import json
from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.models import Source
from app.services.collection_service import run_collection
from tests.conftest import FakeQueue, make_http_client, rss_handler

SOURCES_JSON = Path(__file__).parents[2] / "data" / "sources.json"
NEW_SOURCE = {
    "name": "Nouvelle source",
    "url": "https://jobs.example.com/feed.rss",
    "target_type": "rss",
    "frequency_minutes": 30,
}


def test_create_get_update_list(client: TestClient, auth_headers: dict[str, str]) -> None:
    created = client.post("/api/v1/sources", json=NEW_SOURCE, headers=auth_headers)
    assert created.status_code == 201
    source = created.json()
    assert source["health_status"] == "unknown"
    assert source["is_active"] is False  # inactive par défaut

    patched = client.patch(
        f"/api/v1/sources/{source['id']}", json={"is_active": True}, headers=auth_headers
    )
    assert patched.status_code == 200
    assert patched.json()["is_active"] is True

    listed = client.get("/api/v1/sources", params={"is_active": True}, headers=auth_headers)
    assert [s["name"] for s in listed.json()["items"]] == ["Nouvelle source"]


def test_duplicate_name_conflict(client: TestClient, auth_headers: dict[str, str]) -> None:
    assert client.post("/api/v1/sources", json=NEW_SOURCE, headers=auth_headers).status_code == 201
    dup = client.post("/api/v1/sources", json=NEW_SOURCE, headers=auth_headers)
    assert dup.status_code == 409


def test_invalid_payloads_rejected(client: TestClient, auth_headers: dict[str, str]) -> None:
    for bad in (
        {**NEW_SOURCE, "url": "ftp://example.com"},
        {**NEW_SOURCE, "frequency_minutes": 1},
        {**NEW_SOURCE, "target_type": "unknown"},
        {**NEW_SOURCE, "unexpected": True},
    ):
        assert client.post("/api/v1/sources", json=bad, headers=auth_headers).status_code == 422
    created = client.post("/api/v1/sources", json=NEW_SOURCE, headers=auth_headers).json()
    null_name = client.patch(
        f"/api/v1/sources/{created['id']}", json={"name": None}, headers=auth_headers
    )
    assert null_name.status_code == 422


def test_import_user_json_is_idempotent(client: TestClient, auth_headers: dict[str, str]) -> None:
    payload = json.loads(SOURCES_JSON.read_text())
    first = client.post("/api/v1/sources/import", json=payload, headers=auth_headers)
    assert first.status_code == 200
    assert len(first.json()["created"]) == len(payload) == 12
    second = client.post("/api/v1/sources/import", json=payload, headers=auth_headers).json()
    assert second["created"] == []
    assert len(second["skipped"]) == 12


def test_delete_refused_when_history_exists(
    client: TestClient,
    auth_headers: dict[str, str],
    db: Session,
    rss_source: Source,
    settings: Settings,
) -> None:
    with make_http_client(settings, rss_handler) as http:
        run_collection(db, rss_source.id, http, "manual")
    response = client.delete(f"/api/v1/sources/{rss_source.id}", headers=auth_headers)
    assert response.status_code == 409
    empty = client.post("/api/v1/sources", json=NEW_SOURCE, headers=auth_headers).json()
    assert client.delete(f"/api/v1/sources/{empty['id']}", headers=auth_headers).status_code == 204


def test_test_endpoint_does_not_write(
    client: TestClient, auth_headers: dict[str, str], rss_source: Source
) -> None:
    response = client.post(f"/api/v1/sources/{rss_source.id}/test", headers=auth_headers)
    assert response.status_code == 200
    body = response.json()
    assert body == {
        "ok": True,
        "items_found": 4,
        "valid_items": 3,
        "sample_titles": [
            "Acme Fictive: Développeur FastAPI senior",
            "Globex Exemple: Développeur Flutter",
            "Globex Exemple: Développeur Flutter (republication)",
        ],
        "error": None,
    }
    offers = client.get("/api/v1/offers", headers=auth_headers).json()
    assert offers["total"] == 0


def test_run_endpoint_enqueues(
    client: TestClient, auth_headers: dict[str, str], rss_source: Source, fake_queue: FakeQueue
) -> None:
    response = client.post(f"/api/v1/sources/{rss_source.id}/run", headers=auth_headers)
    assert response.status_code == 202
    assert response.json() == {"task_id": f"fake-task-{rss_source.id}"}
    assert fake_queue.enqueued == [rss_source.id]
    missing = client.post("/api/v1/sources/999999/run", headers=auth_headers)
    assert missing.status_code == 404
