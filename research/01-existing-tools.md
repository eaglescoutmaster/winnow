# Research track 1: existing Windows debloat tools

Observed on 2026-11-23. Stars, licenses and commit dates come from the GitHub REST API (`gh api repos/OWNER/REPO`, `/license`, `/commits?per_page=1`) on that date. "Last commit" is the newest commit on the default branch.

Conventions:

- Every claim carries a source URL. A claim marked **unverified** was not confirmed in a primary source during this pass.
- Issue links are user reports. A report is not proof that the tool caused the fault; where a maintainer disputed the cause, that is stated.
- No code was copied. Techniques are described in prose.

## Tools that could not be matched with confidence

| Name asked for | Result |
| --- | --- |
| RemoveWindowsAI (zoicware) | The original repo and the whole `zoicware` account returned HTTP 404 on 2026-11-23 (`https://github.com/zoicware`, `https://github.com/zoicware/RemoveWindowsAI`, and `gh api users/zoicware`). The reason is **unverified**: no news report or GitHub notice was found. Findings below come from a third-party mirror and a SourceForge mirror, not from the original. |
| win-ai-tools | One repo has this exact name and a matching description: `waar19/win-ai-tools` (7 stars). No author was given in the request, so whether this is the intended tool is **unverified**. |
| Window-Debloat-Agent | One repo has this exact name: `writtenonwater99/Window-Debloat-Agent` (0 stars, created 2026-11-17, no license). Whether this is the intended tool is **unverified**. |
| Winpilot / BloatynosyAI (builtbybel) | `builtbybel/Winpilot` and `builtbybel/BloatynosyAI` both redirect to `builtbybel/Bloatynosy`. They are one repo, covered once below. |

---

## 1. Win11Debloat (Raphire)

- **URL:** https://github.com/Raphire/Win11Debloat
- **License:** MIT (https://github.com/Raphire/Win11Debloat/blob/master/LICENSE)
- **Stars / last commit:** 63,572 / 2026-11-15 (https://api.github.com/repos/Raphire/Win11Debloat)
- **Targets:** Windows 10 and 11 (repo description, same URL).

**What it removes or disables.** Preinstalled apps; telemetry, diagnostic data, activity history, targeted ads; tips and suggestions; Bing web search and Copilot in search; widgets; location services; Game Bar/DVR; Windows Update behaviours (driver updates, Delivery Optimization, auto restart); many Explorer, taskbar and Start layout options. AI: disables and removes Copilot, Recall and Click to Do, stops the `WSAIFabricSvc` service auto-starting, and disables AI features in Edge, Chrome, Paint and Notepad (https://github.com/Raphire/Win11Debloat/blob/master/README.md).

**Methods.**
- Registry: each tweak is a `.reg` file under `Regfiles/`, with a parallel `Regfiles/Sysprep/` set for the Default user profile (https://github.com/Raphire/Win11Debloat/tree/master/Regfiles).
- App removal uses "Windows' built-in package management tools Appx and WinGet", for all users by default, or a named user with `-AppRemovalTarget` (https://github.com/Raphire/Win11Debloat/wiki/App-Removal). Each app in the catalog names its removal method (https://github.com/Raphire/Win11Debloat/blob/master/Config/Apps.json). Whether provisioned packages are also removed is **unverified**.
- Optional features: can enable Windows Sandbox and WSL (README, above).
- Edge: an optional force-removal marked "NOT RECOMMENDED" that leaves Core, WebView and Update in place (https://github.com/Raphire/Win11Debloat/wiki/App-Removal).
- Services, scheduled tasks, CBS, hosts and firewall: no use seen in the README or wiki; **unverified** beyond that.

**Data-driven design.** The repo is already catalog-driven: `Config/Apps.json` (per app: id, selected-by-default flag, a recommendation level, removal method), `Config/Features.json` (categories and features), `Config/DefaultSettings.json`, and per-language string files (https://github.com/Raphire/Win11Debloat/tree/master/Config).

**Revert.**
- A registry backup is taken before changes (release 2026.05.10 and later) and restored from the Options menu. It does not restore uninstalled apps (https://github.com/Raphire/Win11Debloat/wiki/Reverting-Changes).
- 66 hand-written undo `.reg` files in `Regfiles/Undo/` (https://github.com/Raphire/Win11Debloat/tree/master/Regfiles/Undo).
- Start menu layout is backed up to a `.bak` file and can be restored (wiki, above).
- A system restore point is created by the script (https://github.com/Raphire/Win11Debloat/blob/master/Scripts/Features/Invoke-SystemRestorePoint.ps1).
- Apps come back through the Store or WinGet. The wiki says the Microsoft Store itself and `XboxSpeechToTextOverlay` cannot easily be reinstalled (wiki, above).

**Reported breakages.**
- Start menu search stopped working after a run; the maintainer pointed to the Bing web search tweak and its undo file: https://github.com/Raphire/Win11Debloat/issues/361
- Explorer not working after a default run; maintainer again suspected the web search change: https://github.com/Raphire/Win11Debloat/issues/226
- Microsoft account and Xbox sign-in failing; cause not identified, in-place repair suggested: https://github.com/Raphire/Win11Debloat/issues/537
- Windows Hello, PIN and DISM problems on Enterprise 25H2; maintainer could not reproduce and disputed the cause: https://github.com/Raphire/Win11Debloat/issues/401
- Boot loop reported after default mode; maintainer disputed the cause: https://github.com/Raphire/Win11Debloat/issues/539
- Start menu clearing repeated on every sign-in: https://github.com/Raphire/Win11Debloat/issues/185
- Appx removal for all users erroring on Windows 10: https://github.com/Raphire/Win11Debloat/issues/131
- WinGet uninstall of Copilot timing out on Windows 10 22H2, with the app left installed: https://github.com/Raphire/Win11Debloat/issues/822 (earlier hang: https://github.com/Raphire/Win11Debloat/issues/730)
- Start menu pins and the Recommended section returning or no longer being removed after Windows updates: https://github.com/Raphire/Win11Debloat/issues/282, https://github.com/Raphire/Win11Debloat/issues/419

---

## 2. RemoveWindowsAI (zoicware): original repo unavailable

- **Original URL (404 on 2026-11-23):** https://github.com/zoicware/RemoveWindowsAI
- **Sources used instead:** mirror https://github.com/kinoosaki/RemoveWindowsAI (described by its owner as "restored from SourceForge"; created 2026-11-11) and https://sourceforge.net/projects/removewindowsai/ (an automated "exact mirror", last updated 2026-10-31). Neither is confirmed to be maintained by the author.
- **License:** MIT, copyright 2024 zoicware, per the mirror's LICENSE file (https://github.com/kinoosaki/RemoveWindowsAI/blob/main/LICENSE) and the SourceForge listing.
- **Stars / last commit:** not available, since the repo is gone. The mirror's numbers are not the original's. The mirror README carries a badge claiming "#11 Top 100 PowerShell Repos"; the star count is **unverified**.
- **Background:** The Register covered it on 2026-01-13 as a script by "zoicware" hosted on GitHub (https://www.theregister.com/2026/01/13/script_removes_ai_from_windows/).

**What it removes or disables** (mirror README, https://github.com/kinoosaki/RemoveWindowsAI/blob/main/README.md): Copilot, Recall, input insights, Copilot in Edge, Paint and Notepad AI, AI actions, Click to Do, AI in Settings search, Office Copilot, Photos AI, voice effects, the AI Fabric service, Recall scheduled tasks, the "AI Components" Settings page, Defender's AI platform process, and optionally the NPU device.

**Methods** (mirror documentation, https://github.com/kinoosaki/RemoveWindowsAI/blob/main/Documentation.md):
- Registry and group policy values, also written into the policy file so they show in `gpedit.msc`.
- Edits to Edge's local state file and to UWP apps' `settings.dat`.
- Edits to `IntegratedServicesRegionPolicySet.json` to flip Copilot-related region policies.
- Appx removal including packages flagged non-removable. The documentation itself calls the techniques "exploits": running as TrustedInstaller, marking packages end-of-life in the Appx all-user store, adding them to the deprovisioned list, clearing the non-removable policy through DISM, and deleting inbox-app registrations.
- Optional feature removal: Recall is disabled with its payload removed.
- CBS manipulation: hidden packages are made visible by editing their servicing registry keys (visibility flag, owner and update subkeys), then removed.
- A custom update package is installed so Windows believes a newer AI package is present. The documentation credits this method to Atlas and ReviOS.
- File deletion of package install folders and machine-learning DLLs.
- Scheduled tasks: Recall tasks removed by deleting task files and registry entries; a new task re-runs cleanup after Windows updates.
- An image-file-execution debugger entry is used against the Defender AI process.
- The repo ships classic `mspaint` and Snipping Tool binaries taken from a Windows Server 2025 ISO (documentation, above).

**Revert.** A `-backupMode` switch must be used on the first run "to be able to fully revert"; it also creates a restore point. A `-revertMode` switch reverses the selected options (mirror README, above).

**Reported breakages.** The original issue tracker is gone, so no issues can be linked. Available evidence:
- The README warns that third-party antivirus flags the script, and that PowerShell 7 "WILL cause issues" (mirror README).
- The documentation says end-of-life registry entries are removed after uninstall "to avoid Windows Update from failing", which shows the technique can break Windows Update if left in place (mirror documentation).
- The author says full removal is not guaranteed on Home editions (mirror documentation).
- SourceForge shows a "Malware Detected" download warning, and its one review reports an update process that keeps the PC from sleeping and says the GitHub repo was removed (https://sourceforge.net/projects/removewindowsai/). Single review; **unverified**.

---

## 3. Bloatynosy / Winpilot / BloatynosyAI (builtbybel)

- **URL:** https://github.com/builtbybel/Bloatynosy (the Winpilot and BloatynosyAI names redirect here)
- **License:** MIT (https://github.com/builtbybel/Bloatynosy/blob/main/LICENSE)
- **Stars / last commit:** 5,892 / 2026-11-06 (https://api.github.com/repos/builtbybel/Bloatynosy); latest release 1.12.10 on 2026-11-12 (https://github.com/builtbybel/Bloatynosy/releases)
- **History:** the README says the classic app was renamed, then discontinued, replaced by Winpilot, and has now been rebuilt as "Bloatynosy Origin". Older code sits under `legacy/`, including `legacy/BloatynosyAI/` (https://github.com/builtbybel/Bloatynosy/blob/main/README.md).

**What it removes or disables.** 98 registry tweaks per the README badge, covering ads, privacy, UI, gaming and AI, plus uninstall of Store and Win32 apps. Legacy code has Copilot taskbar and Recall (machine and user) toggles (https://github.com/builtbybel/Bloatynosy/tree/main/legacy/Bloatynosy/Experience/AI).

**Methods** (README "Under the hood"):
- Each setting writes one registry value. The app "does not patch system files, does not stop services".
- Every value is checked before writing and read back afterwards; a mismatch is reported as a failure.
- Store apps are removed for the current user only. Packages marked non-removable, framework or resource are refused.
- Win32 programs are removed by launching the vendor's own uninstall command, counted as "uninstallers started", not as removed.
- Rules live in data files (`Data/WinRules.ini`, `Data/AppRules.ini`), with JSON community recipes and plugin packs (https://github.com/builtbybel/Bloatynosy/tree/main/Community/Recipes).
- It does not demand admin rights up front; refused writes are reported.

**Revert.** Settings with a documented default can be reset from the "Already applied" branch, and single rows have "Undo now". Uninstalled apps are the stated exception (README, above).

**Reported breakages.**
- Winpilot opening Windows Update unexpectedly: https://github.com/builtbybel/Bloatynosy/issues/160
- User asking how to get the Microsoft Store back: https://github.com/builtbybel/Bloatynosy/issues/127
- No high-comment reports of Start menu or servicing corruption were found in the search of this tracker on 2026-11-23.

---

## 4. win-ai-tools (waar19): identity unconfirmed

- **URL:** https://github.com/waar19/win-ai-tools
- **License:** MIT (https://github.com/waar19/win-ai-tools/blob/main/LICENSE)
- **Stars / last commit:** 7 / 2026-01-13 (https://api.github.com/repos/waar19/win-ai-tools)
- **Form:** Python GUI, shipped as a PyInstaller executable (https://github.com/waar19/win-ai-tools/blob/main/README.md).

**What it removes or disables.** Eleven AI-related services by its own count: Copilot, Recall, AI Explorer, Bing search in Start, taskbar web search, Widgets, Cortana, Edge Copilot sidebar, AI voice typing, suggested actions (README).

**Methods.** A list of service definitions in code, each with registry values (path, name, disable value, enable value, hive), optional Appx package names, and an optional Windows feature name. Disabling writes the registry values, removes matching Appx packages for the current user by wildcard name, and disables the optional feature (https://github.com/waar19/win-ai-tools/blob/main/core/ai_services.py, https://github.com/waar19/win-ai-tools/blob/main/core/manager.py).

**Revert.** Each service has an enable path that writes the stored enable values. A backup function saves current registry values to a timestamped JSON file in the user profile and can restore them (manager.py, above). From reading that file: the backup records only values that already exist, so a value the tool newly created would not be deleted on restore, and removed Appx packages are not reinstalled. That reading is mine, not a documented statement.

**Reported breakages.** The tracker has no issues (https://github.com/waar19/win-ai-tools/issues). The README warns that settings may reset after major Windows updates.

**Note.** Compiled build output and `__pycache__` are committed to the repo (https://github.com/waar19/win-ai-tools/tree/main/build).

---

## 5. Chris Titus Tech WinUtil

- **URL:** https://github.com/ChrisTitusTech/winutil
- **License:** MIT, copyright CT Tech Group LLC (https://github.com/ChrisTitusTech/winutil/blob/main/LICENSE)
- **Stars / last commit:** 66,542 / 2026-11-18 (https://api.github.com/repos/ChrisTitusTech/winutil)

**What it removes or disables.** Telemetry, a services-to-manual set, Edge debloat policies, optional Edge and OneDrive removal, a "Windows AI - Disable And Remove" tweak, app installs through WinGet, Windows Update presets, and an ISO builder (formerly MicroWin, now "Win11 Creator" in issue titles) (https://github.com/ChrisTitusTech/winutil/blob/main/config/tweaks.json).

**Methods.**
- JSON catalog: `config/tweaks.json` held 69 entries on 2026-11-23. Entries may carry a registry list (path, name, value, type, original value), a service list (name, startup type, original type), an invoke script and an undo script. Of 69 entries, 50 had registry lists, 4 had service lists, 27 had invoke scripts and 22 had undo scripts (same file). Other catalogs: `appx.json`, `feature.json`, `applications.json`, `dns.json`, `preset.json` (https://github.com/ChrisTitusTech/winutil/tree/main/config).
- Edge removal: per the catalog description, it creates a dummy file in the legacy Edge folder so the official uninstaller unlocks (tweaks.json).
- OneDrive removal: runs OneDrive's own uninstaller while protecting user files (tweaks.json).
- Hosts file: an Adobe network block tweak edits hosts (https://github.com/ChrisTitusTech/winutil/issues/4039).
- A restore point tweak is checked by default (tweaks.json).
- The repo contains `AGENTS.md`, `CLAUDE.md` and `GEMINI.md` for coding agents (https://github.com/ChrisTitusTech/winutil).

**Revert.** Per-entry original values for registry and services, plus undo scripts, drive an "undo" action. The "Windows AI - Disable And Remove" entry has no undo script in the catalog (tweaks.json).

**Reported breakages.**
- Windows Update failing on installs built with MicroWin / Win11 Creator: https://github.com/ChrisTitusTech/winutil/issues/3214, https://github.com/ChrisTitusTech/winutil/issues/2118, https://github.com/ChrisTitusTech/winutil/issues/3651, https://github.com/ChrisTitusTech/winutil/issues/5130
- Store and inbox apps failing after updates, with an update-repair service left disabled: https://github.com/ChrisTitusTech/winutil/issues/5095
- Store and WinGet stopped working after "Disable all updates": https://github.com/ChrisTitusTech/winutil/issues/3859
- Policies left behind lock settings with "managed by your organisation": https://github.com/ChrisTitusTech/winutil/issues/4242
- Undo of the Adobe block deleted the hosts file: https://github.com/ChrisTitusTech/winutil/issues/4039; undo of hibernation did not re-enable it: https://github.com/ChrisTitusTech/winutil/issues/1798
- Edge removal broke sign-in for apps needing WebView2: https://github.com/ChrisTitusTech/winutil/issues/1075; Edge removal failing on 24H2: https://github.com/ChrisTitusTech/winutil/issues/2969
- Start menu not working after a context-menu tweak: https://github.com/ChrisTitusTech/winutil/issues/4446; old Start menu tweak dead after a cumulative update: https://github.com/ChrisTitusTech/winutil/issues/4687
- Start search missing newly installed apps after the bundled O&O ShutUp10 run: https://github.com/ChrisTitusTech/winutil/issues/569
- Tool hangs while removing Recall: https://github.com/ChrisTitusTech/winutil/issues/3179
- Copilot removed without being ticked: https://github.com/ChrisTitusTech/winutil/issues/2112

---

## 6. O&O ShutUp10++ (O&O Software)

- **URL:** https://www.oo-software.com/en/shutup10
- **License:** proprietary freeware, closed source. The product page calls the free edition "completely free"; a paid Premium edition exists (same URL). No SPDX id applies. The EULA text was not read, so commercial-use terms are **unverified**.
- **Stars / last commit:** not on GitHub. Latest version 3.7.1143, dated 11/10/2026 (https://www.oo-software.com/en/shutup10/changelog).

**What it disables.** Privacy, telemetry, app-access, Edge, Office and Windows Update settings for Windows 10 and 11. AI coverage per the changelog: Copilot and Recall disabling since 2023-2024; Copilot removal and secure deletion of Recall data in 2.0.1009; Click to Do, Settings Agent, AI editor features, AI actions in File Explorer and generative-AI app access in 3.2.1111 (changelog URL above).

**Methods.** Setting toggles identified by ids such as `C208` or `P082` (changelog). The changelog refers to policy keys and to writing or deleting values, which indicates registry and policy changes; the exact mechanism per setting is closed source and **unverified**. Use of services, tasks, hosts or firewall is **unverified**.

**Revert.** Restore point prompt before changes; "reset to factory settings"; from 3.3.1119 a change history of the last 10 sessions with undo and "Restore Original Settings"; settings import from the command line with a quiet switch and a switch to skip the restore point (changelog).

**Reported breakages** (vendor changelog entries, same URL):
- 3.0.1076 fixed factory reset leaving policy keys "that blocked Windows updates".
- 3.5.1130 changed two settings to write the Windows default instead of deleting the value, to stop them reactivating.
- Third-party report: Start search missing new apps after a WinUtil-driven O&O run (https://github.com/ChrisTitusTech/winutil/issues/569).

---

## 7. Window-Debloat-Agent (writtenonwater99): identity unconfirmed

- **URL:** https://github.com/writtenonwater99/Window-Debloat-Agent
- **License:** none. There is no LICENSE file and the API reports no license (https://api.github.com/repos/writtenonwater99/Window-Debloat-Agent). With no license, default copyright applies.
- **Stars / last commit:** 0 / 2026-11-17, repo created the same day (same API URL).

**What it does.** It removes nothing. It is a read-only inventory script plus instructions for an AI agent. The README states "The PowerShell collector is read-only" and the agent instructions say the release "contains no validated change executor" (https://github.com/writtenonwater99/Window-Debloat-Agent/blob/main/README.md, https://github.com/writtenonwater99/Window-Debloat-Agent/blob/main/AGENTS.md).

**Methods.** The collector emits JSON in sections, each with its own status: Windows edition and build, architecture, system drive space, domain membership, registered desktop software, current-user Store packages, provisioned packages, optional features, and startup entries (https://github.com/writtenonwater99/Window-Debloat-Agent/blob/main/Review-Windows.ps1). The agent workflow groups findings into keep, ask the owner, and unresolved, and treats inventory strings as data (AGENTS.md). A separate guide routes Copilot, Recall and diagnostic-data questions to Microsoft's own Settings pages (https://github.com/writtenonwater99/Window-Debloat-Agent/blob/main/AI-AND-PRIVACY.md).

**Revert.** Not applicable; nothing is changed.

**Reported breakages.** No issues exist (https://github.com/writtenonwater99/Window-Debloat-Agent/issues).

---

## 8. Sophia Script for Windows (farag2)

- **URL:** https://github.com/farag2/Sophia-Script-for-Windows
- **License:** MIT (https://github.com/farag2/Sophia-Script-for-Windows/blob/main/LICENSE)
- **Stars / last commit:** 9,977 / 2026-11-22 (https://api.github.com/repos/farag2/Sophia-Script-for-Windows)
- **Targets:** the README's support table lists Windows 10 22H2, several LTSC releases and "Windows 11 26H2+" (https://github.com/farag2/Sophia-Script-for-Windows/blob/main/README.md). Support for 23H2/24H2/25H2 in the current release is therefore **unverified**; older tagged releases may be needed.

**What it removes or disables.** "More than 150 unique functions": privacy, telemetry service and diagnostic level, UWP app uninstall with a dynamic list, OneDrive uninstall, scheduled cleanup tasks, DNS-over-HTTPS, file associations, and a "Windows AI functions" disable/enable pair (README; preset file https://github.com/farag2/Sophia-Script-for-Windows/blob/main/src/Sophia_Script_for_Windows_11/Sophia.ps1).

**Methods.** A PowerShell module with one function per tweak, called from a preset file or by name. Registry policies are written so they appear in `gpedit.msc`. Separate script trees per Windows version, architecture and PowerShell version (README; https://github.com/farag2/Sophia-Script-for-Windows/tree/main/src). The README says it uses "Microsoft's officially documented ways".

**Revert.** "Every tweak has a corresponding function to restore the default settings" (README). The preset creates a restore point first (Sophia.ps1, above).

**Reported breakages.**
- `sfc /scannow` stalling after a run on Windows 10 21H2: https://github.com/farag2/Sophia-Script-for-Windows/issues/334
- The script's own environment checks refuse to run on systems altered by other tweakers (Task Scheduler or edition query reported as "broken or removed"): https://github.com/farag2/Sophia-Script-for-Windows/issues/561, https://github.com/farag2/Sophia-Script-for-Windows/issues/554
- Appx removal "Access is denied": https://github.com/farag2/Sophia-Script-for-Windows/issues/256
- Conflict with Kaspersky: https://github.com/farag2/Sophia-Script-for-Windows/issues/605

---

## 9. tiny11builder (ntdevlabs)

- **URL:** https://github.com/ntdevlabs/tiny11builder
- **License:** none. No LICENSE file; the repo's own notice says "This upstream checkout contains no standalone license file" and that a public repo "alone does not grant redistribution rights" (https://github.com/ntdevlabs/tiny11builder/blob/winui-preview/NOTICE.md).
- **Stars / last commit:** 22,490 / 2026-10-30 on default branch `winui-preview` (https://api.github.com/repos/ntdevlabs/tiny11builder)
- **Scope:** offline image builder for Windows 11 22H2 onward. It modifies install media, not a running system (https://github.com/ntdevlabs/tiny11builder/blob/winui-preview/README.md).

**What it removes.** Tiny11 preset: bundled apps, Edge/WebView2 and OneDrive binaries, hardware-check, reserved-storage and auto-encryption settings; keeps Update, Defender, recovery and Store. Core preset: also deletes most WinSxS component folders, removes recovery, and disables Windows Update and Defender. Custom: individual apps, protected system apps, optional features, language capabilities, CBS packages, services, drivers and WinSxS folders (https://github.com/ntdevlabs/tiny11builder/blob/winui-preview/docs/usage.md).

**Methods.** DISM image servicing on a mounted image, offline registry hive edits, file deletion, and JSON "recipes" that record a removal set (usage.md and https://github.com/ntdevlabs/tiny11builder/tree/winui-preview/recipes).

**Revert.** None for a built image. The usage guide says Core changes "cannot be reversed"; the README says Core "cannot be updated or serviced".

**Reported breakages.**
- Search bar dead after cumulative updates on 25H2 images: https://github.com/ntdevlabs/tiny11builder/issues/524, https://github.com/ntdevlabs/tiny11builder/issues/575
- Updates failing to install: https://github.com/ntdevlabs/tiny11builder/issues/543, https://github.com/ntdevlabs/tiny11builder/issues/22
- Store and Defender missing, users asking how to restore: https://github.com/ntdevlabs/tiny11builder/issues/539

---

## 10. privacy.sexy (undergroundwires)

- **URL:** https://github.com/undergroundwires/privacy.sexy
- **License:** AGPL-3.0 (https://github.com/undergroundwires/privacy.sexy/blob/master/LICENSE)
- **Stars / last commit:** 6,186 / 2025-04-18 on the default branch; the repo's `pushed_at` is 2026-02-13 (https://api.github.com/repos/undergroundwires/privacy.sexy). 251 open issues.

**What it removes or disables.** "Hundreds of scripts" for Windows, macOS and Linux: telemetry, bloatware and system-app removal, Defender, services, Windows Update, firewall and more (https://github.com/undergroundwires/privacy.sexy/blob/master/README.md).

**Methods.** A data-driven generator: one YAML collection per OS with a schema file, and a templating language; the Windows collection alone is about 4 MB. It emits a script the user runs (https://github.com/undergroundwires/privacy.sexy/tree/master/src/application/collections). The exact Windows mechanisms per script were not read in this pass; issue titles show service removal, system-app removal and firewall-related changes (links below).

**Revert.** Advertised as "Reversible. Revert if something feels wrong" (README); scripts carry paired revert code. Revert is not complete in practice (issues below).

**Reported breakages.**
- "Remove system apps" breaks cumulative updates: https://github.com/undergroundwires/privacy.sexy/issues/287
- Search still broken after restoring: https://github.com/undergroundwires/privacy.sexy/issues/358
- Reverting removed Windows services fails: https://github.com/undergroundwires/privacy.sexy/issues/270
- Standard preset breaks Phone Link: https://github.com/undergroundwires/privacy.sexy/issues/350
- Taskbar calendar broken: https://github.com/undergroundwires/privacy.sexy/issues/314
- Disabling Defender also breaks Windows Firewall: https://github.com/undergroundwires/privacy.sexy/issues/193
- Online game logins broken: https://github.com/undergroundwires/privacy.sexy/issues/185

---

## 11. Atlas (Atlas-OS)

- **URL:** https://github.com/Atlas-OS/Atlas
- **License:** GPL-3.0 (https://github.com/Atlas-OS/Atlas/blob/main/LICENSE)
- **Stars / last commit:** 22,179 / 2026-11-23 (https://api.github.com/repos/Atlas-OS/Atlas)
- **Targets:** Windows 11 25H2 (build 26200) and 26H2 (build 26300) only, public releases only (https://github.com/Atlas-OS/Atlas/blob/main/docs/windows-release-policy.md).

**What it changes.** Telemetry and data-collection policies; background activity, services and power settings; user choices for Defender, SmartScreen, Windows Update, CPU mitigations and core isolation; interface defaults, ads and selected apps (https://github.com/Atlas-OS/Atlas/blob/main/README.md).

**Methods.** Installed by its own "Atlas Manager" from a package that is mostly PowerShell and data, with a JSON manifest listing supported builds, pre-install requirement checks and install choices (https://github.com/Atlas-OS/Atlas/blob/main/docs/package-format.md). The package is a password-protected archive because antivirus would otherwise quarantine scripts that remove Defender (same file). Intended for a fresh Windows install (README). RemoveWindowsAI's documentation credits Atlas with the "fake newer package" method for blocking AI package reinstall (https://github.com/kinoosaki/RemoveWindowsAI/blob/main/Documentation.md); that was not confirmed in Atlas's own source, so it is **unverified**.

**Revert.** No full uninstall was found in the files read. An installed desktop folder has per-setting controls "including putting some settings back to the Windows defaults", and a read-only health check reports what changed (README). A published toggle catalog lists each control (https://github.com/Atlas-OS/Atlas/blob/main/docs/catalog/toggles.md).

**Reported breakages.**
- Microsoft Store installs failing (139 comments): https://github.com/Atlas-OS/Atlas/issues/1556; also https://github.com/Atlas-OS/Atlas/issues/1353, https://github.com/Atlas-OS/Atlas/issues/1675
- Windows Update configuration problems: https://github.com/Atlas-OS/Atlas/issues/974
- Settings account page disappearing after updates: https://github.com/Atlas-OS/Atlas/issues/1140

---

## 12. ReviOS Playbook (meetrevision)

- **URL:** https://github.com/meetrevision/playbook
- **License:** CC-BY-SA-4.0 (https://github.com/meetrevision/playbook/blob/main/LICENSE)
- **Stars / last commit:** 2,140 / 2026-11-23 (https://api.github.com/repos/meetrevision/playbook)
- **Targets:** Windows 10 21H2/22H2 and Windows 11 23H2, 24H2, 25H2, 26H1 (https://github.com/meetrevision/playbook/blob/main/README.md).

**What it removes or disables.** "Removes bloatware and unnecessary system components"; privacy, update, security and UI registry settings; Defender disabling; an option to remove AI components (README; https://github.com/meetrevision/playbook/blob/main/src/Configuration/Tasks/packages/win-sxs.yml).

**Methods.** YAML task files run by AME Wizard, many with TrustedInstaller privilege: registry values, services, Appx, optional features, Win32 apps and WinSxS system packages (https://github.com/meetrevision/playbook/tree/main/src/Configuration/Tasks). A deprovisioned-apps registry task exists (same tree). System components are now removed by installing a removal package through the project's own tool; the task file notes the older direct system-package method is "deprecated" and "one of the main cause of #49" (win-sxs.yml, above).

**Revert.** No general undo. A `revert.yml` task rolls back specific tweaks from older playbook versions on upgrade, each annotated with the issue it caused (https://github.com/meetrevision/playbook/blob/main/src/Configuration/Tasks/revert.yml). The README recommends starting from a fresh Windows install.

**Reported breakages.**
- Cumulative updates failing with error 0x800f0984: https://github.com/meetrevision/playbook/issues/49
- Disabling root certificate auto-update caused problems: https://github.com/meetrevision/playbook/issues/15
- Windows Update could not update a driver on 24H2: https://github.com/meetrevision/playbook/issues/121
- Service and registry tweaks that broke the Xbox accessory service, Task Manager efficiency mode and Game Bar recording are recorded in revert.yml (above).

---

## 13. Windows10Debloater (Sycnex)

- **URL:** https://github.com/Sycnex/Windows10Debloater
- **License:** MIT, copyright 2017 Richard Newton (https://github.com/Sycnex/Windows10Debloater/blob/master/LICENSE)
- **Stars / last commit:** 18,788 / 2021-06-27; archived; 299 open issues (https://api.github.com/repos/Sycnex/Windows10Debloater)

**What it removes or disables.** Preinstalled Windows 10 apps, leftover registry keys, some telemetry, Cortana in search, and a set of scheduled tasks (https://github.com/Sycnex/Windows10Debloater/blob/master/README.md).

**Methods.** Appx removal and provisioned-package removal, registry key deletion, scheduled task disabling; a Sysprep switch that removes all Appx packages first (README).

**Revert.** A "Revert" option that "reinstalls the bloatware and changes your registry keys back to default" (README).

**Reported breakages.**
- Start menu and Microsoft Store gone: https://github.com/Sycnex/Windows10Debloater/issues/361
- Store unavailable for another user: https://github.com/Sycnex/Windows10Debloater/issues/130
- Store, Calculator and Photos removed unexpectedly: https://github.com/Sycnex/Windows10Debloater/issues/5
- Start menu broken or cleared: https://github.com/Sycnex/Windows10Debloater/issues/277, https://github.com/Sycnex/Windows10Debloater/issues/131
- Quick access broken: https://github.com/Sycnex/Windows10Debloater/issues/462

---

## 14. Other tools found

### hellzerg/optimizer
- https://github.com/hellzerg/optimizer; GPL-3.0 (https://github.com/hellzerg/optimizer/blob/master/LICENSE); 18,309 stars; last commit 2026-11-21.
- README lists disabling services, stopping automatic updates, disabling Copilot in Windows 11 and Edge, registry fixes and a hosts editor (https://github.com/hellzerg/optimizer/blob/master/README.md). Revert mechanism **unverified**.
- Issues: could not re-enable Windows Update (https://github.com/hellzerg/optimizer/issues/74); Windows 22H2 update problem (https://github.com/hellzerg/optimizer/issues/348); automatic-update handling (https://github.com/hellzerg/optimizer/issues/268).

### LeDragoX/Win-Debloat-Tools
- https://github.com/LeDragoX/Win-Debloat-Tools; MIT (https://github.com/LeDragoX/Win-Debloat-Tools/blob/main/LICENSE.txt); 6,341 stars; last commit 2026-10-29; archived.
- Methods per README: restore point and hosts backup first, scheduled tasks, services, Windows capabilities, registry and policy keys, Edge and Xbox removal; bundles O&O ShutUp10++ and AdwCleaner, which "have their own licenses" (https://github.com/LeDragoX/Win-Debloat-Tools/blob/main/README.md).
- Revert: an "Undo Tweaks" button that restores "(almost) everything", plus the restore point. The README warns that not every removed feature can be easily restored.
- Issue: complaint about scheduled update tasks created without asking (https://github.com/LeDragoX/Win-Debloat-Tools/issues/122).

### W4RH4WK/Debloat-Windows-10
- https://github.com/W4RH4WK/Debloat-Windows-10; Beerware, which GitHub reports as `NOASSERTION` (SPDX id `Beerware`) (https://github.com/W4RH4WK/Debloat-Windows-10/blob/master/LICENSE); 6,128 stars; last commit 2025-09-23; archived and marked deprecated.
- Methods per README: scripts that disable services, Defender and scheduled tasks, remove apps, and block domains in the hosts file. The README states "There is no undo" and notes some blocked domains are needed by other features (https://github.com/W4RH4WK/Debloat-Windows-10/blob/master/README.md).
- Issues: Store error 0x80070422 with Windows Update disabled (https://github.com/W4RH4WK/Debloat-Windows-10/issues/260); Start menu broken (https://github.com/W4RH4WK/Debloat-Windows-10/issues/105, https://github.com/W4RH4WK/Debloat-Windows-10/issues/94); search stopped working (https://github.com/W4RH4WK/Debloat-Windows-10/issues/104).

### memstechtips/Winhance
- https://github.com/memstechtips/Winhance; PolyForm Shield 1.0.0, reported by GitHub as `NOASSERTION` (SPDX id `PolyForm-Shield-1.0.0`) (https://github.com/memstechtips/Winhance/blob/main/LICENSE.txt); 15,052 stars; last commit 2026-09-30.
- Source-available, not open source: the README says it cannot be forked or rebranded and redistributed as a competing product (https://github.com/memstechtips/Winhance/blob/main/README.md). Methods and revert **unverified** in this pass.
- Issues: Start menu showing nothing (https://github.com/memstechtips/Winhance/issues/285); startup programs not starting (https://github.com/memstechtips/Winhance/issues/377); cannot type in Start search (https://github.com/memstechtips/Winhance/issues/25); reinstalling the Store (https://github.com/memstechtips/Winhance/issues/128); registry backup broken (https://github.com/memstechtips/Winhance/issues/42).

### xM4ddy/OFGB
- https://github.com/xM4ddy/OFGB; Unlicense (https://github.com/xM4ddy/OFGB/blob/main/LICENSE); 7,518 stars; last commit 2024-09-12.
- A small GUI of registry toggles for Windows 11 ads; credits the registry keys to Shawn Brink's ElevenForum script (https://github.com/xM4ddy/OFGB/blob/main/README.md). Checkbox toggles imply two-way revert; **unverified** beyond that.
- Issue: a policy value puts Edge into "Managed" mode (https://github.com/xM4ddy/OFGB/issues/34).

### builtbybel/Flyoobe
- https://github.com/builtbybel/Flyoobe; MIT (https://github.com/builtbybel/Flyoobe/blob/main/LICENSE); 7,363 stars; pushed 2026-10-08. A Windows setup/OOBE tool by the Bloatynosy author. Not examined further.

---

## Cross-cutting findings

1. **Servicing-stack changes are the main source of serious breakage.** Removing system or CBS packages, deleting WinSxS content, or disabling update services is tied to failed cumulative updates and broken Store or search in ReviOS (#49), privacy.sexy (#287), tiny11builder (#524, #575, #543), WinUtil (#5095, #3859) and W4RH4WK (#260). ReviOS deprecated its own direct package-removal method for this reason.
2. **App removal is the least reversible step.** Every tool that documents revert excludes uninstalled apps (Win11Debloat wiki, Bloatynosy README). The Microsoft Store is the worst case (Win11Debloat wiki; Sycnex #361, #130; tiny11builder #539).
3. **Search and Start are fragile.** Disabling Bing or web search by policy is the repeated suspect for dead Start search (Win11Debloat #361, #226; WinUtil #569; privacy.sexy #358).
4. **Policy keys have side effects.** They produce "managed by your organisation" lockouts (WinUtil #4242; OFGB #34) and have blocked updates when left behind (O&O changelog 3.0.1076).
5. **Revert needs the prior state, not only a default.** WinUtil stores an original value per entry; Win11Debloat added a pre-change registry backup on top of static undo files; O&O added session history. O&O's 3.5.1130 fix and my reading of win-ai-tools' backup both show that "value absent" and "value set to default" are different states.
6. **Windows updates undo or outdate tweaks.** Win11Debloat #282 and #419, WinUtil #4687, win-ai-tools README. Responses seen: a post-update re-run task (RemoveWindowsAI), a monitoring service (O&O Premium), strict build gating (Atlas).
7. **Non-interactive runs hang.** Win11Debloat #822 and #730, WinUtil #3179. This matters for agent-driven use.
8. **Supply chain.** The most thorough AI-removal script vanished from GitHub, and its documented one-line installer pulled from that URL. Atlas encrypts its package to avoid antivirus quarantine. Several tools are flagged by antivirus (RemoveWindowsAI README, SourceForge listing).
9. **Data-driven catalogs already exist** in Win11Debloat (JSON), WinUtil (JSON), Bloatynosy (INI and JSON), privacy.sexy (YAML), Atlas (JSON manifest), ReviOS (YAML) and tiny11builder (JSON recipes). Only Window-Debloat-Agent is written for an AI agent, and it stops at read-only review.
