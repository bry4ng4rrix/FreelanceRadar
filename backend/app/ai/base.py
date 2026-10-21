from typing import Protocol

from app.ai.schemas import ApplicationPromptInput, GeneratedApplication


class AIError(Exception):
    """Échec du fournisseur IA. Le message est destiné à l'utilisateur : jamais de clé dedans."""


class AINotConfiguredError(AIError):
    pass


class AITransientError(AIError):
    """Erreur temporaire (quota, surcharge, réseau) : une nouvelle tentative différée a du sens."""


class AIProvider(Protocol):
    name: str
    model: str

    def generate_application(self, data: ApplicationPromptInput) -> GeneratedApplication: ...
