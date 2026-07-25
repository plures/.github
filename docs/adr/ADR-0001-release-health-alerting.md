# ADR-0001: Alert on Release Health Tripwire (not just detect it)

- Status: Proposed
- Date: 2026-07-23
- Related: `release-health-monitor.yml`, issue #18 (org:release-failure-alerting)

## Context

`release-health-monitor.yml` runs daily and correctly **detects** two classes
of problems across the org: recent `Release` workflow failures, and repos
with releasable commits that have gone stale (no release in N days). On any
hit it opens or updates a single tracking issue in `plures/.github` (currently
issue #18, sitting at 4 FAILED + 20 STALE).

The gap: that tracking issue is the *only* signal. Nobody is subscribed to
`plures/.github` issues by default, there's no assignee, and the issue is
silently re-edited in place every day rather than re-notifying anyone. A repo
can sit FAILED or STALE for months (as already happened once, per the
workflow's own comment) with detection running perfectly the whole time and
zero human ever seeing it. Detection without alerting is why the epic exists:
`org:release-failure-alerting` implies the missing half is delivering the
signal to a human/channel, not producing a better report.

## Decision

Add an explicit **notification step** to `release-health-monitor.yml` that
fires whenever the tripwire condition is true (`stale_count != 0 ||
failed_count != 0`), in addition to the existing issue create/update step.

- Notification channel: an org-level repository secret
  `RELEASE_HEALTH_WEBHOOK_URL` (Slack incoming-webhook or MS Teams
  connector-compatible JSON body; either works with a `{"text": "..."}`
  payload). This keeps the workflow decoupled from a specific vendor — ops
  can point it at Slack, Teams, or a generic webhook relay.
- The step is a **no-op, not a failure**, when the secret is unset, so forks
  and repos that haven't configured a webhook yet don't break the workflow.
- Payload includes: issue URL, failed count, stale count, and the top-line
  repo names, so the alert is actionable without opening GitHub.
- We alert on **every tripwire-positive run**, not just on state transitions
  (new failure), because the existing failure mode was "stayed broken and
  nobody noticed" — a daily nag until it's fixed is the correct failure mode
  to replace silence with, and is cheap (one webhook POST/day while unhealthy).
- We do **not** alert on the "still healthy" path — no noise when there's
  nothing to do.

## Consequences

- Requires an org/repo secret (`RELEASE_HEALTH_WEBHOOK_URL`) to be configured
  out-of-band by an admin for the alert to actually reach a channel; until
  then this ADR's workflow change is a documented no-op, which is acceptable
  because it doesn't regress current behavior (issue tracking still works).
- Adds one `curl` step, no new dependencies, no third-party Action.
- Future work (out of scope here): per-repo routing, @mention of repo owner,
  escalation after N consecutive unhealthy days. Tracked as follow-ups, not
  blockers, since the primary gap (zero notification) is closed by this ADR.

## Alternatives considered

- **GitHub issue assignee + notifications**: relies on the assignee having
  GitHub notifications enabled/watched for `plures/.github`, which is exactly
  the failure mode that let this go stale for months. Rejected as primary
  mechanism, but not mutually exclusive with a webhook.
- **Email via SMTP action**: heavier dependency, needs SMTP credentials;
  webhook is simpler and matches how the org already does alerting elsewhere
  (chat-first).
