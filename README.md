# Winnow

*To winnow: to blow the chaff away and keep the grain.* OS debloat for Windows, Linux and
macOS, runnable by a coding agent.

Sourced catalogs of preinstalled bloat, telemetry and nags, plus small engines that remove
them reversibly. It is built to be driven by an API-backed coding agent (Claude Code, Codex
CLI, Gemini CLI): you paste one prompt and walk away. The agent runs the aggressive profile,
asks nothing, and reports when it is done. Every run can be reverted from its log.

| OS | Targets | Catalog | Engine |
|---|---|---|---|
| Windows | 10 22H2 (19045); 11 23H2 (22631), 24H2 (26100), 25H2 (26200) | [catalog/items.json](catalog/items.json) | PowerShell 5.1, `scripts\Invoke-Debloat.ps1` |
| Linux | Ubuntu 22.04+, Debian 12+, Fedora Workstation (GNOME desktop installs) | [catalog/linux.json](catalog/linux.json) | Python 3, `scripts/winnow.py` |
| macOS | 14 Sonoma and later | [catalog/macos.json](catalog/macos.json) | Python 3, `scripts/winnow.py` |

> **Disclaimer.** This changes system settings and removes apps. It has automated tests for
> its catalogs and dry-run logic, and CI runs real change-and-revert cycles on throwaway
> targets on Windows, Ubuntu and macOS runners, but the shipped catalogs have **not** been
> applied on a range of real machines yet. The Linux and macOS catalogs are newer and less
> proven than the Windows one. Use it on a machine you can afford to repair and keep the run
> log; it is what the revert uses. No warranty; see [LICENSE](LICENSE).

## Quick start

1. Open your coding agent in a terminal on the machine.
2. Paste the prompt for your OS from [PROMPT.md](PROMPT.md).
3. Walk away. On Windows, accept the one UAC prompt (or start the terminal as administrator
   and there is none).

The default is the `aggressive` profile with nothing kept. To change that, add a line to the
prompt, such as `Use the safe profile.` or `Keep gaming and OneDrive.`

The agent's rules are in [AGENTS.md](AGENTS.md). It may run the repo's scripts and nothing else.

## GUI

Prefer clicking to prompting? Start the local page and your browser opens on it:

```shell
# Windows
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Start-Gui.ps1
# Linux, macOS (as your normal user; run `sudo -v` first if you plan to apply)
python3 scripts/winnow_gui.py
```

It shows what the catalog found on this machine, lets you tick items (presets for safe,
moderate, aggressive; "keep" chips for things you use), previews the plan as a dry run, applies
it after you confirm, and lists past runs with a Revert button. Protected (`never-default`)
items stay locked until you open their notes and unlock them one by one.

The GUI is a thin front end: it runs the same scripts with the same guards, backups and logs,
and adds no way to change the system that the command line lacks. The server listens on
loopback only, every request needs the one-time token in the URL it prints, requests from other
origins are refused, and it accepts only plan and log files it wrote itself. No dependencies
and nothing is fetched from the network. Stop it with Quit or Ctrl+C.

## Without an agent: Windows

From the repo root, in Windows PowerShell 5.1:

```powershell
# 1. What is on this machine? (read-only)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Test-State.ps1

# 2. One shot: apply the aggressive profile now (one UAC prompt)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Invoke-Debloat.ps1 -Auto

# 2b. Or look first: plan (read-only, prints PLAN_FILE=...), then apply exactly that plan
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Invoke-Debloat.ps1 -Profile safe -Exclude gaming,office
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Invoke-Debloat.ps1 -Apply -Plan logs\plan-<id>.json -Elevate

# 4. Undo a run
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Invoke-Debloat.ps1 -Revert logs\run-<id>.json -Apply -Elevate
```

| Parameter | Meaning |
|---|---|
| `-Auto` | One shot: apply now. Same as `-Apply -Elevate -EnableSystemRestore -AllowUntestedBuild`. |
| `-Profile safe\|moderate\|aggressive` | Cumulative tiers. Default `aggressive`. |
| `-DryRun` | The default without `-Auto` or `-Apply`: nothing changes. |
| `-Apply` | Make changes. Needs elevation, a restore point and a registry export, or it stops. |
| `-Plan <file>` | Apply only what that dry-run plan listed. |
| `-Only <ids>` | Act on named catalog items only. The only way to touch `never-default` items. |
| `-Exclude <tags>` | Leave alone: `gaming`, `office`, `onedrive`, `edge`. |
| `-Revert <log>` | Undo a run from its log (dry run unless `-Apply`). |
| `-Elevate` | Relaunch elevated for `-Apply`. |
| `-EnableSystemRestore` | Turn System Restore on for the system drive first (it is off by default on Windows 11). |
| `-AllowUntestedBuild` | Allow `-Apply` on a Windows build the catalog was not written for. |

Exit codes: `0` ok, `1` unexpected error, `2` precondition failed (nothing changed), `3` finished with failures, `4` invalid input or catalog.

## Without an agent: Linux and macOS

Needs `python3` (3.8+; on macOS it comes with the Command Line Tools: `xcode-select --install`).
Run as your normal user, never with `sudo`; the script calls `sudo` itself for the single
commands that need it, so run `sudo -v` first.

```sh
python3 scripts/winnow.py state                                  # read-only report
python3 scripts/winnow.py auto                                   # one shot: aggressive profile, plan and apply
python3 scripts/winnow.py plan --profile safe --exclude media    # or look first: dry run, prints PLAN_FILE=...
python3 scripts/winnow.py apply --plan logs/plan-<id>.json       # apply exactly that plan
python3 scripts/winnow.py revert logs/run-<id>.json --apply      # undo a run
```

What it can do, and nothing else:

| OS | Operation | Undo |
|---|---|---|
| Linux | Remove a package with apt, dnf, snap or flatpak (never purge) | Reinstall |
| Linux | Disable and stop a systemd unit | Restore logged enablement, restart |
| Linux | Set a GNOME `gsettings` key | Restore logged value |
| Linux | Set `KEY=value` in a file under `/etc` | Restore logged line |
| macOS | `defaults write` a preference | Restore logged value, or delete the key |
| macOS | Move an app in `/Applications` to the Trash | Move it back, or App Store link |
| macOS | `launchctl disable` a service | `launchctl enable` |

Guards: a package is skipped (`skip:blocked`) when the package manager says removing it would
also remove anything else; protected packages, units, services and preference domains are
listed in each catalog and cannot be reached by any profile; it stops on Macs enrolled in
device management; it never disables SIP, never touches `/System`, and offers none of Apple's
own background agents. Before the first change it backs up every file and preference domain
it will touch and takes a filesystem snapshot (Timeshift or Snapper; a Time Machine local
snapshot on macOS). With no snapshot tool it stops unless you pass `--no-snapshot`.

## What it does and does not do (Windows)

Does, all driven by [catalog/items.json](catalog/items.json):

- Removes preinstalled Store apps (installed copies and the provisioned package).
- Sets documented policies and settings for Copilot and other AI features, Widgets, telemetry,
  ads and suggestions, Start web search, Edge and OneDrive nags.
- Disables (never deletes) telemetry scheduled tasks and a few services.

Never does:

- Remove CBS/servicing packages, delete files under Windows, or touch Windows Update, Defender,
  the Store, WebView2, .NET, app frameworks, Windows Hello or BitLocker.
- Remove system-signed, non-removable or framework packages, whatever the catalog says.
- Install a scheduled task to re-apply itself. After a feature update, run it again.
- Change a machine managed by an organisation (domain-joined, Entra-joined or MDM-enrolled), or
  one with a restart pending.

## Safety model

- Nothing changes without `-Auto`/`auto` or `-Apply`/`apply`. A preview writes a plan file that records exactly what was shown.
- Before the first change: a verified restore point and a `.reg` export of every key the run touches.
- Each change is logged with its prior state in `logs\run-<id>.json` before the next one starts.
- Idempotent: re-running skips what is already done.
- Revert restores registry values, service start types and task states exactly. Removed apps are
  re-registered or reinstalled from the Microsoft Store where possible; otherwise the revert
  output tells you which ones to reinstall by hand.

## Layout

```
AGENTS.md  CLAUDE.md  GEMINI.md   agent rules (the last two import AGENTS.md)
PROMPT.md                         the one-paste prompt
catalog/items.json                Windows: id, category, tier, detect, remove, revert, builds, sources
catalog/items.schema.json         JSON Schema (draft-07) for the Windows catalog
catalog/linux.json, macos.json    Linux and macOS catalogs
catalog/unix.schema.json          JSON Schema (draft-07) for those two
scripts/Invoke-Debloat.ps1        Windows entry point
scripts/Test-State.ps1            Windows read-only state report
scripts/modules/*.psm1            Common, Appx, Services, Tasks, Registry, Policies, AI-Features
scripts/winnow.py                 Linux and macOS engine (standard library only)
scripts/Start-Gui.ps1             GUI server for Windows
scripts/winnow_gui.py             GUI server for Linux and macOS
gui/index.html                    the GUI page (one file, no dependencies)
tests/                            Pester 5 tests (Windows), unittest + integration.sh (Linux, macOS)
research/                         findings per track, synthesis, sources, tools comparison
logs/                             plans, run logs, registry exports (gitignored)
```

## Tests

```powershell
Invoke-Pester -Path tests                              # Windows, Pester 5
python3 -m unittest discover -s tests -p "test_*.py"   # Linux/macOS engine; runs on any OS
```

On your machine, tests never pass `-Apply` from an elevated session. The registry round-trip
test writes only under `HKCU\Software\WinDebloatKitTest` and removes it. `tests\Elevated.Tests.ps1`
(real service and task disable/revert on throwaway objects, plus an elevated `-Apply` of a
fixture item) runs only when elevated with `WINNOW_ELEVATED_TESTS=1`; CI sets that on a
disposable runner.

The Python unit tests send every command to a fake shell, so they cannot change a machine.
`tests/integration.sh` does a real plan, apply and revert against throwaway targets it creates
itself; it refuses to run without `WINNOW_INTEGRATION=1` and is meant for CI or a VM.

## Editing the catalog

The catalog files are the source of truth and are edited by hand. Rules: every item needs an
`https://` source, an exact identifier, a tier, and one of the six operations. Run the tests;
they check the schema, uniqueness, that no profile reaches a protected identifier, and that no
identifier is hardcoded in `scripts/`. `.claude/settings.json` is a permission allowlist for
Claude Code that asks before any `-Apply`.

## Credits

Original code. Existing tools were studied for techniques and for known breakages, and are
credited in [research/tools-comparison.md](research/tools-comparison.md). No code was copied.
Every catalog item cites its sources; see [research/sources.md](research/sources.md).

## License

MIT.
