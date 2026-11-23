# 03 - Risk and breakage research

Research date: 2026-11-23. Targets: Windows 10 22H2, Windows 11 23H2 / 24H2 / 25H2.
Research only. No code copied from other repositories; commands appear only as descriptions of what a source reports.

## Evidence legend

| Tag | Meaning |
|---|---|
| [S] | Source URL fetched or returned by search during this research session |
| [L] | Observed locally (read-only `Get-AppxPackage`, `Get-Service`, registry read) on one Windows 11 Pro for Workstations machine, build 10.0.26300 (Insider), current-user scope, not elevated. Names can differ on 22H2 / 23H2 / 24H2 retail builds. |
| [U] | **Unverified**: from general knowledge, not confirmed against a source this session. Verify before the catalog relies on it. |

Known gaps (stated up front):

- Microsoft's former per-version "provisioned apps" and "system apps" Learn pages now redirect to a generic overview that contains no package table. There is no current first-party list of package names. The overview only gives the two enumeration commands. [S] https://learn.microsoft.com/en-us/windows/application-management/overview-windows-apps
- No GitHub issue was found that documents `sfc /scannow` or `DISM /RestoreHealth` failing specifically because of Recall/AI CBS package removal. The closest evidence is secondary (section B5). Treat that causal link as [U].
- No first-party statement was found that Windows Insider enrollment requires the DiagTrack service. Evidence is community-level (section B8).
- GitHub issue search was rate limited part-way through, so the issue sample is partial (Win11Debloat and winutil only; RemoveWindowsAI issues are cited through secondary reporting).

Shared source abbreviations used below:

- **SRV** = Microsoft Learn, "Security guidelines for system services in Windows Server 2016" (per-service name, description, recommendation). https://learn.microsoft.com/en-us/windows-server/security/windows-services/security-guidelines-for-disabling-system-services-in-windows-server
  Caveat: written for Server with Desktop Experience. Its "OK to disable" verdicts are server verdicts and several are wrong for a client (flagged per row).
- **APPS** = https://learn.microsoft.com/en-us/windows/application-management/overview-windows-apps
- **KB5072911** = https://support.microsoft.com/en-us/topic/kb5072911-multiple-symptoms-occur-after-provisioning-a-pc-with-a-windows-11-version-24h2-update-d2d30684-4e2b-47f5-9899-a00a8e0acb09
- **DMA** = https://blogs.windows.com/windows-insider/2025/06/02/updates-to-windows-for-the-digital-markets-act/
- **WV2** = https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution

---

## A. Components that must never be removed or disabled by default

General rule backed by Microsoft: system apps live under `C:\Windows\` and "are part of the Windows OS"; they are enumerated by `SignatureKind -eq "System"` [S] APPS. On the local machine every system-signed package also reported `NonRemovable = True` [L]. The engine should treat `SignatureKind = System` OR `NonRemovable = True` OR `IsFramework = True` as an automatic refusal, independent of any name list.

Microsoft also states: "We don't recommend applying policies that disable services that aren't [disabled] by default by Microsoft." [S] SRV

### A1. Security

| Component | Exact identifier | Why it must stay / what depends on it | Source |
|---|---|---|---|
| Defender antimalware service | service `WinDefend` | "Helps protect users from malware and other potentially unwanted software." Tamper Protection also blocks changes, so attempts fail noisily. | [S] SRV; presence [L] |
| Defender network inspection / core | services `WdNisSvc`, `MDCoreSvc`, `Sense` | Part of the Defender stack. Present locally. Role descriptions not sourced. | [L] names; role [U] |
| Windows Security app service | service `SecurityHealthService` | Backs the Windows Security UI. | [L] name; role [U] |
| Security Center | service `wscsvc` | Reports AV/firewall state to Windows. | [L] name; role [U] |
| Windows Security UI | Appx `Microsoft.SecHealthUI` (Win11). Win10 name `Microsoft.Windows.SecHealthUI` is [U]. | Locally flagged `NonRemovable` although not system-signed. Removing it leaves Defender running with no UI to manage it. | [L] |
| SmartScreen / reputation | Appx `Microsoft.Windows.Apprep.ChxApp`; service `webthreatdefsvc` | System-signed, NonRemovable locally. | [L] |

### A2. Windows Update and servicing

| Component | Identifier | Why | Source |
|---|---|---|---|
| Windows Update | service `wuauserv` | If disabled, "users of this computer will not be able to use Windows Update ... and programs will not be able to use the Windows Update Agent (WUA) API." | [S] SRV |
| Update Orchestrator | service `UsoSvc` | Recommendation: **"Do not disable"**. "Windows Update, including WSUS, depends on this service." | [S] SRV |
| BITS | service `BITS` | "any applications that depend on BITS, such as Windows Update ... are unable to automatically download programs". | [S] SRV |
| Delivery Optimization | service `DoSvc` | Microsoft's supported way to stop peer-to-peer is Download Mode 0, not killing the service; mode 100 (Bypass) can cause download failures (0x80d03002). | [S] https://learn.microsoft.com/windows/deployment/do/waas-delivery-optimization-faq |
| Update Medic | service `WaaSMedicSvc` | Repairs Update components and re-enables disabled update services; protected (Services console returns Access denied). Disabling requires a registry edit and is discouraged. | [S] (tech press) https://www.thewindowsclub.com/windows-update-medic-service ; https://www.howtogeek.com/799392/what-is-waasmedic-agent-exe-how-to-fix-high-disk-usage/ |
| Modules Installer | service `TrustedInstaller` | CBS servicing engine. A winutil issue is titled "Windows Update broken after system/debloat tooling: TrustedInstaller service ImagePath hijacked". | [L] name; [S] https://github.com/ChrisTitusTech/winutil/issues/4811 (title only read) |
| App Readiness | service `AppReadiness` | Recommendation: **"Do not disable"**. | [S] SRV |
| Appx deployment | services `AppXSvc`, `StateRepository` | AppXSvc: "if disabled, Store applications don't deploy to the system and may not function properly." StateRepository: "required infrastructure support for the application model." | [S] SRV |

Real-world confirmation: a winutil "Disable all updates" toggle left Store installs stuck at "Queued" and winget stuck at "Installing" until update settings were reverted. [S] https://github.com/ChrisTitusTech/winutil/issues/3859

### A3. Microsoft Store, licensing and app frameworks

| Component | Identifier | Why | Source |
|---|---|---|---|
| Microsoft Store | Appx `Microsoft.WindowsStore` | Delivery and update channel for most inbox apps and codecs. Only officially uninstallable in the EEA (Windows 10 and 11); there, Store-installed apps keep updating and the Store can be reinstalled. | [S] DMA; name [L] |
| Store purchase UI | Appx `Microsoft.StorePurchaseApp` | In-app purchase and licence acquisition UI. | [L] name; role [U] |
| App Installer / winget | Appx `Microsoft.DesktopAppInstaller` (also `Microsoft.Winget.Source`) | Hosts `winget` and .appx/.msix install handling. Locally flagged `NonRemovable`. Needs VCLibs UWPDesktop and UI.Xaml frameworks. | [L]; [S] https://learn.microsoft.com/windows/package-manager/winget ; https://github.com/microsoft/winget-cli/issues/5251 |
| VCLibs | `Microsoft.VCLibs.140.00`, `Microsoft.VCLibs.140.00.UWPDesktop` (older `110.00`/`120.00.UWPDesktop` also seen) | Framework dependency of App Installer and many Store apps. A missing `Microsoft.VCLibs.140.00.UWPDesktop` blocks App Installer install. | [L]; [S] https://github.com/microsoft/winget-cli/issues/5251 |
| WinUI 2 | `Microsoft.UI.Xaml.2.x` (2.7 and 2.8 seen) | Framework dependency of winget and inbox apps. Microsoft's own docs disagree on whether winget needs 2.7 or 2.8, so never prune "old" versions. | [L]; [S] https://learn.microsoft.com/windows/package-manager/winget ; https://learn.microsoft.com/en-us/windows/iot/iot-enterprise/deployment/install-winget-windows-iot |
| .NET Native | `Microsoft.NET.Native.Framework.x.y`, `Microsoft.NET.Native.Runtime.x.y` | Framework packages for UWP apps. | [L] names; role [U] |
| Windows App SDK runtime | `Microsoft.WindowsAppRuntime.1.x` / `.2`, `MicrosoftCorporationII.WinAppRuntime.Main.*`, CBS variants `Microsoft.WindowsAppRuntime.CBS.*` | Framework for WinUI 3 apps; CBS variants are system-signed. Seven side-by-side versions were present locally, which shows apps pin specific versions. | [L] |
| Other frameworks | `Microsoft.DirectXRuntime`, `Microsoft.Services.Store.Engagement`, `Microsoft.WidgetsPlatformRuntime` | Framework or runtime packages. | [L] |
| Store licensing | service `ClipSVC` | "if disabled, applications bought using Microsoft Store don't behave correctly." | [S] SRV |
| Licence manager | service `LicenseManager` | "if disabled then content acquired through the Microsoft Store will not function properly." | [S] SRV |
| Store install | service `InstallService` | Store install pipeline. | [L] name; role [U] |
| Windows activation | service `sppsvc` | Software Protection (activation). | [L] name; role [U] |
| .NET Framework | optional features `NetFx4-AdvSrv` / `NetFx3`; inbox .NET Framework 4.8.x | OS component used by PowerShell 5.1 (our own engine) and many desktop apps. Never remove; never disable the feature. | [U] feature names and claim (reference to check: https://learn.microsoft.com/en-us/dotnet/framework/install/on-windows-and-server) |

Framework rule for the engine: never remove a package where `IsFramework = True`. Windows removes unreferenced frameworks itself. [U] for the last sentence.

### A4. WebView2 and Edge

| Component | Identifier | Why | Source |
|---|---|---|---|
| WebView2 Evergreen Runtime | Win32 product; detect via `pv` value under `HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}` (or same GUID under HKCU) | "The Evergreen WebView2 Runtime will be included as part of the Windows 11 operating system." Production WebView2 apps must use the Runtime, not the browser, so removing it breaks them even if Edge stays. Edge and the Runtime binaries are hard-linked when versions match. | [S] WV2 |
| What depends on WebView2 | Widgets, new Outlook, Teams (Microsoft Q&A answers); Store, Copilot, Start search web pane (third-party explainer) | Microsoft Q&A answers list Teams, new Outlook and Widgets. Third-party app logins (Minecraft launcher, Autodesk) failed after a debloat tool removed it. | [S] community-level: https://learn.microsoft.com/en-us/answers/questions/5582726/edge-webview-runtime2 ; https://geekrewind.com/what-breaks-when-you-uninstall-microsoft-edge-completely/ ; https://github.com/ChrisTitusTech/winutil/issues/1075 |
| Edge browser | Appx `Microsoft.MicrosoftEdge.Stable`; services `edgeupdate`, `edgeupdatem`, `MicrosoftEdgeElevationService` | Officially uninstallable only in the EEA. In the EEA, after uninstall "other Microsoft apps won't prompt you to reinstall it". Elsewhere removal is a hack. Microsoft warns that uninstalling Edge stops PWAs and widgets working. `edgeupdate` also updates the WebView2 Runtime, so disabling it freezes WebView2 on an unpatched version. | [S] DMA; https://windowsreport.com/uninstalling-microsoft-edge-breaks-apps-widgets/ ; https://www.windowscentral.com/software-apps/windows-11/microsoft-will-let-windows-11-users-in-europe-uninstall-edge-bing-and-disable-ads-in-eea-dma ; services [L]; updater claim [S] WV2 (runtime updates automatically via the Edge updater) |
| Edge DevTools client | Appx `Microsoft.MicrosoftEdgeDevToolsClient` | System-signed, NonRemovable. | [L] |
| Legacy web host | Appx `Microsoft.Win32WebViewHost` | System-signed, NonRemovable. | [L] |

EEA detection is [U]: no first-party source was found describing how Windows decides a device is in the EEA. Do not try to detect or spoof region. Only offer Edge removal when Windows itself exposes an uninstall entry.

### A5. Shell, Start, Settings, sign-in (system apps)

All of the following are system-signed and `NonRemovable` on the local machine [L]. Microsoft's KB5072911 shows what happens when just three of them are *unregistered* (not even removed): Start menu fails with a critical error, taskbar missing, Explorer crashes, Settings silently fails to launch, `ShellHost.exe` crashes. [S] KB5072911

| Component | Appx identifier | What breaks | Source |
|---|---|---|---|
| Shell host (taskbar, notification UI) | `Microsoft.Windows.ShellExperienceHost` | Taskbar, flyouts. | [L]; [S] KB5072911 (symptom class) |
| Start menu | `Microsoft.Windows.StartMenuExperienceHost` | Start menu. | [L]; [S] https://learn.microsoft.com/en-us/troubleshoot/windows-client/shell-experience/troubleshoot-start-menu-errors |
| Client CBS (shell, Search, Windows Backup, input UI) | `MicrosoftWindows.Client.CBS` | Named in KB5072911 as one of the packages whose registration Start, Taskbar, Explorer and Settings need. "Windows Backup lives here" is [U]. | [S] KB5072911; [L] |
| Client Core | `MicrosoftWindows.Client.Core` | Named in KB5072911. | [S] KB5072911; [L] |
| System XAML | `Microsoft.UI.Xaml.CBS` | Named in KB5072911. | [S] KB5072911; [L] |
| File Explorer / AI / OOBE shells | `MicrosoftWindows.Client.FileExp`, `MicrosoftWindows.Client.CoreAI`, `MicrosoftWindows.Client.OOBE`, `MicrosoftWindows.Client.Photon`, `Windows.CBSPreview` | System-signed shell pieces. Roles not sourced. | [L] names; roles [U] |
| AI runtime shared with Explorer | `Microsoft.AIFabric.CBS.*`, `Microsoft.Windows.AugLoop.CBS` | Framework + system. User reports tie removal of `Microsoft.AIFabric.CBS` to File Explorer reverting to the classic UI (section B10). | [L]; [S] https://windowsforum.com/news/removewindowsai-cleanup-task-may-revert-windows-11-file-explorer-after-updates.447102/ |
| Settings | `windows.immersivecontrolpanel` | The Settings app itself. | [L] |
| Entra/MSA token broker | `Microsoft.AAD.BrokerPlugin` | Microsoft 365 desktop sign-in fails when missing; Microsoft ships a troubleshooter that reinstalls it and documents re-registering it. | [S] https://learn.microsoft.com/en-us/microsoft-365/troubleshoot/authentication/cannot-sign-in-microsoft-365-desktop-apps ; https://support.microsoft.com/en-gb/windows/access-work-or-school-troubleshooter-for-restoring-access-to-m365-desktop-applications-aae546b0-ee55-49a9-9784-9fa46d8c15cf |
| Account picker | `Microsoft.AccountsControl` | Account selection dialog for Store/apps. | [L] name; role [U] |
| OOBE / account flows | `Microsoft.Windows.CloudExperienceHost` | First-run, add-account, Hello enrollment flows. | [L] name; role [U] |
| Lock screen | `Microsoft.LockApp` | Lock screen. | [L] name; role [U] |
| Credential prompt | `Microsoft.CredDialogHost` | UAC/credential dialogs. | [L] name; role [U] |
| Hello enrollment | `Microsoft.BioEnrollment` | Face/fingerprint setup. | [L] name; role [U] |
| Others seen system-signed | `Microsoft.Windows.ContentDeliveryManager`, `Microsoft.Windows.CapturePicker`, `Microsoft.Windows.PrintQueueActionCenter`, `Windows.PrintDialog`, `Microsoft.AsyncTextService`, `Microsoft.ECApp`, `Microsoft.Windows.ParentalControls`, `Microsoft.Windows.PeopleExperienceHost`, `Microsoft.Windows.PinningConfirmationDialog`, `Microsoft.Windows.SecureAssessmentBrowser`, `Microsoft.Windows.AssignedAccessLockApp`, `Microsoft.Windows.NarratorQuickStart`, `Microsoft.Windows.OOBENetworkCaptivePortal`, `Microsoft.Windows.OOBENetworkConnectionFlow`, `Microsoft.Windows.XGpuEjectDialog`, `Microsoft.PPIProjection`, `Microsoft.XboxGameCallableUI`, `MicrosoftWindows.UndockedDevKit`, GUID-named packages (`1527c705-839a-4832-9118-54d4Bd6a0c89`, `c5e2524a-ea46-4f67-841f-6a9465d9d515`, `E2A4F912-2574-4A75-9BB0-0D023378592B`, `F46D4000-FD22-4DB4-AC8E-4E1DDDE828FE`) | Covered by the SignatureKind rule. `ContentDeliveryManager` is a common debloat target: configure it by policy/registry, never remove the package. | [L] |
| Windows 10 only | `Microsoft.Windows.Search`, `Microsoft.Windows.Cortana` (pre-2004), `Microsoft.MicrosoftEdge` (legacy) | Win10 system app names. | [U] |

### A6. Identity, Hello, encryption

| Component | Identifier | Why | Source |
|---|---|---|---|
| Passport | service `NgcSvc` | "If you disable this service ... includes the ability to sign in to the machine and single-sign on for apps and websites ... We recommend you don't reconfigure this service." SRV says "OK to disable" only because Server has no PIN/Hello: "Needed to sign in with PIN and Windows Hello". On a client, disabling can lock a PIN-only user out. | [S] SRV |
| Passport container | service `NgcCtnrSvc` | "the system can't access local user identity keys and TPM virtual smart cards. We recommend you don't reconfigure this service." | [S] SRV |
| Biometrics | service `WbioSrvc` | Fingerprint/face capture service. | [S] SRV |
| Web account manager | service `TokenBroker` | SSO token broker used with AAD.BrokerPlugin. | [L] name; role [U] |
| MSA sign-in | service `wlidsvc` | A blank Settings > Sign-in options page was fixed by setting this back to Manual. | [S] https://www.winhelponline.com/blog/sign-in-options-settings-blank/ |
| BitLocker | service `BDESVC` | Windows 11 24H2 turns on device encryption automatically on clean install with a Microsoft or Entra account and backs the key up to that account. Touching BitLocker services, TPM settings or boot configuration on such a machine risks a recovery-key prompt. | [S] https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/oem-bitlocker ; https://www.tomshardware.com/software/windows/windows-11-24h2-will-enable-bitlocker-encryption-for-everyone-happens-on-both-clean-installs-and-reinstalls ; service name [L] |
| Restore/backup plumbing | services `VSS`, `swprv` | Needed for System Restore, which the engine uses as a safety net. | [L] names; role [U] |

### A7. Platform services that debloat lists commonly disable

| Component | Identifier | Reality on a client | Source |
|---|---|---|---|
| Windows Search | service `WSearch` | Microsoft notes that "Optimize your PC" tools disable it and says not to run them if you want Search. Start/Explorer search and Outlook search depend on the index. SRV shows it disabled only because Server ships it disabled. | [S] https://learn.microsoft.com/en-us/troubleshoot/windows-client/shell-experience/windows-search-performance-issues ; SRV |
| SysMain | service `SysMain` | "Maintains and improves system performance over time." SRV: "No guidance". No Microsoft source found recommending disabling it on SSDs. | [S] SRV; SSD claim [U] |
| Push notifications | services `WpnService`, `WpnUserService_*` | Host the notification platform and the WNS connection; toast, tile and raw notifications. SRV "OK to disable" is a server verdict. On a client this silences all app notifications. | [S] SRV |
| Connected Devices Platform | services `CDPSvc`, `CDPUserSvc_*` | "Connected Devices and Universal Glass scenarios". Client impact (Nearby Sharing, Phone Link, Bluetooth quick settings, night light) is [U]. | [S] SRV; impact [U] |
| Telemetry | service `DiagTrack` | Also "enables features that support in-application and connected user experiences". See B8. | [S] SRV |
| WAP push | service `dmwappushservice` | "Service required on client devices for Intune, MDM and similar management technologies." | [S] SRV |
| Per-user services | names ending `_<LUID>` (for example `CDPUserSvc_d4ff14`) | Suffix is random per session, so the catalog must match on the template name. | [L] |

### A8. Gaming

| Component | Identifier | Why | Source |
|---|---|---|---|
| Game Bar | Appx `Microsoft.XboxGamingOverlay` (protocols `ms-gamebar`, `ms-gamingoverlay`) | Removing it leaves the protocol unhandled: a "You'll need a new app to open this ms-gamingoverlay link" popup appears when a game starts or a controller is connected. | [S] https://github.com/Raphire/Win11Debloat/issues/367 ; https://github.com/Raphire/Win11Debloat/issues/62 ; https://github.com/ChrisTitusTech/winutil/issues/4397 |
| Game Bar overlay helper | Appx `Microsoft.XboxGameOverlay` | Companion package. | [L] name; role [U] |
| Xbox sign-in | Appx `Microsoft.XboxIdentityProvider` | Store listing: system app that lets PC games connect to Xbox Live. | [S] https://apps.microsoft.com/detail/9wzdncrd1hkw ; name [L] |
| Xbox UI | Appx `Microsoft.Xbox.TCUI` | Xbox Live in-game UI (friends, invites). | [L] name; role [U] |
| Xbox app | Appx `Microsoft.GamingApp` | Game Pass client; can repair missing gaming components. | [L] name; [S] https://techcommunity.microsoft.com/discussions/windows11/reinstalling-the-microsoft-gaming-overlay/4365333 |
| Gaming Services | Appx `Microsoft.GamingServices`; services `GamingServices`, `GamingServicesNet` | Required to install and launch Game Pass / Store games. | [L] names; [S] community-level https://learn.microsoft.com/en-us/answers/questions/5876499/xbox-pc-app-login |
| Xbox services | `XblAuthManager`, `XblGameSave`, `XboxNetApiSvc`, `XboxGipSvc` | XblAuthManager: "If you stop this service, some applications may not operate correctly." XblGameSave: save data will not sync. SRV "Should be disabled" is a server verdict. | [S] SRV |
| Other | `Microsoft.XboxSpeechToTextOverlay`, `Microsoft.Edge.GameAssist`, `Microsoft.XboxGameCallableUI` (system) | Accessibility overlay; Edge Game Bar widget; system app. | [L] |

### A9. Inbox apps users expect, and codecs

None of these are system-critical, but silent removal causes "my files will not open" support cases. Names are [L] unless noted.

| App | Identifier | Note |
|---|---|---|
| Windows Terminal | `Microsoft.WindowsTerminal` | Default console host on Windows 11 [U]. LLM agents and our own docs will tell users to open it. |
| Notepad | `Microsoft.WindowsNotepad` | Default .txt handler on Win11. |
| Paint | `Microsoft.Paint` | Win10 22H2 name is [U]. |
| Photos | `Microsoft.Windows.Photos` | Default image handler. |
| Calculator | `Microsoft.WindowsCalculator` | One of the three apps Microsoft's own removal policy supported at launch (with Camera and Feedback Hub), so it is officially removable in managed environments. [S] https://techcommunity.microsoft.com/blog/windows-itpro-blog/policy-based-removal-of-pre-installed-microsoft-store-apps/4463835 |
| Snipping Tool | `Microsoft.ScreenSketch` | [U]: not present on the local machine. Handles Win+Shift+S and PrtScn on Win11 [U]. |
| Camera, Alarms | `Microsoft.WindowsCamera`, `Microsoft.WindowsAlarms` | |
| HEVC | `Microsoft.HEVCVideoExtension` | [S] https://learn.microsoft.com/en-us/answers/a/1180572 . HEVC is a paid Store item for most users, so removal can cost money to undo [U]. |
| HEIF | `Microsoft.HEIFImageExtension` | Reads/writes .heic/.heif. [S] https://www.windowscentral.com/software-apps/windows-11/how-to-add-support-for-heic-and-hevc-files-on-windows-11 |
| WebP, AV1, VP9, RAW, MPEG-2, AVC encoder | `Microsoft.WebpImageExtension`, `Microsoft.AV1VideoExtension`, `Microsoft.VP9VideoExtensions`, `Microsoft.RawImageExtension`, `Microsoft.MPEG2VideoExtension`, `Microsoft.AVCEncoderVideoExtension` | Codecs used by Photos, Media Player, Explorer thumbnails and browsers. Dependency detail is third-party. [L] names |

---

## B. Real-world breakage and recovery

### B1. Start menu / taskbar dead

- **First-party proof of mechanism.** After provisioning with Windows 11 24H2 cumulative updates from July 2025 (KB5062553) onward, `MicrosoftWindows.Client.CBS`, `Microsoft.UI.Xaml.CBS` and `MicrosoftWindows.Client.Core` could fail to register in time. Symptoms: Start menu critical error, missing taskbar, Explorer crash, Settings not launching. **Recovery (Microsoft):** re-register each package from its manifest under `C:\Windows\SystemApps` with `Add-AppxPackage -Register ... -DisableDevelopmentMode`, then restart the shell; a synchronous logon script for non-persistent VDI. [S] KB5072911 ; https://www.neowin.net/news/microsoft-updates-fix-for-broken-windows-11-25h2-24h2-crucial-ui-components/
  Lesson: these packages are fatal single points of failure, and re-registration only works while the package files still exist on disk. If a tool deleted the files, the remaining options are DISM/SFC or an in-place repair.
- **Start search dead after "safe" tweaks.** Multiple reports that Start/taskbar search returns nothing after default-mode debloat runs. Maintainer's recovery: re-enable the "Bing web search" setting and restart Explorer. One reporter needed a WebView2 Runtime reinstall; another needed System Restore. [S] https://github.com/Raphire/Win11Debloat/issues/830 ; https://github.com/Raphire/Win11Debloat/issues/361 ; https://github.com/ChrisTitusTech/winutil/issues/2541
  Lesson: "disable Bing in search" is not a zero-risk tweak on current builds. Tier it moderate and verify search after applying.
- `MicrosoftWindows.Client.WebExperience` (Widgets) is a normal, non-system package on the local machine [L]. No report was found that removing it alone kills Start. Risk is loss of Widgets and the weather button only [U].

### B2. Store unusable or removed

- Re-register route: `Get-AppxPackage -AllUsers` for the Store piped to `Add-AppxPackage -Register` on its manifest. Works only if package files remain; reported failures include 0x80073CF6 and "nothing found" when the package is gone. [S] https://learn.microsoft.com/en-us/answers/questions/3983846/how-to-reinstall-microsoft-store-app-in-windows-11 ; https://learn.microsoft.com/en-us/answers/questions/1420023/error-when-trying-to-reinstall-store
- `wsreset -i`: user-reported to bring the Store back on Windows 11; **not documented by Microsoft** (another user notes `wsreset /?` shows nothing). Treat as best-effort. [S] same thread as above
- Xbox app route: the Xbox app detects missing gaming components and offers a download button. [S] https://techcommunity.microsoft.com/discussions/windows11/reinstalling-the-microsoft-gaming-overlay/4365333
- EEA: Store is officially uninstallable and "You will be able to reinstall the Microsoft Store". [S] DMA
- Store "Queued" forever / winget stuck: caused by disabled update services, not by Store removal (A2). Recovery: restore update service defaults. [S] https://github.com/ChrisTitusTech/winutil/issues/3859
- Last resort: in-place repair (B12).

### B3. Windows Update / feature upgrade failures

- Disabled update services break Store and winget as well as Windows Update. [S] https://github.com/ChrisTitusTech/winutil/issues/3859
- AI/CBS package removal: a packager of RemoveWindowsAI warns that Windows Update "may fail or be blocked after removing AI components, particularly CBS packages", and that CBS package and Recall removal are not reversible without a repair or reinstall. [S] https://wapt.tranquil.it/store/en/details/tis-remove-windows-ai_0-3_windows_10.0.26100_PROD.wapt ; https://windowsforum.com/windows-news.4/removewindowsai-one-click-debloat-of-windows-11-ai-features.393824/latest
- Edge removal: community guidance says updates may fail or loop, or simply reinstall Edge. Not confirmed by Microsoft. [S] https://geekrewind.com/what-breaks-when-you-uninstall-microsoft-edge-completely/ ; winutil reports that removing Edge also removed Edge Update: https://github.com/ChrisTitusTech/winutil/issues/2791
- Removed provisioned apps return on feature updates; this is long-standing behaviour. [S] https://learn.microsoft.com/en-us/archive/blogs/mniehaus/windows-10-1607-keeping-apps-from-coming-back-when-deploying-the-feature-update . The supported persistent method is the policy "Remove default Microsoft Store packages from the system" (Enterprise/Education 25H2, later extended to 24H2; not planned for Pro). [S] https://techcommunity.microsoft.com/blog/windows-itpro-blog/policy-based-removal-of-pre-installed-microsoft-store-apps/4463835 . Idempotent re-runs are therefore a design requirement.
- Sysprep/imaging: deprovisioning a package without removing it for every user (or the reverse) makes Sysprep fail. [S] https://learn.microsoft.com/en-us/troubleshoot/windows-client/deployment/sysprep-fails-remove-or-update-store-apps . Guard: always handle provisioned + all-user state together, and warn on reference images.
- Error codes commonly seen (0x800f0922, 0x80073712) are generic (EFI space, missing servicing files) and do not by themselves prove debloat damage. [S] https://support.microsoft.com/kb/883825

### B4. Generic recovery ladder (use in our docs)

1. Undo our own change from the engine's journal (registry backup, service start type, re-register package).
2. `DISM /Online /Cleanup-Image /RestoreHealth`, then `sfc /scannow`. [S] https://learn.microsoft.com/en-us/troubleshoot/windows-server/installing-updates-features-roles/fix-windows-update-errors
3. System Restore, if a point exists (limits in B13).
4. In-place repair: Settings > System > Recovery > "Fix problems using Windows Update" > Reinstall now. Reinstalls the current version and keeps apps, files and settings. Needs Windows 11 22H2 with the February 2024 optional update or later; may be unavailable on managed devices. [S] https://support.microsoft.com/en-us/topic/497ac6da-7cac-4641-82a5-f50398d879a0 . On Windows 10 22H2 use Setup from matching ISO media with "keep apps and files" [U].
5. Reset this PC / clean install.

### B5. SFC / DISM failures after CBS package removal

- **[U] as a direct causal claim.** No primary report was located. Supporting evidence is indirect: the tool installs a custom update package into the CBS store to block reinstall of AI packages, and reviewers call breaking "Windows Update, feature upgrades, or in-place servicing the single greatest technical risk". [S] https://www.majorgeeks.com/files/details/remove_windows_ai.html ; https://windowsforum.com/windows-news.4/removewindowsai-one-click-debloat-of-windows-11-ai-features.393824/latest
- Independent of debloat, `/RestoreHealth` can fail with 0x800f0915 after particular cumulative updates, so a failing RestoreHealth is not proof of tool damage. [S] https://learn.microsoft.com/en-us/answers/questions/5806219/kb5077241-appears-to-damage-dism-on-24h2-and-25h2
- Design consequence: the engine must never call `DISM /Remove-Package`, edit CBS package visibility/ownership in the registry, or delete from `WinSxS` / `SystemApps`. Use only documented switches: optional features, capabilities, Appx removal, policy.

### B6. Settings pages broken

- Sign-in options page blank: caused by the Microsoft Account Sign-in Assistant service being disabled; fix is `wlidsvc` back to Manual. [S] https://www.winhelponline.com/blog/sign-in-options-settings-blank/
- Settings fails to launch at all when Client.CBS / UI.Xaml.CBS / Client.Core are unregistered. [S] KB5072911
- Microsoft 365 / work account sign-in broken when `Microsoft.AAD.BrokerPlugin` is missing; fix is Microsoft's troubleshooter or re-registration. [S] https://learn.microsoft.com/en-us/microsoft-365/troubleshoot/authentication/cannot-sign-in-microsoft-365-desktop-apps
- Accounts > Windows Backup page breaking after package removal: **[U]**, no report found.

### B7. "ms-gamingoverlay" / "ms-gamebar" popup

- Cause: Game Bar package removed while capture features and the protocol association remain. Appears on game launch or controller connect, on Windows 10 and 11 including 25H2. [S] https://github.com/Raphire/Win11Debloat/issues/367 ; https://github.com/Raphire/Win11Debloat/issues/62 ; https://github.com/Raphire/Win11Debloat/issues/386 ; https://github.com/Raphire/Win11Debloat/issues/80
- Recoveries reported:
  - Turn capture off: `AppCaptureEnabled = 0` under `HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR` and `GameDVR_Enabled = 0` under `HKCU\System\GameConfigStore`. [S] issue 367 comments; https://github.com/ChrisTitusTech/winutil/issues/4397
  - Register stub handlers for the `ms-gamebar` (and `ms-gamingoverlay`) URL protocols so the shell stops prompting. [S] issue 367
  - Reinstall Game Bar from the Store / Xbox app, disable it in Settings > Gaming, optionally uninstall again. [S] winutil 4397; https://windowsreport.com/youll-need-new-app-open-ms-gamingoverlay-link/
- Design consequence: "remove Game Bar" must be one catalog item that always applies the capture-off settings first and offers the stub handler, never a bare package removal.

### B8. Telemetry service disabled

- With "Connected User Experiences and Telemetry" (`DiagTrack`) disabled, users report the Optional diagnostic data toggle is greyed out and Windows Insider enrollment cannot proceed; fix reported is setting the service back to Manual/Automatic and starting it. Community-level. [S] https://techcommunity.microsoft.com/discussions/windowsinsiderprogram/i-cant-turn-on-optional-diagnostic-data/2378006 ; https://techcommunity.microsoft.com/discussions/windowsinsiderprogram/optional-diagnostic-data/2573581
- Microsoft's own description says the service also "enables features that support in-application and connected user experiences". [S] SRV
- Feedback Hub and compatibility-hold ("safeguard") evaluation depending on DiagTrack: [U].
- The local test machine is itself an Insider build (26300) with DiagTrack Automatic [L]. Guard is mandatory.
- Prefer the supported route: set diagnostic data to Required via policy instead of disabling the service. [S] https://learn.microsoft.com/windows/privacy/windows-diagnostic-data

### B9. OneDrive removal with Known Folder Move

- Uninstalling OneDrive does not move Desktop/Documents/Pictures back; Windows keeps pointing at the OneDrive path. Deleting the OneDrive folder that holds those folders deletes the data, and synced deletions go to the OneDrive web recycle bin, not the local one. [S] https://learn.microsoft.com/en-us/answers/a/12182878 ; https://techcommunity.microsoft.com/discussions/onedriveforbusiness/a-bunch-of-files-are-missing-from-desktop-folders-managed-by-onedrive/4487218
- Debloat-tool reports: Desktop folder missing from the backup folder after an uninstall script. [S] https://www.github.com/Sycnex/Windows10Debloater/issues/550 ; https://www.github.com/Sycnex/Windows10Debloater/issues/545 . A copy step failing with Access Denied, the tool assuming OneDrive lives inside the profile, and cloud-only placeholder files not being movable. [S] https://github.com/ChrisTitusTech/winutil/issues/2125 ; https://github.com/ChrisTitusTech/winutil/issues/1154
- Recovery: files are usually still under the OneDrive folder or online. Stop backup per folder choosing "keep on this PC", use each folder's Properties > Location > Restore Default, then uninstall. [S] https://learn.microsoft.com/en-us/answers/a/12182878
- Detecting KFM (our guard): read `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders` values `Desktop`, `Personal`, `My Pictures` (also `My Music`, `My Video`, and `{374DE290-123F-4565-9164-39C4925E467B}` for Downloads) and test whether the expanded path sits under a OneDrive root. Roots come from the `OneDrive`, `OneDriveConsumer`, `OneDriveCommercial` environment variables and the `UserFolder` value under `HKCU\Software\Microsoft\OneDrive\Accounts\<Personal|BusinessN>`. Value names confirmed present locally [L]. A dedicated "KFM state" registry value is [U]; do not rely on one.
- Also check for dehydrated (cloud-only) files before any move; file attribute test is [U].

### B10. Copilot / Recall removal fallout

- October 2024: removing the Recall package from a 24H2 image also removed a shared runtime package that provides the modern File Explorer (tabs, dark mode), so Explorer reverted to the old UI. Disabling instead of removing avoided it. Unclear whether bug or intent. [S] https://www.notebookcheck.net/Removing-Windows-Recall-breaks-File-Explorer-in-latest-24H2-update.899991.0.html ; https://christitus.com/microsoft-recall-situation/ ; https://itsfoss.com/news/microsoft-windows-recall/
- 2026: a stale scheduled cleanup task from an AI-removal tool re-ran after cumulative updates and File Explorer reverted to the classic UI on 25H2 (build 26200.9457 to 26200.9550); reports name `Microsoft.AIFabric.CBS`. Recovery reported: disable the tool's scheduled task, restore a feature-management override, install the next cumulative update. Related issue: file associations broken. [S] https://windowsforum.com/news/removewindowsai-cleanup-task-may-revert-windows-11-file-explorer-after-updates.447102/ ; https://github.com/zoicware/RemoveWindowsAI/issues/247 (title only seen via secondary source)
- Supported route exists: Recall is an optional component controlled by the "Allow Recall" policy, and is disabled and removed by default on managed devices. Users can remove it through Optional features. [S] https://learn.microsoft.com/windows/client-management/manage-recall ; https://www.pcworld.com/article/2470708/microsoft-now-confirms-you-can-opt-out-of-and-remove-windows-recall.html
- Design consequences: (1) AI items are policy-first, optional-feature second, CBS surgery never. (2) The engine must not install scheduled tasks that re-apply removals after updates; that is exactly what caused the 2026 regression.

### B11. Edge removal

- WebView2 removed along with Edge: Minecraft launcher and Autodesk sign-in failed; one user could not reinstall WebView2 ("doesn't meet the minimum hardware requirements"). [S] https://github.com/ChrisTitusTech/winutil/issues/1075
- Edge could not be reinstalled after scripted removal; Edge Update removed too. [S] https://github.com/ChrisTitusTech/winutil/issues/340 ; https://github.com/ChrisTitusTech/winutil/issues/2791
- Widgets, PWAs, Start web results, "learn more" help links stop working. [S] https://windowsreport.com/uninstalling-microsoft-edge-breaks-apps-widgets/ ; https://geekrewind.com/what-breaks-when-you-uninstall-microsoft-edge-completely/
- Recovery: reinstall the Evergreen WebView2 Runtime with Microsoft's bootstrapper or standalone installer; reinstall Edge from microsoft.com. [S] WV2

### B12. In-place repair install

Covered in B4 step 4. It is the only recovery that reliably restores deleted system app files and CBS state while keeping user data. [S] https://support.microsoft.com/en-us/topic/497ac6da-7cac-4641-82a5-f50398d879a0

### B13. Limits of System Restore

- **Off by default.** Microsoft's System Protection page says it is not enabled by default and recommends turning it on. [S] https://support.microsoft.com/windows/system-protection-e9126e6e-fa64-4f5f-874d-9db90e57645a ; https://www.ghacks.net/2022/01/02/find-out-if-system-restore-is-enabled-on-windows-11-devices/
- **24-hour throttle.** If `SystemRestorePointCreationFrequency` (DWORD, minutes) under `HKLM\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore` does not exist and a restore point was created in the last 24 hours, Windows silently skips the new one and still reports success. Value 0 means never skip; value N means skip if one exists within N minutes. [S] https://learn.microsoft.com/en-us/windows/win32/sr/calling-srsetrestorepoint
  Consequence: a "restore point created" message is not proof. The engine must compare the newest restore point's sequence number/time before and after, and tell the user plainly when none was created. Changing the frequency value is itself a system change: record and restore it.
- **60-day retention.** After the June 2025 security update (KB5060842), Windows 11 24H2 keeps restore points for up to 60 days; older ones are unavailable. Press reports say the previous limit was 90 days. [S] https://support.microsoft.com/en-us/kb/5060842 ; https://learn.microsoft.com/windows/win32/sr/restoring-the-system ; https://tech.slashdot.org/story/25/06/23/2140208/microsoft-sets-new-60-day-limit-for-system-restore-points-in-windows-11-update
- **Points vanish.** Users report all prior restore points missing after a debloat run plus a Windows update; maintainer notes Windows can remove restore points after an update. [S] https://github.com/Raphire/Win11Debloat/issues/576
- **Does not reliably bring back apps or their data.** In the same issue a user restored to recover Sticky Notes content and found the app and notes corrupted. [S] https://github.com/Raphire/Win11Debloat/issues/576 . The general statement that System Restore does not reliably restore per-user Appx removals is otherwise [U].
- **Scope.** Windows 8 and later monitor only boot-volume files relevant to restore; personal data is untouched. [S] https://learn.microsoft.com/en-us/windows/win32/sr/calling-srsetrestorepoint ; https://support.microsoft.com/windows/system-protection-e9126e6e-fa64-4f5f-874d-9db90e57645a
- One tool created its backup after the changes ran instead of before. [S] https://github.com/Raphire/Win11Debloat/issues/360 . Order and verification matter.

Conclusion: System Restore is a secondary net. The primary undo mechanism must be the engine's own per-change journal.

### B14. Registry backup best practice

- Microsoft's command reference: "before editing any registry entries, you must save the parent subkey using the reg save command. If the edit fails, you can then restore the original subkey using the reg restore operation." [S] https://learn.microsoft.com/windows-server/administration/windows-commands/reg-save
- `reg export` writes a text .reg of a key and its subkeys. [S] https://learn.microsoft.com/windows-server/administration/windows-commands/reg-export . Manual export of the key you are about to change is also Microsoft's consumer guidance. [S] https://support.microsoft.com/en-us/help/322756/how-to-back-up-and-restore-the-registry-in-windows
- A full-registry export is not a full system backup. [S] (third party) https://helpdeskgeek.com/back-up-and-restore-windows-registry/
- Recommendation for our engine:
  - Journal **per value**: key path, value name, whether it existed, previous type and data. This is the only form that can undo a value that did not exist before (importing a .reg merges; it never deletes values that were added later) [U for the merge-semantics sentence].
  - Additionally `reg export` the specific touched key to a timestamped file as a human-readable fallback.
  - Do not export whole hives as the undo mechanism: large, slow, cannot be merged selectively, and re-importing an old full export over a live system can revert unrelated changes [U].
  - HKCU changes are per user: journal the SID, and handle other loaded/unloaded user hives explicitly rather than assuming the elevated account is the target user [U].

---

## C. Recommended tiers and guard conditions

Tier meanings: **safe** = reversible, no reported breakage; **moderate** = reversible but changes visible behaviour or has reported edge cases; **aggressive** = removes functionality some users need, undo may need a download; **never-default** = engine refuses unless the item is explicitly named by the user.

| # | Risk / item | Tier | Guard conditions (detect how) |
|---|---|---|---|
| 1 | Any package with `SignatureKind = System`, `NonRemovable = True` or `IsFramework = True` | never-default (hard refusal) | Evaluate properties at run time; do not rely only on a name list. |
| 2 | Defender / Security Health / `wscsvc` / `Microsoft.SecHealthUI` | never-default | No override in default profiles. |
| 3 | Update stack services (`wuauserv`, `UsoSvc`, `BITS`, `DoSvc`, `WaaSMedicSvc`, `TrustedInstaller`, `AppXSvc`, `AppReadiness`, `StateRepository`) | never-default | Offer policy-based deferral/pause and Delivery Optimization Download Mode 0 as the **safe/moderate** alternative. |
| 4 | Store + frameworks + licensing (`Microsoft.WindowsStore`, `Microsoft.StorePurchaseApp`, `Microsoft.DesktopAppInstaller`, VCLibs, UI.Xaml, NET.Native, WindowsAppRuntime, `ClipSVC`, `LicenseManager`, `InstallService`) | never-default | Store removal only when Windows itself offers uninstall (EEA); never infer region. |
| 5 | WebView2 Runtime | never-default | Presence check via the EdgeUpdate `pv` value. If absent, warn rather than "fix". |
| 6 | Edge browser removal | never-default outside EEA; aggressive where Windows exposes a supported uninstall | Require WebView2 Runtime present after the operation; never touch `edgeupdate` services while WebView2 is installed; confirm another browser is installed and is default. |
| 7 | Edge noise reduction (first-run, default-browser nags, sidebar, startup boost) via policy | safe | None. |
| 8 | Game Bar removal (`Microsoft.XboxGamingOverlay`) | aggressive | Skip if user games. Always pair with capture-off settings and protocol stub (B7). |
| 9 | Game DVR / capture off (settings only) | safe | None; reversible. |
| 10 | Xbox identity / services (`Microsoft.XboxIdentityProvider`, `Microsoft.Xbox.TCUI`, `Microsoft.GamingServices`, `Microsoft.GamingApp`, `Xbl*`, `XboxNetApiSvc`, `XboxGipSvc`) | aggressive | Skip if any of: `Microsoft.GamingApp` or `Microsoft.GamingServices` installed and used, Steam/Epic/GOG/Battle.net/EA install keys present, Minecraft installed, an Xbox controller paired, or user answers "I game". Heuristics are [U]; ask when uncertain. |
| 11 | Hello / biometrics / NGC services | never-default | If a PIN or biometric is enrolled, hard refusal: the user could be locked out. |
| 12 | BitLocker / device encryption, TPM, boot config | never-default | If the OS volume is encrypted or encrypting, also show a "save your recovery key" notice before any run. |
| 13 | Shell packages (ShellExperienceHost, StartMenuExperienceHost, Client.CBS, Client.Core, UI.Xaml.CBS, AAD.BrokerPlugin, AccountsControl, CloudExperienceHost, LockApp, immersivecontrolpanel) | never-default | Covered by item 1; also listed by name. |
| 14 | Widgets off by policy | safe | None. |
| 15 | Widgets package removal (`MicrosoftWindows.Client.WebExperience`) | moderate | Prefer policy. Confirm it is not system-signed on the target build. |
| 16 | "Disable Bing/web search in Start" | moderate | Post-check that local search still returns results; document the revert (B1). |
| 17 | `WSearch` disable | aggressive | Skip if classic Outlook is installed or user relies on Explorer/Start search. Offer index-scope reduction instead. |
| 18 | `SysMain` disable | aggressive | No sourced benefit; off by default in every profile. |
| 19 | `WpnService` / `WpnUserService` | never-default | Offer per-app notification and suggestion toggles (safe) instead. |
| 20 | `CDPSvc` / `CDPUserSvc` | never-default | Skip regardless; Phone Link, Nearby Sharing, Bluetooth users affected [U]. |
| 21 | Telemetry level to Required via policy | safe | None. |
| 22 | `DiagTrack` / `dmwappushservice` disable | aggressive | Skip if Insider-enrolled (detect: `HKLM\SOFTWARE\Microsoft\WindowsSelfHost\Applicability` has a channel/branch value [U]), if MDM/Intune enrolled, or if Entra-joined (`dsregcmd /status`). |
| 23 | OneDrive uninstall | aggressive | Skip if KFM active (B9 detection), if a Business account is configured, or if sync is in progress. Never move or delete user files; instruct the user to turn off folder backup first. |
| 24 | OneDrive: stop autostart / hide nag | safe | None. |
| 25 | Copilot / Recall / AI off via policy | safe | None. |
| 26 | Recall optional feature removal; Copilot Appx removal | moderate | Only through Optional Features / Appx. Check Explorer still shows tabs afterwards on 24H2+. |
| 27 | AI CBS package removal, `DISM /Remove-Package`, CBS registry edits, SystemApps/WinSxS deletion | never-default (not implemented at all) | Engine has no code path for this. |
| 28 | Persistent "re-apply after update" scheduled tasks | never-default (not implemented) | See B10. Idempotent manual re-run is the supported pattern. |
| 29 | Codecs (HEVC, HEIF, WebP, AV1, VP9, RAW, MPEG-2) | never-default | HEVC may be a paid entitlement. |
| 30 | Terminal, Notepad, Paint, Photos, Calculator, Snipping Tool | aggressive, off by default | Skip if the app is the registered default handler for any file type or protocol, or if no replacement is installed. |
| 31 | Consumer apps (Clipchamp, Solitaire, News, Bing apps, Feedback Hub, Get Help, Teams consumer, Office Hub stub, third-party promos) | safe | Remove for current user + deprovision together; skip on Sysprep reference images; expect return after feature updates. |
| 32 | Phone Link (`Microsoft.YourPhone`), Cross Device (`MicrosoftWindows.CrossDevice`) | moderate | Skip if a phone is linked [U detection]. |
| 33 | Provisioned-package removal on imaging machines | moderate | Detect audit mode / reference image; warn about Sysprep (B3). |
| 34 | Anything on a managed device | refuse by default | Detect domain join, Entra join, MDM enrollment; policies will fight the tool and may be owned by IT. |

Engine-level guards that apply to every run:

- Preflight: OS build and edition on an allowlist (19045; 22631; 26100; 26200). Unknown or Insider builds require an explicit flag, because package names shift (the local 26300 build already shows `MicrosoftWindows.Client.CoreAI`, `Client.FileExp`, `Client.Photon`, `Windows.CBSPreview`) [L].
- Preflight: pending reboot or servicing in progress means stop.
- Journal every change before making it; verify after; print the exact undo command.
- Attempt a restore point, then verify one was really created (B13); never claim success from the API return alone.
- Dry-run is the default mode for LLM agents; apply requires an explicit flag.
- Refuse wildcard matches that hit any protected identifier.

---

## Protected identifiers

Machine-usable. The engine must refuse to remove, disable or modify these unless the user names the exact identifier explicitly. Trailing `*` is a prefix wildcard. Matching is case-insensitive. Entries marked `#U` are unverified names.

```yaml
protected:
  appx_rules:            # property-based, evaluated first
    - SignatureKind == System
    - NonRemovable == true
    - IsFramework == true

  appx_names:
    # security
    - Microsoft.SecHealthUI
    - Microsoft.Windows.SecHealthUI            #U (Windows 10 name)
    - Microsoft.Windows.Apprep.ChxApp
    # store, installer, licensing UI
    - Microsoft.WindowsStore
    - Microsoft.StorePurchaseApp
    - Microsoft.DesktopAppInstaller
    - Microsoft.Winget.Source
    - Microsoft.Services.Store.Engagement
    # frameworks
    - Microsoft.VCLibs.*
    - Microsoft.UI.Xaml.*
    - Microsoft.NET.Native.Framework.*
    - Microsoft.NET.Native.Runtime.*
    - Microsoft.WindowsAppRuntime.*
    - MicrosoftCorporationII.WinAppRuntime.*
    - Microsoft.DirectXRuntime
    - Microsoft.WidgetsPlatformRuntime
    # shell, settings, sign-in
    - Microsoft.Windows.ShellExperienceHost
    - Microsoft.Windows.StartMenuExperienceHost
    - MicrosoftWindows.Client.CBS
    - MicrosoftWindows.Client.Core
    - MicrosoftWindows.Client.CoreAI
    - MicrosoftWindows.Client.FileExp
    - MicrosoftWindows.Client.OOBE
    - MicrosoftWindows.Client.Photon
    - Windows.CBSPreview
    - Microsoft.UI.Xaml.CBS
    - Microsoft.AIFabric.CBS.*
    - Microsoft.Windows.AugLoop.CBS
    - windows.immersivecontrolpanel
    - Microsoft.AAD.BrokerPlugin
    - Microsoft.AccountsControl
    - Microsoft.Windows.CloudExperienceHost
    - Microsoft.LockApp
    - Microsoft.CredDialogHost
    - Microsoft.BioEnrollment
    - Microsoft.Windows.ContentDeliveryManager
    - Microsoft.Windows.CapturePicker
    - Microsoft.Windows.PrintQueueActionCenter
    - Windows.PrintDialog
    - Microsoft.AsyncTextService
    - Microsoft.ECApp
    - Microsoft.Windows.OOBENetworkCaptivePortal
    - Microsoft.Windows.OOBENetworkConnectionFlow
    - Microsoft.Windows.PinningConfirmationDialog
    - Microsoft.Windows.AssignedAccessLockApp
    - Microsoft.Windows.SecureAssessmentBrowser
    - Microsoft.Windows.ParentalControls
    - Microsoft.Windows.PeopleExperienceHost
    - Microsoft.Windows.NarratorQuickStart
    - Microsoft.Windows.XGpuEjectDialog
    - Microsoft.PPIProjection
    - MicrosoftWindows.UndockedDevKit
    - Microsoft.Windows.Search                 #U (Windows 10)
    - 1527c705-839a-4832-9118-54d4Bd6a0c89
    - c5e2524a-ea46-4f67-841f-6a9465d9d515
    - E2A4F912-2574-4A75-9BB0-0D023378592B
    - F46D4000-FD22-4DB4-AC8E-4E1DDDE828FE
    # edge / webview
    - Microsoft.MicrosoftEdge.Stable
    - Microsoft.MicrosoftEdge                  #U (Windows 10 legacy)
    - Microsoft.MicrosoftEdgeDevToolsClient
    - Microsoft.Win32WebViewHost
    # gaming identity (guarded, see C8-C10)
    - Microsoft.XboxIdentityProvider
    - Microsoft.Xbox.TCUI
    - Microsoft.XboxGameCallableUI
    - Microsoft.GamingServices
    - Microsoft.XboxGamingOverlay
    - Microsoft.XboxGameOverlay
    # codecs
    - Microsoft.HEVCVideoExtension
    - Microsoft.HEIFImageExtension
    - Microsoft.WebpImageExtension
    - Microsoft.AV1VideoExtension
    - Microsoft.VP9VideoExtensions
    - Microsoft.RawImageExtension
    - Microsoft.MPEG2VideoExtension
    - Microsoft.AVCEncoderVideoExtension
    - Microsoft.WebMediaExtensions             #U
    # expected inbox apps (off by default, explicit opt-in)
    - Microsoft.WindowsTerminal
    - Microsoft.WindowsNotepad
    - Microsoft.Paint
    - Microsoft.Windows.Photos
    - Microsoft.WindowsCalculator
    - Microsoft.ScreenSketch                   #U (Snipping Tool)

  win32_products:
    - Microsoft Edge WebView2 Runtime          # EdgeUpdate client {F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}
    - Microsoft Edge                           # outside supported uninstall
    - Microsoft Edge Update

  services:
    # security
    - WinDefend
    - WdNisSvc
    - MDCoreSvc
    - Sense
    - SecurityHealthService
    - wscsvc
    - webthreatdefsvc
    - mpssvc                                   #U (Windows Firewall)
    # update / servicing / app model
    - wuauserv
    - UsoSvc
    - BITS
    - DoSvc
    - WaaSMedicSvc
    - TrustedInstaller
    - AppXSvc
    - AppReadiness
    - StateRepository
    - InstallService
    - ClipSVC
    - LicenseManager
    - sppsvc
    - edgeupdate
    - edgeupdatem
    - MicrosoftEdgeElevationService
    # identity / encryption
    - NgcSvc
    - NgcCtnrSvc
    - WbioSrvc
    - TokenBroker
    - wlidsvc
    - BDESVC
    # platform
    - WSearch
    - SysMain
    - WpnService
    - WpnUserService*
    - CDPSvc
    - CDPUserSvc*
    - DiagTrack
    - dmwappushservice
    - EventLog
    - Schedule
    - VSS
    - swprv
    - camsvc
    # gaming
    - GamingServices
    - GamingServicesNet
    - XblAuthManager
    - XblGameSave
    - XboxNetApiSvc
    - XboxGipSvc

  optional_features:
    - NetFx4-AdvSrv                            #U
    - NetFx3                                   #U
    - Windows-Defender-Default-Definitions     #U
    - Recall                                   # allowed only via Optional Features path, never CBS

  forbidden_operations:
    - dism_remove_package                      # any CBS package removal
    - cbs_registry_edit                        # Component Based Servicing\Packages visibility/ownership
    - delete_under: ["%WINDIR%\\SystemApps", "%WINDIR%\\WinSxS", "%ProgramFiles%\\WindowsApps"]
    - scheduled_task_reapply_after_update
    - move_or_delete_user_profile_folders
    - whole_hive_registry_restore
```
