import httpx2
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.models import Notification, Source, User
from app.services.collection_service import run_collection
from app.services.user_service import create_user
from tests.conftest import TEST_PASSWORD, make_http_client, rss_handler

NOTIFICATIONS = "/api/v1/notifications"


def _count(db: Session, **filters: object) -> int:
    stmt = select(func.count()).select_from(Notification).filter_by(**filters)
    return db.scalar(stmt) or 0


def test_new_offers_notify_once_per_run(
    db: Session, settings: Settings, rss_source: Source, user_email: str
) -> None:
    create_user(db, "inactive@example.com", TEST_PASSWORD)
    inactive = db.scalars(select(User).where(User.email == "inactive@example.com")).one()
    inactive.is_active = False
    db.commit()

    with make_http_client(settings, rss_handler) as http:
        run_collection(db, rss_source.id, http, "manual")
        run_collection(db, rss_source.id, http, "schedule")  # aucune nouvelle offre

    notifications = db.scalars(select(Notification)).all()
    assert len(notifications) == 1  # un seul utilisateur actif, une seule collecte utile
    notification = notifications[0]
    assert notification.type == "new_offers"
    assert notification.body == "2 nouvelles offres — Flux de test"
    assert notification.source_id == rss_source.id
    assert notification.offer_id is None  # plusieurs offres : on ouvre la source


def test_failure_notifies_only_on_state_change(
    db: Session, settings: Settings, rss_source: Source, user_email: str
) -> None:
    with make_http_client(settings, lambda r: httpx2.Response(502)) as http:
        run_collection(db, rss_source.id, http, "schedule")
        run_collection(db, rss_source.id, http, "schedule")
    assert _count(db, type="source_error") == 1

    with make_http_client(settings, lambda r: httpx2.Response(403)) as http:
        run_collection(db, rss_source.id, http, "schedule")
    blocked = db.scalars(select(Notification).where(Notification.type == "source_blocked")).one()
    assert blocked.title == "Source bloquée par le site"
    assert "HTTP 403" in blocked.body


def test_notification_failure_does_not_break_collection(
    db: Session,
    settings: Settings,
    rss_source: Source,
    user_email: str,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def boom(*args: object, **kwargs: object) -> int:
        raise RuntimeError("notification indisponible")

    monkeypatch.setattr("app.services.collection_service.notify_collection_outcome", boom)
    with make_http_client(settings, rss_handler) as http:
        run = run_collection(db, rss_source.id, http, "manual").run
    assert run.status == "success"
    assert run.items_new == 2


def test_api_list_read_and_counts(
    client: TestClient,
    auth_headers: dict[str, str],
    db: Session,
    settings: Settings,
    rss_source: Source,
) -> None:
    with make_http_client(settings, rss_handler) as http:
        run_collection(db, rss_source.id, http, "manual")
    with make_http_client(settings, lambda r: httpx2.Response(500)) as http:
        run_collection(db, rss_source.id, http, "schedule")

    assert client.get(f"{NOTIFICATIONS}/unread-count", headers=auth_headers).json() == {"count": 2}
    page = client.get(NOTIFICATIONS, headers=auth_headers).json()
    assert page["total"] == 2
    assert [n["type"] for n in page["items"]] == ["source_error", "new_offers"]  # récentes d'abord

    errors = client.get(NOTIFICATIONS, params={"type": "source_error"}, headers=auth_headers)
    assert errors.json()["total"] == 1

    first_id = page["items"][0]["id"]
    read = client.patch(f"{NOTIFICATIONS}/{first_id}/read", headers=auth_headers).json()
    again = client.patch(f"{NOTIFICATIONS}/{first_id}/read", headers=auth_headers).json()
    assert read["read_at"] is not None and read["read_at"] == again["read_at"]

    unread = client.get(NOTIFICATIONS, params={"unread_only": True}, headers=auth_headers).json()
    assert unread["total"] == 1
    marked = client.post(f"{NOTIFICATIONS}/mark-all-read", headers=auth_headers).json()
    assert marked == {"updated": 1}
    assert client.get(f"{NOTIFICATIONS}/unread-count", headers=auth_headers).json() == {"count": 0}


def test_notifications_are_isolated(
    client: TestClient,
    auth_headers: dict[str, str],
    db: Session,
    settings: Settings,
    rss_source: Source,
) -> None:
    with make_http_client(settings, rss_handler) as http:
        run_collection(db, rss_source.id, http, "manual")
    mine = client.get(NOTIFICATIONS, headers=auth_headers).json()["items"][0]

    create_user(db, "late@example.com", TEST_PASSWORD)  # créé après la collecte
    tokens = client.post(
        "/api/v1/auth/login", json={"email": "late@example.com", "password": TEST_PASSWORD}
    ).json()
    other = {"Authorization": f"Bearer {tokens['access_token']}"}
    assert client.get(NOTIFICATIONS, headers=other).json()["total"] == 0
    assert client.patch(f"{NOTIFICATIONS}/{mine['id']}/read", headers=other).status_code == 404
    assert client.post(f"{NOTIFICATIONS}/mark-all-read", headers=other).json() == {"updated": 0}
    assert client.get(f"{NOTIFICATIONS}/unread-count", headers=auth_headers).json() == {"count": 1}


def test_notifications_require_authentication(client: TestClient) -> None:
    assert client.get(NOTIFICATIONS).status_code == 401
    assert client.get(f"{NOTIFICATIONS}/unread-count").status_code == 401
