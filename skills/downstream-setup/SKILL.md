---
name: agtx-downstream-setup
description: "Prepare a downstream project to use agtx as the board/execution owner with Codex/Claude MCP, local .agtx config, canonical AGENTS.md guidance, and no Agent Mail / Beads workflow."
disable-model-invocation: true
---

# agtx Downstream Setup

Use this skill when the user asks to apply agtx to another project, prepare a
downstream repo for agtx, or make Codex/Claude open in that repo already aware
of the agtx MCP board.

## Boundaries

- Do not recreate Agent Mail, Beads, mailbox threads, reservations, `.beads`
  workflow state, or a second task board.
- Keep `.agtx/` local and ignored unless the user explicitly asks to track a
  specific project artifact.
- Treat `AGENTS.md` as canonical. `CLAUDE.md` should be a thin pointer back to
  `AGENTS.md`.
- Preserve downstream app-specific guidance where possible. If `AGENTS.md`
  already exists, append an agtx contract only when the repo lacks one.

## Setup Steps

1. Read `docs/downstream-setup.md`.
2. Check the target repo:
   ```powershell
   git status --short --branch
   Get-ChildItem -Force
   ```
3. Run the setup script from the agtx repo:
   ```powershell
   powershell -ExecutionPolicy Bypass -File D:\Projects\agtx\scripts\setup-agtx-downstream.ps1 -ProjectPath <target> -ProjectName <name> -BaseBranch <branch>
   ```
   Add `-InitGit` only for a new project that should be initialized as a git
   repo. Add `-ConfigureAgentMcp` only when machine-global Codex/Claude MCP
   setup is missing or the user explicitly wants it refreshed.
4. Verify:
   ```powershell
   git status --short --branch
   git check-ignore -v .agtx/config.toml
   Test-Path .codex/skills/agtx-brainstorm/SKILL.md
   Test-Path .codex/skills/agtx-sweep/SKILL.md
   Test-Path .claude/commands/agtx/brainstorm.md
   Test-Path .claude/commands/agtx/sweep.md
   agtx trust
   tmux -V
   codex mcp list
   claude mcp list
   ```
5. Search for retired workflow leftovers:
   ```powershell
   rg -n "Agent Mail|Beads|bd |swarm|plan-beads|executor-loop|BEADS_WORKFLOW|workflow-status|agent-mail|\\.beads|bead" AGENTS.md CLAUDE.md .gitignore .codex .claude scripts -S
   ```
   Expected matches should be only explicit "do not use" guardrails or
   `.beads/` ignore/exclude rules.

## Session Prompt

After setup, tell the user to open Codex or Claude from the downstream project
root and use the prompt in `docs/codex-agtx-session-prompt.md`.
