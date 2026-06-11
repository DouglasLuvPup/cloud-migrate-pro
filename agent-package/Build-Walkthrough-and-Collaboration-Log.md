<p align="center">
  <img src="assets/cloud-migrate-pro-logo.png" alt="Cloud Migrate Pro" width="180" />
</p>

# Cloud Migrate Pro — Build Walkthrough & Collaboration Log

> **What this document is.** A plain-language record of *what we actually did*
> to turn three PowerShell migration playbooks into a working multi-agent
> assistant in Microsoft Copilot Studio: the files each agent uses and **why**,
> every setting we changed, the **back-and-forth between Doug (human) and GitHub
> Copilot in VS Code (AI pair)**, and an honest **time estimate** for each phase.
>
> **Companion docs:** `Cloud-Migrate-Pro-Agent-How-We-Built-It.md` (the design
> case study / *why it's shaped this way*) and `05-Porting-to-CopilotStudio.md`
> (the click-by-click import steps). This file is the *journey + inventory*.

---

## 1. The 60-second summary

We built a **two-tier agent**: one **Concierge** that does nothing but figure
out which of three migrations you're doing and hand you to the right
**specialist**. Each specialist owns one scenario and its own knowledge.

```
                ┌───────────────────────────────────────┐
                │   Cloud Migrate Pro Concierge         │
                │   router · no knowledge · routes only │
                └───────────────────────────────────────┘
                               │  hands off to
        ┌──────────────────────┼───────────────────────┐
        │                      │                       │
 ┌──────────────┐      ┌──────────────┐       ┌──────────────────┐
 │ On-Prem SP → │      │ H: Drive →   │       │ Common Drive →   │
 │ SPO Guide    │      │ OneDrive     │       │ Teams/SharePoint │
 └──────────────┘      └──────────────┘       └──────────────────┘
   2024 playbook         2025 playbook           2026 playbook
```

- **Platform:** Microsoft Copilot Studio (Power Platform).
- **Model:** Claude Sonnet 4.6 on all four agents.
- **How it was authored:** entirely through the Copilot Studio web UI, with
  all the *source material* (system prompts, knowledge files, adaptive cards,
  topic YAML) drafted and version-controlled in **VS Code with GitHub Copilot**.

---

## 2. The four agents and the files each one uses

Everything lives under `CopilotStudio-AgentPackage/`. Each agent has its own
folder. The pattern is identical across all three specialists, which is the
whole point — a repeatable template.

### 2.1 Concierge (router) — `01-Concierge/`

The front door. It carries **no knowledge files** on purpose (a router that
reads documents starts answering questions it should be routing).

| File | What it is | Why it exists |
|------|-----------|---------------|
| `system-prompt.md` | The full router instructions (the "brain"). | Defines the one job: identify the scenario, ask up to 3 qualifying questions, hand off. Also holds the vendor-positioning answers (ShareGate/AvePoint/Quest/BitTitan) and sovereign-cloud talking points. |
| `system-prompt-TRIMMED-8k.txt` | A ~7,950-char version of the prompt. | Copilot Studio's Instructions field **hard-caps at 8,000 characters**. The full prompt is longer, so we trimmed a faithful copy that fits. |
| `welcome-card.json` | An Adaptive Card greeting with 3 tappable scenario tiles + Help/Positioning/About buttons. | Gives users a click-to-route first screen instead of a wall of text. |
| `topics.md` / `topics-yaml/01-Concierge.topics.yaml` | The conversation topics (Greeting, routing, About, Goodbye). | Drives the deterministic routing and the greeting. |
| `battlecards.md`, `demo-script.md`, `marketing-onepager.md`, `roi-worksheet.md`, `evaluate-test-prompts.md` | Sales/demo/test collateral. | Not loaded into the agent — these are for the human running the demo and for QA test prompts. |

### 2.2 Specialist pattern (shared by all three)

Each specialist folder (`02-OnPrem2SPO-Agent/`, `03-HDrive-Agent/`,
`04-CommonDrive-Agent/`) follows the same recipe:

| File | Role | Why it matters |
|------|------|---------------|
| `system-prompt.md` | Full specialist instructions. | Scenario-specific persona, scope, and refusal rules ("don't advise across silos"). |
| `system-prompt-TRIMMED-8k.txt` | <8,000-char instructions actually pasted into Copilot Studio. | Same 8k cap workaround as the Concierge. |
| `preflight.md` | Pre-migration checklist knowledge. | What to verify before running anything. |
| `workflows.md` | Step-by-step migration workflow + Mermaid diagrams. | Lets the agent show the exact process as a flowchart on request. |
| `knowledge-cards.md` / `knowledge-cardsv2.md` | Q&A "cards" — endpoints, GCC/GCC-H/DoD swaps, positioning. | The grounding that makes answers concrete instead of generic. |
| `command-reference.md` | The actual script commands/parameters. | So the agent can explain (never execute) the real commands. |
| `troubleshooting.md` | Known errors and fixes. | Turns the agent into a support colleague, not just a doc reader. |
| `*.txt` / `*.ps1` scripts | The real PowerShell playbooks (sanitized). | The source of truth the knowledge files describe. |

**Per-agent specifics:**

- **On-Prem → SPO** (`02-OnPrem2SPO-Agent/`): 7 knowledge files + two migration
  scripts (`Migration-SP2SPO…txt`, `Migration-OD2OD…txt`). Covers SharePoint
  2016/2019 sites *and* MySites/OneDrive.
- **H: Drive → OneDrive** (`03-HDrive-Agent/`): 6 knowledge files + the home-drive
  script (`Hdrive-OneDriveScript081825a.txt`). Note there are two trimmed prompt
  versions (`…TRIMMED-8k.txt` and `…v2.txt`) from iterating under the 8k cap.
- **Common Drive → Teams/SharePoint** (`04-CommonDrive-Agent/`): the richest one —
  knowledge files **plus ~11 PowerShell scripts** (the full toolkit:
  `CommonDriveMigration.v2`, `SPMT-Worker.v2`, `Invoke-UNCStorageScan-v2`,
  dashboard/landing-page/manual builders, `Retry-FailedMigration`,
  `Import-MigrationSources`, `Update-MigrationTargets`, etc.). This scenario has
  the storage auto-downgrade, multi-server claim-locking, and Teams
  auto-provisioning logic, so it needed the most grounding.

---

## 3. The settings we configured (and what each does)

These are the Copilot Studio toggles that make the suite behave correctly.

| Setting | Concierge | Specialists | Why |
|---------|-----------|-------------|-----|
| **Model** | Claude Sonnet 4.6 | Claude Sonnet 4.6 | Consistent reasoning quality across the suite. |
| **Knowledge** | None | One silo each | Keeps the router from answering, and stops cross-scenario contamination. |
| **Generative answers (general knowledge)** | Off | On | Router only routes; specialists reason over their own knowledge. |
| **Connected agents** | 3 specialists attached | n/a | This is the handoff wiring — the Concierge lists the three as connected agents. |
| **Authentication** | **No authentication** | **No authentication** | Required for the open external/demo link. *All four must match* (see §5). |
| **Topics** | Greeting + routing + About/Goodbye | Greeting/scope | Deterministic first screen and routing. |
| **Suggested prompts** | "Where do I start?", "Explain my options simply", "Help me pick", "Why not just buy a tool?" | scenario-specific | Lowers the blank-page barrier for users. |
| **Publish** | After every change | After every change | Nothing goes live until you publish — this bit us more than once (§5). |

---

## 4. How Doug + Copilot actually worked together

This was a genuine pair-programming loop, not a one-shot prompt. Two distinct
roles:

**Doug (human) owned:**
- The domain truth — the real migration playbooks, which scenario maps to which
  script, the GCC/GCC-H/DoD realities, the honest vendor tradeoffs.
- Direction and judgment calls ("trim to under 8k rather than split the prompt",
  "set everything to No auth for the demo", "stop here for now").
- Anything that needed a real human in the tenant: signing in, clicking through
  consent, eyeballing whether the published bot *felt* right.

**GitHub Copilot (AI) owned:**
- Drafting and rewriting the four system prompts, knowledge cards, troubleshooting
  guides, workflows (with Mermaid), the adaptive welcome card JSON, and the topic
  YAML — all in VS Code.
- The fiddly mechanical work: counting characters against the 8,000 cap and
  trimming faithfully, keeping the four prompts structurally parallel, generating
  the import guide and launch kit.
- Driving the Copilot Studio web UI through browser automation — setting
  authentication, publishing, and running end-to-end test conversations — then
  reading back the results and diagnosing failures.

**The loop looked like this, repeatedly:**
1. Doug describes the goal or a problem in plain language.
2. Copilot drafts the file / makes the config change / runs the test.
3. Copilot reports what happened (including failures, verbatim).
4. Doug corrects course or approves.
5. Commit / publish, then next item.

The honest parts worth remembering: several rounds were spent **fighting the
platform, not the content** — the 8,000-char Instructions cap, an Instructions
editor that wouldn't accept typed input (solved by injecting state directly into
its Lexical editor), a model picker that wouldn't load during a backend
degradation, and the connected-agent authentication mismatch. Those are
documented so the next build skips them.

---

## 5. The gotchas that cost us real time

1. **The 8,000-character Instructions cap.** Full prompts are longer; every agent
   needed a trimmed-but-faithful copy. *Lesson: write the prompt, then budget it.*
2. **The Instructions editor rejects typed/pasted text.** It's a read-only-looking
   Lexical editor; the working method was to inject editor state programmatically.
3. **Publish is not optional.** Auth and instruction changes do nothing for end
   users until you **Publish** the agent. We re-learned this each time.
4. **Connected-agent auth must match.** When the Concierge is *No authentication*
   but a connected specialist still requires sign-in, the handoff fails with
   **`ConnectedAgentAuthMismatch`** for anonymous users. Fix: set **all four**
   agents to No auth *and re-publish the Concierge* so it refreshes its manifest.
   *(Status as of this writing: all four set to No auth and re-published; the
   anonymous handoff was still returning the mismatch on last test — open item to
   confirm once the change fully propagates.)*
5. **Environment flakiness.** The tenant was slow (~50–60s page loads) with
   constant console errors during a backend degradation window; some authoring
   (the model picker) simply couldn't be done until it recovered.

---

## 6. The VS Code + GitHub Copilot angle

Copilot Studio is the *runtime*, but the **engineering happened in VS Code**:

- **Single source of truth in the repo.** Every prompt, knowledge file, card,
  and script lives as a versioned text file in `CopilotStudio-AgentPackage/`.
  That means diffs, history, and the ability to regenerate the agents from
  scratch — the Copilot Studio UI has none of that.
- **Copilot as the drafting + automation engine.** GitHub Copilot Chat (agent
  mode) authored and refactored the content, kept the four prompts parallel,
  enforced the character budget, and even drove the browser to configure and
  test the live agents.
- **A `_scrub.ps1` sanitizer** keeps tenant-specific values (hostnames, GUIDs,
  emails) out of the shared package, so the whole thing is safe to hand to
  another CSA.
- **Solution packaging** (`CloudMigratePro_2_0_0_0.zip`) for moving the work
  between environments.

The takeaway: treat agent content like code. Author and review it in VS Code
with Copilot, keep it in source control, and use the Copilot Studio UI only as
the deployment target.

---

## 7. Honest time estimate

These are *effort* estimates for a build like this, assuming the source
playbooks already exist (they did) and one CSA pairing with Copilot. Ranges, not
promises — a lot depends on how cooperative the tenant is on the day.

| Phase | What it covers | Estimate |
|-------|----------------|----------|
| **Discovery & shape** | Deciding router-vs-mega-agent, mapping 3 scenarios, naming | 2–3 hrs |
| **Content authoring** | 4 system prompts + ~25 knowledge files + welcome card + topics (Copilot-drafted, human-reviewed) | 6–10 hrs |
| **8k trimming & parallelizing** | Fitting every prompt under the cap, keeping them consistent | 2–4 hrs |
| **Environment & import** | Creating agents, attaching knowledge, wiring connected agents, model selection | 3–5 hrs |
| **Settings & publishing** | Auth, generative-answers toggles, suggested prompts, publish cycles | 1–2 hrs |
| **Testing & debugging** | End-to-end routing tests + chasing the gotchas in §5 | 3–6 hrs |
| **Packaging & docs** | README, launch kit, this walkthrough, sanitizer, solution zip | 3–5 hrs |
| **— Total** | | **~20–35 hrs** |

A meaningful chunk of that total was **platform friction** (the 8k cap, the
editor, auth, environment slowness), not creative work. A second build of the
same shape — now that the gotchas are documented — would land near the bottom
of that range.

---

## 8. Reuse checklist (for the next agent like this)

- [ ] Draft the full system prompt first; **then** trim a faithful <8,000-char copy.
- [ ] One knowledge silo per scenario; router carries **no** knowledge.
- [ ] Router: generative answers **off**. Specialists: **on**.
- [ ] Set authentication consistently across **parent and all connected agents**.
- [ ] **Publish** after every auth/instruction change.
- [ ] Keep all content in VS Code under source control; use Copilot to draft,
      parallelize, and budget characters.
- [ ] Sanitize tenant-specific values before sharing.
