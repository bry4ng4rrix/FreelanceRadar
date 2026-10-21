from app.ai.base import AINotConfiguredError, AIProvider
from app.core.config import Settings


def get_provider(settings: Settings) -> AIProvider:
    """Fournisseur IA configuré. La collecte et l'API fonctionnent sans IA (`prompt.md` §16)."""
    if settings.ai_provider == "disabled":
        raise AINotConfiguredError("La génération IA est désactivée (AI_PROVIDER=disabled).")
    if settings.gemini_api_key is None:
        raise AINotConfiguredError("Clé Gemini absente : ajoutez GEMINI_API_KEY dans .env.")
    from app.ai.gemini import GeminiProvider  # import différé : SDK chargé seulement si utilisé

    return GeminiProvider(settings)
