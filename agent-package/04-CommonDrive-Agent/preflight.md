# Pre-flight Checklist — Common Drive → SPO (2026)

The most involved deployment of the three. Plan for several days of setup at first.

## 1. App registrations (36 total)

- [ ] **1 Graph (delegated)** — `Group.ReadWrite.All`, `Sites.FullControl.All`, `User.Read`, admin consent
- [ ] **6 SPO Admin (app-only)** — `Sites.FullControl.All`, one per worker server, cert auth
- [ ] **18 SPMT worker (app-only)** — `Sites.FullControl.All`, distinct cert per app for throttle isolation
- [ ] **11 Helper (app-only)** — `Sites.FullControl.All` (most), `Sites.Read.All` (read-only ones)
- [ ] All app reg cert thumbprints documented in a vault.
- [ ] Cert distribution to each server's `CurrentUser\My` automated.

## 2. Identity

- [ ] `svc-migration` service account exists.
- [ ] svc-migration can be added as M365 Group Owner (no admin block on the account).
- [ ] Human admin available for Phase 1 of UMT (delegated Graph requires a person).

## 3. Source environment

- [ ] All source UNCs `\\server\share\<unit>\...` reachable from all 6 worker servers.
- [ ] DFS / namespace resolution consistent across servers (otherwise different servers see different content).
- [ ] No SMB encryption blocking SPMT scans.
- [ ] Storage scan ran once per row: `Size3YrMB` / `Size5YrMB` / `Size7YrMB` populated.

## 4. Target environment (SPO)

- [ ] Tenant URL confirmed for the right cloud.
- [ ] Per-target site / Teams team quota sized for `YearUsed` horizon.
- [ ] Sharing policy / external sharing confirmed.
- [ ] Driver list created with all columns from `command-reference.md`.
- [ ] Power Automate flow on driver list configured.

## 5. Workers (6 servers, 18 worker slots)

- [ ] 6 Windows servers with PS7.
- [ ] PnP.PowerShell at compatible version on each.
- [ ] SPMT installed and up-to-date on each.
- [ ] Each server has its SPO Admin app reg cert in `CurrentUser\My`.
- [ ] Each server's 3 worker slots mapped to 3 of the 18 SPMT worker app regs (no overlap across servers).
- [ ] Scheduled task or service to launch `CommonDriveMigration.v2.ps1` per slot.
- [ ] Outbound network to SPO, Graph endpoints for the right cloud.

## 6. Scheduling configuration

- [ ] US federal holiday calendar verified for the year (currently hardcoded — review yearly).
- [ ] Per-row `TimeZone` set correctly for distributed agencies.
- [ ] `Priority` set for high-value rows.
- [ ] Large rows (≥10GB) confirmed they can wait for weekend/holiday windows.
- [ ] `ExtendedHours = Yes` set sparingly with business approval.

## 7. UMT Phase 1 (one-time per Team)

- [ ] List of Teams to provision identified.
- [ ] Human admin scheduled to run Phase 1 of `Update-MigrationTargets.v2.ps1` in delegated context.
- [ ] Phase 1 results verified: `svc-migration` is M365 Group Owner; channel folder exists in SharePoint document library.

## 8. Driver list rows

- [ ] `Import-MigrationSources.ps1` run; `Migrate` column **blank** (NOT "Pending").
- [ ] `Invoke-UNCStorageScan-v2.ps1` run; size columns populated.
- [ ] UMT Phase 2 run; `YearUsed` populated; SCAs granted on targets.
- [ ] No rows have stale `ClaimedBy` / `ClaimedAt`.

## 9. Dry-run

- [ ] Set `Migrate = Ready` on **one** small low-risk row.
- [ ] Run orchestrator with `-MigrationType Stage -MaxItems 1` (no `-Continuous`).
- [ ] Verify `Staged` state.
- [ ] Run with `-MigrationType Migrate -MaxItems 1`.
- [ ] Verify `Migrated` state; target Teams channel folder has content.
- [ ] Verify Power Automate notification flow fired.
- [ ] Verify dashboard page reflects the row in `Complete` stage.

## 10. Go-live

- [ ] All 6 servers running, all 18 worker slots active.
- [ ] `-Continuous` mode enabled with appropriate `-MaxRuntime` (typically 10–22h).
- [ ] On-call CSA has driver list + dashboard access.
- [ ] Escalation tree includes: tenant admin (storage), Graph admin (Phase 1 redo), Microsoft ticket (throttle).
- [ ] Rollback decision tree documented (see `troubleshooting.md`).

## 11. Cloud-specific endpoint matrix

| Env | SPO host | Login | Graph |
|---|---|---|---|
| Commercial | `.sharepoint.com` | `login.microsoftonline.com` | `graph.microsoft.com` |
| GCC-H / IL5 | `.sharepoint.us` | `login.microsoftonline.us` | `graph.microsoft.us` |
| DoD | `.sharepoint-mil.us` | `login.microsoftonline.us` | `graph.microsoft.us` |
| IL6 | `.spo.microsoft.scloud` | `login.microsoftonline.microsoft.scloud` | `graph.microsoft.scloud` |
