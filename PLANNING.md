# PLANNING — FreelanceRadar

Architecture, décisions, risques, état des sources et commandes. Étapes : `ROADMAP.md`. Tâches : `TASKS.md`.

## 1. État du dépôt (mis à jour le 2026-10-21)

- Branche `master` avec commits de l'utilisateur ; le backend vit dans `backend/`.
- Backend fonctionnel : authentification JWT, sources, collecte RSS, offres, Celery + Beat (détail : `TASKS.md`).
- `main.py` vide à la racine : conservé, sa suppression attend l'accord de l'utilisateur.
- `.venv.old-py314/` : ancien environnement cassé (Python 3.14 déplacé), renommé et ignoré par Git ; suppression soumise à accord.
- Outils du poste : Docker 29.9 + Compose 5.6, `uv` (Python 3.12.15), Node, Ollama 0.40.6 (`gemma3:4b`), Flutter 3.44.8 (`~/.flutter/bin`), Android SDK 36. Absents : n8n, CMake (requis pour `flutter build linux`).
- Java par défaut : 27, non supporté par Gradle 9.1 du projet Android (« Unsupported class file major version 71 ») ; Java 17 est installé (`JAVA_HOME=/usr/lib/jvm/java-17-openjdk` ou `flutter config --jdk-dir`).
- Application mobile dans `mobile/` (Flutter, Riverpod, go_router, Dio) : voir `mobile/README.md`.
- Un conteneur d'un autre projet (`madasource-ci-db-test-1`) occupe `127.0.0.1:5434` : ne pas y toucher.

## 2. Architecture

```
Flutter ──HTTPS──► reverse proxy ──► FastAPI (backend/app)
n8n ─────HTTP (réseau interne)──►        │
                                         ├─► PostgreSQL (données ; déduplication par contraintes)
                                         └─► Redis ◄── Celery worker + Celery Beat (une seule instance)
Worker ─► connecteurs (registre : RSS aujourd'hui ; HTML/Playwright/API ensuite), plus tard IA, SMTP, IMAP, FCM
```

Organisation de `backend/app/` : `api/v1` (routes), `core` (config, sécurité, erreurs, logs, limitation), `db`, `models`, `schemas`, `services` (logique métier), `collectors` (connecteurs, client HTTP anti-SSRF, normalisation), `tasks` (Celery), `cli.py` (administration).
Dépôt cible : `backend/`, `flutter_app/`, `n8n/`, `docs/`, `scripts/`.

## 3. Décisions

| # | Décision | Raison |
|---|---|---|
| D1 | Python 3.12 via `uv` (`backend/pyproject.toml`, `uv.lock`) | Cible du projet, reproductibilité |
| D2 | Ruff (lint + format), mypy strict, pytest | Qualité vérifiable |
| D3 | Tests d'intégration sur PostgreSQL réel, base dédiée `<base>_test` recréée par Alembic (aller-retour) à chaque session | Les doublons sont garantis par des contraintes PostgreSQL |
| D4 | **JWT** (accès 15 min, renouvellement 7 j) + Argon2id ; révocation globale par `token_version` (logout) ; pas d'inscription publique (`create-user` en CLI) | Prompt maître ; application mono-utilisateur pour l'instant |
| D5 | PostgreSQL/Redis liés à `127.0.0.1` en dev, jamais publiés en production | Sécurité |
| D6 | SQLAlchemy **synchrone** (psycopg 3) dans l'API et Celery | Un seul modèle d'accès aux données, Celery est synchrone |
| D7 | Déduplication : unique `(source_id, external_id)` + unique `url_normalized` ; `fingerprint` indexé pour le rapprochement futur ; insertion `ON CONFLICT DO NOTHING` | Robuste face aux exécutions concurrentes |
| D8 | Client HTTP de collecte : schémas http(s), ports 80/443, IP publiques uniquement, redirections revalidées, taille max, délai | Protection SSRF |
| D9 | 401/403/429 → source `blocked`, plus planifiée automatiquement ; erreurs réseau/5xx → 3 reprises Celery avec backoff (60/120/240 s) | Ne jamais contourner une protection ; reprises raisonnables |
| D10 | Verrou Redis par source pendant une collecte | Pas de collectes concurrentes d'une même source |
| D11 | Import de sources idempotent par nom, jamais d'écrasement ; suppression refusée si la source a un historique (désactiver à la place) | Aucune perte de données |
| D12 | `httpx2` (remplaçant indiqué par Starlette) pour le client HTTP et les tests | Avertissement de dépréciation de Starlette |
| D13 | `.env` unique à la racine, partagé par Docker Compose et le backend | Une seule source de configuration |
| D14 | Un profil par utilisateur, créé vide au premier `GET /profile` (e-mail du compte prérempli) ; niveaux de compétence toujours saisis par l'utilisateur | Pas d'inscription séparée ; ne jamais inventer une compétence |
| D15 | Notifications persistées pour tous les utilisateurs actifs, uniques par `(user_id, dedup_key)` ; nouvelles offres = 1 par collecte ; erreurs = seulement sur changement d'état ; un échec de notification n'affecte pas la collecte | Pas de spam ni de doublon (`notifications.md` §7) |
| D16 | Sans FCM, le badge mobile est relu toutes les 60 s au premier plan | En attendant le projet Firebase |
| D17 | Une seule image backend (Python 3.12.15-slim, uv 0.13.0, utilisateur non root) pour API, worker, Beat et migrations ; `migrate` s'exécute avant les autres à chaque `up` | Démarrage en une commande, migrations fiables |
| D18 | SMTP en TLS direct (port 465, certificat vérifié) ; secrets uniquement dans `.env` ; envoi désactivé (`EMAIL_SENDING_ENABLED=false`) | Serveur sondé : 465 et 587 disponibles, 25 fermé |
| D19 | Gemini via `google-genai`, sortie JSON contrainte par schéma puis revalidée (longueurs, texte de remplacement refusé, compétences hors profil retirées) ; annonce transmise comme donnée non fiable | `prompt.md` §11 ; injection testée |
| D20 | Modèles à offre gratuite en cascade ; 503/429/réseau = erreur temporaire (modèle suivant, puis reprises Celery 30/60/120 s) | Tarifs officiels vérifiés le 2026-10-21 |
| D21 | Candidature : une par offre ; envoi uniquement après `confirm: true`, destinataire saisi par l'utilisateur, réservation atomique (`sending`), `sent` après acceptation SMTP, `delivery_unknown` jamais renvoyé, limite quotidienne | `prompt.md` §12, `notifications.md` §4 |
| D22 | `COLLECTION_SCHEDULER` : `beat` (fréquence par source) ou `n8n` (collecte quotidienne via `POST /automation/collections/run`, jeton de service) ; jamais les deux | Éviter deux planificateurs concurrents |
| D23 | IMAP en lecture seule (EXAMINE, BODY.PEEK) ; seules les réponses associées à une candidature sont stockées (texte seul, pièces jointes ignorées) | Minimisation des données |
| D24 | Production : image GHCR par commit (`sha-…`), déploiement par clé SSH dédiée (`restrict`), secrets applicatifs uniquement dans le `.env` du VPS ; ports publiés sur 127.0.0.1 seulement | Même méthode que les autres projets du serveur |

## 4. Risques et limites connus

- **DNS rebinding** : entre la validation DNS et la connexion, la résolution peut changer. Risque résiduel documenté dans `collectors/http.py`.
- **Limitation de connexion** : par couple IP + e-mail (5 échecs / 15 min). Un attaquant multipliant les IP n'est pas freiné globalement. Dans Docker sans reverse proxy, l'IP vue est celle de la passerelle Docker : la limite devient de fait par e-mail.
- **Jetons de renouvellement** sans rotation stockée : un refresh volé reste valable jusqu'à expiration ou déconnexion (qui révoque tout).
- **Sources Playwright** : sélecteurs fournis par l'utilisateur, non vérifiés ; aucun connecteur Playwright encore.
- **Périmètre** : backend + application mobile (offres, sources) ; n8n, IA, e-mails non commencés.
- **Mobile** : HTTP en clair autorisé (`usesCleartextTraffic`) pour le réseau local ; à retirer avec le passage en HTTPS. Les compteurs de l'accueil font 4 appels `GET /offers` : un endpoint de statistiques (FR-023) les remplacera.

## 5. État réel des sources (vérifié le 2026-10-21)

| Source | Type | Résultat observé | État |
|---|---|---|---|
| We Work Remotely — Full Stack | rss | HTTP 200, 76 items ; `robots.txt` autorise | ✅ collectée (75 offres + 1 doublon) |
| Remotive — feed | rss | HTTP 200, 10 items ; chemin non interdit par `robots.txt` | ✅ collectée — **Remotive demande ≤ 4 appels/jour** pour son API : fréquence de 30 min à porter à ≥ 360 min |
| Upwork ×2 | rss | 404 (User-Agent du backend), 403 (curl) | ❌ flux indisponibles — à désactiver |
| Codeur, Free-Work, Malt, Freelancer, Contra, goLance, Guru, DevJobScanner | playwright | Non testées : aucun connecteur Playwright ; CGU et sélecteurs à vérifier | ⏸ non collectées |
| Asako.mg (`https://www.asako.mg/freelance`) | ? | Citée dans le prompt maître, absente du JSON | ⏸ à évaluer |

## 6. Commandes vérifiées

Depuis la racine (`.env` requis, copier `.env.example`) :

| Usage | Commande |
|---|---|
| Tout le backend (PostgreSQL, Redis, migrations, API, worker, Beat) | `docker compose up -d --build` puis `docker compose ps` |
| PostgreSQL + Redis seulement (développement avec uv) | `docker compose up -d postgres redis` |
| Logs | `docker compose logs -f api worker beat` |
| Commandes d'administration dans Docker | `docker compose exec api python -m app.cli <commande>` |
| Arrêter (données conservées) | `docker compose down` |

Depuis `backend/` :

| Usage | Commande |
|---|---|
| Installer | `uv sync` |
| Migrer | `uv run alembic upgrade head` (vérifier : `uv run alembic check`) |
| ⚠️ Jamais de `alembic downgrade` sur la base de développement | L'aller-retour des migrations est vérifié automatiquement par `pytest` sur `<base>_test` (incident du 2026-10-21 : tables profil/compétences/notifications de dev supprimées par un downgrade) |
| Créer un utilisateur | `uv run python -m app.cli create-user --email vous@example.com` |
| Importer les sources | `uv run python -m app.cli import-sources data/sources.json` |
| API | `uv run uvicorn app.main:app --reload` → http://127.0.0.1:8000/docs |
| Worker | `uv run celery -A app.tasks.celery_app worker --loglevel=INFO` |
| Beat (une seule instance) | `uv run celery -A app.tasks.celery_app beat --loglevel=INFO` |
| Tester le SMTP (aucun envoi) | `uv run python -m app.cli check-smtp` |
| Tests | `uv run pytest` (PostgreSQL requis pour l'intégration, sinon ignorés avec raison) |
| Qualité | `uv run ruff check . && uv run ruff format --check . && uv run mypy app tests migrations/env.py` |

## 7. Agents, skills et règles

- Pas de sous-agent permanent. Sous-agent ponctuel pour l'évaluation des sources (beaucoup de pages web, contexte isolé) et `/security-review` en fin d'étape.
- Skill `verify` (ruff + mypy + pytest + `docker compose ps`) à créer si la vérification se répète souvent.
