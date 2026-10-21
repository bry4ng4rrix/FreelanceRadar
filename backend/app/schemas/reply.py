from datetime import datetime
from typing import Literal

from app.schemas.common import ORMModel


class ReplyRead(ORMModel):
    id: int
    application_id: int
    offer_title: str
    from_address: str
    from_name: str | None
    subject: str
    body_text: str
    received_at: datetime | None
    match_method: Literal["headers", "sender_subject"]
    created_at: datetime
    read_at: datetime | None
