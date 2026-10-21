from datetime import datetime
from typing import Literal

from pydantic import BaseModel

from app.schemas.common import ORMModel

NotificationType = Literal["new_offers", "source_error", "source_blocked"]


class NotificationRead(ORMModel):
    id: int
    type: NotificationType
    title: str
    body: str
    offer_id: int | None
    source_id: int | None
    collection_run_id: int | None
    created_at: datetime
    read_at: datetime | None


class UnreadCount(BaseModel):
    count: int


class MarkAllReadResult(BaseModel):
    updated: int
