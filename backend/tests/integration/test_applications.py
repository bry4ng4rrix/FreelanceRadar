"""Candidatures : rédaction IA simulée, validation, envoi sur un faux serveur SMTP.

Aucun appel à Gemini, aucun e-mail réel.
"""

from email.message import EmailMessage

import pytest
from fastapi.testclient import TestClient
from pydantic import SecretStr
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.ai.base import AIError, AITransientError
from app.ai.schemas import ApplicationPromptInput, GeneratedApplication
from app.api.v1.applications import get_generation_queue, get_sender
from app.core.config import Settings, get_settings
from app.models import Application, Notification, Offer, Source
from app.services import email_service
from app.services.application_service import generate_application
from app.services.collection_service import run_collection
from tests.conftest import make_http_client, rss_handler

APPS = "/api/v1/applications"


class FakeProvider:
    name = "fake"
    model = "fake-model"

    def __init__(self, result: GeneratedApplication | Exception) -> None:
        self.result = result
        self.inputs: list[ApplicationPromptInput] = []

    def generate_application(self, data: ApplicationPromptInput) -> GeneratedApplication:
        self.inputs.append(data)
        if isinstance(self.result, Exception):
            raise self.result
        return self.result


GENERATED = GeneratedApplication(
    subject="Candidature FastAPI",
    message=(
        "Bonjour,\n\nVotre mission correspond à mon profil : je développe avec FastAPI et Django "
        "et je peux vous proposer une première version rapidement. Je reste disponible pour "
        "un échange afin de préciser vos besoins et le planning.\n\nJane Dev"
    ),
    language="fr",
    referenced_skills=["fastapi", "Kubernetes"],  # Kubernetes n'est pas dans le profil
    warnings=["Budget non indiqué"],
    confidence=0.7,
)


class FakeSender:
    def __init__(self, error: Exception | None = None) -> None:
        self.error = error
        self.sent: list[EmailMessage] = []

    def __call__(self, settings: Settings, message: EmailMessage) -> None:
        if self.error is not None:
            raise self.error
        self.sent.append(message)


class FakeQueue:
    def __init__(self) -> None:
        self.enqueued: list[int] = []

    def enqueue(self, application_id: int) -> None:
        self.enqueued.append(application_id)


@pytest.fixture
def offer(db: Session, settings: Settings, rss_source: Source) -> Offer:
    with make_http_client(settings, rss_handler) as http:
        run_collection(db, rss_source.id, http, "manual")
    return db.scalars(select(Offer).order_by(Offer.id)).first()  # type: ignore[return-value]


@pytest.fixture
def sending_settings(settings: Settings) -> Settings:
    return settings.model_copy(
        update={
            "email_sending_enabled": True,
            "smtp_host": "smtp.example.com",
            "smtp_username": "dev@example.com",
            "smtp_password": SecretStr("secret-de-test"),
            "smtp_from_email": "dev@example.com",
            "smtp_from_name": "Jane Dev",
        }
    )


@pytest.fixture
def queue(client: TestClient) -> FakeQueue:
    fake = FakeQueue()
    client.app.dependency_overrides[get_generation_queue] = lambda: fake  # type: ignore[attr-defined]
    return fake


@pytest.fixture
def sender(client: TestClient, sending_settings: Settings) -> FakeSender:
    fake = FakeSender()
    client.app.dependency_overrides[get_sender] = lambda: fake  # type: ignore[attr-defined]
    client.app.dependency_overrides[get_settings] = lambda: sending_settings  # type: ignore[attr-defined]
    return fake


def _prepare_and_generate(
    client: TestClient,
    headers: dict[str, str],
    db: Session,
    settings: Settings,
    offer: Offer,
    result: GeneratedApplication | Exception = GENERATED,
) -> dict[str, object]:
    created = client.post(f"{APPS}/prepare", json={"offer_id": offer.id}, headers=headers)
    assert created.status_code == 202, created.text
    assert created.json()["status"] == "generating"
    provider = FakeProvider(result)
    generate_application(db, created.json()["id"], settings, lambda _s: provider)
    application: dict[str, object] = client.get(
        f"{APPS}/{created.json()['id']}", headers=headers
    ).json()
    return application


def _setup_profile(client: TestClient, headers: dict[str, str]) -> None:
    client.patch("/api/v1/profile", headers=headers, json={"full_name": "Jane Dev"})
    for name in ("FastAPI", "Django"):
        client.post("/api/v1/profile/skills", headers=headers, json={"name": name})


def test_prepare_generates_draft_and_notifies(
    client: TestClient,
    auth_headers: dict[str, str],
    db: Session,
    settings: Settings,
    offer: Offer,
    queue: FakeQueue,
) -> None:
    _setup_profile(client, auth_headers)
    application = _prepare_and_generate(client, auth_headers, db, settings, offer)
    assert queue.enqueued == [application["id"]]
    assert application["status"] == "pending_approval"
    assert application["offer_title"] == offer.title
    assert application["offer_url"] == offer.url
    assert application["subject"] == "Candidature FastAPI"
    assert application["generated_message"] == application["message"]
    # Seules les compétences du profil sont gardées ; l'inconnue est signalée.
    assert application["referenced_skills"] == ["FastAPI"]
    warnings = application["ai_warnings"]
    assert isinstance(warnings, list) and any("Kubernetes" in w for w in warnings)
    db.refresh(offer)
    assert offer.status == "application_prepared"

    notification = db.scalars(
        select(Notification).where(Notification.type == "application_ready")
    ).one()
    assert notification.application_id == application["id"]
    assert notification.title == "Candidature prête à valider"
    assert "destinataire à renseigner" in notification.body

    duplicate = client.post(f"{APPS}/prepare", json={"offer_id": offer.id}, headers=auth_headers)
    assert duplicate.status_code == 409


def test_prompt_uses_only_profile_data(
    client: TestClient,
    auth_headers: dict[str, str],
    db: Session,
    settings: Settings,
    offer: Offer,
    queue: FakeQueue,
) -> None:
    _setup_profile(client, auth_headers)
    created = client.post(f"{APPS}/prepare", json={"offer_id": offer.id}, headers=auth_headers)
    provider = FakeProvider(GENERATED)
    generate_application(db, created.json()["id"], settings, lambda _s: provider)
    data = provider.inputs[0]
    assert data.candidate_name == "Jane Dev"
    assert [s["name"] for s in data.candidate_skills] == ["Django", "FastAPI"]
    assert data.offer_title == offer.title


def test_generation_failure_is_recorded_and_notified(
    client: TestClient,
    auth_headers: dict[str, str],
    db: Session,
    settings: Settings,
    offer: Offer,
    queue: FakeQueue,
) -> None:
    application = _prepare_and_generate(
        client, auth_headers, db, settings, offer, AIError("Quota Gemini atteint.")
    )
    assert application["status"] == "generation_failed"
    assert application["error_message"] == "Quota Gemini atteint."
    assert db.scalars(select(Notification).where(Notification.type == "application_failed")).one()
    again = client.post(f"{APPS}/{application['id']}/regenerate", headers=auth_headers)
    assert again.status_code == 202
    assert again.json()["status"] == "generating"


def test_send_requires_enabled_confirmation_and_recipient(
    client: TestClient,
    auth_headers: dict[str, str],
    db: Session,
    settings: Settings,
    offer: Offer,
    queue: FakeQueue,
) -> None:
    application = _prepare_and_generate(client, auth_headers, db, settings, offer)
    url = f"{APPS}/{application['id']}/send"
    # Envoi désactivé par défaut côté serveur.
    disabled = client.post(url, json={"confirm": True}, headers=auth_headers)
    assert disabled.status_code == 409
    assert "EMAIL_SENDING_ENABLED" in disabled.json()["error"]["message"]
    # Confirmation explicite obligatoire.
    assert client.post(url, json={}, headers=auth_headers).status_code == 422
    assert client.post(url, json={"confirm": False}, headers=auth_headers).status_code == 422


def test_send_success_records_exact_content_and_notifies(
    client: TestClient,
    auth_headers: dict[str, str],
    db: Session,
    settings: Settings,
    offer: Offer,
    queue: FakeQueue,
    sender: FakeSender,
) -> None:
    application = _prepare_and_generate(client, auth_headers, db, settings, offer)
    url = f"{APPS}/{application['id']}"
    no_recipient = client.post(f"{url}/send", json={"confirm": True}, headers=auth_headers)
    assert no_recipient.status_code == 422

    edited = client.patch(
        url,
        headers=auth_headers,
        json={"recipient_email": "client@example.org", "message": "Texte relu et corrigé."},
    )
    assert edited.status_code == 200

    sent = client.post(f"{url}/send", json={"confirm": True}, headers=auth_headers)
    assert sent.status_code == 200, sent.text
    body = sent.json()
    assert body["status"] == "sent"
    assert body["sent_to"] == "client@example.org"
    assert body["sent_message"] == "Texte relu et corrigé."
    assert body["sent_from"] == "dev@example.com"

    (message,) = sender.sent
    assert message["To"] == "client@example.org"
    assert message["From"] == "Jane Dev <dev@example.com>"
    assert message["Message-ID"].endswith("@example.com>")

    db.refresh(offer)
    assert offer.status == "application_sent"
    notification = db.scalars(
        select(Notification).where(Notification.type == "application_sent")
    ).one()
    assert notification.title == "Candidature envoyée"
    assert notification.body.endswith("→ client@example.org")

    # Jamais de double envoi, et plus de modification possible.
    again = client.post(f"{url}/send", json={"confirm": True}, headers=auth_headers)
    assert again.status_code == 409
    assert len(sender.sent) == 1
    assert client.patch(url, headers=auth_headers, json={"subject": "x"}).status_code == 409
    assert client.post(f"{url}/cancel", headers=auth_headers).status_code == 409


@pytest.mark.parametrize(
    ("error", "status"),
    [
        (email_service.SmtpRejectedError("Destinataire refusé par le serveur SMTP."), "failed"),
        (
            email_service.SmtpUncertainError("Connexion interrompue pendant l'envoi."),
            "delivery_unknown",
        ),
    ],
)
def test_send_failures(
    client: TestClient,
    auth_headers: dict[str, str],
    db: Session,
    settings: Settings,
    offer: Offer,
    queue: FakeQueue,
    sender: FakeSender,
    error: Exception,
    status: str,
) -> None:
    application = _prepare_and_generate(client, auth_headers, db, settings, offer)
    url = f"{APPS}/{application['id']}"
    client.patch(url, headers=auth_headers, json={"recipient_email": "client@example.org"})
    sender.error = error
    result = client.post(f"{url}/send", json={"confirm": True}, headers=auth_headers).json()
    assert result["status"] == status
    assert result["sent_at"] is None
    assert db.scalars(select(Notification).where(Notification.type == "application_failed")).one()

    sender.error = None
    retry = client.post(f"{url}/send", json={"confirm": True}, headers=auth_headers)
    if status == "failed":
        assert retry.json()["status"] == "sent"  # nouvelle tentative contrôlée, à la demande
    else:
        assert retry.status_code == 409  # résultat incertain : jamais renvoyé
        assert sender.sent == []


def test_daily_limit(
    client: TestClient,
    auth_headers: dict[str, str],
    db: Session,
    settings: Settings,
    offer: Offer,
    queue: FakeQueue,
    sender: FakeSender,
    sending_settings: Settings,
) -> None:
    client.app.dependency_overrides[get_settings] = lambda: sending_settings.model_copy(  # type: ignore[attr-defined]
        update={"email_daily_limit": 1}
    )
    offers = db.scalars(select(Offer).order_by(Offer.id)).all()
    for target in offers[:2]:
        created = client.post(f"{APPS}/prepare", json={"offer_id": target.id}, headers=auth_headers)
        generate_application(db, created.json()["id"], settings, lambda _s: FakeProvider(GENERATED))
        client.patch(
            f"{APPS}/{created.json()['id']}",
            headers=auth_headers,
            json={"recipient_email": "client@example.org"},
        )
    ids = [a["id"] for a in client.get(APPS, headers=auth_headers).json()["items"]]
    assert (
        client.post(f"{APPS}/{ids[0]}/send", json={"confirm": True}, headers=auth_headers).json()[
            "status"
        ]
        == "sent"
    )
    limited = client.post(f"{APPS}/{ids[1]}/send", json={"confirm": True}, headers=auth_headers)
    assert limited.status_code == 429


def test_applications_are_isolated(
    client: TestClient,
    auth_headers: dict[str, str],
    db: Session,
    settings: Settings,
    offer: Offer,
    queue: FakeQueue,
) -> None:
    from app.services.user_service import create_user
    from tests.conftest import TEST_PASSWORD

    application = _prepare_and_generate(client, auth_headers, db, settings, offer)
    create_user(db, "other@example.com", TEST_PASSWORD)
    tokens = client.post(
        "/api/v1/auth/login", json={"email": "other@example.com", "password": TEST_PASSWORD}
    ).json()
    other = {"Authorization": f"Bearer {tokens['access_token']}"}
    url = f"{APPS}/{application['id']}"
    assert client.get(url, headers=other).status_code == 404
    assert client.patch(url, headers=other, json={"subject": "x"}).status_code == 404
    assert client.post(f"{url}/send", json={"confirm": True}, headers=other).status_code == 404
    assert client.get(APPS, headers=other).json()["total"] == 0
    stored = db.get(Application, application["id"])
    assert stored is not None and stored.status == "pending_approval"


def test_transient_ai_error_is_retried_then_recorded(
    client: TestClient,
    auth_headers: dict[str, str],
    db: Session,
    settings: Settings,
    offer: Offer,
    queue: FakeQueue,
) -> None:
    created = client.post(f"{APPS}/prepare", json={"offer_id": offer.id}, headers=auth_headers)
    application_id = created.json()["id"]
    provider = FakeProvider(AITransientError("Gemini est indisponible (HTTP 503)."))

    # Tentatives intermédiaires : l'erreur remonte (la tâche Celery réessaiera), rien n'est écrit.
    with pytest.raises(AITransientError):
        generate_application(
            db, application_id, settings, lambda _s: provider, raise_transient=True
        )
    assert (
        client.get(f"{APPS}/{application_id}", headers=auth_headers).json()["status"]
        == "generating"
    )
    assert db.scalars(select(Notification)).all() == [] or all(
        n.type == "new_offers" for n in db.scalars(select(Notification))
    )

    # Dernière tentative : échec enregistré et notifié.
    generate_application(db, application_id, settings, lambda _s: provider)
    final = client.get(f"{APPS}/{application_id}", headers=auth_headers).json()
    assert final["status"] == "generation_failed"
    assert "503" in final["error_message"]
