# CHANGELOG — FreelanceRadar

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## [Non publié]

### Ajouté
- Documents de pilotage : `ROADMAP.md`, `PLANNING.md`, `CHANGELOG.md` ; `TASKS.md` restructuré (FR-001).
- Backend FastAPI dans `backend/` : configuration, logs JSON, erreurs standardisées, CORS explicite, `GET /api/v1/health` et `/ready` (FR-002, FR-003).
- Docker Compose de développement : PostgreSQL 17.11 et Redis 8.2.10 sur `127.0.0.1` (FR-003).
- Schéma PostgreSQL et migration Alembic initiale : utilisateurs, sources, offres, historique de collecte (FR-004, FR-010).
- Authentification JWT (accès, renouvellement, déconnexion révoquant tous les jetons), Argon2id, limitation des échecs de connexion (FR-005).
- Sources : CRUD, import idempotent (API et CLI), test sans écriture, lancement manuel, historique (FR-010).
- Collecte RSS avec client HTTP anti-SSRF, normalisation, déduplication PostgreSQL, Celery + Beat, verrou par source, reprises avec backoff (FR-006, FR-011, FR-012).
- Offres : recherche, filtres, tri, pagination, statut, notes, archivage (FR-012).
- `backend/data/sources.json` : les 12 sources fournies par l'utilisateur.

### Corrigé
- Le gestionnaire d'erreurs standard conserve désormais les en-têtes HTTP (`WWW-Authenticate`).
