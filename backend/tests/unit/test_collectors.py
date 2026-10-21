from datetime import UTC, datetime
from pathlib import Path

import httpx2
import pytest

from app.collectors.errors import (
    CollectorError,
    SourceBlockedError,
    TransientCollectorError,
    UnsafeUrlError,
)
from app.collectors.http import validate_public_url
from app.collectors.normalize import fingerprint, html_to_text, normalize_url
from app.collectors.rss import parse_feed
from app.core.config import Settings
from app.services.collection_service import normalize_offers
from tests.conftest import make_http_client, public_resolver

FIXTURES = Path(__file__).parents[1] / "fixtures"


# --- Normalisation -----------------------------------------------------------------------


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        (
            "HTTPS://Example.COM:443/Jobs/?utm_source=rss&b=2&a=1#top",
            "https://example.com/Jobs?a=1&b=2",
        ),
        ("http://example.com", "http://example.com/"),
        ("https://example.com:8443/x/", "https://example.com:8443/x"),
        ("https://example.com/x?fbclid=abc", "https://example.com/x"),
    ],
)
def test_normalize_url(raw: str, expected: str) -> None:
    assert normalize_url(raw) == expected


@pytest.mark.parametrize("raw", ["ftp://example.com/a", "javascript:alert(1)", "/relative", ""])
def test_normalize_url_rejects_non_http(raw: str) -> None:
    with pytest.raises(ValueError):
        normalize_url(raw)


def test_html_to_text_strips_tags_and_scripts() -> None:
    text = html_to_text("<p>Hello <b>world</b> &amp; co</p><script>alert(1)</script><li>item</li>")
    assert text == "Hello world & co\nitem"


def test_fingerprint_is_case_and_space_insensitive() -> None:
    assert fingerprint("Dev  Python", "Desc") == fingerprint("dev python", "desc")
    assert fingerprint("Dev Python", "Desc") != fingerprint("Dev Flutter", "Desc")


# --- Analyse RSS -------------------------------------------------------------------------


def test_parse_feed_fixture() -> None:
    offers = parse_feed((FIXTURES / "rss_sample.xml").read_bytes())
    assert len(offers) == 4
    first = offers[0]
    assert first.title == "Acme Fictive: Développeur FastAPI senior"
    assert first.external_id == "https://jobs.example.com/remote-jobs/acme-fastapi"
    assert first.location == "Anywhere in the World"
    assert first.category == "Back-End Programming"
    assert first.published_at == datetime(2026, 10, 19, 8, 30, tzinfo=UTC)


def test_parse_feed_rejects_garbage() -> None:
    with pytest.raises(CollectorError):
        parse_feed(b"<html><body>Not a feed</body></html")


def test_normalize_offers_counts_invalid_and_cleans_html() -> None:
    offers = parse_feed((FIXTURES / "rss_sample.xml").read_bytes())
    result = normalize_offers(1, offers)
    assert result.invalid == 1  # item sans lien
    assert len(result.rows) == 3  # le doublon est écarté plus tard par PostgreSQL
    first = result.rows[0]
    assert first["url_normalized"] == "https://jobs.example.com/remote-jobs/acme-fastapi"
    assert "alert" not in first["description"]
    assert "FastAPI & PostgreSQL." in first["description"]


# --- Protection SSRF et client HTTP ------------------------------------------------------


@pytest.mark.parametrize(
    "url",
    [
        "http://localhost/feed",
        "http://127.0.0.1/feed",
        "http://10.0.0.5/feed",
        "http://192.168.1.10/feed",
        "http://169.254.169.254/latest/meta-data/",
        "http://[::1]/feed",
        "http://[::ffff:127.0.0.1]/feed",
        "http://0.0.0.0/feed",
        "ftp://example.com/feed",
        "file:///etc/passwd",
        "https://user:pass@example.com/feed",
        "https://example.com:8080/feed",
    ],
)
def test_validate_public_url_rejects_internal_targets(url: str) -> None:
    def resolver(host: str, port: int) -> list[str]:
        return ["127.0.0.1"] if host == "localhost" else ["93.184.215.14"]

    with pytest.raises(UnsafeUrlError):
        validate_public_url(url, resolver)


def test_validate_public_url_rejects_hostname_resolving_to_private_ip() -> None:
    with pytest.raises(UnsafeUrlError):
        validate_public_url(
            "https://internal.example.com/", lambda h, p: ["93.184.215.14", "10.1.2.3"]
        )


def test_validate_public_url_accepts_public_host() -> None:
    validate_public_url("https://jobs.example.com/feed.rss", public_resolver)


def test_redirect_to_internal_address_is_refused(settings: Settings) -> None:
    def handler(request: httpx2.Request) -> httpx2.Response:
        return httpx2.Response(302, headers={"location": "http://169.254.169.254/latest/"})

    with make_http_client(settings, handler) as client, pytest.raises(UnsafeUrlError):
        client.get("https://jobs.example.com/feed.rss")


def test_public_redirect_is_followed(settings: Settings) -> None:
    def handler(request: httpx2.Request) -> httpx2.Response:
        if request.url.path == "/old":
            return httpx2.Response(301, headers={"location": "/new"})
        return httpx2.Response(200, content=b"ok")

    with make_http_client(settings, handler) as client:
        result = client.get("https://jobs.example.com/old")
    assert result.url == "https://jobs.example.com/new"
    assert result.content == b"ok"


@pytest.mark.parametrize(
    ("status", "error"),
    [
        (403, SourceBlockedError),
        (429, SourceBlockedError),
        (503, TransientCollectorError),
        (404, CollectorError),
    ],
)
def test_http_errors_are_classified(
    settings: Settings, status: int, error: type[Exception]
) -> None:
    with (
        make_http_client(settings, lambda r: httpx2.Response(status)) as client,
        pytest.raises(error),
    ):
        client.get("https://jobs.example.com/feed.rss")


def test_network_error_is_transient(settings: Settings) -> None:
    def handler(request: httpx2.Request) -> httpx2.Response:
        raise httpx2.ConnectError("boom", request=request)

    with make_http_client(settings, handler) as client, pytest.raises(TransientCollectorError):
        client.get("https://jobs.example.com/feed.rss")


def test_response_size_is_limited(settings: Settings) -> None:
    small = settings.model_copy(update={"http_max_response_bytes": 10})
    with make_http_client(small, lambda r: httpx2.Response(200, content=b"x" * 11)) as client:
        with pytest.raises(CollectorError, match="volumineuse"):
            client.get("https://jobs.example.com/feed.rss")
