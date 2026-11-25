# WindowsCleanupSuite

[![Build Status](https://img.shields.io/badge/CI-passing-brightgreen.svg)](https://github.com/patbaumgartner/WindowsCleanupSuite/actions)
[![Release](https://img.shields.io/badge/Releases-v1.2.2-brightgreen.svg)](https://github.com/patbaumgartner/WindowsCleanupSuite/releases)
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
4. **Apply** — System Restore point is created (Admin required), then changes are applied after a typed **YES** confirmation (skipped with `-AutoApprove`). The run aborts if no restore point can be created.
5. **Actions menu** — `[1]` preview / `[2]` apply / `[3]` updates+re-debloat / `[4]` schedule re-run / `[5]` review backup records then restore / `[6]` audits / `[h]` help / `[0]` exit.

Everything is colored, numbered and stable — invalid input is retried instead of crashing.

### Self-executing download (curl-friendly)

Get the menu without downloading anything — `Launcher.ps1` fetches the latest GitHub
Release zip, extracts it to `%TEMP%\WindowsCleanupSuite` and launches the menu. It is
**curl-friendly and the Raphire/Win11Debloat style**:

```powershell
# PowerShell (recommended) - the `| iex` is what executes it; plain `irm <url>` only prints the script:
irm https://raw.githubusercontent.com/patbaumgartner/WindowsCleanupSuite/main/Launcher.ps1 | iex

# curl (Windows):
curl.exe -L https://raw.githubusercontent.com/patbaumgartner/WindowsCleanupSuite/main/Launcher.ps1 -o "%TEMP%\Launcher.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\Launcher.ps1"
```

Works on Windows PowerShell 5.1 and PowerShell 7.x (verified on 5.1.26100 and 7.1.5).

Re-run it any time to update (it always extracts the latest release).
You can also run it locally: `Launcher.ps1 -WhatIf` (dry run).

## 🔧 Non-interactive (CLI)

Perfect for scripts/CI:

```powershell
# Preview only (safe, nothing changes)
& 'WindowsCleanupSuite\Runners\Run-Menu.ps1' -NonInteractive -Level 2 -Topics 'ServicesTasks,PrivacySettings'

# Apply changes (requires Administrator + a typed YES confirmation, System Restore point auto-created;
# -AutoApprove skips the prompt for automation). Apply aborts if no restore point can be created.
& 'WindowsCleanupSuite\Runners\Run-Menu.ps1' -NonInteractive -Level 3 -Topics 'ServicesTasks,PrivacySettings,WindowsUpdates' -Apply -AutoApprove

# Save your defaults (Level + Topics) for next time
& 'WindowsCleanupSuite\Runners\Run-Menu.ps1' -NonInteractive -Level 2 -Topics 'ServicesTasks' -SavePreferences

# Risky items (Network: NetBIOS off, static DNS):
& 'WindowsCleanupSuite\Runners\Run-Menu.ps1' -NonInteractive -Level 2 -Topics 'Network' -AllowRisky

# Fast topic-only preview (-Quick is preview-only; -Apply -Quick exits 1):
& 'WindowsCleanupSuite\Runners\Run-Menu.ps1' -NonInteractive -Level 2 -Quick

# Parallel preview (default) vs sequential escape hatches:
& 'WindowsCleanupSuite\Runners\Run-Menu.ps1' -NonInteractive -Level 2                    # topics scan in parallel (max 4)
& 'WindowsCleanupSuite\Runners\Run-Menu.ps1' -NonInteractive -Level 2 -NoParallel        # force sequential
& 'WindowsCleanupSuite\Runners\Run-Menu.ps1' -NonInteractive -Level 2 -MaxParallel 2     # custom pool size

# Schedule the automatic re-run (uses the AutoReRunDays pref; 0 = unregister; needs Admin):
& 'WindowsCleanupSuite\Runners\Run-Menu.ps1' -ScheduleDays -1
& 'WindowsCleanupSuite\Runners\Run-Menu.ps1' -ScheduleDays 7

# Review backup records before restoring (non-interactive listing):
& 'WindowsCleanupSuite\Runners\Run-Menu.ps1' -ReviewBackups

# Unified restore (restores Backups\ records immediately; preview with -WhatIf):
& 'WindowsCleanupSuite\Tools\Restore-WCSBackup.ps1' -Backups -WhatIf
& 'WindowsCleanupSuite\Tools\Restore-WCSBackup.ps1' -Backups
```

**Performance switches:** previews run the topic scans in parallel (PS 5.1 runspace pool,
`-MaxParallel` default 4; `-NoParallel` forces the old sequential order; `-Apply` is always
sequential). `-Quick` makes the three heaviest topics (InstalledSoftware, TempAndJunkFiles,
ServicesAndTasks) topic-only: single-pass uninstall index, no recursive junk-file scan, exact
service/task probes. Measured on the dev machine (Win 11, non-admin): full Level 2 preview
exits 0 in **~2.9× faster than sequential** (parallel ~166s vs sequential ~476s; ~132s once
already-done operations are skipped).

**Topic names:** `ServicesTasks`, `PrivacySettings`, `Privacy`, `Browsers`, `Network`, `AI`,
`OneDrive`, `ExtremeExtras`, `Maintenance`, `DNS`, `WindowsUpdates`, `PowerPlan`.

### Direct scripts (audits & single cleanups)

Entry points: `Launcher.ps1` (one-liner) or `Runners\Run-Menu.ps1` — there are no legacy runners anymore.
Individual scripts still work standalone (all cleanups support `-WhatIf`):

```powershell
# Read-only performance snapshot (writes Logs\<ts>-perf-<phase>.json)
& 'WindowsCleanupSuite\Audit\Perf-Snapshot.ps1' -Phase Standalone

# Direct cleanup script (preview with -WhatIf; apply = run without it, needs Admin)
& 'WindowsCleanupSuite\Cleanups\WindowsSpeedup\Disable-ServicesAndTasks.ps1' -WhatIf -Profile Balanced
```

---

## 🧹 What it cleans

| Topic | What it does |
|---|---|
| **ServicesTasks** | Disables nonessential Windows services, scheduled tasks, startup apps (Run values + StartupApproved flags + packaged startup tasks) and installed bloatware. Manual launches keep working. |
| **PrivacySettings** | Disables advertising ID, tailored experiences, speech consent, location/personalization (registry). |
| **Privacy** | Telemetry `AllowTelemetry=0`, advertising ID, activity history, CEIP/AppCompat, consumer/cloud content, ContentDeliveryManager suggested apps, WER off (Raphire-style policies). |
| **Browsers** | Edge/Chrome `BackgroundModeEnabled=0`, Edge `StartupBoostEnabled=0`, Firefox background update + Pocket off (HKLM policies, all users). |
| **Network** | LLMNR off, Delivery Optimization → Manual + `DODownloadMode=0`. Risky (only with `-AllowRisky`): NetBIOS over TCP/IP off per adapter, static DNS 1.1.1.1/8.8.8.8 (per-adapter backup). |
| **AI** | Copilot/Recall/Click-to-Do, WSAIFabricSvc + AI policies in Edge/Chrome/Paint/Notepad. |
| **OneDrive** | OneDrive Run entry + startup flag + logon/update tasks; `OneDrive.Sync.Service` → Manual (files stay local, manual launch works). |
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
Invoke-WCSDebloatAfterUpdates -Level Balanced -Apply     # re-debloat afterwards
```

Then it **re-debloats automatically** (`Runners\Run-Menu.ps1 -NonInteractive -Level 4 -Apply`). This matters because
app updates often re-install bloatware — the wifi kill apps, Telegram Shell, driver-managed
updaters, etc. — and the post-update re-run removes them again.

You can also do the update+re-debloat manually:

```powershell
& 'WindowsCleanupSuite\Runners\Run-Menu.ps1'  # Actions → [3] Updates + re-debloat
```

Logs for updates: `Logs\updates-*.log`.

---

Update with specific packages (e.g. `winget upgrade --id Discord.Discord --force`):

```powershell
Invoke-WCSUpdateManager -PackageIds @('Discord.Discord') -Force   # winget: --id + --force per package
Invoke-WCSUpdateManager -PackageIds @('Telegram.TelegramDesktop') # no --force
Invoke-WCSUpdateManager -IncludeUnknown                            # --include-unknown (default for winget)
```

## 🕒 Scheduled Re-runs

One command registers a scheduled task so the machine gets re-debloated automatically:

```powershell
. 'WindowsCleanupSuite\Core\WCS.Scheduler.ps1'   # dot-source the library, then:
Register-WCSReRunTask -Days 7 -Hour 8            # register the re-run task (needs Admin)
Register-WCSReRunTask -Days -1                   # use the AutoReRunDays pref from Config\UserPreferences.json (fallback 7)
Register-WCSReRunTask -Days 0                    # = Unregister-WCSReRunTask: remove the task
Register-WCSReRunTask -Days 3 -WhatIf            # preview what would be registered (no Admin needed)
Unregister-WCSReRunTask                          # remove it again
```

Or straight from the entry point / menu:

```powershell
& 'WindowsCleanupSuite\Runners\Run-Menu.ps1' -ScheduleDays -1   # CLI switch; -1 = stored AutoReRunDays pref
# menu: Actions → [4] Schedule auto re-run   (prompt defaults to the AutoReRunDays pref; 0 unregisters)
```

Registered as `WindowsCleanupSuite_ReRun` (Task Scheduler → Task Scheduler Library → WindowsCleanupSuite_ReRun).
Runs at 8 AM as SYSTEM, repeating every N days, calling `Runners\Run-Menu.ps1 -NonInteractive -Level <stored> -Apply -AutoApprove [-Topics ...]` —
the Level/Topics come from your saved preferences (`Config\UserPreferences.json`, fallback `-Level 4` = Extreme).
Set `"AutoReRunDays": 7` in `Config\UserPreferences.json` (or via `-SavePreferences` flow) to change the interval;
`-Days -1` always picks it up.

---

## 🛡️ Backups & restore

Every change is backed up to `Backups\` (JSON records per item). **Review what is backed up
before restoring** (non-interactive listing, or interactive picker with an optional
admin-gated restore at the end):

```powershell
& 'WindowsCleanupSuite\Tools\Review-WCSBackup.ps1' -List          # list all records + folders
& 'WindowsCleanupSuite\Tools\Review-WCSBackup.ps1'                 # interactive picker -> optional restore
& 'WindowsCleanupSuite\Runners\Run-Menu.ps1' -ReviewBackups         # same via the entry point
# menu: Actions → [5] Review backup records, then restore
```

Restore everything (really restores; use `-WhatIf` to preview first):

```powershell
& 'WindowsCleanupSuite\Tools\Restore-WCSBackup.ps1' -Backups -WhatIf   # preview only
& 'WindowsCleanupSuite\Tools\Restore-WCSBackup.ps1' -Backups           # restore (needs Admin)
```

Or restore a System Restore point:

```powershell
& 'WindowsCleanupSuite\Tools\Restore-WCSBackup.ps1' -RestorePoint 3
& 'WindowsCleanupSuite\Tools\Restore-WCSBackup.ps1' -Latest
```

Notes: restoring a System Restore point triggers an automatic reboot (type `YES`).

---

## 🔍 Audits

Run read-only audits to see current state:

```powershell
& 'WindowsCleanupSuite\Audit\Audit-State.ps1'
& 'WindowsCleanupSuite\Audit\Audit-InstalledSoftware.ps1'
& 'WindowsCleanupSuite\Audit\Audit-RunningServices.ps1'
& 'WindowsCleanupSuite\Audit\Perf-Snapshot.ps1'         # perf snapshot -> Logs\<ts>-perf-*.json
```

`Audit\Check-SystemHealth.ps1` is the exception: its DISM `/RestoreHealth` and `sfc /SCANNOW`
steps **repair** the system (admin-only, skipped otherwise; DISM `/ScanHealth` is read-only).
Preview everything with `-WhatIf`:

```powershell
& 'WindowsCleanupSuite\Audit\Check-SystemHealth.ps1' -WhatIf
```

---

## 🏗️ Architecture

```
WindowsCleanupSuite/
├── Launcher.ps1                     # Self-executing download-and-run (irm <url> | iex)
├── Runners\
│   └── Run-Menu.ps1                 # The only entry point (interactive menu / non-interactive CLI)
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
│   ├── Restore-WCSBackup.ps1        # Restore backups + System Restore points
│   ├── Review-WCSBackup.ps1         # Review backup records (-List / interactive) before restoring
│   └── New-WCSZip.ps1               # Structure-preserving zip builder (releases/snapshots)
├── Audit\                           # State / installed software / running services / health
│                                    # checks + Perf-Snapshot (before/after comparisons)
├── Tests\
│   ├── Invoke-SuiteTests.ps1        # Structural tests + menu smoke tests (no system changes)
│   └── Invoke-PS51ParseCheck.ps1    # Parses every file with the PS 5.1 parser
├── .github\workflows\               # ci.yml (validate + snapshot) / release.yml (tag releases)
├── Config\UserPreferences.json      # Your saved Level/Topics/AutoReRunDays (git-ignored)
├── Backups\                         # Original-state records per changed item (git-ignored)
└── Logs\                            # Timestamped run logs (git-ignored)
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
- **Feature coverage**: parallel preview runner (runspace pool, `-NoParallel`/`-MaxParallel` fallbacks, `-Apply` stays sequential), `-Quick` dispatch and per-cleanup quick paths, scheduler (`AutoReRunDays` resolution, task command line, `-WhatIf` paths, admin gate), backup review tool.
- **Hardening coverage**: original backups never overwritten, preview-safe AppX/provisioned handling, `-Quick` standalone guards, admin gates, DNS static-on-DHCP restore, PowerPlan GUID/state/hibernate restore, restore type fidelity, single-owner restore, scheduler argument-injection validation, apply confirmation/restore-point abort, honest failure exit codes.
- **Wiring drift checks**: the ServicesTasks catalog mapping (→ StartupBloat + ServicesAndTasks + InstalledSoftware), the engine run order covers all cleanups, every cleanup has a `Restore-*.ps1`, the legacy runner scripts are gone (no references anywhere in code), and `-AllowRisky` gating is present.
- Independence check: no references to the previous project.

---

## 🔒 Safety & Reversibility

- **Preview by default** — nothing changes without `-Apply` (or Actions `[2]`). `-Apply` additionally requires a typed **YES** confirmation (skipped with `-AutoApprove` for automation) and **aborts if no System Restore point can be created**. Every cleanup script supports `-WhatIf`.
- **`-AllowRisky` gate** — manifest entries flagged `Risky = $true` (NetBIOS off, static DNS resolvers, VPN/Citrix services, Windows Search indexing, Connected Devices Platform) are skipped unless `-AllowRisky` is passed.
- **System Restore point** created automatically on apply (admin required).
- **Backups** (`Backups\`) keep the ORIGINAL state of every changed item (repeated runs never overwrite them); restore scripts (`Restore-*.ps1`) for each cleanup.
- **Auto-start only, not removal** — no app is uninstalled and no binary is deleted. Run values, StartupApproved flags and packaged startup tasks are backed up; Startup-folder shortcuts are moved to `Backups\StartupBloat\StartupFolder` and can be restored. Services are set to Manual (never Disabled by these topics), so you can still launch WhatsApp/kDrive/Dropbox/OneDrive yourself.
- **Reversibility exceptions** (read before applying): junk-file/event-log deletions (`TempAndJunkFiles`) and the `DNSReset` stack reset are **not** restorable; removed **UWP/provisioned apps** are reinstalled from the Microsoft Store, not auto-restored; Win32 apps get their Uninstall registry keys back, not a reinstallation.
- **No data deletion of important items**: protected patterns (Intel DSA, drivers) are never touched; OneDrive/Dropbox/Teams/PowerToys/TeamViewer remain kept per your needs.
- **Risky items are explicit**: `Privacy` (Raphire policies), `Network` (NetBIOS off, static DNS) — apply via `-AllowRisky` or the menu option.
- **Perf snapshots**: `Audit\Perf-Snapshot.ps1` writes read-only before/after JSON for a/b comparison (run with `-Phase Before` / `-Phase After` around a cleanup).
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
`WindowsCleanupSuite-vX.Y.Z.zip` + `WindowsCleanupSuite-vX.Y.Z.zip.SHA256` + a downloadable snapshot (zip + `.zip.SHA256`) from every build.

