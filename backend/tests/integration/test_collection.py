"""Premier parcours complet : flux RSS (fixture) → normalisation → PostgreSQL → API."""

from datetime import timedelta

import httpx2
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.db.base import utcnow
from app.models import CollectionRun, Offer, Source
from app.services.collection_service import due_source_ids, run_collection
from tests.conftest import make_http_client, rss_handler


def _offer_count(db: Session) -> int:
    return db.scalar(select(func.count()).select_from(Offer)) or 0


def test_rss_collection_end_to_end(
    db: Session,
    settings: Settings,
    rss_source: Source,
    client: TestClient,
    auth_headers: dict[str, str],
) -> None:
    with make_http_client(settings, rss_handler) as http:
        first = run_collection(db, rss_source.id, http, "manual").run
    assert first.status == "success"
    assert (first.items_seen, first.items_new, first.items_duplicate, first.items_invalid) == (
        4,
        2,
        1,
        1,
    )
    assert _offer_count(db) == 2

    # Seconde collecte identique : aucune nouvelle offre, tout est doublon.
    with make_http_client(settings, rss_handler) as http:
        second = run_collection(db, rss_source.id, http, "schedule").run
    assert (second.items_new, second.items_duplicate) == (0, 3)
    assert _offer_count(db) == 2

    db.refresh(rss_source)
    assert rss_source.health_status == "ok"
    assert rss_source.offers_count == 2
    assert rss_source.last_success_at is not None

    # Les offres sont consultables via l'API.
    response = client.get("/api/v1/offers", headers=auth_headers, params={"sort": "-published_at"})
    assert response.status_code == 200
    page = response.json()
    assert page["total"] == 2
    assert page["items"][0]["title"] == "Globex Exemple: Développeur Flutter"
    runs = client.get(f"/api/v1/sources/{rss_source.id}/runs", headers=auth_headers).json()
    assert runs["total"] == 2


def test_same_url_from_another_source_is_deduplicated(
    db: Session, settings: Settings, rss_source: Source
) -> None:
    other = Source(name="Autre flux", url="https://other.example.com/rss", target_type="rss")
    db.add(other)
    db.commit()
    with make_http_client(settings, rss_handler) as http:
        run_collection(db, rss_source.id, http, "manual")
        result = run_collection(db, other.id, http, "manual").run
    assert result.items_new == 0
    assert _offer_count(db) == 2


def test_blocked_source_is_marked_and_not_scheduled(
    db: Session, settings: Settings, rss_source: Source
) -> None:
    with make_http_client(settings, lambda r: httpx2.Response(403)) as http:
        result = run_collection(db, rss_source.id, http, "schedule")
    assert result.run.status == "blocked"
    assert not result.retryable
    db.refresh(rss_source)
    assert rss_source.health_status == "blocked"
    assert rss_source.error_count == 1
    far_future = utcnow() + timedelta(days=1)
    assert rss_source.id not in due_source_ids(db, far_future)


def test_transient_error_is_retryable(db: Session, settings: Settings, rss_source: Source) -> None:
    with make_http_client(settings, lambda r: httpx2.Response(502)) as http:
        result = run_collection(db, rss_source.id, http, "schedule")
    assert result.run.status == "failed"
    assert result.retryable
    db.refresh(rss_source)
    assert rss_source.health_status == "error"
    assert rss_source.consecutive_failures == 1


def test_unsupported_connector_is_recorded(db: Session, settings: Settings) -> None:
    source = Source(name="Playwright", url="https://example.com/jobs", target_type="playwright")
    db.add(source)
    db.commit()
    with make_http_client(settings, rss_handler) as http:
        result = run_collection(db, source.id, http, "manual")
    assert result.run.status == "unsupported"
    db.refresh(source)
    assert source.health_status == "unsupported"


def test_due_sources_respect_frequency_and_activity(db: Session, rss_source: Source) -> None:
    now = utcnow()
    inactive = Source(
        name="Inactive", url="https://x.example.com/rss", target_type="rss", is_active=False
    )
    playwright = Source(
        name="Pw", url="https://y.example.com/", target_type="playwright", is_active=True
    )
    db.add_all([inactive, playwright])
    db.commit()
    assert due_source_ids(db, now) == [rss_source.id]  # jamais collectée → due

    rss_source.last_attempt_at = now - timedelta(minutes=10)
    db.commit()
    assert due_source_ids(db, now) == []  # fréquence 30 min non écoulée
    assert due_source_ids(db, now + timedelta(minutes=21)) == [rss_source.id]


def test_run_history_is_persisted(db: Session, settings: Settings, rss_source: Source) -> None:
    with make_http_client(settings, rss_handler) as http:
        run_collection(db, rss_source.id, http, "manual", task_id="task-123")
    run = db.scalars(select(CollectionRun)).one()
    assert run.task_id == "task-123"
    assert run.finished_at is not None
    assert run.finished_at >= run.started_at
