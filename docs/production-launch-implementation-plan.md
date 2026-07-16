# KPB Education — Plan d’implémentation pour la mise en production

**Statut :** plan d’exécution  
**Priorité :** lancement prochain  
**Périmètre :** application Flutter, API NestJS/PostgreSQL, administration Next.js, infrastructure et stores  
**Budget de taille accepté :** environ **50 MB téléchargés/installés** pour la version Android destinée aux utilisateurs

## 1. Objectif

Préparer une version de KPB Education suffisamment sécurisée, stable et exploitable pour :

1. une bêta interne ;
2. une bêta fermée avec de vrais étudiants et conseillers ;
3. un déploiement public progressif sur Android et iOS.

Le lancement public ne doit commencer qu’après validation de tous les critères `P0` de ce document.

## Avancement de l’implémentation — 11 juillet 2026

Les protections applicatives préparatoires sont implémentées sur la branche
`codex/production-launch` : documents privés et validés par contenu, proxy de
confiance, endpoints de santé, healthcheck Docker, garde-fou de signature
Android, AAB signé sur tags et entitlement APNs iOS de production.

Restent volontairement à exécuter avec les accès du propriétaire : secrets et
certificats stores, DNS/TLS, déploiement staging, migrations/seed sur les bases
réelles, tests physiques, soumission Play/TestFlight et validation de la taille
calculée par Play Console. Ces éléments ne peuvent pas être certifiés depuis le
poste local sans accès aux comptes et à l’infrastructure.

## 2. Principes d’exécution

- Utiliser la branche `main` actuelle comme base de vérité.
- Préserver l’architecture existante : Flutter, NestJS/Prisma et Next.js.
- Privilégier les changements additifs et ciblés.
- Ne jamais publier un build signé avec une clé de développement.
- Ne jamais rendre publics les documents déposés par les étudiants.
- Valider chaque phase sur l’environnement staging avant la production.
- Conserver `KPB_MVP_ONLY=true` pour le premier lancement.

## 3. Planning indicatif

| Phase | Sujet | Durée estimée | Condition de sortie |
|---|---|---:|---|
| 0 | Base de release propre | 0,5–1 jour | Branche synchronisée avec `main` |
| 1 | Sécurité bloquante | 1–2 jours | Documents privés et rate limiting correct |
| 2 | Infrastructure staging/production | 1–2 jours | DNS, HTTPS, API et base accessibles |
| 3 | Données et intégrations | 1–2 jours | Parcours réels opérationnels sur staging |
| 4 | Builds Android/iOS | 1–2 jours | AAB et IPA acceptés par les plateformes |
| 5 | QA et performance | 2–3 jours | Aucun défaut P0/P1 ouvert |
| 6 | Automatisation complémentaire | 1–2 jours | E2E et contrôles de release actifs |
| 7 | Bêta et lancement progressif | 3–7 jours | Indicateurs stables |

**Estimation globale :** 10 à 15 jours ouvrés, hors délais de revue Apple et Google.

---

## Phase 0 — Construire une base de release propre

### Travaux

- [x] Mettre à jour les références distantes Git.
- [x] Créer `codex/production-launch` depuis la dernière version de `origin/main`.
- [ ] Ne pas publier directement depuis `codex/kpb-delivery-review`.
- [ ] Examiner les cinq commits locaux de cette branche et ne réintégrer que ceux encore utiles.
- [ ] Vérifier que les correctifs déjà intégrés dans `main` ne sont pas écrasés.
- [ ] Verrouiller le périmètre avec `KPB_MVP_ONLY=true`.
- [ ] Définir la version de la release, par exemple `1.0.0+46`.
- [ ] Créer un tag uniquement après validation finale, par exemple `v1.0.0-rc.1`.

### Validation

```bash
git status --short --branch
git log --oneline --decorate -10
git diff --stat origin/main...HEAD
```

### Critère de sortie

- Branche basée sur la dernière version de `main`.
- Aucun changement non identifié.
- Périmètre MVP documenté et verrouillé.

---

## Phase 1 — Corriger les blocages de sécurité

### 1.1 Rendre les documents étudiants privés

- [x] Supprimer l’exposition statique publique de `/uploads`.
- [x] Reprendre et revoir le correctif du commit `509bf5d`.
- [x] Ajouter un endpoint authentifié de téléchargement.
- [x] Vérifier que l’étudiant possède le dossier et le document demandés.
- [x] Autoriser un conseiller uniquement selon son rôle et son affectation.
- [x] Ne pas accepter directement une URL de fichier fournie par le client.
- [x] Détecter le type réel du fichier à partir de son contenu.
- [x] Générer l’extension du fichier à partir du type détecté.
- [x] Refuser HTML, SVG, JavaScript, doubles extensions et traversées `../`.
- [x] Conserver la limite de 10 MB par document.
- [x] Conserver le scan antivirus ClamAV en mode fail-closed.
- [x] Utiliser `Cache-Control: private, no-store`.
- [x] Utiliser `Content-Disposition: attachment` lorsque l’affichage inline n’est pas nécessaire.

### Tests requis

- [ ] Le propriétaire peut télécharger son document.
- [ ] Un autre étudiant reçoit `404` ou `403`.
- [ ] Un utilisateur non connecté reçoit `401`.
- [ ] Un fichier dont le contenu est travesti par un faux type MIME est rejeté.
- [ ] Un fichier infecté est rejeté.
- [ ] Un nom contenant `../` est rejeté.
- [ ] Un fichier HTML renommé en image est rejeté.
- [ ] La suppression du compte efface également les fichiers associés.

### 1.2 Corriger le rate limiting derrière Nginx

- [x] Configurer explicitement le proxy de confiance côté NestJS/Express.
- [ ] Extraire l’adresse du client depuis une chaîne de proxy contrôlée.
- [ ] Vérifier que la limitation globale s’applique par IP/utilisateur.
- [ ] Conserver une limite renforcée pour la connexion et les OTP.
- [ ] Ajouter un test avec plusieurs adresses IP simulées derrière Nginx.

### Critère de sortie

- Aucun document étudiant n’est accessible publiquement.
- Les tests d’autorisation et de validation de fichiers sont verts.
- Deux utilisateurs différents ne partagent pas accidentellement le même quota réseau.

---

## Phase 2 — Déployer l’infrastructure réelle

### 2.1 DNS et HTTPS

- [ ] Configurer `api.kpb-education.com`.
- [ ] Configurer `admin.kpb-education.com`.
- [ ] Configurer `kpb-education.com`.
- [ ] Créer des domaines distincts pour staging.
- [ ] Installer TLS/HTTPS avec renouvellement automatique.
- [ ] Vérifier les redirections HTTP vers HTTPS.

### 2.2 Services

- [ ] Déployer PostgreSQL.
- [ ] Déployer l’API NestJS.
- [ ] Déployer l’administration Next.js.
- [ ] Déployer ClamAV.
- [ ] Monter un volume persistant pour les fichiers si S3 n’est pas encore utilisé.
- [ ] Vérifier les règles Nginx pour REST, WebSocket et uploads.
- [ ] Limiter l’accès direct aux ports Postgres, API et admin.

### 2.3 Santé et observabilité

- [x] Créer `/health/live` pour vérifier le processus API.
- [x] Créer `/health/ready` pour vérifier PostgreSQL et les services indispensables.
- [x] Ajouter un healthcheck Docker pour l’API.
- [ ] Ajouter un contrôle externe d’uptime.
- [ ] Alerter sur les erreurs 5xx, la latence, l’espace disque et les échecs de sauvegarde.
- [ ] Connecter Crashlytics et les tableaux de bord Analytics.

### 2.4 Sauvegardes

- [ ] Conserver les sauvegardes PostgreSQL quotidiennes.
- [ ] Copier les sauvegardes hors du VPS.
- [ ] Définir la rétention.
- [ ] Effectuer un test de restauration complet.
- [ ] Documenter le RPO et le RTO acceptés.

### Critère de sortie

- Staging accessible en HTTPS.
- L’API répond et sa readiness devient négative lorsque PostgreSQL est indisponible.
- Une sauvegarde peut être restaurée sur une base vierge.

---

## Phase 3 — Configurer les données, secrets et intégrations

### 3.1 Base de données

- [ ] Exécuter `prisma migrate deploy` sur staging.
- [ ] Exécuter les seeds nécessaires.
- [ ] Importer le catalogue OMNES réel.
- [ ] Vérifier les relations pays, établissements, programmes et bourses.
- [ ] Contrôler manuellement au moins 20 établissements et 30 programmes.
- [ ] Vérifier les neuf pays du MVP.
- [ ] Vérifier les frais, dates limites, sources et dates de dernière validation.
- [ ] Répéter la procédure contrôlée en production.

### 3.2 Secrets de production

- [ ] Générer des secrets JWT forts et distincts.
- [ ] Configurer Supabase URL, clés et service-role.
- [ ] Configurer Groq.
- [ ] Configurer OneSignal.
- [ ] Configurer Resend.
- [ ] Configurer Firebase.
- [ ] Configurer le stockage S3 ou le volume persistant.
- [ ] Configurer ClamAV.
- [ ] Configurer les origines CORS exactes.
- [ ] Vérifier qu’aucun secret n’est présent dans Git ou dans un artefact client.

### 3.3 Parcours d’intégration

- [ ] Tester Google OAuth sur Android et iOS.
- [ ] Tester l’OTP email sur Android et iOS.
- [ ] Vérifier les URLs de redirection Supabase.
- [ ] Tester l’association OneSignal à l’utilisateur connecté.
- [ ] Envoyer une notification transactionnelle.
- [ ] Envoyer une campagne segmentée de test.
- [ ] Tester l’envoi d’email avec Resend.
- [ ] Tester Groq et son comportement de repli.
- [ ] Tester la suppression complète du compte et de l’identité Supabase.

### Critère de sortie

- Tous les parcours critiques utilisent les services réels sur staging.
- Aucun fallback de démonstration n’est utilisé silencieusement pour une fonction critique.

---

## Phase 4 — Produire les builds stores

### 4.1 Android

- [x] Supprimer le fallback automatique vers la clé debug pour une release.
- [x] Faire échouer CI si le keystore ou un mot de passe manque.
- [ ] Configurer Play App Signing.
- [ ] Produire un AAB signé avec la clé d’upload.
- [ ] Vérifier le certificat de signature.
- [ ] Générer l’AAB avec `KPB_APP_ENV=prod`.
- [x] Ajouter l’AAB signé comme artefact de release CI.
- [ ] Envoyer le build sur Google Play Internal Testing.

### 4.2 iOS

- [x] Configurer `aps-environment=production` pour Release.
- [ ] Configurer le certificat Apple Distribution.
- [ ] Configurer le provisioning profile.
- [ ] Produire une archive Xcode signée.
- [ ] Produire et envoyer l’IPA.
- [ ] Distribuer le build via TestFlight.
- [ ] Tester les notifications APNs depuis TestFlight.

### 4.3 Métadonnées stores

- [ ] Préparer les descriptions courtes et longues.
- [ ] Préparer les captures Android et iOS.
- [ ] Préparer l’icône, le visuel Play et les catégories.
- [ ] Publier la politique de confidentialité.
- [ ] Publier une page web de suppression de compte.
- [ ] Remplir Google Data Safety.
- [ ] Remplir les déclarations App Store Privacy.
- [ ] Confirmer l’âge minimum et la classification du contenu.

### Critère de sortie

- AAB accepté par Google Play.
- IPA accepté par App Store Connect/TestFlight.
- Aucun artefact n’est signé avec un certificat de développement.

---

## Phase 5 — QA fonctionnelle et performance

### 5.1 Matrice de test

Tester au minimum sur :

- [ ] Android entrée de gamme avec 2–3 Go de RAM.
- [ ] Android récent.
- [ ] iPhone physique.
- [ ] Wi-Fi stable.
- [ ] Connexion mobile lente.
- [ ] Mode hors ligne puis reconnexion.

### 5.2 Parcours bloquants

- [ ] Installation propre et premier démarrage.
- [ ] Google OAuth.
- [ ] OTP email.
- [ ] Onboarding complet.
- [ ] Orientation et recommandations.
- [ ] Consultation d’un établissement et d’un programme.
- [ ] Création d’un dossier.
- [ ] Upload et téléchargement d’un document.
- [ ] Conversation étudiant–conseiller.
- [ ] Synchronisation hors ligne puis reconnexion.
- [ ] Coach IA et quota.
- [ ] Ouverture WhatsApp.
- [ ] Push en foreground, background et app fermée.
- [ ] Export des données personnelles.
- [ ] Suppression du compte.
- [ ] Connexion et opérations principales dans l’admin.

### 5.3 Budget de taille accepté

La taille d’environ **50 MB est considérée acceptable** pour cette release.

Les mesures actuelles observées pendant l’audit sont :

| Artefact | Taille observée | Interprétation |
|---|---:|---|
| AAB envoyé à Google Play | ~100,9 MB | Contient plusieurs architectures et des métadonnées ; ce n’est pas la taille téléchargée par chaque utilisateur |
| APK arm64 séparé | ~52,2 MB | Proche du budget accepté de 50 MB |

Budget de validation retenu :

- **Taille livrée/installée Android cible :** environ 50 MB.
- **Tolérance release initiale :** jusqu’à 55 MB pour l’APK arm64, si la taille affichée par Play Console reste proche de 50 MB.
- **AAB upload :** accepté tant qu’il respecte les limites Google Play et que la taille de téléchargement calculée par Play est conforme.

Travaux de finition recommandés, non bloquants si le budget est respecté :

- [ ] Mesurer la taille réellement téléchargée dans Play Console.
- [ ] Compresser les images les plus lourdes en WebP/AVIF.
- [ ] Supprimer les fichiers images en doublon.
- [ ] Déplacer les contenus non indispensables vers le catalogue distant.
- [ ] Vérifier les dépendances Flutter inutilisées.

### 5.4 Performance

- [ ] Mesurer cinq démarrages à froid sur l’Android de référence.
- [ ] Mesurer la mémoire sur les écrans principaux.
- [ ] Mesurer les données consommées pendant une session typique.
- [ ] Vérifier le défilement des listes volumineuses.
- [ ] Vérifier le mode économie de données.
- [ ] Vérifier qu’aucune initialisation non critique ne bloque le premier écran.

### Critère de sortie

- Aucun défaut P0 ou P1 ouvert.
- Tous les parcours bloquants sont validés sur Android et iOS.
- La taille Android livrée est proche de 50 MB et ne dépasse pas la tolérance décidée.

---

## Phase 6 — Renforcer les tests et la CI

### Tests automatisés

- [ ] Ajouter un E2E mobile : connexion → onboarding → accueil → création de dossier.
- [ ] Ajouter un E2E document : upload → affichage → téléchargement → suppression.
- [ ] Ajouter un E2E hors ligne → reconnexion.
- [ ] Ajouter des tests admin pour la connexion, les dossiers, utilisateurs et rapports.
- [x] Ajouter des tests backend pour les téléchargements privés.
- [ ] Définir un seuil de couverture initial réaliste.

### CI

- [ ] Conserver Flutter format, analyse et tests.
- [ ] Conserver backend lint, tests et build.
- [ ] Conserver admin lint et build.
- [ ] Exécuter les migrations sur une base PostgreSQL vierge.
- [ ] Exécuter les seeds et les contrôles d’intégrité.
- [ ] Démarrer l’API et vérifier sa readiness.
- [x] Interdire toute signature Android debug sur un tag de release.
- [x] Produire un AAB signé pour les tags de release.
- [ ] Ajouter le contrôle des vulnérabilités avec une politique documentée.

### Critère de sortie

- Une régression des parcours critiques bloque automatiquement la release.
- Aucun build de production ne peut être généré silencieusement avec des identifiants de développement.

---

## Phase 7 — Bêta et lancement progressif

### Étape 1 — Bêta interne

- [ ] Équipe KPB.
- [ ] Conseillers.
- [ ] Comptes étudiants de test.
- [ ] Observation pendant au moins 24 heures.

### Étape 2 — Bêta fermée

- [ ] 20 à 50 étudiants réels.
- [ ] Plusieurs modèles Android.
- [ ] Au moins quelques utilisateurs iOS.
- [ ] Observation pendant 3 à 7 jours.

### Étape 3 — Production progressive

- [ ] Déploiement à 5 %.
- [ ] Passage à 20 % après 24–48 heures stables.
- [ ] Passage à 100 % après validation des indicateurs.

### Indicateurs de décision

- Utilisateurs sans crash ≥ 99,5 %.
- Erreurs API 5xx < 1 %.
- Connexions réussies ≥ 95 %.
- Créations de dossiers réussies ≥ 95 %.
- Aucun document accessible sans autorisation.
- Aucun incident de perte de données après synchronisation.
- Notifications et messages opérationnels.
- Sauvegardes quotidiennes réussies.
- Temps de réponse conseiller suivi dans l’admin.

### Critères de rollback

Suspendre le déploiement en cas de :

- authentification indisponible ;
- fuite ou accès incorrect à un document ;
- perte/corruption de données ;
- hausse importante des crashs ;
- API indisponible ou taux de 5xx élevé ;
- impossibilité de créer ou suivre un dossier.

---

## 4. Ordre d’exécution recommandé

1. Créer la branche de release depuis `main`.
2. Sécuriser les documents.
3. Corriger le comportement proxy/rate limiting.
4. Déployer DNS, HTTPS et staging.
5. Appliquer migrations, seeds et données réelles.
6. Configurer les secrets et intégrations.
7. Produire les builds signés Android/iOS.
8. Exécuter la QA sur appareils physiques.
9. Vérifier la taille réellement livrée par les stores.
10. Lancer la bêta interne puis fermée.
11. Déployer progressivement en production.

## 5. Gate finale de lancement

Le lancement public est autorisé uniquement si :

- [ ] Tous les éléments `P0` sont terminés.
- [ ] Les domaines de production répondent en HTTPS.
- [ ] La base de production est migrée et sauvegardée.
- [ ] Les documents sont privés et protégés contre les accès croisés.
- [ ] L’AAB est signé avec la clé d’upload officielle.
- [ ] L’IPA est signé avec le profil de distribution.
- [ ] OAuth, OTP, push et suppression de compte ont été testés sur appareils physiques.
- [ ] Aucun défaut P1 n’affecte un parcours critique.
- [ ] La taille Android livrée est proche du budget accepté de 50 MB.
- [ ] La bêta fermée ne révèle aucun incident bloquant.
- [ ] Le plan de rollback est connu de l’équipe.

## 6. Commandes de validation

### Flutter

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --dart-define=KPB_ENABLE_REMOTE_SYNC=false
flutter build appbundle --release --dart-define=KPB_APP_ENV=prod
flutter build apk --release --split-per-abi --dart-define=KPB_APP_ENV=prod
```

### Backend

```bash
cd backend
npm ci
npm run lint
npm test -- --runInBand
npm run build
npx prisma migrate deploy
```

### Administration

```bash
cd admin
npm ci
npm run lint
npm run build
npm audit --omit=dev
```

### Contrôles production

```bash
curl -fsS https://api.kpb-education.com/api/health/live
curl -fsS https://api.kpb-education.com/api/health/ready
```

---

**Résultat attendu :** une première release volontairement limitée au MVP, sécurisée, mesurable, réversible et adaptée à un lancement progressif.
