# Troubleshooting — Common Drive → SPO

## Error code → diagnosis → fix

| Symptom in `Log` / `ScriptError` | Likely cause | Fix |
|---|---|---|
| `STORAGE_INSUFFICIENT_3YR` | Even 3-year horizon won't fit | Request quota increase OR shrink source OR split into multiple rows |
| `STORAGE_DOWNGRADED_TO_5YR` / `TO_3YR` | Auto-downgrade triggered | Normal — `YearUsed` reflects choice; SPMT filters source by `LastWriteTime` |
| `CHANNEL_FOLDER_MISSING` | Phase 1 of UMT wasn't run for this Team | Re-run UMT Phase 1 (interactive) for this row's TeamName |
| `GRAPH_NOT_ADMIN` | Phase 1 attempted in app-only context | Phase 1 needs delegated admin; re-run as a human |
| `SCA_GRANT_FAILED` | Phase 2 couldn't add `svc-migration` as SCA | Verify SPO Admin app has `Sites.FullControl.All`; cert valid |
| `THROTTLE` | SPO 429 | 18-app design usually avoids this. If sustained: reduce active worker count, spread across cert thumbprints |
| `CLAIM_STALE_RELEASED` | Auto-release after 24h | Inspect why prior runner died; re-run |
| `MigrationStatus = StagedWithErrors` | Stage pass had per-file errors | Inspect SPMT report; decide: accept and migrate, or fix source first |
| `MigrationStatus = ErrorLog` after Migrate | Per-file errors during delta/cutover | Use `Retry-FailedMigration.ps1` |
| `0-byte at target` | Silent SPMT failure | `Retry-FailedMigration.ps1` detects this; will re-upload |
| Row skipped this run | Scheduling window says no | Check `TimeZone`, current time, size vs 10GB threshold, `ExtendedHours` flag |
| Row stuck in `Migrating` past `MaxRuntime` | Worker crashed | Clear `ClaimedBy` + `ClaimedAt`; reset `MigrationStatus` to `Staged` or `Ready` |
| `Migrate` set to "Pending" by intake person | Wrong value — script expects blank | Clear the column (intake script leaves it blank intentionally) |
| Teams channel folder created with wrong name | `TeamChannel0` text mismatch | Phase 1 matches case-insensitively but exact text; fix and re-run Phase 1 |
| Storage scan returned 0 for all 3/5/7yr | Source UNC unreachable or empty | `Test-Path` source; verify Kerberos; verify no `$` hidden share issue |

## Common gotchas

1. **UMT has TWO phases.** Phase 1 is interactive Graph (Team owner + channel provision). Phase 2 is app-only SPO Admin (storage + SCA). Running just one is incomplete.
2. **36 apps = 1 + 6 + 18 + 11.** Don't say "36 SPO apps" — they're not interchangeable. Use the right app for the right script.
3. **`Migrate` column starts BLANK** after `Import-MigrationSources.ps1`. Intake people often "helpfully" set it to "Pending" — that's wrong. The state machine expects blank or `Ready`.
4. **Storage auto-downgrade is silent.** Watch `YearUsed`. If it says `3`, SPMT will skip files older than 3 years from source. Communicate this to the data owner.
5. **Scheduling window is LOCAL to `TimeZone`.** A row tagged `PST` is evaluated against PST clock, not server clock.
6. **`ExtendedHours = Yes` overrides BOTH the night window and the ≥10GB weekend-only rule.** Use carefully.
7. **`ClaimStaleHours = 2` means a 1h45m-stuck row stays stuck for the rest of the window.** If a server crashes hard and you can't wait the remaining minutes, manually clear `ClaimedBy` / `ClaimedAt` rather than waiting for auto-release.
8. **18 SPMT worker apps each carry their own throttle bucket.** A single misconfigured app reg → throttle hot spot. Verify all 18 distinct app GUIDs in worker config.
9. **Retry handles both report formats AND 0-byte.** Don't write your own retry — `Retry-FailedMigration.ps1` is the source of truth.
10. **`-DeleteSource` is dangerous.** Only used by `Retry-FailedMigration.ps1` and only after target verification. Don't enable on the orchestrator.

## "How do I prove the wave worked?"

1. Driver list filter `MigrationStatus = Migrated`, count matches expected.
2. Random spot-check: 5 rows, verify target Teams channel / SPO site holds source content, file counts match `YearUsed` horizon.
3. SPMT reports show 0 blocking errors for the spot-checked rows.
4. Power Automate notification flow logs show user emails sent.
5. Dashboard page (`New-MigrationDashboard.ps1` output) shows expected counts per stage.

## Rollback

- All content is COPIED, not moved. Source UNCs are untouched unless someone ran `Retry-FailedMigration.ps1 -DeleteSource`.
- To roll back a Team / site: communicate with users, then remove the target Team / site (SCA grant means you have the rights).
- Demote `svc-migration` from M365 Group Owner / SCA if rollback is permanent.

## When to escalate

- Phase 1 Graph fails for everyone → Graph admin consent revoked or delegated permission policy changed.
- Tenant-wide throttle even with 18-app spread → Microsoft support ticket.
- Storage capacity blocked at tenant level → tenant admin quota request.
