# H: Drive → OneDrive — Workflow

This document describes the script-accurate workflow for `Hdrive-OneDriveScript`
(v5.2). The script migrates per-user network home drives from
`\\server\users\<sam>` to OneDrive `/Documents/HDrive`, and performs an AD
cutover on success.

The script has two operational modes driven by the row's `Migrate` column:

- **Stage** — content copy only, no AD changes. Used as a pre-pass to seed
  data without affecting the user.
- **Migrate** — full migration: content copy, then My Documents reorg, AD
  cutover, and source lockdown.

```mermaid
flowchart TD
    Start([Script start]) --> Boot[Bootstrap:<br/>Ensure-Module SPO/SPMT/AD/PnP<br/>Set-RequiredRegistryKeys<br/>LongPathsEnabled, BlockLongPaths]
    Boot --> Trans[Start-Transcript:<br/>F:\SPMTTranscripts\Log_SERVER_TIMESTAMP.log]
    Trans --> Cred{SPMTCred.xml<br/>cached?}
    Cred -->|Yes| Load[Import-Clixml SPMTCred.xml<br/>DPAPI-decrypted]
    Cred -->|No| Prompt[Get-Credential prompt]
    Prompt --> Save[Export-Clixml SPMTCred.xml<br/>DPAPI-encrypted]
    Save --> Menu
    Load --> Menu[Interactive picker:<br/>SPO list OR CSV file<br/>NEW / STAGED / MIGRATED]
    Menu --> Conn[Connect-PnPOnline to driver list<br/>w/ throttle retry 3x 15s]
    Conn --> Pull[Get-PnPListItem<br/>pageSize 500-2000]
    Pull --> Filter[Filter rows:<br/>Migrate IN Stage, Migrate<br/>skip Migrated/Processing/blank]
    Filter --> Loop{For each<br/>queued user}
    Loop --> PP{Postpone field<br/>has future date?<br/>6 spellings checked}
    PP -->|Yes| Skip[Skip silently]
    Skip --> Loop
    PP -->|No| UPN{UPN present<br/>and valid?}
    UPN -->|No| BadUPN[Migrate = Invalid UPN]
    BadUPN --> Loop
    UPN -->|Yes| Lic{User in license group<br/>O365S-AddOn-License?}
    Lic -->|No| Unlic[Migrate = Unlicensed]
    Unlic --> Loop
    Lic -->|Yes| Resolve[Resolve SAM to UPN<br/>build OneDrive URL]
    Resolve --> Prov{OneDrive<br/>already provisioned?}
    Prov -->|No| Req[Request-SPOPersonalSite<br/>retry 3x backoff 60/120/180s]
    Req --> Verify[Verify-OneDriveProvisioning<br/>poll Get-SPOSite until ready]
    Prov -->|Yes| SCA02
    Verify --> SCA02[Set-SPOUser SCA02<br/>OneDriveAdminGroup as SCA]
    SCA02 --> SpecQ{Row marked<br/>SpecialGroup = Yes?}
    SpecQ -->|Yes| SCA03[Add SCA03 SpecialGroup as SCA]
    SpecQ -->|No| Mark
    SCA03 --> Mark
    Mark[Stamp Processing = Processing<br/>StartDate, Server = COMPUTERNAME]
    Mark --> SPMT[Register-SPMTMigration<br/>-SkipFilesWithExtension .pst<br/>-ReplacementOfInvalidChar _<br/>-MigrateWithoutRootFolder]
    SPMT --> AddT[Add-SPMTTask<br/>UNC \\server\users\sam<br/>to OneDrive /Documents/HDrive]
    AddT --> RunS[Start-SPMTMigration<br/>throttle retry 5x 10-300s]
    RunS --> Reports[Consolidate reports:<br/>TaskReport folders<br/>ItemReport_R1*.csv<br/>FailureSummaryReport2.csv<br/>FatalError_*.csv]
    Reports --> Result{Status?}
    Result -->|Success no errors| OK1[Migrate = Migrated<br/>LOG, CompletedDate stamped<br/>FailureSummaryReport2.csv attached]
    Result -->|Per-file errors<br/>attach succeeded| Err1[Migrate = ErrorLog<br/>ItemReport_R1.csv attached]
    Result -->|Per-file errors<br/>attach FAILED| Manual[Migrate = ManualLog]
    Result -->|Fatal errors detected| FatalP[Parse FatalError_*.csv<br/>append categorized<br/>error to ScriptError]
    Result -->|Hard failure| Fail[Migrate = Failed<br/>Processing cleared<br/>row eligible for retry]
    OK1 --> ModeChk{Was this a<br/>Stage pass?}
    ModeChk -->|Yes| Staged[Migrate = Staged<br/>or StagedWithErrors<br/>STOP - no AD changes]
    Staged --> Loop
    ModeChk -->|No, full Migrate| Reorg[Move-MyDocumentsContent<br/>flatten /Documents/My Documents<br/>into /Documents<br/>hierarchy preserved<br/>throttle-aware, mid-op reconnect]
    Reorg --> ADcut[AD cutover:<br/>Set-ADUser wwwHomePage = OneDrive URL<br/>Remove from each RedirectGP group<br/>multi-group, comma/newline split]
    ADcut --> Lockdown[Start-Job Set-Acl<br/>H: source = ReadAndExecute<br/>separate PS process<br/>does not block loop]
    Lockdown --> Flag[Stamp HReadOnly = Updated<br/>Redirect = Updated]
    Flag --> Loop
    Err1 --> Loop
    Manual --> Loop
    FatalP --> Loop
    Fail --> Loop
    Loop -->|All processed| Cleanup[Stop SPMT migrations<br/>kill Microsoft.SharePoint.Migration* procs]
    Cleanup --> EndT[Stop-Transcript]
```

---

## State management notes

- **Processing flag** is cleared only on the `Failed` path so the row is
  retryable. Success / ErrorLog / ManualLog / Fatal paths leave it set and
  write a terminal `Migrate` value instead.
- **SPO connection** is re-established after errors via `Ensure-PnPConnection`,
  with a `$script:PnPConnectionCache` keyed by URL to keep reconnects cheap.
- **SPMT session** is properly disposed even on failure (cleanup at end of run
  also stops migrations and kills `Microsoft.SharePoint.Migration*` processes).
- **SCA cleanup:** the script **adds** SCA02 (`OneDriveAdminGroup`) and
  optionally SCA03 (`SpecialGroup` when the row sets `SpecialGroup = Yes`) but
  does **not** remove them post-migration. Clean up manually with
  `Remove-SPOUser` if your governance requires it.
- **AD group flips — what actually happens:**
  - The script **removes** the user from every group listed in the row's
    `RedirectGP` column (multi-group, comma- or newline-separated).
  - The script **adds** the user to `$targetGroup` (`SecFltr-USR-Office365`)
    on success via `Add-ADGroupMember`.
  - The script **only validates** that the user is a member of the license
    group `$targetGroup2` (`O365S-AddOn-License`) and sets `Migrate =
    Unlicensed` (skipping the row) if not. It does NOT add to the license
    group — the license grant must happen upstream of the migration.
- **Stage mode stops before AD cutover** — the `Staged` / `StagedWithErrors`
  terminal states do not perform My Documents reorg, AD changes, or source
  lockdown. Re-run the row with `Migrate = Migrate` to complete the cutover.
- **ACL changes** run in a separate PowerShell process so a slow ACL walk does
  not block the user loop.
- **Throttle handling:** `Handle-SPOThrottling` (5x, 10–300s, honors
  `Retry-After` headers) wraps PnP connections, list reads, SPMT calls, and
  per-item content moves.
- **Long-path support:** registry keys `LongPathsEnabled=1`,
  `BlockLongPaths=0`, `UseLegacyPathHandling=0` are set on bootstrap.
- **Audit trail per row:** `StartDate`, `CompletedDate`, `Server`, `LOG`,
  `ScriptError` (categorized: LICENSE / UPN / ONEDRIVE PROVISIONING /
  ATTACHMENT / CONTENT MOVE / AD / SITE ADMIN / FATAL / GENERAL), `HReadOnly`,
  `Redirect`, plus `FailureSummaryReport2.csv` and `FatalError_*.csv`
  attached to the row.
