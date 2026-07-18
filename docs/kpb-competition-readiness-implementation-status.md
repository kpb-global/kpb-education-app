# KPB Competition Readiness — état d’implémentation

Dernière mise à jour : 18 juillet 2026

Document de suivi : l’architecture normative reste
`docs/kpb-competition-readiness-implementation-architecture.md`. Cette page
décrit le contenu réellement présent dans la branche de release et les gates
effectivement exécutés. La fonctionnalité reste désactivée par défaut jusqu’à
l’activation contrôlée en environnement de production.

## État de sécurité du rollout

Les flags sont désactivés par défaut :

- `KPB_COMPETITION_READINESS_ENABLED=false`
- `KPB_SUCCESS_LAB_ENABLED=false`
- `KPB_APPLICATION_ARTIFACTS_ENABLED=false`
- `KPB_STUDY_REVIEW_ENABLED=false`
- `KPB_AI_DIAGNOSTIC_ENABLED=false`
- `KPB_OUTCOME_EVIDENCE_ENABLED=false`
- `KPB_IMPACT_PUBLIC_STATS_ENABLED=false`
- `KPB_AI_DIAGNOSTIC_KILL_SWITCH=true`
- `KPB_AI_DIAGNOSTIC_MONTHLY_BUDGET_MICROS_USD=0`
- `KPB_SUCCESS_LAB_ROLLOUT_PERCENT=0`

En production, l’activation exige les secrets de signature, `KPB_BUILD_SHA`,
le stockage privé, ClamAV et les fournisseurs explicitement configurés. Le
backend NestJS/Prisma reste l’autorité métier ; Supabase sert uniquement à
l’authentification.

## Couverture du backlog

| Lots | État | Résultat concret |
| --- | --- | --- |
| CR-000 à CR-020 | terminé | fondations, consentement, workspace, artefacts, IA bornée, étude humaine, créneaux, admin, résultats vérifiés et Flutter Success Lab |
| CR-021 | terminé | Impact/Reports corrigés : aucune admission ou bourse n’est inférée de `Case.completed` |
| CR-022 | terminé | outbox durable, lease PostgreSQL, retry/backoff, dead-letter, projection analytique et réconciliation stockage |
| CR-023 | terminé | accords partenaires révisables et immuables, preuves, rôles, pays et scopes |
| CR-024 | terminé | pilotes, cohortes, enrolment consenti, mineurs, assignments et assessments minimisés |
| CR-025 | terminé | snapshots append-only, reporting par pilote et data room JSON expurgée |
| CR-026 | terminé | FR/EN, accessibilité, 200 % texte, réseau faible et gating Flutter fail-closed |
| CR-027 | terminé | export/suppression RGPD, rétention, purge stockage et idempotency records administratifs |
| CR-028 à CR-031 | terminé P0 | tests trois surfaces, concurrence, sécurité, claims, runbooks, rollback et privacy partenaires/pilotes |
| CR-032 | terminé P0 | audit de release, flags fail-closed, CI, migrations neuves et upgrade peuplé |

## Capacités livrées

### Étudiant Flutter

- Success Lab accessible seulement après entitlement serveur ;
- diagnostic IA borné, consenti, budgeté et relayé vers un conseiller KPB ;
- artefacts privés versionnés, demandes d’étude, créneaux, annulation et
  replanification ;
- déclarations séparées de soumission, admission et financement ;
- preuves privées, décisions versionnées et historique distinct ;
- cache local non sensible, retry idempotent et état réseau accessible ;
- interface FR/EN avec contrôle à 200 % de taille de texte ;
- Impact public caché lorsqu’il n’existe pas et erreur explicite lorsqu’il est
  indisponible — jamais de zéros fabriqués.

### Admin Next.js

- hub `/competition-readiness`, tri humain, créneaux, conversions et preuves
  privées à durée courte ;
- accords partenaires révisés par version avec preuves HTTPS et limites de
  capacité ;
- gestion des pilotes, cohortes, états et couverture multi-pays par accords
  actifs ;
- snapshots immuables, rapports par pilote et data room JSON sans clé de
  stockage ni manifest privé ;
- RBAC/country/resource scopes, confirmations, erreurs localisées et clés
  d’idempotence pour chaque mutation critique.

### Backend NestJS/Prisma

- migrations additives `competition_01` à `competition_09` ;
- snapshots, exports data room et résultats analytiques immuables au niveau
  PostgreSQL ;
- tableaux d’impact public issus uniquement des snapshots `isPublicSafe`, avec
  cellules de taille minimale `n ≥ 20` et consentement témoignage actif ;
- guardian authorization obligatoire et courante pour les mineurs ;
- export/suppression de compte couvrant workspace, résultat, pilote, cohortes,
  assessments, assignments et idempotency ;
- CORS HTTPS strict, headers `no-store`/CSP/nosniff pour les documents,
  WebSocket sans token en query-string et logs expurgés de PII ;
- validation production de l’environnement, build SHA, images taguées et
  migrations comme étape de release explicite.

## Gates exécutés — release candidate

- Backend : 87 suites réussies, 572 tests réussis, 2 suites PostgreSQL
  volontairement ignorées hors variable d’intégration ; Prisma format/validate/
  generate, TypeScript, build Nest et ESLint verts.
- PostgreSQL : 46 migrations appliquées depuis zéro sur une base temporaire ;
  statut à jour ; upgrade additif sur données peuplées vert ; export,
  suppression RGPD et rétention stockage verts.
- Admin : 7 fichiers de tests, 50 tests ; ESLint strict et build Next
  production verts.
- Flutter : analyse sans issue, suite globale verte et APK debug produit.
- Dépendances : audit npm production vert pour backend et admin.
- `git diff --check` doit être rejoué immédiatement avant le commit final.

## Conditions restantes avant activation réelle

Le code est prêt pour revue/merge une fois les derniers contrôles Git effectués.
L’activation externe reste conditionnée à :

1. secrets et variables de production contrôlés ;
2. test staging du stockage privé, ClamAV, OneSignal et suppression Supabase ;
3. rehearsal backup/rollback sur l’infrastructure cible ;
4. validation juridique des accords et notices, formation des conseillers ;
5. pilote limité, métriques J0/J30/J90 et revue humaine des claims publics.
