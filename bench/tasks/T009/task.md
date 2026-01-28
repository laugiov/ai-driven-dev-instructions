# T009: Implement Handoff Validator

## Objective

Create a script that validates handoff YAML against the schema.

## Setup

HANDOFF_TEMPLATE.md with schema definition.

## Task Description

1. Read the handoff schema from HANDOFF_TEMPLATE.md
2. Create tools/validate_handoff.py
3. Accept YAML file as input
4. Validate required fields are present
5. Validate field types
6. Report validation errors

## Acceptance Criteria

- [ ] Script accepts file path argument
- [ ] Validates all required fields
- [ ] Reports missing fields clearly
- [ ] Reports type mismatches
- [ ] Provides helpful error messages
- [ ] Exit codes indicate pass/fail

## Constraints

- Python 3.8+ compatible
- May use PyYAML (assume available)
- Under 150 lines
- Include usage help

## Expected Duration

40-50 minutes

## Difficulty

Hard
