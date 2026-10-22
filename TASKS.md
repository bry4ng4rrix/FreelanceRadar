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

- [x] FR-030a — IA Gemini (SDK officiel `google-genai` 2.32) : rédaction structurée et validée (objet, message, langue, compétences citées, avertissements, confiance) ; modèles gratuits en cascade (`gemini-3.8-flash` → `gemini-3.5-flash-lite` → `gemini-3.1-flash-lite`) ; reprises Celery sur erreur temporaire.
- [x] FR-040a / FR-041b — Candidatures : préparation par l'IA à partir du profil et des compétences, notification « prête à valider », relecture et modification, envoi SMTP après confirmation explicite (réservation anti-double envoi, limite quotidienne), notification « Candidature envoyée → destinataire » ; migration `2497f2b33a23`.
- [x] FR-070c — Mobile : onglet Rapport (envoyées, à valider, échecs), écran de candidature avec validation de l'envoi, Sources déplacées dans les Réglages.
  - Vérification : backend 132 tests (Gemini et SMTP simulés, aucun envoi), ruff, mypy strict ; mobile 52 tests, analyse sans remarque ; contrat Dart = OpenAPI. Appel Gemini réel : modèle gratuit OK et injection de l'annonce ignorée, mais réponse « ... » observée une fois (validation durcie depuis) puis 503 « forte demande » : génération réelle complète **non revérifiée**. Aucun e-mail réel envoyé.

- [x] FR-050a — Réponses des clients (IMAP, lecture seule EXAMINE/BODY.PEEK) : association par en-têtes puis expéditeur + objet, ambiguïtés ignorées, seules les réponses associées conservées, statut « Réponse reçue », notification ; synchronisation Celery (5 min) ; Rapport mobile ; migration `d641e0c2acf4`.
- [x] FR-061 — n8n 2.45.1 : workflow « collecte quotidienne » (07:00, Indian/Antananarivo) importé et activé automatiquement, jeton de service ; `COLLECTION_SCHEDULER=n8n` désactive la planification Beat.
- [x] FR-080a — Production sur le VPS (`~/freelanceradar`, `docker-compose.prod.yml`) + GitHub Actions (tests → GHCR → déploiement SSH par clé dédiée).
  - Vérification : backend 144 tests, mobile 53 tests ; actionlint sans erreur ; sur le VPS : `/ready` = 200, n8n actif, SMTP/IMAP OK (aucun envoi), workflow exécuté (collecte réelle), aucun secret dans les logs, autres applications non modifiées.

## À faire — backend (ordre recommandé)

- [ ] FR-013 — Ajuster la configuration des sources selon `PLANNING.md` §5 (Remotive ≥ 360 min, Upwork désactivées) — **décision utilisateur requise**.
- [ ] FR-014 — Alerte de panne répétée : source passée en `error` après N échecs consécutifs visible dans l'API (base des notifications futures).
- [ ] FR-020b — Profil : expériences, diplômes et certifications.
- [ ] FR-021 — Upload privé du CV (PDF/DOCX, taille et type contrôlés, jamais journalisé).
- [ ] FR-022 — Score de pertinence explicable (raisons +/−, seuil configurable) et détection des compétences.
- [ ] FR-023 — Tableau de bord / statistiques.
- [ ] FR-030b — Ollama en alternative (`gemma3:4b` disponible en local) et choix du fournisseur sans redéploiement.
- [ ] FR-031 — Push FCM pour « candidature prête à valider » (projet Firebase de l'utilisateur requis).
- [ ] FR-041c — Pièces jointes (CV) et premier envoi réel autorisé par l'utilisateur.
- [ ] FR-051b — Notifications push FCM (projet Firebase requis) et préférences par type.
- [ ] FR-013b — Connecteurs HTML/Playwright, source par source, après vérification des CGU.

## Hors focus actuel

- [ ] FR-060 — Workflows n8n.
- [ ] FR-070b — Flutter : écrans candidatures et messagerie (au fil des modules backend FR-040 à FR-050).
- [ ] FR-080b — HTTPS public (nom de domaine + nginx + certbot, `sudo` requis) et sauvegarde planifiée de PostgreSQL.

## Bloqué

Pour chaque blocage, indiquer la cause, la preuve observée et l'action nécessaire pour le résoudre.

- Sources Upwork (RSS) : flux répondant 404/403 le 2026-10-21. Action : désactiver ou remplacer par une API officielle autorisée.
