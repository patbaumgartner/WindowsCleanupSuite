# WindowsCleanupSuite

[![Build Status](https://img.shields.io/badge/CI-passing-brightgreen.svg)](https://github.com/patbaumgartner/WindowsCleanupSuite/actions)
[![Release](https://img.shields.io/badge/Releases-v1.0.0-brightgreen.svg)](https://github.com/patbaumgartner/WindowsCleanupSuite/releases)
[![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://learn.microsoft.com/en-us/powershell/scripting/windows-powershell/overview)
[![Windows 10/11](https://img.shields.io/badge/Windows-10/11-blue.svg)](https://www.microsoft.com/windows)
[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A modern, interactive suite to **debloat Windows and speed up your machine again**.
Choosing a **Level** and **Topics**, it disables nonessential services, scheduled
tasks, startup apps, privacy telemetry and system settings — everything is
reversible, backups included, System Restore points created. It works for both
Windows 10 and Windows 11, runs as Administrator for full effect.

## 🗺️ Vision: unique, all-in-one, publishable

There are many debloat scripts, but none combine what this project offers:

- 📊 **Interactive Menu with Levels + Topics** — pick a *Level* (Safe / Balanced / Aggressive /
  Extreme) and which *Topics* you care about (Services & Tasks, Startup Apps, Privacy &
  Telemetry, AI, OneDrive, ExtremeExtras, Maintenance, DNS, Windows Updates, Power Plan).
- 🛡️ **Preview-by-default + System Restore + backups** — every change is backed up before it is
  made; every change can be undone via restore scripts or System Restore points.
- ⚙️ **Update integration** — runs *Chocolatey* (`choco upgrade all`) or *Winget*
  (`winget upgrade --all --silent`) and **re-debloats afterwards** — so app updates that
  re-install bloatware (e.g. wifi kill apps via drivers) get removed again automatically.
- 🔄 **Scheduled re-runs** — register a weekly (or custom) `WindowsCleanupSuite_ReRun` task to
  keep the machine fast "from time to time".
- 🧹 **Custom cleanups** — `PrivacySettings`, `WindowsUpdates`, `OneDrive`, `ExtremeExtras`,
  `Privacy`, `Browsers`, `Network`, `TempAndJunkFiles`, `DNSReset`, `PowerPlan`.
- 📦 **CI/CD & Releases** — every build uploads a downloadable snapshot; every tag releases a zip.

---

## 🎮 The Menu (main entry point)

```powershell
& 'WindowsCleanupSuite\Runners\Run-Menu.ps1'           # Interactive menu
```

Walk through:

1. **Choose Level** — `1`-`4` or `Safe/Balanced/Aggressive/Extreme`:
   - **Safe (Recommended)** — Balanced engine + ServicesTasks, PrivacySettings, Privacy, Browsers, Network, Maintenance, DNS, WindowsUpdates, PowerPlan.
   - **Balanced** — Safe + AI and OneDrive topics (visual effects are part of ServicesTasks).
   - **Aggressive** — Maximum profile: more services set to Manual/Disabled.
   - **Extreme** — Maximum + ExtremeExtras (WpnUserService, StoreBroker, etc.).
2. **Choose Topics** — toggle the areas you want (spaces/numbers/[a]ll/[n]one, Enter to accept).
3. **Preview** — see what would change (WhatIf).
4. **Apply** — System Restore point is created, then changes are applied (needs Admin).
5. **Actions menu** — preview / apply / updates+re-debloat / schedule re-run / revert / audits / help / exit.

Everything is colored, numbered and stable — invalid input is retried instead of crashing.

### Self-executing download (curl-friendly)

Get the menu without downloading anything — `Launcher.ps1` fetches the latest GitHub
Release zip, extracts it to `%TEMP%\WindowsCleanupSuite` and launches the menu. It is
**curl-friendly and the Raphire/Win11Debloat style**:

```powershell
# PowerShell (recommended):
irm https://raw.githubusercontent.com/patbaumgartner/WindowsCleanupSuite/main/Launcher.ps1

# curl (Windows):
curl.exe https://raw.githubusercontent.com/patbaumgartner/WindowsCleanupSuite/main/Launcher.ps1 -o "%TEMP%\Launcher.ps1"
powershell -File "%TEMP%\Launcher.ps1"
```

Re-run it any time to update (it always extracts the latest release).
You can also run it locally: `Launcher.ps1 -WhatIf` (dry run).

## 🔧 Non-interactive (CLI)

Perfect for scripts/CI:

```powershell
# Preview only (safe, nothing changes)
& 'WindowsCleanupSuite\Runners\Run-Menu.ps1' -Level 2 -Topics 'ServicesTasks,PrivacySettings'

# Apply changes (requires Administrator, System Restore point auto-created)
& 'WindowsCleanupSuite\Runners\Run-Menu.ps1' -Level 3 -Topics 'ServicesTasks,PrivacySettings,WindowsUpdates' -Apply

# Save your defaults (Level + Topics) for next time
& 'WindowsCleanupSuite\Runners\Run-Menu.ps1' -Level 2 -Topics 'ServicesTasks' -SavePreferences

# Risky items (Network: NetBIOS off, static DNS):
& 'WindowsCleanupSuite\Runners\Run-Menu.ps1' -NonInteractive -Level 2 -Topics 'Network' -AllowRisky

# Unified restore-all (restores Backups\RegistryRecords + every Restore-*.ps1):
& 'WindowsCleanupSuite\Runners\Restore-All.ps1'
```

**Topic names:** `ServicesTasks`, `PrivacySettings`, `Privacy`, `Browsers`, `Network`, `AI`,
`OneDrive`, `ExtremeExtras`, `Maintenance`, `DNS`, `WindowsUpdates`, `PowerPlan`.

### Legacy entry points (still supported)

```powershell
# Classic data-driven cleanup (preview by default, -Apply applies)
& 'WindowsCleanupSuite\Runners\Run-Cleanup.ps1' -Profile Balanced                     # preview
& 'WindowsCleanupSuite\Runners\Run-Cleanup.ps1' -Profile Balanced -Apply            # apply
& 'WindowsCleanupSuite\Runners\Run-Cleanup.ps1' -Profile Maximum -Apply -AllowRisky # incl. Risky entries

# Monthly wrapper: preview first, ask before applying (calls the runner in-process)
& 'WindowsCleanupSuite\Runners\Run-Monthly.ps1'

# Restore everything from Backups\ in reverse run order (preview by default)
& 'WindowsCleanupSuite\Runners\Restore-All.ps1'
& 'WindowsCleanupSuite\Runners\Restore-All.ps1' -Apply

# Read-only performance snapshot (writes Logs\<ts>-perf-<phase>.json)
& 'WindowsCleanupSuite\Audit\Perf-Snapshot.ps1' -Phase Standalone

# Direct cleanup scripts (all support -WhatIf)
& 'WindowsCleanupSuite\Cleanups\WindowsSpeedup\Disable-ServicesAndTasks.ps1' -WhatIf
```

---

## 🧹 What it cleans

| Topic | What it does |
|---|---|
| **ServicesTasks** | Disables nonessential Windows services, scheduled tasks, startup apps (Balanced/Maximum profiles). |
| **PrivacySettings** | Disables advertising ID, tailored experiences, speech consent, location/personalization (registry). |
| **Privacy** | Telemetry `AllowTelemetry=0`, advertising ID, activity history, CEIP/AppCompat, consumer/cloud content, ContentDeliveryManager suggested apps, WER off (Raphire-style policies). |
| **Browsers** | Edge/Chrome `BackgroundModeEnabled=0`, Edge `StartupBoostEnabled=0`, Firefox background update + Pocket off (HKLM policies, all users). |
| **Network** | LLMNR off, Delivery Optimization → Manual + `DODownloadMode=0`. Risky (only with `-AllowRisky`): NetBIOS over TCP/IP off per adapter, static DNS 1.1.1.1/8.8.8.8 (per-adapter backup). |
| **AI** | Copilot/Recall/Click-to-Do, WSAIFabricSvc + AI policies in Edge/Chrome/Paint/Notepad. |
| **OneDrive** | OneDrive auto-start + `OneDrive.Sync.Service` → Manual. |
| **ExtremeExtras** (Level 4) | Fully disables `WpnUserService`, `AppReadiness`, `StoreBrokerService`, `SmsRouter`. |
| **Maintenance** | Temp/junk files, caches, prefetch, event logs, Disk Cleanup (`cleanmgr`), defrag. |
| **DNS** | DNS flush, IP stack reset, TCP autotuning + RSS tuning. |
| **WindowsUpdates** | WU service → Manual, auto-restart off, drivers excluded, DO off. |
| **PowerPlan** | Ultimate Performance plan + hibernate off. |

### Level deep-dive

- **Safe (Level 1)** — Balanced profile + ServicesTasks, PrivacySettings, Privacy, Browsers, Network, Maintenance, DNS, WindowsUpdates, PowerPlan (all default-on).
- **Balanced (Level 2)** — Safe + AI and OneDrive topics.
- **Aggressive (Level 3)** — Maximum profile (more services disabled) + everything above.
- **Extreme (Level 4)** — Maximum + ExtremeExtras (push, Store broker, SMS routing fully disabled).

---

## 🔄 Updates (Chocolatey / Winget)

The suite integrates with the two standard package managers on Windows:

```powershell
. 'WindowsCleanupSuite\Core\WCS.Updates.ps1'    # dot-source the library, then:
Invoke-WCSUpdateManager                          # runs: winget upgrade --all --silent
                                                 # or choco upgrade all -y (when winget is missing)
Invoke-WCSDebloatAfterUpdates -Profile Balanced -Apply   # re-debloat afterwards
```

Then it **re-debloats automatically** (`Runners\Run-Cleanup.ps1 -Apply`). This matters because
app updates often re-install bloatware — the wifi kill apps, Telegram Shell, driver-managed
updaters, etc. — and the post-update re-run removes them again.

You can also do the update+re-debloat manually:

```powershell
& 'WindowsCleanupSuite\Runners\Run-Menu.ps1'  # Actions → [3] Updates + re-debloat
```

Logs for updates: `Logs\updates-*.log`.

---

## 🕒 Scheduled Re-runs

One command registers a scheduled task so the machine gets re-debloated automatically:

```powershell
. 'WindowsCleanupSuite\Core\WCS.Scheduler.ps1'   # dot-source the library, then:
Register-WCSReRunTask -Days 7 -Hour 8            # register the re-run task
Unregister-WCSReRunTask                          # remove it again
```

Registered as `WindowsCleanupSuite_ReRun` (Task Scheduler → Task Scheduler Library → WindowsCleanupSuite_ReRun).
Runs daily at 8 AM as SYSTEM, repeating every 7 days (changeable), calling `Runners\Run-Cleanup.ps1 -Profile Maximum -Apply`.

---

## 🛡️ Backups & restore

Every change is backed up to `Backups\` (JSON records per item). Restore everything:

```powershell
& 'WindowsCleanupSuite\Tools\Restore-WCSBackup.ps1' -Backups
```

Or restore a System Restore point:

```powershell
& 'WindowsCleanupSuite\Tools\Restore-WCSBackup.ps1' -RestorePoint 3
& 'WindowsCleanupSuite\Tools\Restore-WCSBackup.ps1' -RestorePoint -Latest
```

Notes: restoring a System Restore point triggers an automatic reboot (type `YES`).

---

## 🔍 Audits

Run read-only audits to see current state:

```powershell
& 'WindowsCleanupSuite\Audit\Audit-State.ps1'
& 'WindowsCleanupSuite\Audit\Audit-InstalledSoftware.ps1'
& 'WindowsCleanupSuite\Audit\Audit-RunningServices.ps1'
& 'WindowsCleanupSuite\Audit\Check-SystemHealth.ps1'   # sfc + DISM health checks
& 'WindowsCleanupSuite\Audit\Perf-Snapshot.ps1'         # perf snapshot -> Logs\<ts>-perf-*.json
```

---

## 🏗️ Architecture

```
WindowsCleanupSuite/
├── Runners\
│   ├── Run-Menu.ps1                 # Interactive menu entry point
│   ├── Run-Cleanup.ps1              # Data-driven runner (preview unless -Apply; perf snapshots Before/After)
│   ├── Run-Monthly.ps1              # Monthly wrapper (preview + ask; in-process call, no nested powershell.exe)
│   └── Restore-All.ps1              # Restore all Backups\ records (preview unless -Apply)
├── Core\
│   ├── CleanupEngine.ps1            # Shared engine: backups, registry helpers, manifest loader
│   ├── WCS.Catalog.ps1              # Single source of truth: Levels + Topics + Cleanup mapping
│   ├── WCS.Menu.ps1                 # Interactive menu + preview/apply logic
│   ├── WCS.Updates.ps1              # Winget/Chocolatey update integration + re-debloating
│   └── WCS.Scheduler.ps1            # Scheduled task registration for re-runs
├── Cleanups\
│   ├── StartupBloat\                # Run-key autoruns (OneDrive, Teams, kDrive, ...)
│   ├── WindowsSpeedup\              # Services, scheduled tasks, startup apps, visual effects
│   ├── InstalledSoftware\           # Win32 + UWP uninstall (Discord, Dropbox, ...)
│   ├── WindowsAI\                   # Copilot/Recall/Click-to-Do + Edge/Chrome/Paint/Notepad AI
│   ├── Privacy\                     # Privacy policies (Raphire-style, RequiresAdmin)
│   ├── Browsers\                    # Browser background modes + Pocket (HKLM policies)
│   ├── Network\                     # LLMNR off, DoSvc Manual, DoSvc policy off (Risky items)
│   ├── PrivacySettings\             # Telemetry/advertising ID/personalization (registry, HKCU)
│   ├── WindowsUpdates\              # WU Manual, no auto-restart, driver updates off
│   ├── OneDrive\                    # OneDrive autorun + sync service
│   ├── ExtremeExtras\               # Level 4: push, Store broker, SMS routing (all Disabled)
│   ├── TempAndJunkFiles\            # Temp dirs, prefetch, event logs, Disk Cleanup, defrag
│   ├── DNSReset\                    # DNS + IP stack reset + TCP/RSS tuning
│   └── PowerPlan\                   # Ultimate Performance + hibernate off
├── Tools\
│   └── Restore-WCSBackup.ps1        # Restore backups + System Restore points
├── Audit\                           # State / installed software / running services / health
│                                    # checks + Perf-Snapshot (before/after comparisons)
├── Tests\
│   └── Invoke-SuiteTests.ps1        # Structural tests + menu smoke test (read-only)
└── Logs\                            # Timestamped run logs
```

---

## ✅ Tests

```powershell
& 'WindowsCleanupSuite\Tests\Invoke-SuiteTests.ps1'
```

- Parses every `.ps1` file (static analysis).
- Validates manifest schema (entries, levels, protected patterns) for all cleanups.
- Extends: menu-era cleanup schema checks + extension manifest checks (TempAndJunkFiles, DNSReset, PowerPlan).
- **Menu smoke test**: runs the menu non-interactively in preview mode; exit code must be `0`.
- **Wiring drift checks**: `Run-Cleanup.ps1` runs every cleanup, the engine run order covers all cleanups, every cleanup has a `Restore-*.ps1` (used by `Restore-All.ps1`), and `-AllowRisky` gating is present.
- Independence check: no references to the previous project.

---

## 🔒 Safety & Reversibility

- **Preview by default** — the menu never applies changes without confirmation (`-Apply`/Actions `[2]`); every runner and cleanup script supports `-WhatIf`.
- **`-AllowRisky` gate** — manifest entries flagged `Risky = $true` (NetBIOS off, static DNS resolvers, VPN/Citrix services, Windows Search indexing, Connected Devices Platform) are skipped unless `-AllowRisky` is passed.
- **System Restore point** created automatically on apply (admin required).
- **Backups** (`Backups\`) of every changed item; restore scripts (`Restore-*.ps1`) for each cleanup.
- **No data deletion of important items**: protected patterns (Intel DSA, drivers) are never touched; OneDrive/Dropbox/Teams/PowerToys/TeamViewer remain kept per your needs.
- **Risky items are explicit**: `Privacy` (Raphire policies), `Network` (NetBIOS off, static DNS) — apply via `-AllowRisky` or the menu option.
- **Perf snapshots**: `Audit\Perf-Snapshot.ps1` writes read-only before/after JSON for a/b comparison (wired into Run-Cleanup).
- **Automatic re-runs**: scheduled task re-debloats weekly; also re-runs happen automatically after updates.
- **Admin required** for service changes — run elevated for full effect.

---

## 🧪 Credits & Inspirations

- [Raphire — Win11Debloat](https://github.com/Raphire/Win11Debloat) (MIT)
- [JonathanFerraz — debloat-windows](https://github.com/JonathanFerraz/debloat-windows) (MIT)
- [Sparkle — debloat/optimize app](https://github.com/thedogecraft/sparkle)
- [OO ShutUp10 — Windows privacy](https://www.oo-software.com/en/shutup10)
- Chainski WindowsCleanerUtility, Marvin700 — Win32/UWP uninstall + extensions.

## 🤝 Contributing

PRs welcome. Follow the existing patterns: data-driven `Manifest.psd1` + `Disable-*.ps1` +
`Restore-*.ps1` per cleanup. See `.github/workflows/ci.yml` for CI requirements.

## 🚀 Releases

Downloadable archives are attached to GitHub Releases (tag `vX.Y.Z`).
`WindowsCleanupSuite-vX.Y.Z.zip` + `SHA256.txt` + a downloadable snapshot from every build.

