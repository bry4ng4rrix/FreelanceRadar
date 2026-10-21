import time
from typing import Protocol

from redis import Redis


class LoginRateLimiter(Protocol):
    def is_blocked(self, key: str) -> bool: ...
    def register_failure(self, key: str) -> None: ...
    def reset(self, key: str) -> None: ...


class RedisLoginRateLimiter:
    """Fenêtre fixe : au-delà de `max_attempts` échecs pendant `window_seconds`, refus."""

    def __init__(self, redis: Redis, max_attempts: int, window_seconds: int) -> None:
        self._redis = redis
        self._max_attempts = max_attempts
        self._window = window_seconds

    def _key(self, key: str) -> str:
        return f"login-failures:{key}"

    def is_blocked(self, key: str) -> bool:
        value = self._redis.get(self._key(key))
        return value is not None and int(str(value)) >= self._max_attempts

    def register_failure(self, key: str) -> None:
        pipe = self._redis.pipeline()
        pipe.incr(self._key(key))
        pipe.expire(self._key(key), self._window, nx=True)
        pipe.execute()

    def reset(self, key: str) -> None:
        self._redis.delete(self._key(key))


class InMemoryLoginRateLimiter:
    """Implémentation mémoire pour les tests (non partagée entre processus)."""

    def __init__(self, max_attempts: int, window_seconds: int) -> None:
        self._max_attempts = max_attempts
        self._window = window_seconds
        self._failures: dict[str, tuple[int, float]] = {}

    def is_blocked(self, key: str) -> bool:
        count, started = self._failures.get(key, (0, 0.0))
        if time.monotonic() - started > self._window:
            return False
        return count >= self._max_attempts

    def register_failure(self, key: str) -> None:
        count, started = self._failures.get(key, (0, time.monotonic()))
        if time.monotonic() - started > self._window:
            count, started = 0, time.monotonic()
        self._failures[key] = (count + 1, started)

    def reset(self, key: str) -> None:
        self._failures.pop(key, None)
