# Example: PHP/Symfony/Kubernetes Platform

> A complete reference implementation demonstrating the AI-Driven Development methodology.

This directory contains a comprehensive example of how to apply the agentic development framework to a real-world project: a cloud-native AI Workflow Processing Platform.

---

## What This Example Demonstrates

This example shows how to write **unambiguous, security-by-design documentation** that enables AI coding assistants to implement complex systems without drifting from architecture, security, and operations standards.

## Technology Stack

| Category | Technology |
|----------|------------|
| Language | PHP 8.3+ / Symfony 7.x |
| Database | PostgreSQL 15+ |
| Message Broker | RabbitMQ 3.12+ |
| Orchestration | Kubernetes 1.28+ / Istio 1.20+ |
| Security | Keycloak, HashiCorp Vault |
| Observability | Prometheus, Grafana, Loki, Tempo |
| CI/CD | GitHub Actions + ArgoCD |

## Contents

| Directory | Description | Files |
|-----------|-------------|-------|
| [01-architecture/](01-architecture/) | System design, ADRs, DDD patterns | 8 |
| [02-security/](02-security/) | Security-by-design, Zero Trust, compliance | 8 |
| [03-infrastructure/](03-infrastructure/) | Kubernetes, service mesh, observability | 6 |
| [04-development/](04-development/) | Coding standards, testing, API design | 8 |
| [05-code-review/](05-code-review/) | Review checklists, quality standards | 5 |
| [06-cicd/](06-cicd/) | Pipeline, GitOps, deployment strategies | 5 |
| [07-operations/](07-operations/) | Monitoring, incident response, DR | 5 |
| [08-services/](08-services/) | Microservice specifications (7 services) | 7 |

## Supporting Files

| File | Purpose |
|------|---------|
| [CODE_EXAMPLES_INDEX.md](CODE_EXAMPLES_INDEX.md) | 500+ code examples indexed |
| [LLM_USAGE_GUIDE.md](LLM_USAGE_GUIDE.md) | AI agent navigation guide |
| [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md) | 13-week phased plan |
| [LLM_PROMPTS.md](LLM_PROMPTS.md) | Prompt templates |

## Metrics

| Metric | Value |
|--------|-------|
| Documentation files | 52 |
| Words | ~213,000 |
| Code examples | 500+ |
| Microservices documented | 7 |

## How to Use This Example

### As a Reference

Browse the documentation to see how comprehensive, AI-friendly specs are structured:

1. Start with [01-architecture/01-architecture-overview.md](01-architecture/01-architecture-overview.md)
2. Explore security patterns in [02-security/](02-security/)
3. Review the service specs in [08-services/](08-services/)

### As a Template

To use this as a starting point for your own project:

1. Copy the directory structure
2. Replace PHP/Symfony references with your stack
3. Adapt the patterns to your domain
4. Keep the documentation style and checkpoint structure

### With AI Agents

Point your AI agent to [LLM_USAGE_GUIDE.md](LLM_USAGE_GUIDE.md) for task-based navigation.

---

## Key Principles Demonstrated

### 1. Explicit Over Implicit

Every decision includes justification:

```markdown
Use PostgreSQL 15+ for the following reasons:
- ACID compliance required for financial workflow data
- JSONB support for flexible metadata storage
- Row-level security for multi-tenant isolation
```

### 2. Validation Checkpoints

Every section includes verification criteria:

```markdown
## Validation Checkpoint
- [ ] All domain entities use readonly properties
- [ ] Value objects implement equals() method
- [ ] Repository interfaces are in Domain layer
```

### 3. Security Gates as Code

Security requirements become enforceable:

```markdown
## Security Requirements
- [ ] Input validation on all API endpoints
- [ ] JWT token verification middleware active
- [ ] Audit logging for all mutations
```

---

## Related Framework Documentation

This example implements the methodology defined in:

- [../../core/](../../core/) — Agent Operating Model
- [../../runtime/](../../runtime/) — Execution guides and prompts
- [../../METHODOLOGY.md](../../METHODOLOGY.md) — Core methodology

---

*This is one example of applying the AI-Driven Development framework. The framework itself is technology-agnostic.*
