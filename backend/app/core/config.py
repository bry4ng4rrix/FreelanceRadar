from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import Field, SecretStr
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


@lru_cache
def get_settings() -> Settings:
    return Settings()
