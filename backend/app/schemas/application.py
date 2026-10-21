from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.schemas.common import ORMModel

ApplicationStatus = Literal[
    "generating",
    "generation_failed",
    "pending_approval",
    "sending",
    "sent",
    "failed",
    "delivery_unknown",
    "cancelled",
]


class ApplicationRead(ORMModel):
    id: int
    offer_id: int
    offer_title: str
    offer_url: str
    status: ApplicationStatus
    recipient_email: str | None
    subject: str | None
    message: str | None
    language: str | None
    generated_subject: str | None
    generated_message: str | None
    referenced_skills: list[str]
    ai_warnings: list[str]
    ai_confidence: float | None
    ai_provider: str | None
    ai_model: str | None
    generated_at: datetime | None
    generation_count: int
    send_attempts: int
    sent_at: datetime | None
    sent_from: str | None
    sent_to: str | None
    sent_subject: str | None
    sent_message: str | None
    error_message: str | None
    created_at: datetime
    updated_at: datetime


class ApplicationPrepare(BaseModel):
    model_config = ConfigDict(extra="forbid")

    offer_id: int


class ApplicationUpdate(BaseModel):
    """Modification du brouillon avant envoi."""

    model_config = ConfigDict(extra="forbid")

    recipient_email: EmailStr | None = None
    subject: str | None = Field(default=None, min_length=1, max_length=200)
    message: str | None = Field(default=None, min_length=1, max_length=8000)

    @field_validator("recipient_email", mode="before")
    @classmethod
    def empty_to_none(cls, value: object) -> object:
        return None if isinstance(value, str) and not value.strip() else value


class ApplicationSend(BaseModel):
    """Confirmation explicite obligatoire : aucun envoi sans `confirm: true`."""

    model_config = ConfigDict(extra="forbid")

    confirm: Literal[True]
