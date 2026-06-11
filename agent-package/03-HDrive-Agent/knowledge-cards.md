# H: Drive → OneDrive — Knowledge Cards

## Script: `Hdrive-OneDriveScript(081825a).ps1` (v5.2)

**Purpose:** Migrate per-user network H: drives (UNC home folders) into the
user's SPO OneDrive under `/Documents/HDrive`.

---

## Configuration (placeholders in the script — replace before running)

| Variable | Placeholder value | Replace with |
|---|---|---|
| `$siteUrl` | `https://contoso.spo.microsoft.scloud/sites/000001` | Site hosting the driver list |
| `$adminUrl` | `https://contoso-admin.spo.microsoft.scloud/` | Your SPO admin URL |
| `$mySharePointUrl` | `https://contoso-my.spo.microsoft.scloud` | Your SPO OneDrive root |
| `$domain` | `@contoso.gov` | Your UPN domain |
| `$listName` | `USER-Hdrive OneDrive Migration Status` | (keep or rename) |
| `$targetdocumentlibrary` | `Documents` | Usually keep |
| `$removeGroup` | `SecFltr-USR-OneDrive` | Source AD group |
| `$targetGroup` | `SecFltr-USR-Office365` | Target AD group |
| `$targetGroup2` | `O365S-AddOn-License` | License group |
| `$SCA02` | `c:0t.c\|tenant\|eeeeeeee-...` | OneDrive admin group claim |
| `$SCA03` | `c:0t.c\|tenant\|ffffffff-...` | Tenant admins group claim |
| `$MigrationUsersLists` | `F:\Migration-Users-Lists` | CSV staging folder |
| `$CredentialPath` | `$env:USERPROFILE\SPMTCred.xml` | Keep |
| `$TempPath` | `F:\Temp` | ACL temp folder |

---

## Prerequisites

- SPMT 4.2.129.0+ installed.
- PowerShell modules: SPMT, PnP.PowerShell,
  `Microsoft.Online.SharePoint.PowerShell`, `ActiveDirectory` (RSAT-AD).
- Tenant admin or equivalent for SPO + AD writes.
- Local admin on the migration host (the script sets registry keys for
  Windows long-path support via `Set-RequiredRegistryKeys`).
- Network line of sight to the H: drive file server.
- Driver SPO list provisioned with columns: `Title`, `SAM`, `UPN`,
  `SourcePath` (UNC), `Migrate`, `Processing`, `LOG`, `StartDate`,
  `CompletedDate`, `ScriptError`, `Server`, `HReadOnly`, `Redirect`,
  `SpecialGroup`, `RedirectGP`, and an optional postpone column.
- AD groups already exist (the three listed above).
- The two SCA group object IDs replaced in `$SCA02` / `$SCA03`.

> **There is no `TimeZone` column on this driver list.** TimeZone-based
> scheduling is a Common Drive feature only.

---

## How OneDrive URLs are built

```powershell
function Get-OneDriveUrl {
    param([string]$UserPrincipalName)
    return "$mySharePointUrl/personal/$($UserPrincipalName.Replace('@','_').Replace('.','_'))"
}
# user1@contoso.gov → https://contoso-my.spo.microsoft.scloud/personal/user1_contoso_gov
```

---

## Credential caching

First run prompts for SPO admin credentials and persists them:

```powershell
$SPOCredential | Export-Clixml -Path $env:USERPROFILE\SPMTCred.xml
```

Subsequent runs do:

```powershell
$SPOCredential = Import-Clixml -Path $env:USERPROFILE\SPMTCred.xml
```

DPAPI-encrypted — only the original user account on the original machine can
decrypt. To force re-prompt: `Remove-Item $env:USERPROFILE\SPMTCred.xml`.

---

## Lifecycle per user (summary)

1. Check **postpone** column (script tolerates six spellings: `Postpone`,
   `PostPone`, `postpone`, `POSTPONE`, `Postponed`, `DelayUntil`). If any
   holds a future date, **skip the row silently**.
2. Resolve SAM → UPN → OneDrive URL.
3. Provision OneDrive if missing (`Request-SPOPersonalSite`). Retries up
   to 3x with 60s / 120s / 180s exponential backoff.
4. Add **SCA02** (OneDriveAdminGroup) to the user's OneDrive.
5. **Conditional:** if list item `SpecialGroup = "Yes"`, also add **SCA03**
   (TenantAdminsGroup). Otherwise SCA03 is not touched.
6. Set `Processing = "Processing"`. Record `StartDate`. Record
   `Server = $Env:COMPUTERNAME` for multi-runner tracking.
7. SPMT: UNC source → OneDrive `/Documents/HDrive`. Blocked extensions:
   `@("pst")` by default.
8. Update list with status + log path:
   - Success → `Migrate = Migrated`, `CompletedDate`, `LOG`.
   - Per-file errors with attachment success → `Migrate = ErrorLog`,
     `ItemReport_R1.csv` attached.
   - Per-file errors but attachment failed → `Migrate = ManualLog`
     (needs manual review).
   - Fatal SPMT error → `FatalError_*.csv` parsed, categorized error
     appended to `ScriptError` column (LICENSE / UPN /
     ONEDRIVE PROVISIONING / ACCESS / THROTTLE / ...).
   - Hard failure → `Migrate = Failed`, `Processing` cleared so the row
     can be retried on the next run.
9. **On success:** run `Move-MyDocumentsContent` to reorganize content
   from legacy `/Documents/My Documents` to flat `/Documents/Documents`.
10. **On success:** flip AD groups
    - Remove from `$removeGroup` (`SecFltr-USR-OneDrive`).
    - Add to `$targetGroup` (`SecFltr-USR-Office365`). ✅ actually adds.
    - **Validate** membership in `$targetGroup2` (`O365S-AddOn-License`) —
      script does NOT add; if the user isn't already a member it sets
      `Migrate = Unlicensed` and skips the row. License grant is upstream.
    - If `RedirectGP` is populated, also remove from each group it
      contains (newline-separated and comma-separated within each line).
    - If any group removal fails, `Redirect = "Failed"`.
11. **On success:** launch ACL changes against the source UNC as a
    **separate PowerShell process** (so they don't block the main loop);
    set `HReadOnly = "Updated"`.
12. **SCA02/SCA03 are NOT removed by the script.** They persist on the
    user's OneDrive after migration. Manual cleanup if desired:
    `Remove-SPOUser -Site <OneDriveUrl> -LoginName "c:0t.c|tenant|<SCA-GUID>"`.
13. Pause; next user.

---

## Status values (the `Migrate` column)

| Value | Meaning |
|---|---|
| `Ready` | Queued; the script will pick this up. |
| `Processing` | A runner is actively working this row (the lock flag). |
| `Migrated` | SPMT reported success; AD + content move + ACL bg job all kicked off. |
| `ErrorLog` | SPMT had per-file errors. `ItemReport_R1.csv` is attached to the list item. |
| `ManualLog` | SPMT had errors AND attaching the report failed. Look at the file system / SPMT logs directly. |
| `Failed` | Hard failure (e.g. provisioning timed out, fatal SPMT error). `Processing` is cleared for retry. |

---

## Other list fields the script writes

| Field | When it's set | What it means |
|---|---|---|
| `StartDate` | Just before SPMT starts | Timestamp of migration start. |
| `CompletedDate` | On success or final error | Timestamp of migration end. |
| `LOG` | On migration completion | Path to log/transcript folder. |
| `Server` | Just before SPMT starts | `$Env:COMPUTERNAME` of the runner. Useful for multi-runner deployments. |
| `HReadOnly` | After ACL bg job launches | `"Updated"` when the parallel ACL job kicks off. |
| `Redirect` | After AD group removal | `"Failed"` if any group remove failed; otherwise blank. |
| `ScriptError` | On any categorized error | Appended (not replaced) with `CATEGORY: message` (LICENSE / UPN / ONEDRIVE PROVISIONING / ACCESS / THROTTLE / etc.). |

---

## SCA cleanup — important caveat

The script **adds** SCA02 (and conditionally SCA03 when
`SpecialGroup = "Yes"`) but it does **NOT** remove them post-migration.
This is intentional in v5.2 (for post-migration troubleshooting) but it
means you must clean them up manually if your governance requires it:

```powershell
Remove-SPOUser -Site <OneDriveUrl> -LoginName "c:0t.c|tenant|<SCA02-GUID>"
# and if SpecialGroup = Yes:
Remove-SPOUser -Site <OneDriveUrl> -LoginName "c:0t.c|tenant|<SCA03-GUID>"
```

---

## Postpone column — multiple spellings

The script checks six column-name variants and accepts a future date or
datetime value in any of them. If any holds a future value, the row is
**silently skipped** for that run:

`Postpone`, `PostPone`, `postpone`, `POSTPONE`, `Postponed`, `DelayUntil`.

`Reset-PostponedUserStatus` (callable inside the script) clears stale
postpones.

---

## RedirectGP — multi-group removal

The `RedirectGP` column on the driver list can hold MULTIPLE AD group
names the user should be removed from. Parsing rules:

1. Split on newline.
2. For each line, split on comma.
3. Trim whitespace; remove from each.

Example value:

```
LegacyHomeDrive-Eng, LegacyHomeDrive-Sales
RedirectionPolicy-OldDomain
```

→ Removes the user from 3 groups.

---

## Interactive CSV picker

When run, the script presents a menu of CSVs found in
`F:\Migration-Users-Lists`, categorized as:

- **NEW** — CSVs not yet processed.
- **STAGED** — CSVs partially processed.
- **MIGRATED** — CSVs whose users are all migrated.

Features: pagination, filter toggle, per-CSV row counts. Menu option
**5 "Clear credentials"** deletes `SPMTCred.xml` to force a re-prompt.

---

## Retry, throttling, and connection caching

- **OneDrive provisioning:** 3 retries, 60s / 120s / 180s exponential backoff.
- **SPO throttling:** `Handle-SPOThrottling` retries up to 5x with 10-300s
  waits, honoring `Retry-After` headers when present.
- **PnP connection cache:** `$script:PnPConnectionCache` keyed by URL
  keeps reconnects cheap. `Ensure-PnPConnection` validates the cached
  context is still alive before reusing it.

---

## Move-MyDocumentsContent

After a successful migration, the script reorganizes the user's OneDrive
from the legacy nested structure:

```
/Documents/HDrive/My Documents/<stuff>
```

to the flat OneDrive-friendly structure:

```
/Documents/<stuff>
```

This prevents users from ending up with a confusing nested `Documents/
Documents/My Documents` path after the migration.

---

## Common errors

| Symptom | Likely cause | Fix |
|---|---|---|
| "OneDrive not ready" | Provisioning in progress | Wait; script auto-retries up to 3x with exponential backoff |
| "Access denied" on UNC | File server perms | Verify your account has read on `\\server\users\<sam>` |
| AD update fails | RSAT-AD missing | `Install-WindowsFeature RSAT-AD-PowerShell` |
| `Migrate = ManualLog` | Migration had errors AND attaching the report failed | Pull the report from the SPMT log folder directly |
| `Redirect = "Failed"` | One of the AD group removals failed | Check `ScriptError` for the failing group; re-run with corrected `RedirectGP` |
| SCA add fails | Wrong claim GUID | Re-check `$SCA02` / `$SCA03` object IDs in Entra |
| SCAs still on user's OneDrive after migration | **Expected** — the script does not remove them | Clean up manually with `Remove-SPOUser` if your governance requires |
| `SPMTCred.xml` refuses to import | Different user / machine | Use menu option 5 "Clear credentials" or delete the file |
| `Processing` stuck after crash | Runner died mid-row | Manually clear `Processing` (and `Inprocess` if you see it from older versions) |
| Row is being skipped silently | Postpone column has a future date | Check all six postpone variants (`Postpone`, `PostPone`, `postpone`, `POSTPONE`, `Postponed`, `DelayUntil`) |
| Long-path errors on source UNC | Long-path registry keys missing | Run as local admin (script auto-sets via `Set-RequiredRegistryKeys`) |
| PST files not migrated | `@("pst")` is in `$BlockedExtensions` | Edit `$BlockedExtensions` if you want to allow PST |

---

## Sample invocation

```powershell
# Stage the user CSV(s) in F:\Migration-Users-Lists or populate the SPO list.
# Then from the runner:

.\Hdrive-OneDriveScript(081825a).ps1
```

The script is self-driving: it prompts (or loads) credentials, reads the
list, processes each row, and stops when the queue empties.

---

## Reminders

- Sanitized placeholders (`contoso.*`, `@contoso.gov`, the
  `eeeeeeee-...` / `ffffffff-...` claim GUIDs) must be replaced.
- Don't share `SPMTCred.xml` — it only works for the account that created it.
- This script is for personal home drives only. For shared/common drives,
  use the Common Drive specialist.

---

## Cloud portability

These were built and proven in **IL6** (sovereign / `microsoft.scloud` endpoints) but port cleanly to commercial or IL5 by swapping host suffixes only — no logic changes.

| Cloud | SPO | Login | Graph (if used) |
|---|---|---|---|
| Commercial | `.sharepoint.com` | `login.microsoftonline.com` | `graph.microsoft.com` |
| IL5 (GCC-H) | `.sharepoint.us` | `login.microsoftonline.us` | `graph.microsoft.us` |
| IL5 (DoD) | `.sharepoint-mil.us` | `login.microsoftonline.us` | `dod-graph.microsoft.us` |
| IL6 (sovereign) | `.spo.microsoft.scloud` | `login.microsoftonline.microsoft.scloud` | `graph.microsoft.scloud` |

SPMT version, module set, AD logic, driver-list schema, and SPO list workflow are identical in every cloud. Cert thumbprints, Entra app IDs, and the `@contoso.gov` UPN suffix are tenant-specific everywhere.

---

## Why this playbook — H: Drive → OneDrive (positioning)

### The competitive landscape

> **Pricing disclaimer.** All vendor cost figures below are **industry
> estimates** based on publicly-discussed federal SI engagements
> 2023–2026. None are quoted prices. ShareGate, AvePoint, Quest, and
> BitTitan price by RFQ; ranges vary widely by user count, term, and
> federal premium. **Confirm with a current vendor RFQ before citing any
> number in a customer-facing conversation.**

| Tool | Source coverage | Cloud reach | Licensing | Federal CUI/IL5/IL6 |
|---|---|---|---|---|
| **This playbook (SPMT + scripts)** | UNC home folders (`\\server\users\<sam>`) | Commercial, GCC, GCC-H/IL5, IL6 | **Free** (SPMT) + owned wrapper IP | **Yes — verified in IL6** |
| **Microsoft Mover** | File shares, cloud storage | Commercial only | Free | **Retired Feb 2024 — gone** |
| **SharePoint Migration Manager (SAC UI)** | UNC, SP server | Commercial, GCC; limited GCC-H | Free | No IL6; no AD glue |
| **OneDrive Sync client + manual lift** | Local filesystem | Anywhere OneDrive runs | Free | Manual labor at scale; no automation |
| **ShareGate Migrate (File Share module)** | UNC | Commercial, GCC | $30k–$150k+/yr | **No IL5/IL6 SaaS** |
| **AvePoint Fly** | File shares, multi-source | Commercial, GCC, GCC-H | Six-figure annual | Yes GCC-H; IL6 not documented |
| **BitTitan MigrationWiz (User Migration Bundle)** | File shares + mailbox | Commercial SaaS | ~$15–$40/user | **No** — routes through BitTitan cloud |
| **Quest On Demand Migration** | File shares + multi-workload | Commercial SaaS | $50k–$200k+/yr | SaaS routing concerns |

### Why CSAs pick this playbook for H: drives

1. **Zero licensing.** Per-user COTS pricing (estimate: roughly the low tens of dollars per user for file-share modules) compounds fast at 10k+ home drives. The licensing delta to this playbook is six-figure at typical federal home-drive scale — confirm with vendor RFQ.
2. **Mover's gap, filled.** Microsoft Mover retired Feb 2024 with no native UNC-to-OneDrive successor at scale. SPMT supports UNC but has no built-in identity workflow, no postpone-by-date, no per-user retry, no CSV-picker UI. This playbook is that missing layer.
3. **Identity workflow tied to migration success** — uniquely federal:
   - Remove user from `SecFltr-USR-OneDrive`
   - Add user to `SecFltr-USR-Office365` (script does NOT add to
     `O365S-AddOn-License` — it validates membership and skips with
     `Migrate = Unlicensed` if not present; license grant must happen
     upstream)
   - Multi-group removal via `RedirectGP` column (newline + comma separated)
   - Grants get auditable success/failure flags (`Redirect = "Failed"`)
4. **Conditional SCA grant** based on `SpecialGroup = "Yes"`:
   - Always adds SCA02 (OneDriveAdminGroup) for SPMT write
   - Adds SCA03 (TenantAdminsGroup) only for designated rows
   - **Note:** does NOT auto-remove SCAs post-migration; manual `Remove-SPOUser` if your governance requires it
5. **Postpone-by-date with six column-name spellings** (`Postpone`, `PostPone`, `postpone`, `POSTPONE`, `Postponed`, `DelayUntil`). Real-world federal data has wildly inconsistent column naming; this playbook tolerates it.
6. **Resilient by design:**
   - OneDrive provisioning retry: 3x with 60s / 120s / 180s exponential backoff
   - Throttle handler: 5x with 10–300s waits, honors `Retry-After`
   - PnP connection cache keyed by URL (cheap reconnects)
   - Fatal-error categorization → `ScriptError` column (LICENSE / UPN / ONEDRIVE PROVISIONING / ACCESS / THROTTLE / ...)
7. **Status nuance most tools don't model:**
   - `Migrated` = clean success
   - `ErrorLog` = per-file errors with `ItemReport_R1.csv` attached
   - `ManualLog` = had errors AND attaching the report failed
   - `Failed` = hard fail, `Processing` cleared for retry
   - Fatal errors append (not replace) to `ScriptError` so history is preserved
8. **Move-MyDocumentsContent step.** Post-migration, flattens legacy `/Documents/HDrive/My Documents/...` to `/Documents/...` so users don't end up with the confusing nested OneDrive structure. No COTS tool does this automatically.
9. **ACL changes on the source UNC run as a separate PowerShell process** so a slow ACL walk on a large home folder never blocks the user loop. `HReadOnly = "Updated"` indicates the bg job was launched.
10. **Sovereign-cloud native.** Same code, same behavior in IL6.
11. **Interactive CSV picker menu** classifies each CSV in `F:\Migration-Users-Lists` as NEW / STAGED / MIGRATED. Operators pick which to process. Menu option 5 clears the cached credential.
12. **DPAPI-protected credential cache** (`$env:USERPROFILE\SPMTCred.xml`) — only the original user on the original machine can decrypt. No vendor cloud, no broker.

### Honest tradeoffs (say so if asked)

- **SCAs are NOT removed post-migration.** Intentional in v5.2 for post-migration troubleshooting. Manual cleanup if governance requires it.
- **`@("pst")` blocked by default.** Edit the array if you want PSTs (typically no — they're huge and OneDrive sync hates them).
- **No GUI.** PowerShell-literate operators only.
- **No content classification / DLP at migration time.** OneDrive policy applies after.
- **Single source pattern.** This script assumes `\\server\users\<sam>`. Different patterns require source-resolution edits.
- **Per-user serialized.** Not parallelized at the user level (different from Common Drive's 18-worker design). Each runner does one user at a time. For >10,000 users use multiple runners on different CSV partitions.

### When NOT to use this playbook

- Bulk file-share migration that isn't per-user homedirs (use Common Drive playbook).
- Cross-tenant home drives (use BitTitan).
- Customer needs vendor-supported SLA + GUI (consider ShareGate in commercial or AvePoint in GCC-H).
- Customer wants pre-migration content scoring (consider AvePoint).
