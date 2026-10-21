"""Candidatures : rédaction par l'IA, validation par l'utilisateur, envoi SMTP.

Règles (`prompt.md` §12, `notifications.md` §4) :
- aucune candidature n'est envoyée sans confirmation explicite de l'utilisateur ;
- le destinataire est saisi par l'utilisateur, jamais deviné ;
- une seule candidature par offre ; réservation en base avant l'envoi (pas de double envoi) ;
- `sent` uniquement après acceptation par le serveur SMTP ; un résultat incertain n'est jamais
  renvoyé automatiquement.
"""

import logging
import uuid
from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime, time
from email.message import EmailMessage

from pydantic import EmailStr, TypeAdapter, ValidationError
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.ai.base import AIError, AIProvider
from app.ai.schemas import ApplicationPromptInput
from app.core.config import Settings
from app.db.base import utcnow
from app.models import Application, Offer, Skill, User
from app.services import email_service
from app.services.notification_service import notify_user
from app.services.profile_service import get_or_create_profile, list_skills

logger = logging.getLogger(__name__)

EDITABLE = ("pending_approval", "generation_failed", "failed")
SENDABLE = ("pending_approval", "failed")
REGENERABLE = ("pending_approval", "generation_failed", "failed")
FINAL = ("sending", "sent", "delivery_unknown")
# Statuts d'offre que la préparation d'une candidature peut remplacer.
_OFFER_STATUSES_BEFORE_APPLICATION = ("new", "relevant", "favorite")

_email_adapter = TypeAdapter(EmailStr)

ProviderFactory = Callable[[Settings], AIProvider]
Sender = Callable[[Settings, EmailMessage], None]


@dataclass
class ApplicationError(Exception):
    """Erreur métier traduite en réponse HTTP par la route."""

    status_code: int
    message: str


def get_owned(db: Session, user: User, application_id: int) -> Application:
    application = db.scalar(
        select(Application).where(Application.id == application_id, Application.user_id == user.id)
    )
    if application is None:
        raise ApplicationError(404, "Candidature introuvable.")
    return application


def start_application(db: Session, user: User, offer_id: int) -> Application:
    """Crée la candidature en statut `generating` (la rédaction se fait en tâche de fond)."""
    offer = db.get(Offer, offer_id)
    if offer is None:
        raise ApplicationError(404, "Offre introuvable.")
    existing = db.scalar(
        select(Application).where(Application.user_id == user.id, Application.offer_id == offer_id)
    )
    if existing is not None:
        raise ApplicationError(
            409, f"Une candidature existe déjà pour cette offre (n° {existing.id})."
        )
    application = Application(user_id=user.id, offer_id=offer_id, status="generating")
    db.add(application)
    try:
        db.commit()
    except IntegrityError as exc:  # création concurrente
        db.rollback()
        raise ApplicationError(409, "Une candidature existe déjà pour cette offre.") from exc
    return application


def build_prompt_input(db: Session, user: User, offer: Offer) -> ApplicationPromptInput:
    """Rassemble UNIQUEMENT les informations réelles du profil et de l'offre."""
    profile = get_or_create_profile(db, user)
    skills = list_skills(db, profile)
    budget = None
    if offer.budget_min is not None or offer.budget_max is not None:
        bounds = [str(v) for v in (offer.budget_min, offer.budget_max) if v is not None]
        budget = f"{' - '.join(bounds)} {offer.currency or ''}".strip()
    rate = None
    if profile.default_rate is not None:
        unit = "jour" if profile.rate_unit == "day" else "heure"
        rate = f"{profile.default_rate} {profile.currency} / {unit}"
    links = {
        name: url
        for name, url in (
            ("portfolio", profile.portfolio_url),
            ("github", profile.github_url),
            ("linkedin", profile.linkedin_url),
        )
        if url
    }
    return ApplicationPromptInput(
        offer_title=offer.title,
        offer_description=offer.description,
        offer_company=offer.company,
        offer_location=offer.location,
        offer_budget=budget,
        offer_url=offer.url,
        candidate_name=profile.full_name,
        candidate_title=profile.professional_title,
        candidate_summary=profile.summary,
        candidate_location=profile.location,
        candidate_languages=profile.preferred_languages,
        candidate_availability=profile.availability,
        candidate_rate=rate,
        candidate_links=links,
        candidate_skills=[
            {
                "name": skill.name,
                "level": skill.proficiency_level,
                "years": skill.years_experience,
                "category": skill.category,
            }
            for skill in skills
        ],
    )


def _keep_known_skills(referenced: list[str], skills: list[Skill]) -> tuple[list[str], list[str]]:
    """Ne garde que les compétences réellement présentes dans le profil."""
    known = {skill.name.casefold(): skill.name for skill in skills}
    kept: list[str] = []
    removed: list[str] = []
    for name in referenced:
        match = known.get(name.strip().casefold())
        if match is None:
            removed.append(name)
        elif match not in kept:
            kept.append(match)
    return kept, removed


def generate_application(
    db: Session, application_id: int, settings: Settings, provider_factory: ProviderFactory
) -> Application | None:
    """Rédige le brouillon puis notifie l'utilisateur qu'il est prêt à valider."""
    application = db.get(Application, application_id)
    if application is None or application.status != "generating":
        return application  # déjà traitée (tâche rejouée) : rien à faire
    user = db.get(User, application.user_id)
    offer = db.get(Offer, application.offer_id)
    if user is None or offer is None:
        return None

    try:
        prompt_input = build_prompt_input(db, user, offer)
        provider = provider_factory(settings)
        result = provider.generate_application(prompt_input)
    except AIError as exc:
        application.status = "generation_failed"
        application.error_message = str(exc)
        notify_user(
            db,
            user.id,
            type="application_failed",
            title="Rédaction impossible",
            body=f"{offer.title} : {exc}",
            dedup_key=f"application:{application.id}:generation_failed:{application.generation_count}",
            offer_id=offer.id,
            application_id=application.id,
        )
        db.commit()
        return application

    profile = get_or_create_profile(db, user)
    kept, removed = _keep_known_skills(result.referenced_skills, list_skills(db, profile))
    warnings = list(result.warnings)
    if removed:
        warnings.append(
            "Compétences citées par l'IA mais absentes de votre profil, à vérifier dans le texte : "
            + ", ".join(removed)
        )
    application.generated_subject = result.subject
    application.generated_message = result.message
    application.subject = result.subject
    application.message = result.message
    application.language = result.language
    application.referenced_skills = kept
    application.ai_warnings = warnings
    application.ai_confidence = result.confidence
    application.ai_provider = provider.name
    application.ai_model = provider.model
    application.generated_at = utcnow()
    application.generation_count += 1
    application.error_message = None
    application.status = "pending_approval"
    if offer.status in _OFFER_STATUSES_BEFORE_APPLICATION:
        offer.status = "application_prepared"
    hint = "" if application.recipient_email else " — destinataire à renseigner"
    notify_user(
        db,
        user.id,
        type="application_ready",
        title="Candidature prête à valider",
        body=f"{offer.title}{hint}",
        dedup_key=f"application:{application.id}:ready:{application.generation_count}",
        offer_id=offer.id,
        application_id=application.id,
    )
    db.commit()
    return application


def update_draft(db: Session, application: Application, changes: dict[str, object]) -> Application:
    if application.status not in EDITABLE:
        raise ApplicationError(409, "Cette candidature ne peut plus être modifiée.")
    for field, value in changes.items():
        if field in ("subject", "message") and value is None:
            raise ApplicationError(422, "L'objet et le message ne peuvent pas être vides.")
        setattr(application, field, value)
    db.commit()
    return application


def request_regeneration(db: Session, application: Application) -> Application:
    if application.status not in REGENERABLE:
        raise ApplicationError(409, "Cette candidature ne peut pas être rédigée à nouveau.")
    application.status = "generating"
    db.commit()
    return application


def cancel(db: Session, application: Application) -> Application:
    if application.status in FINAL:
        raise ApplicationError(
            409, "Une candidature envoyée (ou en cours d'envoi) ne s'annule pas."
        )
    application.status = "cancelled"
    db.commit()
    return application


def _sent_today(db: Session, user_id: int) -> int:
    start = datetime.combine(utcnow().date(), time.min, tzinfo=utcnow().tzinfo)
    return (
        db.scalar(
            select(func.count())
            .select_from(Application)
            .where(
                Application.user_id == user_id,
                Application.sent_at.is_not(None),
                Application.sent_at >= start,
            )
        )
        or 0
    )


def send_application(
    db: Session, user: User, application_id: int, settings: Settings, sender: Sender
) -> Application:
    """Envoie la candidature validée par l'utilisateur."""
    if not settings.email_sending_enabled:
        raise ApplicationError(
            409, "L'envoi d'e-mails est désactivé sur le serveur (EMAIL_SENDING_ENABLED=false)."
        )
    application = get_owned(db, user, application_id)
    if application.status not in SENDABLE:
        raise ApplicationError(409, "Cette candidature n'est pas prête à être envoyée.")
    if not application.recipient_email:
        raise ApplicationError(422, "Renseignez le destinataire avant l'envoi.")
    try:
        _email_adapter.validate_python(application.recipient_email)
    except ValidationError as exc:
        raise ApplicationError(422, "Adresse du destinataire invalide.") from exc
    if not (application.subject or "").strip() or not (application.message or "").strip():
        raise ApplicationError(422, "L'objet et le message ne peuvent pas être vides.")
    if _sent_today(db, user.id) >= settings.email_daily_limit:
        raise ApplicationError(429, "Limite quotidienne d'envois atteinte.")
    try:
        message = email_service.build_message(
            settings,
            to=application.recipient_email,
            subject=application.subject or "",
            body=application.message or "",
        )
    except email_service.SmtpNotConfiguredError as exc:
        raise ApplicationError(409, str(exc)) from exc

    # Réservation atomique : une seule requête peut passer en `sending`.
    reserved = db.execute(
        update(Application)
        .where(
            Application.id == application.id,
            Application.user_id == user.id,
            Application.status.in_(SENDABLE),
        )
        .values(
            status="sending",
            idempotency_key=uuid.uuid4().hex,
            send_attempts=Application.send_attempts + 1,
        )
        .returning(Application.id)
    ).all()
    db.commit()
    if not reserved:
        raise ApplicationError(409, "Cette candidature est déjà en cours d'envoi ou envoyée.")
    db.refresh(application)
    offer = db.get(Offer, application.offer_id)
    offer_title = offer.title if offer else "Offre"

    try:
        sender(settings, message)
    except email_service.SmtpUncertainError as exc:
        _record_send_failure(db, application, offer_title, "delivery_unknown", str(exc))
        return application
    except (email_service.SmtpRejectedError, email_service.SmtpNotConfiguredError) as exc:
        _record_send_failure(db, application, offer_title, "failed", str(exc))
        return application

    application.status = "sent"
    application.sent_at = utcnow()
    application.sent_from = settings.smtp_from_email
    application.sent_to = application.recipient_email
    application.sent_subject = application.subject
    application.sent_message = application.message
    application.smtp_message_id = message["Message-ID"]
    application.error_message = None
    if offer is not None:
        offer.status = "application_sent"
    notify_user(
        db,
        user.id,
        type="application_sent",
        title="Candidature envoyée",
        body=f"{offer_title} → {application.recipient_email}",
        dedup_key=f"application:{application.id}:sent",
        offer_id=application.offer_id,
        application_id=application.id,
    )
    db.commit()
    logger.info("Candidature %s envoyée (Message-ID %s).", application.id, message["Message-ID"])
    return application


def _record_send_failure(
    db: Session, application: Application, offer_title: str, status: str, error: str
) -> None:
    application.status = status
    application.error_message = error
    notify_user(
        db,
        application.user_id,
        type="application_failed",
        title="Envoi incertain" if status == "delivery_unknown" else "Échec d'envoi",
        body=f"{offer_title} : {error}",
        dedup_key=f"application:{application.id}:{status}:{application.send_attempts}",
        offer_id=application.offer_id,
        application_id=application.id,
    )
    db.commit()
    logger.warning("Candidature %s : envoi %s (%s).", application.id, status, error)
