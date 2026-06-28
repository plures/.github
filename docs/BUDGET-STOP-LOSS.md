# Actions Budget Stop-Loss

Org-wide guard against runaway GitHub Actions spend. Lives in the `plures/.github`
repo so it covers every repo in the org from one place.

## What it does

`scripts/budget-stop-loss.mjs` + `.github/workflows/budget-stop-loss.yml`:

1. **Reads live billing** — the enhanced usage report
   (`/orgs/<org>/settings/billing/usage`), filters to `product == actions`, and
   sums the **current-month `netAmount`** (what you actually pay after the
   included-minutes discount — NOT the headline gross).
2. **Compares to a monthly budget** and assigns a level:
   - `OK` < 70%
   - `WARN` ≥ 70%
   - `HIGH` ≥ 85%
   - `CRITICAL` ≥ 95%
3. **Reports** — always writes a step summary table (spend / budget / % / level /
   minutes + top repos by net). At `WARN`+ it can send a Telegram alert.
4. **Enforces (opt-in)** — at `CRITICAL` with enforcement enabled, it pauses
   **nonessential scheduled workflows** in the **top-spending repos** only
   (workflows whose triggers are limited to `schedule:`/`workflow_dispatch` with
   no `push`/`pull_request`). Event-driven CI is never touched. Re-enabling is
   **manual** (next cycle) so a human decides what comes back.

## Why net, not gross

The org's gross Actions usage is huge (most of it is discounted to $0 by included
minutes). Only `netAmount` maps to the bill. Example from June 2026:
gross $3,211 YTD vs **net $920 YTD**; June net was **$200**, almost all from one
repo's `Org Proactive Monitor` scheduled scan.

## Configuration

Set on the `plures/.github` repo (Settings → Secrets and variables → Actions):

| Kind | Name | Purpose | Default |
|---|---|---|---|
| Variable | `ACTIONS_MONTHLY_BUDGET_USD` | budget to check against | `150` |
| Variable | `ACTIONS_BUDGET_ENFORCE` | `true` to auto-pause at CRITICAL | `false` (alert-only) |
| Secret | `PLURES_GITHUB_TOKEN` | org **billing-read** + `actions:write` token | — |
| Secret | `TELEGRAM_BOT_TOKEN` | optional alerting | — |
| Secret | `TELEGRAM_CHAT_ID` | optional alerting | — |

> `GITHUB_TOKEN` usually **cannot** read org billing. Provide
> `PLURES_GITHUB_TOKEN` (a PAT/installation token with org admin/billing read)
> or the job will fail at the billing read with a clear error.

## Run it manually

```bash
# Report only (safe, read-only):
node scripts/budget-stop-loss.mjs --org plures --budget 150

# See exactly what enforcement WOULD pause, without disabling anything:
node scripts/budget-stop-loss.mjs --org plures --budget 150 --dry-enforce --json

# Actually enforce (only acts if spend >= 95% of budget):
node scripts/budget-stop-loss.mjs --org plures --budget 150 --enforce
```

Or trigger the workflow: **Actions → Budget Stop-Loss → Run workflow** (inputs let
you override the budget and toggle enforcement for that run).

## Operational notes

- Scheduled daily at 08:00 PDT (`0 15 * * *` UTC).
- Enforcement is scoped to the **top 8 spending repos** from the billing report,
  so it stays fast and rate-friendly instead of scanning the whole org.
- The detector is conservative: a workflow with ANY `push`/`pull_request`
  trigger is treated as essential CI and is never paused, even if it also has a
  `schedule`.
- To re-enable a paused workflow: GitHub UI (Actions → workflow → ⋯ → Enable) or
  `gh api -X PUT repos/<repo>/actions/workflows/<id>/enable`.
