"""Automatisations (n8n) : jeton de service et planificateur."""

from unittest.mock import patch

from fastapi.testclient import TestClient
from pydantic import SecretStr
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.models import Source
from tests.conftest import FakeQueue

RUN = "/api/v1/automation/collections/run"
TOKEN = "jeton-de-service-de-test-0123456789abcdef"  # noqa: S105  # donnée fictive


def _with_token(client: TestClient, settings: Settings) -> None:
    configured = settings.model_copy(update={"service_api_token": SecretStr(TOKEN)})
    client.app.dependency_overrides[get_settings] = lambda: configured  # type: ignore[attr-defined]


def test_service_token_required(client: TestClient, settings: Settings) -> None:
    # Indépendant du .env local, qui peut définir SERVICE_API_TOKEN.
    unconfigured = settings.model_copy(update={"service_api_token": None})
    client.app.dependency_overrides[get_settings] = lambda: unconfigured  # type: ignore[attr-defined]
    assert client.post(RUN).status_code == 503  # jeton non configuré : refus
    _with_token(client, settings)
    assert client.post(RUN).status_code == 401
    assert client.post(RUN, headers={"X-Service-Token": "mauvais"}).status_code == 401


def test_user_token_is_not_a_service_token(
    client: TestClient, settings: Settings, auth_headers: dict[str, str]
) -> None:
    _with_token(client, settings)
    assert client.post(RUN, headers=auth_headers).status_code == 401


def test_run_queues_only_schedulable_sources(
    client: TestClient, settings: Settings, db: Session, rss_source: Source, fake_queue: FakeQueue
) -> None:
    blocked = Source(
        name="Bloquée",
        url="https://b.example.com/rss",
        target_type="rss",
        is_active=True,
        health_status="blocked",
    )
    inactive = Source(name="Inactive", url="https://i.example.com/rss", target_type="rss")
    playwright = Source(
        name="Pw", url="https://p.example.com/", target_type="playwright", is_active=True
    )
    db.add_all([blocked, inactive, playwright])
    db.commit()
    _with_token(client, settings)
    response = client.post(RUN, headers={"X-Service-Token": TOKEN})
    assert response.status_code == 200
    assert response.json()["queued"] == [rss_source.id]
    assert fake_queue.triggers == ["schedule"]


def test_beat_stops_scheduling_when_n8n_is_the_scheduler(settings: Settings) -> None:
    from app.tasks import collection

    with (
        patch.object(
            collection,
            "get_settings",
            lambda: settings.model_copy(update={"collection_scheduler": "n8n"}),
        ),
        patch.object(collection, "due_source_ids") as due,
    ):
        assert collection.schedule_due_sources() == []
        due.assert_not_called()
