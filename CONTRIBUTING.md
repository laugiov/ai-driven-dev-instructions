# Contributing to AI-Driven Development Instructions

Thank you for your interest in contributing to this project! This document provides guidelines for contributions.

## Table of Contents

1. [How to Contribute](#how-to-contribute)
2. [Documentation Standards](#documentation-standards)
3. [Code Examples Guidelines](#code-examples-guidelines)
4. [Pull Request Process](#pull-request-process)
5. [Style Guide](#style-guide)

## How to Contribute

### Types of Contributions Welcome

- **Documentation improvements**: Fix typos, clarify explanations, improve readability
- **New code examples**: Add practical, production-ready examples
- **New sections**: Expand coverage of topics not yet documented
- **Translations**: Help make this resource accessible in other languages
- **Bug fixes**: Fix broken links, incorrect references, outdated information
- **LLM optimization**: Improve navigation, add validation checkpoints, enhance cross-references

### Getting Started

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/improve-auth-docs`)
3. Make your changes
4. Test that all links work and examples are valid
5. Submit a pull request

## Documentation Standards

### File Naming

- Use lowercase with hyphens: `my-new-document.md`
- Prefix with section number: `01-architecture/07-new-topic.md`
- Be descriptive: `api-versioning-strategy.md` not `api-v.md`

### Document Structure

Every documentation file should follow this structure:

```markdown
# Title

## Overview

Brief description of what this document covers and why it matters.

## Prerequisites

What the reader should understand before reading this document.
Link to other documentation files.

## Table of Contents

For documents longer than 500 words.

## Main Content

Organized with clear headings (##, ###, ####).

## Code Examples

Practical, copy-paste ready examples.

## Validation Checkpoint

How to verify understanding or implementation.

## Related Documentation

Links to related files in this repository.
```

### Writing Style

- **Be explicit**: Don't assume prior knowledge
- **Justify decisions**: Explain WHY, not just WHAT
- **Provide context**: Help AI agents understand the reasoning
- **Use active voice**: "Use PostgreSQL" not "PostgreSQL should be used"
- **Be concise**: Avoid unnecessary words, but don't sacrifice clarity

## Code Examples Guidelines

### Requirements

All code examples must be:

1. **Complete**: No pseudo-code, no `// ...` placeholders
2. **Runnable**: Can be copied and executed directly
3. **Correct**: Syntactically valid and following best practices
4. **Commented**: Explain non-obvious parts

### Format

```php
<?php
// filepath: src/Domain/Entity/Example.php

declare(strict_types=1);

namespace App\Domain\Entity;

/**
 * Brief description of what this class does.
 */
final readonly class Example
{
    public function __construct(
        private string $id,
        private string $name,
    ) {
        // Validation logic here
    }
}
```

### Language-Specific Standards

| Language | Standards |
|----------|-----------|
| PHP | PSR-1, PSR-4, PSR-12, PHPStan Level 9 |
| YAML | 2-space indentation, quoted strings for special characters |
| JSON | 2-space indentation, trailing commas not allowed |
| Bash | ShellCheck compliant |

## Pull Request Process

### Before Submitting

- [ ] All links are valid (no broken references)
- [ ] Code examples are syntactically correct
- [ ] Spelling and grammar are correct
- [ ] File follows the document structure template
- [ ] Changes are consistent with existing documentation style

### PR Description Template

```markdown
## Summary

Brief description of changes.

## Type of Change

- [ ] Documentation improvement
- [ ] New content
- [ ] Bug fix (broken link, typo, etc.)
- [ ] Code example addition/improvement

## Checklist

- [ ] I have read the CONTRIBUTING.md guidelines
- [ ] My changes follow the documentation standards
- [ ] I have tested all links in my changes
- [ ] Code examples are complete and runnable
```

### Review Process

1. Maintainers will review within 5 business days
2. Address any requested changes
3. Once approved, changes will be merged

## Style Guide

### Markdown Formatting

- Use ATX-style headers (`#`, `##`, `###`)
- Use fenced code blocks with language identifier
- Use tables for structured data
- Use blockquotes for important notes
- Maximum line length: 120 characters (soft limit)

### Terminology

Use consistent terminology throughout:

| Preferred | Avoid |
|-----------|-------|
| AI agent | AI, bot, LLM |
| documentation | docs, doc |
| microservice | micro-service, service (when ambiguous) |
| repository | repo |

### Cross-References

Always use relative links:

```markdown
<!-- Good -->
See [Architecture Overview](examples/php-symfony-k8s/01-architecture/01-architecture-overview.md)

<!-- Avoid -->
See [Architecture Overview](/full/path/to/file.md)
```

## Questions?

If you have questions about contributing, please open an issue with the `question` label.

---

Thank you for contributing to making AI-driven development more accessible!
