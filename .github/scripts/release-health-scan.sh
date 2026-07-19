#!/usr/bin/env bash
# release-health-scan.sh — org-wide release-staleness + failure tripwire.
#
# WHY THIS EXISTS: in May-July 2026 the entire plures org silently stopped
# releasing for ~2 months (a shared-workflow migration dropped highest-tag
# reconciliation + the trigger). NOTHING alerted. This scan is the missing
# tripwire: it flags, for every non-archived repo, either
#   (a) STALE  — there are releasable conventional commits on the default
#                branch since the last tag, but no release/tag was cut, or
#   (b) FAILED — the most recent Release workflow run concluded 'failure'.
# Output is a compact report; the calling workflow alerts on any non-empty
# STALE/FAILED set. Read-only: no writes, no merges.
#
# Env: GH_TOKEN must be set. Optional: STALE_DAYS (default 14).
# Per-repo API calls may transiently fail or return non-zero (missing file,
# empty tag list); we must NOT abort the whole org scan on one repo. So we
# deliberately do NOT use `set -e` here — each step has its own `|| default`.
set -uo pipefail

# Pure decision logic (count_releasable / is_stale / is_failed_run + the
# RELEASABLE_RE single-source-of-truth) lives in the sibling lib so it can be
# unit-tested without live API calls. See release-health-selftest.sh.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./release-health-lib.sh
. "$SCRIPT_DIR/release-health-lib.sh"

STALE_DAYS="${STALE_DAYS:-14}"
NOW_EPOCH=$(date -u +%s)
STALE_SECS=$(( STALE_DAYS * 86400 ))

# Conventional-commit types that SHOULD produce a release are defined once in
# the lib as RELEASABLE_RE (sourced above).

stale_list=""
failed_list=""
ok_count=0
skip_count=0

# Enumerate non-archived repos that actually have a release workflow.
repos=$(gh repo list plures --limit 200 --no-archived --json name --jq '.[].name')

for r in $repos; do
  # Must have a release.yml to be release-bearing; else skip.
  if ! gh api "repos/plures/$r/contents/.github/workflows/release.yml" --silent 2>/dev/null; then
    skip_count=$((skip_count+1)); continue
  fi

  default_branch=$(gh api "repos/plures/$r" --jq '.default_branch' 2>/dev/null || echo main)

  # Most recent Release run conclusion.
  run_concl=$(gh run list --repo "plures/$r" --workflow Release -L 1 --json conclusion --jq '.[0].conclusion' 2>/dev/null || echo "")
  if [ "$(is_failed_run "$run_concl")" = "1" ]; then
    failed_list="${failed_list}  - ${r}: last Release run FAILED\n"
  fi

  # Highest existing vX.Y.Z tag + its date.
  last_tag=$(gh api "repos/plures/$r/tags?per_page=100" --jq '[.[].name | select(test("^v[0-9]+[.][0-9]+[.][0-9]+$"))] | .[0]' 2>/dev/null || echo "")
  if [ -z "$last_tag" ] || [ "$last_tag" = "null" ]; then
    # No tags yet — only stale if there are releasable commits at all.
    last_tag=""
  fi

  # Count releasable commits on default branch since last tag.
  if [ -n "$last_tag" ]; then
    compare=$(gh api "repos/plures/$r/compare/${last_tag}...${default_branch}" --jq '[.commits[].commit.message] | .[]' 2>/dev/null || echo "")
  else
    compare=$(gh api "repos/plures/$r/commits?sha=${default_branch}&per_page=50" --jq '[.[].commit.message] | .[]' 2>/dev/null || echo "")
  fi

  releasable=$(count_releasable "$compare")

  # Date of the last release (fallback: last tag's commit date).
  last_rel_date=$(gh release view --repo "plures/$r" --json publishedAt --jq '.publishedAt' 2>/dev/null || echo "")
  if [ -n "$last_rel_date" ] && [ "$last_rel_date" != "null" ]; then
    rel_epoch=$(date -u -d "$last_rel_date" +%s 2>/dev/null || echo "$NOW_EPOCH")
  else
    rel_epoch=0
  fi
  age_days=$(( (NOW_EPOCH - rel_epoch) / 86400 ))

  if [ "$(is_stale "$releasable" "$NOW_EPOCH" "$rel_epoch" "$STALE_SECS")" = "1" ]; then
    stale_list="${stale_list}  - ${r}: ${releasable} releasable commit(s) since ${last_tag:-<no tag>}, last release ${age_days}d ago\n"
  else
    ok_count=$((ok_count+1))
  fi
done

echo "## Release health scan (STALE_DAYS=${STALE_DAYS})"
echo ""
if [ -n "$failed_list" ]; then
  echo "### ❌ Recent Release run FAILED"
  printf '%b' "$failed_list"
  echo ""
fi
if [ -n "$stale_list" ]; then
  echo "### ⏰ STALE (releasable commits, no recent release)"
  printf '%b' "$stale_list"
  echo ""
fi
if [ -z "$failed_list" ] && [ -z "$stale_list" ]; then
  echo "### ✅ All release-bearing repos healthy"
fi
echo "_ok=${ok_count} skipped(no release.yml)=${skip_count}_"

# Emit machine-readable signal for the workflow to decide alerting.
stale_n=$(printf '%b' "$stale_list" | grep -c '^  - ' || true)
failed_n=$(printf '%b' "$failed_list" | grep -c '^  - ' || true)
{
  echo "stale_count=${stale_n:-0}"
  echo "failed_count=${failed_n:-0}"
} >> "${GITHUB_OUTPUT:-/dev/stderr}"
