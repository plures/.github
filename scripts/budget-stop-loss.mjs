#!/usr/bin/env node
/**
 * budget-stop-loss.mjs — org GitHub Actions spend guard.
 *
 * Reads the enhanced billing usage report for the org, computes the
 * CURRENT-MONTH net (actually-billed, post-discount) Actions spend, compares
 * it to a monthly budget, and reports a status + alert level. At/over the
 * critical threshold it can DISABLE nonessential scheduled workflows (those
 * whose only trigger is `schedule:`/`workflow_dispatch`) across the org to
 * stop the bleeding, leaving event-driven CI (push/pull_request) untouched.
 *
 * Dependency-free: shells out to the `gh` CLI (already authed in CI via
 * GH_TOKEN). Node 18+ only.
 *
 * Usage:
 *   node budget-stop-loss.mjs --org plures --budget 150 [--enforce] [--json]
 *
 * Env (CI-friendly overrides; flags win over env):
 *   ORG, MONTHLY_BUDGET_USD, ENFORCE=true|false
 *
 * Exit codes:
 *   0  under all thresholds (or report-only)
 *   0  thresholds crossed but handled (alerts emitted / enforcement ran)
 *   2  hard failure (couldn't read billing) — surfaces as a failed run
 *
 * NOTE: This NEVER disables a workflow that has a push/pull_request trigger.
 * It only pauses purely-scheduled "nonessential" jobs, and only when --enforce
 * is set AND spend >= the critical threshold. Re-enabling is intentionally
 * manual (next cycle) so a human stays in the loop on what comes back.
 */

import { execFileSync } from "node:child_process";
import { appendFileSync } from "node:fs";

const args = process.argv.slice(2);
function flag(name, fallback = undefined) {
  const i = args.indexOf(`--${name}`);
  if (i === -1) return fallback;
  const next = args[i + 1];
  if (next === undefined || next.startsWith("--")) return true; // boolean flag
  return next;
}

const ORG = flag("org", process.env.ORG || "plures");
const BUDGET = Number(flag("budget", process.env.MONTHLY_BUDGET_USD || "150"));
const ENFORCE = flag("enforce", process.env.ENFORCE === "true") === true || flag("enforce") === true;
const DRY_ENFORCE = flag("dry-enforce", false) === true; // list targets, do not disable
const JSON_OUT = flag("json", false) === true;

// Alert thresholds as fractions of the monthly budget.
const WARN = 0.7;
const HIGH = 0.85;
const CRIT = 0.95;

function gh(apiPath, jqExpr) {
  const a = ["api", apiPath];
  if (jqExpr) a.push("--jq", jqExpr);
  return execFileSync("gh", a, { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
}

function currentMonthKey() {
  const d = new Date();
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
}

function readActionsNetThisMonth() {
  // Enhanced billing usage report. Items carry product/sku/netAmount/date.
  let raw;
  try {
    raw = gh(`/orgs/${ORG}/settings/billing/usage`);
  } catch (e) {
    throw new Error(
      `Could not read billing usage for org '${ORG}'. ` +
        `Token needs admin/billing read on the org. Underlying: ${String(e.message || e).slice(0, 200)}`,
    );
  }
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new Error("Billing usage response was not valid JSON.");
  }
  const items = Array.isArray(parsed.usageItems) ? parsed.usageItems : [];
  const month = currentMonthKey();
  let net = 0;
  let minutes = 0;
  const byRepo = new Map();
  for (const it of items) {
    if (String(it.product).toLowerCase() !== "actions") continue;
    const mk = String(it.date || "").slice(0, 7); // YYYY-MM
    if (mk !== month) continue;
    const n = Number(it.netAmount || 0);
    net += n;
    minutes += Number(it.quantity || 0);
    const repo = it.repositoryName || "(org)";
    byRepo.set(repo, (byRepo.get(repo) || 0) + n);
  }
  const topRepos = [...byRepo.entries()]
    .filter(([, v]) => v > 0)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 8)
    .map(([repo, v]) => ({ repo, net: Math.round(v * 100) / 100 }));
  return { month, net: Math.round(net * 100) / 100, minutes: Math.round(minutes), topRepos, org: ORG };
}

function levelFor(pct) {
  if (pct >= CRIT) return "CRITICAL";
  if (pct >= HIGH) return "HIGH";
  if (pct >= WARN) return "WARN";
  return "OK";
}

/**
 * List "nonessential scheduled" workflow candidates in the given repos: their
 * triggers are limited to schedule/workflow_dispatch (no push/pull_request).
 * Scoped to a repo allowlist (the top spenders) so enforcement stays fast and
 * rate-friendly instead of scanning every workflow in every org repo.
 */
function findNonessentialScheduled(repoFullNames) {
  const out = [];
  for (const full of repoFullNames) {
    let wfList;
    try {
      wfList = JSON.parse(gh(`repos/${full}/actions/workflows`, null)).workflows || [];
    } catch {
      continue;
    }
    for (const wf of wfList) {
      if (wf.state !== "active") continue; // already disabled → skip
      let contentB64;
      try {
        contentB64 = gh(`repos/${full}/contents/${wf.path}`, ".content");
      } catch {
        continue;
      }
      const text = Buffer.from(contentB64.replace(/\s/g, ""), "base64").toString("utf8");
      const onBlock = (text.match(/\non:\s*([\s\S]*?)\n\w/m) || [, ""])[1];
      const hasSchedule = /\bschedule:/.test(text);
      const hasEventTrigger = /\bpush:|\bpull_request:|\bpull_request_target:/.test(onBlock || text);
      if (hasSchedule && !hasEventTrigger) {
        out.push({ repo: full, path: wf.path, id: wf.id, name: wf.name });
      }
    }
  }
  return out;
}

function disableWorkflow(repoFullName, workflowId) {
  execFileSync(
    "gh",
    ["api", "-X", "PUT", `repos/${repoFullName}/actions/workflows/${workflowId}/disable`],
    { encoding: "utf8" },
  );
}

function main() {
  const usage = readActionsNetThisMonth();
  const pct = BUDGET > 0 ? usage.net / BUDGET : 0;
  const level = levelFor(pct);
  const pctStr = (pct * 100).toFixed(1);

  const report = {
    org: ORG,
    month: usage.month,
    budgetUsd: BUDGET,
    netUsd: usage.net,
    minutes: usage.minutes,
    pctOfBudget: Number(pctStr),
    level,
    thresholds: { warn: WARN, high: HIGH, crit: CRIT },
    topRepos: usage.topRepos,
    enforce: ENFORCE,
    actionsTaken: [],
  };

  if ((level === "CRITICAL" && ENFORCE) || DRY_ENFORCE) {
    // Scope enforcement to the repos actually driving spend this month (top
    // spenders), not the whole org — fast, rate-friendly, and on-target.
    const targetRepos = usage.topRepos.map((t) => `${ORG}/${t.repo}`);
    const candidates = findNonessentialScheduled(targetRepos);
    if (DRY_ENFORCE && !(level === "CRITICAL" && ENFORCE)) {
      // Audit only — show what WOULD be paused, disable nothing.
      report.wouldPause = candidates.map((c) => ({ repo: c.repo, path: c.path, name: c.name }));
    } else {
      for (const c of candidates) {
        try {
          disableWorkflow(c.repo, c.id);
          report.actionsTaken.push({ disabled: `${c.repo}:${c.path}`, name: c.name });
        } catch (e) {
          report.actionsTaken.push({ failed: `${c.repo}:${c.path}`, error: String(e.message || e).slice(0, 120) });
        }
      }
    }
  }

  if (JSON_OUT) {
    console.log(JSON.stringify(report, null, 2));
  } else {
    const bar = `${"$".repeat(Math.min(20, Math.round(pct * 20))).padEnd(20, "·")}`;
    console.log(`Budget stop-loss — ${ORG} — ${usage.month}`);
    console.log(`  Spend: $${usage.net.toFixed(2)} / $${BUDGET.toFixed(2)} budget  (${pctStr}%)  [${bar}]`);
    console.log(`  Minutes: ${usage.minutes.toLocaleString()}   Level: ${level}`);
    if (usage.topRepos.length) {
      console.log(`  Top repos (net):`);
      for (const t of usage.topRepos) console.log(`    ${t.repo.padEnd(28)} $${t.net.toFixed(2)}`);
    }
    if (report.actionsTaken.length) {
      console.log(`  Enforcement:`);
      for (const a of report.actionsTaken) console.log(`    ${JSON.stringify(a)}`);
    } else if (level !== "OK") {
      console.log(`  (alert-only — pass --enforce to auto-pause nonessential scheduled workflows at CRITICAL)`);
    }
  }

  // Emit GitHub Actions outputs + step summary when running in CI.
  if (process.env.GITHUB_OUTPUT) {
    appendFileSync(
      process.env.GITHUB_OUTPUT,
      `level=${level}\npct=${pctStr}\nnet=${usage.net}\nminutes=${usage.minutes}\n`,
    );
  }
  if (process.env.GITHUB_STEP_SUMMARY) {
    const lines = [
      `### 💸 Actions Budget — ${ORG} — ${usage.month}`,
      ``,
      `| Spend | Budget | % | Level | Minutes |`,
      `|---|---|---|---|---|`,
      `| $${usage.net.toFixed(2)} | $${BUDGET.toFixed(2)} | ${pctStr}% | **${level}** | ${usage.minutes.toLocaleString()} |`,
      ``,
    ];
    if (usage.topRepos.length) {
      lines.push(`<details><summary>Top repos by net spend</summary>`, ``, `| repo | net |`, `|---|---|`);
      for (const t of usage.topRepos) lines.push(`| ${t.repo} | $${t.net.toFixed(2)} |`);
      lines.push(``, `</details>`);
    }
    if (report.actionsTaken.length) {
      lines.push(`**Enforcement actions:**`);
      for (const a of report.actionsTaken) lines.push(`- \`${JSON.stringify(a)}\``);
    }
    appendFileSync(process.env.GITHUB_STEP_SUMMARY, lines.join("\n") + "\n");
  }
}

try {
  main();
} catch (e) {
  console.error(`stop-loss error: ${String(e.message || e)}`);
  process.exit(2);
}
