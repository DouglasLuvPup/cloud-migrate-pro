# Pre-flight Checklist — On-Prem → SPO (2024)

Use this before kicking off either OD2OD or SP2SPO. Federal scope assumed; trim items in commercial.

## 1. Identity & access

- [ ] **Service account** `svc-migration` (or equivalent) exists and is SCA-capable.
- [ ] App registrations in target Entra tenant:
  - [ ] OD2OD app — `Sites.FullControl.All` (app), cert auth, PnP-capable
  - [ ] SP2SPO app — `Sites.FullControl.All` (app), cert auth, PnP-capable
- [ ] App reg certs deployed to **CurrentUser\My** on each worker host that will run the runner.
- [ ] Federal-specific AD groups exist (only if you intend to enable the AD block):
  - [ ] `SecFltr-USR-OneDrive` (the "you have an on-prem OneDrive" group)
  - [ ] `SecFltr-USR-Office365` (target license group)
  - [ ] `O365S-AddOn-License` (if used)
  - [ ] All `*REDIRECTION*` groups identified for removal

## 2. Source environment

- [ ] On-prem SharePoint farm (2016 or 2019) is reachable from worker hosts.
- [ ] User running the script has read access to all source MySites / sites in scope.
- [ ] SPMT prerequisites installed on each worker (.NET, SPMT MSI, latest update).
- [ ] DLL paths:
  - [ ] OD2OD: `F:\Tools\` exists and contains the expected DLLs
  - [ ] SP2SPO: `F:\IAU_Scripts\OneDrive_Migration_Scripts\` exists and contains the DLLs
- [ ] (Optional) Cloud hybrid search SSA registered if unified search is required.

## 3. Target environment (SPO)

- [ ] SPO tenant URL confirmed for cloud level: `.sharepoint.com` / `.sharepoint.us` / `.sharepoint-mil.us` / `.spo.microsoft.scloud`.
- [ ] Tenant has sufficient OneDrive storage quota for the wave.
- [ ] Sharing / external sharing setting confirmed (most federal: internal only).
- [ ] Migration driver list created in a control SPO site, with all required columns (see `command-reference.md`).
- [ ] Power Automate flow on the list configured (email-on-`ErrorLog`, email-on-`Migrated`, etc.).

## 4. Worker hosts

- [ ] At least one Windows Server / Win10+ host with PowerShell 7.
- [ ] PnP.PowerShell module installed at a version compatible with the cert auth flow you use.
- [ ] Execution policy set to allow signed or all (per policy).
- [ ] Network path to source on-prem allowed by firewall + reverse-proxy rules.
- [ ] Outbound to SPO endpoint suffixes allowed.

## 5. Driver list rows

- [ ] CSV or list import populated with `SourceUrl`, `TargetUrl`, `UserPrincipalName` (OD2OD).
- [ ] `Inprocess` (OD2OD) / `Processing` (SP2SPO) columns blank for all candidate rows.
- [ ] `MigrationStatus` blank.
- [ ] (If AD block enabled) AD attributes you intend to flip are documented.

## 6. Dry-run

- [ ] Pick **one** low-risk row.
- [ ] Run the runner with `-WhatIf` (if supported) or manually with a single-row driver list.
- [ ] Verify:
  - Lock column gets set
  - SPMT log generated
  - Target site/OneDrive populated
  - `MigrationStatus = Migrated`
  - Power Automate email arrived (if configured)
  - AD block side-effects only happen if uncommented

## 7. Go-live

- [ ] Wave window communicated to users (Power Automate template approved).
- [ ] Support runbook for the on-call CSA includes:
  - How to clear a stuck lock
  - How to read `Log` + `ScriptError`
  - Who to escalate to for throttle or cert issues
- [ ] Rollback decision tree documented (see `troubleshooting.md`).

## 8. Cloud-specific (only flip what's needed)

| Env | SPO host | Login | Graph |
|---|---|---|---|
| Commercial | `.sharepoint.com` | `login.microsoftonline.com` | `graph.microsoft.com` |
| GCC-H / IL5 | `.sharepoint.us` | `login.microsoftonline.us` | `graph.microsoft.us` |
| DoD | `.sharepoint-mil.us` | `login.microsoftonline.us` | `graph.microsoft.us` |
| IL6 | `.spo.microsoft.scloud` | `login.microsoftonline.microsoft.scloud` | `graph.microsoft.scloud` |
