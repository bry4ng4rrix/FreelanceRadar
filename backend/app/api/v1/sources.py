from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError

from app.api.deps import (
    CollectionQueue,
    CurrentUser,
    DbDep,
    get_collection_queue,
    get_http_client,
)
from app.collectors.errors import CollectorError
from app.collectors.http import SafeHttpClient
from app.collectors.registry import get_collector
from app.models import CollectionRun, Source
from app.schemas.common import Page
from app.schemas.source import (
    CollectionRunRead,
    RunQueued,
    SourceCreate,
    SourceImportResult,
    SourceRead,
    SourceTestResult,
    SourceUpdate,
    TargetType,
)
from app.services.collection_service import normalize_offers, to_source_config
from app.services.source_service import create_source, has_history, import_sources

router = APIRouter(prefix="/sources", tags=["sources"])


def _get_or_404(db: DbDep, source_id: int) -> Source:
    source = db.get(Source, source_id)
    if source is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Source introuvable.")
    return source


def _commit_or_conflict(db: DbDep) -> None:
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "Une source porte déjà ce nom.") from exc


@router.get("", response_model=Page[SourceRead])
def list_sources(
    _: CurrentUser,
    db: DbDep,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 50,
    is_active: bool | None = None,
    target_type: TargetType | None = None,
) -> Page[SourceRead]:
    stmt = select(Source)
    if is_active is not None:
        stmt = stmt.where(Source.is_active.is_(is_active))
    if target_type is not None:
        stmt = stmt.where(Source.target_type == target_type)
    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.scalars(stmt.order_by(Source.name).offset((page - 1) * page_size).limit(page_size))
    return Page(
        items=[SourceRead.model_validate(r) for r in rows],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.post("", response_model=SourceRead, status_code=status.HTTP_201_CREATED)
def create(body: SourceCreate, _: CurrentUser, db: DbDep) -> Source:
    source = create_source(db, body)
    _commit_or_conflict(db)
    return source


@router.post("/import", response_model=SourceImportResult)
def import_(body: list[SourceCreate], _: CurrentUser, db: DbDep) -> SourceImportResult:
    """Import idempotent : les sources dont le nom existe déjà sont ignorées, jamais écrasées."""
    return import_sources(db, body)


@router.get("/{source_id}", response_model=SourceRead)
def get(source_id: int, _: CurrentUser, db: DbDep) -> Source:
    return _get_or_404(db, source_id)


@router.patch("/{source_id}", response_model=SourceRead)
def update(source_id: int, body: SourceUpdate, _: CurrentUser, db: DbDep) -> Source:
    source = _get_or_404(db, source_id)
    changes = body.model_dump(exclude_unset=True)
    if "url" in changes:
        changes["url"] = str(body.url)
    if {"url", "target_type", "selectors"} & changes.keys():
        # La configuration a changé : l'état bloqué/non supporté doit être réévalué.
        source.health_status = "unknown"
    for field, value in changes.items():
        setattr(source, field, value)
    _commit_or_conflict(db)
    return source


@router.delete("/{source_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete(source_id: int, _: CurrentUser, db: DbDep) -> None:
    source = _get_or_404(db, source_id)
    if has_history(db, source_id):
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Cette source possède des offres ou un historique : désactivez-la plutôt.",
        )
    db.delete(source)
    db.commit()


@router.post("/{source_id}/test", response_model=SourceTestResult)
def test(
    source_id: int,
    _: CurrentUser,
    db: DbDep,
    client: Annotated[SafeHttpClient, Depends(get_http_client)],
) -> SourceTestResult:
    """Collecte d'essai sans aucune écriture en base."""
    source = _get_or_404(db, source_id)
    try:
        raw = get_collector(source.target_type).collect(to_source_config(source), client)
    except CollectorError as exc:
        return SourceTestResult(ok=False, items_found=0, valid_items=0, sample_titles=[], error=str(exc))
    normalized = normalize_offers(source.id, raw)
    return SourceTestResult(
        ok=True,
        items_found=len(raw),
        valid_items=len(normalized.rows),
        sample_titles=[row["title"] for row in normalized.rows[:5]],
    )


@router.post("/{source_id}/run", response_model=RunQueued, status_code=status.HTTP_202_ACCEPTED)
def run(
    source_id: int,
    _: CurrentUser,
    db: DbDep,
    queue: Annotated[CollectionQueue, Depends(get_collection_queue)],
) -> RunQueued:
    """Met en file une collecte ; le résultat apparaît dans `/sources/{id}/runs`."""
    _get_or_404(db, source_id)
    return RunQueued(task_id=queue.enqueue(source_id))


@router.get("/{source_id}/runs", response_model=Page[CollectionRunRead])
def list_runs(
    source_id: int,
    _: CurrentUser,
    db: DbDep,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 20,
) -> Page[CollectionRunRead]:
    _get_or_404(db, source_id)
    stmt = select(CollectionRun).where(CollectionRun.source_id == source_id)
    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.scalars(
        stmt.order_by(CollectionRun.started_at.desc(), CollectionRun.id.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    return Page(
        items=[CollectionRunRead.model_validate(r) for r in rows],
        total=total,
        page=page,
        page_size=page_size,
    )
