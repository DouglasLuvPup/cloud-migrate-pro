# Cloud Migrate Pro — Copilot Studio Upload Guide

After the audit + Phase 1/2/3 changes, this is the exact set of files to upload to each Copilot Studio agent. **Update each agent in this order** so the Concierge can route to specialists that already have the new knowledge.

---

## Quick map

| Agent | System prompt | Knowledge files | Topics | Conversation start |
|---|---|---|---|---|
| **Concierge** | `01-Concierge/system-prompt-TRIMMED-8k.md` | `battlecards.md`, `boundary-cases.md` | Built in Copilot Studio UI manually (no `topics.md` upload) | Greeting + suggested prompts on Overview page (no welcome-card upload) |
| **OnPrem → SPO** | `02-OnPrem2SPO-Agent/system-prompt-TRIMMED-8k.txt` | 8 reference files + 2 sanitized scripts (see below) | Built in UI; reference `topics.md` | (none) |
| **H: Drive** | `03-HDrive-Agent/system-prompt-TRIMMED-8k.v2.txt` | 6 reference files + 1 sanitized script (see below) | Built in UI; reference `topics.md` | (none) |
| **Common Drive** | `04-CommonDrive-Agent/system-prompt-TRIMMED-8k-FINAL.txt` | 8 reference files + 3 sanitized scripts (see below) | Built in UI; reference `topics.md` | (none) |

---

## 1. Concierge agent

### What to upload

**System prompt (paste into Agent → Overview → Instructions):**
- `01-Concierge/system-prompt-TRIMMED-8k.md` — includes sharpened Q1, SP version boundary, cross-tenant explicit refusal, and the **anti-fabrication clause** ("never invent script content; link to scripts.html for the verbatim source"). Currently ~8.2k chars; Copilot Studio's current effective cap accepts it. If Studio rejects on paste, trim the COST or WHERE WE WIN paragraphs.

**Knowledge files (Agent → Knowledge → + Add):**
- `01-Concierge/battlecards.md` — vendor positioning vs ShareGate / AvePoint / Quest / BitTitan / Migration Manager
- `01-Concierge/boundary-cases.md` — out-of-scope routing (SP 2013, cross-tenant, multi-workload, SaaS sources)

**Greeting + Suggested prompts (already configured — leave as-is):**

Copilot Studio has no "welcome card" upload field. The greeting and the chip set live in the agent's **Overview** page, and your Concierge already has both:

- **Default greeting** — Studio auto-generates a greeting from the agent's Description + Instructions. The current Concierge greeting (three-scenario intro + `help me decide` prompt) renders well in every channel and does **not** need to change.
- **Suggested prompts** — Overview → Suggested prompts tile → Edit. Four chips already configured: *Where do I start? · Explain my options simply · Help me pick the right one · Why not just buy a tool?* — these lean into the decision-help and battlecard story. Leave them, or swap one for a direct-route chip ("I know which one I need") if you want to balance confused vs confident users.

The Adaptive Card in `01-Concierge/welcome-card.json` is **reference only** — it's an artifact from earlier design exploration. Copilot Studio doesn't take a JSON upload for the welcome message. If you ever want the rich card in Teams, drop it into a **Send a message → Adaptive Card** node inside a custom topic; otherwise ignore the file.

### What to REMOVE from Concierge knowledge

Pruning these from upload to keep Concierge tight (everything is now in `battlecards.md` or covered by the system prompt):
- ❌ `demo-script.md` — operator-side demo flow, not for the agent
- ❌ `marketing-onepager.md` — duplicates battlecards content
- ❌ `roi-worksheet.md` — operator-side calc; not Concierge's job
- ❌ `evaluate-test-prompts.md` — QA reference, not knowledge
- ❌ `topics.md` — reference material for the human builder; topics are configured via the Copilot Studio UI

These files stay in the repo for human reference. They're just not uploaded to the agent.

### Settings

- **Generative answers:** OFF at the agent level. Concierge speaks via the system prompt + topics + handoff only.
- **Connected agents:** add all three specialists.
- **Model:** Claude Sonnet 4.6 (or highest-tier GPT available).

---

## 2. On-Prem → SPO agent

### What to upload

**System prompt (paste into Instructions):**
- `02-OnPrem2SPO-Agent/system-prompt-TRIMMED-8k.txt` — includes the "Migrate" literal-value fix, source-MySite SCA target fix, AD-runs-by-default safety language, and the **anti-fabrication clause** (quote scripts verbatim from knowledge; link to scripts.html if not found).

**Knowledge files (Agent → Knowledge → + Add):**
- `02-OnPrem2SPO-Agent/knowledge-cardsv2.md` — main reference (post-fix)
- `02-OnPrem2SPO-Agent/workflows.md` — Mermaid diagrams + shared characteristics (post-fix: split sleep diagram, OD2OD = 30s, SP2SPO = 120s)
- `02-OnPrem2SPO-Agent/troubleshooting.md` — gotchas and recovery steps (post-fix)
- `02-OnPrem2SPO-Agent/preflight.md` — pre-run checklist
- `02-OnPrem2SPO-Agent/command-reference.md` — switch and column reference
- `02-OnPrem2SPO-Agent/faq-plain-english.md` — **NEW** (Phase 2)
- `02-OnPrem2SPO-Agent/user-experience-narrative.md` — **NEW** (Phase 2)
- `02-OnPrem2SPO-Agent/decision-aids.md` — **NEW** (Phase 2)
- `02-OnPrem2SPO-Agent/Migration-OD2OD-SPO09132024.txt` — **sanitized PowerShell source** (svc-migration / contoso.* / placeholder GUIDs). Upload as knowledge so the agent quotes the script verbatim instead of fabricating cmdlets.
- `02-OnPrem2SPO-Agent/Migration-SP2SPO09132024.txt` — **sanitized PowerShell source**. Same rationale.

**Topics:**
- `02-OnPrem2SPO-Agent/topics.md` — reference for human builder. Configure topics in the Copilot Studio UI per the build sheet. **Note Topic 8d updated** (AD runs by default), **Topic 12 added** (Why questions), **Topic 13 added** (Audience-aware patterns).

### What NOT to upload

- ❌ `system-prompt.md` (long-form) — use the trimmed `.txt` instead.
- ❌ Earlier untrimmed system prompts archived under `old/`.

### Settings

- **Generative answers:** ON, grounded on knowledge.
- **Connected agent (incoming):** Concierge.
- **Model:** Claude Sonnet 4.6.

---

## 3. H: Drive → OneDrive agent

### What to upload

**System prompt (paste into Instructions):**
- `03-HDrive-Agent/system-prompt-TRIMMED-8k.v2.txt` — v2 is canonical (paste this entire file, not the older `system-prompt-TRIMMED-8k.txt` which is now archived). Includes the **anti-fabrication clause**.

**Knowledge files (Agent → Knowledge → + Add):**
- `03-HDrive-Agent/knowledge-cards.md` — main reference (post-fix: Step 10 corrected; AD-group operations are ADD vs VALIDATE)
- `03-HDrive-Agent/workflows.md` — Mermaid diagrams (post-fix: AD section corrected)
- `03-HDrive-Agent/troubleshooting.md` — gotchas
- `03-HDrive-Agent/faq-plain-english.md` — **NEW** (Phase 2)
- `03-HDrive-Agent/user-experience-narrative.md` — **NEW** (Phase 2)
- `03-HDrive-Agent/decision-aids.md` — **NEW** (Phase 2)
- `03-HDrive-Agent/Hdrive-OneDriveScript081825a.txt` — **sanitized PowerShell source** (3,461 lines). Upload as knowledge so the agent quotes the script verbatim instead of fabricating cmdlets.

**Topics:**
- `03-HDrive-Agent/topics.md` — reference for human builder. **Topic 12 added** (Why questions), **Topic 13 added** (Audience-aware patterns).

### What NOT to upload

- ❌ `Old/system-prompt-TRIMMED-8k.txt` — stale; v2 supersedes it.
- ❌ `Old/system-prompt.md` — long-form reference; use v2 trimmed.

### Settings

- **Generative answers:** ON, grounded on knowledge.
- **Connected agent (incoming):** Concierge.
- **Model:** Claude Sonnet 4.6.

---

## 4. Common Drive → Teams / SPO agent

### What to upload

**System prompt (paste into Instructions):**
- `04-CommonDrive-Agent/system-prompt-TRIMMED-8k-FINAL.txt` — includes the `ClaimStaleHours = 2` fix and the **anti-fabrication clause**.

**Knowledge files (Agent → Knowledge → + Add):**
- `04-CommonDrive-Agent/knowledge-cards.md` — main reference (post-fix: ClaimStaleHours corrected throughout)
- `04-CommonDrive-Agent/workflows.md` — Mermaid diagrams (canonical)
- `04-CommonDrive-Agent/troubleshooting.md` — gotchas (post-fix: 2-hour window framing)
- `04-CommonDrive-Agent/command-reference.md` — switches and column reference (post-fix: ClaimStaleHours corrected)
- `04-CommonDrive-Agent/preflight.md` — pre-run checklist
- `04-CommonDrive-Agent/faq-plain-english.md` — **NEW** (Phase 2)
- `04-CommonDrive-Agent/user-experience-narrative.md` — **NEW** (Phase 2)
- `04-CommonDrive-Agent/decision-aids.md` — **NEW** (Phase 2)

**Sanitized PowerShell sources — curated set (recommended):**
The Common Drive folder has 11 sanitized .txt scripts (~12,000 lines). Uploading all 11 will degrade retrieval. Upload the three most-asked-about ones; leave the other 8 hosted on the website at https://douglasluvpup.github.io/cloud-migrate-pro/scripts.html and let the agent link out when asked.
- `04-CommonDrive-Agent/CommonDriveMigration.v2.txt` — main orchestrator (4,865 lines). Most asked about.
- `04-CommonDrive-Agent/SPMT-Worker.v2.txt` — SPMT runner (173 lines).
- `04-CommonDrive-Agent/Update-MigrationTargets.v2.txt` — SCA pre-grant + Phase 1/2 (1,030 lines).

If the demo audience routinely asks about dashboards, retry, intake, or the documentation pipeline, upload those scripts too — but each addition costs retrieval quality.

**Topics:**
- `04-CommonDrive-Agent/topics.md` — reference for human builder. **Topic 16 added** (Why questions), **Topic 17 added** (Audience-aware patterns).

### What NOT to upload

- ❌ The other 8 Common Drive scripts (Deploy-SystemDocumentation, Import-MigrationSources, Invoke-UNCStorageScan-v2, New-MigrationDashboard, New-MigrationLandingPage, New-MigrationUserManualPage-Simple, New-SystemDocumentationPage, Retry-FailedMigration) — host on the website only.
- ❌ `system-prompt-TRIMMED-8k.txt` (older version) — use the `-FINAL` variant.
- ❌ `system-prompt.md` (long-form) — use the trimmed final.

### Settings

- **Generative answers:** ON, grounded on knowledge.
- **Connected agent (incoming):** Concierge.
- **Model:** Claude Sonnet 4.6.

---

## Re-upload checklist (after this audit)

For each agent:

1. **Replace the system prompt** (paste new content over old).
2. **Remove old knowledge files** that have been superseded:
   - On Concierge: remove `demo-script.md`, `marketing-onepager.md`, `roi-worksheet.md`, `evaluate-test-prompts.md`, `topics.md` if they were uploaded previously.
3. **Re-upload the corrected knowledge files** (knowledge-cardsv2 / knowledge-cards / workflows / troubleshooting / command-reference / preflight). They were edited during Phase 1.
4. **Upload the three new conversational files** to each specialist:
   - `faq-plain-english.md`
   - `user-experience-narrative.md`
   - `decision-aids.md`
5. **Update topics in the Copilot Studio UI** to reflect the changes flagged in the topics.md changelog at the bottom of this guide.
6. **Test** by asking each specialist:
   - "Why does the script do X?" (validates new "Why" topic)
   - "Give me an executive summary I can email" (validates Audience-aware topic)
   - A scripted operator question (validates the existing fact knowledge still works)

---

## Topics changelog (for the human builder updating Copilot Studio UI)

### Concierge
- Sharpened Q1 phrasing in routing question (per-user vs shared file share clarifier)
- Out-of-scope topic: explicit refusal of cross-tenant + SP 2013 (already in system prompt; mirror in topics if you have a dedicated out-of-scope topic node)

### OnPrem → SPO
- **Topic 8d** corrected: "AD Updates (RUNS by default)" — change the topic description in the UI accordingly
- **Topic 12 added:** "'Why' questions"
- **Topic 13 added:** "Audience-aware patterns"

### H: Drive
- **Topic 12 added:** "'Why' questions"
- **Topic 13 added:** "Audience-aware patterns"

### Common Drive
- **Topic 16 added:** "'Why' questions"
- **Topic 17 added:** "Audience-aware patterns"

---

## Files that stay in the repo but DO NOT upload to any agent

These are operator-facing reference materials, not agent knowledge:

- `01-Concierge/demo-script.md`, `marketing-onepager.md`, `roi-worksheet.md`, `evaluate-test-prompts.md`, `welcome-card.json`
- The 8 Common Drive scripts that aren't in the curated set (see Common Drive section above) — hosted on https://douglasluvpup.github.io/cloud-migrate-pro/scripts.html instead
- `system-prompt.md` long-form versions (the trimmed `.txt` is what fits the agent)
- All `topics.md` files (reference for the builder; the actual topics live in Copilot Studio UI)
- Anything under `old/` or `Old/` subfolders (archived prior versions)

---

## Verification: post-upload smoke test prompts

Run these against each agent after re-upload:

| Agent | Prompt | Expected behavior |
|---|---|---|
| Concierge | "I have a SharePoint 2013 site to migrate" | Reframe to content (we migrate content, not site structure). Note SP 2013 is out of scope for this orchestration but **SPMT supports SP 2013** sources. Recommend SPMT standalone OR upgrade-then-migrate. Must NOT say "feature gaps" or push third-party GUI tools as the only option. |
| Concierge | "I want to migrate OneDrive across tenants" | Refuse politely, name Microsoft Cross-Tenant or BitTitan |
| Concierge | "Move our file share to SharePoint" | Ask the per-user vs shared clarifier from sharpened Q1 |
| OnPrem | "Does the AD block run by default?" | "Yes — runs by default. The `#<#` markers are single-line comments because of the leading `#`." |
| OnPrem | "Where does the SCA swap happen?" | "On the **source** on-prem MySite (`$sourceUrl` with `$OnPremCredential`), not the new SPO OneDrive." |
| OnPrem | "How long between rows?" | "OD2OD pauses 30 seconds; SP2SPO pauses 120 seconds." |
| OnPrem | "What value triggers a row?" | "`Migrate = \"Migrate\"` (literal string). Not 'Ready'." |
| H: Drive | "Does the script add users to license groups?" | "It ADDS to `SecFltr-USR-Office365`. It only VALIDATES `O365S-AddOn-License` (license-group membership is governed by the identity team)." |
| H: Drive | "Why a separate process for ACL changes?" | (Why-question topic answers from rationale knowledge) |
| Common Drive | "What's ClaimStaleHours default?" | "2 hours, not 24." |
| Common Drive | "Phase 1 vs Phase 2 — when does each run?" | Phase 1 interactive (delegated Graph); Phase 2 automated (app-only). Flow B skips Phase 1. |
| Common Drive | "Give me an end-user announcement for cutover complete" | (Audience-aware topic produces a draft from `user-experience-narrative.md`) |
| **Hallucination guard — OnPrem** | "Show me Migration-SP2SPO09132024.ps1" | Quotes verbatim from uploaded knowledge OR refuses with link to https://douglasluvpup.github.io/cloud-migrate-pro/scripts.html. Must NOT fabricate cmdlets like `New-SPMTMigrationTask` (real cmdlet is `Add-SPMTTask`). Filename should be plain (no parens). |
| **Hallucination guard — OnPrem** | "Show me the OD2OD post-migration AD block" | Quotes verbatim from the uploaded source (lines around the `#<#` markers). Must NOT paraphrase or reconstruct from memory. |
| **Hallucination guard — H: Drive** | "Show me the SCA02/SCA03 add logic" | Quotes verbatim from `Hdrive-OneDriveScript081825a.txt`. If the section isn't found, says so and links scripts.html. |
| **Hallucination guard — Common Drive** | "Show me the storage auto-downgrade code" | Quotes verbatim from `CommonDriveMigration.v2.txt` (or `Update-MigrationTargets.v2.txt`). Must NOT invent a `Get-StorageHorizon` cmdlet or similar. |
| **Hallucination guard — Concierge** | "Show me the script that does X" | Does NOT generate any PowerShell. Routes to the specialist AND links scripts.html. |

If any of these fail, the corresponding knowledge file probably didn't upload — re-check.
