#!/usr/bin/env bash
# ci-drift-selftest.sh — unit tests for ci-drift-lib.sh classify logic.
# Run: bash .github/scripts/ci-drift-selftest.sh
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./ci-drift-lib.sh
. "$SCRIPT_DIR/ci-drift-lib.sh"

fail=0
check() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "ok - $desc"
  else
    echo "FAIL - $desc (expected '$expected' got '$actual')"
    fail=1
  fi
}

# 1. Canonical delegating @main -> OK
c1='name: CI
on: [push]
jobs:
  ci:
    uses: plures/.github/.github/workflows/ci-reusable.yml@main'
check "delegating @main is OK" "OK" "$(classify "$c1")"

# 2. Local non-delegating copy -> LOCAL
c2='name: CI
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: npm test'
check "local copy is LOCAL" "LOCAL" "$(classify "$c2")"

# 3. Delegating but pinned to an old tag -> STALE_REF
c3='jobs:
  ci:
    uses: plures/.github/.github/workflows/ci-reusable.yml@v1.2.0'
check "pinned old tag is STALE_REF" "STALE_REF:v1.2.0" "$(classify "$c3")"

# 4. Delegating pinned to a sha (still flagged, caller decides if it matters)
c4='jobs:
  ci:
    uses: plures/.github/.github/workflows/ci-reusable.yml@abcdef1234567890abcdef1234567890abcdef12'
check "pinned sha is STALE_REF" "STALE_REF:abcdef1234567890abcdef1234567890abcdef12" "$(classify "$c4")"

# 5. Empty content -> LOCAL
check "empty content is LOCAL" "LOCAL" "$(classify "")"

# 6. is_delegating helper directly
check "is_delegating true" "1" "$(is_delegating "$c1")"
check "is_delegating false" "0" "$(is_delegating "$c2")"

# 7. extract_ref helper
check "extract_ref main" "main" "$(extract_ref "$c1")"
check "extract_ref v1.2.0" "v1.2.0" "$(extract_ref "$c3")"

# 8. Regex-escaping: a path with a literal '.' standing in for CANON's '.'
# (e.g. "plures/Xgithub/Xgithub/workflows/ciXreusable.yml" using any char in
# place of the dots) must NOT be treated as a match — proves '.' isn't being
# used as a regex wildcard.
c8='jobs:
  ci:
    uses: plures/Xgithub/Xgithub/workflows/ciXreusable.yml@main'
check "dot-metachar path is not a false-positive match" "0" "$(is_delegating "$c8")"
check "dot-metachar path classifies as LOCAL, not OK" "LOCAL" "$(classify "$c8")"

# 9. ere_escape helper: literal specials come back escaped
check "ere_escape dot" '\.' "$(ere_escape '.')"
check "ere_escape slash-path" 'a/b\.c' "$(ere_escape 'a/b.c')"

# 10. is_full_sha helper
check "is_full_sha true" "1" "$(is_full_sha "abcdef1234567890abcdef1234567890abcdef12")"
check "is_full_sha false (short)" "0" "$(is_full_sha "abc123")"
check "is_full_sha false (branch name)" "0" "$(is_full_sha "my-branch")"

if [ "$fail" -eq 1 ]; then
  echo "SELFTEST FAILED"
  exit 1
fi
echo "SELFTEST OK"
