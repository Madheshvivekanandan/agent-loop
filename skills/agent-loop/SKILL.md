---
name: agent-loop
description: Run a task through the staged agent loop — triage, analyze, plan, implement, verify, debug — with file-based handoff, fresh context per stage, and capped iterations.
argument-hint: <task description>
disable-model-invocation: true
---

# Agent loop orchestrator

You are orchestrating a staged pipeline for this task:

> $ARGUMENTS

**Your context must stay small.** Hold only: the task, the tier, the current stage, and artifact file paths. Never paste artifact contents, diffs, or logs into your own context — stages communicate through files, and each stage agent returns at most a 10-line summary.

## Step 0 — Run directory and profile

1. Create the run directory `.agent-loop/runs/<YYYY-MM-DD>-<short-slug>/` (slug: 2–4 words from the task). Ensure `.agent-loop/` is listed in `.gitignore`; add it if missing.
2. **Profile.** If `.agent-loop/profile.md` exists, use it. Otherwise delegate profile creation to the **analyzer** agent with this brief: read `AGENTS.md`/`CLAUDE.md` if present; otherwise detect package manager, test command, build command, lint command, and one exemplar file per major pattern — then **run each discovered command once to confirm it works** and write `.agent-loop/profile.md` per `templates/profile.md`. An unverified test command poisons every downstream stage.
3. Write `task.md` in the run directory: the task verbatim, plus your tier decision and reasoning (after Step 1).

## Step 1 — Triage

Classify the task yourself, inline — no subagent. State the tier and a one-sentence reason before proceeding, so a wrong sizing is visible and correctable.

| Tier | Signal | Pipeline |
|------|--------|----------|
| **S** | Diff describable in one sentence; single file; no design choice | implement → verify |
| **M** | Localized change, but touches unfamiliar code or needs a reuse check | analyze → implement → verify |
| **L** | Multi-file, new feature, architectural choice, or uncertain scope | analyze → plan → implement → verify |

When in doubt between two tiers, pick the smaller one — escalating mid-run is cheap (spawn the skipped stage), while running the full pipeline on a trivial task is pure waste.

## Step 2 — Run the stages

Each stage is **one spawn of the matching agent** (`analyzer`, `planner`, `implementer`, `verifier`, `debugger`) via the Agent tool, run in the foreground, in order. Every delegation prompt must contain:

- the specific objective for this stage;
- **absolute paths** to its input artifacts (from the run directory and `profile.md`);
- the absolute path where its output artifact goes, and the template to follow (`templates/<name>.md` in this plugin/repo);
- its budget (analyzer ≤ 15 tool calls, planner ≤ 10, verifier ≤ 15);
- the instruction to return a summary of at most 10 lines.

Vague delegation causes duplicate work and gaps — always pass the full brief.

### Stage gates (check after each stage, before the next)

- **Analyze** → `analysis.md` exists with all four sections (Found / Exemplars / Missing / Reuse plan).
- **Plan** → `plan.md` contains a **Runnable check** section with an executable command. If missing, send the planner back once with that feedback; if still missing, stop and ask the user.
- **Implement** → `implementation.md` exists with real command output under Evidence.
- **Verify** → `test-report.md` contains a structured `PASS` or `FAIL` verdict with evidence. The verifier's delegation prompt gets **only** the plan (or `task.md` for tier S) and profile paths — never the implementer's summary, so it judges fresh.

## Step 3 — Debug loop (on FAIL)

Maximum **3 iterations**. For each:

1. Spawn **debugger** with paths to `plan.md` (or `task.md`), `test-report.md`, `implementation.md`, and the iteration number.
2. Spawn a **fresh verifier** (same brief as before). Never let the debugger self-certify.

Stop the loop early and escalate if:
- two consecutive debug iterations made substantively the same change (the loop is oscillating);
- the debugger reports the **plan itself** is wrong;
- 3 iterations are exhausted.

**Escalation:** write a distilled failure summary at the end of `test-report.md` — what was tried, what still fails, current best hypothesis — and report to the user. Do not silently continue past the cap, and do not re-plan without the user asking for it.

## Step 4 — Report

Tell the user: the tier chosen, what changed (files, one line each), the final verdict, where the evidence is, and the run-directory path. Keep it short — the artifacts are the audit log.
