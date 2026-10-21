from collections.abc import Sequence

from sqlalchemy import exists, select
from sqlalchemy.orm import Session

from app.models import CollectionRun, Offer, Source
from app.schemas.source import SourceCreate, SourceImportResult


def create_source(db: Session, data: SourceCreate) -> Source:
    payload = data.model_dump()
    payload["url"] = str(data.url)
    source = Source(**payload)
    db.add(source)
    return source


def import_sources(db: Session, items: Sequence[SourceCreate]) -> SourceImportResult:
    """Import idempotent par nom : une source existante n'est jamais écrasée."""
    existing = set(db.scalars(select(Source.name)))
    result = SourceImportResult(created=[], skipped=[])
    for item in items:
        if item.name in existing:
            result.skipped.append(item.name)
            continue
        create_source(db, item)
        existing.add(item.name)
        result.created.append(item.name)
    db.commit()
    return result


def has_history(db: Session, source_id: int) -> bool:
    """Une source avec offres ou historique ne se supprime pas : on la désactive."""
    return bool(
        db.scalar(
            select(
                exists().where(Offer.source_id == source_id)
                | exists().where(CollectionRun.source_id == source_id)
            )
        )
    )
