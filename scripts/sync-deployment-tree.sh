#!/usr/bin/env bash
# Mirror one allowlisted deployment tree and prune files removed from source.
# Deletion is scoped to the destination tree; persistent runtime paths inside
# backend/admin are protected and the destination parent is never a delete root.
set -euo pipefail

TREE="${1:-}"
SOURCE="${2:-}"
DESTINATION="${3:-}"

usage() {
  echo "usage: $0 <backend|admin|web|scripts> <source-dir> <destination-tree/>" >&2
  exit 2
}

case "$TREE" in backend|admin|web|scripts) ;; *) usage ;; esac
[ -d "$SOURCE" ] || { echo "error: source directory not found: $SOURCE" >&2; exit 2; }
[ "$(basename "${SOURCE%/}")" = "$TREE" ] || {
  echo "error: source basename must equal allowlisted tree '$TREE': $SOURCE" >&2
  exit 2
}
[ -n "$DESTINATION" ] || usage

# For user@host:/path/tree/, inspect only the remote path portion. IPv6 remote
# syntax is deliberately unsupported here; deployment uses a DNS name/IPv4.
if [[ "$DESTINATION" == *:* ]]; then
  DEST_PATH="${DESTINATION#*:}"
else
  DEST_PATH="$DESTINATION"
fi
case "$DEST_PATH" in
  */"$TREE"/) ;;
  *)
    echo "error: destination must end in the exact allowlisted tree '/$TREE/': $DEST_PATH" >&2
    exit 2
    ;;
esac
case "$DEST_PATH" in
  *[[:space:]]*) echo "error: destination may not contain whitespace" >&2; exit 2 ;;
esac
case "$DEST_PATH" in
  *[!A-Za-z0-9_./-]*) echo "error: destination path contains unsupported characters" >&2; exit 2 ;;
esac
case "/${DEST_PATH#/}/" in
  */../*|*/./*) echo "error: destination may not contain '.' or '..' path components" >&2; exit 2 ;;
esac
PARENT="${DEST_PATH%/$TREE/}"
case "$PARENT" in
  ''|/|.) echo "error: refusing a deployment tree directly under a filesystem root" >&2; exit 2 ;;
esac

RSYNC_ARGS=(
  --archive
  --compress
  # Deploy correctness is content-based. Git checkouts and fast CI fixtures can
  # produce changed files with the same size and second-level mtime as the VPS
  # copy; rsync's default quick check would silently leave the stale bytes.
  --checksum
  --delete-delay
  --itemize-changes
  --human-readable
  --safe-links
  --omit-dir-times
)
if [ -n "${KPB_RSYNC_RSH:-}" ]; then
  RSYNC_ARGS+=(--rsh "$KPB_RSYNC_RSH")
fi

protect_runtime_path() {
  # P = receiver-side deletion protection; - = do not transfer local runtime
  # material. Both are explicit so a later rsync-option change cannot turn an
  # excluded secret/cache into a deletion candidate.
  RSYNC_ARGS+=(--filter "P $1" --filter "- $1")
}

if [ "$TREE" = backend ] || [ "$TREE" = admin ]; then
  # Ship tracked example templates, but preserve/exclude every real env variant
  # (.env, .env.production, .env.local, future provider-specific names, etc.).
  RSYNC_ARGS+=(--filter '+ /.env*.example')
  protect_runtime_path '/.env*'
  protect_runtime_path '/node_modules/'
  protect_runtime_path '/.npm/'
  protect_runtime_path '/.cache/'
  protect_runtime_path '/.pnpm-store/'
  protect_runtime_path '/.yarn/'
  protect_runtime_path '/logs/'
fi
if [ "$TREE" = backend ]; then
  protect_runtime_path '/backups/'
  protect_runtime_path '/uploads/'
  protect_runtime_path '/storage/'
fi
if [ "$TREE" = admin ]; then
  protect_runtime_path '/.next/cache/'
fi

echo "Syncing allowlisted tree '$TREE' to '$DEST_PATH' (scoped prune enabled)."
rsync "${RSYNC_ARGS[@]}" "${SOURCE%/}/" "$DESTINATION"
