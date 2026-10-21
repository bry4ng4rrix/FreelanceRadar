from typing import Any

from app.ai.base import AITransientError
from app.ai.registry import get_provider
from app.core.config import get_settings
from app.db.session import get_sessionmaker
from app.services.application_service import generate_application
from app.tasks.celery_app import celery_app

MAX_RETRIES = 3


@celery_app.task(name="applications.generate", bind=True, max_retries=MAX_RETRIES)  # type: ignore[untyped-decorator]
def generate_application_task(self: Any, application_id: int) -> str | None:
    """Rédaction IA en tâche de fond ; une notification annonce le brouillon prêt à valider.

    Erreurs temporaires (surcharge, quota, réseau) : nouvelles tentatives à 30 s, 60 s, 120 s,
    puis la candidature passe en `generation_failed` (l'utilisateur peut relancer).
    """
    last_try = self.request.retries >= MAX_RETRIES
    with get_sessionmaker()() as db:
        try:
            application = generate_application(
                db, application_id, get_settings(), get_provider, raise_transient=not last_try
            )
        except AITransientError as exc:
            raise self.retry(countdown=30 * 2**self.request.retries) from exc
        return application.status if application else None
