# Development Standards

**Document Version**: 1.0
**Last Updated**: 2025-01-07
**Status**: Complete

## Table of Contents

1. [Overview](#overview)
2. [Development Workflow](#development-workflow)
3. [Git Workflow](#git-workflow)
4. [Branch Strategy](#branch-strategy)
5. [Commit Guidelines](#commit-guidelines)
6. [Code Review Process](#code-review-process)
7. [Development Environment Setup](#development-environment-setup)
8. [IDE Configuration](#ide-configuration)
9. [Local Development](#local-development)
10. [Documentation Standards](#documentation-standards)
11. [Quality Gates](#quality-gates)

## Overview

This document defines development standards and workflows for the AI Workflow Processing Platform. All developers must follow these standards to ensure code quality, consistency, and maintainability.

### Core Principles

1. **Code Quality**: Write clean, maintainable, testable code
2. **Consistency**: Follow established patterns and conventions
3. **Documentation**: Document complex logic and decisions
4. **Testing**: Write tests for all business logic
5. **Security**: Follow security best practices
6. **Performance**: Consider performance implications
7. **Collaboration**: Effective code reviews and knowledge sharing

## Development Workflow

### Standard Development Flow

```
1. Pick task from backlog
   ↓
2. Create feature branch
   ↓
3. Implement feature with tests
   ↓
4. Run local quality checks
   ↓
5. Push and create Pull Request
   ↓
6. Code review and approval
   ↓
7. CI/CD pipeline runs
   ↓
8. Merge to main
   ↓
9. Automatic deployment to staging
   ↓
10. Manual deployment to production
```

### Task Management

**Issue Tracking**: GitHub Issues / Jira

**Issue Template**:
```markdown
## Description
Clear description of the feature/bug

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Tests written
- [ ] Documentation updated

## Technical Notes
Implementation details, API changes, etc.

## Related Issues
#123, #456
```

## Git Workflow

### Repository Structure

```
platform-monorepo/
├── services/
│   ├── llm-agent-service/
│   ├── workflow-orchestrator-service/
│   └── ...
├── shared/
│   ├── common/
│   ├── contracts/
│   └── testing/
├── infrastructure/
│   ├── terraform/
│   ├── kubernetes/
│   └── helm/
└── docs/
```

### Git Configuration

```bash
# Set user information
git config --global user.name "Your Name"
git config --global user.email "your.email@company.com"

# Set default branch name
git config --global init.defaultBranch main

# Enable rebase on pull
git config --global pull.rebase true

# Set up GPG signing (recommended)
git config --global commit.gpgsign true
git config --global user.signingkey YOUR_GPG_KEY
```

## Branch Strategy

### Branch Types

| Branch Type | Naming | Purpose | Base Branch | Lifetime |
|-------------|--------|---------|-------------|----------|
| **main** | `main` | Production-ready code | - | Permanent |
| **develop** | `develop` | Integration branch | main | Permanent |
| **feature** | `feature/ISSUE-123-short-description` | New features | develop | Temporary |
| **bugfix** | `bugfix/ISSUE-123-short-description` | Bug fixes | develop | Temporary |
| **hotfix** | `hotfix/ISSUE-123-critical-bug` | Production fixes | main | Temporary |
| **release** | `release/v1.2.3` | Release preparation | develop | Temporary |

### Branch Naming Convention

```bash
# Feature branches
feature/LLM-123-add-temperature-control
feature/WF-456-implement-retry-logic

# Bug fix branches
bugfix/AUTH-789-fix-token-expiration
bugfix/VAL-321-handle-null-values

# Hotfix branches
hotfix/SEC-999-patch-vulnerability
hotfix/PERF-888-optimize-query
```

### Branch Lifecycle

**Creating a feature branch**:
```bash
# Update develop
git checkout develop
git pull origin develop

# Create feature branch
git checkout -b feature/LLM-123-add-temperature-control

# Push to remote
git push -u origin feature/LLM-123-add-temperature-control
```

**Updating from develop**:
```bash
# On feature branch
git fetch origin
git rebase origin/develop

# Resolve conflicts if any
git add .
git rebase --continue

# Force push (since history changed)
git push --force-with-lease
```

**Merging to develop**:
```bash
# Via Pull Request only (never direct push to develop)
# PR must be approved before merge
```

## Commit Guidelines

### Commit Message Format

Follow **Conventional Commits** specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Build process, dependencies, etc.
- `ci`: CI/CD changes

**Scope**: Service or component name (e.g., `llm-agent`, `workflow`, `auth`)

**Subject**: Imperative mood, lowercase, no period, max 50 chars

**Body**: Detailed explanation (optional, wrap at 72 chars)

**Footer**: Issue references, breaking changes

### Commit Message Examples

**Good commits**:
```
feat(llm-agent): add temperature parameter to completion request

Allows users to control the randomness of LLM responses by setting
a temperature value between 0 and 2.

Closes #LLM-123
```

```
fix(auth): resolve JWT token expiration race condition

The token validation was checking expiration before refreshing,
causing false negatives during high load. Now refreshes first,
then validates.

Fixes #AUTH-456
```

```
refactor(workflow): extract validation logic to separate class

Improves testability and separates concerns. No functional changes.

Related to #WF-789
```

**Bad commits**:
```
❌ Fixed bug
❌ WIP
❌ Updated code
❌ misc changes
```

### Atomic Commits

Each commit should be a logical unit:

```bash
# Good: Separate logical changes
git add src/Domain/LLMAgent/Entity/Temperature.php
git commit -m "feat(llm-agent): add Temperature value object"

git add src/Application/LLMAgent/Command/CreateCompletion.php
git commit -m "feat(llm-agent): add temperature to completion command"

git add tests/Unit/Domain/LLMAgent/Entity/TemperatureTest.php
git commit -m "test(llm-agent): add Temperature value object tests"

# Bad: Mixed changes in one commit
git add .
git commit -m "feat(llm-agent): add temperature feature"
```

### Commit Signing

All commits to `main` and `develop` must be signed:

```bash
# Generate GPG key
gpg --full-generate-key

# List keys
gpg --list-secret-keys --keyid-format=long

# Configure git
git config --global user.signingkey YOUR_KEY_ID
git config --global commit.gpgsign true

# Sign commits
git commit -S -m "feat(llm-agent): add feature"

# Verify signature
git log --show-signature
```

## Code Review Process

### Pull Request Requirements

**Before creating PR**:
- [ ] All tests pass locally
- [ ] Code follows coding guidelines
- [ ] No debug code or commented code
- [ ] Documentation updated
- [ ] CHANGELOG.md updated (for user-facing changes)

**PR Template**:
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix or feature causing existing functionality to change)
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] No new warnings
- [ ] Tests added that prove fix/feature works
- [ ] New and existing tests pass locally

## Screenshots (if applicable)

## Related Issues
Closes #123
Related to #456
```

### Review Process

1. **Self-Review**: Author reviews own code first
2. **Automated Checks**: CI pipeline must pass
3. **Peer Review**: At least 1 approval required (2 for critical changes)
4. **Security Review**: Required for authentication, authorization, data access
5. **Approval**: PR can be merged after all approvals

### Review Guidelines

**As a reviewer**:
- Review within 24 hours
- Be constructive and respectful
- Ask questions if unclear
- Suggest improvements, don't demand
- Approve when satisfied

**Review checklist**:
- [ ] Code is readable and maintainable
- [ ] Follows project conventions
- [ ] No obvious bugs
- [ ] Tests cover main scenarios
- [ ] Error handling is appropriate
- [ ] No security vulnerabilities
- [ ] Performance considerations addressed
- [ ] Documentation is clear

**Comment types**:
```
💡 Suggestion: Consider using dependency injection here
❓ Question: Why are we using setTimeout instead of proper async?
🐛 Bug: This will throw exception if array is empty
🔒 Security: This input needs validation
⚠️ Warning: This approach might have performance issues
✨ Nice: Great use of pattern matching here!
```

### Merge Strategy

**Squash and Merge** (recommended for feature branches):
```bash
# All feature branch commits squashed into one on develop
git checkout develop
git merge --squash feature/LLM-123-add-temperature
git commit -m "feat(llm-agent): add temperature parameter (#123)"
```

**Merge Commit** (for release branches):
```bash
# Preserves all commits
git checkout main
git merge --no-ff release/v1.2.3
```

**Rebase and Merge** (for hotfixes):
```bash
# Linear history
git checkout main
git rebase hotfix/SEC-999-patch-vulnerability
```

## Development Environment Setup

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| **PHP** | 8.3+ | Runtime |
| **Composer** | 2.6+ | Dependency management |
| **Docker** | 24+ | Local development |
| **Docker Compose** | 2.20+ | Multi-container orchestration |
| **Git** | 2.40+ | Version control |
| **Node.js** | 20+ | Frontend tooling |
| **kubectl** | 1.28+ | Kubernetes CLI |
| **Helm** | 3.12+ | Kubernetes package manager |

### Local Setup Script

```bash
#!/bin/bash
# setup-dev-env.sh

set -e

echo "🚀 Setting up development environment..."

# Check prerequisites
command -v docker >/dev/null 2>&1 || { echo "❌ Docker not installed"; exit 1; }
command -v php >/dev/null 2>&1 || { echo "❌ PHP not installed"; exit 1; }
command -v composer >/dev/null 2>&1 || { echo "❌ Composer not installed"; exit 1; }

# Install PHP dependencies
echo "📦 Installing PHP dependencies..."
composer install

# Install Git hooks
echo "🔗 Installing Git hooks..."
cp scripts/git-hooks/* .git/hooks/
chmod +x .git/hooks/*

# Start local services
echo "🐳 Starting local services..."
docker-compose up -d

# Wait for services
echo "⏳ Waiting for services to be ready..."
sleep 10

# Run migrations
echo "🗄️  Running database migrations..."
docker-compose exec app php bin/console doctrine:migrations:migrate --no-interaction

# Load fixtures (dev data)
echo "🌱 Loading development data..."
docker-compose exec app php bin/console doctrine:fixtures:load --no-interaction

# Run tests
echo "🧪 Running tests..."
docker-compose exec app php bin/phpunit

echo "✅ Development environment ready!"
echo "🌐 Application: http://localhost:8000"
echo "📊 Grafana: http://localhost:3000 (admin/admin)"
echo "🗄️  Adminer: http://localhost:8080"
```

### Docker Compose for Local Development

```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.dev
    ports:
      - "8000:8000"
    volumes:
      - .:/app
      - /app/vendor
    environment:
      APP_ENV: dev
      DATABASE_URL: postgresql://postgres:password@postgres:5432/platform
      REDIS_URL: redis://redis:6379
      RABBITMQ_URL: amqp://guest:guest@rabbitmq:5672
    depends_on:
      - postgres
      - redis
      - rabbitmq

  postgres:
    image: postgres:15-alpine
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: platform
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  rabbitmq:
    image: rabbitmq:3-management-alpine
    ports:
      - "5672:5672"
      - "15672:15672"
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest

  adminer:
    image: adminer
    ports:
      - "8080:8080"

volumes:
  postgres_data:
```

## IDE Configuration

### PhpStorm Configuration

**Code Style**:
1. File → Settings → Editor → Code Style → PHP
2. Set From... → PSR-12
3. Set tab size: 4 spaces
4. Enable: "Add a comma after last element in multiline array"

**Inspections**:
1. Enable all PHP inspections
2. Enable Symfony plugin
3. Enable PHPStan integration (level 9)

**File Templates**:
```php
<?php

declare(strict_types=1);

namespace ${NAMESPACE};

/**
 * ${NAME}
 */
final class ${NAME}
{
    public function __construct()
    {
    }
}
```

### VS Code Configuration

```json
// .vscode/settings.json
{
  "php.validate.executablePath": "/usr/local/bin/php",
  "php.suggest.basic": false,
  "files.associations": {
    "*.php": "php"
  },
  "[php]": {
    "editor.defaultFormatter": "bmewburn.vscode-intelephense-client",
    "editor.formatOnSave": true,
    "editor.tabSize": 4,
    "editor.insertSpaces": true
  },
  "phpstan.level": "9",
  "phpstan.enableLanguageServer": true
}
```

**Recommended Extensions**:
- PHP Intelephense
- PHPStan
- PHP Debug
- PHP DocBlocker
- EditorConfig
- GitLens

## Local Development

### Running Locally

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f app

# Run specific service
docker-compose up -d app postgres redis

# Execute commands in container
docker-compose exec app php bin/console cache:clear
docker-compose exec app composer install

# Run tests
docker-compose exec app php bin/phpunit

# Stop services
docker-compose down

# Clean everything (including volumes)
docker-compose down -v
```

### Development Commands

```bash
# Clear cache
php bin/console cache:clear

# Run migrations
php bin/console doctrine:migrations:migrate

# Generate migration
php bin/console doctrine:migrations:diff

# Load fixtures
php bin/console doctrine:fixtures:load

# Run tests
php bin/phpunit

# Run PHPStan
vendor/bin/phpstan analyse --level=9 src

# Run PHP CS Fixer
vendor/bin/php-cs-fixer fix src

# Start development server
symfony server:start -d
```

### Debugging

**Xdebug Configuration** (docker-compose.yml):
```yaml
environment:
  XDEBUG_MODE: debug
  XDEBUG_CONFIG: client_host=host.docker.internal
```

**PhpStorm Xdebug Setup**:
1. File → Settings → PHP → Debug
2. Port: 9003
3. Check "Break at first line in PHP scripts"
4. Add server mapping: `/app` → local project path

## Documentation Standards

### Code Documentation

**PHPDoc blocks** required for:
- All public methods
- Complex private methods
- Classes and interfaces

```php
<?php

/**
 * Processes LLM completion requests.
 *
 * This service handles all communication with the LLM provider,
 * manages rate limiting, and handles retries on failures.
 */
final class CompletionService
{
    /**
     * Create a completion from the given prompt.
     *
     * @param string $prompt The user prompt
     * @param array<string, mixed> $options Additional options (temperature, max_tokens, etc.)
     * @return CompletionResult The completion result
     * @throws RateLimitException If rate limit is exceeded
     * @throws LLMProviderException If the LLM provider returns an error
     */
    public function complete(string $prompt, array $options = []): CompletionResult
    {
        // Implementation
    }
}
```

### README Files

Every service must have a README.md:

```markdown
# LLM Agent Service

## Description
Service responsible for managing LLM interactions.

## Architecture
Hexagonal architecture with clear separation of concerns.

## Setup
\`\`\`bash
composer install
php bin/console doctrine:migrations:migrate
\`\`\`

## Testing
\`\`\`bash
php bin/phpunit
\`\`\`

## API Documentation
See [docs/api.md](docs/api.md)
```

### ADRs (Architecture Decision Records)

Document significant architectural decisions:

```markdown
# ADR-001: Use Hexagonal Architecture

## Status
Accepted

## Context
Need to structure services in a maintainable, testable way.

## Decision
Use hexagonal architecture (ports and adapters) for all services.

## Consequences
- **Positive**: Clear separation of concerns, easy testing
- **Negative**: More boilerplate code
- **Mitigation**: Use code generators for common patterns
```

## Quality Gates

### Pre-Commit Checks

```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "🔍 Running pre-commit checks..."

# PHPStan
echo "  Running PHPStan..."
vendor/bin/phpstan analyse --level=9 src || exit 1

# PHP CS Fixer
echo "  Running PHP CS Fixer..."
vendor/bin/php-cs-fixer fix --dry-run --diff src || exit 1

# Tests
echo "  Running tests..."
php bin/phpunit || exit 1

echo "✅ All checks passed!"
```

### CI Pipeline Checks

Every PR must pass:
- ✅ PHPStan level 9
- ✅ PHP CS Fixer
- ✅ All unit tests
- ✅ All integration tests
- ✅ Security scan (Composer audit)
- ✅ Code coverage > 80%

See [../06-cicd/](../06-cicd/) for complete CI/CD configuration.

## Best Practices

1. **Keep commits small and focused**
2. **Write tests first (TDD)**
3. **Review your own code before creating PR**
4. **Update documentation with code changes**
5. **Don't commit commented-out code**
6. **Don't commit debug statements**
7. **Use meaningful variable names**
8. **Keep functions small (< 20 lines)**
9. **One class per file**
10. **Follow SOLID principles**

## References

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Git Flow](https://nvie.com/posts/a-successful-git-branching-model/)
- [Code Review Best Practices](https://google.github.io/eng-practices/review/)

## Related Documentation

- [02-coding-guidelines-php.md](02-coding-guidelines-php.md) - PHP coding standards
- [04-testing-strategy.md](04-testing-strategy.md) - Testing guidelines
- [../05-code-review/01-code-review-checklist.md](../05-code-review/01-code-review-checklist.md) - Review checklist

---

**Document Maintainers**: Engineering Team
**Review Cycle**: Quarterly
**Next Review**: 2025-04-07
