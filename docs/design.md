# Design decisions

Why the agent loop is built the way it is. Synthesized (Sept 2026) from Anthropic's engineering guidance, official Claude Code docs, and a survey of nine existing agent-workflow repos.

## Principles

1. **Process over personas.** Five agents defined by stage contracts (input artifact → output artifact), not job-title prompts. The most-adopted framework in the ecosystem (obra/superpowers) encodes workflow discipline, not a cast of characters; the 150–200-agent catalogs provide titles but no loop. Five is the ceiling — new capability goes into stage contracts, not new roles.
2. **Sequential stages, file handoff.** Anthropic's multi-agent research flags coding as a poor fit for parallel agents: stages are tightly coupled, and parallel agents make conflicting implicit decisions (Cognition's "Don't Build Multi-Agents" reaches the same conclusion). Each stage runs in a fresh context and hands off through a markdown artifact that carries *decisions and rationale*, not just conclusions — a downstream agent reconstructing context from a lossy summary is the classic handoff failure.
3. **Adaptive ceremony (triage tiers).** Multi-agent workflows cost roughly 15× the tokens of a single chat (Anthropic measurement). The official best-practices rule — "if you could describe the diff in one sentence, skip the plan" — is generalized into three tiers so trivial tasks never pay for the full pipeline.
4. **Verification terminates the loop.** "Give Claude a check it can run" is the top-billed official practice. The planner must name a runnable check or the plan is rejected; done means an independent verifier passed that check — never "the implementer says so."
5. **Hard caps everywhere.** Debug loop capped at 3 iterations with oscillation detection (Claude Code's own Stop-hook enforcement caps at 8 consecutive blocks — official precedent that bounded loops are the right design). Per-stage tool-call budgets; `maxTurns` on the debugger. On cap: escalate with a distilled failure summary, never grind on.
6. **Zero runtime.** Pure `.claude/` content. Frameworks that shipped daemons, tmux coordination, or databases are now maintenance liabilities racing against native Claude Code features.

## Load-bearing details

- **The verifier has no Edit/Write tools.** Withholding them is the structural guarantee it reports instead of patching. It also never sees the implementer's summary or reasoning — an agent that saw the rationale tends to confirm it rather than break it. Its prompt caps the opposite failure too: only correctness-affecting gaps count, because a reviewer prompted to find gaps will otherwise manufacture them.
- **The analyzer owns the existence gate.** Mandatory Found / Exemplars / Missing / Reuse-plan sections. Most agent failures on real codebases come from re-implementing what exists.
- **The debugger starts fresh each iteration** so failed attempts don't accumulate as context noise, and it must reproduce a failure before fixing it. If it concludes the *plan* is wrong, that's an escalation, not a code change.
- **The profile makes the loop generic.** Project-specific knowledge (commands, exemplars, conventions) lives in one generated, cached file — `.agent-loop/profile.md` — not in the agent prompts. Discovered commands are executed once before being trusted.
- **`disable-model-invocation: true`** on the skill: the loop runs only when explicitly invoked and adds zero always-loaded context weight.

## Failure modes this design targets

| Failure mode | Mitigation here |
|---|---|
| Context poisoning (bad output contaminates later stages) | Fresh context per stage; artifacts, not transcripts |
| Sycophantic verification | Independent verifier, no write tools, no implementer rationale, evidence required |
| Infinite fix loops | Cap of 3, oscillation detection, escalation contract |
| Re-implementing existing code | Analyzer's mandatory existence gate + exemplars |
| Over-orchestration of trivial tasks | Triage tiers; prefer the smaller tier when unsure |
| Lossy handoffs | Plans carry decisions *and rationale*; templates enforce sections |

## Roadmap

- **v0.1 (this):** agents + skill + templates; install by copying `.claude/` contents or `claude --plugin-dir`. Exit: completes real tier-M/L tasks end-to-end on 2–3 different stacks, including a FAIL → debug → PASS cycle.
- **v0.2:** optional `hooks/hooks.json` enforcement layer (`SubagentStop` gate on the verifier re-running the check; `Stop` gate on required artifacts); tier and budget tuning from real run logs.
- **v1.0:** publish via plugin marketplace (`/plugin marketplace add <org>/claude-agent-loop`); team rollout through `extraKnownMarketplaces`.

## Key sources

- [Anthropic — Building Effective Agents](https://www.anthropic.com/engineering/building-effective-agents)
- [Anthropic — Multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)
- [Anthropic — Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Claude Code — Best practices](https://code.claude.com/docs/en/best-practices) · [Subagents](https://code.claude.com/docs/en/sub-agents) · [Skills](https://code.claude.com/docs/en/skills) · [Plugins](https://code.claude.com/docs/en/plugins)
- [Cognition — Don't Build Multi-Agents](https://cognition.com/blog/dont-build-multi-agents)
