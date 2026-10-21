import uuid
from datetime import UTC, datetime, timedelta
from typing import Literal

import jwt
from pwdlib import PasswordHash

from app.core.config import Settings

TokenType = Literal["access", "refresh"]

_password_hash = PasswordHash.recommended()  # Argon2id
# Hash factice pour que la vérification d'un e-mail inconnu prenne le même temps.
_DUMMY_HASH = _password_hash.hash("dummy-password-for-timing")


class InvalidTokenError(Exception):
    pass


def hash_password(password: str) -> str:
    return _password_hash.hash(password)


def verify_password(password: str, password_hash: str | None) -> bool:
    if password_hash is None:
        _password_hash.verify(password, _DUMMY_HASH)
        return False
    return _password_hash.verify(password, password_hash)


def create_token(
    settings: Settings, user_id: int, token_version: int, token_type: TokenType
) -> tuple[str, int]:
    """Retourne (jeton, durée de validité en secondes)."""
    if token_type == "access":
        lifetime = timedelta(minutes=settings.access_token_expire_minutes)
    else:
        lifetime = timedelta(days=settings.refresh_token_expire_days)
    now = datetime.now(UTC)
    payload = {
        "sub": str(user_id),
        "type": token_type,
        "ver": token_version,
        "iat": now,
        "exp": now + lifetime,
        "jti": uuid.uuid4().hex,
    }
    token = jwt.encode(
        payload, settings.jwt_secret_key.get_secret_value(), algorithm=settings.jwt_algorithm
    )
    return token, int(lifetime.total_seconds())


def decode_token(settings: Settings, token: str, expected_type: TokenType) -> tuple[int, int]:
    """Retourne (user_id, token_version) ou lève InvalidTokenError."""
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret_key.get_secret_value(),
            algorithms=[settings.jwt_algorithm],
            options={"require": ["sub", "type", "ver", "exp", "iat"]},
        )
    except jwt.PyJWTError as exc:
        raise InvalidTokenError("Jeton invalide ou expiré.") from exc
    if payload["type"] != expected_type:
        raise InvalidTokenError("Type de jeton inattendu.")
    try:
        return int(payload["sub"]), int(payload["ver"])
    except (TypeError, ValueError) as exc:
        raise InvalidTokenError("Jeton invalide.") from exc
