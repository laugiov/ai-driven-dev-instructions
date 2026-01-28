# T007: Add Validation Script

## Objective

Create a simple Python script to validate markdown link integrity.

## Setup

Repository with markdown files containing internal links.

## Task Description

1. Create tools/validate_links.py
2. Script should find all .md files
3. Extract internal links (relative paths)
4. Verify each link target exists
5. Output pass/fail report

## Acceptance Criteria

- [ ] Script is executable
- [ ] Finds all markdown files recursively
- [ ] Correctly identifies internal links
- [ ] Reports broken links with file and line
- [ ] Exit code 0 for success, 1 for failures
- [ ] No external dependencies (stdlib only)

## Constraints

- Python 3.8+ compatible
- No external packages
- Under 100 lines
- Clear output format

## Expected Duration

30-40 minutes

## Difficulty

Medium
