# Changelog

All notable changes to WindowsCleanupSuite will be documented in this file.

## [1.0.0] - 2026-11-21 - self-executing launcher

- **Launcher.ps1** — self-executing, curl-friendly download-and-run (the Raphire/Win11Debloat
  style): `irm https://raw.githubusercontent.com/patbaumgartner/WindowsCleanupSuite/master/Launcher.ps1`
  fetches the latest GitHub Release zip, extracts it to `%TEMP%\WindowsCleanupSuite` and launches the menu.
  (GitHub API unavailable from this sandbox - verified: curl.exe to api.github.com fails.)

## [1.0.0] - 2026-11-21 (final)

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this
project adheres to [Semantic Versioning](https://semver.org/) (`1.x` era; 1.0.0 = first publishable release).

## [Unreleased]

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

