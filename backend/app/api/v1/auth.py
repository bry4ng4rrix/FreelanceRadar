import logging
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status
from redis.exceptions import RedisError

from app.api.deps import CurrentUser, DbDep, SettingsDep, get_login_limiter
from app.core.rate_limit import LoginRateLimiter
from app.core.security import InvalidTokenError, create_token, decode_token, verify_password
from app.models import User
from app.schemas.auth import LoginRequest, RefreshRequest, TokenPair, UserRead
from app.services.user_service import get_user_by_email, normalize_email

router = APIRouter(prefix="/auth", tags=["authentification"])
logger = logging.getLogger(__name__)


def _token_pair(settings: SettingsDep, user: User) -> TokenPair:
    access, expires_in = create_token(settings, user.id, user.token_version, "access")
    refresh, _ = create_token(settings, user.id, user.token_version, "refresh")
    return TokenPair(access_token=access, refresh_token=refresh, expires_in=expires_in)


@router.post("/login", response_model=TokenPair)
def login(
    body: LoginRequest,
    request: Request,
    db: DbDep,
    settings: SettingsDep,
    limiter: Annotated[LoginRateLimiter, Depends(get_login_limiter)],
) -> TokenPair:
    client_ip = request.client.host if request.client else "unknown"
    key = f"{client_ip}|{normalize_email(body.email)}"
    try:
        if limiter.is_blocked(key):
            raise HTTPException(
                status.HTTP_429_TOO_MANY_REQUESTS, "Trop de tentatives. Réessayez plus tard."
            )
        user = get_user_by_email(db, body.email)
        password_ok = verify_password(body.password, user.password_hash if user else None)
        if user is None or not password_ok or not user.is_active:
            limiter.register_failure(key)
            # L'e-mail n'est pas journalisé : donnée personnelle.
            logger.warning("Échec de connexion depuis %s", client_ip)
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Identifiants invalides.")
        limiter.reset(key)
    except RedisError as exc:
        logger.error("Limiteur de connexion indisponible (Redis).")
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE, "Service temporairement indisponible."
        ) from exc
    return _token_pair(settings, user)


@router.post("/refresh", response_model=TokenPair)
def refresh(body: RefreshRequest, db: DbDep, settings: SettingsDep) -> TokenPair:
    try:
        user_id, token_version = decode_token(settings, body.refresh_token, "refresh")
    except InvalidTokenError as exc:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, str(exc)) from exc
    user = db.get(User, user_id)
    if user is None or not user.is_active or user.token_version != token_version:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Session invalide.")
    return _token_pair(settings, user)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(user: CurrentUser, db: DbDep) -> None:
    """Révoque tous les jetons (accès et renouvellement) de l'utilisateur."""
    user.token_version += 1
    db.commit()


@router.get("/me", response_model=UserRead)
def me(user: CurrentUser) -> User:
    return user
