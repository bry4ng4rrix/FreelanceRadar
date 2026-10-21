# TASKS — FreelanceRadar

Phases : `ROADMAP.md`. Décisions : `PLANNING.md`.

## Terminé

Une tâche passe ici uniquement lorsque ses critères d'acceptation sont satisfaits, que les tests pertinents ont été exécutés et que le résultat est documenté.

- [x] FR-001 — Analyser l'architecture et l'état actuel du dépôt.
  - Livrable : audit dans `PLANNING.md` §1 et §4.
  - Critères : structure, dépendances, commandes disponibles, risques et lacunes identifiés.

- [ ] FR-002 — Initialiser le dépôt et l'outillage Python. **(code livré, commit en attente)**
  - Dépendance : FR-001 + validation des décisions D1, D2, D8, D9.
  - Contenu : recréer `.venv` en 3.12 via `uv` (l'actuel est cassé, suppression soumise à accord), `.gitignore` (dont `.venv/`, `.env`), `pyproject.toml` (Python 3.12, FastAPI, Pydantic v2, ruff, mypy, pytest), `app/main.py` avec `GET /health`, `app/core/config.py` (pydantic-settings), `.env.example`, premier test.
  - Critères : `uv sync` OK ; `ruff check .`, `ruff format --check .`, `mypy app`, `pytest` passent ; `GET /health` = 200 en test ; aucun secret dans Git ; premier commit sur `main`.
  - Fait : socle FastAPI (`app/`), erreurs standardisées, logs JSON, `/api/v1/health`, 5 tests. Reste hors tâche : premier commit et renommage `main` (attendent votre accord) ; ancien venv conservé dans `.venv.old-py314/`.

## À faire — Phase 1 (Fondations)

- [ ] FR-003 — Docker Compose de développement : PostgreSQL, Redis, API.
  - Dépendance : FR-002.
  - Critères : `docker compose up -d` → services `healthy` ; volumes persistants (données conservées après `docker compose restart`) ; ports liés à `127.0.0.1` ; `GET /api/v1/ready` vérifie DB et Redis (`/health` reste un simple test de vie).

- [ ] FR-004 — SQLAlchemy 2 + Alembic, base de test isolée.
  - Dépendance : FR-003.
  - Critères : `alembic upgrade head` et `alembic downgrade base` OK sur base de dev ; fixture pytest sur base de test dédiée ; commandes documentées dans `PLANNING.md` §5.

- [ ] FR-005 — Authentification par clé API et journalisation sans secrets.
  - Dépendance : FR-002.
  - Critères : endpoints privés → 401 sans clé ; comparaison en temps constant ; test vérifiant l'absence de la clé dans les logs.

- [ ] FR-006 — Celery worker + Beat branchés sur Redis.
  - Dépendance : FR-003.
  - Critères : tâche `ping` exécutée par le worker en test d'intégration ; services `worker` et `beat` dans Compose.

## Backlog (phases suivantes, à détailler le moment venu)

- [ ] FR-010 — Modèles Source/Offer/ScrapingRun + import idempotent des 13 sources (Phase 2).
- [ ] FR-011 — Garde SSRF des collecteurs (Phase 2).
- [ ] FR-012 — Connecteur RSS de bout en bout sur fixture, avec déduplication (Phase 2).
- [ ] FR-013 — Connecteurs HTTP/HTML puis Playwright sur fixtures (Phase 2).
- [ ] FR-014 — Vérification réelle des 13 sources : testée / à vérifier / bloquée (Phase 2).
- [ ] FR-020 — Offres : filtres, pagination, scoring ; profil, compétences, CV (Phase 3).
- [ ] FR-030 — Sélection Gemini/Ollama et brouillons de proposition (Phase 4).
- [ ] FR-040 — Candidatures, approbation, envoi SMTP idempotent (Phase 5).
- [ ] FR-050 — Synchronisation IMAP et association des réponses (Phase 6).
- [ ] FR-051 — Centre de notifications et FCM (Phase 6).
- [ ] FR-060 — Workflows n8n (Phase 7).
- [ ] FR-070 — Application Flutter (Phase 8).
- [ ] FR-080 — Reverse proxy, sauvegardes, guide VPS (Phase 9).

## Bloqué

Pour chaque blocage, indiquer la cause, la preuve observée et l'action nécessaire pour le résoudre.

_Aucun pour le moment._
