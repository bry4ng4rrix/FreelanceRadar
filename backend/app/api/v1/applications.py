from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select

from app.api.deps import CurrentUser, DbDep, SettingsDep
from app.models import Application
from app.schemas.application import (
    ApplicationPrepare,
    ApplicationRead,
    ApplicationSend,
    ApplicationStatus,
    ApplicationUpdate,
)
from app.schemas.common import Page
from app.services import application_service as service
from app.services import email_service

router = APIRouter(prefix="/applications", tags=["candidatures"])


class GenerationQueue:
    """Point d'entrée vers Celery, remplaçable dans les tests."""

    def enqueue(self, application_id: int) -> None:
        from app.tasks.applications import generate_application_task

        generate_application_task.delay(application_id)


def get_generation_queue() -> GenerationQueue:
    return GenerationQueue()


def get_sender() -> service.Sender:
    """Envoi SMTP réel ; remplacé par un faux serveur dans les tests."""
    return email_service.send_message


QueueDep = Annotated[GenerationQueue, Depends(get_generation_queue)]


def _http(error: service.ApplicationError) -> HTTPException:
    return HTTPException(error.status_code, error.message)


@router.post("/prepare", response_model=ApplicationRead, status_code=status.HTTP_202_ACCEPTED)
def prepare(body: ApplicationPrepare, user: CurrentUser, db: DbDep, queue: QueueDep) -> Application:
    """Lance la rédaction par l'IA. Une notification annonce le brouillon prêt à valider."""
    try:
        application = service.start_application(db, user, body.offer_id)
    except service.ApplicationError as exc:
        raise _http(exc) from exc
    queue.enqueue(application.id)
    return application


@router.get("", response_model=Page[ApplicationRead])
def list_applications(
    user: CurrentUser,
    db: DbDep,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 20,
    application_status: Annotated[ApplicationStatus | None, Query(alias="status")] = None,
    offer_id: int | None = None,
) -> Page[ApplicationRead]:
    stmt = select(Application).where(Application.user_id == user.id)
    if application_status is not None:
        stmt = stmt.where(Application.status == application_status)
    if offer_id is not None:
        stmt = stmt.where(Application.offer_id == offer_id)
    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.scalars(
        stmt.order_by(Application.updated_at.desc(), Application.id.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    return Page(
        items=[ApplicationRead.model_validate(r) for r in rows],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/{application_id}", response_model=ApplicationRead)
def get(application_id: int, user: CurrentUser, db: DbDep) -> Application:
    try:
        return service.get_owned(db, user, application_id)
    except service.ApplicationError as exc:
        raise _http(exc) from exc


@router.patch("/{application_id}", response_model=ApplicationRead)
def update(
    application_id: int, body: ApplicationUpdate, user: CurrentUser, db: DbDep
) -> Application:
    try:
        application = service.get_owned(db, user, application_id)
        return service.update_draft(db, application, body.model_dump(exclude_unset=True))
    except service.ApplicationError as exc:
        raise _http(exc) from exc


@router.post(
    "/{application_id}/regenerate",
    response_model=ApplicationRead,
    status_code=status.HTTP_202_ACCEPTED,
)
def regenerate(application_id: int, user: CurrentUser, db: DbDep, queue: QueueDep) -> Application:
    try:
        application = service.request_regeneration(db, service.get_owned(db, user, application_id))
    except service.ApplicationError as exc:
        raise _http(exc) from exc
    queue.enqueue(application.id)
    return application


@router.post("/{application_id}/send", response_model=ApplicationRead)
def send(
    application_id: int,
    body: ApplicationSend,
    user: CurrentUser,
    db: DbDep,
    settings: SettingsDep,
    sender: Annotated[service.Sender, Depends(get_sender)],
) -> Application:
    """Envoi confirmé par l'utilisateur. Le statut renvoyé indique le résultat réel :
    `sent` (accepté par le serveur SMTP), `failed` ou `delivery_unknown`."""
    try:
        return service.send_application(db, user, application_id, settings, sender)
    except service.ApplicationError as exc:
        raise _http(exc) from exc


@router.post("/{application_id}/cancel", response_model=ApplicationRead)
def cancel(application_id: int, user: CurrentUser, db: DbDep) -> Application:
    try:
        return service.cancel(db, service.get_owned(db, user, application_id))
    except service.ApplicationError as exc:
        raise _http(exc) from exc
