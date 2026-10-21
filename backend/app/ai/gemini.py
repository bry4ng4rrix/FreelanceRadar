from google import genai
from google.genai import errors, types
from pydantic import ValidationError

from app.ai.base import AIError, AITransientError
from app.ai.prompts import SYSTEM_INSTRUCTION, build_application_prompt
from app.ai.schemas import ApplicationPromptInput, GeneratedApplication
from app.core.config import Settings


class GeminiProvider:
    """Gemini via le SDK officiel `google-genai` (sortie JSON contrainte par un schéma).

    Les modèles configurés sont essayés dans l'ordre : une erreur temporaire (surcharge, quota,
    réseau) ou un modèle introuvable fait passer au suivant. `model` indique celui qui a répondu.
    """

    name = "gemini"

    def __init__(self, settings: Settings, client: genai.Client | None = None) -> None:
        if settings.gemini_api_key is None:
            raise AIError("Clé Gemini absente (GEMINI_API_KEY).")
        self.models = list(settings.gemini_models)
        self.model = self.models[0]
        self._temperature = settings.ai_temperature
        self._client = client or genai.Client(
            api_key=settings.gemini_api_key.get_secret_value(),
            http_options=types.HttpOptions(timeout=int(settings.ai_timeout_seconds * 1000)),
        )

    def generate_application(self, data: ApplicationPromptInput) -> GeneratedApplication:
        last_error: AIError = AIError("Aucun modèle Gemini configuré.")
        for model in self.models:
            try:
                result = self._generate(model, data)
            except _ModelUnavailableError as exc:
                last_error = exc.error
                continue
            self.model = model
            return result
        raise last_error

    def _generate(self, model: str, data: ApplicationPromptInput) -> GeneratedApplication:
        config = types.GenerateContentConfig(
            system_instruction=SYSTEM_INSTRUCTION,
            temperature=self._temperature,
            max_output_tokens=4096,
            response_mime_type="application/json",
            response_json_schema=GeneratedApplication.model_json_schema(),
        )
        try:
            response = self._client.models.generate_content(
                model=model, contents=build_application_prompt(data), config=config
            )
        except errors.ClientError as exc:
            if exc.code == 429:
                raise _ModelUnavailableError(
                    AITransientError("Quota Gemini atteint. Réessayez plus tard.")
                ) from exc
            if exc.code == 404:
                raise _ModelUnavailableError(
                    AIError(f"Modèle Gemini introuvable : {model}.")
                ) from exc
            if exc.code in (401, 403):
                raise AIError("Clé Gemini refusée.") from exc
            raise AIError(f"Requête refusée par Gemini (HTTP {exc.code}).") from exc
        except errors.ServerError as exc:
            raise _ModelUnavailableError(
                AITransientError(f"Gemini est indisponible (HTTP {exc.code}).")
            ) from exc
        except errors.APIError as exc:
            raise AIError("Erreur de l'API Gemini.") from exc
        except Exception as exc:  # réseau, délai (httpx), erreurs inattendues du SDK
            raise _ModelUnavailableError(
                AITransientError("Gemini injoignable (réseau ou délai dépassé).")
            ) from exc

        text = response.text
        if not text:
            raise _ModelUnavailableError(
                AIError("Gemini n'a renvoyé aucun texte (contenu bloqué ou réponse vide).")
            )
        try:
            return GeneratedApplication.model_validate_json(text)
        except ValidationError as exc:
            # Réponse inexploitable de ce modèle : le suivant de la liste est essayé.
            raise _ModelUnavailableError(
                AIError("Réponse de Gemini invalide (texte incomplet ou format inattendu).")
            ) from exc


class _ModelUnavailableError(Exception):
    """Modèle momentanément inutilisable : on essaie le suivant de la liste."""

    def __init__(self, error: AIError) -> None:
        super().__init__(str(error))
        self.error = error
