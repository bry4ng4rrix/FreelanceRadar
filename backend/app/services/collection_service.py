"""Exécution d'une collecte : connecteur → validation → normalisation → insertion dédupliquée."""

import logging
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any, Literal

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.collectors.base import RawOffer, SourceConfig
from app.collectors.errors import (
    CollectorError,
    SourceBlockedError,
    TransientCollectorError,
    UnsupportedConnectorError,
)
from app.collectors.http import SafeHttpClient
from app.collectors.normalize import clean_line, fingerprint, html_to_text, normalize_url
from app.collectors.registry import get_collector, supported_target_types
from app.db.base import utcnow
from app.models import CollectionRun, Offer, Source

logger = logging.getLogger(__name__)

Trigger = Literal["manual", "schedule"]
# Statuts de santé pour lesquels la planification automatique s'arrête.
_NOT_SCHEDULABLE = ("blocked", "unsupported")


@dataclass(frozen=True)
class CollectionResult:
    run: CollectionRun
    # Vrai si l'échec est temporaire (réseau, HTTP 5xx) : une reprise différée a du sens.
    retryable: bool


@dataclass(frozen=True)
class NormalizedOffers:
    rows: list[dict[str, Any]]
    invalid: int


def to_source_config(source: Source) -> SourceConfig:
    return SourceConfig(
        id=source.id, url=source.url, target_type=source.target_type, selectors=source.selectors
    )


def normalize_offers(source_id: int, raw_offers: list[RawOffer]) -> NormalizedOffers:
    rows: list[dict[str, Any]] = []
    invalid = 0
    for raw in raw_offers:
        title = clean_line(raw.title, 500)
        if not title or not raw.url:
            invalid += 1
            continue
        try:
            url_normalized = normalize_url(raw.url)
        except ValueError:
            invalid += 1
            continue
        description = html_to_text(raw.description)
        rows.append(
            {
                "source_id": source_id,
                "external_id": (raw.external_id or "").strip()[:500] or None,
                "url": raw.url.strip(),
                "url_normalized": url_normalized,
                "fingerprint": fingerprint(title, description),
                "title": title,
                "description": description,
                "company": clean_line(raw.company, 300),
                "location": clean_line(raw.location, 300),
                "category": clean_line(raw.category, 200),
                "published_at": raw.published_at,
                "skills": [],
                "status": "new",
            }
        )
    return NormalizedOffers(rows=rows, invalid=invalid)


def store_offers(db: Session, rows: list[dict[str, Any]]) -> int:
    """Insère les offres ; les doublons sont écartés par les contraintes PostgreSQL."""
    if not rows:
        return 0
    stmt = insert(Offer).values(rows).on_conflict_do_nothing().returning(Offer.id)
    return len(db.execute(stmt).all())


def run_collection(
    db: Session,
    source_id: int,
    client: SafeHttpClient,
    trigger: Trigger,
    task_id: str | None = None,
) -> CollectionResult:
    source = db.get(Source, source_id)
    if source is None:
        raise LookupError(f"Source {source_id} introuvable.")

    run = CollectionRun(source_id=source.id, trigger=trigger, status="running", task_id=task_id)
    db.add(run)
    source.last_attempt_at = utcnow()
    db.commit()

    retryable = False
    try:
        raw_offers = get_collector(source.target_type).collect(to_source_config(source), client)
        normalized = normalize_offers(source.id, raw_offers)
        new_count = store_offers(db, normalized.rows)
    except UnsupportedConnectorError as exc:
        _record_failure(source, run, "unsupported", "unsupported", str(exc))
    except SourceBlockedError as exc:
        _record_failure(source, run, "blocked", "blocked", str(exc))
    except TransientCollectorError as exc:
        retryable = True
        _record_failure(source, run, "failed", "error", str(exc))
    except CollectorError as exc:
        _record_failure(source, run, "failed", "error", str(exc))
    except Exception:
        db.rollback()
        logger.exception("Erreur inattendue pendant la collecte de la source %s", source_id)
        _record_failure(source, run, "failed", "error", "Erreur interne pendant la collecte.")
    else:
        run.status = "success"
        run.items_seen = len(raw_offers)
        run.items_new = new_count
        run.items_invalid = normalized.invalid
        run.items_duplicate = len(normalized.rows) - new_count
        source.health_status = "ok"
        source.last_success_at = utcnow()
        source.last_error = None
        source.consecutive_failures = 0
        source.offers_count += new_count

    run.finished_at = utcnow()
    db.commit()
    logger.info(
        "Collecte source=%s run=%s statut=%s nouvelles=%s doublons=%s invalides=%s",
        source.id,
        run.id,
        run.status,
        run.items_new,
        run.items_duplicate,
        run.items_invalid,
    )
    return CollectionResult(run=run, retryable=retryable)


def _record_failure(
    source: Source, run: CollectionRun, run_status: str, health: str, message: str
) -> None:
    run.status = run_status
    run.error_message = message[:2000]
    source.health_status = health
    source.last_error = message[:2000]
    source.error_count += 1
    source.consecutive_failures += 1


def is_due(source: Source, now: datetime) -> bool:
    if source.last_attempt_at is None:
        return True
    return source.last_attempt_at + timedelta(minutes=source.frequency_minutes) <= now


def due_source_ids(db: Session, now: datetime) -> list[int]:
    """Sources actives, avec connecteur, non bloquées, dont la fréquence est écoulée."""
    stmt = select(Source).where(
        Source.is_active.is_(True),
        Source.target_type.in_(supported_target_types()),
        Source.health_status.not_in(_NOT_SCHEDULABLE),
    )
    return [s.id for s in db.scalars(stmt) if is_due(s, now)]
