# H: Drive → OneDrive — Decision Aids

When an operator asks "should I X or Y?" — this file has the answer in a single screen. Voice: peer senior engineer, no padding.

---

## Stage first or straight Migrate?

| Situation | Recommendation |
|---|---|
| First wave for this customer / unfamiliar data shape | **Stage first.** Surfaces SPMT errors (long paths, weird filenames, blocked extensions) before you commit to the cutover. |
| Data is known clean (you've migrated similar shape before) | Straight Migrate. Saves a pass. |
| Large H: shares (>10GB per user typical) | **Stage first.** Cutover delta will be tiny instead of full content again. |
| Highly active users (constant writes during business hours) | **Stage first.** Run Stage during business hours, Migrate cutover at a quiet window. Reduces user-visible disruption. |
| User is VIP / leadership | **Stage first.** Same rationale, plus you get to fix any per-file errors before the boss sees them. |
| One-off, low-stakes user | Straight Migrate. The script handles everything in one pass. |

---

## When to fix per-file errors at source vs accept and move on

After an `ErrorLog`, you have the `FailureSummaryReport2.csv` / `ItemReport_R1.csv` attached to the SPO list row. The errors fall into categories:

| Error pattern | Source-side fix? | Worth doing? |
|---|---|---|
| Long path (>400 chars) | Rename folders / shorten paths at source | Yes if the data matters; often legacy junk worth skipping |
| Invalid characters (`# % & * { } | : ? <>`) | Rename files at source | Yes — usually small number, fast |
| Blocked extension (`.pst`, `.exe`, etc.) | Move to a separate share / OneDrive can't host these | **No** — the block is a feature; users shouldn't be storing PSTs on OneDrive anyway |
| Locked file at copy time | Wait for user to close, retry | Yes — retry once. If chronic, schedule a quiet window |
| 0-byte file at target | Re-run the row (the retry script detects 0-byte and re-uploads) | Yes always — silent corruption |
| User unauthorized at source | Reset NTFS perms, retry | Yes — likely a one-time anomaly |

**Rule of thumb:** if more than 10% of files fail with the same error, it's a systemic issue worth fixing at source before mass-retrying. If <10%, accept and move on — communicate the failures via the user-facing email and let the user request specific manual moves.

---

## When to use `Postpone` vs `Skipped` vs leaving `Migrate` blank

| Need | Action |
|---|---|
| Skip this user until a future specific date | Set `Postpone` (or one of its 5 alternate spellings) to that date. Script auto-skips until then. |
| Skip this user indefinitely / they shouldn't be in this wave | Set `Migrate = Skipped` (or your shop's convention). Script won't pick up rows where `Migrate` isn't `Stage` or `Migrate`. |
| User isn't ready (license, ServiceNow, governance) | Leave `Migrate` blank. Script ignores blank rows. Operator triggers when ready. |

**Don't** delete the row — you lose audit trail.

---

## When to grant SCA03 (SpecialGroup)

`SpecialGroup = Yes` on the row triggers the script to add SCA03 (`TenantAdminsGroup`) as a Site Collection Admin on the user's OneDrive — in addition to the always-on SCA02 (`OneDriveAdminGroup`).

| Use SCA03 for | Don't use SCA03 for |
|---|---|
| Classified data owners (extra recovery access) | Regular users |
| VIPs / leadership where extra ops coverage is needed | Bulk waves |
| Users whose OneDrive will hold high-value records | Test users |
| Migrations where post-cutover compliance audits are likely | Migrations where minimum-necessary-access is the policy |

Remember: the script does **not** auto-remove SCA grants. If SpecialGroup → SCA03, that grant persists until you run cleanup.

---

## When to clear a stuck row vs let it auto-recover

| Symptom | Action |
|---|---|
| Row in `Processing`, runner host actively logging | Wait. Runner is alive. |
| Row in `Processing`, runner host rebooted / no transcript activity > 2× typical per-row time | Clear `Processing`. Script will retry on next cycle. |
| Row in `Migrating`, SPMT process running on runner | Wait. Migration in progress. |
| Row in `Migrating`, no SPMT process | Kill any zombie SPMT process, clear `Processing` + `Migrating` if needed, retry. |
| Row in `Failed`, `ScriptError = THROTTLE` | Wait 30 min. Then clear lock and retry. SPO will have cooled down. |
| Row in `Failed`, `ScriptError = ONEDRIVE PROVISIONING` | Try `Request-SPOPersonalSite` manually for that UPN; wait 5 min; clear lock; retry. |
| Row in `Failed`, `ScriptError = LICENSE` | Grant license upstream first. Then retry. |
| Row in `Failed`, multiple users with same `ScriptError = ACCESS` | Cert expired or app reg revoked. Fix that first; mass-retry after. |

---

## When to retry single row vs mass-reset

| Situation | Approach |
|---|---|
| One user failed | Single-row retry. Clear `Processing`, set `Migrate = Migrate` or `Migrate = Stage` per the desired phase. |
| Multiple users failed with **different** errors | Triage each, retry individually. Errors are unrelated. |
| Multiple users failed with **same** error (throttle, auth, network) | Fix the underlying issue, then mass-reset by clearing locks + resetting `Migrate` for the affected rows. |
| Entire wave failed | Stop. Don't retry until root cause known. |

---

## When to manually clean up SCAs

The script adds SCA02 + (conditionally) SCA03 but never removes them. Depending on your governance:

| Policy | Action |
|---|---|
| Permanent ops access for support / e-discovery | Leave grants in place. They're documented in the playbook. |
| Time-bound: remove after N days post-migration | Build a separate cleanup script that filters `CompletedDate > N days ago` and runs `Remove-SPOUser` for each grant. |
| Per-user manual signoff | Add a column to the SPO list (`AdminCleanupComplete = Yes/No`); operator flips it after running cleanup; cleanup script honors the flag. |

There is **no** cleanup script in this playbook by design — different shops want different cleanup rules. Write your own when needed.

---

## When to use OneDrive vs ask "should this even be in OneDrive"

OneDrive is **personal** content. If the H: drive contains:

| Content type | Right destination |
|---|---|
| Personal work files (drafts, docs in progress, personal notes) | OneDrive — yes, migrate |
| Team-shared documents (multiple users editing) | **SharePoint site or Teams channel**, not OneDrive. Migrate those via Common Drive playbook instead. |
| Application data (databases, app config) | Probably not OneDrive at all — investigate where the app should store it post-migration |
| Backups / archives | Discuss with the customer — OneDrive isn't a backup tool |
| Mailbox exports (`.pst`, etc.) | Blocked extension. Should be archived in Exchange Online or removed entirely |

If you're seeing a lot of one of the "wrong destination" categories in a customer's H: drives, raise it with the customer's PM — they may need a different migration strategy for those files, or a content-cleanup pass first.

---

## When the customer asks "Why this vs Mover or ShareGate?"

Short version (without quoting prices, which are RFQ):

- **Microsoft Mover:** retired Feb 2024. No native UNC-to-OneDrive successor at the scale this playbook handles.
- **SPMT alone:** Microsoft's SPMT does support UNC sources, but it has no orchestration, no driver list, no AD glue, no per-user retry, no license-gating, no postpone-by-date, no `RedirectGP` parsing. SPMT is the engine; this playbook is the surrounding plant.
- **ShareGate:** GUI-friendly, strong on commercial, but no IL5 or IL6 instance. Licensing is in the low-to-mid five figures annually per RFQ; doesn't ship the federal AD identity workflow.
- **AvePoint Fly + Confidence:** GCC-H support, but six-figure annual pricing per RFQ; same identity-glue gap.
- **BitTitan MigrationWiz:** SaaS, routes through commercial Azure. **Not usable in IL5/IL6.**

Long version in `knowledge-cards.md` under "Why this playbook."

---

## When to route the conversation back to the Concierge

If the operator describes any of these, this isn't the right agent:

- Per-user OneDrive on legacy on-prem SharePoint (MySites) → **OnPrem → SPO agent**
- Shared/common UNC drive (multiple users) → **Common Drive agent**
- Cross-tenant OneDrive migration → out of scope; route back
- Mailbox migration → out of scope; route back
- SharePoint site → SharePoint site → **OnPrem → SPO agent**

Reply: "That's not in my scope. Type 'back' to return to the Cloud Migrate Pro Concierge and pick the right specialist."

---

## When to escalate to Microsoft support

- Tenant-wide SPO throttle that doesn't subside in an hour
- OneDrive provisioning failing tenant-wide (Request-SPOPersonalSite returning errors for every UPN)
- SPMT engine errors not in this playbook's troubleshooting list
- Cert / app reg issues that aren't obviously a config mistake
