from typing import Annotated

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.api.deps import CollectionQueue, DbDep, get_collection_queue, require_service_token
from app.services.collection_service import schedulable_source_ids

router = APIRouter(
    prefix="/automation",
    tags=["automatisations"],
    dependencies=[Depends(require_service_token)],
)


class CollectionRunQueued(BaseModel):
    queued: list[int]
    task_ids: list[str]


@router.post("/collections/run", response_model=CollectionRunQueued)
def run_collections(
    db: DbDep, queue: Annotated[CollectionQueue, Depends(get_collection_queue)]
) -> CollectionRunQueued:
    """Met en file la collecte de toutes les sources actives (workflow n8n quotidien).

    Les sources bloquées par leur site ou sans connecteur sont exclues.
    """
    ids = schedulable_source_ids(db)
    return CollectionRunQueued(
        queued=ids, task_ids=[queue.enqueue(source_id, "schedule") for source_id in ids]
    )
