#!/usr/bin/env bash
# release-health-selftest.sh - proves the release-health tripwire actually fires.
#
# WHY: the monitor exists because the org's release pipeline broke SILENTLY for
# ~2 months. A tripwire that can itself silently stop detecting is worthless.
# This self-test sources the SAME decision lib the monitor runs and asserts it
# still flags stale/failed/releasable inputs. It runs in CI on every change to
# the scan or lib, so a regression that blinds the tripwire fails loudly here
# instead of in production two months later.
#
# No network, no gh, no adapter (C-TEST-002). Pure fixtures -> pure assertions.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./release-health-lib.sh
. "$DIR/release-health-lib.sh"

pass=0
fail=0
check() { # check <label> <expected> <actual>
  if [ "$2" = "$3" ]; then
    pass=$((pass+1))
  else
    fail=$((fail+1))
    echo "FAIL: $1 -> expected '$2' got '$3'"
  fi
}

DAY=86400
STALE_SECS=$(( 14 * DAY ))
NOW=1000000000

# --- count_releasable: the regex must catch every releasable type + breaking ---
check "feat is releasable"        1 "$(count_releasable 'feat: add thing')"
check "fix is releasable"         1 "$(count_releasable 'fix: bug')"
check "perf is releasable"        1 "$(count_releasable 'perf: faster')"
check "refactor is releasable"    1 "$(count_releasable 'refactor: tidy')"
check "release is releasable"     1 "$(count_releasable 'release: v2')"
check "scoped feat releasable"    1 "$(count_releasable 'feat(api): x')"
check "breaking bang releasable"  1 "$(count_releasable 'feat!: drop v1')"
check "scoped breaking releasable" 1 "$(count_releasable 'fix(core)!: x')"
check "chore NOT releasable"      0 "$(count_releasable 'chore: deps')"
check "docs NOT releasable"       0 "$(count_releasable 'docs: readme')"
check "counts multiple" 2 "$(count_releasable "$(printf 'feat: a\nchore: b\nfix: c')")"

# --- is_stale: releasable + old release => stale; otherwise not ---
OLD=$(( NOW - 30*DAY ))   # 30d ago, beyond the 14d window
RECENT=$(( NOW - 2*DAY ))  # 2d ago, inside the window
check "stale: releasable+old"        1 "$(is_stale 3 "$NOW" "$OLD" "$STALE_SECS")"
check "not stale: releasable+recent" 0 "$(is_stale 3 "$NOW" "$RECENT" "$STALE_SECS")"
check "not stale: no releasable"     0 "$(is_stale 0 "$NOW" "$OLD" "$STALE_SECS")"
check "stale: never released (epoch0)" 1 "$(is_stale 1 "$NOW" 0 "$STALE_SECS")"

# --- is_failed_run ---
check "failure trips"     1 "$(is_failed_run failure)"
check "success no trip"   0 "$(is_failed_run success)"
check "empty no trip"     0 "$(is_failed_run '')"
check "cancelled no trip" 0 "$(is_failed_run cancelled)"

echo ""
echo "release-health self-test: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
