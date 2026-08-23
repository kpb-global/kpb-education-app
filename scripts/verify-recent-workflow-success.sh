#!/usr/bin/env bash
# Require a recent successful run of an operational GitHub Actions workflow.
set -euo pipefail

WORKFLOW="${1:?usage: $0 WORKFLOW_FILE [MAX_AGE_HOURS]}"
MAX_AGE_HOURS="${2:-8}"
RUN_NAME_CONTAINS="${RUN_NAME_CONTAINS:-}"
: "${GITHUB_REPOSITORY:?set GITHUB_REPOSITORY to owner/repository}"
: "${GITHUB_TOKEN:?set GITHUB_TOKEN so workflow evidence can be read}"
case "$MAX_AGE_HOURS" in *[!0-9]*|'') echo "error: MAX_AGE_HOURS must be an integer" >&2; exit 2 ;; esac

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
gh api -H 'Accept: application/vnd.github+json' \
  "/repos/${GITHUB_REPOSITORY}/actions/workflows/${WORKFLOW}/runs?status=completed&per_page=20" > "$tmp"

python3 - "$tmp" "$WORKFLOW" "$MAX_AGE_HOURS" "$RUN_NAME_CONTAINS" <<'PY'
import datetime as dt
import json
import sys

path, workflow, max_hours_raw, name_filter = sys.argv[1:]
max_age = dt.timedelta(hours=int(max_hours_raw))
now = dt.datetime.now(dt.timezone.utc)
with open(path, encoding="utf-8") as handle:
    runs = json.load(handle).get("workflow_runs", [])
if name_filter:
    runs = [run for run in runs if name_filter in (run.get("display_title") or run.get("name") or "")]
if not runs:
    suffix = f" whose run name contains {name_filter!r}" if name_filter else ""
    print(f"error: {workflow} has no completed run{suffix}", file=sys.stderr)
    sys.exit(1)
latest = max(runs, key=lambda run: run.get("updated_at") or "")
if latest.get("conclusion") != "success":
    print(f"error: newest completed {workflow} run concluded {latest.get('conclusion')}", file=sys.stderr)
    print(latest.get("html_url", ""), file=sys.stderr)
    sys.exit(1)
completed = dt.datetime.fromisoformat(latest["updated_at"].replace("Z", "+00:00"))
age = now - completed
if age > max_age:
    print(f"error: newest successful {workflow} run is {age.total_seconds()/3600:.1f}h old; maximum is {max_age.total_seconds()/3600:.1f}h", file=sys.stderr)
    print(latest.get("html_url", ""), file=sys.stderr)
    sys.exit(1)
print(f"RECENT WORKFLOW OK: {workflow} succeeded {age.total_seconds()/3600:.1f}h ago")
print(latest.get("html_url", ""))
PY
