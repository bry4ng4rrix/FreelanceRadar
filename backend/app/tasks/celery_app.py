from celery import Celery
from celery.schedules import crontab

from app.core.config import get_settings

_settings = get_settings()

celery_app = Celery(
    "freelanceradar",
    broker=_settings.redis_url,
    include=[
        "app.tasks.collection",
        "app.tasks.applications",
        "app.tasks.replies",
        "app.tasks.offers",
    ],
)
celery_app.conf.update(
    task_ignore_result=True,
    timezone="UTC",
    enable_utc=True,
    broker_connection_retry_on_startup=True,
    # Une seule instance de Beat doit tourner : elle ne fait qu'émettre ce déclencheur.
    beat_schedule={
        "schedule-due-sources": {
            "task": "collection.schedule_due_sources",
            "schedule": float(_settings.scheduler_interval_seconds),
        },
        # Sans effet tant que EMAIL_SYNC_ENABLED est faux.
        "sync-replies": {
            "task": "replies.sync",
            "schedule": float(_settings.imap_sync_interval_seconds),
        },
        # Offres expirées : chaque jour à 00:30 UTC (03:30 à Antananarivo).
        "cleanup-offers": {
            "task": "offers.cleanup",
            "schedule": crontab(hour=0, minute=30),
        },
    },
)
