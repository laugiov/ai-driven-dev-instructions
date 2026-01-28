# Core — Agentic-Ready Specification

> **What does it mean for a repository to be "agentic-ready"?**

This directory contains the normative specification for AI-driven development workflows. It defines the rules, checkpoints, and templates that make autonomous agent execution predictable, safe, and auditable.

---

## Contents

| Directory | Purpose | Status |
|-----------|---------|--------|
| [spec/](spec/) | AIDD specification and checkpoints | ✅ Active |
| [agent-operating-model/](agent-operating-model/) | Roles, workflows, escalation rules | ✅ Active |
| [templates/](templates/) | Issue, PR, and ADR templates | ✅ Active |

---

## Specification (`spec/`)

| Document | Description |
|----------|-------------|
| [CHECKPOINTS.md](spec/CHECKPOINTS.md) | Validation gates (C0-C4) with entry/exit criteria and proof requirements |

**Planned**:
- AIDD_SPEC.md — Normative MUST/SHOULD/MAY rules
- CONFORMANCE.md — How to verify compliance

---

## Agent Operating Model (`agent-operating-model/`)

| Document | Description |
|----------|-------------|
| [AGENT_OPERATING_MODEL.md](agent-operating-model/AGENT_OPERATING_MODEL.md) | Roles (Manager, Planner, Implementer, Tester, Reviewer) and the Plan→Act→Observe→Fix workflow |
| [HANDOFF_TEMPLATE.md](agent-operating-model/HANDOFF_TEMPLATE.md) | Standardized YAML format for role transitions |
| [ESCALATION_RULES.md](agent-operating-model/ESCALATION_RULES.md) | When and how agents request human validation |
| [RISK_MODEL.md](agent-operating-model/RISK_MODEL.md) | Risk taxonomy, levels, and mitigation strategies |

---

## Templates (`templates/`)

| Document | Description |
|----------|-------------|
| [ADR_TEMPLATE.md](templates/ADR_TEMPLATE.md) | Architecture Decision Record format |

**Planned**:
- ISSUE_TEMPLATE_FEATURE.md
- ISSUE_TEMPLATE_BUG.md
- ISSUE_TEMPLATE_SECURITY.md
- PR_TEMPLATE.md

---

## Quick Reference

### The Five Roles

| Role | Responsibility |
|------|----------------|
| **Manager** | Orchestration, task decomposition, progress monitoring |
| **Planner** | Analysis, design, risk assessment |
| **Implementer** | Code production, file modifications |
| **Tester** | Verification, test execution, validation |
| **Reviewer** | Quality assurance, compliance, approval |

### The Workflow Loop

```
PLAN → ACT → OBSERVE → FIX → [CHECKPOINT or ESCALATE]
```

### The Checkpoints

| Gate | Purpose |
|------|---------|
| C0 | Comprehension & Scope confirmed |
| C1 | Plan & Risks validated |
| C2 | Implementation & Tests pass |
| C3 | PR complete with proofs |
| C4 | Post-merge monitoring (optional) |

---

## Design Principles

1. **Explicit over implicit** — Every rule documented, every decision justified
2. **Machine-checkable where possible** — Automated validation over manual review
3. **Human at the gates** — Autonomy within bounds, escalation when needed
4. **Minimal viable bureaucracy** — Only structure that adds value

---

## Getting Started

1. Read [AGENT_OPERATING_MODEL.md](agent-operating-model/AGENT_OPERATING_MODEL.md) to understand how agents work
2. Review [CHECKPOINTS.md](spec/CHECKPOINTS.md) to understand validation requirements
3. Study [ESCALATION_RULES.md](agent-operating-model/ESCALATION_RULES.md) to know when to ask for help
4. Use [HANDOFF_TEMPLATE.md](agent-operating-model/HANDOFF_TEMPLATE.md) for role transitions

---

*See [../REPO_MAP.md](../REPO_MAP.md) for navigation guidance.*
