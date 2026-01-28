# Agent Operating Model

> How AI agents work autonomously within defined boundaries.

This document defines the roles, workflow loop, and execution rules that govern agentic development. It provides the foundation for predictable, auditable AI-assisted software delivery.

---

## Roles

An agentic workflow involves five distinct roles. A single agent may perform multiple roles sequentially, or specialized agents may handle each role.

### Manager

**Responsibility**: Orchestration and coordination.

- Decomposes objectives into discrete tasks
- Assigns work to appropriate roles
- Monitors progress and checkpoint completion
- Triggers escalations when thresholds are exceeded
- Maintains project-level context

### Planner

**Responsibility**: Analysis and design.

- Reads and understands existing codebase
- Identifies files to create or modify
- Assesses risks and dependencies
- Produces structured implementation plans
- Hands off to Implementer with clear deliverables

### Implementer

**Responsibility**: Code production.

- Executes the plan from Planner
- Creates or modifies files as specified
- Follows coding standards and patterns
- Produces atomic, reviewable changes
- Documents deviations from plan

### Tester

**Responsibility**: Verification.

- Executes available test suites
- Runs lint, type checks, and static analysis
- Validates against acceptance criteria
- Reports issues with actionable details
- Confirms checkpoint requirements met

### Reviewer

**Responsibility**: Quality assurance.

- Reviews changes for correctness and clarity
- Checks compliance with standards
- Identifies potential regressions
- Validates proof artifacts
- Approves or requests revisions

---

## Workflow Loop

The core execution pattern follows a **Plan → Act → Observe → Fix** cycle.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐ │
│   │   PLAN   │───►│   ACT    │───►│ OBSERVE  │───►│   FIX    │ │
│   └──────────┘    └──────────┘    └──────────┘    └──────────┘ │
│        │                                               │        │
│        │              ┌──────────┐                     │        │
│        │              │ ESCALATE │◄────────────────────┤        │
│        │              └──────────┘                     │        │
│        │                   │                           │        │
│        │                   ▼                           │        │
│        │              [HUMAN]                          │        │
│        │                   │                           │        │
│        ▼                   ▼                           ▼        │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                    CHECKPOINT                           │  │
│   └─────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              ▼                                  │
│                         [SUCCESS]                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### PLAN

- Understand the objective and constraints
- Analyze existing code and context
- Identify approach and risks
- Produce structured deliverable list

### ACT

- Execute the planned changes
- Create or modify files
- Run initial validation
- Document what was done

### OBSERVE

- Run tests and checks
- Compare results to expectations
- Identify discrepancies
- Collect proof artifacts

### FIX

- Address failures from OBSERVE
- Iterate until checks pass
- If iteration limit reached → ESCALATE
- Document fixes and reasoning

### ESCALATE

- When autonomous resolution fails
- When human decision is required
- When risk threshold exceeded
- See [ESCALATION_RULES.md](ESCALATION_RULES.md)

---

## Stop Conditions

The workflow loop terminates when any of these conditions is met:

| Condition | Action |
|-----------|--------|
| **Success** | All checkpoint criteria satisfied → proceed to next phase |
| **Max iterations** | Limit reached (default: 5) → escalate to human |
| **Escalation triggered** | Mandatory human decision → pause and await input |
| **Blocking error** | Unrecoverable failure → escalate with diagnostics |
| **Scope change** | Requirements shifted → escalate for re-planning |

---

## Role Responsibility Matrix

| Activity | Manager | Planner | Implementer | Tester | Reviewer |
|----------|:-------:|:-------:|:-----------:|:------:|:--------:|
| Task decomposition | ● | ○ | | | |
| Codebase analysis | | ● | ○ | | |
| Implementation plan | | ● | | | |
| Code changes | | | ● | | |
| Test execution | | | | ● | |
| Static analysis | | | | ● | |
| Change review | | | | | ● |
| Escalation decision | ● | ○ | ○ | ○ | ○ |
| Checkpoint approval | | | | | ● |

**Legend**: ● Primary responsibility | ○ Supporting role

---

## Iteration Limits

Default limits to prevent infinite loops:

| Context | Max Iterations | Escalation After |
|---------|----------------|------------------|
| Single file fix | 3 | Escalate with diff |
| Multi-file change | 5 | Escalate with partial |
| Test failures | 5 | Escalate with logs |
| Build failures | 3 | Escalate immediately |

These limits are configurable per task via handoff metadata.

---

## Context Persistence

Between iterations, agents maintain:

- Current checkpoint status
- Files read and modified
- Test results and errors
- Decisions made and rationale
- Escalation history

Context is passed via [HANDOFF_TEMPLATE.md](HANDOFF_TEMPLATE.md) when transitioning between roles.

---

## Integration Points

- **Checkpoints**: See [../spec/CHECKPOINTS.md](../spec/CHECKPOINTS.md)
- **Escalations**: See [ESCALATION_RULES.md](ESCALATION_RULES.md)
- **Handoffs**: See [HANDOFF_TEMPLATE.md](HANDOFF_TEMPLATE.md)
- **Risk Assessment**: See [RISK_MODEL.md](RISK_MODEL.md)

---

*This model governs all agentic execution within this framework.*
