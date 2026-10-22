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
- Application mobile `mobile/` adaptée au backend FreelanceRadar (ancienne « Garrix Offre ») : connexion JWT sans inscription, accueil, offres (recherche, filtres, favoris, statut, notes, archivage), sources (création, test, collecte, historique), réglages ; identifiant Android `mg.garrix.freelanceradar`, icônes « F » (FR-070a).
- Profil professionnel et compétences : API `/profile` et `/profile/skills`, écrans mobiles Profil, Modifier le profil, Compétences (FR-020a).
- Centre de notifications : nouvelles offres et sources en erreur ou bloquées, API `/notifications`, onglet mobile Alertes avec badge (FR-051a).
- Migration `9e708b8a9030` : tables `profiles`, `skills`, `notifications` (ajout uniquement).
- Docker : image du backend et services `migrate`, `api`, `worker`, `beat` ; tout le backend démarre avec `docker compose up -d --build` (FR-007).
- Configuration SMTP (variables `SMTP_*`, envoi désactivé par défaut) et commande `check-smtp` qui vérifie la connexion sans rien envoyer (FR-041a).
- Candidatures rédigées par Gemini (modèles gratuits, reprises automatiques), validation puis envoi SMTP, notifications « prête à valider », « envoyée », « échec » ; migration `2497f2b33a23`.
- Mobile : onglet Rapport, écran de candidature avec validation de l'envoi ; Sources accessibles depuis les Réglages.
- Réponses des clients lues par IMAP (lecture seule), associées aux candidatures, notifiées et affichées dans le Rapport ; migration `d641e0c2acf4`.
- n8n : collecte quotidienne automatique (workflow importé et activé au démarrage).
- Production : `docker-compose.prod.yml`, workflow GitHub Actions (tests, image GHCR, déploiement SSH), guide `docs/DEPLOYMENT.md`.

### Modifié
- Sources : Codeur.com et Freelancer.com collectées par leurs flux RSS officiels ; Malt, Guru, Contra, Free-Work, goLance, DevJobScanner et Upwork désactivées ; Remotive toutes les 6 h (FR-013).
- Mobile : la liste des offres est triée par défaut par date de publication, de la plus récente à la plus ancienne (au lieu de la date de collecte).

### Supprimé
- Mobile : écrans sans équivalent backend (candidatures, documents, notifications, profil, administration, temps réel), conservés dans le commit `f55f266`.

### Corrigé
- Le gestionnaire d'erreurs standard conserve désormais les en-têtes HTTP (`WWW-Authenticate`).
