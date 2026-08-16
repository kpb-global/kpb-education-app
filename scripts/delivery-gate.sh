#!/usr/bin/env bash
# LIV-T14 — four production curls that decide whether the last backend
# deploy actually landed. Run AFTER a VPS deploy, never from a lot PR.
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

echo "LIV-T14 OK"
