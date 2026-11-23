# 02b - Windows AI features: sourced identifiers

Research date: 2026-11-23. Targets: Windows 10 22H2 (19045), Windows 11 23H2 (22631), 24H2 (26100), 25H2 (26200).
Scope: registry/policy values, Appx names, services, optional features. No CBS package removal.

Method: Microsoft Learn pages were fetched as markdown and read directly. Every row cites the page it was read on.
Community tool source (Win11Debloat, winutil, RemoveWindowsAI mirror) was read only for corroboration and is labelled
"community". No code was copied. Anything not read on a page is in section 10 (UNVERIFIED).

Source keys used below:

| Key | URL |
| --- | --- |
| WAI | https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-windowsai (page dated 2026-10-14) |
| COP | https://learn.microsoft.com/en-us/windows/client-management/manage-windows-copilot |
| REC | https://learn.microsoft.com/en-us/windows/client-management/manage-recall |
| C2D | https://learn.microsoft.com/en-us/windows/client-management/manage-click-to-do |
| NOTE | https://learn.microsoft.com/en-us/windows/client-management/manage-notepad |
| CUP | https://learn.microsoft.com/en-us/windows/client-management/copilot-update-policy-control |
| DEP | https://learn.microsoft.com/en-us/windows/client-management/deploy-unified-copilot-app |
| PAUSE | https://learn.microsoft.com/en-us/windows/client-management/pause-unified-copilot-app-deployment |
| CAPP | https://learn.microsoft.com/en-us/windows/client-management/configure-microsoft-copilot-policies |
| EXP | https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-experience |
| APPM | https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-applicationmanagement |
| PRIV | https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-privacy |
| M365DEP | https://learn.microsoft.com/en-us/microsoft-365/copilot/deploy-microsoft-365-copilot-app |
| M365FAQ | https://learn.microsoft.com/en-us/microsoft-365/copilot/faq-deploy-microsoft-365-copilot-app |
| EDGE | https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies (index, dated 2026-11-19); per-policy pages at `.../microsoft-edge-policies/<policyname-lowercase>` |
| ECFG | https://learn.microsoft.com/en-us/deployedge/configure-microsoft-edge |
| AGENT | https://support.microsoft.com/en-us/windows/experimental-agentic-features-a25ede8a-e4c2-4841-85a8-44839191dfb3 |
| PBR | https://support.microsoft.com/en-us/servicing/os/windows/docs/2025/08/policy-based-removal-of-pre-installed-microsoft-store-apps |
| QA | https://learn.microsoft.com/en-ca/answers/questions/5891331/workloadssessionhost-using-4gb-ram-on-copilot-pc (Microsoft Q&A, moderator answer; not product documentation) |
| W11D (community) | https://github.com/Raphire/Win11Debloat/tree/master/Regfiles |
| WU (community) | https://github.com/ChrisTitusTech/winutil/blob/main/config/tweaks.json |
| RWAI (community mirror) | https://github.com/kinoosaki/RemoveWindowsAI (mirror of zoicware/RemoveWindowsAI; the original repo returned "Not Found" from the GitHub API on the research date) |
| TITUS (community) | https://christitus.com/microsoft-recall-situation/ |

General finding on "do feature updates restore it": Microsoft does not state, on any page read, whether a feature
update resets any of these policy values. The only restore-related statements found are for the Copilot app
(section 1). All policy rows are therefore `returnsAfterFeatureUpdate: unknown` in the JSON.

---

## 1. Windows Copilot

### 1.1 TurnOffWindowsCopilot (legacy, deprecated)

| Field | Value | Source |
| --- | --- | --- |
| Key | `SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot` | WAI |
| Value | `TurnOffWindowsCopilot`, int, 1 = Disable Copilot, 0 = Enable (default) | WAI |
| Scope | User only. Device scope is marked not supported. GP location "User Configuration" | WAI |
| Min build | 10.0.19044.3758; 10.0.19045.3758 (KB5032278); 10.0.22621.2361 (KB5030310); 10.0.22631 | WAI |
| Editions | Pro, Enterprise, Education, IoT Enterprise | WAI |
| Status | "This policy is deprecated and may be removed in a future release." | WAI |
| Limits | "isn't for the new Copilot experience"; "also applies to upgrade scenarios to prevent installation of the Copilot app from an image that would have had the Copilot in Windows pane" | WAI |
| Replacement | "AppLocker policy should be used instead of the Turn Off Windows Copilot legacy policy ... The policy is subject to near-term deprecation." | COP |

CONFLICT: community tools (W11D `Disable_Copilot.reg`) write the value in both HKCU and HKLM. Microsoft documents
user scope only, so the HKLM form is not a documented policy location. Only the HKCU form is in the JSON.

### 1.2 What replaces it

- AppLocker packaged-app rule: Publisher `CN=MICROSOFT CORPORATION, O=MICROSOFT CORPORATION, L=REDMOND, S=WASHINGTON, C=US`,
  package name `MICROSOFT.COPILOT`, version `*` and above. Prevents install and blocks launch. (COP) Not engine-supported.
- Remove the Appx: Microsoft documents `Get-AppxPackage -Name "Microsoft.Copilot"` then `Remove-AppxPackage`. (COP)
- Restore behaviour: "The Microsoft Copilot app is automatically enabled after you install the Windows updates listed
  above if you haven't previously enabled a group policy to prevent the installation of Copilot." Rollout was the
  Sept 2024 preview / Oct 2024 security update on Windows 11 and Nov 2024 on Windows 10. (COP)
- `RemoveMicrosoftCopilotApp` policy exists (WAI): Device and User scope; Enterprise, Education, IoT Enterprise
  (Pro marked not supported in the table, although the description text says "Enterprise, Professional and Education");
  Windows 11 24H2 10.0.26100 and later; 1 = removal enabled. It only uninstalls when Microsoft 365 Copilot and Microsoft
  Copilot are both installed, the Copilot app was not user-installed, and it was not launched in the last 28 days.
  Users can reinstall. The page gives NO registry key or value name (GP mapping shows only a name and an internal
  path), so it is not in the JSON.

### 1.3 Unified Microsoft Copilot app via Microsoft Edge Update (2026)

New since most debloat tools were written. "The Microsoft 365 Copilot app is now called Microsoft Copilot"; broad
commercial rollout began September 2026 and the app is delivered and updated by Microsoft Edge Update. (DEP)

| Value under `HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\EdgeUpdate` | Type | Data | Source |
| --- | --- | --- | --- |
| `Install{C50565E9-CCCF-44B4-BA15-5AC5C6569197}` | REG_DWORD | 0 = installs disabled, 1 = enabled, 5 = force installs (machine-wide) | CUP |
| `Update{C50565E9-CCCF-44B4-BA15-5AC5C6569197}` | REG_DWORD | 0 = updates disabled, 1 = always allow | CUP |
| `Uninstall{C50565E9-CCCF-44B4-BA15-5AC5C6569197}` | REG_DWORD | Enabled = uninstall, 2 = uninstall and delete user data, 3 = block uninstall. AD domain-joined only | CUP |
| `CopilotUnificationAllowed{C50565E9-CCCF-44B4-BA15-5AC5C6569197}` | REG_DWORD | 1 = unify now, 0 = standard rollout. AD domain-joined only | CUP |

Requires Microsoft Edge Update 1.3.253.25 or later. (CUP) Only `Install...=0` is in the JSON.

`PauseCopilotAppUnificationRollout` = 1 under `HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate` defers unification, but
"You can temporarily defer device unification until November 30, 2026. Starting December 1, 2026, unification will be
enabled for all eligible devices, and further deferrals will no longer be available." (PAUSE) Expires one week after
this research; value type is not stated; omitted from the JSON.

Copilot app policies under `SOFTWARE\Policies\Microsoft\Copilot` (hive not stated on the page): `BrowsingEnabled`,
`ComponentUpdatesEnabled`, `CopilotCoworkToolActionsEnabled`, all REG_DWORD, Copilot 152 or later. (CAPP) Not in the
JSON because the hive is not stated.

### 1.4 Copilot hardware key

`SetCopilotHardwareKey` (WAI, COP): User scope only; Pro, Enterprise, Education, IoT Enterprise; Windows 11 22H2 with
KB5044380 (10.0.22621.4391) and later; string = AUMID of the target app. Registry key name
`SOFTWARE\Policies\Microsoft\Windows\CopilotKey`. The page does NOT give a registry value name, so it is not in the
JSON. End-user setting URI: `ms-settings:personalization-textinput-copilot-hardwarekey`. (COP)

### 1.5 Appx identities

- `Microsoft.Copilot`, Store id `9NHT9RB2F4HD` (link `https://apps.microsoft.com/detail/9NHT9RB2F4HD`). (COP)
- Microsoft 365 Copilot app: Microsoft's own AUMID example is
  `Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe!Microsoft.MicrosoftOfficeHub`. (WAI)

### 1.6 Microsoft 365 Copilot app auto-install opt-out

Tenant-side only: Microsoft 365 Apps admin center > Customization > Device Configuration > Modern Apps settings >
Microsoft 365 Copilot app > clear "Enable automatic installation of Microsoft 365 Copilot app". Requires Microsoft 365
Apps Version 2511; not applied in the EEA or on Semi-Annual Enterprise Channel. (M365DEP) No local registry or policy
value is documented. Install happens once in SYSTEM context; if a user uninstalls it, it is not auto-reinstalled.
(M365FAQ) Not engine-supported.

`Experience/DisableCopilotPinScreen` (EXP): device scope; Enterprise, Education, IoT Enterprise; Windows Insider
Preview; 1 = M365 Copilot pinning screen disabled. No registry key or value name on the page. Not in the JSON.

---

## 2. Recall

Hardware: Copilot+ PC meeting Secured-core, 40 TOPS NPU, 16 GB RAM, 8 logical processors, 256 GB storage, BitLocker or
Device Encryption, Windows Hello ESS. (REC) "By default, Recall is disabled and removed on managed devices"; on
unmanaged Copilot+ PCs "Recall is available by default but a user has to opt in to save snapshots." (REC)

All values below live under `SOFTWARE\Policies\Microsoft\Windows\WindowsAI`, ADMX `WindowsCopilot.admx`. (WAI)

| Value | Scope | Disable data | CSP default | Min build | Editions | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `AllowRecallEnablement` | Device only (HKLM) | 0 | 1 | 10.0.26100.3915 (KB5055627) | Pro, Ent, Edu, IoT Ent | Disabled: "the bits for Recall will be removed from the device", snapshots deleted, restart required |
| `DisableAIDataAnalysis` | Device and User (HKLM, HKCU) | 1 | 0 | 10.0.26100.3915 | Pro, Ent, Edu, IoT Ent | Enabling deletes saved snapshots |
| `SetDenyAppListForRecall` | Device and User | string, `;` separated AUMIDs or exe names | none | 10.0.26100.3915 | Ent, Edu, IoT Ent (not Pro) | Restart needed |
| `SetDenyUriListForRecall` | Device and User | string, `;` separated URIs | none | 10.0.26100.3915 | Ent, Edu, IoT Ent | Restart needed |
| `SetMaximumStorageDurationForRecallSnapshots` | Device and User | 30/60/90/180 | 90 | 10.0.26100.3915 | Ent, Edu, IoT Ent | |
| `SetMaximumStorageSpaceForRecallSnapshots` | Device and User | 10240..153600 (MB) | 0 | 10.0.26100.3915 | Ent, Edu, IoT Ent | |
| `AllowRecallExport` | Device only | 0 = deny (default) | 0 | Insider Preview | Ent, Edu, IoT Ent | EEA only |

Also in the CSP with no registry mapping given: `DisableRecallDataProviders` (User; Insider), `SetDataLossPreventionProvider`
(Device; 10.0.26100.6725, KB5065789). (WAI)

Optional feature: FeatureName is `Recall`. Documented commands (REC):

- `Enable-WindowsOptionalFeature -Online -FeatureName "Recall"`
- `Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -Remove`

Community: winutil runs `Disable-WindowsOptionalFeature -FeatureName Recall -Online -NoRestart` (no `-Remove`) and
guards for the feature not existing. (WU)

File Explorer reports: Chris Titus Tech (Oct 2024) reported that removing Recall from an offline image reverted the
new File Explorer, then corrected it: the cause was removal of the `MicrosoftWindows.Client.AIX` package, which pulled
out `Microsoft.WindowsAppRuntime.CBS_cw5n1h2txyewy`, on which `MicrosoftWindows.Client.FileExp` depends. (TITUS,
community, not a Microsoft statement) Consequence for this repo: disable the feature or set policy; never remove the
AIX Appx.

CONFLICT: W11D and RWAI also write `TurnOffSavingSnapshots` = 1 under the WindowsAI key. That value name is not on
WAI or REC. Unverified; not in the JSON.

---

## 3. Click to Do

`DisableClickToDo` under `SOFTWARE\Policies\Microsoft\Windows\WindowsAI`, int, 1 = disabled, default 0; Device and
User scope; Pro, Enterprise, Education, IoT Enterprise. (WAI) Requires a Copilot+ PC or eligible Cloud PC. (C2D)
"This policy doesn't affect Click to Do in Recall." (C2D)

CONFLICT inside Microsoft docs: WAI lists Applicable OS as "Windows Insider Preview" only, while C2D documents the
Group Policy as a current management setting with no build number. Minimum build is therefore unknown (null in JSON).

---

## 4. Other Windows AI controls

### 4.1 Paint (WAI)

Key `Software\Microsoft\Windows\CurrentVersion\Policies\Paint` (note: not under `SOFTWARE\Policies`), Computer
Configuration, int, 1 = disabled, default 0. Min Windows 11 22H2 10.0.22621.4870 and 24H2 10.0.26100.3360. Pro,
Enterprise, Education, IoT Enterprise.

- `DisableImageCreator`
- `DisableCocreator`
- `DisableGenerativeFill`

W11D additionally writes `DisableGenerativeErase` and `DisableRemoveBackground` in the same key; neither is on WAI.
Unverified.

### 4.2 Settings agent (WAI)

`DisableSettingsAgent` under `SOFTWARE\Policies\Microsoft\Windows\WindowsAI`, Device only, 1 = disabled, default 0.
Enterprise, Education, IoT Enterprise (not Pro). Applicable OS: Windows Insider Preview.

### 4.3 Notepad (NOTE)

"To disable AI features in Notepad, set the `DisableAIFeatures` registry value to `1` under
`HKLM:\SOFTWARE\Policies\WindowsNotepad`." Policy name `DisableAIFeaturesInNotepad`, ADMX `WindowsNotepad.admx`
(separate download, machine-wide). Windows 11 22H2 or later, Notepad 11.2503.16.0 or later. There is no Policy CSP
page for Notepad (`policy-csp-admx-notepad` and `policy-csp-notepad` both return 404). Corroborated by W11D and WU.

### 4.4 Agent connectors / agent workspace

- WAI lists `AgentConnectorAccessPolicy`, `AgentConsentDuration`, `ConfigureAgentConnectors` (0 user in control,
  1 force enable, 2 force disable) and `OnDeviceRegistryLoggingLevel`: Device scope; Enterprise, Education, IoT
  Enterprise; Windows Insider Preview. No registry key or value names are given for any of them.
- "Experimental agentic features" is off by default, is a Settings toggle at System > AI Components, can only be
  enabled by an administrator and then applies to all users. (AGENT) No registry value or policy is given on that page.
- A `DisableAgentWorkspaces` / `DisableAgentConnectors` policy is written by RWAI and was claimed by a search summary,
  but neither name appears on WAI as fetched (page dated 2026-10-14). Unverified.

### 4.5 Windows AI Fabric service

Service name `WSAIFabricSvc` is confirmed only through community source and a Microsoft Q&A thread. No Microsoft
product documentation for the service, its default start type, or supported ways to disable it was found.
A Microsoft Q&A moderator answer says: "On Copilot+ builds, this runtime is treated as a core OS component, so in
some cases, Windows can re-enable or bypass disabled services internally" and "the component isn't user-controlled
today". (QA; the asker reported the service still starting with Start = 4.) Community disagreement on handling: W11D
sets `Start` = 3 (manual); WU sets it Disabled if present; RWAI deletes the service and its revert value implies 2
(automatic). Not in the JSON; recommend never-default if added later.

### 4.6 File Explorer AI actions, Photos, Snipping Tool, text input

- File Explorer: the FileExplorer Policy CSP page (https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-fileexplorer)
  contains no AI actions policy. `HideAIActionsMenu` appears only on third-party sites. Unverified.
- Photos, Snipping Tool: no policy found on any Microsoft page read. C2D only notes that the Click to Do entry point
  in Snipping Tool needs Snipping Tool 11.2411.20.0 or later.
- Text input: the TextInput Policy CSP page (https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-textinput)
  has no AI- or Copilot-specific policy. RWAI writes `HKCU\Software\Microsoft\input\Settings\InsightsEnabled` = 0;
  community only, unverified.

---

## 5. Microsoft Edge AI policies

All: key `SOFTWARE\Policies\Microsoft\Edge`, REG_DWORD, ADMX `MSEdge.admx`. Source is the per-policy page under EDGE.
Hive: policy pages give the path without a hive; ECFG gives `HKLM\SOFTWARE\Policies\Microsoft\Edge` and says policies
can be configured via the registry for AD-joined devices and Intune-enrolled Windows 10 Pro/Enterprise. Microsoft
does not promise effect on unmanaged devices. "MSA" column = the page's "Applies to a profile that is signed in with
a Microsoft account" field.

| Value name | Disable data | Min Edge (Windows) | Status | MSA | Notes |
| --- | --- | --- | --- | --- | --- |
| `HubsSidebarEnabled` | 0 | 99 | current | No | Hides the whole sidebar. "As of Microsoft Edge version 141, the Microsoft365CopilotChatIconEnabled policy is the only means of controlling the display of Copilot in the toolbar." |
| `Microsoft365CopilotChatIconEnabled` | 0 | 139 | current | No | Entra ID profiles; side pane only |
| `CopilotPageContext` | 0 | 124 | current | No | Entra profiles. Default on outside EU, off in EU |
| `EdgeEntraCopilotPageContext` | 0 | 130 | current | No | Replaces CopilotCDPPageContext |
| `CopilotCDPPageContext` | 0 | 124-132 | OBSOLETE ("doesn't work after Microsoft Edge version 132") | No | Do not ship |
| `DiscoverPageContextEnabled` | 0 | 113-127 | OBSOLETE | No | Do not ship |
| `AllowBrowsingWithCopilot` | 0 | 148-158 | OBSOLETE ("Starting in Microsoft Edge version 159") | No | Do not ship |
| `NewTabPageBingChatEnabled` | 0 | 117 | current | No | Enterprise new tab page |
| `ComposeInlineEnabled` | 0 | 115 | current | No | "Commercial Writing"; needs Entra account |
| `GenAILocalFoundationalModelSettings` | 1 (Disallowed) | 132 | current | Yes | 0 = download model; 1 = no download, existing model deleted |
| `EdgeHistoryAISearchEnabled` | 0 | 138 | current | No | |
| `AIGenThemesEnabled` | 0 | 122 | current | No | DALL-E themes |
| `BuiltInAIAPIsEnabled` | 0 | 138 | current | No | Blocks LanguageModel/Summarization/Writer/Rewriter web APIs |
| `CopilotAddressBarSuggestionsEnabled` | 0 | 149 | current | No | |
| `CopilotNewTabPageEnabled` | 0 | 148 | current | No | Default already off |
| `CopilotCoworkToolActionsEnabled` | 0 | 152 | current | No | |
| `M365LinksAutoOpenCopilotEnabled` | 0 | 148 | current | No | |
| `ShareBrowsingHistoryWithCopilotSearchAllowed` | 0 | 143 | current | No | |
| `EdgeCopilotEnabled` | n/a | Android/iOS 123 only | current | No | "Windows: Not supported" |

"CopilotMode": no policy with "CopilotMode" in its name exists on the EDGE index (searched the page, dated 2026-11-19).

Practical caveat: most Copilot policies are scoped to Entra work profiles and are marked as not applying to
Microsoft-account profiles, so on a home PC they may do nothing. `GenAILocalFoundationalModelSettings` is the one
that explicitly applies to MSA profiles.

Community corroboration: W11D `Disable_Edge_AI_Features.reg` writes nine of these in HKLM, including the obsolete
`CopilotCDPPageContext`.

---

## 6. Bing Chat / Copilot in Windows Search

The Search Policy CSP page (https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-search) has no
Copilot- or Bing-Chat-specific policy. Nothing AI-specific to add beyond the general search suggestion policies
covered elsewhere.

---

## 7. Generative AI app permission

The Privacy Policy CSP page (PRIV) contains no `LetAppsAccessGenerativeAI` or `LetAppsAccessSystemAIModels` entry
(full heading list checked; zero matches for "generative" or "SystemAI"). Both value names, and the
`HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\generativeAI` `Value` = `Deny`
form, were found only in community source (RWAI) and third-party how-to sites. Unverified; not in the JSON.

---

## 8. Appx packages with an AI role

| Package | Removable by plain Remove-AppxPackage | Basis | Catalog decision |
| --- | --- | --- | --- |
| `Microsoft.Copilot` | Yes | Microsoft documents the removal (COP) | Include, safe |
| `Microsoft.MicrosoftOfficeHub` | Yes (community lists it as normal Appx: W11D `Config/Apps.json`) | Name from WAI AUMID example | Include, moderate |
| `Microsoft.Windows.Ai.Copilot.Provider` | Unknown | Name seen only in RWAI | Do not include (unverified) |
| `MicrosoftWindows.Client.AIX` | No | RWAI docs: "most AI packages are marked as Non-Removeable" and removal needs EndOfLife / inbox-app registry tricks; TITUS: removing it broke File Explorer | Never touch |
| `MicrosoftWindows.Client.CoreAI` | No | WU and RWAI both need the `AppxAllUserStore\EndOfLife` trick to remove it | Never touch |
| `Microsoft.AIFabric.CBS*` | No | RWAI source comment: "aifabric is a dependency with explorer" | Never touch |
| `Microsoft.Windows.AIHub` | Listed as normal Appx by W11D | Community only | Unverified |

Microsoft does not publish a statement on any page read that these packages are system-signed or non-removable; the
"non-removable" classification is community-sourced. The decision not to touch them rests on the engine rule (exact
Appx removal only, no servicing-store edits) plus the community breakage reports.

Related Microsoft mechanism (not engine-supported): `RemoveDefaultMicrosoftStorePackages`, key
`Software\Policies\Microsoft\Windows\Appx\RemoveDefaultMicrosoftStorePackages`, value `Enabled`; Enterprise and
Education only; the policy payload includes `Copilot` and `MicrosoftOfficeHub` ids. (APPM, PBR)

---

## 9. Deprecation summary

| Item | Status | Source |
| --- | --- | --- |
| `TurnOffWindowsCopilot` | Deprecated, "subject to near-term deprecation"; no effect on the new Copilot app | WAI, COP |
| Edge `CopilotCDPPageContext` | Obsolete after Edge 132 | EDGE |
| Edge `DiscoverPageContextEnabled` | Obsolete after Edge 127 | EDGE |
| Edge `AllowBrowsingWithCopilot` | Obsolete after Edge 158 | EDGE |
| Edge `HubsSidebarEnabled` | Current, but no longer controls the Copilot toolbar icon from Edge 141 | EDGE |
| `PauseCopilotAppUnificationRollout` | Stops working after 2026-11-30 | PAUSE, DEP |

---

## 10. UNVERIFIED (not read on a Microsoft page; do not treat as fact)

1. `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ShowCopilotButton` = 0. Community only (W11D,
   RWAI). No Microsoft page found. Type, default and build range unverified.
2. `TurnOffWindowsCopilot` in HKLM. Community only; Microsoft documents user scope only.
3. `TurnOffSavingSnapshots` (WindowsAI key). Community only (W11D, RWAI).
4. `DisableGenerativeErase`, `DisableRemoveBackground` (Paint key). Community only (W11D).
5. `DisableAgentWorkspaces`, `DisableAgentConnectors`, `DisableRemoteAgentConnectors` (WindowsAI key). Community only
   (RWAI); not on WAI as fetched.
6. `HKLM\SYSTEM\CurrentControlSet\Services\IsoEnvBroker` (agent workspace service or `Enabled` value). Community and
   third-party sites only; the two sources disagree on the value (`Start` vs `Enabled`).
7. `HideAIActionsMenu` (File Explorer AI actions). Third-party sites only; exact key path inconsistent between them.
8. `LetAppsAccessGenerativeAI`, `LetAppsAccessSystemAIModels` (`SOFTWARE\Policies\Microsoft\Windows\AppPrivacy`) and
   the `ConsentStore\generativeAI` `Value` = `Deny` form. Community only (RWAI).
9. `WSAIFabricSvc` default start type and any supported disable method. No Microsoft documentation found.
10. Registry value names for `SetCopilotHardwareKey`, `RemoveMicrosoftCopilotApp`, `DisableCopilotPinScreen`,
    `ConfigureAgentConnectors`, `DisableRecallDataProviders`, `SetDataLossPreventionProvider`: the policies are real
    (Microsoft pages) but the pages give no value name.
11. Hive for `SOFTWARE\Policies\Microsoft\Copilot` (Copilot app policies): not stated on CAPP.
12. Store id for `Microsoft.MicrosoftOfficeHub`: not read on a Microsoft page.
13. `Microsoft.Windows.Ai.Copilot.Provider`, `MicrosoftWindows.Client.CoPilot`, `Microsoft.Windows.AIHub`: package
    names from community source only; build ranges and removability unverified.
14. "System-signed / non-removable" status of `MicrosoftWindows.Client.AIX`, `MicrosoftWindows.Client.CoreAI`,
    `Microsoft.AIFabric.CBS`: community-sourced, no Microsoft statement read.
15. Whether Edge policies written to HKLM take effect on unmanaged (non-domain, non-MDM) Windows 10/11 Home or Pro.
16. Minimum released build for `DisableClickToDo` and `DisableSettingsAgent` (Microsoft lists Insider Preview only).
17. Whether any feature update resets the policy values above. No Microsoft statement found either way.
18. Whether the original zoicware/RemoveWindowsAI repository still exists; only a mirror was readable.
19. Photos and Snipping Tool AI policy controls: none found; absence on unread pages is not proof of absence.

---

## 11. Output

`research/raw/ai-candidates.json`: 30 verified, engine-supported items (27 policy, 2 appx, 1 feature; 24 safe,
6 moderate). Every item in it has its identifier read on a Microsoft page. Items excluded and why are listed in
sections 1 to 8 and 10.
