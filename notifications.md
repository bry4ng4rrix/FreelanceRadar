# MODULE COMPLÉMENTAIRE — EMAIL, BOÎTE DE RÉCEPTION ET NOTIFICATIONS PUSH FLUTTER

Tu dois intégrer ce module au projet existant **FreelanceRadar**. Commence par inspecter le dépôt, son architecture et les fonctionnalités déjà développées. Réutilise les modèles, services, conventions, migrations et composants existants. Ne crée pas un second backend ni une architecture parallèle.

## 1. Objectifs fonctionnels

L'application doit permettre de :

1. Configurer une ou plusieurs adresses e-mail pour envoyer des candidatures.
2. Envoyer des candidatures par SMTP lorsque le mode est autorisé.
3. Enregistrer chaque e-mail envoyé et son statut réel.
4. Récupérer les réponses des clients via IMAP.
5. Afficher les messages envoyés et reçus dans une boîte de réception unifiée.
6. Associer autant que possible les réponses à la bonne offre et à la bonne candidature.
7. Envoyer des notifications push sur l'application Flutter.
8. Notifier l'utilisateur lorsqu'une nouvelle offre correspond à son profil, lorsqu'une candidature est envoyée avec succès et lorsqu'un client répond.
9. Ouvrir directement la bonne offre, la candidature, la conversation ou la réponse lorsqu'une notification est touchée.
10. Consulter les notifications et les messages même après une déconnexion temporaire ou une perte de réseau.

## 2. Architecture à respecter

- Backend : FastAPI, Python 3.12, Pydantic v2, SQLAlchemy 2 et Alembic.
- Base de données : PostgreSQL.
- Tâches asynchrones : Celery et Redis, en réutilisant les services existants.
- Automatisation : n8n pour les workflows pertinents, sans dupliquer la logique métier du backend.
- Envoi d'e-mails : SMTP avec TLS/STARTTLS selon le fournisseur.
- Lecture des e-mails : IMAP sécurisé, avec synchronisation périodique en arrière-plan.
- Notifications mobiles : Firebase Cloud Messaging (FCM).
- Application mobile : Flutter pour Android en priorité, avec une architecture compatible iOS si nécessaire.
- Déploiement : Docker Compose sur VPS Ubuntu.

Ne fais pas dépendre le fonctionnement de la boîte de réception de l'ouverture de l'application Flutter.

## 3. Paramétrage SMTP et IMAP

Créer une page de configuration e-mail dans l'interface d'administration.

Champs configurables :

- Nom du compte.
- Adresse e-mail d'expédition.
- Nom affiché comme expéditeur.
- Serveur SMTP.
- Port SMTP.
- Mode TLS/STARTTLS.
- Nom d'utilisateur SMTP.
- Mot de passe ou secret SMTP.
- Serveur IMAP.
- Port IMAP.
- Mode TLS.
- Nom d'utilisateur IMAP.
- Mot de passe ou secret IMAP.
- Adresse de réponse (`Reply-To`) facultative.
- Activation ou désactivation de la synchronisation IMAP.
- Fréquence de synchronisation.
- Dossier IMAP à surveiller.
- Statut de connexion et dernière synchronisation réussie.

Exigences de sécurité :

- Stocker les secrets chiffrés au repos lorsque leur stockage est nécessaire.
- Ne jamais retourner de mot de passe ou de secret dans les réponses API.
- Ne jamais écrire de secrets dans les logs, le frontend, Git ou les notifications.
- Utiliser des variables d'environnement pour les secrets d'infrastructure.
- Prévoir un bouton « Tester la connexion SMTP » et un bouton « Tester la connexion IMAP ».
- Afficher des erreurs compréhensibles sans exposer les identifiants ni les détails sensibles.
- Prévoir une procédure de rotation des identifiants.
- Ne pas supposer qu'un mot de passe de compte classique fonctionne : certains fournisseurs exigent un mot de passe d'application ou OAuth2.

Le backend doit utiliser une interface de service e-mail permettant de changer de fournisseur sans réécrire le système.

## 4. Envoi des candidatures

Créer un service `EmailSendingService`.

Fonctionnalités :

- Composer un objet et un corps de message.
- Générer un brouillon à l'aide du fournisseur IA sélectionné : Gemini ou Ollama.
- Utiliser les informations réelles du profil et du CV.
- Permettre la modification manuelle du brouillon avant envoi.
- Joindre un CV ou d'autres documents explicitement sélectionnés.
- Vérifier les formats et la taille des pièces jointes.
- Envoyer le message via SMTP.
- Enregistrer l'heure, le destinataire, l'objet, le contenu envoyé, le compte expéditeur, l'identifiant du message et le statut.
- Afficher les erreurs et permettre une nouvelle tentative contrôlée.
- Prévenir les doubles envois avec une clé d'idempotence et une vérification des candidatures déjà envoyées.
- Conserver le contenu exact envoyé pour que l'utilisateur puisse le consulter ultérieurement.

États possibles :

`draft`, `pending_approval`, `queued`, `sending`, `sent`, `failed`, `delivery_unknown`, `bounced`, `replied`, `cancelled`.

Ne marque pas un e-mail comme envoyé avant que le serveur SMTP ait accepté le message. L'acceptation SMTP ne garantit pas sa livraison finale : distingue l'envoi accepté, la livraison confirmée et l'échec de livraison lorsqu'une preuve est disponible.

La candidature automatique doit rester désactivée par défaut. Autoriser l'envoi automatique uniquement pour les scénarios configurés et approuvés par l'utilisateur. Ne jamais envoyer un message sans destinataire vérifié ni inventer une adresse e-mail.

## 5. Boîte de réception unifiée

Créer une interface de type boîte mail comprenant :

- Boîte de réception.
- Messages envoyés.
- Brouillons.
- Réponses des clients.
- Messages non lus.
- Messages liés à une candidature.
- Messages non associés.
- Échecs d'envoi.
- Recherche et filtres par date, expéditeur, destinataire, objet, offre et statut.
- Filtres « Non lus », « Avec réponse », « En attente » et « Erreur ».
- Vue conversation regroupant les messages par fil.
- Détail d'un message avec date, expéditeur, destinataires, objet, corps, pièces jointes et candidature liée.
- Actions « Marquer comme lu », « Archiver », « Répondre » et « Ouvrir la candidature ».
- Pagination côté serveur.

Les messages HTML entrants doivent être affichés de façon sécurisée : supprimer les scripts, bloquer l'exécution de contenu actif et éviter les chargements distants automatiques. Protéger les pièces jointes contre les noms de fichiers dangereux et les fichiers trop volumineux.

Ne pas stocker uniquement un résumé généré par IA. Conserver le contenu original disponible, avec une politique de rétention configurable et des contrôles d'accès appropriés.

## 6. Synchronisation IMAP et association des réponses

Créer un service `EmailInboxSyncService` exécuté par un worker Celery.

Il doit :

1. Se connecter au serveur IMAP via TLS.
2. Synchroniser le dossier configuré.
3. Récupérer les nouveaux messages et les identifiants nécessaires.
4. Enregistrer les messages de façon idempotente.
5. Gérer les messages déjà synchronisés, les reconnexions et les erreurs temporaires.
6. Sauvegarder un curseur de synchronisation fiable.
7. Reprendre après redémarrage sans perdre les messages déjà détectés.
8. Détecter les messages envoyés par les clients, les accusés de réception, les réponses automatiques et les rebonds lorsque cela est possible.
9. Mettre à jour le statut de la candidature sans écraser les informations historiques.

Pour associer une réponse à une candidature, utiliser dans cet ordre :

- `In-Reply-To` et `References` des en-têtes de courrier.
- `Message-ID` du message envoyé.
- Les identifiants de conversation fournis par le fournisseur lorsqu'ils sont disponibles.
- Une comparaison prudente du destinataire, du sujet, de l'expéditeur et de la période.

Une correspondance incertaine doit être marquée « Association à vérifier » et ne doit pas être présentée comme certaine.

Prévoir une synchronisation périodique configurable, un mécanisme de reprise et des métriques. IMAP IDLE peut être ajouté comme optimisation si le serveur le supporte, mais un mécanisme de polling doit rester disponible.

## 7. Notifications push Flutter via Firebase Cloud Messaging

Intégrer FCM pour les notifications Android et préparer la compatibilité iOS.

Backend :

- Créer un `PushNotificationService`.
- Enregistrer les tokens FCM par utilisateur et par appareil.
- Autoriser plusieurs appareils pour un même utilisateur.
- Mettre à jour les tokens renouvelés.
- Supprimer ou désactiver les tokens invalides.
- Gérer les erreurs et les nouvelles tentatives.
- Ne jamais envoyer de notification à un token appartenant à un autre utilisateur.
- Ajouter une préférence utilisateur permettant de désactiver certains types de notifications.
- Enregistrer chaque notification dans PostgreSQL avant ou au moment de son traitement.
- Distinguer la notification persistée, l'envoi accepté par FCM et l'accusé de réception applicatif lorsqu'il est implémenté. Ne pas confondre ces états.

Utiliser le SDK Firebase Admin côté serveur. Les identifiants du compte de service Firebase doivent rester secrets et ne jamais être intégrés à l'application Flutter.

### Types de notifications obligatoires

**A. Nouvelle offre pertinente**

Titre : `Nouvelle offre freelance`

Corps : nom ou titre de l'offre, source et score de correspondance si disponible.

Action : ouvrir la fiche de l'offre.

**B. Candidature envoyée**

Titre : `Candidature envoyée`

Corps : titre de l'offre et destinataire, si celui-ci peut être affiché sans exposer de données sensibles.

Action : ouvrir la candidature et son historique.

Déclencher uniquement après confirmation de l'acceptation par le serveur SMTP ou le mécanisme de candidature utilisé.

**C. Échec d'envoi**

Titre : `Échec de candidature`

Corps : résumé non sensible de l'erreur.

Action : ouvrir la candidature pour corriger ou réessayer.

**D. Nouvelle réponse d'un client**

Titre : `Nouvelle réponse reçue`

Corps : nom de l'expéditeur ou objet du message.

Action : ouvrir directement la conversation correspondante.

**E. Autres événements**

Prévoir des types configurables pour les rebonds, les erreurs de synchronisation et les tâches de collecte en échec.

Ne pas envoyer une notification pour chaque étape technique interne. Éviter les notifications en double.

### Données des notifications

Chaque notification doit inclure un payload de données stable, par exemple :

- `notification_id`
- `type`
- `offer_id` si pertinent
- `application_id` si pertinent
- `conversation_id` si pertinent
- `message_id` si pertinent
- `created_at`

Ne pas placer le contenu intégral d'un e-mail ni des secrets dans le payload. Flutter doit récupérer les détails autorisés via l'API après l'ouverture.

## 8. Application Flutter

Créer ou compléter une application Flutter avec :

- Écran de connexion.
- Tableau de bord.
- Liste des nouvelles offres.
- Liste des candidatures.
- Détail d'une candidature et historique de ses statuts.
- Boîte de réception.
- Liste des conversations.
- Détail d'une conversation avec les messages envoyés et reçus.
- Centre de notifications.
- Badge indiquant le nombre de notifications non lues.
- Écran de préférences des notifications.
- Écran d'état de connexion SMTP/IMAP.
- États de chargement, listes vides, erreurs et boutons de réessai.
- Gestion de la déconnexion et de l'expiration du jeton d'authentification.

Intégrer Firebase Messaging et la gestion des notifications locales lorsque cela est nécessaire.

Gérer correctement :

- La demande d'autorisation de notification.
- Le token FCM.
- La réception en premier plan.
- La réception en arrière-plan.
- L'ouverture de l'application depuis une notification.
- L'ouverture depuis une application terminée.
- Le renouvellement du token FCM.
- La déconnexion et la désinscription éventuelle de l'appareil.
- Les routes profondes vers les offres, candidatures, messages et conversations.

Les notifications push ne doivent pas être le seul moyen d'afficher une information : l'historique doit rester disponible dans le centre de notifications de l'application et être synchronisé depuis l'API.

Utiliser une architecture Flutter maintenable, par exemple Riverpod pour l'état et GoRouter pour la navigation, sauf si le projet utilise déjà une architecture cohérente à conserver.

## 9. Modèles de données

Inspecter d'abord les modèles existants. Ajouter ou adapter les modèles suivants sans créer de doublons :

- `EmailAccount` : configuration et statut du compte.
- `EmailMessage` : message envoyé ou reçu, en-têtes utiles, corps, dates et statut.
- `EmailAttachment` : métadonnées de pièce jointe et emplacement de stockage sécurisé.
- `EmailConversation` : regroupement des messages.
- `EmailSyncState` : dernier curseur et date de synchronisation.
- `DevicePushToken` : utilisateur, token FCM, plateforme, appareil et statut.
- `Notification` : type, titre, contenu, référence métier, dates de lecture et statut.
- `NotificationPreference` : préférences par type.
- `EmailSendAttempt` ou structure équivalente pour tracer les tentatives d'envoi.

Tous les modèles doivent inclure les relations, contraintes, index, horodatages et règles de suppression nécessaires.

Les secrets de compte ne doivent jamais être exposés par les schémas de lecture API.

## 10. API FastAPI

Créer ou adapter des routes versionnées sous `/api/v1`.

### Comptes e-mail

- `GET /email/accounts`
- `POST /email/accounts`
- `GET /email/accounts/{account_id}`
- `PATCH /email/accounts/{account_id}`
- `DELETE /email/accounts/{account_id}`
- `POST /email/accounts/{account_id}/test-smtp`
- `POST /email/accounts/{account_id}/test-imap`
- `POST /email/accounts/{account_id}/sync`

### Messages et conversations

- `GET /email/messages`
- `GET /email/messages/{message_id}`
- `GET /email/conversations`
- `GET /email/conversations/{conversation_id}`
- `POST /email/conversations/{conversation_id}/reply`
- `PATCH /email/messages/{message_id}/read`
- `POST /email/messages/{message_id}/archive`

### Notifications

- `POST /devices/push-tokens`
- `DELETE /devices/push-tokens/{token_id}`
- `GET /notifications`
- `GET /notifications/unread-count`
- `PATCH /notifications/{notification_id}/read`
- `POST /notifications/mark-all-read`
- `GET /notifications/preferences`
- `PATCH /notifications/preferences`

Ces routes sont une base à adapter aux conventions du projet. Toutes les opérations doivent vérifier l'authentification, l'autorisation et l'appartenance des objets à l'utilisateur connecté.

Ajouter pagination, filtres, validations Pydantic, réponses d'erreur cohérentes, documentation OpenAPI et tests.

## 11. Workflows Celery et n8n

Créer les tâches suivantes :

- `sync_email_inbox` : synchronisation IMAP.
- `send_application_email` : envoi SMTP d'une candidature approuvée.
- `process_incoming_email` : normalisation et association d'un message reçu.
- `send_push_notification` : livraison d'une notification via FCM.
- `cleanup_invalid_push_tokens` : nettoyage des tokens invalides.
- `retry_failed_email_tasks` : reprise contrôlée des échecs récupérables.

Les workflows n8n peuvent orchestrer les événements et notifications, mais FastAPI doit rester la source de vérité pour les autorisations, les statuts et les règles métier.

Prévoir des files de tâches, des timeouts, des retries avec backoff, une file d'échec définitif si nécessaire et des logs sans données sensibles.

Une erreur FCM ne doit jamais annuler un e-mail déjà envoyé. Une erreur IMAP ne doit jamais supprimer une candidature. Les opérations indépendantes doivent échouer de manière indépendante.

## 12. Configuration Docker et variables d'environnement

Compléter `.env.example` avec des variables documentées, sans aucune vraie valeur secrète, notamment :

- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USERNAME`
- `SMTP_PASSWORD`
- `SMTP_USE_TLS`
- `IMAP_HOST`
- `IMAP_PORT`
- `IMAP_USERNAME`
- `IMAP_PASSWORD`
- `EMAIL_SYNC_INTERVAL_SECONDS`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_SERVICE_ACCOUNT_PATH` ou une méthode sécurisée équivalente.
- `PUSH_NOTIFICATIONS_ENABLED`

Les paramètres d'un compte e-mail doivent pouvoir être enregistrés via l'interface sécurisée, plutôt que d'obliger l'utilisateur à modifier les variables d'environnement pour chaque compte.

Mettre à jour Docker Compose et le Dockerfile Flutter uniquement si nécessaire. Le service backend et les workers doivent pouvoir accéder aux secrets sans les inclure dans l'image. Ne pas exposer PostgreSQL, Redis ou les interfaces internes publiquement.

Documenter la configuration Firebase : création du projet, enregistrement de l'application Android, téléchargement du fichier de configuration Flutter, activation de FCM et configuration des identifiants serveur.

## 13. Tests obligatoires

Backend :

- Tests SMTP avec serveur factice ou serveur de test.
- Tests IMAP avec messages simulés.
- Déduplication des messages reçus.
- Association d'une réponse par `Message-ID`, `In-Reply-To` et `References`.
- Cas d'association ambiguë.
- Gestion des rebonds et erreurs temporaires.
- Idempotence de l'envoi.
- Tests des permissions et de l'isolation des données.
- Tests de création, lecture et marquage des notifications.
- Tests FCM avec client simulé.
- Vérification qu'un échec FCM ne modifie pas le statut d'envoi d'un e-mail.
- Vérification qu'aucun secret n'apparaît dans les logs ou les réponses API.

Flutter :

- Tests des écrans de boîte de réception et de notifications.
- Tests de navigation depuis une notification.
- Tests des états de chargement, erreur et absence de données.
- Tests de renouvellement du token et de reconnexion.
- Tests de gestion des notifications en premier plan et à l'ouverture de l'application.

Ne prétends pas qu'un test réel SMTP, IMAP ou FCM a réussi si aucun environnement de test n'est configuré.

## 14. Documentation et livraison

Créer ou mettre à jour :

- `docs/EMAIL_SETUP.md`
- `docs/IMAP_SYNC.md`
- `docs/FIREBASE_FLUTTER_SETUP.md`
- `docs/NOTIFICATIONS.md`
- `docs/DEPLOYMENT.md`
- `.env.example`
- Les migrations Alembic.
- Les tests backend et Flutter.
- Les workflows n8n exportables.
- Les instructions de lancement local et de déploiement VPS.

Fournir des commandes exactes pour démarrer, migrer, tester et consulter les logs. Ne pas exécuter de commande destructive sur les données existantes.

## 15. Ordre d'implémentation

1. Inspecter le dépôt et les fonctionnalités existantes.
2. Écrire un plan d'intégration sans casser les modules déjà réalisés.
3. Créer les migrations et les modèles.
4. Implémenter les comptes SMTP/IMAP et les tests de connexion.
5. Implémenter l'envoi, l'historique et la synchronisation des messages.
6. Implémenter l'association des réponses aux candidatures.
7. Implémenter le centre de notifications et l'intégration FCM.
8. Créer les écrans Flutter et les liens profonds.
9. Ajouter les workers, les workflows n8n et les configurations Docker.
10. Exécuter les tests, corriger les erreurs et documenter les limites restantes.

À chaque phase, livrer du code fonctionnel, les tests et les instructions nécessaires. Ne pas se limiter à générer des fichiers vides ou des interfaces fictives. Ne pas simuler une connexion réussie sans l'avoir testée.

Commence maintenant par l'inspection du projet, puis mets à jour `ROADMAP.md` et `PLANNING.md` avant de commencer l'implémentation.

