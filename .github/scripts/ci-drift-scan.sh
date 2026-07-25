#!/usr/bin/env bash
# ci-drift-scan.sh — org-wide CI-workflow drift sweep.
#
# WHY THIS EXISTS: a one-time audit (github-actions:ci-lockin-reduction epic,
# PR plures/.github#21) found 20 repos with a non-reusable ci.yml and 5 with
# a non-reusable release.yml across the org. That was a snapshot. Nothing
# stops a repo from drifting back to a local copy, or from being pinned to a
# stale/wrong ref of ci-reusable.yml after it changes. This script is the
# ONGOING (daily) sweep: for every non-archived org repo with a
# .github/workflows/ci.yml, classify it as:
#   OK        — delegates via workflow_call to ci-reusable.yml@main
#   LOCAL     — has its own non-delegating copy (full drift)
#   STALE_REF — delegates, but pinned to a ref other than @main
# Read-only against target repos. Mirrors release-health-scan.sh's shape
# (same lib/scan/selftest split, same GITHUB_OUTPUT contract) so the calling
# workflow can alert identically.
#
# Env: GH_TOKEN must be set. Optional: ORG (default plures).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-drift-lib.sh
. "$SCRIPT_DIR/ci-drift-lib.sh"

ORG="${ORG:-plures}"

local_list=""
stale_list=""
ok_count=0
skip_count=0

# .github itself hosts the canonical template and is not expected to consume
# it (chicken/egg). Skip it explicitly.
SKIP_REPOS=".github"

repos=$(gh repo list "$ORG" --limit 200 --no-archived --json name --jq '.[].name')

for r in $repos; do
  case " $SKIP_REPOS " in
    *" $r "*) continue ;;
  esac

  content_b64=$(gh api "repos/${ORG}/${r}/contents/.github/workflows/ci.yml" --jq '.content' 2>/dev/null || echo "")
  if [ -z "$content_b64" ] || [ "$content_b64" = "null" ]; then
    skip_count=$((skip_count+1)); continue
  fi

  # Decode in-process (never pipe through a shell display layer — see
  # TOOLS.md gh api --jq '.content' display-wrap gotcha).
  content=$(printf '%s' "$content_b64" | tr -d '\n' | base64 -d 2>/dev/null || echo "")
  if [ -z "$content" ]; then
    skip_count=$((skip_count+1)); continue
  fi

  result=$(classify "$content")
  case "$result" in
    OK)
      ok_count=$((ok_count+1))
      ;;
    LOCAL)
      local_list="${local_list}  - ${r}: local non-delegating ci.yml\n"
      ;;
    STALE_REF:*)
      ref="${result#STALE_REF:}"
      stale_list="${stale_list}  - ${r}: pinned to @${ref} (canonical is @main)\n"
      ;;
  esac
done

echo "## CI-workflow drift scan (org=${ORG})"
echo ""
if [ -n "$local_list" ]; then
  echo "### 🔴 LOCAL — non-delegating ci.yml (full drift)"
  printf '%b' "$local_list"
  echo ""
fi
if [ -n "$stale_list" ]; then
  echo "### 🟡 STALE_REF — delegating but pinned off @main"
  printf '%b' "$stale_list"
  echo ""
fi
if [ -z "$local_list" ] && [ -z "$stale_list" ]; then
  echo "### ✅ All ci.yml-bearing repos delegate to ci-reusable.yml@main"
fi
echo "_ok=${ok_count} skipped(no ci.yml)=${skip_count}_"

local_n=$(printf '%b' "$local_list" | grep -c '^  - ' || true)
stale_n=$(printf '%b' "$stale_list" | grep -c '^  - ' || true)
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "local_count=${local_n:-0}"
    echo "stale_count=${stale_n:-0}"
  } >> "$GITHUB_OUTPUT"
else
  echo "local_count=${local_n:-0} stale_count=${stale_n:-0}" >&2
fi
