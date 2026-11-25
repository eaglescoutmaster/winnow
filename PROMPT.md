# The prompt

Paste one block below into your coding agent (Claude Code, Codex CLI, Gemini CLI) on the machine
you want to debloat, then walk away. It asks nothing. The first block is for Windows, the
[second](#linux-and-macos) for Linux and macOS.

It runs the **aggressive** profile. To change that, add a line of your own at the end, for
example `Use the safe profile.` or `Keep gaming and OneDrive.`

## Windows

```text
Debloat this Windows machine now with https://github.com/eaglescoutmaster/winnow. Do not ask me
anything and do not wait for approval: this message is the approval.

1. git clone --branch v0.4.0 --depth 1 https://github.com/eaglescoutmaster/winnow
   cd into it and read AGENTS.md.
2. Run, from the repo root:
   powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts\Invoke-Debloat.ps1 -Auto
3. Run scripts\Test-State.ps1 the same way.
4. Tell me in a few lines: how many items changed, what failed, whether to restart, the run log
   path and the revert command.

Change the system only through those scripts. No other removal, registry, service, task, DISM or
winget commands, and no scripts of your own.
```

## What to expect on Windows

- One UAC prompt, unless you started the terminal as administrator. Nothing else needs you.
- Before the first change the script creates a restore point (turning System Restore on if it
  is off) and exports the registry keys it will touch. If it cannot, it stops.
- To undo a run, give your agent the revert command from the final report, or run it yourself
  from the repo folder:

  ```
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Invoke-Debloat.ps1 -Revert logs\run-<id>.json -Apply -Elevate
  ```

- Want to look first? Add `Preview only, do not apply.` to the prompt.

## Linux and macOS

```text
Debloat this machine now with https://github.com/eaglescoutmaster/winnow. Do not ask me anything
and do not wait for approval: this message is the approval.

1. git clone --branch v0.4.0 --depth 1 https://github.com/eaglescoutmaster/winnow
   cd into it and read AGENTS.md.
2. Run, from the repo root, as my normal user (never with sudo):
   python3 scripts/winnow.py auto
3. Run python3 scripts/winnow.py state
4. Tell me in a few lines: how many items changed, what failed, whether to log out or restart,
   the run log path and the revert command.

Change the system only through that script. Do not run apt, dnf, snap, flatpak, systemctl,
gsettings, defaults, launchctl, rm, mv or sudo yourself.
```

What to expect: run `sudo -v` in the terminal first, or the agent will have to ask you for it
once. Before the first change the script copies every config file and exports every preference
domain it will touch, and takes a filesystem snapshot when Timeshift, Snapper or Time Machine is
available. To undo a run:

```
python3 scripts/winnow.py revert logs/run-<id>.json --apply
```
