# AI-Driven Development Methodology

> A systematic approach to writing documentation that enables AI agents to autonomously implement software systems.

## What is AI-Driven Development?

AI-Driven Development (AIDD) is a methodology where technical documentation is specifically designed to be consumed and acted upon by AI coding assistants. Unlike traditional documentation written for human developers, AIDD documentation provides the explicit context, validation criteria, and decision rationale that AI agents need to work autonomously.

```
Traditional Development          AI-Driven Development
─────────────────────────        ─────────────────────────
Human reads documentation   →    AI agent reads documentation
Human interprets intent     →    AI follows explicit instructions
Human makes decisions       →    AI applies documented decisions
Human validates work        →    AI self-validates with checkpoints
Human asks for help         →    AI consults troubleshooting trees
```

## Core Principles

### 1. Explicit Over Implicit

AI agents cannot infer intent or read between the lines. Every decision, pattern, and constraint must be explicitly stated.

**Bad: Implicit instruction**
```markdown
Use a modern database for storing user data.
```

**Good: Explicit instruction**
```markdown
Use PostgreSQL 15+ for user data storage.

Justification:
- ACID compliance required for user financial data integrity
- JSONB support for flexible user preferences storage
- Row-level security for multi-tenant data isolation
- Native UUID support for distributed ID generation

Configuration:
- Connection pool: 20 connections minimum
- Statement timeout: 30 seconds
- Idle timeout: 10 minutes
```

### 2. Context Completeness

Each document must be self-contained enough for an AI agent to act without requiring external information.

**Required context elements:**
- Prerequisites (what to read first)
- Technology versions (exact, not "latest")
- Environment assumptions
- Dependencies and their purposes
- Expected inputs and outputs

### 3. Decision Justification

Every architectural, technical, or design decision includes:
- The decision itself
- Why this choice was made
- What alternatives were considered
- When to reconsider this decision

```markdown
## Decision: Use RabbitMQ for Message Queuing

**Decision**: RabbitMQ 3.12+ as the primary message broker.

**Rationale**:
- Flexible routing patterns (topic, fanout, direct exchanges)
- Built-in delivery guarantees and acknowledgments
- Lower operational complexity than Kafka for our throughput (<10k msg/sec)
- Native PHP library support (php-amqplib)

**Alternatives Considered**:
- Kafka: Rejected - overkill for current throughput, higher ops burden
- Redis Streams: Rejected - less mature, weaker delivery guarantees
- AWS SQS: Rejected - vendor lock-in, no local development option

**Reconsider When**:
- Throughput exceeds 50k messages/second sustained
- Event replay becomes a core requirement
- Long-term event storage (>7 days) is needed
```

### 4. Validation Checkpoints

AI agents need to verify their work. Every major section includes explicit validation criteria.

```markdown
## Validation Checkpoint: User Entity Implementation

Before proceeding, verify:

- [ ] `User` class is in `src/Domain/User/` directory
- [ ] Class is declared as `final readonly`
- [ ] Constructor validates all invariants
- [ ] `UserId` value object uses UUID v7
- [ ] `Email` value object validates format
- [ ] `equals()` method compares by ID only
- [ ] Unit tests cover all validation rules
- [ ] PHPStan level 9 passes with no errors

**Verification Commands**:
```bash
# Run static analysis
./vendor/bin/phpstan analyse src/Domain/User --level=9

# Run unit tests
./vendor/bin/phpunit tests/Unit/Domain/User

# Verify file location
ls -la src/Domain/User/User.php
```
```

### 5. Troubleshooting Decision Trees

When errors occur, AI agents need clear resolution paths.

```markdown
## Troubleshooting: Database Connection Failures

```
Error: "SQLSTATE[08006] Connection refused"
│
├── Q: Is PostgreSQL container running?
│   │   Check: docker ps | grep postgres
│   │
│   ├── No → Solution: docker-compose up -d postgres
│   │         Wait 10 seconds, retry connection
│   │
│   └── Yes → Continue to next question
│
├── Q: Is DATABASE_URL correctly configured?
│   │   Check: echo $DATABASE_URL
│   │   Expected: postgresql://user:pass@localhost:5432/dbname
│   │
│   ├── Wrong format → Fix .env file, see example below
│   │
│   └── Correct → Continue to next question
│
├── Q: Is the port accessible?
│   │   Check: nc -zv localhost 5432
│   │
│   ├── Connection refused → Check firewall, Docker network
│   │
│   └── Connection successful → Check credentials
│
└── Q: Are credentials correct?
        Check: psql -h localhost -U user -d dbname
        │
        ├── Authentication failed → Verify password in .env
        │
        └── Success → Issue is application-specific, check logs
```
```

### 6. Layered Navigation

Documentation is organized in layers for progressive context building.

```
Layer 1: Overview (5 min read)
├── What is this system?
├── Key technologies
└── High-level architecture

Layer 2: Architecture (30 min read)
├── Design patterns
├── Service boundaries
└── Communication patterns

Layer 3: Implementation (60+ min read)
├── Detailed specifications
├── Code examples
└── Database schemas

Layer 4: Reference (as needed)
├── API documentation
├── Configuration options
└── Troubleshooting guides
```

### 7. Task-Based Organization

Organize documentation by what the AI agent needs to accomplish, not by technical category.

**Traditional (category-based):**
```
/security/
  authentication.md
  authorization.md
  encryption.md
```

**AI-Driven (task-based):**
```
Task: Implement User Authentication
├── Read: security/authentication.md (OAuth2 flows)
├── Read: services/auth-service.md (implementation details)
├── Read: development/testing.md (how to test auth)
└── Validate: security/checklist.md (security requirements)
```

## Writing Checklist

Use this checklist when writing AI-driven documentation:

### Document Structure
- [ ] Clear title describing the content
- [ ] Prerequisites section with links to required reading
- [ ] Table of contents for documents > 500 words
- [ ] Logical section progression (overview → details → examples)
- [ ] Validation checkpoint at the end

### Content Quality
- [ ] No ambiguous pronouns ("it", "this", "that" without clear referent)
- [ ] All technical terms defined or linked to glossary
- [ ] Exact versions specified for all technologies
- [ ] Every decision includes justification
- [ ] Alternatives considered are documented

### Code Examples
- [ ] Complete and runnable (no `// ...` placeholders)
- [ ] Include file path comment at top
- [ ] Syntax highlighted with language identifier
- [ ] Follow coding standards documented in project
- [ ] Include expected output where relevant

### Navigation
- [ ] Cross-references use relative links
- [ ] Related documents are linked
- [ ] Next steps are clear
- [ ] Prerequisites link to actual files

### Validation
- [ ] Explicit success criteria provided
- [ ] Verification commands included
- [ ] Common errors and solutions documented
- [ ] Self-check questions where appropriate

## Anti-Patterns to Avoid

### 1. Implicit Knowledge

```markdown
<!-- Bad -->
Configure the service mesh appropriately.

<!-- Good -->
Configure Istio service mesh with the following settings:
- mTLS mode: STRICT (all traffic encrypted)
- Timeout: 30 seconds for all services
- Retry policy: 3 attempts with exponential backoff
```

### 2. Vague References

```markdown
<!-- Bad -->
See the security documentation for more details.

<!-- Good -->
See [Authentication & Authorization](examples/php-symfony-k8s/02-security/03-authentication-authorization.md)
for OAuth2 flow implementation details.
```

### 3. Outdated Information

```markdown
<!-- Bad -->
Use the latest version of Symfony.

<!-- Good -->
Use Symfony 7.x (tested with 7.0.3).
Minimum required: 7.0.0
```

### 4. Missing Context

```markdown
<!-- Bad -->
Run the migration command.

<!-- Good -->
Run the database migration:

Prerequisites:
- PostgreSQL is running (docker ps | grep postgres)
- DATABASE_URL is configured in .env

Command:
php bin/console doctrine:migrations:migrate --no-interaction

Expected output:
[OK] 3 migrations executed successfully
```

### 5. Pseudo-Code

```markdown
<!-- Bad -->
```php
function authenticate(user, password) {
    // validate credentials
    // generate token
    // return response
}
```

<!-- Good -->
```php
<?php
// filepath: src/Application/UseCase/AuthenticateUser.php

declare(strict_types=1);

namespace App\Application\UseCase;

final readonly class AuthenticateUser
{
    public function __construct(
        private UserRepositoryInterface $userRepository,
        private PasswordHasherInterface $passwordHasher,
        private TokenGeneratorInterface $tokenGenerator,
    ) {}

    public function execute(AuthenticateUserCommand $command): AuthenticationResult
    {
        $user = $this->userRepository->findByEmail($command->email);

        if ($user === null) {
            return AuthenticationResult::failed('User not found');
        }

        if (!$this->passwordHasher->verify($command->password, $user->passwordHash())) {
            return AuthenticationResult::failed('Invalid password');
        }

        $token = $this->tokenGenerator->generate($user);

        return AuthenticationResult::success($token);
    }
}
```
```

## Measuring Documentation Quality

### Quantitative Metrics

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Code example completeness | 100% | No `// ...` or pseudo-code |
| Cross-reference validity | 100% | All links resolve |
| Decision justification | 100% | Every decision has "why" |
| Validation checkpoints | 1 per major section | Count checkpoints |
| Prerequisites coverage | 100% | All files list prerequisites |

### Qualitative Indicators

- AI agent can implement feature without asking clarifying questions
- AI agent produces code matching documented patterns
- AI agent identifies and resolves errors using troubleshooting guides
- New team members can onboard using documentation alone

## Tools and Automation

### Link Validation
```bash
# Check for broken internal links
find . -name "*.md" -exec grep -l "\[.*\](.*\.md)" {} \; | \
  xargs -I {} markdown-link-check {}
```

### Code Example Validation
```bash
# Extract and syntax-check PHP examples
grep -Pzo '```php\n([\s\S]*?)```' *.md | php -l
```

### Documentation Linting
```bash
# Check markdown style
markdownlint "**/*.md" --config .markdownlint.json
```

## Further Reading

- [LLM_USAGE_GUIDE.md](examples/php-symfony-k8s/LLM_USAGE_GUIDE.md) - See these principles in action (PHP/Symfony example)
- [IMPLEMENTATION_ROADMAP.md](examples/php-symfony-k8s/IMPLEMENTATION_ROADMAP.md) - Task-based implementation plan (PHP/Symfony example)
- [CODE_EXAMPLES_INDEX.md](examples/php-symfony-k8s/CODE_EXAMPLES_INDEX.md) - Index of all code examples (PHP/Symfony example)
- [CONTRIBUTING.md](CONTRIBUTING.md) - How to contribute to this project

---

**This methodology is the foundation of AI-driven development. Master these principles to create documentation that enables truly autonomous software development.**
