# FreelanceRadar

Agrégateur personnel d'offres freelance : collecte (RSS d'abord), déduplication, API sécurisée.
État d'avancement : `ROADMAP.md`. Commandes et décisions : `PLANNING.md`.

## Démarrage local (backend)

Prérequis : Docker + Compose, [uv](https://docs.astral.sh/uv/).

```bash
# 1. Configuration : copier puis remplacer chaque "change-me" par un secret fort
cp .env.example .env
python3 -c "import secrets; print(secrets.token_hex(32))"

# 2. PostgreSQL et Redis
docker compose up -d
docker compose ps            # les deux services doivent être "healthy"

# 3. Backend
cd backend
uv sync
uv run alembic upgrade head
uv run python -m app.cli create-user --email vous@example.com   # mot de passe demandé (12 caractères min.)
uv run python -m app.cli import-sources data/sources.json

# 4. Lancer (trois terminaux)
uv run uvicorn app.main:app --reload                             # API : http://127.0.0.1:8000/docs
uv run celery -A app.tasks.celery_app worker --loglevel=INFO     # exécute les collectes
uv run celery -A app.tasks.celery_app beat --loglevel=INFO       # planificateur (une seule instance)
```

Dans Swagger (`/docs`) : `POST /api/v1/auth/login`, copier `access_token`, puis bouton **Authorize**.

## Tests et qualité

```bash
cd backend
uv run pytest            # tests d'intégration sur la base <POSTGRES_DB>_test (créée automatiquement)
uv run ruff check . && uv run ruff format --check . && uv run mypy app tests migrations/env.py
```

## Sources

Les sources se gèrent via l'API (`/api/v1/sources`). Seul le connecteur RSS existe pour l'instant ; l'état réel de chaque source est tenu dans `PLANNING.md` §5. Une source qui répond 401/403/429 passe en `blocked` et n'est plus collectée automatiquement : aucune protection n'est contournée.
