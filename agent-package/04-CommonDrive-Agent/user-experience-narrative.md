# Common Drive → Teams / SPO — User Experience Narrative

The point of this file: an operator can ask "what does the end user see / feel / get told?" and get an answer in customer-ready language. Voice: peer senior engineer; expand acronyms; light empathy.

---

## What the end user actually experiences

### Before migration

The shared / common UNC drive works as it always has. Users open it from File Explorer (mapped drive letter or `\\server\share\...` path), open files, save files. Nothing changed.

The destination (Teams channel for Flow A, SPO site for Flow B) may or may not exist yet:
- **Flow A:** the Team and channel exist (someone created them), but the channel folder underneath may not be provisioned (Teams lazy-creates it). `Update-MigrationTargets.v2.ps1` Phase 1 force-provisions it before migration.
- **Flow B:** the SPO site exists (someone created it). No channel concept.

**Recommended pre-migration comms (to the unit, not individual users):**
> "Your shared drive `\\server\share\HR Files` is moving to [Teams channel name / SPO site URL] on or around [date window]. Keep using the current location until you receive a 'complete' notice."

### During Stage

Content is being copied to the target in the background. Users don't see this — there are no comms to send during Stage.

If a user happens to open the destination during Stage, they'll see partially-populated content. That's fine, but they shouldn't start using it yet — the cutover hasn't happened and any edits at destination will be **overwritten by the next delta pass**.

### During cutover (Migrate)

The orchestrator does a final delta SPMT pass, marks the row `Migrated` (or `MigratedWithErrors` / `Failed`), and the Power Automate flow notifies people based on the row's final state.

Users may notice:
- New files / updated files appearing in the Teams channel or SPO site.
- The source UNC drive still works (it's NOT locked down by this playbook — Common Drive doesn't do source ACL changes like H: Drive does).

### After successful cutover

- **Teams channel folder (Flow A) or SPO site (Flow B)** has all the content from the source UNC.
- **Source UNC drive** still has the content, still writeable. **No ACL change happens.** The content is copy-not-move; if you want source decommissioned, that's a separate governance step.
- **File ownership / permissions** at target are inherited from the Team's M365 group membership (Flow A) or the SPO site's permission set (Flow B). They do NOT match source NTFS ACLs file-by-file — that's intentional; cloud collaboration uses different access models than NTFS.

**Recommended post-cutover comms:**
> "Your shared drive content has migrated to [Teams channel / SPO site URL]. Please use the new location going forward.
>
> Note: the old `\\server\share\HR Files` is still accessible but will be decommissioned on [date]. Save new work to the new location."

### After failed migration

- **`Failed`** → Power Automate emails the unit lead (per your flow config). "Migration didn't complete. We'll re-queue. Continue using the source."
- **`MigratedWithErrors`** → "Migration mostly succeeded. A few files had errors (long paths, weird characters, blocked types). We're reviewing."
- **`StagedWithErrors`** → Operator-only notification typically; cutover hasn't happened.

---

## Things that are different from H: Drive

End users may have been through the H: Drive migration before — set expectations carefully:

| Aspect | H: Drive | Common Drive |
|---|---|---|
| Destination | Personal OneDrive | Teams channel folder OR SPO site |
| Source after cutover | Read-only (script locks it down) | **Still writeable** (no ACL change) |
| Access model | "You own it" — personal | "Your team owns it" — shared based on group membership |
| Version history | Was none on H:; OneDrive now has it | Was none on UNC; SPO now has it |
| Folder structure | Preserved under Documents/HDrive | Preserved under the target folder |
| Email notification | Per-user | Typically unit-level (configure your Power Automate flow) |

**Why source isn't locked down:** Common drives are usually accessed by many users, often across multiple teams, and the customer typically wants a coexistence window where both source and target are live before fully cutting over. Locking the source the moment migration completes would break that workflow.

If your customer wants source lockdown after cutover, that's a separate governance step — run an ACL change script after sign-off, or set the share to read-only at the file-server level.

---

## What the end user does NOT need to know

Don't put any of this in user emails:

- The driver list, the script names, the `Migrate` column, state values
- Stage vs Migrate, `-MigrationType`, the orchestrator, the 18 workers, the 36 apps
- `ClaimedBy`, `ClaimStaleHours`, `YearUsed`, the storage auto-downgrade
- The Power Automate flow internals
- Per-row error categorization

End users care about: "where's my stuff now?" and "what do I do differently?" Everything else is operator-internal.

---

## Sample comms templates

### Pre-migration unit announcement

> Subject: `\\server\share\HR Files` is moving to a Teams channel
>
> Hi all,
>
> Your shared drive `\\server\share\HR Files` is migrating to the **HR** Team's **Files** channel on or around [date window]. This is part of [agency]'s file-storage consolidation.
>
> **What to do:** Keep using the current shared drive. We'll let you know when to switch.
>
> **What to expect:** You'll get a "complete" notice with the new Teams channel link. After that, use the channel.
>
> Questions: [helpdesk channel]

### Cutover complete (Flow A — Teams channel)

> Subject: Your shared drive is now in Teams
>
> Hi all,
>
> Your shared content has migrated to the **HR > Files** channel in Teams.
>
> **Where to go:** Open Teams → HR → Files. All your folders and files are there, organized the way they were on the shared drive.
>
> **What changed:**
> - **Teams is now the primary location.** Save new work there.
> - The old `\\server\share\HR Files` is still accessible but will be decommissioned on [date]. Don't save new work there.
> - **Version history is on:** SharePoint keeps every version of every file going forward.
> - **Access:** based on Teams membership. If someone needs access, add them to the HR Team.
>
> If a specific file looks missing or wrong, reply to this email by [date + 7 days].

### Cutover complete (Flow B — SPO site)

> Subject: Your shared drive is now in SharePoint
>
> Hi all,
>
> Your shared content has migrated to: [SPO site URL]
>
> **Where to go:** Open the link above. Bookmark it. All your folders and files are there.
>
> **What changed:**
> - **SharePoint is now the primary location.** Save new work there.
> - The old `\\server\share\HR Files` is still accessible but will be decommissioned on [date]. Don't save new work there.
> - **Version history is on.**
> - **Access:** managed by the site owner. Requests go to [owner name].
>
> If anything looks off, reply by [date + 7 days].

### Per-file errors (`MigratedWithErrors`)

> Subject: Migration complete, with a few exceptions
>
> Hi all,
>
> Your shared drive is now in [Teams channel / SPO site]. A small number of files couldn't be moved automatically — typically:
> - Filenames with characters SharePoint doesn't allow (`# % & * { } | : ? <>`)
> - Very long file paths (over 400 characters)
> - File types Microsoft blocks (e.g., `.pst`)
>
> The source drive is still accessible, so those files are still readable. If you need a specific one moved manually, reply to this email with the filename.

### Hard failure (`Failed`)

> Subject: Migration didn't complete this run
>
> Hi all,
>
> Your shared drive migration didn't complete on this attempt. **Nothing was lost — the source is unchanged.** We're re-queueing and will email when it's done.
>
> Continue using `\\server\share\HR Files` as usual.

### Storage horizon notice (`YearUsed = 3`)

If `YearUsed` ended up at 3 (the smallest), files older than 3 years didn't migrate. Tell the unit:

> Subject: Heads-up: older files weren't moved
>
> Hi all,
>
> Your migration is complete, but **files modified more than 3 years ago stayed on the source drive** — the target site didn't have enough quota to hold the full history.
>
> Those older files are still at `\\server\share\HR Files`. If your team needs any of them moved to Teams, reply with a list and we'll handle it case-by-case.

---

## Operator gotchas around comms

- **Source isn't locked.** Don't tell users "the old drive is read-only" unless you've separately done ACL changes. Common Drive playbook doesn't lock source.
- **Power Automate is the email path.** If your flow's trigger column or threshold is wrong, users won't get notified even on success. Test the flow before each wave.
- **Storage downgrade is silent unless you communicate it.** Operators sometimes don't realize `YearUsed = 3` means 7-year files didn't migrate. Always include a horizon-notice email if `YearUsed < 7`.
- **Teams channel folder permissions don't match NTFS.** A user who could read a specific subfolder via NTFS ACL but isn't in the Team won't have access post-migration. Pre-migration discovery should include "who needs to be added to the Team."
- **Don't promise "everything migrates."** Blocked extensions, long paths, retention-horizon cuts, weird filenames — all reasons files stay at source. Set expectation honestly.

---

## What to tell a non-technical asker

| Question | Plain answer |
|---|---|
| "Is our data safe?" | "Yes — content is copied, not moved. The source drive stays as a fallback." |
| "When do we switch?" | "When you get the 'complete' notice. Until then, keep using the current shared drive." |
| "What if something's missing?" | "Reply to the completion email within 7 days with the filename and we'll restore from source." |
| "Why are we doing this?" | "[Agency] is consolidating file storage to the cloud. Teams / SharePoint Online is the destination for shared content; OneDrive is for personal files." |
| "Do we lose version history?" | "No — you're gaining it. The shared drive had no versioning; SharePoint keeps every version forward." |
| "Who can see our files now?" | "[Flow A] Members of the HR Team. To grant access, add them to the Team. / [Flow B] Members of the SPO site. The site owner is [name]." |
| "Will the share letter (S:, G:, etc.) still work?" | "It'll keep working for now — we'll decommission it on [date], after the migration is verified." |
| "Why are some old files still on the old drive?" | "Quota limits — files older than [N] years stayed at source. Tell us if you need specific older files moved." (Only relevant if `YearUsed < 7`.) |
