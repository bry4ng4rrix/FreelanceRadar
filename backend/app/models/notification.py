from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base

NOTIFICATION_TYPES = (
    "new_offers",
    "source_error",
    "source_blocked",
    "application_ready",
    "application_sent",
    "application_failed",
    "reply_received",
)


class Notification(Base):
    """Notification persistée (centre de notifications). L'envoi push (FCM) viendra plus tard.

    `dedup_key` empêche les doublons : un même événement ne notifie qu'une fois chaque utilisateur.
    """

    __tablename__ = "notifications"
    __table_args__ = (
        CheckConstraint(f"type IN {NOTIFICATION_TYPES}", name="type"),
        UniqueConstraint("user_id", "dedup_key", name="uq_notifications_user_id_dedup_key"),
        # Compteur des non lues et liste triée par date.
        Index("ix_notifications_user_id_read_at", "user_id", "read_at"),
        Index("ix_notifications_user_id_created_at", "user_id", "created_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    type: Mapped[str] = mapped_column(String(30), nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False, default="")
    dedup_key: Mapped[str] = mapped_column(String(200), nullable=False)

    # Références métier (l'application ouvre l'écran correspondant).
    offer_id: Mapped[int | None] = mapped_column(ForeignKey("offers.id", ondelete="SET NULL"))
    source_id: Mapped[int | None] = mapped_column(ForeignKey("sources.id", ondelete="SET NULL"))
    collection_run_id: Mapped[int | None] = mapped_column(
        ForeignKey("collection_runs.id", ondelete="SET NULL")
    )
    application_id: Mapped[int | None] = mapped_column(
        ForeignKey("applications.id", ondelete="SET NULL")
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
