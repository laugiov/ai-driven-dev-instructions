# Handoff Template

> Standardized format for passing work between agent roles.

A handoff is a structured transfer of context, objectives, and constraints from one role to another. This ensures continuity and prevents information loss during role transitions.

---

## Schema

```yaml
handoff:
  # Metadata
  id: "unique-handoff-id"
  timestamp: "ISO-8601 datetime"

  # Role transition
  from_role: [Manager|Planner|Implementer|Tester|Reviewer]
  to_role: [Manager|Planner|Implementer|Tester|Reviewer]

  # Objective
  objective: "Clear, actionable statement of what must be done"

  # Context
  context:
    issue_ref: "Issue or task reference"
    repo_sections:
      - "Relevant files or directories"
    prior_work:
      - "Summary of completed steps"
    constraints:
      - "Explicit limitations or rules"

  # Deliverables
  deliverables:
    - path: "file/path/to/create/or/modify"
      action: [create|modify|delete]
      acceptance:
        - "Criterion 1"
        - "Criterion 2"

  # Validation
  tests:
    - "Test or check to run"

  # Risk
  risks:
    - "Identified risk with mitigation"

  # Notes
  notes:
    - "Additional context or warnings"
```

---

## Required Fields

| Field | Required | Description |
|-------|----------|-------------|
| from_role | Yes | Originating role |
| to_role | Yes | Receiving role |
| objective | Yes | What must be accomplished |
| deliverables | Yes | At least one deliverable |
| deliverables[].acceptance | Yes | At least one acceptance criterion |

---

## Example: Planner → Implementer

```yaml
handoff:
  id: "HO-2026-01-28-001"
  timestamp: "2026-01-28T15:30:00Z"

  from_role: Planner
  to_role: Implementer

  objective: "Create ESCALATION_RULES.md defining when agents must request human validation"

  context:
    issue_ref: "Lot 1 - Agent Operating Model"
    repo_sections:
      - "core/agent-operating-model/"
      - "GLOSSARY.md"
    prior_work:
      - "AGENT_OPERATING_MODEL.md created with role definitions"
      - "RISK_MODEL.md created with taxonomy"
    constraints:
      - "Must align with existing escalation mentions in operating model"
      - "Keep document under 120 lines"

  deliverables:
    - path: "core/agent-operating-model/ESCALATION_RULES.md"
      action: create
      acceptance:
        - "Lists all mandatory escalation triggers"
        - "Defines escalation format (question + options + recommendation)"
        - "Documents response handling"
        - "Specifies timeout behavior"

  tests:
    - "All internal links resolve"
    - "Terminology matches GLOSSARY"

  risks:
    - "May overlap with RISK_MODEL.md - ensure clear separation"

  notes:
    - "Reference existing escalation language in AGENT_OPERATING_MODEL.md"
```

---

## Example: Implementer → Tester

```yaml
handoff:
  id: "HO-2026-01-28-002"
  timestamp: "2026-01-28T16:00:00Z"

  from_role: Implementer
  to_role: Tester

  objective: "Validate ESCALATION_RULES.md meets acceptance criteria and integrates correctly"

  context:
    issue_ref: "Lot 1 - Agent Operating Model"
    repo_sections:
      - "core/agent-operating-model/ESCALATION_RULES.md"
      - "core/agent-operating-model/AGENT_OPERATING_MODEL.md"
    prior_work:
      - "ESCALATION_RULES.md created with all required sections"
    constraints:
      - "Do not modify files, only validate"

  deliverables:
    - path: "validation-report"
      action: create
      acceptance:
        - "All links verified"
        - "All acceptance criteria checked"
        - "Issues documented with line numbers"

  tests:
    - "Link checker passes"
    - "Line count under 120"
    - "Required sections present"

  risks:
    - "None identified"

  notes:
    - "Report any terminology inconsistencies"
```

---

## Validation Rules

Before accepting a handoff, the receiving role should verify:

1. **Objective is actionable** — Can be completed without further clarification
2. **Context is sufficient** — All referenced files exist and are accessible
3. **Deliverables are specific** — Paths and acceptance criteria are concrete
4. **Constraints are clear** — No ambiguous limitations

If validation fails, return the handoff to the originating role with specific questions.

---

*All role transitions must use this format.*
