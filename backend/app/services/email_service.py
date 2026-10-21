"""Messagerie SMTP : vérification de la configuration et envoi d'un message.

Aucun message ne part si EMAIL_SENDING_ENABLED est faux (contrôlé par l'appelant, voir
`application_service.send_application`). Les messages d'erreur ne contiennent jamais de secret.
"""

import smtplib
import ssl
from dataclasses import dataclass
from email.message import EmailMessage
from email.utils import formataddr, formatdate, make_msgid

from app.core.config import Settings


@dataclass(frozen=True)
class SmtpCheckResult:
    ok: bool
    message: str


class SmtpNotConfiguredError(Exception):
    pass


class SmtpRejectedError(Exception):
    """Refus certain (connexion, authentification, destinataire, contenu) : rien n'est parti."""


class SmtpUncertainError(Exception):
    """Coupure pendant la transmission : le message a peut-être été accepté. Ne pas renvoyer."""


def _target(settings: Settings) -> str:
    return f"{settings.smtp_host}:{settings.smtp_port} ({settings.smtp_security})"


def _connect(settings: Settings) -> smtplib.SMTP:
    """Connexion chiffrée (certificat et nom d'hôte vérifiés) et authentifiée."""
    if not settings.smtp_host or not settings.smtp_username or settings.smtp_password is None:
        raise SmtpNotConfiguredError(
            "SMTP non configuré (SMTP_HOST, SMTP_USERNAME, SMTP_PASSWORD)."
        )
    context = ssl.create_default_context()
    if settings.smtp_security == "ssl":
        client: smtplib.SMTP = smtplib.SMTP_SSL(
            settings.smtp_host,
            settings.smtp_port,
            timeout=settings.smtp_timeout_seconds,
            context=context,
        )
    else:
        client = smtplib.SMTP(
            settings.smtp_host, settings.smtp_port, timeout=settings.smtp_timeout_seconds
        )
        client.starttls(context=context)
    client.login(settings.smtp_username, settings.smtp_password.get_secret_value())
    return client


def check_smtp_connection(settings: Settings) -> SmtpCheckResult:
    """Ouvre une connexion TLS, s'authentifie puis se déconnecte. N'envoie aucun e-mail."""
    try:
        with _connect(settings):
            pass
    except SmtpNotConfiguredError as exc:
        return SmtpCheckResult(False, str(exc))
    except smtplib.SMTPAuthenticationError:
        return SmtpCheckResult(False, f"Authentification refusée par {_target(settings)}.")
    except (smtplib.SMTPException, OSError) as exc:
        return SmtpCheckResult(
            False, f"Connexion impossible à {_target(settings)} : {type(exc).__name__}."
        )
    return SmtpCheckResult(
        True,
        f"Connexion et authentification réussies sur {_target(settings)} (aucun e-mail envoyé).",
    )


def build_message(settings: Settings, *, to: str, subject: str, body: str) -> EmailMessage:
    """Message texte UTF-8 avec un Message-ID unique (conservé pour associer les réponses)."""
    if not settings.smtp_from_email:
        raise SmtpNotConfiguredError("Adresse d'expédition absente (SMTP_FROM_EMAIL).")
    message = EmailMessage()
    message["From"] = formataddr((settings.smtp_from_name or "", settings.smtp_from_email))
    message["To"] = to
    message["Subject"] = subject
    message["Date"] = formatdate(localtime=True)
    message["Message-ID"] = make_msgid(domain=settings.smtp_from_email.rsplit("@", 1)[-1])
    message.set_content(body)
    return message


def send_message(settings: Settings, message: EmailMessage) -> None:
    """Transmet le message. Lève SmtpRejectedError (rien n'est parti) ou SmtpUncertainError."""
    try:
        client = _connect(settings)
    except SmtpNotConfiguredError:
        raise
    except smtplib.SMTPAuthenticationError as exc:
        raise SmtpRejectedError(f"Authentification refusée par {_target(settings)}.") from exc
    except (smtplib.SMTPException, OSError) as exc:
        raise SmtpRejectedError(
            f"Connexion impossible à {_target(settings)} : {type(exc).__name__}."
        ) from exc
    with client:
        try:
            client.send_message(message)
        except smtplib.SMTPRecipientsRefused as exc:
            raise SmtpRejectedError("Destinataire refusé par le serveur SMTP.") from exc
        except smtplib.SMTPSenderRefused as exc:
            raise SmtpRejectedError("Expéditeur refusé par le serveur SMTP.") from exc
        except smtplib.SMTPDataError as exc:
            raise SmtpRejectedError(
                f"Message refusé par le serveur SMTP (code {exc.smtp_code})."
            ) from exc
        except (smtplib.SMTPException, OSError) as exc:
            raise SmtpUncertainError(
                f"Connexion interrompue pendant l'envoi ({type(exc).__name__}) : "
                "vérifiez le dossier « Envoyés » avant de réessayer."
            ) from exc
