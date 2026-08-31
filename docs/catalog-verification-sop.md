# Catalogue Verification SOP

KPB-47 turns the verification badge into an operational promise: every sensitive catalogue row must carry a recent source, a timestamp, and the admin who checked it.

## Cadence And Ownership

| Category | Rows | Cadence | Owner |
| --- | --- | --- | --- |
| Pays: visa, couts et difficulte admission | `Country` | 30 days | Amina KPB |
| Etablissements: frais, niveaux et exigences | `Institution` | 180 days | Fatou Admin |
| Formations: frais, duree, langue et prerequis | `Program` | 180 days | Fatou Admin |
| Bourses: deadlines, financement et eligibilite | `Scholarship` | 30 days | Amina KPB |

## Workflow

1. Open the admin verification queue at `/verification`.
2. Review rows due for re-check, starting with missing source links and never-verified rows.
3. Confirm the row against an official source.
4. Save the verification. The admin API records `lastVerifiedAt`, `verifiedById`, `verifiedByName`, and `sourceUrl`.
5. If a source is unavailable, leave the row inactive or update the public copy so it does not overpromise.

## Source Standard

Use official school, government, scholarship, Campus France, embassy, or partner pages. Avoid aggregator pages unless no official source exists and the row is explicitly marked for follow-up.

> **Propriétaires à nommer.** « Amina KPB » et « Fatou Admin » ci-dessus sont des
> personnages de jeux de test, pas des personnes. Tant qu'une personne réelle
> n'est pas nommée pour chaque cadence, la file de vérification n'a pas de
> propriétaire et le badge « Vérifié » reste vert sans que personne ne soit tenu
> de le rouvrir.

## Publier le catalogue vérifié en production

Le catalogue vérifié vit dans le dépôt (`backend/src/modules/scholarships-index/data/`).
Le déployer ne le publie pas : **le code et les données sont deux chemins
distincts**, et c'est pour cela que 34 fiches vérifiées ont pu rester invisibles
pendant un mois pendant que la production servait 11 fiches de démonstration.

La CLI est compilée dans l'image (`dist/cli/`), donc exécutable dans le
conteneur. Chaque sous-commande exige `--dry-run` ou `--apply` : il n'y a pas de
mode par défaut.

```bash
docker compose exec -T api npm run catalog:import -- --dry-run
docker compose exec -T api npm run catalog:import -- --apply
docker compose exec -T api npm run catalog:reconcile -- --dry-run
docker compose exec -T api npm run catalog:reconcile -- --apply
docker compose exec -T api npm run catalog:switch -- --dry-run
docker compose exec -T api npm run catalog:switch -- --apply
```

> ### ⚠️ `import` ne corrige RIEN. C'est `reconcile` qui réaligne. (31/08/2026)
>
> `import` est idempotent par identifiant : il crée les fiches manquantes et
> **saute** celles qui existent déjà. C'est délibéré — il ne doit pas écraser une
> ligne à l'aveugle — mais la conséquence l'était moins : **une correction
> apportée à une fiche du dépôt n'atteignait jamais la production une fois la
> ligne créée.**
>
> Mesuré en production le 31/08/2026, après `catalog:switch --apply` (30 fiches
> publiées, catalogue 1.3.0) : `york_pise_2027_forecast` et
> `jj_wbgsp_2027_forecast` servaient `dateConfidence: "estimated"` alors que le
> dépôt dit `confirmed` depuis la re-vérification du 24/08 (commit `1176f22`).
> L'écart était conservateur — « À venir, généralement aux mois de … » au lieu
> d'une date ferme, donc aucun étudiant n'a vu de fausse échéance — mais il
> grandit à chaque version du catalogue.
>
> Rien ne le disait : `"skippedExisting": 34` se lit « rien à faire » alors qu'il
> veut dire « 34 fiches non réalignées, donc potentiellement périmées ». Le
> compteur s'appelle désormais `existingNotUpdated`, et `import --dry-run` liste
> les écarts **champ par champ** :
>
> ```json
> "existingNotUpdated": 34,
> "existingAligned": 32,
> "existingDrifted": 2,
> "drift": [
>   { "id": "york_pise_2027_forecast", "realign": 4, "keptFromDatabase": 0,
>     "fields": ["cycle.dateConfidence : estimated → confirmed", "…"] }
> ]
> ```
>
> **L'ordre `import` → `reconcile` → `switch` n'est pas une préférence.**
> `reconcile` doit passer AVANT `switch`, sinon on publie la version périmée
> avant de la corriger.
>
> **`reconcile` ne publie ni n'approuve jamais.** Il n'écrit ni `isActive` ni
> `moderationStatus`, et sa transaction est annulée si l'état de modération
> d'une seule fiche a bougé pendant l'opération. La modération reste
> fail-closed : publier est le travail de `switch`, sur décision explicite.
>
> **Ce que `reconcile` refuse d'écraser**, en le signalant dans son rapport
> plutôt qu'en le taisant :
>
> | Cas | Qui fait foi | Pourquoi |
> | --- | --- | --- |
> | Cycle activé depuis l'admin (`activatedAt`) | la base | Réaligner rétrograderait une date ferme confirmée par un humain en « À venir » — le défaut d'aujourd'hui, dans l'autre sens |
> | **Vérification révoquée** (`setVerification(..., false)` → `lastVerifiedAt` nul) | la base | La révocation ne touche NI `isActive` NI `moderationStatus` : la fiche reste active et n'est masquée que par `lastVerifiedAt: { not: null }`. Reposer le tampon la **republierait sans relecture**. Un `lastVerifiedAt` nul est un signal, pas un vide — seule une nouvelle vérification humaine le repose |
> | `lastVerifiedAt` en base plus récent que celui du dépôt | la base | Un contrôle humain du mois dernier ne se remplace pas par un tampon de catalogue plus ancien. `lastVerifiedAt`, `verifiedById`, `verifiedByName` et **`sourceUrl`** se déplacent d'un bloc : `verificationData` les écrit ensemble, et garder le nom du relecteur en réécrivant sa source attribuerait sa vérification à un lien qu'il n'a pas ouvert |
> | Étape de candidature présente en base et absente du catalogue | la base | `ScholarshipWorkspaceStep.sourceStepId` est en `onDelete: SetNull` : la supprimer détacherait la progression des étudiants |
> | Tags posés dans l'admin, ou tag d'une version antérieure du catalogue | la base | Les tags s'ajoutent, ne se remplacent pas — `publish` retrouve les lignes par ce tag |
>
> Sur tout le reste — texte, avantages, éligibilité, dates du cycle, étapes —
> **le dépôt fait foi**. Une modification faite dans l'admin sur un champ
> éditorial sera donc écrasée. C'est le sens voulu (une correction relue en PR
> doit atteindre la production), et c'est pourquoi le `--dry-run` liste chaque
> champ avant d'écrire.

> ### ⚠️ `--confirmed-only` a été RETIRÉ de ces commandes (30/08/2026)
>
> Ce drapeau écarte par construction toute fiche dont le cycle est `estimated`
> — c'est-à-dire **exactement** les bourses « à venir ». Mesuré en production le
> 30/08 : 34 fiches vérifiées en base, **10 servies à l'app**, dont 4 en licence.
> Les 22 manquantes étaient les fiches à dates estimées, dont les six licences
> panafricaines (Ashesi, ALU, AUC) et les trois européennes.
>
> Le drapeau avait un sens tant que l'app ne savait afficher qu'une date ferme :
> publier une projection au jour près aurait été un mensonge. Depuis la build 50,
> l'app rend « À venir, généralement aux mois de … » pour ces fiches et ne leur
> applique ni compte à rebours, ni badge « bientôt clôturé », ni notification
> d'échéance. La raison de les cacher a disparu ; le drapeau, non.
>
> Le remettre re-cacherait 22 fiches sur 34. Si un jour il faut publier une
> vague strictement confirmée, ajouter `--confirmed-only` **à cet appel-là**, en
> connaissance de cause.
>
> Ces commandes s'exécutent aussi depuis GitHub Actions → **VPS ops
> (feature flag / catalogue)** → `publish-catalog`, pour qui n'a pas d'accès SSH.

> **`import` n'est pas optionnel, et l'ordre n'est pas une préférence.** `switch`
> publie les fiches *déjà présentes en base* puis dépublie les anciennes. Lancé
> sans `import`, il ne trouve rien à publier et dépublie quand même : l'onglet
> Bourses se vide. C'est arrivé en production le 14 août 2026. La CLI refuse
> désormais ce cas, mais la règle reste : **`import` d'abord, toujours.**
>
> Et lisez la sortie du `--dry-run` au lieu de la parcourir : `"published": 0`
> est le signal qu'il ne faut pas passer à `--apply`.

**Pourquoi `switch` et pas `publish` puis `deactivate-legacy`.** `switch` fait les
deux dans une seule transaction, en publiant avant de dépublier : il n'existe
donc aucun instant où l'onglet Bourses est vide pour les utilisateurs. Lancées
séparément, les deux commandes laissent une fenêtre.

**Pourquoi `--confirmed-only` a existé, et pourquoi il ne s'applique plus.**
Une build déjà distribuée pouvait ne pas savoir afficher une date estimée
autrement que comme une date ferme ; publier d'abord les seules fiches
confirmées évitait de faire mentir une app en circulation. Ce paragraphe
annonçait déjà la sortie : « les fiches estimées se publient avec la build qui
sait les présenter, en relançant sans le drapeau ».

**Cette build est la 50** (30/08/2026). Elle rend « À venir, généralement aux
mois de … » pour les cycles estimés, et surtout elle ne leur applique plus ce
qui aurait menti : ni compte à rebours (`_deadlineBadge`), ni badge « bientôt
clôturé » (`ScholarshipModel.windowStatus` sort sur `deadlineIsEstimated`), ni
« Date limite » ferme sur la fiche détail, ni rappel J-30/…/J-1 ni digest
hebdomadaire (`hasEstimatedDeadline`, côté backend). La condition posée ici est
donc remplie, et vérifiable ligne à ligne.

**Ce que la CLI refuse.** Elle écarte une fiche dont la clôture est passée ou
absente, une fiche que la porte de qualité refuse, et elle annule la transaction
entière si, à l'arrivée, une fiche publiée n'a pas de date de vérification.
Contrairement à l'ancien script, une anomalie sur une fiche n'empêche plus
l'import des autres : le refus global était une falaise — une seule campagne
close rendait les 33 autres fiches inimportables.

**Après l'opération**, vérifier de l'extérieur :

```bash
curl -s https://api.kpbeducation.cloud/api/catalog/scholarships | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['source'], len(d['items']))"
```

La provenance doit être `database`, et aucun identifiant de la liste legacy
(`chevening_uk`, `mccall_macbain`, `rhodes_oxford`, …) ne doit subsister.
