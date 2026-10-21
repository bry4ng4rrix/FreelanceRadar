from datetime import datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.common import ORMModel

OfferStatus = Literal[
    "new", "relevant", "ignored", "favorite", "application_prepared", "application_sent"
]
# Statuts qu'un utilisateur peut poser directement ; les autres viendront du module candidatures.
UserSettableStatus = Literal["new", "relevant", "ignored", "favorite"]
OfferSort = Literal["-collected_at", "collected_at", "-published_at", "published_at"]


class OfferRead(ORMModel):
    id: int
    source_id: int
    external_id: str | None
    url: str
    title: str
    company: str | None
    description: str
    location: str | None
    mission_type: str | None
    category: str | None
    budget_min: Decimal | None
    budget_max: Decimal | None
    currency: str | None
    skills: list[str]
    published_at: datetime | None
    collected_at: datetime
    relevance_score: int | None
    ai_summary: str | None
    status: OfferStatus
    notes: str | None
    archived_at: datetime | None


class OfferUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    status: UserSettableStatus | None = None
    notes: str | None = Field(default=None, max_length=10_000)
