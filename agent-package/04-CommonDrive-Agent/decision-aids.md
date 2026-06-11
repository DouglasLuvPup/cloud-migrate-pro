# Common Drive → Teams / SPO — Decision Aids

When an operator asks "should I X or Y?" — this file has the answer in a single screen. Voice: peer senior engineer, no padding.

---

## Flow A (Teams channel) vs Flow B (SPO site) — which?

Ask the customer: **does this unit collaborate primarily in Teams, or do they need a stand-alone document library?**

| Use Flow A (Teams channel folder) when | Use Flow B (SPO site) when |
|---|---|
| The unit already has a Team and active chat / channel meetings | The content is the artifact (e.g., a controlled document library) |
| Files are accessed alongside conversations | Content has formal owners separate from the team that uses it |
| Membership = Team membership (M365 group) | Membership is managed at the site level (custom permission sets) |
| Lower governance overhead | Higher governance: site policies, retention, classification labels |

If the customer says "we want both" — they want a SharePoint site that's also a Team's underlying site. That's Flow A (Teams creates the underlying SPO site; Flow A migrates into a channel folder on it).

---

## Stage vs MigrateOnly vs Both

| `-MigrationType` value | When to use |
|---|---|
| `Stage` | Low-risk pre-load. Surfaces errors, lets you fix at source, doesn't notify anyone. Use for first wave with a new customer, or for big sources where cutover delta should be tiny. |
| `MigrateOnly` | One-pass full migration, skipping the Stage step. Use for known-clean small sources, or when the source has been stable for weeks. |
| `Both` | Stage immediately followed by Migrate, in the same run. Use for batches you trust and want a one-pass cutover for. |
| `Migrate` (after a prior `Stage`) | The cutover pass after a successful Stage. Use this when you've reviewed Stage results, fixed source errors, and you're ready to commit. |

**Default recommendation:** Stage first, separately, for any wave > 5 rows. Review `StagedWithErrors` rows. Fix source. Then run `Migrate`.

---

## When to run `Update-MigrationTargets.v2.ps1`

| Flow | Phase 1 | Phase 2 |
|---|---|---|
| **Flow A** (Teams channel) | **Required** — adds svc-migration as M365 Group Owner, provisions channel folders. Interactive, run once per wave by a human admin. | **Required** — storage auto-downgrade + SCA grant. Run before each migration pass. Safe to schedule. |
| **Flow B** (SPO site) | **Skip** — no Team, no group ownership to grant, no channel folder to provision. | **Required IF** you want storage auto-downgrade + automated SCA grant. **Optional** if you grant SCA manually and don't need YearUsed. |

If you skip Phase 2 for Flow B, the script won't auto-downgrade — all rows attempt 7-year content. Plan target quota accordingly.

---

## When to use `-UseScheduling` vs run unrestricted

`-UseScheduling` turns on the TimeZone + holiday + Large-Migration-Threshold rules.

| Situation | Use `-UseScheduling`? |
|---|---|
| Production migration during business hours allowed | **No** (or selectively per-row via `ExtendedHours = Yes`) |
| Production migration where business hours must be protected | **Yes** |
| Pilot / test migration in a non-prod tenant | **No** — runs faster without window restrictions |
| Customer is multi-time-zone (e.g., national agency) | **Yes** — the per-row TimeZone is the whole point |
| Customer is single-time-zone, small wave | Optional — easier to just run windows of your choice |
| Specific deadline (e.g., cutover for a stakeholder demo Monday) | **No** — get it done; rely on operator judgment for timing |

---

## When to use `-Continuous` vs single-pass

`-Continuous` keeps the orchestrator running, looping until `-MaxRuntime` is hit. It picks up rows as they arrive (or as Stage finishes for the Migrate pass).

| Situation | Use `-Continuous`? |
|---|---|
| Steady-state migration over days/weeks | **Yes** — set `-MaxRuntime (New-TimeSpan -Hours 10)` per workday |
| Specific wave, want to know exactly when it's done | **No** — single-pass with `-MaxItems N` |
| Operator wants to monitor progress visually | **No** — single-pass; check the dashboard between runs |
| Running on a schedule (cron / Task Scheduler) | Either — `-Continuous` with `-MaxRuntime` is safer (auto-terminates) |

---

## When to claim-reset a row manually

`ClaimStaleHours = 2` means a stuck claim auto-releases after 2 hours. Decide:

| Situation | Manual reset? |
|---|---|
| Claim is < 2h old, runner host is responsive | **No** — runner is alive. |
| Claim is < 2h old, runner host is unreachable / rebooted | **Yes** — clear `ClaimedBy` and `ClaimedAt`. Don't wait. |
| Claim is > 2h old | **No** — auto-release will fire next cycle. |
| Multiple claims by the same dead runner | **Yes — bulk** — script a clear for all claims by that COMPUTERNAME. |

---

## When to retry a failed row vs re-import

| `Migrate` value | Action |
|---|---|
| `Failed` (after Migrate pass) | Clear `ClaimedBy` / `ClaimedAt` / `Migrate`. Set `Migrate = Ready`. Or use `Retry-FailedMigration.ps1` for per-file-level retry. |
| `StageFailed` (after Stage pass) | Same — clear claim, set `Migrate = Ready`, re-stage. |
| `MigratedWithErrors` | Inspect attached CSV. Decide skip vs `Retry-FailedMigration.ps1`. |
| `StagedWithErrors` | Inspect SPMT report. Fix source if possible. Re-stage or accept and Migrate. |
| Row is fundamentally wrong (wrong target, wrong source) | Delete the row in the list, re-import via `Import-MigrationSources.ps1`. |

---

## When to use `Retry-FailedMigration.ps1` vs reset Migrate to Ready

| Situation | Use Retry script | Use reset |
|---|---|---|
| Per-file errors (`MigratedWithErrors` / `StagedWithErrors`) — handful of named files | **Retry script** (it reads the CSV and only retries listed files) | |
| Per-file errors — many files (>50) | | **Reset to Ready** — full retry is cheaper than per-file dispatching |
| 0-byte target files suspected | **Retry script** (it has 0-byte detection) | |
| Hard failure (`Failed`) — full content didn't migrate | | **Reset to Ready** |
| Throttle exhaustion (`THROTTLE` in ScriptError) | | **Reset to Ready**, but wait an hour for SPO to cool down |
| Need to delete source after verified target write | **Retry script with `-DeleteSource`** (only after sign-off) | |

---

## When to use `ExtendedHours = Yes`

Per-row override of the scheduling window. Use for:

| Situation | Set ExtendedHours? |
|---|---|
| Specific row needs to finish before a stakeholder demo | **Yes** |
| Row is `Failed` and you're retrying right now | **Yes** if you're online to monitor; otherwise it'll wait for the window |
| Test row in a non-prod tenant | **Yes** (or just don't use `-UseScheduling`) |
| Large source (>10GB) for a unit that's already in production | **No** — the Large Migration Threshold exists to protect production hours |
| Generic "I want it done sooner" | **No** — that's why the schedule exists |

---

## When `YearUsed = 3` is acceptable vs needs intervention

After Phase 2, every row has a `YearUsed` value. If `YearUsed = 3` for a row, only files modified in the last 3 years migrated. The rest stayed at source.

| Customer attitude | Decision |
|---|---|
| "Old files don't matter; archive them on-prem indefinitely" | **Accept.** Communicate via the horizon-notice email template. |
| "Old files are records and need to be in the cloud" | **Intervene.** Request quota increase, or split the source into multiple rows (e.g., separate "active" and "archive" rows with different targets). |
| "We don't know which old files matter" | **Pause.** Get the data owner to triage before deciding. Don't ship a `YearUsed = 3` migration into a black hole. |
| Records-management policy requires segregation by age | **Split the row.** Migrate active (3yr) to active SPO; migrate older to a records-management archive site separately. |

---

## When to grant SCA manually vs let Phase 2 do it

Phase 2 of `Update-MigrationTargets.v2.ps1` adds `svc-migration` as SCA on every Flow A / Flow B target. App-only, idempotent, safe to re-run.

| Situation | Approach |
|---|---|
| Standard migration wave | Let Phase 2 handle it. |
| Target site doesn't exist yet | Create site first, then run Phase 2. |
| Customer requires manual approval per SCA grant | Run Phase 2 disabled / SCA-skip mode if your shop has built that; otherwise grant manually one-by-one and skip Phase 2 for those rows. |
| Target is a site you don't have admin rights to | Get rights first. SCA grant requires SPO admin (the app reg has that). |

---

## When to route the conversation back to the Concierge

If the operator describes any of these, this isn't the right agent:

- Per-user OneDrive (H: drive) migration → **H: Drive agent**
- Per-user OneDrive (on-prem MySite) → **OnPrem → SPO agent**
- On-prem SharePoint site → SPO site → **OnPrem → SPO agent**
- Mailbox migration → out of scope
- Cross-tenant migration → out of scope
- File-server consolidation (multiple shares into one) → discuss whether to use multiple Common Drive runs

Reply: "That's not in my scope. Type 'back' to return to the Cloud Migrate Pro Concierge and pick the right specialist."

---

## When to escalate to Microsoft support

- Tenant-wide SPO throttle that doesn't subside in an hour (suggests a tenant-level issue)
- Graph API failures during Phase 1 that aren't documented (suggests a Graph or app-reg issue)
- SPMT engine errors that aren't in the playbook's troubleshooting list and reproduce across rows
- Channel folder provisioning failing tenant-wide (Phase 1 auto-provision can't keep up)
- Cert / app reg issues (e.g., conditional access policy blocking the SPMT worker apps)
