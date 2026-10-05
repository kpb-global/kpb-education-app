# Runbook — ouvrir l'espace « Études en France » réel aux étudiants

> **État et blocages : `docs/ouverture-espace-eef.md` (corrigé le 03/10/2026).** La 54 n'a
> **jamais été envoyée** aux boutiques ; la **2.3.0 (55)** la remplace et porte le hub.
> Dans ce runbook, « la 54 » (écrit avant ce constat) désigne **la build qui contient le hub,
> c'est-à-dire la 55**. Les corrections de procédure du catalogue publié ont été appliquées
> le 02/10 (`eef-reconcile`, #305) ; le juridique est tranché depuis le 03/10.

> **Ce que ce runbook couvre.** Le passage de l'état de lancement (vitrine
> « en préparation » + notifications) à l'espace réel (hub, catalogue, profil) pour
> la build **2.3.0 (55)** et suivantes (la 54, jamais envoyée, est abandonnée). Il complète `docs/cutover-build49.md`
> (étape 9 bis = la vitrine, titré « build 49 ») ; il ne le remplace pas.
>
> **Ce qu'il ne fait jamais.** Poser `KPB_EEF_ENABLED=true`. C'est l'**ancien**
> commutateur : il retire la vitrine de TOUTES les builds, dont les 49 à 53 qui
> n'ont qu'une coquille vide pour l'espace. L'ouverture de la 54 passe par
> **`eefSpace`** (`KPB_EEF_SPACE_ENABLED`), qui ne touche pas à la vitrine des
> builds plus anciennes. `eef-teaser-on` et `eef-space-on` refusent d'ailleurs de
> s'exécuter si `KPB_EEF_ENABLED=true` est posé.

## État de lancement (1er octobre 2026)

| Clé `/config/app` | Valeur | Pourquoi |
|---|---|---|
| `features.eefTeaser` | `true` | la vitrine, pour toutes les builds |
| `features.eef` | `false` | **ne pas toucher** |
| `features.eefSpace` | `false` | le hub n'est pas encore ouvert |
| `eefCampaign.opensAt` | `2026-10-01` | jour nu |
| `eefCampaign.closesAt` | `null` | les clôtures divergent par pays |
| `eefCampaign.suspendedCountries` | `["Niger","NE"]` | |

## Préconditions — TOUTES, dans cet ordre

| # | Précondition | Comment le vérifier |
|---|---|---|
| 1 | **La build qui contient le hub (la 55) est en vente sur les deux stores** et adoptée par la majorité | App Store Connect / Play Console ; PostHog (version de l'app). Tant qu'elle n'est pas majoritaire, ouvrir l'espace ne profite qu'à une minorité — les 49 à 53 gardent la vitrine. Le seuil d'adoption n'est pas fixé dans le dépôt (`docs/ouverture-espace-eef.md` § 6). |
| 2 | **Le backend est au commit de FUSION de la branche build 54** — celui qui contient `eef-catalog-attribution.ts`, les audiences `eef_interest` / `all_students_except_countries` et les clés `/config/app` (`eefCatalog`, `platformUrl`, `suspendedSources`, `recommendedVersion`). **Pas `95440db`** : ce SHA porte la recherche et le `PATCH` mais ni la mention de paternité du catalogue ni les audiences. | `GET /api/health/version` → `sha` ; `deploy.yml` `scope=full`. Migration additive `20260930120000_eef_search_text_and_acronym` (`Program.searchText`, `Institution.acronym`) : `prisma migrate status` ne liste rien en attente. `eef-space-on` **refuse** désormais d'écrire si le conteneur ne porte pas `eef-catalog-attribution.js`, et le workflow vérifie après coup que `/config/app` sert `eefCatalog` et `platformUrl`. |
| 3 | **Le catalogue est importé** (lignes inactives) et ses index sont remplis | `vps-ops` → `eef-import` : d'abord `dry_run` coché (lit les 4 passes : import, cycles, admission, **recherche**), puis décoché. Un second passage ne doit plus rien créer. |
| 4 | **Le catalogue est publié** (au minimum un établissement pilote) | Deux voies, même service, même plan. **(a)** Admin → « Publication EEF » : plan → simulation → application, un établissement à la fois, sous le nom du vérificateur connecté. **(b)** En une fois, par délégation du propriétaire : `vps-ops` → `eef-publish` (simulation, puis total saisi) — voir `docs/eef-publication-deleguee.md`. Dans les deux cas : `GET /api/etudes-en-france/search` → `total > 0`. `.github/scripts/db-info.sql` §7 et §8 (colonne `publiees`) donnent le décompte, le §11 dit si le texte cherchable est comblé, le §12 audite l'intégrité des lignes. |
| 5 | **La recherche répond bien** | `curl 'https://api.kpbeducation.cloud/api/etudes-en-france/search?q=<nom du pilote>'` → l'établissement et sa formation, avec `institution`, `procedureType`, `catalogPublished: true`. |
| 6 | Les textes juridiques sont validés | `docs/eef-consent-v1.md` §« Questions juridiques ouvertes » ; la phrase sur l'agence dans le héros du hub. |

> **Pourquoi pas avant.** Un espace ouvert sur un catalogue vide affiche « Le
> catalogue arrive » à tout le monde — c'est honnête, mais c'est une porte
> ouverte sur une pièce vide, et un refus potentiel à la revue (guideline 2.1) si
> la 54 est encore en revue.

## Ouvrir

1. **GitHub → Actions → « VPS ops »** → `eef-space-on`, **`dry_run` coché**. Les
   contrôles passent ou échouent : `KPB_EEF_ENABLED` absent, décompte des
   formations publiées lisible **et > 0**. Rien n'est écrit.
2. Relancer **`dry_run` décoché**. L'action sauvegarde le `.env`, pose
   `KPB_EEF_SPACE_ENABLED=true`, recrée le seul conteneur `api` à la même image.
3. **Observer** :
   ```bash
   curl -fsS https://api.kpbeducation.cloud/api/config/app | jq '.features, .eefCampaign, .eefCatalog'
   ```
   - `features.eefSpace` → `true` ;
   - `features.eefTeaser` → `true` (**inchangé** : les 49 à 53 gardent leur vitrine) ;
   - `features.eef` → `false` ;
   - `eefCampaign.platformUrl` → l'URL de la plateforme ; `suspendedSources` → une
     entrée par pays suspendu ;
   - `eefCatalog.updatedAt` → le jour du dernier import.
4. **Contrôler sur appareil** (une 53 et une 54) : la 53 montre la vitrine ; la 54
   montre le hub. Sur la 54 : ouvrir le catalogue, chercher le nom du pilote,
   vérifier la carte (université, ville, procédure), le pied de page (licence,
   non-affiliation), puis « Mon profil Études en France » → Modifier / Me retirer.
5. **Un compte du Niger** (ou un profil dont le pays est dans la liste) : le hub
   montre la mise en garde et le lien de la source, **pas** la date.

## Bulle « Une question ? » et écoles privées (build 56 et suivantes)

Deux interrupteurs serveur **de plus**, lus par la seule build 56 et les suivantes. Ils sont
**fermés par défaut**, **indépendants** de l'espace et **l'un de l'autre** : ouvrir l'espace
n'allume ni l'un ni l'autre, et aucun des deux n'affiche quoi que ce soit si `eefSpace` est
faux (l'app exige l'espace ouvert EN PLUS). Une clé absente est lue « faux » — anciennes builds
et ancien backend ne voient rien.

| Clé `/config/app` | Variable `.env` | Ouvrir | Fermer |
|---|---|---|---|
| `features.eefHelpBubble` | `KPB_EEF_HELP_BUBBLE_ENABLED` | `eef-bubble-on` | `eef-bubble-off` |
| `features.eefPrivateSchools` | `KPB_EEF_PRIVATE_SCHOOLS_ENABLED` | `eef-private-schools-on` | `eef-private-schools-off` |

**Ordre d'ouverture.** 1. `eef-space-on` (section « Ouvrir » ci-dessus). 2. `eef-bubble-on`.
3. `eef-private-schools-on` — **seulement après la validation juridique** (phrase sur la
rémunération, phrase sur les frais, Niger) et, de préférence, quelques jours après le hub pour
ne pas mêler les signaux. **Fermeture dans l'ordre inverse** : `eef-private-schools-off`, puis
`eef-bubble-off`, puis `eef-space-off` si l'espace lui-même doit se refermer. Chaque retour
arrière est indépendant : fermer la bulle ne ferme pas l'espace.

**Comment les lancer** (GitHub → Actions → « VPS ops ») :

- Les deux `-on` **simulent par défaut** : `dry_run` coché, les contrôles passent ou échouent,
  rien n'est écrit. On n'écrit que sur un `dry_run` **décoché** (toute autre valeur simule).
  Contrôles : la variable est relayée par `docker-compose.yml`, et **le backend déployé SERT la
  clé** (le contrôleur compilé du conteneur la contient). Un backend déployé à un commit
  antérieur à la 56 est refusé : déployer d'abord (`deploy.yml`, `scope=full`) — **jamais un
  commit postérieur au SHA de release de la 55 avant le préflight de la 55** (voir
  `docs/release-ledger.md`). Si l'espace n'est pas à `true` dans le `.env`, un avertissement le
  dit (l'ordre ci-dessus), sans bloquer.
- Les deux `-off` **n'ont pas de simulation** : ils agissent tout de suite, que `dry_run` soit
  coché ou non, et ne dépendent pas du code déployé (on doit toujours pouvoir fermer).
- Chaque action n'écrit que **sa** clé dans le `.env` (sauvegardé avant), puis recrée le seul
  conteneur `api` à la même image et attend qu'il réponde.

**La preuve vient de l'extérieur, pas du code de sortie.** Après chaque action réelle, le
workflow relit `/config/app` et vérifie : la clé de l'action vaut la valeur voulue ;
`features.eef` reste `false` ; `features.eefSpace` vaut ce qu'il valait **avant** l'opération
(relevé au début du job — une ouverture réelle dont ce relevé est illisible est refusée, une
fermeture part quand même). Elle n'exige ni `eefCatalog` ni `eefCampaign` : ce sont les
conditions d'ouverture de l'espace. À vérifier à la main en plus :

```bash
curl -fsS https://api.kpbeducation.cloud/api/config/app | jq '.features | {eef, eefTeaser, eefSpace, eefHelpBubble, eefPrivateSchools}'
```

Si `eefHelpBubble` / `eefPrivateSchools` sont **absents** de la réponse, l'image en production
est antérieure à la 56 : la bascule n'a aucun effet. Les builds antérieures à la 56 n'ont, elles,
rien à voir changer.

## Inviter à mettre à jour — un levier pour les builds SUIVANTES, pas pour la 53

**Ce levier ne touche pas les builds 49 à 53** : elles ne lisent pas
`recommendedVersion`, et le bandeau n'existe que dans la 55 et après. Les
utilisateurs de la 53 ne passent à la 55 que par la mise à jour automatique du
store, une notification qui les y envoie, ou (en dernier recours, jamais avant la
55 à ~100 %) `KPB_MIN_APP_VERSION`.

`recommended-version-set` sert aux passages **55 → build suivante → forum** : la veille d'une
build, mettre sa version dans `RECOMMENDED_APP_VERSION`
(`.github/scripts/vps-ops.sh`, **par PR** — l'action n'accepte aucune valeur
libre), puis lancer l'action (simulation d'abord) quand la build est **disponible
sur les deux stores**. Les builds plus anciennes que la valeur (la 55 et suivantes) voient alors un bandeau
**qu'on ferme**, avec le lien du store. La constante est **vide** par défaut : à
vide, l'action retire la clé. `KPB_MIN_APP_VERSION` n'est jamais touché.

## Annoncer l'ouverture

- Audience (décision juridique du 03/10/2026) : **tous les étudiants, Niger compris**
  (`all_students`), avec un texte **neutre** qui ne promet pas que la procédure est
  ouverte pour le lecteur : un étudiant nigérien peut faire sa procédure par un autre
  pays, on ne bloque personne. **Ne pas** poser `exceptCountries` / `eef_suspended` pour
  cette annonce. **Jamais `country`** : il filtre sur le pays de résidence. **Pas
  `eef_interest`** : la question de consentement ci-dessous n'est pas tranchée.
  - **Lire l'aperçu** avant le feu vert : le nombre de destinataires doit être celui des
    comptes étudiants, sans pays retiré.
  - **Question juridique toujours ouverte pour `eef_interest`** : le texte de consentement
    dit « un conseiller KPB te contacte au sujet de cet espace ». Une annonce
    d'ouverture automatisée (push ou e-mail) à ceux qui ont déclaré leur intérêt
    est-elle couverte ? La vitrine promet « on te préviendra dès l'ouverture »
    (`eef_cta_body`), ce qui plaide pour, mais ce texte n'est pas celui que le test
    d'empreinte fige. Voir `docs/eef-consent-v1.md` § 4, point 4. Tant qu'elle n'est pas
    tranchée, l'audience `eef_interest` reste inutilisée.
- Route : **`/etudes-en-france`**. Jamais `/etudes-en-france/catalogue` : sur une
  build 49 à 53 ce lien tombe sur l'accueil.
- Brouillon par l'agent `kpb-notifications` ; **feu vert humain** obligatoire
  (plafond de 3 diffusions sur 7 jours glissants, fenêtre 8 h – 20 h). **L'agent et l'outil
  `kpb_draft_notification` contredisent encore la décision du 03/10** : l'agent ordonne
  d'exclure les pays suspendus, et l'outil avertit « Cette annonce vise Études en France sans
  exclure les pays suspendus ». L'avertissement est **attendu** ici : ne pas ajouter
  `exceptCountries`, et **donner la consigne explicitement à l'agent**
  (`docs/ouverture-espace-eef.md` § 4, « Ce que l'outillage dit encore »). La mise à jour de
  l'agent et de l'outil est une PR séparée.
- Ne pas promettre de catalogue plus fourni que ce qui est publié.

## Retour arrière

> Bulle et écoles privées ont leurs propres retours arrière (`eef-bubble-off`, `eef-private-schools-off`) : voir la section précédente. Fermer l'espace ne les ferme pas, mais sans espace ils n'affichent rien.

`vps-ops` → **`eef-space-off`** (pas de simulation, il agit tout de suite). Il
remet `KPB_EEF_SPACE_ENABLED=false` : les builds du hub (55) retombent sur la vitrine, les
49 à 53 n'ont jamais bougé. Les déclarations d'intérêt et les profils déjà saisis
restent en base ; rien n'est perdu.

## Après l'ouverture

| Quand | Quoi |
|---|---|
| J+1 | `eef_space_viewed`, `eef_hub_tile_opened`, `eef_catalog_searched`, `eef_help_card_shown` / `eef_help_cta_tapped` (taux de clic par `help_step`) (PostHog / Firebase) ; **`eef_catalog_failed` doit rester ≈ 0** (sinon une panne se lit « personne ne cherche »). Voir `docs/analytics-event-contract.md`. |
| J+1 | Admin → liste d'intérêt : les déclarations arrivent. `consentVersion = eef-consent-v1` se lit dans l'**export CSV** (`export.csv`), pas dans la liste. |
| J+7 | Ratio recherches sans résultat (`result_count = 0`) : croiser avec `catalog_published`. Beaucoup de `0` avec `catalog_published = 1` ⇒ le catalogue publié est trop étroit pour la demande : publier d'autres établissements. |
| Semaine 2 | Décider de la build suivante (fiche formation, sélection, checklist, projet d'études — numéro non décidé : la 55 est celle du hub) sur ces chiffres. |
