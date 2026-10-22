# Déploiement du backend sur le VPS

Le backend (API, worker, Beat, n8n, PostgreSQL, Redis) tourne sur le VPS avec
`docker-compose.prod.yml`. L'application mobile n'est pas déployée ici.

## Architecture sur le serveur

| Élément | Emplacement |
|---|---|
| Dossier | `~/freelanceradar` (`docker-compose.prod.yml`, `.env`, `n8n/workflows/`) |
| Image | `ghcr.io/bry4ng4rrix/freelanceradar-backend:sha-<commit>` (construite par GitHub Actions) |
| API | `http://157.173.103.147:8000` (`API_BIND=0.0.0.0` dans `.env`) |
| n8n | `http://157.173.103.147:5678` (`N8N_BIND=0.0.0.0`, `N8N_SECURE_COOKIE=false`) ; identifiants du propriétaire dans `~/freelanceradar/n8n-owner.txt` (droits `600`) |
| PostgreSQL, Redis | aucun port publié (réseau Docker interne) |

Les secrets de l'application sont dans `~/freelanceradar/.env` (droits `600`), jamais dans Git ni
dans GitHub. `EMAIL_SENDING_ENABLED=false` tant que l'envoi réel n'est pas autorisé.

## Déploiement automatique (GitHub Actions)

`.github/workflows/backend.yml` : à chaque push sur `master` touchant le backend :
tests (ruff, mypy, pytest sur PostgreSQL) → image poussée sur GHCR → déploiement SSH
(`docker compose pull && up -d`, attente de l'état `healthy`). Rien n'est déployé si un test échoue.

À configurer dans GitHub (Settings → Secrets and variables → Actions) :

| Type | Nom | Valeur |
|---|---|---|
| Secret | `VPS_SSH_KEY` | clé privée de déploiement (dédiée, ajoutée au serveur avec l'option `restrict`) |
| Secret | `VPS_KNOWN_HOSTS` | sortie de `ssh-keyscan -t ed25519,ecdsa,rsa 157.173.103.147` |
| Variable | `VPS_HOST` | `157.173.103.147` |
| Variable | `VPS_USER` | `garrix` |
| Variable | `VPS_DEPLOY_PATH` | `/home/garrix/freelanceradar` |

Le serveur récupère l'image avec les identifiants `ghcr.io` déjà enregistrés pour l'utilisateur
`garrix` (comme pour les autres projets). Si le paquet est privé et que ces identifiants n'y ont
pas accès : `docker login ghcr.io` sur le serveur avec un jeton `read:packages`.

## Commandes utiles (sur le serveur)

```bash
cd ~/freelanceradar
C="docker compose -f docker-compose.prod.yml"
$C ps                                                # état des services
$C logs -f --tail=100 api worker beat n8n            # journaux
$C exec api python -m app.cli create-user --email vous@example.com   # compte (mot de passe demandé)
$C exec api python -m app.cli check-smtp             # SMTP, aucun envoi
$C exec api python -m app.cli check-imap             # IMAP, lecture seule
$C exec api python -m app.cli cleanup-offers --dry-run   # offres expirées (essai)
$C up -d                                             # redémarrer avec l'image mémorisée (.env)
```

n8n : http://157.173.103.147:5678 (compte propriétaire créé au déploiement, avant l'ouverture du
port ; identifiants dans `~/freelanceradar/n8n-owner.txt`, à changer après la première connexion).

**Exposition directe en HTTP** : mots de passe et jetons circulent en clair. Passer en HTTPS (section
suivante) puis remettre `API_BIND` / `N8N_BIND` à `127.0.0.1` et `N8N_SECURE_COOKIE=true`.

## Sauvegarde et restauration PostgreSQL

```bash
# Sauvegarde (à planifier, ex. cron quotidien)
$C exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > backup-$(date +%F).dump
# Restauration dans une base vide (vérifier la cible avant !)
$C exec -T postgres sh -c 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists' < backup-AAAA-MM-JJ.dump
```

Ne jamais lancer `alembic downgrade` en production : les migrations sont vérifiées dans les deux
sens par les tests, sur une base dédiée.

## HTTPS (à faire)

L'API est exposée en HTTP sur le port 8000. Pour HTTPS, il faut un nom de domaine pointant vers
`157.173.103.147`, puis un site nginx (`proxy_pass http://127.0.0.1:8000`) et un certificat
`certbot --nginx`, comme pour les autres sites du serveur (nécessite `sudo`).
