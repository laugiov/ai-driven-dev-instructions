# Quickstart for Agents

> How to operate effectively within this repository as an AI agent.

This guide provides the file reading order, extraction strategy, and execution guidelines for AI agents working on this repository.

---

## Initial Context Loading

### Priority 1: Core Understanding (Read First)

| Order | File | Extract |
|-------|------|---------|
| 1 | `README.md` | Repository purpose, structure overview |
| 2 | `REPO_MAP.md` | Navigation paths, key concepts |
| 3 | `core/README.md` | What agentic-ready means |

### Priority 2: Operating Rules (Read Before Working)

| Order | File | Extract |
|-------|------|---------|
| 4 | `core/agent-operating-model/AGENT_OPERATING_MODEL.md` | Roles, workflow loop, stop conditions |
| 5 | `core/spec/CHECKPOINTS.md` | C0-C4 gates, required proofs |
| 6 | `core/agent-operating-model/ESCALATION_RULES.md` | When to pause and ask |

### Priority 3: Execution Guidance (Read When Needed)

| File | When to Read |
|------|--------------|
| `core/agent-operating-model/HANDOFF_TEMPLATE.md` | Transitioning between roles |
| `core/agent-operating-model/RISK_MODEL.md` | Assessing change impact |
| `core/templates/ADR_TEMPLATE.md` | Making architectural decisions |
| `runtime/quality-gates/definition-of-done.md` | Validating completeness |

---

## First Task Execution

### Step 1: Comprehension (C0)

1. Read the task description completely
2. Identify affected files and components
3. State the objective in your own words
4. List what's in scope and out of scope
5. Raise questions if anything is unclear

### Step 2: Planning (C1)

1. Analyze existing code in affected areas
2. Design your approach
3. List files to create or modify
4. Identify risks using RISK_MODEL categories
5. Document your plan

### Step 3: Implementation (C2)

1. Execute changes per plan
2. Follow existing code patterns
3. Run available tests locally
4. Fix issues iteratively (max 5 iterations)
5. Document any deviations

### Step 4: Delivery (C3)

1. Create PR with required sections
2. Attach all proof artifacts
3. Self-review changes
4. Request human review

---

## Execution Rules

### Always Do

- Read relevant files before modifying
- Work in small, atomic changes
- Provide proofs at each checkpoint
- Escalate when uncertain
- Document your reasoning

### Never Do

- Skip checkpoints
- Exceed iteration limits without escalating
- Make architecture changes without ADR
- Ignore test failures
- Assume when you should ask

---

## Escalation Protocol

When you must escalate:

1. **Stop** current execution
2. **Document** what you attempted
3. **Format** escalation per ESCALATION_RULES.md
4. **Wait** for human response
5. **Resume** only after receiving guidance

---

## Output Format

### For Plans

```markdown
## Plan: [Task Name]

### Objective
[Clear statement]

### Files to Modify
- path/to/file1.md — [change description]
- path/to/file2.md — [change description]

### Risks
- [Risk 1]: [Mitigation]

### Checkpoints
- C0: [How verified]
- C1: [How verified]
```

### For PRs

Use the template in [CHECKPOINTS.md](../../core/spec/CHECKPOINTS.md#pr-template-requirements).

---

## Quick Commands Reference

| Action | Guidance |
|--------|----------|
| Reading codebase | Start with README, follow imports |
| Making changes | Small commits, clear messages |
| Running tests | Execute all relevant test suites |
| Creating docs | Follow existing style |
| Asking questions | Use escalation format |

---

## Integration Points

- System prompt: [CLAUDE_CODE_SYSTEM.md](../prompts/CLAUDE_CODE_SYSTEM.md)
- Role prompts: [runtime/prompts/](../prompts/)
- Quality gates: [runtime/quality-gates/](../quality-gates/)

---

*Follow this guide to operate effectively within this framework.*
