from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.deps import CurrentUser, DbDep
from app.models import Profile, Skill
from app.schemas.profile import ProfileRead, ProfileUpdate, SkillCreate, SkillRead, SkillUpdate
from app.services.profile_service import (
    DuplicateSkillError,
    get_or_create_profile,
    get_skill,
    list_skills,
    save_skill,
    update_profile,
)

router = APIRouter(prefix="/profile", tags=["profil"])


def current_profile(user: CurrentUser, db: DbDep) -> Profile:
    return get_or_create_profile(db, user)


ProfileDep = Annotated[Profile, Depends(current_profile)]

_DUPLICATE = "Cette compétence est déjà dans votre profil."


def _skill_or_404(db: DbDep, profile: Profile, skill_id: int) -> Skill:
    skill = get_skill(db, profile, skill_id)
    if skill is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Compétence introuvable.")
    return skill


@router.get("", response_model=ProfileRead)
def read_profile(profile: ProfileDep) -> Profile:
    """Profil de l'utilisateur connecté (créé vide au premier accès)."""
    return profile


@router.patch("", response_model=ProfileRead)
def patch_profile(body: ProfileUpdate, profile: ProfileDep, db: DbDep) -> Profile:
    return update_profile(db, profile, body.model_dump(exclude_unset=True))


@router.get("/skills", response_model=list[SkillRead])
def read_skills(profile: ProfileDep, db: DbDep) -> list[Skill]:
    return list_skills(db, profile)


@router.post("/skills", response_model=SkillRead, status_code=status.HTTP_201_CREATED)
def create_skill(body: SkillCreate, profile: ProfileDep, db: DbDep) -> Skill:
    try:
        return save_skill(db, Skill(profile_id=profile.id, **body.model_dump()))
    except DuplicateSkillError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, _DUPLICATE) from exc


@router.patch("/skills/{skill_id}", response_model=SkillRead)
def patch_skill(skill_id: int, body: SkillUpdate, profile: ProfileDep, db: DbDep) -> Skill:
    skill = _skill_or_404(db, profile, skill_id)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(skill, field, value)
    try:
        return save_skill(db, skill)
    except DuplicateSkillError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, _DUPLICATE) from exc


@router.delete("/skills/{skill_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_skill(skill_id: int, profile: ProfileDep, db: DbDep) -> None:
    db.delete(_skill_or_404(db, profile, skill_id))
    db.commit()
