# ADR Template

> Architecture Decision Record format for agentic development.

Use this template to document significant technical decisions. ADRs provide a historical record of choices made and their rationale.

---

## When to Write an ADR

Create an ADR when:
- Introducing a new technology or dependency
- Changing architectural patterns
- Modifying service boundaries
- Making security-related design choices
- Resolving an escalation with lasting implications

Do not create an ADR for:
- Implementation details within established patterns
- Bug fixes
- Minor refactoring
- Test additions

---

## Template

```markdown
# ADR-[NUMBER]: [SHORT TITLE]

**Status**: [Proposed | Accepted | Deprecated | Superseded by ADR-XXX]
**Date**: YYYY-MM-DD
**Decision Makers**: [Human approver, Agent role]

## Context

[Describe the situation that requires a decision. What problem are we solving?
What constraints exist? What is the current state?]

## Decision Drivers

- [Driver 1: e.g., "Need to support 10x current load"]
- [Driver 2: e.g., "Must maintain backward compatibility"]
- [Driver 3: e.g., "Security requirement X"]

## Considered Options

### Option A: [Name]
[Brief description]

**Pros**:
- [Advantage 1]
- [Advantage 2]

**Cons**:
- [Disadvantage 1]
- [Disadvantage 2]

### Option B: [Name]
[Brief description]

**Pros**:
- [Advantage 1]

**Cons**:
- [Disadvantage 1]

## Decision

[State the decision clearly. Which option was chosen?]

## Rationale

[Explain why this option was selected. Reference the decision drivers.]

## Consequences

### Positive
- [Positive outcome 1]
- [Positive outcome 2]

### Negative
- [Negative outcome or tradeoff 1]
- [Mitigation if any]

### Risks
- [Risk 1 and mitigation]

## Implementation Notes

[Any specific guidance for implementing this decision]

## Related

- [Link to related ADRs]
- [Link to relevant documentation]
- [Escalation ID if this resolved an escalation]
```

---

## Example

```markdown
# ADR-001: Use YAML for Handoff Format

**Status**: Accepted
**Date**: 2026-01-28
**Decision Makers**: Laurent (human), Planner (agent)

## Context

The agent operating model requires a standardized format for passing work
between roles. We need a format that is both human-readable and machine-parseable.

## Decision Drivers

- Must be readable without special tools
- Must support nested structures (context, deliverables)
- Must be easily validatable
- Should be familiar to developers

## Considered Options

### Option A: YAML
Human-readable data serialization format.

**Pros**:
- Highly readable
- Supports comments
- Well-known in DevOps community
- Good library support

**Cons**:
- Indentation-sensitive
- Multiple ways to represent same data

### Option B: JSON
Standard data interchange format.

**Pros**:
- Universal support
- Strict syntax

**Cons**:
- No comments
- Less readable for complex structures
- Verbose

## Decision

Use YAML for all handoff templates.

## Rationale

Readability is the primary concern for handoffs that may be inspected by humans.
YAML's comment support allows for inline documentation. The DevOps community
familiarity reduces learning curve.

## Consequences

### Positive
- Handoffs are easily readable in any text editor
- Can include explanatory comments

### Negative
- Must be careful with indentation
- Need YAML validation in tooling

## Implementation Notes

- Use 2-space indentation consistently
- Prefer block style for multi-line strings
- Include JSON schema for validation

## Related

- HANDOFF_TEMPLATE.md
- Escalation from initial design discussion
```

---

## ADR Numbering

- Use sequential numbers: ADR-001, ADR-002, etc.
- Store in `docs/adr/` or similar dedicated location
- Never reuse numbers, even for deprecated ADRs

---

## ADR Lifecycle

1. **Proposed** — Under discussion
2. **Accepted** — Decision made, implementation proceeds
3. **Deprecated** — No longer recommended but still in effect
4. **Superseded** — Replaced by a newer ADR

---

*ADRs capture the "why" behind technical decisions.*
