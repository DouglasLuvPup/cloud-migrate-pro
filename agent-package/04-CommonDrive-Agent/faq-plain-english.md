# Common Drive → Teams / SPO — Plain-English FAQ

Use this when a user asks a "why" or "what really happens" question that's hard to answer with a cmdlet. Voice: peer senior engineer to junior colleague. Acronyms expanded on first use per conversation.

---

## Flows and targets

**Q: What's "Flow A" vs "Flow B"?**
- **Flow A** = the UNC source goes to a **Teams channel folder**. The driver-list row has `TeamName` and `TeamChannel0` populated. The migration ends up under the Team's underlying SharePoint site, in the channel's document folder.
- **Flow B** = the UNC source goes to a **plain SharePoint Online site**. `TeamName` is blank. The migration ends up under whatever `TargetUrl` you specified.

Operators ask "which flow?" because the prep steps differ — Flow A needs `Update-MigrationTargets.v2.ps1` to run first (Phase 1 + Phase 2); Flow B starts at Phase 2 only (or skips it entirely if you grant `svc-migration` manually).

**Q: Why is there a Phase 1 / Phase 2 split in `Update-MigrationTargets`?**
Different auth needs.
- **Phase 1** has to add `svc-migration` as an M365 Group Owner of the Team. Microsoft Graph requires a **human admin** to delegate that consent — there's no app-only path that adds a group owner without interactive sign-in. So Phase 1 is interactive, delegated Graph.
- **Phase 2** does storage-quota fitting and SCA grants on the target SPO site. Those can run app-only with certificate auth. So Phase 2 is automated and safe to schedule on a loop.

Separating them lets you do the one-time interactive setup (Phase 1) early in the engagement, then run Phase 2 unattended at scale.

**Q: Why does Phase 1 also auto-provision the channel folder?**
Teams lazy-creates channel folders. Until someone uploads a file (or the channel folder is explicitly provisioned), the folder doesn't exist on the underlying SharePoint site. SPMT would 404 trying to write to it. Phase 1 force-creates the folder via Graph so SPMT has a target.

---

## Scheduling

**Q: What's `TimeZone` on the row, and why is it per-row?**
Each row carries its own time zone (`EST`, `CST`, `MST`, `PST`, `AKST`, `HST`, or `ANYTIME`). The scheduling window (weekdays 5pm–6am, weekends 24h, holidays 24h) is evaluated **local to the row's time zone**, not the runner host's time zone.

Why: federal agencies often have distributed offices across 4+ time zones. A migration row for a Pacific office shouldn't run during their business hours just because the runner happens to live on Eastern.

**Q: How do US federal holidays factor in?**
The scheduling logic treats US federal holidays as 24-hour migration windows (full-day eligible). The holiday calendar is built into the script — operators don't pass it. If you need to add custom dates, edit the holiday list at the top of `CommonDriveMigration.v2.ps1`.

**Q: What's the "Large Migration Threshold"?**
Rows where the migration size is **≥ 10 GB** get restricted to weekends and holidays only — even if their TimeZone-local window would otherwise allow weekday-evening runs. This protects production hours from giant data drops that could throttle the tenant.

Operators can override per-row with `ExtendedHours = Yes` — that bypasses both the night window AND the >=10GB weekend-only rule.

**Q: What's `Priority` for?**
A number column. `1` = highest priority. The orchestrator picks rows by priority band, then by `QueuedAt` (FIFO within a band). Use it to push specific waves (VIP migrations, deadline-driven cutovers) ahead of the general queue.

**Q: When should I use `ExtendedHours = Yes`?**
Rarely. The night/weekend window exists for a reason (protect business hours from throttle). Use ExtendedHours for:
- A wave that's running long and you need it to finish before a stakeholder demo
- Test runs where production impact doesn't matter
- A specific row that's blocking dependent work

Don't use it as a default. If you find yourself setting it on most rows, your wave is undersized for the window and you should add migration servers or stretch the timeline instead.

---

## Storage capacity auto-downgrade

**Q: What's `YearUsed` and how does it get set?**
`YearUsed` is the retention horizon SPMT will use for THIS row, expressed as years (`3`, `5`, or `7`). It's set by Phase 2 of `Update-MigrationTargets.v2.ps1`.

Logic:
1. The UNC storage scan (`Invoke-UNCStorageScan-v2.ps1`) computed `Size3YrMB`, `Size5YrMB`, `Size7YrMB` for each row — the total bytes of files modified in the last 3, 5, and 7 years respectively.
2. Phase 2 tries to fit the migration in the destination site's quota. It tries `Size7YrMB` first, then `Size5YrMB`, then `Size3YrMB`.
3. The first one that fits gets stamped into `YearUsed`. SPMT then filters source files by last-modified date matching the chosen horizon.

**Q: What if even 3 years doesn't fit?**
Row is flagged for manual review. Operator decides: request more quota, split the source into multiple rows, or skip files via the SPMT exclusion list.

**Q: Why retention horizons at 3/5/7 years specifically?**
Federal records-retention policy commonly aligns to those bands. Older files often have records-management requirements anyway and shouldn't sit in active OneDrive/Teams — they should be in an archive system. The horizon model lets you migrate what's actively used and defer or archive the rest.

**Q: If `YearUsed = 3`, what happens to files older than 3 years?**
SPMT skips them. They stay at source. The user / data owner needs to be told this — older content isn't moving in this migration. The script doesn't email about this; communicate it as part of the cutover comms.

---

## Multi-server claim locking

**Q: Why claim locking?**
`CommonDriveMigration.v2.ps1` is designed to run on **multiple migration servers in parallel** (default deployment: 6 servers, 3 SPMT worker instances per server = 18 concurrent SPMT sessions). Without claim locking, two servers could pick up the same row and both try to migrate it.

**Q: How does it work?**
When a server picks a row:
- Sets `ClaimedBy = $Env:COMPUTERNAME` (the server's hostname).
- Sets `ClaimedAt = current timestamp`.

Other servers see the claim and skip that row.

When the server finishes (success or failure), it clears the claim columns.

If a server crashes mid-row and never clears the claim, the row would be stuck forever — except for `ClaimStaleHours`.

**Q: What's `ClaimStaleHours`?**
The auto-release window. Default is **2 hours**. If a claim is older than 2 hours and the migration didn't complete, the orchestrator considers the claim abandoned and releases it. Another server can then pick up the row.

(Note: prior knowledge files said "24 hours" — that was wrong. The actual script default is `2`.)

**Q: Should I manually clear a stuck claim?**
If you know the runner is dead and you can't wait the rest of the 2 hours, yes — clear `ClaimedBy` and `ClaimedAt` on the row. Otherwise, let auto-release handle it.

**Q: What if two servers do pick up the same row somehow?**
That shouldn't happen with claim locking, but if it does (SharePoint list eventual-consistency hiccup), the second-write loses. The row will end up in whatever state the last write set it to. In practice, with 2-hour stale windows, double-pickup is vanishingly rare.

---

## App registrations

**Q: Why 36 app registrations?**
Breakdown:
- **1 Graph app** — Phase 1 of `Update-MigrationTargets` (Team owner add + channel folder provisioning). Delegated auth.
- **6 SPO Admin apps** — one per migration server. Handles Phase 2 + orchestrator-level SPO admin operations. App-only certificate auth.
- **18 SPMT worker apps** — one per concurrent SPMT session (6 servers × 3 sessions). **Each app gets its own throttle bucket in SPO**, so the 18 concurrent workers spread their throttle pressure across 18 identities — SPO rarely returns 429.
- **11 Helper apps** — dashboard, landing page, retry tool, scan tool, system docs, etc.
- **Total: 36.**

**Q: Are they interchangeable?**
**No.** Each script expects a specific app type. The Graph app can't grant SCAs; the SPO Admin apps can't add M365 Group Owners; the SPMT worker apps can't run helper utilities. Don't say "36 SPO apps" — they're 1+6+18+11 of distinct types.

**Q: Why 18 workers and not just 6 (one per server)?**
Per-app throttle. If all 6 servers used the same app reg for SPMT, the 6 concurrent sessions would all share one throttle bucket → tenant would 429 us under heavy load. By giving each concurrent session its own app reg, we spread the load. 18 apps = 18 throttle buckets = comfortable headroom.

---

## The state machine

**Q: What's the column-by-column lifecycle?**

```
(blank) → Ready → Stage → Staged | StagedWithErrors | MigrateOnly → Migrating → Migrated | MigratedWithErrors | Failed
```

In `Migrate` column values:

| Value | Set by | Meaning |
|---|---|---|
| (blank) | Import script | Row exists but isn't queued |
| `Ready` | Operator | Eligible for staging |
| `Stage` | Operator | Operator-overridden; in case you want to explicitly stage |
| `Staged` | Orchestrator | Stage pass succeeded; ready for Migrate |
| `StagedWithErrors` | Orchestrator | Stage pass had per-file errors; review then decide |
| `MigrateOnly` | Operator | Skip staging; do full migration in one pass |
| `Migrating` | Orchestrator | Migrate pass in progress (this is a transient lock-equivalent; ClaimedBy/ClaimedAt are the actual lock) |
| `Migrated` | Orchestrator | Clean cutover success |
| `MigratedWithErrors` | Orchestrator | Cutover had per-file errors; CSV attached |
| `Failed` | Orchestrator | Hard failure during Migrate pass |
| `StageFailed` | Orchestrator | Hard failure during Stage pass |

**Q: Why have `Stage` AND `Ready`?**
`Ready` is the operator's "I've queued this, the orchestrator picks the next action based on `-MigrationType`." `Stage` is explicit "I want to stage this row, regardless of where it would otherwise be in the lifecycle." Most operators use `Ready` and let the `-MigrationType Both` or `-MigrationType Stage` flag control behavior.

**Q: How does `-MigrationType Both` work?**
Picks `Ready` rows → stages them → flips to `Staged` → in the same run, picks up the just-`Staged` rows and migrates them. Useful for small batches where you want one-pass cutover. For large waves, run `Stage` and `Migrate` separately so you can review staging errors before committing to cutover.

---

## Retry and failures

**Q: A row is `Failed`. What now?**
1. Look at `ScriptError` column — it has a categorized error (LICENSE / UPN / ONEDRIVE PROVISIONING / ATTACHMENT / CONTENT MOVE / AD / SITE ADMIN / FATAL / GENERAL).
2. Open the per-row `Log` column for the full transcript path.
3. Fix the root cause based on the category.
4. Clear `ClaimedBy`, `ClaimedAt`, set `Migrate = Ready` (or use `Retry-FailedMigration.ps1` for per-file-level retry).

**Q: What's `Retry-FailedMigration.ps1` for?**
Per-file-level retry. After a `MigratedWithErrors` or `StagedWithErrors`, the SPMT failure report has the specific files that didn't move. `Retry-FailedMigration.ps1` reads the CSV, attempts to re-migrate just those files, and detects 0-byte uploads (a silent SPMT failure mode where the target file exists but is empty).

**Q: What's "0-byte upload detection"?**
SPMT occasionally writes a 0-byte placeholder at target instead of the real file. SPMT reports "success." Without 0-byte detection, the user gets an empty file and thinks the migration worked. `Retry-FailedMigration.ps1` checks target file sizes against source and re-uploads any 0-byte mismatches.

**Q: What's `-DeleteSource` and when do I use it?**
A flag on `Retry-FailedMigration.ps1` (NOT on the orchestrator). After verified target write, deletes the source file. **Use carefully** — only when target is confirmed good and the customer has signed off on source removal. Default is OFF.

---

## What's NOT in scope for this agent

- Per-user OneDrive migrations (H: drive → OneDrive) → route to **H: Drive agent**.
- On-prem MySite → SPO OneDrive → route to **OnPrem → SPO agent**.
- On-prem SharePoint site → SPO site → route to **OnPrem → SPO agent**.
- Cross-tenant migrations → out of scope; tell the operator.
- Mailbox migrations → out of scope.

---

## "Where does X live?"

| What | Where |
|---|---|
| UNC source | `\\fileserver\share\<division>\Common\...` (typical) |
| Driver list | SPO list `CommonMigrationStatus` on the orchestrator site |
| Per-row log | SPO list row `Log` column (multi-line, contains transcript path) |
| Per-row error | `ScriptError` column (multi-line, APPEND-only) |
| SPMT transcripts | `F:\SPMTLOGS\` on the runner host |
| Migration dashboard | SPO page produced by `New-MigrationDashboard.ps1` |
| Landing page | SPO page produced by `New-MigrationLandingPage.ps1` |
| User manual page | SPO page produced by `New-MigrationUserManualPage-Simple.ps1` |

---

## "How do I explain this to my PM / customer?"

- **"What's moving?"** Shared / common UNC drives (the network folders multiple people in a unit collaborate in). The destination is either a Teams channel folder (Flow A) or a SharePoint Online site (Flow B), depending on whether the unit collaborates in Teams or needs a stand-alone document library.
- **"What's the engine?"** SharePoint Migration Tool. Microsoft's own. Free.
- **"What's the wrapper?"** A PowerShell orchestrator + SharePoint list as the work queue + scheduling logic (time zones, federal holidays, large-file weekend-only) + multi-server claim locking + storage-quota auto-fit + Teams provisioning. Lets us run 6 servers, 18 concurrent migrations, across federal-scale waves without manual coordination.
- **"What's the user experience?"** Pre-migration: nothing changes. Cutover: the new Teams channel folder or SPO site has the content. End users get a notification email through Power Automate.
- **"What does it cost?"** SPMT is free. The wrapper is internal IP. Vendor alternatives (ShareGate, AvePoint, Quest) start at five to six figures annually and most don't run in IL5/IL6. Use those figures as orientation, not as quoted prices — RFQ for actuals.
- **"What's the risk?"** Content is copied, not moved. UNC source stays as a fallback. `Retry-FailedMigration.ps1 -DeleteSource` is the only thing that deletes source, and only after verified target writes.
