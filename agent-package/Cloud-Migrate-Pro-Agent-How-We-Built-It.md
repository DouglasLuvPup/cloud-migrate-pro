<p align="center">
  <img src="assets/cloud-migrate-pro-logo.png" alt="Cloud Migrate Pro" width="180" />
</p>

# Cloud Migrate Pro Agent — How We Built It

> **A training case study for CSAs and agent builders.**
> How we turned three battle-tested PowerShell migration playbooks into a
> single multi-agent assistant in Microsoft Copilot Studio — and the design
> decisions, gotchas, and reusable patterns we picked up along the way.

> **Author:** Douglas Cox
> **Audience:** Cloud Solution Architects, Copilot Studio agent builders,
> anyone packaging field IP into reusable AI assistants
> **Companion to:** `00-README.md`, `05-Porting-to-CopilotStudio.md`,
> `06-Launch-Kit.md`

---

## TL;DR — what we shipped

A two-tier agent in Copilot Studio:

```
                ┌──────────────────────────────────────┐
                │   Cloud Migrate Pro Concierge        │
                │   (router · generative answers OFF)  │
                └──────────────────────────────────────┘
                              │
       ┌──────────────────────┼──────────────────────┐
       │                      │                      │
┌──────────────┐      ┌──────────────┐      ┌──────────────────┐
│ On-Prem SP → │      │ H: Drive →   │      │ Common Drive →   │
│ SPO Guide    │      │ OneDrive     │      │ SharePoint       │
└──────────────┘      └──────────────┘      └──────────────────┘
   Knowledge silo        Knowledge silo        Knowledge silo
   (5 files)             (5 files + script)    (5 files + 11 scripts)
```

- **Concierge (router):** no Knowledge attached, generative answers **off**,
  topics route to one of three Connected Agents based on the user's signal.
- **Three specialist agents:** each owns its scenario, has its own Knowledge
  silo, has generative answers **on**, and never advises across silos.
- **Cloud-portable:** built on commercial; documented endpoint swaps for
  GCC / GCC-H / DoD.
- **Model:** Claude Sonnet 4.6 (with GPT fallback).

---

## 1. The headline lesson

> **Ground the agent in reality, not just the script.**
>
> CSAs ask migration-shaped questions, not script-shaped questions. They
> ask about GCC-H portability, Microsoft recommendations, vendor
> comparisons, when *not* to use a given approach, and what to do when
> the script doesn't fit. So we deliberately broadened the agent beyond
> script Knowledge: cloud portability notes, vendor positioning with
> honest tradeoffs, Microsoft references (SPMT / FastTrack / SAC /
> Mover-retired), an explicit *when NOT to use this playbook*, and a
> refusal-and-handoff pattern for everything off-scope.
>
> **Principle: the script is the floor of what the agent knows, not the ceiling.**

If you only feed an agent your scripts, you ship a script-reader. If you
feed it the *world the script lives in*, you ship a colleague.

---

## 2. Decision points & tradeoffs

### 2.1 Router vs. one mega-agent

**Decision:** Build a Concierge router with three Connected Agents instead
of one large agent that knows everything.

**Why:**

- Knowledge cross-contamination. If H: Drive guidance and Common Drive
  guidance live in the same Knowledge pool, the agent will splice
  retrieval results from both and confidently invent a hybrid that doesn't
  exist.
- Scoped instructions. Each specialist's system prompt can be sharply
  worded ("you are *only* the X migration agent; if asked about Y,
  hand off") without polluting siblings.
- Independent iteration. We can update the H: Drive Knowledge without
  retesting the SP-on-prem flows.

**Tradeoff:** One extra hop for the user (router → specialist). Worth it.

### 2.2 Generative answers OFF on the router, ON on specialists

**Decision:** The Concierge answers only via topics; specialists answer
via Knowledge + generative.

**Why:**

- The router's *only* job is classification + handoff. Generative output
  there is a liability — it might answer the question itself instead of
  routing.
- Specialists need generative output to phrase Knowledge results, fill
  gaps, and stay conversational.

### 2.3 Knowledge siloed per agent, not shared

**Decision:** Each specialist has its own 5-file Knowledge bundle plus its
own scripts. No shared corpus.

**Why:** See 2.1. Also: file-level access in Copilot Studio Knowledge is
coarse, so silos give us a clean blast radius.

### 2.4 The "Heritage SharePoint" naming reversal

**What happened:** An early draft branded the on-prem agent around the
phrase **"Heritage SharePoint"** (covering SP 2013/2016/2019/SE +
MySites). It read well — terse, evocative, distinct from "Modern SPO".

**What broke:** The user fact-checked the term against internal Microsoft
sources. *"Heritage SharePoint"* is field slang, not an official Microsoft
term. A CSA Googling for it would find blog posts, not docs.

**What we did:** Renamed the agent to **"On-Prem SharePoint → SPO
Migration Guide"** — longer, less elegant, but searchable. Removed the
glossary entry. Updated all references.

**Lesson:** If a user might reasonably Google your terminology and not
find it in product docs, *rename the thing*. Don't gloss over it. An
agent that uses unofficial vocabulary as if it were canonical is an
agent that quietly erodes user trust.

### 2.5 Pricing softened with an RFQ caveat

**Decision:** Vendor battlecards include indicative pricing, but every
number is followed by *"contact vendor for current pricing — government
and enterprise SKUs vary"*.

**Why:** Pricing rots fast. An agent that confidently quotes a stale
ShareGate or Quest number to a CSA in front of a customer is worse than
an agent that says "ask the vendor."

---

## 3. Gotchas (Copilot Studio Knowledge)

These cost us cycles. Write them down.

| Symptom | Root cause | Fix |
|---|---|---|
| *"There was a problem creating your knowledge source"* on a `.ps1` upload | Studio Knowledge rejects `.ps1` extension | Rename to `.txt`, re-upload |
| Same error on a file like `Migration-OD2OD-SPO(09132024).ps1` | Filenames containing `()`, `&`, `+`, `#`, or other shell-y characters | Strip parens / specials before upload |
| Same error after deleting a file and re-uploading the same name | Stale Dataverse record collision | Refresh the Studio page **or** rename the file slightly (e.g. add `-v2`) |
| Agent confidently mixes guidance from two silos | You attached Knowledge to the router instead of (or in addition to) the specialists | Knowledge belongs on specialists only |
| Agent ignores your carefully written "## Notes for the builder" section | That section is *for you*, not for the agent — Studio's Instructions field is the only thing the model reads | Keep builder notes in the `.md` for humans; put model-facing rules in Instructions |
| Duplicate filename across two specialists confuses retrieval | Filename collisions across silos still surface in some Studio views | Prefix scripts with the agent name: `Hdrive-`, `CommonDrive-`, etc. |

---

## 4. Reusable patterns

### 4.1 The `system-prompt.md` template

Every specialist follows the same skeleton. Copy it for the next agent
you build:

```
VERSION: vX.Y, <Month Year>
NAME / BRANDING: display name, what to say when asked "what are you?"
SCOPE: one paragraph — what this agent is and isn't
SCRIPTS: which files in Knowledge are authoritative
BEHAVIOR: how to answer (cite Knowledge, ask clarifying Qs, etc.)
OUT-OF-SCOPE: explicit list of "if asked about X, hand off / refuse"
CLOUD PORTABILITY: endpoint swap notes for GCC / GCC-H / DoD
NEVER: hard rails — never invent script flags, never quote stale prices,
       never advise outside silo
```

### 4.2 The 5-file Knowledge bundle per specialist

1. **`workflows.md`** — narrative walkthrough of the end-to-end process
2. **`knowledge-cards.md`** — atomic Q&A cards the model can quote
3. **`command-reference.md`** — exact PowerShell invocations + flags
4. **`troubleshooting.md`** — observed failures and their fixes
5. **`preflight.md`** — checks to run before kicking off a migration

Plus the actual scripts (renamed to `.txt`).

### 4.3 Router → specialist handoff

In the Concierge's topics, each route ends with a single handoff line
like:

> "I'm bringing in the **H: Drive Migration Guide**. Ask away."

Short, branded, sets expectation. Avoids "transferring you to..." which
sounds like a call center.

### 4.4 Conversation starter chips

Three chips, one per scenario, phrased as user-shaped questions:

- *"How do I migrate H: Drives to OneDrive?"*
- *"How do I move a Common Drive to SharePoint?"*
- *"How do I migrate from on-prem SharePoint to SPO?"*

Not *"H: Drive agent"*, *"Common Drive agent"*. Users don't think in
agents; they think in problems.

---

## 5. Build sequence

For the step-by-step click-path in Copilot Studio, see
[`05-Porting-to-CopilotStudio.md`](05-Porting-to-CopilotStudio.md).
Short version:

1. Build the three specialists first (each: prompt, Knowledge, topics, test).
2. Build the Concierge last (no Knowledge, generative off, topics that
   hand off to the three Connected Agents).
3. Test each specialist standalone, then test routing through the
   Concierge.
4. Publish the Concierge to Teams. Specialists are reachable only
   through the router.

---

## 6. What we'd do differently next time

- **Lock terminology against product docs on day one.** The Heritage
  reversal was cheap to fix in a `.md` package, expensive to fix after
  the agent ships and CSAs have screenshots in decks.
- **Sanitize filenames at export, not at upload.** Add a one-liner to
  the export tooling that strips `()`, `&`, `+`, `#` from any artifact
  destined for Studio Knowledge.
- **Stand up a "what NOT to use this for" doc per agent before the
  happy-path doc.** Forces the scoping conversation early.
- **Treat Knowledge like product, not like a folder dump.** A scripts
  dump answers script questions. A *curated* Knowledge bundle —
  workflows, cards, troubleshooting, preflight — answers migration
  questions.
- **Build a smoke-test prompt sheet per agent before the first publish.**
  We bolted ours on later (`evaluate-test-prompts.md`); should have
  written it first and let it drive scoping.

---

## 7. Reusing this for your own scenario

If you're a CSA with field IP that lives as a pile of scripts and a
mental model in your head, the path is:

1. **Pick one scenario you've run end-to-end at least three times.** Not
   the most ambitious — the most repeated.
2. **Write the 5-file Knowledge bundle before you touch Studio.** If you
   can't write `troubleshooting.md` from memory, the scenario isn't
   ready.
3. **Sanitize the scripts** (`.ps1` → `.txt`, strip parens).
4. **Stand up one specialist agent.** Skip the router. Use it yourself
   for a week.
5. **Add a second scenario.** *Now* you need a router. Build the
   Concierge.
6. **Add a launch kit and a battlecard.** The agent isn't done until
   someone other than you can find it and pitch it.

The Cloud Migrate Pro package in this folder is a worked example of
every step above. Steal the templates.

---

## 8. Session addenda — things we learned during the actual Studio build

This section captures lessons from the session where we took the package
from Markdown to a published agent. Studio's UI shifts often, so some of
these correct or supersede earlier guidance.

### 8.1 Studio's tab layout has flattened — there is no "Overview" tab

Older docs (and earlier drafts of `05-Porting-to-CopilotStudio.md`) say
"Agent → Overview → Instructions / Details / Icon." In the current build,
the agent header has only **Build · Preview · Evaluate · Monitor**.
Everything that used to live on Overview is now on the **Build** view
itself, with the right rail (Model / Skills / Tools / Knowledge /
Connected agents) and a **Settings** dialog reached via the **`...`**
menu top-right.

If a guide tells you to click "Overview," translate that to:

| Old path | Current path |
|---|---|
| Overview → Instructions | Build → main pane |
| Overview → Details → Name | pencil icon next to agent name |
| Overview → Details → Icon | `...` → Settings → Agent details → Icon |
| Overview → Generative AI | `...` → Settings → AI & behavior |

### 8.2 Agent icons: 100 KB cap, and watch for fake transparency

**The cap is 100 KB.** A 1024×1024 PNG from your branding folder will
fail the upload. Resize to 256–384 px before uploading.

**The trap we hit:** a logo PNG that *looks* like it has a transparent
background can actually have the gray-checker pattern **baked in as gray
pixels** (with full alpha=255). Studio shows what's in the file, so the
agent icon ends up with a grid behind the logo. Fix:

- Use a flat, opaque background in your source image (no transparency
  needed — Studio applies its own corner rounding).
- Or programmatically replace any "near-gray, mid-bright" pixels with
  your tile color before resizing.

The icon we shipped is `assets/cloud-migrate-pro-logo-icon.png` —
384×384, ~84 KB, solid dark blue tile (#1E3A61) with a white cloud-and-
arrow glyph. Same icon goes on all four agents for visual coherence.

### 8.3 The "Generative answers OFF" toggle no longer exists

Earlier guidance (still echoed in `01-Concierge/system-prompt.md` builder
notes) tells you to flip a **Generative answers: OFF** switch on the
router. In the current UI, **that toggle is gone**. Agent settings →
**AI & behavior** shows only:

- **Allow other agents to connect** (whether *other* agents can call
  this one as a tool — different setting)
- **Moderation level** (content filter strength)

Generative behavior is now governed by:

1. **The Instructions field** — the system prompt is the actual guardrail.
2. **Knowledge attachments** — empty Knowledge = nothing to free-form
   answer from.
3. **Connected agents** — present, so the router has somewhere to hand off.

For the Concierge, that means: Knowledge stays empty, Instructions stay
sharp, Connected Agents are wired. There's no extra toggle to flip.

**For the `Allow other agents to connect` toggle:**

- **Concierge: OFF.** Nothing should call the Concierge as a tool.
- **Specialists: ON** if routing tests fail (it's how the Concierge
  invokes them). In our tenant routing worked without it being explicitly
  on, but flip it if Connected Agents picker shows them but routing
  silently fails.

### 8.4 Connected Agents picker requires Published specialists

**Build order matters:**

1. Build all three specialists.
2. **Save AND Publish each specialist** before opening the Concierge.
3. Build the Concierge. The Connected Agents picker only lists
   **Published** agents.

Skipping step 2 makes the specialists invisible in the picker and burns
half an hour of "why isn't my agent in the list."

Important: **Publish ≠ deploy to channels.** Publishing the specialists
just makes them invokable as Connected Agents. They don't need any
channel enabled — users never reach them directly.

### 8.5 Conversation Starters have *two* fields, not one

Studio's Greeting & Prompts panel for starters takes:

- **Title** — short chip text users see (~50 chars works best)
- **Message** — what gets sent to the agent when clicked

Most teams write only the Title and wonder why routing is fuzzy. Use the
Message field to phrase the exact routing keyword the system prompt is
listening for. Our four:

| Title | Message |
|---|---|
| `On-prem SharePoint → SPO` | `I need to migrate an on-premises SharePoint site to SharePoint Online.` |
| `H: drive → OneDrive` | `I need to migrate user H: drive home folders to OneDrive.` |
| `Common drive → Teams / SPO` | `I need to migrate a common file-server drive to a Teams channel or a SharePoint site.` |
| `Why these scripts vs. ShareGate / AvePoint?` | `Why should I use these migration scripts instead of ShareGate, AvePoint, or Quest?` |

### 8.6 Three publish paths — pick by your governance posture

The Publish dialog offers three channels. They are *not* equivalent.

| Channel | Admin approval needed? | User experience | Best for |
|---|---|---|---|
| **Demo Website** | None | Browser tab with chat UI, shareable URL | Pilot, early feedback, working sessions |
| **Web app** | None (but iframe host needed) | Embedded in any page | Internal portal, SharePoint landing page |
| **Teams + M365** | **Yes — Teams admin must allow in Manage apps** | Real Teams app, M365 Copilot agent picker, pinning, channel/meeting access | Production rollout |

**The Teams + M365 path is the one that requires admin approval.**
Publishing alone is not enough; until a Teams admin flips the app from
**Blocked** to **Allowed** in Teams Admin Center → Manage apps, end users
will not find it when they search.

Strategy that works:

1. Enable **Demo Website** immediately. Pilot it with 2–3 CSAs.
2. In parallel, file the Teams admin allow-list request.
3. When admin approves, migrate users to the proper Teams app.

### 8.7 Re-publishing doesn't require re-approval

Once Teams admin has allowed the app, you can iterate freely:

- Edit Instructions, swap icon, add starters, retune knowledge.
- Click **Publish** again — Studio pushes an updated manifest.
- Already-installed users get the update automatically.
- Allow-list status persists. **No re-approval needed** for content
  changes.

Only changes that introduce new permissions or scopes can re-trigger an
approval prompt. Routine content iteration is free.

### 8.8 Teams + M365 publish dialog field cheatsheet

The publish dialog asks for several fields whose right values aren't
obvious. What we used:

- **Icon** → `assets/cloud-migrate-pro-logo-icon.png`
- **Change color** → dark blue, ~`#1F3864`
- **Short description (80 char cap)** → one-liner positioning the
  agent's job. We used: *"Front door for Microsoft 365 migrations:
  on-prem SharePoint, H: drives, file shares."*
- **Long description (3,400 char cap)** → use it. We shipped ~2,400
  chars covering: scenarios, vendor positioning, what specialists do,
  what they don't do, sanitization reminder.
- **Show an agent disclaimer in M365 Copilot** → **OFF** for internal
  tools. The disclaimer is for marketplace apps.
- **Users can add this agent to a team** → **ON**. Useful for migration
  project teams.
- **Use this agent for group and meeting chats** → **ON**. Lets a CSA
  `@mention` it during a working session.
- **Developer name / Website / Terms / Privacy / MPN ID** → Microsoft
  defaults are fine for internal tools. Only override if your org has a
  governance requirement.

### 8.9 Description-writing lesson

Our first long description had two phrases that didn't survive review:

- **"Generate ready-to-run PowerShell parameters"** — overstated. The
  specialists *help you choose* parameter values; they don't auto-emit
  customer-ready commands. Final wording: *"help you choose the right
  parameter values for your tenant."*
- **"Cost, sovereign cloud coverage, data sovereignty, auditability"**
  — read like a compliance brochure. Final wording: *"compare these
  PowerShell-based playbooks to ShareGate, AvePoint, Quest On Demand,
  BitTitan MigrationWiz, and Microsoft's built-in SharePoint Migration
  Manager — covering price models, sovereign cloud coverage, where data
  actually flows, and what each tool covers (and skips)."*

Lesson: write the description as if a CSA would forward it to a customer.
Honest verbs ("help you choose," not "generate"). Plain English over
audit-speak. Always include explicit *what it doesn't do.*

### 8.10 Suite-wide rebrand was the most expensive rename

Mid-build we rebranded from **Migration Concierge** to
**Cloud Migrate Pro Concierge** (umbrella suite name + product name). It
touched 30+ files: every system prompt, every README, the launch kit,
the marketing one-pager, the welcome card, the training doc.

**Lesson:** pick the suite name **before** writing prompts. A bulk
sed-style replace gets you 95% of the way; the last 5% is in mermaid
diagrams, table cells, prose mentions, and adaptive-card text that
escaped the search. Budget 30 minutes for that long tail.

If you're starting fresh: pick a **short** umbrella name (2 words max).
Anything longer becomes painful in chip text, in the Studio agent
header, and in conversational handoffs ("I'm bringing in the …").

### 8.11 Adaptive Cards in Teams: dark mode, hosting, and what not to do

Three dead ends we hit on the welcome card:

- **Hosting images on SharePoint Site Assets:** the URLs are auth-gated.
  Adaptive Card image renderers in Teams won't follow the redirect.
  Card renders without the image. Avoid.
- **Hard-coded colors for dark/light:** the host (Teams user theme)
  controls dark/light. Use **semantic tokens** (`style: emphasis`,
  `color: Accent`, `isSubtle: true`) and let the host pick.
- **Trying to brand the card with a logo image:** not worth the
  hosting headache. Rely on the **agent icon** (Microsoft-hosted) for
  branding. Drop the Image column entirely.

Final welcome card: text-only, semantic-token styled, theme-neutral.

### 8.12 Date stamping and version discipline

Every agent's system prompt has a `VERSION:` line that the agent will
quote when asked. We refreshed all stamps from May 2026 to June 2026
mid-session — a one-shell-loop bulk replace.

**Pattern:** keep the version string in exactly one form across the
package: `vMAJOR.MINOR (Month YYYY)`. Then you can grep / sed it cleanly.
Mixed forms (`v1.0`, `1.0`, `v1`, `May 2026`, `5/2026`) make bulk
updates miss things.

---

*— End of training doc. Questions / improvements / your own war stories
welcome.*
