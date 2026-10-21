from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import func, select

from app.api.deps import CurrentUser, DbDep
from app.db.base import utcnow
from app.models import ReceivedReply
from app.schemas.common import Page
from app.schemas.reply import ReplyRead

router = APIRouter(prefix="/replies", tags=["réponses"])


@router.get("", response_model=Page[ReplyRead])
def list_replies(
    user: CurrentUser,
    db: DbDep,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 20,
    application_id: int | None = None,
    unread_only: bool = False,
) -> Page[ReplyRead]:
    """Réponses reçues aux candidatures de l'utilisateur, les plus récentes d'abord."""
    stmt = select(ReceivedReply).where(ReceivedReply.user_id == user.id)
    if application_id is not None:
        stmt = stmt.where(ReceivedReply.application_id == application_id)
    if unread_only:
        stmt = stmt.where(ReceivedReply.read_at.is_(None))
    total = db.scalar(select(func.count()).select_from(stmt.subquery())) or 0
    rows = db.scalars(
        stmt.order_by(ReceivedReply.created_at.desc(), ReceivedReply.id.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    return Page(
        items=[ReplyRead.model_validate(r) for r in rows],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.patch("/{reply_id}/read", response_model=ReplyRead)
def mark_read(reply_id: int, user: CurrentUser, db: DbDep) -> ReceivedReply:
    reply = db.scalar(
        select(ReceivedReply).where(ReceivedReply.id == reply_id, ReceivedReply.user_id == user.id)
    )
    if reply is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Réponse introuvable.")
    if reply.read_at is None:
        reply.read_at = utcnow()
        db.commit()
    return reply
