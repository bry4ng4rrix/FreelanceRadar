from datetime import UTC, datetime, timedelta

import jwt
import pytest

from app.core.config import Settings
from app.core.rate_limit import InMemoryLoginRateLimiter
from app.core.security import (
    InvalidTokenError,
    create_token,
    decode_token,
    hash_password,
    verify_password,
)


def test_password_hash_roundtrip() -> None:
    hashed = hash_password("un-mot-de-passe-long")
    assert hashed != "un-mot-de-passe-long"
    assert hashed.startswith("$argon2id$")
    assert verify_password("un-mot-de-passe-long", hashed)
    assert not verify_password("mauvais", hashed)


def test_verify_password_unknown_user_is_false() -> None:
    assert not verify_password("peu-importe", None)


def test_token_roundtrip(settings: Settings) -> None:
    token, expires_in = create_token(settings, 42, 3, "access")
    assert expires_in == settings.access_token_expire_minutes * 60
    assert decode_token(settings, token, "access") == (42, 3)


def test_refresh_token_rejected_as_access(settings: Settings) -> None:
    token, _ = create_token(settings, 1, 0, "refresh")
    with pytest.raises(InvalidTokenError):
        decode_token(settings, token, "access")


def test_expired_and_forged_tokens_rejected(settings: Settings) -> None:
    now = datetime.now(UTC)
    payload = {
        "sub": "1",
        "type": "access",
        "ver": 0,
        "iat": now,
        "exp": now - timedelta(seconds=1),
    }
    expired = jwt.encode(payload, settings.jwt_secret_key.get_secret_value(), algorithm="HS256")
    with pytest.raises(InvalidTokenError):
        decode_token(settings, expired, "access")
    forged = jwt.encode(
        {**payload, "exp": now + timedelta(hours=1)}, "another-secret-another-secret-xx", "HS256"
    )
    with pytest.raises(InvalidTokenError):
        decode_token(settings, forged, "access")


def test_in_memory_limiter_blocks_after_max_attempts() -> None:
    limiter = InMemoryLoginRateLimiter(max_attempts=2, window_seconds=60)
    assert not limiter.is_blocked("k")
    limiter.register_failure("k")
    limiter.register_failure("k")
    assert limiter.is_blocked("k")
    limiter.reset("k")
    assert not limiter.is_blocked("k")
