#!/usr/bin/env bash
# LIV-T14 — les curls de production qui décident si le dernier déploiement
# backend a réellement atterri. À lancer APRÈS un déploiement VPS, jamais
# depuis la PR d'un lot.
#
# Cinq contrôles. Le 5e couvre l'espace « Études en France » : il est arrivé
# avec la build 49 et le déploiement couplé (docs/cutover-build49.md, étape 9).
#
# CAT-T4 (`dateConfidence` on catalog scholarships) is a backend-deploy
# check: unit tests going green on main do not prove prod is serving it.
set -euo pipefail

BASE="${KPB_API_BASE_URL:-https://api.kpbeducation.cloud/api}"

echo "== 1. Catalogue legacy : source=database =="
curl -fsS "${BASE}/catalog/scholarships" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('source')=='database', d.get('source'); print('source=', d['source'], 'n=', len(d.get('items') or []))"

echo "== 2. Compression gzip (Accept-Encoding) =="
headers="$(mktemp)"
curl -fsS -D "$headers" -o /dev/null \
  -H 'Accept-Encoding: gzip' \
  "${BASE}/catalog/scholarships"
if ! grep -qi '^content-encoding: gzip' "$headers"; then
  echo "MISSING content-encoding: gzip" >&2
  cat "$headers" >&2
  rm -f "$headers"
  exit 1
fi
grep -i '^content-encoding:' "$headers"
rm -f "$headers"

echo "== 3. CAT-T4 dateConfidence (exige le backend déployé) =="
curl -fsS "${BASE}/catalog/scholarships" \
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
curl -fsS "${BASE}/health" \
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
curl -fsS "${BASE}/config/app" \
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

code="$(curl -sS -o /dev/null -w '%{http_code}' "${BASE}/etudes-en-france/interest")"
case "$code" in
  401|403) echo "route d'intérêt montée et gardée (HTTP $code)" ;;
  404)     echo "HTTP 404 — le module etudes-en-france n'est PAS monté : l'ancienne image tourne encore" >&2; exit 1 ;;
  200)     echo "HTTP 200 sans jeton — la route n'est PAS gardée, c'est une fuite" >&2; exit 1 ;;
  *)       echo "HTTP $code inattendu sur la route d'intérêt" >&2; exit 1 ;;
esac

echo "LIV-T14 OK"
