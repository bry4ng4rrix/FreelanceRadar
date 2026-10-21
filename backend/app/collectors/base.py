from dataclasses import dataclass
from datetime import datetime
from typing import Any, Protocol

from app.collectors.http import SafeHttpClient


@dataclass(frozen=True)
class SourceConfig:
    """Vue immuable d'une source, indépendante de la session SQLAlchemy."""

    id: int
    url: str
    target_type: str
    selectors: dict[str, Any]


@dataclass(frozen=True)
class RawOffer:
    """Offre extraite par un connecteur, avant validation et normalisation."""

    url: str | None
    title: str | None
    description: str = ""
    external_id: str | None = None
    published_at: datetime | None = None
    company: str | None = None
    location: str | None = None
    category: str | None = None


class Collector(Protocol):
    def collect(self, source: SourceConfig, client: SafeHttpClient) -> list[RawOffer]: ...
