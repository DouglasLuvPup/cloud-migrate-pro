# H: Drive → OneDrive — Plain-English FAQ

Use this when a user asks a "why" or "what really happens" question that's hard to answer with a cmdlet. Voice: peer senior engineer to junior colleague. Acronyms expanded on first use per conversation.

---

## What this migration actually does

**Q: What's an "H: drive" in this context?**
A network home drive — a per-user folder on a file server, mapped as drive letter `H:` via Group Policy or login script. Typical path: `\\fileserver\users\<sam>`. We're moving its contents into the user's OneDrive at `/Documents/HDrive`.

**Q: Why do we put it under `/Documents/HDrive` instead of the OneDrive root?**
Two reasons:
1. Operators can tell at a glance whether a OneDrive came from H: drive migration vs other sources (the folder name is a marker).
2. The script's `Move-MyDocumentsContent` step later flattens `/Documents/My Documents/` → `/Documents/`. Keeping H: content in a named subfolder avoids collision with that flatten.

**Q: What's `Move-MyDocumentsContent`?**
After the main copy, the script reorganizes content. Legacy file-server setups often have `My Documents` as a nested folder (because Windows used to redirect "My Documents" into the home drive). When that hits OneDrive, you end up with `/Documents/My Documents/<stuff>`. The flatten step pulls those files up to `/Documents/<stuff>` so OneDrive doesn't look weird. Hierarchy is preserved inside.

---

## Identity & licensing

**Q: Does the script license the user?**
**No.** It validates that the user is already a member of the license group (`O365S-AddOn-License`). If they're not, it sets `Migrate = Unlicensed` and skips them. License grant must happen upstream (your provisioning workflow, ServiceNow request, Entra license assignment — whatever your shop uses).

**Q: But it does add them to a group, right?**
Yes — `SecFltr-USR-Office365` on success. That's separate from the license validation. Adding to that group is the "user is now an SPO user" signal that downstream systems key off. It's not the license itself.

**Q: Why are there TWO group operations?**
- `SecFltr-USR-OneDrive` → removed (this group typically gates Group Policy redirecting Documents to H:)
- `SecFltr-USR-Office365` → added (this is the "user is fully cloud-eligible" gate group)
- `O365S-AddOn-License` → validated only (membership = "user has the SPO license entitlement")

The OD2OD on-prem-to-OneDrive script uses the same first two groups. License-group validation is unique to H: Drive because file-server home drives often have license gaps (someone created an AD account but never licensed them).

**Q: What's `RedirectGP`?**
A multi-value column on the SPO list. Operators populate it with one or more AD group names whose memberships should also be removed on cutover. Typically used when an agency has multiple GP redirection groups across regions or business units. The script parses the column newline-separated, then comma-separated within each line — so both `["GPO-USR-East", "GPO-USR-West"]` and `"GPO-USR-East, GPO-USR-West"` on one line both work.

**Q: What happens if a group removal fails?**
`Redirect` column on the row is set to `"Failed"`. Migration is still marked `Migrated`, but the audit trail says the AD cleanup was incomplete. Operator needs to manually finish the removal.

---

## Stage vs Migrate

**Q: What's the difference between Stage and Migrate?**

| `Migrate` value | What it does |
|---|---|
| `Stage` | Content copy only. No AD changes. No source lockdown. Used to seed data without touching the user. |
| `Migrate` | Full cutover: content copy + Move-MyDocumentsContent flatten + AD group flips + source ACL lockdown. |

**Q: Why have a Stage mode if it's the same script?**
Separation of risk. You can run a Stage pass weeks before cutover, surface SPMT errors early, fix bad filenames / long paths, and not affect the user. The actual cutover (Migrate) is then much faster because most content is already at target.

**Q: When the operator runs Stage on already-staged content, what happens?**
The script picks up the row, runs SPMT (which does a delta — only new/changed files), and stays in `Staged` / `StagedWithErrors`. AD doesn't change.

**Q: When the operator flips a `Staged` row to `Migrate`, what happens?**
The script picks it up again, runs SPMT (final delta), does Move-MyDocumentsContent, flips AD groups, kicks off the source ACL lockdown as a background process. End state: `Migrated`.

---

## SCA grants and SpecialGroup

**Q: What's SCA02 vs SCA03?**
Site Collection Administrator grants made on the user's new SPO OneDrive site:
- **SCA02 = `OneDriveAdminGroup`** — always added. This is the standard ops group that SPMT needs on every OneDrive site to write data into it.
- **SCA03 = `SpecialGroup` (e.g., `TenantAdminsGroup`)** — added only when the row has `SpecialGroup = "Yes"`. Use for VIPs, classified data owners, or other rows where extra admin coverage is required.

**Q: Does the script remove these admin grants after migration?**
**No.** The script adds them and leaves them. This is intentional in v5.2 — operators routinely need admin access to the OneDrive for post-migration support (restoring deleted files, fixing permissions). If your governance requires removal after a certain window, you need a separate cleanup script: `Remove-SPOUser -Site <OneDriveUrl> -LoginName "c:0t.c|tenant|<SCA-GUID>"`.

---

## Failures, retries, and edge cases

**Q: What does each `Migrate` end state mean?**

| Value | Meaning | Operator action |
|---|---|---|
| `Migrated` | Clean success | None |
| `ErrorLog` | Per-file errors; `ItemReport_R1.csv` attached to the row | Review CSV; decide skip vs fix |
| `ManualLog` | Per-file errors AND attaching the report failed | Look at the file system; SPMT logs in `F:\SPMTTranscripts\` |
| `Failed` | Hard failure; `Processing` cleared so row is retry-eligible | Investigate root cause from `ScriptError` column |
| `Unlicensed` | User not in `O365S-AddOn-License` | Grant the license upstream, then re-trigger |
| `Invalid UPN` | UPN missing or malformed | Fix UPN in source data; re-trigger |

**Q: What's the difference between `ErrorLog` and `ManualLog`?**
`ErrorLog` means SPMT ran, had file-level errors (long paths, invalid chars, blocked extensions), and the script successfully attached the per-file CSV to the SPO list row. You can see what failed without leaving SharePoint.

`ManualLog` means the errors happened AND the script couldn't attach the CSV (rare — usually an SPO throttling problem or the file is too large). You have to go look at the actual report file in `F:\SPMTTranscripts\` to know what failed. It's a "go investigate the file system" flag.

**Q: A row is stuck in `Processing` forever. What do I do?**
The runner crashed mid-row and didn't clear the flag. Manually clear `Processing` on that row. The next runner cycle will pick it up. Note: H: Drive script uses the column literally named `Processing` (no nuance like OnPrem's `Inprocess` vs `Processing` distinction).

**Q: What's "Postpone" and why does it have six spellings?**
The script checks six column-name variants — `Postpone`, `PostPone`, `postpone`, `POSTPONE`, `Postponed`, `DelayUntil` — and skips the row if any of them holds a future date. This is real-world federal data hygiene: different intake teams capitalize differently and the script tolerates all of it rather than making operators clean column names first.

**Q: I see "FatalError_*.csv" in the SPMT folder. What does that mean?**
SPMT itself crashed (not a per-file error — the engine itself died). The script parses any `FatalError_*.csv`, categorizes the error (LICENSE / UPN / ONEDRIVE PROVISIONING / ACCESS / THROTTLE / etc.), and appends it to the row's `ScriptError` column. The categorization helps you triage in bulk — filter the list by category and you can see how many rows hit the same root cause.

---

## Source-side behavior

**Q: What happens to the H: drive after migration?**
On success, the script launches a **separate PowerShell process** (`Start-Job`) to run `Set-Acl` on the source UNC path, setting it to `ReadAndExecute` for the user. This is a background job — it doesn't block the main migration loop, so a slow ACL walk on a deep folder doesn't hold up the next user.

The source content is NOT deleted. It's just made read-only.

**Q: Why launch ACL in a separate process?**
Set-Acl on a large folder tree can take minutes. Putting it in `Start-Job` (which spawns a new PS process) means:
1. The orchestrator can move on to the next user.
2. If the ACL job itself crashes, it doesn't take down the migration loop.
3. The migration script doesn't have to wait for ACL completion to declare the user `Migrated`.

`HReadOnly` column on the row is set to `"Updated"` when the ACL job is kicked off (NOT when it completes). So a `Migrated` row with `HReadOnly = Updated` means "we launched the lockdown — verify in the file system if you need to confirm."

**Q: What if the user keeps writing to H: after migration?**
They can't — it's read-only post-cutover. They'll get permission denied. This is part of the cutover narrative: "your H: drive is now read-only; please use OneDrive going forward."

**Q: Can I restore write access to H: as a rollback?**
Yes — `Set-Acl` with the original ACL. The script doesn't store the original ACL anywhere, so either you snapshot it before running or you reconstruct it (typically `Modify` or `FullControl` for the user). The migration data is still in OneDrive regardless.

---

## "What do I tell the user?"

See `user-experience-narrative.md` for full sample comms. Quick versions:

- **Before:** "Your H: drive is moving to OneDrive on or around [date]. Keep using H: until I tell you otherwise."
- **Stage complete (no comm needed — users don't know about Stage):** *(silent)*
- **Cutover complete:** "Your migration is done. H: is now read-only. Use OneDrive — your files are in Documents → HDrive."
- **ErrorLog:** "Most files migrated; a few couldn't move (usually long paths or weird characters). We're reviewing."
- **Failed:** "We hit an issue. Nothing was lost — H: is still your live location. We'll re-queue."

---

## "Where does X live?"

| What | Where |
|---|---|
| H: drive source | `\\server\users\<sam>` (UNC path; check Group Policy for actual server name) |
| OneDrive target | `https://contoso-my.spo.microsoft.scloud/personal/<upn-with-underscores>/Documents/HDrive` |
| Driver list | SPO list "USER-Hdrive OneDrive Migration Status" on the orchestrator site |
| SPMT install | `F:\SPMT-migration_tool.9\` |
| Cached creds | `F:\Scripts\SPMTCred.xml` (DPAPI-encrypted to the runner host) |
| Transcripts | `F:\SPMTTranscripts\Log_<COMPUTERNAME>_<TIMESTAMP>.log` |
| SPMT reports | `F:\SPMTLOGS\<task-folder>\` |
| Failure reports | Attached to the SPO list row AND in SPMT folder |

---

## "How do I explain this to my PM / customer?"

- **"What's moving?"** Per-user network home drives (the `H:` mapping you see in File Explorer). The content lands in each user's OneDrive under Documents → HDrive.
- **"What's the engine?"** SharePoint Migration Tool. Microsoft's own. Free.
- **"What's the wrapper?"** A PowerShell scaffold around SPMT plus a SharePoint list as the work queue, plus identity-cutover glue (AD group flips, OneDrive provisioning, license-gating). Lets us migrate at federal scale without per-user GUI clicks.
- **"What's the user experience?"** Pre-migration: nothing changes. Cutover: H: becomes read-only; OneDrive shows up in File Explorer with their content. They get one email when it's done.
- **"What does it cost?"** SPMT is free. The wrapper is internal IP. Vendor alternatives (ShareGate, AvePoint) start at $30k–$200k+/yr and don't support IL5/IL6. Use those figures only as orientation, not as quoted prices — RFQ for actuals.
- **"What about risk?"** Content is copied, not moved. H: stays as a read-only fallback indefinitely (until your governance deletes it). If something goes wrong, the user's data is still on H:.
