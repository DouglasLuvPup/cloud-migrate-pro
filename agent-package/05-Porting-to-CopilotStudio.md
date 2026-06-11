# Porting the Package into Copilot Studio (current UI)

> **Package version:** 1.0 (June 2026)

This guide reflects the **current Copilot Studio UI** (Build / Preview /
Evaluate / Monitor tabs, right-rail with Skills / Tools / Knowledge /
Connected agents, single Instructions box, no separate Topics tab).

You will build **4 agents**:

| # | Agent | Source files in this package |
|---|---|---|
| 1 | On-Prem to SPO Migration | `02-OnPrem2SPO-Agent/` |
| 2 | H: Drive Migration | `03-HDrive-Agent/` |
| 3 | Common Drive Migration | `04-CommonDrive-Agent/` |
| 4 | Cloud Migrate Pro Concierge (router) | `01-Concierge/` |

**Build the 3 child agents first, then the Concierge** so you can wire the
children in as Connected agents.

---

## 0. One-time prep (do this ONCE before building any agent)

Everything in this section is done **one time, up front**. You will not
repeat it per agent.

1. Open **Copilot Studio** → top-left environment picker → confirm the right
   tenant/environment.
2. Decide on a model. **Claude Sonnet 4.6** is recommended (good at long
   instructions + PowerShell). You'll pick this from the model picker
   (top-right of each agent page) when you create each agent — but the
   choice is the same for all 4. Decide now so you're consistent.
3. **Stage and rename all 3 script folders right now**, before building any
   agent. Don't do this mid-build — it breaks your flow.

   | Folder | Goes to (one agent only, do not mix) |
   |---|---|
   | `CopilotStudio-scripts-4agent/OnPrem2SPO2024/` | On-Prem to SPO Migration |
   | `CopilotStudio-scripts-4agent/HDrive2025/` | H: Drive Migration |
   | `CopilotStudio-scripts-4agent/CommonDrive2026/` | Common Drive Migration |

   The Concierge gets **no** Knowledge files at all.

   > **Heads-up:** Copilot Studio Knowledge does not accept `.ps1`. Make a
   > **copy** of each folder, rename every `.ps1` in the copy to `.txt`
   > (content unchanged), and keep the originals untouched. The silo
   > separation is what keeps the agents from cross-contaminating — never
   > upload a script from one folder into a different agent.

   Easy PowerShell to do all three folder renames in one shot:

   ```powershell
   cd "C:\Users\docox\OneDrive - Microsoft\01-VSCworkspace\CopilotStudio-scripts-4agent"
   foreach ($folder in 'OnPrem2SPO2024','HDrive2025','CommonDrive2026') {
       $src = ".\$folder"
       $dst = ".\$folder-forUpload"
       Copy-Item $src $dst -Recurse -Force
       Get-ChildItem $dst -Recurse -Filter *.ps1 |
           Rename-Item -NewName { $_.Name -replace '\.ps1$','.txt' }
       Write-Host "Prepared: $dst"
   }
   ```

   After this runs, you have three `*-forUpload` folders with `.txt` copies
   ready to drag into Knowledge. Originals untouched.

4. Have this package open in VS Code or File Explorer so you can grab
   `system-prompt.md` / `knowledge-cards.md` / etc. quickly during the
   per-agent steps below.

---

## 1. Build a child agent (repeat 3×)

Do this once per scenario. The pattern is identical; only the source
files differ.

### 1a. Create the agent

1. Top-left environment picker → **Agents** → **+ New agent**.
2. Skip the "describe your agent" chat → click **Skip to configure** (or
   "Configure" — the button label moves).
3. **Name** field: use the matching name from the table above.
4. **Icon:** skip for now. We'll add icons after everything works.

### 1b. Paste Instructions

The right-side panel has one big **Instructions** box. There is no longer a
separate Description field.

1. Open the matching `system-prompt.md` from this package
   (e.g. `02-OnPrem2SPO-Agent/system-prompt.md`).
2. Copy **everything inside the code fence** (between the triple backticks).
3. Paste into the Instructions box.
4. Save (top-right **Save** button, or it auto-saves).

> The first paragraph of the prompt doubles as the agent's "description" —
> the new UI surfaces it that way in the agent list.

### 1c. Add Knowledge

Right rail → **Knowledge** → **+ Add knowledge** → **Upload files**.

Upload **all** of the following for that agent. Rename every `.ps1` to
`.txt` first (Copilot Studio Knowledge rejects `.ps1`).

| Agent | Upload |
|---|---|
| On-Prem to SPO | All scripts from `OnPrem2SPO2024/` renamed to `.txt` + `02-OnPrem2SPO-Agent/workflows.md` + `02-OnPrem2SPO-Agent/knowledge-cards.md` + `command-reference.md` + `troubleshooting.md` + `preflight.md` |
| H: Drive | The script from `HDrive2025/` renamed to `.txt` + `03-HDrive-Agent/workflows.md` + `03-HDrive-Agent/knowledge-cards.md` + `command-reference.md` + `troubleshooting.md` + `preflight.md` |
| Common Drive | All 11 scripts from `CommonDrive2026/` renamed to `.txt` + `04-CommonDrive-Agent/workflows.md` + `04-CommonDrive-Agent/knowledge-cards.md` + `command-reference.md` + `troubleshooting.md` + `preflight.md` |

> **Why upload the `.txt`-renamed `.ps1` files at all?** So the agent can quote exact script lines, parameter blocks, and behaviors instead of paraphrasing. Without the scripts uploaded, the agent only knows what the cards say. **The script files are the source of truth; the cards are the index.**

After upload, wait for the status column to show **Ready** (indexing takes a
minute or two per file).

### 1d. Skip Skills / Tools / Connected agents

For child agents you do **not** need Skills, Tools, or Connected agents.
Leave those empty. The Instructions + Knowledge combo is the whole agent.

### 1e. Verify with Preview

1. Top tab → **Preview**.
2. Ask 2–3 questions from the matching `topics.md` trigger phrases — e.g.
   for On-Prem to SPO: *"how do I run an OD2OD migration?"*
3. Confirm:
   - It cites the right script names.
   - It does **not** mention scripts from the other scenarios.
   - It refuses out-of-scope questions (e.g. ask the H: Drive agent about
     Common Drive — it should bounce you back to the Concierge).

If it leaks across scenarios, re-check that you uploaded **only** the
matching script folder.

### 1f. Repeat 1a–1e for the other two child agents.

---

## 2. Build the Concierge (router)

### 2a. Create

Same as 1a, name it **Cloud Migrate Pro Concierge**.

### 2b. Instructions

Paste the contents of `01-Concierge/system-prompt.md` into the Instructions
box.

### 2c. Knowledge

**Leave empty.** The Concierge does not answer technical questions; it only
routes. Knowledge would tempt it to over-explain.

### 2d. Connected agents (this is the routing wiring)

Right rail → **Connected agents** → **+ Add**.

Add each of the 3 child agents you just built:

1. **On-Prem to SPO Migration**
   - "When to use" text: *Use when the user describes migrating on-premises
     SharePoint or on-premises OneDrive (MySite) to SharePoint Online or SPO
     OneDrive. Sub-flows: OD2OD and SP2SPO.*
2. **H: Drive Migration**
   - "When to use": *Use when the user describes migrating an individual's
     network home drive (H: drive, UNC `\\server\users\<sam>`) to their SPO
     OneDrive.*
3. **Common Drive Migration**
   - "When to use": *Use when the user describes migrating UNC shared/common
     drives (`\\server\share\<unit>\Common\...`) into SharePoint Online,
     either as a Teams channel folder (Flow A) or a straight SPO site (Flow
     B).*

### 2e. Welcome message & Conversation Starters (recommended)

The new UI lets you set a starter message **plus suggested-prompt chips**
("Conversation Starters") that appear under the welcome bubble.

1. **Agent Icon (branding)** — in **Overview → Details**, click the icon
   placeholder and upload `assets/cloud-migrate-pro-logo.png`. Microsoft
   hosts the icon for you and shows it next to every message in Teams /
   M365 Chat. This is where your branding lives — *not* in the welcome
   card. (The welcome card is intentionally text-only and theme-neutral
   so it renders correctly in both light and dark mode regardless of the
   user's host client.)
2. **Overview / Description / Welcome message** — paste the text from the
   main TextBlock in `01-Concierge/welcome-card.json` (or the opening
   paragraph of `system-prompt.md`).
3. **Conversation Starters** — in the Overview tab look for the
   "Conversation Starters" or "Suggested prompts" section. Add these chips
   (one per line, max 4 typically):
   - `Show me the OD2OD flow`
   - `What's -MigrationType MigrateOnly?`
   - `Why this over ShareGate?`
   - `Help me decide`

   These are the prompts that will demo well. Pick the 4 that match your
   audience.

4. The full Adaptive Card in `welcome-card.json` is for richer welcome
   experiences if your channel renders Adaptive Cards (Teams does).
   Put it in a Message node in topic 1 "Conversation Start" if you want
   the card-based welcome.

### 2f. Verify with Preview

1. **Preview** tab.
2. Try each of:
   - *"I need to migrate an on-prem SharePoint site to SPO."* → should
     hand off to On-Prem to SPO.
   - *"User's H drive needs to go to OneDrive."* → H: Drive agent.
   - *"We have a common drive that needs to land in a Teams channel."* →
     Common Drive agent.
3. Confirm the Concierge does **not** itself answer the technical questions
   — it should silently route, and the answer should come from the matching
   child.

---

## 3. Publish to Teams + Microsoft 365

1. Top-right **Publish** on the Concierge (only publish the Concierge — the
   children are reached via Connected agents).
2. In the channel list, enable **Microsoft Teams and Microsoft 365 Copilot**
   (this is a single combined channel in the current UI; it replaces the old
   separate Teams channel).
3. Click **Publish**. Wait for the green check.
4. Go to **Microsoft 365 admin center → Integrated apps** (or **Teams admin
   center → Manage apps**, depending on your tenant).
5. Find the Cloud Migrate Pro Concierge app → **Allow** for the right CSA group
   (or org-wide, your call).
6. In Teams, **Apps** → search "Cloud Migrate Pro Concierge" → **Add**.

---

## 4. (Optional, later) Polish pass

Do these only **after** the agents are working end-to-end.

| Want | Where |
|---|---|
| Custom icons per agent | Agent header → small image next to the name → upload |
| Auth gating (only CSAs can use) | Top **Settings** → **Security** → **Authenticate manually** / Entra |
| Email the right script after handoff | Right rail → **Tools** → **+ Add tool** → Power Automate flow → `Send email` |
| Web channel for a demo site | **Channels** → Demo Website / Web app |
| Analytics | Top tab → **Monitor** (sessions, top topics, escalations) |
| Eval harness | Top tab → **Evaluate** — paste rows from `01-Concierge/evaluate-test-prompts.md` |
| Live demo run-order | Open `01-Concierge/demo-script.md` in a private window before going on camera |

---

## 5. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Concierge answers a technical question itself | Instructions weren't pasted, or Knowledge was added to it | Re-paste prompt; remove any Knowledge files from the Concierge |
| Child leaks advice from another scenario | Wrong scripts uploaded to its Knowledge | Remove and re-upload only the matching folder |
| Connected agent doesn't get triggered | "When to use" text is vague | Make it more specific; include unique keywords (`MySite`, `H:`, `Common`) |
| Knowledge upload rejected | `.ps1` is not a supported type | Rename the copy to `.txt` and re-upload. Supported types include `.txt`, `.md`, `.pdf`, `.docx`, `.html`, `.xlsx`, `.pptx` |
| Indexing stuck on Knowledge | One file too large | Remove the file; split or shrink; re-upload |
| Publish to Teams greyed out | Need to publish to "Microsoft Teams and Microsoft 365 Copilot" channel first | Enable that channel in the Channels list |
| Model picker missing Claude Sonnet 4.6 | Tenant policy or region | Use the highest-tier GPT model available; behavior is similar with these prompts |

---

## File-by-file checklist (what goes where)

| File in this package | Goes into |
|---|---|
| `01-Concierge/system-prompt.md` | Concierge → Instructions |
| `01-Concierge/topics.md` | Reference only (don't upload) |
| `01-Concierge/welcome-card.json` | Reference for welcome / starter prompts |
| `01-Concierge/demo-script.md` | Reference only (operator playbook for live demos) |
| `01-Concierge/evaluate-test-prompts.md` | Paste into Evaluate tab as regression tests |
| `01-Concierge/marketing-onepager.md` | Reference only (exec / leadership artifact — fill placeholders before sharing) |
| `01-Concierge/battlecards.md` | Reference only (peer / sales enablement — fill placeholders before customer-facing use) |
| `01-Concierge/roi-worksheet.md` | Reference only (build-vs-buy framing tool — requires live vendor RFQ as input) |
| `02-OnPrem2SPO-Agent/system-prompt.md` | OnPrem agent → Instructions |
| `02-OnPrem2SPO-Agent/workflows.md` | OnPrem agent → Knowledge |
| `02-OnPrem2SPO-Agent/knowledge-cards.md` | OnPrem agent → Knowledge |
| `02-OnPrem2SPO-Agent/command-reference.md` | OnPrem agent → Knowledge |
| `02-OnPrem2SPO-Agent/troubleshooting.md` | OnPrem agent → Knowledge |
| `02-OnPrem2SPO-Agent/preflight.md` | OnPrem agent → Knowledge |
| `02-OnPrem2SPO-Agent/topics.md` | Reference only |
| `03-HDrive-Agent/system-prompt.md` | HDrive agent → Instructions |
| `03-HDrive-Agent/workflows.md` | HDrive agent → Knowledge |
| `03-HDrive-Agent/knowledge-cards.md` | HDrive agent → Knowledge |
| `03-HDrive-Agent/command-reference.md` | HDrive agent → Knowledge |
| `03-HDrive-Agent/troubleshooting.md` | HDrive agent → Knowledge |
| `03-HDrive-Agent/preflight.md` | HDrive agent → Knowledge |
| `03-HDrive-Agent/topics.md` | Reference only |
| `04-CommonDrive-Agent/system-prompt.md` | CommonDrive agent → Instructions |
| `04-CommonDrive-Agent/workflows.md` | CommonDrive agent → Knowledge |
| `04-CommonDrive-Agent/knowledge-cards.md` | CommonDrive agent → Knowledge |
| `04-CommonDrive-Agent/command-reference.md` | CommonDrive agent → Knowledge |
| `04-CommonDrive-Agent/troubleshooting.md` | CommonDrive agent → Knowledge |
| `04-CommonDrive-Agent/preflight.md` | CommonDrive agent → Knowledge |
| `04-CommonDrive-Agent/topics.md` | Reference only |
| `CopilotStudio-scripts-4agent/OnPrem2SPO2024/*.ps1` → rename copies to `.txt` | OnPrem agent → Knowledge |
| `CopilotStudio-scripts-4agent/HDrive2025/*.ps1` → rename copy to `.txt` | HDrive agent → Knowledge |
| `CopilotStudio-scripts-4agent/CommonDrive2026/*.ps1` → rename copies to `.txt` | CommonDrive agent → Knowledge |

`topics.md` files are not uploaded — they're a human reference for the
prompts you'll use to verify each agent in Preview.
