from datetime import date
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    Date,
    ForeignKey,
    Index,
    Numeric,
    String,
    Text,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin

AVAILABILITIES = ("available", "partially_available", "unavailable")
RATE_UNITS = ("hour", "day")
PROFICIENCY_LEVELS = ("beginner", "intermediate", "advanced", "expert")


class Profile(TimestampMixin, Base):
    """Profil professionnel : un par utilisateur (`prompt.md` §7 et §10)."""

    __tablename__ = "profiles"
    __table_args__ = (
        CheckConstraint(f"availability IN {AVAILABILITIES}", name="availability"),
        CheckConstraint(f"rate_unit IN {RATE_UNITS}", name="rate_unit"),
        CheckConstraint("default_rate IS NULL OR default_rate >= 0", name="default_rate"),
        CheckConstraint("minimum_budget IS NULL OR minimum_budget >= 0", name="minimum_budget"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False
    )

    full_name: Mapped[str | None] = mapped_column(String(200))
    professional_title: Mapped[str | None] = mapped_column(String(200))
    summary: Mapped[str | None] = mapped_column(Text)
    primary_email: Mapped[str | None] = mapped_column(String(320))
    secondary_emails: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)
    phone: Mapped[str | None] = mapped_column(String(40))
    location: Mapped[str | None] = mapped_column(String(200))
    portfolio_url: Mapped[str | None] = mapped_column(Text)
    github_url: Mapped[str | None] = mapped_column(Text)
    linkedin_url: Mapped[str | None] = mapped_column(Text)
    # Codes ISO 639-1 (`fr`, `en`...).
    preferred_languages: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)

    availability: Mapped[str] = mapped_column(String(30), nullable=False, default="available")
    available_from: Mapped[date | None] = mapped_column(Date)
    default_rate: Mapped[Decimal | None] = mapped_column(Numeric(10, 2))
    rate_unit: Mapped[str] = mapped_column(String(10), nullable=False, default="day")
    minimum_budget: Mapped[Decimal | None] = mapped_column(Numeric(12, 2))
    currency: Mapped[str] = mapped_column(String(3), nullable=False, default="EUR")

    # Préférences de recherche (prompt maître §4.A).
    contract_types: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)
    accepted_locations: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)
    accepted_timezones: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)
    included_keywords: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)
    excluded_keywords: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)


class Skill(TimestampMixin, Base):
    """Compétence du profil, avec son niveau réel (jamais déduit automatiquement)."""

    __tablename__ = "skills"
    __table_args__ = (
        CheckConstraint(f"proficiency_level IN {PROFICIENCY_LEVELS}", name="proficiency_level"),
        CheckConstraint(
            "years_experience IS NULL OR (years_experience >= 0 AND years_experience <= 60)",
            name="years_experience",
        ),
        # Une compétence n'apparaît qu'une fois par profil, sans tenir compte de la casse.
        Index("uq_skills_profile_id_lower_name", "profile_id", text("lower(name)"), unique=True),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    profile_id: Mapped[int] = mapped_column(
        ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    category: Mapped[str | None] = mapped_column(String(100))
    proficiency_level: Mapped[str] = mapped_column(
        String(20), nullable=False, default="intermediate"
    )
    years_experience: Mapped[Decimal | None] = mapped_column(Numeric(4, 1))
    aliases: Mapped[list[str]] = mapped_column(JSONB, nullable=False, default=list)
