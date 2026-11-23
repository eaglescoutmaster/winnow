# Winnow

*To winnow: to blow the chaff away and keep the grain.* Windows debloat, runnable by a coding agent.

A sourced catalog of Windows 10/11 bloat plus a small PowerShell engine that removes it
reversibly. It is built to be driven by an API-backed coding agent (Claude Code, Codex CLI,
Gemini CLI): you paste one prompt, the agent inspects your machine, shows you a plan, and
applies it only after you approve.

Targets: Windows 10 22H2 (19045) and Windows 11 23H2 (22631), 24H2 (26100), 25H2 (26200).

> **Disclaimer.** This changes system settings and removes apps. It has automated tests for
> its catalog, dry-run and registry logic, but the apply path has **not** been exercised on a
> range of real machines yet. Use it on a machine you can afford to repair, keep the run log,
> and read the plan before approving it. No warranty; see [LICENSE](LICENSE).

## Quick start

1. Open your coding agent in a terminal on the Windows machine.
2. Paste the prompt from [PROMPT.md](PROMPT.md).
3. Answer its two questions (profile, exclusions), read the plan, approve or not.

The agent's rules are in [AGENTS.md](AGENTS.md). It may run two scripts and nothing else.

## Without an agent

From the repo root, in Windows PowerShell 5.1:

```powershell
# 1. What is on this machine? (read-only)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Test-State.ps1

# 2. Plan (read-only; this is the default mode). Prints PLAN_FILE=...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Invoke-Debloat.ps1 -Profile safe -Exclude gaming,office

# 3. Apply exactly that plan (UAC prompt)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Invoke-Debloat.ps1 -Apply -Plan logs\plan-<id>.json -Elevate

# 4. Undo a run
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Invoke-Debloat.ps1 -Revert logs\run-<id>.json -Apply -Elevate
```

| Parameter | Meaning |
|---|---|
| `-Profile safe\|moderate\|aggressive` | Cumulative tiers. Default `safe`. |
| `-DryRun` | The default. Nothing changes without `-Apply`. |
| `-Apply` | Make changes. Needs elevation, a restore point and a registry export, or it stops. |
| `-Plan <file>` | Apply only what that dry-run plan listed. |
| `-Only <ids>` | Act on named catalog items only. The only way to touch `never-default` items. |
| `-Exclude <tags>` | Leave alone: `gaming`, `office`, `onedrive`, `edge`. |
| `-Revert <log>` | Undo a run from its log (dry run unless `-Apply`). |
| `-Elevate` | Relaunch elevated for `-Apply`. |
| `-EnableSystemRestore` | Turn System Restore on for the system drive first (it is off by default on Windows 11). |
| `-AllowUntestedBuild` | Allow `-Apply` on a Windows build the catalog was not written for. |

Exit codes: `0` ok, `1` unexpected error, `2` precondition failed (nothing changed), `3` finished with failures, `4` invalid input or catalog.

## What it does and does not do

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
- Change a domain-joined machine.

## Safety model

- Dry run by default; a plan file records exactly what was shown to you.
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
catalog/items.json                every item: id, category, tier, detect, remove, revert, builds, sources
catalog/items.schema.json         JSON Schema (draft-07) for the catalog
scripts/Invoke-Debloat.ps1        entry point
scripts/Test-State.ps1            read-only state report
scripts/modules/*.psm1            Common, Appx, Services, Tasks, Registry, Policies, AI-Features
tests/                            Pester 5 tests
research/                         findings per track, synthesis, sources, tools comparison
logs/                             plans, run logs, registry exports (gitignored)
```

## Tests

```powershell
Invoke-Pester -Path tests      # Pester 5
```

Tests never pass `-Apply` from an elevated session. The registry round-trip test writes only
under `HKCU\Software\WinDebloatKitTest` and removes it.

## Credits

Original code. Existing tools were studied for techniques and for known breakages, and are
credited in [research/tools-comparison.md](research/tools-comparison.md). No code was copied.
Every catalog item cites its sources; see [research/sources.md](research/sources.md).

## License

MIT.
