# On-Prem → SPO — Decision Aids

When an operator asks "should I X or Y?" — this file has the answer in a single screen. Voice: peer senior engineer, no padding.

---

## OD2OD vs SP2SPO — which script?

Always confirm the **source type** first.

| Source | Target | Script |
|---|---|---|
| On-prem MySite (per-user OneDrive on legacy SP) | SPO OneDrive (`/personal/`) | `Migration-OD2OD-SPO(09132024).ps1` |
| On-prem SharePoint site (team site, project site, communication site on SP 2016/2019) | SPO site (`/sites/`) | `Migration-SP2SPO(09132024).ps1` |

If the user says "OneDrive" but means "my home folder on a file server" → that's H: Drive, not this agent. Route them to the Cloud Migrate Pro Concierge.

If the user says "SharePoint" but means "I have a folder on a UNC share that needs to go to a Team channel" → that's Common Drive, not this agent.

---

## When to run an Inprocess / Processing reset

The lock-flag column gets set when a runner picks up a row. It gets cleared when the row finishes. If a row is stuck in the lock state but no runner is touching it, the runner crashed mid-row.

| Situation | Reset? |
|---|---|
| Row in lock state, runner is actively logging in the transcript | **No.** It's still running. Wait. |
| Row in lock state, runner host is offline / rebooted / no transcript activity for >2× the average per-row time | **Yes.** Clear the lock column (`Inprocess` for OD2OD, `Processing` for SP2SPO). Row will be retried on next runner cycle. |
| Row in lock state, want to abort | **Yes**, clear the lock. Also kill any SPMT process on the runner host first to avoid orphaned writes. |
| Row in lock state, want to permanently skip | Set `Migrate = Skipped` (or your shop's convention), clear lock. The script won't pick rows where Migrate isn't `"Migrate"`. |

---

## When to retry vs investigate vs escalate

| Symptom on the row | First move |
|---|---|
| `Migrate = ErrorLog` | Open the attached `FailureSummaryReport.csv`. If errors are filename/long-path issues, fix at source then re-trigger by setting `Migrate = "Migrate"`. If errors are auth/access, fix that first. |
| `Migrate = Failed`, log shows SPMT failed | Open the transcript. Common causes: source unreachable (network), credentials wrong (re-prompt), SPMT corruption (reinstall SPMT). |
| `Migrate = Failed`, log shows AD cmdlet failure | Runner account lacks AD perms. Verify delegation. Re-run for this user only once perms are fixed. |
| `Migrate = Failed`, log empty | Pre-run guard failed silently. Check execution policy, cert thumbprint, DLL path. |
| Repeated 429 throttle on many users | SPO is throttling. Lower concurrency (run on fewer servers), or wait an hour, or open a Microsoft support ticket if persistent. |
| One user works fine, another always fails | Look at the user-specific differences: license state, UPN format, special characters in MySite URL, SharePoint version on source. |

---

## When to enable vs disable the AD block

The AD block runs **by default** (see comment-marker caveat in knowledge files). Decide whether you actually want it running for this engagement:

| Scenario | Recommendation |
|---|---|
| Federal customer, identity-aware downstream apps that read `wwwHomePage` | **Keep on.** This is what the playbook is for. |
| Customer wants AD changes via a separate governance workflow (e.g., ServiceNow ticket per user) | **Disable.** Change `#<#` to `<#` on the marker lines in the script. Run AD updates separately. |
| Customer doesn't use redirection groups / doesn't have `SecFltr-USR-Office365` etc. | **Disable.** Run a quick pilot with one user; if no value, leave off. |
| Customer governance requires AD changes be reviewable before commit | **Disable.** Stage the migration without AD; then run an AD-only cleanup script after sign-off. |

---

## When to do OD2OD vs ask "do they even need a MySite"

If a customer is migrating on-prem MySites that are essentially empty (users never used them), consider:

- **Skip the migration.** Set `Migrate = NotNeeded` (or similar) and just provision the new OneDrive. The script's `Move-MyDocumentsContent` flatten step won't have anything to flatten. Saves time at scale.
- **Migration is for content + identity changes.** If you skip, you still need to make the AD `wwwHomePage`, group removal, and SecFltr-USR-Office365 add happen via a separate one-off script — they're tied to the migration success path in the orchestrator.

Rule of thumb: if average MySite content is < 50MB across the wave, the per-row overhead of running the script exceeds the value. Bulk-provision and run a slim AD-cutover-only script.

---

## When to use Stage (SP2SPO) vs straight Migrate

SP2SPO doesn't have a formal Stage mode in this script (Common Drive does). But you can simulate one:

1. Run SP2SPO against a smaller subset (e.g., one project site).
2. Verify content fidelity, permissions, links.
3. Repeat for next subset.

Use straight Migrate if:
- The site is owned by one team that can cutover at a known time.
- Source content is stable (no active writes).
- You've already done a fidelity check on a similar site.

---

## When to escalate to Microsoft support

- SPMT engine errors that aren't documented and reproduce across runners (likely SPMT bug — open a ticket with reproduction steps + version)
- Tenant-wide throttle that doesn't subside after an hour
- SPO endpoint returning 5xx for >15 minutes
- App registration / cert problems specific to the tenant config (e.g., conditional access blocking the runner account)

---

## When NOT to use this playbook at all

- **Cross-tenant migration** — wrong tool. Use Microsoft cross-tenant tooling or BitTitan.
- **Mailbox migration** — wrong tool. Use mailbox-migration scripts or third-party.
- **OneDrive sync client troubleshooting** — wrong tool. That's a desktop issue.
- **File-share → OneDrive** — wrong tool. Route to H: Drive specialist.
- **File-share → Teams channel** — wrong tool. Route to Common Drive specialist.

If the operator describes a scenario in the "wrong tool" column, route them back to the Concierge: "That's not in my scope. Type 'back' to return to the Cloud Migrate Pro Concierge and pick the right specialist."

---

## When the customer asks "Why this vs ShareGate?"

Short version (without quoting prices, which are RFQ):
- ShareGate is GUI-friendly and has good fidelity for permissions on commercial.
- ShareGate doesn't have an IL5 or IL6 SaaS instance. If you're in either, ShareGate isn't an option.
- ShareGate doesn't ship the AD/SCA federal identity glue this playbook does — you'd have to build it yourself.
- ShareGate per-year licensing is typically five to six figures depending on user count and federal premium; this playbook is free (SPMT) + internal wrapper IP.

Long version is in `knowledge-cardsv2.md` under "Why this playbook."

---

## When to retry a single row vs the whole wave

| Situation | Approach |
|---|---|
| One user failed in an otherwise-clean wave | Single-row retry. Clear lock, set `Migrate = "Migrate"`, let the next runner pick it up. |
| Multiple users failed with the same error (auth, throttle, network) | Don't retry individually. Fix the underlying issue, then mass-retry by clearing locks and resetting `Migrate`. |
| Entire wave is `Failed` | Stop. Don't retry until root cause is identified. Likely a config or environment problem. |
