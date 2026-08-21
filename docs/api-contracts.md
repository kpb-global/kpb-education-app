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
