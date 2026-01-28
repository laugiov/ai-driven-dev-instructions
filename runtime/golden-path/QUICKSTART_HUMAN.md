# Quickstart for Humans

> Get productive with agentic development in 15 minutes.

This guide walks you through setting up and understanding the agentic development workflow so you can effectively collaborate with AI agents.

---

## Prerequisites

Before starting, ensure you have:

- [ ] Access to this repository (cloned locally)
- [ ] A code editor (VS Code recommended)
- [ ] Basic understanding of git workflows
- [ ] Access to an AI agent (Claude Code or similar)

---

## Your First 15 Minutes

### Minute 0-3: Understand the Goal

Read [REPO_MAP.md](../../REPO_MAP.md) to understand:
- What this repository provides
- Where to find what you need
- The three main paths (methodology, security, agentic)

### Minute 3-7: Learn the Operating Model

Skim [AGENT_OPERATING_MODEL.md](../../core/agent-operating-model/AGENT_OPERATING_MODEL.md):
- The five roles (Manager, Planner, Implementer, Tester, Reviewer)
- The Plan→Act→Observe→Fix loop
- When agents escalate to you

### Minute 7-10: Understand Checkpoints

Review [CHECKPOINTS.md](../../core/spec/CHECKPOINTS.md):
- C0 through C4 validation gates
- What proofs are required at each stage
- Your role in approving checkpoints

### Minute 10-13: Know When You're Needed

Read [ESCALATION_RULES.md](../../core/agent-operating-model/ESCALATION_RULES.md):
- What triggers mandatory human input
- How agents present decisions to you
- How to respond effectively

### Minute 13-15: Ready to Start

You're now equipped to:
- Assign work to an agent
- Review agent escalations
- Approve checkpoint completions
- Merge agent-created PRs

---

## Working with Agents

### Assigning Work

Provide clear, unambiguous instructions:

```
Task: Add a PR template to the .github directory
Constraints: Follow existing template style
Reference: See core/templates/ for format guidance
```

### Responding to Escalations

When an agent escalates:
1. Read the context provided
2. Review the options presented
3. Make a decision
4. Provide rationale if helpful

### Approving Checkpoints

At each checkpoint, verify:
- [ ] Required proofs are present
- [ ] Quality meets standards
- [ ] No regressions introduced

---

## Common Tasks

| Task | What You Do |
|------|-------------|
| Start new work | Create issue or describe task |
| Review plan | Approve agent's C1 checkpoint |
| Code review | Review PR at C3 checkpoint |
| Make decisions | Respond to escalations |
| Monitor | Check C4 post-merge (optional) |

---

## Next Steps

1. Complete [FIRST_TASK.md](FIRST_TASK.md) — Your first guided Issue→PR
2. Explore [PROMPT_PACK.md](../prompts/PROMPT_PACK.md) — How agent prompts work
3. Review [definition-of-done.md](../quality-gates/definition-of-done.md) — Quality standards

---

## Quick Reference

| Document | When to Reference |
|----------|-------------------|
| CHECKPOINTS.md | Validating agent work |
| ESCALATION_RULES.md | Understanding agent requests |
| HANDOFF_TEMPLATE.md | Reviewing task transitions |
| RISK_MODEL.md | Assessing change impact |

---

*You're ready to work with AI agents effectively.*
