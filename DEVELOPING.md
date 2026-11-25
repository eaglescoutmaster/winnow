# Developing Winnow

Notes for maintainers. Not imported by `CLAUDE.md`/`AGENTS.md`, so debloat agents never load it.

## Status

| Tag | Adds |
|---|---|
| v0.1.0 | Windows engine, catalog (152 items), CI, managed/pending-restart guards |
| v0.2.0 | Linux (81 items) and macOS (31 items) catalogs, `scripts/winnow.py` |
| v0.3.0 | Local GUI for all three platforms |
| v0.4.0 | One-shot mode: `-Auto` / `auto`, aggressive default, agent contract asks nothing; Edge never-default and PDF items (154 items) |

`PROMPT.md` pins the clone to a tag. Bump it in the same commit that precedes a new tag.

### Proven on a real machine

- Windows, 2026-11-23: 3 HKCU registry items applied and reverted through the GUI API on an Insider build (26300). Round trip exact, including removal of a key the run created. Elevation relaunch and per-user registry redirect worked.

### Proven only in CI (throwaway targets)

- Windows: service and task disable/revert; elevated `-Apply` of a fixture item.
- Linux: apt remove/reinstall, systemd disable/re-enable, `/etc` key=value.
- macOS: `defaults` write/restore/delete.

### Unproven

- Any shipped catalog item other than the 3 above, on any OS.
- Appx removal, policies, optional features on Windows; creating a new restore point (the test reused one under 24 hours old).
- Apply/Revert dialogs clicked in the GUI page (only its API was exercised).
- Linux unit names outside Ubuntu 24.04; any macOS key on macOS 27.

## Next steps

1. Apply the safe profile in Windows 10 and 11 VMs (Hyper-V), then an Ubuntu VM. Biggest gap.
2. Double-click launcher (`Start-Gui.cmd`) for non-technical Windows users.
3. Screenshots in README.
4. GitHub Releases with notes instead of bare tags.
5. Confirm three Windows tool credits: RemoveWindowsAI (repo 404, read via mirror), win-ai-tools, Window-Debloat-Agent.

## Layout

```
AGENTS.md (CLAUDE.md, GEMINI.md import it)   public agent contract
PROMPT.md                                    paste-in prompts per OS
catalog/items.json, items.schema.json        Windows
catalog/linux.json, macos.json, unix.schema.json
scripts/Invoke-Debloat.ps1, Test-State.ps1, modules/*.psm1   Windows engine
scripts/winnow.py                            Linux/macOS engine (stdlib only)
scripts/Start-Gui.ps1, winnow_gui.py, gui/index.html         GUI
tests/*.Tests.ps1                            Pester 5 (Windows)
tests/test_*.py, integration.sh              unittest + real apply/revert on throwaway targets
research/                                    findings per track, synthesis, sources, tool credits
.github/workflows/test.yml                   windows-latest, ubuntu-latest, ubuntu-22.04, macos-latest
```

## Key decisions

| Decision | Why |
|---|---|
| Catalogs are the only identifier lists; tests fail if an engine hardcodes one | Agents must not improvise removals; one place to review |
| Plan file is a ceiling, not an exact match | An elevated run sees all-user/provisioned apps the unelevated dry run could not |
| Refuse on domain/Entra/MDM machines and with a restart pending | Those settings belong to an administrator; pending servicing makes state unreliable |
| MDM detection uses `DiscoveryServiceFullURL` in `HKLM\SOFTWARE\Microsoft\Enrollments` | Every Windows install has built-in enrollment entries with a `ProviderID`; using that gave a false positive |
| Linux distro match is exact (`ID` only, not `ID_LIKE`) | Mint/Pop!_OS defaults were not verified |
| Package removal is simulated first and refused if anything else would go | Same package is a soft dependency on Ubuntu but pulls metapackages on Debian |
| Remove, never purge; never autoremove | Reinstall restores behaviour |
| `firefox-snap`, `snap-store`, `snapd` are never-default | No profile may remove the default browser or the only GUI installer |
| No Apple background agents offered on macOS | `launchctl disable` on them needs SIP off and breaks AirDrop, Messages, Touch ID |
| Apple Intelligence not in catalog | Its preference key is named after the account id and changes |
| GUI is a thin front end; agents must not start it | No new way to change the system; the Apply button is the user's |
| GUI: loopback, per-session token, Host and Origin checks, only its own plan/log file names | Any web page could otherwise POST to a localhost server |

## Gotchas

- Do not run `-Apply` on the maintainer's main PC without an explicit, per-test ask.
- Windows scripts must stay ASCII and PowerShell 5.1 compatible: no ternary, `??`, `&&`; `ConvertFrom-Json` gives PSCustomObject (use `Get-Prop`/`Get-Field`).
- Local Pester 5: the system has Pester 3.4.0 and no NuGet provider. Download the Pester nupkg from PSGallery, expand it, import `Pester.psd1` by path.
- In Pester tests that spawn `powershell.exe`, set `$ErrorActionPreference = 'Continue'` around the call or child stderr fails the test (passed locally, failed in CI).
- Linux/macOS cannot be tested on the Windows dev box: push a branch, open a PR, let CI run.
- Research subagents cannot write `.md` report files: have them write `.txt`, then rename.
- The catalogs were generated once by scratch scripts that are not in the repo. Edit the JSON by hand.
