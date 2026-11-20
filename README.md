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
│   └── WindowsSpeedup/
│       ├── Manifest.psd1            # data-driven lists: services, tasks, startup apps, process stops, visual effects
│       ├── Disable-ServicesAndTasks.ps1
│       └── Restore-ServicesAndTasks.ps1
├── Runners/
│   ├── Run-Cleanup.ps1              # main entry point: preview (dry-run) by default, -Apply to change state
│   └── Run-Monthly.ps1              # monthly wrapper: preview, then asks YES before applying
├── Audit/
│   └── Audit-State.ps1              # read-only post-run audit (services/tasks/Run keys)
└── Tests/
    └── Invoke-SuiteTests.ps1        # structural tests: parse every .ps1, check manifests + independence
```

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
```

## Backups and restore

Every change is backed up before it is made (JSON records in
`WindowsCleanupSuite\Backups\StartupBloat\` and `Backups\WindowsSpeedup\`).

Restore:

```powershell
& 'WindowsCleanupSuite\Cleanups\StartupBloat\Restore-StartupBloat.ps1'
& 'WindowsCleanupSuite\Cleanups\WindowsSpeedup\Restore-ServicesAndTasks.ps1'
```

## Audit

```powershell
& 'WindowsCleanupSuite\Audit\Audit-State.ps1' -Profile Balanced
```

Prints a table of services/tasks/Run entries and their current state.

## Tests

```powershell
& 'WindowsCleanupSuite\Tests\Invoke-SuiteTests.ps1'
```

Read-only structural checks: parses every `.ps1`, verifies manifests, and
checks the project does not reference the previous project.

## Safety notes

- `Run-Cleanup.ps1` is a preview by default. Pass `-Apply` to change state.
- HKLM/service changes require Administrator.
- Protected components (Intel Driver & Support Assistant, DSA tasks, etc.) are
  never touched.
- Backups exist for everything the cleanup changes.
