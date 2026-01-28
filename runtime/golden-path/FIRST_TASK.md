# First Task: Documentation Link Fix

> A guided walkthrough of your first Issue→PR cycle.

This task walks you through the complete agentic workflow using a simple, achievable objective: fixing a documentation link.

---

## Task Description

**Objective**: Create a new file `docs/QUICK_LINKS.md` that provides shortcuts to the most important documents in this repository.

**Why this task?**
- Simple enough to complete quickly
- Touches multiple checkpoints
- Produces visible, useful output
- Low risk (documentation only)

---

## Checkpoint C0: Comprehension & Scope

### What to Do

1. Read the task description above
2. Understand the deliverable
3. Define the scope

### Your Output

```markdown
## C0 Verification

### Objective (in my own words)
Create a new file at docs/QUICK_LINKS.md that serves as a shortcut
reference to the most important documents in the repository.

### Scope
**In scope:**
- Creating docs/QUICK_LINKS.md
- Linking to 5-10 key documents
- Following existing documentation style

**Out of scope:**
- Modifying existing documents
- Adding new functionality
- Changing repository structure

### Questions
None — task is clear and self-contained.
```

**C0 Exit Criteria**: ✅ Objective understood, scope defined, no blocking questions

---

## Checkpoint C1: Plan & Risks

### What to Do

1. Identify which documents to include
2. Plan the file structure
3. Assess risks

### Your Output

```markdown
## C1 Plan

### Files to Create
- docs/QUICK_LINKS.md

### Content Plan
1. Header with purpose
2. Table of quick links organized by category:
   - Getting Started (README, REPO_MAP)
   - For Developers (LLM_USAGE_GUIDE, METHODOLOGY)
   - For Security (security checklist)
   - For Agentic Work (core/README, CHECKPOINTS)
3. Footer with navigation back to main docs

### Risks
| Risk | Level | Mitigation |
|------|-------|------------|
| Broken links | Low | Verify all links before commit |
| Missing key docs | Low | Review DOCUMENTATION_INDEX for completeness |

### Dependencies
- docs/ directory must exist (create if not)
```

**C1 Exit Criteria**: ✅ Plan documented, risks identified

---

## Checkpoint C2: Implementation & Tests

### What to Do

1. Create the docs directory if needed
2. Create QUICK_LINKS.md with content
3. Verify all links work

### Your Output

```markdown
## C2 Implementation

### Actions Taken
1. Created docs/ directory
2. Created docs/QUICK_LINKS.md with:
   - 8 quick links organized by category
   - Consistent markdown formatting
   - Navigation footer

### Verification
- [ ] All 8 links manually verified
- [ ] Markdown renders correctly
- [ ] File is under 50 lines (actual: 42)

### Test Output
Link check: 8/8 valid
```

**Example File Content**:

```markdown
# Quick Links

> Fast access to essential documentation.

## Getting Started
- [README](../../README.md) — Project overview
- [Repository Map](../../REPO_MAP.md) — Navigation guide

## For Developers
- [Methodology](../../METHODOLOGY.md) — Documentation approach

## For Security
- [Security Checklist](../../examples/php-symfony-k8s/02-security/07-security-checklist.md) — Pre-deployment validation (example)

## For Agentic Development
- [Core Specification](../../core/README.md) — Agentic-ready framework
- [Checkpoints](../../core/spec/CHECKPOINTS.md) — Validation gates
- [Escalation Rules](../../core/agent-operating-model/ESCALATION_RULES.md) — When to ask

---
*See [DOCUMENTATION_INDEX.md](../../DOCUMENTATION_INDEX.md) for complete file listing.*
```

**C2 Exit Criteria**: ✅ File created, links verified

---

## Checkpoint C3: PR & Proofs

### What to Do

1. Create PR with required sections
2. Attach proofs
3. Request review

### Your Output

```markdown
## Pull Request: Add Quick Links Document

### Summary
Creates a new quick links document to provide fast access to essential
documentation for different user profiles.

### Checkpoints Completed
- [x] C0: Comprehension & Scope
- [x] C1: Plan & Risks
- [x] C2: Implementation & Tests
- [x] C3: PR & Proofs

### Changes
- Created `docs/QUICK_LINKS.md` (42 lines)

### Testing
- Manual link verification: 8/8 links valid
- Markdown rendering: Verified in preview

### Risks
- Low: New file only, no changes to existing content

### Escalations
- None required
```

**C3 Exit Criteria**: ✅ PR created with all required sections

---

## Success Criteria

Your first task is complete when:

- [ ] docs/QUICK_LINKS.md exists
- [ ] Contains 5-10 quick links
- [ ] All links are valid
- [ ] PR includes all checkpoint documentation
- [ ] Human reviewer approves

---

## What You Learned

After completing this task, you've experienced:

1. **C0**: How to verify understanding before starting
2. **C1**: How to plan and assess risks
3. **C2**: How to implement and verify
4. **C3**: How to document and deliver

These patterns apply to every task, regardless of complexity.

---

## Next Steps

- Try a slightly more complex task
- Review [PROMPT_PACK.md](../prompts/PROMPT_PACK.md) for advanced workflows
- Explore [bench/](../../bench/) for benchmark tasks

---

*Congratulations on completing your first agentic workflow cycle.*
