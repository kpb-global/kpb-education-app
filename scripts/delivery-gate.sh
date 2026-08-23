#!/usr/bin/env bash
# LIV-T14 — les curls de production qui décident si le dernier déploiement
# backend a réellement atterri. À lancer APRÈS un déploiement VPS, jamais
# depuis la PR d'un lot.
#
# Six contrôles. Le 5e couvre l'espace « Études en France » : il est arrivé
# avec la build 49 et le déploiement couplé (docs/cutover-build49.md, étape 9).
# Le 6e lie ces preuves publiques au SHA immuable choisi par le déploiement.
#
# CAT-T4 (`dateConfidence` on catalog scholarships) is a backend-deploy
# check: unit tests going green on main do not prove prod is serving it.
set -euo pipefail

BASE="${KPB_API_BASE_URL:-https://api.kpbeducation.cloud/api}"
EXPECTED_BUILD_SHA="${KPB_EXPECTED_BUILD_SHA:-}"
CURL_ARGS=(--fail --silent --show-error --retry 2 --retry-delay 3 \
  --retry-all-errors --connect-timeout 10 --max-time 30)

fetch() {
  curl "${CURL_ARGS[@]}" "$@"
}

echo "== 1. Catalogue legacy : source=database =="
fetch "${BASE}/catalog/scholarships" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('source')=='database', d.get('source'); print('source=', d['source'], 'n=', len(d.get('items') or []))"

echo "== 2. Compression gzip (Accept-Encoding) =="
headers="$(mktemp)"
trap 'rm -f "$headers"' EXIT
fetch -D "$headers" -o /dev/null \
  -H 'Accept-Encoding: gzip' \
  "${BASE}/catalog/scholarships"
if ! grep -qi '^content-encoding: gzip' "$headers"; then
  echo "MISSING content-encoding: gzip" >&2
  cat "$headers" >&2
  exit 1
fi
grep -i '^content-encoding:' "$headers"

echo "== 3. CAT-T4 dateConfidence (exige le backend déployé) =="
fetch "${BASE}/catalog/scholarships" \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)
items = data.get('items') or []
assert items, 'catalogue vide'
sample = items[0]
has = 'dateConfidence' in sample or any(
    isinstance(c, dict) and 'dateConfidence' in c
    for c in (sample.get('cycles') or [])
)
assert has, 'dateConfidence absent — CAT-T4 pas en prod'
print('dateConfidence present on first item')
"

echo "== 4. Health ai.configured (boolean, never the key) =="
fetch "${BASE}/health" \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
ai = d.get('ai') or {}
assert isinstance(ai.get('configured'), bool), ai
assert 'GROQ' not in json.dumps(d)
print('ai.configured=', ai['configured'])
"

echo "== 5. Espace « Études en France » : le module est en ligne =="
# Deux preuves distinctes, parce qu'elles peuvent échouer séparément.
#
# (a) /config/app porte les clés EEF. On teste leur PRÉSENCE, jamais leur
#     valeur : `eefTeaser: false` est un état parfaitement normal — c'est
#     l'état par défaut, avant que l'exploitation ait posé la variable. Un
#     `assert d['features']['eefTeaser']` aurait donc rougi sur un déploiement
#     parfaitement réussi, et c'est le genre de garde qu'on finit par
#     désactiver.
#
# (b) la route d'intérêt répond 401, pas 404. C'est la seule façon de prouver
#     que le module est ENREGISTRÉ sans détenir de session étudiante : 404 = le
#     module n'est pas monté (l'ancienne image tourne encore), 401 = il est
#     monté et gardé. Un `curl -f` refuserait les deux ; on lit donc le code.
fetch "${BASE}/config/app" \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
features = d.get('features') or {}
for key in ('eefTeaser', 'eef'):
    assert key in features, f'features.{key} absent — ancienne image en prod'
campaign = d.get('eefCampaign')
assert isinstance(campaign, dict), f'eefCampaign absent ou mal typé: {campaign!r}'
for key in ('opensAt', 'closesAt', 'suspendedCountries'):
    assert key in campaign, f'eefCampaign.{key} absent'
print('features.eefTeaser=', features['eefTeaser'], '· features.eef=', features['eef'])
print('eefCampaign.opensAt=', campaign['opensAt'])
print('eefCampaign.suspendedCountries=', campaign['suspendedCountries'])
"

# Une sonde de route, avec les trois pièges nommés.
#
# ## Ce que 401 prouve, et pourquoi 403 ne prouve rien
#
# `StudentAuthGuard` et `AdminAuthGuard` lèvent tous deux une
# `UnauthorizedException` — donc **401**. Un 403 ne vient PAS de l'application
# sur ces routes : il viendrait d'un WAF ou d'un proxy inverse répondant 403 à
# toute requête sans cookie. Or un tel intermédiaire répond 403 pour un chemin
# INEXISTANT aussi, ce qui détruit la logique « 404 = pas monté ». Accepter 403
# revenait donc à accepter la réponse qui ne distingue rien.
#
# ## 429 n'est pas un échec
#
# `ThrottlerGuard` est global (60/min en production) et s'évalue avant tout. Un
# 429 dit « on n'a pas pu conclure », pas « le module n'est pas déployé ».
# L'ancienne version tombait dans la branche d'erreur et annonçait un
# déploiement manquant alors que tout allait bien.
probe_route() {
  local label="$1" path="$2" attempt code
  for attempt in 1 2 3; do
    code="$(curl --silent --show-error --connect-timeout 10 --max-time 30 \
      -o /dev/null -w '%{http_code}' "${BASE}${path}")"
    case "$code" in
      401)
        echo "  ${label} : montée et gardée (HTTP 401)"
        return 0
        ;;
      404)
        echo "MANQUE : ${label} rend 404 — le module n'est PAS monté, l'ancienne image tourne encore" >&2
        return 1
        ;;
      200)
        echo "FUITE : ${label} rend 200 SANS jeton — la route n'est pas gardée" >&2
        return 1
        ;;
      403)
        echo "REFUS : ${label} rend 403. L'application lève 401 sur ces routes ; un 403" >&2
        echo "        vient d'un WAF ou d'un proxy, qui répondrait 403 pour un chemin" >&2
        echo "        inexistant aussi — donc cette sonde ne prouverait plus rien." >&2
        return 1
        ;;
      429)
        # Non concluant, pas un échec. On laisse la fenêtre du limiteur s'écouler.
        echo "  ${label} : HTTP 429 (limiteur), tentative ${attempt}/3 — on patiente"
        sleep 20
        ;;
      *)
        echo "MANQUE : ${label} rend HTTP ${code}, inattendu" >&2
        return 1
        ;;
    esac
  done
  echo "NON CONCLUANT : ${label} a rendu 429 trois fois. Le limiteur masque la" >&2
  echo "                réponse ; relancer plus tard plutôt que conclure." >&2
  return 1
}

# La route étudiante ET une route admin. Les deux contrôleurs sont enregistrés
# sur deux lignes distinctes d'app.module.ts : perdre la seconde dans une
# résolution de merge laisserait la première verte et la page du back-office
# en 404.
probe_route "route d'intérêt" "/etudes-en-france/interest"
probe_route "route admin"     "/admin/etudes-en-france/interest"

# ── Ce que le contrôle 5 NE prouve PAS, et où c'est prouvé ────────────────
#
# Que la table `EefInterest` existe. Les gardes s'exécutent AVANT le handler,
# donc un 401 n'atteint aucun code de service et aucune requête SQL : si
# `prisma migrate deploy` n'avait pas tourné, cette sonde passerait quand même
# et la première déclaration d'un étudiant partirait en 500 de schéma.
#
# On ne comble pas ce trou ici, et c'est délibéré : `deploy.yml` lance lui-même
# `prisma migrate deploy` PUIS `prisma migrate status` dans le même job. C'est
# la preuve autoritaire, faite au bon endroit et par le processus qui applique
# la migration. Ajouter ici une sonde plus faible pour la même question
# donnerait deux réponses dont une moins fiable — et c'est la moins fiable
# qu'on lirait, puisqu'elle est dans le portail.
#
# Ce que ce contrôle prouve exactement : l'image DÉPLOYÉE sert les clés EEF de
# /config/app, et les deux contrôleurs du module sont montés et gardés.

echo "== 6. Empreinte immuable du build (/health/version) =="
version="$(fetch "${BASE}/health/version")"
deployed="$(printf '%s' "$version" | python3 -c "import json,sys; print(json.load(sys.stdin).get('sha',''))")"
if [[ ! "$deployed" =~ ^[0-9a-f]{12}$ ]]; then
  echo "build de production invalide ou non estampillé : '${deployed:-vide}'" >&2
  exit 1
fi
if [ -n "$EXPECTED_BUILD_SHA" ] && [ "$deployed" != "${EXPECTED_BUILD_SHA:0:12}" ]; then
  echo "production sert $deployed ; SHA attendu ${EXPECTED_BUILD_SHA:0:12}" >&2
  exit 1
fi
echo "deployed sha=$deployed"

echo "LIV-T14 OK"
