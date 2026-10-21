"""Lecture IMAP en lecture seule (EXAMINE + BODY.PEEK : aucun message n'est marqué comme lu)."""

import imaplib
import ssl
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import dataclass
from typing import Protocol

from app.core.config import Settings


class ImapError(Exception):
    """Échec IMAP. Le message ne contient jamais d'identifiant ni de mot de passe."""


@dataclass(frozen=True)
class MailboxStatus:
    uidvalidity: int
    uidnext: int


class Mailbox(Protocol):
    """Opérations utilisées par la synchronisation (remplaçables par une fausse boîte en test)."""

    def status(self) -> MailboxStatus: ...
    def search_uids(self, since_uid: int, since_date: str | None) -> list[int]: ...
    def fetch_headers(self, uid: int) -> bytes: ...
    def fetch_message(self, uid: int) -> bytes: ...


def imap_credentials(settings: Settings) -> tuple[str, str] | None:
    """Identifiants IMAP, à défaut ceux du compte SMTP (même boîte)."""
    username = settings.imap_username or settings.smtp_username
    password = settings.imap_password or settings.smtp_password
    if not settings.imap_host or not username or password is None:
        return None
    return username, password.get_secret_value()


class ImapMailbox:
    """Dossier ouvert en lecture seule sur une connexion authentifiée."""

    HEADER_FIELDS = "(MESSAGE-ID IN-REPLY-TO REFERENCES FROM SUBJECT DATE)"

    def __init__(self, client: imaplib.IMAP4, folder: str) -> None:
        self._client = client
        self._folder = folder

    def status(self) -> MailboxStatus:
        typ, data = self._client.status(_quote(self._folder), "(UIDVALIDITY UIDNEXT)")
        if typ != "OK" or not data or data[0] is None:
            raise ImapError("Statut du dossier IMAP illisible.")
        raw = data[0].decode() if isinstance(data[0], bytes) else str(data[0])
        values = raw[raw.index("(") + 1 : raw.rindex(")")].split()
        fields = dict(zip(values[::2], values[1::2], strict=False))
        return MailboxStatus(int(fields["UIDVALIDITY"]), int(fields["UIDNEXT"]))

    def search_uids(self, since_uid: int, since_date: str | None) -> list[int]:
        criteria = ["UID", f"{since_uid + 1}:*"]
        if since_date:
            criteria += ["SINCE", since_date]
        typ, data = self._client.uid("SEARCH", *criteria)
        if typ != "OK":
            raise ImapError("Recherche IMAP refusée.")
        uids = [int(x) for x in (data[0] or b"").split()]
        # « n:* » renvoie toujours le dernier message, même s'il est antérieur à n.
        return sorted(uid for uid in uids if uid > since_uid)

    def fetch_headers(self, uid: int) -> bytes:
        return self._fetch(uid, f"(BODY.PEEK[HEADER.FIELDS {self.HEADER_FIELDS}])")

    def fetch_message(self, uid: int) -> bytes:
        return self._fetch(uid, "(BODY.PEEK[])")

    def _fetch(self, uid: int, parts: str) -> bytes:
        typ, data = self._client.uid("FETCH", str(uid), parts)
        if typ != "OK":
            raise ImapError("Lecture IMAP refusée.")
        for item in data:
            if isinstance(item, tuple) and len(item) == 2 and isinstance(item[1], bytes):
                return item[1]
        return b""


def _quote(folder: str) -> str:
    return '"' + folder.replace("\\", "\\\\").replace('"', '\\"') + '"'


@contextmanager
def open_mailbox(settings: Settings) -> Iterator[ImapMailbox]:
    """Connexion TLS (certificat vérifié), authentification, dossier en lecture seule."""
    credentials = imap_credentials(settings)
    if credentials is None or settings.imap_host is None:
        raise ImapError("IMAP non configuré (IMAP_HOST et identifiants).")
    context = ssl.create_default_context()
    target = f"{settings.imap_host}:{settings.imap_port}"
    try:
        if settings.imap_security == "ssl":
            client: imaplib.IMAP4 = imaplib.IMAP4_SSL(
                settings.imap_host, settings.imap_port, ssl_context=context, timeout=30
            )
        else:
            client = imaplib.IMAP4(settings.imap_host, settings.imap_port, timeout=30)
            client.starttls(ssl_context=context)
        client.login(*credentials)
        typ, _ = client.select(_quote(settings.imap_folder), readonly=True)
        if typ != "OK":
            raise ImapError(f"Dossier « {settings.imap_folder} » introuvable.")
    except imaplib.IMAP4.error as exc:
        raise ImapError(f"Connexion IMAP refusée par {target}.") from exc
    except OSError as exc:
        raise ImapError(f"Serveur IMAP injoignable ({target}) : {type(exc).__name__}.") from exc
    try:
        yield ImapMailbox(client, settings.imap_folder)
    finally:
        try:
            client.logout()
        except (imaplib.IMAP4.error, OSError):
            pass
