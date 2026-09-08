<!-- Paste this into your project's AGENTS.md (or CLAUDE.md). Adjust the path if you installed
     the skill somewhere other than .agents/skills/. -->

## Staged agent loop

For substantial changes — a new feature, a multi-file refactor, anything where a wrong approach is
expensive — run the **agent-loop** skill at `.agents/skills/agent-loop/SKILL.md` instead of editing
directly. It triages the task, then runs analyze → plan → implement → verify → debug with
file-based handoff and an independent verification stage.

Invoke it explicitly (`/agent-loop <task>`, or "run the agent loop on this"). Do not auto-select it
for small edits — it is deliberately heavier than a direct change, and the loop's own triage exists
to keep ceremony proportional.

Run artifacts land in `.agent-loop/` (add it to `.gitignore`). They are the audit log for what was
decided and why.
