#!/usr/bin/env bash
# ci-drift-lib.sh — pure decision logic for the CI-workflow drift sweep.
#
# Extracted from ci-drift-scan.sh so it can be unit-tested without live API
# calls (see ci-drift-selftest.sh). No I/O here — only string/logic helpers.
set -uo pipefail

# The canonical delegating line every repo's .github/workflows/ci.yml is
# expected to contain, e.g.:
#   uses: plures/.github/.github/workflows/ci-reusable.yml@main
# Repos MAY pin to a specific tag/sha instead of @main; that is only "drift"
# if the ref does not match CANON_REF (see is_stale_ref below).
CANON_REUSABLE_PATH="plures/.github/.github/workflows/ci-reusable.yml"
CANON_REF="main"

# is_delegating CONTENT
# Returns "1" if the given ci.yml content contains a `uses:` line that points
# at the canonical reusable workflow (any ref), else "0".
is_delegating() {
  local content="$1"
  if printf '%s' "$content" | grep -Eq "uses:[[:space:]]*${CANON_REUSABLE_PATH//\//\\/}@"; then
    echo "1"
  else
    echo "0"
  fi
}

# extract_ref CONTENT
# Pulls the ref (branch/tag/sha) pinned after the @ on the uses: line.
# Echoes empty string if not delegating.
extract_ref() {
  local content="$1"
  printf '%s' "$content" \
    | grep -E "uses:[[:space:]]*${CANON_REUSABLE_PATH//\//\\/}@" \
    | head -n1 \
    | sed -E "s#.*${CANON_REUSABLE_PATH//\//\\/}@([^[:space:]\"']+).*#\1#"
}

# is_stale_ref REF
# A ref is "stale/wrong" drift if it is non-empty and NOT the canonical ref
# (main) and NOT a full 40-char commit SHA that is currently reachable from
# main (that check requires a live API call and is done by the caller; here
# we only flag refs that are obviously a different named branch/tag, since a
# repo intentionally pinned to an old tag while main has moved on is exactly
# the "pinned to a stale ref" drift case the epic asked for).
# Returns "1" (stale) or "0" (fresh/ok).
is_stale_ref() {
  local ref="$1"
  if [ -z "$ref" ]; then
    echo "0"; return
  fi
  if [ "$ref" = "$CANON_REF" ]; then
    echo "0"
  else
    echo "1"
  fi
}

# classify CONTENT
# Emits one of: OK | LOCAL | STALE_REF:<ref>
# OK        - delegates to ci-reusable.yml@main
# LOCAL     - has a ci.yml but it does not delegate at all (a local/forked copy)
# STALE_REF - delegates, but pinned to something other than @main
classify() {
  local content="$1"
  local delegating
  delegating=$(is_delegating "$content")
  if [ "$delegating" = "0" ]; then
    echo "LOCAL"
    return
  fi
  local ref
  ref=$(extract_ref "$content")
  local stale
  stale=$(is_stale_ref "$ref")
  if [ "$stale" = "1" ]; then
    echo "STALE_REF:${ref}"
  else
    echo "OK"
  fi
}
