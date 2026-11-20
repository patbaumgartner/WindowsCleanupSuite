# WindowsCleanupSuite

An independent, self-contained suite that disables nonessential Windows cleanup
components (startup bloat + background services/tasks/apps) so the machine boots
and runs faster, with everything reversible via the bundled restore scripts.

## Structure

```
WindowsCleanupSuite/
├── Core/
│   └── CleanupEngine.ps1            # shared helpers (manifests, backups, protection rules, registry)
├── Cleanups/
│   ├── StartupBloat/
│   │   ├── Manifest.psd1            # data-driven list of startup entries (HKCU + HKLM Run keys)
│   │   ├── Disable-StartupBloat.ps1
│   │   └── Restore-StartupBloat.ps1
│   ├── WindowsSpeedup/
│   │   ├── Manifest.psd1            # data-driven lists: services, tasks, startup apps, process stops, visual effects
│   │   ├── Disable-ServicesAndTasks.ps1
│   │   └── Restore-ServicesAndTasks.ps1
│   ├── InstalledSoftware/
│   │   ├── Manifest.psd1            # Win32 apps via uninstaller + UWP apps (Raphire/Marvin700)
│   │   ├── Disable-InstalledSoftware.ps1
│   │   └── Restore-InstalledSoftware.ps1
│   ├── WindowsAI/
│   │   ├── Manifest.psd1            # Copilot/Recall/Click-to-Do + Edge/Chrome/Paint/Notepad AI policy keys (Raphire)
│   │   ├── Disable-WindowsAI.ps1
│   │   └── Restore-WindowsAI.ps1
│   ├── TempAndJunkFiles/
│   │   ├── Manifest.psd1            # temp/junk dirs, log files, event logs (Chainski + Marvin700)
│   │   ├── Disable-TempAndJunkFiles.ps1
│   │   └── Restore-TempAndJunkFiles.ps1
│   ├── PowerPlan/
│   │   ├── Manifest.psd1            # Ultimate Performance plan (Marvin700) + LeDragoX performance tweaks
│   │   ├── Enable-UltimatePerformancePlan.ps1
│   │   └── Restore-PowerPlan.ps1
│   └── DNSReset/
│       ├── Manifest.psd1            # ipconfig/netsh reset commands (Chainski + Marvin700)
│       ├── Disable-DNSReset.ps1
│       └── Restore-DNSReset.ps1
├── Runners/
│   ├── Run-Cleanup.ps1              # main entry point: preview (dry-run) by default, -Apply to change state
│   └── Run-Monthly.ps1              # monthly wrapper: preview, then asks YES before applying
├── Audit/
│   ├── Audit-State.ps1              # read-only post-run audit (services/tasks/Run keys)
│   ├── Audit-InstalledSoftware.ps1  # lists bloatware found vs. the InstalledSoftware manifest
│   ├── Audit-RunningServices.ps1    # snapshots running services vs. the WindowsSpeedup expectations
│   └── Check-SystemHealth.ps1       # sfc + DISM ScanHealth / RestoreHealth
└── Tests/
    └── Invoke-SuiteTests.ps1        # structural tests: parse every .ps1, check manifests + independence
```

Cleanup components (each has a matching restore step; all data-driven from
`Manifest.psd1`, protected names via `ProtectedPatterns`):

- `StartupBloat` — startup-bloat Run entries (HKCU + HKLM).
- `WindowsSpeedup` — services, tasks, startup apps, process stops, visual effects.
- `InstalledSoftware` — Win32 apps via their uninstaller (Discord, Dropbox, ...)
  and UWP apps (Microsoft, Dell, Samsung, TikTok, Netflix, ...).
- `WindowsAI` — Copilot/Recall/Click-to-Do, Edge/Chrome/Paint/Notepad AI,
  WSAIFabricSvc (Raphire Win11Debloat).
- `TempAndJunkFiles` — temp/junk dirs, log files, event logs (Chainski + Marvin700).
- `PowerPlan` — Ultimate Performance plan (Marvin700) + LeDragoX tweaks.
- `DNSReset` — DNS/network stack reset commands (Chainski + Marvin700).

## Profiles

- `Balanced` (default) - safe defaults for daily use.
- `Maximum` - additionally disables aggressive components (Office, CCleaner,
  PowerToys, WSearch, CDPUserSvc_*, etc.).

`-LoginSafe` (default: on) keeps login/session-critical components enabled:
OneDrive run entries, csc_vpnagent, CtxsDPS, CWAUpdaterService, WSearch.
Pass `-LoginSafe:$false` to disable those exclusions.

## Running

```powershell
# Preview only (default; nothing is modified)
& 'WindowsCleanupSuite\Runners\Run-Cleanup.ps1' -Profile Balanced

# Actually apply (requires Administrator)
& 'WindowsCleanupSuite\Runners\Run-Cleanup.ps1' -Profile Balanced -Apply

# Monthly wrapper: preview, then prompt to confirm before applying
& 'WindowsCleanupSuite\Runners\Run-Monthly.ps1' -Profile Balanced
```

Direct cleanup scripts (all support `-WhatIf`):

```powershell
& 'WindowsCleanupSuite\Cleanups\StartupBloat\Disable-StartupBloat.ps1' -WhatIf
& 'WindowsCleanupSuite\Cleanups\WindowsSpeedup\Disable-ServicesAndTasks.ps1' -WhatIf
& 'WindowsCleanupSuite\Cleanups\TempAndJunkFiles\Disable-TempAndJunkFiles.ps1' -WhatIf
& 'WindowsCleanupSuite\Cleanups\DNSReset\Disable-DNSReset.ps1' -WhatIf
```

## Backups and restore

Every change is backed up before it is made (JSON records under
`WindowsCleanupSuite\Backups\`, one folder per cleanup).

Restore:

```powershell
& 'WindowsCleanupSuite\Cleanups\InstalledSoftware\Restore-InstalledSoftware.ps1'
& 'WindowsCleanupSuite\Cleanups\WindowsSpeedup\Restore-ServicesAndTasks.ps1'
```

## Audit

```powershell
# Current state of services/tasks/Run keys (profile-aware)
& 'WindowsCleanupSuite\Audit\Audit-State.ps1' -Profile Balanced

# Installed-software audit: total installed + bloatware found vs. manifest
& 'WindowsCleanupSuite\Audit\Audit-InstalledSoftware.ps1'

# Snapshot of running services
& 'WindowsCleanupSuite\Audit\Audit-RunningServices.ps1'

# System health: sfc scan + DISM ScanHealth / RestoreHealth
& 'WindowsCleanupSuite\Audit\Check-SystemHealth.ps1'
```

Each audit prints a report; run them before and after the cleanups to compare.

## Tests

```powershell
& 'WindowsCleanupSuite\Tests\Invoke-SuiteTests.ps1'
```

Read-only structural checks: parses every `.ps1`, verifies manifests, and
checks the project does not reference the previous project.

## Safety notes

- `Run-Cleanup.ps1` is a preview by default. Pass `-Apply` to change state.
- HKLM/service changes require Administrator; non-admin runs stay at
  current-user scope where the API allows it.
- Protected components (Intel Driver & Support Assistant, DSA tasks, etc.) are
  never touched.
- Backups exist for everything the cleanup changes.
