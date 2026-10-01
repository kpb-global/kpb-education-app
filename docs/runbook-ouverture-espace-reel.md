# Runbook — ouvrir l'espace « Études en France » réel aux étudiants

> **Ce que ce runbook couvre.** Le passage de l'état de lancement (vitrine
> « en préparation » + notifications) à l'espace réel (hub, catalogue, profil) pour
> la build **2.3.0 (54)** et suivantes. Il complète `docs/cutover-build49.md`
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
| 1 | **La 54 est en vente sur les deux stores** et adoptée par la majorité | App Store Connect / Play Console ; PostHog (version de l'app). Tant que la 54 n'est pas majoritaire, ouvrir l'espace ne profite qu'à une minorité — les 49 à 53 gardent la vitrine. |
| 2 | **Le backend est au SHA `95440db` ou plus récent** | `GET /api/health/version` → `sha` ; `deploy.yml` `scope=full`. Migration additive `20260930120000_eef_search_text_and_acronym` (`Program.searchText`, `Institution.acronym`) : `prisma migrate status` ne liste rien en attente. |
| 3 | **Le catalogue est importé** (lignes inactives) et ses index sont remplis | `vps-ops` → `eef-import` : d'abord `dry_run` coché (lit les 4 passes : import, cycles, admission, **recherche**), puis décoché. Un second passage ne doit plus rien créer. |
| 4 | **Au moins un établissement relu est publié** (le pilote) | Admin → « Publication EEF » : plan → simulation → application, sous le nom du vérificateur. `GET /api/etudes-en-france/search` → `total > 0`. `.github/scripts/db-info.sql` §11 donne le décompte. |
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

## Inviter à mettre à jour (facultatif, quand la 54 est disponible partout)

`recommended-version-set` (valeur écrite dans `.github/scripts/vps-ops.sh`,
`RECOMMENDED_APP_VERSION`, relue en PR) → un bandeau **qu'on ferme** apparaît sur
l'accueil des builds plus anciennes, avec le lien du store. **`KPB_MIN_APP_VERSION`
n'est pas touché** : relever `minVersion` bloque l'app derrière un écran sans
sortie, et ne se fait qu'après la 54 à ~100 %.

## Annoncer l'ouverture

- Audience : **`eef_interest`** (ceux qui ont déclaré leur intérêt) avec
  `{"exceptCountries": ["eef_suspended"]}` ; à défaut `all_students_except_countries`
  avec le même filtre. **Jamais `country`** : il filtre sur le pays de résidence.
- Route : **`/etudes-en-france`**. Jamais `/etudes-en-france/catalogue` : sur une
  build 49 à 53 ce lien tombe sur l'accueil.
- Brouillon par l'agent `kpb-notifications` ; **feu vert humain** obligatoire
  (plafond de 3 diffusions sur 7 jours glissants, fenêtre 8 h – 20 h).
- Ne pas promettre de catalogue plus fourni que ce qui est publié.

## Retour arrière

`vps-ops` → **`eef-space-off`** (pas de simulation, il agit tout de suite). Il
remet `KPB_EEF_SPACE_ENABLED=false` : les builds 54 retombent sur la vitrine, les
49 à 53 n'ont jamais bougé. Les déclarations d'intérêt et les profils déjà saisis
restent en base ; rien n'est perdu.

## Après l'ouverture

| Quand | Quoi |
|---|---|
| J+1 | `eef_space_viewed`, `eef_hub_tile_opened`, `eef_catalog_searched` (PostHog / Firebase) ; **`eef_catalog_failed` doit rester ≈ 0** (sinon une panne se lit « personne ne cherche »). Voir `docs/analytics-event-contract.md`. |
| J+1 | Admin → liste d'intérêt : les déclarations arrivent avec `consentVersion = eef-consent-v1`. |
| J+7 | Ratio recherches sans résultat (`result_count = 0`) : croiser avec `catalog_published`. Beaucoup de `0` avec `catalog_published = 1` ⇒ le catalogue publié est trop étroit pour la demande : publier d'autres établissements. |
| Semaine 2 | Décider de la build 55 (fiche formation, sélection, checklist, projet d'études) sur ces chiffres. |
