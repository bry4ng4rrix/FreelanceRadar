from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import func, select, update

from app.api.deps import CurrentUser, DbDep
from app.db.base import utcnow
from app.models import Notification
from app.schemas.common import Page
from app.schemas.notification import (
    MarkAllReadResult,
    NotificationRead,
    NotificationType,
    UnreadCount,
)

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("", response_model=Page[NotificationRead])
def list_notifications(
    user: CurrentUser,
    db: DbDep,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 20,
    unread_only: bool = False,
    notification_type: Annotated[NotificationType | None, Query(alias="type")] = None,
) -> Page[NotificationRead]:
    """Notifications de l'utilisateur connecté, les plus récentes d'abord."""
    stmt = select(Notification).where(Notification.user_id == user.id)
    if unread_only:
        stmt = stmt.where(Notification.read_at.is_(None))
    if notification_type is not None:
        stmt = stmt.where(Notification.type == notification_type)
    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.scalars(
        stmt.order_by(Notification.created_at.desc(), Notification.id.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    return Page(
        items=[NotificationRead.model_validate(r) for r in rows],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/unread-count", response_model=UnreadCount)
def unread_count(user: CurrentUser, db: DbDep) -> UnreadCount:
    count = db.scalar(
        select(func.count())
        .select_from(Notification)
        .where(Notification.user_id == user.id, Notification.read_at.is_(None))
    )
    return UnreadCount(count=count or 0)


@router.patch("/{notification_id}/read", response_model=NotificationRead)
def mark_read(notification_id: int, user: CurrentUser, db: DbDep) -> Notification:
    """Idempotent : relire une notification déjà lue ne change pas sa date de lecture."""
    notification = db.scalar(
        select(Notification).where(
            Notification.id == notification_id, Notification.user_id == user.id
        )
    )
    if notification is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Notification introuvable.")
    if notification.read_at is None:
        notification.read_at = utcnow()
        db.commit()
    return notification


@router.post("/mark-all-read", response_model=MarkAllReadResult)
def mark_all_read(user: CurrentUser, db: DbDep) -> MarkAllReadResult:
    updated = db.execute(
        update(Notification)
        .where(Notification.user_id == user.id, Notification.read_at.is_(None))
        .values(read_at=utcnow())
        .returning(Notification.id)
    ).all()
    db.commit()
    return MarkAllReadResult(updated=len(updated))
