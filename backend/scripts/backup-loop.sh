#!/bin/sh
# Continuous PostgreSQL backup loop, run by the `db-backup` service in
# docker-compose.yml (image: postgres:15-alpine, so pg_dump + gzip are present).
#
# Produces one gzipped dump per interval into $BACKUP_DIR (a host bind mount so
# the dumps survive `docker-compose down -v`, which would otherwise wipe named
# volumes), and prunes dumps older than $BACKUP_KEEP_DAYS.
#
# Connection uses the standard libpq env vars (PGHOST/PGUSER/PGPASSWORD/PGDATABASE)
# injected by docker-compose.
#
# NOTE: this protects against volume corruption, accidental drops and `down -v`,
# but NOT against loss of the whole VPS. Copy $BACKUP_DIR off-site as well
# (see docs/DEPLOYMENT.md, section "Sauvegardes").
set -eu

: "${PGDATABASE:=kpb}"
: "${BACKUP_DIR:=/backups}"
: "${BACKUP_KEEP_DAYS:=14}"
: "${BACKUP_INTERVAL_SECONDS:=86400}" # daily

mkdir -p "$BACKUP_DIR"

log() { echo "[db-backup] $(date -u +%FT%TZ) $*"; }

while true; do
  ts=$(date -u +%Y%m%d-%H%M%SZ)
  out="$BACKUP_DIR/kpb-${PGDATABASE}-${ts}.sql.gz"
  log "dumping database '$PGDATABASE' -> $out"
  if pg_dump --no-owner --no-privileges "$PGDATABASE" | gzip -9 > "$out.tmp"; then
    mv "$out.tmp" "$out"
    log "backup ok ($(du -h "$out" | cut -f1))"
  else
    log "ERROR: pg_dump failed, keeping previous backups"
    rm -f "$out.tmp"
  fi

  # Retention: remove dumps older than BACKUP_KEEP_DAYS.
  find "$BACKUP_DIR" -name 'kpb-*.sql.gz' -type f -mtime +"$BACKUP_KEEP_DAYS" -delete 2>/dev/null || true

  sleep "$BACKUP_INTERVAL_SECONDS"
done
