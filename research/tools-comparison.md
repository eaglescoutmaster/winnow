# Windows debloat tools: comparison

Observed 2026-11-23 through the GitHub REST API and each project's own pages. Full findings and per-claim sources are in [01-existing-tools.md](01-existing-tools.md). "Last commit" is the newest commit on the default branch. Issue numbers refer to each tool's own tracker.

| Tool | URL | License (SPDX) | Stars | Last commit | Methods | Revert support | AI-feature coverage | Notable breakages |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Win11Debloat (Raphire) | https://github.com/Raphire/Win11Debloat | MIT | 63,572 | 2026-11-15 | Registry `.reg` files; Appx and WinGet removal; optional features (enable only); JSON catalog | Pre-change registry backup; 66 undo `.reg` files; Start layout backup; restore point. Apps not restored | Copilot, Recall, Click to Do, AI service auto-start, AI in Edge, Chrome, Paint, Notepad | Start search dead (#361); Explorer (#226); account sign-in (#537, cause unknown); Copilot WinGet removal timeout (#822); Start tweaks lost after updates (#282, #419) |
| RemoveWindowsAI (zoicware) | https://github.com/zoicware/RemoveWindowsAI (404 on 2026-11-23); mirror https://github.com/kinoosaki/RemoveWindowsAI | MIT (per mirror) | unavailable | unavailable | Registry and policy; Appx removal of non-removable packages as TrustedInstaller; Recall optional feature; hidden CBS package removal; blocker update package; file deletion; scheduled tasks; Edge and UWP settings files | `-backupMode` then `-revertMode`; restore point | Widest found: Copilot, Recall, Click to Do, AI actions, Office, Paint, Notepad, Photos, Edge, Defender AI, NPU | Tracker gone. README warns of antivirus flags and PowerShell 7 problems; docs note a Windows Update failure risk from one technique |
| Bloatynosy / Winpilot / BloatynosyAI (builtbybel) | https://github.com/builtbybel/Bloatynosy | MIT | 5,892 | 2026-11-06 | One registry value per tweak with read-back check; current-user Appx removal; vendor uninstallers; INI and JSON rule files. No services, no file patching | Restore defaults per setting; "Undo now". Apps not restored | Copilot taskbar and Recall toggles (legacy code); current rule set not itemised | Winpilot opened Windows Update (#160); Store recovery question (#127) |
| win-ai-tools (waar19), identity unconfirmed | https://github.com/waar19/win-ai-tools | MIT | 7 | 2026-01-13 | Registry values; wildcard Appx removal; optional feature disable. Python GUI | Enable path per service; JSON backup of existing registry values. Apps not restored | Copilot, Recall, AI Explorer, Bing and web search, Widgets, Cortana, Edge Copilot, voice typing, suggested actions | No issues filed |
| WinUtil (Chris Titus Tech) | https://github.com/ChrisTitusTech/winutil | MIT | 66,542 | 2026-11-18 | JSON catalog of registry, services and scripts; Appx; Edge and OneDrive removal; hosts; ISO builder | Original value per registry and service entry; undo scripts; restore point. AI removal entry has no undo script | "Windows AI - Disable And Remove" tweak; Edge debloat | Updates failing on built ISOs (#3214, #5130); Store broken (#5095, #3859); policy lockout (#4242); undo deleted hosts (#4039); WebView2 loss (#1075); Recall removal hang (#3179) |
| O&O ShutUp10++ | https://www.oo-software.com/en/shutup10 | Proprietary freeware (no SPDX) | n/a | v3.7.1143, 2026-11-10 | Setting toggles; registry and policy per changelog; internals closed | Restore point; factory reset; 10-session undo history; config import | Copilot, Recall (incl. data deletion), Click to Do, Settings Agent, AI in File Explorer, generative-AI app access | Vendor fixes: reset left policy keys that blocked updates (3.0.1076); settings reactivating (3.5.1130). WinUtil #569 |
| Window-Debloat-Agent (writtenonwater99), identity unconfirmed | https://github.com/writtenonwater99/Window-Debloat-Agent | None (no license file) | 0 | 2026-11-17 | Read-only JSON inventory plus agent instructions. Changes nothing | n/a | Guidance only: Copilot app, Recall, diagnostic data | No issues filed |
| Sophia Script (farag2) | https://github.com/farag2/Sophia-Script-for-Windows | MIT | 9,977 | 2026-11-22 | PowerShell module, one function per tweak; registry and policies; UWP removal; OneDrive; scheduled tasks | Paired restore-default function for every tweak; restore point | "Windows AI functions" disable/enable | sfc stall (#334); refuses altered systems (#561, #554); Appx access denied (#256) |
| tiny11builder (ntdevlabs) | https://github.com/ntdevlabs/tiny11builder | None (no license file) | 22,490 | 2026-10-30 | Offline image: DISM, provisioned apps, CBS packages, WinSxS deletion, offline registry, services; JSON recipes | None; rebuild the image | Not itemised (unverified) | Search dead after cumulative updates (#524, #575); update failures (#543); Store and Defender missing (#539) |
| privacy.sexy (undergroundwires) | https://github.com/undergroundwires/privacy.sexy | AGPL-3.0 | 6,186 | 2025-04-18 | YAML collection generating scripts; services, system apps, Defender, firewall (per issues) | Paired revert scripts; incomplete in practice | Not checked (unverified) | Cumulative updates broken (#287); search not restored (#358); service revert fails (#270); Firewall (#193) |
| Atlas (Atlas-OS) | https://github.com/Atlas-OS/Atlas | GPL-3.0 | 22,179 | 2026-11-23 | Own installer; PowerShell package with JSON manifest; policies, services, power, app removal, Defender choices | Per-setting toggles back to defaults; health check. No full uninstall found | Not itemised (unverified) | Store failures (#1556, #1353, #1675); Update config (#974); Settings page lost (#1140) |
| ReviOS Playbook (meetrevision) | https://github.com/meetrevision/playbook | CC-BY-SA-4.0 | 2,140 | 2026-11-23 | AME Wizard YAML as TrustedInstaller: registry, services, Appx, optional features, WinSxS system packages | No general undo; upgrade-time rollback of known-bad tweaks | Optional AI component removal | Cumulative updates fail 0x800f0984 (#49); root-cert update (#15); driver update (#121) |
| Windows10Debloater (Sycnex) | https://github.com/Sycnex/Windows10Debloater | MIT | 18,788 | 2021-06-27 (archived) | Appx and provisioned removal; registry key deletion; scheduled tasks | "Revert" reinstalls apps and resets keys | None (predates them) | Start menu and Store gone (#361, #130, #277); Quick access (#462) |
| Optimizer (hellzerg) | https://github.com/hellzerg/optimizer | GPL-3.0 | 18,309 | 2026-11-21 | Services, registry, update blocking, hosts editor | Unverified | Copilot in Windows 11 and Edge | Could not re-enable Windows Update (#74); 22H2 update issue (#348) |
| Win-Debloat-Tools (LeDragoX) | https://github.com/LeDragoX/Win-Debloat-Tools | MIT | 6,341 | 2026-10-29 (archived) | Tasks, services, capabilities, registry and policy, Edge and Xbox removal; bundles O&O ShutUp10++ | "Undo Tweaks" for almost everything; restore point; hosts backup | Unverified | Update tasks created without consent (#122) |
| Debloat-Windows-10 (W4RH4WK) | https://github.com/W4RH4WK/Debloat-Windows-10 | Beerware (API: NOASSERTION) | 6,128 | 2025-09-23 (archived) | Services, Defender, tasks, app removal, hosts blocking | None ("There is no undo") | None | Store error with Update disabled (#260); Start menu (#105, #94); search (#104) |
| Winhance (memstechtips) | https://github.com/memstechtips/Winhance | PolyForm-Shield-1.0.0 (API: NOASSERTION) | 15,052 | 2026-09-30 | Unverified | Unverified | Unverified | Start menu empty (#285); startup apps (#377); Store reinstall (#128); registry backup broken (#42) |
| OFGB (xM4ddy) | https://github.com/xM4ddy/OFGB | Unlicense | 7,518 | 2024-09-12 | Registry toggles for Windows 11 ads | Checkbox toggles (unverified) | None | Edge shown as "Managed" (#34) |

Out of scope by request: simplewall.

## Credits

Our project is original work. These projects informed the design; no code was copied from any of them.

- **Win11Debloat** by Raphire: https://github.com/Raphire/Win11Debloat
- **RemoveWindowsAI** by zoicware: originally https://github.com/zoicware/RemoveWindowsAI (unavailable on 2026-11-23); read through the mirror by kinoosaki, https://github.com/kinoosaki/RemoveWindowsAI
- **Bloatynosy / Winpilot / BloatynosyAI** by Builtbybel (Belim): https://github.com/builtbybel/Bloatynosy
- **win-ai-tools** by waar19: https://github.com/waar19/win-ai-tools
- **WinUtil** by Chris Titus Tech (CT Tech Group LLC) and contributors: https://github.com/ChrisTitusTech/winutil
- **O&O ShutUp10++** by O&O Software GmbH: https://www.oo-software.com/en/shutup10
- **Window-Debloat-Agent** by writtenonwater99: https://github.com/writtenonwater99/Window-Debloat-Agent
- **Sophia Script for Windows** by farag2 (Dmitry Nefedov) and contributors: https://github.com/farag2/Sophia-Script-for-Windows
- **tiny11builder** by ntdevlabs (NTDEV): https://github.com/ntdevlabs/tiny11builder
- **privacy.sexy** by undergroundwires: https://github.com/undergroundwires/privacy.sexy
- **Atlas** by the Atlas-OS team: https://github.com/Atlas-OS/Atlas
- **ReviOS Playbook** by Revision (meetrevision): https://github.com/meetrevision/playbook
- **Windows10Debloater** by Sycnex (Richard Newton): https://github.com/Sycnex/Windows10Debloater
- **Optimizer** by hellzerg: https://github.com/hellzerg/optimizer
- **Win-Debloat-Tools** by LeDragoX (Plínio Larrubia): https://github.com/LeDragoX/Win-Debloat-Tools
- **Debloat-Windows-10** by W4RH4WK and contributors: https://github.com/W4RH4WK/Debloat-Windows-10
- **Winhance** by memstechtips (Marco du Plessis): https://github.com/memstechtips/Winhance
- **OFGB** by xM4ddy, with registry keys credited there to Shawn Brink: https://github.com/xM4ddy/OFGB

## License notes

This is a working summary, not legal advice.

**Cannot be pasted into an MIT repo**

- **GPL-3.0: Atlas, Optimizer.** Copyleft. Any copied code would force the combined work to GPL-3.0.
- **AGPL-3.0: privacy.sexy.** Copyleft with a network clause. This includes its YAML script collection, which is the part most tempting to borrow.
- **CC-BY-SA-4.0: ReviOS Playbook.** ShareAlike. Adapted material must stay under CC-BY-SA, which cannot be relicensed as MIT.
- **PolyForm Shield 1.0.0: Winhance.** Source-available with a non-compete condition. Not an open-source license.
- **Proprietary: O&O ShutUp10++.** Closed source freeware. Do not bundle or redistribute the binary without checking the EULA, which was not read in this pass.
- **No license: tiny11builder, Window-Debloat-Agent.** Default copyright applies, so there is no permission to copy or redistribute. tiny11builder's own notice says so.

**Permissive, but still not copied**

- **MIT: Win11Debloat, WinUtil, Sophia Script, Bloatynosy, Windows10Debloater, Win-Debloat-Tools, win-ai-tools, RemoveWindowsAI (per mirror).** Copying would be legal with the copyright and permission notice preserved. The project rule is still to write original code and catalog entries.
- **Unlicense: OFGB.** Public-domain dedication.
- **Beerware: Debloat-Windows-10.** Permissive, notice must be retained.

**Other points**

- RemoveWindowsAI's MIT status rests on a third-party mirror's LICENSE file and a SourceForge listing, because the original repo is gone. Treat it as lower confidence.
- That mirror also contains Microsoft binaries (classic Paint and Snipping Tool from a Server ISO). The MIT license of the script does not cover those. Never redistribute Microsoft binaries.
- Win-Debloat-Tools bundles O&O ShutUp10++ and AdwCleaner under their own licenses. An MIT label on a repo does not cover everything inside it.
- Registry paths, policy names, package names and service names are facts about Windows. Our catalog should be built from Microsoft documentation and our own testing, with each entry citing its source, so no entry depends on another project's selection or wording.
- Two GitHub license fields read `NOASSERTION` (Debloat-Windows-10, Winhance). The SPDX ids above come from reading the LICENSE files.
