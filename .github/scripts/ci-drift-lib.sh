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

# ere_escape STRING
# Escapes all POSIX Extended Regular Expression metacharacters in STRING so
# it can be safely embedded in a grep -E / sed -E pattern as a LITERAL match.
# Without this, the literal '.' in "ci-reusable.yml" (and ".github") matches
# ANY character, which can false-positive-match non-canonical paths and
# misclassify a repo as OK/STALE_REF when it should be LOCAL.
ere_escape() {
  printf '%s' "$1" | sed -E 's/[][(){}.^$*+?|\\]/\\&/g'
}

CANON_REUSABLE_PATH_ESCAPED=$(ere_escape "$CANON_REUSABLE_PATH")

# is_delegating CONTENT
# Returns "1" if the given ci.yml content contains a `uses:` line that points
# at the canonical reusable workflow (any ref), else "0".
is_delegating() {
  local content="$1"
  if printf '%s' "$content" | grep -Eq "uses:[[:space:]]*${CANON_REUSABLE_PATH_ESCAPED}@"; then
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
    | grep -E "uses:[[:space:]]*${CANON_REUSABLE_PATH_ESCAPED}@" \
    | head -n1 \
    | sed -E "s#.*${CANON_REUSABLE_PATH_ESCAPED}@([^[:space:]\"']+).*#\1#"
}

# is_full_sha REF
# Returns "1" if REF looks like a full 40-char commit SHA (hex), else "0".
is_full_sha() {
  local ref="$1"
  if printf '%s' "$ref" | grep -Eq '^[0-9a-fA-F]{40}$'; then
    echo "1"
  else
    echo "0"
  fi
}

# is_stale_ref REF
# A ref is "stale/wrong" drift if it is non-empty and NOT the canonical ref
# (main). A full 40-char commit SHA is NOT decided here: this function has no
# git/network access, so it always flags a non-"main" ref as stale. The
# CALLER (ci-drift-scan.sh, which has a live git checkout) is responsible for
# the actual reachability check via `git merge-base --is-ancestor <sha> main`
# and downgrading a reachable-SHA verdict from STALE_REF to OK before it is
# reported/counted. See ci-drift-scan.sh's classify_with_reachability().
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
