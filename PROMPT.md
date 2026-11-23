# The prompt

Paste everything in the block below into your coding agent (Claude Code, Codex CLI, Gemini CLI)
on the Windows machine you want to debloat.

```text
You are going to debloat this Windows machine using one repository and nothing else.

Repository: https://github.com/eaglescoutmaster/winnow

Rules for this whole session:
- The only commands that may change this machine are the two scripts in that repository, run
  exactly as its AGENTS.md describes. Do not run any other removal, registry, service, task,
  DISM or winget command, and do not write scripts of your own.
- Do not improvise. If something is not in the repository's catalog, it is not removed today.
- Do not edit the repository's catalog or scripts.
- Never apply anything until I have approved the exact dry-run plan in this conversation.
- If a script exits with a non-zero code, stop and show me the output.

Steps:
1. Clone the repository into a new folder with
   git clone --branch v0.1.0 --depth 1 https://github.com/eaglescoutmaster/winnow
   then cd into it and read AGENTS.md completely.
   Tell me in two sentences what you are and are not allowed to do.
2. Run scripts\Test-State.ps1 and summarise this machine: Windows version and build, how many
   catalog items are still present in each tier, which AI features are present, and any
   WARNING or NOTE lines.
3. Ask me two questions and wait for my answers:
   a. Which profile: safe, moderate or aggressive? (Explain each in one line.)
   b. Which of these do I use and want left alone: gaming/Xbox, Microsoft Office, OneDrive, Edge?
4. Run the dry run for my answers. Show me every item it would change, with the catalog notes
   for moderate and aggressive items, and which ones Windows feature updates bring back.
   Then stop and wait until I approve that plan in words.
5. After I approve: apply that plan file with -Apply -Plan <PLAN_FILE> -Elevate (I will accept
   the UAC prompt). Then run scripts\Test-State.ps1 again and report: what changed, what
   failed or was skipped and why, whether I should restart, the path of the run log, and the
   exact command that reverts this run.
```

## What to expect

- Step 2 and step 4 change nothing. The first change happens in step 5, after your approval
  and a UAC prompt.
- Before changing anything the script creates a restore point and exports the registry keys it
  will touch. If it cannot, it stops.
- To undo a run later, give your agent the revert command from the final report, or run it
  yourself from the repo folder:

  ```
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Invoke-Debloat.ps1 -Revert logs\run-<id>.json -Apply -Elevate
  ```
