from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin
from app.models.offer import Offer

# generating -> pending_approval (prête, à valider) -> sending -> sent | failed | delivery_unknown
APPLICATION_STATUSES = (
    "generating",
    "generation_failed",
    "pending_approval",
    "sending",
    "sent",
    "failed",
    "delivery_unknown",
    "replied",
    "cancelled",
)


class Application(TimestampMixin, Base):
    """Candidature à une offre : brouillon rédigé par l'IA, validé puis envoyé par l'utilisateur.

    Une seule candidature par offre et par utilisateur. Le contenu exact envoyé est conservé à part
    du brouillon modifiable.
    """

    __tablename__ = "applications"
    __table_args__ = (
        CheckConstraint(f"status IN {APPLICATION_STATUSES}", name="status"),
        UniqueConstraint("user_id", "offer_id", name="uq_applications_user_id_offer_id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    offer_id: Mapped[int] = mapped_column(
        ForeignKey("offers.id", ondelete="RESTRICT"), nullable=False
    )
    status: Mapped[str] = mapped_column(String(30), nullable=False, default="generating")

    # Brouillon modifiable par l'utilisateur.
    recipient_email: Mapped[str | None] = mapped_column(String(320))
    subject: Mapped[str | None] = mapped_column(String(200))
    message: Mapped[str | None] = mapped_column(Text)
    language: Mapped[str | None] = mapped_column(String(5))

    # Version produite par l'IA (conservée telle quelle) et métadonnées de génération.
    generated_subject: Mapped[str | None] = mapped_column(String(200))
    generated_message: Mapped[str | None] = mapped_column(Text)
    referenced_skills: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)
    ai_warnings: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)
    ai_confidence: Mapped[float | None] = mapped_column(Float)
    ai_provider: Mapped[str | None] = mapped_column(String(30))
    ai_model: Mapped[str | None] = mapped_column(String(100))
    generated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    generation_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    # Envoi : contenu exact transmis au serveur SMTP.
    idempotency_key: Mapped[str | None] = mapped_column(String(64), unique=True)
    send_attempts: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    sent_from: Mapped[str | None] = mapped_column(String(320))
    sent_to: Mapped[str | None] = mapped_column(String(320))
    sent_subject: Mapped[str | None] = mapped_column(String(200))
    sent_message: Mapped[str | None] = mapped_column(Text)
    smtp_message_id: Mapped[str | None] = mapped_column(String(300))
    error_message: Mapped[str | None] = mapped_column(Text)

    # Offre chargée avec la candidature (titre et lien affichés dans les listes).
    offer: Mapped[Offer] = relationship(lazy="joined")

    @property
    def offer_title(self) -> str:
        return self.offer.title

    @property
    def offer_url(self) -> str:
        return self.offer.url
