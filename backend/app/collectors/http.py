"""Client HTTP de collecte protégé contre les SSRF.

Chaque URL (y compris chaque redirection) est validée : schéma http(s), ports 80/443,
et toutes les adresses résolues doivent être publiques. Risque résiduel connu : entre la
validation DNS et la connexion, un DNS malveillant pourrait changer de réponse (rebinding).
"""

import ipaddress
import socket
from collections.abc import Callable
from dataclasses import dataclass
from urllib.parse import urljoin, urlsplit

import httpx2

from app.collectors.errors import (
    CollectorError,
    SourceBlockedError,
    TransientCollectorError,
    UnsafeUrlError,
)
from app.core.config import Settings

Resolver = Callable[[str, int], list[str]]

_ALLOWED_PORTS = {"http": 80, "https": 443}
_BLOCKING_STATUSES = {401, 403, 429}


def system_resolver(host: str, port: int) -> list[str]:
    try:
        infos = socket.getaddrinfo(host, port, proto=socket.IPPROTO_TCP)
    except socket.gaierror as exc:
        raise TransientCollectorError(f"Résolution DNS impossible pour {host}.") from exc
    return [str(info[4][0]) for info in infos]


def _is_public(address: str) -> bool:
    ip = ipaddress.ip_address(address.split("%", 1)[0])
    if isinstance(ip, ipaddress.IPv6Address) and ip.ipv4_mapped is not None:
        ip = ip.ipv4_mapped
    return ip.is_global and not ip.is_multicast


def validate_public_url(url: str, resolver: Resolver) -> None:
    parts = urlsplit(url)
    scheme = parts.scheme.lower()
    if scheme not in _ALLOWED_PORTS:
        raise UnsafeUrlError("Seuls les schémas http et https sont autorisés.")
    if parts.username or parts.password:
        raise UnsafeUrlError("Les identifiants dans l'URL sont interdits.")
    host = parts.hostname
    if not host:
        raise UnsafeUrlError("URL sans hôte.")
    try:
        port = parts.port or _ALLOWED_PORTS[scheme]
    except ValueError as exc:
        raise UnsafeUrlError("Port invalide.") from exc
    if port != _ALLOWED_PORTS[scheme]:
        raise UnsafeUrlError("Seuls les ports 80 (http) et 443 (https) sont autorisés.")
    try:
        addresses = [str(ipaddress.ip_address(host))]
    except ValueError:
        addresses = resolver(host, port)
    if not addresses or not all(_is_public(a) for a in addresses):
        raise UnsafeUrlError("Destination non publique refusée.")


@dataclass(frozen=True)
class FetchResult:
    url: str
    status_code: int
    content_type: str
    content: bytes


class SafeHttpClient:
    def __init__(
        self,
        settings: Settings,
        transport: httpx2.BaseTransport | None = None,
        resolver: Resolver = system_resolver,
    ) -> None:
        self._settings = settings
        self._resolver = resolver
        self._client = httpx2.Client(
            transport=transport,
            timeout=settings.http_timeout_seconds,
            follow_redirects=False,
            headers={"User-Agent": settings.http_user_agent},
        )

    def close(self) -> None:
        self._client.close()

    def __enter__(self) -> "SafeHttpClient":
        return self

    def __exit__(self, *_: object) -> None:
        self.close()

    def get(self, url: str) -> FetchResult:
        current = url
        for _ in range(self._settings.http_max_redirects + 1):
            validate_public_url(current, self._resolver)
            try:
                with self._client.stream("GET", current) as response:
                    if response.is_redirect:
                        location = response.headers.get("location")
                        if not location:
                            raise CollectorError("Redirection sans destination.")
                        current = urljoin(current, location)
                        continue
                    self._raise_for_status(response.status_code)
                    content = self._read_limited(response)
                    return FetchResult(
                        url=current,
                        status_code=response.status_code,
                        content_type=response.headers.get("content-type", ""),
                        content=content,
                    )
            except httpx2.TimeoutException as exc:
                raise TransientCollectorError("Délai d'attente dépassé.") from exc
            except httpx2.TransportError as exc:
                raise TransientCollectorError("Erreur réseau.") from exc
        raise CollectorError("Trop de redirections.")

    @staticmethod
    def _raise_for_status(status: int) -> None:
        if status in _BLOCKING_STATUSES:
            raise SourceBlockedError(f"Accès refusé par la plateforme (HTTP {status}).")
        if status >= 500:
            raise TransientCollectorError(f"Erreur serveur distante (HTTP {status}).")
        if status >= 400:
            raise CollectorError(f"Réponse HTTP {status}.")

    def _read_limited(self, response: httpx2.Response) -> bytes:
        limit = self._settings.http_max_response_bytes
        chunks: list[bytes] = []
        size = 0
        for chunk in response.iter_bytes():
            size += len(chunk)
            if size > limit:
                raise CollectorError("Réponse trop volumineuse.")
            chunks.append(chunk)
        return b"".join(chunks)
