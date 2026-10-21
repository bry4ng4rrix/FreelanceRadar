from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.models import User

MIN_PASSWORD_LENGTH = 12


def normalize_email(email: str) -> str:
    return email.strip().lower()


def get_user_by_email(db: Session, email: str) -> User | None:
    return db.scalar(select(User).where(User.email == normalize_email(email)))


def create_user(db: Session, email: str, password: str) -> User:
    if len(password) < MIN_PASSWORD_LENGTH:
        raise ValueError(
            f"Le mot de passe doit contenir au moins {MIN_PASSWORD_LENGTH} caractères."
        )
    if get_user_by_email(db, email) is not None:
        raise ValueError("Un utilisateur existe déjà avec cet e-mail.")
    user = User(email=normalize_email(email), password_hash=hash_password(password))
    db.add(user)
    db.commit()
    return user
