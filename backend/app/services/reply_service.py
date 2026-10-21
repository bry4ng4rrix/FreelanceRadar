"""Réponses des clients : association prudente des messages reçus aux candidatures envoyées.

Ordre d'association (`notifications.md` §6) :
1. en-têtes In-Reply-To / References contenant le Message-ID d'une candidature envoyée ;
2. à défaut, expéditeur = destinataire de la candidature ET objet « Re: <objet envoyé> » ;
3. plusieurs candidatures possibles : message ignoré (ambigu), jamais deviné.
Seuls les messages associés sont enregistrés ; les autres e-mails ne sont pas conservés.
"""

import logging
import re
from collections.abc import Callable
from contextlib import AbstractContextManager
from dataclasses import dataclass, field
from datetime import datetime
from email import message_from_bytes, policy
from email.message import EmailMessage
from email.utils import parseaddr, parsedate_to_datetime

from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.collectors.normalize import html_to_text
from app.core.config import Settings
from app.db.base import utcnow
from app.models import Application, EmailSyncState, ReceivedReply
from app.services.imap_service import ImapError, Mailbox, imap_credentials
from app.services.notification_service import notify_user

logger = logging.getLogger(__name__)

MailboxFactory = Callable[[Settings], AbstractContextManager[Mailbox]]

_REPLY_PREFIX = re.compile(r"^\s*((re|r|aw|sv|tr|fwd?|wg)\s*(\[\d+\])?\s*:\s*)+", re.IGNORECASE)
_MESSAGE_ID = re.compile(r"<[^<>\s]+>")
_MAX_BODY = 20_000


@dataclass
class SyncResult:
    scanned: int = 0
    stored: int = 0
    ambiguous: int = 0
    errors: list[str] = field(default_factory=list)


def _parse(raw: bytes) -> EmailMessage:
    message = message_from_bytes(raw, policy=policy.default)
    if not isinstance(message, EmailMessage):  # toujours vrai avec policy.default
        raise ImapError("Message illisible.")
    return message


def normalize_subject(subject: str) -> str:
    return re.sub(r"\s+", " ", _REPLY_PREFIX.sub("", subject or "")).strip().casefold()


def _message_ids(*values: str | None) -> list[str]:
    ids: list[str] = []
    for value in values:
        ids += _MESSAGE_ID.findall(value or "")
    return ids


def _text_body(message: EmailMessage) -> str:
    """Texte du message (partie texte, sinon HTML converti). Pièces jointes ignorées."""
    part = message.get_body(preferencelist=("plain", "html"))
    if part is None:
        return ""
    try:
        content = part.get_content()
    except (LookupError, ValueError):
        return ""
    text = str(content)
    if part.get_content_type() == "text/html":
        text = html_to_text(text)
    return text.strip()[:_MAX_BODY]


def match_application(db: Session, headers: EmailMessage) -> tuple[Application, str] | None:
    """Candidature à laquelle répond ce message, et méthode d'association."""
    references = _message_ids(headers.get("In-Reply-To"), headers.get("References"))
    if references:
        by_header = db.scalars(
            select(Application).where(Application.smtp_message_id.in_(references))
        ).all()
        if len(by_header) == 1:
            return by_header[0], "headers"
    sender = parseaddr(str(headers.get("From", "")))[1].casefold()
    subject = normalize_subject(str(headers.get("Subject", "")))
    if not sender or not subject:
        return None
    candidates = [
        application
        for application in db.scalars(
            select(Application).where(
                func.lower(Application.sent_to) == sender,
                Application.status.in_(("sent", "replied")),
            )
        )
        if normalize_subject(application.sent_subject or "") == subject
    ]
    if len(candidates) == 1:
        return candidates[0], "sender_subject"
    if len(candidates) > 1:
        raise _AmbiguousReplyError
    return None


class _AmbiguousReplyError(Exception):
    pass


def _state(db: Session, account: str, folder: str) -> EmailSyncState:
    state = db.scalar(
        select(EmailSyncState).where(
            EmailSyncState.account == account, EmailSyncState.folder == folder
        )
    )
    if state is None:
        state = EmailSyncState(account=account, folder=folder, last_uid=0)
        db.add(state)
        db.flush()
    return state


def _store_reply(
    db: Session, application: Application, method: str, uid_message: bytes, message_id: str
) -> ReceivedReply | None:
    message = _parse(uid_message)
    name, address = parseaddr(str(message.get("From", "")))
    received_at: datetime | None
    try:
        received_at = parsedate_to_datetime(str(message.get("Date")))
    except (TypeError, ValueError):
        received_at = None
    stmt = (
        insert(ReceivedReply)
        .values(
            user_id=application.user_id,
            application_id=application.id,
            message_id=message_id[:500],
            from_address=address[:320] or "inconnu",
            from_name=name[:300] or None,
            subject=str(message.get("Subject", ""))[:500],
            body_text=_text_body(message),
            received_at=received_at,
            match_method=method,
        )
        .on_conflict_do_nothing(index_elements=["message_id"])
        .returning(ReceivedReply.id)
    )
    row = db.execute(stmt).first()
    return db.get(ReceivedReply, row[0]) if row else None


def sync_replies(db: Session, settings: Settings, mailbox_factory: MailboxFactory) -> SyncResult:
    """Lit les nouveaux messages du dossier et enregistre les réponses aux candidatures."""
    result = SyncResult()
    credentials = imap_credentials(settings)
    if credentials is None:
        result.errors.append("IMAP non configuré.")
        return result
    state = _state(db, credentials[0], settings.imap_folder)
    # Aucune candidature envoyée : rien ne peut être une réponse, on n'ouvre même pas la boîte.
    first_sent = db.scalar(select(func.min(Application.sent_at)))
    try:
        with mailbox_factory(settings) as mailbox:
            status = mailbox.status()
            if state.uidvalidity != status.uidvalidity:
                # Nouveau dossier (ou renuméroté) : on repart du début, borné par la date d'envoi.
                state.uidvalidity = status.uidvalidity
                state.last_uid = 0
            if first_sent is None:
                state.last_uid = max(state.last_uid, status.uidnext - 1)
            else:
                since = first_sent.strftime("%d-%b-%Y")
                uids = mailbox.search_uids(state.last_uid, since)[: settings.imap_batch_size]
                for uid in uids:
                    _process(db, mailbox, uid, result)
                    state.last_uid = uid
                    db.commit()
        state.last_error = None
    except ImapError as exc:
        db.rollback()
        state = _state(db, credentials[0], settings.imap_folder)
        state.last_error = str(exc)
        result.errors.append(str(exc))
        logger.warning("Synchronisation IMAP impossible : %s", exc)
    state.last_sync_at = utcnow()
    db.commit()
    return result


def _process(db: Session, mailbox: Mailbox, uid: int, result: SyncResult) -> None:
    result.scanned += 1
    headers = _parse(mailbox.fetch_headers(uid))
    message_id = (_message_ids(str(headers.get("Message-ID", ""))) or [f"<uid-{uid}@imap>"])[0]
    try:
        match = match_application(db, headers)
    except _AmbiguousReplyError:
        result.ambiguous += 1
        logger.info("Réponse ambiguë ignorée (UID %s) : plusieurs candidatures possibles.", uid)
        return
    if match is None:
        return  # message sans rapport avec une candidature : non conservé
    application, method = match
    reply = _store_reply(db, application, method, mailbox.fetch_message(uid), message_id)
    if reply is None:
        return  # déjà enregistré
    result.stored += 1
    if application.status == "sent":
        application.status = "replied"
    sender = reply.from_name or reply.from_address
    notify_user(
        db,
        application.user_id,
        type="reply_received",
        title="Nouvelle réponse reçue",
        body=f"{sender} — {reply.subject or application.offer_title}"[:300],
        dedup_key=f"reply:{reply.id}",
        offer_id=application.offer_id,
        application_id=application.id,
    )
