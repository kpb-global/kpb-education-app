# KPB Competition Readiness — apports réalisés de CR-000 à CR-020

Dernière mise à jour : 18 juillet 2026
Statut : implémenté et validé localement, derrière feature flags désactivés

## 1. Résumé exécutif

Les lots CR-000 à CR-020 ont transformé l’idée du **Scholarship Success Lab**
en une première plateforme opérationnelle sur les trois surfaces KPB :

- l’application étudiante Flutter ;
- le backend NestJS/Prisma ;
- l’administration Next.js.

L’étudiant peut désormais organiser une candidature à une bourse, préparer ses
documents, recevoir un diagnostic IA volontairement limité, demander une étude
humaine de son dossier, réserver un échange avec un conseiller KPB, déclarer
une soumission et renseigner séparément une admission ou un financement.

L’équipe KPB dispose parallèlement d’une file d’administration pour traiter les
demandes, proposer des créneaux, consulter uniquement les documents consentis,
convertir une demande vers un dossier d’accompagnement et vérifier les preuves
de résultats sans inventer une décision à la place de l’établissement.

Cette tranche est une **fondation P0 robuste**. Elle ne correspond pas encore au
projet Competition Readiness complet : les lots CR-021 à CR-032 restent à
réaliser pour l’impact, les partenaires, les pilotes, la privacy, les E2E et le
rollout de production.

## 2. Apports fonctionnels par lot

| Lots | Apports réalisés |
| --- | --- |
| CR-000 à CR-004 | Contrats communs, workspaces de candidature, progression, consentements, idempotence, audit et outbox transactionnelle |
| CR-005 | Documents privés versionnés, upload contrôlé, validation, scan antivirus, accès sécurisé et suppression logique |
| CR-006 à CR-007 | Modèles, codecs, repository, cache non sensible, outbox Flutter, liste, détail et navigation Success Lab |
| CR-008 à CR-010 | Diagnostic IA borné, quotas et budget, ledger de coûts, sortie structurée, fallback déterministe et cas d’évaluation |
| CR-011 | Consentement lié à la version et au hash exacts de la notice, diagnostic unique et orientation vers un conseiller |
| CR-012 | Demande d’étude humaine, sélection explicite des versions partagées et consentement conseiller |
| CR-013 | Disponibilités, offres de créneaux expirables, réoffre et réservation transactionnelle sans surbooking |
| CR-014 | Hub admin, file des demandes, détail, SLA, viewer privé et contrôle par rôle/scope |
| CR-015 | Reprise d’une demande, compléments sous verrou optimiste et réservation Flutter confirmée par le serveur |
| CR-016 | Conversion humaine vers un `Case`, sans achat, paiement ou facturation automatique |
| CR-017 à CR-018 | Soumission, admission et financement séparés, versionnés, consentis et accompagnés de preuves privées |
| CR-019 | File admin de résultats, détail expurgé, accès court aux preuves et transitions de vérification auditées |
| CR-020 | Déclaration Flutter, décision courante, historique et complément uniquement lorsque le serveur le permet |

## 3. Apports côté étudiant Flutter

### 3.1 Espace Success Lab

- Entrée depuis le volet bourses.
- Liste des workspaces de candidature.
- Écran de détail avec progression par étapes.
- Navigation dédiée et deep-links normalisés.
- Affichage français et anglais avec parité des clés.
- Composants utilisables à 200 % de taille de texte.

### 3.2 Préparation de candidature

- Création d’un workspace associé à une bourse.
- Suivi des étapes de préparation.
- Cache local limité aux données non sensibles.
- Outbox hors ligne uniquement pour les opérations autorisées et non sensibles.
- Documents PDF, JPEG et PNG versionnés et stockés de manière privée.
- Suppression volontaire d’une version lorsque les règles métier le permettent.
- Blocage de la suppression lorsqu’une version est encore partagée dans une
  étude ouverte.

### 3.3 Diagnostic IA à coût maîtrisé

- Une seule amélioration IA au lieu d’un accompagnement conversationnel sans
  limite.
- Consentement explicite avant utilisation.
- Budget et quotas contrôlés par le backend.
- Réponse structurée validée avant affichage.
- Fallback déterministe si le fournisseur IA échoue ou renvoie une réponse
  invalide.
- Invitation à planifier un échange avec un conseiller KPB pour poursuivre
  l’accompagnement humain.

### 3.4 Étude humaine et rendez-vous

- Choix explicite des documents à partager avec KPB.
- Soumission d’une demande d’étude.
- Reprise de la demande active après fermeture ou redémarrage de l’application.
- Ajout de compléments sans retirer silencieusement les versions déjà partagées.
- Affichage des créneaux encore réellement disponibles.
- Réservation avec clés d’idempotence conservées lors d’un retry identique.
- Confirmation uniquement après réponse positive du serveur.
- Affichage distinct du fuseau de l’étudiant et du fuseau source du créneau.

### 3.5 Résultats de candidature

- Déclaration d’une candidature soumise.
- Admission et financement enregistrés comme deux décisions indépendantes.
- Conservation de la décision courante et des versions historiques.
- Consentement `outcome_evidence` dédié aux preuves de résultat.
- Upload privé et scan obligatoire avant utilisation d’une preuve.
- Références de candidature non conservées dans le cache ou l’outbox.
- Ajout d’un complément uniquement lorsque la décision courante est en
  `needs_information`.
- Mutations sensibles refusées hors ligne au lieu d’être mises en attente de
  manière risquée.

## 4. Apports côté administration Next.js

### 4.1 Hub Competition Readiness

- Nouvelle route `/competition-readiness`.
- Onglets pour les demandes, les résultats/preuves et les opérations IA.
- Interface adaptée aux capacités visibles, tout en laissant le backend comme
  autorité finale.
- États explicites pour accès refusé, endpoint indisponible, chargement et vide.

### 4.2 Traitement des demandes

- File paginée avec filtres serveur.
- SLA configurable, fixé à 48 heures par défaut.
- Détail expurgé selon le rôle, le scope pays et l’affectation.
- Affectation à un conseiller actif autorisé pour la demande.
- Transitions de triage et demande de compléments.
- Création et annulation de disponibilités.
- Proposition de un à trois créneaux avec date d’expiration.
- Conversion idempotente vers un dossier d’accompagnement après décision
  humaine.
- Aucun achat ni paiement déclenché automatiquement par cette conversion.

### 4.3 Vérification des résultats

- File de soumissions, admissions et financements avec filtres serveur.
- Affichage de l’étudiant, de la bourse, du type et du statut de vérification.
- Détail sans clé de stockage ni empreinte SHA du document.
- Preuve principale et preuves complémentaires distinguées.
- Accès temporaire `no-store` uniquement aux preuves propres et encore
  consenties.
- Décisions remplacées visibles en lecture seule pour conserver l’historique.
- Transitions auditables vers `pending`, `verified`, `needs_information` et
  `rejected`.
- Réouverture explicite d’un résultat déjà vérifié ou rejeté.
- Gestion des conflits de version avec rechargement de la vérité serveur.
- Séparation des responsabilités pour empêcher l’auteur ou un acteur non
  indépendant de valider sa propre preuve.

### 4.4 Supervision IA

- Vue agrégée des tentatives, erreurs, tokens et coûts.
- Lecture du budget, des montants réservés et dépensés.
- Aucun prompt brut ou identifiant fournisseur sensible exposé dans l’interface.

## 5. Apports backend NestJS/Prisma

### 5.1 Nouveau domaine métier

- Module `competition-readiness` isolé par sous-domaines : workspaces,
  artefacts, diagnostics, études, disponibilités, résultats et administration.
- Contrats d’erreur stables pour les clients Flutter et Next.js.
- Contrôle d’accès par ownership étudiant, rôle interne, grant actif, scope pays
  et affectation conseiller.
- Feature flags vérifiés côté serveur ; l’interface ne peut pas forcer
  l’activation d’une fonctionnalité.

### 5.2 Cohérence et concurrence

- Verrous optimistes `version`, `lockVersion` et `expectedVersion`.
- Idempotency records pour rejouer sans doublon une création après timeout.
- Compare-and-swap pour les réservations et les changements sensibles.
- Contrainte PostgreSQL empêchant le chevauchement des disponibilités.
- Capacité de créneau réclamée transactionnellement pour éviter le surbooking.
- Un seul rendez-vous actif par demande.
- Audit et événements outbox enregistrés dans la même transaction métier.

### 5.3 Documents et confidentialité

- Stockage privé des documents de candidature et preuves de résultats.
- Quarantaine, contrôle du type, de la taille et du hash, puis scan antivirus.
- Accès courts, finalisés et audités avec en-têtes `no-store`.
- Consentements versionnés et révocables.
- Références de candidature protégées par HMAC.
- Clés de stockage et empreintes privées absentes des réponses destinées aux
  interfaces.

### 5.4 Vérité des résultats

- `ApplicationSubmission`, `ApplicationDecisionRecord` et
  `FundingDecisionRecord` sont des événements distincts.
- Admission et financement sont historisés séparément.
- Les preuves sont reliées explicitement au résultat concerné.
- Une décision d’établissement n’est jamais inférée depuis `Case.completed`.
- L’établissement reste l’autorité de la décision ; KPB vérifie seulement la
  preuve déclarée.

## 6. Base de données et migrations

Sept migrations additives ont été ajoutées :

1. `competition_01_foundations` ;
2. `competition_02_workspace` ;
3. `competition_03_artifacts_reviews` ;
4. `competition_04_ai_diagnostic_ledger` ;
5. `competition_05_admin_review_ops` ;
6. `competition_06_review_scheduling` ;
7. `competition_07_verified_outcomes`.

L’approche reste additive : elle conserve les modèles et contrats déjà utilisés
par KPB au lieu de remplacer le schéma existant.

## 7. Sécurité et gouvernance intégrées

- Feature flags désactivés par défaut.
- Kill-switch IA actif et budget initial à zéro.
- Consentement explicite et lié à une notice exacte.
- Principe du moindre privilège côté étudiant et administration.
- Projection expurgée selon le rôle et le scope.
- Idempotence, verrou optimiste et audit des mutations sensibles.
- Documents privés, scannés et servis avec accès temporaire.
- Refus fermé des opérations sensibles en mode hors ligne.
- Séparation entre assistance KPB et décision de l’établissement.
- Séparation entre étude de dossier et vente d’un accompagnement payant.

## 8. Feature flags actuels

Les fonctionnalités sont implémentées mais non activées en production :

```dotenv
KPB_COMPETITION_READINESS_ENABLED=false
KPB_SUCCESS_LAB_ENABLED=false
KPB_APPLICATION_ARTIFACTS_ENABLED=false
KPB_STUDY_REVIEW_ENABLED=false
KPB_AI_DIAGNOSTIC_ENABLED=false
KPB_OUTCOME_EVIDENCE_ENABLED=false
KPB_AI_DIAGNOSTIC_KILL_SWITCH=true
KPB_AI_DIAGNOSTIC_MONTHLY_BUDGET_MICROS_USD=0
KPB_SUCCESS_LAB_ROLLOUT_PERCENT=0
```

## 9. Validations exécutées

| Surface | Résultat |
| --- | --- |
| Backend | 74 suites et 478 tests réussis ; build NestJS vert ; Prisma format/validate/generate verts ; lint sans erreur, avec trois warnings historiques hors lot |
| Admin | 6 fichiers et 41 tests réussis ; ESLint strict vert ; build Next.js production vert ; audit npm production à 0 vulnérabilité connue |
| Flutter | `flutter analyze --no-pub` sans erreur ; 406 tests réussis, y compris les écrans Success Lab à 200 % de taille de texte |
| PostgreSQL | 44 migrations appliquées depuis zéro sur base temporaire ; statut à jour ; drift nul ; invariants Outcomes verts |
| Worktree | `git diff --check` vert |

Une course réelle sur un créneau de capacité un a également produit le résultat
attendu : un gagnant, un perdant et un compteur final `1/1`.

## 10. Principaux points d’entrée

### Documentation

- `docs/kpb-competition-readiness-implementation-architecture.md`
- `docs/kpb-competition-readiness-implementation-status.md`

### Backend

- `backend/src/modules/competition-readiness/competition-readiness.module.ts`
- `backend/src/modules/competition-readiness/workspaces/`
- `backend/src/modules/competition-readiness/artifacts/`
- `backend/src/modules/competition-readiness/diagnostics/`
- `backend/src/modules/competition-readiness/reviews/`
- `backend/src/modules/competition-readiness/outcomes/`
- `backend/src/modules/competition-readiness/admin/`
- `backend/prisma/migrations/20260717210000_competition_07_verified_outcomes/`
- `backend/scripts/verify-outcomes-sql.sql`

### Administration

- `admin/app/competition-readiness/page.tsx`
- `admin/components/competition-readiness/readiness-hub.tsx`
- `admin/components/competition-readiness/review-request-queue.tsx`
- `admin/components/competition-readiness/outcome-verification-panel.tsx`
- `admin/components/competition-readiness/outcome-detail.tsx`
- `admin/lib/competition-readiness-api.ts`

### Flutter

- `lib/app/core/models/success_lab.dart`
- `lib/app/core/data/success_lab_api_codec.dart`
- `lib/app/core/repositories/success_lab_repository.dart`
- `lib/app/core/controllers/success_lab_controller.dart`
- `lib/app/core/controllers/success_lab_diagnostic_controller.dart`
- `lib/app/core/controllers/success_lab_study_review_controller.dart`
- `lib/app/core/controllers/success_lab_schedule_controller.dart`
- `lib/app/core/controllers/success_lab_submission_controller.dart`
- `lib/app/core/controllers/success_lab_outcome_controller.dart`
- `lib/app/features/success_lab/`

## 11. Impact produit attendu

- Donner à l’étudiant un parcours clair entre découverte d’une bourse et suivi
  du résultat.
- Réduire les candidatures incomplètes grâce aux étapes, documents et revues.
- Maîtriser la facture IA en limitant son rôle à une amélioration ciblée.
- Transformer les besoins complexes en échanges qualifiés avec un conseiller.
- Offrir à KPB une preuve auditée de l’accompagnement et des résultats obtenus.
- Produire plus tard des métriques de concours crédibles sans confondre activité
  commerciale et réussite académique.

## 12. Ce qui reste à réaliser

### CR-021 à CR-025

- métriques et modèles d’impact ;
- accords et droits partenaires ;
- pilotes, cohortes et consentements associés ;
- snapshots de résultats et reporting agrégé.

### CR-026 à CR-032

- privacy export, suppression et rétention ;
- E2E sur les trois surfaces ;
- audit IDOR et hardening des autorisations ;
- tests faible réseau et reprise après incident ;
- runbooks, rehearsal de rollback et rollout pilote.

Restent également l’annulation/replanification contrôlée des rendez-vous, un
worker durable de réconciliation stockage/outbox, la validation des migrations
sur un clone peuplé anonymisé et le suivi Swift Package Manager des plugins iOS
signalés par Flutter.

## 13. Statut Git et livraison

Au moment de cette synthèse :

- les changements Competition Readiness sont présents dans le worktree local ;
- ils ne sont pas encore commités, poussés ou déployés ;
- ils ne doivent pas être considérés comme inclus dans la PR du thème Lot 9 ;
- les feature flags restent désactivés.

La prochaine étape de livraison consiste à isoler le périmètre, créer un commit
propre sur une branche dédiée, pousser cette branche et ouvrir une PR vers
`main`, puis laisser la CI et la revue valider l’intégration avant tout merge.
