# Codex agtx Session Prompt

Use this prompt in any project prepared with `setup-agtx-downstream.ps1`:

```text
Read AGENTS.md first. Use agtx MCP as the board for this project.

First, brainstorm with me in discussion mode. Do not implement and do not create
tasks yet.

When the direction is settled, propose feature-level agtx tasks. Each task must
be fresh-context-safe and include:

- purpose and expected outcome
- files, docs, or modules to inspect
- persisted inputs and decisions from this discussion
- expected edit surface when known
- verification commands or live checks
- risks and edge cases
- dependencies on other tasks
- escalation condition for human input

Stop and ask for my confirmation before creating tasks. After I confirm, create
the tasks in agtx through MCP.

Do not recreate Agent Mail, Beads, mailboxes, reservations, or a second task
board. agtx owns task state and execution.
```
