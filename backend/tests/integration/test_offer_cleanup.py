"""Offres expirées : archivage, suppression définitive, protections et filtre à la collecte."""

from datetime import UTC, datetime, timedelta

import pytest
from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.models import Application, Offer, Source
from app.services.collection_service import run_collection
from app.services.offer_cleanup_service import cleanup_expired_offers
from app.services.user_service import create_user
from tests.conftest import TEST_PASSWORD, make_http_client, rss_handler

NOW = datetime(2026, 10, 22, 12, 0, tzinfo=UTC)


@pytest.fixture
def cleanup_settings(settings: Settings) -> Settings:
    # Délais fixés ici : indépendants des valeurs éventuelles du .env local.
    return settings.model_copy(
        update={"offer_archive_after_days": 30, "offer_purge_after_days": 90}
    )


def _offer(
    db: Session,
    source: Source,
    key: str,
    *,
    published_days_ago: int | None,
    collected_days_ago: int = 0,
    archived: bool = False,
    **fields: object,
) -> Offer:
    offer = Offer(
        source_id=source.id,
        url=f"https://jobs.example.com/{key}",
        url_normalized=f"https://jobs.example.com/{key}",
        fingerprint=key,
        title=f"Offre {key}",
        published_at=None
        if published_days_ago is None
        else NOW - timedelta(days=published_days_ago),
        collected_at=NOW - timedelta(days=collected_days_ago),
        archived_at=NOW - timedelta(days=1) if archived else None,
        **fields,
    )
    db.add(offer)
    db.commit()
    return offer


def _state(db: Session, offer_id: int) -> str:
    db.expire_all()
    offer = db.get(Offer, offer_id)
    if offer is None:
        return "deleted"
    return "archived" if offer.archived_at else "visible"


def test_archives_expired_offers_only(
    db: Session, cleanup_settings: Settings, rss_source: Source
) -> None:
    recent = _offer(db, rss_source, "recent", published_days_ago=5)
    old = _offer(db, rss_source, "old", published_days_ago=31)
    # Sans date de publication : la date de collecte sert de référence.
    old_undated = _offer(db, rss_source, "undated", published_days_ago=None, collected_days_ago=40)
    new_undated = _offer(db, rss_source, "undated-new", published_days_ago=None)

    result = cleanup_expired_offers(db, cleanup_settings, NOW)

    assert (result.archived, result.purged) == (2, 0)
    assert _state(db, recent.id) == "visible"
    assert _state(db, old.id) == "archived"
    assert _state(db, old_undated.id) == "archived"
    assert _state(db, new_undated.id) == "visible"


def test_purges_only_archived_offers_past_the_limit(
    db: Session, cleanup_settings: Settings, rss_source: Source
) -> None:
    archived_old = _offer(db, rss_source, "a-old", published_days_ago=91, archived=True)
    archived_recent = _offer(db, rss_source, "a-recent", published_days_ago=40, archived=True)
    # Jamais archivée : archivée à ce passage, supprimée seulement au suivant.
    visible_old = _offer(db, rss_source, "v-old", published_days_ago=200)

    result = cleanup_expired_offers(db, cleanup_settings, NOW)

    assert (result.archived, result.purged) == (1, 1)
    assert _state(db, archived_old.id) == "deleted"
    assert _state(db, archived_recent.id) == "archived"
    assert _state(db, visible_old.id) == "archived"
    assert cleanup_expired_offers(db, cleanup_settings, NOW).purged == 1
    assert _state(db, visible_old.id) == "deleted"


def test_protected_offers_are_never_touched(
    db: Session, cleanup_settings: Settings, rss_source: Source
) -> None:
    favorite = _offer(db, rss_source, "fav", published_days_ago=200, status="favorite")
    noted = _offer(db, rss_source, "noted", published_days_ago=200, notes="À relancer")
    applied = _offer(db, rss_source, "applied", published_days_ago=200, archived=True)
    user = create_user(db, "dev@example.com", TEST_PASSWORD)
    db.add(Application(user_id=user.id, offer_id=applied.id, status="cancelled"))
    db.commit()

    result = cleanup_expired_offers(db, cleanup_settings, NOW)

    assert (result.archived, result.purged) == (0, 0)
    assert _state(db, favorite.id) == "visible"
    assert _state(db, noted.id) == "visible"
    assert _state(db, applied.id) == "archived"


def test_dry_run_changes_nothing(
    db: Session, cleanup_settings: Settings, rss_source: Source
) -> None:
    old = _offer(db, rss_source, "old", published_days_ago=31)
    gone = _offer(db, rss_source, "gone", published_days_ago=100, archived=True)

    result = cleanup_expired_offers(db, cleanup_settings, NOW, dry_run=True)

    assert (result.archived, result.purged) == (1, 1)
    assert _state(db, old.id) == "visible"
    assert _state(db, gone.id) == "archived"


def test_zero_disables_cleanup(db: Session, cleanup_settings: Settings, rss_source: Source) -> None:
    old = _offer(db, rss_source, "old", published_days_ago=300, archived=True)
    disabled = cleanup_settings.model_copy(
        update={"offer_archive_after_days": 0, "offer_purge_after_days": 0}
    )

    assert cleanup_expired_offers(db, disabled, NOW) == cleanup_expired_offers(
        db, disabled, NOW, dry_run=True
    )
    assert cleanup_expired_offers(db, disabled, NOW).purged == 0
    assert _state(db, old.id) == "archived"


def test_purge_delay_must_exceed_archive_delay() -> None:
    with pytest.raises(ValidationError, match="OFFER_PURGE_AFTER_DAYS"):
        Settings(offer_archive_after_days=30, offer_purge_after_days=30)


def test_collection_skips_expired_offers(
    db: Session, settings: Settings, rss_source: Source
) -> None:
    # Fixture : publiées le 19/10 et le 20/10 ; la limite écarte la première.
    with make_http_client(settings, rss_handler) as http:
        run = run_collection(
            db, rss_source.id, http, "manual", published_after=datetime(2026, 10, 20, tzinfo=UTC)
        ).run

    assert run.status == "success"
    assert (run.items_seen, run.items_new, run.items_duplicate, run.items_invalid) == (4, 1, 1, 1)
    titles = db.scalars(select(Offer.title)).all()
    assert titles == ["Globex Exemple: Développeur Flutter"]
