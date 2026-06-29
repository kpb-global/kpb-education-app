# SOP — Vérification du catalogue KPB (le process derrière le badge « Vérifié »)

> **Statut : BROUILLON** (KPB-47). Les zones `[À COMPLÉTER PAR KPB]` doivent être
> renseignées par l'équipe (propriétaires nommés, sources internes) avant mise en service.
> Référentiel : épic **KPB-37** (rendre le signal de confiance réel, visible, frais).

## 1. Pourquoi cette procédure existe

Le récit produit de KPB — « on bat les agences parce qu'on **vérifie et date** chaque
fait » — n'est crédible que s'il y a un **process humain répétable** derrière le badge.
Backfiller les données une fois (KPB-46) ne fait que déplacer le problème : sans cadence
de re-vérification, un `lastVerifiedAt` vieillit et le badge ment.

L'app rend déjà la fraîcheur **visible et auto-dégradante** : `VerifiedBadge`
(`lib/app/core/ui/components/verified_badge.dart`) passe au **vert** quand la donnée est
fraîche et à l'**ambre** quand elle dépasse son seuil. Cette procédure est ce qui garde
le badge majoritairement vert — honnêtement.

**Une donnée sans `lastVerifiedAt` n'est jamais présentée comme vérifiée.** C'est la règle d'or.

## 2. Périmètre : quelles données, contre quelle source, à quelle fréquence

Quatre entités du catalogue portent `lastVerifiedAt` + `sourceUrl`
(`backend/prisma/schema.prisma` : `Country`, `Institution`, `Program`, `Scholarship`).

| Catégorie de donnée | Où (modèle · champs) | Source d'autorité (jamais un agrégateur/agence) | Cadence de re-vérif | Seuil app (badge → ambre) | Propriétaire |
|---|---|---|---|---|---|
| **Frais de scolarité / coût** | `Program.tuition*`, `Country` coût de vie | Page officielle de l'université / du programme | **6 mois** | `tuitionFreshness = 180 j` | `[À COMPLÉTER PAR KPB]` |
| **Deadlines** (candidature, bourse) | `Program`, `Scholarship` dates | Page officielle université / organisme de bourse | **mensuelle** | `deadlineFreshness = 31 j` | `[À COMPLÉTER PAR KPB]` |
| **Visa / procédures** | `Country.howItWorks`, étapes visa | Site de l'ambassade / consulat / service d'immigration | **3 mois** (proposé) | `[à câbler dans verified_badge.dart]` | `[À COMPLÉTER PAR KPB]` |
| **Établissement** (accréditation, programmes offerts) | `Institution`, `Program.campusOfferings` | Site officiel de l'établissement / autorité d'accréditation | **6 mois** | défaut `staleAfter` | `[À COMPLÉTER PAR KPB]` |
| **Pays** (vue d'ensemble, fonds requis) | `Country` | Source gouvernementale officielle | **6 mois** | défaut `staleAfter` | `[À COMPLÉTER PAR KPB]` |

> ⚠️ **Cohérence app ↔ process** : si une cadence change ici, mettre à jour le seuil
> correspondant dans `verified_badge.dart` (et inversement). Le « visa » n'a pas encore
> de seuil dédié dans le code → à ajouter si la cadence 3 mois est retenue (note pour le
> ticket code de KPB-47).

## 3. Rôles & responsabilités

| Rôle | Responsabilité | Qui |
|---|---|---|
| **Vérificateur** | Exécute le geste de vérification, met à jour les champs + `sourceUrl` | `[À COMPLÉTER PAR KPB]` |
| **Propriétaire de catégorie** | Garant de la fraîcheur d'une catégorie (cf. table §2), vide la file en retard | `[À COMPLÉTER PAR KPB]` |
| **Validateur / 4-yeux** (sensibles : frais, fonds requis, visa) | Contrôle une 2ᵉ paire d'yeux avant publication | `[À COMPLÉTER PAR KPB]` |
| **Responsable data catalogue** | Détenteur global de cette SOP, suit les KPIs (§9) | `[À COMPLÉTER PAR KPB]` |

Chaque catégorie **doit** avoir un propriétaire nommé (AC2 de KPB-47). Une catégorie sans
propriétaire = donnée qui pourrira sans que personne ne s'en aperçoive.

## 4. Le geste de vérification (pas-à-pas)

Pour chaque ligne à (re)vérifier, dans le **panel admin catalogue** :

1. **Ouvrir** la ligne et son `sourceUrl`.
2. **Comparer** chaque champ à la source **officielle** (université, ambassade,
   organisme de bourse, gouvernement). Jamais un comparateur, un blog, ni une agence.
3. **Trois cas** :
   - **Exact** → ré-enregistrer la ligne : l'admin **horodate automatiquement**
     `lastVerifiedAt = now` + le **vérificateur** (AC1). Rien d'autre à faire.
   - **Changé** → corriger le(s) champ(s) + mettre à jour `sourceUrl` si l'URL a bougé,
     puis enregistrer (re-stamp auto). Pour les champs sensibles (frais, fonds, visa) →
     passer au **validateur 4-yeux** avant publication.
   - **Source morte / introuvable** → **ne pas** re-stamper. Marquer « à investiguer »,
     chercher la nouvelle page officielle. Si la donnée n'est plus sourçable, la retirer
     plutôt que d'afficher un fait non vérifiable.
4. **Toujours** : `sourceUrl` pointe vers la page **officielle cliquable** (celle que
   l'étudiant verra via le badge — KPB-48).

## 5. Ce que l'outillage admin doit garantir (moitié « code » de KPB-47)

Cette SOP suppose les comportements suivants côté `admin-catalog` (à livrer dans le
ticket code, en cours côté admin-panel) :

- **AC1** — Éditer un champ scolarité / deadline / visa **horodate auto** `lastVerifiedAt`
  + l'identité du vérificateur. *Implique d'ajouter un champ `verifiedById`
  (référence `AdminUser`) aux 4 modèles* — il n'existe pas encore (seuls
  `alumniVerifiedById` sur le profil et `kycVerifiedAt` sur le conseiller existent).
- **AC3** — Une **file de re-vérification** : lister toutes les lignes où
  `now − lastVerifiedAt > seuil(catégorie)` (ou `lastVerifiedAt IS NULL`), triable par
  catégorie et par ancienneté. C'est l'écran de travail quotidien du vérificateur.
- **Lien badge** : `lastVerifiedAt` alimente directement `VerifiedBadge` (vert/ambre).
  Une ligne sans `lastVerifiedAt` ne montre **aucun** badge « vérifié ».

## 6. Cadence opérationnelle (le rythme)

| Rythme | Action |
|---|---|
| **Hebdomadaire** | Vider la file « deadlines » (seuil 31 j) — c'est la catégorie la plus volatile. |
| **Mensuel** | Échantillon « frais/coût » + « visa » ; traiter toute ligne ambre. |
| **Trimestriel** | Revue complète « établissements » + « pays ». |
| **Avant chaque pic** (rentrées, vagues de bourses CSC/HSK, salons) | Sprint de vérif ciblé sur les pays/programmes concernés. |

Objectif de service : **aucune ligne ambre visible par un étudiant** sur les catégories
critiques (frais, deadlines, visa) en régime normal.

## 7. Correction, signalement & retrait

- Un étudiant peut **signaler** une donnée fausse (lien avec le dispositif anti-fraude /
  report, KPB-53). Tout signalement ouvre une vérif **prioritaire**.
- **SLA de correction** proposé : `[À COMPLÉTER PAR KPB]` (ex. 48 h pour frais/visa/deadlines).
- Si un fait ne peut être resourcé → **retrait**, pas de devinette. Mieux vaut un champ
  vide qu'un champ faux portant un badge.

## 8. Traçabilité & audit

- Chaque (re)vérification conserve **qui** (`verifiedById`) et **quand** (`lastVerifiedAt`).
- Conserver l'historique des éditions (au minimum : ne jamais écraser silencieusement —
  l'horodatage + vérificateur suffisent pour un audit de premier niveau).
- Une revue d'audit `[trimestrielle]` échantillonne N lignes « vertes » et re-contrôle
  qu'elles correspondent toujours à leur source — pour détecter les re-stamps de complaisance.

## 9. Indicateurs (KPIs à suivre)

- **% de lignes fraîches** par catégorie (cible : `[À COMPLÉTER]` %).
- **Âge médian** de `lastVerifiedAt` par catégorie.
- **Taille de la file en retard** (lignes au-delà du seuil) — doit tendre vers 0.
- **Délai de correction** après signalement étudiant.
- **Taux de lignes sans `sourceUrl`** (doit être 0 sur les catégories critiques).

## 10. Définition de « Vérifié » (ce que le badge promet à l'étudiant)

> Une donnée **Vérifiée** est une donnée qu'un membre nommé de l'équipe KPB a confrontée,
> à une date connue et récente, à une **source officielle cliquable** — et que l'étudiant
> peut lui-même rouvrir. Le badge n'est pas un argument marketing : c'est une **promesse
> datée et sourcée**, qui se dégrade visiblement quand elle vieillit.

---

### Annexe A — Sources d'autorité par pays (9 pays MVP)
`[À COMPLÉTER PAR KPB : pour chaque pays, l'URL officielle visa/immigration + l'autorité
d'accréditation des universités. Ex. format ci-dessous.]`

| Pays | Visa / immigration (officiel) | Accréditation établissements |
|---|---|---|
| `[pays]` | `[url officielle]` | `[url officielle]` |

### Annexe B — Liens code
- Seuils de fraîcheur : `lib/app/core/ui/components/verified_badge.dart`
- Champs vérifiés : `backend/prisma/schema.prisma` (`Country`, `Institution`, `Program`, `Scholarship`)
- Outillage : `backend/src/modules/admin-catalog/admin-catalog.controller.ts`
- Badge + source cliquable côté étudiant : KPB-48 · décroissance temporelle : KPB-49
