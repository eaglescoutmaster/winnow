# Synthesis: from research to catalog

How the four research tracks became `catalog/items.json`. Compiled 2026-11-23.

## Tier definitions

| Tier | Meaning | Selected by |
|---|---|---|
| `safe` | Reversible, no reported breakage | `-Profile safe` and above |
| `moderate` | Reversible, but changes visible behaviour or has reported edge cases | `-Profile moderate` and above |
| `aggressive` | Removes functionality some users need; undo may need a download | `-Profile aggressive` |
| `never-default` | Protected identifier or known breakage | only `-Only <id>` |

## Evidence rules used

1. A Microsoft page that names the identifier wins over any tool.
2. A community-only identifier enters the catalog only if two independent tools use it, and its `notes` say so.
3. Local observations on the build machine (Insider 26300) are never sufficient on their own.
4. Anything a source marked unverified is left out.
5. `returnsAfterFeatureUpdate` is `unknown` unless a source states it. No source was found for any registry value, policy or task, so those are all `unknown`.

## Conflicts and how they were settled

| # | Conflict | Sources | Decision | Why |
|---|---|---|---|---|
| 1 | Disabling `DiagTrack` / `dmwappushservice`: "aggressive with guards" vs protected | Track 3 table C22 vs track 3 protected list; IoT guidance says "OK to disable", Server guidance says "no guidance" | `never-default` | The guards (Insider, MDM, Entra detection) are not implemented, and Microsoft has no client-edition guidance. The policy `AllowTelemetry = 1` is the safe substitute. |
| 2 | `Microsoft.Xbox.TCUI`, `Microsoft.XboxIdentityProvider`: Microsoft's own policy example removes them; Win11Debloat rates them unsafe | Policy CSP ApplicationManagement vs Win11Debloat `Config/Apps.json` | `never-default` | Stricter source wins when the cost of being wrong is broken game sign-in. |
| 3 | `Microsoft.XboxGamingOverlay` (Game Bar): moderate vs protected | Appx research vs track 3 B7 | `never-default` | Bare removal causes the `ms-gamingoverlay` popup; the paired mitigation is not implemented. |
| 4 | `MicrosoftWindows.Client.WebExperience`: moderate vs aggressive | Track 3 C15 vs Appx research | `aggressive` | Stricter tier; the widgets policy is the safe route. |
| 5 | Edge and Windows policies: "safe" vs "policy keys cause managed-by-organisation lockouts" | Track 3 C7 vs track 1 lesson 4 (WinUtil #4242, OFGB #34) | Tier follows track 3; every policy item carries a note about the managed label | The label is cosmetic and fully reversible; users are told before approval. |
| 6 | Bing in Start: `BingSearchEnabled` (tools) vs `DisableSearchBoxSuggestions` (Microsoft policy) | winutil vs Policy CSP ADMX_WindowsExplorer | Policy only, tier `moderate` | The policy is documented; `BingSearchEnabled` has one community source. Search tweaks are a repeated suspect for dead Start search (Win11Debloat #361). |
| 7 | Advertising ID: HKCU `Enabled` (tools) vs HKLM policy (Microsoft) | winutil, W4RH4WK vs manage-connections | HKLM policy | Microsoft source. |
| 8 | Feedback frequency: tools set one value, Microsoft sets two | winutil vs manage-connections 18.16 | Both values, as Microsoft documents | Microsoft source. |
| 9 | `PreventNetworkTrafficPreUserSignIn` path differs between two Microsoft pages | manage-connections vs OneDrive group policy page | Left out | No way to settle it without testing. |
| 10 | `DisableCloudOptimizedContent` hive differs between two Microsoft pages | manage-connections vs Policy CSP Experience | Left out | Same. |
| 11 | `HideRecommendedSection` editions | Policy CSP Start (Pro) vs community (SE / Enterprise only) | Left out | Unsettled; winutil warns it also disables Spotlight. |
| 12 | Instagram package name | Store (`Facebook.InstagramBeta`) vs Win11Debloat (`Facebook.Instagram`) | Left out | No exact identifier. |
| 13 | `CLAUDE.md` as copy/symlink vs import | Task brief vs Claude Code docs | One-line `@AGENTS.md` import (and `@./AGENTS.md` for `GEMINI.md`) | Claude Code docs advise the import on Windows; git symlinks need Developer Mode. |
| 14 | Appx build ranges | Appx research `minBuild` values vs absence of any Microsoft per-build list | Wide range, presence detected at run time | Microsoft no longer publishes per-version provisioned app tables. |
| 15 | `TurnOffWindowsCopilot` hive | Tools write HKLM; Microsoft documents user scope only | HKCU only, noted as deprecated | Microsoft source. |
| 16 | `DisableClickToDo` availability | Policy CSP ("Insider Preview only") vs Manage Click to Do page (current) | Included, `safe`, conflict stated in notes | Two Microsoft pages plus tool corroboration; an unset-able policy is harmless. |
| 17 | Recall and File Explorer breakage | Press reports vs the original reporter | Optional feature disable is `moderate`; AIX package removal is not offered | The reporter traced the breakage to removing `MicrosoftWindows.Client.AIX`, which is protected here. |
| 18 | Recall snapshot policy tier | AI research (`safe`) vs its own note that enabling deletes saved snapshots | `moderate` | Deleting user data is not undone by revert. |
| 19 | Edge policies on unmanaged PCs | Per-policy pages (no restriction) vs Edge configuration page (registry policies are for AD-joined or Intune devices) | Included, with a note that the effect is not guaranteed | Harmless if ignored. |

## Design decisions taken from the research

- No CBS/DISM package removal, no WinSxS or SystemApps deletion, no update-service changes, no persistent re-apply task. These are behind most broken-update reports (track 1, track 3 B3/B5/B10).
- Appx packages that are system-signed, non-removable or frameworks are refused at run time regardless of the catalog (track 3 C1).
- Prior state is captured per item at run time; "value absent" and "value set" are distinct (track 1 lesson 2).
- A restore point is verified by sequence number, because the API reports success inside the 24-hour throttle (track 3 B13). The run log, not System Restore, is the primary undo.
- Plan then apply: apply takes a plan file and never exceeds it (track 4).
- Catalog operations are a closed set of six; the catalog holds no executable text (track 4).

## Left out, and why

| Item | Reason |
|---|---|
| OneDrive uninstall, Edge uninstall | Need an installer run, which the engine does not do. Edge removal is unsupported outside the EEA. |
| `TaskbarDa` (widgets button), `ShellFeedsTaskbarViewMode` | System-managed on current builds; writes are denied. |
| `DisableWidgetsBoard`, `DisableWidgetsOnLockScreen` | Microsoft lists them as Insider Preview only. |
| `CEIPEnable`, `AITEnable`, `DisableInventory` | Data values not confirmed on a Microsoft page. |
| `AllowLinguisticDataCollection` | Hive not confirmed. |
| `DisableOneSettingsDownloads`, Edge `EdgeAssetDeliveryServiceEnabled`, Edge `DiagnosticData = 0` | Microsoft warns features may stop working. |
| Obsolete or deprecated Edge policies (Collections, Follow, Wallet, WebWidget, PromotionalTabs and others) | No effect on current Edge. |
| Edge update and OneDrive scheduled tasks | Names contain random or per-user suffixes; no exact identifier. |
| Flighting tasks, `DmClientOnScenarioDownload`, `Microsoft Compatibility Appraiser Exp` | Seen only on the local Insider machine. |
| `SoftLandingEnabled`, `RotatingLockScreenOverlayEnabled`, `SubscribedContent-353698Enabled`, `-314559Enabled`, suggested toasts, `TaskbarMn`, `EnableAccountNotifications` | Single community source. |
| `BingSearchEnabled`, `SearchboxTaskbarMode`, `IsDynamicSearchBoxEnabled`, `CortanaConsent` | Community only, or cosmetic. |
| Windows Spotlight policies | Enterprise and Education only, and Spotlight is not an ad surface for most users. |
| New Outlook auto-install block, `ConfigureStartPins`, promotional Start pins | Need key deletion or JSON blobs; delivery of promotional pins is undocumented. |
| Store `AutoDownload = 2` | Stops Store app updates. |
| `lfsvc`, `PcaSvc`, `wisvc`, `WMPNetworkSvc`, `WerSvc`, `DPS` | Not bloat, or Microsoft says do not disable. |
| `Microsoft.OneConnect`, `Microsoft.Messaging`, `Microsoft.Print3D` | Retired before the target builds. |
| `Microsoft.Windows.Ai.Copilot.Provider` | No source names it. |
| `ShowCopilotButton`, `HideAIActionsMenu`, `LetAppsAccessGenerativeAI`, `ConsentStore\generativeAI`, `SetCopilotHardwareKey`, `RemoveMicrosoftCopilotApp` | Value names not confirmed on a Microsoft page. |
| `DisableSettingsAgent` | Insider Preview only, and not supported on Pro. |
| `TurnOffSavingSnapshots`, `DisableGenerativeErase`, `DisableRemoveBackground`, `DisableAgentWorkspaces` | Community-only value names. |
| `WSAIFabricSvc` | Default start type unconfirmed; reported to be re-enabled by Windows. Listed as protected. |
| Edge Copilot policies for work profiles (`Microsoft365CopilotChatIconEnabled`, `CopilotPageContext`, `EdgeEntraCopilotPageContext`, `ComposeInlineEnabled`, `M365LinksAutoOpenCopilotEnabled`, `ShareBrowsingHistoryWithCopilotSearchAllowed`) | Apply to Entra ID profiles only, not Microsoft-account profiles. |
| Obsolete Edge Copilot policies (`CopilotCDPPageContext`, `DiscoverPageContextEnabled`, `AllowBrowsingWithCopilot`), `PauseCopilotAppUnificationRollout` | Obsolete, or stops working after 2026-11-30. |
| AI CBS packages (`MicrosoftWindows.Client.AIX`, `Client.CoreAI`, `Microsoft.AIFabric.*`) | Protected; removing AIX is what broke File Explorer in 2024. |
| Photos, Paint, Snipping Tool, Calculator, Notepad, Terminal, codecs | Protected; expected inbox apps. |
