import logging
from typing import Literal

from fastapi import APIRouter
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from redis.exceptions import RedisError
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.api.deps import DbDep, SettingsDep, get_redis

router = APIRouter(tags=["santé"])
logger = logging.getLogger(__name__)


class HealthResponse(BaseModel):
    status: Literal["ok"]


class ReadyResponse(BaseModel):
    status: Literal["ok", "unavailable"]
    database: bool
    redis: bool


@router.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    """Liveness : le processus API répond (aucune dépendance vérifiée)."""
    return HealthResponse(status="ok")


@router.get("/ready", response_model=ReadyResponse, responses={503: {"model": ReadyResponse}})
def ready(db: DbDep, settings: SettingsDep) -> JSONResponse:
    """Readiness : PostgreSQL et Redis répondent."""
    try:
        db.execute(text("SELECT 1"))
        database = True
    except SQLAlchemyError:
        logger.warning("Readiness : PostgreSQL indisponible.")
        database = False
    try:
        redis = bool(get_redis(settings).ping())
    except RedisError:
        logger.warning("Readiness : Redis indisponible.")
        redis = False
    ok = database and redis
    body = ReadyResponse(status="ok" if ok else "unavailable", database=database, redis=redis)
    return JSONResponse(status_code=200 if ok else 503, content=body.model_dump())
