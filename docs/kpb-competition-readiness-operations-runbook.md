# KPB Competition Readiness — runbook d'exploitation

Dernière mise à jour : 18 juillet 2026

Ce document couvre l'activation, la surveillance, les incidents et le rollback
du Success Lab. Il complète `DEPLOYMENT.md`. Il ne donne jamais l'autorisation
d'activer une fonctionnalité : le responsable de livraison et le responsable
opérationnel doivent signer la checklist correspondant à la phase.

## 1. Principes non négociables

- déployer d'abord avec tous les flags désactivés ;
- utiliser un `KPB_IMAGE_TAG` immuable correspondant au SHA Git testé ;
- sauvegarder PostgreSQL hors du VPS avant `prisma migrate deploy` ;
- ne jamais restaurer une base pour un simple rollback applicatif : les
  migrations Competition Readiness sont additives ;
- garder `KPB_AI_DIAGNOSTIC_KILL_SWITCH=true` tant que le budget, les
  consentements et les évaluations ne sont pas validés ;
- ne publier aucun chiffre d'impact qui ne pointe pas vers un snapshot gelé et
  des outcomes vérifiés ;
- ne recruter aucun participant sans accord actif, cohorte active et reçu de
  consentement adapté ;
- ne copier dans un ticket ou un canal d'incident ni document étudiant, ni URL
  signée, ni token, ni clé de stockage.

## 2. Rôles de garde

| Rôle | Responsabilité |
| --- | --- |
| Release owner | SHA, sauvegarde, migration, déploiement et rollback |
| Backend owner | santé API/DB, outbox, stockage, antivirus, budget IA |
| Operations owner | capacité conseillers, SLA, offres et rendez-vous |
| Safeguarding/privacy owner | consentements, mineurs, accès aux preuves, suppression |
| Impact owner | définitions KPI, cohortes, snapshots, seuil de petites cellules |
| Partnerships owner | validité et portée des accords actifs |

Une personne peut cumuler plusieurs rôles, mais l'activation des statistiques
publiques et la vérification d'un outcome exigent une seconde revue humaine.

## 3. Préflight avant chaque déploiement

Dans le SHA exact qui sera livré :

```bash
git status --short
git diff --check
docker compose --env-file .env.example config --quiet

cd backend
npm ci
npx prisma generate
npx prisma validate
npm run lint
npm test -- --runInBand
npm run build

cd ../admin
npm ci
npm run lint
npm run test:run
npm run build

cd ..
flutter pub get
flutter analyze
flutter test --exclude-tags=golden --dart-define=KPB_ENABLE_REMOTE_SYNC=false
flutter build apk --debug --dart-define=KPB_APP_ENV=prod
```

Sur une base PostgreSQL éphémère, appliquer toutes les migrations depuis zéro,
exécuter l'intégration privacy, puis vérifier `prisma migrate status`. Avant le
premier pilote, répéter l'opération sur un clone **anonymisé et peuplé** de la
production. Le clone ne doit contenir ni secret, ni document privé réel.

Vérifier aussi :

- `.env` réel absent de Git et permissions restreintes ;
- secrets Competition Readiness distincts et d'au moins 32 octets ;
- Supabase service role présent pour la suppression complète d'un compte ;
- ClamAV et stockage privés accessibles ;
- sauvegarde PostgreSQL restaurée avec succès dans un environnement jetable ;
- capacité conseiller couvrant la cohorte ;
- dashboard/alertes outbox, erreurs, budget et SLA accessibles à la garde.

## 4. Déploiement dark

La configuration initiale obligatoire est :

```env
KPB_COMPETITION_READINESS_ENABLED=false
KPB_SUCCESS_LAB_ENABLED=false
KPB_APPLICATION_ARTIFACTS_ENABLED=false
KPB_STUDY_REVIEW_ENABLED=false
KPB_AI_DIAGNOSTIC_ENABLED=false
KPB_AI_DIAGNOSTIC_KILL_SWITCH=true
KPB_AI_DIAGNOSTIC_MONTHLY_BUDGET_MICROS_USD=0
KPB_OUTCOME_EVIDENCE_ENABLED=false
KPB_IMPACT_PUBLIC_STATS_ENABLED=false
KPB_SUCCESS_LAB_ROLLOUT_PERCENT=0
```

Suivre ensuite `DEPLOYMENT.md` : construire sans remplacer les conteneurs,
sauvegarder, lancer une seule fois `prisma migrate deploy`, remplacer API/admin,
puis vérifier :

```bash
curl -fsS https://api.kpbeducation.cloud/api/health/live
curl -fsS https://api.kpbeducation.cloud/api/health/ready
curl -fsS https://api.kpbeducation.cloud/api/config/app
```

Le dernier JSON doit annoncer toutes les capacités Competition Readiness à
`false`. Une route étudiante ne doit pas apparaître dans l'app tant que la
décision authentifiée `/competition-readiness/access` ne l'autorise pas.

## 5. Activation progressive

Ne changer qu'une étape à la fois et conserver une fenêtre d'observation.

1. **Admin interne** : activer le parent global, garder Success Lab public et
   impact public désactivés. Vérifier RBAC et audit.
2. **Employés/testeurs** : activer Success Lab pour les pays autorisés avec un
   pourcentage stable très faible et une allowlist opérationnelle.
3. **Artefacts/étude** : activer après test réel stockage + ClamAV + accès signé
   court + suppression physique.
4. **IA** : fixer un budget non nul borné, conserver le kill switch le temps du
   smoke test, puis l'enlever. Vérifier qu'une réponse fournit exactement une
   amélioration et invite au conseiller.
5. **Outcomes** : activer seulement après consentements, revue des preuves et
   processus de séparation des responsabilités.
6. **Pilote** : recruter uniquement via accord et cohorte actifs. Augmenter le
   pourcentage par paliers documentés.
7. **Impact public** : dernière étape, après audit des snapshots et du seuil
   minimal de cellule.

Après chaque palier, contrôler pendant au moins une fenêtre opérationnelle :
erreurs inattendues, backlog/dead letters outbox, stockage/scan, coût IA,
offres/rendez-vous, retraits de consentement, plaintes confidentialité et taux
de synchronisation mobile.

## 6. Seuils d'arrêt

Rollback ou kill switch immédiat si l'un des événements suivants survient :

- accès inter-utilisateur, inter-conseiller ou preuve non consentie ;
- document servi publiquement, token ou secret présent dans logs/URL ;
- mineur admis dans un traitement exigeant un tuteur sans autorisation valide ;
- budget IA dépassé, double débit ou réponse non bornée ;
- admission/financement public compté sans statut `verified` ;
- migration ou readiness DB en échec ;
- corruption, perte de données ou suppression physique non réconciliable ;
- taux d'erreur sans fallback IA ≥ 1 % sur la fenêtre pilote ;
- synchronisation finalement appliquée < 98 % ;
- événement critique complet < 98 % ;
- incident critique privacy/safeguarding non contenu.

Une dégradation de fournisseur sans fuite peut justifier le kill switch de la
seule capacité touchée plutôt qu'un rollback de toute l'application.

## 7. Rollback applicatif

1. Annoncer l'incident et geler toute nouvelle activation.
2. Positionner tous les flags Competition Readiness à `false`, le rollout à
   zéro, le budget IA à zéro et le kill switch IA à `true`.
3. Redémarrer uniquement l'API avec cette configuration et vérifier
   `/api/config/app` ainsi qu'une route authentifiée d'accès.
4. Si le code doit être retiré, remettre `KPB_IMAGE_TAG` au SHA précédent et
   exécuter `docker compose up -d --no-deps api admin`.
5. Ne pas rétrograder les migrations additives. Restaurer la base uniquement
   pour corruption avérée, après capture des données post-déploiement et accord
   explicite du responsable DB.
6. Vérifier l'absence de nouveaux diagnostics/uploads/outcomes et laisser le
   worker outbox finir les purges déjà engagées.
7. Documenter heure, SHA, flags, métriques, cause, portée et décision de reprise.

### Rehearsal requis avant alpha

Effectuer ce scénario sur staging : activation à 1 %, création d'un workspace
synthétique, upload d'un fichier inoffensif, simulation d'indisponibilité IA,
activation du kill switch, flags à zéro, retour à l'image précédente, contrôle
DB et purge stockage. Archiver les sorties horodatées et les deux SHA. Un test
unitaire de flags n'est pas un remplacement de ce rehearsal opérationnel.

## 8. Incidents ciblés

### IA indisponible ou budget anormal

Activer immédiatement `KPB_AI_DIAGNOSTIC_KILL_SWITCH=true`. Confirmer que le
fallback explicite s'affiche, qu'aucun second droit n'est consommé et que les
réservations de budget expirées sont réconciliées. Ne journaliser ni prompt ni
contenu étudiant. Réactiver seulement après eval ciblée et rapprochement coût à
±5 %.

### Stockage ou antivirus indisponible

Désactiver les artefacts et les preuves outcome. Les scans sont fail-closed :
aucun fichier non scanné ne devient courant ou téléchargeable. Contrôler le
backlog outbox, les dead letters et les versions soft-deleted. Après retour,
relancer une réconciliation bornée et confirmer l'absence de l'objet avant de
clôturer. Un objet hard-deleted dont la ligne DB a disparu exige l'inventaire
du bucket ; le reconciler conservateur ne peut pas le redécouvrir seul.

### Notification en panne

Ne pas considérer l'acceptation fournisseur comme une livraison appareil.
Conserver la notification in-app comme source de vérité, identifier les
dead-letter/retries et prévenir l'équipe opérations pour les échéances
critiques. Ne pas envoyer manuellement une liste contenant des données privées.

### Retrait de consentement ou demande de suppression

Bloquer immédiatement les traitements futurs et les liens courts. Exécuter
l'export si demandé avant suppression, puis la purge applicative, stockage et
identité Supabase. Vérifier les ledgers retenus pseudonymisés, sans contenu ni
identifiant fournisseur. Conserver uniquement l'audit minimal légalement
validé. Escalader si `SUPABASE_SERVICE_ROLE_KEY` manque : la suppression du
profil applicatif seule ne supprime pas l'identité de connexion.

### Incident mineur/safeguarding

Retirer le participant de la cohorte, bloquer le traitement concerné et notifier
le responsable safeguarding. Préserver l'audit minimal sans diffuser les
documents. Vérifier séparément assentiment du mineur, autorisation du tuteur,
expiration et politique pays. Ne reprendre qu'après décision humaine tracée.

### Fuite de lien, token ou preuve

Révoquer/faire expirer le lien, tourner le secret affecté si nécessaire,
désactiver la capacité, préserver les logs expurgés et lancer l'analyse
d'exposition. Rechercher les accès par `requestId`/ressource, pas en recopiant
le token. Suivre le processus légal de notification applicable.

### Suspicion de faux document

Ne jamais supprimer silencieusement la déclaration. Passer la vérification au
statut nécessitant une revue, conserver la chaîne d'audit et séparer le
déclarant du vérificateur. Seul l'établissement émet la décision ; KPB vérifie
la preuve, il ne fabrique pas une admission.

## 9. Contrôles quotidiens du pilote

- santé live/ready et taux de réponses attendues ;
- événements outbox pending/processing/dead-letter et âge du plus ancien ;
- erreurs de scan, objets en quarantaine et purges en attente ;
- budget IA réservé/consommé/remboursé, coût et fallback ;
- demandes au-delà du SLA, capacité de créneaux et annulations ;
- consentements expirés/révoqués et cohortes retirées ;
- outcomes `self_reported`, `needs_information`, `rejected`, `verified` séparés ;
- snapshots en retard et cellules sous le seuil public ;
- accords expirant avant la fin du recrutement.

## 10. Preuve de livraison

Pour chaque release, archiver sans données personnelles : SHA et tag, logs CI,
résultat des migrations vierge + clone anonymisé, résultat privacy, version de
la checklist, opérateurs, horaires, configuration de flags, capture des sondes,
rehearsal rollback, incidents et décision go/no-go.

Le statut « logiciel vérifié » ne signifie pas « pilote terrain autorisé ».
Restent externes au code : secrets réels, clone anonymisé, restauration testée,
accords signés, capacité conseillers, consentements locaux, appareils/réseaux
réels et observation des métriques pendant la durée convenue.

Toute communication concours ou publique passe ensuite par
`docs/kpb-competition-readiness-claim-evidence-matrix.md`.
