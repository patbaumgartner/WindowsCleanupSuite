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
  test suite runs it when available. New tests also assert the one-liner docs use `| iex` and that
  `Launcher.ps1` contains no PS7-only operators (`??`, `?.`, `&&`, `||`).

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

