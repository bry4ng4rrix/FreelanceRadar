from functools import lru_cache
from pathlib import Path
from typing import Literal, Self

from pydantic import Field, SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# `.env` unique à la racine du dépôt, partagé avec docker-compose.yml.
ROOT_ENV_FILE = Path(__file__).resolve().parents[3] / ".env"


class Settings(BaseSettings):
    """Configuration chargée depuis les variables d'environnement (et `.env` en local)."""

    model_config = SettingsConfigDict(
        env_file=ROOT_ENV_FILE, env_file_encoding="utf-8", extra="ignore"
    )

    app_name: str = "FreelanceRadar"
    environment: Literal["development", "test", "production"] = "development"
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR"] = "INFO"
    api_v1_prefix: str = "/api/v1"
    cors_origins: list[str] = []

    database_url: str
    redis_url: str = "redis://127.0.0.1:6379/0"

    jwt_secret_key: SecretStr = Field(min_length=32)
    jwt_algorithm: Literal["HS256"] = "HS256"
    access_token_expire_minutes: int = Field(default=15, ge=1, le=1440)
    refresh_token_expire_days: int = Field(default=7, ge=1, le=90)
    login_max_attempts: int = Field(default=5, ge=1)
    login_window_seconds: int = Field(default=900, ge=60)

    http_timeout_seconds: float = Field(default=20, gt=0, le=120)
    http_max_response_bytes: int = Field(default=5_000_000, gt=0)
    http_max_redirects: int = Field(default=5, ge=0, le=10)
    http_user_agent: str = "FreelanceRadar/0.1 (+agregateur personnel d'offres)"
    scheduler_interval_seconds: int = Field(default=60, ge=10)
    # beat : Celery Beat collecte chaque source à sa fréquence ; n8n : un workflow n8n déclenche
    # la collecte (POST /automation/collections/run) et Beat ne planifie plus les collectes.
    collection_scheduler: Literal["beat", "n8n"] = "beat"
    # Jeton des automatisations (n8n), envoyé dans l'en-tête X-Service-Token. Absent = refusé.
    service_api_token: SecretStr | None = Field(default=None, min_length=32)

    # Offres expirées (date de référence : publication, sinon collecte) ; 0 = désactivé.
    # Archivées (récupérables) après OFFER_ARCHIVE_AFTER_DAYS, et non collectées au-delà ;
    # supprimées définitivement après OFFER_PURGE_AFTER_DAYS si elles sont archivées.
    # Jamais touchées : favoris, offres annotées ou ayant une candidature.
    offer_archive_after_days: int = Field(default=30, ge=0, le=3650)
    offer_purge_after_days: int = Field(default=90, ge=0, le=3650)

    # SMTP : configuration du compte d'envoi des candidatures. Aucun e-mail n'est envoyé tant que
    # EMAIL_SENDING_ENABLED est faux (et l'envoi lui-même n'est pas encore implémenté, FR-041).
    email_sending_enabled: bool = False
    smtp_host: str | None = None
    smtp_port: int = Field(default=465, ge=1, le=65535)
    # ssl = TLS dès la connexion (port 465) ; starttls = chiffrement négocié (port 587).
    smtp_security: Literal["ssl", "starttls"] = "ssl"
    smtp_username: str | None = None
    smtp_password: SecretStr | None = None
    smtp_from_email: str | None = None
    smtp_from_name: str | None = None
    smtp_timeout_seconds: float = Field(default=15, gt=0, le=120)
    # Garde-fou : nombre maximal de candidatures envoyées par utilisateur et par jour.
    email_daily_limit: int = Field(default=20, ge=1, le=500)

    # IMAP : lecture seule de la boîte de réception pour retrouver les réponses aux candidatures.
    # Identifiants : ceux du SMTP si IMAP_USERNAME / IMAP_PASSWORD sont absents.
    email_sync_enabled: bool = False
    imap_host: str | None = None
    imap_port: int = Field(default=993, ge=1, le=65535)
    imap_security: Literal["ssl", "starttls"] = "ssl"
    imap_username: str | None = None
    imap_password: SecretStr | None = None
    imap_folder: str = "INBOX"
    imap_sync_interval_seconds: int = Field(default=300, ge=60)
    imap_batch_size: int = Field(default=100, ge=1, le=1000)

    # IA : rédaction des candidatures. Sans clé, la génération est refusée proprement.
    ai_provider: Literal["gemini", "disabled"] = "gemini"
    gemini_api_key: SecretStr | None = None
    # Modèles essayés dans l'ordre : si l'un est surchargé (503) ou hors quota (429), le suivant
    # prend le relais. Tous ont une offre gratuite (tarifs officiels vérifiés le 2026-10-21).
    gemini_models: list[str] = Field(
        default=["gemini-3.8-flash", "gemini-3.5-flash-lite", "gemini-3.1-flash-lite"],
        min_length=1,
    )
    ai_temperature: float = Field(default=0.4, ge=0, le=2)
    ai_timeout_seconds: float = Field(default=60, gt=0, le=300)

    @model_validator(mode="after")
    def purge_after_archive(self) -> Self:
        archive, purge = self.offer_archive_after_days, self.offer_purge_after_days
        if archive and purge and purge <= archive:
            raise ValueError("OFFER_PURGE_AFTER_DAYS doit dépasser OFFER_ARCHIVE_AFTER_DAYS.")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
