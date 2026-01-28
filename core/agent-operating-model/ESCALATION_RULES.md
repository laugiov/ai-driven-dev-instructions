# Escalation Rules

> When and how agents must request human validation.

Escalation is the mechanism by which an agent pauses autonomous execution to request human input. This document defines mandatory triggers, the escalation format, and response handling.

---

## Mandatory Escalation Triggers

These situations **always** require human validation before proceeding:

### 1. Architecture Decisions

- New service or component introduction
- Changes to service boundaries
- Database schema modifications
- New external dependencies
- Communication pattern changes (sync → async, REST → events)

### 2. Security Decisions

- Authentication or authorization logic changes
- Cryptographic implementation decisions
- Secrets management modifications
- Access control policy changes
- Security vulnerability remediation approaches

### 3. Data Decisions

- PII handling changes
- Data retention policy modifications
- Cross-border data transfer implications
- Backup or recovery procedure changes
- Data migration strategies

### 4. Compatibility Decisions

- Breaking changes to public APIs
- Deprecation of features
- Configuration format changes
- Major version upgrades of dependencies

### 5. Uncertainty

- Multiple valid approaches with unclear preference
- Conflicting requirements in documentation
- Ambiguous acceptance criteria
- Missing context that blocks progress

### 6. Iteration Limits

- Max iterations reached without success
- Repeated failures with same error
- Blocking error that resists automated fix

---

## Escalation Format

When escalating, provide:

```yaml
escalation:
  trigger: "[category from above]"
  summary: "One-line description of what needs decision"

  context:
    what_was_attempted: "Brief description of work done"
    why_escalation: "Specific reason this requires human input"
    blocking_factor: "What prevents autonomous resolution"

  options:
    - id: "A"
      description: "First option"
      pros:
        - "Advantage 1"
      cons:
        - "Disadvantage 1"
      risk: "[low|medium|high]"

    - id: "B"
      description: "Second option"
      pros:
        - "Advantage 1"
      cons:
        - "Disadvantage 1"
      risk: "[low|medium|high]"

  recommendation:
    option: "A"
    rationale: "Why this option is recommended"

  information_needed:
    - "Specific question 1"
    - "Specific question 2"
```

---

## Response Handling

### Expected Human Response

```yaml
escalation_response:
  decision: "[A|B|other]"
  rationale: "Why this decision was made (optional)"
  additional_guidance: "Any extra instructions"
  constraints_added: "New constraints to respect"
```

### Agent Behavior After Response

1. **Acknowledge** — Confirm understanding of the decision
2. **Document** — Record decision in ADR if significant
3. **Resume** — Continue workflow with decision applied
4. **Validate** — Ensure implementation aligns with decision

---

## Timeout Behavior

| Scenario | Default Timeout | Action |
|----------|-----------------|--------|
| Standard escalation | 24 hours | Reminder notification |
| Blocking escalation | 4 hours | Work on other tasks if available |
| Critical escalation | 1 hour | Halt all related work |

If timeout is reached:
- Send reminder to human
- Do **not** proceed autonomously
- Do **not** make assumptions

---

## Non-Escalation Scenarios

These do **not** require escalation:

- Choosing between equivalent implementations (style preferences)
- Minor refactoring within established patterns
- Test additions that don't change behavior
- Documentation improvements
- Bug fixes with clear root cause and solution
- Dependency patch updates (non-breaking)

---

## Escalation Best Practices

1. **Be specific** — Vague escalations waste human time
2. **Provide context** — Include what was tried and why it failed
3. **Offer options** — Present at least two viable alternatives
4. **Make a recommendation** — Guide the human toward a decision
5. **Minimize frequency** — Escalate only when genuinely needed
6. **Batch when possible** — Group related questions in one escalation

---

## Tracking Escalations

Record all escalations for analysis:

| Field | Purpose |
|-------|---------|
| Timestamp | When escalation occurred |
| Trigger category | Which rule triggered it |
| Resolution time | How long until human responded |
| Decision | What was decided |
| Outcome | Did implementation succeed after decision |

This data helps identify patterns and improve autonomous capabilities over time.

---

*Escalation is a feature, not a failure. It ensures quality and safety.*
