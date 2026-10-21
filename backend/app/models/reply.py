from datetime import datetime

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    ForeignKey,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin
from app.models.application import Application

MATCH_METHODS = ("headers", "sender_subject")


class ReceivedReply(Base):
    """Réponse d'un client à une candidature, lue par IMAP (seuls les messages associés).

    Les pièces jointes ne sont pas conservées : seul le texte du message est stocké.
    """

    __tablename__ = "received_replies"
    __table_args__ = (CheckConstraint(f"match_method IN {MATCH_METHODS}", name="match_method"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    application_id: Mapped[int] = mapped_column(
        ForeignKey("applications.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # En-tête Message-ID : un message n'est enregistré qu'une fois.
    message_id: Mapped[str] = mapped_column(String(500), unique=True, nullable=False)
    from_address: Mapped[str] = mapped_column(String(320), nullable=False)
    from_name: Mapped[str | None] = mapped_column(String(300))
    subject: Mapped[str] = mapped_column(String(500), nullable=False, default="")
    body_text: Mapped[str] = mapped_column(Text, nullable=False, default="")
    received_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    match_method: Mapped[str] = mapped_column(String(20), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    application: Mapped[Application] = relationship(lazy="joined")

    @property
    def offer_title(self) -> str:
        return self.application.offer_title


class EmailSyncState(TimestampMixin, Base):
    """Curseur de synchronisation IMAP par compte et dossier."""

    __tablename__ = "email_sync_states"
    __table_args__ = (
        UniqueConstraint("account", "folder", name="uq_email_sync_states_account_folder"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    account: Mapped[str] = mapped_column(String(320), nullable=False)
    folder: Mapped[str] = mapped_column(String(200), nullable=False)
    uidvalidity: Mapped[int | None] = mapped_column(BigInteger)
    last_uid: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    last_sync_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_error: Mapped[str | None] = mapped_column(Text)
