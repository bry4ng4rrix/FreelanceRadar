import logging
from functools import lru_cache
from typing import Any

from redis import Redis

from app.collectors.http import SafeHttpClient
from app.core.config import get_settings
from app.db.base import utcnow
from app.db.session import get_sessionmaker
from app.models import Source
from app.services.collection_service import due_source_ids, is_due, run_collection
from app.services.offer_cleanup_service import expiry_cutoff
from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)

MAX_RETRIES = 3
_LOCK_TIMEOUT_SECONDS = 600


@lru_cache
def _redis() -> Redis:
    return Redis.from_url(get_settings().redis_url)


@celery_app.task(name="collection.schedule_due_sources")  # type: ignore[untyped-decorator]
def schedule_due_sources() -> list[int]:
    # Collecte déclenchée par n8n : Beat ne planifie plus rien (pas de double planificateur).
    if get_settings().collection_scheduler != "beat":
        return []
    with get_sessionmaker()() as db:
        ids = due_source_ids(db, utcnow())
    for source_id in ids:
        collect_source.delay(source_id, "schedule", True)
    return ids


@celery_app.task(  # type: ignore[untyped-decorator]
    name="collection.collect_source", bind=True, max_retries=MAX_RETRIES
)
def collect_source(self: Any, source_id: int, trigger: str, check_due: bool) -> str:
    # Verrou par source : deux collectes simultanées de la même source sont impossibles.
    lock = _redis().lock(f"lock:collect:source:{source_id}", timeout=_LOCK_TIMEOUT_SECONDS)
    if not lock.acquire(blocking=False):
        logger.info("Collecte déjà en cours pour la source %s : ignorée.", source_id)
        return "locked"
    try:
        with get_sessionmaker()() as db:
            source = db.get(Source, source_id)
            if source is None:
                return "missing"
            if check_due and not is_due(source, utcnow()):
                return "not_due"
            settings = get_settings()
            with SafeHttpClient(settings) as client:
                result = run_collection(
                    db,
                    source_id,
                    client,
                    trigger,  # type: ignore[arg-type]
                    task_id=self.request.id,
                    published_after=expiry_cutoff(settings, utcnow()),
                )
            status = result.run.status
    finally:
        lock.release()
    if result.retryable and self.request.retries < MAX_RETRIES:
        # Backoff exponentiel : 60 s, 120 s, 240 s. La reprise ignore la fréquence.
        raise self.retry(args=(source_id, trigger, False), countdown=60 * 2**self.request.retries)
    return str(status)
