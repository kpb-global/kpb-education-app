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
docker compose exec api npm run catalog:import -- --dry-run
docker compose exec api npm run catalog:import -- --apply
docker compose exec api npm run catalog:switch -- --dry-run --confirmed-only
docker compose exec api npm run catalog:switch -- --apply --confirmed-only
```

**Pourquoi `switch` et pas `publish` puis `deactivate-legacy`.** `switch` fait les
deux dans une seule transaction, en publiant avant de dépublier : il n'existe
donc aucun instant où l'onglet Bourses est vide pour les utilisateurs. Lancées
séparément, les deux commandes laissent une fenêtre.

**Pourquoi `--confirmed-only` par défaut aujourd'hui.** Une build déjà distribuée
peut ne pas savoir afficher une date estimée autrement que comme une date ferme.
Publier d'abord les seules fiches à dates confirmées évite de faire mentir une
app en circulation. Les fiches estimées se publient avec la build qui sait les
présenter, en relançant `catalog:publish --apply` sans le drapeau.

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
