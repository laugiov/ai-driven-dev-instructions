# Definition of Done

> What "done" means for different types of changes.

This document defines the criteria that must be satisfied before work is considered complete. Criteria are organized by change type and split into machine-checkable and human-judgment categories.

---

## Universal Criteria

These apply to ALL changes:

### Machine-Checkable
- [ ] No broken internal links
- [ ] No merge conflicts
- [ ] Commit messages follow convention
- [ ] All required files present

### Human-Judgment
- [ ] Change matches the original objective
- [ ] No unintended side effects
- [ ] Documentation is clear and accurate

---

## Documentation Changes

Changes to `.md` files, comments, or non-executable content.

### Machine-Checkable
- [ ] Markdown syntax valid
- [ ] Links resolve correctly
- [ ] Headings are unique within file
- [ ] Code blocks have language specifier
- [ ] Line length under 120 characters (soft limit)

### Human-Judgment
- [ ] Content is accurate
- [ ] Tone is professional
- [ ] Structure aids comprehension
- [ ] No unnecessary content
- [ ] Terminology is consistent

### Proof Artifacts
- Link check output
- Markdown lint output (if available)

---

## Code Changes

Changes to executable code (any language).

### Machine-Checkable
- [ ] Tests pass (existing + new)
- [ ] Lint passes (no new violations)
- [ ] Static analysis passes (type checks, etc.)
- [ ] Coverage not decreased
- [ ] No new security vulnerabilities (SAST)

### Human-Judgment
- [ ] Code is readable
- [ ] Follows existing patterns
- [ ] Appropriate error handling
- [ ] No over-engineering
- [ ] Comments where needed (not excessive)

### Proof Artifacts
- Test execution output
- Lint output
- Static analysis report
- Coverage report

---

## Configuration Changes

Changes to `.yaml`, `.json`, `.env`, infrastructure code.

### Machine-Checkable
- [ ] Syntax valid
- [ ] Schema validation passes (if schema exists)
- [ ] No secrets in plain text
- [ ] No hardcoded environment-specific values

### Human-Judgment
- [ ] Change is backwards compatible (or breaking change documented)
- [ ] Appropriate for all target environments
- [ ] Security implications considered

### Proof Artifacts
- Schema validation output
- Secrets scan output

---

## Schema Changes

Database migrations, API contract changes.

### Machine-Checkable
- [ ] Migration runs successfully
- [ ] Rollback tested
- [ ] No data loss in migration

### Human-Judgment
- [ ] Change is necessary
- [ ] Performance impact acceptable
- [ ] Backward compatibility considered
- [ ] Data privacy implications reviewed

### Proof Artifacts
- Migration execution log
- Rollback test log
- Performance benchmark (if applicable)

---

## Security-Sensitive Changes

Any change touching auth, crypto, access control, or sensitive data.

### Machine-Checkable
- [ ] SAST passes
- [ ] Dependency vulnerabilities checked
- [ ] No secrets committed

### Human-Judgment
- [ ] Security review completed
- [ ] Threat model updated (if applicable)
- [ ] Follows security principles
- [ ] Least privilege applied

### Proof Artifacts
- Security scan output
- Security review approval
- Threat model reference

---

## Checklist by Checkpoint

### C0 (Comprehension)
- [ ] Objective stated in own words
- [ ] Scope boundaries defined

### C1 (Plan)
- [ ] Implementation plan documented
- [ ] Risks identified and tagged

### C2 (Implementation)
- [ ] All changes implemented
- [ ] Local tests pass
- [ ] Lint/static analysis pass

### C3 (PR)
- [ ] PR description complete
- [ ] All proofs attached
- [ ] Review requested

### C4 (Post-Merge)
- [ ] No production errors
- [ ] Metrics within bounds

---

## Quality Thresholds

| Metric | Threshold |
|--------|-----------|
| Test coverage | >= 80% (for code changes) |
| Lint violations | 0 new violations |
| Static analysis | Pass at configured level |
| Documentation links | 100% valid |

---

## Exceptions

If a criterion cannot be met:

1. **Document** the exception clearly
2. **Explain** why it cannot be met
3. **Get approval** from human reviewer
4. **Track** as technical debt if appropriate

Never silently skip criteria.

---

*Done means done. Not "mostly done" or "done except for."*
