# Runtime — Executing Agentic Workflows

> **How do you actually run an agentic development cycle?**

This directory contains everything needed to execute AI-driven development workflows. It bridges the normative specification (core/) with practical execution through quickstart guides, prompts, and quality gates.

---

## Contents

| Directory | Purpose | Status |
|-----------|---------|--------|
| [golden-path/](golden-path/) | Step-by-step guides for humans and agents | ✅ Active |
| [quality-gates/](quality-gates/) | Definition of Done, validation checks | ✅ Active |
| [prompts/](prompts/) | Agent prompts for Claude Code | ✅ Active |

---

## Golden Path (`golden-path/`)

| Document | Description |
|----------|-------------|
| [QUICKSTART_HUMAN.md](golden-path/QUICKSTART_HUMAN.md) | Get productive in 15 minutes (human perspective) |
| [QUICKSTART_AGENT.md](golden-path/QUICKSTART_AGENT.md) | File reading order and execution guidance (agent perspective) |
| [FIRST_TASK.md](golden-path/FIRST_TASK.md) | Your first Issue→PR guided walkthrough |
| [BOOTSTRAP_NEW_PROJECT.md](golden-path/BOOTSTRAP_NEW_PROJECT.md) | **Apply this methodology to your own project** |

---

## Quality Gates (`quality-gates/`)

| Document | Description |
|----------|-------------|
| [definition-of-done.md](quality-gates/definition-of-done.md) | What "done" means by change type, machine-checkable criteria |

**Planned**:
- repo_checks.md — Conformance and documentation hygiene
- security_checks.md — Security sanity checks

---

## Prompts (`prompts/`)

| Document | Description |
|----------|-------------|
| [CLAUDE_CODE_SYSTEM.md](prompts/CLAUDE_CODE_SYSTEM.md) | Core system prompt for Claude Code |
| [WORKFLOW_MANAGER.md](prompts/WORKFLOW_MANAGER.md) | Manager role — orchestration and coordination |
| [WORKFLOW_PLANNER.md](prompts/WORKFLOW_PLANNER.md) | Planner role — analysis and design |
| [WORKFLOW_IMPLEMENTER.md](prompts/WORKFLOW_IMPLEMENTER.md) | Implementer role — code production |
| [WORKFLOW_TESTER.md](prompts/WORKFLOW_TESTER.md) | Tester role — verification |
| [WORKFLOW_REVIEWER.md](prompts/WORKFLOW_REVIEWER.md) | Reviewer role — quality assurance |
| [PROMPT_PACK.md](prompts/PROMPT_PACK.md) | How to use and combine prompts |

---

## Quick Start

### For Humans

1. Read [QUICKSTART_HUMAN.md](golden-path/QUICKSTART_HUMAN.md) — 15-minute orientation
2. Complete [FIRST_TASK.md](golden-path/FIRST_TASK.md) — Guided walkthrough
3. Review [definition-of-done.md](quality-gates/definition-of-done.md) — Quality standards

### For Agents

1. Read [QUICKSTART_AGENT.md](golden-path/QUICKSTART_AGENT.md) — File reading order
2. Load [CLAUDE_CODE_SYSTEM.md](prompts/CLAUDE_CODE_SYSTEM.md) — System prompt
3. Follow [PROMPT_PACK.md](prompts/PROMPT_PACK.md) — Usage guidance

---

## Execution Philosophy

1. **Start small** — First task should take < 30 minutes
2. **Prove as you go** — Every checkpoint produces evidence
3. **Fail fast, escalate early** — Don't spin; ask for help
4. **Iterate to excellence** — Good enough ships, then improves

---

## How It All Connects

```
[Issue/Task]
     │
     ▼
[QUICKSTART_AGENT] ──── Read order & setup
     │
     ▼
[CLAUDE_CODE_SYSTEM] ── Base behavior
     │
     ├── [WORKFLOW_PLANNER] ──── C0, C1
     │
     ├── [WORKFLOW_IMPLEMENTER] ── C2
     │
     ├── [WORKFLOW_TESTER] ──── Validation
     │
     └── [WORKFLOW_REVIEWER] ── C3
              │
              ▼
    [definition-of-done] ── Quality gate
              │
              ▼
         [PR Merged]
```

---

*See [../REPO_MAP.md](../REPO_MAP.md) for navigation guidance.*
