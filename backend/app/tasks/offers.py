from app.core.config import get_settings
from app.db.base import utcnow
from app.db.session import get_sessionmaker
from app.services.offer_cleanup_service import cleanup_expired_offers
from app.tasks.celery_app import celery_app


@celery_app.task(name="offers.cleanup")  # type: ignore[untyped-decorator]
def cleanup_offers() -> dict[str, int]:
    """Archivage et suppression des offres expirées (une fois par jour, via Beat)."""
    with get_sessionmaker()() as db:
        result = cleanup_expired_offers(db, get_settings(), utcnow())
    return {"archived": result.archived, "purged": result.purged}
