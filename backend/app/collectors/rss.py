from datetime import UTC, datetime
from typing import Any

import feedparser

from app.collectors.base import RawOffer, SourceConfig
from app.collectors.errors import CollectorError
from app.collectors.http import SafeHttpClient


def _published_at(entry: Any) -> datetime | None:
    parsed = entry.get("published_parsed") or entry.get("updated_parsed")
    if not parsed:
        return None
    return datetime(*parsed[:6], tzinfo=UTC)


def _description(entry: Any) -> str:
    content = entry.get("content")
    if content:
        return str(content[0].get("value", ""))
    return str(entry.get("summary", ""))


def parse_feed(content: bytes) -> list[RawOffer]:
    """Analyse un flux RSS/Atom. Les champs restent bruts : la validation se fait ensuite."""
    feed = feedparser.parse(content)
    if feed.bozo and not feed.entries:
        raise CollectorError("Flux RSS/Atom illisible.")
    offers = []
    for entry in feed.entries:
        tags = entry.get("tags") or []
        offers.append(
            RawOffer(
                url=entry.get("link"),
                title=entry.get("title"),
                description=_description(entry),
                external_id=entry.get("id") or None,
                published_at=_published_at(entry),
                company=entry.get("author") or None,
                # `region` : élément non standard publié par certains flux (ex. We Work Remotely).
                location=entry.get("region") or None,
                category=tags[0].get("term") if tags else None,
            )
        )
    return offers


class RssCollector:
    def collect(self, source: SourceConfig, client: SafeHttpClient) -> list[RawOffer]:
        return parse_feed(client.get(source.url).content)
