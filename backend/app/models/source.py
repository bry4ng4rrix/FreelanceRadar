from datetime import datetime
from typing import Any

from sqlalchemy import Boolean, CheckConstraint, DateTime, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin

TARGET_TYPES = ("rss", "html", "playwright", "api", "manual")
HEALTH_STATUSES = ("unknown", "ok", "error", "blocked", "unsupported")


class Source(TimestampMixin, Base):
    __tablename__ = "sources"
    __table_args__ = (
        CheckConstraint(f"target_type IN {TARGET_TYPES}", name="target_type"),
        CheckConstraint(f"health_status IN {HEALTH_STATUSES}", name="health_status"),
        CheckConstraint("frequency_minutes >= 5", name="frequency_minutes"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(200), unique=True, nullable=False)
    category: Mapped[str | None] = mapped_column(String(200))
    url: Mapped[str] = mapped_column(Text, nullable=False)
    target_type: Mapped[str] = mapped_column(String(20), nullable=False)
    frequency_minutes: Mapped[int] = mapped_column(Integer, nullable=False, default=60)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    keywords: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)
    selectors: Mapped[dict[str, Any]] = mapped_column(JSONB, nullable=False, default=dict)

    health_status: Mapped[str] = mapped_column(String(20), nullable=False, default="unknown")
    last_attempt_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_success_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_error: Mapped[str | None] = mapped_column(Text)
    offers_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    error_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    consecutive_failures: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
