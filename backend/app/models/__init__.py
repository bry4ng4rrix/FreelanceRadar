"""Import de tous les modèles : nécessaire pour que Alembic voie l'ensemble des tables."""

from app.models.application import Application
from app.models.collection_run import CollectionRun
from app.models.notification import Notification
from app.models.offer import Offer
from app.models.profile import Profile, Skill
from app.models.source import Source
from app.models.user import User

__all__ = [
    "Application",
    "CollectionRun",
    "Notification",
    "Offer",
    "Profile",
    "Skill",
    "Source",
    "User",
]
