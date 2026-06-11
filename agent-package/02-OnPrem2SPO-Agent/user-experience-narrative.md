# On-Prem → SPO — User Experience Narrative

The point of this file: an operator can ask "what does the end user see / feel / get told?" and get an answer in customer-ready language. Voice: peer senior engineer; expand acronyms; light empathy.

---

## What the end user actually experiences

### Before migration

Nothing changes for them. The script reads from the source MySite or on-prem SharePoint site and writes to the SPO equivalent. The user keeps using the old location until communication tells them otherwise.

### During migration (their row is in `Inprocess` / `Processing`)

Still no visible change for the end user. The script is copying in the background. If they have the source MySite open in a browser, they can keep editing — but anything they save during this window may need to be re-copied later (which means an admin task, not a user task).

**Recommended user comms during this window:** "Your OneDrive migration is queued/running this week. Until you receive a 'complete' email, keep using your current setup."

### After successful migration (`Migrate = Migrated`)

Three things change at once:

1. **Their AD `wwwHomePage` attribute now points to the new SPO OneDrive URL.** Apps that read this attribute (line-of-business apps, intranet directory listings, some Outlook contact-card features) will start linking to the new OneDrive.
2. **They no longer belong to the `*REDIRECTION*` group(s) or `SecFltr-USR-OneDrive`.** Group Policy that redirected their Documents folder to a network share will stop applying at next refresh. Windows starts using local-OneDrive paths instead.
3. **They are now a member of `SecFltr-USR-Office365`.** This is typically the gate group for downstream provisioning (Teams chat, OneDrive sync client config, conditional access exceptions, etc.). Adding them flips on whatever's keyed to this group.

Plus: the **source MySite is locked down** — the migration service account is the SCA on the source, and the user is demoted. So if they try to open the old MySite in a browser, they may still see it but won't have admin rights to manage it; depending on permissions, content may or may not be readable.

**Recommended user comms post-migration:**
- "Your OneDrive migration is complete. Your files are at [new OneDrive URL]."
- "The old [source MySite URL] is now archived. Don't bookmark it — use the new OneDrive."
- "If anything looks missing, reply to this email within 7 days. We keep the source as a fallback during that window."

### After a failed migration (`Migrate = Failed` or `Migrate = ErrorLog`)

The script doesn't email the user — a Power Automate flow on the SPO list does. The end user's experience depends entirely on what the flow says.

- **Failed** → "We hit an issue migrating your content. Don't worry — nothing was lost. We'll re-run and notify you when it's complete." Avoid technical detail; operator follow-up addresses root cause.
- **ErrorLog** → "Your content is mostly migrated. A few files (typically those with very long paths, special characters, or types Microsoft blocks) couldn't move. We'll review and follow up."

---

## What the end user does NOT need to know

Don't put this in user emails — it's operator-internal:

- The driver list, the SPO list columns, or the script names
- SPMT, SCA, `wwwHomePage`, group names, the `Inprocess` vs `Processing` distinction
- The `#<#`/`#>` comment quirk
- Power Automate flow logic
- Which runner server processed their row

If a user asks a technical question, route them to their helpdesk. The agent is for operators and CSAs.

---

## Sample comms templates

### Pre-migration heads-up (1–2 weeks out)

> Subject: Your OneDrive migration is scheduled
>
> Hi [Name],
>
> Your home folder / SharePoint MySite is scheduled to move to SharePoint Online OneDrive on or around [date window]. This is part of [agency]'s move to the cloud.
>
> **What to do:** Nothing. Keep using your current location.
>
> **What to expect:** You'll get a "complete" email when your new OneDrive is ready. At that point, please use the new location — the old MySite will be archived.
>
> Questions: [helpdesk channel]

### Cutover-complete

> Subject: Your OneDrive is ready
>
> Hi [Name],
>
> Your migration to SharePoint Online OneDrive is complete. **Your new OneDrive:** [URL]
>
> **What to do:**
> 1. Open File Explorer. OneDrive should appear in the left sidebar within a few minutes (if it doesn't, run "OneDrive" from Start).
> 2. Sign in with your work account if prompted.
> 3. Your files are under `Documents`.
>
> **What changed:**
> - Your old MySite at [old URL] is now archived (read-only). Don't bookmark it.
> - Apps that linked to your old location will start pointing at the new OneDrive automatically.
>
> If anything looks missing, reply to this email by [date + 7 days] — we keep your source content as a fallback during that window.

### Per-file error (ErrorLog)

> Subject: Your OneDrive migration completed with a few exceptions
>
> Hi [Name],
>
> Your migration is complete, with a small number of files that couldn't be moved automatically. The most common reasons are:
> - Filenames with characters SharePoint doesn't allow (e.g., `# % & * { } | : ? <>`)
> - Very long file paths (over 400 characters end-to-end)
> - File types Microsoft blocks in SharePoint (e.g., `.pst`, executables)
>
> We have the list of affected files and will follow up if action from you is needed.

### Hard failure (Failed)

> Subject: Your OneDrive migration needs another pass
>
> Hi [Name],
>
> Your migration didn't complete on this attempt. Nothing was lost — your source content is unchanged.
>
> We're re-queueing it and will email again when it's complete.

---

## Operator gotchas around comms

- **Don't send "complete" emails from the script.** The script doesn't email. The Power Automate flow does. If you trigger emails from somewhere else (e.g., a manual mailmerge), you may double-send when the flow fires.
- **Don't tell users about the SCA swap or AD group changes.** They're identity-layer plumbing; the user experience is "things work" or "things don't work."
- **Don't promise speed.** Per-user OD2OD typically completes in minutes; a large SP2SPO site can take hours. Communicate a window, not a time.
- **Don't tell users the old MySite is "deleted."** It isn't. It's locked down (SCA swap) but the content is still there as a fallback. Use "archived" or "read-only."
- **Acknowledge anxiety.** End users often perceive "my files are moving" as risky. The truthful frame is: nothing is moved; files are copied; source stays as a fallback. That language defuses most of the worry.

---

## What to tell a non-technical asker

| Question | Plain answer |
|---|---|
| "Is my data safe?" | "Yes — content is copied, not moved. Your source is untouched until you confirm everything looks good." |
| "When can I start using OneDrive?" | "When you get the 'complete' email. Until then, keep using what you have." |
| "What if files are missing?" | "Reply to the completion email within 7 days and we'll restore from the source." |
| "Why are we doing this?" | "[Agency]'s file storage is consolidating to the cloud. OneDrive is the destination for personal files; SharePoint Online sites for team content." |
| "Will I lose my version history?" | "No. SharePoint Online keeps all your prior versions of every file." |
| "Will my AD account change?" | "Your AD home page attribute will point to OneDrive instead of the old MySite. Your sign-in, password, and group memberships otherwise stay the same." (Caveat: you ARE removing them from the redirection groups + SecFltr-USR-OneDrive, but those are infrastructure groups not used for sign-in.) |
