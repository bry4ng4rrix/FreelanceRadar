"""Import de tous les modèles : nécessaire pour que Alembic voie l'ensemble des tables."""

from app.models.collection_run import CollectionRun
from app.models.offer import Offer
from app.models.source import Source
from app.models.user import User

__all__ = ["CollectionRun", "Offer", "Source", "User"]
