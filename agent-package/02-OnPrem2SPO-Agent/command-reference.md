# Command Reference — On-Prem → SPO (2024)

> **Source of truth:** the `.ps1` files in `CopilotStudio-scripts-4agent/OnPrem2SPO2024/`. This card summarizes; always cite the script line for an exact answer.

## Scripts in this playbook

| Script | Purpose | Sub-flow |
|---|---|---|
| `Onboard-CloudHybridSearch-SPOONS-Updated.ps1` | Optional: cloud hybrid search SSA setup | Both |
| `Remove-CloudSSA.ps1` | Tear down a cloud SSA | Both |
| OD2OD runner (MySite → SPO OneDrive) | Per-user MySite content + OneDrive provisioning | OD2OD |
| SP2SPO runner (on-prem site → SPO site) | Per-site content migration | SP2SPO |

## Driver list columns (both flows)

| Column | Type | Set by | Notes |
|---|---|---|---|
| `SourceUrl` | Text | input | on-prem site or MySite URL |
| `TargetUrl` | Text | input | SPO site or OneDrive URL |
| `UserPrincipalName` | Text | input | OD2OD only |
| `Inprocess` | Yes/No | runner | OD2OD lock flag |
| `Processing` | Yes/No | runner | SP2SPO lock flag (DIFFERENT NAME) |
| `Log` | Multi-line | runner | success/error log (NOT `MigrationLog`) |
| `MigrationStatus` | Choice | runner | Migrated / Failed / ErrorLog |
| `ScriptError` | Text | runner | fatal-category tag |

## OD2OD runner — common parameter shape

```powershell
# illustrative — exact param block lives in the script header
.\OD2OD-Runner.ps1 `
    -DriverListUrl  "https://<spo-host>/sites/migration/Lists/OD2OD" `
    -AppClientId    "<od2od-app-guid>" `
    -CertThumbprint "<thumbprint>" `
    -DLLPath        "F:\Tools\" `
    -SleepSeconds   30
```

Key behaviors:
- Looks for rows where `Inprocess` is blank → claims by setting `Inprocess = Yes`.
- Provisions target OneDrive if missing (retries 3×).
- Runs SPMT for MySite → OneDrive content.
- On success: `MigrationStatus = Migrated`, `Inprocess` cleared.
- SCA swap on new OneDrive: ensure `svc-migration` → make SCA → demote original user. (Commented out by default — uncomment to enable.)
- AD block (wwwHomePage flip, group adds/removes) **commented out by default**.
- Email is NOT sent by the script. A Power Automate flow on the list sends user notifications.

## SP2SPO runner — common parameter shape

```powershell
.\SP2SPO-Runner.ps1 `
    -DriverListUrl  "https://<spo-host>/sites/migration/Lists/SP2SPO" `
    -AppClientId    "<sp2spo-app-guid>" `
    -CertThumbprint "<thumbprint>" `
    -DLLPath        "F:\IAU_Scripts\OneDrive_Migration_Scripts\" `
    -SleepSeconds   120
```

Key behaviors:
- Looks for rows where `Processing` is blank → claims with `Processing = Yes`.
- DLLs live in the **different** folder above (compared to OD2OD).
- Sleep is **120s** between row picks (vs 30s for OD2OD).
- Same `Log` column, same `MigrationStatus` semantics.

## Status values you will see

| Value | Meaning | Action |
|---|---|---|
| (blank) | not yet picked | nothing — runner will claim |
| `Inprocess`/`Processing = Yes` | currently being worked | leave alone |
| `Migrated` | done | none |
| `Failed` | hard fail, lock cleared | inspect `Log` + `ScriptError`, edit, re-clear status to retry |
| `ErrorLog` | per-file errors during SPMT | review SPMT log, decide retry vs accept |

## Optional: cloud hybrid search

`Onboard-CloudHybridSearch-SPOONS-Updated.ps1` registers the on-prem SSA with the SPO tenant for unified search during the migration window. Tear it down post-cutover with `Remove-CloudSSA.ps1` if you no longer need hybrid results.

## How to retry a row

1. Open the driver list item.
2. Clear the lock column (`Inprocess` or `Processing`).
3. Clear `MigrationStatus` (or leave it — runner re-evaluates).
4. Save. Next runner cycle will pick it back up.

## Cloud portability

Endpoint suffix swap only — see `system-prompt.md` "CLOUD PORTABILITY" block. The PnP + SPMT calls auto-target the host suffix you pass.
