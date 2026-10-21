from datetime import date, datetime
from decimal import Decimal
from typing import Annotated, Any, Literal

from pydantic import (
    AnyHttpUrl,
    BaseModel,
    BeforeValidator,
    ConfigDict,
    EmailStr,
    Field,
    StringConstraints,
    field_validator,
)

from app.schemas.common import ORMModel

Availability = Literal["available", "partially_available", "unavailable"]
RateUnit = Literal["hour", "day"]
ContractType = Literal["freelance", "fixed_price", "part_time", "full_time"]
ProficiencyLevel = Literal["beginner", "intermediate", "advanced", "expert"]

ShortText = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]


def _lower(value: Any) -> Any:
    return value.strip().lower() if isinstance(value, str) else value


def _upper(value: Any) -> Any:
    return value.strip().upper() if isinstance(value, str) else value


# La casse est normalisée avant le contrôle du motif (« FR » -> « fr », « mga » -> « MGA »).
LanguageCode = Annotated[str, BeforeValidator(_lower), StringConstraints(pattern=r"^[a-z]{2,3}$")]
Currency = Annotated[str, BeforeValidator(_upper), StringConstraints(pattern=r"^[A-Z]{3}$")]
Phone = Annotated[str, StringConstraints(strip_whitespace=True, pattern=r"^\+?[0-9 ().-]{6,30}$")]

# Champs texte facultatifs : une chaîne vide efface la valeur.
_NULLABLE_TEXT = (
    "full_name",
    "professional_title",
    "summary",
    "primary_email",
    "phone",
    "location",
    "portfolio_url",
    "github_url",
    "linkedin_url",
)
# Champs qui ne peuvent pas être effacés (valeur par défaut ou liste vide à la place).
_NOT_NULL = (
    "secondary_emails",
    "preferred_languages",
    "availability",
    "rate_unit",
    "currency",
    "contract_types",
    "accepted_locations",
    "accepted_timezones",
    "included_keywords",
    "excluded_keywords",
)


class ProfileRead(ORMModel):
    id: int
    full_name: str | None
    professional_title: str | None
    summary: str | None
    primary_email: str | None
    secondary_emails: list[str]
    phone: str | None
    location: str | None
    portfolio_url: str | None
    github_url: str | None
    linkedin_url: str | None
    preferred_languages: list[str]
    availability: Availability
    available_from: date | None
    default_rate: Decimal | None
    rate_unit: RateUnit
    minimum_budget: Decimal | None
    currency: str
    contract_types: list[ContractType]
    accepted_locations: list[str]
    accepted_timezones: list[str]
    included_keywords: list[str]
    excluded_keywords: list[str]
    created_at: datetime
    updated_at: datetime


class ProfileUpdate(BaseModel):
    """Modification partielle du profil : seuls les champs envoyés changent."""

    model_config = ConfigDict(extra="forbid")

    full_name: str | None = Field(default=None, max_length=200)
    professional_title: str | None = Field(default=None, max_length=200)
    summary: str | None = Field(default=None, max_length=5000)
    primary_email: EmailStr | None = None
    secondary_emails: list[EmailStr] | None = Field(default=None, max_length=10)
    phone: Phone | None = None
    location: str | None = Field(default=None, max_length=200)
    portfolio_url: AnyHttpUrl | None = None
    github_url: AnyHttpUrl | None = None
    linkedin_url: AnyHttpUrl | None = None
    preferred_languages: list[LanguageCode] | None = Field(default=None, max_length=10)
    availability: Availability | None = None
    available_from: date | None = None
    default_rate: Decimal | None = Field(default=None, ge=0, le=100_000, decimal_places=2)
    rate_unit: RateUnit | None = None
    minimum_budget: Decimal | None = Field(default=None, ge=0, le=10_000_000, decimal_places=2)
    currency: Currency | None = None
    contract_types: list[ContractType] | None = Field(default=None, max_length=4)
    accepted_locations: list[ShortText] | None = Field(default=None, max_length=20)
    accepted_timezones: list[ShortText] | None = Field(default=None, max_length=20)
    included_keywords: list[ShortText] | None = Field(default=None, max_length=50)
    excluded_keywords: list[ShortText] | None = Field(default=None, max_length=50)

    @field_validator(*_NULLABLE_TEXT, mode="before")
    @classmethod
    def empty_to_none(cls, value: Any) -> Any:
        if isinstance(value, str) and not value.strip():
            return None
        return value.strip() if isinstance(value, str) else value

    @field_validator(*_NOT_NULL)
    @classmethod
    def not_null(cls, value: Any) -> Any:
        if value is None:
            raise ValueError("Ce champ ne peut pas être nul.")
        return value

    @field_validator(
        "secondary_emails",
        "preferred_languages",
        "contract_types",
        "accepted_locations",
        "accepted_timezones",
        "included_keywords",
        "excluded_keywords",
    )
    @classmethod
    def unique_items(cls, value: list[Any] | None) -> list[Any] | None:
        """Retire les doublons (sans tenir compte de la casse) en gardant l'ordre."""
        if value is None:
            return None
        seen: set[str] = set()
        result = []
        for item in value:
            key = str(item).casefold()
            if key not in seen:
                seen.add(key)
                result.append(item)
        return result


class SkillRead(ORMModel):
    id: int
    name: str
    category: str | None
    proficiency_level: ProficiencyLevel
    years_experience: Decimal | None
    aliases: list[str]
    created_at: datetime
    updated_at: datetime


class SkillCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: ShortText
    category: ShortText | None = None
    proficiency_level: ProficiencyLevel = "intermediate"
    years_experience: Decimal | None = Field(default=None, ge=0, le=60, decimal_places=1)
    aliases: list[ShortText] = Field(default_factory=list, max_length=20)


class SkillUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: ShortText | None = None
    category: ShortText | None = None
    proficiency_level: ProficiencyLevel | None = None
    years_experience: Decimal | None = Field(default=None, ge=0, le=60, decimal_places=1)
    aliases: list[ShortText] | None = Field(default=None, max_length=20)

    @field_validator("name", "proficiency_level", "aliases")
    @classmethod
    def not_null(cls, value: Any) -> Any:
        if value is None:
            raise ValueError("Ce champ ne peut pas être nul.")
        return value
