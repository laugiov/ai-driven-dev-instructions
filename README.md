# AI-Driven Development Instructions

[![Documentation](https://img.shields.io/badge/docs-99%20files-blue)](./DOCUMENTATION_INDEX.md)
[![Code Examples](https://img.shields.io/badge/examples-500%2B-orange)](./CODE_EXAMPLES_INDEX.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

> A reference framework for **secure, auditable AI-assisted software delivery** — from documentation methodology to autonomous agentic workflows.

---

## What This Repo Is

1. **A methodology** for writing unambiguous, security-by-design documentation that enables AI coding assistants to implement systems without drifting from standards.

2. **A reference implementation** demonstrating the methodology through a complete platform specification (PHP 8.3, Symfony 7, Kubernetes).

3. **An agentic development framework** for autonomous Issue→PR workflows where AI agents plan, implement, test, and deliver with human oversight at defined checkpoints.

## What This Repo Is NOT

- Not a prompt library or "magic" AI coding tricks
- Not a full product implementation
- Not a universal agent or model comparison
- Not autonomous execution without human supervision

---

## Start Here

| Your Goal | Start With |
|-----------|------------|
| Understand the methodology | [METHODOLOGY.md](METHODOLOGY.md) |
| Navigate as an AI agent | [LLM_USAGE_GUIDE.md](LLM_USAGE_GUIDE.md) |
| Evaluate security practices | [02-security/07-security-checklist.md](02-security/07-security-checklist.md) |
| Explore agentic workflows | [core/README.md](core/README.md) |
| **Apply to your own project** | [BOOTSTRAP_NEW_PROJECT.md](runtime/golden-path/BOOTSTRAP_NEW_PROJECT.md) |
| Find your path by profile | [REPO_MAP.md](REPO_MAP.md) |

---

## Repository Structure

```
├── [Methodology & Guides]     README, METHODOLOGY, LLM_USAGE_GUIDE, REPO_MAP
├── [Reference Specs]          01-architecture/ through 08-services/
├── [Agentic Framework]
│   ├── core/                  Specification, operating model, templates
│   ├── runtime/               Quickstarts, prompts, quality gates
│   ├── bench/                 10 benchmark tasks, scoring, runner
│   └── tools/                 Validation utilities
├── [Case Studies]             case-studies/
└── [Supporting]               LICENSE, CONTRIBUTING, .github/
```

Full index: [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)

---

## Key Principles

### Explicit Over Implicit
Every decision includes justification. AI agents follow documented reasoning, not guesses.

### Validation Checkpoints
Every workflow stage includes verification criteria for self-validation.

### Security Gates as Code
Security requirements become enforceable pipeline gates, not optional guidelines.

### Human at the Checkpoints
Autonomous execution within bounds; escalation and approval at defined gates.

---

## Security & Compliance

Includes enterprise-grade security guidance: Zero Trust Architecture, IAM & Secrets Management, Network & Data Protection, Incident Response, and alignment with GDPR, SOC2, ISO27001, and NIS2.

---

## Technology Stack (Reference Example)

| Category | Technology |
|----------|------------|
| Language | PHP 8.3+ / Symfony 7.x |
| Database | PostgreSQL 15+ |
| Message Broker | RabbitMQ 3.12+ |
| Orchestration | Kubernetes 1.28+ / Istio 1.20+ |
| Security | Keycloak, HashiCorp Vault |
| Observability | Prometheus, Grafana, Loki, Tempo |
| CI/CD | GitHub Actions + ArgoCD |

---

## Metrics

| Metric | Value |
|--------|-------|
| Documentation files | 99 |
| Words | ~250,000 |
| Code examples | 500+ |
| Microservices documented | 7 |
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

*A framework for secure, auditable AI-assisted software delivery.*
