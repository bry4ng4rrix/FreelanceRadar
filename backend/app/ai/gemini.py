from google import genai
from google.genai import errors, types
from pydantic import ValidationError

from app.ai.base import AIError
from app.ai.prompts import SYSTEM_INSTRUCTION, build_application_prompt
from app.ai.schemas import ApplicationPromptInput, GeneratedApplication
from app.core.config import Settings


class GeminiProvider:
    """Gemini via le SDK officiel `google-genai` (sortie JSON contrainte par un schéma)."""

    name = "gemini"

    def __init__(self, settings: Settings, client: genai.Client | None = None) -> None:
        if settings.gemini_api_key is None:
            raise AIError("Clé Gemini absente (GEMINI_API_KEY).")
        self.model = settings.gemini_model
        self._temperature = settings.ai_temperature
        self._client = client or genai.Client(
            api_key=settings.gemini_api_key.get_secret_value(),
            http_options=types.HttpOptions(timeout=int(settings.ai_timeout_seconds * 1000)),
        )

    def generate_application(self, data: ApplicationPromptInput) -> GeneratedApplication:
        config = types.GenerateContentConfig(
            system_instruction=SYSTEM_INSTRUCTION,
            temperature=self._temperature,
            max_output_tokens=4096,
            response_mime_type="application/json",
            response_json_schema=GeneratedApplication.model_json_schema(),
        )
        try:
            response = self._client.models.generate_content(
                model=self.model, contents=build_application_prompt(data), config=config
            )
        except errors.ClientError as exc:
            if exc.code == 429:
                raise AIError("Quota Gemini atteint. Réessayez plus tard.") from exc
            if exc.code in (401, 403):
                raise AIError("Clé Gemini refusée.") from exc
            if exc.code == 404:
                raise AIError(f"Modèle Gemini introuvable : {self.model}.") from exc
            raise AIError(f"Requête refusée par Gemini (HTTP {exc.code}).") from exc
        except errors.ServerError as exc:
            raise AIError(f"Gemini est indisponible (HTTP {exc.code}).") from exc
        except errors.APIError as exc:
            raise AIError("Erreur de l'API Gemini.") from exc
        except Exception as exc:  # réseau, délai (httpx), erreurs inattendues du SDK
            raise AIError("Gemini injoignable (réseau ou délai dépassé).") from exc

        text = response.text
        if not text:
            raise AIError("Gemini n'a renvoyé aucun texte (contenu bloqué ou réponse vide).")
        try:
            return GeneratedApplication.model_validate_json(text)
        except ValidationError as exc:
            raise AIError("Réponse de Gemini invalide (format inattendu).") from exc
