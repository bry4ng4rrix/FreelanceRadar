"""Vérification SMTP avec un serveur simulé : aucun réseau, aucun e-mail envoyé."""

import smtplib
from typing import Any

import pytest
from pydantic import SecretStr

from app.core.config import Settings
from app.services import email_service

SECRET = "mot-de-passe-de-test"  # noqa: S105  # donnée fictive


class FakeSMTP:
    """Remplace smtplib.SMTP / SMTP_SSL et enregistre les appels."""

    instances: list["FakeSMTP"] = []
    fail_login = False

    def __init__(self, host: str, port: int, **kwargs: Any) -> None:
        self.host, self.port, self.kwargs = host, port, kwargs
        self.calls: list[str] = []
        FakeSMTP.instances.append(self)

    def __enter__(self) -> "FakeSMTP":
        return self

    def __exit__(self, *_: object) -> None:
        self.calls.append("quit")

    def starttls(self, context: Any) -> None:
        self.calls.append("starttls")

    def login(self, user: str, password: str) -> None:
        self.calls.append(f"login:{user}")
        if FakeSMTP.fail_login:
            raise smtplib.SMTPAuthenticationError(535, b"bad credentials")

    def sendmail(self, *args: object) -> None:  # ne doit jamais être appelé
        self.calls.append("sendmail")


@pytest.fixture(autouse=True)
def fake_smtp(monkeypatch: pytest.MonkeyPatch) -> None:
    FakeSMTP.instances = []
    FakeSMTP.fail_login = False
    monkeypatch.setattr(smtplib, "SMTP", FakeSMTP)
    monkeypatch.setattr(smtplib, "SMTP_SSL", FakeSMTP)


def _settings(settings: Settings, **changes: object) -> Settings:
    base: dict[str, object] = {
        "smtp_host": "mail.example.com",
        "smtp_username": "dev@example.com",
        "smtp_password": SecretStr(SECRET),
    }
    return settings.model_copy(update={**base, **changes})


def test_not_configured(settings: Settings) -> None:
    result = email_service.check_smtp_connection(settings.model_copy(update={"smtp_host": None}))
    assert not result.ok
    assert FakeSMTP.instances == []


def test_ssl_login_without_sending(settings: Settings) -> None:
    result = email_service.check_smtp_connection(_settings(settings, smtp_port=465))
    assert result.ok
    assert "aucun e-mail envoyé" in result.message
    (client,) = FakeSMTP.instances
    assert (client.host, client.port) == ("mail.example.com", 465)
    assert client.kwargs["context"] is not None  # certificat vérifié
    assert client.calls == ["login:dev@example.com", "quit"]


def test_starttls(settings: Settings) -> None:
    result = email_service.check_smtp_connection(
        _settings(settings, smtp_security="starttls", smtp_port=587)
    )
    assert result.ok
    assert FakeSMTP.instances[0].calls == ["starttls", "login:dev@example.com", "quit"]


def test_auth_failure_never_reveals_password(settings: Settings) -> None:
    FakeSMTP.fail_login = True
    result = email_service.check_smtp_connection(_settings(settings))
    assert not result.ok
    assert "Authentification refusée" in result.message
    assert SECRET not in result.message


def test_network_error(settings: Settings, monkeypatch: pytest.MonkeyPatch) -> None:
    def refuse(*args: object, **kwargs: object) -> None:
        raise ConnectionRefusedError("refused")

    monkeypatch.setattr(smtplib, "SMTP_SSL", refuse)
    result = email_service.check_smtp_connection(_settings(settings))
    assert not result.ok
    assert "ConnectionRefusedError" in result.message


def test_email_sending_disabled_by_default(settings: Settings) -> None:
    assert Settings.model_fields["email_sending_enabled"].default is False
