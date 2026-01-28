# Prompt Pack

> How to use the agentic workflow prompts effectively.

This guide explains how to combine and customize the prompts in this directory for different scenarios.

---

## Available Prompts

| Prompt | Role | When to Use |
|--------|------|-------------|
| [CLAUDE_CODE_SYSTEM.md](CLAUDE_CODE_SYSTEM.md) | System | Always — base configuration |
| [WORKFLOW_MANAGER.md](WORKFLOW_MANAGER.md) | Manager | Multi-task orchestration |
| [WORKFLOW_PLANNER.md](WORKFLOW_PLANNER.md) | Planner | Designing implementations |
| [WORKFLOW_IMPLEMENTER.md](WORKFLOW_IMPLEMENTER.md) | Implementer | Writing code/docs |
| [WORKFLOW_TESTER.md](WORKFLOW_TESTER.md) | Tester | Validating changes |
| [WORKFLOW_REVIEWER.md](WORKFLOW_REVIEWER.md) | Reviewer | Quality assurance |

---

## Usage Patterns

### Pattern 1: Single Agent, Full Cycle

For most tasks, one agent performs all roles sequentially.

```
1. Load CLAUDE_CODE_SYSTEM.md as system prompt
2. Agent performs: Plan → Implement → Test → Self-Review
3. Human reviews at C3
```

**Best for**: Standard feature development, documentation updates, bug fixes.

### Pattern 2: Specialized Roles

For complex or sensitive work, use role-specific prompts.

```
1. Load CLAUDE_CODE_SYSTEM.md + WORKFLOW_PLANNER.md
2. Planner produces plan
3. Human approves plan
4. Load CLAUDE_CODE_SYSTEM.md + WORKFLOW_IMPLEMENTER.md
5. Implementer executes plan
6. ...continue with Tester and Reviewer prompts
```

**Best for**: Architecture changes, security-sensitive work, team collaboration.

### Pattern 3: Manager-Led Orchestration

For large initiatives with multiple tasks.

```
1. Load CLAUDE_CODE_SYSTEM.md + WORKFLOW_MANAGER.md
2. Manager decomposes objective into tasks
3. Each task follows Pattern 1 or 2
4. Manager tracks completion
```

**Best for**: Multi-day projects, epic-level work, complex refactoring.

---

## Combining Prompts

Prompts can be combined by concatenation:

```
[CLAUDE_CODE_SYSTEM.md content]

---

[WORKFLOW_PLANNER.md content]
```

The system prompt establishes base behavior; the role prompt adds specificity.

---

## Customization

### Adding Constraints

Append project-specific rules:

```
## Additional Constraints for This Project
- All new files must have copyright header
- Maximum function length: 50 lines
- Use British English spelling
```

### Adjusting Iteration Limits

Override defaults in the system prompt:

```
## Custom Limits
- Max iterations per file: 3 (instead of 5)
- Max files per PR: 5 (instead of 10)
```

### Adding Quality Checks

Extend the Tester prompt:

```
## Additional Checks
- Accessibility audit (if UI changes)
- Performance benchmark (if critical path)
```

---

## Common Scenarios

### Scenario: Documentation Update

1. Use system prompt only
2. Agent performs full cycle
3. Focus on link validation and style consistency

### Scenario: Bug Fix

1. Use system prompt only
2. Emphasize root cause analysis in planning
3. Require regression test in testing phase

### Scenario: New Feature

1. Use Planner prompt for design
2. Human approves architecture
3. Use Implementer prompt for development
4. Use Tester + Reviewer prompts for validation

### Scenario: Security Patch

1. Use Planner prompt with security focus
2. Mandatory human approval at C1
3. Use Tester prompt with security checks
4. Mandatory security review at C3

---

## Anti-Patterns

### Don't: Skip the System Prompt
Always include CLAUDE_CODE_SYSTEM.md as the foundation.

### Don't: Combine Conflicting Roles
Planner and Implementer in same prompt can cause confusion. Use sequentially.

### Don't: Override Core Rules
The escalation and checkpoint rules exist for safety. Customize, don't disable.

---

## Debugging

If agent behavior seems wrong:

1. **Check prompt loading** — Is the full prompt included?
2. **Check context** — Does agent have access to required files?
3. **Check constraints** — Are rules being followed?
4. **Escalate** — Ask agent to explain its reasoning

---

## Version Compatibility

These prompts are designed for Claude-based agents. Adaptations may be needed for:
- OpenAI GPT models
- Other LLM providers
- Custom agent frameworks

---

*Use these prompts as starting points. Adapt to your specific needs.*
