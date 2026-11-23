# 02 - Component catalog research

Compiled 2026-11-23. Research only. Appx packages are in `02a-appx-packages.md`.
Local observations ("LOCAL") were read-only queries on one Insider machine (build 26300) and are
not a web source; nothing enters the catalog on LOCAL evidence alone.

## Source keys

| Key | URL | Kind |
|---|---|---|
| MC | https://learn.microsoft.com/en-us/windows/privacy/manage-connections-from-windows-operating-system-components-to-microsoft-services | Microsoft |
| DD | https://learn.microsoft.com/en-us/windows/privacy/configure-windows-diagnostic-data-in-your-organization | Microsoft |
| SYS | https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-system | Microsoft |
| PRIV | https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-privacy | Microsoft |
| EXP | https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-experience | Microsoft |
| SRV | https://learn.microsoft.com/en-us/windows-server/security/windows-services/security-guidelines-for-disabling-system-services-in-windows-server | Microsoft (Server 2016 defaults) |
| IOT | https://learn.microsoft.com/en-us/windows/iot/iot-enterprise/optimize/services | Microsoft |
| VDI | https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/rds-vdi-recommendations-2004 | Microsoft |
| EP/name | https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/NAME-LOWERCASE | Microsoft |
| EU | https://learn.microsoft.com/en-us/deployedge/microsoft-edge-update-policies | Microsoft |
| ODGP | https://learn.microsoft.com/en-us/sharepoint/use-group-policy | Microsoft |
| NI | https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-newsandinterests | Microsoft |
| SRCH | https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-search | Microsoft |
| WE | https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-admx-windowsexplorer | Microsoft |
| PS | https://raw.githubusercontent.com/undergroundwires/privacy.sexy/master/src/application/collections/windows.yaml | community |
| WU | https://raw.githubusercontent.com/ChrisTitusTech/winutil/main/config/tweaks.json | community |
| W4 | https://github.com/W4RH4WK/Debloat-Windows-10 | community |
| W11D | https://github.com/Raphire/Win11Debloat | community |

## 1. Telemetry

### 1.1 Services

| Service | Default start | Microsoft guidance | Source |
|---|---|---|---|
| DiagTrack (Connected User Experiences and Telemetry) | Automatic | SRV "No guidance"; IOT "OK to disable"; VDI "consider disabling if on disconnected network". No Microsoft page says disabling is supported on client editions. | SRV, IOT, VDI |
| dmwappushservice | Manual | SRV "OK to disable" but "required on client devices for Intune, MDM ... and Unified Write Filter" | SRV, IOT |
| diagnosticshub.standardcollector.service | Manual | IOT "Don't disable" | IOT |
| WerSvc | Manual | "Do not disable" | SRV, IOT |
| DPS, WdiServiceHost | Automatic / Manual | Diagnostics stop working | SRV |
| PcaSvc | Automatic | "OK to disable" | SRV, IOT |
| wisvc (Windows Insider Service) | Manual | "OK to disable"; needed for Insider Program | SRV, IOT |
| lfsvc (Geolocation) | Manual | "OK to disable"; apps lose location | SRV, IOT |
| MapsBroker (Downloaded Maps Manager) | Automatic | "OK to disable" | SRV, IOT |
| RetailDemo | Automatic per IOT, Manual on LOCAL | "OK to disable" | IOT |
| WMPNetworkSvc | Manual per IOT | "OK to disable" | IOT |

DiagTrack side effects, Microsoft-sourced:
- Windows Update for Business reports need at least Required diagnostic data: https://learn.microsoft.com/en-us/windows/deployment/update/wufb-reports-configuration-manual
- Insider builds need optional diagnostic data: https://learn.microsoft.com/en-us/windows-insider/business/manage-builds
- With diagnostic data off, "important information about update failures isn't sent" (DD).

### 1.2 Diagnostic data policies

Key `HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection` (SYS, MC).

- `AllowTelemetry` REG_DWORD: 0 Security/off, 1 Required, 2 Enhanced, 3 Optional (DD). Value 0 is honoured only on Enterprise, Education and Server; elsewhere it is treated as 1 (SYS). Value 2 exists only on Windows 10 1809 and earlier (DD).
- `DoNotShowFeedbackNotifications` = 1, since 1607 (EXP, MC).
- `DisableOneSettingsDownloads` = 1, Windows 11 21H2+; "apps using this service may stop working" (MC section 31).
- `LimitDiagnosticLogCollection`, `LimitDumpCollection`, `DisableDiagnosticDataViewer`: CSP names confirmed (SYS, DD); registry value names **unverified**.
- `AllowCommercialDataPipeline`: deprecated, 1809 only (SYS).

### 1.3 Scheduled tasks

No Microsoft page lists full task paths. Microsoft gives names and descriptions (VDI); full paths come from community sources.

| Full path | Microsoft description (VDI) | Path source | Notes |
|---|---|---|---|
| `\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser` | "Collects program telemetry information if opted-in to the Microsoft CEIP" | PS, W4 | absent on LOCAL 26300 |
| `\Microsoft\Windows\Application Experience\ProgramDataUpdater` | none | PS, W4 | PS: present on Win10 22H2, missing on Win11 22H2/23H2 |
| `\Microsoft\Windows\Application Experience\StartupAppTask` | "Scans startup entries and raises notification to the user if there are too many" | PS, W4 | not telemetry; left out |
| `\Microsoft\Windows\Autochk\Proxy` | "collects and uploads autochk SQM data if opted-in to the CEIP" | PS, W4 | |
| `\Microsoft\Windows\Customer Experience Improvement Program\Consolidator` | "collects and sends usage data to Microsoft" if CEIP consented | PS, W4 | |
| `\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip` | "Customer Experience Improvement Program task" | PS, W4 | |
| `\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector` | "reports general disk and system information to Microsoft for users participating in the Customer Experience Program" | PS, W4 | |
| `\Microsoft\Windows\Feedback\Siuf\DmClient` | none | W4 | |
| `\Microsoft\Windows\Windows Error Reporting\QueueReporting` | "Windows Error Reporting task to process queued reports" | PS, W4 | |
| `\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload`, Flighting tasks, `Microsoft Compatibility Appraiser Exp` | none | LOCAL only | left out: no web source |

- VDI warns that "several tasks ... can't be disabled with a script, even when run on an elevated command prompt".
- No source says Windows re-enables any of these tasks after updates: `returnsAfterFeatureUpdate` is `unknown` for all tasks.
- W4 names a Shell task `FamilySafetyRefresh`; VDI and LOCAL say `FamilySafetyRefreshTask`. Not in catalog.

### 1.4 Other privacy settings (all Microsoft-sourced unless marked)

| Setting | Location | Disable data | Source |
|---|---|---|---|
| Advertising ID (policy) | `HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo` `DisabledByGroupPolicy` | 1 | MC, PRIV |
| Tailored experiences | `HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent` `DisableTailoredExperiencesWithDiagnosticData` | 1 | MC, EXP |
| Activity history | `HKLM\SOFTWARE\Policies\Microsoft\Windows\System` `EnableActivityFeed`, `PublishUserActivities`, `UploadUserActivities` | 0 each | MC 18.22, PRIV |
| Error reporting (policy) | `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting` `Disabled` | 1 | https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-errorreporting |
| Feedback frequency | `HKCU\Software\Microsoft\Siuf\Rules` `NumberOfSIUFInPeriod`, `PeriodInNanoSeconds` | 0 each; delete both for default | MC 18.16 |
| Inking and typing | `HKCU\Software\Microsoft\InputPersonalization` `RestrictImplicitTextCollection`, `RestrictImplicitInkCollection` | 1 each | MC 18.21 |
| Online speech | `HKCU\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy` `HasAccepted` | 0 | MC |
| Language list for websites | `HKCU\Control Panel\International\User Profile` `HttpAcceptLanguageOptOut` | 1 | MC |
| App launch tracking | `HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced` `Start_TrackProgs` | 0 | MC |
| Delivery Optimization | `HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization` `DODownloadMode` | 0 = HTTP only, 99 = no peering and no DO cloud | MC 28.3, https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-deliveryoptimization |
| CEIP | `HKLM\Software\Policies\Microsoft\SQMClient\Windows` `CEIPEnable` | data value **unverified** | https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-admx-icm |
| Application telemetry | `HKLM\Software\Policies\Microsoft\Windows\AppCompat` `AITEnable`, `DisableInventory` | data values **unverified** | https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-admx-appcompat |

Differences from what tools commonly write:
- MC documents advertising ID `Enabled` = 0 under **HKLM**; the HKCU variant is community-only (WU, W4).
- `AllowLinguisticDataCollection` lives under `Software\Microsoft\Windows\CurrentVersion\Policies\TextInput`, not `Policies\Microsoft\Windows\TextInput` (https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-textinput).
- WU sets only `NumberOfSIUFInPeriod` and deletes `PeriodInNanoSeconds`; Microsoft's table sets both to 0.

Unverified, not in catalog: `Autologger-Diagtrack-Listener` `Start` = 0; `MaxTelemetryAllowed`; HKCU `TailoredExperiencesWithDiagnosticDataEnabled`; `HKCU\Software\Microsoft\Input\TIPC` `Enabled`; Wi-Fi Sense (removed in 1803).

## 2. Edge

All under `HKLM\SOFTWARE\Policies\Microsoft\Edge`, REG_DWORD, one Learn page per policy (EP/name). None carries a domain-join restriction.

| Value | Disable data | Min Edge | Status |
|---|---|---|---|
| StartupBoostEnabled | 0 | 88 | current |
| BackgroundModeEnabled | 0 | 77 | current |
| HubsSidebarEnabled | 0 | 99 | current; mandatory key only. From Edge 141 the Copilot toolbar icon is governed by `Microsoft365CopilotChatIconEnabled` |
| HideFirstRunExperience | 1 | 80 | current |
| ShowRecommendationsEnabled | 0 | 89 | current |
| SpotlightExperiencesAndRecommendationsEnabled | 0 | 86 | current |
| PersonalizationReportingEnabled | 0 | 80 | current |
| EdgeShoppingAssistantEnabled | 0 | 87 | current |
| ShowMicrosoftRewards | 0 | 88 | current |
| NewTabPageContentEnabled | 0 | 91 | current |
| NewTabPageBingChatEnabled | 0 | 117 | current |
| DefaultBrowserSettingsCampaignEnabled | 0 | 113 | current |
| DiagnosticData | 0 off ("Not recommended"), 1 required | 122 on Windows | current; not in catalog |
| EdgeAssetDeliveryServiceEnabled | 0 | 101 | "features won't be able to download assets needed for them to run correctly"; not in catalog |
| EdgeCollectionsEnabled, EdgeFollowEnabled, EdgeEnhanceImagesEnabled, CryptoWalletEnabled, GamerModeEnabled, WebWidgetAllowed, PromotionalTabsEnabled, EdgeWalletCheckoutEnabled, EdgeWalletEtreeEnabled | 0 | various | **obsolete or deprecated**; not in catalog |

Edge Update (EU), key `HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate`:
- `CreateDesktopShortcutDefault` = 0: no desktop shortcut at install. "If Microsoft Edge is already installed, this policy has no effect."
- `RemoveDesktopShortcutDefault` = 1 or 2 deletes shortcuts; 2 also deletes user-made ones. Not in catalog.
- Services `edgeupdate`, `edgeupdatem`: IOT "Don't disable ... security vulnerabilities and issues can't be fixed." Protected.
- Edge update task names carry a random suffix (community, PS) and differ on LOCAL; not in catalog (no exact identifier).

Edge removal:
- "our default web browser is an essential component of our operating system and can't be uninstalled": https://support.microsoft.com/en-us/edge/why-can-t-i-uninstall-microsoft-edge
- Uninstallable in the EEA since Win10 19045.4123 / Win11 22631.3235: https://blogs.windows.com/windows-insider/2023/11/16/previewing-changes-in-windows-to-comply-with-the-digital-markets-act-in-the-european-economic-area/
- WebView2 Runtime ships with Windows 11 and updates with Edge: https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution

Unverified: that policy presence causes Edge's "Managed by your organization" banner (widely reported, no Microsoft statement found); `DisableEdgeDesktopShortcutCreation`.

## 3. OneDrive

| Setting | Location | Data | Effect | Source |
|---|---|---|---|---|
| DisableFileSyncNGSC | `HKLM\Software\Policies\Microsoft\Windows\OneDrive` | 1 | No sync, no app or file-picker access, removed from Explorer nav pane | SYS, MC |
| KFMBlockOptIn | `HKLM\SOFTWARE\Policies\Microsoft\OneDrive` | 1 blocks the folder-backup prompt; 2 also redirects known folders back to the PC | No effect if KFMOptInWithWizard / KFMOptInNoWizard is set | ODGP |
| PreventNetworkTrafficPreUserSignIn | **Microsoft pages disagree**: MC says `HKLM\SOFTWARE\Microsoft\OneDrive`, ODGP says `HKLM\SOFTWARE\Policies\Microsoft\OneDrive` | 1 | | MC, ODGP |
| ShowSyncProviderNotifications | `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | 0 | Hides sync-provider ads in Explorer. Community only; value missing by default | PS |
| Nav pane CLSID | `HKCU\Software\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}` `System.IsPinnedToNameSpaceTree` | 0 | Community only | W11D |

- Uninstall: Microsoft's own sample runs `OneDriveSetup.exe /uninstall` and removes the default-profile Run value (https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/rds_vdi-recommendations-1909, written for 1909). Support article: "OneDrive is built in to some versions of Windows and can't be uninstalled" (https://support.microsoft.com/en-us/office/turn-off-disable-or-uninstall-onedrive-f32a17ce-3336-40fe-9c38-6efb09f944b0).
- OneDrive scheduled task names contain the user SID; no exact identifier, not in catalog.
- Windows Backup app: "a system component and cannot be removed" (https://support.microsoft.com/help/5032038).
- Not found: any Microsoft statement on OneDrive returning after feature updates.

## 4. Widgets / News and interests

- `HKLM\SOFTWARE\Policies\Microsoft\Dsh` `AllowNewsAndInterests` = 0 ("Allow widgets"; Windows 11 21H2 build 22000+; "applies to the entire widgets experience, including content on the taskbar"). Source NI, MC section 32.
- `DisableWidgetsBoard`, `DisableWidgetsOnLockScreen`: same key, listed by NI as Windows Insider Preview only. Not in catalog.
- Windows 10: `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds` `EnableFeeds` = 0 (MC 18.24; CSP https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-feeds).
- `TaskbarDa` (HKCU Explorer\Advanced): Microsoft Q&A staff say such values "are now system-managed ... no longer act as writable switches" (https://learn.microsoft.com/en-us/answers/questions/5638954/protected-registry-keys). Community reports tie the access-denied behaviour to the UCPD driver (https://oofhours.com/2025/05/02/what-is-windows-11s-new-ucpd-feature/). Not in catalog.
- Packages: Windows Web Experience Pack, Store id `9MSSGKG348SP` (https://support.microsoft.com/en-us/topic/a16c9bf1-f042-4dc9-a523-740cca1e1e60); package name `MicrosoftWindows.Client.WebExperience` per W11D and winutil (https://winutil.christitus.com/code-reference/tweaks/essential-tweaks/widget/). `Microsoft.StartExperiencesApp` is "a provider of widget and feed experiences" (https://blogs.windows.com/windows-insider/2025/06/02/updates-to-windows-for-the-digital-markets-act/).

## 5. Search

| Policy | Location | Disable data | Builds / editions | Source |
|---|---|---|---|---|
| DisableSearchBoxSuggestions | `HKCU\Software\Policies\Microsoft\Windows\Explorer` | 1 | Win10 19041.1202+, Win11 21H2+. Documented effect: recent search entries in File Explorer. Use as "disable Bing in Start" is community practice (W11D) | WE |
| AllowSearchHighlights (`EnableDynamicContentInWSB`) | `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search` | 0 | Win10 19042.1620+, Win11 22000.1761+ | SRCH |
| DoNotUseWebResults (`ConnectedSearchUseWeb`) | same key | 0 | Win10 1803+; **not supported on Pro** | SRCH |
| `DisableWebSearch` | same key | 1 | privacy baseline only, not on the CSP page | MC |
| AllowCortana | same key | 0 | Win10 1507+ | EXP |
| DisableSearch | same key | 1 | Win11 22H2+; removes the whole Search UI. Not in catalog | SRCH |

- Cortana "as a standalone app was retired in the spring of 2023" (https://support.microsoft.com/cortana).
- Community only, not in catalog: `BingSearchEnabled` (WU), `SearchboxTaskbarMode`, `IsDynamicSearchBoxEnabled`, `CortanaConsent`.
- EEA: web search from Bing is uninstallable there (DMA blog post above).

## 6. AI features and 7. Ads and suggestions

See `02b-ai-features.md` and `02c-ads-and-suggestions.md`.
