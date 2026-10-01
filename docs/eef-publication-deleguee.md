# Publication déléguée du catalogue « Études en France »

*Établi le 01/10/2026. Pour : le propriétaire du produit. Complète
`docs/runbook-ouverture-espace-reel.md` (précondition 4) et
`docs/eef-dossier-relecture-procedures.md`.*

## En deux phrases

Le propriétaire a relu le catalogue dans l'admin et demandé de ne pas publier
84 établissements et ~10 500 formations à la main. L'action **`eef-publish`** de
`vps-ops` le fait **par le même service que l'écran admin** (même plan, même transaction
par établissement, même « tout ou rien »), après un contrôle que les pages-sources
répondent encore, et en laissant **en attente** les formations dont la page a disparu.

**Publier ne montre rien aux étudiants.** Tant que `features.eefSpace` est faux
(`eef-space-on`), aucune build ne lit ce catalogue.

## Constat du 01/10/2026 (rapport versionné `source-check.json`)

| | Adresses | Formations |
|---|---:|---:|
| Pages d'établissement contrôlées | 1 559 | 2 150 |
| Répondent | 1 031 | — |
| **Mortes** (404/410 ou renvoi à l'accueil, constatés deux fois) | 341 | **470** — laissées en attente |
| Incertaines (403, 5xx, délai, certificat mal servi) | 187 | 251 — publiées |

Les 470 formations écartées sont **toutes des masters** issus du jeu « Trouver mon master »
de **2021** (cinq ans) : leurs pages ont été retirées ou déplacées par les universités. Elles
touchent 64 établissements. Les 8 352 autres lignes (Parcoursup, Mon Master, jeu du
ministère) ne sont pas concernées par ce contrôle.

Répétition sur une copie complète de l'import (84 établissements, 10 502 formations),
avec le vrai rapport : **10 032 formations publiables, 0 refusée par le plan, 0
établissement refusé** ; écriture en 5 s ; la recherche publique rend alors 10 032
résultats (50 à 490 ms par requête) ; une formation écartée reste inactive et invisible.

## Ce qui est contrôlé avant d'écrire

| Contrôle | Où | Effet |
|---|---|---|
| Source HTTPS, procédure qualifiée, domaine du référentiel d01–d12, formation de l'import rattachée à son établissement | plan de publication (`eef-publication.plan.ts`), recalculé **dans** la transaction | une formation qui échoue est refusée et nommée ; un établissement sans source n'écrit rien |
| La page-source **répond encore** | `npm run eef:check-sources` → `publication/data/source-check.json` | 404/410 (ou redirection vers l'accueil) constatés **deux fois** ⇒ formation laissée inactive. 403, 5xx, délai, certificat mal servi ⇒ « incertaine », **publiée** |
| Le contrôle des pages est récent | script de publication | plus de 14 jours : `--apply` refusé |
| Total saisi | `expected_programs` | l'écriture exige le « TOTAL publiable » de la simulation ; autre nombre ⇒ rien n'est écrit |
| Isolation | `etudes-en-france.postgres.spec.ts`, `db-info.sql` §12, et l'étape « Prouver l'isolation » du workflow | `/catalog/institutions` et `/catalog/programs` ne bougent pas |

Ce que le contrôle des pages **ne dit pas** : il ne lit pas la page. Une page qui répond
200 en disant « formation introuvable » passe. Les fiches Parcoursup (4 140), le portail
Mon Master (1 078) et le jeu de données du ministère (3 134) ne sont pas contrôlées
une à une : ce sont des portails qui répondent toujours, et leur 200 ne prouverait rien
sur l'existence de la formation (elle vient du jeu de données officiel 2026 pour
Parcoursup).

## Ce que le tampon dit

Chaque ligne publiée porte `verifiedById` = le compte administrateur, et
`verifiedByName` = « *Nom (publication déléguée · lancée par <compte GitHub>)* ». Le badge
« Vérifié » dit qui a regardé ; ici personne n'a regardé les formations une à une, et le
tampon ne doit pas le laisser croire. Une ligne `AdminAuditEvent`
(`eef.publication.delegated`) est écrite par établissement publié.

## Faire

1. **Simulation.** GitHub → Actions → « VPS ops » → `eef-publish`, `dry_run` **coché**.
   La sortie liste chaque établissement et finit par `TOTAL publiable : N formation(s)`.
   `verifier_email` : l'e-mail de connexion du compte admin qui signe. Vide, l'outil prend
   l'unique `super_admin` actif, à défaut l'unique compte `admin` ; s'il y en a plusieurs il
   refuse de deviner et liste les comptes éligibles masqués (`a***@domaine`). La production
   compte aujourd'hui 2 comptes `admin` et aucun `super_admin` : renseigner l'e-mail.
2. **Essai sur un établissement** (facultatif, recommandé) : même action avec
   `institution_id` = un `eef-univ-…`, `dry_run` décoché, `expected_programs` = le total
   annoncé pour lui seul.
3. **Application.** `dry_run` **décoché**, `expected_programs` = N. Vérifier ensuite la
   dernière étape du job (totaux publics) et `GET /api/etudes-en-france/search`.
   Si un établissement échoue (conflit d'écriture, base indisponible), sa transaction est
   annulée en entier, les autres sont publiés et le job sort en erreur. Relancer une
   **nouvelle simulation**, puis ressaisir son total : le second passage ne republie rien et
   n'écrase aucun tampon.
4. **Retour arrière.** Admin → Publication → « Retirer » (par établissement), ou
   `unpublish` du service. Les tampons restent ; les étudiants qui avaient enregistré une
   formation la perdent de leur liste (le plan le chiffre avant d'écrire).

## Refaire le contrôle des pages

```bash
cd backend
NODE_USE_ENV_PROXY=1 npm run eef:check-sources   # ~25 min, 1 559 adresses, 2 requêtes simultanées par site
git add src/modules/etudes-en-france/publication/data/source-check.json
```

Le test `eef-source-check.spec.ts` refuse un rapport qui cite une formation absente du
catalogue ou dont l'adresse a changé : régénérer le catalogue oblige à refaire le contrôle.

## Ce que l'outil ne fait pas

Il ne tranche pas les **sept questions de procédure** de
`docs/eef-dossier-relecture-procedures.md` (Sciences Po en L1, L1 sélectives
et Parcoursup, BUT, PASS/L.AS, écoles d'ingénieurs « hors procédure », repère
d'admission). Elles restent celles d'une personne qui connaît Campus France. Écarter une
famille de la première vague est possible sans code : `--exclude-procedure hors_eef`
(script) puis retrait par l'admin.
