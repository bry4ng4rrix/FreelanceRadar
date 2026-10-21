"""Réponses aux candidatures lues sur une fausse boîte IMAP (aucune connexion réelle)."""

from collections.abc import Iterator
from contextlib import contextmanager
from email.message import EmailMessage

import pytest
from fastapi.testclient import TestClient
from pydantic import SecretStr
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.models import Application, EmailSyncState, Notification, Offer, ReceivedReply, User
from app.services.application_service import generate_application, send_application
from app.services.imap_service import ImapError, MailboxStatus
from app.services.reply_service import normalize_subject, sync_replies
from tests.integration.test_applications import GENERATED, FakeProvider, FakeSender

REPLIES = "/api/v1/replies"


def _mail(
    uid: int,
    *,
    sender: str = "Client <client@example.org>",
    subject: str = "Re: Candidature FastAPI",
    in_reply_to: str | None = None,
    html: bool = False,
) -> bytes:
    message = EmailMessage()
    message["From"] = sender
    message["To"] = "dev@example.com"
    message["Subject"] = subject
    message["Message-ID"] = f"<reply-{uid}@example.org>"
    message["Date"] = "Tue, 20 Oct 2026 10:00:00 +0000"
    if in_reply_to:
        message["In-Reply-To"] = in_reply_to
        message["References"] = in_reply_to
    if html:
        message.set_content("<p>Bonjour, <b>disponible</b> mardi ?</p>", subtype="html")
    else:
        message.set_content("Bonjour, êtes-vous disponible mardi ?")
    return message.as_bytes()


class FakeMailbox:
    """Boîte simulée ; ne propose que des lectures (comme EXAMINE + BODY.PEEK)."""

    def __init__(self, messages: dict[int, bytes], uidvalidity: int = 1) -> None:
        self.messages = messages
        self.uidvalidity = uidvalidity
        self.full_fetches: list[int] = []

    def status(self) -> MailboxStatus:
        return MailboxStatus(self.uidvalidity, max(self.messages, default=0) + 1)

    def search_uids(self, since_uid: int, since_date: str | None) -> list[int]:
        return sorted(uid for uid in self.messages if uid > since_uid)

    def fetch_headers(self, uid: int) -> bytes:
        return self.messages[uid].split(b"\n\n", 1)[0] + b"\n\n"

    def fetch_message(self, uid: int) -> bytes:
        self.full_fetches.append(uid)
        return self.messages[uid]

    def factory(self) -> object:
        @contextmanager
        def open_(_settings: Settings) -> Iterator["FakeMailbox"]:
            yield self

        return open_


@pytest.fixture
def imap_settings(settings: Settings) -> Settings:
    return settings.model_copy(
        update={
            "email_sending_enabled": True,
            "email_sync_enabled": True,
            "smtp_host": "smtp.example.com",
            "smtp_username": "dev@example.com",
            "smtp_password": SecretStr("secret"),
            "smtp_from_email": "dev@example.com",
            "imap_host": "imap.example.com",
        }
    )


def _sent_application(db: Session, settings: Settings, offer: Offer, user: User) -> Application:
    application = Application(user_id=user.id, offer_id=offer.id, status="generating")
    db.add(application)
    db.commit()
    generate_application(db, application.id, settings, lambda _s: FakeProvider(GENERATED))
    application.recipient_email = "client@example.org"
    db.commit()
    return send_application(db, user, application.id, settings, FakeSender())


@pytest.fixture
def user(db: Session, user_email: str) -> User:
    return db.scalars(select(User).where(User.email == user_email)).one()


@pytest.fixture
def first_offer(db: Session, settings: Settings, rss_source: object) -> Offer:
    from app.services.collection_service import run_collection
    from tests.conftest import make_http_client, rss_handler

    with make_http_client(settings, rss_handler) as http:
        run_collection(db, rss_source.id, http, "manual")  # type: ignore[attr-defined]
    return db.scalars(select(Offer).order_by(Offer.id)).first()  # type: ignore[return-value]


def test_normalize_subject() -> None:
    assert normalize_subject("RE: Re:  Candidature FastAPI") == "candidature fastapi"
    assert normalize_subject("TR: Fwd: Candidature") == "candidature"


def test_reply_matched_by_headers_is_stored_and_notified(
    db: Session, imap_settings: Settings, first_offer: Offer, user: User
) -> None:
    application = _sent_application(db, imap_settings, first_offer, user)
    mailbox = FakeMailbox(
        {
            5: _mail(5, sender="Autre <newsletter@example.net>", subject="Promo"),
            6: _mail(6, in_reply_to=application.smtp_message_id, subject="Votre profil", html=True),
        }
    )
    result = sync_replies(db, imap_settings, mailbox.factory())  # type: ignore[arg-type]
    assert (result.scanned, result.stored) == (2, 1)
    assert mailbox.full_fetches == [6]  # le message sans rapport n'est jamais lu en entier

    reply = db.scalars(select(ReceivedReply)).one()
    assert reply.application_id == application.id
    assert reply.match_method == "headers"
    assert reply.from_address == "client@example.org"
    assert reply.body_text == "Bonjour, disponible mardi ?"
    db.refresh(application)
    assert application.status == "replied"
    notification = db.scalars(
        select(Notification).where(Notification.type == "reply_received")
    ).one()
    assert notification.application_id == application.id
    assert notification.title == "Nouvelle réponse reçue"

    # Nouvelle synchronisation : rien n'est relu ni dupliqué.
    again = sync_replies(db, imap_settings, mailbox.factory())  # type: ignore[arg-type]
    assert again.scanned == 0
    assert len(db.scalars(select(ReceivedReply)).all()) == 1


def test_reply_matched_by_sender_and_subject(
    db: Session, imap_settings: Settings, first_offer: Offer, user: User
) -> None:
    application = _sent_application(db, imap_settings, first_offer, user)
    mailbox = FakeMailbox({3: _mail(3, subject="RE: Candidature FastAPI")})
    sync_replies(db, imap_settings, mailbox.factory())  # type: ignore[arg-type]
    reply = db.scalars(select(ReceivedReply)).one()
    assert reply.match_method == "sender_subject"
    assert reply.application_id == application.id


def test_ambiguous_reply_is_ignored(
    db: Session, imap_settings: Settings, first_offer: Offer, user: User
) -> None:
    _sent_application(db, imap_settings, first_offer, user)
    other_offer = db.scalars(select(Offer).where(Offer.id != first_offer.id)).first()
    assert other_offer is not None
    _sent_application(db, imap_settings, other_offer, user)  # même destinataire, même objet
    mailbox = FakeMailbox({4: _mail(4, subject="Re: Candidature FastAPI")})
    result = sync_replies(db, imap_settings, mailbox.factory())  # type: ignore[arg-type]
    assert (result.stored, result.ambiguous) == (0, 1)
    assert db.scalars(select(ReceivedReply)).all() == []


def test_without_sent_application_nothing_is_read(
    db: Session, imap_settings: Settings, user: User
) -> None:
    mailbox = FakeMailbox({1: _mail(1), 2: _mail(2)})
    result = sync_replies(db, imap_settings, mailbox.factory())  # type: ignore[arg-type]
    assert result.scanned == 0
    state = db.scalars(select(EmailSyncState)).one()
    assert state.last_uid == 2  # les messages antérieurs ne seront jamais analysés


def test_uidvalidity_change_restarts_scan(
    db: Session, imap_settings: Settings, first_offer: Offer, user: User
) -> None:
    application = _sent_application(db, imap_settings, first_offer, user)
    mailbox = FakeMailbox({7: _mail(7, subject="Sans rapport")})
    sync_replies(db, imap_settings, mailbox.factory())  # type: ignore[arg-type]
    renumbered = FakeMailbox({1: _mail(1, in_reply_to=application.smtp_message_id)}, uidvalidity=2)
    result = sync_replies(db, imap_settings, renumbered.factory())  # type: ignore[arg-type]
    assert result.stored == 1


def test_imap_error_is_recorded(db: Session, imap_settings: Settings, user: User) -> None:
    @contextmanager
    def broken(_settings: Settings) -> Iterator[FakeMailbox]:
        raise ImapError("Connexion IMAP refusée par imap.example.com:993.")
        yield  # pragma: no cover

    result = sync_replies(db, imap_settings, broken)
    assert result.errors == ["Connexion IMAP refusée par imap.example.com:993."]
    state = db.scalars(select(EmailSyncState)).one()
    assert state.last_error is not None and state.last_sync_at is not None


def test_replies_api_and_isolation(
    client: TestClient,
    auth_headers: dict[str, str],
    db: Session,
    imap_settings: Settings,
    first_offer: Offer,
    user: User,
) -> None:
    application = _sent_application(db, imap_settings, first_offer, user)
    mailbox = FakeMailbox({8: _mail(8, in_reply_to=application.smtp_message_id)})
    sync_replies(db, imap_settings, mailbox.factory())  # type: ignore[arg-type]

    page = client.get(REPLIES, headers=auth_headers).json()
    assert page["total"] == 1
    reply = page["items"][0]
    assert reply["offer_title"] == first_offer.title
    assert reply["read_at"] is None
    by_app = client.get(REPLIES, params={"application_id": application.id}, headers=auth_headers)
    assert by_app.json()["total"] == 1
    read = client.patch(f"{REPLIES}/{reply['id']}/read", headers=auth_headers).json()
    assert read["read_at"] is not None
    assert (
        client.get(REPLIES, params={"unread_only": True}, headers=auth_headers).json()["total"] == 0
    )

    from app.services.user_service import create_user
    from tests.conftest import TEST_PASSWORD

    create_user(db, "other@example.com", TEST_PASSWORD)
    tokens = client.post(
        "/api/v1/auth/login", json={"email": "other@example.com", "password": TEST_PASSWORD}
    ).json()
    other = {"Authorization": f"Bearer {tokens['access_token']}"}
    assert client.get(REPLIES, headers=other).json()["total"] == 0
    assert client.patch(f"{REPLIES}/{reply['id']}/read", headers=other).status_code == 404
