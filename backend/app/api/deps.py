from collections.abc import Iterator
from functools import lru_cache
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from redis import Redis
from sqlalchemy.orm import Session

from app.collectors.http import SafeHttpClient
from app.core.config import Settings, get_settings
from app.core.rate_limit import LoginRateLimiter, RedisLoginRateLimiter
from app.core.security import InvalidTokenError, decode_token
from app.db.session import get_db
from app.models import User

SettingsDep = Annotated[Settings, Depends(get_settings)]
DbDep = Annotated[Session, Depends(get_db)]

_bearer = HTTPBearer(auto_error=False)


@lru_cache
def _redis_client(url: str) -> Redis:
    return Redis.from_url(url, socket_timeout=2, socket_connect_timeout=2)


def get_redis(settings: SettingsDep) -> Redis:
    return _redis_client(settings.redis_url)


def get_login_limiter(settings: SettingsDep) -> LoginRateLimiter:
    return RedisLoginRateLimiter(
        get_redis(settings), settings.login_max_attempts, settings.login_window_seconds
    )


def get_http_client(settings: SettingsDep) -> Iterator[SafeHttpClient]:
    with SafeHttpClient(settings) as client:
        yield client


class CollectionQueue:
    """Point d'entrée vers Celery, remplaçable dans les tests."""

    def enqueue(self, source_id: int) -> str:
        from app.tasks.collection import collect_source

        return str(collect_source.delay(source_id, "manual", False).id)


def get_collection_queue() -> CollectionQueue:
    return CollectionQueue()


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_current_user(
    db: DbDep,
    settings: SettingsDep,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> User:
    if credentials is None:
        raise _unauthorized("Authentification requise.")
    try:
        user_id, token_version = decode_token(settings, credentials.credentials, "access")
    except InvalidTokenError as exc:
        raise _unauthorized(str(exc)) from exc
    user = db.get(User, user_id)
    if user is None or not user.is_active or user.token_version != token_version:
        raise _unauthorized("Session invalide.")
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]
