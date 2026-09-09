# Claude Code adapter

Claude Code supports declarative subagents with per-agent tool allowlists, which is the strongest
host configuration the loop can run on:

- **Mode A** — each stage runs in its own context window.
- **Verify defence in depth** — `agents/verifier.md` omits Edit and Write from its `tools:`
  list, removing the convenient edit path. This is not the guarantee: the verifier keeps Bash to
  run the checks, and a shell can edit files, so the orchestrator's diff fingerprint is mandatory
  here too — tool restriction layers on top of it, it does not replace it.
- **`maxTurns: 25`** on `agents/debugger.md` bounds each debug iteration mechanically.

## Demand → model mapping

The stage contracts declare a **reasoning demand**; this adapter maps it to Claude Code's `model:`
and `effort:` fields.

| Stage | Demand | `model` | `effort` |
|---|---|---|---|
| analyzer | moderate | `sonnet` | — |
| planner | **high** | `opus` | `high` |
| implementer | moderate | `sonnet` | — |
| verifier | **high** | `opus` | `high` |
| debugger | **high** | `opus` | `high` |

Strong-model budget goes to the three stages where quality actually comes from: a wrong plan is
executed faithfully by everything downstream, the verifier is the loop's only termination
condition, and a weak debugger reaches for the symptom suppressions its contract forbids.

Nothing is mapped to `haiku`. Analyze is the tempting candidate — it looks like search — but its
real job is noticing that something *already exists*, and missing that hands the implementer a
green light to rebuild it. That costs far more than the model saved. Measure before dropping a
tier; `model: inherit` on all five is a safe way to A/B the whole loop against your session model.

The profile stage has no subagent file: it is orchestrated inline via
`references/stages/profile.md` and runs once per project, so tuning it saves almost nothing.

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
