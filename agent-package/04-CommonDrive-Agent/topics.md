# Common Drive Agent — Topics Build Sheet

## 1. Conversation Start

**Nodes:**
1. **Message:**

```
📁 **Common Drive → SPO Migration Specialist**

I cover the 2026 playbook: UNC shared drives into SharePoint Online —
either as a Microsoft Teams channel folder, or directly into a SPO site.

Before I help, which target are you on?
```

2. **Question** (buttons) → `Global.CDFlow`:
   - "🟪 Teams channel folder" → `Channel`
   - "🟦 SPO site (no Team)" → `SiteOnly`
   - "🤔 Compare the two" → `Compare`
3. **Condition** → redirect:
   - `Channel` → "Flow A Overview"
   - `SiteOnly` → "Flow B Overview"
   - `Compare` → "Flow Comparison"

---

## 2. Flow A Overview (Teams channel)

**Trigger phrases:** teams channel, channel folder, team site, microsoft teams

**Nodes:**
1. **Message:**

```
**Flow A: UNC → Teams channel folder**

Path: Import-MigrationSources → list → Update-MigrationTargets.v2
(resolves TeamName + TeamChannel0 via Graph, auto-provisions the channel
folder, grants perms) → Invoke-UNCStorageScan → SPMT-Worker.v2 →
Dashboard / landing page.

What do you want?
```

2. **Question** (buttons): `Workflow`, `Prereqs`, `Sample call`,
   `List columns`, `Migration states`, `Scheduling`, `Storage downgrade`,
   `UMT Phase 1/2`, `Advanced params`, `Errors`, `Scale & app breakdown`,
   `Retry formats`, `Something else`.
3. **Condition** → redirect to matching topic.

---

## 2.5 Flow A Pipeline Detail

**Trigger:** UMT phase 1, UMT phase 2, Update-MigrationTargets, phase

**Nodes:** Explain the two-phase split:
- **Phase 1** is INTERACTIVE (delegated Graph). Resolves Team → SiteUrl
  and TeamChannel0 → channel, adds svc-migration as M365 Group Owner,
  auto-provisions the channel folder. Requires a human admin sign-in.
- **Phase 2** is AUTOMATED (app-only SPO Admin). Storage capacity check
  + auto-downgrade, grants svc-migration as Site Collection Admin.
  Idempotent.
Flow B starts at Phase 2.

---

## 3. Flow B Overview (SPO site only)

**Trigger phrases:** spo site, site only, no team, direct to site, no channel

**Nodes:** mirror Flow A Overview, but call out:
- `Update-MigrationTargets.v2.ps1` **Phase 1 is skipped** (no Team to
  resolve, no M365 group ownership to grant). **Phase 2 still runs** for
  storage capacity check + SCA grant.
- TeamName / TeamChannel0 left blank; SiteUrl populated directly.
- Service-account perms granted on the SPO site directly by Phase 2.
- Everything after Phase 2 (staging, scheduling, claim locking, state
  machine) is identical to Flow A.

---

## 4. Flow Comparison

**Trigger:** compare, difference, which flow

**Nodes:** Message with the "Flow A vs Flow B" table from
`knowledge-cards.md`.

---

## 5. Workflow

**Trigger:** workflow, diagram, picture, flow

**Nodes:**
1. **Condition** on `Global.CDFlow`:
   - `Channel` → Mermaid diagram for Flow A from `workflows.md`.
   - `SiteOnly` → Mermaid diagram for Flow B from `workflows.md`.
   - else → ask which flow first.

---

## 6. Prereqs

**Trigger:** prereqs, requirements, what do I need, app registration, cert

**Nodes:** Message with the prereq section from `knowledge-cards.md`
(certificate auth, app registrations, modules, service account).

---

## 7. List Columns

**Trigger:** list, columns, fields, csv, schema, what to fill in

**Nodes:** Message with the column table from `knowledge-cards.md` →
"Driver list columns".

---

## 8. Sample Call

**Trigger:** sample, example, how do I run, command line

**Nodes:**
1. **Condition** on `Global.CDFlow` → output the matching sample (Flow A or
   Flow B) from `knowledge-cards.md`.
2. Reminder: replace `contoso.*`, `aaaaaaaa-...` / `bbbbbbbb-...` /
   `cccccccc-...` / `dddddddd-...` GUIDs, `@contoso.gov`, and the cert
   thumbprint placeholder.

---

## 9. Scale & Throttling

**Trigger:** scale, throttle, parallel, workers, app registrations, slow, 36 apps, app breakdown

**Nodes:** Message with the "Scale architecture" section from
`knowledge-cards.md`. Always lead with the correct breakdown of the 36
apps: **1 Graph + 6 SPO Admin + 18 SPMT worker + 11 Helper**. The 18
that actually distribute SPMT throttle pressure are the 18 SPMT worker
apps (one per concurrent SPMT session across 6 servers × 3 workers).

---

## 9a. Scheduling & TimeZones

**Trigger:** scheduling, time zone, TimeZone, window, after hours, weekend, holiday, ExtendedHours, Priority, QueuedAt, ANYTIME

**Nodes:** Explain `-UseScheduling` on `CommonDriveMigration.v2.ps1`:
- Allowed windows: weekdays 5pm–6am (local to row's TimeZone), weekends
  24h, U.S. federal holidays 24h.
- TimeZone values: `EST`, `CST`, `MST`, `PST`, `AKST`, `HST`, or `ANYTIME`
  (bypasses the window check).
- `ExtendedHours = Yes` on a row bypasses the window for that row.
- **Large Migration Threshold:** rows >= 10 GB are weekends/holidays only
  unless `ExtendedHours = Yes`.
- `Priority` (1 = highest) sorts the queue; `QueuedAt` provides FIFO
  within a priority band.

---

## 9b. Storage Capacity Auto-Downgrade

**Trigger:** storage, capacity, quota, size, 3yr, 5yr, 7yr, YearUsed, downgrade, retention

**Nodes:** Explain that `Invoke-UNCStorageScan-v2.ps1` computes
`Size3YrMB / Size5YrMB / Size7YrMB`, then `Update-MigrationTargets.v2.ps1`
Phase 2 picks the largest horizon that fits the target quota
(`7yr → 5yr → 3yr`), stamps the result into `YearUsed`, and SPMT filters
source files by last-modified date matching the chosen horizon. If even
3yr won't fit, the row is flagged for manual review.

---

## 9c. Advanced Parameters

**Trigger:** parameters, switches, UseScheduling, MigrationType, Continuous, MaxRuntime, MaxItems, AppClientIdParam

**Nodes:** Output the `CommonDriveMigration.v2.ps1` parameter table from
`knowledge-cards.md` (`-UseScheduling`, `-MigrationType`
[Stage / Migrate / MigrateOnly / Both], `-Continuous`, `-MaxRuntime`,
`-MaxItems`, `-AppClientIdParam`, `-AppCertThumbprintParam`).

---

## 9d. Migration States

**Trigger:** migration states, Migrate column values, Stage, Staged, StagedWithErrors, MigrateOnly, status

**Nodes:** Output the full Migrate-column value table from
`knowledge-cards.md` (blank → Ready → Stage → Staged /
StagedWithErrors → MigrateOnly → Migrating → Migrated / ErrorLog /
Failed). Also explain `ClaimedBy` / `ClaimedAt` / `ClaimStaleHours`.

---

## 10. Retry Failed Items

**Trigger:** retry, FailureSummaryReport, ItemReport_R1, ItemFailureReport, failed, re-run, 0-byte

**Nodes:** Message with `Retry-FailedMigration.ps1` card from
`knowledge-cards.md`. Make clear it accepts BOTH `ItemReport_R1.csv` AND
`ItemFailureReport_*.csv`, detects 0-byte uploads, and only deletes
source files after verifying the target upload (size + existence).

---

## 11. Dashboard / Landing Page

**Trigger:** dashboard, landing page, status page, documentation, manual, Scanned, pipeline stages, division views

**Nodes:** Message listing the five page generators from
`knowledge-cards.md` with one-line purpose for each. Call out:
- Dashboard's `Scanned` counter is **cumulative**, not per-run.
- Dashboard surfaces pipeline stages: `Awaiting Scan` / `Awaiting Target` /
  `Resolved` / `Queued` / `Migrating` / `Complete`.
- Landing Page **auto-discovers divisions** from the driver list and
  creates filter views per division.

---

## 12. Errors

**Trigger:** error, failed, TeamChannelError, permission denied, cert error

**Nodes:** Message with the "Common errors" table from `knowledge-cards.md`.

---

## 13. Back to Concierge

**Trigger:** back, exit, concierge, different scenario

**Nodes:** Redirect to connected agent → `Cloud Migrate Pro Concierge`.

---

## 14. Out of Scope

**Trigger:** H drive, home drive, on-prem SP, mysite, mailbox, Teams chat

**Nodes:**
1. Message: "Not in my scope — back to the Concierge."
2. Redirect → `Cloud Migrate Pro Concierge`.

---

## 15. Fallback

In-scope keyword (UNC, common drive, SPMT-Worker, Update-MigrationTargets,
etc.) → generative answer grounded on knowledge. Otherwise → out-of-scope.

---

## 16. "Why" questions

**Trigger phrases:** why, rationale, reason, what's the point, why bother, why do, what's the purpose, justify

**Nodes:**
1. **Message:** "Good 'why' question. Here's the short version — ask if you want me to expand any of these."
2. **Generative answer grounded on knowledge** (`faq-plain-english.md`, `knowledge-cards.md`) covering:
   - Why two flows (channel vs site)? → different governance models. Teams = M365-group-driven membership; SPO site = custom permissions and lifecycle.
   - Why Phase 1 / Phase 2 split? → Phase 1 needs delegated Graph (a human admin signing in). Phase 2 is app-only and idempotent. Splitting them lets Phase 2 run on a schedule.
   - Why does Phase 1 add svc-migration as M365 Group Owner instead of using SCA? → group ownership is what Teams needs to reliably create channel folders via Graph. SCA on the underlying SPO site is separately granted in Phase 2.
   - Why claim locking? → multiple migration servers can run simultaneously. Without `ClaimedBy` / `ClaimedAt`, two servers would attempt the same row and corrupt state.
   - Why is `ClaimStaleHours = 2` (not 24)? → keeps the system responsive. A claim on a dead runner releases in 2 hours; with 24 you'd lose a workday.
   - Why storage auto-downgrade vs require operators to set the horizon? → operators can't predict which sources fit which targets without scanning. The script computes 3/5/7yr sizes, picks the largest that fits, and never silently drops content the operator was expecting.
   - Why per-row TimeZone? → federal customers are multi-time-zone. A single global "after hours" window means you migrate during business hours for someone.
   - Why TWO migration types in one workflow (`Stage` then `Migrate`)? → Stage surfaces errors without the cutover commitment. You fix source-side issues, then `Migrate` is a fast delta pass.
   - Why no source ACL change after migration? → common drives have many stakeholders. Locking source unilaterally breaks coexistence. Customer governance decides when to lock.
   - Why a SharePoint list as the driver? → customer-owned state, no external DB, FedRAMP/FISMA boundary clean.
3. Always offer to go deeper.

---

## 17. Audience-aware patterns

**Trigger phrases:** customer, executive, end user, manager, team, audience, talking points, summary for, brief, layman

**Nodes:**
1. **Question** (buttons): "Who's the audience?"
   - "End user (someone whose shared drive is moving)" → `EndUser`
   - "Unit / team lead" → `Lead`
   - "Executive / sponsor" → `Executive`
   - "Other CSA / engineer" → `Engineer`
2. **Condition** on the saved value:
   - `EndUser` → generative answer grounded on `user-experience-narrative.md` — plain language. Use the comms templates verbatim where possible.
   - `Lead` → generative answer grounded on `faq-plain-english.md` and `user-experience-narrative.md` — what changes for the team, when to expect it, who can see what after.
   - `Executive` → generative answer grounded on the Concierge battlecards positioning — cost, sovereignty, governance, tradeoffs. No mechanics.
   - `Engineer` → generative answer grounded on `knowledge-cards.md`, `troubleshooting.md`, `command-reference.md`, `decision-aids.md` — full detail.
3. **Message** offer: "Want me to draft an actual email/announcement using this? Tell me the audience and I'll produce a draft."
