# Competitive Battlecards

> **Pricing disclaimer.** Every dollar figure on these cards is an **industry
> estimate** based on publicly-discussed federal SI engagements 2023–2026.
> None are quoted prices. ShareGate, AvePoint, Quest, and BitTitan all price
> by RFQ; ranges vary widely by user count, term, and federal premium.
> **Replace bracketed placeholders with live vendor quotes before any
> customer-facing claim.**

Format: each card lists **Their pitch / Where they win / Where we win / Proof point / Honest counter**. Use in peer conversations, internal pitches, and competitive scoping calls. Always lead with where they actually win — credibility comes first.

---

## Card 1: ShareGate Migrate

**Their pitch:** "The easy SharePoint migration tool. Drag, drop, done. Strong fidelity for permissions and structure on commercial. Familiar to thousands of SI consultants."

**Where they actually win:**
- Best-in-class **GUI** for non-PowerShell operators
- Mature **commercial-cloud** fidelity (SP 2010–2019 → SPO)
- **Brand recognition** with mid-tier consulting firms
- **Pre-flight permission analysis** stronger than this playbook
- Active **community + documentation**

**Where this playbook wins:**
- **IL5 / IL6.** ShareGate has no IL5/IL6 SaaS instance as of the time of writing.
- **$0 licensing** vs ShareGate's RFQ-quoted annual fee.
- **Federal AD identity glue** — `wwwHomePage` flip, `*REDIRECTION*` group cleanup, `SecFltr-USR-OneDrive` → `SecFltr-USR-Office365`, SCA swap with `svc-migration`. ShareGate doesn't ship this.
- **No vendor cloud in the data path.** ShareGate Online routes through ShareGate's cloud — blocked for CUI/FOUO/SAP.
- **Auditable code.** Customer reads + diffs `.ps1`. ShareGate is an opaque binary.

**Honest counter when customer leans ShareGate:**
> "ShareGate is the right tool if you're commercial-only, want GUI-only ops, and the license fee is approved. For IL5/IL6, or where the AD identity workflow has to happen *during* the migration, ShareGate doesn't solve the whole problem — you'd still need the wrapper. We've already written it."

**Proof point to validate:** `[CUSTOMER_OR_ENGAGEMENT_REFERENCE]` — IL6 migration of `[SCALE]` where ShareGate was disqualified by cloud coverage.

---

## Card 2: AvePoint Fly + Confidence Platform

**Their pitch:** "Enterprise-grade SaaS migration + ongoing governance. Strong GCC-H story. Pre-migration content classification, post-migration governance + DLP."

**Where they actually win:**
- **GCC-H support is real** — strongest of the COTS vendors for fed.
- **Pre-migration content classification / DLP scoring** is genuinely better than this playbook.
- **Ongoing governance** (Confidence Platform) is a real differentiator beyond migration.
- **Vendor SLA + named support** — if a customer needs 24/7 vendor on-call, AvePoint provides it.
- **Multi-workload coverage** (Teams, Yammer, sites, mailbox via partners).

**Where this playbook wins:**
- **IL6** is not publicly documented for AvePoint Confidence; this playbook runs IL6 in production today.
- **Cost.** AvePoint Fly + Confidence enterprise contracts are typically six-figure annual (estimate, RFQ-driven). This playbook is $0 licensing.
- **No vendor cloud in the migration data path** (Fly Online vs. this playbook's customer-controlled infrastructure).
- **Federal-specific AD identity workflow** specific to the receiving agency (group names, SCA semantics) that AvePoint generic federation doesn't model.
- **Targeted scope.** This playbook is for file content. AvePoint sells a broader platform — if the customer doesn't need governance, they're paying for unused capability.

**Honest counter when customer leans AvePoint:**
> "AvePoint Confidence is the right answer if you need pre-migration content classification, ongoing post-migration governance, and a vendor SLA. For migration-only at IL6, you're paying enterprise-platform pricing for a one-time job. We can do the migration; you can layer governance on top after, or not."

**Proof point to validate:** `[CUSTOMER_OR_ENGAGEMENT_REFERENCE]` — federal scenario where governance was not in scope and cost optimization mattered.

---

## Card 3: Quest On Demand Migration (formerly Metalogix Content Matrix)

**Their pitch:** "Decades of SharePoint migration heritage (Metalogix lineage). Multi-workload. Cloud-hosted SaaS."

**Where they actually win:**
- **Long history with SharePoint** content migration including complex on-prem scenarios.
- **Multi-workload** (sites, mailbox, OneDrive, file shares).
- **Quest support organization** is established.

**Where this playbook wins:**
- **Cloud SaaS routing concerns** — On Demand is hosted in Quest's commercial cloud. Blocked for IL5/IL6 sensitive content.
- **Cost.** RFQ-driven, typically five- to low-six-figure annual (estimate). This playbook is $0 licensing.
- **No vendor cloud in path.**
- **Federal AD identity glue** not present.
- **Auditable code** vs. binary.

**Honest counter when customer leans Quest:**
> "If the customer is commercial, has existing Quest investments, and the data-routing-through-Quest-cloud is acceptable, On Demand is reasonable. For federal sovereign cloud, the data-residency story doesn't hold up."

**Proof point to validate:** `[CUSTOMER_OR_ENGAGEMENT_REFERENCE]` — federal scenario where SaaS routing was disqualified.

---

## Card 4: BitTitan MigrationWiz

**Their pitch:** "Per-user, per-workload migration as a service. Mailbox is the strength; file shares + OneDrive are bundled. Cross-tenant friendly."

**Where they actually win:**
- **Cross-tenant** mailbox + content migration — best-in-class.
- **Per-user pricing** is predictable (RFQ but published bundles exist).
- **Mailbox strength** — Exchange Online migration is its core.
- **Operator UX** is clean for run-the-meter cutover work.

**Where this playbook wins:**
- **No IL5/IL6.** MigrationWiz is hosted in commercial Azure; sensitive federal content cannot route through it.
- **Cost at scale.** Per-user pricing × federal user counts adds up fast (estimate: tens of dollars per user, scaled to tens of thousands of users = mid-six-figure to seven-figure one-time). This playbook is $0.
- **Federal AD identity glue** not present.
- **File content depth** — for UNC → Teams channel migration with scheduling, storage downgrade, claim locking, this playbook is purpose-built.

**Honest counter when customer leans BitTitan:**
> "BitTitan is the right answer for cross-tenant or mailbox-led migration. For file content into IL5/IL6, the SaaS routing is a hard stop. We're not competing in BitTitan's strongest scenarios — we're filling the gap for federal file-content workloads."

**Proof point to validate:** `[CUSTOMER_OR_ENGAGEMENT_REFERENCE]` — federal IL5/IL6 file-share migration where BitTitan was disqualified.

---

## Card 5: SharePoint Admin Center bulk migration UI (Microsoft Migration Manager)

**Their pitch:** "Free, GUI, built into the SharePoint Admin Center. Microsoft-supported."

**Where they actually win:**
- **Free** — same as this playbook.
- **GUI** for non-PowerShell admins.
- **Microsoft-supported** — first-party.
- **Good enough** for one-off small migrations and pilots.

**Where this playbook wins:**
- **No scheduling.** SAC UI runs when you click run. No TimeZone windowing, no federal-holiday calendar, no priority queue.
- **No AD identity glue.**
- **No SCA swap, no service-account orchestration.**
- **No claim locking / multi-server orchestration.** Run from one console.
- **No 18-worker parallel design.**
- **No Power Automate hook** on a customer-owned control plane.
- **Limited IL6 surface** for some scenarios.

**Honest counter when customer leans SAC UI:**
> "If the project is a single small share with no per-row scheduling, no AD work, and a single operator at the console — SAC UI is fine. For anything with federal AD glue, multi-server scale, or scheduling, you're hitting the wall the SAC UI was never built to clear."

**Proof point to validate:** `[CUSTOMER_OR_ENGAGEMENT_REFERENCE]` — federal scenario where SAC UI was used for pilot, then this playbook for production scale.

---

## Card 6: Microsoft Mover (deprecated)

**Their pitch:** "(Historical) Free Microsoft file-share migration tool."

**Reality:** **Retired February 2024.** No longer a supported answer for UNC → OneDrive / SPO.

**What to say:**
> "Mover was retired in Feb 2024. If anyone's still bringing it up, they're working from old guidance. SPMT is the supported engine for file content into SPO; this playbook is the orchestration layer SPMT lacks for federal scale and identity workflow."

---

## Card 7: Syskit Migrator / Tzunami Deployer

**Their pitch:** "Wide source coverage, mid-tier enterprise alternative to ShareGate."

**Where they actually win:**
- **Wider source coverage** (Confluence, Box, Google Drive, eRoom, Documentum) than this playbook.
- **Mid-tier pricing** below the top COTS tier (still RFQ).
- Reasonable commercial-cloud fidelity.

**Where this playbook wins:**
- **No published federal story.** Neither vendor publicly markets IL5/IL6 coverage.
- **Cost.** Still RFQ-driven enterprise; this playbook is $0.
- **Federal AD identity glue** not present.

**Honest counter when customer leans Syskit / Tzunami:**
> "If the source is Confluence or Box, this playbook doesn't cover it — Syskit / Tzunami are reasonable. For SharePoint / file-share / OneDrive in federal, the cloud-coverage story doesn't compete."

**Proof point to validate:** `[CUSTOMER_OR_ENGAGEMENT_REFERENCE]` — none in scope; cross-source migrations referred out.

---

## Universal closer (use after any of the above)

> "I'm not anti-COTS. I'd recommend ShareGate or AvePoint where they win.
> What I'm telling you is that for **this specific scenario** — federal,
> file content into SPO/OneDrive/Teams, IL5 or IL6, AD identity flow during
> migration — the tools you're considering either don't cover it or cost
> six- to seven-figures to do what we've already built. Compare the RFQ
> against zero. Then decide."
