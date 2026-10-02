# Publication déléguée du catalogue « Études en France »

*Établi le 01/10/2026. Pour : le propriétaire du produit. Complète
`docs/runbook-ouverture-espace-reel.md` (précondition 4) et
`docs/eef-dossier-relecture-procedures.md`.*

## En trois phrases

À la demande du propriétaire, qui a parcouru le catalogue dans l'admin et ne veut pas publier
84 établissements et ~10 500 formations à la main, l'action **`eef-publish`** de `vps-ops` les
publie en une opération, **par le même service que l'écran admin** (même plan, même transaction
par établissement, même « tout ou rien »). Elle le fait après un contrôle que les pages-sources
répondent encore, et laisse **en attente** les formations dont la page a disparu.

**Publier rend le catalogue lisible par l'API publique, pas visible dans l'app.**
`GET /api/etudes-en-france/search` n'exige aucune session : dès la publication, n'importe qui
qui connaît l'adresse peut lire ces fiches. Aucune build ne les affiche tant que
`features.eefSpace` est faux (action `eef-space-on`, jamais lancée par cet outil).

## Ce qui est identique à l'écran admin, et ce qui ne l'est pas

| | Écran admin | `eef-publish` |
|---|---|---|
| Plan, transaction `RepeatableRead`, tout ou rien par établissement, total attendu | oui | **oui, même service** |
| Relecteur inscrit | l'administrateur de la **session** (prouvé) | un compte `admin` / `super_admin` **choisi par une valeur de workflow** (non prouvé par une session) |
| Qui peut déclencher | un administrateur connecté | quiconque peut lancer le workflow « VPS ops » — c'est déjà le droit de déployer le backend |
| Trace de qui a lancé | la session | `github.triggering_actor` dans la ligne d'audit (au « Re-run », celui qui relance) |

C'est donc un **affaiblissement réel** de la garantie « le relecteur est la personne qui a appuyé »,
compensé par : le tampon « *publication déléguée* », la ligne d'audit, la simulation obligatoire et le
total à ressaisir.

## Constat du 01/10/2026 (rapport versionné `source-check.json`)

| | Adresses | Formations |
|---|---:|---:|
| Pages d'établissement contrôlées | 1 559 | 2 150 |
| Répondent | 1 034 | — |
| **Mortes** (404/410 ou renvoi à l'accueil, constatés deux fois) | 341 | **473** — laissées en attente |
| Incertaines (403, 5xx, délai, certificat mal servi) | 184 | 264 — publiées |

Les 473 formations écartées sont **toutes des masters** issus du jeu « Trouver mon master » de
**2021** : leurs pages ont été retirées ou déplacées par les universités (63 établissements).
Reste donc **10 029 formations publiables** sur 10 502.

**Stabilité.** Deux passages complets à une heure d'écart ont donné 470 puis 473 formations
mortes, dont une trentaine changent d'un passage à l'autre (pages instables, ou renvois à
l'accueil détectés par la règle élargie entre-temps). Le second passage est celui versionné.

Les 8 352 autres formations (fiches Parcoursup 4 140, racine Mon Master 1 078, jeu de données du
ministère 3 134) ne sont pas contrôlées une à une : ce sont des portails qui répondent presque
toujours. Un échantillon de 380 fiches Parcoursup a trouvé **une** page générique en 200 (Sorbonne
« L1 - Droit »).

Répétition sur une copie complète de l'import (84 établissements, 10 502 formations) avec ce
rapport : **10 029 publiables, 0 refusée par le plan, 0 établissement refusé** ; écriture en 5 s ;
un second passage ne publie plus rien ; la recherche publique rend 10 029 résultats (50 à 490 ms).

## Ce qui est contrôlé avant d'écrire

| Contrôle | Où | Effet |
|---|---|---|
| Source HTTPS, procédure qualifiée, domaine d01–d12, formation de l'import rattachée à son établissement | plan de publication, recalculé **dans** la transaction | une formation qui échoue est refusée et nommée ; un établissement sans source n'écrit rien |
| La page-source **répond encore** | `npm run eef:check-sources` → `publication/data/source-check.json` | 404/410 ou renvoi à l'accueil constatés **deux fois** ⇒ formation laissée inactive. 403, 5xx, délai, certificat mal servi ⇒ « incertaine », **publiée** |
| Le rapport est **digne de décider** | `assertSourceCheckUsable` | refusé s'il est partiel, périmé (l'empreinte du catalogue ne correspond plus : formation ajoutée, retirée ou adresse changée), ou issu d'un sondage en panne (moins de 40 % de pages valides, plus de 35 % d'incertaines) |
| Le contrôle est récent | script de publication | plus de 14 jours : `--apply` refusé |
| Total saisi | `expected_programs` | l'écriture exige le « TOTAL publiable » de la simulation ; elle applique les listes **exactes** de la simulation (une formation devenue invalide ou déjà publiée entre-temps fait échouer son établissement) et le total publié est recontrôlé après coup |
| Isolation du catalogue général | étape « Prouver l'isolation » du workflow, `eef-provenance.postgres.spec.ts`, `db-info.sql` §12 | le workflow relève `/catalog/institutions` et `/catalog/programs` **avant**, les relit **après**, et fait échouer le job au moindre écart |

Ce que le contrôle des pages **ne dit pas** : il ne lit pas la page. Une page qui répond 200 en
disant « formation introuvable » passe.

## Ce que le tampon dit

Chaque ligne publiée porte `verifiedById` = le compte administrateur et `verifiedByName` =
« *Nom (publication déléguée)* » (« *Administrateur KPB (publication déléguée)* » si le compte n'a pas
de nom). **Ce tampon est public** : la recherche non authentifiée le recopie dans sa réponse, comme
pour une publication par l'écran admin. On n'y met donc ni l'e-mail ni le compte GitHub de
l'opérateur : celui-ci est dans la ligne `AdminAuditEvent` (`eef.publication.delegated`,
`changes.launchedBy`), écrite par établissement publié. Si cette trace ne peut pas être écrite, le
job sort en erreur (la publication, elle, est en base).

## Faire

1. **Simulation.** GitHub → Actions → « VPS ops » → `eef-publish`, `dry_run` **coché**. La sortie
   liste chaque établissement et finit par `TOTAL publiable : N formation(s)`.
   - `verifier_email` : l'e-mail de connexion du compte admin qui signe. Vide, l'outil prend
     l'unique `super_admin` actif, à défaut l'unique compte `admin` ; s'il y en a plusieurs il
     refuse de deviner et liste les comptes éligibles masqués (`a***@domaine`). La production
     compte, le 01/10/2026 (`db-info.sql` §12), **2 comptes `admin` et aucun `super_admin`** :
     renseigner l'e-mail.
   - `exclude_procedure` : laisser une famille hors de cette vague (`hors_eef`, `dap_jaune`,
     `parcoursup`). Voir « Les sept questions de procédure ».
2. **Essai sur un établissement** (recommandé) : même action avec `institution_id` = un
   `eef-univ-…`, `dry_run` décoché, `expected_programs` = le total annoncé pour lui seul.
3. **Application.** `dry_run` **décoché**, `expected_programs` = N. Si un établissement échoue
   (conflit d'écriture, base indisponible), sa transaction est annulée en entier, les autres sont
   publiés et le job sort en erreur : relancer une **nouvelle simulation**, puis ressaisir son
   total ; le second passage ne republie rien et n'écrase aucun tampon. Vérifier ensuite la dernière
   étape du job et `GET /api/etudes-en-france/search`.

## Retour arrière — ce qui est possible, et ce qui ne l'est pas

- **Retirer** un établissement (admin → Publication → « Retirer ») ou des formations : oui. Les
  tampons restent (« vérifié par X le jour Y » est l'historique), et les étudiants qui avaient
  enregistré une formation la perdent de leur liste (le plan le chiffre avant d'écrire).
- **Corriger une règle de procédure en masse après publication : oui, depuis le 02/10/2026,
  par `eef-reconcile`** (#305), qui réaligne procédure, sélectivité et exigences des lignes
  publiées ou en attente sur les règles du dépôt — simulation d'abord, total saisi, une
  transaction et une trace d'audit par établissement, sans toucher ni à la publication ni au
  tampon, et sans réécrire une ligne retouchée dans l'admin (`docs/ouverture-espace-eef.md`
  § 2.2). `eef:purge-pending`, lui, ne supprime toujours que des lignes **jamais publiées et
  jamais tamponnées**.

D'où l'ordre recommandé : l'espace reste fermé (`eefSpace` faux) jusqu'à ce que les sept questions
de procédure soient tranchées (fait le 02/10/2026) et leurs corrections appliquées en production
(`eef-reconcile`). Tant que l'espace est fermé, aucun étudiant ne voit le catalogue dans l'app,
mais l'API publique le sert.

## Les sept questions de procédure

L'outil ne les tranche pas, et la publication ne les supposait pas tranchées. Elles l'ont été le
02/10/2026 (`docs/eef-dossier-relecture-procedures.md`) ; les lignes publiées sont réalignées par
`eef-reconcile`. Si l'on préfère ne pas publier d'emblée
la famille la plus douteuse, `exclude_procedure` (workflow) écarte `hors_eef` (80 écoles
d'ingénieurs), `dap_jaune` (29) ou `parcoursup` (aucune ligne aujourd'hui) de la vague : elles
restent importées, inactives, et un nouveau passage les publiera plus tard.

## Refaire le contrôle des pages

```bash
cd backend
NODE_USE_ENV_PROXY=1 npm run eef:check-sources   # ~25 min, 1 559 adresses, 2 requêtes simultanées par site
git add src/modules/etudes-en-france/publication/data/source-check.json
```

Un essai (`--limit N`) exige `--out` et produit un rapport **partiel**, que la publication refuse.
Un sondage fait réseau coupé est refusé par le script lui-même (copie de diagnostic en
`*.rejected.json`). Régénérer le catalogue rend le rapport périmé : l'empreinte ne correspond plus
et `eef-publish` refuse jusqu'à un nouveau contrôle.
