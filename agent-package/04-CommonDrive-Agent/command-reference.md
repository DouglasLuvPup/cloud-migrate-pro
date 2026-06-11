# Command Reference — Common Drive → SPO (2026)

> **Source of truth:** the `.ps1` files in `CopilotStudio-scripts-4agent/CommonDrive2026/`. Always cite a specific script line for exactness.

## Scripts in this playbook (11)

| Script | Phase | Purpose |
|---|---|---|
| `Import-MigrationSources.ps1` | Intake | Import sources to driver list; leaves `Migrate` BLANK (not "Pending") |
| `Invoke-UNCStorageScan-v2.ps1` | Discovery | Compute `Size3YrMB` / `Size5YrMB` / `Size7YrMB` per row |
| `Update-MigrationTargets.v2.ps1` | Target prep | **Two phases** — see below |
| `CommonDriveMigration.v2.ps1` | Orchestrator | Main runner; honors scheduling + state machine |
| `SPMT-Worker.v2.ps1` | Worker | Per-row SPMT execution; called by orchestrator |
| `Retry-FailedMigration.ps1` | Retry | Re-process `ErrorLog` / `Failed` rows |
| `New-MigrationDashboard.ps1` | Reporting | Pipeline-stage dashboard SPO page |
| `New-MigrationLandingPage.ps1` | Reporting | Auto-discovers DIVs; creates filter views |
| `New-MigrationUserManualPage-Simple.ps1` | Reporting | End-user guide page |
| `New-SystemDocumentationPage.ps1` | Reporting | Architecture page |
| `Deploy-SystemDocumentation.ps1` | Reporting | Pushes the above |

## App registrations (36 total)

| Count | Role | Notes |
|---|---|---|
| 1 | Graph (delegated) | Phase 1 of UMT v2; Team owner add + channel folder provision |
| 6 | SPO Admin (app-only) | Phase 2 of UMT v2 + orchestration; one per server |
| 18 | SPMT worker (app-only) | One per worker slot; each has own throttle bucket |
| 11 | Helper (app-only) | Dashboard, Landing Page, Retry, Scan, System Docs, etc. |

**Total: 36.** Do not say "36 SPO apps" — they have distinct roles.

## Driver list columns (selected, see `knowledge-cards.md` for full schema)

| Column | Type | Set by | Notes |
|---|---|---|---|
| `Title` | Text | input | source path or unit name |
| `SourcePath` | Text | input | `\\server\share\<unit>\Common\...` |
| `TargetUrl` | Text | runner / input | SPO site or Teams channel folder URL |
| `TeamName` | Text | input | Flow A only |
| `TeamChannel0` | Text | input | Flow A only — channel name |
| `Migrate` | Choice | input | blank → Ready → Stage / MigrateOnly → state machine |
| `MigrationStatus` | Choice | runner | Staged / StagedWithErrors / Migrating / Migrated / ErrorLog / Failed |
| `ClaimedBy` | Text | runner | `$env:COMPUTERNAME` |
| `ClaimedAt` | DateTime | runner | for `ClaimStaleHours` (default 2) |
| `TimeZone` | Choice | input | EST / CST / MST / PST / AKST / HST / ANYTIME |
| `ExtendedHours` | Yes/No | input | bypass scheduling window |
| `Priority` | Number | input | 1 = highest |
| `QueuedAt` | DateTime | runner | FIFO within priority band |
| `Size3YrMB` / `Size5YrMB` / `Size7YrMB` | Number | scan | UNC storage scan output |
| `YearUsed` | Choice | runner | 3 / 5 / 7 — chosen retention horizon |
| `Log` | Multi-line | runner | per-row log |
| `ScriptError` | Multi-line | runner | fatal categories (APPENDED) |

## `CommonDriveMigration.v2.ps1` parameters (orchestrator)

```powershell
.\CommonDriveMigration.v2.ps1 `
    -UseScheduling `
    -MigrationType        Both `
    -Continuous `
    -MaxRuntime           (New-TimeSpan -Hours 10) `
    -MaxItems             50 `
    -AppClientIdParam     "<spo-admin-app-guid>" `
    -AppCertThumbprintParam "<thumbprint>"
```

| Parameter | Values | Behavior |
|---|---|---|
| `-UseScheduling` | switch | turns TimeZone + holiday windowing ON |
| `-MigrationType` | `Stage` / `Migrate` / `MigrateOnly` / `Both` | state machine entry point |
| `-Continuous` | switch | keep looping until `MaxRuntime` |
| `-MaxRuntime` | TimeSpan | kill switch |
| `-MaxItems` | int | per-run cap |
| `-AppClientIdParam` | GUID | SPO admin app for this server |
| `-AppCertThumbprintParam` | thumbprint | matching cert |

### `-MigrationType` semantics

| Value | What it does |
|---|---|
| `Stage` | Picks `Migrate = Ready` rows → bulk copy → `Staged` or `StagedWithErrors` |
| `Migrate` | Picks `MigrationStatus IN (Staged, StagedWithErrors)` → delta + cutover |
| `MigrateOnly` | Single-pass full migration; skips staging |
| `Both` | Stage all eligible, then immediately migrate them |

### State machine

```
(blank) → Ready → Stage → Staged | StagedWithErrors | MigrateOnly → Migrating → Migrated | ErrorLog | Failed
```

## `Update-MigrationTargets.v2.ps1` — TWO PHASES

### Phase 1 (INTERACTIVE — delegated Graph)

- Resolve `TeamName` → SiteUrl via Graph.
- Resolve `TeamChannel0` → channel folder URL.
- **Add `svc-migration` as M365 Group Owner** (Graph requires a human admin context for this).
- **Auto-provision the channel folder** Teams lazy-creates on first file upload (SharePoint API call from delegated context).
- One-time per Team. Idempotent.

### Phase 2 (AUTOMATED — app-only SPO Admin)

- Storage capacity check on target site.
- If insufficient: auto-downgrade horizon 7yr → 5yr → 3yr, stamp `YearUsed`.
- If even 3yr won't fit → flag row for manual quota request.
- Grant `svc-migration` as Site Collection Admin on target.
- Idempotent; safe to loop in unattended cron.

## `Invoke-UNCStorageScan-v2.ps1`

Scans `SourcePath` and writes `Size3YrMB` / `Size5YrMB` / `Size7YrMB` based on file `LastWriteTime`. Lets Phase 2 of UMT pick the horizon.

## `Retry-FailedMigration.ps1`

- Handles **both** SPMT report formats: `ItemReport_R1.csv` (standard) and `ItemFailureReport_*.csv` (v2).
- Detects 0-byte uploads at target (silent SPMT failure mode).
- `-DeleteSource` only fires after verifying upload at target (size + existence).

## Scheduling rules (when `-UseScheduling`)

- Default migration window: weekdays **5pm–6am local** to row's `TimeZone`, weekends 24h, US federal holidays 24h.
- **Large Migration Threshold:** rows ≥ 10 GB → weekends/holidays only (unless `ExtendedHours = Yes`).
- `Priority` 1 picked before 2; within same priority, FIFO by `QueuedAt`.
- `ExtendedHours = Yes` overrides the window for that row.

## Multi-server claim locking

- `ClaimedBy` = `$env:COMPUTERNAME`; `ClaimedAt` set on pick.
- `ClaimStaleHours` (default 2): rows claimed > 2h ago auto-released to the pool.
- Allows 6 servers in parallel with zero double-pickup.

## How to retry a row

| Current state | Action |
|---|---|
| `MigrationStatus = ErrorLog` | Clear `MigrationStatus`, `ClaimedBy`, `ClaimedAt`. Set `Migrate = Ready` or use `Retry-FailedMigration.ps1` |
| `MigrationStatus = Failed` | Inspect `ScriptError` first. Clear status + claim columns. Retry |
| Stuck `ClaimedBy` not yours, but > 2h ago | Will auto-release next cycle; or clear manually |
| Storage said 3yr won't fit | Request quota OR shrink source OR split source into multiple rows |
