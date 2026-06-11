# Cloud Migrate Pro Concierge — Boundary Cases & Out-of-Scope Routing

When users describe edge scenarios, this file disambiguates which specialist (if any) handles it. Voice: peer senior engineer; direct; expand acronyms.

---

## Source-type ambiguities

### "OneDrive" → which agent?

The word "OneDrive" is overloaded. Always confirm before routing.

| User says | They probably mean | Route to |
|---|---|---|
| "Move our on-prem OneDrive to cloud" | Per-user **on-prem MySite** (legacy SP-hosted OneDrive) → SPO OneDrive | **On-Prem → SPO agent** |
| "Move users' home folders to OneDrive" | **`H:` drive** (UNC home folder) → OneDrive | **H: Drive agent** |
| "Cross-tenant OneDrive migration" | Source tenant's OneDrive → target tenant's OneDrive | **Out of scope** — recommend Microsoft's cross-tenant tooling or BitTitan |
| "Set up new users' OneDrive" | Provisioning, not migration | **Out of scope** — recommend `Request-SPOPersonalSite` or Entra license-based auto-provisioning |
| "OneDrive sync client problems" | Desktop client issue | **Out of scope** — recommend their helpdesk / Microsoft 365 admin center |

**Clarifying question to ask:** "Where is the source content today — in a per-user OneDrive on an old SharePoint farm, in a network drive like H:, or somewhere else?"

---

### "SharePoint" → which agent?

| User says | They probably mean | Route to |
|---|---|---|
| "Move our on-prem SharePoint sites to SPO" | On-prem SP 2016/2019 site → SPO site | **On-Prem → SPO agent** (SP2SPO flow) |
| "Move our SharePoint 2013 sites" | SP 2013 on-prem content → SPO | **Out of scope** for these scripts (the playbook orchestrates content migration and is tested against SP 2016 / 2019 / SE). SPMT itself officially supports SP 2013 sources, so the customer's content is migratable — just not via this orchestration layer. Recommend: (1) use SPMT standalone, or (2) upgrade SP 2013 → SP 2016+ first, then SP2SPO. Don't auto-route to OnPrem agent without flagging the version gap. **Don't say "feature gaps" — that's wrong; SPMT supports SP 2013.** |
| "Move SharePoint Online sites between tenants" | Cross-tenant SPO migration | **Out of scope** — recommend SharePoint Multi-Geo / cross-tenant tooling |
| "Migrate a file share to SharePoint" | UNC source → SPO | **Common Drive agent** (Flow B) or H: Drive agent if it's per-user |
| "Move SharePoint sites between site collections in the same tenant" | Intra-tenant restructure | **Out of scope** — recommend SharePoint Admin Center or PnP provisioning |

**Clarifying question to ask:** "What's the SharePoint version on-prem (2013, 2016, 2019, Subscription Edition), and is the target the same tenant or a different one?"

---

### "Teams" → which agent?

| User says | They probably mean | Route to |
|---|---|---|
| "Migrate file share into a Teams channel" | UNC → Teams channel folder | **Common Drive agent** (Flow A) |
| "Migrate SharePoint content into a Team" | Existing SPO content → channelize | **Out of scope** for the playbook (it's about creation, not migration). Recommend manual library move + Teams channel-folder mapping. |
| "Migrate Teams chat history" | Conversation migration | **Out of scope** — recommend Microsoft Teams tenant-to-tenant or third-party (BitTitan, AvePoint) |
| "Set up new Teams" | Provisioning | **Out of scope** — recommend Teams Admin Center or PnP templates |

**Clarifying question to ask:** "Is the source a network file share, or content already in Microsoft 365 (SPO or another Team)?"

---

### "File share" → which agent?

| User says | They probably mean | Route to |
|---|---|---|
| "Per-user home folder, mapped as H:" | Per-user UNC home drive | **H: Drive agent** |
| "Shared/common drive (multiple users, S: or G: or just `\\server\share`)" | Multi-user UNC share | **Common Drive agent** |
| "DFS share" | Distributed File System | Same as UNC — route by per-user vs shared as above |
| "NAS / SAN-backed share" | UNC on top of storage hardware | Same as UNC — route by per-user vs shared as above |
| "Server itself has files" (no share at all) | Local drive content | **Out of scope** as-is — recommend creating a share first, then route by shared vs per-user |

**Clarifying question to ask:** "Is the share used by one person (their personal H: drive) or by multiple people in a team (a shared/common drive)?"

---

## Multi-workload migrations

If the customer says "we need to migrate everything — file shares, mailboxes, SharePoint, OneDrive — all at once":

- **This playbook covers SharePoint/OneDrive content.** Mailboxes and other workloads are separate.
- **Decompose into separate migration tracks.** Don't try to make one tool do all of it.
- **For mailbox migrations:** recommend Exchange Online migration scripts, BitTitan, or Quest On Demand.
- **For Teams chat history:** recommend Microsoft's cross-tenant tooling or AvePoint Confidence.
- **For everything else (SharePoint, OneDrive, file shares):** use the three specialist agents in coordinated waves.

**Concierge response template:** "This playbook handles SharePoint and OneDrive content. For your full workload migration, you'll need:
1. **OneDrive (per-user from on-prem MySite):** On-Prem → SPO agent
2. **H: drives (per-user network home folders):** H: Drive agent
3. **Shared/common drives:** Common Drive agent
4. **SharePoint sites (on-prem):** On-Prem → SPO agent
5. **Mailboxes:** out of scope for this playbook — recommend [vendor option]
6. **Teams chat history:** out of scope — recommend [vendor option]
Which of these is in scope today? I can route you to the right specialist."

---

## Cross-tenant scenarios

**Cross-tenant SPO/OneDrive/Teams is out of scope for all four agents.** The scripts assume single-tenant (source and target in the same Entra tenant).

If a customer needs cross-tenant migration:

- **OneDrive cross-tenant:** Microsoft Cross-Tenant User Data Migration (preview / GA depending on tenant type) or BitTitan MigrationWiz
- **SharePoint cross-tenant:** Microsoft SharePoint Cross-Tenant Migration or third-party
- **Teams chat cross-tenant:** Microsoft Cross-Tenant Migration of Teams Chats (very limited) or AvePoint
- **Mailbox cross-tenant:** Microsoft cross-tenant mailbox migration (T2T)

**Concierge response template:** "Cross-tenant migration isn't in scope for this playbook — these scripts assume a single Entra tenant. For cross-tenant, you'd typically use Microsoft's tenant-to-tenant tooling or a third-party like BitTitan or AvePoint. Want me to lay out the options?"

---

## SP 2013 specifically

The On-Prem → SPO agent's playbook scripts were built against **SP 2016 / 2019 / Subscription Edition** and migrate **content only** (document libraries, MySite/OneDrive contents) — not site collection structure, navigation, or customizations. SP 2013 content may work via the playbook but isn't tested.

**Important — what NOT to say about SP 2013:**
- ❌ "SP 2013 has feature gaps that prevent migration" — wrong. SPMT officially supports SP 2013 sources.
- ❌ "You need a third-party GUI tool" — not required. SPMT standalone handles it.
- ❌ "Migrate the site" — these playbooks migrate **content**, not site collections.

If a customer asks about SP 2013:

**Concierge response template:** "These playbooks orchestrate **content migration** (libraries, MySites/OneDrive content) and are tested against SharePoint 2016, 2019, and Subscription Edition. SharePoint 2013 isn't covered by the orchestration, but SPMT itself officially supports SP 2013 as a source — so the content is migratable, just not through this layer. The likely path is one of:
1. **Use SPMT standalone** for SP 2013 content → SPO (no driver-list orchestration, but it works)
2. **Upgrade SP 2013 → SP 2016+ first**, then use this playbook for the orchestrated run
3. **Use ShareGate or AvePoint** if you need full federal-IL5/IL6 doesn't matter
Want me to lay out the tradeoffs?"

---

## SaaS / vendor-cloud scenarios

If the customer says the source is in a non-Microsoft SaaS (Google Drive, Dropbox, Box):

- **Not in scope for these scripts** — they assume on-prem SharePoint or on-prem UNC sources.
- **Recommend:** Microsoft Mover replacement (Microsoft has no direct replacement; vendor options include BitTitan, ShareGate, AvePoint).
- **For Google Workspace specifically:** Microsoft's own Google Drive migration in M365 Admin Center.

**Concierge response template:** "This playbook handles on-prem SharePoint, on-prem MySites, and UNC file shares as sources. For Google Drive / Dropbox / Box, you'd use Microsoft's migration manager in M365 admin center, or a third-party like ShareGate or AvePoint. Want help thinking through that path?"

---

## "Just give me the scripts" scenarios

If a customer wants the scripts but not the wrapper:

- **The scripts are runnable standalone.** They expect SPMT installed, the SPO list provisioned, and the credentials prompts.
- **But:** without the surrounding playbook (SPO list schema, Power Automate flow, app registrations), they're scripts in a vacuum. Operators have to build out the orchestration.

**Concierge response template:** "You can run the scripts standalone — they're just PowerShell — but you'd need to set up the SharePoint list they read from, the Power Automate flow that notifies users, and the app registrations they auth with. That's most of the playbook. If you want to deploy the full thing, the Launch Kit doc has the setup checklist."

---

## "Why is this free?" scenarios

If the customer is surprised this isn't a commercial product:

- **It's internal IP** from federal-focused customer engagements.
- **SPMT is free** because Microsoft ships it for on-prem-to-SPO migration.
- **The wrapper is owned by [the engineering team] but distributed freely** as part of customer deliverables; no licensing.
- **No commercial support SLA** — internal support model. If you need 24/7 vendor support, that's a reason to use ShareGate or AvePoint instead.

**Concierge response template:** "SPMT is Microsoft's free on-prem-to-SPO migration engine. The wrapper around it is internal IP from federal engagements — it ships with the project, no licensing. Tradeoff: no vendor SLA. If you need 24/7 commercial support, ShareGate or AvePoint are the typical alternatives."

---

## Refuse-and-route response template

When a request is genuinely out of scope (not just "route to a specialist"):

> "That's not in my scope. This playbook covers on-prem SharePoint → SPO, per-user OneDrive (from MySites or H: drive), and shared/common UNC drives → Teams/SPO — all single-tenant. For [the user's scenario], your options are typically [list 1-2 alternatives]. Want me to dig into one of those?"

---

## Common false routes to avoid

| User asks about | Don't route to | Route to |
|---|---|---|
| "Migrate Teams chat" | Common Drive (just because it mentions Teams) | Out of scope; recommend M365 cross-tenant tooling |
| "SP 2013 site" | OnPrem agent (untested for this version) | Flag the version gap; offer upgrade or SPMT-direct alternatives |
| "Cross-tenant OneDrive" | OnPrem or H: Drive agent (they're single-tenant) | Out of scope; recommend Microsoft T2T or BitTitan |
| "Move a single file" | Any specialist | Tell them this is for bulk migration; one file is faster via Web UI |
| "Set up a new SPO site" | Any specialist | Out of scope; recommend PnP or Admin Center |
| "Backup OneDrive" | H: Drive agent (it migrates OneDrive) | Out of scope; recommend OneDrive backup tools or governance retention |
| "Restore deleted files in OneDrive" | Any specialist | Out of scope; recommend OneDrive recycle bin / Microsoft Purview |
