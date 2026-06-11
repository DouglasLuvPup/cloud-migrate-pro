# H: Drive → OneDrive — User Experience Narrative

The point of this file: an operator can ask "what does the end user see / feel / get told?" and get an answer in customer-ready language. Voice: peer senior engineer; expand acronyms; light empathy.

---

## What the end user actually experiences

### Before migration

H: drive works as it always has. The user opens File Explorer, sees `H:`, opens files, saves files. Nothing changed.

OneDrive may or may not already be set up for them:
- If they have an SPO license + are signed into Office: the OneDrive client may already be syncing an empty (or near-empty) OneDrive on their desktop.
- If they don't have an SPO license: nothing OneDrive-related is happening yet, and the script will skip them with `Unlicensed` until the license is granted.

**Recommended pre-migration comms:** "Your H: drive is moving to OneDrive on [date window]. Until you get a 'complete' email, keep using H:."

### During Stage (if you're running Stage first)

Still nothing visible to the user. Stage copies content to their OneDrive in the background but doesn't:
- Lock down H:
- Change AD groups
- Move files around in OneDrive

If the user happens to open their OneDrive in the browser during Stage, they'll see their H: content appearing under `Documents/HDrive`. That's expected. They should still use H: for live work — anything they save to H: during Stage will be re-copied during cutover.

**Recommended comms during Stage:** *(generally none — Stage is operator-internal)*

### During cutover (Migrate)

This is the window where things change. Typical sequence within the user's row:
1. Final SPMT pass copies the latest H: content into OneDrive.
2. `Move-MyDocumentsContent` flattens `/Documents/My Documents/` → `/Documents/`. The legacy nested folder gets cleaned up.
3. AD groups flip:
   - User removed from `SecFltr-USR-OneDrive` (and any `RedirectGP` groups)
   - User added to `SecFltr-USR-Office365`
4. Source ACL lockdown launches in the background (separate PS process) — H: becomes read-only.

The user may or may not notice the switchover happening live. Typically:
- The OneDrive client on their desktop starts showing recent activity (new files appearing).
- The next time their Group Policy refreshes (Windows logon, scheduled GP refresh, manual `gpupdate /force`), the H: drive may un-map (because they're no longer in the redirection group that maps it).
- If they try to save to H: after cutover, they get "permission denied" (it's now read-only).

### After successful cutover (`Migrate = Migrated`)

- **OneDrive on the desktop** has all their files under `Documents/HDrive`. The folder structure from H: is preserved inside.
- **H: drive** is read-only. They can still read old files there during the rollback window.
- **AD `wwwHomePage`** is set to their new OneDrive URL.
- **Group memberships** updated as above.
- **SCA grants** on their OneDrive: `OneDriveAdminGroup` (always) + `TenantAdminsGroup` (if `SpecialGroup = Yes`).

**Recommended post-cutover comms:** "Your migration is complete. Use OneDrive going forward — your files are under Documents → HDrive. H: drive is now read-only. If anything looks off, reply by [date + 7 days]."

### Edge cases the user might experience

- **`Unlicensed`:** They will see no OneDrive provisioning at all. The script logs `Migrate = Unlicensed` and skips. From the user's view, nothing happened. Operator follows up with license grant.
- **`Invalid UPN`:** Same as Unlicensed from user perspective — nothing happens. Operator fixes the source data.
- **`ErrorLog`:** Migration mostly worked, but specific files didn't move (long paths, weird chars, blocked extensions). Email user with the list.
- **`ManualLog`:** Same as ErrorLog from user view; operator has to do file-system spelunking to find what failed.
- **`Failed`:** Nothing moved. H: still works as their live location. Reset and retry.

---

## What the end user does NOT need to know

Don't put any of this in user emails:

- The driver list, the SPO list columns, the script name
- SPMT, SCA, OneDriveAdminGroup, RedirectGP, the column-spelling tolerance
- `Move-MyDocumentsContent`, the ACL background job
- Which runner server processed their row
- The `ManualLog` vs `ErrorLog` distinction (just say "errors")

If a user asks a technical question, escalate to the operator/CSA team. The agent is for operators.

---

## Sample comms templates

### Pre-migration (1–2 weeks out)

> Subject: Your H: drive migration is scheduled
>
> Hi [Name],
>
> Your network home drive (`H:`) is scheduled to move to OneDrive on or around [date window]. This is part of [agency]'s file-storage modernization.
>
> **What to do:** Keep using H: as usual. We'll let you know when to switch.
>
> **What to expect:** You'll get a "complete" email when OneDrive has your files. After that, please use OneDrive — H: will become read-only.
>
> Questions: [helpdesk channel]

### Cutover complete

> Subject: Your OneDrive is ready — H: is now read-only
>
> Hi [Name],
>
> Your migration to OneDrive is complete.
>
> **Where your files are:** Open OneDrive (File Explorer → OneDrive in left sidebar, or icon in system tray). Your files are under **Documents → HDrive**, with the same folder structure you had on H:.
>
> **What changed:**
> - H: is now **read-only**. You can still see old files there, but new edits must go in OneDrive.
> - OneDrive syncs your work files to the cloud automatically.
>
> If anything looks missing, reply to this email by [date + 7 days].

### License gap (`Unlicensed`)

> Subject: We need to license your account first
>
> Hi [Name],
>
> Your H: drive migration is on hold pending a SharePoint Online license assignment. We've submitted the request; expect a follow-up within [N] business days.
>
> Keep using H: as usual in the meantime.

### Per-file errors (`ErrorLog`)

> Subject: Your migration is complete, with a few exceptions
>
> Hi [Name],
>
> Your H: drive content is in OneDrive (Documents → HDrive). A small number of files couldn't be moved automatically — typically:
> - Filenames with characters SharePoint doesn't allow (`# % & * { } | : ? <>`)
> - Very long file paths (over 400 characters)
> - File types Microsoft blocks in SharePoint (e.g., `.pst`)
>
> H: is read-only now but still readable. If you need a specific file moved manually, reply to this email with the filename.

### Hard failure (`Failed`)

> Subject: Migration didn't complete — we'll re-queue
>
> Hi [Name],
>
> Your migration didn't complete on this run. **Nothing was lost — H: is still your live location.** We're re-queueing it and will email when it's done.
>
> Continue using H: as usual.

---

## Operator gotchas around comms

- **The script doesn't email.** A Power Automate flow on the list does. If your shop sends emails separately (manual mailmerge, ServiceNow), coordinate so users don't get two "complete" messages from different systems.
- **Don't surface the H: read-only timing.** It's launched as a background job and may not be effective immediately. Tell users "H: is now read-only" only after you've confirmed the ACL job completed — or hedge with "H: will become read-only within the next hour."
- **Don't promise OneDrive client visibility.** The desktop OneDrive client may take minutes to hours to fully sync, depending on the user's machine. Telling them "your files appear instantly" sets up disappointment.
- **Acknowledge that "my files are moving" feels risky.** The truthful frame: H: stays as a read-only fallback indefinitely. Nothing is destroyed. Most user anxiety dissolves once they hear that.
- **Don't talk about Stage to end users.** Stage is operator-internal; users see no change. If you tell them "we're staging your content," they'll assume that means cutover and start panicking when H: still works.

---

## What to tell a non-technical asker

| Question | Plain answer |
|---|---|
| "Is my data safe?" | "Yes — content is copied, not moved. H: stays as a read-only backup." |
| "When can I start using OneDrive?" | "Once you get the 'complete' email. Until then, keep using H:." |
| "What if files are missing?" | "Reply to the completion email within 7 days and we'll restore from H:." |
| "Why are we doing this?" | "[Agency] is consolidating file storage to the cloud. OneDrive is the per-user destination; SharePoint sites for team content." |
| "Will I lose version history?" | "OneDrive keeps every version of every file going forward. H: didn't have version history at all, so you're gaining capability." |
| "Will my drive letter (H:) still work?" | "It'll still appear, but read-only. Once everyone in your unit is migrated, H: will be removed entirely. Until then, just use OneDrive." |
| "Will OneDrive use my disk?" | "By default, OneDrive Files On-Demand keeps placeholders on your disk and downloads files only when you open them. Your disk usage barely changes." |
| "What if I'm offline?" | "Right-click a folder in OneDrive → 'Always keep on this device' to download it for offline use." |
| "What about my desktop / Documents folder?" | "Those are separately managed by [your shop's KFM / Known Folder Move policy]. If your shop hasn't enabled KFM, those are local and don't sync. H: only contained network-stored files — local Desktop / Documents weren't part of H:." |
