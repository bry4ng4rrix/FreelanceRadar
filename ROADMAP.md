# ROADMAP — FreelanceRadar

Phases du projet. Le détail des tâches est dans `TASKS.md`, les décisions dans `PLANNING.md`.
Spécifications de référence : `prompt.md` (cœur) et `notifications.md` (e-mail, IMAP, FCM, Flutter).

Une phase ne commence que lorsque les critères de la précédente sont vérifiés.

| Phase | Objectif | Dépend de | Critères de sortie vérifiables |
|---|---|---|---|
| 0 — Cadrage | Audit, documents de pilotage | — | ROADMAP/PLANNING/TASKS/CHANGELOG validés ; premier commit |
| 1 — Fondations | Squelette FastAPI, config, Docker Compose (Postgres, Redis), Alembic, outillage qualité | 0 | `docker compose up` : postgres et redis `healthy` ; `GET /health` = 200 ; `alembic upgrade head` OK sur base de dev ; `ruff`, `mypy`, `pytest` passent ; auth par clé API sur endpoints privés |
| 2 — Sources et collecte | Modèles Source/Offer/ScrapingRun, import des 13 sources, connecteurs RSS → HTTP/HTML → Playwright, Celery + Beat, protection SSRF | 1 | Import idempotent de `data/sources.json` ; collecte RSS et Playwright sur fixtures locales ; doublons rejetés par contrainte PostgreSQL ; tests SSRF (localhost, IP privées, redirections) ; historique des exécutions consultable |
| 3 — Offres et profil | Normalisation, scoring, filtres/pagination, CRUD profil, compétences, CV | 2 | Recherche filtrée paginée testée ; profil modifiable ; upload CV validé (type, taille) et jamais journalisé |
| 4 — IA | Interface commune, Gemini, Ollama, prompts, validation des sorties | 3 | Fournisseur sélectionnable en base ; tests avec fournisseurs simulés ; la collecte fonctionne sans IA configurée |
| 5 — Candidatures et SMTP | Brouillons, approbation, envoi SMTP idempotent | 4 | Mode automatique refusé par défaut ; destinataire inconnu jamais deviné ; double envoi impossible (test) ; tests SMTP sur serveur factice uniquement |
| 6 — IMAP et notifications | Synchronisation IMAP, association des réponses, centre de notifications, FCM | 5 | Association par `Message-ID`/`In-Reply-To`/`References` testée, cas ambigus inclus ; FCM simulé ; un échec FCM n'altère pas le statut d'envoi |
| 7 — n8n | Workflows JSON appelant l'API | 2 (A, D), 4–5 (B, C, E) | Workflows importables dans le n8n local ; aucune logique métier dupliquée |
| 8 — Flutter | App Android : offres, candidatures, boîte de réception, notifications | 6 | Tests widgets/navigation ; états chargement/erreur/vide ; liens profonds depuis une notification |
| 9 — Production | Reverse proxy HTTPS, sauvegardes, guide VPS | 1–8 | Guide Ubuntu rejoué sur une VM de test ; restauration PostgreSQL vérifiée |

Les sources externes réelles sont classées séparément : testées, à vérifier, bloquées. Un test sur fixture ne prouve pas qu'un site fonctionne.
