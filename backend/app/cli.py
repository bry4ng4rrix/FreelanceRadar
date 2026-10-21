"""Commandes d'administration.

uv run python -m app.cli create-user --email vous@example.com
uv run python -m app.cli import-sources data/sources.json
uv run python -m app.cli check-smtp   # connexion + authentification, aucun envoi
uv run python -m app.cli check-imap   # lecture seule : nombre de messages, rien n'est modifié
"""

import argparse
import getpass
import json
import sys
from pathlib import Path

from pydantic import TypeAdapter, ValidationError

from app.core.config import get_settings
from app.db.session import get_sessionmaker
from app.schemas.source import SourceCreate
from app.services.email_service import check_smtp_connection
from app.services.imap_service import ImapError, open_mailbox
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


def _check_smtp() -> int:
    result = check_smtp_connection(get_settings())
    print(result.message, file=sys.stdout if result.ok else sys.stderr)
    return 0 if result.ok else 1


def _check_imap() -> int:
    settings = get_settings()
    try:
        with open_mailbox(settings) as mailbox:
            status = mailbox.status()
    except ImapError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print(
        f"Connexion IMAP réussie, dossier « {settings.imap_folder} » ouvert en lecture seule "
        f"(prochain UID : {status.uidnext})."
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.cli")
    sub = parser.add_subparsers(dest="command", required=True)
    user = sub.add_parser("create-user", help="Créer un utilisateur (mot de passe demandé).")
    user.add_argument("--email", required=True)
    imp = sub.add_parser("import-sources", help="Importer des sources depuis un fichier JSON.")
    imp.add_argument("path", type=Path)
    sub.add_parser("check-smtp", help="Tester la connexion SMTP (aucun e-mail envoyé).")
    sub.add_parser("check-imap", help="Tester la lecture IMAP (lecture seule).")
    args = parser.parse_args(argv)
    if args.command == "create-user":
        return _create_user(args.email)
    if args.command == "check-smtp":
        return _check_smtp()
    if args.command == "check-imap":
        return _check_imap()
    return _import_sources(args.path)


if __name__ == "__main__":
    raise SystemExit(main())
