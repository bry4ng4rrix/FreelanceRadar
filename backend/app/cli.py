"""Commandes d'administration.

    uv run python -m app.cli create-user --email vous@example.com
    uv run python -m app.cli import-sources data/sources.json
"""

import argparse
import getpass
import json
import sys
from pathlib import Path

from pydantic import TypeAdapter, ValidationError

from app.db.session import get_sessionmaker
from app.schemas.source import SourceCreate
from app.services.source_service import import_sources
from app.services.user_service import create_user


def _create_user(email: str) -> int:
    password = getpass.getpass("Mot de passe : ")
    if password != getpass.getpass("Confirmation : "):
        print("Les mots de passe ne correspondent pas.", file=sys.stderr)
        return 1
    with get_sessionmaker()() as db:
        try:
            user = create_user(db, email, password)
        except ValueError as exc:
            print(str(exc), file=sys.stderr)
            return 1
    print(f"Utilisateur {user.id} créé.")
    return 0


def _import_sources(path: Path) -> int:
    try:
        items = TypeAdapter(list[SourceCreate]).validate_python(json.loads(path.read_text()))
    except (OSError, json.JSONDecodeError, ValidationError) as exc:
        print(f"Fichier invalide : {exc}", file=sys.stderr)
        return 1
    with get_sessionmaker()() as db:
        result = import_sources(db, items)
    print(f"Créées : {len(result.created)} ; ignorées (déjà présentes) : {len(result.skipped)}")
    for name in result.created:
        print(f"  + {name}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.cli")
    sub = parser.add_subparsers(dest="command", required=True)
    user = sub.add_parser("create-user", help="Créer un utilisateur (mot de passe demandé).")
    user.add_argument("--email", required=True)
    imp = sub.add_parser("import-sources", help="Importer des sources depuis un fichier JSON.")
    imp.add_argument("path", type=Path)
    args = parser.parse_args(argv)
    if args.command == "create-user":
        return _create_user(args.email)
    return _import_sources(args.path)


if __name__ == "__main__":
    raise SystemExit(main())
