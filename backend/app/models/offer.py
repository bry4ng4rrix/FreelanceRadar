from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Numeric,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin

OFFER_STATUSES = (
    "new",
    "relevant",
    "ignored",
    "favorite",
    "application_prepared",
    "application_sent",
)


class Offer(TimestampMixin, Base):
    """Offre normalisée.

    Déduplication garantie par PostgreSQL :
    - (source_id, external_id) unique lorsque l'identifiant externe est connu ;
    - url_normalized unique toutes sources confondues.
    `fingerprint` (titre + description) sert au rapprochement inter-sources, sans unicité.
    """

    __tablename__ = "offers"
    __table_args__ = (
        CheckConstraint(f"status IN {OFFER_STATUSES}", name="status"),
        Index(
            "uq_offers_source_id_external_id",
            "source_id",
            "external_id",
            unique=True,
            postgresql_where=text("external_id IS NOT NULL"),
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    source_id: Mapped[int] = mapped_column(
        ForeignKey("sources.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    external_id: Mapped[str | None] = mapped_column(String(500))
    url: Mapped[str] = mapped_column(Text, nullable=False)
    url_normalized: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    fingerprint: Mapped[str] = mapped_column(String(64), nullable=False, index=True)

    title: Mapped[str] = mapped_column(String(500), nullable=False)
    company: Mapped[str | None] = mapped_column(String(300))
    description: Mapped[str] = mapped_column(Text, nullable=False, default="")
    location: Mapped[str | None] = mapped_column(String(300))
    mission_type: Mapped[str | None] = mapped_column(String(100))
    category: Mapped[str | None] = mapped_column(String(200))
    budget_min: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))
    budget_max: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))
    currency: Mapped[str | None] = mapped_column(String(3))
    skills: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)

    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    collected_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False, index=True
    )

    relevance_score: Mapped[int | None] = mapped_column()
    ai_summary: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(30), nullable=False, default="new")
    notes: Mapped[str | None] = mapped_column(Text)
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
