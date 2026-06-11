# Copilot Studio Agent Package — Session Recovery Notes

**Date:** 27 June 2026
**Version stamped:** 1.0 (June 2026)
**Purpose:** Capture state in case the chat session is lost. Everything below is a verification + correction pass against the actual `.ps1` source code in `CopilotStudio-scripts-4agent/`.

---

## What this package is

A Copilot Studio multi-agent build for Cloud Solution Architects (CSAs) covering Doug's three migration playbooks:

| Silo | Playbook | Folder |
|---|---|---|
| Concierge | Router (no Knowledge) | `01-Concierge/` |
| On-Prem → SPO | 2024 (OD2OD + SP2SPO) | `02-OnPrem2SPO-Agent/` |
| H: Drive → OneDrive | 2025 (per-user home drives) | `03-HDrive-Agent/` |
| Common Drive → SPO | 2026 (UNC shares → Teams channel or SPO site) | `04-CommonDrive-Agent/` |

Architecture: Cloud Migrate Pro Concierge → 3 Connected child agents, each siloed with its own Knowledge folder. **No cross-contamination** between silos.

Cloud portability: built/proven in IL6 (`microsoft.scloud`), ports to commercial (`.sharepoint.com`) / IL5 GCC-H (`.sharepoint.us`) / DoD (`.sharepoint-mil.us`) by host-suffix swap only.

Knowledge upload constraint: `.ps1` rejected by Copilot Studio — rename copies to `.txt` (content unchanged). See `05-Porting-to-CopilotStudio.md`.

---

## What was done THIS session (verification pass)

User demand: **"verify the system prompts match the scripts... full feature sets of each script must be included."** Dispatched three parallel Explore subagents to audit each silo against the actual `.ps1` source. The audits found extensive gaps; every gap is now fixed.

### OnPrem 2024 silo — corrections applied

Files: [02-OnPrem2SPO-Agent/system-prompt.md](02-OnPrem2SPO-Agent/system-prompt.md), [knowledge-cards.md](02-OnPrem2SPO-Agent/knowledge-cards.md), [workflows.md](02-OnPrem2SPO-Agent/workflows.md), [topics.md](02-OnPrem2SPO-Agent/topics.md)

| Issue | Fix |
|---|---|
| Sleep claimed uniform 120s | Now **OD2OD = 30s, SP2SPO = 120s** |
| Lock column claimed uniform `Processing` | Now **OD2OD = `Inprocess`, SP2SPO = `Processing`** |
| Log column wrong (`MigrationLog`) | Now `Log` |
| Phantom `TimeZone` column | Removed; explicit note "no TimeZone here — Common Drive only" |
| AD updates shown as always-on | Flagged **commented out by default** (wwwHomePage, *REDIRECTION*, SecFltr-USR-OneDrive, SecFltr-USR-Office365) |
| SCA swap (3-step) missing | Documented: ensure svc-migration → make SCA → demote user |
| Power Automate misattributed (script emails) | Corrected: script attaches CSV + sets `ErrorLog`; flow watches list |
| Missing `ErrorLog` as distinct state | Documented |
| DLL load step + path divergence | Added: OD2OD = `F:\Tools\`, SP2SPO = `F:\IAU_Scripts\OneDrive_Migration_Scripts\` |
| ~50 blocked extensions concept | Mentioned |

### HDrive 2025 silo — corrections applied

Files: [03-HDrive-Agent/system-prompt.md](03-HDrive-Agent/system-prompt.md), [knowledge-cards.md](03-HDrive-Agent/knowledge-cards.md), [workflows.md](03-HDrive-Agent/workflows.md), [topics.md](03-HDrive-Agent/topics.md)

| Issue | Fix |
|---|---|
| **CRITICAL: "Removes the temporary SCAs" was FALSE** | Now correctly documented: script **adds SCA02 (and SCA03 if SpecialGroup=Yes) but NEVER removes them**. Manual cleanup with `Remove-SPOUser` if needed. |
| SCA03 shown as always-added | Now correctly conditional on `SpecialGroup = "Yes"` |
| Phantom `TimeZone` column in prereqs | Removed |
| Column name wrong (`MigrationLog`) | Now `LOG` |
| Missing: 6 postpone-spelling variations (`Postpone`, `PostPone`, `postpone`, `POSTPONE`, `Postponed`, `DelayUntil`) | Documented + topic node |
| Missing: RedirectGP multi-group parsing (newline + comma) | Documented + topic node |
| Missing: Move-MyDocumentsContent (flatten `/Documents/My Documents`) | Documented + topic node |
| Missing: ACL changes run as **separate PS process** (HReadOnly = Updated) | Documented + topic node |
| Missing: ManualLog vs ErrorLog vs Fatal distinction | Full status table added |
| Missing: ScriptError categorization (LICENSE / UPN / ONEDRIVE PROVISIONING / ACCESS / THROTTLE) | Documented |
| Missing: CSV picker menu (NEW/STAGED/MIGRATED + opt 5 clears creds) | Mermaid + lifecycle |
| Missing: retry/backoff (3x 60/120/180s OneDrive provisioning, 5x 10-300s throttle) | Documented |
| Missing: PnP connection cache, Set-RequiredRegistryKeys, Server column, `@("pst")` blocked | All added |
| Wrong "Processing cleared on every error" | Corrected — only on `Failed` path |
| Wrong "email user" on error path | Removed (HDrive script doesn't email) |

### CommonDrive 2026 silo — corrections applied (largest scope)

Files: [04-CommonDrive-Agent/system-prompt.md](04-CommonDrive-Agent/system-prompt.md), [knowledge-cards.md](04-CommonDrive-Agent/knowledge-cards.md), [workflows.md](04-CommonDrive-Agent/workflows.md), [topics.md](04-CommonDrive-Agent/topics.md)

| Issue | Fix |
|---|---|
| **App count claim wrong** ("36 SPO apps") | Now correctly **1 Graph + 6 SPO Admin + 18 SPMT worker + 11 Helper = 36 total** |
| **MISSING: entire scheduling subsystem** | Added: `-UseScheduling`, TimeZone (EST/CST/MST/PST/AKST/HST/ANYTIME), Priority, QueuedAt, ExtendedHours, 5pm-6am weekday window + 24h weekend/holiday, Large Migration Threshold ≥10GB weekends-only |
| **MISSING: storage auto-downgrade** | Added: `Size3YrMB / Size5YrMB / Size7YrMB` from scan → Phase 2 tries 7yr→5yr→3yr → stamps `YearUsed` → SPMT filters by mod-date |
| **MISSING: full state machine** | Added: blank → Ready → Stage → Staged / StagedWithErrors / MigrateOnly → Migrating → Migrated / ErrorLog / Failed |
| **MISSING: UMT Phase 1 vs Phase 2** split | Documented: Phase 1 INTERACTIVE delegated Graph (resolves Team/Channel, adds svc-migration as M365 Group Owner, auto-provisions channel folder) vs Phase 2 AUTOMATED app-only SPO Admin (storage check + auto-downgrade + SCA grant) |
| **MISSING: multi-server claim locking** | Added: `ClaimedBy` / `ClaimedAt` / `ClaimStaleHours = 24` |
| **MISSING: advanced parameters** | All documented: `-UseScheduling`, `-MigrationType Stage|Migrate|MigrateOnly|Both`, `-Continuous`, `-MaxRuntime`, `-MaxItems`, `-AppClientIdParam`, `-AppCertThumbprintParam` |
| Retry-FailedMigration incomplete | Now: accepts `ItemReport_R1.csv` AND `ItemFailureReport_*.csv`, detects 0-byte uploads, verify-before-delete |
| Dashboard incomplete | Now: `Scanned` = cumulative; pipeline stages (Awaiting Scan/Awaiting Target/Resolved/Queued/Migrating/Complete) |
| Landing Page incomplete | Now: auto-discovers divisions, creates per-DIV filter views |
| Import-MigrationSources wrong ("sets Migrate=Pending") | Corrected: leaves `Migrate` BLANK |

---

## Files unchanged this session (already complete)

- `00-README.md` — CSA acronym, v1.0 stamp
- `01-Concierge/system-prompt.md` — CSA, Doug Cox removed, v1.0
- `01-Concierge/topics.md`, `01-Concierge/welcome-card.json`
- `05-Porting-to-CopilotStudio.md` — rewritten for current Copilot Studio UI, .ps1→.txt rename instructions, silo notes, v1.0
- `06-Launch-Kit.md` — v1.0 stamped

---

## Pre-session context (carried forward)

- **Cloud Solution Architect** (CSA) — confirmed acronym, used everywhere
- **Doug Cox** name removed from all 4 system prompts (sanitization)
- **v1.0 (June 2026)** stamped in 7 places
- **Cloud portability** sections added to 3 system prompts + 3 knowledge-cards (commercial / IL5 GCC-H / IL5 DoD / IL6 endpoint mapping table)
- User has verified Copilot Studio permissions (create agents, publish, Teams + M365 channel)
- Copilot Studio UI: Build/Preview/Evaluate/Monitor tabs; right rail Skills/Tools/Knowledge/Connected agents; model picker top-right (Claude Sonnet 4.6); Teams+M365 combined publish channel

---

## Sanitized placeholders used across all silos

| Placeholder | Replace with |
|---|---|
| `contoso.spo.microsoft.scloud` | Your tenant SPO host |
| `contoso-admin.spo.microsoft.scloud` | Your SPO Admin host |
| `contoso-my.spo.microsoft.scloud` | Your SPO OneDrive host |
| `onedrive.contoso-onprem.local` | Your on-prem MySite host |
| `@contoso.gov` | Your UPN domain |
| `svc-migration@contoso.gov` | Your migration service account |
| `/sites/000001` | Your driver-list site |
| `aaaaaaaa-aaaa-...` (tenant) | Your tenant ID |
| `bbbbbbbb-...` / `cccccccc-...` / `dddddddd-...` (apps) | Your Entra app IDs |
| `eeeeeeee-...` / `ffffffff-...` (SCA group claims) | Your AD/Entra group object IDs |

---

## Next actions (when resuming)

1. **User reviews** the three corrected silos one at a time, OnPrem first (per user instruction: "one silo at a time so you can review").
2. After approval, **rename `.ps1` → `.txt`** for Knowledge upload (per [05-Porting-to-CopilotStudio.md](05-Porting-to-CopilotStudio.md)).
3. **Build agents** in Copilot Studio (Concierge first, then 3 child agents, then wire Connected Agents).
4. **Publish** to Teams + M365.

---

## Audit reports (saved in chat workspace storage)

If the audit findings need to be re-read:

- OnPrem audit: `c:\Users\docox\AppData\Roaming\Code\User\workspaceStorage\a756c78afdc25030b1770e2ab14de988\GitHub.copilot-chat\chat-session-resources\64a6ac56-c562-4299-af80-c3f8515a8eae\toolu_01LrSfVBCJntDtwAfud5NQGM__vscode-1779897081114\content.txt`
- HDrive audit: `...toolu_01Us4FoVef66LcbydqdTNcjq__vscode-1779897081115\content.txt`
- CommonDrive audit: `...toolu_01D1JB19osLoZuNHuuKTxyf7__vscode-1779897081116\content.txt`
- Full chat transcript: `c:\Users\docox\AppData\Roaming\Code\User\workspaceStorage\a756c78afdc25030b1770e2ab14de988\GitHub.copilot-chat\transcripts\64a6ac56-c562-4299-af80-c3f8515a8eae.jsonl`

---

**Status as of save:** All 12 agent-package files (3 silos × 4 files each) verified against source scripts and corrected. Ready for user review.
