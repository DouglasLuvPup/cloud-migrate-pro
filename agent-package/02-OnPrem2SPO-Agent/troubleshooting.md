# Troubleshooting — On-Prem → SPO

> Error categories tagged into the `ScriptError` column; the `Log` column holds the full message.

## Error code → diagnosis → fix

| Symptom in `Log` / `ScriptError` | Likely cause | Fix |
|---|---|---|
| `LICENSE` | User has no SPO license; OneDrive can't provision | Assign license (or add to `SecFltr-USR-Office365`); clear lock; retry |
| `UPN` | UPN mismatch between source and target identity | Verify `UserPrincipalName` column matches the cloud UPN exactly |
| `ONEDRIVE PROVISIONING` | Request-personal-site call failed even after 3 retries | Manually `Request-SPOPersonalSite -UserEmails`; wait 5 min; clear lock; retry |
| `THROTTLE` | SPO returned 429 | Runner handles 5× with backoff; if exhausted, lower concurrency or wait |
| `ACCESS` | SCA grant failed or PnP cert expired | Verify cert is installed + valid; verify app reg has `Sites.FullControl.All`; re-run |
| `SPMT FAILED` | SPMT engine error mid-run | Check SPMT log path; common: source unreachable, target lock, file path > 400 chars |
| Row stuck in `Inprocess`/`Processing` | Runner crashed | Manually clear the lock column |
| `ErrorLog` status | Per-file errors during SPMT | Open SPMT report; decide: skip and accept, or fix source then retry |
| Empty `Log` but `Failed` | Pre-run guard failed silently | Confirm cert thumbprint + DLL path; check execution policy |
| MySite source URL 404 | Source MySite already deleted on-prem | Mark row as manual; skip |

## Common gotchas

1. **OD2OD vs SP2SPO column names differ.** `Inprocess` (OD2OD) vs `Processing` (SP2SPO). Don't write to the wrong one.
2. **Log column is `Log`** — not `MigrationLog`. Power Automate flows that target the wrong name will silently fail.
3. **DLL path differs.** OD2OD uses `F:\Tools\`. SP2SPO uses `F:\IAU_Scripts\OneDrive_Migration_Scripts\`.
4. **AD block RUNS by default.** The script has `#<#` ... `#>` markers around the AD code that LOOK like a block comment, but PowerShell parses `#<#` as a single-line comment, so the AD code underneath actually executes. It modifies `wwwHomePage`, `*REDIRECTION*` groups, and `SecFltr-USR-OneDrive` / `SecFltr-USR-Office365`. To truly disable AD changes, change `#<#` to `<#` (remove the leading `#`) on the marker lines.
5. **SCA swap also RUNS by default — on the SOURCE on-prem MySite** (not the new SPO OneDrive). It promotes svc-migration and demotes the migrated user on `$sourceUrl`. Same comment-marker caveat: the apparent block comment doesn't disable it.
6. **Email is NOT sent by the script.** A Power Automate flow on the list does it. If users aren't getting emails, the flow is the suspect, not the script.

## "How do I prove it worked?"

1. Driver list row shows `Migrate = Migrated`, lock column empty.
2. Target OneDrive / site loads, content visible at expected path.
3. SPMT log shows zero blocking errors.
4. AD `wwwHomePage` reflects new OneDrive URL (this runs by default).
5. SCA list on the SOURCE on-prem MySite includes `svc-migration`; original user demoted (this also runs by default).

## Rollback

- **OD2OD:** content was COPIED, not moved. Source MySite still exists on-prem. Disable OneDrive sync on the user's machine; uninvite SCA changes if applied; restore old AD group memberships.
- **SP2SPO:** same — copy, not move. Source on-prem site is untouched. Communicate the rollback URL.

## When to escalate

- SPMT engine corruption (re-install on the worker host).
- Cert expiry on the app reg (rotate cert in Entra; redeploy to worker hosts).
- Tenant-wide throttle from SPO (open a Microsoft ticket).
