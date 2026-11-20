# WindowsAI cleanup manifest - Raphire Win11Debloat AI policy keys.
@{
    Project           = 'WindowsCleanupSuite'
    Cleanup           = 'WindowsAI'
    Description       = 'Disables Microsoft Copilot, Recall, Click to Do, Edge/Chrome/Paint/Notepad AI features, and WSAIFabricSvc (AI/analytics service). Based on Raphire Win11Debloat Regfiles: Disable_Copilot.reg, Disable_Recall.reg, Disable_Click_to_Do.reg, Disable_AI_Service_Auto_Start.reg, Disable_Edge_AI_Features.reg, Disable_Chrome_AI_Features.reg, Disable_Paint_AI_Features.reg, Disable_Notepad_AI_Features.reg.'
    ProtectedPatterns = @('*DSA*', '*Driver*Support*')

    Entries = @(
        # Raphire Disable_Copilot.reg
        @{ RegistryKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowCopilotButton'; Value = 0; Type = 'DWord'; Reason = 'Hide Copilot button on taskbar' },
        @{ RegistryKey = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Value = 1; Type = 'DWord'; Reason = 'Disable Copilot service (current user)' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Copilot service (all users)' },

        # Raphire Disable_AI_Recall.reg
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'AllowRecall'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Windows Recall (Windows 11 24H2+)' },

        # Raphire Disable_Click_to_Do.reg
        @{ RegistryKey = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableClickToDo'; Value = 1; Type = 'DWord'; Reason = 'Disable Click to Do (current user)' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableClickToDo'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Click to Do (all users)' },

        # Raphire Disable_AI_Service_Auto_Start.reg
        @{ RegistryKey = 'HKLM:\SYSTEM\CurrentControlSet\Services\WSAIFabricSvc'; Name = 'Start'; Value = 3; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable WSAIFabricSvc (AI/analytics service) - needs restart'; StopService = $true },

        # Raphire Disable_Edge_AI_Features.reg
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'CopilotCDuPageContext'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Copilot contextual menu (Edge)' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'CopilotPageContext'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Copilot page context (Edge)' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'HubSidebarEnabled'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Copilot sidebar (Edge)' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'Microsoft365CopilotChatIconEnabled'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Microsoft 365 Copilot chat icon (Edge)' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'EdgeEnterpriseCopilotPageContext'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable enterprise Copilot page context (Edge)' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'EdgeHistoryAISearchEnabled'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable AI history search (Edge)' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'ComposeInlineEnabled'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable inline AI compose (Edge)' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'GenAILocalFoundationalModelSettings'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable AI local foundational model (Edge)' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'NewTabPageBingChatEnabled'; Value = 0; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable New Tab Page AI chat (Edge)' },

        # Raphire Disable_Chrome_AI_Features.reg
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'AIModeSettings'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Chrome AI mode settings' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'AutofillPredictionSettings'; Value = 2; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Chrome AI autofill predictions' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'ChromeSuggestionsSettings'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Chrome AI suggestions' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'CreateThemesSettings'; Value = 2; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Chrome AI theme creation' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'DevToolsGenAiSettings'; Value = 2; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Chrome DevTools GenAI' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'FindAndFillWithGeminiSettings'; Value = 2; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Chrome Gemini search' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'GeminiSettings'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Chrome Gemini' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'GeminiSparkSettings'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Chrome Gemini spark' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'GenAILocalFoundationalModelSettings'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Chrome GenAI local model' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'HelpMeWriteSettings'; Value = 2; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Chrome help-me-write AI' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'HistorySearchSettings'; Value = 2; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Chrome history search AI' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'SearchContentSharingSettings'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Chrome AI search content sharing' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'SmartTabSharingSettings'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Chrome smart tab sharing' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'TabCompareSettings'; Value = 2; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Chrome tab compare AI' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'ThirdPartyAiChatSettings'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Chrome third-party AI chat' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'VoiceTypingSettings'; Value = 2; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Chrome voice typing AI' },

        # Raphire Disable_Paint_AI_Features.reg
        @{ RegistryKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'; Name = 'DisableCocreator'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Paint AI Cocreator' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'; Name = 'DisableGenerativeFill'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Paint AI generative fill' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'; Name = 'DisableImageCreator'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Paint AI image creator' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'; Name = 'DisableGenerativeErase'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Paint AI generative erase' },
        @{ RegistryKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'; Name = 'DisableRemoveBackground'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Paint AI remove background' },

        # Raphire Disable_Notepad_AI_Features.reg
        @{ RegistryKey = 'HKLM:\SOFTWARE\Policies\WindowsNotepad'; Name = 'DisableAIFeatures'; Value = 1; Type = 'DWord'; RequiresAdmin = $true; Reason = 'Disable Notepad AI features' }
    )
}
