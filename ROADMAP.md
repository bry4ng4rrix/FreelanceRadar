# ROADMAP — FreelanceRadar

Étapes du projet (alignées sur le « prompt maître » du 2026-10-21). Détail des tâches : `TASKS.md`. Décisions : `PLANNING.md`.
Spécifications de référence : prompt maître (prioritaire), `prompt.md` (cœur) et `notifications.md` (e-mail, IMAP, FCM, Flutter).

Une étape ne commence que lorsque les critères de la précédente sont vérifiés. **Focus actuel : backend FastAPI uniquement.**

| Étape | Objectif | Dépend de | Critères de sortie vérifiables | État |
|---|---|---|---|---|
| 1 — Audit | État du dépôt, documents de pilotage | — | Documents à jour, risques identifiés | ✅ |
| 2 — Fondation backend | FastAPI, PostgreSQL, SQLAlchemy/Alembic, auth JWT, santé, OpenAPI | 1 | Migrations aller-retour OK ; `/health` et `/ready` ; routes privées → 401 ; ruff/mypy/pytest verts | ✅ (sauf conteneur API, FR-007) |
| 3 — Premier parcours | RSS réel → normalisation → PostgreSQL → déduplication → API → tâche planifiée | 2 | Collecte réelle d'une source autorisée ; doublons rejetés par PostgreSQL ; offres lisibles via l'API ; Beat déclenche les collectes | ✅ |
| 4 — Métier | Profil, préférences, filtres, score explicable, favoris, candidatures | 3 | CRUD profil testé ; score avec raisons +/− ; brouillons soumis à approbation | 🟡 profil + compétences livrés (FR-020a) |
| 5 — IA | Gemini + Ollama derrière une interface commune | 4 | Fournisseurs simulés en test ; sorties validées ; aucune invention de compétence | ⏳ |
| 6 — E-mails | SMTP, IMAP, conversations, idempotence | 4 | Tests sans envoi réel ; statuts distincts (accepté SMTP ≠ livré) | ⏳ |
| 7 — Notifications | Centre persistant + FCM | 6 | Notification créée même si FCM indisponible | 🟡 centre persistant livré (FR-051a), FCM à faire |
| 8 — Flutter | Application Android reliée à l'API | 2–7 | Tests widgets/navigation ; états chargement/erreur/vide | 🟡 offres + sources livrées (FR-070a), reste à suivre le backend |
| 9 — n8n et sources | Workflows, connecteurs supplémentaires (HTML, Playwright) | 3 | Workflows importables ; chaque source testée, documentée et classée | ⏳ |
| 10 — Livraison | Docker complet, guides, bilan | tout | Compose démarre l'ensemble ; README et guide VPS rejoués | ⏳ |

Un test sur fixture ne prouve pas qu'un site fonctionne : l'état réel de chaque source est tenu dans `PLANNING.md` §5.
