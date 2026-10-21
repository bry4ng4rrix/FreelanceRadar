"""Création des notifications persistées (centre de notifications).

Une notification par événement et par utilisateur actif, jamais en double (`dedup_key`).
"""

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.models import CollectionRun, Notification, Source, User

_FAILURE_TYPES = {"error": "source_error", "blocked": "source_blocked"}
_FAILURE_TITLES = {
    "source_error": "Source en erreur",
    "source_blocked": "Source bloquée par le site",
}


def notify_active_users(
    db: Session,
    *,
    type: str,
    title: str,
    body: str,
    dedup_key: str,
    offer_id: int | None = None,
    source_id: int | None = None,
    run_id: int | None = None,
) -> int:
    """Notifie chaque utilisateur actif. Renvoie le nombre de notifications créées."""
    user_ids = list(db.scalars(select(User.id).where(User.is_active.is_(True))))
    if not user_ids:
        return 0
    rows = [
        {
            "user_id": user_id,
            "type": type,
            "title": title,
            "body": body,
            "dedup_key": dedup_key,
            "offer_id": offer_id,
            "source_id": source_id,
            "collection_run_id": run_id,
        }
        for user_id in user_ids
    ]
    stmt = (
        insert(Notification)
        .values(rows)
        .on_conflict_do_nothing(constraint="uq_notifications_user_id_dedup_key")
        .returning(Notification.id)
    )
    return len(db.execute(stmt).all())


def notify_collection_outcome(
    db: Session,
    source: Source,
    run: CollectionRun,
    previous_health: str,
    new_offer_ids: list[int],
) -> int:
    """Notifications d'une collecte terminée.

    - nouvelles offres : une seule notification par collecte (jamais une par offre) ;
    - erreur ou blocage : seulement quand l'état de la source change, pas à chaque tentative.
    """
    if run.status == "success" and new_offer_ids:
        count = len(new_offer_ids)
        plural = "s" if count > 1 else ""
        return notify_active_users(
            db,
            type="new_offers",
            title=f"Nouvelle{plural} offre{plural}",
            body=f"{count} nouvelle{plural} offre{plural} — {source.name}",
            dedup_key=f"run:{run.id}:new_offers",
            # Une seule offre : la notification ouvre directement sa fiche.
            offer_id=new_offer_ids[0] if count == 1 else None,
            source_id=source.id,
            run_id=run.id,
        )
    notification_type = _FAILURE_TYPES.get(source.health_status)
    if notification_type is None or source.health_status == previous_health:
        return 0
    detail = (run.error_message or "Erreur inconnue.")[:300]
    return notify_active_users(
        db,
        type=notification_type,
        title=_FAILURE_TITLES[notification_type],
        body=f"{source.name} : {detail}",
        dedup_key=f"run:{run.id}:{notification_type}",
        source_id=source.id,
        run_id=run.id,
    )
