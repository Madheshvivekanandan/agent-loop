# Design decisions

Why the agent loop is built the way it is. Synthesized (Sept 2026) from Anthropic's engineering guidance, the Agent Skills open standard, the skill and subagent docs of the major coding agents, and a survey of nine existing agent-workflow repos.

## Principles

1. **Process over personas.** Five agents defined by stage contracts (input artifact → output artifact), not job-title prompts. The most-adopted framework in the ecosystem (obra/superpowers) encodes workflow discipline, not a cast of characters; the 150–200-agent catalogs provide titles but no loop. Five is the ceiling — new capability goes into stage contracts, not new roles.
2. **Sequential stages, file handoff.** Anthropic's multi-agent research flags coding as a poor fit for parallel agents: stages are tightly coupled, and parallel agents make conflicting implicit decisions (Cognition's "Don't Build Multi-Agents" reaches the same conclusion). Each stage runs in a fresh context and hands off through a markdown artifact that carries *decisions and rationale*, not just conclusions — a downstream agent reconstructing context from a lossy summary is the classic handoff failure.
3. **Adaptive ceremony (triage tiers).** Multi-agent workflows cost roughly 15× the tokens of a single chat (Anthropic measurement). The official best-practices rule — "if you could describe the diff in one sentence, skip the plan" — is generalized into three tiers so trivial tasks never pay for the full pipeline.
4. **Verification terminates the loop.** Give the agent a check it can run — the top-billed practice in every vendor's own guidance. The planner must name a runnable check or the plan is rejected; done means an independent verifier executed that check and it passed, never "the implementer says so." This is why shell execution is the loop's one hard requirement.
5. **Hard caps everywhere.** Debug loop capped at 3 iterations with oscillation detection (Claude Code's own Stop-hook enforcement caps at 8 consecutive blocks — precedent that bounded loops are the right design). Per-stage tool-call budgets, plus a per-turn cap on the debugger where the host offers one. On cap: escalate with a distilled failure summary, never grind on.
6. **Zero runtime.** Markdown and a shell installer, nothing else. Frameworks that shipped daemons, tmux coordination, or databases are now maintenance liabilities racing against native agent features.
7. **Host-agnostic by construction.** The loop is one [Agent Skills](https://agentskills.io) folder — an open standard (`SKILL.md`, `name` + `description`) adopted across 30+ clients. Nothing in the protocol or the stage contracts names a vendor, a tool, or a frontmatter field belonging to one product. Host-specific affordances live in `agents/` and `adapters/`, and every one of them has a stated fallback.

## Load-bearing details

- **The verifier has no Edit/Write tools.** Withholding them removes the convenient edit path and states intent — defence in depth on top of the mandatory diff fingerprint, which is the actual guarantee it reports instead of patching (the verifier keeps a shell to run the checks, and a shell can edit files). It also never sees the implementer's summary or reasoning — an agent that saw the rationale tends to confirm it rather than break it. Its prompt caps the opposite failure too: only correctness-affecting gaps count, because a reviewer prompted to find gaps will otherwise manufacture them.
- **The analyzer owns the existence gate.** Mandatory Found / Exemplars / Missing / Reuse-plan sections. Most agent failures on real codebases come from re-implementing what exists.
- **The debugger starts fresh each iteration** so failed attempts don't accumulate as context noise, and it must reproduce a failure before fixing it. If it concludes the *plan* is wrong, that's an escalation, not a code change.
- **The profile makes the loop generic.** Project-specific knowledge (commands, exemplars, conventions) lives in one generated, cached file — `.agent-loop/profile.md` — not in the agent prompts. Discovered commands are executed once before being trusted.
- **Explicit invocation only.** The loop should never be auto-selected for an ordinary edit, so it adds zero always-loaded context weight. Hosts with a declarative switch get it (`disable-model-invocation: true`); the rest are covered by the skill `description`, which states the constraint in prose that the host's own selection logic reads.
- **Reasoning demand is declared, models are not.** Each stage contract states whether its demand is moderate or high; mapping that to an actual model is an adapter's job. Naming models in the neutral core would date it within months and would silently mean nothing on hosts with a different lineup. The demand levels are a property of the work, so they stay true.
- **Stage contracts are data, not prompts.** They live in `references/stages/` and are read at the point of use rather than baked into a host's agent format. That is what lets one set of contracts drive a Claude Code subagent, a Codex child thread, and a single-context sequential run without divergence.

## Portability

The loop's guarantees split into two kinds, and the split is what makes it portable.

**Protocol guarantees** hold on any host, because they are properties of the artifact contracts:
stages read only their declared inputs; the plan carries rationale; the verifier is given the plan
and the diff but not the implementer's reasoning; the debug loop counts to three and stops.

**Host guarantees** depend on what the runtime provides. Each is declared with an explicit
fallback in `skills/agent-loop/references/capabilities.md`, and the run announces which one it got:

| Guarantee | Structural where supported | Fallback elsewhere |
|---|---|---|
| Fresh context per stage | Subagents with own context windows (Mode A) | Sequential stages reading only declared inputs (Mode B) |
| Verifier cannot edit code | Diff fingerprint on every run, plus spawned without write tools | Diff fingerprint alone — it is the guarantee on every host |
| Bounded debug spend | Per-agent turn cap | Iteration counting against the loop's cap of 3 |
| Cost proportional to difficulty | Per-stage model/effort selection | One model for every stage; cost rises, quality does not fall |

Two consequences worth stating plainly. First, Mode B is not a degraded loop: file-based handoff is
what makes stages separable, and it works with one context window or six — what Mode B loses is
protection against the orchestrator's own memory, which is why the stage contracts state their
inputs as closed lists. Second, the diff fingerprint is the verifier's real no-edit guarantee on
every host, not a fallback: the verifier must hold a shell to run the checks, and a shell can edit
files, so withholding write tools removes the convenient path without preventing mutation.
Detection after the fact — void the verdict, re-verify — is what actually holds, which is why the
fingerprint is mandatory on every run and tool restriction is defence in depth on top of it.

The one non-negotiable requirement is shell execution. Verification that cannot run real commands
gives the loop no termination condition, so on such a host the loop refuses to run rather than
emitting confident unverified output.

## Failure modes this design targets

| Failure mode | Mitigation here |
|---|---|
| Context poisoning (bad output contaminates later stages) | Fresh context per stage; artifacts, not transcripts |
| Sycophantic verification | Independent verifier, mandatory diff fingerprint, no implementer rationale, evidence required |
| Infinite fix loops | Cap of 3, oscillation detection, escalation contract |
| Re-implementing existing code | Analyzer's mandatory existence gate + exemplars |
| Over-orchestration of trivial tasks | Triage tiers; prefer the smaller tier when unsure |
| Lossy handoffs | Plans carry decisions *and rationale*; templates enforce sections |

## Roadmap

- **v0.1:** Claude Code only — subagents, skill, templates. Established the stage contracts.
- **v0.2 (this):** restructured as a portable Agent Skill with vendor-neutral stage contracts, an explicit host-capability matrix with per-capability fallbacks, and `install.sh` for Claude Code / Codex / Cursor / `.agents`. Exit: completes real tier-M/L tasks end-to-end on 2–3 stacks and on 2+ hosts, including a FAIL → debug → PASS cycle in both Mode A and Mode B.
- **v0.3:** optional host-native enforcement layers where they exist (on Claude Code, a `SubagentStop` gate on the verifier re-running the check and a `Stop` gate on required artifacts); tier and budget tuning from real run logs.
- **v1.0:** distribution through each host's own channel — plugin marketplace for Claude Code, a skills registry entry for the rest.

## Key sources

- [Anthropic — Building Effective Agents](https://www.anthropic.com/engineering/building-effective-agents)
- [Anthropic — Multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)
- [Anthropic — Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Claude Code — Best practices](https://code.claude.com/docs/en/best-practices) · [Subagents](https://code.claude.com/docs/en/sub-agents) · [Skills](https://code.claude.com/docs/en/skills) · [Plugins](https://code.claude.com/docs/en/plugins)
- [Cognition — Don't Build Multi-Agents](https://cognition.com/blog/dont-build-multi-agents)
- [Agent Skills open standard — specification](https://agentskills.io/specification) · [clients](https://agentskills.io/clients)
- Host skill/subagent docs: [Claude Code](https://code.claude.com/docs/en/skills) · [Codex](https://developers.openai.com/codex/skills) · [Cursor](https://cursor.com/docs/skills)
