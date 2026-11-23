# 04 - Agent-runnable design conventions

Research track 4 of 4. Compiled 2026-11-23. Research only; no scripts.

## How to read this file

Every claim carries a confidence tag and a source URL.

| Tag | Meaning |
|-----|---------|
| **[V]** | Verified: the cited page was fetched and read during this session (2026-11-23). |
| **[S]** | Search-level: taken from a search-engine summary of the cited page; the page itself was not read in full. Re-check before relying on it. |
| **[U]** | Unverified: from prior knowledge or inference. A pointer URL is given where one exists, but it was not read this session. |

Things that changed in 2026, or where sources conflict, are collected in section 5 ("Volatile facts").

---

## 1. Instruction files

### 1.1 AGENTS.md (the cross-tool convention)

- AGENTS.md is "a simple, open format for guiding coding agents", described as "a README for agents". Plain Markdown, no required fields. **[V]** https://agents.md/
- It is "now stewarded by the Agentic AI Foundation under the Linux Foundation". **[V]** https://agents.md/
- Tools listed on the site as supporting it include Codex (OpenAI), Gemini CLI (Google), Jules, Cursor, Aider, Zed, VS Code, GitHub Copilot coding agent, Devin, Windsurf, Amp, goose, opencode, Factory, RooCode, Kilo Code, Junie, Warp and others. Claude Code is not in the list returned by the page fetch, although Claude Code now reads the file (see 1.2). **[V]** https://agents.md/
- Precedence per the site FAQ: "The closest AGENTS.md to the edited file wins; explicit user chat prompts override everything." **[V]** https://agents.md/
- The site's own migration advice uses a symlink (`mv AGENT.md AGENTS.md && ln -s AGENTS.md AGENT.md`). That advice is POSIX-centric and should not be copied for a Windows-first repo (see 1.6). **[V]** https://agents.md/
- For Gemini CLI the site says to set `{ "context": { "fileName": "AGENTS.md" } }` in `.gemini/settings.json`; for Aider, `read: AGENTS.md` in `.aider.conf.yml`. **[V]** https://agents.md/

### 1.2 Claude Code: CLAUDE.md, imports, and native AGENTS.md

- Project instructions load from `./CLAUDE.md` or `./.claude/CLAUDE.md`; user instructions from `~/.claude/CLAUDE.md`; personal per-project from `./CLAUDE.local.md`. Files in the directory hierarchy above the working directory load at launch; subdirectory files load on demand. **[V]** https://code.claude.com/docs/en/memory
- Discovered files are concatenated, not overridden, ordered from filesystem root down to the working directory. **[V]** https://code.claude.com/docs/en/memory
- Imports: `@path/to/import` syntax; relative paths resolve relative to the importing file; recursive imports allowed "with a maximum depth of four hops". Imports that resolve outside the working directory trigger a one-time approval dialog. **[V]** https://code.claude.com/docs/en/memory
- Size guidance: "target under 200 lines per CLAUDE.md file"; imports organise a file but do not reduce context cost. **[V]** https://code.claude.com/docs/en/memory
- Block-level HTML comments in CLAUDE.md are stripped before injection (visible again if the file is opened with the Read tool). **[V]** https://code.claude.com/docs/en/memory
- **Native AGENTS.md (recent change):** "Claude Code can read AGENTS.md as your project instructions, so a repository already set up for other coding agents works without adding a CLAUDE.md, an import, or a setting." It "requires Claude Code v2.1.277 or later". **[V]** https://code.claude.com/docs/en/memory#agents-md
- Default behaviour (`claude-md-or-agents-md`): AGENTS.md is read only when there is no `CLAUDE.md`, `.claude/CLAUDE.md` or `CLAUDE.local.md` in the working directory or above it. If a CLAUDE.md exists, only CLAUDE.md files are read unless that CLAUDE.md imports AGENTS.md. An alternative setting `claude-md-and-agents-md` loads both. **[V]** https://code.claude.com/docs/en/memory#agents-md
- Trap: a user's own `CLAUDE.local.md` in the repo counts as a CLAUDE.md and silently stops native AGENTS.md loading. **[V]** https://code.claude.com/docs/en/memory#agents-md
- Native AGENTS.md is unavailable in some sessions: built-in plugin disabled via `/plugin`; sometimes the first session after upgrading from v2.1.276 or earlier; and "Before v2.1.281, some sessions, such as those on Amazon Bedrock or with telemetry disabled, read CLAUDE.md files only." The documented fix in all those cases is to import it from a CLAUDE.md. **[V]** https://code.claude.com/docs/en/memory#agents-md
- Documented sharing pattern: a `CLAUDE.md` whose first line is `@AGENTS.md`, with Claude-specific additions below. "Keeping the import never makes Claude read AGENTS.md twice." **[V]** https://code.claude.com/docs/en/memory#agents-md
- Documented Windows guidance, verbatim: "if you or anyone who clones the repository works on Windows, use the `@AGENTS.md` import instead. Creating a symlink there needs Administrator privileges or Developer Mode, and Git checks a committed symlink out as a plain text file unless `core.symlinks` is enabled, which leaves that clone with a one-line CLAUDE.md in place of your instructions." **[V]** https://code.claude.com/docs/en/memory#agents-md
- Weak pattern to avoid: a CLAUDE.md that says in prose "read AGENTS.md" - "Claude sees AGENTS.md only if it decides to open the file." **[V]** https://code.claude.com/docs/en/memory#agents-md

### 1.3 OpenAI Codex CLI: AGENTS.md handling

- Global scope: Codex home (`~/.codex` unless `CODEX_HOME` is set); reads `AGENTS.override.md` if present, else `AGENTS.md`; first non-empty file only. **[V]** https://learn.chatgpt.com/docs/agent-configuration/agents-md (redirect target of https://developers.openai.com/codex/guides/agents-md)
- Project scope: starts at the project root (typically the Git root) and walks down to the current directory; per directory checks `AGENTS.override.md`, then `AGENTS.md`, then any `project_doc_fallback_filenames`; at most one file per directory. "If Codex cannot find a project root, it only checks the current directory." **[V]** same URL
- Merge: concatenated root-downward; "Files closer to your current directory override earlier guidance because they appear later in the combined prompt." **[V]** same URL
- Size cap: loading stops when combined size reaches `project_doc_max_bytes`, "32 KiB by default". **[V]** same URL
- Verification command given by the docs: `codex --ask-for-approval never "Summarize the current instructions."` **[V]** same URL
- Note: OpenAI's Codex docs now redirect from developers.openai.com/codex/... to learn.chatgpt.com/docs/.... Old deep links still resolve via 308. **[V]** (observed redirects this session)

### 1.4 Gemini CLI: GEMINI.md and context.fileName

- Default context file is `GEMINI.md`. Load order: global `~/.gemini/GEMINI.md`; then workspace directories and their parents; then just-in-time discovery when a tool touches a directory. All found files are concatenated and sent with every prompt. **[V]** https://geminicli.com/docs/cli/gemini-md/
- `context.fileName` in `settings.json` accepts a string or a list, e.g. `{"context": {"fileName": ["AGENTS.md", "CONTEXT.md", "GEMINI.md"]}}`. **[V]** https://geminicli.com/docs/cli/gemini-md/
- Imports: `@path` inside a GEMINI.md pulls in another file; relative and absolute paths supported (`@./components/instructions.md`). **[V]** https://geminicli.com/docs/cli/gemini-md/
- `/memory show` prints the concatenated context; `/memory reload` rescans. **[V]** https://geminicli.com/docs/cli/gemini-md/
- **Product status (changed 2026):** the Gemini CLI docs carry a banner: "Gemini CLI was replaced by Antigravity CLI on June 18th, 2026" for unpaid-tier and Google One users. **[V]** https://geminicli.com/docs/reference/policy-engine/ Google announced the transition on 2026-05-19; Gemini CLI "will remain accessible via paid Gemini and Gemini Enterprise Agent Platform API keys". **[S]** https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/
- Successor (Antigravity CLI, `agy`) reads `AGENTS.md` or `GEMINI.md` (and `.agents/rules/*.md`) from the workspace folder and parents up to the repository root; rules are cumulative; files over 24,000 bytes are truncated; it does not load rules from subfolders below the workspace folder. **[V]** https://antigravity.google/docs/rules.md
- Folder trust interaction: in an untrusted folder Gemini CLI "will not load the .gemini/settings.json file from the project", so a repo-supplied `context.fileName` cannot be relied on. Sources conflict on whether folder trust is enabled by default. **[S]** https://geminicli.com/docs/cli/trusted-folders/ , https://github.com/google-gemini/gemini-cli/pull/30406

### 1.5 Summary matrix

| Tool | Native file | Reads AGENTS.md natively? | Import syntax | Size limit |
|------|-------------|---------------------------|---------------|-----------|
| Codex CLI | AGENTS.md | Yes | none documented | 32 KiB combined (default) |
| Claude Code | CLAUDE.md | Yes from v2.1.277, only if no CLAUDE.md exists; some sessions cannot | `@path` (4 hops) | advice: under 200 lines |
| Gemini CLI | GEMINI.md | Only via `context.fileName` setting | `@path` | none stated |
| Antigravity CLI | AGENTS.md or GEMINI.md | Yes | `@[label](path)` includes mentioned | 24,000 bytes per file |

Sources: rows as cited in 1.2 to 1.4.

### 1.6 Serving all three from one repo: copy vs symlink vs import

- **Symlink: reject.** Git for Windows disables symlink support by default; without `core.symlinks=true` plus Developer Mode or elevation, a committed symlink checks out as a small text file containing the target path. **[S]** https://gitforwindows.org/symbolic-links , https://github.com/git-for-windows/git/wiki/symbolic-links . Claude Code's own docs say the same and tell Windows users to use the import instead (quoted in 1.2). **[V]** This repo's whole audience is on Windows, so a symlinked CLAUDE.md would degrade to a one-line file for most users.
- **Copy: reject as primary.** Three full copies drift. Only acceptable if generated and checked by a test; unnecessary given imports.
- **Import: adopt.** `AGENTS.md` is the single canonical file. `CLAUDE.md` contains exactly `@AGENTS.md` (documented pattern, never double-loads). `GEMINI.md` contains exactly `@./AGENTS.md` (documented Gemini import syntax). Codex and Antigravity read `AGENTS.md` directly.
- **Do not also set `context.fileName` to include AGENTS.md in a committed `.gemini/settings.json`.** Combined with a GEMINI.md that imports AGENTS.md it risks loading the content twice, and project settings are ignored in untrusted folders anyway. Whether Gemini de-duplicates is not documented. **[U]**
- **Budget:** keep AGENTS.md under 200 lines and under 24,000 bytes so it fits every tool's limit (Claude advice 200 lines, Antigravity 24,000-byte truncation, Codex 32 KiB). Sources as in 1.5.
- **Windows-only `core.symlinks` gotcha does not apply** once no symlinks are committed; add a test that fails if any tracked file has git mode 120000. **[U]** (design inference)

---

## 2. Structuring scripts so an agent runs them deterministically

### 2.1 Single entry point, closed parameter sets

- One script (for example `debloat.ps1`) with a mandatory `-Action` constrained by `[ValidateSet()]` so that an invalid verb fails at parameter binding instead of being improvised around. ValidateSet reference: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters **[U]** (page not re-read)
- Constraints that `powershell.exe -File` imposes on the parameter design **[V]** https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_powershell_exe?view=powershell-5.1 :
  - "The File parameter can't support scripts using a parameter that expects an array of argument values." Consequence: selections (profile names, catalog item IDs) must travel in a file, not as an array argument.
  - "It isn't possible to pass an explicit boolean value for a switch parameter when running a script in this way" (5.1). Consequence: use plain switches or string enums, never `-Flag:$false`.
  - "File must be the last parameter in the command."
- Catalog item IDs should be validated against the catalog, never interpolated into commands. **[U]** (design inference)

### 2.2 Machine-readable output and stable exit codes

- Invoke with `-File`, not `-Command`. With `-File`, "When the script file terminates with an exit command, the process exit code is set to the numeric argument used with the exit command"; a script-terminating error gives `1`. With `-Command`, any exit code other than 0 or 1 "is converted to 1". **[V]** https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_powershell_exe?view=powershell-5.1
- Reserve `1` for "unhandled engine error" since PowerShell itself emits it; give every expected outcome its own code (example table in Recommendations). **[U]** (design inference from the above)
- Prefer a result file over parsing stdout. Reasons: an elevated child's stdout cannot be captured at all (section 3.3), and when Windows PowerShell is launched from another process its non-output streams also land on stdout, so stray warnings can corrupt a JSON stream. **[U]** https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_output_streams (not re-read)
- Always pass `-Depth` to `ConvertTo-Json`; the default depth truncates nested objects. **[U]** https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertto-json (not re-read)
- Encoding: Windows PowerShell 5.1 file-writing defaults differ by cmdlet and can add a BOM, which breaks byte-level hashing. Write plan and result files with an explicit UTF-8 no-BOM .NET call. **[U]** https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_character_encoding (not re-read)

### 2.3 Non-interactive operation

- `-NonInteractive`: "Any attempts to use interactive features, like Read-Host or confirmation prompts, result in statement terminating errors rather than hanging." **[V]** https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_powershell_exe?view=powershell-5.1
- `-NoProfile`: "Doesn't load the PowerShell profile." Required so user profiles cannot alter engine behaviour or output. **[V]** same URL
- No `Read-Host`, no `Get-Credential`, no `Out-GridView`, no `pause` anywhere in the engine. Pass `-Confirm:$false` explicitly to cmdlets that may prompt, because under `-NonInteractive` a prompt becomes an error. **[V]** (follows from the quote above) / ShouldProcess background: https://learn.microsoft.com/powershell/scripting/learn/deep-dives/everything-about-shouldprocess **[S]**
- The human approval step therefore lives in the agent conversation (and in the UAC prompt), not in the script.

### 2.4 Idempotency

- Each catalog action needs a `detect` step and an `apply` step; `apply` is skipped when `detect` reports the desired state. A second run of the same plan must produce zero changes and exit with the "nothing to do" code. **[U]** (design principle; no single authoritative source)

### 2.5 Plan files with a hash

- Model: Terraform's saved plan. `terraform plan -out=FILE` writes a plan and `terraform apply FILE` executes exactly that plan without re-planning; Terraform refuses a saved plan that is stale against current state. **[U]** https://developer.hashicorp.com/terraform/cli/commands/plan , https://developer.hashicorp.com/terraform/cli/commands/apply (not re-read)
- Applied here: `plan` writes `plan-<id>.json` and prints its SHA-256. `apply` requires both `-PlanPath` and `-PlanHash`, recomputes the hash over the file bytes, and refuses on mismatch. The plan embeds the catalog hash, engine version, machine identifier, OS build, and creation time so a plan cannot be replayed on another machine or after the catalog changed. `Get-FileHash` reference: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-filehash **[U]** (not re-read; design is inference)
- The hash is the thing the human approves in chat. It also closes the time-of-check/time-of-use gap between an unelevated planner and an elevated applier, because the hash crosses the elevation boundary on the command line while the plan file sits in a user-writable directory. **[U]** (design inference)

### 2.6 Allowlist-based permission configs

**Claude Code** **[V]** https://code.claude.com/docs/en/permissions

- Rules live in `permissions.allow` / `ask` / `deny`. "Rules are evaluated in order: deny, then ask, then allow. The first match in that order determines the outcome, and rule specificity doesn't change the order." An allow rule cannot carve an exception out of a deny or ask rule.
- There is a dedicated PowerShell tool with its own rule namespace: "PowerShell permission rules use the same shape as Bash rules"; aliases are canonicalised (`PowerShell(Get-ChildItem *)` also matches `gci`, `ls`, `dir`); matching is case-insensitive; "Claude Code parses the PowerShell AST and checks each command in a compound command independently."
- On Windows both shells may be present: "Claude Code auto-detects pwsh.exe for PowerShell 7+ with a fallback to powershell.exe for PowerShell 5.1"; the Bash tool remains available when Git Bash is installed. Consequence: rules must be written for both `Bash(...)` and `PowerShell(...)`, and the engine must be launched by an explicit `powershell.exe ... -File` command so the host shell's edition does not matter. **[V]** https://code.claude.com/docs/en/tools-reference.md
- Argument-constraining patterns "are fragile", and a rule "covers the invocation Claude usually produces and isn't a security boundary around the program". Treat the allowlist as friction reduction and a guard against drift, not as containment.
- Project `permissions.allow` rules in `.claude/settings.json` "grant capability, so Claude Code applies them only after you accept the workspace trust dialog for that folder... deny and ask rules aren't affected, since they only restrict." In `claude -p` and SDK sessions the trust dialog never shows and project allow rules are not used.
- Hooks and the `env` block in a repo's settings files ARE used even before trust and in `claude -p`. A debloat repo should therefore ship no hooks at all, so a reviewer can see that nothing runs implicitly.
- Modes: `bypassPermissions` "Skips permission prompts"; docs say use only in isolated containers or VMs. `dontAsk` denies anything not pre-approved. The repo's instructions must say never to use bypass mode for this task.
- Auto mode is now the built-in starting mode for interactive terminal sessions ("a separate classifier model reviews actions instead of you"); explicit ask and deny rules still apply. An `ask` rule on the apply command is therefore the reliable way to force a human confirmation. **[V]** https://code.claude.com/docs/en/security.md

**OpenAI Codex CLI** **[V]** https://learn.chatgpt.com/docs/agent-approvals-security.md

- Two independent controls: sandbox mode (`read-only`, `workspace-write`, `danger-full-access`) and approval policy (`on-request`, `never`, `granular`). `untrusted` as an approval policy is retired and "can stop either client from starting".
- Defaults: version-controlled folders get workspace-write with on-request approvals; network access off.
- `--dangerously-bypass-approvals-and-sandbox` (alias `--yolo`) removes both; documented as not recommended.
- Windows: native sandbox with three implementations, `mxc` (recommended where supported), `elevated`, `unelevated`. In the elevated sandbox "Commands in the sandbox run without administrator privileges." Consequence: a debloat apply cannot succeed inside the Codex sandbox; it must be an explicit, human-approved escalation. **[V]** https://learn.chatgpt.com/docs/windows/windows-sandbox.md
- Command allowlists: Starlark `prefix_rule(pattern=[...], decision="allow"|"prompt"|"forbidden", justification=..., match=[...], not_match=[...])` in `rules/*.rules`; most restrictive decision wins (`forbidden` > `prompt` > `allow`); project-local `<repo>/.codex/rules/` loads only when the project `.codex/` layer is trusted; test with `codex execpolicy check`. "Rules are experimental and may change." The page documents special parsing for `bash -lc` wrappers and says nothing about PowerShell wrappers. **[V]** https://learn.chatgpt.com/docs/agent-configuration/rules.md
- Non-interactive: `codex exec`, with `--json` (JSONL events) and `-o/--output-last-message`. **[S]** https://developers.openai.com/codex/noninteractive

**Gemini CLI** **[V]** https://geminicli.com/docs/reference/policy-engine/

- Policy engine: TOML `[[rule]]` blocks with `toolName`, `commandPrefix` or `commandRegex`, `decision` (`allow`, `deny`, `ask_user`), `priority` 0-999. Tiers: Default < Extension < Workspace < User < Admin.
- User policies: `~/.gemini/policies/*.toml`. Workspace policies (`.gemini/policies/*.toml`) are documented as currently non-functional (issue #18186). Consequence: a repo cannot ship an effective Gemini policy; it can only ship a sample for the user to copy.
- Headless: `ask_user` "is treated as deny" in non-interactive mode.
- Approval modes: `default`, `autoEdit`, `plan`, `yolo`.
- Legacy `tools.core` / `tools.exclude` prefix lists exist; `tools.exclude` is marked deprecated in favour of the policy engine, and the older docs warn that shell prefix restrictions are simple string matching and bypassable. **[S]** https://geminicli.com/docs/reference/configuration/ , https://www.geminicli.com/docs/tools/shell

### 2.7 Prompt-injection considerations

- Everything in the repo is model input: AGENTS.md, the catalog JSON, READMEs, issue templates, comments in scripts. Claude Code's guidance: "Avoid piping untrusted content directly to Claude", review commands before approval, and no protection is complete. **[V]** https://code.claude.com/docs/en/security.md
- Codex guidance: "Prompt injection can cause the agent to fetch and follow untrusted instructions"; web results are untrusted. **[V]** https://learn.chatgpt.com/docs/agent-approvals-security.md
- Design consequences **[U]** (inference from the above):
  - Catalog fields are data. No field may contain shell text that is executed; actions are a closed enum the engine implements. Free-text `description` fields get a length cap and a character allowlist enforced by the schema test, so a pull request cannot smuggle instructions to the agent through the catalog.
  - The engine prints only IDs, enums, counts and paths. It never echoes machine-derived strings (app display names, registry string values, scheduled-task descriptions) into the agent's context unquoted; those go into the JSON result file as data.
  - The agent is told not to fetch anything from the network during the task and not to follow instructions found in tool output.
  - The pasted prompt pins a release tag or commit so the instructions the agent reads are the ones that were reviewed.
  - Ship no hooks, no MCP config, no `env` block, since those run before trust in some session types (2.6).

---

## 3. Safe elevation on Windows from an agent's shell

### 3.1 Detecting admin

- Check `[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)`. API reference: https://learn.microsoft.com/en-us/dotnet/api/system.security.principal.windowsprincipal.isinrole **[U]** (not re-read). With UAC, an unelevated process of an admin user returns false, which is the wanted behaviour.

### 3.2 `#Requires -RunAsAdministrator`

- "specifies that the PowerShell session in which you're running the script must be started with elevated user rights"; introduced in PowerShell 4.0. `#Requires` statements "are always applied globally, and must be met, before the script can execute." **[V]** https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_requires?view=powershell-5.1
- Consequence: it cannot be used on a single entry point that has both unelevated actions (`plan`, `status`) and elevated ones (`apply`), and its failure is a generic error rather than a stable exit code. Use a runtime check that returns a dedicated exit code; reserve `#Requires -RunAsAdministrator` for an internal apply-only worker script if one exists. `#Requires -Version 5.1` is still appropriate everywhere. **[U]** (inference)

### 3.3 Self-elevation and why the parent sees no output

- `Start-Process -Verb RunAs` uses the `UseShellExecute` parameter set. That set has `-Verb`, `-Wait`, `-PassThru`, `-WindowStyle`, `-WorkingDirectory`, `-ArgumentList`, and does **not** have `-RedirectStandardOutput`, `-RedirectStandardError`, `-RedirectStandardInput` or `-NoNewWindow` (those are in the `Default` set only). **[V]** https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process
- So the elevated child runs in a new window with its own console; nothing it writes reaches the agent's shell. Pattern: the child writes a result JSON and a log to a path passed in by the parent; the parent uses `-Wait`, then reads the file. `-Wait` "waits for the process tree (the process and all its descendants) to exit". **[V]** same URL
- Whether `-PassThru` reliably exposes the elevated child's `ExitCode` to an unelevated parent, and the exact exception thrown when the user declines the UAC prompt, were not verified. Treat the result file as the source of truth and treat "no result file" as a distinct failure. **[U]**
- A UAC consent prompt needs a human at the interactive desktop; an agent cannot answer it. Background: https://learn.microsoft.com/en-us/windows/security/application-security/application-control/user-account-control/how-it-works **[U]** (not re-read). Design consequence: tell the user in advance that a UAC prompt will appear, and treat the prompt as a second approval gate.

### 3.4 Windows `sudo`

All **[V]** https://learn.microsoft.com/en-us/windows/advanced-settings/sudo/

- Availability: "Windows 11, version 24H2 or higher". Not Windows 10.
- Off until enabled: Settings > System > Advanced > "Enable sudo".
- Three modes: `forceNewWindow` ("the default configuration option", runs the command in a new window), `disableInput` (current window, input closed), `normal` (inline). Change with `sudo config --enable <option>` from an elevated console.
- Still UAC-gated: "sudo can only be elevated via the User Account Control (UAC) security feature".
- Microsoft's own warning: `disableInput` and `normal` carry risk because "malicious processes [may] attempt to drive the elevated process"; `forceNewWindow` "is recommended unless you are familiar and comfortable with the risks".
- Consequence: the engine must not depend on `sudo` (absent on Windows 10, off by default on 11, output not captured in the default mode) and must never enable or reconfigure it.

### 3.5 gsudo

- Third-party open-source sudo for Windows; Microsoft's sudo page points to it for extra functionality. **[V]** https://learn.microsoft.com/en-us/windows/advanced-settings/sudo/
- Still shows a UAC popup per elevation unless its credentials cache is active; cache modes are `Explicit` (default), `Auto`, `Disabled`; the docs warn the cache is unsafe if a malicious process is already running. Elevation failure returns exit code 999. `gsudo status IsElevated` exists. **[S]** https://gerardog.github.io/gsudo/docs/credentials-cache , https://gerardog.github.io/gsudo/docs/usage , https://github.com/gerardog/gsudo
- Consequence: optional convenience only. Never install it, never enable its cache.

### 3.6 Administrator protection (new elevation model, in flux)

- Windows 11 "Administrator protection" issues admin tokens from a hidden, system-managed, profile-separated account and authorises each elevation with Windows Hello; auto-elevation is removed. **[S]** https://learn.microsoft.com/en-us/windows/security/application-security/application-control/administrator-protection , https://blogs.windows.com/windowsdeveloper/2025/05/19/enhance-your-application-security-with-administrator-protection/
- Rollout status conflicts between sources (see section 5).
- Design consequence **[U]** (inference, not stated by Microsoft in what was read): when the elevated process runs under a different profile, `HKCU`, `%APPDATA%`, `%TEMP%` and per-user Appx operations inside it refer to the wrong user. The same is true today when a standard user elevates with another account's credentials. The engine must therefore split every plan into a user-scope phase run unelevated and a machine-scope phase run elevated, and must never touch `HKCU` or per-user packages from the elevated phase. The parent must pass absolute paths (plan, result, log) rather than relying on environment variables in the child.

### 3.7 Execution policy

- `-ExecutionPolicy <policy>` on the command line "Sets the default execution policy for the current session and saves it in the `$Env:PSExecutionPolicyPreference` environment variable. This parameter does not change the PowerShell execution policy that's set in the registry." **[V]** https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_powershell_exe?view=powershell-5.1
- Process scope is not persisted and lasts for the process and its children; Group Policy scopes (MachinePolicy, UserPolicy) take precedence over it, so `-ExecutionPolicy Bypass` does not work on a machine where policy is enforced by GPO. **[S]** https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies
- `Unblock-File` removes the downloaded-from-internet mark from files (relevant for ZIP downloads under RemoteSigned); it modifies files on disk and persists, whereas the per-process flag changes nothing. https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/unblock-file **[U]** (not re-read)
- Consequence: use per-process `-ExecutionPolicy Bypass` on the one launch command; never call `Set-ExecutionPolicy`; do not run `Unblock-File` automatically; detect a GPO-enforced policy and stop with a dedicated exit code.

### 3.8 Windows PowerShell 5.1 vs PowerShell 7

- Removed from PowerShell 7 (`Microsoft.PowerShell.Management`): `Checkpoint-Computer`, `Enable-ComputerRestore`, `Disable-ComputerRestore`, `Get-ComputerRestorePoint` (and `Restore-Computer` **[U]**). **[V]** https://learn.microsoft.com/en-us/powershell/scripting/whats-new/differences-from-windows-powershell
- `Import-Module -UseWindowsPowerShell` "creates a proxy module in PowerShell 7 that uses a local Windows PowerShell process to implicitly run any cmdlets contained in that module." **[V]** same URL
- The compatibility layer runs a background 5.1 process (`WinPSCompatSession`) via implicit remoting and "Operates on serialized cmdlet parameters and return values, not on live objects"; modules under `%windir%\system32\WindowsPowerShell\v1.0\Modules` are loaded this way unless their manifest declares Core compatibility. **[V]** https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_windows_powershell_compatibility
- Appx specifically: Microsoft's compatibility table lists Appx as "Natively Compatible**" with the footnote "Must use Compatibility Layer with PowerShell 7.1" (page dated 2024-02). **[V]** https://learn.microsoft.com/en-us/powershell/windows/module-compatibility . Community reports say `Import-Module Appx` fails in PowerShell 7.1 through 7.4 with "Operation is not supported on this platform" and needs `-UseWindowsPowerShell`, with deserialized output and occasional further failures on Windows 11. **[S]** https://github.com/PowerShell/PowerShell/issues/13225 , https://learn.microsoft.com/zh-cn/answers/questions/1665679/poweshell7-get-appxpackage . The two sources disagree; current behaviour on pwsh 7.5/7.6 was not tested.
- Dism and ScheduledTasks are listed as natively compatible on Windows 10 1903+/1809+. **[V]** https://learn.microsoft.com/en-us/powershell/windows/module-compatibility
- Consequence: run the engine under Windows PowerShell 5.1 (`powershell.exe`), which ships with every supported Windows 10/11 and has Appx, Dism and the restore-point cmdlets as live objects. Launch it explicitly from whatever shell the agent has; do not let the agent's default shell choose the edition.

### 3.9 Restore points

- `Checkpoint-Computer`: client OS only; "cannot create more than one checkpoint each day"; "Beginning in Windows 8 ... If you try to create a new restore point before the 24-hour period has elapsed, Windows PowerShell generates the following error: 'A new system restore point cannot be created because one has already been created within the past 24 hours.'" `-RestorePointType` values include `MODIFY_SETTINGS` and `APPLICATION_UNINSTALL`. The cmdlet produces no output. **[V]** https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/checkpoint-computer?view=powershell-5.1
- Whether the throttle surfaces as a terminating error or a warning in practice was not tested. **[U]** Because the cmdlet returns nothing either way, confirm creation by comparing `Get-ComputerRestorePoint` before and after.
- Throttle control: the DWORD `SystemRestorePointCreationFrequency` under the `SystemRestore` key in HKLM; value N means skip creation if a restore point was made in the previous N minutes; 0 means never skip; the value does not exist by default. **[S]** https://learn.microsoft.com/en-us/windows/win32/sr/calling-srsetrestorepoint . The commonly cited full path is `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore`, and "1440" as the effective default appears only in third-party guides. **[U]**
- `Enable-ComputerRestore -Drive "C:\"` turns System Restore on for a drive (it is frequently off on Windows 11); 5.1 only. https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/enable-computerrestore?view=powershell-5.1 **[U]** (parameter details not re-read; removal from PS 7 is **[V]** above)
- Consequence: restore-point creation is a named, visible plan step with three recorded outcomes (created / throttled-existing-recent-point / unavailable). The engine should not silently change `SystemRestorePointCreationFrequency` or enable System Restore; each is its own opt-in catalog action with a journal entry.

---

## 4. Dry-run and plan/approve patterns

### 4.1 SupportsShouldProcess / -WhatIf

- `[CmdletBinding(SupportsShouldProcess)]` adds `-WhatIf` and `-Confirm`; the function calls `$PSCmdlet.ShouldProcess(target, action)`, which under `-WhatIf` prints a description and returns `$false`. `$WhatIfPreference` propagates to called cmdlets. `ConfirmImpact='High'` prompts when at or above `$ConfirmPreference`. **[S]** https://learn.microsoft.com/powershell/scripting/learn/deep-dives/everything-about-shouldprocess , https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/useshouldprocessforstatechangingfunctions
- Limits for agent use **[U]** (inference): `-WhatIf` output is host text, not data, and not every third-party or native command honours it (`reg.exe`, `dism.exe`, `sc.exe` do not). So `-WhatIf` is a second safety net, not the plan mechanism. The plan must be computed by the engine's own `detect` logic and emitted as JSON.
- Every state-changing engine function still declares `SupportsShouldProcess` so that a stray `-WhatIf` at the top level is honoured end to end, and PSScriptAnalyzer can enforce it.

### 4.2 Terraform-style plan/apply

- Phases: `plan` (read-only, unelevated, writes plan JSON plus hash) -> human reviews the summary the agent shows -> `apply -PlanPath -PlanHash` (executes exactly those steps, re-running `detect` per step and skipping steps already satisfied) -> `verify` (re-detect, report drift). Terraform references in 2.5. **[U]**
- A stale plan (catalog hash, OS build, or machine ID mismatch, or older than a fixed TTL) is refused with a dedicated exit code, mirroring Terraform's stale-plan refusal. **[U]**

### 4.3 Change journal for revert

- Before each mutation, append a journal record: step ID, catalog item ID, action type, target, prior state (for example registry value type and data or "absent", service start type, task enabled state, package full name and whether it stays provisioned), new state, timestamp, result. Append-only JSON Lines, one journal per apply run, stored outside the repo working tree in a per-machine data directory. **[U]** (design; no single authoritative source)
- `revert -JournalPath` replays records in reverse, using the same closed action set. Actions that cannot be undone from local state (for example removing a package whose payload is gone) are marked `reversible: false` in the catalog and shown as such in the plan summary before approval. Reversibility facts per action type belong to the other research tracks. **[U]**
- Write the journal record before the mutation and update it after, so a crash mid-apply leaves evidence of the in-flight step. **[U]**

### 4.4 Pester 5 conventions

- Two phases: Discovery then Run. Code outside `It`/`BeforeAll`/`BeforeEach`/`AfterAll`/`AfterEach` runs during Discovery; "Put all your test-code into It, BeforeAll, BeforeEach, AfterAll or AfterEach." **[S]** https://pester.dev/docs/usage/discovery-and-run
- Data-driven tests: build data in `BeforeDiscovery`, feed it with `-ForEach`; hashtable keys become variables in `It` and `BeforeAll`. Variables set in `BeforeAll` are not available to `-ForEach`. **[S]** https://pester.dev/docs/usage/data-driven-tests , https://pester.dev/docs/commands/BeforeDiscovery
- Pester 6 exists and changes phase scoping (Discovery and Run per file rather than global) and makes duplicate setup blocks an error. **[S]** https://pester.dev/docs/migrations/v5-to-v6 . Pin the Pester major version in the test runner.
- Windows PowerShell 5.1 ships an old inbox Pester (3.x) that cannot run v5 syntax; tests must import a pinned v5 explicitly. https://pester.dev/docs/introduction/installation **[U]** (not re-read)
- Mocking (`Mock`, `Should -Invoke`) and `New-PesterConfiguration` (`Run.Exit`, `TestResult`) for CI were not re-read. https://pester.dev/docs/usage/mocking , https://pester.dev/docs/usage/configuration **[U]**
- Suggested test layers **[U]** (design): (1) catalog validates against schema; (2) every catalog item generates one `-ForEach` case asserting required fields, unique ID, known action enum, reversible flag present; (3) `plan` on a mocked machine state yields a golden-file JSON; (4) `apply` with all mutating cmdlets mocked asserts each mutation is invoked exactly once and only for steps in the plan; (5) `apply` with a wrong hash exits with the hash-mismatch code and invokes zero mutations; (6) static test that no engine file contains `Read-Host`, `Invoke-Expression`, `Invoke-WebRequest` or `Set-ExecutionPolicy`.

### 4.5 JSON Schema validation in PowerShell

- `Test-Json` "was introduced in PowerShell 6.1"; it does not exist in Windows PowerShell 5.1. **[V]** https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/test-json
- "Beginning in PowerShell 7.4, Test-Json uses System.Text.Json for JSON parsing and JsonSchema.NET for schema validation", and "No longer supports Draft 4 schemas" and "Only supports strictly conformant JSON" (no comments or trailing commas unless `-Options`, added in 7.5 preview). `-Path`/`-LiteralPath` were added in 7.4; `-SchemaFile` supports `$ref` to other files. **[V]** same URL
- Options for 5.1 **[U]** (design; libraries not evaluated this session):
  1. Hand-written validator in the engine (parse with `ConvertFrom-Json`, then explicit checks for required keys, types, enums, ID uniqueness). No dependencies; runs at every `plan` and `apply`.
  2. Run real JSON Schema validation only in CI and tests, under PowerShell 7.4+ with `Test-Json -SchemaFile`.
  3. Vendor a .NET Framework-compatible schema library and load it with `Add-Type`. Adds a binary to a repo whose selling point is auditability, and licence terms vary by library; not recommended.
- Recommended combination: 1 at runtime plus 2 in CI. Write the schema in draft 2020-12 or draft-07, never draft-04, and keep the catalog strictly conformant JSON (no comments, no trailing commas) so both validators agree.
- 5.1 `ConvertFrom-Json` has no `-AsHashtable` and returns PSCustomObject; code must not assume hashtables. https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertfrom-json?view=powershell-5.1 **[U]** (not re-read)

---

## 5. Volatile facts (changed recently or sources disagree)

1. **Claude Code reads AGENTS.md natively** as of v2.1.277, but only when no CLAUDE.md exists, and not in every session type before v2.1.281. Older blog posts saying "Claude Code does not read AGENTS.md" are out of date; posts saying "it just works" overstate it. **[V]** https://code.claude.com/docs/en/memory#agents-md
2. **Claude Code starts interactive terminal sessions in auto mode** (classifier-reviewed) rather than prompting for everything. Instructions that assume "the user will be asked before every command" are wrong unless an `ask` rule forces it. **[V]** https://code.claude.com/docs/en/security.md
3. **Claude Code has a native PowerShell tool on Windows** with its own permission-rule namespace; allowlists written only as `Bash(...)` do not cover it. **[V]** https://code.claude.com/docs/en/tools-reference.md
4. **Gemini CLI was replaced by Antigravity CLI on 2026-06-18** for consumer tiers; still reachable with paid API keys. The project brief names Gemini CLI; decide whether "Gemini" support means Gemini CLI with an API key, Antigravity CLI, or both. Both read a root AGENTS.md path one way or another (1.4). **[V]/[S]** https://geminicli.com/docs/reference/policy-engine/ , https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/
5. **Gemini CLI folder-trust default** is documented inconsistently (guide says disabled, settings reference and a merged PR say enabled). **[S]** https://github.com/google-gemini/gemini-cli/pull/30406 , https://github.com/google-gemini/gemini-cli/issues/30388
6. **Gemini CLI workspace-tier policies are documented as non-functional**; the tier-number examples on the same page are internally inconsistent. **[V]** https://geminicli.com/docs/reference/policy-engine/
7. **Codex docs moved** to learn.chatgpt.com; the `untrusted` approval policy is retired; `--full-auto` and `on-failure` are not mentioned on the current approvals page (status not confirmed); Windows sandbox gained an `mxc` implementation. **[V]** https://learn.chatgpt.com/docs/agent-approvals-security.md , https://learn.chatgpt.com/docs/windows/windows-sandbox.md
8. **Codex rules are experimental** and their handling of PowerShell command lines is undocumented. **[V]** https://learn.chatgpt.com/docs/agent-configuration/rules.md
9. **Windows Administrator protection**: Microsoft Learn says it is coming "soon" and that the October 2025 release was reverted; a Message Center notice dated 2026-10-13 says it is generally available, disabled by default, and enabled by default in the Windows 11 security baselines from the October 2026 security update. Not reconciled. **[S]** https://learn.microsoft.com/en-us/windows/security/application-security/application-control/administrator-protection , https://mc.merill.net/message/MC1506291
10. **Appx in PowerShell 7**: Microsoft's table says natively compatible; community reports say it needs the compatibility layer. Not tested on 7.5/7.6. (3.8)
11. **Pester 6** is out with different phase semantics. (4.4)
12. **Test-Json dropped draft-04** in 7.4. (4.5)

---

## Recommendations for this repo

Each rule is written so a reviewer or a test can check it.

**Instruction files**

1. `AGENTS.md` at the repo root is the only file containing agent instructions. Test: it exists, is under 200 lines and under 24,000 bytes.
2. `CLAUDE.md` at the root contains exactly one non-empty line: `@AGENTS.md`. Test: byte-compare against the expected content.
3. `GEMINI.md` at the root contains exactly one non-empty line: `@./AGENTS.md`. Test: byte-compare.
4. No symlinks are committed. Test: `git ls-files -s` shows no mode `120000` entries.
5. No committed `.gemini/settings.json` sets `context.fileName`; no `AGENTS.override.md`; no nested AGENTS.md/CLAUDE.md/GEMINI.md in subdirectories. Test: file-existence checks.
6. The repo ships no hooks, no `.mcp.json`, and no `env` block in any agent settings file. Test: `.claude/settings.json`, if present, has only a `permissions` key.
7. The pasted entry prompt names a pinned release tag, tells the agent to read AGENTS.md, and lists the exact commands it may run. Test: the prompt text in README matches a fixture and contains the current tag.

**Entry point and invocation**

8. One entry script. The only documented launch form is `powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File <abs path>\debloat.ps1 -Action <verb> ...`. Test: AGENTS.md and README contain this form and no other.
9. `-Action` is `[ValidateSet('status','plan','apply','verify','revert')]` (or the final closed list). Every other parameter that has a finite domain also uses `[ValidateSet()]`. No parameter takes an array; no parameter takes a script block or command string. Test: AST inspection of the `param()` block.
10. The engine declares `#Requires -Version 5.1` and refuses to run under PowerShell Core with a dedicated exit code (`$PSVersionTable.PSEdition -ne 'Desktop'`). It does not use `#Requires -RunAsAdministrator` on the entry script. Test: static check plus a run under pwsh expecting that code.
11. Engine source contains none of: `Read-Host`, `Get-Credential`, `Out-GridView`, `pause`, `Invoke-Expression`, `Invoke-WebRequest`, `Invoke-RestMethod`, `Start-BitsTransfer`, `Set-ExecutionPolicy`, `Unblock-File`, `sudo`, `gsudo`. Test: AST/token scan.
12. Every cmdlet call that can prompt passes `-Confirm:$false`. Test: PSScriptAnalyzer custom rule or token scan over an explicit list of mutating cmdlets.

**Output contract**

13. Every action writes a result JSON file (UTF-8, no BOM, `ConvertTo-Json -Depth` set explicitly) to a path given by `-ResultPath` or a documented default, and prints exactly one final stdout line of the form `RESULT <absolute path>`. Test: run each action, assert last stdout line and that the file parses and validates against `result.schema.json`.
14. Exit codes are a documented, frozen table, for example: 0 success / no changes needed; 2 changes pending (plan non-empty); 3 invalid arguments or catalog; 4 plan hash mismatch; 5 plan stale; 6 elevation required or declined; 7 unsupported host (edition, OS, policy); 8 partial failure (some steps failed, journal written); 1 reserved for unhandled errors. Test: one Pester case per code.
15. The engine never prints machine-derived free text (display names, registry strings) to stdout; such values appear only inside the result/plan JSON. Test: run `plan` against a mock state containing an instruction-like string and assert stdout does not contain it.

**Plan / apply / revert**

16. `plan` makes no changes and needs no elevation. Test: all mutating commands mocked; `Should -Invoke ... -Times 0`.
17. `plan` writes a plan file containing: schema version, engine version, catalog SHA-256, machine ID, OS build, creation time, and an ordered list of steps (step ID, catalog item ID, action enum, target, scope `user`|`machine`, current state, desired state, reversible flag). It reports the plan file's SHA-256 in the result JSON. Test: schema validation and golden file.
18. `apply` requires `-PlanPath` and `-PlanHash`; it recomputes SHA-256 over the file bytes and exits 4 with zero mutations on mismatch; it exits 5 if the catalog hash, machine ID or OS build differs or the plan is older than the TTL. `apply` never re-plans and never accepts item IDs directly. Test: tampered-plan and stale-plan cases.
19. `apply` re-runs `detect` for each step and skips satisfied steps. Running the same plan twice yields zero mutations the second time. Test: idempotency case.
20. Every mutation is preceded by an append-only journal record holding prior state; the journal lives outside the repo tree. `revert -JournalPath` undoes in reverse order using only the closed action set. Test: apply then revert on mocked state returns to the starting state for every action with `reversible: true`.
21. Catalog items with `reversible: false` are listed separately in the plan summary and in AGENTS.md's instructions for what the agent must show the human before asking for approval. Test: plan JSON has a `nonReversible` array; AGENTS.md mentions it.
22. Every state-changing function declares `SupportsShouldProcess` and guards its mutation with `$PSCmdlet.ShouldProcess`. Test: PSScriptAnalyzer rule `PSUseShouldProcessForStateChangingFunctions` passes; `apply -WhatIf` invokes zero mutations.

**Elevation**

23. Elevation state is detected with `WindowsPrincipal.IsInRole(Administrator)` and reported in `status` output. Test: mocked true/false.
24. User-scope steps (HKCU, per-user packages) run only in the unelevated process; machine-scope steps run only in the elevated process. The elevated phase never reads or writes HKCU or user-profile paths derived from environment variables. Test: step `scope` drives dispatch; static scan of machine-scope handlers for `HKCU:` and `$env:APPDATA`/`$env:USERPROFILE`/`$env:TEMP`.
25. When machine-scope steps exist and the process is not elevated, `apply` launches one elevated child with `Start-Process -Verb RunAs -Wait`, passing absolute `-PlanPath`, `-PlanHash`, `-ResultPath` and `-LogPath`; the child re-verifies the hash; the parent reads the result file and exits 6 if the file is missing. Test: `Start-Process` mocked; argument list asserted; missing-file case.
26. AGENTS.md tells the agent: a UAC prompt will appear and only the human can answer it; do not retry elevation more than once; do not try `sudo`, `gsudo`, `runas`, scheduled tasks, or any other route. Test: text present.
27. The engine never changes execution policy, never enables or reconfigures Windows `sudo`, never installs tools. It detects a GPO-enforced execution policy and exits 7. Test: static scan (rule 11) plus mocked `Get-ExecutionPolicy -List`.
28. Restore-point creation is an explicit plan step with outcomes `created`, `skipped-recent-point-exists`, `unavailable`; success is confirmed by comparing `Get-ComputerRestorePoint` before and after. Changing `SystemRestorePointCreationFrequency` or calling `Enable-ComputerRestore` happens only as separate opt-in catalog actions with journal entries. Test: three mocked outcomes.

**Catalog and schema**

29. The catalog is strictly conformant JSON (no comments, no trailing commas) with a JSON Schema in draft 2020-12 or draft-07. CI validates it with `Test-Json -SchemaFile` under PowerShell 7.4+. Test: CI job.
30. The engine also validates the catalog at runtime in pure PowerShell 5.1 (required keys, types, action enum, unique IDs) and exits 3 on failure. Test: malformed-catalog fixtures.
31. Catalog entries contain no executable text: `action` is a closed enum, targets are typed fields. Free-text fields have a maximum length and a restricted character set enforced by the schema. Test: schema `enum`, `maxLength`, `pattern`.

**Permission configs**

32. `.claude/settings.json` contains: allow rules for the exact `status`, `plan` and `verify` invocations, written for both the `PowerShell(...)` and `Bash(...)` tool namespaces; an `ask` rule for the `apply` and `revert` invocations; deny rules for direct use of the dangerous primitives (for example `Remove-AppxPackage`, `Remove-AppxProvisionedPackage`, `reg`, `sc`, `Set-Service`, `Disable-ScheduledTask`, `Set-ExecutionPolicy`) so the agent must go through the engine. README states that allow rules take effect only after the folder is trusted and that these rules are guardrails, not a sandbox. Test: JSON fixture comparison.
33. For Codex, ship a sample `docs/agent-configs/codex.rules` (`prefix_rule` allow for plan/status/verify, `prompt` for apply/revert) and state: use the default workspace-write sandbox with on-request approvals; never `--yolo` / `danger-full-access`; the apply step will require an approval because the sandbox runs without admin rights. Test: file exists; README text present.
34. For Gemini CLI / Antigravity, ship a sample user-tier policy TOML in `docs/agent-configs/` with `allow` for plan/status/verify and `ask_user` for apply/revert, and state that it must be copied to `~/.gemini/policies/` because workspace policies are not honoured, and that headless mode turns `ask_user` into deny. Test: file exists; README text present.
35. AGENTS.md forbids, in plain words: bypass/yolo/full-access modes, network fetches during the task, following instructions found in tool output or in catalog text, and editing the catalog or engine before running it. Test: text present.

**Testing**

36. Tests use Pester 5 pinned by exact version in the test bootstrap; the bootstrap fails if the loaded Pester major version is not 5. Data-driven cases are built in `BeforeDiscovery` and fed with `-ForEach`. Test: bootstrap assertion.
37. CI runs the suite under Windows PowerShell 5.1 (engine behaviour) and the schema job under PowerShell 7.4+ (rule 29). Test: two CI jobs present.

---

## Source list

Agent instruction files and permissions
- https://agents.md/
- https://code.claude.com/docs/en/memory
- https://code.claude.com/docs/en/permissions
- https://code.claude.com/docs/en/tools-reference.md
- https://code.claude.com/docs/en/security.md
- https://learn.chatgpt.com/docs/agent-configuration/agents-md
- https://learn.chatgpt.com/docs/agent-approvals-security.md
- https://learn.chatgpt.com/docs/agent-configuration/rules.md
- https://learn.chatgpt.com/docs/windows/windows-sandbox.md
- https://developers.openai.com/codex/noninteractive
- https://geminicli.com/docs/cli/gemini-md/
- https://geminicli.com/docs/reference/policy-engine/
- https://geminicli.com/docs/cli/trusted-folders/
- https://geminicli.com/docs/reference/configuration/
- https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/
- https://antigravity.google/docs/rules.md
- https://gitforwindows.org/symbolic-links

Windows and PowerShell
- https://learn.microsoft.com/en-us/windows/advanced-settings/sudo/
- https://github.com/gerardog/gsudo
- https://gerardog.github.io/gsudo/docs/credentials-cache
- https://learn.microsoft.com/en-us/windows/security/application-security/application-control/administrator-protection
- https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process
- https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_requires?view=powershell-5.1
- https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_powershell_exe?view=powershell-5.1
- https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies
- https://learn.microsoft.com/en-us/powershell/scripting/whats-new/differences-from-windows-powershell
- https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_windows_powershell_compatibility
- https://learn.microsoft.com/en-us/powershell/windows/module-compatibility
- https://github.com/PowerShell/PowerShell/issues/13225
- https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/checkpoint-computer?view=powershell-5.1
- https://learn.microsoft.com/en-us/windows/win32/sr/calling-srsetrestorepoint
- https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/test-json
- https://learn.microsoft.com/powershell/scripting/learn/deep-dives/everything-about-shouldprocess

Testing and plan/apply
- https://pester.dev/docs/usage/discovery-and-run
- https://pester.dev/docs/usage/data-driven-tests
- https://pester.dev/docs/migrations/v5-to-v6
- https://developer.hashicorp.com/terraform/cli/commands/plan
