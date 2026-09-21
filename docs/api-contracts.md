# KPB Education relaunch API contracts

These are the working contracts represented in the current scaffolding.

## Profiles

- `GET /profiles/me`
- `PATCH /profiles/me`

Purpose:
- load the current user profile
- progressively enrich profile data after onboarding

## Orientation

- `POST /orientation/sessions`
- `GET /orientation/results/:id`

Purpose:
- submit guided orientation answers
- retrieve scored recommendations and next actions

## Catalog

- `GET /catalog/fields`
- `GET /catalog/countries`
- `GET /catalog/institutions`
- `GET /catalog/programs`
- `GET /catalog/scholarships`

Purpose:
- feed Explore, Scholarships, and recommendation surfaces

## Matches (Phase 0 / P0-D — kit US-003/US-004)

- `GET /matches/aha-moment?limit=3` (student auth)
- `GET /matches/school/:institutionId` (student auth)

Purpose:
- deterministic admission-probability scoring (algorithm v1, 5 weighted
  factors — see `docs/phase0-new-plan-alignment.md` and the kit's
  `matching_algorithm.md`)
- `aha-moment` returns the top-N institutions (best program each) across the
  caller's target countries/fields, for the post-onboarding reveal
- `school/:institutionId` returns the best-scoring program of one institution

Response item shape:

```json
{
  "institutionId": "…",
  "institutionName": { "fr": "…", "en": "…" },
  "programId": "…",
  "programName": { "fr": "…", "en": "…" },
  "probability": 0.74,
  "zone": "green | yellow | blue",
  "isEstimate": false,
  "algorithmVersion": "v1",
  "factors": [
    { "name": "academic", "weight": 0.3, "score": 1, "isEstimate": false }
  ],
  "narrative": { "fr": "…", "en": "…" }
}
```

`aha-moment` wraps items as `{ "items": [...], "isEstimate": bool }`.
Zones: green > 0.70 · yellow 0.30–0.70 · blue < 0.30. Missing inputs score a
neutral 0.5 with `isEstimate`; ≥2 missing caps probability at 0.65.

## Content

- `GET /content/service-offers`
- `GET /content/support-destinations`
- `GET /content/articles`

Purpose:
- feed the mobile relaunch with dashboard-managed offers, destination coverage, and editorial content

## Community

- `GET /community/forum-categories`
- `GET /community/forum-tags`

Purpose:
- expose dashboard-managed forum taxonomy to the mobile community layer

## Cases

- `GET /cases`
- `GET /cases/:id`
- `POST /cases`
- `PATCH /cases/:id`
- `GET /cases/:id/messages`
- `POST /cases/:id/messages`
- `POST /cases/:id/documents`

Purpose:
- create and manage the unified student-facing `My Cases` experience
- support counselor/admin updates, service messaging, and document handling

## Admin case operations

- `GET /admin/cases`
- `POST /admin/cases/:id/assign`
- `POST /admin/cases/:id/tasks`
- `POST /admin/cases/:id/internal-notes`
- `POST /admin/cases/:id/timeline-events`

Purpose:
- power counselor and admin case ownership, internal workflow, and operational follow-up

## Appointments

- `GET /appointments`
- `POST /appointments`

Purpose:
- schedule counseling and mentoring sessions linked to cases

## Saved Items

- `GET /saved-items`
- `POST /saved-items`
- `DELETE /saved-items/:id`

Purpose:
- persist saved countries, fields, programs, institutions, and scholarships

## Partner leads

- `GET /partner-leads`
- `POST /partner-leads`

Purpose:
- support lightweight partner acquisition outside the student case flow

## Recherche du catalogue « Études en France » (Phase 1)

- `GET /etudes-en-france/search`

**Publique**, et c'est une décision produit, pas un oubli : « catalogue
gratuit, accompagnement payant » (plan § 2). Un étudiant doit pouvoir chercher
sa formation avant de créer un compte — c'est ce qui lui donne une raison d'en
créer un. La route vit donc dans son propre contrôleur, à côté de celui de la
déclaration d'intérêt, qui lui est authentifié au niveau de la classe.

### Paramètres

| Paramètre | Forme | Notes |
|---|---|---|
| `q` | texte | découpé en mots (6 max). Chaque mot doit apparaître dans l'intitulé **ou** la ville — « droit rennes » fonctionne. |
| `procedureType` | CSV | `dap_blanche`, `dap_jaune`, `eef`, `parcoursup`, `hors_eef` |
| `cycle` | CSV | `licence1`, `licence2`, `licence3`, `but1`, `deust`, `sante`, `ingenieur`, `master` |
| `fieldId` | CSV | `d01`..`d12` |
| `selectivity` | CSV | `selective`, `non_selective` |
| `campusCity` | CSV | vocabulaire ouvert (vient du catalogue) |
| `institutionId` | CSV | vocabulaire ouvert |
| `cursor` | opaque | rendu par la page précédente |
| `limit` | entier | défaut 20, plafond 50 |

Chaque paramètre de liste accepte les **deux formes** : séparée par des
virgules (`?cycle=master,licence1`) et répétée (`?cycle=master&cycle=licence1`).
Express livre la seconde sous forme de tableau ; les refuser serait une
chausse-trappe, puisque c'est la forme que produisent naturellement les clients
HTTP. Un paramètre scalaire répété (`?cursor=a&cursor=b`) retient la première
valeur.

Une valeur hors référentiel fermé rend **400 `EEF_SEARCH_BAD_PARAM`**, avec le
paramètre fautif et les valeurs admises. L'ignorer silencieusement ferait
afficher des compteurs qui ne correspondent pas à la demande. Un
`institutionId` inconnu, lui, rend zéro résultat : c'est la bonne réponse, pas
une erreur. Chaque facette accepte au plus 20 valeurs — une liste `IN` sans
borne se fabrique avec une simple URL.

### Réponse

```jsonc
{
  "items": [ /* même forme que GET /catalog/programs */ ],
  "total": 10247,
  "page": { "limit": 20, "hasMore": true, "nextCursor": "TDEgLSBEcm9pdAB..." },
  "facets": {
    "procedureType": [{ "value": "eef", "count": 7125 }, "…"],
    "cycle": ["…"], "fieldId": ["…"], "selectivity": ["…"],
    "campusCity": ["…"], "institutionId": ["…"]
  },
  "facetsTruncated": ["campusCity", "institutionId"],
  "source": "database"
}
```

### Ce que la pagination garantit

**Curseur, pas offset.** Le curseur porte la POSITION — le dernier couple
`(nameFr, id)` vu — et non un rang. Deux conséquences :

- *Correction* : si un administrateur publie une fiche pendant qu'un étudiant
  fait défiler, un offset décale tout d'un rang et lui fait sauter une
  formation sans qu'il le sache. Le curseur, non.
- *Coût constant* : mesuré sur les 10 247 lignes, page 205 sur 205 — offset
  4,4 ms → 23,4 ms, curseur 3,8 ms → 4,8 ms. L'écart croît avec la taille du
  catalogue ; c'est la correction qui est l'argument fort, le coût n'en est
  que la conséquence visible.

L'ordre est **total** (`nameFr` puis `id`). `nameFr` seul ne l'est pas —
« L1 - Droit » est servi par quarante universités — et un ordre partiel fait
sauter des lignes au curseur.

### Ce que les facettes garantissent

Chaque facette est comptée **sans son propre filtre**. Choisir « master » ne
fait donc pas tomber à zéro le compte des licences : l'étudiant voit toujours
ce qu'il obtiendrait en changeant d'avis, sans avoir à défaire son filtre. Le
total, lui, tient compte de tous les filtres.

Page, total et facettes sont lus dans **une seule transaction**, en isolation
`RepeatableRead` : servis séparément — ou même dans une transaction
`READ COMMITTED`, où chaque instruction a son propre instantané — ils
décriraient deux instants différents, « 1 240 résultats » au-dessus d'une liste
qui en montre d'autres.

`campusCity` et `institutionId` ont des dizaines de valeurs : les 20 plus
fournies sont rendues, et `facetsTruncated` le dit.

### Pas de repli sur les jeux de démonstration

`/catalog/*` sait dégrader vers `mock-catalog` hors production. Pas ici : il
n'existe aucun échantillon « Études en France », et en fabriquer un servirait
des formations qui n'existent pas. Base indisponible ⇒ **503
`CATALOG_UNAVAILABLE`**, dans tous les environnements.

La route ne sert que des lignes **relues** (`isActive = true`) et rattachées à
la France, résolue en base par son **code** — `FRA` comme `FR`, le référentiel
M5 étant en ISO 3166-1 alpha-3 — et jamais par un identifiant écrit en dur. La
règle est partagée avec l'import (`eef-country.ts`) : elle vivait en double, et
c'est pour cela que l'erreur y vivait aussi.

## Espace « Études en France » (Phase 0)

- `GET /etudes-en-france/interest`
- `POST /etudes-en-france/interest`

Authentifiés (`StudentAuthGuard`) : une déclaration d'intérêt sans identité ne
serait pas rappelable, et c'est le contact qu'on cherche à collecter.

Purpose:
- enregistrer qui veut être prévenu à l'ouverture de l'espace, et qui se déclare
  intéressé par le Premium

Réponse (les deux routes) :

```json
{
  "declared": true,
  "currentLevel": "terminale",
  "targetLevel": "licence",
  "fieldIds": ["info"],
  "wantsPremium": true,
  "consentedAt": "2026-08-21T10:00:00.000Z"
}
```

Deux invariants que le client suppose, et sur lesquels des tests existent des
deux côtés :

- **`declared: true` est la seule preuve d'écriture.** Un 2xx dont le corps ne
  l'affirme pas est traité par le client comme un ÉCHEC. Un 200 n'est pas une
  preuve d'écriture ; le corps l'est.
- **Le service échoue fermé.** Base indisponible ⇒ `503`, jamais un objet
  d'apparence normale. Rendre un succès sans écriture ferait afficher « c'est
  noté » pour une ligne qui n'existe nulle part.

`consentedAt` est horodaté par le SERVEUR à la réception, donc non antidatable
par un client, et rafraîchi à chaque redéclaration : la preuve qui compte est le
dernier consentement donné.

L'écriture est un `upsert` sur `userId` (unique) : une redéclaration corrige la
ligne au lieu d'en créer une seconde.

### `DELETE /etudes-en-france/interest`

Retire la déclaration du profil authentifié. **Idempotente** : retirer une
déclaration absente rend le même corps que retirer celle qui existait
(`declared: false`), parce que le résultat qui compte est « cette personne n'est
plus dans la liste » et qu'un 404 obligerait l'écran à distinguer deux cas pour
afficher la même chose.

Cette route existe parce que le texte de consentement promet un retrait. Elle a
manqué : la promesse a précédé le mécanisme, et les seules issues réelles étaient
d'écrire à une adresse générique ou de supprimer le compte entier pour retirer
une ligne de prospection.

**Invariant client** : un corps qui dit encore `declared: true` est traité comme
un ÉCHEC. Afficher « tu es retiré » sur une ligne toujours en base est le même
mensonge que « c'est noté » sur une ligne jamais écrite.

### Les bornes de campagne sont des JOURS, pas des instants

**Format du fil : `AAAA-MM-JJ`, un jour nu.** `/config/app` sert `opensAt` /
`closesAt` sans heure ni décalage, quoi que l'exploitation ait écrit dans la
variable d'environnement. Le client relit les composantes du texte reçu, ce qui
en fait une seconde ligne de défense et non le mécanisme principal.

Ce format est une correction, et elle a deux moitiés parce que le défaut en avait
deux. La borne était sérialisée en instant UTC par le serveur, puis reprojetée
dans le fuseau de l'appareil par le client :

| Valeur écrite par l'exploitation | Servie autrefois | Fuseau du téléphone | Ce qui s'affichait |
|---|---|---|---|
| `2026-10-01T00:00:00Z` | `2026-10-01T00:00:00.000Z` | UTC+0/+1 (Dakar, Niamey) | 1er octobre ✓ |
| `2026-10-01T00:00:00Z` | `2026-10-01T00:00:00.000Z` | UTC−1/−4 (Cabo Verde, diaspora) | **30 septembre** ✗ |
| `2026-10-01T00:00:00+02:00` (heure de Paris) | **`2026-09-30T22:00:00.000Z`** | **tous** | **30 septembre** ✗ |

La dernière ligne est celle qui compte, et elle explique pourquoi le correctif
client ne suffisait pas : `new Date(raw).toISOString()` avait déjà détruit le
jour côté serveur. Aucune lecture du fil ne pouvait le retrouver — et écrire
l'heure de Paris est le réflexe naturel pour une procédure française, donc ce
n'était pas un cas de bord mais le cas de production, donnant la mauvaise date à
**tout le public d'un coup**.

Deux conséquences pour qui pose ces variables :

- **N'écrivez pas d'heure.** `2026-10-01` est la forme attendue. Une heure
  écrite est ignorée — `2026-10-01T23:30:00-05:00` désigne bien le 1er octobre —
  mais elle laisse croire qu'elle compte, et c'est cette croyance qui a produit
  le défaut.
- **Les deux bornes sont INCLUSIVES.** « Jusqu'au 15 novembre » inclut le 15
  entier. La comparaison était auparavant faite sur l'instant, donc la campagne
  passait « close » à la première seconde du jour de clôture — un étudiant
  ouvrant l'app le matin de sa date limite lisait que c'était terminé.

Une valeur illisible, un mois 13 ou un 30 février rendent `null` **des deux
côtés**, et l'app n'annonce alors AUCUNE date. `new Date(Date.UTC(2026, 12, 1))`
vaut janvier 2027 et `DateTime(2026, 1, 32)` vaut le 1er février : normaliser
une faute de frappe fabriquerait une échéance que personne n'a écrite, et
qu'un étudiant lirait comme une information.

Gardé par `test/release/campaign_wire_day_test.dart` (le format du fil) et
`test/features/etudes_en_france/eef_campaign_day_test.dart` (le décodage). Le
premier existe parce que les deux côtés étaient verts pendant que le défaut
vivait dans la couture : les tests mobiles décodaient la valeur d'exploitation
directement, contournant la normalisation serveur, et un test backend figeait
cette normalisation comme contrat.

### Le consentement, sur le fil

`POST /etudes-en-france/interest` exige deux champs, et les refuse absents :

| Champ | Règle |
|---|---|
| `consent` | doit valoir exactement `true`. Un `false` explicite est refusé, pas enregistré |
| `consentVersion` | l'identifiant du texte affiché à l'écran, borné à 64 caractères |

`consentedAt` reste horodaté **par le serveur** : le client ne l'envoie pas et ne
peut donc pas l'antidater. Mais l'horodatage seul ne prouvait que « non
antidatable » — sans `consent`, un `POST` au corps vide fabriquait une preuve de
consentement, le `now()` ayant simplement déménagé de Postgres vers Node. Et sans
`consentVersion`, on ne pourrait produire qu'une date, jamais la phrase acceptée.

`test/features/etudes_en_france/eef_consent_version_test.dart` apparie la
constante client à une empreinte des textes FR et EN : le texte ne peut plus
changer sans que la version bouge.

### `DELETE /admin/etudes-en-france/interest/:id`

Le même retrait, exécuté par l'équipe pour une demande reçue par e-mail ou
WhatsApp. Ouvert aux mêmes rôles que la LECTURE — pas restreint à
l'administration comme l'export : l'export fait sortir des données du périmètre,
ce retrait les fait disparaître, et un droit qu'on exerce lentement s'exerce mal.

## Admin — liste d'intérêt « Études en France »

- `GET /admin/etudes-en-france/interest/summary`
- `GET /admin/etudes-en-france/interest?take=&skip=`
- `GET /admin/etudes-en-france/interest/export.csv`

Rôles : `admin`, `super_admin`, `commercial`, `counselor`. Volontairement PAS
`moderator` ni `content_manager` — ce sont des noms, des e-mails et des numéros
de téléphone, et la modération de forum n'a rien à en faire.

Purpose:
- lire et exporter la liste des prospects, sans quoi elle ne quitte jamais
  Postgres et personne ne rappelle personne

L'export est servi en `text/csv; charset=utf-8` avec
`Content-Disposition: attachment`, un BOM UTF-8 (sans lui Excel sous Windows
rend « Côte d'Ivoire » en « CÃ´te d'Ivoire »), et chaque cellule neutralisée
contre l'évaluation de formules par un tableur — voir `eef-interest-csv.ts`.

## Admin content operations

- `GET /admin/service-offers`
- `POST /admin/service-offers`
- `PATCH /admin/service-offers/:id`
- `GET /admin/support-destinations`
- `POST /admin/support-destinations`
- `PATCH /admin/support-destinations/:id`
- `GET /admin/articles`
- `POST /admin/articles`
- `PATCH /admin/articles/:id`
- `GET /admin/forum-categories`
- `POST /admin/forum-categories`
- `PATCH /admin/forum-categories/:id`
- `GET /admin/forum-tags`
- `POST /admin/forum-tags`
- `PATCH /admin/forum-tags/:id`
- `GET /admin/forum-moderation`

Purpose:
- let operations teams add service offers, destination coverage, articles, forum categories, and topic tags from the dashboard

## Admin notifications

- `GET /admin/notifications/templates`
- `POST /admin/notifications/templates`
- `PATCH /admin/notifications/templates/:id`
- `GET /admin/notifications/campaigns`
- `POST /admin/notifications/campaigns`
- `GET /admin/notifications/campaigns/:id/deliveries`

Purpose:
- manage grouped or specific campaigns across push, in-app, and email channels
- attach critical campaign events to case timelines when needed

## Admin users and reporting

- `GET /admin/users`
- `POST /admin/users`
- `PATCH /admin/users/:id`
- `GET /admin/reports/overview`
- `GET /admin/reports/funnel`
- `GET /admin/reports/counselor-performance`
- `GET /admin/reports/campaign-performance`

Purpose:
- manage internal roles and provide the first reporting layer for cases, counseling, and campaigns
