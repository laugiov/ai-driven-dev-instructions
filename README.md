# AI-Driven Development Framework

[![Documentation](https://img.shields.io/badge/docs-99%20files-blue)](./DOCUMENTATION_INDEX.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

> A **technology-agnostic framework** for autonomous AI-driven software delivery — from Issue to PR with human oversight at defined checkpoints.

---

## What This Repo Is

1. **An agentic development framework** for autonomous Issue→PR workflows where AI agents plan, implement, test, and deliver with human oversight at defined checkpoints.

2. **A methodology** for writing unambiguous, security-by-design documentation that enables AI coding assistants to implement systems without drifting from standards.

3. **A complete example** demonstrating the methodology applied to a real-world platform (PHP/Symfony/Kubernetes).

## What This Repo Is NOT

- Not tied to any specific technology stack
- Not a prompt library or "magic" AI coding tricks
- Not autonomous execution without human supervision

---

## Start Here

| Your Goal | Start With |
|-----------|------------|
| **Apply to your own project** | [BOOTSTRAP_NEW_PROJECT.md](runtime/golden-path/BOOTSTRAP_NEW_PROJECT.md) |
| Explore agentic workflows | [core/README.md](core/README.md) |
| Understand the methodology | [METHODOLOGY.md](METHODOLOGY.md) |
| See a complete example | [examples/php-symfony-k8s/](examples/php-symfony-k8s/) |
| Find your path by profile | [REPO_MAP.md](REPO_MAP.md) |

---

## Repository Structure

```
├── [Framework]
│   ├── core/                  Agent operating model, checkpoints, templates
│   ├── runtime/               Quickstarts, prompts, quality gates
│   ├── bench/                 10 benchmark tasks, scoring, runner
│   └── tools/                 Validation utilities
│
├── [Examples]
│   └── php-symfony-k8s/       Complete reference implementation
│
├── [Methodology]              README, METHODOLOGY, GLOSSARY
├── [Case Studies]             case-studies/
└── [Supporting]               LICENSE, CONTRIBUTING, .github/
```

Full index: [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)

---

## The Framework

### Agent Operating Model

Defines how AI agents work autonomously within boundaries:
- **5 Roles**: Manager, Planner, Implementer, Tester, Reviewer
- **Workflow**: Plan → Act → Observe → Fix
- **Checkpoints**: C0 (scope) → C1 (plan) → C2 (implement) → C3 (PR)

See [core/agent-operating-model/](core/agent-operating-model/)

### Escalation Rules

When agents must pause and request human input:
- Architecture decisions
- Security concerns
- Multiple valid approaches
- Iteration limits reached

See [core/agent-operating-model/ESCALATION_RULES.md](core/agent-operating-model/ESCALATION_RULES.md)

### Quality Gates

Definition of Done by change type:
- Documentation, code, configuration, schema changes
- Machine-checkable and human-judgment criteria

See [runtime/quality-gates/](runtime/quality-gates/)

---

## Key Principles

### Explicit Over Implicit
Every decision includes justification. AI agents follow documented reasoning, not guesses.

### Validation Checkpoints
Every workflow stage includes verification criteria for self-validation.

### Human at the Checkpoints
Autonomous execution within bounds; escalation and approval at defined gates.

### Technology Agnostic
The framework applies to any stack. Adapt checkpoints and prompts to your tools.

---

## Examples

### PHP/Symfony/Kubernetes

A complete reference implementation with 52 documentation files:

| Area | Content |
|------|---------|
| Architecture | Hexagonal, DDD, microservices |
| Security | Zero Trust, OAuth2, Vault |
| Infrastructure | Kubernetes, Istio, observability |
| Development | Coding standards, testing, APIs |
| Operations | Monitoring, incident response, DR |

See [examples/php-symfony-k8s/](examples/php-symfony-k8s/)

*More examples welcome via contributions.*

---

## Metrics

| Metric | Value |
|--------|-------|
| Framework documents | 47 |
| Example documents | 52 |
| Benchmark tasks | 10 |
| Agent prompts | 6 |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License — See [LICENSE](LICENSE) for details.

## Author

**Laurent Giovannoni**

---

*A technology-agnostic framework for AI-driven software delivery.*
