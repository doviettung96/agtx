# Codex agtx Session Prompt

Use this short prompt in any project prepared with `setup-agtx-downstream.ps1`:

```text
Read AGENTS.md first.
```

Then call:

- `$agtx-brainstorm` in Codex
- `$agtx-sweep` in Codex when ready to create tasks

For Claude, use `/agtx:brainstorm` and `/agtx:sweep`.

The skills carry the detailed rules: brainstorm does not implement or create
tasks; sweep proposes feature-level tasks, waits for confirmation, then creates
them through agtx MCP.
