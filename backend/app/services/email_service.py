"""Messagerie SMTP.

Pour l'instant : vérification de la configuration (connexion chiffrée + authentification),
sans jamais envoyer de message. L'envoi des candidatures viendra avec FR-041.
"""

import smtplib
import ssl
from dataclasses import dataclass

from app.core.config import Settings


@dataclass(frozen=True)
class SmtpCheckResult:
    ok: bool
    message: str


def check_smtp_connection(settings: Settings) -> SmtpCheckResult:
    """Ouvre une connexion TLS, s'authentifie puis se déconnecte. N'envoie aucun e-mail.

    Le message renvoyé ne contient jamais le mot de passe.
    """
    if not settings.smtp_host or not settings.smtp_username or settings.smtp_password is None:
        return SmtpCheckResult(
            False, "SMTP non configuré (SMTP_HOST, SMTP_USERNAME, SMTP_PASSWORD)."
        )
    context = ssl.create_default_context()  # certificat et nom d'hôte vérifiés
    target = f"{settings.smtp_host}:{settings.smtp_port} ({settings.smtp_security})"
    try:
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
        with client:
            client.login(settings.smtp_username, settings.smtp_password.get_secret_value())
    except smtplib.SMTPAuthenticationError:
        return SmtpCheckResult(False, f"Authentification refusée par {target}.")
    except (smtplib.SMTPException, OSError) as exc:
        return SmtpCheckResult(False, f"Connexion impossible à {target} : {type(exc).__name__}.")
    return SmtpCheckResult(
        True, f"Connexion et authentification réussies sur {target} (aucun e-mail envoyé)."
    )
