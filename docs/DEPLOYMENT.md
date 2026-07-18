# KPB Education - Deployment Guide

Pour l'activation et les incidents du Success Lab, appliquer également le
runbook `docs/kpb-competition-readiness-operations-runbook.md`. Un déploiement
réussi ne vaut pas autorisation de pilote tant que sa checklist terrain n'est
pas signée.

## 0. Production actuelle — VPS Hostinger derrière le Traefik existant

C'est la procédure **de référence** pour le lancement. Le VPS Hostinger
(`72.60.190.175`, domaine `kpbeducation.cloud`) fait déjà tourner un **Traefik
v3** partagé (réseau Docker externe `traefik`, ports 80/443, certificats
Let's Encrypt via resolver `letsencrypt`) devant n8n + Mautic. L'app KPB s'y
**greffe** : pas de nginx, pas de ports 80/443 propres — `api` et `admin`
rejoignent le réseau `traefik` et sont routés par des labels (déjà dans
`docker-compose.yml`). `db` + `clamav` restent sur un réseau privé `internal`.

**DNS** (déjà créés) : `api.kpbeducation.cloud` et `admin.kpbeducation.cloud`
→ `72.60.190.175` (A). Requis avant le 1er déploiement pour l'émission du
certificat (challenge HTTP-01 de Traefik). Le domaine racine
`kpbeducation.cloud` (`@` + CNAME `www`) pointe aussi sur ce VPS et est servi
par le service `web` (pages légales statiques — voir ci-dessous).

**Site légal statique (`web`)** : sert `kpbeducation.cloud` — politique de
confidentialité, CGU et procédure de suppression de compte. Ces URLs sont
référencées dans Play Console (« Privacy policy », « Account deletion ») et
App Store Connect ; elles doivent rester en ligne en permanence. Mise en
service : `docker compose up -d web` (aucun build, image nginx officielle ;
contenu monté depuis `web/public/`).

**Déploiement (SSH sur le VPS)** :

```bash
# 1. Récupérer le code
git clone <repo> /docker/kpb && cd /docker/kpb   # ou git pull si déjà cloné

# 2. Créer le .env de prod À CÔTÉ du docker-compose.yml (voir §1 pour le
#    contenu complet ; secrets forts, jamais commités). Au minimum :
#    POSTGRES_* , KPB_JWT_* , KPB_ADMIN_REFRESH_SECRET , SUPABASE_URL ,
#    CORS_ORIGINS=https://admin.kpbeducation.cloud , GROQ/RESEND/ONESIGNAL…

# 3. Utiliser un tag d'image immuable (SHA Git ou version de release).
export KPB_IMAGE_TAG="$(git rev-parse --short=12 HEAD)"
export KPB_BUILD_SHA="$(git rev-parse HEAD)"

# 4. Le réseau Traefik existe déjà (créé par le stack marketing). Sinon :
docker network create traefik

# 5. Construire les images SANS remplacer les conteneurs en cours.
docker compose build api admin

# 6. Vérifier puis copier la dernière sauvegarde hors du VPS.
docker compose exec -T db pg_dump -U "$POSTGRES_USER" -d "${POSTGRES_DB:-kpb}" \
  --format=custom > "backups/predeploy-${KPB_IMAGE_TAG}.dump"

# 7. Appliquer les migrations une seule fois avec la nouvelle image. Les
#    conteneurs en ligne restent sur l'ancienne image si cette étape échoue.
docker compose run --rm --no-deps api npx prisma migrate deploy

# 8. Remplacer uniquement l'API et l'admin, puis vérifier leur santé.
docker compose up -d --no-deps api admin

# 9. Première installation seulement : seed après migrations.
docker compose exec api npm run prisma:seed

# 10. Vérifs
curl -fsS https://api.kpbeducation.cloud/api/health/live   # 200 attendu
curl -fsS https://api.kpbeducation.cloud/api/health/ready  # 200 attendu
curl -fsS https://api.kpbeducation.cloud/api/config/app
#    admin.kpbeducation.cloud doit répondre en HTTPS (cert Let's Encrypt auto)
```

Le démarrage de l'API n'applique volontairement aucune migration. Cette étape
explicite garantit que la sauvegarde est terminée avant toute évolution du
schéma et qu'un échec de migration ne remplace pas les conteneurs sains.

Pour un rollback applicatif, remettre tous les flags Competition Readiness à
`false`, le kill switch IA à `true`, `KPB_SUCCESS_LAB_ROLLOUT_PERCENT=0`, puis
revenir au `KPB_IMAGE_TAG` précédent et relancer uniquement `api` et `admin`.
Les migrations de ce lot sont additives : ne restaurer la base qu'en cas de
corruption avérée, après décision opérationnelle et sauvegarde des données
post-déploiement.

Traefik gère le TLS + l'upgrade WebSocket (chat des dossiers) automatiquement —
aucune config nginx à écrire. Les limites `mem_limit` du `docker-compose.yml`
protègent la box 8 Go partagée (une fuite Mautic/n8n ne peut pas tuer l'API).

> Stockage des documents : le fallback disque est persisté sur le volume
> `kpb-uploads` (OK sur VPS). Pour décharger le disque, renseigner les
> `KPB_S3_*` (Scaleway Paris `fr-par`, Bunny, ou R2) — voir §backend.

> ⚠️ Ne pas ajouter un 2ᵉ reverse-proxy : le conteneur `traefik-hctj` en
> crash-loop sur la box est justement un Traefik en doublon à supprimer.

---

## 1. Backend — alternative : VPS dédié avec nginx

*(Procédure historique, pour un VPS dédié SANS Traefik. Sur le VPS Hostinger
actuel, suivre la §0 ci-dessus.)*

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
CORS_ORIGINS=https://admin.kpbeducation.cloud

# L'API est derrière exactement un proxy (Traefik) ; nécessaire au rate limiting
KPB_TRUST_PROXY_HOPS=1
```

3. Construisez les images, sauvegardez la base, exécutez explicitement
   `npx prisma migrate deploy` avec la nouvelle image, puis remplacez les
   services comme décrit dans la procédure de référence §0. N'utilisez pas un
   simple `up -d --build` pour une livraison de production.
4. Configurez NGINX pour pointer le domaine de production `api.kpbeducation.cloud` vers `http://127.0.0.1:3000` (le conteneur écoute sur le port `3000` via `PORT=3000` dans `docker-compose.yml`), avec HTTPS/Certbot.

> ⚠️ **Le chat temps réel (WebSocket) exige l'upgrade côté nginx** — sans les
> en-têtes ci-dessous, la connexion socket.io échoue en production. Prévoir aussi
> `client_max_body_size` ≥ 10 Mo pour les uploads de documents.
>
> ```nginx
> server {
>   server_name api.kpbeducation.cloud;
>   client_max_body_size 12m;                 # uploads (limite app = 10 Mo)
>   location / {
>     proxy_pass http://127.0.0.1:3000;
>     proxy_http_version 1.1;                  # requis pour le WebSocket
>     proxy_set_header Upgrade $http_upgrade;  # /socket.io upgrade
>     proxy_set_header Connection "upgrade";
>     proxy_set_header Host $host;
>     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
>     proxy_set_header X-Forwarded-Proto $scheme;
>   }
> }
> ```

> Les documents étudiants ne sont plus servis par un chemin public `/uploads`.
> N'ajoutez donc pas de bloc Nginx qui pointe ce chemin vers le volume : le
> téléchargement passe uniquement par l'API authentifiée. Nginx doit être le
> seul proxy de l'API exposé à Internet ; c'est ce qui rend fiable
> `KPB_TRUST_PROXY_HOPS=1` et le rate limiting par adresse client.

### Vérification de santé après déploiement

L'API expose deux contrôles distincts :

- `GET /api/health/live` vérifie que le processus répond ; Docker l'utilise pour son healthcheck.
- `GET /api/health/ready` vérifie aussi la connexion PostgreSQL. Un répartiteur ou une sonde externe doit exiger un `200` avant de router du trafic vers une nouvelle version.

Après `docker-compose up -d --build`, vérifiez les deux :

```bash
curl -fsS https://api.kpbeducation.cloud/api/health/live
curl -fsS https://api.kpbeducation.cloud/api/health/ready
docker compose ps
```

### Database Migrations & seed :

Lorsque l'API Container est lancé pour la première fois, la base de données est vide. Appliquez le schéma Prisma puis semez le catalogue :

```bash
docker exec -it kpb_api npx prisma migrate deploy
docker exec -it kpb_api npm run seed:catalog   # pays + OMNES + partenaires + catalogue unique
docker exec -it kpb_api npm run prisma:seed    # comptes admin (mots de passe temporaires imprimés une fois) + contenu de démo
docker exec -it kpb_api npm run verify:catalog # confirme 0 référence pays orpheline
```

> ℹ️ Le conteneur API **n'exécute volontairement aucune migration au
> démarrage**. Appliquez `prisma migrate deploy` une seule fois, après la
> sauvegarde et avant le remplacement des conteneurs, conformément à la §0.
> Cette séparation évite qu'un redémarrage automatique modifie le schéma sans
> fenêtre contrôlée. Les seeds ne sont à relancer que pour un premier
> provisioning ou un rafraîchissement explicitement validé du catalogue.

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
À chaque push sur `main`, GitHub teste l'application, construit un APK de
validation et compile iOS sans signature. Lorsqu'un tag `v*` est créé, GitHub
produit un AAB Android signé avec la clé d'upload ; le workflow échoue si l'une
des quatre variables de signature manque.

- L'APK Android de validation (debug).
- Le `.app` iOS (sans signature).
- L'AAB Android signé sur tag `v*`.

### Connexion Google / magic-link (deep link Supabase) :

Le retour d'authentification (Google OAuth et magic-link) utilise le deep link
`io.supabase.kpbeducation://login-callback/` (voir `AppConfig.supabaseOAuthRedirect`).
Ce scheme est enregistré dans `AndroidManifest.xml` et `ios/Runner/Info.plist`.
Il doit **aussi** figurer dans la *Redirect URLs allow-list* du dashboard Supabase
(Authentication → URL Configuration), sinon Google sign-in laisse l'utilisateur
bloqué dans le navigateur. Testez le flux complet sur un appareil physique
Android **et** iOS avant la soumission aux stores.

### API Endpoint :

L'hôte API de production canonique est **`https://api.kpbeducation.cloud/api`**.
La CI compile l'app avec `--dart-define=KPB_APP_ENV=prod`, qui résout cet hôte
via `app_config.dart` (ne pas hardcoder `KPB_API_BASE_URL`). Assurez-vous que le
certificat TLS nginx couvre bien `api.kpbeducation.cloud`.

**⚠️ Attention pour iOS :**
Le GitHub Action actuel compile l'application iOS pour prouver qu'il n'y a pas d'erreur de compilation (`--no-codesign`). Cependant, pour l'envoyer sur l'App Store Connect, il te faudra soit :
A) Compiler manuellement avec `Xcode` sur ton Mac (Plus simple pour les V1).
B) Configurer `Fastlane match` et injecter tes Certificats Apple dans les GitHub Secrets pour que le Runner puisse signer le `.ipa` (Nécessite le compte Apple Developer actif).

---

## 3. Panneau admin (Next.js)

Le panneau admin est un service du `docker-compose.yml` (`admin`, image Next.js
standalone), à placer derrière nginx sur `https://admin.kpbeducation.cloud` — ce
domaine doit figurer dans `CORS_ORIGINS` (déjà le cas dans l'exemple `.env`).

- **Build/déploiement** : `docker-compose up -d --build admin`. L'URL de l'API
  est **inlinée au build** via l'argument `NEXT_PUBLIC_KPB_API_BASE_URL`
  (défaut `https://api.kpbeducation.cloud/api`, surchargable par
  `KPB_ADMIN_API_BASE_URL` dans le `.env`) — **rebuild** l'image si l'hôte API
  change.
- **nginx** : proxy `admin.kpbeducation.cloud` → `http://127.0.0.1:3001`, HTTPS via
  Certbot. Pour que le cookie de session admin (httpOnly, `Secure`) fonctionne,
  l'admin et l'API doivent être servis en HTTPS sur le même domaine parent
  (`*.kpbeducation.cloud`).
- Le conteneur tourne en utilisateur non-root et n'expose que le port 3000
  interne (publié sur `127.0.0.1:3001`).
