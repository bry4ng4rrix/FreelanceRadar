"""Tests du socle applicatif, sans base de données."""

from fastapi import APIRouter, Query
from fastapi.testclient import TestClient

from app.core.config import Settings
from app.main import create_app


def _client(settings: Settings) -> TestClient:
    app = create_app(settings)
    router = APIRouter()

    @router.get("/boom")
    def boom() -> None:
        raise RuntimeError("secret-value-should-not-leak")

    @router.get("/typed")
    def typed(n: int = Query()) -> int:
        return n

    app.include_router(router)
    return TestClient(app, raise_server_exceptions=False)


def test_health_returns_ok(settings: Settings) -> None:
    response = _client(settings).get("/api/v1/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_unknown_route_uses_standard_error_format(settings: Settings) -> None:
    response = _client(settings).get("/api/v1/does-not-exist")
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "http_404"


def test_validation_error_is_standardized_and_hides_input(settings: Settings) -> None:
    response = _client(settings).get("/typed", params={"n": "my-password"})
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"
    assert "my-password" not in response.text


def test_unhandled_error_returns_500_without_details(settings: Settings) -> None:
    response = _client(settings).get("/boom")
    assert response.status_code == 500
    assert response.json()["error"]["code"] == "internal_error"
    assert "secret-value-should-not-leak" not in response.text


def test_docs_disabled_in_production(settings: Settings) -> None:
    prod = settings.model_copy(update={"environment": "production"})
    assert _client(prod).get("/docs").status_code == 404


def test_private_routes_require_authentication(settings: Settings) -> None:
    client = _client(settings)
    for path in ("/api/v1/sources", "/api/v1/offers", "/api/v1/auth/me"):
        response = client.get(path)
        assert response.status_code == 401, path
        assert response.headers["www-authenticate"] == "Bearer"


def test_cors_only_allows_configured_origins(settings: Settings) -> None:
    configured = settings.model_copy(update={"cors_origins": ["https://app.example.com"]})
    client = _client(configured)
    headers = {"Origin": "https://app.example.com", "Access-Control-Request-Method": "GET"}
    allowed = client.options("/api/v1/health", headers=headers)
    assert allowed.headers.get("access-control-allow-origin") == "https://app.example.com"
    denied = client.options(
        "/api/v1/health", headers={**headers, "Origin": "https://evil.example.net"}
    )
    assert "access-control-allow-origin" not in denied.headers
