# 02c - Ads and suggestions research

Compiled 2026-11-23. `[MS]` = read on a Microsoft page. `[C]` = community only. All values REG_DWORD unless stated.

## Source keys

| Key | URL |
|---|---|
| EXP | https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-experience |
| START | https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-start |
| MC | https://learn.microsoft.com/en-us/windows/privacy/manage-connections-from-windows-operating-system-components-to-microsoft-services |
| SPOT | https://learn.microsoft.com/en-us/windows/configuration/windows-spotlight/ |
| VDI | https://learn.microsoft.com/en-us/previous-versions/windows-server/it-pro/windows-server-2019/remote/remote-desktop-services/rds-vdi-recommendations-2004 |
| W11D | https://github.com/Raphire/Win11Debloat/tree/master/Regfiles |
| SOPH | https://github.com/farag2/Sophia-Script-for-Windows |
| D0 | https://raw.githubusercontent.com/Disassembler0/Win10-Initial-Setup-Script/master/Win10.psm1 |
| SYC | https://raw.githubusercontent.com/Sycnex/Windows10Debloater/master/Windows10Debloater.ps1 |
| PS | https://raw.githubusercontent.com/undergroundwires/privacy.sexy/master/src/application/collections/windows.yaml |

## 1. ContentDeliveryManager

Key `HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`. Disable = 0.

Microsoft documents none of the semantics. VDI names seven of the values in `reg add` lines with data 0. The UI mappings below come from Win11Debloat file comments `[C]`. Default data (1) is unconfirmed.

| Value | UI toggle `[C]` | On a Microsoft page | Tool sources |
|---|---|---|---|
| SubscribedContent-310093Enabled | Windows welcome experience after updates | no | W11D, SOPH, D0 |
| SubscribedContent-338388Enabled | "Occasionally show suggestions in Start" (Win10) | VDI | W11D, SOPH, D0 |
| SystemPaneSuggestionsEnabled | same toggle as 338388 | VDI | W11D, D0, SYC |
| SubscribedContent-338389Enabled | "Get tips, tricks, and suggestions as you use Windows" | VDI | W11D, SOPH, D0 |
| SoftLandingEnabled | same toggle as 338389 | no | W11D only |
| SubscribedContent-338393Enabled, -353694Enabled, -353696Enabled | "Show me suggested content in the Settings app" | VDI | W11D, SOPH, PS, D0 |
| SubscribedContent-353698Enabled | grouped with Settings suggestions | no | W11D, D0 |
| SubscribedContent-338387Enabled | lock screen fun facts and tips | no | W11D, D0 |
| RotatingLockScreenOverlayEnabled | lock screen fun facts and tips | no | W11D only |
| SilentInstalledAppsEnabled | automatic installation of suggested apps (no UI toggle) | no | W11D, SOPH, D0, SYC |
| ContentDeliveryAllowed, OemPreInstalledAppsEnabled, PreInstalledAppsEnabled, PreInstalledAppsEverEnabled | no UI; "application suggestions and automatic installation" | no | D0, SYC |
| SubscribedContent-314559Enabled | unknown | no | D0 only |

Microsoft confirms the toggle name "Show me suggested content in the Settings app": https://support.microsoft.com/en-us/windows/privacy/privacy-settings-for-recommendations-offers-in-windows-11

## 2. CloudContent policies

Key `Software\Policies\Microsoft\Windows\CloudContent`. Enable = 1. All `[MS]` from EXP. "E/Edu" = EXP's edition table shows Enterprise, Education, IoT Enterprise but not Pro.

| Value | Hive | Editions | Since |
|---|---|---|---|
| DisableWindowsConsumerFeatures | HKLM | E/Edu | 1607 |
| DisableSoftLanding | HKLM | E/Edu | 1607 |
| DisableCloudOptimizedContent | HKLM (MC section 25 says HKCU: Microsoft's pages disagree) | E/Edu | Win11 21H2 |
| DisableConsumerAccountStateContent | HKLM | E/Edu | Win11 21H2 |
| DisableWindowsSpotlightFeatures | HKCU | E/Edu | 1607 |
| DisableWindowsSpotlightOnActionCenter | HKCU | E/Edu | 1703 |
| DisableWindowsSpotlightOnSettings | HKCU | E/Edu | 1803 |
| DisableWindowsSpotlightWindowsWelcomeExperience | HKCU | E/Edu | 1703 |
| DisableThirdPartySuggestions | HKCU | Pro and E/Edu | 1607 |
| DisableTailoredExperiencesWithDiagnosticData | HKCU | Pro and E/Edu | 1703 |
| DisableSpotlightCollectionOnDesktop | HKCU | E/Edu | Win11 21H2 |

- DisableWindowsConsumerFeatures covers "Start suggestions, Membership notifications, Post-OOBE app install and redirect tiles" (EXP).
- "Windows spotlight is available on Windows Enterprise and Education editions only" for policy control (SPOT).

## 3. Start menu

| Value | Location | Data | Evidence |
|---|---|---|---|
| Start_IrisRecommendations | `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | 0 | `[C]` W11D, SOPH. "Show recommendations for tips, shortcuts, new apps, and more" |
| Start_AccountNotifications | same key | 0 | `[C]` W11D, SOPH. "Show account-related notifications" |
| Start_TrackDocs | same key | 0 | `[MS]` MC section 33. Recently opened items; not an ad, not in catalog |
| HideRecommendedSection | `Software\Policies\Microsoft\Windows\Explorer` | 1 | `[MS]` START lists Pro; community pages conflict on editions. Not in catalog |
| HideRecommendedPersonalizedSites | same key | 1 | `[MS]` START, Win11 22621.1928+. Scope not confirmed. Not in catalog |

## 4. Notifications, Explorer, taskbar

| Value | Location | Data | Evidence |
|---|---|---|---|
| ScoobeSystemSettingEnabled | `HKCU\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement` | 0 | value in VDI `[MS]`; UI mapping ("finish setting up your device") `[C]` W11D, SOPH |
| ShowSyncProviderNotifications | `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | 0 | `[C]` W11D, SOPH, PS |
| HideSCAMeetNow (Win10) | `HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer` | 1 | GPO "Remove the Meet Now icon" `[MS]` https://learn.microsoft.com/en-us/windows/configuration/taskbar/policy-settings ; value name `[C]` W11D, SOPH |
| AllowSuggestedAppsInWindowsInkWorkspace | `HKLM\Software\Policies\Microsoft\WindowsInkWorkspace` | 0 | `[MS]` https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-windowsinkworkspace |
| Windows.SystemToast.Suggested `Enabled`, `EnableAccountNotifications`, `TaskbarMn` | various HKCU | 0 | `[C]` W11D only. Not in catalog |

Not usable by this engine (needs key deletion or a JSON blob): blocking new Outlook auto-install (https://learn.microsoft.com/en-us/microsoft-365-apps/outlook/get-started/control-install), ConfigureStartPins.

## 5. Reset by feature updates

No Microsoft or reputable statement found either way. `returnsAfterFeatureUpdate` is `unknown` for every item here.

## Unverified

- Defaults of the HKCU toggles.
- FeatureManagementEnabled, SubscribedContentEnabled, RotatingLockScreenEnabled, and other SubscribedContent ids: not found on any page read.
- How promotional Start pins (Spotify, LinkedIn and similar) are delivered.
- `ConfigureChatAutoInstall`, `DevHomeUpdate`, `SmartClipboard`: search snippets only.
