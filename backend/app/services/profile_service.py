from typing import Any

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models import Profile, Skill, User


class DuplicateSkillError(Exception):
    pass


def get_or_create_profile(db: Session, user: User) -> Profile:
    """Profil de l'utilisateur, créé vide au premier accès (e-mail du compte prérempli)."""
    profile = db.scalar(select(Profile).where(Profile.user_id == user.id))
    if profile is not None:
        return profile
    profile = Profile(user_id=user.id, primary_email=user.email)
    db.add(profile)
    try:
        db.commit()
    except IntegrityError:
        # Création concurrente (deux premières requêtes simultanées) : on relit.
        db.rollback()
        return db.scalars(select(Profile).where(Profile.user_id == user.id)).one()
    return profile


def update_profile(db: Session, profile: Profile, changes: dict[str, Any]) -> Profile:
    for field, value in changes.items():
        # Les URL validées par Pydantic sont stockées en texte.
        if field.endswith("_url") and value is not None:
            value = str(value)
        setattr(profile, field, value)
    db.commit()
    return profile


def list_skills(db: Session, profile: Profile) -> list[Skill]:
    stmt = select(Skill).where(Skill.profile_id == profile.id).order_by(func.lower(Skill.name))
    return list(db.scalars(stmt))


def get_skill(db: Session, profile: Profile, skill_id: int) -> Skill | None:
    """Compétence du profil ; None si elle n'existe pas ou appartient à un autre profil."""
    return db.scalar(select(Skill).where(Skill.id == skill_id, Skill.profile_id == profile.id))


def save_skill(db: Session, skill: Skill) -> Skill:
    db.add(skill)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise DuplicateSkillError from exc
    return skill
