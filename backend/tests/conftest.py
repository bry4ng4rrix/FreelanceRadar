"""Fixtures partagées.

Les tests d'intégration utilisent une base PostgreSQL dédiée `<base>_test`, créée si besoin
sur le serveur de DATABASE_URL, puis remise à zéro par les migrations Alembic à chaque session.
Ils sont ignorés (avec la raison affichée) si PostgreSQL n'est pas joignable.
"""

import os
from collections.abc import Callable, Iterator
from pathlib import Path

import httpx2
import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import Connection, create_engine, make_url, text
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session

# Valeurs par défaut si aucun `.env` n'est présent (CI) : jamais de vrai secret ici.
os.environ.setdefault(
    "DATABASE_URL", "postgresql+psycopg://freelanceradar:test@127.0.0.1:5432/freelanceradar"
)
os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key-not-for-production-0123456789")

from app.api.deps import CollectionQueue, get_collection_queue, get_http_client, get_login_limiter  # noqa: E402
from app.collectors.http import SafeHttpClient  # noqa: E402
from app.core.config import Settings  # noqa: E402
from app.core.rate_limit import InMemoryLoginRateLimiter  # noqa: E402
from app.db.session import get_db  # noqa: E402
from app.main import create_app  # noqa: E402
from app.models import Source  # noqa: E402
from app.services.user_service import create_user  # noqa: E402

BACKEND_DIR = Path(__file__).resolve().parents[1]
FIXTURES = Path(__file__).parent / "fixtures"
TEST_PASSWORD = "correct-horse-battery-staple"  # noqa: S105  # donnée de test fictive


@pytest.fixture(scope="session")
def settings() -> Settings:
    return Settings(environment="test")  # type: ignore[call-arg]


@pytest.fixture(scope="session")
def test_database_url(settings: Settings) -> str:
    url = make_url(settings.database_url)
    test_name = f"{url.database}_test"
    assert test_name.endswith("_test")  # garde-fou : jamais la base de développement
    admin = create_engine(url.set(database="postgres"), isolation_level="AUTOCOMMIT")
    try:
        with admin.connect() as conn:
            exists = conn.scalar(
                text("SELECT 1 FROM pg_database WHERE datname = :n"), {"n": test_name}
            )
            if not exists:
                conn.execute(text(f'CREATE DATABASE "{test_name}"'))
    except OperationalError as exc:
        pytest.skip(f"PostgreSQL injoignable ({url.host}:{url.port}) : {exc.orig}")
    finally:
        admin.dispose()
    test_url = url.set(database=test_name).render_as_string(hide_password=False)

    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("sqlalchemy.url", test_url.replace("%", "%%"))
    # Aller-retour complet : vérifie aussi que le downgrade fonctionne.
    command.downgrade(cfg, "base")
    command.upgrade(cfg, "head")
    return test_url


@pytest.fixture
def connection(test_database_url: str) -> Iterator[Connection]:
    engine = create_engine(test_database_url)
    with engine.connect() as conn:
        trans = conn.begin()
        yield conn
        trans.rollback()
    engine.dispose()


@pytest.fixture
def db(connection: Connection) -> Iterator[Session]:
    """Session dont les commit deviennent des savepoints : tout est annulé en fin de test."""
    with Session(
        bind=connection, join_transaction_mode="create_savepoint", expire_on_commit=False
    ) as session:
        yield session


def public_resolver(host: str, port: int) -> list[str]:
    return ["93.184.215.14"]  # adresse publique fictive : aucun DNS réel en test


def make_http_client(
    settings: Settings, handler: Callable[[httpx2.Request], httpx2.Response]
) -> SafeHttpClient:
    return SafeHttpClient(settings, transport=httpx2.MockTransport(handler), resolver=public_resolver)


def rss_handler(request: httpx2.Request) -> httpx2.Response:
    return httpx2.Response(
        200,
        content=(FIXTURES / "rss_sample.xml").read_bytes(),
        headers={"content-type": "application/rss+xml"},
    )


class FakeQueue(CollectionQueue):
    def __init__(self) -> None:
        self.enqueued: list[int] = []

    def enqueue(self, source_id: int) -> str:
        self.enqueued.append(source_id)
        return f"fake-task-{source_id}"


@pytest.fixture
def fake_queue() -> FakeQueue:
    return FakeQueue()


@pytest.fixture
def limiter() -> InMemoryLoginRateLimiter:
    return InMemoryLoginRateLimiter(max_attempts=3, window_seconds=60)


@pytest.fixture
def client(
    settings: Settings, db: Session, fake_queue: FakeQueue, limiter: InMemoryLoginRateLimiter
) -> Iterator[TestClient]:
    app = create_app(settings)
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_login_limiter] = lambda: limiter
    app.dependency_overrides[get_collection_queue] = lambda: fake_queue

    def _http_client() -> Iterator[SafeHttpClient]:
        with make_http_client(settings, rss_handler) as c:
            yield c

    app.dependency_overrides[get_http_client] = _http_client
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c


@pytest.fixture
def user_email(db: Session) -> str:
    create_user(db, "Dev@Example.com", TEST_PASSWORD)
    return "dev@example.com"


@pytest.fixture
def auth_headers(client: TestClient, user_email: str) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/login", json={"email": user_email, "password": TEST_PASSWORD}
    )
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


@pytest.fixture
def rss_source(db: Session) -> Source:
    source = Source(
        name="Flux de test",
        url="https://jobs.example.com/feed.rss",
        target_type="rss",
        frequency_minutes=30,
        is_active=True,
    )
    db.add(source)
    db.commit()
    return source
