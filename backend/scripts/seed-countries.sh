#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is not set. Export it or create backend/.env first." >&2
  exit 1
fi

# psql does not accept Prisma-only query params like schema=public.
PSQL_URL="$(printf '%s' "$DATABASE_URL" | sed -E 's/[?&]schema=[^&]*//g' | sed -E 's/\?&/?/g')"

psql "$PSQL_URL" -f "$(dirname "$0")/seed-kpb-countries.sql"
