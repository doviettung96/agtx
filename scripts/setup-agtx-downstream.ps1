param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$ProjectName,

    [string]$BaseBranch = "main",

    [switch]$InitGit,

    [switch]$ConfigureAgentMcp
)

$ErrorActionPreference = "Stop"

function Ensure-Directory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Add-UniqueLine([string]$Path, [string]$Line) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType File -Path $Path | Out-Null
    }
    $content = Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($content -notcontains $Line) {
        Add-Content -LiteralPath $Path -Value $Line
    }
}

function Write-FileIfMissing([string]$Path, [string]$Content) {
    if (-not (Test-Path -LiteralPath $Path)) {
        $parent = Split-Path -Parent $Path
        if ($parent) {
            Ensure-Directory $parent
        }
        Set-Content -LiteralPath $Path -Value $Content -NoNewline
    }
}

function Convert-ToClaudeCommand([string]$Content, [string]$CommandName) {
    return $Content -replace "(?m)^name:\s*agtx-[^\r\n]+", "name: agtx:$CommandName"
}

function Deploy-AgtxDiscussionSkills([string]$TemplateRoot) {
    $skillMap = @(
        @{ Name = "brainstorm"; Source = Join-Path $TemplateRoot "skills\brainstorm\SKILL.md" },
        @{ Name = "sweep"; Source = Join-Path $TemplateRoot "skills\sweep\SKILL.md" }
    )

    foreach ($skill in $skillMap) {
        if (-not (Test-Path -LiteralPath $skill.Source)) {
            throw "Missing bundled agtx skill: $($skill.Source)"
        }

        $content = Get-Content -LiteralPath $skill.Source -Raw

        $codexDir = Join-Path ".codex\skills" ("agtx-" + $skill.Name)
        Ensure-Directory $codexDir
        Set-Content -LiteralPath (Join-Path $codexDir "SKILL.md") -Value $content -NoNewline

        $claudeDir = ".claude\commands\agtx"
        Ensure-Directory $claudeDir
        $claudeContent = Convert-ToClaudeCommand $content $skill.Name
        Set-Content -LiteralPath (Join-Path $claudeDir ($skill.Name + ".md")) -Value $claudeContent -NoNewline
    }
}

$templateRoot = Split-Path -Parent $PSScriptRoot
$resolvedProject = [System.IO.Path]::GetFullPath($ProjectPath)
Ensure-Directory $resolvedProject

if (-not $ProjectName) {
    $ProjectName = Split-Path -Leaf $resolvedProject
}

Push-Location $resolvedProject
try {
    $isGitRepo = $false
    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $gitCheck = & git rev-parse --is-inside-work-tree 2>$null
    $gitCheckExit = $LASTEXITCODE
    $ErrorActionPreference = $oldErrorActionPreference
    if ($gitCheckExit -eq 0 -and $gitCheck -match "true") {
        $isGitRepo = $true
    }

    if (-not $isGitRepo) {
        if (-not $InitGit) {
            throw "Target is not a git repo. Re-run with -InitGit if this should initialize one."
        }
        git init -b $BaseBranch | Out-Host
    }

    Add-UniqueLine ".gitignore" "# Local agtx board/worktree/runtime state"
    Add-UniqueLine ".gitignore" ".agtx/"
    Add-UniqueLine ".gitignore" ""
    Add-UniqueLine ".gitignore" "# Agent-local MCP/skill files generated during the agtx pilot"
    Add-UniqueLine ".gitignore" ".codex/"
    Add-UniqueLine ".gitignore" ".claude/"
    Add-UniqueLine ".gitignore" ".gemini/"
    Add-UniqueLine ".gitignore" ".cursor/"
    Add-UniqueLine ".gitignore" ".opencode/"
    Add-UniqueLine ".gitignore" ""
    Add-UniqueLine ".gitignore" "# Retired local task-state data from the old workflow"
    Add-UniqueLine ".gitignore" ".beads/"

    Ensure-Directory ".agtx"
    $agtxConfig = @"
default_agent = "codex"
workflow_plugin = "agtx"
base_branch = "$BaseBranch"

[agents]
planning = "codex"
running = "codex"
review = "codex"
"@
    Set-Content -LiteralPath ".agtx/config.toml" -Value $agtxConfig

    $agentsTemplate = @'
# Agent Instructions

This checkout is managed by **agtx**. Use agtx as the board and execution owner
for multi-agent coding work: tasks live on the agtx board, execution runs in
agtx-created worktrees and tmux panes, and Review is the human merge gate.

Do not recreate or use the old Agent Mail / Beads swarm workflow in this repo.
Do not create a second task board, mailbox, reservation system, or `.beads`
control plane.

## Project Overview

{{ProjectName}} is an agtx-managed project. Update this section with the concrete
application stack, key source directories, and runtime notes once known.

## agtx Workflow

- Use Claude or Codex for discussion capture when useful: brainstorm first,
  then sweep confirmed work into agtx tasks.
- Do not create agtx tasks from sweep until the user confirms the proposed task
  list.
- Create feature/PR-level tasks, not tiny implementation subtasks.
- Make every task fresh-context-safe: include purpose, expected outcome,
  relevant files, persisted decisions, verification commands, risks, and the
  condition that should escalate to the user.
- Move only a small number of tasks into Planning or Running at once.
- Codex is the default execution agent for Planning, Running, Review, and the
  experimental orchestrator.
- Human review owns merge/Done. Do not silently mark work Done.

## Local agtx Setup

`.agtx/` is local runtime state and must remain ignored. This checkout uses
local `.agtx/config.toml` with Codex as the default agent and `{{BaseBranch}}` as
the base branch.

Run agtx from a shell whose PATH includes:

- `C:\Users\Admin\.cargo\bin`
- `C:\Program Files\Git\bin` for `sh.exe`
- `C:\Users\Admin\.local\bin` for `agtx.exe`

Useful commands:

```powershell
agtx trust
agtx --experimental
agtx -g
tmux -L agtx list-windows -a
```

## Verification

Update this section with the real build/test/run commands once the stack exists.
Do not claim task completion without fresh verification evidence.
'@
    $agentsContent = $agentsTemplate.Replace("{{ProjectName}}", $ProjectName).Replace("{{BaseBranch}}", $BaseBranch)

    if (Test-Path -LiteralPath "AGENTS.md") {
        $existing = Get-Content -LiteralPath "AGENTS.md" -Raw
        $hasAgtxContract =
            ($existing -match "agtx pilot repo") -or
            ($existing -match "agtx Project Contract") -or
            (($existing -match "agtx Workflow") -and ($existing -match "Human review owns merge/Done"))
        if (-not $hasAgtxContract) {
            $block = "`n`n---`n`n## agtx Project Contract`n`n" + ($agentsContent -replace "^# Agent Instructions\r?\n\r?\n", "")
            Add-Content -LiteralPath "AGENTS.md" -Value $block
        }
    } else {
        Set-Content -LiteralPath "AGENTS.md" -Value $agentsContent
    }

    $claudeContent = @'
# CLAUDE.md

Read `AGENTS.md` first. It is the canonical instruction file for this repo.

Claude may be used for agtx brainstorm/sweep discussion capture. Do not use or
recreate the old Agent Mail / Beads swarm workflow.
'@
    Write-FileIfMissing "CLAUDE.md" $claudeContent
    Deploy-AgtxDiscussionSkills $templateRoot

    if (-not $env:HOME) {
        $env:HOME = $env:USERPROFILE
    }
    $env:Path = "$env:USERPROFILE\.local\bin;$env:USERPROFILE\.cargo\bin;C:\Program Files\Git\bin;$env:Path"

    agtx trust | Out-Host

    if ($ConfigureAgentMcp) {
        $agtxExe = Join-Path $env:USERPROFILE ".local\bin\agtx.exe"
        $codexList = codex mcp list 2>$null
        if ($LASTEXITCODE -eq 0 -and ($codexList -notmatch "(?m)^agtx\b")) {
            codex mcp add agtx -- $agtxExe mcp-serve . | Out-Host
        }

        $claudeList = claude mcp list 2>$null
        if ($LASTEXITCODE -eq 0 -and ($claudeList -notmatch "(?m)^agtx\b")) {
            claude mcp add -s user agtx -- $agtxExe mcp-serve . | Out-Host
        }
    }

    Write-Host "agtx downstream setup complete: $resolvedProject"
}
finally {
    Pop-Location
}
