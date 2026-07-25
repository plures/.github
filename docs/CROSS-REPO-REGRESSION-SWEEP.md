# Cross-Repo Regression Sweep (epic:ci-cross-repo-regression-sweep)

## Problem
Producer repos (pluresdb, praxis, pares-radix core crates) merge changes that
consumer repos (pares-radix, pares-agens, pares-modulus, pares-arca) depend on
via git-pinned Cargo deps or workspace packages. Today nothing runs the
consumers' test suites before a producer change is considered safe to release
— breakage is discovered only when a consumer separately re-pins and its own
CI fails, often much later.

## Dependency graph
See `docs/CROSS-REPO-DEPENDENCY-GRAPH.md` for the full enumerated edge list
(grepped from actual `Cargo.toml`/`package.json` files across the 6 repos,
not assumed). Summary:
- `pluresdb` → pares-radix, pares-agens, pares-arca (3 independent pin points)
- `praxis` → indirect only, via `pluresdb-px` (ADR-0021 doctrine)
- `pares-radix` core crates → pares-agens (git-tag pinned, not path — a release
  does not auto-flow until agens bumps tags)
- `pares-modulus` → no Rust/TS dependency edge on any producer today (no-op target)

## Solution
`.github/workflows/cross-repo-regression.yml` — a reusable `workflow_call`
that a producer repo's release/CI pipeline calls after merging to `main`. It:
1. Resolves the correct consumer set for that producer (hardcoded table,
   mirrors the dependency-graph doc — update both together).
2. Dispatches each consumer's existing `ci.yml` via `workflow_dispatch`
   (already enabled on every plures repo's `ci.yml` — no consumer-side
   changes required to adopt this).
3. Polls for the new run and waits for its conclusion.
4. Fails the caller (blocking release) if any consumer regresses.

## Adoption (producer side)
Add a job to the producer's release workflow:
```yaml
jobs:
  regression-sweep:
    if: github.ref == 'refs/heads/main'
    uses: plures/.github/.github/workflows/cross-repo-regression.yml@main
    with:
      producer: pluresdb
    secrets:
      dispatch_token: ${{ secrets.CROSS_REPO_DISPATCH_TOKEN }}
```
Requires a `CROSS_REPO_DISPATCH_TOKEN` org secret (PAT or GitHub App
installation token) with `actions:write` + `contents:read` on every consumer
repo — this is the one piece of new infra needed; no consumer repo changes.

## Known gaps / follow-ups (tracked, not silently ignored)
- **pares-agens tag drift**: pares-agens pins pares-radix crates by git tag,
  not path, and currently has 3 different tags in flight
  (`v1.55.36`/`v1.55.37`/`v1.55.39`). The sweep runs pares-agens CI against
  its CURRENT pins, which will NOT catch a regression until pares-agens bumps
  its tags. A follow-up (tracked separately) should add an optional
  "propose pin-bump PR" step so the sweep tests the NEW code, not stale pins.
- **pares-arca independent pluresdb rev**: pares-arca pins pluresdb at a
  different rev (`68436c57`) than radix/agens (`d08f88b5...`). It is swept
  as its own edge, which is correct, but a producer merge is only "safe" for
  arca once arca has re-pinned to include the new commit — same caveat as above.
- **pares-modulus**: has no dependency edge on any producer today; included
  in the design for completeness/future-proofing but currently a no-op.
