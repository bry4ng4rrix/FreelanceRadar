import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.services.user_service import create_user
from tests.conftest import TEST_PASSWORD

PROFILE = "/api/v1/profile"
SKILLS = "/api/v1/profile/skills"


@pytest.fixture
def other_headers(client: TestClient, db: Session) -> dict[str, str]:
    """Second utilisateur, pour vérifier l'isolation des données."""
    create_user(db, "other@example.com", TEST_PASSWORD)
    tokens = client.post(
        "/api/v1/auth/login", json={"email": "other@example.com", "password": TEST_PASSWORD}
    ).json()
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def test_profile_requires_authentication(client: TestClient) -> None:
    assert client.get(PROFILE).status_code == 401
    assert client.get(SKILLS).status_code == 401


def test_profile_is_created_on_first_read(client: TestClient, auth_headers: dict[str, str]) -> None:
    first = client.get(PROFILE, headers=auth_headers)
    assert first.status_code == 200
    profile = first.json()
    assert profile["primary_email"] == "dev@example.com"  # e-mail du compte prérempli
    assert profile["availability"] == "available"
    assert profile["currency"] == "EUR"
    assert client.get(PROFILE, headers=auth_headers).json()["id"] == profile["id"]


def test_patch_profile_updates_and_normalizes(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    response = client.patch(
        PROFILE,
        headers=auth_headers,
        json={
            "full_name": "  Jane Dev ",
            "professional_title": "Développeuse Python / Flutter",
            "github_url": "https://github.com/janedev",
            "preferred_languages": ["FR", "en", "fr"],
            "default_rate": "450.00",
            "rate_unit": "day",
            "currency": "mga",
            "contract_types": ["freelance", "fixed_price"],
            "excluded_keywords": ["wordpress", "WordPress"],
            "available_from": "2026-11-01",
        },
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["full_name"] == "Jane Dev"
    assert body["github_url"] == "https://github.com/janedev"
    assert body["preferred_languages"] == ["fr", "en"]
    assert body["currency"] == "MGA"
    assert body["excluded_keywords"] == ["wordpress"]
    assert body["default_rate"] == "450.00"

    # Une chaîne vide efface un champ facultatif ; les champs non envoyés sont conservés.
    cleared = client.patch(PROFILE, headers=auth_headers, json={"full_name": ""}).json()
    assert cleared["full_name"] is None
    assert cleared["professional_title"] == "Développeuse Python / Flutter"


@pytest.mark.parametrize(
    "payload",
    [
        {"github_url": "javascript:alert(1)"},
        {"primary_email": "pas-un-email"},
        {"phone": "appelez-moi"},
        {"currency": "EURO"},
        {"preferred_languages": ["français"]},
        {"availability": "busy"},
        {"default_rate": -1},
        {"contract_types": ["cdi"]},
        {"currency": None},
        {"unknown_field": True},
    ],
)
def test_patch_profile_rejects_invalid_values(
    client: TestClient, auth_headers: dict[str, str], payload: dict[str, object]
) -> None:
    assert client.patch(PROFILE, headers=auth_headers, json=payload).status_code == 422


def test_profiles_are_isolated(
    client: TestClient, auth_headers: dict[str, str], other_headers: dict[str, str]
) -> None:
    client.patch(PROFILE, headers=auth_headers, json={"full_name": "Jane Dev"})
    other = client.get(PROFILE, headers=other_headers).json()
    assert other["full_name"] is None
    assert other["primary_email"] == "other@example.com"


def test_skills_crud(client: TestClient, auth_headers: dict[str, str]) -> None:
    created = client.post(
        SKILLS,
        headers=auth_headers,
        json={
            "name": " FastAPI ",
            "category": "Backend",
            "proficiency_level": "advanced",
            "years_experience": "3.5",
            "aliases": ["fast-api"],
        },
    )
    assert created.status_code == 201, created.text
    skill = created.json()
    assert skill["name"] == "FastAPI"
    assert skill["years_experience"] == "3.5"

    client.post(SKILLS, headers=auth_headers, json={"name": "Django"})
    names = [s["name"] for s in client.get(SKILLS, headers=auth_headers).json()]
    assert names == ["Django", "FastAPI"]  # tri alphabétique

    patched = client.patch(
        f"{SKILLS}/{skill['id']}", headers=auth_headers, json={"proficiency_level": "expert"}
    )
    assert patched.status_code == 200
    assert patched.json()["proficiency_level"] == "expert"
    assert patched.json()["category"] == "Backend"

    assert client.delete(f"{SKILLS}/{skill['id']}", headers=auth_headers).status_code == 204
    assert [s["name"] for s in client.get(SKILLS, headers=auth_headers).json()] == ["Django"]


def test_duplicate_skill_is_rejected_case_insensitively(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    assert client.post(SKILLS, headers=auth_headers, json={"name": "Python"}).status_code == 201
    duplicate = client.post(SKILLS, headers=auth_headers, json={"name": "python"})
    assert duplicate.status_code == 409
    flutter = client.post(SKILLS, headers=auth_headers, json={"name": "Flutter"}).json()
    rename = client.patch(
        f"{SKILLS}/{flutter['id']}", headers=auth_headers, json={"name": "PYTHON"}
    )
    assert rename.status_code == 409


@pytest.mark.parametrize(
    "payload",
    [
        {"name": ""},
        {"name": "Go", "proficiency_level": "guru"},
        {"name": "Go", "years_experience": 99},
        {"name": "Go", "years_experience": "1.25"},
    ],
)
def test_invalid_skill_rejected(
    client: TestClient, auth_headers: dict[str, str], payload: dict[str, object]
) -> None:
    assert client.post(SKILLS, headers=auth_headers, json=payload).status_code == 422


def test_skills_are_isolated(
    client: TestClient, auth_headers: dict[str, str], other_headers: dict[str, str]
) -> None:
    skill = client.post(SKILLS, headers=auth_headers, json={"name": "Python"}).json()
    assert client.get(SKILLS, headers=other_headers).json() == []
    url = f"{SKILLS}/{skill['id']}"
    assert client.patch(url, headers=other_headers, json={"name": "X"}).status_code == 404
    assert client.delete(url, headers=other_headers).status_code == 404
    # Le même nom reste possible pour un autre utilisateur.
    assert client.post(SKILLS, headers=other_headers, json={"name": "Python"}).status_code == 201
