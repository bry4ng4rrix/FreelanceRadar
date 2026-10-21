# PLANNING — FreelanceRadar

Architecture, décisions et risques. Phases : `ROADMAP.md`. Tâches : `TASKS.md`.

## 1. État constaté (audit du 2026-10-21, FR-001)

- Dépôt Git sans aucun commit, branche `master` (la branche principale attendue est `main`).
- Fichiers indexés : `CLAUDE.md`, `TASKS.md`, `prompt.md` (spec cœur), `notifications.md` (spec e-mail/FCM/Flutter), `main.py` (vide).
- Aucun code, test, `pyproject.toml`, `Dockerfile`, `docker-compose.yml`, `.env.example` ni `.gitignore`.
- `.venv/` **inutilisable en l'état** : Python 3.14 (cible : 3.12), créé à l'origine dans `/home/garrix/Dev/freelancer/.venv` puis déplacé ; ses scripts pointent vers un interpréteur inexistant (`.venv/bin/uvicorn` → « mauvais interpréteur »). Non ignoré par Git. Paquets installés à la main, sans fichier de dépendances : FastAPI, Pydantic, pydantic-settings, uvicorn, httpx. Absents : SQLAlchemy, Alembic, pytest, ruff, mypy, Celery, psycopg, feedparser, Playwright.
- Outils vérifiés sur le poste : Docker 29.9 (démon actif) + Compose 5.6, `uv` (Python 3.12.15 installé), client `psql`, Node, Ollama 0.40.6 actif sur `127.0.0.1:11434` avec le modèle `gemma3:4b`. Absents : Flutter, `redis-server` local (Redis passera par Docker), n8n local.
- Ports libres : 5432, 6379, 8000, 5678. Un conteneur d'un autre projet (`madasource-ci-db-test-1`, PostgreSQL 18.6) occupe `127.0.0.1:5434` : ne pas le toucher et ne pas réutiliser ce port.

Conclusion : rien n'est fonctionnel ; tout reste à construire à partir de la spec.

## 2. Architecture cible

```
Flutter ──HTTPS──► reverse proxy ──► FastAPI (api)
n8n ─────HTTP (réseau Docker interne)──►   │
                                           ├─► PostgreSQL (données, déduplication par contraintes)
                                           └─► Redis ◄─ Celery worker / Celery Beat
Celery worker ─► collecteurs (RSS, HTTP/HTML, Playwright), IA (Gemini/Ollama), SMTP, IMAP, FCM
```

- Code dans `app/` selon la structure de `prompt.md` §4 : `api/`, `models/`, `schemas/`, `services/`, `collectors/`, `ai/`, `tasks/`, `core/`, `db/`.
- La logique métier reste dans les services FastAPI/Celery ; n8n ne fait qu'orchestrer via l'API.
- Flutter dans `mobile/`, consommateur de l'API uniquement.

## 3. Décisions proposées (à valider)

| # | Décision | Raison |
|---|---|---|
| D1 | Gestion Python par `uv` + `pyproject.toml` avec Python 3.12 épinglé ; recréer `.venv` en 3.12 (l'actuel est conservé jusqu'à accord) | Conformité à la cible, reproductibilité |
| D2 | Ruff (lint + format), mypy, pytest | Prévus par la spec |
| D3 | Tests d'intégration sur un PostgreSQL de test dédié (conteneur), jamais SQLite | Les contraintes de déduplication dépendent de PostgreSQL |
| D4 | Auth V1 : clé API en en-tête, comparée en temps constant ; modèle prêt pour utilisateurs/rôles | Spec §15 ; limites documentées |
| D5 | Ports PostgreSQL/Redis non publiés en production ; publiés sur `127.0.0.1` seulement en dev | Spec §15 |
| D6 | Secrets SMTP/IMAP stockés chiffrés en base (clé dans l'env), jamais renvoyés par l'API | `notifications.md` §12 |
| D7 | Envoi d'e-mails désactivé par défaut (`EMAIL_SENDING_ENABLED=false`) ; tests sur serveur SMTP factice | Règle 10 de `CLAUDE.md` |
| D8 | Renommer `master` → `main` au premier commit | Cohérence avec la branche principale attendue |
| D9 | `main.py` vide à la racine remplacé par `app/main.py` (suppression soumise à accord) | Structure cible |

## 4. Risques

- **Sources externes (non vérifiées)** : aucune des 13 URL n'a été testée. Les flux RSS Upwork sont possiblement retirés (information non confirmée, à vérifier en FR-014). Les sélecteurs CSS de la spec (ex. Codeur.com `.project-item`) ne sont pas vérifiés.
- **Ollama local** : `gemma3:4b` est disponible pour des tests manuels ; les tests automatisés restent sur fournisseur simulé. Depuis Docker, l'accès à Ollama hôte (`127.0.0.1`) nécessitera une configuration réseau explicite. Certaines plateformes interdisent le scraping dans leurs CGU ou ont des protections anti-bot : ne pas contourner, marquer « bloquée ».
- **SSRF** : URLs configurables → validation stricte, y compris après résolution DNS et redirections.
- **Double envoi** : idempotence obligatoire (clé unique par candidature, verrou transactionnel).
- **Données personnelles** : CV et e-mails ; jamais dans les logs.
- **Périmètre** : la spec est large (API + workers + n8n + IA + mail + mobile). Livrer verticalement, une tâche à la fois.
- **Conflit de consignes** : `prompt.md` §22 demande de démarrer la Phase 1 immédiatement ; `CLAUDE.md` impose une validation préalable. `CLAUDE.md` prévaut.

## 5. Commandes

Vérifiées le 2026-10-21 (FR-002) :

| Usage | Commande |
|---|---|
| Installer / synchroniser | `uv sync` |
| Démarrer l'API (dev) | `uv run uvicorn app.main:app --reload` → http://127.0.0.1:8000/docs |
| Tests | `uv run pytest` |
| Lint | `uv run ruff check .` |
| Format | `uv run ruff format --check .` |
| Typage | `uv run mypy app tests` |

À venir : `docker compose up -d` (FR-003), `alembic upgrade head` (FR-004).

## 6. Agents, skills et règles

Bénéfice concret seulement :
- **Maintenant** : aucun sous-agent permanent. Le projet est petit ; le contexte principal suffit.
- **Sous-agent ponctuel** `Explore`/`general-purpose` pour : vérifier l'accessibilité réelle des 13 sources (contexte isolé, beaucoup de pages web), et audit de sécurité avant chaque fin de phase (`/security-review`).
- **Skill projet** à créer en Phase 1 seulement : `verify` (lance ruff + mypy + pytest + état Docker), pour standardiser la vérification de fin de tâche.
- **Règles ciblées** : pas de nouvelle règle ; `CLAUDE.md` couvre déjà les besoins.
