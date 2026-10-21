from datetime import datetime
from typing import Annotated, Any, Literal

from pydantic import AnyHttpUrl, BaseModel, ConfigDict, Field, field_validator

from app.schemas.common import ORMModel

TargetType = Literal["rss", "html", "playwright", "api", "manual"]
HealthStatus = Literal["unknown", "ok", "error", "blocked", "unsupported"]
Keyword = Annotated[str, Field(min_length=1, max_length=100)]


class SourceBase(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=200)
    category: str | None = Field(default=None, max_length=200)
    url: AnyHttpUrl
    target_type: TargetType
    frequency_minutes: int = Field(default=60, ge=5, le=10_080)
    is_active: bool = False
    keywords: list[Keyword] = Field(default_factory=list, max_length=50)
    selectors: dict[str, Any] = Field(default_factory=dict)


class SourceCreate(SourceBase):
    pass


class SourceUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(default=None, min_length=1, max_length=200)
    category: str | None = Field(default=None, max_length=200)
    url: AnyHttpUrl | None = None
    target_type: TargetType | None = None
    frequency_minutes: int | None = Field(default=None, ge=5, le=10_080)
    is_active: bool | None = None
    keywords: list[Keyword] | None = Field(default=None, max_length=50)
    selectors: dict[str, Any] | None = None

    @field_validator("name", "url", "target_type", "frequency_minutes", "is_active")
    @classmethod
    def not_null(cls, value: object) -> object:
        if value is None:
            raise ValueError("Ce champ ne peut pas être nul.")
        return value


class SourceRead(ORMModel):
    id: int
    name: str
    category: str | None
    url: str
    target_type: TargetType
    frequency_minutes: int
    is_active: bool
    keywords: list[str]
    selectors: dict[str, Any]
    health_status: HealthStatus
    last_attempt_at: datetime | None
    last_success_at: datetime | None
    last_error: str | None
    offers_count: int
    error_count: int
    consecutive_failures: int
    created_at: datetime
    updated_at: datetime


class SourceImportResult(BaseModel):
    created: list[str]
    skipped: list[str]


class SourceTestResult(BaseModel):
    ok: bool
    items_found: int
    valid_items: int
    sample_titles: list[str]
    error: str | None = None


class CollectionRunRead(ORMModel):
    id: int
    source_id: int
    trigger: str
    status: str
    task_id: str | None
    started_at: datetime
    finished_at: datetime | None
    items_seen: int
    items_new: int
    items_duplicate: int
    items_invalid: int
    error_message: str | None


class RunQueued(BaseModel):
    task_id: str
