# LLM Usage Guide

**Purpose**: This guide is specifically designed for Large Language Models (LLMs) to navigate the documentation efficiently and autonomously build the entire AI Workflow Processing Platform.

**Last Updated**: 2025-01-07
**Documentation Version**: 2.0.0
**Target Audience**: LLM agents performing autonomous development

---

## 📋 Table of Contents

1. [How to Use This Guide](#how-to-use-this-guide)
2. [Quick Start: First 5 Files to Read](#quick-start-first-5-files-to-read)
3. [Task-Based Navigation Matrix](#task-based-navigation-matrix)
4. [Implementation Phases](#implementation-phases)
5. [Service Implementation Workflows](#service-implementation-workflows)
6. [Validation Checkpoints](#validation-checkpoints)
7. [Common Patterns Quick Reference](#common-patterns-quick-reference)
8. [Troubleshooting Decision Tree](#troubleshooting-decision-tree)

---

## How to Use This Guide

### For LLM Agents

This documentation suite (60 files, 500,000+ words, 500+ code examples) is **LLM-First**: designed to enable autonomous development without human intervention at each step.

**Navigation Strategy**:
1. **Start here** (this file) to understand the navigation system
2. **Identify your task** from the Task-Based Navigation Matrix below
3. **Follow the reading order** specified for that task (files listed in optimal sequence)
4. **Read files completely** - each file is self-contained with all context needed
5. **Use cross-references** (200+ internal links) to explore related topics
6. **Validate understanding** at checkpoints before proceeding

**Key Principle**: Read files in the specified order to minimize backtracking. Each reading order is optimized for building context progressively.

---

## Quick Start: First 5 Files to Read

**For ANY task, start with these 5 foundation files** (read in this exact order):

### 1. [README.md](README.md) - 5 min read
**Why**: Overall navigation, technology stack summary, key principles
**Key takeaways**:
- 8 documentation sections (architecture → services)
- Technology stack (PHP 8.3, Symfony 7, PostgreSQL, Kubernetes, Istio)
- Quick start by role (Developer, Architect, Operations, Security)

### 2. [01-architecture/01-architecture-overview.md](01-architecture/01-architecture-overview.md) - 20 min read
**Why**: System purpose, architectural principles, 7 ADRs
**Key takeaways**:
- Microservices with clear bounded contexts
- Event-driven architecture with RabbitMQ
- Zero Trust security from day one
- All technology decisions justified

### 3. [01-architecture/03-hexagonal-architecture.md](01-architecture/03-hexagonal-architecture.md) - 25 min read
**Why**: Code structure pattern used in ALL services
**Key takeaways**:
- Domain layer (pure business logic, no infrastructure)
- Application layer (use cases, orchestration)
- Infrastructure layer (adapters: DB, HTTP, messaging)
- Directory structure: `src/{Domain,Application,Infrastructure}/`
- Dependency rule: Domain ← Application ← Infrastructure

### 4. [01-architecture/04-domain-driven-design.md](01-architecture/04-domain-driven-design.md) - 30 min read
**Why**: DDD tactical patterns used throughout
**Key takeaways**:
- 7 bounded contexts defined
- Entities vs Value Objects vs Aggregates
- Domain Events for async communication
- Repository pattern for data access
- Complete code examples for all patterns

### 5. [04-development/02-coding-guidelines-php.md](04-development/02-coding-guidelines-php.md) - 20 min read
**Why**: Coding standards for all PHP code
**Key takeaways**:
- PSR-1/PSR-4/PSR-12 compliance mandatory
- PHP 8.3 features (enums, readonly, never type, DNF types)
- PHPStan Level 9 (maximum static analysis)
- Type safety: always use strict types, never use mixed

**Total Foundation Reading Time**: ~100 minutes
**After these 5 files**: You understand the architecture, patterns, and coding standards. Now proceed to specific tasks below.

---

## Task-Based Navigation Matrix

### Task Category: Service Implementation

#### Task: Implement Authentication Service

**Goal**: Build complete OAuth2/OIDC authentication service with JWT, RBAC, MFA

**Prerequisites**: Read foundation files 1-5 above ✅

**Reading Order**:
1. ✅ Foundation files (already read)
2. [02-security/03-authentication-authorization.md](02-security/03-authentication-authorization.md) - 35 min
   - OAuth2 flows (Authorization Code, Client Credentials)
   - JWT generation and validation
   - RBAC/ABAC implementation
   - Session management and MFA
3. [08-services/02-authentication-service.md](08-services/02-authentication-service.md) - 45 min
   - **MAIN IMPLEMENTATION FILE** with complete code
   - Domain model (User, Role, Permission aggregates)
   - Use cases (Login, Logout, RefreshToken, ValidateToken)
   - API endpoints with OpenAPI specs
   - Database schema with indexes
   - Keycloak integration
4. [04-development/03-symfony-best-practices.md](04-development/03-symfony-best-practices.md) - 25 min
   - Symfony 7 DI container
   - Security component configuration
   - JWT bundle integration
5. [04-development/04-testing-strategy.md](04-development/04-testing-strategy.md) - 30 min
   - Unit tests for domain logic
   - Integration tests for auth flows
   - E2E tests for complete scenarios
6. [02-security/04-secrets-management.md](02-security/04-secrets-management.md) - 25 min
   - Store JWT private keys in Vault
   - Rotate secrets regularly

**Expected Output**:
- Fully functional Authentication Service
- 15+ unit tests (domain layer)
- 10+ integration tests (use cases)
- 5+ E2E tests (complete flows)
- 80%+ code coverage

**Estimated Implementation Time**: 3-5 days
**Validation Checkpoint**: See "Validation Checkpoints" section below

---

#### Task: Implement Workflow Engine

**Goal**: Build workflow orchestration service with Saga pattern, state machine, step executors

**Prerequisites**: Read foundation files 1-5 above ✅

**Reading Order**:
1. ✅ Foundation files (already read)
2. [01-architecture/06-communication-patterns.md](01-architecture/06-communication-patterns.md) - 20 min
   - Event-driven architecture
   - Saga pattern for distributed transactions
   - Choreography vs Orchestration
3. [08-services/03-workflow-engine.md](08-services/03-workflow-engine.md) - 60 min ⚠️ **LONGEST FILE**
   - **MAIN IMPLEMENTATION FILE** - most comprehensive (76KB, 2,267 lines)
   - Complete state machine (10 states: draft → completed/failed)
   - Saga pattern implementation
   - 4 step executor types (Agent, Transform, Conditional, Parallel)
   - Error handling and retry strategies
   - Compensation logic for rollbacks
   - Complete API endpoints and database schema
4. [03-infrastructure/06-message-queue.md](03-infrastructure/06-message-queue.md) - 30 min
   - RabbitMQ event publishing
   - Exchange types (topic, fanout)
   - Event routing patterns
5. [04-development/07-error-handling.md](04-development/07-error-handling.md) - 25 min
   - Exception hierarchy
   - Retry strategies (exponential backoff)
   - Circuit breaker pattern
6. [04-development/04-testing-strategy.md](04-development/04-testing-strategy.md) - 30 min
   - State machine testing
   - Saga compensation testing
   - Event publishing verification

**Expected Output**:
- Fully functional Workflow Engine
- State machine with all transitions
- 4 step executor implementations
- Saga orchestration with compensations
- 25+ unit tests
- 15+ integration tests
- 80%+ code coverage

**Estimated Implementation Time**: 7-10 days (most complex service)
**Validation Checkpoint**: See "Validation Checkpoints" section below

---

#### Task: Implement Agent Manager Service

**Goal**: Build LLM integration service supporting multiple providers (OpenAI, Anthropic, Google AI)

**Prerequisites**: Read foundation files 1-5 above ✅

**Reading Order**:
1. ✅ Foundation files (already read)
2. [08-services/04-agent-manager.md](08-services/04-agent-manager.md) - 50 min
   - **MAIN IMPLEMENTATION FILE** (3,325 lines - longest)
   - Multi-provider abstraction (OpenAI, Anthropic, Google AI, Azure OpenAI)
   - Prompt template management
   - Token tracking and cost calculation
   - Model fallback strategies
   - Conversation context management
   - API endpoints and database schema
3. [04-development/08-performance-optimization.md](04-development/08-performance-optimization.md) - 25 min
   - Caching LLM responses (Redis)
   - Response streaming
   - Connection pooling for HTTP clients
4. [02-security/06-data-protection.md](02-security/06-data-protection.md) - 30 min
   - PII handling in prompts
   - Data anonymization before sending to LLMs
   - Audit logging of all LLM interactions
5. [02-security/04-secrets-management.md](02-security/04-secrets-management.md) - 25 min
   - Store API keys in Vault
   - Dynamic secrets for provider credentials

**Expected Output**:
- Fully functional Agent Manager
- 4+ provider implementations (OpenAI, Anthropic, Google AI, Azure)
- Prompt template engine
- Token tracking system
- Fallback logic (provider → model → retry)
- 20+ unit tests
- 10+ integration tests
- 80%+ code coverage

**Estimated Implementation Time**: 5-7 days
**Validation Checkpoint**: See "Validation Checkpoints" section below

---

#### Task: Implement Validation Service

**Goal**: Build rule-based validation engine with scoring, feedback generation

**Prerequisites**: Read foundation files 1-5 above ✅

**Reading Order**:
1. ✅ Foundation files (already read)
2. [08-services/05-validation-service.md](08-services/05-validation-service.md) - 40 min
   - **MAIN IMPLEMENTATION FILE**
   - Rule engine architecture
   - 4 validator types (regex, length, JSON schema, custom PHP)
   - Scoring engine with weighted rules
   - Feedback generation
   - Rule versioning and A/B testing
   - API endpoints and database schema
3. [04-development/06-database-guidelines.md](04-development/06-database-guidelines.md) - 25 min
   - JSONB for flexible rule storage
   - Indexing strategies for rule queries
   - Partitioning validation_results by date
4. [04-development/08-performance-optimization.md](04-development/08-performance-optimization.md) - 25 min
   - Caching validation rules (Redis)
   - Parallel rule execution
   - Query optimization

**Expected Output**:
- Fully functional Validation Service
- Rule engine with 4 validator types
- Scoring algorithm implementation
- Rule versioning system
- 20+ unit tests (rule execution)
- 10+ integration tests (complete validation flows)
- 80%+ code coverage

**Estimated Implementation Time**: 4-6 days
**Validation Checkpoint**: See "Validation Checkpoints" section below

---

#### Task: Implement Notification Service

**Goal**: Build multi-channel notification service (email, SMS, webhook, in-app)

**Prerequisites**: Read foundation files 1-5 above ✅

**Reading Order**:
1. ✅ Foundation files (already read)
2. [08-services/06-notification-service.md](08-services/06-notification-service.md) - 40 min
   - **MAIN IMPLEMENTATION FILE**
   - Multi-channel architecture (email, SMS, webhook, in-app)
   - Template rendering with Twig
   - Retry logic and dead letter queue
   - User preferences management
   - Provider abstraction (SendGrid, Twilio, etc.)
   - API endpoints and database schema
3. [03-infrastructure/06-message-queue.md](03-infrastructure/06-message-queue.md) - 30 min
   - Async notification processing with RabbitMQ
   - Dead letter queue for failed notifications
   - Priority queues for urgent notifications
4. [04-development/07-error-handling.md](04-development/07-error-handling.md) - 25 min
   - Retry strategies (exponential backoff)
   - Circuit breaker for provider failures
   - Graceful degradation

**Expected Output**:
- Fully functional Notification Service
- 4 channel implementations (email, SMS, webhook, in-app)
- Template engine with Twig
- Retry logic with exponential backoff
- User preference system
- 20+ unit tests
- 10+ integration tests
- 80%+ code coverage

**Estimated Implementation Time**: 4-6 days
**Validation Checkpoint**: See "Validation Checkpoints" section below

---

#### Task: Implement Audit & Logging Service

**Goal**: Build immutable audit logging with tamper detection for compliance

**Prerequisites**: Read foundation files 1-5 above ✅

**Reading Order**:
1. ✅ Foundation files (already read)
2. [02-security/06-data-protection.md](02-security/06-data-protection.md) - 30 min
   - GDPR compliance requirements
   - SOC2 audit trail requirements
   - ISO27001 logging standards
   - NIS2 incident reporting
3. [08-services/07-audit-logging-service.md](08-services/07-audit-logging-service.md) - 40 min
   - **MAIN IMPLEMENTATION FILE**
   - Immutable event capture
   - Tamper detection (checksums and digital signatures)
   - Compliance reporting
   - Data retention and anonymization
   - API endpoints and database schema
4. [04-development/06-database-guidelines.md](04-development/06-database-guidelines.md) - 25 min
   - Time-series partitioning for audit logs
   - Append-only tables
   - Indexing strategies for compliance queries
5. [02-security/04-secrets-management.md](02-security/04-secrets-management.md) - 25 min
   - Private key management for signatures
   - Certificate rotation

**Expected Output**:
- Fully functional Audit & Logging Service
- Immutable event storage
- Tamper detection implementation
- Compliance reports (GDPR, SOC2, ISO27001, NIS2)
- Data retention policies
- 20+ unit tests
- 10+ integration tests
- 80%+ code coverage

**Estimated Implementation Time**: 4-6 days
**Validation Checkpoint**: See "Validation Checkpoints" section below

---

### Task Category: Infrastructure & Deployment

#### Task: Set Up Kubernetes Cluster

**Goal**: Deploy production-ready Kubernetes cluster with namespaces, RBAC, network policies

**Prerequisites**: Read foundation files 1-5 above ✅

**Reading Order**:
1. ✅ Foundation files (already read)
2. [03-infrastructure/01-infrastructure-overview.md](03-infrastructure/01-infrastructure-overview.md) - 25 min
   - Infrastructure as Code strategy
   - Terraform for cluster provisioning
   - Cloud-agnostic design
3. [03-infrastructure/02-kubernetes-architecture.md](03-infrastructure/02-kubernetes-architecture.md) - 40 min ⚠️ **KEY INFRASTRUCTURE FILE**
   - Kubernetes 1.28+ configuration
   - Namespace design (dev, staging, production)
   - RBAC configuration
   - Resource management (requests/limits)
   - Network policies
   - High availability setup (3+ control plane nodes)
   - Complete manifests for all services
4. [02-security/05-network-security.md](02-security/05-network-security.md) - 30 min
   - Network policies for service isolation
   - Pod security policies
   - Ingress configuration with TLS
5. [03-infrastructure/05-disaster-recovery.md](03-infrastructure/05-disaster-recovery.md) - 25 min
   - Backup strategies for etcd
   - Cluster failover procedures

**Expected Output**:
- Functional Kubernetes cluster (1.28+)
- 3 namespaces (dev, staging, production)
- RBAC configured for least privilege
- Network policies for zero trust
- High availability (3 control plane nodes, 5+ worker nodes)
- Monitoring with Prometheus operator

**Estimated Implementation Time**: 2-3 days
**Validation Checkpoint**: `kubectl get nodes` shows all nodes Ready, all system pods running

---

#### Task: Deploy Istio Service Mesh

**Goal**: Configure Istio for mTLS, traffic management, observability

**Prerequisites**: Kubernetes cluster running ✅

**Reading Order**:
1. [03-infrastructure/03-service-mesh.md](03-infrastructure/03-service-mesh.md) - 35 min ⚠️ **KEY FILE**
   - Istio 1.20+ installation
   - mTLS configuration (STRICT mode)
   - Traffic management (load balancing, retries, circuit breakers)
   - Observability integration (Prometheus, Grafana, Jaeger)
   - Complete Istio resource manifests
2. [02-security/02-zero-trust-architecture.md](02-security/02-zero-trust-architecture.md) - 25 min
   - Zero trust principles
   - mTLS verification
   - Authorization policies
3. [03-infrastructure/04-observability-stack.md](03-infrastructure/04-observability-stack.md) - 35 min
   - Prometheus integration with Istio
   - Grafana dashboards for service mesh
   - Distributed tracing with Tempo

**Expected Output**:
- Istio 1.20+ deployed
- mTLS enabled in STRICT mode for all services
- Traffic management policies configured
- Observability stack integrated
- Zero trust network policies

**Estimated Implementation Time**: 2-3 days
**Validation Checkpoint**: `istioctl verify-install` passes, mTLS enabled across all services

---

#### Task: Set Up CI/CD Pipeline

**Goal**: Configure GitHub Actions + ArgoCD for automated build, test, deploy

**Prerequisites**: Kubernetes cluster + Istio running ✅

**Reading Order**:
1. [06-cicd/01-cicd-overview.md](06-cicd/01-cicd-overview.md) - 25 min
   - CI/CD philosophy
   - GitHub Actions for CI
   - ArgoCD for CD (GitOps)
2. [06-cicd/02-pipeline-stages.md](06-cicd/02-pipeline-stages.md) - 40 min ⚠️ **KEY FILE**
   - Complete GitHub Actions workflows
   - Build stage (Docker image build)
   - Test stage (PHPUnit, PHPStan Level 9, 80% coverage)
   - Security scan stage (Trivy, Grype, OWASP Dependency Check)
   - Deploy stage (update manifests, trigger ArgoCD)
   - Complete YAML examples
3. [06-cicd/03-gitops-workflow.md](06-cicd/03-gitops-workflow.md) - 30 min
   - ArgoCD 2.9+ installation
   - Application manifests
   - Auto-sync configuration
   - Rollback procedures
4. [06-cicd/04-quality-gates.md](06-cicd/04-quality-gates.md) - 25 min
   - PHPStan Level 9 enforcement
   - Code coverage thresholds (80%)
   - Security scan requirements (no HIGH/CRITICAL vulnerabilities)
5. [06-cicd/05-deployment-strategies.md](06-cicd/05-deployment-strategies.md) - 30 min
   - Blue-green deployments
   - Canary releases (10% → 50% → 100%)
   - Automatic rollback on errors

**Expected Output**:
- GitHub Actions CI pipeline running
- ArgoCD deployed and syncing
- Quality gates enforced (PHPStan Level 9, 80% coverage, security scans)
- Deployment strategies configured (canary by default)
- Automatic rollback on failures

**Estimated Implementation Time**: 2-3 days
**Validation Checkpoint**: CI pipeline passes all quality gates, ArgoCD syncs successfully

---

#### Task: Deploy Observability Stack

**Goal**: Set up Prometheus, Grafana, Loki, Tempo for complete observability

**Prerequisites**: Kubernetes + Istio running ✅

**Reading Order**:
1. [03-infrastructure/04-observability-stack.md](03-infrastructure/04-observability-stack.md) - 40 min ⚠️ **KEY FILE**
   - Prometheus installation (Prometheus Operator)
   - Grafana dashboards
   - Loki for log aggregation
   - Tempo for distributed tracing
   - Complete configuration manifests
2. [07-operations/02-monitoring-alerting.md](07-operations/02-monitoring-alerting.md) - 35 min
   - SLI/SLO/SLA definitions
   - Alert rules (Prometheus AlertManager)
   - Dashboard design
   - On-call rotation setup
3. [07-operations/01-operations-overview.md](07-operations/01-operations-overview.md) - 25 min
   - SRE principles
   - Error budgets
   - Operational excellence

**Expected Output**:
- Prometheus collecting metrics from all services
- Grafana with 10+ dashboards (system, per-service, SLO)
- Loki aggregating logs from all pods
- Tempo tracing requests across services
- Alert rules configured and routing to PagerDuty/Slack

**Estimated Implementation Time**: 2-3 days
**Validation Checkpoint**: All dashboards showing data, alerts firing correctly

---

### Task Category: Security & Compliance

#### Task: Implement Zero Trust Architecture

**Goal**: Configure zero trust security with mTLS, network policies, authorization

**Prerequisites**: Kubernetes + Istio deployed ✅

**Reading Order**:
1. [02-security/01-security-principles.md](02-security/01-security-principles.md) - 25 min
   - 10 core security principles
   - Defense in depth
   - Least privilege
2. [02-security/02-zero-trust-architecture.md](02-security/02-zero-trust-architecture.md) - 25 min ⚠️ **KEY FILE**
   - Zero trust principles
   - Never trust, always verify
   - Micro-segmentation
   - Continuous verification
3. [03-infrastructure/03-service-mesh.md](03-infrastructure/03-service-mesh.md) - 35 min
   - Istio mTLS configuration (STRICT mode)
   - Authorization policies (service-to-service)
4. [02-security/05-network-security.md](02-security/05-network-security.md) - 30 min
   - Kubernetes network policies
   - Service mesh security policies
   - API Gateway security (Kong)
5. [02-security/03-authentication-authorization.md](02-security/03-authentication-authorization.md) - 35 min
   - OAuth2/OIDC for user authentication
   - JWT for API authentication
   - RBAC/ABAC for authorization

**Expected Output**:
- mTLS enabled in STRICT mode across all services
- Network policies isolating namespaces
- Authorization policies for service-to-service communication
- API Gateway with OAuth2 authentication
- Zero implicit trust anywhere in the system

**Estimated Implementation Time**: 3-4 days
**Validation Checkpoint**: Security audit passes, no services can communicate without mTLS

---

#### Task: Configure Secrets Management with Vault

**Goal**: Deploy HashiCorp Vault and integrate with all services

**Prerequisites**: Kubernetes cluster running ✅

**Reading Order**:
1. [02-security/04-secrets-management.md](02-security/04-secrets-management.md) - 30 min ⚠️ **KEY FILE**
   - HashiCorp Vault architecture
   - Dynamic secrets
   - Secret rotation strategies
   - Encryption as a Service
   - Kubernetes integration (Vault Agent Injector)
   - Complete configuration examples
2. [02-security/01-security-principles.md](02-security/01-security-principles.md) - 25 min
   - Principle: No secrets in code or config files
   - Principle: Secrets must be rotated regularly
3. [03-infrastructure/02-kubernetes-architecture.md](03-infrastructure/02-kubernetes-architecture.md) - Reference
   - Vault integration with Kubernetes (Vault Agent Injector sidecar)

**Expected Output**:
- Vault deployed in HA mode (3 replicas)
- All secrets stored in Vault (database passwords, API keys, JWT private keys)
- Dynamic secrets configured for PostgreSQL
- Automatic secret rotation (30-90 days)
- Vault Agent Injector running in each namespace
- No secrets in code, config files, or environment variables

**Estimated Implementation Time**: 2-3 days
**Validation Checkpoint**: All services retrieve secrets from Vault, rotation working

---

#### Task: GDPR Compliance Implementation

**Goal**: Implement GDPR requirements (right to access, erasure, data portability)

**Prerequisites**: All services deployed ✅

**Reading Order**:
1. [02-security/06-data-protection.md](02-security/06-data-protection.md) - 40 min ⚠️ **KEY FILE**
   - GDPR requirements overview
   - Right to access (data export)
   - Right to erasure (data deletion)
   - Right to data portability
   - Consent management
   - Data minimization
   - Privacy by design
   - Complete implementation examples
2. [08-services/07-audit-logging-service.md](08-services/07-audit-logging-service.md) - 40 min
   - Audit trail for GDPR compliance
   - Data retention policies
   - Anonymization strategies
3. [04-development/06-database-guidelines.md](04-development/06-database-guidelines.md) - Reference
   - Soft deletes vs hard deletes
   - Cascading deletes for user data

**Expected Output**:
- Data access API endpoint (export user data)
- Data erasure API endpoint (delete user data)
- Data portability API endpoint (JSON export)
- Consent management system
- Audit trail for all data operations
- Privacy policy integration

**Estimated Implementation Time**: 3-4 days
**Validation Checkpoint**: GDPR compliance audit passes

---

### Task Category: Testing & Quality

#### Task: Achieve 80% Code Coverage

**Goal**: Write comprehensive tests to achieve minimum 80% code coverage

**Prerequisites**: Service implemented ✅

**Reading Order**:
1. [04-development/04-testing-strategy.md](04-development/04-testing-strategy.md) - 35 min ⚠️ **KEY FILE**
   - Testing pyramid (70% unit, 20% integration, 10% E2E)
   - PHPUnit for unit and integration tests
   - Behat for E2E tests
   - Code coverage with PHPUnit + Xdebug
   - Mutation testing with Infection
   - Test doubles (mocks, stubs, fakes)
   - Complete test examples
2. [05-code-review/04-quality-standards.md](05-code-review/04-quality-standards.md) - 30 min
   - Quality metrics (coverage, complexity, duplication)
   - SonarQube configuration
   - Technical debt management
3. [06-cicd/04-quality-gates.md](06-cicd/04-quality-gates.md) - 25 min
   - Coverage threshold enforcement (80%)
   - Failing builds on coverage drop

**Expected Output**:
- Unit tests for all domain logic (70% of tests)
- Integration tests for use cases (20% of tests)
- E2E tests for critical flows (10% of tests)
- Code coverage ≥ 80% (measured by PHPUnit)
- Mutation score ≥ 70% (measured by Infection)
- All tests passing in CI pipeline

**Estimated Implementation Time**: 2-3 days (per service)
**Validation Checkpoint**: `vendor/bin/phpunit --coverage-text` shows ≥ 80%

---

#### Task: PHPStan Level 9 Compliance

**Goal**: Achieve maximum static analysis level (Level 9) with PHPStan

**Prerequisites**: Service implemented ✅

**Reading Order**:
1. [04-development/02-coding-guidelines-php.md](04-development/02-coding-guidelines-php.md) - 25 min ⚠️ **KEY FILE**
   - Type safety requirements
   - PHP 8.3 features for type safety (readonly, never, DNF types)
   - PHPStan Level 9 requirements
   - Common type errors and fixes
2. [06-cicd/04-quality-gates.md](06-cicd/04-quality-gates.md) - Reference
   - PHPStan Level 9 enforcement in CI

**Expected Output**:
- `vendor/bin/phpstan analyse` passes at Level 9
- All parameters have type declarations
- All return types declared
- All properties typed
- No mixed types used
- No @phpstan-ignore comments (fix issues properly)
- CI pipeline enforces Level 9

**Estimated Implementation Time**: 1-2 days (per service)
**Validation Checkpoint**: `vendor/bin/phpstan analyse --level=9 src/` returns 0 errors

---

### Task Category: Performance & Optimization

#### Task: Optimize Database Performance

**Goal**: Optimize database queries, indexes, partitioning for production scale

**Prerequisites**: Service implemented and deployed ✅

**Reading Order**:
1. [04-development/06-database-guidelines.md](04-development/06-database-guidelines.md) - 35 min ⚠️ **KEY FILE**
   - PostgreSQL 15+ best practices
   - Index design (B-tree, GIN, GiST)
   - Query optimization (EXPLAIN ANALYZE)
   - N+1 query prevention
   - Partitioning strategies (range, list, hash)
   - Connection pooling (PgBouncer)
   - Complete optimization examples
2. [04-development/08-performance-optimization.md](04-development/08-performance-optimization.md) - 30 min
   - Database caching with Redis
   - Query result caching
   - Prepared statements
3. [07-operations/05-performance-tuning.md](07-operations/05-performance-tuning.md) - 30 min
   - Load testing with K6
   - Performance monitoring
   - Capacity planning

**Expected Output**:
- All queries using indexes (verify with EXPLAIN ANALYZE)
- No N+1 queries (use eager loading)
- Partitioned tables for time-series data (audit_logs, notifications)
- Connection pooling configured (PgBouncer)
- Redis caching for frequently accessed data
- Query performance: P95 < 50ms for simple queries, < 200ms for complex

**Estimated Implementation Time**: 2-3 days
**Validation Checkpoint**: Load test shows P95 < 200ms for all API endpoints

---

#### Task: Configure Caching Strategy

**Goal**: Implement multi-level caching (OPcache, Redis, HTTP cache)

**Prerequisites**: Service deployed ✅

**Reading Order**:
1. [04-development/08-performance-optimization.md](04-development/08-performance-optimization.md) - 35 min ⚠️ **KEY FILE**
   - OPcache configuration (PHP bytecode cache)
   - JIT configuration (PHP 8.3)
   - Redis caching patterns
   - HTTP cache headers
   - Cache invalidation strategies
   - Complete configuration examples
2. [01-architecture/05-data-architecture.md](01-architecture/05-data-architecture.md) - Reference
   - Cache-aside pattern
   - Write-through cache
   - Cache invalidation on events
3. [04-development/06-database-guidelines.md](04-development/06-database-guidelines.md) - Reference
   - Materialized views for complex queries

**Expected Output**:
- OPcache enabled with 256MB memory
- JIT enabled (tracing mode)
- Redis configured for application cache
- HTTP cache headers on API responses (ETag, Last-Modified)
- Cache invalidation on domain events
- Cache hit rate > 80% for frequently accessed data

**Estimated Implementation Time**: 1-2 days
**Validation Checkpoint**: Redis hit rate > 80%, API response times reduced by 50%

---

## Implementation Phases

### Phase 0: Environment Setup (Week 0)

**Goal**: Set up local development environment and tools

**Tasks**:
1. Install PHP 8.3, Composer, Symfony CLI
2. Install Docker Desktop (for local PostgreSQL, Redis, RabbitMQ)
3. Install kubectl, helm, istioctl
4. Clone repository and configure Git
5. Set up IDE (PHPStorm recommended) with plugins

**Reading**:
- [04-development/01-development-standards.md](04-development/01-development-standards.md)

**Duration**: 1 day
**Validation**: Run `symfony check:requirements` and see all green

---

### Phase 1: Infrastructure Foundation (Weeks 1-2)

**Goal**: Deploy Kubernetes cluster with service mesh and observability

**Tasks in Order**:
1. **Kubernetes Cluster** (Days 1-3)
   - Deploy cluster (see "Set Up Kubernetes Cluster" task above)
   - Configure namespaces (dev, staging, production)
   - Set up RBAC

2. **Istio Service Mesh** (Days 4-6)
   - Deploy Istio (see "Deploy Istio Service Mesh" task above)
   - Enable mTLS
   - Configure traffic management

3. **Observability Stack** (Days 7-10)
   - Deploy Prometheus + Grafana (see "Deploy Observability Stack" task above)
   - Configure Loki for logs
   - Set up Tempo for tracing
   - Create dashboards

**Reading Order**:
1. Foundation files (README → architecture → hexagonal → DDD → coding guidelines)
2. [03-infrastructure/01-infrastructure-overview.md](03-infrastructure/01-infrastructure-overview.md)
3. [03-infrastructure/02-kubernetes-architecture.md](03-infrastructure/02-kubernetes-architecture.md)
4. [03-infrastructure/03-service-mesh.md](03-infrastructure/03-service-mesh.md)
5. [03-infrastructure/04-observability-stack.md](03-infrastructure/04-observability-stack.md)

**Duration**: 2 weeks
**Validation Checkpoint**:
- All infrastructure pods running
- Grafana dashboards showing metrics
- mTLS enabled across cluster

---

### Phase 2: Core Security Infrastructure (Weeks 3-4)

**Goal**: Deploy security infrastructure (Vault, Keycloak, API Gateway)

**Tasks in Order**:
1. **HashiCorp Vault** (Days 1-3)
   - Deploy Vault in HA mode (see "Configure Secrets Management" task above)
   - Configure dynamic secrets
   - Set up rotation policies

2. **Keycloak** (Days 4-6)
   - Deploy Keycloak
   - Configure realms and clients
   - Set up OAuth2/OIDC flows

3. **Kong API Gateway** (Days 7-10)
   - Deploy Kong
   - Configure rate limiting
   - Set up authentication plugins

**Reading Order**:
1. [02-security/01-security-principles.md](02-security/01-security-principles.md)
2. [02-security/02-zero-trust-architecture.md](02-security/02-zero-trust-architecture.md)
3. [02-security/04-secrets-management.md](02-security/04-secrets-management.md)
4. [02-security/03-authentication-authorization.md](02-security/03-authentication-authorization.md)
5. [02-security/05-network-security.md](02-security/05-network-security.md)

**Duration**: 2 weeks
**Validation Checkpoint**:
- All services retrieve secrets from Vault
- OAuth2 flows working in Keycloak
- API Gateway routing requests

---

### Phase 3: Core Services Implementation (Weeks 5-10)

**Goal**: Implement all 7 essential microservices

**Tasks in Order** (can parallelize with multiple developers):

1. **Authentication Service** (Weeks 5-6)
   - See "Implement Authentication Service" task above
   - **Priority**: HIGH (other services depend on it)

2. **Audit & Logging Service** (Week 6)
   - See "Implement Audit & Logging Service" task above
   - **Priority**: HIGH (all services use it)

3. **Notification Service** (Week 7)
   - See "Implement Notification Service" task above
   - **Priority**: MEDIUM

4. **Agent Manager Service** (Weeks 7-8)
   - See "Implement Agent Manager Service" task above
   - **Priority**: HIGH (workflow engine needs it)

5. **Validation Service** (Week 8-9)
   - See "Implement Validation Service" task above
   - **Priority**: MEDIUM

6. **Workflow Engine** (Weeks 9-10)
   - See "Implement Workflow Engine" task above
   - **Priority**: HIGH (most complex, requires other services)

7. **Services Overview** (Week 10)
   - Service registry and catalog
   - Health checks for all services

**Reading Order Per Service**: See individual task sections above

**Duration**: 6 weeks
**Validation Checkpoint**:
- All services deployed and running
- Integration tests passing
- 80% code coverage achieved
- PHPStan Level 9 passing

---

### Phase 4: CI/CD Pipeline (Week 11)

**Goal**: Automate build, test, deploy with GitHub Actions + ArgoCD

**Tasks**:
1. GitHub Actions pipelines (see "Set Up CI/CD Pipeline" task above)
2. ArgoCD configuration
3. Quality gates enforcement
4. Deployment strategies (canary)

**Reading Order**:
1. [06-cicd/01-cicd-overview.md](06-cicd/01-cicd-overview.md)
2. [06-cicd/02-pipeline-stages.md](06-cicd/02-pipeline-stages.md)
3. [06-cicd/03-gitops-workflow.md](06-cicd/03-gitops-workflow.md)
4. [06-cicd/04-quality-gates.md](06-cicd/04-quality-gates.md)
5. [06-cicd/05-deployment-strategies.md](06-cicd/05-deployment-strategies.md)

**Duration**: 1 week
**Validation Checkpoint**: CI pipeline passes, ArgoCD auto-deploys to staging

---

### Phase 5: Integration Testing (Week 12)

**Goal**: Test all services working together end-to-end

**Tasks**:
1. Integration test scenarios
2. End-to-end test flows
3. Performance testing
4. Security testing (penetration test)

**Reading Order**:
1. [04-development/04-testing-strategy.md](04-development/04-testing-strategy.md)
2. [05-code-review/02-security-review-checklist.md](05-code-review/02-security-review-checklist.md)
3. [07-operations/05-performance-tuning.md](07-operations/05-performance-tuning.md)

**Duration**: 1 week
**Validation Checkpoint**: All integration tests passing, load test meets SLOs

---

### Phase 6: Production Deployment (Week 13)

**Goal**: Deploy to production with canary rollout

**Tasks**:
1. Production namespace configuration
2. Canary deployment (10% → 50% → 100%)
3. Monitoring and alerting validation
4. Incident response procedures
5. Backup and disaster recovery testing

**Reading Order**:
1. [06-cicd/05-deployment-strategies.md](06-cicd/05-deployment-strategies.md)
2. [07-operations/01-operations-overview.md](07-operations/01-operations-overview.md)
3. [07-operations/02-monitoring-alerting.md](07-operations/02-monitoring-alerting.md)
4. [07-operations/03-incident-response.md](07-operations/03-incident-response.md)
5. [07-operations/04-backup-recovery.md](07-operations/04-backup-recovery.md)

**Duration**: 1 week
**Validation Checkpoint**: Production running stable, all SLOs met, zero incidents

---

## Service Implementation Workflows

### Generic Service Implementation Workflow

**Use this workflow for implementing ANY service** (applies to all 7 services):

#### Step 1: Read Service Documentation (60-90 min)
1. Read foundation files (if not already done)
2. Read service-specific file in [08-services/](08-services/)
3. Read related infrastructure files (RabbitMQ, database, etc.)

#### Step 2: Set Up Service Structure (30 min)
```bash
mkdir -p src/Domain/{Entity,ValueObject,Event,Service,Repository}
mkdir -p src/Application/{UseCase,Query,Command,DTO}
mkdir -p src/Infrastructure/{Persistence,HTTP,Messaging,Configuration}
mkdir -p tests/{Unit,Integration,E2E}
```

**Validation**: Directory structure matches hexagonal architecture

#### Step 3: Implement Domain Layer (2-3 days)
1. Create entities, value objects, aggregates
2. Define domain events
3. Create domain services
4. Define repository interfaces (ports)
5. Write unit tests for domain logic (70% of tests)

**Reading**:
- [01-architecture/04-domain-driven-design.md](01-architecture/04-domain-driven-design.md) (DDD patterns)
- Service file in [08-services/](08-services/) (domain model section)

**Validation**: All domain tests passing, 100% coverage on domain layer

#### Step 4: Implement Application Layer (1-2 days)
1. Create use cases (commands/queries)
2. Define DTOs for input/output
3. Implement application services
4. Write integration tests for use cases (20% of tests)

**Reading**:
- [01-architecture/03-hexagonal-architecture.md](01-architecture/03-hexagonal-architecture.md) (application layer)
- Service file in [08-services/](08-services/) (use cases section)

**Validation**: All use case tests passing, 100% coverage on application layer

#### Step 5: Implement Infrastructure Layer (1-2 days)
1. Create repository implementations (PostgreSQL)
2. Create HTTP controllers (REST API)
3. Create message handlers (RabbitMQ)
4. Configure dependency injection
5. Write E2E tests (10% of tests)

**Reading**:
- [04-development/03-symfony-best-practices.md](04-development/03-symfony-best-practices.md) (Symfony DI)
- [04-development/05-api-design-guidelines.md](04-development/05-api-design-guidelines.md) (REST API)
- Service file in [08-services/](08-services/) (API endpoints, database schema)

**Validation**: E2E tests passing, service responds to HTTP requests

#### Step 6: Database Setup (1 day)
1. Create migration (PostgreSQL schema)
2. Add indexes
3. Configure partitioning (if needed)
4. Seed test data

**Reading**:
- [04-development/06-database-guidelines.md](04-development/06-database-guidelines.md)
- Service file in [08-services/](08-services/) (database schema section)

**Validation**: Migration runs successfully, indexes created

#### Step 7: Integration & Testing (1 day)
1. Integration with Vault (secrets)
2. Integration with Keycloak (authentication)
3. Integration with RabbitMQ (events)
4. Run full test suite

**Reading**:
- [04-development/04-testing-strategy.md](04-development/04-testing-strategy.md)

**Validation**:
- All tests passing (unit + integration + E2E)
- Code coverage ≥ 80%
- PHPStan Level 9 passing

#### Step 8: Deployment (1 day)
1. Create Dockerfile
2. Create Kubernetes manifests
3. Create Istio resources (VirtualService, DestinationRule)
4. Deploy to dev namespace
5. Verify health checks

**Reading**:
- [03-infrastructure/02-kubernetes-architecture.md](03-infrastructure/02-kubernetes-architecture.md)
- [03-infrastructure/03-service-mesh.md](03-infrastructure/03-service-mesh.md)

**Validation**: Service running in Kubernetes, health check endpoint responding

**Total Time Per Service**: 7-10 days

---

## Validation Checkpoints

### After Reading Foundation Files

**Checkpoint**: Verify you understand the core patterns

**Questions to Answer**:
1. What are the 3 layers in Hexagonal Architecture? (Domain, Application, Infrastructure)
2. What is the dependency rule? (Domain ← Application ← Infrastructure)
3. What is an Aggregate in DDD? (Cluster of entities with consistency boundary)
4. What is the difference between Entity and Value Object? (Entity has identity, Value Object doesn't)
5. What is a Domain Event? (Something that happened in the domain that domain experts care about)
6. What is PHPStan Level 9? (Maximum static analysis level, no mixed types)
7. What is the minimum code coverage? (80%)

**If you can answer all 7**: ✅ Proceed to service implementation
**If you cannot**: ❌ Re-read foundation files

---

### After Implementing Domain Layer

**Checkpoint**: Verify domain logic is correct and independent

**Verification Steps**:
1. Run domain unit tests: `vendor/bin/phpunit tests/Unit/Domain/`
   - **Expected**: All tests passing
2. Check domain has no infrastructure dependencies:
   ```bash
   grep -r "use Doctrine" src/Domain/
   grep -r "use Symfony" src/Domain/
   ```
   - **Expected**: No results (domain should be pure PHP)
3. Run PHPStan on domain:
   ```bash
   vendor/bin/phpstan analyse --level=9 src/Domain/
   ```
   - **Expected**: 0 errors
4. Check domain coverage:
   ```bash
   vendor/bin/phpunit --coverage-text --coverage-filter=src/Domain/
   ```
   - **Expected**: 100% coverage (domain is pure logic, easy to test)

**If all pass**: ✅ Proceed to application layer
**If any fail**: ❌ Fix domain implementation before proceeding

---

### After Implementing Application Layer

**Checkpoint**: Verify use cases are correct

**Verification Steps**:
1. Run application integration tests:
   ```bash
   vendor/bin/phpunit tests/Integration/Application/
   ```
   - **Expected**: All tests passing
2. Run PHPStan on application:
   ```bash
   vendor/bin/phpstan analyse --level=9 src/Application/
   ```
   - **Expected**: 0 errors
3. Check application coverage:
   ```bash
   vendor/bin/phpunit --coverage-text --coverage-filter=src/Application/
   ```
   - **Expected**: ≥ 90% coverage

**If all pass**: ✅ Proceed to infrastructure layer
**If any fail**: ❌ Fix application implementation before proceeding

---

### After Implementing Infrastructure Layer

**Checkpoint**: Verify service is fully functional

**Verification Steps**:
1. Run all tests:
   ```bash
   vendor/bin/phpunit
   ```
   - **Expected**: All tests passing (unit + integration + E2E)
2. Check total coverage:
   ```bash
   vendor/bin/phpunit --coverage-text
   ```
   - **Expected**: ≥ 80% overall coverage
3. Run PHPStan on entire codebase:
   ```bash
   vendor/bin/phpstan analyse --level=9 src/
   ```
   - **Expected**: 0 errors
4. Run Psalm:
   ```bash
   vendor/bin/psalm --no-cache
   ```
   - **Expected**: 0 errors
5. Test API endpoint:
   ```bash
   curl http://localhost:8000/health
   ```
   - **Expected**: `{"status":"ok"}`

**If all pass**: ✅ Proceed to deployment
**If any fail**: ❌ Fix implementation before deploying

---

### After Deploying Service

**Checkpoint**: Verify service is running correctly in Kubernetes

**Verification Steps**:
1. Check pod status:
   ```bash
   kubectl get pods -n dev -l app=<service-name>
   ```
   - **Expected**: All pods `Running` with `READY 2/2` (app + istio-proxy)
2. Check logs:
   ```bash
   kubectl logs -n dev -l app=<service-name> -c app
   ```
   - **Expected**: No errors, service started successfully
3. Test health endpoint through Istio:
   ```bash
   kubectl exec -n dev <some-pod> -c app -- curl http://<service-name>:8000/health
   ```
   - **Expected**: `{"status":"ok"}`
4. Check Prometheus metrics:
   - Go to Grafana
   - Open service dashboard
   - **Expected**: Metrics showing (requests, latency, errors)
5. Check mTLS:
   ```bash
   istioctl authn tls-check <pod-name>.<namespace> <service-name>.<namespace>.svc.cluster.local
   ```
   - **Expected**: `mTLS: STRICT`

**If all pass**: ✅ Service successfully deployed
**If any fail**: ❌ Debug deployment before proceeding

---

### After Complete Platform Deployment

**Checkpoint**: Verify entire platform is operational

**Verification Steps**:
1. All services running:
   ```bash
   kubectl get pods -n production
   ```
   - **Expected**: All 7 services with status `Running`
2. Integration test:
   ```bash
   vendor/bin/behat
   ```
   - **Expected**: All E2E scenarios passing
3. Load test:
   ```bash
   k6 run tests/Performance/load-test.js
   ```
   - **Expected**: P95 < 200ms, error rate < 0.1%
4. Security scan:
   ```bash
   trivy image <registry>/authentication-service:latest
   ```
   - **Expected**: No HIGH or CRITICAL vulnerabilities
5. Grafana dashboards:
   - Open system dashboard
   - **Expected**: All services green, SLOs met

**If all pass**: ✅ Platform ready for production
**If any fail**: ❌ Fix issues before going to production

---

## Common Patterns Quick Reference

### Quick Reference: Hexagonal Architecture Structure

```
src/
├── Domain/                          # Pure business logic (no infrastructure)
│   ├── Entity/                      # Objects with identity (User, Workflow)
│   ├── ValueObject/                 # Objects without identity (Email, Money)
│   ├── Event/                       # Domain events (UserCreated, WorkflowCompleted)
│   ├── Service/                     # Domain services (business rules spanning entities)
│   └── Repository/                  # Repository interfaces (ports)
├── Application/                     # Use cases and orchestration
│   ├── UseCase/                     # Commands (CreateUser, StartWorkflow)
│   ├── Query/                       # Queries (GetUser, ListWorkflows)
│   ├── DTO/                         # Data Transfer Objects
│   └── Service/                     # Application services (orchestration)
└── Infrastructure/                  # Technical implementation (adapters)
    ├── Persistence/                 # Database implementations (Doctrine repositories)
    ├── HTTP/                        # REST API controllers
    ├── Messaging/                   # RabbitMQ consumers/producers
    └── Configuration/               # Symfony configuration
```

**Dependency Rule**: Domain → Application → Infrastructure (arrows point INWARD)

---

### Quick Reference: DDD Tactical Patterns

| Pattern | Purpose | Example | Location |
|---------|---------|---------|----------|
| **Entity** | Object with identity that changes over time | `User`, `Workflow`, `Agent` | `src/Domain/Entity/` |
| **Value Object** | Immutable object without identity | `Email`, `WorkflowState`, `TokenCount` | `src/Domain/ValueObject/` |
| **Aggregate** | Cluster of entities with consistency boundary | `User` (includes `Role`, `Permission`) | `src/Domain/Entity/` |
| **Domain Event** | Something that happened in the domain | `UserCreated`, `WorkflowCompleted` | `src/Domain/Event/` |
| **Domain Service** | Business logic spanning multiple entities | `WorkflowExecutor`, `TokenCalculator` | `src/Domain/Service/` |
| **Repository** | Interface for aggregate persistence | `UserRepository`, `WorkflowRepository` | `src/Domain/Repository/` (interface), `src/Infrastructure/Persistence/` (implementation) |

---

### Quick Reference: Common Code Snippets

#### Entity with Aggregate Root

```php
<?php
declare(strict_types=1);

namespace App\Domain\Entity;

use App\Domain\Event\UserCreated;
use App\Domain\ValueObject\Email;
use App\Domain\ValueObject\UserId;

final class User
{
    private array $domainEvents = [];

    public function __construct(
        private readonly UserId $id,
        private Email $email,
        private string $passwordHash,
    ) {
        $this->domainEvents[] = new UserCreated($this->id, $this->email);
    }

    public static function create(Email $email, string $passwordHash): self
    {
        return new self(UserId::generate(), $email, $passwordHash);
    }

    public function changeEmail(Email $newEmail): void
    {
        $this->email = $newEmail;
    }

    public function popDomainEvents(): array
    {
        $events = $this->domainEvents;
        $this->domainEvents = [];
        return $events;
    }
}
```

#### Value Object

```php
<?php
declare(strict_types=1);

namespace App\Domain\ValueObject;

final readonly class Email
{
    public function __construct(
        private string $value,
    ) {
        if (!filter_var($value, FILTER_VALIDATE_EMAIL)) {
            throw new \InvalidArgumentException("Invalid email: {$value}");
        }
    }

    public function value(): string
    {
        return $this->value;
    }

    public function equals(Email $other): bool
    {
        return $this->value === $other->value;
    }
}
```

#### Use Case (Command)

```php
<?php
declare(strict_types=1);

namespace App\Application\UseCase;

use App\Domain\Entity\User;
use App\Domain\Repository\UserRepository;
use App\Domain\ValueObject\Email;

final readonly class CreateUser
{
    public function __construct(
        private UserRepository $userRepository,
    ) {}

    public function execute(CreateUserCommand $command): User
    {
        $email = new Email($command->email);

        if ($this->userRepository->findByEmail($email) !== null) {
            throw new \DomainException("User already exists");
        }

        $user = User::create($email, $command->passwordHash);
        $this->userRepository->save($user);

        return $user;
    }
}
```

#### Repository Interface (Port)

```php
<?php
declare(strict_types=1);

namespace App\Domain\Repository;

use App\Domain\Entity\User;
use App\Domain\ValueObject\Email;
use App\Domain\ValueObject\UserId;

interface UserRepository
{
    public function save(User $user): void;
    public function findById(UserId $id): ?User;
    public function findByEmail(Email $email): ?User;
}
```

#### Repository Implementation (Adapter)

```php
<?php
declare(strict_types=1);

namespace App\Infrastructure\Persistence;

use App\Domain\Entity\User;
use App\Domain\Repository\UserRepository;
use App\Domain\ValueObject\Email;
use App\Domain\ValueObject\UserId;
use Doctrine\ORM\EntityManagerInterface;

final readonly class DoctrineUserRepository implements UserRepository
{
    public function __construct(
        private EntityManagerInterface $entityManager,
    ) {}

    public function save(User $user): void
    {
        $this->entityManager->persist($user);
        $this->entityManager->flush();
    }

    public function findById(UserId $id): ?User
    {
        return $this->entityManager->find(User::class, $id->value());
    }

    public function findByEmail(Email $email): ?User
    {
        return $this->entityManager->getRepository(User::class)
            ->findOneBy(['email.value' => $email->value()]);
    }
}
```

---

### Quick Reference: Testing Patterns

#### Unit Test (Domain)

```php
<?php
declare(strict_types=1);

namespace App\Tests\Unit\Domain\Entity;

use App\Domain\Entity\User;
use App\Domain\ValueObject\Email;
use PHPUnit\Framework\TestCase;

final class UserTest extends TestCase
{
    public function testCreateUser(): void
    {
        $email = new Email('user@example.com');
        $user = User::create($email, 'hashed_password');

        $this->assertEquals($email, $user->email());
        $this->assertCount(1, $user->popDomainEvents());
    }
}
```

#### Integration Test (Use Case)

```php
<?php
declare(strict_types=1);

namespace App\Tests\Integration\Application\UseCase;

use App\Application\UseCase\CreateUser;
use App\Application\UseCase\CreateUserCommand;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;

final class CreateUserTest extends KernelTestCase
{
    public function testExecute(): void
    {
        self::bootKernel();
        $container = self::getContainer();

        $useCase = $container->get(CreateUser::class);
        $command = new CreateUserCommand('user@example.com', 'hashed_password');

        $user = $useCase->execute($command);

        $this->assertNotNull($user->id());
    }
}
```

---

## Troubleshooting Decision Tree

### Problem: "I don't know which file to read first"

**Solution**:
1. Are you starting from scratch? → Read [Quick Start: First 5 Files](#quick-start-first-5-files-to-read)
2. Do you have a specific task? → Use [Task-Based Navigation Matrix](#task-based-navigation-matrix)
3. General exploration? → Read [README.md](README.md) first

---

### Problem: "The file references another concept I don't understand"

**Solution**:
1. Look for cross-reference link in the file (200+ links throughout docs)
2. If no link, search in [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)
3. Read that file, then return to original file

**Example**:
- Reading about Workflow Engine, see mention of "Saga pattern"
- Find cross-reference: [01-architecture/06-communication-patterns.md](01-architecture/06-communication-patterns.md)
- Read that section on Saga pattern
- Return to Workflow Engine file with understanding

---

### Problem: "I implemented a service but tests are failing"

**Solution - Follow this debug sequence**:

1. **Domain tests failing?**
   - Check: Are you using infrastructure in domain layer? (Grep for Doctrine/Symfony in Domain/)
   - Fix: Remove infrastructure dependencies, use pure PHP
   - Reference: [01-architecture/03-hexagonal-architecture.md](01-architecture/03-hexagonal-architecture.md)

2. **Application tests failing?**
   - Check: Are your use cases orchestrating correctly?
   - Fix: Verify use case has all dependencies injected
   - Reference: [01-architecture/03-hexagonal-architecture.md](01-architecture/03-hexagonal-architecture.md) (Application Layer section)

3. **Integration/E2E tests failing?**
   - Check: Is database schema correct?
   - Fix: Run migrations, check database state
   - Reference: [04-development/06-database-guidelines.md](04-development/06-database-guidelines.md)

4. **PHPStan Level 9 failing?**
   - Check: Type errors?
   - Fix: Add type declarations, remove mixed types
   - Reference: [04-development/02-coding-guidelines-php.md](04-development/02-coding-guidelines-php.md)

5. **Coverage below 80%?**
   - Check: Which files have low coverage? (`vendor/bin/phpunit --coverage-html coverage/`)
   - Fix: Write tests for uncovered code
   - Reference: [04-development/04-testing-strategy.md](04-development/04-testing-strategy.md)

---

### Problem: "Service deployed but pods are CrashLoopBackOff"

**Solution - Debug sequence**:

1. **Check logs**:
   ```bash
   kubectl logs -n dev <pod-name> -c app
   ```
   - Look for errors in application startup

2. **Common causes**:
   - Database connection failed → Check Vault secrets
   - RabbitMQ connection failed → Check service mesh configuration
   - Environment variables missing → Check ConfigMap/Secret
   - Port conflict → Check Dockerfile EXPOSE and Service port

3. **Check readiness probe**:
   ```bash
   kubectl describe pod -n dev <pod-name>
   ```
   - Look for failed readiness checks
   - Verify `/health` endpoint is responding

4. **Reference**: [03-infrastructure/02-kubernetes-architecture.md](03-infrastructure/02-kubernetes-architecture.md) (Troubleshooting section)

---

### Problem: "mTLS not working between services"

**Solution**:

1. **Verify Istio injection**:
   ```bash
   kubectl get pod <pod-name> -n dev -o jsonpath='{.spec.containers[*].name}'
   ```
   - Expected: `app istio-proxy` (2 containers)
   - If only `app`: Istio sidecar not injected
   - Fix: Label namespace with `istio-injection=enabled`

2. **Check PeerAuthentication**:
   ```bash
   kubectl get peerauthentication -n dev
   ```
   - Expected: Mode `STRICT`
   - If missing: Create PeerAuthentication resource

3. **Test mTLS**:
   ```bash
   istioctl authn tls-check <pod-name>.<namespace> <service-name>.<namespace>.svc.cluster.local
   ```
   - Expected: `mTLS: STRICT`

4. **Reference**: [03-infrastructure/03-service-mesh.md](03-infrastructure/03-service-mesh.md) (mTLS section)

---

### Problem: "API requests timing out"

**Solution - Debug sequence**:

1. **Check application logs** (slow query? exception?):
   ```bash
   kubectl logs -n dev <pod-name> -c app | grep -i error
   ```

2. **Check database performance**:
   ```sql
   SELECT * FROM pg_stat_activity WHERE state = 'active' AND query_start < now() - interval '5 seconds';
   ```
   - Are queries slow? → Add indexes
   - Reference: [04-development/06-database-guidelines.md](04-development/06-database-guidelines.md)

3. **Check Istio timeout configuration**:
   ```bash
   kubectl get virtualservice <service-name> -n dev -o yaml
   ```
   - Look for `timeout:` field
   - Default: 15s, may need to increase for slow operations

4. **Check circuit breaker**:
   ```bash
   kubectl get destinationrule <service-name> -n dev -o yaml
   ```
   - Circuit breaker may be open → Check error rate

5. **Reference**: [04-development/08-performance-optimization.md](04-development/08-performance-optimization.md)

---

### Problem: "I need to implement a new feature not documented"

**Solution**:

1. **Find similar feature in documentation**:
   - Search in [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)
   - Look for similar use cases in existing services

2. **Follow same patterns**:
   - Use Hexagonal Architecture structure
   - Apply DDD tactical patterns
   - Write tests first (TDD)

3. **Reference existing service**:
   - Use [08-services/03-workflow-engine.md](08-services/03-workflow-engine.md) as template (most comprehensive)
   - Copy structure, adapt to your feature

4. **Validation**:
   - PHPStan Level 9 must pass
   - Coverage must be ≥ 80%
   - All architectural patterns followed

---

## Summary: LLM Success Criteria

### Before Starting Implementation

✅ **Foundation Knowledge Acquired**:
- Read 5 foundation files (README, architecture overview, hexagonal, DDD, coding guidelines)
- Understand dependency rule (Domain ← Application ← Infrastructure)
- Understand testing strategy (70% unit, 20% integration, 10% E2E)

### During Implementation

✅ **Following Patterns**:
- All services use Hexagonal Architecture structure
- All domain logic uses DDD tactical patterns
- All code follows PSR-1/PSR-4/PSR-12 standards
- All code uses PHP 8.3 features and type safety

✅ **Quality Gates Passing**:
- PHPStan Level 9 passing (0 errors)
- Code coverage ≥ 80%
- All tests passing (unit + integration + E2E)
- Security scans passing (no HIGH/CRITICAL vulnerabilities)

### After Implementation

✅ **Service Running**:
- Pods running in Kubernetes
- Health check responding
- mTLS enabled (STRICT mode)
- Metrics showing in Grafana
- Logs appearing in Loki
- Traces appearing in Tempo

✅ **Integration Working**:
- Service communicates with other services
- Events published to RabbitMQ
- Data persisted in PostgreSQL
- Secrets retrieved from Vault
- Authentication via Keycloak working

### Platform Complete

✅ **All 7 Services Deployed**:
- Authentication Service ✅
- Workflow Engine ✅
- Agent Manager ✅
- Validation Service ✅
- Notification Service ✅
- Audit & Logging Service ✅
- Services Overview ✅

✅ **Infrastructure Running**:
- Kubernetes cluster ✅
- Istio service mesh ✅
- Observability stack (Prometheus, Grafana, Loki, Tempo) ✅
- HashiCorp Vault ✅
- Keycloak ✅
- Kong API Gateway ✅
- RabbitMQ ✅
- PostgreSQL (per service) ✅

✅ **CI/CD Operational**:
- GitHub Actions CI pipeline ✅
- ArgoCD GitOps CD ✅
- Quality gates enforced ✅
- Canary deployments configured ✅

✅ **Production Ready**:
- Load testing passed (P95 < 200ms) ✅
- Security audit passed ✅
- GDPR compliance verified ✅
- Disaster recovery tested ✅
- Incident response procedures documented ✅
- On-call rotation configured ✅

---

## Meta: How This Guide Was Created

**Purpose**: This guide was created specifically to optimize LLM navigation through the 60-file, 500,000+ word documentation suite.

**Design Principles**:
1. **Task-Based Navigation**: LLMs work best with specific tasks, not general exploration
2. **Optimal Reading Order**: Files listed in order that builds context progressively
3. **Prerequisites Explicit**: No assumptions about prior knowledge
4. **Validation Checkpoints**: Verify understanding before proceeding (reduce errors)
5. **Troubleshooting Trees**: Common problems with step-by-step solutions

**Maintenance**: Update this guide when:
- New services are added
- Architecture patterns change
- Common LLM issues are discovered
- Feedback from LLM usage suggests improvements

---

**Last Updated**: 2025-01-07
**Documentation Version**: 2.0.0
**Next Review**: After first LLM-driven implementation

**For Questions**: This is the master navigation guide. If you cannot find what you need here, consult [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md) for the complete file listing.
