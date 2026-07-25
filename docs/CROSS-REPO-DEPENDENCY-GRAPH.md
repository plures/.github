# Cross-Repo Rust/TS Dependency Graph (producer → consumer)

Generated 2026-07-25 by grepping `Cargo.toml` (git/path deps) and `package.json`
(workspace/`@plures/*` deps) across the plures Rust/TS repos on this box.
This is the **real, evidence-based edge list** the `cross-repo-regression.yml`
reusable workflow acts on — not a guess.

## Method
```
Get-ChildItem <repo> -Recurse -Filter Cargo.toml | grep for:
  pluresdb | pluresdb-px | pluresdb-storage | pluresdb-sync | pluresdb-sea | pluresdb-procedures
  praxis | pares-radix-praxis
  pares-radix-core | pares-radix-praxis | pares-radix-audit | pares-rector
Get-ChildItem <repo> -Recurse -Filter package.json | grep for:
  @plures/* workspace deps, "pares-radix", "praxis"
```

## Producers → Consumers (Rust crates, git/rev-pinned)

| Producer crate(s) | Consumer repo | Consumer crate(s) | Pin style |
|---|---|---|---|
| `pluresdb`, `pluresdb-px`, `pluresdb-sync`, `pluresdb-sea`, `pluresdb-procedures` (repo: **pluresdb**) | pares-radix | crates/agenda, crates/audit, crates/praxis (as `pluresdb-px`), crates/radix-core | `git` + `rev` (currently `d08f88b5410384235f586320bafb89c4be3aa7a1`) |
| `pluresdb`, `pluresdb-px`, `pluresdb-sync` (repo: **pluresdb**) | pares-agens | crates/agenda, crates/agens-plugin, crates/audit, crates/channels, crates/core, crates/mcp-server | `git` + `rev` (same rev as pares-radix, kept in lockstep by convention) |
| `pluresdb`, `pluresdb-storage`, `pluresdb-sync` (repo: **pluresdb**) | pares-arca | Cargo.toml (workspace root), crates/arca-core | `git` + `rev` (currently `68436c57`, **independently pinned** — NOT in lockstep with radix/agens) |
| `pluresdb` | pares-modulus | — (no Rust crates found; TS-only repo) | n/a |
| `pares-radix-core`, `pares-radix-praxis`, `pares-rector` (repo: **pares-radix**, crates `radix-core`/`praxis`/`crates/mcp-client`) | pares-agens | crates/agens-plugin, crates/bitnet, crates/channels, crates/cli, crates/core, crates/mcp-client, crates/mcp-server, crates/models, crates/tauri-app, crates/tui | `git` + `tag` (currently mixed: `v1.55.39` core, `v1.55.37` praxis, `v1.55.36` rector) |
| `pares-radix` (crate `praxis`, internal path dep) | pares-radix (self, crates/radix-core depends on crates/praxis) | in-repo `path = "../praxis"` | path (same-repo, not cross-repo) |
| **praxis** (repo, standalone rules engine) | pares-radix crates/praxis, pares-agens crates via `pluresdb-px` re-export (px-through-PluresDB doctrine, ADR-0021) | indirect — praxis logic is consumed THROUGH pluresdb-px, not a direct crate dep today | indirect / doctrine-enforced |
| pares-modulus | — | no repo currently declares `pares-modulus` as a Cargo/npm dependency; it consumes pares-radix as a **plugin host**, not the reverse | n/a (modulus is itself a consumer of pares-radix's plugin contract, verified at runtime not at build) |

## Key findings
1. **pares-radix and pares-agens both pin `pluresdb` to the SAME rev** (`d08f88b5...`) by convention but this is **not machine-enforced** — a pluresdb change merged and re-pinned in one repo but not the other is a real drift risk this workflow should catch.
2. **pares-arca pins pluresdb independently** (`68436c57`, a different commit than radix/agens) — it is a separate blast-radius branch of the graph and must be tracked separately.
3. **pares-agens re-vendors pares-radix crates by git tag** (`v1.55.36`–`v1.55.39`, currently 3 different tags across 4 crates) rather than path. A pares-radix release is NOT automatically picked up by pares-agens until someone manually bumps these tags — meaning "regression on merge" for pares-radix requires pares-agens to first re-pin, then test. The workflow below handles this as a **two-phase gate**: (a) run pares-radix's own consumers-that-path-depend immediately, (b) open/flag a pin-bump dependency PR for tag-pinned consumers (pares-agens) so their CI runs against the new code, rather than silently testing stale pins.
4. **pares-modulus has no Rust dependency edge** to any producer in this epic — it is TS-only (plugin registry). It is included in the workflow's consumer list for future-proofing (a Rust-based plugin loader) but currently has **no crate/package edge to gate on**; the workflow no-ops for it until such a dependency appears.
5. **praxis (repo) has no direct crate consumers today** — its logic is consumed indirectly via `pluresdb-px` per ADR-0021 (px-through-PluresDB doctrine). Regression coverage for praxis therefore routes through the pluresdb edge, not a direct one.

## Producer set (from epic) mapped to repos
- `pluresdb` → repo **plures/pluresdb**
- `praxis` → repo **plures/praxis** (indirect edge only, see finding 5)
- `pares-radix core crates` → repo **plures/pares-radix** (crates: radix-core, praxis, mcp-client, audit, agenda)

## Consumer set (from epic) mapped to repos
- pares-radix (also a producer for its own core crates — self-consumes internally via path deps, no cross-repo action needed)
- pares-agens
- pares-modulus (currently no gate-able edge; included as a no-op target)
- pares-arca
