# H: Drive Agent — Topics Build Sheet

## 1. Conversation Start

**Nodes:**
1. **Message:**

```
🏠 **H: Drive → OneDrive Migration Specialist**

I cover the 2025 playbook: network home drives (\\server\users\<sam>) into
the user's SPO OneDrive under /Documents/HDrive.

Pick a path:
```

2. **Question** (buttons): `Workflow`, `Prereqs`, `Sample call`,
   `Errors`, `SCA cleanup`, `Postpone`, `Status values`,
   `Back to Concierge`.
3. **Condition** → redirect to matching topic.

---

## 2. Workflow

**Trigger:** workflow, diagram, picture, flow

**Nodes:** Message with the Mermaid diagram from `workflows.md`.

---

## 3. Prereqs

**Trigger:** prereqs, requirements, what do I need

**Nodes:** Message with the prereq section from `knowledge-cards.md`.

---

## 4. Sample Call

**Trigger:** sample, example, how do I run, command line, run the script

**Nodes:**
1. **Message** with the PowerShell sample from `knowledge-cards.md` →
   "Sample invocation".
2. Reminder to replace `contoso.*`, `@contoso.gov`, and the
   `eeeeeeee-...` / `ffffffff-...` claim GUIDs with real values.

---

## 5. Credentials / SPMTCred.xml

**Trigger:** credential, password, SPMTCred, re-prompt, login

**Nodes:**
1. **Message:**

```
The script caches your SPO credential at:
  $env:USERPROFILE\SPMTCred.xml

To force a re-prompt:
  Remove-Item $env:USERPROFILE\SPMTCred.xml

The XML is DPAPI-protected — only your account on this machine can decrypt
it. Don't copy it to other machines.
```

---

## 6. AD Group Changes

**Trigger:** group, security group, SecFltr, license, O365S-AddOn

**Nodes:**
1. **Message:** "On success, the script flips AD group membership:"
2. Bullet list:
   - Remove: `SecFltr-USR-OneDrive`
   - Add: `SecFltr-USR-Office365`, `O365S-AddOn-License`
3. Note: requires RSAT-AD PowerShell module on the runner.

---

## 7. Site Collection Admin claims

**Trigger:** SCA, site collection admin, claim, c:0t.c|tenant, SCA02, SCA03, SpecialGroup

**Nodes:**
1. **Message:**

```
The script adds SCAs to each user's OneDrive so SPMT can write to it:

  SCA02 = c:0t.c|tenant|eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee (OneDriveAdminGroup)
        — ALWAYS added.

  SCA03 = c:0t.c|tenant|ffffffff-ffff-ffff-ffff-ffffffffffff (TenantAdminsGroup)
        — added ONLY when the list item SpecialGroup column = "Yes".

Replace those GUIDs with your tenant's group object IDs.

IMPORTANT: the script does NOT remove SCA02 or SCA03 after migration.
They persist on the user's OneDrive. Manual cleanup if your governance
requires it:

  Remove-SPOUser -Site <OneDriveUrl> -LoginName "c:0t.c|tenant|<SCA-GUID>"
```

---

## 8. Errors / Retry

**Trigger:** error, failed, retry, Processing stuck, FatalError, ScriptError, ManualLog, ErrorLog

**Nodes:**
1. **Message** with the "Common errors" table from `knowledge-cards.md`.
2. Note: only the `Failed` path clears `Processing` for retry. `ErrorLog`,
   `ManualLog`, and fatal-error rows leave `Processing` set and write a
   terminal `Migrate` value (see the "Status values" topic).
3. Note: fatal SPMT errors are categorized (LICENSE / UPN /
   ONEDRIVE PROVISIONING / ACCESS / THROTTLE / ...) and appended to the
   `ScriptError` column.

---

## 8a. Status values

**Trigger:** status, Migrate column, what does ErrorLog mean, ManualLog

**Nodes:** Message with the full Migrate-column value table from
`knowledge-cards.md` (Ready / Processing / Migrated / ErrorLog /
ManualLog / Failed).

---

## 8b. Postpone

**Trigger:** postpone, skip, delay, DelayUntil

**Nodes:** Explain the six accepted postpone-column spellings
(`Postpone`, `PostPone`, `postpone`, `POSTPONE`, `Postponed`,
`DelayUntil`). If any holds a future date the row is silently skipped.
`Reset-PostponedUserStatus` clears stale entries.

---

## 8c. RedirectGP multi-group

**Trigger:** RedirectGP, multiple groups, Redirect Failed

**Nodes:** Explain that `RedirectGP` accepts MULTIPLE group names,
parsed newline- then comma-separated. If any removal fails,
`Redirect = "Failed"`.

---

## 8d. Move-MyDocumentsContent

**Trigger:** My Documents, nested folders, Documents Documents, flatten

**Nodes:** Explain post-success reorganization from legacy
`/Documents/HDrive/My Documents/...` to flat `/Documents/...`.

---

## 8e. ACL background process

**Trigger:** ACL, lock down source, HReadOnly, read only

**Nodes:** Explain that ACL changes on the source UNC run in a SEPARATE
PowerShell process so they don't block the user loop. `HReadOnly =
"Updated"` indicates the bg job was launched (not that ACLs are done).

---

## 9. Back to Concierge

**Trigger:** back, exit, concierge, different scenario

**Nodes:** Redirect to connected agent → `Cloud Migrate Pro Concierge`.

---

## 10. Out of Scope

**Trigger:** common drive, shared drive, file share, SP site, mailbox

**Nodes:**
1. **Message** "That's not in my scope — back to the Concierge."
2. Redirect to `Cloud Migrate Pro Concierge`.

---

## 11. Fallback

In-scope keyword present (H drive, OneDrive provisioning, SCA, etc.) →
generative answer grounded on knowledge. Otherwise → out-of-scope message.

---

## 12. "Why" questions

**Trigger phrases:** why, rationale, reason, what's the point, why bother, why do, what's the purpose, justify

**Nodes:**
1. **Message:** "Good 'why' question. Here's the short version — ask if you want me to expand any of these."
2. **Generative answer grounded on knowledge** (`faq-plain-english.md`, `knowledge-cards.md`) covering:
   - Why migrate H: drives at all? → home drives are an old NTFS pattern; OneDrive gives users versioning, sync, web access, and reduces file-server footprint.
   - Why under `/Documents/HDrive/` and not the OneDrive root? → preserves a clean recovery path and avoids name collisions with content the user already has in OneDrive.
   - Why does the script add and KEEP SCA claims (SCA02 / SCA03)? → SPMT writes to user OneDrives via service-account access; cleanup is governance-policy decision left to the customer.
   - Why ADD to `SecFltr-USR-Office365` instead of toggling? → the operation is additive; users may still need other group memberships preserved. We grant; we don't remove arbitrary memberships.
   - Why VALIDATE `O365S-AddOn-License` instead of adding it? → license groups are typically governed by a separate identity team; the script verifies the user is licensed (it's a precondition) but doesn't grant licenses.
   - Why a separate background process for ACL changes? → ACL recursion on big home folders is slow; the user-loop must keep moving. The bg process writes status back independently.
   - Why six different "Postpone" spellings? → operators are humans; consistent column conventions break under real load. The script accepts what people actually type.
3. Always offer to go deeper.

---

## 13. Audience-aware patterns

**Trigger phrases:** customer, executive, end user, manager, team, audience, talking points, summary for, brief, layman

**Nodes:**
1. **Question** (buttons): "Who's the audience?"
   - "End user (the person being migrated)" → `EndUser`
   - "Manager / team lead" → `Manager`
   - "Executive / sponsor" → `Executive`
   - "Other CSA / engineer" → `Engineer`
2. **Condition** on the saved value:
   - `EndUser` → generative answer grounded on `user-experience-narrative.md` — plain language, no script names, no column names. Use the comms templates verbatim where possible.
   - `Manager` → generative answer grounded on `faq-plain-english.md` and `user-experience-narrative.md` — "what changes for your team," timing, what to say.
   - `Executive` → generative answer grounded on the Concierge battlecards positioning — cost, sovereignty, governance, tradeoffs. No mechanics.
   - `Engineer` → generative answer grounded on `knowledge-cards.md`, `troubleshooting.md`, `command-reference.md` — full detail.
3. **Message** offer: "Want me to draft an actual email/announcement using this? Tell me the audience and I'll produce a draft."
