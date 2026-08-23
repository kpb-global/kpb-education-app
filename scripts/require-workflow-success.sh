#!/usr/bin/env bash
# Require successful GitHub Actions workflow runs for one immutable commit.
#
# Usage:
#   GITHUB_TOKEN=... GITHUB_REPOSITORY=owner/repo \
#     scripts/require-workflow-success.sh <40-char-sha> workflow-a.yml [...]
#
# This deliberately queries runs by head_sha. A green run on `main` from an
# earlier commit is not release evidence for the commit being deployed.
set -euo pipefail

SHA="${1:-}"
shift || true

if [[ ! "$SHA" =~ ^[0-9a-f]{40}$ ]]; then
  echo "error: expected an immutable 40-character commit SHA, got '${SHA:-<empty>}'" >&2
  exit 2
fi
if [ "$#" -eq 0 ]; then
  echo "error: provide at least one workflow filename" >&2
  exit 2
fi
: "${GITHUB_REPOSITORY:?set GITHUB_REPOSITORY to owner/repository}"
: "${GITHUB_TOKEN:?set GITHUB_TOKEN so workflow evidence can be read}"
command -v gh >/dev/null || { echo "error: gh is required" >&2; exit 2; }
command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 2; }

failed=0
for workflow in "$@"; do
  response="$(gh api --method GET \
    -H 'Accept: application/vnd.github+json' \
    "/repos/${GITHUB_REPOSITORY}/actions/workflows/${workflow}/runs" \
    -f "head_sha=${SHA}" -f per_page=100)"

  latest_run="$(printf '%s' "$response" | jq -r '
    [.workflow_runs[] | select(.head_sha == $sha)]
    | sort_by(.updated_at)
    | last
    | if . == null then empty else [.id, .html_url, .event, (.conclusion // .status), .updated_at] | @tsv end
  ' --arg sha "$SHA")"

  if [ -z "$latest_run" ]; then
    echo "::error::${workflow} has no run for ${SHA}."
    failed=1
    continue
  fi

  IFS=$'\t' read -r run_id run_url event conclusion completed_at <<< "$latest_run"
  if [ "$conclusion" != "success" ]; then
    echo "::error::Latest ${workflow} run for ${SHA} is '${conclusion}', not success: ${run_url}"
    failed=1
    continue
  fi
  echo "${workflow}: success for ${SHA} (run ${run_id}, ${event}, ${completed_at})"
  echo "  ${run_url}"
done

if [ "$failed" -ne 0 ]; then
  echo "error: exact-SHA CI precondition failed; deployment is refused" >&2
  exit 1
fi

echo "Exact-SHA CI evidence is green for ${SHA}."
