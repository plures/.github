#!/usr/bin/env bash
# release-health-lib.sh - PURE decision logic for the release-health tripwire.
#
# Extracted from release-health-scan.sh so it can be unit-tested WITHOUT any
# live GitHub API calls (C-TEST-002: the core logic must be verifiable locally,
# never dependent on a transport/adapter being up). The scan script sources
# this lib and feeds it data it fetched; the self-test sources this lib and
# feeds it fixtures. Same function, two callers - the test proves the exact
# code the monitor runs.
#
# No side effects, no network, no `gh`. Pure string/arithmetic decisions.

# Conventional-commit types that SHOULD produce a release. Single source of
# truth for both the scan and its test.
RELEASABLE_RE='^(feat|fix|perf|refactor|release)(\(.+\))?!?:|!:'

# count_releasable <multiline-commit-messages>
# Echoes the number of commit-message lines that are releasable.
count_releasable() {
  local msgs="$1"
  local n
  n=$(printf '%s\n' "$msgs" | grep -cE "$RELEASABLE_RE" 2>/dev/null | head -1 | tr -d '[:space:]')
  echo "${n:-0}"
}

# is_stale <releasable_count> <now_epoch> <last_release_epoch> <stale_secs>
# Echoes "1" if the repo is STALE (has releasable commits AND the last release
# is older than the stale window), else "0".
is_stale() {
  local releasable="$1" now="$2" rel_epoch="$3" stale_secs="$4"
  if [ "$releasable" -gt 0 ] && [ $(( now - rel_epoch )) -gt "$stale_secs" ]; then
    echo 1
  else
    echo 0
  fi
}

# is_failed_run <conclusion>
# Echoes "1" if a Release run conclusion counts as a failure tripwire.
is_failed_run() {
  [ "$1" = "failure" ] && echo 1 || echo 0
}
