"""Normalisation des URL et du texte des offres, empreinte de déduplication."""

import hashlib
import re
from html import unescape
from html.parser import HTMLParser
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

# Paramètres de suivi sans incidence sur le contenu de l'offre.
_TRACKING_PARAMS = {"fbclid", "gclid", "mc_cid", "mc_eid", "ref", "source"}
_DEFAULT_PORTS = {"http": 80, "https": 443}
_WHITESPACE = re.compile(r"\s+")


def normalize_url(url: str) -> str:
    """Forme canonique d'une URL http(s) ; lève ValueError si l'URL est inexploitable."""
    parts = urlsplit(url.strip())
    scheme = parts.scheme.lower()
    if scheme not in _DEFAULT_PORTS or not parts.hostname:
        raise ValueError("URL http(s) attendue.")
    host = parts.hostname.lower()
    port = parts.port
    netloc = host if port in (None, _DEFAULT_PORTS[scheme]) else f"{host}:{port}"
    path = parts.path or "/"
    if len(path) > 1:
        path = path.rstrip("/")
    query = sorted(
        (k, v)
        for k, v in parse_qsl(parts.query, keep_blank_values=True)
        if not k.lower().startswith("utm_") and k.lower() not in _TRACKING_PARAMS
    )
    return urlunsplit((scheme, netloc, path, urlencode(query), ""))


class _TextExtractor(HTMLParser):
    _BLOCK_TAGS = {"p", "br", "li", "div", "h1", "h2", "h3", "h4", "h5", "h6", "tr", "ul", "ol"}

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []
        self._skip = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag in ("script", "style"):
            self._skip += 1
        elif tag in self._BLOCK_TAGS:
            self.parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        if tag in ("script", "style") and self._skip:
            self._skip -= 1

    def handle_data(self, data: str) -> None:
        if not self._skip:
            self.parts.append(data)


def html_to_text(value: str, max_length: int = 20_000) -> str:
    """Texte brut lisible : les balises sont retirées, jamais interprétées."""
    parser = _TextExtractor()
    parser.feed(value)
    parser.close()
    lines = (_WHITESPACE.sub(" ", unescape(line)).strip() for line in "".join(parser.parts).split("\n"))
    text = "\n".join(line for line in lines if line)
    return text[:max_length]


def clean_line(value: str | None, max_length: int) -> str | None:
    if value is None:
        return None
    cleaned = _WHITESPACE.sub(" ", html_to_text(value)).strip()
    return cleaned[:max_length] or None


def fingerprint(title: str, description: str) -> str:
    basis = f"{title.casefold()}|{description[:1000].casefold()}"
    return hashlib.sha256(_WHITESPACE.sub(" ", basis).encode()).hexdigest()
