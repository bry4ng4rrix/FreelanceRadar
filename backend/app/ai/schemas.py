from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, Field


class ApplicationPromptInput(BaseModel):
    """Données envoyées au modèle : uniquement le profil réel et l'offre."""

    offer_title: str
    offer_description: str
    offer_company: str | None = None
    offer_location: str | None = None
    offer_budget: str | None = None
    offer_url: str
    candidate_name: str | None = None
    candidate_title: str | None = None
    candidate_summary: str | None = None
    candidate_location: str | None = None
    candidate_languages: list[str] = []
    candidate_availability: str
    candidate_rate: str | None = None
    candidate_links: dict[str, str] = {}
    candidate_skills: list[dict[str, str | Decimal | None]] = []


class GeneratedApplication(BaseModel):
    """Sortie structurée exigée du modèle (`prompt.md` §11), revalidée côté serveur."""

    subject: str = Field(min_length=1, max_length=200, description="Objet de l'e-mail.")
    message: str = Field(
        min_length=1, max_length=8000, description="Corps de l'e-mail, texte brut, signé."
    )
    language: Literal["fr", "en"] = Field(description="Langue de l'annonce et du message.")
    referenced_skills: list[str] = Field(
        default_factory=list, description="Compétences du profil citées dans le message."
    )
    warnings: list[str] = Field(
        default_factory=list,
        description="Points à vérifier par le candidat (informations manquantes, doutes).",
    )
    confidence: float = Field(ge=0, le=1, description="Adéquation estimée entre profil et offre.")
