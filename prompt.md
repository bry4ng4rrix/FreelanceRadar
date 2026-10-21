# MISSION : CONSTRUIRE FREELANCERADAR, UN AGRÉGATEUR INTELLIGENT DE MISSIONS FREELANCE

## 1. TON RÔLE

Tu es un ingénieur logiciel senior spécialisé en Python, FastAPI, architecture distribuée, PostgreSQL, scraping web, Playwright, automatisation n8n, sécurité applicative et intégration de LLM.

Tu dois développer une application complète, robuste, maintenable et déployable sur un VPS Ubuntu avec Docker Compose.

Le nom du projet est **FreelanceRadar**.

Tu travailles directement dans le workspace VS Code. Tu dois créer et modifier les fichiers réels, installer les dépendances nécessaires, lancer les tests et corriger les erreurs.

Ne te contente pas de proposer une architecture, de produire du pseudo-code ou de donner des exemples isolés. Implémente réellement les fonctionnalités demandées.

Ne réécris pas inutilement un fichier existant avant d'avoir examiné son contenu. Si un projet existe déjà, analyse son architecture et conserve les fonctionnalités utiles.

Si une information manque, prends une décision technique raisonnable, documente-la et continue. Pose une question uniquement lorsqu'une décision indispensable ne peut pas être prise sans risque.

---

## 2. OBJECTIF FONCTIONNEL

Créer une API qui collecte des annonces de missions freelance et des offres de développement publiées sur plusieurs plateformes.

L'application doit notamment rechercher des missions correspondant aux compétences suivantes :

- Python
- Django
- Django REST Framework
- FastAPI
- React
- Next.js
- TypeScript
- Flutter
- Dart
- PostgreSQL
- MySQL
- API REST
- Web scraping
- Playwright
- OCR
- Tesseract
- Traitement de documents
- Automatisation
- Intégration web
- Développement fullstack
- Applications mobiles

Les offres collectées doivent être normalisées, enregistrées dans PostgreSQL, dédupliquées, classées et affichées dans une API REST.

L'application doit ensuite pouvoir générer une proposition commerciale personnalisée à l'aide de Gemini ou d'Ollama.

Elle doit permettre :
1. De rechercher et consulter les offres.
2. De gérer les sites sources.
3. De gérer entièrement mon profil professionnel.
4. De gérer mon CV et mes compétences.
5. De générer des propositions personnalisées.
6. De préparer des candidatures.
7. D'envoyer les candidatures par SMTP lorsqu'un destinataire est connu.
8. D'utiliser les mécanismes de réponse autorisés des plateformes qui les proposent.
9. De suivre l'historique des candidatures.
10. D'automatiser les tâches récurrentes avec n8n et un worker asynchrone.

Ne prétends jamais que toutes les annonces d'un site sont récupérées si cela n'a pas été démontré par des tests.

---

## 3. STACK TECHNIQUE OBLIGATOIRE

Backend :
- Python 3.12
- FastAPI
- Pydantic v2
- SQLAlchemy 2
- PostgreSQL
- Alembic
- HTTPX
- BeautifulSoup4
- Playwright
- feedparser pour RSS
- pytest
- Ruff
- mypy lorsque raisonnable

Tâches asynchrones :
- Celery
- Redis
- Celery Beat pour la planification périodique

Automatisation :
- n8n auto-hébergé
- Workflows exportables en JSON
- Appels à l'API FastAPI par HTTP

Intelligence artificielle :
- Google Gemini via le SDK officiel actuel
- Ollama via son API HTTP
- Fournisseur configurable dans la base de données
- Modèle configurable
- Température et paramètres configurables
- Aucun fournisseur ne doit être obligatoire pour utiliser la collecte.

E-mails :
- SMTP configurable
- TLS
- Validation des destinataires
- Journalisation des erreurs
- Gestion des échecs et des tentatives contrôlées

Infrastructure :
- Docker
- Docker Compose
- PostgreSQL avec volume persistant
- Redis avec volume persistant
- API
- Worker Celery
- Celery Beat
- n8n avec volume persistant
- Healthchecks
- Redémarrage automatique des services

Documentation :
- README.md
- .env.example
- Documentation de l'API
- Guide d'installation Ubuntu
- Guide de sauvegarde et de restauration
- Guide d'importation des workflows n8n
- Documentation de chaque connecteur.

N'ajoute pas de frontend obligatoire dans la première version. L'API doit être exploitable depuis Swagger, n8n et un futur frontend React, Next.js ou Flutter.

---

## 4. ARCHITECTURE DU PROJET

Organise le code avec une architecture modulaire.

Structure cible :

freelanceradar/
├── app/
│   ├── main.py
│   ├── core/
│   │   ├── config.py
│   │   ├── security.py
│   │   ├── logging.py
│   │   └── exceptions.py
│   ├── db/
│   │   ├── base.py
│   │   ├── session.py
│   │   └── migrations/
│   ├── models/
│   │   ├── source.py
│   │   ├── offer.py
│   │   ├── profile.py
│   │   ├── application.py
│   │   ├── ai_settings.py
│   │   ├── scraping_run.py
│   │   └── audit_log.py
│   ├── schemas/
│   ├── api/
│   │   └── v1/
│   │       ├── sources.py
│   │       ├── offers.py
│   │       ├── scraping.py
│   │       ├── profile.py
│   │       ├── applications.py
│   │       ├── settings.py
│   │       ├── health.py
│   │       └── statistics.py
│   ├── services/
│   │   ├── source_service.py
│   │   ├── offer_service.py
│   │   ├── matching_service.py
│   │   ├── profile_service.py
│   │   ├── application_service.py
│   │   ├── email_service.py
│   │   └── audit_service.py
│   ├── collectors/
│   │   ├── base.py
│   │   ├── registry.py
│   │   ├── rss.py
│   │   ├── http_html.py
│   │   └── playwright.py
│   ├── ai/
│   │   ├── base.py
│   │   ├── registry.py
│   │   ├── gemini.py
│   │   ├── ollama.py
│   │   ├── prompts.py
│   │   └── schemas.py
│   ├── tasks/
│   │   ├── celery_app.py
│   │   ├── scraping_tasks.py
│   │   ├── application_tasks.py
│   │   └── maintenance_tasks.py
│   └── utils/
├── data/
│   └── sources.json
├── n8n/
│   ├── workflows/
│   └── README.md
├── tests/
│   ├── unit/
│   ├── integration/
│   └── fixtures/
├── scripts/
├── docker-compose.yml
├── Dockerfile
├── requirements.txt
├── pyproject.toml
├── alembic.ini
├── .env.example
├── .gitignore
└── README.md

Tu peux adapter cette structure si une meilleure architecture est justifiée, mais conserve la séparation entre API, accès aux données, connecteurs, IA, tâches et envoi des candidatures.

Évite les fichiers monolithiques et les dépendances circulaires.

---

## 5. SOURCES INITIALES À IMPORTER

Crée le fichier data/sources.json contenant les sources ci-dessous.

Toutes les sources doivent pouvoir être modifiées via l'API sans modifier le code.

Source 1 :
{
  "name": "Codeur.com - Projets Web, Mobile & OCR",
  "category": "Freelance Généraliste (Francophone)",
  "url": "https://www.codeur.com/projets",
  "target_type": "playwright",
  "frequency_minutes": 15,
  "is_active": true,
  "keywords": ["web", "mobile", "ocr", "python", "flutter", "react", "scraping", "automatisation"],
  "selectors": {
    "item": ".project-item",
    "title": ".project-title",
    "description": ".project-description",
    "link": "a.project-title"
  }
}

Source 2 :
{
  "name": "Upwork - RSS OCR & Python",
  "category": "Freelance International",
  "url": "https://www.upwork.com/ab/jobs/search/rss?q=ocr+python",
  "target_type": "rss",
  "frequency_minutes": 10,
  "is_active": true,
  "keywords": ["ocr", "tesseract", "document processing", "data extraction"],
  "selectors": {}
}

Source 3 :
{
  "name": "Upwork - RSS Flutter & Mobile",
  "category": "Freelance International",
  "url": "https://www.upwork.com/ab/jobs/search/rss?q=flutter+mobile",
  "target_type": "rss",
  "frequency_minutes": 10,
  "is_active": true,
  "keywords": ["flutter", "dart", "mobile app", "react native"],
  "selectors": {}
}

Source 4 :
{
  "name": "Free-Work - Missions IT & Tech",
  "category": "Job Board Spécialisé IT",
  "url": "https://www.free-work.com/fr/tech-it/jobs",
  "target_type": "playwright",
  "frequency_minutes": 30,
  "is_active": true,
  "keywords": ["ocr", "python", "fullstack", "fastapi", "react", "node"],
  "selectors": {
    "item": ".job-card",
    "title": ".job-title",
    "description": ".job-summary",
    "link": "a.job-link"
  }
}

Source 5 :
{
  "name": "Malt - Missions Développeur",
  "category": "Plateforme Freelance (Europe)",
  "url": "https://www.malt.fr/c/freelance/developpeur",
  "target_type": "playwright",
  "frequency_minutes": 60,
  "is_active": true,
  "keywords": ["web", "mobile", "python", "ocr", "api"],
  "selectors": {
    "item": ".freelance-card",
    "title": ".freelance-title",
    "description": ".freelance-description",
    "link": "a.freelance-link"
  }
}

Source 6 :
{
  "name": "Freelancer.com - Scraping & OCR Jobs",
  "category": "Freelance International",
  "url": "https://www.freelancer.com/jobs/python/1/",
  "target_type": "playwright",
  "frequency_minutes": 20,
  "is_active": true,
  "keywords": ["scraping", "ocr", "python", "automation", "data mining"],
  "selectors": {
    "item": ".JobSearchCard-item",
    "title": ".JobSearchCard-primary-heading-link",
    "description": ".JobSearchCard-primary-description",
    "link": ".JobSearchCard-primary-heading-link"
  }
}

Source 7 :
{
  "name": "Contra - Freelance 0% Commission",
  "category": "Plateforme Indépendante",
  "url": "https://contra.com/opportunity-feed",
  "target_type": "playwright",
  "frequency_minutes": 30,
  "is_active": true,
  "keywords": ["flutter", "mobile", "web development", "fullstack", "python"],
  "selectors": {
    "item": "[data-testid='opportunity-card']",
    "title": "[data-testid='opportunity-title']",
    "description": "[data-testid='opportunity-description']",
    "link": "a"
  }
}

Source 8 :
{
  "name": "goLance - Tech & Software Jobs",
  "category": "Freelance International (0% Fee)",
  "url": "https://golance.com/jobs?q=python",
  "target_type": "playwright",
  "frequency_minutes": 30,
  "is_active": true,
  "keywords": ["python", "web", "mobile", "api", "automation"],
  "selectors": {
    "item": ".job-item",
    "title": ".job-title",
    "description": ".job-description",
    "link": "a.job-title-link"
  }
}

Source 9 :
{
  "name": "We Work Remotely - Full Stack & Mobile (RSS)",
  "category": "Remote International",
  "url": "https://weworkremotely.com/categories/remote-full-stack-programming-jobs.rss",
  "target_type": "rss",
  "frequency_minutes": 30,
  "is_active": true,
  "keywords": ["fullstack", "mobile", "python", "react", "flutter"],
  "selectors": {}
}

Source 10 :
{
  "name": "Guru.com - Web & Software Jobs",
  "category": "Freelance International",
  "url": "https://www.guru.com/d/jobs/c/programming-development/",
  "target_type": "playwright",
  "frequency_minutes": 45,
  "is_active": true,
  "keywords": ["ocr", "python", "flutter", "web development"],
  "selectors": {
    "item": ".jobRecord",
    "title": ".jobRecord__title",
    "description": ".jobRecord__desc",
    "link": ".jobRecord__title a"
  }
}

Source 11 :
{
  "name": "Remotive - Software Development (RSS)",
  "category": "Remote Tech Jobs",
  "url": "https://remotive.com/remote-jobs/feed",
  "target_type": "rss",
  "frequency_minutes": 30,
  "is_active": true,
  "keywords": ["python", "flutter", "react", "fullstack", "ocr", "scraping"],
  "selectors": {}
}

Source 12 :
{
  "name": "DevJobScanner - Web Scraping Jobs",
  "category": "Spécialisé Scraping & Backend",
  "url": "https://www.devjobsscanner.com/web-scraping-jobs/",
  "target_type": "playwright",
  "frequency_minutes": 60,
  "is_active": true,
  "keywords": ["scraping", "python", "automation", "crawling"],
  "selectors": {
    "item": ".job-card",
    "title": ".job-card-title",
    "description": ".job-card-description",
    "link": "a"
  }
}

Source 13 :
{
  "name": "Asako.mg - Missions freelance",
  "category": "Plateforme freelance Madagascar",
  "url": "https://www.asako.mg/freelance",
  "target_type": "playwright",
  "frequency_minutes": 15,
  "is_active": true,
  "keywords": ["développement web", "python", "react", "next.js", "flutter", "mobile", "api", "digital"],
  "selectors": {}
}

Important :
- Les sélecteurs sont des valeurs initiales fournies par l'utilisateur et ne sont pas certifiés fonctionnels.
- Ne prétends pas que tous les sites sont accessibles ni que tous les flux fonctionnent.
- Implémente un test de connecteur permettant de vérifier une source.
- Ajoute un statut `unverified`, `working`, `partial`, `blocked` ou `error`.
- Une source sans sélecteurs doit utiliser une stratégie générique prudente, puis être signalée comme à configurer si aucun résultat pertinent n'est trouvé.
- Ne contourne jamais un CAPTCHA, une authentification obligatoire, un paywall ou une protection anti-bot.
- Préfère les API officielles, flux autorisés et mécanismes d'alerte proposés par les plateformes.

---

## 6. GESTION COMPLÈTE DES SOURCES

Créer un CRUD complet :

- Ajouter une source.
- Lire les sources.
- Modifier la configuration.
- Activer ou désactiver une source.
- Supprimer une source avec une stratégie de conservation de l'historique.
- Configurer la fréquence de collecte.
- Configurer les mots-clés.
- Configurer les sélecteurs CSS.
- Choisir RSS, HTTP/HTML, Playwright ou API officielle.
- Définir une limite de résultats par collecte.
- Définir les règles de pagination.
- Définir les délais d'attente et limites de requêtes.
- Tester une source sans envoyer de candidature.
- Consulter le dernier résultat et les erreurs.
- Déclencher une collecte manuelle.
- Afficher le nombre d'offres collectées.
- Afficher le nombre d'offres nouvelles.
- Afficher le taux d'échec.
- Permettre d'exporter et d'importer les configurations JSON.

Créer un registre de connecteurs extensible. Ajouter un nouveau site ne doit pas nécessiter de modifier le moteur central de collecte.

La fréquence doit être appliquée individuellement à chaque source. Éviter de relancer un site avant la fin de sa précédente collecte.

---

## 7. MODÈLE DE DONNÉES

Créer les modèles SQLAlchemy et les migrations Alembic nécessaires.

### SourceSite
- id
- name
- category
- base_url
- search_url
- connector_type
- frequency_minutes
- is_active
- keywords
- exclude_keywords
- selectors
- pagination_config
- status
- last_run_at
- last_success_at
- last_error
- auto_send_enabled
- application_method
- created_at
- updated_at

### Offer
- id
- source_site_id
- external_id
- canonical_url
- title
- description
- client_name
- client_location
- budget_min
- budget_max
- budget_currency
- budget_text
- employment_type
- project_type
- required_skills
- keywords_found
- match_score
- published_at
- discovered_at
- last_seen_at
- status
- raw_data
- content_hash

### Profile
- id
- full_name
- professional_title
- summary
- primary_email
- secondary_emails
- phone
- location
- portfolio_url
- github_url
- linkedin_url
- preferred_languages
- availability
- default_rate
- currency
- created_at
- updated_at

### Skill
- id
- profile_id
- name
- category
- proficiency_level
- years_experience
- aliases

### Experience
- id
- profile_id
- company
- title
- description
- start_date
- end_date
- technologies

### ProfileDocument
- id
- profile_id
- filename
- storage_path
- document_type
- content_type
- extracted_text
- uploaded_at

### AISettings
- id
- provider
- model
- temperature
- max_output_tokens
- language
- tone
- prompt_template
- min_match_score

### Application
- id
- offer_id
- channel
- recipient
- subject
- message
- status
- approval_required
- approved_at
- sent_at
- external_reference
- error
- created_at
- updated_at

### ScrapingRun
- id
- source_site_id
- task_id
- status
- started_at
- completed_at
- items_seen
- items_inserted
- items_updated
- error_message
- execution_metadata

### AuditLog
- id
- event_type
- entity_type
- entity_id
- details
- created_at

Ajouter les clés étrangères, les index et les contraintes d'unicité nécessaires.

Les migrations Alembic sont obligatoires. Ne te contente pas d'utiliser `Base.metadata.create_all()` en production.

---

## 8. MOTEUR DE COLLECTE

Implémenter un moteur de collecte extensible.

### RSS
- Lire les flux avec feedparser.
- Gérer les flux malformés.
- Respecter les timeouts HTTP.
- Suivre les redirections raisonnables.
- Utiliser les dates de publication lorsqu'elles existent.
- Conserver le lien original.
- Nettoyer le HTML des descriptions.
- Gérer les erreurs par source.

### HTTP et HTML
- Utiliser HTTPX.
- Respecter les limites de requêtes.
- Ajouter un User-Agent identifiable avec une adresse de contact configurable.
- Parser les pages avec BeautifulSoup.
- Éviter les téléchargements inutiles.
- Respecter les conditions d'utilisation des sites.

### Playwright
- Lancer Chromium en mode headless.
- Réutiliser les navigateurs dans les limites raisonnables.
- Fermer correctement pages et navigateurs.
- Configurer les timeouts.
- Extraire les cartes à partir des sélecteurs configurés.
- Normaliser les URL relatives.
- Gérer les pages sans résultats.
- Enregistrer les erreurs et captures de diagnostic lorsque cela est autorisé.
- Ne pas tenter de contourner les mécanismes anti-bot.

### Pagination
- Configurer la pagination par source.
- Limiter le nombre de pages par collecte.
- Empêcher les boucles infinies.
- Conserver le dernier point de collecte lorsque cela est possible.
- Pouvoir reprendre une collecte interrompue.

### Qualité des données
- Nettoyer les espaces.
- Normaliser les dates en UTC.
- Extraire le budget lorsque le format est compréhensible.
- Ne jamais inventer un budget ou un client.
- Conserver les champs bruts utiles pour le diagnostic.

Chaque connecteur doit avoir des tests unitaires basés sur des fixtures locales. Les tests ordinaires ne doivent pas dépendre de la disponibilité des vrais sites.

---

## 9. DÉDUPLICATION ET CORRESPONDANCE

Ne crée pas deux offres identiques lors de deux collectes successives.

Implémente plusieurs niveaux :
1. Identifiant externe stable lorsqu'il existe.
2. URL canonique normalisée.
3. Empreinte du contenu.
4. Détection prudente des annonces similaires entre plusieurs sources.

Créer des index uniques adaptés et gérer les conflits de concurrence dans PostgreSQL.

Ne supprime pas une annonce simplement parce qu'elle n'apparaît plus dans une collecte. Marque-la éventuellement comme inactive après une politique documentée.

Le score de correspondance doit prendre en compte :
- Les compétences requises.
- Les synonymes et variantes linguistiques.
- Les technologies.
- La description.
- Le type de mission.
- Le budget lorsqu'il est renseigné.
- Les préférences du profil.
- Les exclusions explicites.

Le score doit être explicable : conserver les mots-clés trouvés et les raisons du score.

Commencer avec une méthode déterministe testable. Le LLM peut enrichir la classification, mais ne doit pas être nécessaire pour chaque annonce.

Prévoir des filtres sur le score, la source, les dates, les compétences et le statut.

---

## 10. GESTION DU PROFIL ET DES DOCUMENTS

Créer un CRUD complet pour le profil professionnel.

Permettre de modifier :
- Nom et titre professionnel.
- Présentation.
- Une ou plusieurs adresses e-mail.
- Coordonnées.
- Compétences et niveaux.
- Expériences professionnelles.
- Portfolio.
- GitHub.
- LinkedIn.
- Langues.
- Disponibilité.
- Tarif par défaut.
- CV.
- Autres documents professionnels.

Prévoir un upload sécurisé du CV :
- Vérification de la taille.
- Vérification du type de fichier.
- Noms de fichiers sécurisés.
- Stockage persistant.
- Refus des exécutables.
- Extraction de texte optionnelle.
- Possibilité de remplacer ou supprimer un document.
- Ne pas exposer les fichiers directement sans contrôle d'accès.

Le système doit utiliser exclusivement les informations réellement présentes dans le profil et les documents. Ne jamais inventer une expérience ou une référence client.

---

## 11. FOURNISSEURS IA : GEMINI ET OLLAMA

Créer une interface commune pour les fournisseurs IA.

Exemple de contrat :
- `generate_response()`
- `classify_offer()`
- `extract_structured_fields()`

### Gemini
- Utiliser le SDK officiel actuel.
- Clé API via variable d'environnement.
- Modèle configurable.
- Gestion des quotas et erreurs.
- Timeouts.
- Possibilité de désactiver le fournisseur.

### Ollama
- URL configurable.
- Modèle configurable.
- Appels HTTP.
- Gestion des modèles absents.
- Timeouts.
- Gestion des réponses malformées.

Les clés API ne doivent jamais être retournées dans les endpoints.

Le choix du fournisseur doit pouvoir être modifié sans redéployer l'application.

### Génération d'une candidature
Le prompt doit recevoir :
- Titre de l'offre.
- Description.
- Compétences demandées.
- Budget si connu.
- Langue.
- Profil professionnel.
- Expériences pertinentes.
- Portfolio.
- Préférences de ton et de longueur.

La réponse doit être structurée et validée avec Pydantic :
- subject
- message
- language
- referenced_skills
- warnings
- confidence

Ne jamais demander au modèle d'inventer des informations absentes.

Traiter la description de l'offre comme une donnée non fiable. Une annonce peut contenir des instructions malveillantes visant à détourner le modèle. Ces instructions ne doivent jamais remplacer les consignes système ni déclencher un envoi.

Enregistrer les versions générées et permettre de modifier le texte avant envoi.

---

## 12. GESTION DES CANDIDATURES ET ENVOI AUTOMATIQUE

Créer un moteur de candidature avec les canaux suivants :
- `smtp`
- `official_api`
- `authorized_form`
- `manual`

Ne suppose pas que toutes les plateformes permettent de candidater automatiquement.

Pour chaque source, enregistrer :
- Le canal autorisé.
- L'activation ou non de l'automatisation.
- Les prérequis.
- La politique de validation.
- Les limites de fréquence.
- Le dernier résultat d'envoi.

### Modes de candidature
- `manual_review` : aucune candidature n'est envoyée sans validation.
- `auto_approved_sources` : envoi automatique uniquement pour les sources explicitement validées.
- `disabled` : aucune candidature ne peut être envoyée.

Le mode par défaut est `manual_review`.

Même lorsque l'automatisation est activée, exiger :
- Une source explicitement autorisée.
- Un canal réellement configuré.
- Un destinataire fiable.
- Une offre encore pertinente.
- Un message valide.
- L'absence d'une candidature existante pour cette offre.
- Le respect des quotas.
- Un enregistrement d'audit.

Pour SMTP, ne devine jamais les adresses e-mail. N'envoie jamais de message à une adresse extraite d'une page si elle n'est pas clairement identifiée comme destinataire de candidature.

Pour les plateformes sans API ou canal autorisé, fournir un lien vers l'offre et un message prêt à copier, sans simuler une candidature envoyée.

Ne contourne pas les CAPTCHA, les connexions obligatoires, les protections anti-bot ou les limitations des plateformes.

Créer une clé d'idempotence pour empêcher les doubles envois. Utiliser une transaction et une stratégie de réservation de candidature avant l'envoi afin de limiter les courses concurrentes.

Enregistrer les erreurs SMTP et permettre une nouvelle tentative contrôlée, sans renvoyer automatiquement une candidature dont le résultat est incertain.

---

## 13. N8N

Créer des workflows n8n exportables en JSON.

### Workflow A : collecte périodique
- Schedule Trigger toutes les cinq minutes.
- Appel de FastAPI pour rechercher les sources dues.
- Création des tâches de collecte.
- Journalisation du résultat.
- Gestion des erreurs.

### Workflow B : notification de nouvelle offre
- Déclenchement à la détection d'une nouvelle offre pertinente.
- Filtrage selon le score.
- Notification par e-mail ou Telegram si configuré.
- Inclusion du titre, du lien, du score et de la source.

### Workflow C : génération de candidature
- Webhook protégé.
- Réception de l'identifiant de l'offre.
- Appel de FastAPI.
- Choix du fournisseur IA.
- Retour du brouillon.

### Workflow D : suivi des erreurs
- Détection d'échecs de collecte.
- Notification des sources en panne.
- Prévention des alertes répétitives.
- Journalisation de l'erreur.

### Workflow E : candidature approuvée
- Récupération des candidatures éligibles.
- Vérification des autorisations côté FastAPI.
- Envoi par le canal autorisé.
- Enregistrement du résultat.

Les contrôles de sécurité doivent être réalisés dans FastAPI. Ne considère jamais qu'un appel venant de n8n est automatiquement autorisé.

Les workflows doivent être importables et documentés. Utilise les nodes disponibles dans la version de n8n ciblée.

Configurer l'accès n8n avec authentification et un chiffrement persistant des credentials.

---

## 14. API REST

Préfixe général : `/api/v1`.

Créer au minimum les endpoints suivants.

### Santé
- `GET /health`
- `GET /ready`

### Sources
- `GET /sources`
- `POST /sources`
- `GET /sources/{id}`
- `PATCH /sources/{id}`
- `DELETE /sources/{id}`
- `POST /sources/{id}/test`
- `POST /sources/{id}/run`
- `GET /sources/{id}/runs`
- `POST /sources/import`
- `GET /sources/export`

### Collecte
- `POST /scraping/run`
- `GET /scraping/runs`
- `GET /scraping/runs/{id}`

### Offres
- `GET /offers`
- `GET /offers/{id}`
- `PATCH /offers/{id}`
- `POST /offers/{id}/classify`
- `POST /offers/{id}/generate-response`
- `POST /offers/{id}/archive`

### Profil
- `GET /profile`
- `PATCH /profile`
- `POST /profile/documents`
- `GET /profile/documents`
- `DELETE /profile/documents/{id}`
- CRUD des compétences.
- CRUD des expériences.
- CRUD des e-mails.

### IA
- `GET /settings/ai`
- `PATCH /settings/ai`
- `POST /settings/ai/test`

### Candidatures
- `GET /applications`
- `GET /applications/{id}`
- `POST /applications/prepare`
- `PATCH /applications/{id}`
- `POST /applications/{id}/approve`
- `POST /applications/{id}/send`
- `POST /applications/{id}/cancel`

### Statistiques
- `GET /statistics/overview`
- `GET /statistics/sources`
- `GET /statistics/applications`

Implémenter :
- Pagination.
- Validation des paramètres.
- Codes HTTP cohérents.
- Réponses d'erreur standardisées.
- Filtres et tris.
- Documentation OpenAPI.
- Authentification sur les endpoints privés.
- Limitation de débit sur les endpoints sensibles.
- Journalisation sans secrets.

Ne crée pas d'endpoints qui annoncent une fonctionnalité si celle-ci n'est pas réellement implémentée.

---

## 15. SÉCURITÉ

Le projet sera déployé sur un VPS accessible par Internet.

Implémente :
- Configuration par variables d'environnement.
- Aucun secret dans Git.
- Validation des entrées.
- Protection contre les injections SQL via SQLAlchemy.
- Contrôle d'accès.
- Authentification pour les endpoints privés.
- Protection des uploads.
- Limitation des requêtes.
- Timeouts réseau.
- Logs sans mots de passe ni clés.
- Sauvegarde PostgreSQL.
- Healthchecks.
- Isolation des services Docker.
- Restriction des ports.
- Gestion sûre des erreurs.

Ne publie pas directement PostgreSQL et Redis sur Internet.

L'API et n8n doivent être exposés derrière un reverse proxy HTTPS en production.

Si une authentification par clé API est utilisée pour la première version, documente clairement ses limites. Prévois une architecture permettant de passer à une authentification utilisateur avec rôles.

### Protection SSRF du scraper
Les URL sources sont configurables par l'administrateur, mais elles restent des entrées à contrôler.

Refuser par défaut :
- localhost ;
- les IP privées et link-local ;
- les adresses de métadonnées cloud ;
- les protocoles autres que HTTP et HTTPS ;
- les redirections vers des destinations interdites.

Valider à nouveau les redirections et les adresses résolues. Ne pas laisser une URL configurée permettre d'accéder aux services internes du réseau Docker ou à l'interface d'administration.

---

## 16. DOCKER COMPOSE

Créer un Dockerfile propre et un docker-compose.yml comprenant :
- api
- postgres
- redis
- worker
- beat
- n8n

Le conteneur Playwright doit disposer des bibliothèques nécessaires à Chromium.

Prévoir :
- volumes persistants ;
- healthchecks ;
- redémarrage automatique ;
- réseau interne ;
- variables d'environnement ;
- migrations au démarrage selon une stratégie fiable ;
- commandes de maintenance ;
- commandes de logs ;
- sauvegarde et restauration.

Ne pas publier PostgreSQL ou Redis sur une interface publique.

Ne pas lancer automatiquement plusieurs instances de Celery Beat.

Ne pas utiliser `latest` pour toutes les images en production : fixer des versions compatibles et documenter la procédure de mise à jour.

Ne pas supposer qu'Ollama est installé sur le VPS. Il doit être optionnel. La collecte et l'API doivent rester opérationnelles si aucun fournisseur IA n'est disponible.

Prévoir une configuration pour Ollama sur l'hôte ou sur un autre serveur. Ne pas télécharger automatiquement un gros modèle sans demande explicite.

---

## 17. TESTS OBLIGATOIRES

Créer des tests unitaires et d'intégration.

Tester au minimum :
- Validation des sources.
- Import du JSON.
- Parsing RSS à partir de fixtures.
- Parsing HTML à partir de fixtures.
- Normalisation des URL.
- Déduplication.
- Score de correspondance.
- Pagination.
- Gestion des erreurs de collecte.
- Génération IA avec fournisseurs simulés.
- Validation des réponses structurées.
- CRUD du profil.
- Upload sécurisé.
- CRUD des sources.
- Authentification.
- Prévention des candidatures en double.
- Envoi SMTP simulé.
- Blocage de l'envoi si la source n'est pas autorisée.
- Blocage de l'envoi sans destinataire fiable.
- Respect du mode manuel.
- Sécurité SSRF.
- Idempotence des tâches.
- Importation des workflows n8n.

Les tests unitaires ne doivent pas contacter les vrais sites, envoyer de vrais e-mails ou consommer des crédits Gemini.

Ajouter des fixtures représentatives et des tests pour les erreurs de réseau.

Avant de terminer :
1. Installer les dépendances.
2. Exécuter Ruff.
3. Exécuter les tests.
4. Vérifier les migrations.
5. Vérifier le démarrage Docker si l'environnement le permet.
6. Corriger les erreurs rencontrées.
7. Documenter précisément les tests qui n'ont pas pu être exécutés.

---

## 18. OBSERVABILITÉ

Chaque collecte doit avoir :
- Un identifiant d'exécution.
- Une date de début et de fin.
- Le nombre d'éléments examinés.
- Le nombre d'offres nouvelles.
- Le nombre de doublons.
- Le statut.
- Les erreurs éventuelles.

Prévoir :
- Logs structurés.
- Identifiants de tâches.
- Statistiques par source.
- Historique des candidatures.
- Journal d'audit.
- Endpoint de readiness.
- Alertes en cas de panne répétée.

Ne stocke pas de contenu sensible inutilement.

---

## 19. ORDRE D'EXÉCUTION DU PROJET

Travaille par phases.

### Phase 1 — Analyse et fondations
- Examiner le workspace.
- Créer le plan de développement.
- Définir l'architecture.
- Créer la configuration.
- Créer les modèles.
- Créer les migrations.
- Créer Docker Compose.
- Vérifier le démarrage de PostgreSQL et Redis.

### Phase 2 — Sources et collecte
- Importer les 13 sources.
- Créer le registre de connecteurs.
- Implémenter RSS, HTTP/HTML et Playwright.
- Implémenter les tâches Celery.
- Tester les connecteurs sur des fixtures.
- Créer les endpoints de sources et d'historique.
- Tester une collecte réelle par source lorsque cela est autorisé.

### Phase 3 — Offres et profil
- CRUD complet du profil.
- Gestion des documents.
- Normalisation.
- Déduplication.
- Scoring.
- Recherche, filtres et pagination.

### Phase 4 — IA
- Interface commune.
- Gemini.
- Ollama.
- Configuration dynamique.
- Prompts.
- Validation des sorties.
- Tests avec fournisseurs simulés.

### Phase 5 — Candidatures
- Préparation.
- Approbation.
- SMTP.
- Canaux autorisés.
- Idempotence.
- Suivi.
- Protection contre les doubles envois.

### Phase 6 — n8n
- Créer les workflows JSON.
- Tester leurs appels API.
- Documenter l'importation.
- Documenter les credentials.
- Vérifier les erreurs et notifications.

### Phase 7 — Finalisation
- Lancer tous les tests.
- Corriger les problèmes.
- Vérifier Docker Compose.
- Finaliser README.
- Créer le guide VPS.
- Fournir un récapitulatif des fonctionnalités réellement terminées.

Ne passe pas silencieusement à une autre phase si les fondations sont cassées. Corrige les problèmes avant de continuer.

---

## 20. DÉPLOIEMENT SUR VPS UBUNTU

Créer un guide précis comprenant :
- Installation de Docker Engine et Docker Compose.
- Clonage du projet.
- Création du fichier `.env`.
- Génération de secrets forts.
- Configuration Gemini.
- Configuration SMTP.
- Configuration d'Ollama si nécessaire.
- Build et démarrage.
- Migrations.
- Import des sources.
- Création ou mise à jour du profil.
- Import des workflows n8n.
- Configuration HTTPS.
- Sauvegarde et restauration PostgreSQL.
- Mise à jour de l'application.
- Consultation des logs.
- Dépannage des connecteurs Playwright.

Ne demande jamais de communiquer un mot de passe SMTP ou une clé Gemini dans la conversation. Les secrets doivent être configurés localement.

Ne lance aucune commande destructive sur un VPS existant sans inspection préalable et confirmation explicite.

---

## 21. CRITÈRES D'ACCEPTATION

Le projet sera considéré comme prêt pour une première mise en production lorsque :

1. L'API démarre correctement.
2. Les migrations fonctionnent.
3. PostgreSQL conserve les données après redémarrage.
4. Les 13 sources sont importables.
5. Une source peut être ajoutée sans modifier le code.
6. Une collecte RSS fonctionne sur une fixture.
7. Une collecte Playwright fonctionne sur une fixture HTML.
8. Les doublons sont contrôlés par PostgreSQL.
9. Les offres sont consultables avec filtres.
10. Le profil est modifiable.
11. Gemini et Ollama sont sélectionnables.
12. Les propositions générées sont enregistrées.
13. Les candidatures manuelles sont préparables.
14. Les candidatures automatiques sont refusées par défaut.
15. L'activation automatique est contrôlée par source.
16. Un destinataire inconnu n'est jamais deviné.
17. Une candidature déjà envoyée ne peut pas être envoyée une seconde fois par accident.
18. Les workflows n8n sont importables.
19. Les erreurs sont visibles.
20. La documentation permet à un développeur de déployer le projet sur Ubuntu.

La réussite d'un test local ne signifie pas que tous les sites externes fonctionnent. Affiche explicitement les sources testées, celles à vérifier et celles bloquées.

---

## 22. CONSIGNES DE TRAVAIL DANS CLAUDE CODE

Commence par examiner le workspace et produire `ROADMAP.md` et `PLANNING.md`.

Ensuite, commence immédiatement la Phase 1.

Ne te contente pas de m'expliquer ce que tu ferais.

Crée les fichiers réels, vérifie leur cohérence, exécute les commandes disponibles et corrige les erreurs.

Travaille par lots logiques pour conserver un contexte maîtrisé. Évite de relire inutilement l'intégralité du dépôt à chaque étape.

Avant chaque modification importante :
- inspecte les fichiers concernés ;
- vérifie les dépendances ;
- applique les changements minimaux nécessaires ;
- exécute les tests pertinents.

À la fin de chaque phase, fournis :
- les fichiers créés ou modifiés ;
- les fonctionnalités terminées ;
- les tests exécutés ;
- les résultats ;
- les problèmes restants ;
- la prochaine étape.

Ne prétends jamais qu'un fichier, un test, un déploiement ou une intégration a été réalisé si ce n'est pas réellement le cas.

Commence maintenant par l'inspection du workspace, puis construis FreelanceRadar progressivement jusqu'à obtenir une application fonctionnelle.
