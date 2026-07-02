#!/usr/bin/env bash
# Restore a PostgreSQL dump produced by backup-loop.sh into the running `db`
# container. Run from the VPS host (next to docker-compose.yml).
#
#   Usage: POSTGRES_USER=... POSTGRES_DB=... ./backend/scripts/restore-db.sh ./backups/kpb-kpb_prod-YYYYMMDD-HHMMSSZ.sql.gz
#
# WARNING: this overwrites the current database contents. Stop the API first
# (docker-compose stop api) so nothing writes during the restore.
set -euo pipefail

FILE="${1:?usage: restore-db.sh <backup.sql.gz>}"
: "${POSTGRES_USER:?set POSTGRES_USER (same as your .env)}"
: "${POSTGRES_DB:=kpb}"
DB_CONTAINER="${DB_CONTAINER:-kpb_db}"

if [ ! -f "$FILE" ]; then
  echo "backup file not found: $FILE" >&2
  exit 1
fi

echo "Restoring $FILE into database '$POSTGRES_DB' (container $DB_CONTAINER)…"
gunzip -c "$FILE" | docker exec -i "$DB_CONTAINER" psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"
echo "Restore complete. Restart the API: docker-compose up -d api"
