# Common Drive → SPO — Knowledge Cards

One card per script in the 2026 playbook, plus reference tables. Upload this
file along with all 11 `.ps1` files from
`CopilotStudio-scripts-4agent/CommonDrive2026/` as the agent's knowledge.

---

## Flow A vs Flow B — quick comparison

| Aspect | Flow A (Teams channel) | Flow B (SPO site only) |
|---|---|---|
| Target | A channel folder inside a Team's SPO site | A regular SPO site (no Team) |
| `TeamName` column | **Required** | Blank |
| `TeamChannel0` column | Required (defaults to General if missing) | Blank |
| Direct `SiteUrl` column | Resolved by script | **Required, user-provided** |
| `Update-MigrationTargets.v2.ps1` | **Run before migration** | Skip |
| Graph API used | Yes (Team + Channel lookup) | No |
| Channel folder auto-provisioning | Yes | N/A |
| Service-account perms granted on | Resolved Team site | The provided SPO site |
| Everything after that | Identical pipeline (Scan → Worker → Dashboard) | Identical pipeline |

---

## Driver list columns (CommonDriveMigration)

User-entered (per row):

| Column | Required | Notes |
|---|---|---|
| `DIV` | Yes | Organization / division code (e.g. `org1`) |
| `Title` | Yes | Display title (e.g. `HR Files`) |
| `ITDistro` | Yes | IT distribution group / contact |
| `SourcePath` | Yes | UNC path to source folder |
| `TimeZone` | If `-UseScheduling` | `EST` / `CST` / `MST` / `PST` / `AKST` / `HST` / `ANYTIME`. Anchors the migration window. |
| `Priority` | Optional | 1 = highest. Sorts the queue within a window. |
| `ExtendedHours` | Optional | `Yes` = ignore the time-of-day window for this row. |
| `TeamName` | Flow A only | Destination Team display name |
| `TeamChannel0` | Flow A only | Channel name (defaults to General) |
| `SiteUrl` | Flow B only | Direct target SPO site URL |

Auto-populated by scripts:

| Column | Source |
|---|---|
| `TeamChannelError` | `Update-MigrationTargets.v2.ps1` Phase 1 when resolution fails |
| Resolved `SiteUrl` (Flow A) | `Update-MigrationTargets.v2.ps1` Phase 1 |
| `Migrate` | Orchestrator. **Many states** — see "Migration states" below. |
| `Stage` | Orchestrator (staging pipeline state). |
| `ClaimedBy` | Orchestrator (`$Env:COMPUTERNAME` of the runner that claimed the row). |
| `ClaimedAt` | Orchestrator (claim timestamp, paired with `ClaimStaleHours`). |
| `QueuedAt` | Orchestrator (FIFO ordering within a priority band). |
| `Size3YrMB` / `Size5YrMB` / `Size7YrMB` | `Invoke-UNCStorageScan-v2.ps1` |
| `YearUsed` | `Update-MigrationTargets.v2.ps1` Phase 2 (auto-downgrade result) |
| `LOG` / per-run timestamps | Worker |

---

## Migration states (the `Migrate` column)

| Value | Meaning |
|---|---|
| *(blank)* | Untouched. `Import-MigrationSources.ps1` leaves new rows blank. |
| `Ready` | Operator marks the row ready to be picked up. |
| `Stage` | Queued for the staging (initial bulk) copy. |
| `Staged` | Staging copy succeeded; ready for delta + cutover. |
| `StagedWithErrors` | Staging had per-file errors; review before cutover. |
| `MigrateOnly` | Skip staging; do a single-pass full migration. |
| `Migrating` | SPMT is actively running on this row. |
| `Migrated` | Done. |
| `ErrorLog` | Per-file errors; `ItemReport_R1.csv` (or `ItemFailureReport_*.csv`) attached. |
| `Failed` | Hard failure. Claim is released so another runner can retry. |

---

## Scheduling & TimeZone behavior

`CommonDriveMigration.v2.ps1 -UseScheduling` makes the orchestrator only
pick up rows whose **scheduled migration window** is currently open.

**Default allowed windows (overridable in the script):**

- **Weekdays (Mon–Fri):** 5:00 PM → 6:00 AM next day (in the row's local
  `TimeZone`).
- **Weekends (Sat–Sun):** 24 hours.
- **U.S. federal holidays:** 24 hours (the script ships with a holiday
  list; check the source to confirm dates for your year).

**TimeZone column values:** `EST`, `CST`, `MST`, `PST`, `AKST`, `HST`.

**Special values:**

- `TimeZone = ANYTIME` — row ignores the window entirely.
- `ExtendedHours = Yes` — row ignores the window entirely (per-row
  override).

**Large Migration Threshold:** any row whose total size is `>= 10 GB`
is restricted to **weekends/holidays only**, regardless of `TimeZone`,
unless `ExtendedHours = Yes`.

**`QueuedAt`** is stamped when a row enters the active queue and is used
for FIFO ordering within each `Priority` band.

Without `-UseScheduling`, the orchestrator runs everything it sees as fast
as the workers can pick it up.

---

## Storage capacity auto-downgrade

`Invoke-UNCStorageScan-v2.ps1` computes THREE sizes per source:

| Column | Files included |
|---|---|
| `Size7YrMB` | Modified within the last 7 years |
| `Size5YrMB` | Modified within the last 5 years |
| `Size3YrMB` | Modified within the last 3 years |

`Update-MigrationTargets.v2.ps1` Phase 2 picks the **largest horizon that
still fits** in the target site's available quota, trying `7yr → 5yr → 3yr`
in that order. The chosen horizon is stamped into the `YearUsed` column.
SPMT then filters source files by last-modified date matching the chosen
horizon.

If even the 3-year horizon won't fit, the row is flagged for manual
review (operator must request more quota or split the source).

---

## Multi-server claim locking

`CommonDriveMigration.v2.ps1` is designed to run on **multiple migration
servers in parallel** (default deployment is 6 servers). To prevent two
servers from picking up the same row:

| Field | What it does |
|---|---|
| `ClaimedBy` | `$Env:COMPUTERNAME` of the server that claimed the row. |
| `ClaimedAt` | Timestamp of the claim. |
| `ClaimStaleHours` | (script parameter, default `2`) How long before a claim is considered abandoned. Stale claims are auto-released so another server can pick the row up. |

This is in addition to the per-row `Migrate` state machine; the two
together make the orchestrator safe to scale horizontally.

---

## Script: `Import-MigrationSources.ps1`

**Purpose:** Build SPO list rows from a CSV of UNC paths.

**Behavior:**
- Accepts a CSV. For UNC paths ending in `\Common\` (or similar), enumerates
  subfolders and creates one list row per subfolder.
- Extracts `DIV` from the UNC pattern: `\\server\share\<DIV>\Common\...`
- Examples:
  - `\\contoso-fs\userdata\org1\Common\HR Files` → DIV=`org1`, Title=`HR Files`
  - `\\contoso-fs\userdata\org2\Common\Unit Data\Reports` → DIV=`org2`,
    Title=`Reports`
- Adds rows to the `CommonDriveMigration` list with `Migrate` **left BLANK**
  (the operator flips it to `Ready` / `Stage` / `MigrateOnly` to start work).

**Sample:**
```powershell
.\Import-MigrationSources.ps1 -CsvPath F:\Migration\sources.csv
```

---

## Script: `Invoke-UNCStorageScan-v2.ps1`

**Purpose:** Pre-flight scan of every UNC source in the list — total size,
file count, top file extensions, oldest/newest mod date. Also computes
**three retention-horizon sizes** for the auto-downgrade step.

**Use it for:**
- Sizing the migration window.
- Catching unexpectedly large drops (e.g., archives, PSTs).
- Generating an `Excluded Extensions` recommendation.
- Populating `Size3YrMB`, `Size5YrMB`, `Size7YrMB` so
  `Update-MigrationTargets.v2.ps1` Phase 2 can auto-pick a retention horizon
  that fits the target quota.

**Sample:**
```powershell
.\Invoke-UNCStorageScan-v2.ps1
# Updates the SPO list with size + file-count + 3/5/7-year size columns.
```

---

## Script: `Update-MigrationTargets.v2.ps1` — TWO PHASES

**Purpose:** Combined pre-migration helper. Runs in TWO distinct phases
because they have different auth needs and different cadences.

### Phase 1 — INTERACTIVE (Flow A only)

- Runs as a **human admin** (delegated Graph auth, interactive sign-in).
- For each list row with `TeamName` populated:
  - Graph call: get Team by display name → SiteUrl.
  - Graph call: get channel by name → channel folder.
  - **Adds the migration service account** (`svc-migration@contoso.gov`)
    **as an M365 Group Owner** of the Team — this requires a human admin
    consent, which is why Phase 1 is delegated.
  - **Auto-provisions** the channel folder if Teams hasn't initialized it
    yet (Teams lazy-creates channel folders on first file upload).
  - Writes back: resolved `SiteUrl`, or `TeamChannelError` if resolution
    failed.
- Skip Phase 1 entirely for Flow B.

### Phase 2 — AUTOMATED (Flow A and Flow B)

- Runs **app-only** against the SPO Admin endpoint (no human).
- For each row:
  - **Storage capacity check** + **auto-downgrade**: tries to fit the
    migration in the destination quota using `Size7YrMB → Size5YrMB →
    Size3YrMB`. Stamps the result into `YearUsed`. SPMT then filters
    source files by the chosen retention horizon.
  - **Grants `svc-migration` as Site Collection Admin** on the target
    site (idempotent; safe to re-run).
- Phase 2 is safe to schedule on a loop because it's idempotent and
  app-only.

**Auth:** Phase 1 delegated Graph; Phase 2 certificate-based app-only.
**Endpoints:** `https://graph.microsoft.scloud`,
`https://login.microsoftonline.microsoft.scloud`,
SPO Admin (`https://contoso-admin.spo.microsoft.scloud`).

**Sample:**
```powershell
.\Update-MigrationTargets.v2.ps1 -Phase 1   # interactive Graph
.\Update-MigrationTargets.v2.ps1 -Phase 2   # app-only SPO Admin
```

Flow B starts at Phase 2.

---

## Script: `CommonDriveMigration.v2.ps1`

**Purpose:** The orchestrator (4865+ lines). Reads the driver list, hands
work to `SPMT-Worker.v2.ps1`, watches status, writes results back.

**Key knobs (in the script):**
- `$RequiredTargetUrlPrefix` — guardrail; refuses to migrate if the resolved
  target isn't under this prefix.
- `$AppClientId` / `$AppTenantId` — default app identity (overridable per
  run via `-AppClientIdParam` / `-AppCertThumbprintParam`).
- `PreservePermission = $false` — disabled on Team Sites (can cause SPMT to
  error out otherwise).
- `MigrateFileVersionHistory = $true` / `KeepAllVersions = $true`
- `ReplacementOfInvalidChar = "_"`
- `ClaimStaleHours = 2` — how long before a `ClaimedBy` claim is auto-released.

**Parameters:**

| Parameter | Meaning |
|---|---|
| `-UseScheduling` | Honor `TimeZone` / `Priority` / window rules. |
| `-MigrationType Stage` | Staging copy only (`Migrate` becomes `Staged` / `StagedWithErrors`). |
| `-MigrationType Migrate` | Pick up rows already in `Staged`; do delta + cutover. |
| `-MigrationType MigrateOnly` | Skip staging; single-pass migration. |
| `-MigrationType Both` | Stage then immediately Migrate. |
| `-Continuous` | Loop instead of exiting after one pass. |
| `-MaxRuntime <minutes>` | Self-terminate after N minutes (good for matching the scheduling window). |
| `-MaxItems <n>` | Cap how many rows this run will pick up. |
| `-AppClientIdParam <guid>` | Override the configured app id (lets you swap throttle identity per run). |
| `-AppCertThumbprintParam <thumb>` | Override the configured cert. |

**Behavior:**
- Refuses target URLs outside `$RequiredTargetUrlPrefix`.
- Honors the multi-server claim system (`ClaimedBy` / `ClaimedAt` /
  `ClaimStaleHours`).
- Updates `Migrate` through the full state machine
  (`Stage` / `Staged` / `StagedWithErrors` / `MigrateOnly` / `Migrating` /
  `Migrated` / `ErrorLog` / `Failed`).
- Writes `LOG`, timestamps, and per-run telemetry.
- Sleeps between dispatches.

---

## Script: `SPMT-Worker.v2.ps1`

**Purpose:** The actual SPMT executor. Designed to run as multiple instances
across multiple servers.

**Key behaviors:**
- Reads its assigned subset of the work queue.
- Uses one of the 18 SPMT-worker app registrations (3 per server x 6 servers).
- `PreservePermission = $false`.
- Writes per-task logs to `F:\SPMTLOGS\task<n>\`.
- On per-file failures, generates `ItemReport_R1.csv` and / or
  `ItemFailureReport_*.csv` for retry. Both formats are consumed by
  `Retry-FailedMigration.ps1`.

**Typical layout:** 6 servers × 3 SPMT worker instances = **18 concurrent
SPMT sessions**, each holding a different SPMT-worker app identity for
throttle distribution.

---

## Script: `Retry-FailedMigration.ps1`

**Purpose:** Re-migrate items from a failure report produced by SPMT.
Accepts **both** formats SPMT can emit:

- `ItemReport_R1.csv` (standard per-item report)
- `ItemFailureReport_*.csv` (SPMT v2 failure report)

Also **detects 0-byte uploads** at the target (a common silent failure
mode) and re-queues those items.

**Parameters:**
- `-CsvPath` — path to the failure CSV.
- `-SiteUrl` — destination SPO site URL.
- `-TargetSubfolder` — optional subfolder (e.g., `"General"` for a Teams
  channel).
- `-DeleteSource` — delete the source file after a successful retry.
  **Source deletion only fires after the upload is verified at the target**
  (size + existence check).

**Sample:**
```powershell
.\Retry-FailedMigration.ps1 `
    -CsvPath "F:\SPMTLOGS\task1\ItemReport_R1.csv" `
    -SiteUrl "https://contoso.spo.microsoft.scloud/sites/TeamSite" `
    -TargetSubfolder "General" `
    -DeleteSource
```

---

## Reporting / UX generators

| Script | What it does |
|---|---|
| `New-MigrationDashboard.ps1` | Live status dashboard SPO page. **`Scanned` counter is cumulative** (sum across all runs, not the current run). Surfaces pipeline stages: `Awaiting Scan` / `Awaiting Target` / `Resolved` / `Queued` / `Migrating` / `Complete`. Per-DIV breakdown. |
| `New-MigrationLandingPage.ps1` | CSA hub: **auto-discovers all divisions** from the driver list and creates filter views per division. Links, instructions, recent activity. |
| `New-MigrationUserManualPage-Simple.ps1` | End-user-facing manual (what they enter in the list, what happens, where their data ends up). |
| `New-SystemDocumentationPage.ps1` | Architecture / system docs page (the 6-server / 18-worker / 36-app picture). |
| `Deploy-SystemDocumentation.ps1` | Pushes the generated pages to the SPO site. |

All five generators output modern SPO pages and use the same app-only
certificate auth.

---

## Authentication & app registrations

**36 total app registrations**, but they are NOT all the same type. The
mix matters for governance and quota planning:

| App role | Count | Used by | Auth | Permissions |
|---|---|---|---|---|
| Graph app | 1 | `Update-MigrationTargets.v2.ps1` Phase 1 | Delegated (interactive admin) | `Team.ReadBasic.All`, `Channel.ReadBasic.All`, `Sites.Read.All`, `Group.ReadWrite.All` (to add svc account as Team owner) |
| SPO Admin app | 6 | `Update-MigrationTargets.v2.ps1` Phase 2 + orchestrator; one per migration server | App-only (certificate) | SPO Admin Sites.FullControl.All |
| SPMT worker app | 18 | `SPMT-Worker.v2.ps1`; 3 per server x 6 servers | App-only (certificate) | SPO Sites.FullControl.All (each is its own throttle bucket) |
| Helper / reporting app | 11 | Dashboard, Landing Page, System Documentation, Retry tool, Storage Scan tool, etc. | App-only (certificate) | Scoped per script (typically Sites.FullControl.All + Sites.Read.All) |
| **Total** | **36** | | | |

Auth model at runtime: **certificate-based app-only**, except Phase 1 of
`Update-MigrationTargets.v2.ps1` (delegated, human admin).

**Placeholders in scripts:**
- `$AppClientId = "bbbbbbbb-..."` (default) or `cccccccc-...` / `dddddddd-...`
- `$AppTenantId = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"`
- Replace with your real Entra app + tenant IDs.

---

## Scale architecture

- **6 servers** running the worker.
- **3 SPMT worker instances per server** = **18 concurrent SPMT sessions**.
- **18 SPMT worker app registrations** are rotated through workers (one
  per concurrent session) — each registration is its own throttle bucket in
  SPO, so the 18 concurrent workers spread their throttle pressure across
  18 identities and rarely hit 429.
- **6 SPO Admin apps** (one per server) handle `Update-MigrationTargets.v2`
  Phase 2 work + orchestrator-level SPO Admin operations.
- **1 Graph app** handles Team/Channel resolution (Flow A, Phase 1 only,
  delegated auth).
- **11 Helper apps** power the dashboard, landing page, retry tool, etc.
- **Multi-server claim locking** (`ClaimedBy` / `ClaimedAt` /
  `ClaimStaleHours`) keeps all 6 servers from picking up the same row.

---

## Prerequisites

- SPMT 4.2.129.0+ installed on every worker host.
- PowerShell modules on every host: `SPMT`, `PnP.PowerShell`,
  `Microsoft.Graph` (or the subset modules), `Microsoft.Online.SharePoint
  .PowerShell`.
- All certificates deployed to each worker (LocalMachine or CurrentUser
  store).
- Entra app registrations provisioned (1 Graph + 6 SPO Admin + 18 SPMT
  worker + 11 Helper = 36 total).
- Migration service account exists in Entra (placeholder
  `svc-migration@contoso.gov`).
- Driver SPO list provisioned with required columns.
- Network line of sight: workers → UNC source AND workers → SPO + Graph
  endpoints.

---

## Common errors

| Symptom | Likely cause | Fix |
|---|---|---|
| `TeamChannelError` populated | Team / channel name typo, or Team not yet provisioned | Verify Team display name in Teams admin; rerun `Update-MigrationTargets.v2.ps1` |
| `Required target URL prefix` rejection | Resolved site is outside `$RequiredTargetUrlPrefix` | Either correct the target or relax the prefix |
| SPMT 401 / cert error | Wrong cert or thumbprint, or cert not in trust store | Re-deploy cert; verify `Get-ChildItem Cert:\` |
| 429 throttle | Too many ops on one app registration | Confirm 36 apps in rotation; reduce per-worker concurrency |
| `PreservePermission` error on Team Sites | SPMT enables it by accident | Confirm `PreservePermission = $false` in worker config |
| Per-file failures (`FailureSummaryReport.csv`) | Long paths, invalid chars, locked files | Use `Retry-FailedMigration.ps1` |
| Channel folder missing | Teams hasn't initialized it (lazy provisioning) | `Update-MigrationTargets.v2.ps1` auto-creates |
| Service account no perms | Grant step skipped or wrong site | Re-run `Update-MigrationTargets.v2.ps1` (Flow A) or grant manually (Flow B) |

---

## Sample invocations

### Flow A (Teams channel target)

```powershell
# 1. Build the list
.\Import-MigrationSources.ps1 -CsvPath F:\Migration\sources-flowA.csv

# 2. Storage scan
.\Invoke-UNCStorageScan-v2.ps1

# 3. Resolve Teams targets + grant perms + provision channel folders
.\Update-MigrationTargets.v2.ps1

# 4. Run the orchestrator (or directly launch workers on each host)
.\CommonDriveMigration.v2.ps1
#    └─ each worker host runs:  .\SPMT-Worker.v2.ps1 -WorkerId N

# 5. (As needed) retry per-file failures
.\Retry-FailedMigration.ps1 -CsvPath "F:\SPMTLOGS\task1\FailureSummaryReport.csv" `
    -SiteUrl "https://contoso.spo.microsoft.scloud/sites/MyTeam" `
    -TargetSubfolder "General"

# 6. Dashboards / docs
.\New-MigrationDashboard.ps1
.\Deploy-SystemDocumentation.ps1
```

### Flow B (straight SPO site)

```powershell
# 1. Build the list (CSV must include SiteUrl, TeamName blank)
.\Import-MigrationSources.ps1 -CsvPath F:\Migration\sources-flowB.csv

# 2. Storage scan
.\Invoke-UNCStorageScan-v2.ps1

# (skip Update-MigrationTargets.v2.ps1 — nothing to resolve)

# 3. Grant svc-migration perms on each target SPO site (one-time, manual
#    or via your own helper — UMT is Flow A specific)

# 4. Run the orchestrator
.\CommonDriveMigration.v2.ps1

# 5. Retry / report as in Flow A.
```

---

## Reminders

- Sanitized placeholders (`contoso.*`, `aaaaaaaa-...` / `bbbbbbbb-...` /
  `cccccccc-...` / `dddddddd-...` GUIDs, `@contoso.gov`,
  `svc-migration@contoso.gov`) must be replaced with your tenant's values.
- Cert thumbprints in the scripts are placeholders — replace.
- The scripts assume `microsoft.scloud` endpoints (sovereign / IL6). They
  port cleanly to commercial or IL5 by swapping host suffixes only — no
  logic changes:
  | Cloud | SPO | Login | Graph |
  |---|---|---|---|
  | Commercial | `.sharepoint.com` | `login.microsoftonline.com` | `graph.microsoft.com` |
  | IL5 (GCC-H) | `.sharepoint.us` | `login.microsoftonline.us` | `graph.microsoft.us` |
  | IL5 (DoD) | `.sharepoint-mil.us` | `login.microsoftonline.us` | `dod-graph.microsoft.us` |
  | IL6 (sovereign) | `.spo.microsoft.scloud` | `login.microsoftonline.microsoft.scloud` | `graph.microsoft.scloud` |

---

## Why this playbook — Common Drive → SPO (positioning)

### The competitive landscape (2026)

> **Pricing disclaimer.** All vendor cost figures below are **industry
> estimates** based on publicly-discussed federal SI engagements
> 2023–2026. None are quoted prices. ShareGate, AvePoint, Quest, and
> BitTitan price by RFQ; ranges vary widely by user count, term, and
> federal premium. **Confirm with a current vendor RFQ before citing any
> number in a customer-facing conversation.**

| Tool | Target | Cloud reach | Licensing | Federal CUI/IL5/IL6 |
|---|---|---|---|---|
| **This playbook (SPMT + scripts)** | Teams channel folder OR SPO site | Commercial, GCC, GCC-H/IL5, IL6 | **Free** (SPMT) + owned wrapper IP | **Yes — verified in IL6 production** |
| **Microsoft SharePoint Migration Manager (SAC UI)** | SPO site | Commercial, GCC; limited GCC-H | Free | No IL6; one-off only, no scheduling |
| **ShareGate Migrate** | SPO site (+ Teams w/ workarounds) | Commercial, GCC | $80k–$200k+/yr at scale | **No IL5/IL6 SaaS instance** |
| **AvePoint Fly + Confidence Platform** | SPO, Teams, multi-target | Commercial, GCC, GCC-H | Six-figure annual | GCC-H yes; IL6 not publicly documented |
| **Quest On Demand Migration (ex-Metalogix)** | SPO + multi-workload | Commercial SaaS | $50k–$200k+/yr | SaaS routing concerns |
| **BitTitan MigrationWiz** | SPO / OD / mailbox | Commercial SaaS | ~$15–$40/user | **No** — SaaS through commercial Azure |
| **Tzunami Deployer** | SP/SPO from many sources | Commercial | Mid-tier enterprise | No federal story |
| **Syskit Migrator** | SP/SPO + Teams | Commercial | Mid-tier enterprise | No federal story |

### Why this playbook is the federal Common-Drive answer

This is the most differentiated of the three playbooks because UNC → Teams channel at federal scale is a market gap most COTS tools don't fill cleanly.

1. **Two-phase Update-MigrationTargets** — no COTS tool models this:
   - **Phase 1 (INTERACTIVE, delegated Graph):** resolve `TeamName` → SiteUrl, resolve `TeamChannel0` → channel folder, **add `svc-migration` as M365 Group Owner** of the Team (delegated because Graph requires a human admin for this), **auto-provision** the channel folder Teams lazy-creates on first file upload.
   - **Phase 2 (AUTOMATED, app-only SPO Admin):** storage capacity check + auto-downgrade, grant `svc-migration` as Site Collection Admin. Idempotent. Safe to schedule on a loop.
   - Separation matters: Phase 1 needs a human (one-time), Phase 2 can run unattended at scale.

2. **TimeZone-aware scheduling with US federal holiday calendar** — built in:
   - Per-row `TimeZone` column: `EST` / `CST` / `MST` / `PST` / `AKST` / `HST` / `ANYTIME`
   - Default migration window: weekdays 5pm–6am (local to row), weekends 24h, US federal holidays 24h
   - `ExtendedHours = Yes` per-row override
   - `Priority` (1 = highest) + `QueuedAt` for FIFO within a band
   - **`-UseScheduling` flag** turns the whole system on/off
   - **No COTS tool ships per-row TimeZone scheduling with federal-holiday awareness.** This was built for distributed agencies operating in 4+ time zones simultaneously.

3. **Large Migration Threshold** — rows >=10 GB auto-restricted to weekends/holidays only (unless `ExtendedHours = Yes`). Protects production hours from giant data drops.

4. **Storage capacity auto-downgrade** — unique to this playbook:
   - `Invoke-UNCStorageScan-v2.ps1` computes `Size3YrMB`, `Size5YrMB`, `Size7YrMB`
   - Phase 2 tries 7yr → 5yr → 3yr retention horizon to fit target quota
   - Stamps result into `YearUsed` column
   - SPMT filters source files by last-modified matching the chosen horizon
   - If even 3yr won't fit → row flagged for manual review (request quota or split)
   - **No COTS tool does this automatically.** ShareGate / AvePoint require pre-migration analysis and a manual decision.

5. **18-worker parallel design across 6 servers** — built for federal scale:
   - **App registration breakdown: 1 Graph + 6 SPO Admin + 18 SPMT worker + 11 Helper = 36 total**
   - 18 SPMT worker apps each carry their own throttle bucket → spreads 18 concurrent SPMT sessions across 18 identities → SPO rarely hits 429
   - 6 SPO Admin apps (one per server) handle Phase 2 + orchestrator work
   - 11 Helper apps power Dashboard, Landing Page, Retry, Scan, System Docs
   - 1 Graph app for Phase 1 interactive Team resolution
   - **Most COTS tools use a single app identity per tenant** — capped at SPO's per-identity throttle.

6. **Multi-server claim locking** — `ClaimedBy = $Env:COMPUTERNAME`, `ClaimedAt`, `ClaimStaleHours = 2` auto-releases abandoned claims. Run 6 migration servers in parallel with zero double-pickup risk. **No COTS tool models stale-claim auto-release for horizontal scale.**

7. **Full staging pipeline** — `-MigrationType Stage | Migrate | MigrateOnly | Both`:
   - `Stage` = initial bulk copy → `Staged` / `StagedWithErrors`
   - `Migrate` = delta + cutover for already-`Staged` rows
   - `MigrateOnly` = single-pass full migration
   - `Both` = stage then immediately migrate
   - **State machine:** blank → Ready → Stage → Staged/StagedWithErrors/MigrateOnly → Migrating → Migrated/ErrorLog/Failed
   - Lets the customer do a low-risk staging pass weeks before cutover.

8. **Resilient retry-failed-migration** — handles **both** SPMT report formats:
   - `ItemReport_R1.csv` (standard)
   - `ItemFailureReport_*.csv` (SPMT v2 format)
   - **Detects 0-byte uploads at target** (a common silent SPMT failure mode)
   - `-DeleteSource` only fires after verifying upload at target (size + existence)
   - No COTS tool ships 0-byte detection or verify-before-delete logic.

9. **Teams channel folder auto-provisioning.** Teams lazy-creates channel folders on first file upload — but SPMT can't target a folder that doesn't exist. Phase 1 calls SharePoint to create it. **This is the #1 reason DIY Teams migrations fail; this playbook handles it.**

10. **List-driven control plane in SharePoint.** All state in a SharePoint list the customer owns. No external DB. No vendor portal. Backups, exports, FedRAMP boundary containment are trivial.

11. **Reporting/UX generators:**
    - `New-MigrationDashboard.ps1` — pipeline stages (Awaiting Scan / Awaiting Target / Resolved / Queued / Migrating / Complete), Scanned counter is cumulative across all runs, per-DIV breakdown
    - `New-MigrationLandingPage.ps1` — **auto-discovers divisions** from the driver list and creates per-DIV filter views
    - `New-MigrationUserManualPage-Simple.ps1` — end-user guide
    - `New-SystemDocumentationPage.ps1` — architecture page
    - `Deploy-SystemDocumentation.ps1` — pushes the above
    - All output modern SPO pages, all use the same cert auth

12. **Sovereign-cloud native.** Same code in IL6. Endpoint suffix swap only. This is the single biggest reason this playbook exists — there is no other production-proven UNC → Teams channel migration solution in IL6.

### Pricing comparison at scale (illustrative — NOT a quote)

> The figures below are **illustrative only**, sized off public/word-of-mouth
> federal SI ranges. Use them to frame the order of magnitude, **not to make
> a customer-facing claim.** For any real conversation, replace these with a
> live vendor RFQ for the specific user count and term.

For a hypothetical 50,000-source-folder migration (typical federal department):

| Tool | License/year | 3-yr cost | Notes |
|---|---|---|---|
| **This playbook** | **$0** | **$0** | Operators paid out of existing budget |
| ShareGate Migrate (commercial, hypothetical IL5 if it existed) | ~$120k | ~$360k | Not available in IL5/IL6 today |
| AvePoint Fly + Confidence | ~$200k | ~$600k | Real federal cost |
| Quest On Demand | ~$150k | ~$450k | SaaS routing concerns |
| BitTitan MigrationWiz | $40/user × 50k = $2M | $2M one-time | Not viable IL5/IL6 |

### Honest tradeoffs (say so if asked)

- **No GUI for non-PowerShell admins.** Operators need PowerShell + SPO list literacy.
- **No content classification at migration time.** OneDrive/SPO labels apply after the fact.
- **No vendor SLA** — internal support model.
- **Dashboards refresh on demand** (re-run the generator script), not real-time.
- **Setup investment.** First-time deployment requires provisioning 36 app registrations, 6 servers with SPMT, cert deployment, and driver-list schema setup. COTS tools have a faster initial GUI install (but you pay that back in license + sovereign-cloud limitations).
- **Doesn't migrate Teams chat, channel posts, or tabs** — file content only. Use Microsoft's Teams migration tools or AvePoint for chat history.
- **No pre-migration permission analysis.** ShareGate has stronger pre-flight permission mapping.

### When NOT to use this playbook

- Customer has zero PowerShell capability and a hard GUI requirement and a budget for COTS (consider AvePoint in GCC-H).
- Project requires content classification / DLP scoring during migration (consider AvePoint).
- Project is in commercial cloud only AND budget allows ShareGate AND customer prefers a GUI.
- Migration is mailbox + file share + Teams chat all-in-one (consider BitTitan + this playbook for the file share portion only).
- One-off migration of a single small share (use SharePoint Admin Center bulk migration UI — free, GUI, sufficient).
