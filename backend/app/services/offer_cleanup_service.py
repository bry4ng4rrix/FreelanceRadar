"""Offres expirées : archivage, puis suppression définitive des offres archivées anciennes.

Aucune source ne fournit de date d'expiration : une offre expire avec l'âge de sa date de
publication (ou de collecte si la source n'en donne pas).
"""

import logging
from dataclasses import dataclass
from datetime import datetime, timedelta

from sqlalchemy import ColumnElement, delete, exists, func, not_, or_, select, update
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.models import Application, Offer

logger = logging.getLogger(__name__)

# Statuts posés par l'utilisateur ou par une candidature : l'offre est toujours conservée.
PROTECTED_STATUSES = ("favorite", "application_prepared", "application_sent")


@dataclass(frozen=True)
class CleanupResult:
    archived: int
    purged: int


def expiry_cutoff(settings: Settings, now: datetime) -> datetime | None:
    """Date avant laquelle une offre est expirée (None : expiration désactivée)."""
    days = settings.offer_archive_after_days
    return now - timedelta(days=days) if days else None


def _reference_date() -> ColumnElement[datetime]:
    return func.coalesce(Offer.published_at, Offer.collected_at)


def _protected() -> ColumnElement[bool]:
    return or_(
        Offer.status.in_(PROTECTED_STATUSES),
        Offer.notes.is_not(None),
        exists().where(Application.offer_id == Offer.id),
    )


def cleanup_expired_offers(
    db: Session, settings: Settings, now: datetime, *, dry_run: bool = False
) -> CleanupResult:
    """Supprime puis archive les offres expirées ; `dry_run` compte sans rien modifier.

    La suppression passe en premier : une offre reste au moins un passage dans les archives
    avant d'être supprimée. Les protections sont vérifiées dans la requête de modification
    elle-même (un favori posé entre-temps est respecté).
    """
    purged = archived = 0
    if settings.offer_purge_after_days:
        purge_where = (
            Offer.archived_at.is_not(None),
            _reference_date() < now - timedelta(days=settings.offer_purge_after_days),
            not_(_protected()),
        )
        purged = (
            _count(db, purge_where)
            if dry_run
            else len(
                db.scalars(
                    delete(Offer)
                    .where(*purge_where)
                    .returning(Offer.id)
                    .execution_options(synchronize_session=False)
                ).all()
            )
        )
    cutoff = expiry_cutoff(settings, now)
    if cutoff is not None:
        archive_where = (
            Offer.archived_at.is_(None),
            _reference_date() < cutoff,
            not_(_protected()),
        )
        archived = (
            _count(db, archive_where)
            if dry_run
            else len(
                db.scalars(
                    update(Offer)
                    .where(*archive_where)
                    .values(archived_at=now)
                    .returning(Offer.id)
                    .execution_options(synchronize_session=False)
                ).all()
            )
        )
    if not dry_run:
        db.commit()
    logger.info(
        "Offres expirées%s : archivées=%s supprimées=%s",
        " (essai, rien de modifié)" if dry_run else "",
        archived,
        purged,
    )
    return CleanupResult(archived=archived, purged=purged)


def _count(db: Session, where: tuple[ColumnElement[bool], ...]) -> int:
    return db.scalar(select(func.count()).select_from(Offer).where(*where)) or 0
