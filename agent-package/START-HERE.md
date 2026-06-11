<p align="center">
  <img src="assets/cloud-migrate-pro-logo.png" alt="Cloud Migrate Pro" width="180" />
</p>

# Cloud Migrate Pro — Start Here

> **For other CSAs.** This is the entry point. It tells you what this project is, *why I built it the way I did*, and where to go next depending on what you want to do — pitch it, build your own, or steal pieces.

---

## The story in 90 seconds

This project started where most CSA IP starts — inside a real customer engagement that grew. Over its lifetime, the migration playbooks underneath this agent have been used to move **50,000+ users** and **petabytes of content** off on-prem SharePoint, home folders, and shared file servers into Microsoft 365 — across commercial, GCC-High, and sovereign clouds.

Same patterns kept repeating. Same gotchas. Same questions from new CSAs joining the engagement: *which switch do I use? what does this column mean? why is the SCA swap necessary?*

So I did what most of us do: I started **writing it down**.

### Attempt 1 — A SharePoint site

The first home for all of it was a SharePoint site — the old way I used to document and share the IP:

> [https://microsoft.sharepoint.com/teams/OneDriveMigrationToolCustom](https://microsoft.sharepoint.com/teams/OneDriveMigrationToolCustom)

Pages, document libraries, embedded scripts, a runbook here, a FAQ there. It worked — *for me*. It was a place I could point a colleague and say "the answer's in there somewhere."

The problems with that model are the obvious ones:

- **Nobody reads internal SharePoint sites end-to-end.** They Ctrl-F for a keyword, miss the context, copy a snippet, and move on.
- **The IP was passive.** It just sat there. It didn't talk back. It couldn't disambiguate "I need to migrate a file share" into "is that an H: drive or a common drive?"
- **It didn't travel.** When a new CSA joined, I'd send the link, then end up explaining the site over Teams anyway.

For years that was the best I could do. Documentation and a Teams channel.

### Attempt 2 — AI

When Microsoft Copilot Studio became usable, GitHub Copilot landed in VS Code, and Microsoft Scout came online for codebase exploration, the picture changed. Not "I made a chatbot" — that undersells it. The actual shift was:

> **Years of CSA muscle memory — hardened against 50k+ user migrations and petabytes of data — got packaged into something that talks back, asks clarifying questions, and generates the exact PowerShell to run.**

That's the project in this folder.

---

## What "next level" actually means

Concretely, what changed when I moved from the SharePoint site to this package:

| Before (SharePoint site) | Now (Cloud Migrate Pro) |
|---|---|
| A page tree someone had to navigate | An **AI Concierge** that asks *what are you migrating?* and routes |
| Generic FAQ that didn't know the user's scenario | Three **specialist agents** with their own scoped knowledge — no cross-scenario contamination |
| Scripts attached as files, no context | Scripts + workflow diagrams + decision aids + plain-English FAQ — **all grounded** to the script source |
| "Here's the link, good luck" | A live **demo website** any CSA can open and use immediately |
| Updates lived in my head | Everything is **markdown in git**, diffable, reviewable, version-controlled |
| Nothing for non-technical stakeholders | **Audience-aware patterns** — the agent can produce end-user emails, executive summaries, or full operator-detail on demand |

The headline isn't the AI. The headline is that **CSA field IP became a product** — repeatable, distributable, version-controlled, and conversational.

---

## What I actually shipped

Three things, working together:

### 1. The website (the front door)

[`cloud-migrate-pro/index.html`](../cloud-migrate-pro/index.html) — a self-contained HTML page that embeds the live AI Concierge. This is what you'd send a manager or a customer to demo.

> Live URL: [https://douglasluvpup.github.io/cloud-migrate-pro/](https://douglasluvpup.github.io/cloud-migrate-pro/)

### 2. The four agents (the brains)

A two-tier architecture in Microsoft Copilot Studio:

```
                Cloud Migrate Pro Concierge
                  router · no knowledge · routes only
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
 On-Prem → SPO          H: Drive → OneDrive   Common Drive → Teams/SP
   2024 playbook           2025 playbook          2026 playbook
```

- **Concierge:** asks one question, picks the right specialist, hands off.
- **Three specialists:** each owns one migration scenario. Each has its own knowledge silo (workflows, command reference, troubleshooting, plain-English FAQ, decision aids, user-experience narrative).
- All four use **Claude Sonnet 4.6**.
- All four use **Microsoft Copilot Studio** as the runtime.

### 3. The package (the source of truth)

This folder — [`CopilotStudio-AgentPackage/`](.) — holds the version-controlled source for everything: the four system prompts, all knowledge files, the welcome card, the topic build sheets, the upload guide, and the deeper writeups. Markdown in git, not a SharePoint site I have to remember to update.

---

## The toolchain (and what each tool does)

I want to call this out specifically because it's the part that makes this repeatable for any other CSA:

### VS Code + GitHub Copilot

This is where **everything was authored**. Every system prompt, every knowledge card, every troubleshooting entry, every Mermaid diagram. The pair-programming loop:

1. I describe the goal in plain language.
2. Copilot drafts the file (or a section).
3. I review against my domain knowledge, push back where it's wrong.
4. Copilot revises.
5. Commit.

What Copilot is *good* at here: keeping four parallel system prompts structurally consistent, counting characters against the 8,000-char Copilot Studio cap, generating Mermaid diagrams from prose descriptions, drafting comms templates, producing audience-aware variants of the same content.

What I (the human) am still doing: domain truth, judgment calls on tradeoffs, decisions about scope, eyeballing whether the published agent *feels* right, writing the customer story.

### Microsoft Scout

When the codebase grew past what I could hold in my head, Scout became the way I asked questions across the whole package — *"is the OD2OD sleep value 30s or 120s? Show me where it's set."* It's the second pair of eyes on a codebase that spans dozens of files.

### Microsoft Copilot Studio

The runtime. This is where the four agents actually live, where the connected-agent wiring happens, where the chat is hosted, where publishing to Teams / Web / M365 Copilot happens.

The thing to understand: **Copilot Studio is the deployment target, not the development environment.** All authoring happens in VS Code. Copilot Studio just consumes what we produce.

### Git + GitHub

Everything is version-controlled. The package, the website, the deep docs. Every change has a diff, every commit has a message, every file has history. This is the single biggest reason the SharePoint site era didn't scale and the Copilot Studio era does.

---

## What this looks like in practice for a CSA using it

A CSA on a customer engagement opens the Concierge and types:

> *"Customer wants to move file shares to SharePoint."*

The Concierge clarifies the scenario in one question (per-user H: drive or shared common drive?), hands off to the right specialist, and the specialist:

- Walks them through the prereqs
- Generates the exact PowerShell command line for their tenant
- Explains which list columns drive what
- Surfaces the gotchas before they hit them
- Drafts the end-user announcement email if asked
- Produces an executive summary if asked

All grounded to the actual scripts in source control. No hallucinated parameters. No cross-scenario contamination.

---

## How to use this package

Pick the entry that matches what you want to do:

| You want to… | Read this |
|---|---|
| **Pitch this to a manager / customer** | The [website](../cloud-migrate-pro/index.html) is the demo. The [`UPLOAD-GUIDE.md`](UPLOAD-GUIDE.md) shows what's actually in each agent. |
| **Stand up your own copy in your tenant** | [`05-Porting-to-CopilotStudio.md`](05-Porting-to-CopilotStudio.md) — click-by-click import steps. Then [`UPLOAD-GUIDE.md`](UPLOAD-GUIDE.md) for what to upload to each agent. |
| **Understand the design decisions and tradeoffs** | [`Cloud-Migrate-Pro-Agent-How-We-Built-It.md`](Cloud-Migrate-Pro-Agent-How-We-Built-It.md) — the case study: why router-vs-mega-agent, why generative-off on the router, the gotchas, the patterns. |
| **See the actual journey and time investment** | [`Build-Walkthrough-and-Collaboration-Log.md`](Build-Walkthrough-and-Collaboration-Log.md) — what we did session by session, what the human/AI split looked like, an honest hours estimate. |
| **Replicate the pattern for your own scenario** | Read both deep docs above, then see "Reuse this pattern" below. |
| **Know exactly what to upload to each Copilot Studio agent** | [`UPLOAD-GUIDE.md`](UPLOAD-GUIDE.md) |
| **Announce the agent in your org** | [`06-Launch-Kit.md`](06-Launch-Kit.md) |

If you only have time for one doc: read [`Cloud-Migrate-Pro-Agent-How-We-Built-It.md`](Cloud-Migrate-Pro-Agent-How-We-Built-It.md). It's the one you'd hand a CSA who asks "how would I do this for my customer?"

---

## Reuse this pattern

If you're a CSA with field IP that lives as a pile of scripts and a mental model in your head — same place I was — the path I'd recommend:

1. **Pick one scenario you've run end-to-end at least three times.** Not the most ambitious. The most repeated.
2. **Open VS Code with GitHub Copilot.** Don't start in Copilot Studio. Start in source control.
3. **Write the 5-file knowledge bundle before you touch Copilot Studio:**
   - `workflows.md` — narrative + Mermaid diagrams
   - `knowledge-cards.md` — atomic Q&A the model can quote
   - `command-reference.md` — exact commands and switches
   - `troubleshooting.md` — observed failures and fixes
   - `preflight.md` — what to verify before kicking off
4. **Add the conversational layer** (this is the part the SharePoint site couldn't do):
   - `faq-plain-english.md` — questions in user language, not script lingo
   - `user-experience-narrative.md` — what the end user actually experiences
   - `decision-aids.md` — when-to-X-vs-Y tables
5. **Sanitize the scripts** (`.ps1` → `.txt`, strip parens and shell-y characters from filenames).
6. **Stand up one specialist agent** in Copilot Studio. Skip the router. Use it yourself for a week.
7. **Add a second scenario.** *Now* you need a router. Build the Concierge.
8. **Add a website** that embeds the agent. This is the demo surface.
9. **Add a launch kit and a battlecard.** The agent isn't done until someone other than you can find it and pitch it.

The package in this folder is a worked example of every step above. **Steal the templates.**

---

## Honest tradeoffs

Things that surprised me, that I'd want another CSA to know going in:

- **Most of the build was content authoring, not platform work.** Maybe 70% writing prompts and knowledge files, 20% testing in Copilot Studio, 10% actual Copilot Studio configuration.
- **The 8,000-character system prompt cap is real.** Plan for it. Write the full prompt first, then trim a faithful copy. (See the deep docs for specifics.)
- **Knowledge cross-contamination is a real risk.** This is why three specialists with separate silos beats one mega-agent that "knows everything." The headline lesson is in [`Cloud-Migrate-Pro-Agent-How-We-Built-It.md` §1](Cloud-Migrate-Pro-Agent-How-We-Built-It.md#1-the-headline-lesson).
- **Publishing isn't optional.** Every change to instructions or auth needs a re-publish to take effect.
- **Copilot Studio's UI moves.** Some screenshots / instructions go stale fast. The deep docs flag the cases where Microsoft has shifted things mid-build.
- **The agent is a colleague, not a script-reader.** If you only feed it your scripts, you ship a script-reader. Feed it the *world the script lives in* — vendor comparisons, when-not-to-use, audience-aware variants — and you ship a colleague.

---

## What's next

A few directions this could go:

- **Apply the pattern to other workloads.** Mailbox migrations, Teams chat history, Power Platform — same shape, different scripts.
- **Cross-tenant scenarios.** Currently out of scope by design; the moment Microsoft's cross-tenant tooling stabilizes, this is a natural extension.
- **MCP / API surfacing.** The agents currently route via Copilot Studio's connected-agents wiring; surfacing the specialists via MCP would let other Copilot consumers (M365 Copilot, dev tools) call them directly.
- **More CSAs reusing the pattern.** The single biggest impact is other engineers taking the templates and standing up their own specialists for their own customers.

If you do any of those: tell me. The whole point of moving from the SharePoint site to this package was so the IP could travel.

---

*— Douglas Cox · Cloud Migrate Pro v1.0*
