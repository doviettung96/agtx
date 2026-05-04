# agtx Downstream Setup

Use this guide when preparing a project so Codex or Claude can open in the repo,
talk to agtx immediately, brainstorm with the user, sweep confirmed work into
board tasks, and let agtx manage multi-agent execution.

This setup replaces the old Agent Mail / Beads swarm control plane. Do not add
mailbox scripts, reservation files, `.beads/workflow`, Beads skills, or a second
task board.

## Target Operating Model

Use two roles, both backed by agtx:

- **Discussion/sweep session**: open Codex or Claude in the project root, chat
  with the user, brainstorm, propose feature-level tasks, and create agtx tasks
  only after user confirmation.
- **Execution session**: open `agtx --experimental` in the same project, move a
  small number of tasks into Planning or Running, and press `O` to let the
  orchestrator manage the board and spawned task sessions.

The user remains the Review/Done gate. Agents can move work toward Review, but
must not silently mark work Done.

## One-Time Machine Setup

Configure agent MCP globally so it works in any repo where the agent is launched
from the project root.

PowerShell:

```powershell
$env:HOME = $env:USERPROFILE
$env:Path = "$env:USERPROFILE\.local\bin;$env:USERPROFILE\.cargo\bin;C:\Program Files\Git\bin;$env:Path"

codex mcp add agtx -- "$env:USERPROFILE\.local\bin\agtx.exe" mcp-serve .
claude mcp add -s user agtx -- "$env:USERPROFILE\.local\bin\agtx.exe" mcp-serve .
```

Why `.` matters: the MCP server becomes project-scoped to the current working
directory of the Codex/Claude session. Open the agent from the repo root.

## Per-Project Setup

Run the setup script from this repo:

```powershell
powershell -ExecutionPolicy Bypass -File D:\Projects\agtx\scripts\setup-agtx-downstream.ps1 -ProjectPath D:\Projects\some-project -ProjectName some-project -BaseBranch main -InitGit
```

For an existing git repo, omit `-InitGit`.

The script:

- creates git repo metadata only when `-InitGit` is supplied and the target is
  not already a git repo
- ensures `.agtx/`, `.beads/`, and agent-local config directories are ignored
- writes local `.agtx/config.toml` for Codex-backed agtx execution
- deploys ignored local Codex and Claude `agtx-brainstorm` / `agtx-sweep`
  skills into the downstream repo
- creates or updates `AGENTS.md` with the agtx operating contract
- creates `CLAUDE.md` as a thin pointer to `AGENTS.md` if missing
- runs `agtx trust` for the project

## Required Project Files

Every agtx-managed downstream project should have:

- `AGENTS.md`: canonical instructions, including the agtx contract
- `CLAUDE.md`: thin pointer back to `AGENTS.md`
- `.gitignore`: ignores `.agtx/`, `.beads/`, and local agent config folders
- `.agtx/config.toml`: local-only agtx project config
- `.codex/skills/agtx-brainstorm/` and `.codex/skills/agtx-sweep/`:
  ignored local Codex discussion/sweep skills
- `.claude/commands/agtx/brainstorm.md` and `sweep.md`: ignored local Claude
  discussion/sweep commands

Recommended `.agtx/config.toml`:

```toml
default_agent = "codex"
workflow_plugin = "agtx"
base_branch = "main"

[agents]
planning = "codex"
running = "codex"
review = "codex"
```

## Codex/Claude Session Prompt

In a prepared downstream repo, the short flow is:

```text
Read AGENTS.md first.
```

Then invoke the local skill:

- Codex: `$agtx-brainstorm`, then `$agtx-sweep`
- Claude: `/agtx:brainstorm`, then `/agtx:sweep`

The brainstorm skill stays in discussion mode. The sweep skill proposes
feature-level agtx tasks, stops for user confirmation, and only then creates
tasks through MCP.

## Execution Session

In another terminal:

```powershell
cd D:\Projects\some-project
$env:HOME = $env:USERPROFILE
$env:Path = "$env:USERPROFILE\.local\bin;$env:USERPROFILE\.cargo\bin;C:\Program Files\Git\bin;$env:Path"
agtx --experimental
```

Then:

1. Review the Backlog.
2. Move only one to three tasks into Planning or Running.
3. Press `O` to start the orchestrator.
4. Watch task panes when needed with Enter or `Ctrl+f`.
5. Keep Review/Done as the human merge gate.

## Verification Checklist

After setup, verify:

```powershell
git status --short --branch
git check-ignore -v .agtx/config.toml
agtx trust
tmux -V
codex mcp list
claude mcp list
```

Expected:

- `.agtx/config.toml` is ignored
- `.codex/skills/agtx-brainstorm/SKILL.md` and
  `.codex/skills/agtx-sweep/SKILL.md` exist
- `.claude/commands/agtx/brainstorm.md` and
  `.claude/commands/agtx/sweep.md` exist
- `agtx trust` succeeds
- `tmux` is available
- Codex and Claude list an `agtx` MCP server
- grep only finds old Agent Mail / Beads references as explicit "do not use"
  guardrails or `.beads/` ignore/exclude rules
