# Complete Documentation Index

## Documentation Status

**Total Files**: 99+
**Last Updated**: 2026-01-28
**Status**: Production-Ready Framework + Complete Example

---

## Repository Organization

This repository contains two distinct parts:

1. **Framework** (core/, runtime/, bench/, tools/) — Technology-agnostic patterns for agentic development
2. **Examples** (examples/) — Stack-specific reference implementations

---

## Framework Documentation

### Core Specification (`core/`)

The normative specification defining how AI agents work autonomously with human checkpoints.

| File | Purpose |
|------|---------|
| [README.md](core/README.md) | Core module overview |
| [AGENT_OPERATING_MODEL.md](core/agent-operating-model/AGENT_OPERATING_MODEL.md) | 5 roles, workflow loop, stop conditions |
| [CHECKPOINTS.md](core/spec/CHECKPOINTS.md) | C0-C4 validation gates |
| [ESCALATION_RULES.md](core/agent-operating-model/ESCALATION_RULES.md) | When to request human input |
| [HANDOFF_TEMPLATE.md](core/agent-operating-model/HANDOFF_TEMPLATE.md) | Role transition format |
| [RISK_MODEL.md](core/agent-operating-model/RISK_MODEL.md) | Risk taxonomy and mitigation |
| [ADR_TEMPLATE.md](core/templates/ADR_TEMPLATE.md) | Architecture decision records |

### Runtime (`runtime/`)

Execution guides, prompts, and quality gates.

| File | Purpose |
|------|---------|
| [README.md](runtime/README.md) | Runtime module overview |
| [QUICKSTART_HUMAN.md](runtime/golden-path/QUICKSTART_HUMAN.md) | 15-minute human onboarding |
| [QUICKSTART_AGENT.md](runtime/golden-path/QUICKSTART_AGENT.md) | Agent file reading order |
| [BOOTSTRAP_NEW_PROJECT.md](runtime/golden-path/BOOTSTRAP_NEW_PROJECT.md) | **Apply framework to your project** |
| [FIRST_TASK.md](runtime/golden-path/FIRST_TASK.md) | Guided Issue→PR walkthrough |
| [definition-of-done.md](runtime/quality-gates/definition-of-done.md) | DoD by change type |
| [CLAUDE_CODE_SYSTEM.md](runtime/prompts/CLAUDE_CODE_SYSTEM.md) | System prompt |
| [PROMPT_PACK.md](runtime/prompts/PROMPT_PACK.md) | Prompt usage guide |
| [WORKFLOW_MANAGER.md](runtime/prompts/WORKFLOW_MANAGER.md) | Manager role prompt |
| [WORKFLOW_PLANNER.md](runtime/prompts/WORKFLOW_PLANNER.md) | Planner role prompt |
| [WORKFLOW_IMPLEMENTER.md](runtime/prompts/WORKFLOW_IMPLEMENTER.md) | Implementer role prompt |
| [WORKFLOW_TESTER.md](runtime/prompts/WORKFLOW_TESTER.md) | Tester role prompt |
| [WORKFLOW_REVIEWER.md](runtime/prompts/WORKFLOW_REVIEWER.md) | Reviewer role prompt |

### Benchmark Suite (`bench/`)

Measure agent performance across standardized tasks.

| Item | Purpose |
|------|---------|
| [README.md](bench/README.md) | Benchmark overview |
| [T001-T010](bench/tasks/) | 10 benchmark tasks (easy to hard) |
| [scoring_schema.json](bench/scoring/scoring_schema.json) | Result format |
| [metrics.md](bench/scoring/metrics.md) | What we measure |
| [run_bench.sh](bench/runner/run_bench.sh) | Execute benchmarks |

### Case Studies (`case-studies/`)

| File | Purpose |
|------|---------|
| [CASE_STUDY_01_issue_to_pr.md](case-studies/CASE_STUDY_01_issue_to_pr.md) | Complete workflow example |

---

## Root Documentation

| File | Purpose |
|------|---------|
| [README.md](README.md) | Project overview |
| [REPO_MAP.md](REPO_MAP.md) | Navigation hub |
| [METHODOLOGY.md](METHODOLOGY.md) | Core methodology |
| [GLOSSARY.md](GLOSSARY.md) | Terminology |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contribution guidelines |

---

## Example: PHP/Symfony/Kubernetes

A complete reference implementation demonstrating the methodology.

**Location**: [examples/php-symfony-k8s/](examples/php-symfony-k8s/)

### Example Overview

| File | Purpose |
|------|---------|
| [README.md](examples/php-symfony-k8s/README.md) | Example overview |
| [LLM_USAGE_GUIDE.md](examples/php-symfony-k8s/LLM_USAGE_GUIDE.md) | Task-based navigation |
| [CODE_EXAMPLES_INDEX.md](examples/php-symfony-k8s/CODE_EXAMPLES_INDEX.md) | 500+ code examples indexed |
| [IMPLEMENTATION_ROADMAP.md](examples/php-symfony-k8s/IMPLEMENTATION_ROADMAP.md) | 13-week phased plan |
| [LLM_PROMPTS.md](examples/php-symfony-k8s/LLM_PROMPTS.md) | Prompt templates |

### Architecture (8 files)

| File | Purpose |
|------|---------|
| [01-architecture-overview.md](examples/php-symfony-k8s/01-architecture/01-architecture-overview.md) | System design, ADRs |
| [02-microservices-catalog.md](examples/php-symfony-k8s/01-architecture/02-microservices-catalog.md) | 7 services catalog |
| [03-hexagonal-architecture.md](examples/php-symfony-k8s/01-architecture/03-hexagonal-architecture.md) | Ports & Adapters |
| [04-domain-driven-design.md](examples/php-symfony-k8s/01-architecture/04-domain-driven-design.md) | DDD patterns |
| [05-data-architecture.md](examples/php-symfony-k8s/01-architecture/05-data-architecture.md) | Database design |
| [06-communication-patterns.md](examples/php-symfony-k8s/01-architecture/06-communication-patterns.md) | REST, Events, RabbitMQ |
| [system-context.md](examples/php-symfony-k8s/01-architecture/diagrams/system-context.md) | C4 Level 1 |
| [container-diagram.md](examples/php-symfony-k8s/01-architecture/diagrams/container-diagram.md) | C4 Level 2 |

### Security (7 files)

| File | Purpose |
|------|---------|
| [01-security-principles.md](examples/php-symfony-k8s/02-security/01-security-principles.md) | Core principles |
| [02-zero-trust-architecture.md](examples/php-symfony-k8s/02-security/02-zero-trust-architecture.md) | Zero Trust |
| [03-authentication-authorization.md](examples/php-symfony-k8s/02-security/03-authentication-authorization.md) | OAuth2, JWT, RBAC |
| [04-secrets-management.md](examples/php-symfony-k8s/02-security/04-secrets-management.md) | Vault integration |
| [05-network-security.md](examples/php-symfony-k8s/02-security/05-network-security.md) | Service mesh, policies |
| [06-data-protection.md](examples/php-symfony-k8s/02-security/06-data-protection.md) | Encryption, GDPR |
| [07-security-checklist.md](examples/php-symfony-k8s/02-security/07-security-checklist.md) | Pre-deployment gates |

### Infrastructure (6 files)

| File | Purpose |
|------|---------|
| [01-infrastructure-overview.md](examples/php-symfony-k8s/03-infrastructure/01-infrastructure-overview.md) | IaC with Terraform |
| [02-kubernetes-architecture.md](examples/php-symfony-k8s/03-infrastructure/02-kubernetes-architecture.md) | K8s cluster design |
| [03-service-mesh.md](examples/php-symfony-k8s/03-infrastructure/03-service-mesh.md) | Istio configuration |
| [04-observability-stack.md](examples/php-symfony-k8s/03-infrastructure/04-observability-stack.md) | Prometheus, Grafana |
| [05-disaster-recovery.md](examples/php-symfony-k8s/03-infrastructure/05-disaster-recovery.md) | DR procedures |
| [06-scalability-strategy.md](examples/php-symfony-k8s/03-infrastructure/06-scalability-strategy.md) | Scalability |

### Development (8 files)

| File | Purpose |
|------|---------|
| [01-development-standards.md](examples/php-symfony-k8s/04-development/01-development-standards.md) | Git flow, PR process |
| [02-coding-guidelines-php.md](examples/php-symfony-k8s/04-development/02-coding-guidelines-php.md) | PHP 8.3, PSR standards |
| [03-symfony-best-practices.md](examples/php-symfony-k8s/04-development/03-symfony-best-practices.md) | Symfony patterns |
| [04-testing-strategy.md](examples/php-symfony-k8s/04-development/04-testing-strategy.md) | Testing approach |
| [05-api-design-guidelines.md](examples/php-symfony-k8s/04-development/05-api-design-guidelines.md) | REST, OpenAPI |
| [06-database-guidelines.md](examples/php-symfony-k8s/04-development/06-database-guidelines.md) | Migrations, indexing |
| [07-error-handling.md](examples/php-symfony-k8s/04-development/07-error-handling.md) | Error management |
| [08-performance-optimization.md](examples/php-symfony-k8s/04-development/08-performance-optimization.md) | Caching, profiling |

### Code Review (5 files)

| File | Purpose |
|------|---------|
| [01-code-review-checklist.md](examples/php-symfony-k8s/05-code-review/01-code-review-checklist.md) | General review |
| [02-security-review-checklist.md](examples/php-symfony-k8s/05-code-review/02-security-review-checklist.md) | Security review |
| [03-architecture-review-checklist.md](examples/php-symfony-k8s/05-code-review/03-architecture-review-checklist.md) | Architecture review |
| [04-quality-standards.md](examples/php-symfony-k8s/05-code-review/04-quality-standards.md) | Quality metrics |
| [05-common-antipatterns.md](examples/php-symfony-k8s/05-code-review/05-common-antipatterns.md) | What to avoid |

### CI/CD (5 files)

| File | Purpose |
|------|---------|
| [01-cicd-overview.md](examples/php-symfony-k8s/06-cicd/01-cicd-overview.md) | CI/CD philosophy |
| [02-pipeline-stages.md](examples/php-symfony-k8s/06-cicd/02-pipeline-stages.md) | Pipeline details |
| [03-gitops-workflow.md](examples/php-symfony-k8s/06-cicd/03-gitops-workflow.md) | ArgoCD, GitOps |
| [04-quality-gates.md](examples/php-symfony-k8s/06-cicd/04-quality-gates.md) | Automated gates |
| [05-deployment-strategies.md](examples/php-symfony-k8s/06-cicd/05-deployment-strategies.md) | Blue-green, canary |

### Operations (5 files)

| File | Purpose |
|------|---------|
| [01-operations-overview.md](examples/php-symfony-k8s/07-operations/01-operations-overview.md) | SRE principles |
| [02-monitoring-alerting.md](examples/php-symfony-k8s/07-operations/02-monitoring-alerting.md) | Monitoring strategy |
| [03-incident-response.md](examples/php-symfony-k8s/07-operations/03-incident-response.md) | Incident handling |
| [04-backup-recovery.md](examples/php-symfony-k8s/07-operations/04-backup-recovery.md) | Backup strategy |
| [05-performance-tuning.md](examples/php-symfony-k8s/07-operations/05-performance-tuning.md) | Performance |

### Services (7 files)

| File | Purpose |
|------|---------|
| [01-services-overview.md](examples/php-symfony-k8s/08-services/01-services-overview.md) | Service catalog |
| [02-authentication-service.md](examples/php-symfony-k8s/08-services/02-authentication-service.md) | Auth service |
| [03-workflow-engine.md](examples/php-symfony-k8s/08-services/03-workflow-engine.md) | Workflow orchestration |
| [04-agent-manager.md](examples/php-symfony-k8s/08-services/04-agent-manager.md) | LLM integration |
| [05-validation-service.md](examples/php-symfony-k8s/08-services/05-validation-service.md) | Quality control |
| [06-notification-service.md](examples/php-symfony-k8s/08-services/06-notification-service.md) | Notifications |
| [07-audit-logging-service.md](examples/php-symfony-k8s/08-services/07-audit-logging-service.md) | Audit/compliance |

---

## Quick Start by Profile

| Profile | Start Here | Then Read |
|---------|------------|-----------|
| **Apply to Your Project** | [BOOTSTRAP_NEW_PROJECT.md](runtime/golden-path/BOOTSTRAP_NEW_PROJECT.md) | [core/](core/) |
| **Agentic Researcher** | [core/README.md](core/README.md) | [bench/](bench/) |
| **Explore the Example** | [examples/php-symfony-k8s/README.md](examples/php-symfony-k8s/README.md) | [LLM_USAGE_GUIDE.md](examples/php-symfony-k8s/LLM_USAGE_GUIDE.md) |

---

## Metrics

| Category | Count |
|----------|-------|
| Framework documents | 47 |
| Example documents | 52 |
| Benchmark tasks | 10 |
| Agent prompts | 6 |
| **Total** | **99+** |

---

*Last updated: 2026-01-28*
