# Case Study #1: Issue to PR

> A complete walkthrough of an agentic Issue→PR cycle.

This case study documents a real execution of the agentic workflow, demonstrating how an AI agent progresses from issue to merged PR.

---

## The Issue

**Title**: Add quick reference for escalation triggers

**Description**:
> Create a one-page quick reference listing all mandatory escalation triggers from ESCALATION_RULES.md. Should be scannable in under 30 seconds.

**Labels**: `enhancement`, `documentation`

---

## C0: Comprehension & Scope

### Agent's Understanding

```markdown
## Objective
Create a quick reference document that lists all mandatory escalation
triggers in a scannable format.

## Scope
**In scope**:
- Create new file: docs/ESCALATION_QUICKREF.md
- Extract triggers from ESCALATION_RULES.md
- Format for rapid scanning

**Out of scope**:
- Modifying ESCALATION_RULES.md
- Adding new escalation rules
- Detailed explanations (keep brief)

## Questions
None - requirements are clear.
```

**C0 Exit**: ✅ Passed — Objective clear, scope defined

---

## C1: Plan & Risks

### Implementation Plan

```markdown
## Approach
1. Read ESCALATION_RULES.md to extract all trigger categories
2. Create docs/ESCALATION_QUICKREF.md
3. Use table format for scanability
4. Add brief header explaining purpose
5. Link back to full document

## Files
| Path | Action | Description |
|------|--------|-------------|
| docs/ESCALATION_QUICKREF.md | Create | Quick reference table |

## Risks
| Risk | Level | Mitigation |
|------|-------|------------|
| Missing triggers | Low | Cross-check with source |
| Too verbose | Low | Strict word limits |

## Dependencies
- ESCALATION_RULES.md must be current
```

**C1 Exit**: ✅ Passed — Plan documented, risks identified

---

## C2: Implementation

### Actions Taken

1. Read `core/agent-operating-model/ESCALATION_RULES.md`
2. Identified 6 mandatory trigger categories
3. Created `docs/ESCALATION_QUICKREF.md`:

```markdown
# Escalation Quick Reference

> When to pause and ask for human input.

## Mandatory Triggers

| Category | Trigger | Action |
|----------|---------|--------|
| **Architecture** | New service, schema change, new dependency | Escalate before implementing |
| **Security** | Auth changes, crypto, secrets, access control | Escalate immediately |
| **Data** | PII handling, retention, migration | Escalate before implementing |
| **Compatibility** | Breaking API, deprecation, config changes | Escalate before implementing |
| **Uncertainty** | Multiple valid approaches, conflicting requirements | Escalate to clarify |
| **Iteration Limit** | Max attempts reached, repeated failures | Escalate with context |

## Quick Decision

**Ask yourself**: "Could this decision be wrong in a way that's hard to reverse?"

- **Yes** → Escalate
- **No** → Proceed

## Format

When escalating, provide:
1. What you tried
2. Why you're stuck
3. 2+ options with pros/cons
4. Your recommendation

---

*Full details: [ESCALATION_RULES.md](../core/agent-operating-model/ESCALATION_RULES.md)*
```

### Validation

- [x] All 6 categories from source included
- [x] Table format for scanning
- [x] Under 40 lines
- [x] Link to full document works

**C2 Exit**: ✅ Passed — Implementation complete, validation passing

---

## C3: PR & Proofs

### Pull Request

**Title**: Add escalation quick reference

**Body**:
```markdown
## Summary
Creates a scannable quick reference for mandatory escalation triggers,
making it easy to check when human input is required.

## Related Issue
Closes #42

## Checkpoints Completed
- [x] C0: Comprehension & Scope
- [x] C1: Plan & Risks
- [x] C2: Implementation & Tests
- [x] C3: PR & Proofs

## Changes
| File | Change |
|------|--------|
| docs/ESCALATION_QUICKREF.md | Created - 38 lines |

## Testing
- [x] Link validation: 1/1 links valid
- [x] Content review: All 6 triggers present
- [x] Scanability: Readable in <30 seconds

## Risks
| Risk | Level | Mitigation |
|------|-------|------------|
| None identified | - | - |

## Escalations
- [x] No escalations required
```

**C3 Exit**: ✅ Passed — PR complete with all required sections

---

## Outcome

### Metrics

| Metric | Value |
|--------|-------|
| Status | Pass |
| Iterations | 1 |
| Duration | 12 minutes |
| Files changed | 1 |
| Lines added | 38 |
| Escalations | 0 |
| Quality score | 9/10 |

### Human Review Feedback

> "Clean, scannable, exactly what was requested. The 'Quick Decision' section is a nice addition. Approved."

### Lessons Learned

1. **Simple tasks benefit from full workflow** — Even straightforward tasks produce better results with explicit checkpoints
2. **Scanability requires discipline** — Easy to over-explain; word limits help
3. **Links back to source** — Quick references should always point to full documentation

---

## Artifacts

- Issue: #42
- PR: #43
- File created: `docs/ESCALATION_QUICKREF.md`
- Time: 12 minutes total

---

*This case study demonstrates effective agentic execution on a documentation task.*
