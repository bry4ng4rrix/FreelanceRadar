from datetime import datetime
from typing import Annotated, Any

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import ColumnElement, func, or_, select

from app.api.deps import CurrentUser, DbDep
from app.db.base import utcnow
from app.models import Offer
from app.schemas.common import Page
from app.schemas.offer import OfferRead, OfferSort, OfferStatus, OfferUpdate

router = APIRouter(prefix="/offers", tags=["offres"])

_SORTS: dict[str, tuple[ColumnElement[Any], ...]] = {
    "-collected_at": (Offer.collected_at.desc(), Offer.id.desc()),
    "collected_at": (Offer.collected_at.asc(), Offer.id.asc()),
    "-published_at": (Offer.published_at.desc().nulls_last(), Offer.id.desc()),
    "published_at": (Offer.published_at.asc().nulls_last(), Offer.id.asc()),
}


def _escape_like(value: str) -> str:
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def _get_or_404(db: DbDep, offer_id: int) -> Offer:
    offer = db.get(Offer, offer_id)
    if offer is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Offre introuvable.")
    return offer


@router.get("", response_model=Page[OfferRead])
def list_offers(
    _: CurrentUser,
    db: DbDep,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 20,
    q: Annotated[str | None, Query(min_length=2, max_length=200)] = None,
    source_id: int | None = None,
    offer_status: Annotated[OfferStatus | None, Query(alias="status")] = None,
    published_after: datetime | None = None,
    include_archived: bool = False,
    sort: OfferSort = "-collected_at",
) -> Page[OfferRead]:
    stmt = select(Offer)
    if not include_archived:
        stmt = stmt.where(Offer.archived_at.is_(None))
    if q:
        pattern = f"%{_escape_like(q)}%"
        stmt = stmt.where(
            or_(
                Offer.title.ilike(pattern, escape="\\"),
                Offer.description.ilike(pattern, escape="\\"),
            )
        )
    if source_id is not None:
        stmt = stmt.where(Offer.source_id == source_id)
    if offer_status is not None:
        stmt = stmt.where(Offer.status == offer_status)
    if published_after is not None:
        stmt = stmt.where(Offer.published_at >= published_after)
    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.scalars(stmt.order_by(*_SORTS[sort]).offset((page - 1) * page_size).limit(page_size))
    return Page(
        items=[OfferRead.model_validate(r) for r in rows],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/{offer_id}", response_model=OfferRead)
def get(offer_id: int, _: CurrentUser, db: DbDep) -> Offer:
    return _get_or_404(db, offer_id)


@router.patch("/{offer_id}", response_model=OfferRead)
def update(offer_id: int, body: OfferUpdate, _: CurrentUser, db: DbDep) -> Offer:
    offer = _get_or_404(db, offer_id)
    changes = body.model_dump(exclude_unset=True)
    if changes.get("status", "") is None:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT, "Le statut ne peut pas être nul."
        )
    for field, value in changes.items():
        setattr(offer, field, value)
    db.commit()
    return offer


@router.post("/{offer_id}/archive", response_model=OfferRead)
def archive(offer_id: int, _: CurrentUser, db: DbDep) -> Offer:
    """Idempotent : archiver une offre déjà archivée ne change pas sa date d'archivage."""
    offer = _get_or_404(db, offer_id)
    if offer.archived_at is None:
        offer.archived_at = utcnow()
        db.commit()
    return offer
