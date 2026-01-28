# LLM Prompts - Ready-to-Use Templates

**Purpose**: Copy-paste ready prompts to give to an LLM agent to implement the AI Workflow Processing Platform using this documentation.

**Last Updated**: 2025-01-07
**Documentation Path**: `docs/`

---

## 📋 Table of Contents

1. [Initial Project Kickoff Prompt](#initial-project-kickoff-prompt)
2. [Phase-by-Phase Implementation Prompts](#phase-by-phase-implementation-prompts)
3. [Service-Specific Implementation Prompts](#service-specific-implementation-prompts)
4. [Infrastructure Setup Prompts](#infrastructure-setup-prompts)
5. [Debugging & Troubleshooting Prompts](#debugging--troubleshooting-prompts)

---

## Initial Project Kickoff Prompt

### 🚀 Full Platform Implementation (Complete Project)

**Use Case**: You want the LLM to implement the ENTIRE platform from scratch to production.

```
I want you to implement the complete AI Workflow Processing Platform following the comprehensive technical documentation located at docs/.

IMPORTANT INSTRUCTIONS:
1. START by reading docs/LLM_USAGE_GUIDE.md - this is your PRIMARY navigation guide designed specifically for LLMs like you
2. Follow the implementation plan in docs/IMPLEMENTATION_ROADMAP.md (13 weeks, Phase 0 through Phase 6)
3. Use docs/CODE_EXAMPLES_INDEX.md as reference for code patterns

CONTEXT:
- Platform: Enterprise-grade, cloud-native microservices platform
- Tech Stack: PHP 8.3, Symfony 7, PostgreSQL 15+, Kubernetes 1.28+, Istio 1.20+
- Architecture: Hexagonal Architecture, Domain-Driven Design, Event-Driven, Zero Trust Security
- Services: 7 microservices (Authentication, Workflow Engine, Agent Manager, Validation, Notification, Audit & Logging)
- Documentation: 60+ files, 500,000+ words, 500+ code examples

YOUR TASK:
Start with Phase 0 (Environment Setup) from the IMPLEMENTATION_ROADMAP.md. For each phase:
1. Read the specified documentation files in the order indicated
2. Execute the tasks listed (infrastructure setup, service implementation, testing, deployment)
3. Run validation commands at checkpoints
4. Report progress and any issues encountered

Begin by reading the LLM_USAGE_GUIDE.md and confirming you understand the navigation system. Then proceed with Phase 0: Environment Setup.

Working directory: 
Documentation root: docs/

Are you ready to start? Please confirm by summarizing the implementation approach from the LLM_USAGE_GUIDE.md.
```

---

### 🎯 Quick Start (Single Service Implementation)

**Use Case**: You want to implement just ONE specific service to test the approach.

```
I want you to implement the Authentication Service for the AI Workflow Processing Platform using the documentation at docs/.

STEP-BY-STEP APPROACH:
1. Read docs/LLM_USAGE_GUIDE.md (section: "Task: Implement Authentication Service")
2. Follow the reading order specified:
   - Foundation files (README, architecture overview, hexagonal, DDD, coding guidelines)
   - Security context (authentication-authorization.md, secrets-management.md)
   - Main implementation file: 08-services/02-authentication-service.md
   - Testing strategy
3. Implement following the 8-step workflow:
   - Step 1-2: Domain Layer (entities, value objects, aggregates)
   - Step 3-4: Application Layer (use cases)
   - Step 5: Infrastructure Layer (repositories, controllers, API)
   - Step 6: Database (migrations, schema)
   - Step 7: Integration (Vault, Keycloak, RabbitMQ)
   - Step 8: Deployment (Kubernetes manifests)

QUALITY REQUIREMENTS:
- PHPStan Level 9 (maximum static analysis)
- Code coverage ≥ 80%
- All tests passing (unit + integration + E2E)
- Hexagonal Architecture pattern strictly followed
- DDD tactical patterns applied

VALIDATION CHECKPOINTS:
After each step, run the validation commands specified in the LLM_USAGE_GUIDE.md.

Working directory: services/authentication/
Documentation: docs/

Start by reading the prerequisites section in docs/08-services/02-authentication-service.md and confirm you understand the requirements before implementing.
```

---

## Phase-by-Phase Implementation Prompts

### Phase 0: Environment Setup

```
Set up my local development environment for the AI Workflow Processing Platform following Phase 0 from docs/IMPLEMENTATION_ROADMAP.md.

TASKS (execute in order):
1. Install PHP 8.3, Composer, Symfony CLI
2. Install Docker Desktop
3. Install kubectl, helm, istioctl, k9s
4. Install and configure IDE (PHPStorm recommended)
5. Set up local services (PostgreSQL, Redis, RabbitMQ) with Docker Compose

DOCUMENTATION REFERENCE:
- docs/IMPLEMENTATION_ROADMAP.md (Phase 0, Days 1-2)
- docs/04-development/01-development-standards.md

VALIDATION:
After completion, verify with these commands:
- php -v (should show 8.3+)
- symfony check:requirements (all green)
- docker ps (postgres, redis, rabbitmq running)
- kubectl version --client

Report the results of these validation commands when done.
```

---

### Phase 1: Infrastructure Foundation (Kubernetes + Istio + Observability)

```
Deploy the complete infrastructure foundation (Kubernetes cluster, Istio service mesh, and observability stack) following Phase 1 from docs/IMPLEMENTATION_ROADMAP.md.

DURATION: 2 weeks (10 working days)

WEEK 1: Kubernetes Cluster
Tasks:
- Days 1-3: Deploy Kubernetes cluster (choose: minikube for local OR cloud provider)
- Create namespaces (dev, staging, production, observability, security)
- Configure RBAC and resource quotas
- Days 4-6: Install Istio 1.20+, enable sidecar injection, configure mTLS (STRICT mode)
- Days 7-10: Deploy observability stack (Prometheus, Grafana, Loki, Tempo)

DOCUMENTATION REFERENCES (read in order):
1. docs/03-infrastructure/01-infrastructure-overview.md
2. docs/03-infrastructure/02-kubernetes-architecture.md ⚠️ PRIMARY
3. docs/03-infrastructure/03-service-mesh.md
4. docs/03-infrastructure/04-observability-stack.md

VALIDATION CHECKPOINT (end of Week 2):
Run these commands and report results:
- kubectl get nodes
- kubectl get namespaces
- istioctl verify-install
- kubectl get peerauthentication -n dev (should show STRICT mode)
- kubectl get pods -n observability (all Running)
- Access Grafana UI and verify dashboards

Proceed step-by-step, validate at each checkpoint before moving forward.
```

---

### Phase 2: Security Infrastructure (Vault + Keycloak + Kong)

```
Deploy the security infrastructure (HashiCorp Vault, Keycloak, Kong API Gateway) following Phase 2 from docs/IMPLEMENTATION_ROADMAP.md.

DURATION: 2 weeks (10 working days)

WEEK 3: Vault Setup
- Days 1-3: Deploy Vault in HA mode (3 replicas), initialize and unseal
- Enable Kubernetes auth, create secret engines (KV, Database)
- Create policies for each service
- Install Vault Agent Injector

WEEK 4: Keycloak + Kong
- Days 4-6: Deploy Keycloak (3 replicas), configure realm "ai-workflow-platform"
- Create OAuth2 clients for services, configure RBAC roles
- Days 7-10: Deploy Kong API Gateway, configure OAuth2 plugin and rate limiting

DOCUMENTATION REFERENCES (read in order):
1. docs/02-security/01-security-principles.md
2. docs/02-security/04-secrets-management.md ⚠️ PRIMARY for Vault
3. docs/02-security/03-authentication-authorization.md
4. docs/02-security/05-network-security.md

VALIDATION CHECKPOINT (end of Week 4):
- kubectl get pods -n security (Vault, Keycloak, Kong all Running)
- kubectl exec -n security vault-0 -- vault status (Sealed: false)
- Access Keycloak admin console (http://localhost:8080), verify realm configured
- kubectl get ingress -n dev (Kong routes configured)

Report results and any issues encountered.
```

---

### Phase 3: Core Services Implementation

```
Implement all 7 essential microservices following Phase 3 from docs/IMPLEMENTATION_ROADMAP.md.

DURATION: 6 weeks (30 working days)

IMPLEMENTATION ORDER (with dependencies):
Week 5: Authentication Service (HIGH PRIORITY - all others depend on it)
Week 6: Audit & Logging Service (HIGH PRIORITY - all services use it)
Week 7: Agent Manager + Validation Service (parallel development)
Week 9: Notification Service
Week 10: Workflow Engine (MOST COMPLEX - implement last)

FOR EACH SERVICE, FOLLOW THIS WORKFLOW:
1. Read prerequisites section in the service file (docs/08-services/0X-service-name.md)
2. Implement Domain Layer (Days 1-2): Entities, Value Objects, Events, Repository interfaces
3. Implement Application Layer (Days 3-4): Use Cases, DTOs, Application Services
4. Implement Infrastructure Layer (Day 5): Repositories, Controllers, Messaging
5. Database Setup (Day 6): Migrations, indexes, partitioning
6. Testing (Days 7-8): Unit, Integration, E2E tests (≥80% coverage)
7. Quality Gates (Day 9): PHPStan Level 9, Psalm, security scans
8. Deployment (Day 10): Kubernetes manifests, deploy to dev namespace

DOCUMENTATION FOR EACH SERVICE:
Read the prerequisites section first, then the complete service file in docs/08-services/

VALIDATION FOR EACH SERVICE:
- All tests passing: vendor/bin/phpunit
- PHPStan Level 9: vendor/bin/phpstan analyse --level=9 src/
- Coverage ≥80%: vendor/bin/phpunit --coverage-text
- Service deployed: kubectl get pods -n dev -l app=<service-name>
- Health check: kubectl exec -n dev <pod> -- curl http://localhost:8000/health

Start with Authentication Service (Week 5). Confirm you're ready by reading docs/08-services/02-authentication-service.md prerequisites.
```

---

## Service-Specific Implementation Prompts

### Authentication Service

```
Implement the Authentication Service (OAuth2, JWT, RBAC, MFA) following the complete guide at docs/08-services/02-authentication-service.md.

BEFORE YOU START:
Read prerequisites (first section of the service file):
- Foundation: README, architecture overview, hexagonal, DDD, coding guidelines
- Security: authentication-authorization.md, secrets-management.md
- Testing: testing-strategy.md

IMPLEMENTATION (7-10 days):
Domain Layer (Days 1-2):
- User entity (aggregate root) with roles and permissions
- Email, UserId value objects
- UserCreated, UserLoggedIn domain events
- UserRepository interface
- Unit tests (100% coverage on domain)

Application Layer (Days 3-4):
- RegisterUser, LoginUser, LogoutUser, RefreshToken, ValidateToken use cases
- DTOs for commands and queries
- Integration tests for all use cases

Infrastructure Layer (Day 5):
- DoctrineUserRepository implementation
- REST API controllers (Symfony)
- JWT token manager (lexik/jwt-authentication-bundle)
- Keycloak integration
- RabbitMQ event publisher

Database (Day 6):
- Migration for users, roles, permissions tables
- Indexes (email, is_active)
- Junction tables (user_roles, role_permissions)

Testing & Quality (Days 7-8):
- E2E tests (registration → login → access protected endpoint)
- PHPStan Level 9 compliance
- Code coverage ≥80%

Deployment (Days 9-10):
- Dockerfile
- Kubernetes Deployment (3 replicas)
- Vault annotations for secrets (JWT keys, database credentials)
- Deploy to dev namespace

QUALITY REQUIREMENTS:
- PHPStan Level 9: 0 errors
- Code coverage: ≥80%
- All tests passing
- No security vulnerabilities (HIGH/CRITICAL)

VALIDATION COMMANDS:
cd services/authentication
vendor/bin/phpunit
vendor/bin/phpstan analyse --level=9 src/
kubectl apply -f infrastructure/kubernetes/services/authentication/ -n dev
kubectl get pods -n dev -l app=authentication-service

Proceed step-by-step. After completing domain layer, report progress before moving to application layer.
```

---

### Workflow Engine Service

```
Implement the Workflow Engine Service (most complex service - state machine, Saga pattern, step executors) following docs/08-services/03-workflow-engine.md.

⚠️ WARNING: This is the MOST COMPLEX service. Read prerequisites carefully and implement LAST (after all other services are ready).

PREREQUISITES (read ALL before starting):
- Foundation: hexagonal, DDD (aggregates, domain events)
- Architecture: communication-patterns.md ⚠️ CRITICAL (Saga pattern, compensation logic)
- Infrastructure: message-queue.md (RabbitMQ event patterns)
- Dependencies: Agent Manager, Validation Service, Notification Service (must be running)

IMPLEMENTATION (7-10 days):
Domain Layer (Days 1-3 - LONGER due to complexity):
- Workflow aggregate with complex state machine (10 states)
- WorkflowDefinition, WorkflowStep entities
- StepExecutor interface (4 implementations: Agent, Transform, Conditional, Parallel)
- WorkflowState enum with transition validation
- Saga pattern for distributed transactions
- 10+ domain events
- 25+ unit tests (state machine, saga compensation)

Application Layer (Days 4-6):
- StartWorkflow, ExecuteStep, CompleteWorkflow, CompensateWorkflow use cases
- Saga orchestration logic
- 15+ integration tests (complete workflow scenarios)

Infrastructure Layer (Days 7-8):
- PostgreSQL schema (workflows, steps, executions, compensations)
- State machine implementation
- Step executor implementations (call Agent Manager, Validation, Notification services)
- REST API (10+ endpoints)
- RabbitMQ for async step execution
- Compensation logic (rollback on failures)

Testing & Deployment (Days 9-10):
- E2E tests (complete workflow: start → execute steps → complete)
- PHPStan Level 9
- 80%+ coverage (challenging due to complexity)
- Deploy to dev with 5 replicas (high availability)

CRITICAL DOCUMENTATION:
docs/08-services/03-workflow-engine.md (76KB, 2,267 lines - MOST COMPREHENSIVE FILE)

VALIDATION:
- All 10 workflow states working
- Saga compensation working (test failure scenarios)
- All 4 step executor types working
- Integration with Agent Manager, Validation, Notification services verified

Start only after Agent Manager, Validation, and Notification services are deployed and tested.
```

---

## Infrastructure Setup Prompts

### Kubernetes Cluster (Local Development)

```
Set up a local Kubernetes cluster for development using minikube, following docs/03-infrastructure/02-kubernetes-architecture.md.

STEPS:
1. Install minikube: https://minikube.sigs.k8s.io/docs/start/
2. Start cluster:
   minikube start --cpus=4 --memory=8192 --kubernetes-version=v1.28.0

3. Create namespaces:
   kubectl create namespace dev
   kubectl create namespace staging
   kubectl create namespace production
   kubectl create namespace observability
   kubectl create namespace security

4. Configure RBAC (apply manifests from docs/03-infrastructure/02-kubernetes-architecture.md)

5. Configure resource quotas for each namespace

VALIDATION:
kubectl cluster-info
kubectl get nodes (should show 1 node Ready)
kubectl get namespaces (should show 5 namespaces)

Report results when complete.
```

---

### Istio Service Mesh

```
Install and configure Istio service mesh with mTLS (STRICT mode) following docs/03-infrastructure/03-service-mesh.md.

STEPS:
1. Install Istio 1.20+:
   istioctl install --set profile=production -y

2. Enable sidecar injection for namespaces:
   kubectl label namespace dev istio-injection=enabled
   kubectl label namespace staging istio-injection=enabled
   kubectl label namespace production istio-injection=enabled

3. Configure mTLS (STRICT mode):
   Apply PeerAuthentication resource from docs/03-infrastructure/03-service-mesh.md

4. Configure Istio Gateway for ingress

VALIDATION:
istioctl verify-install
kubectl get peerauthentication -n dev (should show mode: STRICT)
kubectl get gateway -n dev

All services will now automatically get Istio sidecars and communicate via mTLS.
```

---

## Debugging & Troubleshooting Prompts

### Service Not Starting

```
My service is deployed to Kubernetes but pods are in CrashLoopBackOff state. Help me debug following the troubleshooting guide in docs/LLM_USAGE_GUIDE.md (Troubleshooting section).

SERVICE DETAILS:
- Service name: [SPECIFY]
- Namespace: dev
- Current pod status: CrashLoopBackOff

DEBUG STEPS:
1. Check logs:
   kubectl logs -n dev <pod-name> -c app --tail=100

2. Check events:
   kubectl describe pod -n dev <pod-name>

3. Common issues to check:
   - Database connection (check Vault secrets)
   - RabbitMQ connection (check service mesh configuration)
   - Missing environment variables (check ConfigMap/Secret)
   - Port conflicts (check Dockerfile EXPOSE)

4. Check readiness probe:
   Verify /health endpoint is responding

Execute these debug steps and report findings. I'll help you fix the issue based on the results.
```

---

### Tests Failing

```
My service tests are failing. Help me debug following docs/04-development/04-testing-strategy.md.

TEST DETAILS:
- Service: [SPECIFY]
- Test type: [unit/integration/E2E]
- Failure: [DESCRIBE ERROR]

DEBUG SEQUENCE:
1. Domain tests failing?
   - Check: Are you using infrastructure in domain layer? (Grep for Doctrine/Symfony in Domain/)
   - Fix: Remove infrastructure dependencies, use pure PHP
   - Reference: docs/01-architecture/03-hexagonal-architecture.md

2. Application tests failing?
   - Check: Are use cases orchestrating correctly?
   - Fix: Verify all dependencies are injected
   - Reference: docs/01-architecture/03-hexagonal-architecture.md (Application Layer)

3. Integration/E2E tests failing?
   - Check: Is database schema correct?
   - Fix: Run migrations, verify schema
   - Reference: docs/04-development/06-database-guidelines.md

4. PHPStan Level 9 failing?
   - Check: Type errors?
   - Fix: Add type declarations, remove mixed types
   - Reference: docs/04-development/02-coding-guidelines-php.md

Run vendor/bin/phpunit --verbose and share the error output for detailed troubleshooting.
```

---

### Code Coverage Below 80%

```
My code coverage is below 80% (current: [SPECIFY]%). Help me increase it to meet quality gates following docs/04-development/04-testing-strategy.md.

CURRENT STATUS:
- Service: [SPECIFY]
- Current coverage: [X]%
- Target: ≥80%

STEPS TO INCREASE COVERAGE:
1. Identify uncovered code:
   vendor/bin/phpunit --coverage-html coverage/
   Open coverage/index.html in browser

2. Write tests for uncovered code:
   - Domain layer: Should be 100% covered (pure logic, easy to test)
   - Application layer: Target 90%+ (use cases)
   - Infrastructure layer: Target 70%+ (adapters)

3. Focus on critical paths:
   - All use cases must have tests
   - All domain logic must have tests
   - Happy paths + error cases

4. Use test doubles:
   - Mock external dependencies (databases, APIs)
   - Stub value objects
   - Fake repositories for integration tests

Reference: docs/04-development/04-testing-strategy.md (complete testing strategy)

Which areas have low coverage? Share the coverage report and I'll help you write the missing tests.
```

---

## Usage Tips

### How to Use These Prompts

1. **Copy the prompt** that matches your current task
2. **Fill in placeholders** (marked with [SPECIFY] or <service-name>)
3. **Paste into your LLM interface** (ChatGPT, Claude, etc.)
4. **Provide context** by sharing error messages, logs, or outputs when asked
5. **Follow the LLM's step-by-step guidance**

### Prompt Customization

You can customize these prompts by:
- Adding your specific environment details (cloud provider, cluster size, etc.)
- Adjusting timelines based on your team size
- Adding company-specific requirements
- Combining multiple prompts for larger tasks

### Best Practices

- ✅ **Start small**: Test with one service before implementing the entire platform
- ✅ **Validate at checkpoints**: Run validation commands after each phase
- ✅ **Keep LLM context**: Reference previous steps in follow-up prompts
- ✅ **Share outputs**: When troubleshooting, always share error messages and logs
- ✅ **Iterate**: If the LLM makes a mistake, provide feedback and ask for corrections

---

## Additional Resources

- **Primary Navigation**: [LLM_USAGE_GUIDE.md](LLM_USAGE_GUIDE.md)
- **Implementation Plan**: [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md)
- **Code Examples**: [CODE_EXAMPLES_INDEX.md](CODE_EXAMPLES_INDEX.md)
- **Complete Index**: [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)

---

**Last Updated**: 2025-01-07
**Prompts Version**: 1.0.0
**Documentation Path**: docs/

**Questions?** All prompts reference the comprehensive documentation. If the LLM needs clarification, direct it to read the specific documentation files mentioned in each prompt.
