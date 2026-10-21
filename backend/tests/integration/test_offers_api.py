import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.models import Source
from app.services.collection_service import run_collection
from tests.conftest import make_http_client, rss_handler


@pytest.fixture
def collected(db: Session, settings: Settings, rss_source: Source) -> None:
    with make_http_client(settings, rss_handler) as http:
        run_collection(db, rss_source.id, http, "manual")


@pytest.mark.usefixtures("collected")
def test_search_filter_and_pagination(client: TestClient, auth_headers: dict[str, str]) -> None:
    found = client.get("/api/v1/offers", params={"q": "fastapi"}, headers=auth_headers).json()
    assert found["total"] == 1
    page = client.get(
        "/api/v1/offers", params={"page_size": 1, "page": 2}, headers=auth_headers
    ).json()
    assert page["total"] == 2
    assert len(page["items"]) == 1
    # Les caractères spéciaux de LIKE sont traités littéralement.
    none = client.get("/api/v1/offers", params={"q": "%%"}, headers=auth_headers).json()
    assert none["total"] == 0


@pytest.mark.usefixtures("collected")
def test_invalid_query_params(client: TestClient, auth_headers: dict[str, str]) -> None:
    for params in ({"page_size": 1000}, {"sort": "title"}, {"status": "bogus"}, {"page": 0}):
        assert client.get("/api/v1/offers", params=params, headers=auth_headers).status_code == 422


@pytest.mark.usefixtures("collected")
def test_update_status_notes_and_archive(client: TestClient, auth_headers: dict[str, str]) -> None:
    offer = client.get("/api/v1/offers", headers=auth_headers).json()["items"][0]
    url = f"/api/v1/offers/{offer['id']}"

    patched = client.patch(
        url, json={"status": "favorite", "notes": "À relancer"}, headers=auth_headers
    )
    assert patched.status_code == 200
    assert (patched.json()["status"], patched.json()["notes"]) == ("favorite", "À relancer")
    # Les statuts liés aux candidatures ne se posent pas à la main.
    refused = client.patch(url, json={"status": "application_sent"}, headers=auth_headers)
    assert refused.status_code == 422

    archived = client.post(f"{url}/archive", headers=auth_headers).json()
    again = client.post(f"{url}/archive", headers=auth_headers).json()
    assert archived["archived_at"] == again["archived_at"] is not None
    visible = client.get("/api/v1/offers", headers=auth_headers).json()
    assert offer["id"] not in [o["id"] for o in visible["items"]]
    with_archived = client.get(
        "/api/v1/offers", params={"include_archived": True}, headers=auth_headers
    ).json()
    assert offer["id"] in [o["id"] for o in with_archived["items"]]


def test_get_missing_offer(client: TestClient, auth_headers: dict[str, str]) -> None:
    response = client.get("/api/v1/offers/999999", headers=auth_headers)
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "http_404"
