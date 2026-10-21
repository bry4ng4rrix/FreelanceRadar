import logging
from functools import lru_cache

from redis import Redis

from app.core.config import get_settings
from app.db.session import get_sessionmaker
from app.services.imap_service import open_mailbox
from app.services.reply_service import sync_replies
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


@lru_cache
def _redis() -> Redis:
    return Redis.from_url(get_settings().redis_url)


@celery_app.task(name="replies.sync")  # type: ignore[untyped-decorator]
def sync_replies_task() -> dict[str, int] | None:
    """Lecture IMAP périodique. Un verrou empêche deux synchronisations simultanées."""
    settings = get_settings()
    if not settings.email_sync_enabled:
        return None
    lock = _redis().lock("lock:replies:sync", timeout=600)
    if not lock.acquire(blocking=False):
        return None
    try:
        with get_sessionmaker()() as db:
            result = sync_replies(db, settings, open_mailbox)
        logger.info(
            "Synchronisation IMAP : %s lus, %s réponses, %s ambigus.",
            result.scanned,
            result.stored,
            result.ambiguous,
        )
        return {"scanned": result.scanned, "stored": result.stored, "ambiguous": result.ambiguous}
    finally:
        lock.release()
