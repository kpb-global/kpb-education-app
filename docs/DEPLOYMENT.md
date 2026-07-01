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

---

## 2. Frontend (Flutter CI/CD)

Les pipelines CI/CD sont configurées via GitHub Actions (voir `.github/workflows/flutter-ci.yml`).
À chaque push sur `main`, GitHub va tester et compiler automatiquement :

- L'APK Android.
- Le `.app` iOS (sans signature).

### API Endpoint :

Le backend de production est passé à l'App Flutter à la compilation via :
`--dart-define=KPB_API_BASE_URL=https://api.vps-planethoster.com`

**⚠️ Attention pour iOS :**
Le GitHub Action actuel compile l'application iOS pour prouver qu'il n'y a pas d'erreur de compilation (`--no-codesign`). Cependant, pour l'envoyer sur l'App Store Connect, il te faudra soit :
A) Compiler manuellement avec `Xcode` sur ton Mac (Plus simple pour les V1).
B) Configurer `Fastlane match` et injecter tes Certificats Apple dans les GitHub Secrets pour que le Runner puisse signer le `.ipa` (Nécessite le compte Apple Developer actif).
