# KPB Education - Deployment Guide

## 1. Backend (VPS PlanetHoster)

We use Docker to ensure the backend environment on the PlanetHoster VPS perfectly matches development.

### Pré-requis sur le VPS:

- Installer `docker` et `docker-compose`.
- Installer `nginx` (pour le reverse proxy et le HTTPS/SSL via Certbot).

### Déploiement :

1. Clonez ce repo sur le VPS.
2. Créez un fichier `.env` à la racine (à côté du `docker-compose.yml`) avec vos variables sécurisées :

> ℹ️ Les noms de variables doivent correspondre exactement à ce que lit le backend
> (voir `backend/.env.example` pour la liste complète et commentée, et
> `docker-compose.yml`). En particulier les secrets sont préfixés `KPB_`.

```env
# Base de données (utilisée par le service `db` et par l'API)
POSTGRES_USER=kpb_admin
POSTGRES_PASSWORD=secure_vps_password
POSTGRES_DB=kpb_prod

# Secrets applicatifs (générer des chaînes longues et aléatoires)
KPB_JWT_SECRET=production_super_secret_jwt
KPB_JWT_REFRESH_SECRET=another_long_random_secret
KPB_ADMIN_REFRESH_SECRET=another_long_random_secret

# Auth Supabase (étudiants/parents) — SUPABASE_URL est obligatoire
SUPABASE_URL=https://YOUR-PROJECT.supabase.co
SUPABASE_JWT_SECRET=            # seulement pour les projets HS256 legacy

# Origines CORS autorisées (app admin web), séparées par des virgules
CORS_ORIGINS=https://admin.kpb-education.com
```

3. Lancez : `docker-compose up -d --build`
4. Configurez NGINX pour pointer votre domaine (ex: `api.vps-planethoster.com`) vers `http://127.0.0.1:3000` (le conteneur écoute sur le port `3000` via `PORT=3000` dans `docker-compose.yml`).

### Database Migrations & seed :

Lorsque l'API Container est lancé pour la première fois, la base de données est vide. Appliquez le schéma Prisma puis semez le catalogue :

```bash
docker exec -it kpb_api npx prisma migrate deploy
docker exec -it kpb_api npm run seed:catalog   # pays + OMNES + partenaires + catalogue unique
docker exec -it kpb_api npm run prisma:seed    # comptes admin (mots de passe temporaires imprimés une fois) + contenu de démo
docker exec -it kpb_api npm run verify:catalog # confirme 0 référence pays orpheline
```

> ⚠️ **À CHAQUE redéploiement** (`docker-compose up -d --build`), et pas seulement
> au premier lancement, relancez les migrations si la release en contient une :
> ```bash
> docker exec -it kpb_api npx prisma migrate deploy
> ```
> Le conteneur démarre le nouveau code sans appliquer les migrations
> automatiquement : l'oublier fait tourner du code contre un schéma périmé
> (erreurs `column ... does not exist`). Les seeds ne sont à relancer que pour
> rafraîchir le catalogue.

### Sauvegardes de la base de données

Le service `db-backup` (dans `docker-compose.yml`) crée automatiquement un dump
gzippé par jour dans `./backups` sur le VPS (bind mount → les dumps survivent à
`docker-compose down -v`), avec une rétention de `BACKUP_KEEP_DAYS` jours (14 par
défaut ; réglable dans `.env`).

**Important — copie hors-site :** `./backups` est sur le même disque que la base.
Pour protéger contre une perte totale du VPS, synchronisez ce dossier vers un
stockage externe (les identifiants S3 `KPB_S3_*` existent déjà). Exemple de cron
hôte (quotidien) :

```bash
# crontab -e  (sur le VPS)
30 3 * * * aws s3 sync /chemin/vers/repo/backups s3://VOTRE_BUCKET/db-backups --delete
```

**Restauration** (écrase la base — arrêter l'API d'abord) :

```bash
docker-compose stop api
POSTGRES_USER=kpb_admin POSTGRES_DB=kpb_prod \
  ./backend/scripts/restore-db.sh ./backups/kpb-kpb_prod-AAAAMMJJ-HHMMSSZ.sql.gz
docker-compose up -d api
```

Testez une restauration complète sur un environnement jetable avant le lancement.

---

## 2. Frontend (Flutter CI/CD)

Les pipelines CI/CD sont configurées via GitHub Actions (voir `.github/workflows/flutter-ci.yml`).
À chaque push sur `main`, GitHub va tester et compiler automatiquement :

- L'APK Android.
- Le `.app` iOS (sans signature).

### Connexion Google / magic-link (deep link Supabase) :

Le retour d'authentification (Google OAuth et magic-link) utilise le deep link
`io.supabase.kpbeducation://login-callback/` (voir `AppConfig.supabaseOAuthRedirect`).
Ce scheme est enregistré dans `AndroidManifest.xml` et `ios/Runner/Info.plist`.
Il doit **aussi** figurer dans la *Redirect URLs allow-list* du dashboard Supabase
(Authentication → URL Configuration), sinon Google sign-in laisse l'utilisateur
bloqué dans le navigateur. Testez le flux complet sur un appareil physique
Android **et** iOS avant la soumission aux stores.

### API Endpoint :

Le backend de production est passé à l'App Flutter à la compilation via :
`--dart-define=KPB_API_BASE_URL=https://api.vps-planethoster.com`

**⚠️ Attention pour iOS :**
Le GitHub Action actuel compile l'application iOS pour prouver qu'il n'y a pas d'erreur de compilation (`--no-codesign`). Cependant, pour l'envoyer sur l'App Store Connect, il te faudra soit :
A) Compiler manuellement avec `Xcode` sur ton Mac (Plus simple pour les V1).
B) Configurer `Fastlane match` et injecter tes Certificats Apple dans les GitHub Secrets pour que le Runner puisse signer le `.ipa` (Nécessite le compte Apple Developer actif).
