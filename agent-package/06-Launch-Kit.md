# Launch Kit — Cloud Migrate Pro Concierge

Everything you need to introduce the Cloud Migrate Pro Concierge to other CSAs.

---

## 1. Teams announcement post

> 🚀 **Introducing the Cloud Migrate Pro Concierge**
>
> Tired of stitching together SPMT scripts from chat threads and OneNote
> pages? Same. So I packaged three field-tested migration playbooks behind
> a single Teams agent.
>
> **Pick your scenario — the Concierge routes you to a specialist agent
> that only knows that scenario.** No cross-wired advice. No hallucinated
> parameters. Just the right answer, from the right script.
>
> 🏢 **On-Prem SharePoint / OneDrive → SPO** (2024 playbook)
> 🏠 **H: Drive → OneDrive** (2025 playbook)
> 📁 **Common Drive → SPO Sites or Teams Channels** (2026 playbook)
>
> Each playbook ships with discovery, migration, retry, dashboard, and
> landing-page tooling — all sanitized templates ready for your tenant.
>
> 👉 **Add to Teams:** [paste deep link from Copilot Studio]
> 👉 **2-min demo:** [Stream link]
> 👉 **Questions / feedback:** [your DM / channel]
>
> — Doug

---

## 2. 2-minute demo script

Record in Stream or Loom. Aim for **under 2 minutes**.

**Scene 1 — The problem (15s)**
- *Voice:* "Every CSA I know has a OneNote page full of migration scripts.
  Different scenarios, different parameters, easy to mix up."

**Scene 2 — The Concierge welcome card (20s)**
- Open Cloud Migrate Pro Concierge in Teams.
- *Voice:* "Three playbooks, one front door. Pick your scenario."
- Hover over the three tiles; click **Common Drive**.

**Scene 3 — Sub-routing (15s)**
- Child agent asks: Teams channel or SPO site?
- Click **Teams channel**.

**Scene 4 — Real answer (40s)**
- Ask: *"What does Update-MigrationTargets do?"*
- Agent responds with grounded answer + cites the script.
- Ask: *"show me the workflow"* → Mermaid diagram renders.
- Ask: *"give me a sample call"* → fenced PowerShell appears.

**Scene 5 — Out-of-scope guardrail (15s)**
- Ask: *"How do I migrate mailboxes?"*
- Agent refuses; offers to return to Concierge.

**Scene 6 — Close (15s)**
- *Voice:* "Sanitized templates, scenario-isolated agents, zero
  hallucinations. Add to Teams. Ship migrations."

---

## 3. Quick-reference card (PDF outline)

One page, landscape. Print or share as PDF.

```
┌─────────────────────────────────────────────────────────────┐
│  🛫 Cloud Migrate Pro Concierge — QUICK REFERENCE                   │
│  Three playbooks. One front door.                           │
├─────────────────────────────────────────────────────────────┤
│  🏢 ON-PREM → SPO (2024)                                    │
│  Use when: source is SharePoint Server or on-prem MySites   │
│  Targets:  SPO sites OR SPO OneDrive                        │
│  Scripts:  Migration-SP2SPO, Migration-OD2OD-SPO            │
│                                                             │
│  🏠 H: DRIVE → ONEDRIVE (2025)                              │
│  Use when: source is a UNC home folder (\\srv\users\sam)    │
│  Target:   the user's SPO OneDrive /Documents/HDrive        │
│  Script:   Hdrive-OneDriveScript                            │
│                                                             │
│  📁 COMMON DRIVE → SPO (2026)                               │
│  Use when: source is a UNC shared/common drive              │
│  Targets:  Teams channel folder OR straight SPO site        │
│  Scripts:  CommonDriveMigration.v2, SPMT-Worker.v2,         │
│            Update-MigrationTargets.v2 (Teams target),       │
│            Import-MigrationSources, Invoke-UNCStorageScan,  │
│            Retry-FailedMigration, dashboard/landing pages   │
├─────────────────────────────────────────────────────────────┤
│  HOW TO USE THE CONCIERGE                                   │
│  1. Open in Teams (link in the launch post)                 │
│  2. Click the matching scenario tile                        │
│  3. Answer the sub-flow question (if asked)                 │
│  4. Ask the specialist anything: prereqs, params, errors,   │
│     workflow diagrams, sample calls                         │
│  5. Replace all placeholder values (contoso.*, GUIDs,       │
│     @contoso.gov) with your tenant values before running    │
├─────────────────────────────────────────────────────────────┤
│  WHAT IT WON'T DO                                           │
│  ✗ Execute scripts (it explains; you run)                   │
│  ✗ Mix advice across scenarios                              │
│  ✗ Invent parameters                                        │
│  ✗ Replace placeholders for you                             │
├─────────────────────────────────────────────────────────────┤
│  CSA-to-CSA. Built by Doug Cox.  v1.0 (June 2026)            │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Long description (for the Teams app store listing)

```
The Cloud Migrate Pro Concierge is your one-stop CSA assistant for three battle-tested
migration playbooks:

• On-Prem SharePoint / OneDrive → SharePoint Online (2024)
• H: Drive (network home folders) → OneDrive (2025)
• Common Drive (UNC shared drives) → SharePoint Online sites or Teams
  channel folders (2026)

Pick your scenario from the welcome card and the Concierge routes you to a
specialist agent grounded only in the scripts for that scenario. Every answer
cites the source PowerShell script. Diagrams render in chat. Sample command
lines come pre-templated with sanitized placeholders.

No cross-scenario hallucinations. No reinventing the playbook.

Author: Douglas Cox.
```

---

## 5. Internal Viva Engage / channel post (shorter form)

```
🛫 New tool for CSAs: Cloud Migrate Pro Concierge.

A Teams agent that picks the right migration specialist for your scenario
(On-Prem→SPO, H:→OneDrive, Common Drive→SPO/Teams) and grounds every
answer in my sanitized PS scripts.

No more guessing which script + which parameters.

Add to Teams → [link]. DMs open for feedback.
```

---

## 6. Office hours / launch event (optional)

30-minute Teams meeting:
- 5 min: the problem
- 10 min: live demo (use the 2-min demo as a baseline, then take questions)
- 10 min: open Q&A
- 5 min: how to contribute a new scenario

---

## 7. Feedback loop

- A Teams channel (`#migration-concierge`) for issues + suggestions.
- A simple SPO list for "new scenario requests" — each request becomes a
  candidate child agent.
- Versioned releases: tag the agents (v1.0, v1.1, …) and note changes in
  the channel.
