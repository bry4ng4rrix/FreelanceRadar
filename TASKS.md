# TASKS — FreelanceRadar

Étapes : `ROADMAP.md`. Décisions et commandes : `PLANNING.md`.

## Terminé

Une tâche passe ici uniquement lorsque ses critères d'acceptation sont satisfaits, que les tests pertinents ont été exécutés et que le résultat est documenté.

- [x] FR-001 — Audit du dépôt. Livrable : `PLANNING.md`.
- [x] FR-002 — Socle FastAPI et outillage (`backend/`, uv, Python 3.12, ruff, mypy strict, pytest, erreurs standardisées, logs JSON, CORS explicite).
- [x] FR-003 — Docker Compose de développement : PostgreSQL 17.11 et Redis 8.2.10, `healthy`, volumes persistants, ports sur `127.0.0.1` ; `GET /api/v1/ready` vérifie les deux.
- [x] FR-004 — SQLAlchemy 2 + Alembic : migration initiale, `upgrade`/`downgrade`/`check` vérifiés ; base de test dédiée.
- [x] FR-005 — Authentification JWT : login, refresh, logout (révocation), `me` ; Argon2id ; limitation des échecs par Redis ; création d'utilisateur en CLI.
- [x] FR-006 — Celery worker + Beat : planification des sources dues, verrou par source, reprises avec backoff. Vérifié en réel.
- [x] FR-010 — Modèles Source/Offer/CollectionRun + import idempotent de `data/sources.json` (API et CLI).
- [x] FR-011 — Protection SSRF du client de collecte (IP privées, métadonnées cloud, redirections, ports, taille).
- [x] FR-012 — Premier parcours RSS de bout en bout : fixture + collecte réelle We Work Remotely et Remotive ; doublons rejetés par PostgreSQL ; offres consultables (recherche, filtres, tri, pagination, statut, notes, archivage).
  - Vérification : 72 tests (48 unitaires, 24 intégration PostgreSQL) ; ruff, format, mypy strict ; worker + Beat réels ; `/ready` = 200 ; aucun secret dans les logs.
- [x] FR-070a — Application Flutter `mobile/` adaptée au backend et renommée FreelanceRadar (thème et composants de Garrix Offre conservés) : connexion JWT, accueil, offres, sources, réglages ; modules sans backend retirés (récupérables au commit `f55f266`).
  - Vérification : `flutter analyze` sans remarque ; 30 tests (modèles, client réseau, fumée des écrans téléphone + grand écran) ; contrat comparé à l'OpenAPI réel (tous les champs lus existent).
  - Non vérifié par moi : build APK/Linux et exécution sur appareil (réalisés par l'utilisateur).
- [x] FR-020a — Profil et compétences : tables `profiles` et `skills` (migration additive `9e708b8a9030`), `GET/PATCH /profile`, CRUD `/profile/skills` (doublon refusé sans tenir compte de la casse) ; écrans mobiles Profil, Modifier le profil, Compétences.
- [x] FR-051a — Centre de notifications : table `notifications` (anti-doublon `dedup_key`), notifications « nouvelles offres » (une par collecte) et « source en erreur / bloquée » (sur changement d'état), `GET /notifications`, `unread-count`, `read`, `mark-all-read` ; onglet mobile Alertes avec badge (relu toutes les 60 s, au retour au premier plan et à l'ouverture).
  - Vérification : backend 99 tests (27 nouveaux : validation, isolation entre utilisateurs, anti-doublon, échec de notification sans effet sur la collecte), ruff, mypy strict, migration aller-retour ; mobile `flutter analyze` sans remarque, 43 tests ; contrat Dart comparé à l'OpenAPI.

- [x] FR-007 — Backend conteneurisé : `backend/Dockerfile` (non root), services `migrate`, `api`, `worker`, `beat` ; `docker compose up -d --build` démarre tout.
  - Vérification : image construite ; migrate `Exited (0)` puis api `healthy` ; `/ready` = 200 depuis l'hôte ; collectes réelles exécutées par le worker conteneurisé, déclenchées par Beat ; processus `uid=10001(app)` ; aucun secret dans les logs.
- [x] FR-041a — Configuration SMTP (`mail.labeltechnology.mg:465`, TLS) et commande `check-smtp` (connexion + authentification, aucun envoi).
  - Vérification : 6 tests sur serveur simulé (dont absence du mot de passe dans les messages) ; authentification réelle réussie une fois, depuis l'hôte puis depuis le conteneur, sans envoi.

## À faire — backend (ordre recommandé)

- [ ] FR-013 — Ajuster la configuration des sources selon `PLANNING.md` §5 (Remotive ≥ 360 min, Upwork désactivées) — **décision utilisateur requise**.
- [ ] FR-014 — Alerte de panne répétée : source passée en `error` après N échecs consécutifs visible dans l'API (base des notifications futures).
- [ ] FR-020b — Profil : expériences, diplômes et certifications.
- [ ] FR-021 — Upload privé du CV (PDF/DOCX, taille et type contrôlés, jamais journalisé).
- [ ] FR-022 — Score de pertinence explicable (raisons +/−, seuil configurable) et détection des compétences.
- [ ] FR-023 — Tableau de bord / statistiques.
- [ ] FR-030 — IA : interface commune, Gemini, Ollama (`gemma3:4b` dispo en local), sorties validées.
- [ ] FR-040 — Candidatures : brouillons versionnés, approbation, anti-doublon.
- [ ] FR-041b — Envoi SMTP des candidatures (sans envoi réel en test), statuts distincts, idempotence.
- [ ] FR-050 — IMAP et association prudente des réponses.
- [ ] FR-051b — Notifications push FCM (projet Firebase requis) et préférences par type.
- [ ] FR-013b — Connecteurs HTML/Playwright, source par source, après vérification des CGU.

## Hors focus actuel

- [ ] FR-060 — Workflows n8n.
- [ ] FR-070b — Flutter : écrans candidatures et messagerie (au fil des modules backend FR-040 à FR-050).
- [ ] FR-080 — Reverse proxy HTTPS, sauvegardes, guide VPS.

## Bloqué

Pour chaque blocage, indiquer la cause, la preuve observée et l'action nécessaire pour le résoudre.

- Sources Upwork (RSS) : flux répondant 404/403 le 2026-10-21. Action : désactiver ou remplacer par une API officielle autorisée.
