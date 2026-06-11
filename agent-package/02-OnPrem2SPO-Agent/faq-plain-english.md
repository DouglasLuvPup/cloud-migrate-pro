# On-Prem → SPO — Plain-English FAQ

Use this when a user asks a "why" or "what really happens" question that's hard to answer with a cmdlet. Voice: peer senior engineer to junior colleague. Acronyms expanded on first use per conversation.

---

## Identity & access

**Q: What does the SCA swap actually do, and why?**
After a successful OneDrive migration (OD2OD only), the script reaches into the user's **source on-prem MySite** — not the new SPO OneDrive — promotes the migration service account (`svc-migration`) to Site Collection Admin, and demotes the migrated user. The point is to lock the source so users can't keep editing the old MySite while the new OneDrive is being adopted. The "new" location is the SPO OneDrive; the SCA swap is a source-side lockdown.

**Q: Will the script actually modify Active Directory?**
Yes, by default. The script has `#<#` and `#>` markers around the AD block that look like a block comment, but PowerShell parses `#<#` as a single-line comment (the leading `#` makes the whole line a comment, so `<#` is just text — it never opens a block). So the AD code underneath runs. To truly disable it, change `#<#` to `<#` (drop the leading `#`) on the marker lines. If your governance requires AD changes to be opt-in, make that edit before deploying.

**Q: What AD changes happen on success?**
Three things:
1. `wwwHomePage` attribute on the user account → set to the new SPO OneDrive URL (so apps that read this attribute redirect to the new location)
2. User removed from every group matching `*REDIRECTION*` and from `SecFltr-USR-OneDrive`
3. User added to `SecFltr-USR-Office365`

**Q: What does removing someone from a REDIRECTION group do?**
Those groups typically drive Group Policy redirection — e.g., redirecting "Documents" to a home folder on a file server. Removing the user from those groups stops the redirect, so Windows starts pointing them at the local OneDrive client instead.

---

## Failures & retry

**Q: A user says they got an error email but I can't find an error in SPMT. What's going on?**
The script doesn't send email at all. A Power Automate flow sitting on the SPO list watches for `Migrate = ErrorLog` or `Migrate = Failed` and sends the email. So if the email arrived, the list row's `Migrate` column is `ErrorLog` or `Failed`. Look at the row, not SPMT.

**Q: What's the difference between `ErrorLog` and `Failed`?**
- `ErrorLog` = SPMT ran but some files had per-file errors (long paths, invalid chars, blocked extensions). The `FailureSummaryReport.csv` is attached to the list row. Migration mostly succeeded — review the CSV and decide whether to skip or fix.
- `Failed` = hard failure. The migration didn't complete. Usually a connectivity, credential, or quota problem. Look at the transcript log first.

**Q: A row is stuck "Processing" forever. What do I do?**
The runner crashed mid-row and didn't clear the lock. Manually clear the lock column in the SPO list:
- OD2OD: clear `Inprocess`
- SP2SPO: clear `Processing`
Once cleared, the next runner cycle will pick it up.

**Q: Why are the OD2OD and SP2SPO lock columns named differently?**
Historical. The OD2OD script uses `Inprocess` (one word, no caps); SP2SPO uses `Processing`. They're not interchangeable — writing to the wrong one is a common operator mistake. Always check which script you're working with.

**Q: Why does my Power Automate flow not fire on errors?**
Most common: the flow watches the wrong column name. Common Drive uses `Migrate`, the column where the script writes terminal values. Some teams mistakenly target a column called `MigrationStatus` or `Status` — those don't exist in this driver list. Verify the flow's trigger filter against the actual list schema.

---

## What the script does and doesn't do

**Q: Does this copy or move the data?**
**Copies.** Source on-prem content is untouched. If you need to truly remove it, that's a separate cleanup pass after migration is verified.

**Q: How long does one user take?**
There's no hard answer — depends on data volume, network, SPMT throttling. The script sleeps 30 seconds between users for OD2OD and 120 seconds between sites for SP2SPO, so per-row throughput is bounded by SPMT runtime + sleep + AD/SCA work. Typical OD2OD per user: 1–10 minutes for a moderate MySite; SP2SPO can be hours for a large site collection.

**Q: Why does SP2SPO sleep 4× longer than OD2OD?**
Site migrations hit more SPO endpoints (lists, libraries, page renders, permissions) than user OneDrive copies. The longer sleep gives SPO time to settle so the next site's `Add-SPMTTask` doesn't pile onto the same back-end throttle bucket.

**Q: Are file versions preserved?**
Yes. `Register-SPMTMigration` is called with `-KeepAllVersions $true` and `-MigrateFileVersionHistory $true`. Every version that exists at source ends up at target.

**Q: Why does the script block 50+ file extensions?**
SPMT refuses to upload certain types regardless of what you tell it: `.pst` (corrupts SPO), executables, system files, lock files, and a long tail of weird MS extensions. The list mirrors what SPMT's own block list rejects. Editing `$BlockedExtensions` in the script header lets you customize, but you generally shouldn't add things SPO does allow (you'd skip files unnecessarily).

---

## Service account & permissions

**Q: Why does svc-migration need to exist before I run anything?**
The script's SCA swap step calls `EnsureUser` for the service account on the source MySite. If the account doesn't exist in Entra/AD, that EnsureUser fails and the SCA swap throws. The migration content itself will already have succeeded by that point, so you get a half-finished row.

**Q: Can I use a different service account name?**
Yes — but you'd edit the hard-coded `svc-migration` reference in the script (there are a few places). For a clean change, set it as a variable at the top and reference everywhere. Right now it's a literal.

**Q: What permission does the runner account need on AD?**
Enough to run `Remove-ADGroupMember`, `Add-ADGroupMember`, and `Set-ADUser -Replace @{WWWhomepage=...}` for the affected users. Typically an account in a "User Modification" or "Helpdesk" delegated AD role. If those calls fail, you'll see entries in the transcript and `wwwHomePage` won't get set to `"Updated"` in the SPO list — a useful smoke test.

---

## When to escalate vs handle locally

**Q: How do I tell the user-facing impact in plain terms?**
- "Your home folder is being copied to OneDrive. Until I tell you otherwise, keep using the H: drive — nothing's changed for you yet." (Stage phase)
- "Your files are in OneDrive now. The old MySite is read-only. Open File Explorer; OneDrive is in the left sidebar. Everything you had is in `Documents` → `HDrive`." (Cutover complete)
- "We had a hiccup migrating a few files — usually it's a filename or a really long path. Working it." (ErrorLog)
- "Migration failed and needs hands-on review. We'll re-queue once we know what happened." (Failed)

**Q: What kinds of issues should I escalate vs fix myself?**
Fix locally: stuck lock flags, individual user retries, license-group adds, single-user AD fixes, blocked-extension complaints.
Escalate: SPMT throttle storm across many users (suggests app-reg or tenant-wide issue), repeated cert failures (likely cert expired/wrong store), Power Automate flow not firing for multiple rows (flow config), source/target unreachable (network).

---

## "Where does X live?"

| What | Where |
|---|---|
| Source MySite | On-prem SP farm; e.g., `https://onedrive.contoso-onprem.local/my/<sam>` |
| Target OneDrive | SPO; e.g., `https://contoso-my.spo.microsoft.scloud/personal/<upn-with-underscores>` |
| Driver list | SPO list "OneDriveMigrationStatus" or "SPOMigrationStatus" on the orchestrator site |
| SPMT install | `F:\SPMT-migration_tool.9\` on each runner host |
| DLLs (OD2OD) | `F:\Tools\` |
| DLLs (SP2SPO) | `F:\IAU_Scripts\OneDrive_Migration_Scripts\` |
| Transcripts | `F:\SPMTLOGS\` (per-runner, per-run) |
| Failure reports | Attached to the SPO list row + in SPMT's per-task report folder |
| Power Automate flow | On the driver list (separate from the script) |

---

## "How do I explain this to my PM / customer?"

- **"What's the engine?"** SharePoint Migration Tool. Microsoft's official on-prem-to-SPO migration engine. Same one FastTrack uses.
- **"What's the wrapper?"** A small PowerShell scaffold around SPMT plus a SharePoint list that acts as the work queue. Lets multiple operators run in parallel without stepping on each other. Plus AD and SCA glue that no commercial tool ships with.
- **"What does it cost?"** SPMT is free. The wrapper is internal IP that ships with the engagement. Vendor alternatives (ShareGate, AvePoint, Quest) start in the low five figures annually and don't run in IL5/IL6.
- **"What's the risk?"** Content is copied, not moved. Source on-prem stays as a fallback until the customer signs off. The AD changes are technically reversible (re-add to groups, restore `wwwHomePage` value) but plan for it.
