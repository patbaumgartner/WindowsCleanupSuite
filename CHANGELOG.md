# Changelog

All notable changes to WindowsCleanupSuite will be documented in this file.

## [1.0.0] - 2026-11-21 - self-executing launcher

- **Launcher.ps1** — self-executing, curl-friendly download-and-run (the Raphire/Win11Debloat
  style): `irm https://raw.githubusercontent.com/patbaumgartner/WindowsCleanupSuite/main/Launcher.ps1 | iex`
  fetches the latest GitHub Release zip, extracts it to `%TEMP%\WindowsCleanupSuite` and launches the menu.
  (GitHub API unavailable from this sandbox - verified: curl.exe to api.github.com fails.)

## [1.0.0] - 2026-11-21 (final)

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this
project adheres to [Semantic Versioning](https://semver.org/) (`1.x` era; 1.0.0 = first publishable release).

## [Unreleased]

## [1.2.1] - 2026-11-24 - hotfix: updates + re-debloat argument binding

### Fixed
- **Menu action 3 (updates + re-debloat) crashed after updating** with
  `Cannot process argument transformation on parameter 'MaxParallel'`:
  `Invoke-WCSDebloatAfterUpdates` passed `-Topics <csv>` via ARRAY splatting after named
  parameters, which binds positionally - the topic list landed on `MaxParallel` and the
  re-debloat never ran. Now uses HASHTABLE splatting (`$menuArgs['Topics']`), so the user's
  selected topics/risky flag bind correctly in both the preview and the `-Apply -AutoApprove`
  paths. Regression test replays the exact action-3 call shape end-to-end.

## [1.2.0] - 2026-11-24 - parallel previews, quick mode, scheduler prefs, backup review

### Added
- **Parallel previews** — in preview mode (`-WhatIf`) the topic scans now run concurrently in a
  Windows PowerShell 5.1-compatible runspace pool instead of one-after-another. Escape hatches:
  `-NoParallel` (force sequential) and `-MaxParallel <n>` (default 4). Apply mode (`-Apply`) always
  stays sequential and single-job runs fall back to sequential automatically. Measured on the dev
  machine (Win 11, non-admin): full Level 2 preview exits 0 in **~166s vs ~476s sequential**
  (~2.9x faster). Header line shows `Mode: PREVIEW +parallel`.
- **`-Quick` topic-only fast preview** — preview-only switch (`-Apply -Quick` is rejected with
  exit 1) threaded into the three heaviest cleanups: `InstalledSoftware` builds a single-pass
  uninstall index and skips the provisioned-package scan, `TempAndJunkFiles` skips the recursive
  FilePatterns scan, `ServicesAndTasks` probes exact service/task names directly and skips the
  OneDrive pattern scan. Header line shows `+quick`.
- **Scheduled re-runs honor the `AutoReRunDays` preference** — `Register-WCSReRunTask -Days -1`
  resolves `AutoReRunDays` from `Config\UserPreferences.json` (fallback 7), `-Days 0` unregisters
  `WindowsCleanupSuite_ReRun`, N>=1 registers it (as SYSTEM, admin-gated, `-WhatIf`-previewable).
  The task command line is built from the stored Level/Topics preferences (fallback
  `-NonInteractive -Level 4 -Apply -AutoApprove`). Wired into menu action 4 (prompt defaults to
  the pref) and the new `-ScheduleDays` CLI switch; `Save-WCSPreferences` preserves an existing
  `AutoReRunDays` value.
- **Interactive backup review before restore** — new `Tools\Review-WCSBackup.ps1`
  (`-List` non-interactive listing, interactive picker, optional admin-gated restore at the end)
  backed by the new engine helper `Get-SuiteBackupReview` in `Core\CleanupEngine.ps1`. Wired into
  menu action 5 and the new `-ReviewBackups` CLI switch. Verified: `-ReviewBackups` lists all
  backup records and exits 0.
- **Tests** — `Tests\Invoke-SuiteTests.ps1` section 9 covers the parallel runner (runspace pool,
  fallbacks), `-Quick` dispatch and per-cleanup quick paths, the scheduler (`AutoReRunDays`
  resolution, task command line, `-WhatIf` register/unregister, admin gate) and the review tool.

### Fixed (deep-review hardening, full-suite + real-machine verified)

- **Preview safety (AppX)**: UWP and provisioned-package removals are now `$PSCmdlet.ShouldProcess`-gated
  (`Remove-AppxPackage`/`Remove-AppxProvisionedPackage` have no usable `-WhatIf`) - a preview can no
  longer remove apps. Provisioned scan is PS 5.1-compatible (`Get-AppxProvisionedPackage` has no
  `-AllUsers`), removes by `PackageName` (not `DisplayName`), records `PackageName` in backups, and
  the restore explicitly lists provisioned records as not auto-restorable (Store reinstall).
- **Original backups are never overwritten** (`New-SuiteBackupFile` + visual-effects backup): repeated
  runs (incl. scheduled re-runs) used to replace the original state with the already-debloated state,
  breaking restore. Registry values/service start types that already match the target are skipped.
- **Restore fidelity**: generic registry records capture `PreviousType` (old value kind) and restores
  prefer it (`Restore-SuiteRegistryRecords`, `Tools\Restore-WCSBackup.ps1`, `Restore-WindowsAI.ps1`);
  `Restore-WindowsUpdates.ps1` uses the type-preserving engine helper; scheduled-task restore prefers
  the recorded `Enabled` flag over lossy `State`; AppModel startup backups record value existence and
  restore `LastDisabledTime` as QWORD; visual-effects restore removes originally-absent values;
  `Set-WCSRegistryEntry` records `NewValue` so the review tool shows `old -> new` correctly.
- **PowerPlan**: activates the GUID returned by `powercfg -duplicatescheme` (previously activated the
  SOURCE scheme), records previous active scheme + hibernation state (`powerplan_state.json`), checks
  powercfg exit codes, and restore reactivates the previous scheme and hibernation ON/OFF.
- **Network/DNS**: backups record `WasStaticDns` (static DNS via the interface `NameServer` value, not
  the IPv4 DHCP state) - restore no longer discards manually configured DNS on DHCP interfaces.
- **TempAndJunkFiles**: `%PROGRAMDATA%\Package Cache` removed from junk targets (installer payloads
  needed for repair/uninstall); system dirs/event logs/defrag are admin-gated; partial deletions are
  reported as warnings instead of "Cleaned".
- **Admin gating**: interactive action 2 was missing the admin check (partial apply); Network/
  InstalledSoftware/PowerPlan restores and PowerPlan hibernate-off are gated; `Check-SystemHealth`
  repair steps (DISM RestoreHealth, sfc) are hard admin-gated (ScanHealth stays read-only).
- **Apply safety**: `-Apply` requires a typed YES confirmation unless `-AutoApprove` (automation and
  the scheduled task already pass it), and aborts when no System Restore point can be created instead
  of applying without a safety net; a missing selected cleanup script aborts the run (no partial apply).
- **Honest exit codes**: the sequential runner captures non-terminating errors (`-ErrorVariable`),
  engine mutation/restore failures now emit `Write-Error`, `Restore-SuiteServiceRecords` no longer
  prints "Restored" after a failed `Set-Service`, and `Tools\Restore-WCSBackup.ps1` propagates
  per-record failures to its exit code. Restore is single-owner (generic pass covers only orphan
  folders - records were previously restored twice), and its RestorePoint mode reads
  `$WhatIfPreference` (the `$WhatIf` variable does not exist).
- **Scheduler hardening**: SYSTEM task prefers the machine-wide System32 Windows PowerShell (not a
  user-writable pwsh), runs with `-NoProfile -ExecutionPolicy Bypass` (unsigned scripts on Restricted/
  AllSigned machines), validates stored Level/Topics against the catalog (no argument injection from
  preferences), refuses registration when the prefs file exists but is unreadable (no silent
  `-Level 4` fallback), and `-ScheduleDays` now works with `-WhatIf` (both entry scripts support it).
- **Updates**: post-update re-debloat forwards the user's Topics/AllowRisky instead of applying every
  level-default topic. Preferences are written atomically (temp file + replace).
- **Launcher**: preserves `Backups`/`Config`/`Logs` across re-runs (migrates them into the fresh
  extraction), refuses to wipe directories that are not a previous suite installation, sanitizes
  archive file names (branch slashes, URL query/fragment), and extract-only mode exits 1 when no
  menu was extracted. `Audit-State` compares task `PathPattern` with `-like`; `New-WCSZip` uses
  `-LiteralPath`.
- **CI/release**: the structural suite now also runs under the Windows PowerShell 5.1 runtime,
  snapshot `.zip.SHA256` files are uploaded with the artifact, and the release workflow runs the
  test suite + 5.1 parse check before packaging. Tests: new section 10 regression checks for all of
  the above; the scheduler WhatIf test injects preferences (hermetic); the zip self-exclusion test
  actually inspects archive entries.

### Fixed
- **Apply mode crashed with `The term 'if' is not recognized`** in every cleanup using
  `Set-WCSRegistryEntry` (PrivacySettings, WindowsUpdates, PowerPlan): the backup record used
  `(if …)` — a statement inside parentheses — which parses as a *command invocation* and only
  throws at runtime (previews passed because `-WhatIf` returns before that line). The old
  value/type are now computed in plain statements first. Regression test scans all `.ps1` for
  statement-in-parens patterns (valid only as `$(…)`/`@(…)`).
- **Menu: Enter was ignored** — `Get-WCSMenuInput` retried on empty input up to `$MaxTries`
  times, so one Enter re-printed the prompt instead of accepting. Empty input is now returned
  immediately: Topics = accept selection, Level = accept the default (marked `*`), Actions = exit.
  The menu also now always exits explicitly (`exit 0` on success) so `Runners\Run-Menu.ps1`
  cannot inherit a stale `$LASTEXITCODE` from an earlier native command.
- **InstalledSoftware: one package failing with `Access is denied` aborted the whole script.**
  UWP/provisioned removal and the Win32 uninstaller start are now wrapped per-item; failures
  are warnings and the backup is kept.
- **Launcher: stale `%TEMP%\WindowsCleanupSuite` could mix old and new files** (the silent
  `Remove-Item` can fail on locked files, producing "Missing script" warnings). The old dir is
  now removed with retries and, if still locked, extraction falls back to a fresh timestamped
  directory; a sanity warning is printed if the extracted suite lacks `Cleanups\`/`Runners\`.
- **Registry backups never captured the old value** (restore was silently broken): two latent
  bugs in `Core\CleanupEngine.ps1`. (1) `Get-WCSRegistryValue` read the value via
  `.$Entry.Name`, which PowerShell parses as a *chained* member access
  `(($result).$Entry).Name` - i.e. a member named after the hashtable - so it always returned
  `$null` and every backup record got `OldExists=false`. Now `.($Entry.Name)` (same fix in
  `Cleanups\OneDrive\Disable-OneDrive.ps1`). (2) `Set-WCSRegistryEntry` declared
  `[ValidateSet(...)][string]$Type` - reading an *unbound* optional `[ValidateSet]` parameter
  throws "The variable cannot be validated..." on PS 5.1 and 7.x, so every caller that omits
  `-Type` (PrivacySettings, WindowsUpdates, PowerPlan) failed in apply mode. The parameter is
  now validated manually via `$PSBoundParameters`. Also fixed: the registry key is now created
  only when the *key* is missing (`Test-Path`), not when the *value* is missing (previously
  "A key in this path already exists"), and `Restore-WCSRegistryRecordValue` accepts
  PSCustomObject records (from `ConvertFrom-Json`) instead of requiring `[hashtable]`, and
  restores with the original value kind (`-Type $OldType`). Regression tests scan all `.ps1`
  files for both broken patterns.

### Fixed
- **Launcher one-liner docs**: the README/help showed `irm <url>` alone, which only *prints*
  the script and never executes it (on any PowerShell version) — that is why the "self-executing
  download" appeared not to work. Docs now show `irm <url> | iex` (Win11Debloat style) and a
  hardened curl variant (`curl.exe -L … -o …` + `powershell -NoProfile -ExecutionPolicy Bypass -File …`).
  Verified end-to-end on **Windows PowerShell 5.1.26100** and **PowerShell 7.1.5**: `-WhatIf` dry run,
  full release-zip download + extract, and `irm <url> | iex` all exit 0 and launch `Runners\Run-Menu.ps1`.

### Added
- **PS 5.1 compatibility guard**: new `Tests\Invoke-PS51ParseCheck.ps1` parses every `.ps1`/`.psd1`
  with the Windows PowerShell 5.1 parser; CI runs it via `powershell.exe` on every build and the
  test suite runs it when available. New tests also assert the one-liner docs use `| iex`, that
  `Launcher.ps1` contains no PS7-only operators (`??`, `?.`, `&&`, `||`), and that no script uses
  `$PSScriptRoot` inside a parameter default (it is empty there on PS 5.1 - this broke the CI
  parse step until fixed by resolving it in the script body).

### Fixed
- `$PSScriptRoot` in parameter default values is empty on Windows PowerShell 5.1 —
  `Tests\Invoke-PS51ParseCheck.ps1` and `Tools\New-WCSZip.ps1` now resolve it in the
  script/function body instead.

## [1.1.0] - 2026-11-22 - legacy entry points removed

### Removed

- **Legacy entry points deleted** (no backwards compatibility): `Runners\Run-Cleanup.ps1`, `Runners\Run-Monthly.ps1` and `Runners\Restore-All.ps1` are gone — `Runners\Run-Menu.ps1` is the only entry point (interactive or `-NonInteractive`). The `ServicesTasks` topic now runs `Cleanups\StartupBloat\Disable-StartupBloat.ps1`, `Cleanups\WindowsSpeedup\Disable-ServicesAndTasks.ps1` (profile from the level, `-LoginSafe` on) and `Cleanups\InstalledSoftware\Disable-InstalledSoftware.ps1` directly. The scheduled re-run task and the post-update re-debloat now call `Run-Menu.ps1 -NonInteractive -Level 4 -Apply`; restore-all is `Tools\Restore-WCSBackup.ps1 -Backups` (menu action 5). Menu action 7 (legacy Restore-All) was removed; `Invoke-WCSDebloatAfterUpdates` now takes `-Level` instead of `-Profile`.

### Fixed

- **Launcher.ps1**: GitHub API URL was built from the full repo URL (`api.github.com/repos/https://github.com/...` → 404) and there was no fallback when no release exists — the one-liner failed with "Could not resolve the latest release zip". Now uses `api.github.com/repos/patbaumgartner/WindowsCleanupSuite` and falls back to the `main` branch source archive (codeload) until the first `vX.Y.Z` release exists; added `-Branch`, forced TLS 1.2 for PS 5.1.
- **CI/docs branch drift**: `ci.yml` only triggered on `master` (default branch is `main`), README/CHANGELOG one-liners used `/master/` — all switched to `main`.
- **Menu apply mode**: `Core\WCS.Menu.ps1` passed `-Apply` to cleanup scripts that only support `-WhatIf` (ParameterBindingException); now apply = run without `-WhatIf`. Menu also forwards `-AllowRisky` to `Run-Cleanup.ps1`, passes `-Level` to `Disable-WindowsUpdates.ps1`, detects script failures via try/catch (not only `$LASTEXITCODE`), action 5 now calls `Restore-WCSBackup.ps1 -Backups`, and preferences are only rewritten when `-SavePreferences` is given. `Runners\Run-Menu.ps1` now accepts `-AllowRisky`/`-AutoApprove`.
- **Tools\Restore-WCSBackup.ps1**: dot-sourced the engine via `$PWD` (crashed unless CWD = suite root) → now `$PSScriptRoot`-based; bare invocation now defaults to `-Backups`; `-WhatIf` is forwarded to every `Restore-*.ps1` (previously ignored → would really restore); errors are no longer swallowed (`-ErrorAction SilentlyContinue | Out-Null`); generic registry restore now reads both backup schemas (`RegistryKey/HadPrevious` and `Path/OldExists`, `.json` and `.txt`); exit code 1 when any restore failed.
- **Backup schema alignment**: `Disable-WindowsAI.ps1` now writes `HadPrevious`/`ValueType` (engine schema) so `Restore-SuiteRegistryRecords` and the Tools restore can consume its records; `Restore-WindowsAI.ps1` creates missing keys and restores by recorded type (engine-consistent). `Enable-UltimatePerformancePlan.ps1` now backs up every registry tweak via `Set-WCSRegistryEntry` (incl. `SvcHostSplitThresholdInKB`), respects the manifest `Type` (String vs DWord), no longer aborts the whole script in `-WhatIf`, and hibernate on/off is ShouldProcess-gated. `Restore-PowerPlan.ps1` is a real restore now (restores backed-up values, re-activates Balanced plan, admin-gated) instead of setting everything to 0.
- **Disable-WindowsUpdates.ps1**: added `-Level` (1-4, default 4) so Safe/Balanced no longer apply Level-2 items (e.g. `HiberbootEnabled=0`); accepts both `Action` and `Mode` service keys.
- **InstalledSoftware**: `Webex VDI Plugin Installer Engine` is now `Kept = $true` like the other keep-list apps; Win32 backup records keep value types (Binary as base64) and the restore recreates a deleted Uninstall key; uninstaller exit code is checked (no more unconditional "Removed"); UWP removals (both scopes) are recorded.
- **Audit\Check-SystemHealth.ps1**: DISM RestoreHealth / sfc repairs are now ShouldProcess-gated with an admin warning (was: unconditional system modification in a read-only Audit folder).
- **Audit\Audit-InstalledSoftware.ps1**: fixed operator-precedence bug (`-not $x -contains 'y'` never skipped entries without DisplayName).
- **Core\WCS.Catalog.ps1**: `ConvertFrom-WCSLevelInput` error messages referenced `$Input` (empty) instead of the actual input.
- **Performance**: full `Get-Service`/`Get-ScheduledTask` enumerations are now cached per session (`Get-SuiteCachedServices`/`Get-SuiteCachedTasks`) — the Balanced preview ran ~6.5 min slower than needed because every manifest entry re-enumerated all services/tasks.
- **Core\WCS.Scheduler.ps1**: task registration always failed — `-Hour` had `[ValidateRange(0,5)]` with default `8`, `New-ScheduledTaskTrigger -Daily` was combined with `-RepetitionInterval/-RepetitionDuration` (invalid parameter set), and `-StartWhenOnBattery` / `New-ScheduledTaskIdleSettings` do not exist. Now: range 0-23, `-Once` trigger with repetition interval/duration, valid settings set (`-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -WakeToRun`). Verified via `-WhatIf`.
- **release.yml**: `gh release create` used `--notes-from-file`, which does not exist (current gh CLI: `-F/--notes-file`) — every tag release failed at the last step. Fixed to `--notes-file CHANGELOG.md`.
- **release.yml / ci.yml zip layout**: `Compress-Archive -Path` flattens every entry to its file name — with absolute paths *and* with repo-relative paths — so the release/snapshot zips had 0 nested entries and all 14 `Manifest.psd1` (plus `ci.yml`/`release.yml`) collided into single entries; the extracted suite was unusable. Both workflows now use the new `Tools\New-WCSZip.ps1` helper, which writes each file under its repo-relative path via `System.IO.Compression.ZipFile` (entry names use `/`), keeping the `Runners\`, `Core\`, `Cleanups\...` structure. Covered by new tests in `Tests\Invoke-SuiteTests.ps1` (nested entries, `Runners/Run-Menu.ps1`, 14 distinct `Manifest.psd1`, no legacy runners, `.git`/`Logs`/`Backups` excluded) and verified by downloading the rebuilt v1.1.0 zip and running the extracted menu.
- **Launcher.ps1**: with `-Launch:$false` the printed menu path assumed a flat layout (`$InstallDir\Runners\Run-Menu.ps1`) — branch archives extract with a top-level `<repo>-<branch>` folder. The launcher now locates `Run-Menu.ps1` recursively and prints the real path.
- **README**: documented `Core\WCS.Updates.ps1` / `Core\WCS.Scheduler.ps1` as directly runnable with switches — they are function libraries; corrected to dot-source + `Invoke-WCSUpdateManager` / `Register-WCSReRunTask` usage. Level descriptions aligned with `Core\WCS.Catalog.ps1` (Safe default topics include Privacy/Browsers/Network; visual effects live in ServicesTasks).

### Added

- **New cleanups: Privacy, Browsers, Network** — each with `Manifest.psd1` + `Disable-*.ps1` + `Restore-*.ps1`:
  - `Privacy`: telemetry (`AllowTelemetry=0`), advertising ID, activity history, CEIP/AppCompat, consumer/cloud content, ContentDeliveryManager suggested apps, WER off (Raphire-style policies).
  - `Browsers`: Edge `BackgroundModeEnabled=0` / `StartupBoostEnabled=0`, Chrome `BackgroundModeEnabled=0`, Firefox `BackgroundAppUpdate=0` / `DisablePocket=1` (HKLM policies).
  - `Network`: LLMNR off, Delivery Optimization → Manual + `DODownloadMode=0`; Risky (only with `-AllowRisky`): NetBIOS over TCP/IP off per adapter, static DNS 1.1.1.1/8.8.8.8 with per-adapter backup/restore.
- **Generic engines in `Core\CleanupEngine.ps1`**: `Invoke-SuiteRegistryEntry` / `Restore-SuiteRegistryRecords` / `Invoke-SuiteServiceEntry` / `Restore-SuiteServiceRecords` (support `RegistryKey` or `PathPattern`, `Name`/`NamePattern`, `RequiresAdmin`, `StopService`, `Risky`; every change backed up first; `$Preview` prints `Would ...` under `-WhatIf`).
- **`-AllowRisky` gating** across `Run-Cleanup.ps1`, `Run-Monthly.ps1`, `Run-Menu.ps1` and `Disable-ServicesAndTasks.ps1`; Maximum-only risky services (`WSearch`, `CDPSvc`, `CDPUserSvc_*`, `csc_vpnagent`, `CtxsDPS`, `CWAUpdaterService`) flagged `Risky = $true`.
- **`Audit\Perf-Snapshot.ps1`**: read-only perf snapshot (boot time/uptime, active power plan, hibernate availability, disks, RAM/CPU, top processes by CPU/memory, service count) written to `Logs\<ts>-perf-<phase>.json`; `Run-Cleanup.ps1` takes Before/After snapshots automatically.
- **`Runners\Restore-All.ps1`**: restores every cleanup in reverse run order from `Backups\` (preview by default, `-Apply` restores).

### Changed

- `Runners\Run-Monthly.ps1` no longer spawns a nested `powershell.exe`; it invokes `Run-Cleanup.ps1` directly in-process and forwards `-AllowRisky`.
- `Get-SuiteManifest` validates against the actual `Cleanups\*` directories (dynamic) instead of a hardcoded list; new `Get-SuiteCleanupNames` (canonical run order) + `Test-SuiteEntryRiskyAllowed` in `Core\CleanupEngine.ps1`.
- `Tests\Invoke-SuiteTests.ps1`: covers the new cleanups, `Restore-All.ps1`, `Perf-Snapshot.ps1`, plus wiring drift checks (runner steps, engine order, restore coverage, `-AllowRisky` gating).
- Extension manifests: DNSReset TCP tuning (RSS off, autotuning restricted), TempAndJunkFiles Disk Cleanup sagerun + Chrome caches + defrag, PowerPlan hibernate off.

## [1.0.0] - 2026-11-21

### Added

- **Interactive menu** (`Runners\Run-Menu.ps1`): choose a Level (Safe, Balanced, Aggressive,
  Extreme) and then Topics (ServicesTasks, PrivacySettings, Privacy, Browsers, Network, AI,
  OneDrive, ExtremeExtras, Maintenance, DNS, WindowsUpdates, PowerPlan). Fully usable, stable,
  non-interactive friendly: `-NonInteractive -Level 2 -Topics 'ServicesTasks,PrivacySettings' [-Apply]`.
  Menu creates System Restore points on apply, and saves preferences via `-SavePreferences`
  to `Config\UserPreferences.json`.
- **New cleanup: PrivacySettings** — disables Windows telemetry, advertising ID, tailored
  experiences, speech consent, personalization (registry-based; win11debloat-style keys).
- **New cleanup: Privacy** — Raphire-style policies: telemetry=0, advertising ID, activity
  history, CEIP, consumer/cloud content, suggestions. Items flagged *Risky* apply with
  `-AllowRisky` (engine-side: `Test-SuiteEntryRiskyAllowed`, `-AllowRisky` support added across
  `Disable-*`, `Invoke-SuiteRegistryEntry`, `Invoke-SuiteServiceEntry`, `Run-Cleanup`,
  `Run-Monthly`, `Disable-ServicesAndTasks`).
- **New cleanup: Browsers** — Edge/Chrome/Firefox background modes off, Edge Startup Boost off,
  Firefox Pocket off (HKLM policies).
- **New cleanup: Network** — LLMNR off, Delivery Optimization Manual + policy off; optional
  (Risky): NetBIOS off per adapter + fast public DNS (1.1.1.1/8.8.8.8).
- **New runner: Restore-All** (`Runners\Restore-All.ps1`) — restores all Backups\ records in
  reverse order using per-cleanup Restore-*.ps1 scripts.
- **Audit\Perf-Snapshot.ps1** — read-only perf snapshots (CPU/RAM/disks/power plan/services)
  written as JSON to Logs\; wired into Run-Cleanup (Before/After).
- **New cleanup: WindowsUpdates** — WU service to Manual, auto-restart off
  (`IsContinuousInnovationOptedIn`), drivers excluded from WU, Delivery Optimization off,
  HiberbootEnabled=0 (fast startup off).
- **New cleanup: OneDrive** — removes the HKCU Run autorun entry + sets
  OneDrive.Sync.Service to Manual (files remain, sync pauses).
- **New cleanup: ExtremeExtras (Level 4)** — WpnUserService, AppReadiness, StoreBrokerService,
  SmsRouter fully Disabled.
- **Updates feature** (`Core\WCS.Updates.ps1`) — runs Chocolatey (`choco upgrade all -y`) or
  Winget (`winget upgrade --all --silent ...`) with logging (`Logs\updates-*.log`), then
  re-debloats (`Run-Cleanup -Apply`) so update-reinstalled bloatware (e.g. wifi kill apps,
  Telegram/Signal shells) is removed again. Menu action [3] wires this up.
- **Scheduler** (`Core\WCS.Scheduler.ps1`) — registers `WindowsCleanupSuite_ReRun`
  (Task Scheduler, daily, runs as SYSTEM) for automatic weekly re-runs.
- **Unified backup restore** (`Tools\Restore-WCSBackup.ps1`) — restores JSON backups
  (all cleanups + generic `Type='Registry'` records) and/or System Restore points.
- **TempAndJunkFiles** — added `%LOCALAPPDATA%\Temp`, Chrome cache/code-cache/GPUCache,
  Disk Cleanup (`cleanmgr /verylowdisk /sagerun`) + defragment.
- **DNSReset** — added `netsh int tcp set global rss=disabled` +
  `netsh int tcp set global autotuninglevel=restricted`.
- **PowerPlan** — hibernate off (`powercfg /h off`).
- **Tests** — added Privacy/Browsers/Network schema checks + smoke topics; runs 299 checks.
- **Tests** — menu smoke test + schema checks for new cleanups.
- **CI** — `.github/workflows/ci.yml`: parses all `.ps1`/`.psd1`, runs
  `Tests\Invoke-SuiteTests.ps1`, uploads a downloadable snapshot artifact on every build.
  `.github/workflows/release.yml`: on tag push `v*.*.*`, builds a zip + sha256 and creates
  a GitHub release.

### Changed

- Manifests standardized to `Manifest.psd1` everywhere.
- Engine (`Core\CleanupEngine.ps1`) — added shared `Set-WCSRegistryEntry` /
  `Get-WCSRegistryValue` helpers used by the new cleanups.
- `Runners\Run-Monthly.ps1` (legacy) kept; new `Runners\Run-Menu.ps1` is the main entry point.

