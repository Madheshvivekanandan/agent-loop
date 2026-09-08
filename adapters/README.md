# Adapters

The loop itself is one [Agent Skills](https://agentskills.io) folder — `skills/agent-loop/`. That
format is an open standard supported by Claude Code, Codex, Cursor, Gemini CLI, GitHub Copilot,
VS Code, OpenCode, Amp, Roo Code, Kiro, Factory and 30+ other clients, so **most hosts need no
adapter at all**: drop the folder in a skills directory and invoke it.

What varies between hosts is only:

1. **Which directory** they scan for skills.
2. **Whether they can spawn subagents**, which decides Mode A vs Mode B (see
   `skills/agent-loop/references/capabilities.md`).
3. **Whether they can restrict a subagent's tools**, which decides whether the verifier's
   no-edit rule is enforced structurally or by diff fingerprint.

## Install locations

Verified against each vendor's current docs. Where a host is not listed, check the
[client showcase](https://agentskills.io/clients) for its skills directory — the skill folder
itself is unchanged.

| Host | Skills directory | Subagents | Tool restriction |
|---|---|---|---|
| **Claude Code** | `.claude/skills/` · `~/.claude/skills/` | Yes → Mode A | Yes (`agents/`) |
| **Codex** | `.agents/skills/` (cwd → repo root) · `~/.agents/skills/` | On request → Mode A | No → fingerprint |
| **Cursor** | `.cursor/skills/` · `.agents/skills/` · also reads `.claude/skills/`, `.codex/skills/` | Cloud agents → Mode A | No → fingerprint |
| **Any other Agent Skills client** | see vendor docs; `.agents/skills/` is the shared convention | varies → declare it | varies |

`install.sh` writes to the right place for you:

```sh
./install.sh claude-code   # or: codex · cursor · agents (the shared .agents/skills path)
./install.sh codex --global
```

## `agents-md/`

A short block to paste into your project's `AGENTS.md` (or `CLAUDE.md`). Optional — it tells the
agent the loop exists and when to reach for it, which matters on hosts that only surface skills on
explicit invocation.

## `claude-code/`

Claude Code specifics: the `agents/` directory at the repo root holds native subagent definitions
whose `tools:` allowlists make the verifier's read-only rule structural rather than behavioural.
Also usable as a plugin without copying anything — see that directory's README.
