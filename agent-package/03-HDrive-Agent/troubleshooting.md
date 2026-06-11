# Troubleshooting — H: Drive → OneDrive

## Error code → diagnosis → fix

| Symptom in `ScriptError` / `Log` | Likely cause | Fix |
|---|---|---|
| `LICENSE` | User missing SPO license | Add to `SecFltr-USR-Office365` + `O365S-AddOn-License`; wait propagation; clear `Processing` + `MigrationStatus`; retry |
| `UPN` | UPN doesn't match cloud identity | Verify `UserPrincipalName` column matches Entra user; correct and retry |
| `ONEDRIVE PROVISIONING` | All 3 retries (60/120/180s) failed | Manually `Request-SPOPersonalSite`; wait 5 min; verify URL; retry |
| `ACCESS` | SCA grant failed | Verify app reg has `Sites.FullControl.All`; verify cert valid; verify user OneDrive exists |
| `THROTTLE` | SPO 429 after 5 retries | Reduce concurrency; wait 30+ min; retry. Persistent throttle = Microsoft ticket |
| `SOURCE_UNREACHABLE` | UNC `\\server\users\<sam>` not reachable | Verify runner host can `Test-Path` the path; check Kerberos/DNS |
| `SCA_GRANT_FAILED` | Couldn't add SCA02 or SCA03 | Verify group SIDs / claim strings; verify OneDrive exists |
| `SPMT_FAILED` | SPMT engine error | Open `ItemReport_R1.csv`; common: path > 400 chars, blocked extension, locked file at source |
| `MigrationStatus = ManualLog` | Errors AND CSV attach failed | Run report attach manually from a working host; investigate why upload failed |
| `Redirect = Failed` | Group removal failed | Inspect AD group membership / replication; manually clean; clear `Redirect` and retry |
| `HReadOnly` stays blank | bg ACL job never launched | Check Task Scheduler / Start-Process logs on runner host |
| Row stuck in `Processing` | Runner crashed mid-row | Manually clear `Processing` |
| Menu option 5 didn't clear cred | Wrong user profile context | Delete `$env:USERPROFILE\SPMTCred.xml` manually |

## Common gotchas

1. **SCAs are NOT removed post-migration.** This is intentional in v5.2 for post-migration troubleshooting. Don't assume cleanup happens — script it separately if governance demands removal.
2. **Six postpone spellings accepted.** If the row is being skipped unexpectedly, check all 6: `Postpone`, `PostPone`, `postpone`, `POSTPONE`, `Postponed`, `DelayUntil`.
3. **PSTs are blocked by default** (`@("pst")` blocked extensions). Edit the array if you really want them — but don't.
4. **`Processing` is cleared only on the `Failed` path** (and on success). If a row is stuck `Processing = Yes` without a final status, the runner died mid-row.
5. **`ScriptError` appends, not replaces.** Long history is normal on a retried row — read the latest entry.
6. **Move-MyDocumentsContent runs AFTER SPMT.** If users see content under `/Documents/HDrive/My Documents/...` and not under `/Documents/...`, the post-step didn't run or failed — check `Log`.
7. **`HReadOnly = Updated` only means the bg ACL job was LAUNCHED**, not that it succeeded. The ACL walk on a 500GB home folder can take hours; verify ACLs separately if you need certainty.
8. **DPAPI cred cache is machine + user bound.** Moving runner hosts requires re-prompting for creds on first run.

## "How do I prove it worked for one user?"

1. `MigrationStatus = Migrated`, `Processing` empty.
2. Target OneDrive opens; `/Documents/` shows content (not `/Documents/HDrive/...`).
3. SPMT `ItemReport_R1.csv` shows 0 errors (or only acceptable extensions).
4. AD group membership: removed from `SecFltr-USR-OneDrive`; added to `SecFltr-USR-Office365`.
5. (Eventually) source UNC ACL locked down for user.

## Rollback

- Content was COPIED. Source UNC still exists (ACLs may be locked — undo via the bg job script).
- Re-add user to `SecFltr-USR-OneDrive`; remove from `SecFltr-USR-Office365` if they should not have a OneDrive yet.
- Old `RedirectGP` group memberships are not auto-restored — keep a backup before running.

## When to escalate

- SCA grant fails with permission error → app reg perms or cert.
- Repeated `ONEDRIVE PROVISIONING` across many users → tenant capacity or SPO health event.
- All users in one wave fail with `THROTTLE` → reduce parallel runners / raise interval.
