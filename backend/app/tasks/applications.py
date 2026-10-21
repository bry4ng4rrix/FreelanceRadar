from app.ai.registry import get_provider
from app.core.config import get_settings
from app.db.session import get_sessionmaker
from app.services.application_service import generate_application
from app.tasks.celery_app import celery_app


@celery_app.task(name="applications.generate")  # type: ignore[untyped-decorator]
def generate_application_task(application_id: int) -> str | None:
    """Rédaction IA en tâche de fond ; une notification annonce le brouillon prêt à valider."""
    with get_sessionmaker()() as db:
        application = generate_application(db, application_id, get_settings(), get_provider)
        return application.status if application else None
