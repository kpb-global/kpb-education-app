# Firebase Analytics event contract

Single source of truth for **custom event names** and **parameter keys** is [`lib/app/core/observability/analytics_event_contract.dart`](../lib/app/core/observability/analytics_event_contract.dart) (`AnalyticsEventName`, `AnalyticsParamKey`). Implementations must use these constants so GA4 / BigQuery exports stay stable.

> **PostHog mirror:** every event below is also sent to PostHog under the **same
> name and parameter keys** (see `AnalyticsService._mirror` / `_mirrorScreen`),
> so PostHog insights and GA4 stay aligned. PostHog is inert unless
> `POSTHOG_API_KEY` is set (`--dart-define`). Screen views additionally arrive
> via `PosthogObserver`, and taps via autocapture. Setup + privacy: see
> [`docs/posthog-analytics.md`](posthog-analytics.md).

## Conventions

| Rule | Detail |
|------|--------|
| Event names | `snake_case`, prefer ≤ 40 characters (GA4 limit). |
| Parameter keys | `snake_case`; reuse shared keys (`item_id`, `case_id`, …). |
| Booleans in Analytics | Use integers `0` / `1` where GA4 typing is ambiguous (see `success` on sync). |
| Screens | Use [`AnalyticsService.logScreen`](../lib/app/core/services/analytics_service.dart) (`logScreenView`) — screen class names are passed as Firebase expects. |

## Custom events (app-defined)

| Event (`AnalyticsEventName`) | Parameters | Purpose |
|------------------------------|------------|---------|
| `logout` | — | Session end |
| `orientation_start` | — | Quiz started |
| `orientation_complete` | `total_questions`, `match_count` | Quiz finished |
| `save_item` / `unsave_item` | `item_id`, `item_type` | Saved list |
| `compare_institutions` | `count`, `ids` | Compare flow |
| `case_created` | `case_type` | New dossier |
| `case_viewed` | `case_id` | Detail open |
| `document_uploaded` | `case_id` | Upload |
| `case_message_sent` | `case_id` | Messaging |
| `profile_updated` | — | Profile saved |
| `theme_toggled` | `theme` (`dark` / `light`) | Theme switch |

## Conversion & funnel

| Event | Parameters | Purpose |
|-------|------------|---------|
| `whatsapp_handoff` | `source` (call site, e.g. `program_detail`, `scholarship_official_form_failed`), `context_type` (e.g. `program`, `destination`, `case`, `case_documents`, `blocked_build`, `fraud_report`, `community_group`), `success` (0/1) | Lead→advisor-contact hand-off; `success = 0` means WhatsApp could not be opened (lost conversion). `success = 0` is now **trustworthy on Android 11+**: the hand-off attempts the launch instead of asking `canLaunchUrl`, which package visibility could make lie. |
| `referral_invite_shared` | — | Invite shared via WhatsApp (KPB-69) |
| `referral_redeemed` | — | Referral code redeemed by a referee (KPB-69) |

## Acquisition, onboarding & auth (KPB-156 / KPB-158)

| Event | Parameters | Purpose |
|-------|------------|---------|
| `guest_mode_entered` | — | Visitor chose "Explore without an account" (KPB-156) |
| `guest_to_signup` | `source` (gate: `cases_gate`, `profile`, `scholarships_gate`, `case_create_gate`, `case_tunnel_gate`, `case_tunnel_profile`) | Guest headed to sign-up from a gated action (KPB-156). Every gate now routes through the shared `KpbGuestGate`, so the `source` breakdown finally shows **which** wall converts — `scholarships_gate` is the middle tab (previously a fake "connection problem" screen that converted nobody) and `case_tunnel_gate` covers all 19 tunnel entries at once. |
| `onboarding_step_viewed` | `step` (1-based), `step_count`, `account_type` | A stepper page became visible (KPB-158) |
| `onboarding_completed` | `account_type` | Finished the last onboarding step (KPB-158) |
| `onboarding_skipped` | `step` (1-based, where skipped) | Left onboarding via Skip (KPB-158) |
| `auth_failed` | `method` (`google`/`email`), `reason` (`oauth_error`/`rate_limited`/`send_error`/`verify_error`) | A sign-in/up attempt failed (KPB-158) |
| `sign_up` (GA4 built-in) | `method` (`google`/`email`) | New account created — the **signup method** (KPB-158) |
| `login` (GA4 built-in) | `method` (`google`/`email`) | Returning user signed in |

> Auth success is logged once, in `navigateAfterAuth`: a user with no completed
> onboarding is a new `sign_up` (carrying the signup method), otherwise a
> returning `login`. Callers no longer log it directly (avoids double-counting).

### Onboarding funnel (PostHog dashboard to build)

Funnel steps: `sign_up` → `onboarding_step_viewed` (step 1) → … → `onboarding_step_viewed` (step N) → `onboarding_completed`. The drop between consecutive `step` values localizes where onboarding leaks; split by `account_type` to compare student / parent / partner. `onboarding_skipped` (by `step`) shows where users bail via Skip, and `auth_failed` split by `method` shows whether email OTP or Google loses people **before** signup — the evidence that gates the deferred phone-OTP decision (KPB-158 → KPB-172 review).

## Engagement & retention (KPB-162 / KPB-164 / KPB-165 / KPB-169)

| Event | Parameters | Purpose |
|-------|------------|---------|
| `daily_scholarship_viewed` / `daily_scholarship_opened` | `item_id` | Home "Bourse du jour" card CTR (KPB-162) |
| `my_plan_progress` | `percent`, `next_step` | Unified progress whenever it changes (KPB-164) |
| `share_card` | `source`, `with_image` | A result card was shared into a conversation (KPB-165) |
| `parcours_view` | `slug`, `item_type` (`video`/`text`), `source` (`feed`/`library`/`story_of_week`) | A story became the one on screen (KPB-169) |
| `parcours_complete` | same as above | The story was consumed — video ended, or written interview scrolled to the last answer (KPB-169) |
| `story_of_week_viewed` / `story_of_week_opened` | `slug` | Home "Récit de la semaine" card CTR (KPB-169) |

### Parcours completion rate (KPB-169)

`parcours_complete ÷ parcours_view`, split by `source`, is the completion rate the
feed is judged on — a view count alone says nothing about whether a story lands.
Split by `item_type` too: a video that stalls at 20 % and an interview read to the
end are different problems. A drop in `feed` completion while `library` holds
steady points at the feed itself, not at the content.

## Espace « Études en France » (Phase 0 — vitrine)

| Event | Parameters | Purpose |
|-------|------------|---------|
| `eef_teaser_viewed` | `source` (`home_card`/`tools_drawer`/`student_tools`/`deep_link`/`direct`) | Portée de la vitrine, et par quelle porte |
| `eef_interest_declared` | `wants_premium`, `field_count`, `current_level` | LA question posée par la vitrine : y a-t-il une demande, et pour le payant ? |
| `eef_interest_failed` | `reason` (`network`/`unauthorized`/`server`) | Un envoi qui échoue |
| `eef_space_viewed` | `source` (`home_card`/`tools_drawer`/`student_tools`/`deep_link`/`direct`) | L'espace réel (hub) vu, et par quelle porte (build 54) |
| `eef_hub_tile_opened` | `tile` (`catalogue`/`cv`/`lettres`/`entretien`/`profil`) | Ce que les étudiants viennent FAIRE dans l'espace. La tuile `conseiller` n'existe plus : la carte d'aide l'a remplacée (voir `eef_help_cta_tapped`, `help_step` = `hub`) |
| `eef_catalog_viewed` | `source` (`hub` quand l'étudiant vient du hub, `deep_link` sinon — lien profond ou notification) | Le catalogue ouvert, et par quelle porte |
| `eef_catalog_searched` | `has_query` (`1`/`0`), `filter_count`, `result_count`, `catalog_published` (`1`/`0`) | Une recherche aboutie. **Jamais le texte tapé** : une requête libre peut contenir un nom, une ville, un établissement |
| `eef_catalog_failed` | `reason` (`network`/`server`) | Le catalogue n'a pas pu répondre |
| `eef_help_card_shown` | `help_step` (`hub`/`procedure`/`documents`/`catalog_results`/`catalog_procedure`/`catalog_empty`/`catalog_unpublished`, et depuis la build 55 `catalog_filters`/`tool_cv`/`tool_letters`/`tool_interview`), `surface` (`hub`/`catalog`, et depuis la build 55 `tools`), `variant` (`card`/`compact`) | Une carte d'aide (« c'est flou ? tu veux de l'aide ? ») a été montée : la portée de CHAQUE emplacement |
| `eef_help_cta_tapped` | mêmes trois propriétés (et, depuis la build 55, `help_step` = `catalog_program` aussi) | Le bouton ou le lien de la carte d'aide a été tapé — part AVANT l'ouverture de WhatsApp |

### Lire la carte d'aide sans se tromper (build 54)

- **Le taux de clic d'un emplacement** est `eef_help_cta_tapped ÷ eef_help_card_shown`,
  par `help_step`. C'est la seule façon de savoir où l'incitation marche et où elle
  n'est que du bruit.
- **`eef_help_card_shown` part une fois par étape et par visite de l'écran** (la mémoire
  vit dans le `PageStorage` de la route) : défiler la liste de haut en bas ne compte
  pas dix vues. Une liste paresseuse monte la carte un peu avant qu'elle soit visible :
  c'est une borne haute de la portée, pas un compte d'yeux.
- **Une carte invisible n'est pas « vue »** : pour un pays suspendu, les formes
  compactes (`procedure`, `documents`, `catalog_procedure`) disparaissent et ne
  partent pas ; seule une carte pleine (au libellé neutre « autres options ») reste.
  La build 55 y ajoute des déclencheurs qui, eux, RESTENT visibles pour ces comptes
  (voir la section suivante).
  On ne mesure volontairement PAS le pays, ni un drapeau « suspendu » qui le
  désignerait presque : l'écart de clic entre pays se lirait sinon sur une donnée
  personnelle.
- **Le tap est distinct de la conversion** : `whatsapp_handoff` (`source` =
  `eef_help_<help_step>`, `context_type` = `eef_help`, `success` 0/1) dit ensuite si
  WhatsApp s'est ouvert. `tapped` sans `handoff` réussi = un téléphone qui n'ouvre pas
  WhatsApp, pas un étudiant qui hésite.
- **Aucune donnée personnelle** : trois identifiants fermés écrits dans le code. Le
  test `analytics_event_contract_test.dart` rougit si une propriété est ajoutée.

### Les déclencheurs d'aide de la build 55 (`EefHelpLine`)

Cinq valeurs de `help_step` s'ajoutent, **sans nouvelle propriété** : `help_step`,
`surface` et `variant` restent les trois seules clés (le test
`analytics_event_contract_test.dart` rougit si une quatrième apparaît).

| `help_step` | `surface` | `variant` | Où | `eef_help_card_shown` | `eef_help_cta_tapped` |
|---|---|---|---|---|---|
| `catalog_program` | `catalog` | `compact` | Le bouton « Demander de l'aide » sous **chaque** formation du catalogue | **jamais** (une par carte affichée serait du bruit) | oui |
| `catalog_filters` | `catalog` | `compact` | La ligne « Tu hésites entre ces formations ? » sous les filtres actifs (dès qu'un filtre est posé, et seulement si la ligne de procédure n'est pas affichée) | une fois par visite du catalogue | oui |
| `tool_cv` | `tools` | `compact` | La ligne « Besoin d'aide pour rédiger ton CV ? » de l'écran CV, **ouvert depuis le hub** | une fois par visite de l'écran | oui |
| `tool_letters` | `tools` | `compact` | Idem, écran des lettres de motivation | idem | oui |
| `tool_interview` | `tools` | `compact` | Idem, écran de l'entretien (choix du type d'entretien) | idem | oui |

`surface` = **`tools`** est nouveau : les écrans d'outils ne sont ni le hub ni le
catalogue. Ils n'émettent rien quand ils sont ouverts ailleurs (boîte à outils,
tiroir « Outils KPB », dossier d'un étudiant, coach).

- **Le taux de clic de `catalog_program` ne se lit PAS comme les autres.** Il n'a pas
  de dénominateur `eef_help_card_shown` : on le lit contre `eef_catalog_searched`
  (une recherche affiche des formations) ou, mieux, en **nombre de taps par visite**
  du catalogue. Les autres valeurs gardent `tapped ÷ shown`.
- **Ce qui n'est JAMAIS mesuré** : l'intitulé d'une formation, l'université, la ville,
  un libellé de filtre, l'outil autrement que par sa valeur de `help_step`. Le
  message WhatsApp les porte, l'analytique non : la seule porte (`EefHelpAnalytics`)
  n'accepte que trois identifiants fermés. `catalog_filters` ne dit donc pas QUELS
  filtres : seul `filter_count` d'`eef_catalog_searched` les compte.
- **Un compte dont le pays est suspendu VOIT ces cinq déclencheurs** (décision du
  03/10/2026), au libellé et au message neutres, et ils sont mesurés comme les
  autres : on ne mesure toujours ni le pays ni un drapeau « suspendu ». C'est
  l'inverse de la build 54, où les formes compactes disparaissaient pour ces
  comptes (voir ci-dessus).
- **`whatsapp_handoff`** : `source` = `eef_help_<help_step>` (par exemple
  `eef_help_catalog_program`), `context_type` = `eef_help`, `success` 0/1.
- **Une seule ligne d'aide à la fois sous les filtres** : `catalog_procedure` (build 54)
  a la priorité sur `catalog_filters` — pour une ligne qu'on VOIT : la ligne de
  procédure est invisible (donc non mesurée) pour un pays suspendu. Deux lignes ne
  sont donc jamais affichées ensemble ; mais l'étudiant qui change de filtres dans la
  même visite peut les produire l'une après l'autre.

### Lire le catalogue sans se tromper (build 54)

- **`eef_catalog_failed` existe pour la même raison que `eef_interest_failed`** :
  une panne du catalogue le jour du lancement se lit, sans lui, exactement comme
  « personne ne cherche ».
- **`result_count = 0` n'est pas une panne** : c'est une recherche qui n'a rien
  trouvé. Croiser avec `catalog_published` : `0` ⇒ rien n'est publié (ce n'est pas
  un défaut de recherche), `1` ⇒ la recherche était trop étroite.
- **Une recherche par requête, pas par page** : `eef_catalog_searched` ne part
  pas au défilement.
- **`filter_count` compte les VALEURS choisies de toutes les familles** — niveau,
  domaine, ville et procédure : un niveau, deux villes et un domaine font `4`.
  Les filtres se posent par feuille (« Voir N formations ») : cocher dix cases puis
  valider est UNE recherche, donc UN événement, avec `filter_count = 10`. Ni le nom
  d'une ville, ni un identifiant de domaine, ni un libellé de filtre ne part
  jamais : une ville est une donnée de profil, au même titre que le texte tapé
  (le test `eef_catalog_controller_test.dart` lit les sources pour le garantir).
  L'ouverture d'une feuille, la recherche locale d'une ville et l'échec du
  chargement des villes ne produisent AUCUN événement — en particulier pas
  `eef_catalog_failed`, qui dit « le catalogue n'a pas pu répondre ».
- **Les booléens partent en `1`/`0`**, pas en `true`/`false`
  (`FirebaseAnalytics.logEvent` n'accepte que `String` ou `num`).

### Pourquoi `eef_interest_failed` existe

Sans lui, un backend en panne le jour du lancement produit exactement la même
courbe que « personne n'est intéressé » — et c'est la conclusion **inverse** de
la vérité qu'on tirerait du tableau de bord. Le taux à surveiller est donc
`eef_interest_failed ÷ (eef_interest_declared + eef_interest_failed)` : au-delà
de quelques pourcents, ce n'est pas le produit qui déçoit, c'est la chaîne
d'envoi qui casse.

`field_count` et non la liste des filières : un compte suffit à segmenter, et
n'expose pas le détail du profil d'un mineur dans une charge analytique.

### Entonnoir de la Phase 0

`eef_teaser_viewed` → `eef_interest_declared`, segmenté par `source`, dit
quelle porte convertit. La part de `wants_premium = true` parmi les
déclarations est le signal qui décide du modèle payant — c'est la seule mesure
directe de la demande pour le Premium dont l'app dispose aujourd'hui, faute de
tout produit payant existant.

> **`field_count` vaut 0 jusqu'à la build 53, puis varie.** Les builds 49 à 53 n'ont
> aucun sélecteur de domaine : le champ existe dans le DTO, en base et dans le
> CSV, mais ces écrans ne l'envoient jamais. La build 54 ajoute le sélecteur
> (domaines d01–d12, préremplis depuis le profil) : à partir d'elle seulement,
> `field_count` segmente. Ne pas comparer la distribution avant/après sans
> filtrer sur la version de l'app (la dimension de version de l'application que Firebase Analytics et PostHog renseignent d'eux-mêmes ; `X-KPB-App-Version` n'est pas lu côté serveur). Écrit ici parce que c'est
> le document qu'on ouvre pour interpréter l'entonnoir, et qu'un zéro constant
> se lit autrement comme « personne ne choisit de filière ».
>
> **`wants_premium` part en `1`/`0`, pas en booléen.**
> `FirebaseAnalytics.logEvent` assert `value is String || value is num` : le
> booléen brut faisait lever en debug, l'exception était attrapée, et c'est
> l'événement ENTIER qui disparaissait — celui-là même dont ce document dit
> qu'il décide du modèle payant.
>
> **Une « modification » réussie réémet `eef_interest_declared`.** Le ratio
> `wants_premium` calculé sur les ÉVÉNEMENTS est donc biaisé par les étudiants
> qui cochent Premium dans un second temps. Compter sur les utilisateurs
> distincts, ou lire le compteur du back-office, qui compte des lignes.

## Sync & reliability (observability)

| Event | Parameters | Purpose |
|-------|------------|---------|
| `sync_full_complete` | `success` (0/1), `elapsed_ms`, `catalog_hive_fallback_count` | Full sync outcome |
| `sync_conflict_resolved` | `domain`, `resolution` | Merge / skip logic (profile, cases, saved_items) |
| `sync_catalog_hive_fallback` | `resource`, `attempts` | Catalog API exhausted retries; Hive used |

## Recommended GA4 / BigQuery checks

- **Hand-off failure rate:** Count `whatsapp_handoff` where `success = 0` / all `whatsapp_handoff` — spikes mean users can't reach the advisor (device without WhatsApp, broken link).
- **Hand-off mix:** Breakdown of `whatsapp_handoff` by `source` × `context_type` to see which screens actually convert.
- **Sync failure rate:** Count `sync_full_complete` where `success = 0` / all `sync_full_complete`.
- **Slow sync:** Distribution of `elapsed_ms` on successful runs.
- **Offline catalog pressure:** Sum `catalog_hive_fallback_count` or count `sync_catalog_hive_fallback`.

See also [`observability-dashboards.md`](observability-dashboards.md).
