# FreelanceRadar — application Flutter

Application **Android** et **Linux** de FreelanceRadar : consulter et trier les offres collectées
par le backend, gérer les sources et suivre leurs collectes. Interface **noire (#000000),
minimaliste, pensée d'abord pour le téléphone** ; sur un grand écran (Linux), la barre de
navigation du bas devient un rail latéral et le contenu reste centré.

L'application ne contient aucune logique métier ni secret : tout passe par l'API du backend
(`../backend`, préfixe `/api/v1`).

---

## 1. Démarrage rapide

Prérequis : Flutter 3.44 (stable), le backend lancé (voir `../README.md`) et un compte créé sur
le serveur (`uv run python -m app.cli create-user --email vous@example.com`). Selon la cible :
- **Linux** : `clang cmake ninja pkg-config gtk3 libsecret` (Arch : `sudo pacman -S clang cmake ninja pkgconf gtk3 libsecret`) ;
- **Android** : Android SDK + JDK 17 ou plus (fourni par Android Studio).

```bash
cd mobile
flutter pub get
flutter run -d linux               # application de bureau
flutter run -d <id-du-telephone>   # voir `flutter devices` (débogage USB activé)
```

Serveur par défaut : `http://localhost:8000` (backend local, Linux). Sur un téléphone : touchez
**Serveur** en bas de l'écran de connexion, saisissez `http://<IP-du-PC>:8000` (même Wi-Fi ; lancez
alors l'API avec `--host 0.0.0.0`), puis **Tester** et **Enregistrer**.

## 2. Construire les applications

```bash
flutter build apk --release        # build/app/outputs/flutter-apk/app-release.apk
flutter build linux --release      # build/linux/x64/release/bundle/ (lancer ./freelanceradar)
```

Installer l'APK sur un téléphone branché : `adb install -r build/app/outputs/flutter-apk/app-release.apk`.

Identifiant Android : `mg.garrix.freelanceradar`. Il diffère de l'ancienne application
« Garrix Offre » (`mg.garrix.garrix_offre`) : les deux peuvent coexister ; désinstallez l'ancienne
si elle n'est plus utile.

### Signature Android

`android/key.properties` (jamais commité) pointe vers la clé de release. **Sauvegardez la clé** :
sans elle, une nouvelle version ne pourra pas s'installer par-dessus l'ancienne. Sans
`key.properties`, la release est signée avec la clé de debug.

```properties
storePassword=...
keyPassword=...
keyAlias=...
storeFile=/home/<vous>/.android-keys/<cle>.jks
```

## 3. Écrans et API utilisée

| Onglet | Contenu | Endpoints |
|---|---|---|
| Connexion | Email + mot de passe, choix du serveur (pas d'inscription : comptes créés sur le serveur) | `POST /auth/login`, `/auth/refresh`, `GET /auth/me`, `GET /ready` |
| Accueil | Compteurs (offres, nouvelles, pertinentes, favorites, sources actives / en erreur), dernières offres, état des sources | `GET /offers` (totaux par statut), `GET /sources` |
| Offres | Recherche, filtres (statut, source, période, archivées), tri, favoris, ignorer, archiver ; détail avec notes et lien vers l'annonce | `GET /offers`, `GET/PATCH /offers/{id}`, `POST /offers/{id}/archive` |
| Sources | Liste filtrable, activation, création / modification, test sans écriture, collecte manuelle, historique | `/sources`, `/sources/{id}`, `/test`, `/run`, `/runs` |
| Alertes | Notifications (nouvelles offres, sources en erreur ou bloquées), filtres, tout marquer comme lu ; badge relu toutes les 60 s | `/notifications`, `/unread-count`, `/{id}/read`, `/mark-all-read` |
| Profil | Résumé et complétude, modification (identité, coordonnées, liens, disponibilité, tarif, langues, recherche), compétences avec niveau | `GET/PATCH /profile`, `/profile/skills` |
| Réglages (depuis Profil) | Compte, état du serveur (PostgreSQL, Redis), changement de serveur, documentation de l'API, déconnexion (révoque toutes les sessions) | `GET /ready`, `POST /auth/logout` |

Fonctionnalités prévues côté backend mais **pas encore disponibles** (donc absentes de
l'application) : expériences et CV, score de pertinence, IA, candidatures, e-mails, push FCM.
L'ancienne application « Garrix Offre » (commit `f55f266`) contient des écrans réutilisables pour
ces modules.

## 4. Architecture

```
lib/
├── main.dart, app.dart           # démarrage, thème, localisation fr_FR, routeur
├── core/
│   ├── config/                   # URL du serveur (modifiable, persistée), nom et version
│   ├── network/                  # ApiClient (Dio) : erreurs en français, renouvellement
│   │                             #   automatique du token sur 401, pagination {items, total, ...}
│   ├── auth/                     # session (tokens : Keystore Android / trousseau Linux), utilisateur
│   ├── router/                   # go_router : 5 onglets + pages de détail
│   ├── theme/                    # palette noir pur, typographie Inter, composants Material 3
│   ├── widgets/                  # design system : cartes, pastilles, listes paginées, formulaires,
│   │                             #   feuilles de détail / formulaire, blocs JSON
│   └── utils/                    # formatage (dates, montants), lecture JSON, liens externes
└── features/
    ├── auth/                     # connexion, choix du serveur
    ├── dashboard/                # accueil
    ├── offers/                   # liste, filtres, détail
    ├── sources/                  # liste, détail, formulaire, test, historique des collectes
    ├── notifications/            # alertes, badge des non lues
    ├── profile/                  # profil, modification, compétences
    └── settings/                 # compte, serveur, à propos
```

Chaque fonctionnalité suit la même organisation : `data/` (modèles `fromJson` et repository qui
appelle l'API), pages `*_page.dart`, `widgets/`. L'état est géré avec **Riverpod 3**, la
navigation avec **go_router**.

### Design

- Fond `#000000`, surfaces `#0A0A0A` → `#1F1F1F`, bordures fines, texte blanc / gris, accent blanc ;
  couleurs sémantiques (vert, ambre, rouge) réservées aux statuts.
- Police **Inter** (incluse, licence OFL), icônes Material arrondies.

## 5. Qualité

```bash
flutter analyze     # aucune remarque attendue
flutter test        # modèles, client réseau, tests de fumée des écrans (téléphone et grand écran)
```

## 6. Sécurité

- Tokens stockés dans le Keystore Android / le trousseau Linux (libsecret). Si aucun trousseau
  n'est disponible sous Linux, repli sur les préférences locales de l'utilisateur.
- `android:usesCleartextTraffic="true"` autorise un backend HTTP sur le réseau local.
  **À retirer dès que l'API est servie en HTTPS** (mots de passe et tokens circulent sinon en clair).
