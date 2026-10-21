from fastapi.testclient import TestClient

from tests.conftest import TEST_PASSWORD

LOGIN = "/api/v1/auth/login"


def test_login_me_and_email_case_insensitive(client: TestClient, user_email: str) -> None:
    response = client.post(LOGIN, json={"email": "DEV@example.com", "password": TEST_PASSWORD})
    assert response.status_code == 200
    body = response.json()
    assert body["token_type"] == "bearer"
    me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {body['access_token']}"})
    assert me.status_code == 200
    assert me.json()["email"] == user_email
    assert "password" not in me.text


def test_login_wrong_password_and_unknown_user_look_identical(
    client: TestClient, user_email: str
) -> None:
    wrong = client.post(LOGIN, json={"email": user_email, "password": "wrong-password"})
    unknown = client.post(LOGIN, json={"email": "nobody@example.com", "password": "x"})
    assert wrong.status_code == unknown.status_code == 401
    assert wrong.json() == unknown.json()


def test_login_is_rate_limited(client: TestClient, user_email: str) -> None:
    for _ in range(3):
        assert client.post(LOGIN, json={"email": user_email, "password": "bad"}).status_code == 401
    blocked = client.post(LOGIN, json={"email": user_email, "password": TEST_PASSWORD})
    assert blocked.status_code == 429


def test_refresh_returns_new_pair_and_rejects_access_token(
    client: TestClient, user_email: str
) -> None:
    tokens = client.post(LOGIN, json={"email": user_email, "password": TEST_PASSWORD}).json()
    refreshed = client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert refreshed.status_code == 200
    assert refreshed.json()["access_token"]
    misuse = client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["access_token"]})
    assert misuse.status_code == 401


def test_logout_revokes_all_tokens(client: TestClient, user_email: str) -> None:
    tokens = client.post(LOGIN, json={"email": user_email, "password": TEST_PASSWORD}).json()
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    assert client.post("/api/v1/auth/logout", headers=headers).status_code == 204
    assert client.get("/api/v1/auth/me", headers=headers).status_code == 401
    again = client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert again.status_code == 401


def test_invalid_bearer_token_rejected(client: TestClient) -> None:
    response = client.get("/api/v1/sources", headers={"Authorization": "Bearer not-a-jwt"})
    assert response.status_code == 401
