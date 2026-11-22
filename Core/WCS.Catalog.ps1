<#
.SYNOPSIS
    Menu catalog: Level definitions (menu levels 1-4 -> Balanced/Maximum profiles)
    and Topic definitions (which cleanups run per topic, default-on by level).

.DESCRIPTION
    The menu UI (Core\WCS.Menu.ps1) and the non-interactive CLI share this single
    source of truth so behavior is identical for both entry points.
#>

function Get-WCSLevelDefinitions {
    <#
        Levels map to Profiles used by the ServicesTasks cleanup
        (Cleanups\WindowsSpeedup\Disable-ServicesAndTasks.ps1):
          Safe (1) + Balanced (2) -> Balanced
          Aggressive (3) + Extreme (4) -> Maximum
        Each level's Topics with DefaultOn[LevelKey]: $true means the topic is
        preselected when the user picks that level.
    #>
    return @(
        @{
            Key         = 'Safe'
            Level       = 1
            Profile     = 'Balanced'
            Label       = 'Safe (Recommended)'
            Description = 'Balanced defaults: services, tasks, startup apps, privacy, updates, DNS, power plan, maintenance'
        }
        @{
            Key         = 'Balanced'
            Level       = 2
            Profile     = 'Balanced'
            Label       = 'Balanced'
            Description = 'Safe + AI Features, OneDrive and Visual Effects topics enabled'
        }
        @{
            Key         = 'Aggressive'
            Level       = 3
            Profile     = 'Maximum'
            Label       = 'Aggressive'
            Description = 'Maximum profile: more services set to Manual/Disabled, extra AI/OneDrive features'
        }
        @{
            Key         = 'Extreme'
            Level       = 4
            Profile     = 'Maximum'
            Label       = 'Extreme'
            Description = 'Maximum + ExtremeExtras (push, Store broker, SMS routing fully disabled)'
        }
    )
}

function Get-WCSTopicDefinitions {
    return @(
        @{
            Topic       = 'ServicesTasks'
            MinLevel    = 1
            DefaultOn   = @{ Safe = $true; Balanced = $true; Aggressive = $true; Extreme = $true }
            Cleanups    = @('Cleanups\StartupBloat\Disable-StartupBloat.ps1', 'Cleanups\WindowsSpeedup\Disable-ServicesAndTasks.ps1', 'Cleanups\InstalledSoftware\Disable-InstalledSoftware.ps1')
            Description = 'Disables nonessential services, scheduled tasks, startup apps and installed bloatware (also visual effects).'
        },
        @{
            Topic       = 'PrivacySettings'
            MinLevel    = 1
            DefaultOn   = @{ Safe = $true; Balanced = $true; Aggressive = $true; Extreme = $true }
            Cleanups    = @('Cleanups\PrivacySettings\Disable-PrivacySettings.ps1')
            Description = 'Privacy & telemetry: advertising ID, tailored experiences, personalization toggles.'
        },
        @{
            Topic       = 'AI'
            MinLevel    = 2
            DefaultOn   = @{ Safe = $false; Balanced = $true; Aggressive = $true; Extreme = $true }
            Cleanups    = @('Cleanups\WindowsAI\Disable-WindowsAI.ps1')
            Description = 'Disables Copilot/Recall/Click-to-Do, WSAIFabricSvc and AI policies (Edge/Chrome/Paint/Notepad).'
        },
        @{
            Topic       = 'OneDrive'
            MinLevel    = 2
            DefaultOn   = @{ Safe = $false; Balanced = $true; Aggressive = $true; Extreme = $true }
            Cleanups    = @('Cleanups\OneDrive\Disable-OneDrive.ps1')
            Description = 'Disables OneDrive auto-start and the sync service (files stay on disk).'
        },
        @{
            Topic       = 'ExtremeExtras'
            MinLevel    = 4
            DefaultOn   = @{ Safe = $false; Balanced = $false; Aggressive = $false; Extreme = $true }
            Cleanups    = @('Cleanups\ExtremeExtras\Disable-ExtremeExtras.ps1')
            Description = 'Fully disables push notifications, Store broker, SMS routing (Level 4 only).'
        },
        @{
            Topic       = 'Maintenance'
            MinLevel    = 1
            DefaultOn   = @{ Safe = $true; Balanced = $true; Aggressive = $true; Extreme = $true }
            Cleanups    = @('Cleanups\TempAndJunkFiles\Disable-TempAndJunkFiles.ps1')
            Description = 'Deletes temp/junk files, caches, prefetch, event logs; runs Disk Cleanup + defrag.'
        },
        @{
            Topic       = 'DNS'
            MinLevel    = 1
            DefaultOn   = @{ Safe = $true; Balanced = $true; Aggressive = $true; Extreme = $true }
            Cleanups    = @('Cleanups\DNSReset\Disable-DNSReset.ps1')
            Description = 'DNS flush + IP stack reset + TCP autotuning/RSS tuning.'
        },
        @{
            Topic       = 'WindowsUpdates'
            MinLevel    = 1
            DefaultOn   = @{ Safe = $true; Balanced = $true; Aggressive = $true; Extreme = $true }
            Cleanups    = @('Cleanups\WindowsUpdates\Disable-WindowsUpdates.ps1')
            Description = 'WU service to Manual, auto-restart off, drivers excluded, DO off.'
        },
        @{
            Topic       = 'Privacy'
            MinLevel    = 1
            DefaultOn   = @{ Safe = $true; Balanced = $true; Aggressive = $true; Extreme = $true }
            Cleanups    = @('Cleanups\Privacy\Disable-Privacy.ps1')
            Description = 'Privacy (Raphire-style policies): telemetry=0, advertising ID, activity history, CEIP, consumer content, suggestions (Risky items need -AllowRisky).'
        },
        @{
            Topic       = 'Browsers'
            MinLevel    = 1
            DefaultOn   = @{ Safe = $true; Balanced = $true; Aggressive = $true; Extreme = $true }
            Cleanups    = @('Cleanups\Browsers\Disable-Browsers.ps1')
            Description = 'Browser background modes off (Edge/Chrome/Firefox), disable Edge Startup Boost, Firefox Pocket.'
        },
        @{
            Topic       = 'Network'
            MinLevel    = 1
            DefaultOn   = @{ Safe = $true; Balanced = $true; Aggressive = $true; Extreme = $true }
            Cleanups    = @('Cleanups\Network\Disable-Network.ps1')
            Description = 'Network chatter: LLMNR off, Delivery Optimization Manual + policy, static DNS (Risky).'
        },
        @{
            Topic       = 'PowerPlan'
            MinLevel    = 1
            DefaultOn   = @{ Safe = $true; Balanced = $true; Aggressive = $true; Extreme = $true }
            Cleanups    = @('Cleanups\PowerPlan\Enable-UltimatePerformancePlan.ps1')
            Description = 'Ultimate Performance power plan active + hibernate off.'
        }
    )
}

function Get-WCSValidTopicNames {
    return @((Get-WCSTopicDefinitions).Topic)
}

function Get-WCSValidTopicByName {
    param([string]$Topic)
    return @((Get-WCSTopicDefinitions) | Where-Object { $_.Topic -eq $Topic })
}

function Get-WCSDefaultTopicSelection {
    param(
        [ValidateSet('Safe', 'Balanced', 'Aggressive', 'Extreme')]
        [string]$LevelKey
    )
    $level = (Get-WCSLevelDefinitions | Where-Object { $_.Key -eq $LevelKey })
    $result = @()
    foreach ($topic in (Get-WCSTopicDefinitions)) {
        if ($topic.MinLevel -le $level.Level -and $topic.DefaultOn[$LevelKey]) {
            $result += $topic.Topic
        }
    }
    return @($result)
}

function Get-WCSLevelByKey {
    param([ValidateSet('Safe', 'Balanced', 'Aggressive', 'Extreme')][string]$Key)
    return (Get-WCSLevelDefinitions | Where-Object { $_.Key -eq $Key })
}

function ConvertFrom-WCSLevelInput {
    <#
        Accepts: '1'-'4', 'Safe', 'Balanced', 'Aggressive', 'Extreme' (case-insensitive).
        Returns the canonical Key string, or throws when invalid.
    #>
    param([string]$LevelString)

    $trimmed = [string]$LevelString.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) { throw "Empty level input" }

    switch ($trimmed.ToLowerInvariant()) {
        '1' { $canonical = 'Safe' }
        '2' { $canonical = 'Balanced' }
        '3' { $canonical = 'Aggressive' }
        '4' { $canonical = 'Extreme' }
        'safe' { $canonical = 'Safe' }
        'balanced' { $canonical = 'Balanced' }
        'aggressive' { $canonical = 'Aggressive' }
        'extreme' { $canonical = 'Extreme' }
        default { throw "Invalid level '$trimmed'. Valid: 1, 2, 3, 4, Safe, Balanced, Aggressive, Extreme" }
    }
    if ($canonical -notin @((Get-WCSLevelDefinitions).Key)) {
        throw "Invalid level '$trimmed'. Valid: 1, 2, 3, 4, Safe, Balanced, Aggressive, Extreme"
    }
    return $canonical
}
