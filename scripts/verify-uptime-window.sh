#!/usr/bin/env bash
# Prove a continuous window from completed scheduled uptime workflow runs.
set -euo pipefail

HOURS="${STABILITY_HOURS:-24}"
MIN_SUCCESS="${STABILITY_MIN_SUCCESS:-80}"
MAX_GAP_MINUTES="${STABILITY_MAX_GAP_MINUTES:-30}"
WORKFLOW="${UPTIME_WORKFLOW:-uptime.yml}"

: "${GITHUB_REPOSITORY:?set GITHUB_REPOSITORY to owner/repository}"
: "${GITHUB_TOKEN:?set GITHUB_TOKEN so uptime evidence can be read}"
command -v gh >/dev/null || { echo "error: gh is required" >&2; exit 2; }
command -v python3 >/dev/null || { echo "error: python3 is required" >&2; exit 2; }

case "$HOURS:$MIN_SUCCESS:$MAX_GAP_MINUTES" in
  *[!0-9:]*|:*|*:) echo "error: stability limits must be positive integers" >&2; exit 2 ;;
esac

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
gh api -H 'Accept: application/vnd.github+json' \
  "/repos/${GITHUB_REPOSITORY}/actions/workflows/${WORKFLOW}/runs?event=schedule&status=completed&per_page=100" > "$tmp"

python3 - "$tmp" "$HOURS" "$MIN_SUCCESS" "$MAX_GAP_MINUTES" <<'PY'
import datetime as dt
import json
import sys

path, hours_raw, minimum_raw, gap_raw = sys.argv[1:]
hours, minimum, max_gap_minutes = map(int, (hours_raw, minimum_raw, gap_raw))
now = dt.datetime.now(dt.timezone.utc)
cutoff = now - dt.timedelta(hours=hours)

with open(path, encoding="utf-8") as handle:
    runs = json.load(handle).get("workflow_runs", [])

scheduled = []
for run in runs:
    if run.get("event") != "schedule":
        continue
    stamp = run.get("run_started_at") or run.get("created_at")
    if not stamp:
        continue
    started = dt.datetime.fromisoformat(stamp.replace("Z", "+00:00"))
    if started >= cutoff:
        scheduled.append((started, run))
scheduled.sort(key=lambda item: item[0])

bad = [(started, run) for started, run in scheduled if run.get("conclusion") != "success"]
successes = [(started, run) for started, run in scheduled if run.get("conclusion") == "success"]
if bad:
    for started, run in bad:
        print(f"error: uptime run {run.get('html_url')} at {started.isoformat()} concluded {run.get('conclusion') or run.get('status')}", file=sys.stderr)
    sys.exit(1)
if len(successes) < minimum:
    print(f"error: only {len(successes)} successful scheduled probes in {hours}h; require at least {minimum}", file=sys.stderr)
    sys.exit(1)

points = [cutoff] + [started for started, _ in successes] + [now]
largest = max((b - a for a, b in zip(points, points[1:])), default=dt.timedelta.max)
if largest > dt.timedelta(minutes=max_gap_minutes):
    print(f"error: largest uncovered uptime interval is {largest.total_seconds() / 60:.1f} minutes; maximum is {max_gap_minutes}", file=sys.stderr)
    sys.exit(1)

print(f"UPTIME STABILITY OK: {len(successes)} successful scheduled probes, no failures, largest gap {largest.total_seconds() / 60:.1f}m across {hours}h.")
print(f"window_utc={cutoff.isoformat()}..{now.isoformat()}")
PY
