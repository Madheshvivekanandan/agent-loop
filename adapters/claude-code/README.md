# Claude Code adapter

Claude Code supports declarative subagents with per-agent tool allowlists, which is the strongest
host configuration the loop can run on:

- **Mode A** — each stage runs in its own context window.
- **Structural verify guarantee** — `agents/verifier.md` omits Edit and Write from its `tools:`
  list, so the verifier physically cannot patch the code it is judging. On hosts without tool
  restriction this degrades to the diff-fingerprint check, which catches the problem after the
  fact instead of preventing it.
- **`maxTurns: 25`** on `agents/debugger.md` bounds each debug iteration mechanically.

The subagent definitions live in `agents/` at the repository root (not in this directory) because
that is where Claude Code's plugin loader expects them. They are thin: each one points at the
vendor-neutral stage contract in `skills/agent-loop/references/stages/` and adds only the
frontmatter Claude Code needs.

## Run as a plugin, without copying anything

```sh
claude --plugin-dir /path/to/agent-loop
```

The root `.claude-plugin/plugin.json` registers the skill and all five subagents.

## Or install into a project

```sh
./install.sh claude-code            # -> .claude/skills/ + .claude/agents/
./install.sh claude-code --global   # -> ~/.claude/skills/ + ~/.claude/agents/
```

## Notes

- `disable-model-invocation: true` in `SKILL.md` keeps the loop from being auto-selected, so it
  costs zero context in normal sessions. Other hosts ignore the field; the skill's `description`
  carries the same instruction in prose for them.
- `effort: high` on the planner and verifier is a Claude Code field. Hosts that ignore it lose a
  quality nudge, not a guarantee.
