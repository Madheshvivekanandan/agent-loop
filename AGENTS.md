# AGENTS.md

Guidance for any coding agent working in this repository.

## What this repo is

A portable [Agent Skills](https://agentskills.io) package — **not an application**. No source code,
no build step, no test suite, no dependencies. Every file is markdown, JSON, or one POSIX shell
installer. "Zero runtime" is a deliberate design constraint (`docs/design.md`), so resist adding
scripts, daemons, or config beyond what a skills client reads.

The product is the single folder `skills/agent-loop/`. Everything else is packaging, docs, or
host-specific affordances.

## Running / testing changes

There is no automated test. Validate by running the loop against a real project:

```sh
./install.sh claude-code --target /tmp/scratch/skills   # or install into a throwaway project
claude --plugin-dir .                                   # Claude Code, no install
```

Then, in that project: `/agent-loop <task>`.

A change is exercised end-to-end only when a run produces every artifact in
`.agent-loop/runs/<date>-<slug>/` and the verifier reaches a `PASS` or `FAIL` verdict. A
FAIL → debug → PASS cycle is the acceptance bar in the roadmap, and v0.2 additionally asks for it
on two different hosts and in both execution modes.

Check `install.sh` with `sh -n install.sh` and by installing into a scratch directory — it is the
only executable file here.

## Architecture

The pipeline is **triage → analyze → plan → implement → verify → debug**. Understanding it means
reading three layers together:

- **`skills/agent-loop/SKILL.md`** — the orchestration protocol. Runs triage inline (never
  delegated), picks an execution mode, runs the tier's stages in order, and enforces the stage
  gates. It holds only file paths, the tier, and ≤10-line stage summaries; artifact contents never
  enter its context.
- **`skills/agent-loop/references/stages/*.md`** — the six stage contracts, each an *input
  artifact → output artifact* contract with declared restrictions and budgets. Vendor-neutral: no
  contract names a tool, a product, or a host frontmatter field.
- **`skills/agent-loop/references/templates/*.md`** — the handoff contracts. Section headings are
  not decoration; the orchestrator's gates check for them (`analysis.md`'s four sections,
  `plan.md`'s **Runnable check**, evidence in `implementation.md`, a `PASS`/`FAIL` verdict in
  `test-report.md`).

`references/capabilities.md` is the fourth thing to read: it defines the two execution modes and
every capability fallback.

State lives in `.agent-loop/` in the *target* project (gitignored, doubles as an audit log):
`profile.md` at the root is the cached, command-verified project profile; each run gets
`runs/<YYYY-MM-DD>-<slug>/` holding `task.md`, `analysis.md`, `plan.md`, `implementation.md`,
`test-report.md`.

### The core/adapter boundary

This is the constraint most likely to be broken by a well-meaning edit.

- `skills/agent-loop/` is **canonical and vendor-neutral**. If you find yourself writing a tool
  name, a product name, or a host-only frontmatter field in there, it belongs in an adapter.
- `agents/` holds thin native subagent definitions for hosts with declarative agents (currently
  Claude Code). Each one points at its stage contract and adds only host frontmatter — the
  behaviour must not diverge from the contract. It sits at the repo root because that is where
  Claude Code's plugin loader looks.
- `adapters/` holds per-host install notes and an `AGENTS.md` snippet. No behaviour.
- Every host-specific affordance needs a **stated fallback** in `references/capabilities.md`. A
  capability with no fallback is a portability bug.

### Invariants to preserve

Each maps to a failure mode in `docs/design.md`.

- **Five stages plus profile is a ceiling.** New capability goes into an existing contract, never a
  new role.
- **The verifier must not be able to certify its own patch.** Where the host can restrict tools,
  spawn it without write tools; everywhere else the **diff fingerprint** before/after verification
  is mandatory. It is also never passed the implementer's summary, reasoning, or
  `implementation.md`.
- **`plan.md` must carry rationale, not just conclusions** — the implementer never sees the
  planner's reasoning, and one that gets only conclusions re-derives and contradicts it.
- **A plan without a Runnable check is invalid.** The orchestrator returns it once, then stops.
- **The debug loop caps at 3 iterations**, with oscillation detection and a fresh verification pass
  after every debug pass. On cap: escalate with a distilled failure summary.
- **Triage prefers the smaller tier** when between two.
- **Project-specific knowledge belongs in `profile.md`, never in a stage contract.** That is what
  keeps the stages generic across stacks. Discovered commands are executed once before being
  trusted.
- **Shell execution is the one hard requirement.** Without it the loop has no termination condition
  and must refuse to run.

Stage budgets (analyze ≤ 15 tool calls, plan ≤ 10, verify ≤ 15, debug ≤ 25 turns) appear in both
`SKILL.md`'s stage table and the individual contracts, so a change must update both.

## Docs to keep in sync

`README.md` (user-facing, includes a mermaid flowchart and the capability table),
`docs/design.md` (rationale, portability section, failure-mode table, roadmap), and
`adapters/README.md` (the per-host install table). A change to tiers, caps, budgets, the stage
list, or host support touches all three.

**Vendor claims must be verifiable.** The install table lists only directories confirmed against
that vendor's current docs. Do not add a host or a path from memory — check the vendor's skills
documentation or https://agentskills.io/clients first, and point elsewhere rather than guess.
