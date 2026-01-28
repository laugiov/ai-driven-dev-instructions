# Implementation Roadmap

**Purpose**: Step-by-step guide to build the complete AI Workflow Processing Platform from scratch to production.

**Last Updated**: 2025-11-07
**Target Audience**: Development teams and LLMs implementing the platform
**Estimated Total Duration**: 13 weeks (3 months)
**Current Status**: Phase 0 Complete ✅ | Phase 1 Ready 📝

---

## 📋 Overview

This roadmap provides a **sequential, phase-by-phase implementation plan** for building the entire platform. Each phase builds on the previous one, with clear dependencies, validation checkpoints, and acceptance criteria.

**Total Phases**: 7 phases (Week 0 → Week 13)
**Total Services**: 7 microservices
**Infrastructure Components**: 11 (Kubernetes, Istio, Vault, Keycloak, Kong, RabbitMQ, PostgreSQL, Prometheus, Grafana, Loki, Tempo)

---

## Quick Navigation

| Phase | Duration | Goal | Status |
|-------|----------|------|--------|
| [Phase 0: Environment Setup](#phase-0-environment-setup-week-0) | 1-2 days | Local dev environment ready | ✅ COMPLETE |
| [Phase 1: Infrastructure Foundation](#phase-1-infrastructure-foundation-weeks-1-2) | 2 weeks | Kubernetes + Istio + Observability | 📝 READY |
| [Phase 2: Security Infrastructure](#phase-2-security-infrastructure-weeks-3-4) | 2 weeks | Vault + Keycloak + Kong | 📝 TODO |
| [Phase 3: Core Services](#phase-3-core-services-implementation-weeks-5-10) | 6 weeks | All 7 microservices | 📝 TODO |
| [Phase 4: CI/CD Pipeline](#phase-4-cicd-pipeline-week-11) | 1 week | GitHub Actions + ArgoCD | 📝 TODO |
| [Phase 5: Integration Testing](#phase-5-integration-testing-week-12) | 1 week | E2E + Performance + Security | 📝 TODO |
| [Phase 6: Production Deployment](#phase-6-production-deployment-week-13) | 1 week | Canary rollout to production | 📝 TODO |

---

## Phase Dependencies

```
Phase 0 (Environment Setup)
    ↓
Phase 1 (Infrastructure: K8s + Istio + Observability)
    ↓
Phase 2 (Security: Vault + Keycloak + Kong)
    ↓
Phase 3 (Services: Auth → Audit → Agent Manager → Validation → Notification → Workflow Engine)
    ↓
Phase 4 (CI/CD: GitHub Actions + ArgoCD)
    ↓
Phase 5 (Testing: Integration + Performance + Security)
    ↓
Phase 6 (Production: Canary Deployment)
```

**Critical Path**: Each phase MUST be completed and validated before proceeding to the next.

---

## Phase 0: Environment Setup (Week 0) ✅

**Duration**: 1-2 days (Actual: ~1 hour)
**Goal**: Prepare local development environment and tools
**Prerequisites**: None (starting point)
**Status**: ✅ **COMPLETE** (2025-11-07)

### Tasks

#### Day 1: Local Development Tools

**Task 0.1: Install PHP 8.3 and Tools**
- Install PHP 8.3+ (with extensions: opcache, pdo_pgsql, redis, amqp, intl, mbstring)
- Install Composer 2.x
- Install Symfony CLI
- Verify installation: `php -v`, `composer --version`, `symfony check:requirements`

**Task 0.2: Install Docker Desktop**
- Install Docker Desktop (or Docker Engine + Docker Compose)
- Verify: `docker --version`, `docker-compose --version`
- Start Docker daemon

**Task 0.3: Install Kubernetes Tools**
- Install kubectl 1.28+
- Install helm 3.x
- Install istioctl 1.20+
- Install k9s (optional but recommended for cluster visualization)
- Verify: `kubectl version`, `helm version`, `istioctl version`

**Task 0.4: Install IDE and Plugins**
- Install PHPStorm (or VS Code with PHP extensions)
- Install plugins:
  - PHP Inspections (PHPStan, Psalm)
  - Symfony Support
  - Docker
  - Kubernetes
  - Database Navigator

**Task 0.5: Repository Setup**
- Clone repository: `git clone <repo-url>`
- Configure Git: `git config user.name`, `git config user.email`
- Create `.env.local` file for local overrides

#### Day 2: Local Services (Docker Compose)

**Task 0.6: Local PostgreSQL**
```yaml
# docker-compose.yml
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: local_password
    ports:
      - "5432:5432"
```
- Start: `docker-compose up -d postgres`
- Verify: `psql -h localhost -U postgres`

**Task 0.7: Local Redis**
```yaml
  redis:
    image: redis:7
    ports:
      - "6379:6379"
```
- Start: `docker-compose up -d redis`
- Verify: `redis-cli ping` → PONG

**Task 0.8: Local RabbitMQ**
```yaml
  rabbitmq:
    image: rabbitmq:3.12-management
    ports:
      - "5672:5672"
      - "15672:15672"
```
- Start: `docker-compose up -d rabbitmq`
- Verify: Open http://localhost:15672 (guest/guest)

### Documentation References
- [04-development/01-development-standards.md](04-development/01-development-standards.md) - Development environment setup
- [04-development/02-coding-guidelines-php.md](04-development/02-coding-guidelines-php.md) - PHP requirements

### ✅ What Was Actually Implemented

**Completed on**: 2025-11-07

#### Core Infrastructure (100% Complete)
1. ✅ **Docker Compose Setup**
   - PostgreSQL 15 Alpine with performance tuning
   - Redis 7 Alpine with LRU eviction + AOF persistence
   - RabbitMQ 3.12 Management Alpine with Prometheus
   - Mailhog for email testing
   - PgAdmin for database management
   - All services with health checks and proper start periods

2. ✅ **PostgreSQL Databases**
   - Database per Service pattern: 7 databases created
   - authentication_service, workflow_engine, agent_manager
   - validation_service, notification_service, audit_logging
   - ai_workflow_dev (main development database)

3. ✅ **RabbitMQ Configuration**
   - Topic exchange: `domain_events`
   - Quorum queues: workflow.events, notification.events, audit.events
   - Proper routing bindings for event-driven architecture
   - Prometheus metrics enabled on port 15692

4. ✅ **Development Tools** (Verified installed)
   - PHP 8.3.6 with required extensions
   - Composer 2.8.8
   - Symfony CLI 4.21.3
   - Docker 28.3.3
   - Docker Compose 2.32.2

#### Developer Experience Enhancements (100% Complete)
5. ✅ **Setup Script**
   - Automated environment setup
   - Prerequisites validation
   - Health check verification
   - Service information display

6. ✅ **Makefile**
   - 30+ common development commands
   - Docker service management (up, down, restart, ps)
   - Database utilities (db-list, db-connect, etc.)
   - RabbitMQ utilities (queues, exchanges, bindings)
   - Health checks (health, health-summary)
   - Web UI shortcuts (rabbitmq-ui, mailhog-ui, pgadmin-ui)

7. ✅ **.env.local Template**
   - Environment variable template
   - Database, Redis, RabbitMQ configuration
   - Service URLs documentation
   - Added to .gitignore

### Validation Checkpoint ✅

**Acceptance Criteria**: ALL MET ✅

| Criterion | Status | Details |
|-----------|--------|---------|
| PHP 8.3+ installed | ✅ PASS | PHP 8.3.6 verified |
| Composer installed | ✅ PASS | Composer 2.8.8 verified |
| Symfony CLI installed | ✅ PASS | Symfony CLI 4.21.3 verified |
| Docker running | ✅ PASS | Docker 28.3.3 verified |
| Docker Compose running | ✅ PASS | Docker Compose 2.32.2 verified |
| PostgreSQL running | ✅ PASS | Container healthy, 7 databases created |
| Redis running | ✅ PASS | Container healthy, PONG response |
| RabbitMQ running | ✅ PASS | Container healthy, 3 queues + 1 exchange |
| kubectl installed | ⏳ DEFER | Not required for Phase 0, install in Phase 1 |
| Helm installed | ⏳ DEFER | Not required for Phase 0, install in Phase 1 |
| istioctl installed | ⏳ DEFER | Not required for Phase 0, install in Phase 1 |

**Quick Verification**:
```bash
# One-command verification
make health

# Or run setup script
bash scripts/setup-dev-env.sh

# Access web interfaces
make urls
```

**Result**: ✅ **PHASE 0 COMPLETE** - Ready for Phase 1

---

## Phase 1: Infrastructure Foundation (Weeks 1-2)

**Duration**: 10 working days
**Goal**: Deploy production-ready Kubernetes cluster with service mesh and observability
**Prerequisites**: Phase 0 complete ✅
**Status**: 📝 **READY TO START**

### Week 1: Kubernetes Cluster Setup

#### Days 1-3: Kubernetes Cluster Deployment

**Task 1.1: Choose Cluster Strategy**
- Local: minikube, kind, or k3d (for development)
- Cloud: EKS (AWS), GKE (Google Cloud), AKS (Azure)
- On-premise: kubeadm, kOps, Rancher

**Task 1.2: Deploy Cluster**

For **local development** (minikube):
```bash
minikube start --cpus=4 --memory=8192 --kubernetes-version=v1.28.0
kubectl cluster-info
```

For **cloud** (example: AWS EKS with Terraform):
```bash
cd infrastructure/terraform/eks
terraform init
terraform plan
terraform apply
aws eks update-kubeconfig --name ai-workflow-platform --region us-east-1
```

**Task 1.3: Create Namespaces**
```bash
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace production
kubectl create namespace observability
kubectl create namespace security
```

**Task 1.4: Configure RBAC**
```yaml
# infrastructure/kubernetes/rbac/developer-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: dev
rules:
  - apiGroups: ["", "apps", "batch"]
    resources: ["pods", "deployments", "jobs", "services"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

Apply RBAC:
```bash
kubectl apply -f infrastructure/kubernetes/rbac/
```

**Task 1.5: Configure Resource Quotas**
```yaml
# infrastructure/kubernetes/resource-quota/dev-quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi
```

Apply quotas:
```bash
kubectl apply -f infrastructure/kubernetes/resource-quota/
```

#### Days 4-6: Istio Service Mesh

**Task 1.6: Install Istio**
```bash
istioctl install --set profile=production -y
```

**Task 1.7: Enable Istio Injection**
```bash
kubectl label namespace dev istio-injection=enabled
kubectl label namespace staging istio-injection=enabled
kubectl label namespace production istio-injection=enabled
```

**Task 1.8: Configure mTLS**
```yaml
# infrastructure/istio/peer-authentication.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: dev
spec:
  mtls:
    mode: STRICT
```

Apply:
```bash
kubectl apply -f infrastructure/istio/peer-authentication.yaml
```

**Task 1.9: Configure Istio Gateway**
```yaml
# infrastructure/istio/gateway.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: api-gateway
  namespace: dev
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 443
        name: https
        protocol: HTTPS
      tls:
        mode: SIMPLE
        credentialName: api-gateway-tls
      hosts:
        - "api.dev.example.com"
```

Apply:
```bash
kubectl apply -f infrastructure/istio/gateway.yaml
```

#### Days 7-10: Observability Stack

**Task 1.10: Install Prometheus Operator**
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --create-namespace \
  --set prometheus.prometheusSpec.retention=30d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=100Gi
```

**Task 1.11: Install Grafana Dashboards**
```bash
# Import pre-configured dashboards
kubectl apply -f infrastructure/observability/grafana-dashboards/
```

**Task 1.12: Install Loki (Log Aggregation)**
```bash
helm install loki grafana/loki-stack \
  --namespace observability \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=50Gi \
  --set promtail.enabled=true
```

**Task 1.13: Install Tempo (Distributed Tracing)**
```bash
helm install tempo grafana/tempo \
  --namespace observability \
  --set persistence.enabled=true \
  --set persistence.size=50Gi
```

**Task 1.14: Configure Service Monitors**
```yaml
# infrastructure/observability/service-monitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: application-services
  namespace: observability
spec:
  selector:
    matchLabels:
      monitoring: "true"
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

Apply:
```bash
kubectl apply -f infrastructure/observability/service-monitor.yaml
```

### Documentation References
- [03-infrastructure/01-infrastructure-overview.md](03-infrastructure/01-infrastructure-overview.md) - Infrastructure strategy
- [03-infrastructure/02-kubernetes-architecture.md](03-infrastructure/02-kubernetes-architecture.md) - **PRIMARY REFERENCE**
- [03-infrastructure/03-service-mesh.md](03-infrastructure/03-service-mesh.md) - Istio configuration
- [03-infrastructure/04-observability-stack.md](03-infrastructure/04-observability-stack.md) - Monitoring setup

### 📋 Phase 1 Implementation Summary

**What to implement**:
1. **Tool Installation** - kubectl, helm, istioctl, minikube, k9s with version requirements
2. **Minikube Cluster Setup** - Configured for 8GB RAM, 4 CPUs, Kubernetes 1.28+
3. **Namespace Configuration** - All 6 namespaces matching documentation exactly:
   - `application` - Application microservices (pod security: restricted)
   - `data` - Data services (pod security: baseline)
   - `infrastructure` - Infrastructure components
   - `observability` - Monitoring stack (no Istio injection to avoid circular dependency)
   - `istio-system` - Service mesh
   - `argocd` - GitOps
4. **Resource Quotas & Limits** - Adapted for Minikube but matching documentation architecture
5. **Istio Installation** - Version 1.20+ with production profile and mTLS STRICT mode
6. **Observability Stack** - Prometheus, Grafana, Loki, Tempo with proper configuration
7. **Health Check Scripts** - Automated verification of all components
8. **Troubleshooting Guide** - Common issues and solutions

**Documentation Compliance**:
- ✅ Namespace strategy matches [02-kubernetes-architecture.md](03-infrastructure/02-kubernetes-architecture.md) lines 299-376
- ✅ Resource quotas reference [02-kubernetes-architecture.md](03-infrastructure/02-kubernetes-architecture.md) lines 378-398
- ✅ Pod security standards implemented as documented
- ✅ Istio configuration follows [03-service-mesh.md](03-infrastructure/03-service-mesh.md)
- ✅ Observability setup follows [04-observability-stack.md](03-infrastructure/04-observability-stack.md)
- ✅ All adaptations for local development clearly documented with references to production specs

**Local vs Production Adaptations**:
| Component | Production (Docs) | Local (Minikube) | Reason |
|-----------|------------------|------------------|--------|
| Cluster | Multi-node, multi-AZ | Single node | Laptop constraints |
| App namespace CPU | 50 CPU | 6 CPU | Minikube limits |
| App namespace RAM | 100Gi | 12Gi | Minikube limits |
| Storage | Cloud PVs | Local storage | Development only |
| High Availability | 3+ replicas | 1 replica | Resource constraints |

**Ready for execution**: All steps documented with command-line instructions, YAML manifests, and validation checkpoints.

### Validation Checkpoint (End of Week 2)

**Acceptance Criteria**:
- ✅ Kubernetes cluster running with 3+ worker nodes
- ✅ All namespaces created (dev, staging, production, observability, security)
- ✅ Istio installed and sidecar injection enabled
- ✅ mTLS enabled in STRICT mode
- ✅ Prometheus collecting metrics
- ✅ Grafana accessible with dashboards
- ✅ Loki collecting logs
- ✅ Tempo collecting traces

**Verification Commands**:
```bash
# Cluster health
kubectl get nodes
kubectl get namespaces

# Istio
kubectl get pods -n istio-system
istioctl verify-install

# mTLS
kubectl get peerauthentication -n dev

# Observability
kubectl get pods -n observability
kubectl port-forward -n observability svc/prometheus-kube-prometheus-prometheus 9090:9090
kubectl port-forward -n observability svc/prometheus-grafana 3000:80
```

**Expected Results**:
- All nodes: `Ready`
- All Istio pods: `Running`
- PeerAuthentication mode: `STRICT`
- Prometheus UI accessible: http://localhost:9090
- Grafana UI accessible: http://localhost:3000 (admin/prom-operator)

**If all pass**: ✅ Proceed to Phase 2
**If any fail**: ❌ Debug infrastructure before proceeding

---

## Phase 2: Security Infrastructure (Weeks 3-4)

**Duration**: 10 working days
**Goal**: Deploy security infrastructure (Vault, Keycloak, Kong API Gateway)
**Prerequisites**: Phase 1 complete
**Status**: 📝 **TODO**

### Week 3: Secrets Management

#### Days 1-3: HashiCorp Vault

**Task 2.1: Install Vault**
```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault \
  --namespace security \
  --set server.ha.enabled=true \
  --set server.ha.replicas=3 \
  --set ui.enabled=true
```

**Task 2.2: Initialize and Unseal Vault**
```bash
kubectl exec -n security vault-0 -- vault operator init -key-shares=5 -key-threshold=3
# Save unseal keys and root token securely!
kubectl exec -n security vault-0 -- vault operator unseal <unseal-key-1>
kubectl exec -n security vault-0 -- vault operator unseal <unseal-key-2>
kubectl exec -n security vault-0 -- vault operator unseal <unseal-key-3>
```

**Task 2.3: Enable Kubernetes Auth**
```bash
kubectl exec -n security vault-0 -- vault auth enable kubernetes
kubectl exec -n security vault-0 -- vault write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"
```

**Task 2.4: Create Secret Engines**
```bash
# KV secrets for static secrets
kubectl exec -n security vault-0 -- vault secrets enable -path=secret kv-v2

# Database secrets for dynamic secrets
kubectl exec -n security vault-0 -- vault secrets enable database
kubectl exec -n security vault-0 -- vault write database/config/postgresql \
  plugin_name=postgresql-database-plugin \
  allowed_roles="*" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/postgres" \
  username="vault" \
  password="vault-password"
```

**Task 2.5: Create Policies**
```bash
# Policy for authentication service
kubectl exec -n security vault-0 -- vault policy write authentication-service - <<EOF
path "secret/data/authentication/*" {
  capabilities = ["read"]
}
path "database/creds/authentication" {
  capabilities = ["read"]
}
EOF
```

**Task 2.6: Install Vault Agent Injector**
```bash
# Already installed with Vault Helm chart
kubectl get deployment -n security vault-agent-injector
```

#### Days 4-6: Keycloak (Identity Provider)

**Task 2.7: Install Keycloak**
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install keycloak bitnami/keycloak \
  --namespace security \
  --set auth.adminUser=admin \
  --set auth.adminPassword=admin \
  --set postgresql.enabled=true \
  --set replicaCount=3
```

**Task 2.8: Configure Realm**
```bash
# Access Keycloak admin console
kubectl port-forward -n security svc/keycloak 8080:80

# Create realm "ai-workflow-platform" via UI or CLI
# http://localhost:8080/admin
```

**Task 2.9: Create OAuth2 Clients**

Create clients for each service:
- `authentication-service` (confidential, service account enabled)
- `workflow-engine` (confidential, service account enabled)
- `api-gateway` (public, for user authentication)

**Task 2.10: Configure RBAC Roles**

Create roles:
- `admin` - Full access
- `developer` - Read/write workflows
- `viewer` - Read-only access

**Task 2.11: Create Test Users**
```bash
# Via Keycloak UI: Users → Add User
# Create users: admin@example.com, dev@example.com, viewer@example.com
```

#### Days 7-10: Kong API Gateway

**Task 2.12: Install Kong**
```bash
helm repo add kong https://charts.konghq.com
helm install kong kong/kong \
  --namespace security \
  --set ingressController.enabled=true \
  --set admin.enabled=true \
  --set proxy.type=LoadBalancer
```

**Task 2.13: Configure OAuth2 Plugin**
```yaml
# infrastructure/kong/oauth2-plugin.yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: oauth2
  namespace: dev
config:
  scopes:
    - read
    - write
  mandatory_scope: true
  enable_client_credentials: true
plugin: oauth2
```

Apply:
```bash
kubectl apply -f infrastructure/kong/oauth2-plugin.yaml
```

**Task 2.14: Configure Rate Limiting**
```yaml
# infrastructure/kong/rate-limiting.yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: rate-limiting
  namespace: dev
config:
  minute: 100
  hour: 10000
  policy: local
plugin: rate-limiting
```

Apply:
```bash
kubectl apply -f infrastructure/kong/rate-limiting.yaml
```

**Task 2.15: Configure Routes**
```yaml
# infrastructure/kong/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-gateway
  namespace: dev
  annotations:
    konghq.com/plugins: oauth2,rate-limiting
spec:
  ingressClassName: kong
  rules:
    - host: api.dev.example.com
      http:
        paths:
          - path: /auth
            pathType: Prefix
            backend:
              service:
                name: authentication-service
                port:
                  number: 8000
```

Apply:
```bash
kubectl apply -f infrastructure/kong/ingress.yaml
```

### Documentation References
- [02-security/01-security-principles.md](02-security/01-security-principles.md) - Security principles
- [02-security/02-zero-trust-architecture.md](02-security/02-zero-trust-architecture.md) - Zero trust implementation
- [02-security/03-authentication-authorization.md](02-security/03-authentication-authorization.md) - OAuth2/OIDC
- [02-security/04-secrets-management.md](02-security/04-secrets-management.md) - **PRIMARY REFERENCE** for Vault
- [02-security/05-network-security.md](02-security/05-network-security.md) - API Gateway configuration

### Validation Checkpoint (End of Week 4)

**Acceptance Criteria**:
- ✅ Vault running in HA mode (3 replicas)
- ✅ Vault initialized and unsealed
- ✅ Kubernetes auth enabled in Vault
- ✅ Secret engines configured (KV, Database)
- ✅ Keycloak running (3 replicas)
- ✅ Realm and OAuth2 clients configured
- ✅ Kong API Gateway running
- ✅ OAuth2 and rate limiting plugins configured

**Verification Commands**:
```bash
# Vault
kubectl get pods -n security -l app.kubernetes.io/name=vault
kubectl exec -n security vault-0 -- vault status

# Keycloak
kubectl get pods -n security -l app.kubernetes.io/name=keycloak
kubectl port-forward -n security svc/keycloak 8080:80
# Open http://localhost:8080 and login

# Kong
kubectl get pods -n security -l app.kubernetes.io/name=kong
kubectl get ingress -n dev
```

**Expected Results**:
- Vault pods: `Running`, status: `Sealed: false`
- Keycloak accessible, realm configured
- Kong ingress controller running
- Ingress routes configured

**If all pass**: ✅ Proceed to Phase 3
**If any fail**: ❌ Debug security infrastructure before proceeding

---

## Phase 3: Core Services Implementation (Weeks 5-10)

**Duration**: 6 weeks (30 working days)
**Goal**: Implement all 7 essential microservices
**Prerequisites**: Phase 2 complete ✅

### Service Implementation Order

**Dependencies**:
1. **Authentication Service** (Week 5) - Required by all other services
2. **Audit & Logging Service** (Week 6) - Used by all other services
3. **Agent Manager** + **Validation Service** (Weeks 7-8) - Parallel development
4. **Notification Service** (Week 9) - Independent
5. **Workflow Engine** (Week 10) - Depends on all above services

### Week 5: Authentication Service

**Priority**: CRITICAL (all other services depend on this)

#### Days 1-2: Domain Layer

**Task 3.1: Create Domain Entities**
```bash
mkdir -p services/authentication/src/Domain/{Entity,ValueObject,Event,Repository}
```

Implement:
- `User` entity (aggregate root)
- `Role` entity
- `Permission` entity
- `Email` value object
- `UserId` value object
- `UserCreated`, `UserLoggedIn` events
- `UserRepository` interface

**Task 3.2: Write Domain Tests**
```bash
mkdir -p services/authentication/tests/Unit/Domain/Entity
```

Write unit tests for:
- User creation
- Role assignment
- Permission checking
- Domain events

**Validation**: `vendor/bin/phpunit tests/Unit/Domain/` all passing

#### Days 3-4: Application Layer

**Task 3.3: Create Use Cases**
```bash
mkdir -p services/authentication/src/Application/UseCase
```

Implement:
- `RegisterUser` command
- `LoginUser` command
- `LogoutUser` command
- `RefreshToken` command
- `ValidateToken` query
- `GetUser` query

**Task 3.4: Write Application Tests**
```bash
mkdir -p services/authentication/tests/Integration/Application/UseCase
```

Write integration tests for all use cases.

**Validation**: `vendor/bin/phpunit tests/Integration/Application/` all passing

#### Day 5: Infrastructure Layer

**Task 3.5: Create Infrastructure Adapters**
```bash
mkdir -p services/authentication/src/Infrastructure/{Persistence,HTTP,Messaging}
```

Implement:
- Doctrine repository implementation
- REST API controllers
- JWT token manager
- Keycloak integration
- RabbitMQ event publisher

**Task 3.6: Database Migration**
```bash
bin/console make:migration
bin/console doctrine:migrations:migrate
```

#### Days 6-7: Testing & Quality

**Task 3.7: Write E2E Tests**
```bash
mkdir -p services/authentication/tests/E2E
```

Test complete authentication flows:
- User registration → login → access protected endpoint
- Token refresh flow
- Invalid credentials handling

**Task 3.8: Achieve Quality Gates**
- Run PHPStan Level 9: `vendor/bin/phpstan analyse --level=9 src/`
- Check coverage: `vendor/bin/phpunit --coverage-text` (target: ≥80%)
- Run Psalm: `vendor/bin/psalm`

**Validation**: All quality gates passing

#### Days 8-10: Deployment

**Task 3.9: Create Kubernetes Manifests**
```bash
mkdir -p infrastructure/kubernetes/services/authentication
```

Create:
- Deployment (3 replicas)
- Service (ClusterIP)
- VirtualService (Istio)
- DestinationRule (Istio)
- ServiceMonitor (Prometheus)

**Task 3.10: Configure Vault Integration**

Add Vault annotations to deployment:
```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "authentication-service"
  vault.hashicorp.com/agent-inject-secret-database: "database/creds/authentication"
  vault.hashicorp.com/agent-inject-secret-jwt: "secret/data/authentication/jwt"
```

**Task 3.11: Deploy to Dev Namespace**
```bash
kubectl apply -f infrastructure/kubernetes/services/authentication/ -n dev
```

**Task 3.12: Verify Deployment**
```bash
kubectl get pods -n dev -l app=authentication-service
kubectl logs -n dev -l app=authentication-service -c app
curl http://authentication-service.dev.svc.cluster.local:8000/health
```

### Documentation References
- [08-services/02-authentication-service.md](08-services/02-authentication-service.md) - **PRIMARY REFERENCE**
- [01-architecture/03-hexagonal-architecture.md](01-architecture/03-hexagonal-architecture.md)
- [01-architecture/04-domain-driven-design.md](01-architecture/04-domain-driven-design.md)
- [04-development/02-coding-guidelines-php.md](04-development/02-coding-guidelines-php.md)
- [04-development/04-testing-strategy.md](04-development/04-testing-strategy.md)

### Validation Checkpoint (Authentication Service)

**Acceptance Criteria**:
- ✅ All tests passing (unit + integration + E2E)
- ✅ PHPStan Level 9: 0 errors
- ✅ Code coverage ≥ 80%
- ✅ Service deployed to dev namespace
- ✅ Pods running (3 replicas)
- ✅ Health check responding
- ✅ mTLS enabled
- ✅ Metrics in Prometheus

**Verification Commands**:
```bash
cd services/authentication
vendor/bin/phpunit
vendor/bin/phpstan analyse --level=9 src/
vendor/bin/phpunit --coverage-text

kubectl get pods -n dev -l app=authentication-service
kubectl exec -n dev <pod-name> -c app -- curl http://localhost:8000/health
istioctl authn tls-check <pod-name>.dev authentication-service.dev.svc.cluster.local
```

**If all pass**: ✅ Proceed to Audit & Logging Service
**If any fail**: ❌ Fix authentication service before proceeding

---

### Week 6: Audit & Logging Service

**Priority**: HIGH (all services use for compliance logging)

**Implementation**: Follow same workflow as Authentication Service (Days 1-10)

**Domain Layer** (Days 1-2):
- `AuditEvent` entity
- `EventType` enum
- `AuditEventRepository` interface
- Unit tests

**Application Layer** (Days 3-4):
- `RecordAuditEvent` command
- `GetAuditEvents` query
- `GenerateComplianceReport` query
- Integration tests

**Infrastructure Layer** (Day 5):
- PostgreSQL with time-series partitioning
- REST API for querying
- RabbitMQ consumer for events
- Tamper detection (checksums)

**Testing & Quality** (Days 6-7):
- E2E tests for complete audit flows
- PHPStan Level 9
- 80%+ coverage

**Deployment** (Days 8-10):
- Kubernetes manifests
- Vault integration
- Deploy to dev namespace

### Documentation References
- [08-services/07-audit-logging-service.md](08-services/07-audit-logging-service.md) - **PRIMARY REFERENCE**
- [02-security/06-data-protection.md](02-security/06-data-protection.md) - Compliance requirements

### Validation Checkpoint (Audit & Logging Service)

Same criteria as Authentication Service (tests, coverage, deployment).

**If all pass**: ✅ Proceed to Week 7
**If any fail**: ❌ Fix audit service before proceeding

---

### Weeks 7-8: Agent Manager + Validation Service (Parallel)

**Note**: These services can be developed in parallel by different team members/agents.

#### Week 7: Agent Manager Service

**Priority**: HIGH (Workflow Engine depends on this)

**Implementation**: Follow same 10-day workflow

**Domain Layer** (Days 1-2):
- `Agent` entity (with prompt template)
- `Execution` entity (LLM interaction)
- `Provider` enum (OpenAI, Anthropic, Google AI, Azure)
- `TokenUsage` value object
- Unit tests

**Application Layer** (Days 3-4):
- `ExecuteAgent` command
- `GetExecution` query
- `CalculateCost` query
- Provider abstraction with fallback strategy
- Integration tests

**Infrastructure Layer** (Day 5):
- HTTP clients for LLM providers (Guzzle)
- PostgreSQL for execution history
- Redis for caching responses
- REST API

**Testing & Quality** (Days 6-7):
- E2E tests (mock LLM providers)
- PHPStan Level 9
- 80%+ coverage

**Deployment** (Days 8-10):
- Kubernetes manifests
- Vault for API keys
- Deploy to dev

**Documentation**: [08-services/04-agent-manager.md](08-services/04-agent-manager.md)

#### Week 7 (Parallel): Validation Service

**Priority**: MEDIUM (used by Workflow Engine)

**Implementation**: Follow same 10-day workflow

**Domain Layer** (Days 1-2):
- `ValidationRule` entity
- `ValidationResult` value object
- `ValidatorType` enum
- Unit tests

**Application Layer** (Days 3-4):
- `ValidateData` command
- `GetValidationRules` query
- Rule engine with 4 validator types
- Integration tests

**Infrastructure Layer** (Day 5):
- PostgreSQL with JSONB for flexible rules
- REST API
- RabbitMQ for async validation

**Testing & Quality** (Days 6-7):
- E2E tests
- PHPStan Level 9
- 80%+ coverage

**Deployment** (Days 8-10):
- Kubernetes manifests
- Deploy to dev

**Documentation**: [08-services/05-validation-service.md](08-services/05-validation-service.md)

### Validation Checkpoint (Week 8 End)

Same criteria for both services: tests, coverage, deployment.

**If all pass**: ✅ Proceed to Week 9
**If any fail**: ❌ Fix services before proceeding

---

### Week 9: Notification Service

**Priority**: MEDIUM (used by Workflow Engine for alerts)

**Implementation**: Follow same 10-day workflow

**Domain Layer** (Days 1-2):
- `Notification` entity
- `Channel` enum (email, SMS, webhook, in-app)
- `NotificationTemplate` entity
- Unit tests

**Application Layer** (Days 3-4):
- `SendNotification` command
- `GetNotificationStatus` query
- Multi-channel delivery with retry logic
- Integration tests

**Infrastructure Layer** (Day 5):
- Provider adapters (SendGrid, Twilio, etc.)
- Template engine (Twig)
- PostgreSQL for notification history
- RabbitMQ for async processing
- Dead letter queue for failures

**Testing & Quality** (Days 6-7):
- E2E tests (mock providers)
- PHPStan Level 9
- 80%+ coverage

**Deployment** (Days 8-10):
- Kubernetes manifests
- Vault for provider API keys
- Deploy to dev

**Documentation**: [08-services/06-notification-service.md](08-services/06-notification-service.md)

### Validation Checkpoint (Notification Service)

Same criteria: tests, coverage, deployment.

**If all pass**: ✅ Proceed to Week 10 (Workflow Engine)
**If any fail**: ❌ Fix notification service before proceeding

---

### Week 10: Workflow Engine (Most Complex)

**Priority**: CRITICAL (core orchestration service)
**Warning**: Most complex service, requires all previous services

**Implementation**: Follow same 10-day workflow (but more complex)

**Domain Layer** (Days 1-3 - LONGER):
- `Workflow` entity (aggregate root with complex state machine)
- `WorkflowDefinition` entity
- `WorkflowStep` entity
- `StepExecutor` interface (4 implementations: Agent, Transform, Conditional, Parallel)
- `WorkflowState` enum (10 states)
- Saga pattern for distributed transactions
- Domain events (10+ events)
- Unit tests (25+ tests)

**Application Layer** (Days 4-6 - LONGER):
- `StartWorkflow` command
- `ExecuteStep` command
- `CompleteWorkflow` command
- `CompensateWorkflow` command (for rollback)
- `GetWorkflow` query
- Saga orchestration logic
- Integration tests (15+ tests)

**Infrastructure Layer** (Days 7-8):
- PostgreSQL with complex schema (workflows, steps, executions, compensations)
- State machine implementation
- Step executor implementations (call Agent Manager, Validation, Notification services)
- REST API (10+ endpoints)
- RabbitMQ for async step execution
- Compensation logic (rollback on failures)

**Testing & Quality** (Day 9):
- E2E tests (complete workflow scenarios)
- PHPStan Level 9
- 80%+ coverage (may be challenging due to complexity)

**Deployment** (Day 10):
- Kubernetes manifests
- Deploy to dev
- Verify integration with all other services

**Documentation**: [08-services/03-workflow-engine.md](08-services/03-workflow-engine.md) - **MOST COMPREHENSIVE FILE** (2,267 lines)

### Validation Checkpoint (Workflow Engine)

**Acceptance Criteria** (stricter due to complexity):
- ✅ All tests passing (25+ unit, 15+ integration, 5+ E2E)
- ✅ PHPStan Level 9: 0 errors
- ✅ Code coverage ≥ 80%
- ✅ State machine working (all 10 states)
- ✅ Saga pattern working (compensations on failure)
- ✅ All 4 step executors working
- ✅ Integration with Agent Manager, Validation, Notification services working
- ✅ Service deployed to dev namespace
- ✅ Pods running (5 replicas for high availability)

**Verification Commands**:
```bash
cd services/workflow-engine
vendor/bin/phpunit
vendor/bin/phpstan analyse --level=9 src/
vendor/bin/phpunit --coverage-text

kubectl get pods -n dev -l app=workflow-engine
kubectl logs -n dev -l app=workflow-engine -c app

# Test complete workflow
curl -X POST http://workflow-engine.dev.svc.cluster.local:8000/workflows \
  -H "Content-Type: application/json" \
  -d '{"definition_id": "test-workflow"}'
```

**If all pass**: ✅ Proceed to Phase 4 (CI/CD)
**If any fail**: ❌ Fix workflow engine before proceeding (most critical service)

---

## Phase 4: CI/CD Pipeline (Week 11)

**Duration**: 1 week (5 working days)
**Goal**: Automate build, test, and deployment with GitHub Actions + ArgoCD
**Prerequisites**: Phase 3 complete (all services implemented) ✅

### Days 1-2: GitHub Actions CI Pipeline

**Task 4.1: Create Workflow File**
```yaml
# .github/workflows/ci.yml
name: CI Pipeline
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: [authentication, workflow-engine, agent-manager, validation, notification, audit-logging]
    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          extensions: opcache, pdo_pgsql, redis, amqp
      - name: Install dependencies
        run: |
          cd services/${{ matrix.service }}
          composer install --no-progress --no-interaction
      - name: PHPStan Level 9
        run: |
          cd services/${{ matrix.service }}
          vendor/bin/phpstan analyse --level=9 src/
      - name: Run tests
        run: |
          cd services/${{ matrix.service }}
          vendor/bin/phpunit --coverage-clover=coverage.xml
      - name: Check coverage
        run: |
          cd services/${{ matrix.service }}
          php vendor/bin/coverage-check coverage.xml 80

  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Trivy scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          severity: 'HIGH,CRITICAL'
          exit-code: '1'

  build:
    needs: [test, security-scan]
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: [authentication, workflow-engine, agent-manager, validation, notification, audit-logging]
    steps:
      - uses: actions/checkout@v4
      - name: Build Docker image
        run: |
          cd services/${{ matrix.service }}
          docker build -t ${{ secrets.REGISTRY }}/ai-workflow/${{ matrix.service }}:${{ github.sha }} .
      - name: Push to registry
        run: |
          echo ${{ secrets.REGISTRY_PASSWORD }} | docker login ${{ secrets.REGISTRY }} -u ${{ secrets.REGISTRY_USERNAME }} --password-stdin
          docker push ${{ secrets.REGISTRY }}/ai-workflow/${{ matrix.service }}:${{ github.sha }}
```

**Task 4.2: Configure Quality Gates**

Add quality gate checks:
- PHPStan Level 9 must pass
- Code coverage ≥ 80%
- No HIGH or CRITICAL vulnerabilities
- All tests must pass

**Task 4.3: Test CI Pipeline**

Push to branch and verify all jobs pass.

### Days 3-5: ArgoCD GitOps CD Pipeline

**Task 4.4: Install ArgoCD**
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**Task 4.5: Access ArgoCD UI**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

**Task 4.6: Create ArgoCD Application**
```yaml
# infrastructure/argocd/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ai-workflow-platform
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/ai-workflow-platform
    targetRevision: main
    path: infrastructure/kubernetes/services
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Apply:
```bash
kubectl apply -f infrastructure/argocd/application.yaml
```

**Task 4.7: Configure Image Updater**

Install ArgoCD Image Updater to automatically update image tags:
```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml
```

Configure image updater annotations:
```yaml
# infrastructure/kubernetes/services/authentication/deployment.yaml
metadata:
  annotations:
    argocd-image-updater.argoproj.io/image-list: authentication=registry.example.com/ai-workflow/authentication
    argocd-image-updater.argoproj.io/authentication.update-strategy: digest
```

**Task 4.8: Test Deployment Flow**

1. Make code change
2. Push to GitHub
3. CI pipeline builds and pushes new image
4. ArgoCD detects new image
5. ArgoCD syncs and deploys to dev namespace

Verify:
```bash
argocd app get ai-workflow-platform
argocd app sync ai-workflow-platform
```

### Documentation References
- [06-cicd/01-cicd-overview.md](06-cicd/01-cicd-overview.md) - CI/CD philosophy
- [06-cicd/02-pipeline-stages.md](06-cicd/02-pipeline-stages.md) - **PRIMARY REFERENCE**
- [06-cicd/03-gitops-workflow.md](06-cicd/03-gitops-workflow.md) - ArgoCD configuration
- [06-cicd/04-quality-gates.md](06-cicd/04-quality-gates.md) - Quality enforcement
- [06-cicd/05-deployment-strategies.md](06-cicd/05-deployment-strategies.md) - Canary/blue-green

### Validation Checkpoint (CI/CD)

**Acceptance Criteria**:
- ✅ GitHub Actions CI pipeline running
- ✅ All quality gates enforced (PHPStan Level 9, 80% coverage, security scans)
- ✅ Docker images built and pushed to registry
- ✅ ArgoCD installed and configured
- ✅ Applications syncing automatically
- ✅ Complete deployment flow working (code push → build → deploy)

**Verification Commands**:
```bash
# Check GitHub Actions
# Go to https://github.com/your-org/ai-workflow-platform/actions

# Check ArgoCD
kubectl get applications -n argocd
argocd app get ai-workflow-platform
argocd app sync ai-workflow-platform

# Verify deployment
kubectl get pods -n dev
```

**If all pass**: ✅ Proceed to Phase 5 (Integration Testing)
**If any fail**: ❌ Fix CI/CD pipeline before proceeding

---

## Phase 5: Integration Testing (Week 12)

**Duration**: 1 week (5 working days)
**Goal**: Validate complete platform with integration, performance, and security testing
**Prerequisites**: Phase 4 complete (CI/CD working) ✅

### Days 1-2: End-to-End Integration Tests

**Task 5.1: Create E2E Test Scenarios**
```bash
mkdir -p tests/E2E/Scenarios
```

Scenarios to test:
1. **Complete Workflow Execution**:
   - User registers → logs in → creates workflow → workflow executes → validates → sends notification → completes
2. **Authentication Flow**:
   - User registers → logs in → refreshes token → accesses protected resource → logs out
3. **Agent Execution**:
   - Create agent → execute with OpenAI → fallback to Anthropic on failure → track tokens
4. **Validation Pipeline**:
   - Submit data → validate with multiple rules → get scored result → feedback generated
5. **Notification Delivery**:
   - Trigger notification → deliver via email → retry on failure → track status

**Task 5.2: Implement Behat Tests**
```gherkin
# tests/E2E/Features/workflow.feature
Feature: Complete Workflow Execution
  As a user
  I want to execute a complete workflow
  So that I can process data with AI agents

  Scenario: Execute simple workflow
    Given I am authenticated as "user@example.com"
    When I create a workflow with definition "simple-agent-workflow"
    And I start the workflow
    Then the workflow should transition to "running" state
    And step "agent-execution" should complete successfully
    And step "validation" should complete successfully
    And the workflow should transition to "completed" state
    And I should receive a notification
```

**Task 5.3: Run E2E Tests**
```bash
vendor/bin/behat
```

**Task 5.4: Fix Integration Issues**

Debug and fix any integration issues found during E2E testing.

### Days 3-4: Performance Testing

**Task 5.5: Install K6 (Load Testing Tool)**
```bash
brew install k6  # macOS
# or download from https://k6.io/
```

**Task 5.6: Create Load Test Scripts**
```javascript
// tests/Performance/load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '1m', target: 50 },   // Ramp up to 50 users
    { duration: '3m', target: 50 },   // Stay at 50 users
    { duration: '1m', target: 100 },  // Ramp up to 100 users
    { duration: '3m', target: 100 },  // Stay at 100 users
    { duration: '1m', target: 0 },    // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<200'],  // 95% of requests < 200ms
    http_req_failed: ['rate<0.01'],    // Error rate < 1%
  },
};

export default function () {
  // Login
  let loginRes = http.post('https://api.dev.example.com/auth/login', JSON.stringify({
    email: 'load-test@example.com',
    password: 'test-password',
  }), { headers: { 'Content-Type': 'application/json' } });

  check(loginRes, {
    'login successful': (r) => r.status === 200,
  });

  let token = loginRes.json('access_token');

  // Create workflow
  let workflowRes = http.post('https://api.dev.example.com/workflows', JSON.stringify({
    definition_id: 'load-test-workflow',
  }), { headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`,
  }});

  check(workflowRes, {
    'workflow created': (r) => r.status === 201,
    'response time < 200ms': (r) => r.timings.duration < 200,
  });

  sleep(1);
}
```

**Task 5.7: Run Load Tests**
```bash
k6 run tests/Performance/load-test.js
```

**Task 5.8: Analyze Results**

Check:
- P95 latency < 200ms ✅
- P99 latency < 500ms ✅
- Error rate < 1% ✅
- Throughput: > 1000 requests/sec ✅

**Task 5.9: Optimize Performance**

If targets not met:
- Add indexes to database queries
- Enable Redis caching
- Increase pod replicas
- Optimize OPcache configuration

Rerun load tests until targets met.

### Day 5: Security Testing

**Task 5.10: Run Security Scans**

**Container Scanning**:
```bash
# Trivy scan all Docker images
for service in authentication workflow-engine agent-manager validation notification audit-logging; do
  trivy image registry.example.com/ai-workflow/$service:latest --severity HIGH,CRITICAL
done
```

**Task 5.11: OWASP ZAP Scan**
```bash
docker run -t owasp/zap2docker-stable zap-baseline.py -t https://api.dev.example.com
```

**Task 5.12: Penetration Testing**

Test for:
- SQL injection
- XSS attacks
- CSRF attacks
- Authentication bypass
- Authorization flaws
- Insecure direct object references

**Task 5.13: Fix Security Issues**

Address all HIGH and CRITICAL findings before proceeding.

### Documentation References
- [04-development/04-testing-strategy.md](04-development/04-testing-strategy.md) - Testing strategy
- [07-operations/05-performance-tuning.md](07-operations/05-performance-tuning.md) - Performance optimization
- [02-security/01-security-principles.md](02-security/01-security-principles.md) - Security principles
- [05-code-review/02-security-review-checklist.md](05-code-review/02-security-review-checklist.md) - Security checklist

### Validation Checkpoint (Integration Testing)

**Acceptance Criteria**:
- ✅ All E2E tests passing (5+ scenarios)
- ✅ Load test targets met (P95 < 200ms, error rate < 1%)
- ✅ Security scans show no HIGH or CRITICAL vulnerabilities
- ✅ Penetration test passes
- ✅ All integration issues resolved

**Verification Commands**:
```bash
# E2E tests
vendor/bin/behat

# Load test
k6 run tests/Performance/load-test.js

# Security scans
trivy image registry.example.com/ai-workflow/authentication:latest
docker run -t owasp/zap2docker-stable zap-baseline.py -t https://api.dev.example.com
```

**Expected Results**:
- E2E: All scenarios passing
- Load test: P95 < 200ms, error rate < 1%
- Security: No HIGH/CRITICAL vulnerabilities

**If all pass**: ✅ Proceed to Phase 6 (Production Deployment)
**If any fail**: ❌ Fix issues before production deployment

---

## Phase 6: Production Deployment (Week 13)

**Duration**: 1 week (5 working days)
**Goal**: Deploy to production with canary rollout strategy
**Prerequisites**: Phase 5 complete (all tests passing) ✅

### Day 1: Production Environment Preparation

**Task 6.1: Create Production Namespace**
```bash
kubectl create namespace production
kubectl label namespace production istio-injection=enabled
```

**Task 6.2: Configure Production Resource Quotas**
```yaml
# infrastructure/kubernetes/resource-quota/production-quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    requests.cpu: "100"
    requests.memory: 200Gi
    limits.cpu: "200"
    limits.memory: 400Gi
    persistentvolumeclaims: "50"
```

Apply:
```bash
kubectl apply -f infrastructure/kubernetes/resource-quota/production-quota.yaml
```

**Task 6.3: Configure Production Secrets**

Store production secrets in Vault:
```bash
# Database credentials
vault kv put secret/production/database/postgresql \
  username=prod_user \
  password=<strong-password>

# JWT keys
vault kv put secret/production/authentication/jwt \
  private_key=@prod_jwt_private_key.pem \
  public_key=@prod_jwt_public_key.pem

# LLM API keys
vault kv put secret/production/agent-manager/openai \
  api_key=<openai-production-key>

vault kv put secret/production/agent-manager/anthropic \
  api_key=<anthropic-production-key>
```

**Task 6.4: Configure Production Network Policies**
```yaml
# infrastructure/kubernetes/network-policies/production-isolation.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: production-isolation
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: production
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: production
    - to:  # Allow external traffic
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 443
```

Apply:
```bash
kubectl apply -f infrastructure/kubernetes/network-policies/production-isolation.yaml
```

### Days 2-3: Database Migration and Backup

**Task 6.5: Create Production Databases**
```sql
-- For each service
CREATE DATABASE authentication_production;
CREATE DATABASE workflow_engine_production;
CREATE DATABASE agent_manager_production;
CREATE DATABASE validation_production;
CREATE DATABASE notification_production;
CREATE DATABASE audit_logging_production;

-- Create service users with limited permissions
CREATE USER authentication_service WITH PASSWORD '<strong-password>';
GRANT ALL PRIVILEGES ON DATABASE authentication_production TO authentication_service;
-- Repeat for each service
```

**Task 6.6: Run Database Migrations**
```bash
# For each service
cd services/authentication
DATABASE_URL=postgresql://authentication_service:<password>@postgres:5432/authentication_production \
  bin/console doctrine:migrations:migrate --no-interaction
```

**Task 6.7: Configure Automated Backups**
```yaml
# infrastructure/kubernetes/cronjobs/postgres-backup.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: production
spec:
  schedule: "0 2 * * *"  # Every day at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: backup
              image: postgres:15
              command:
                - /bin/sh
                - -c
                - |
                  pg_dump -h postgres -U postgres -d authentication_production | gzip > /backup/authentication_$(date +%Y%m%d).sql.gz
              volumeMounts:
                - name: backup-volume
                  mountPath: /backup
          restartPolicy: OnFailure
          volumes:
            - name: backup-volume
              persistentVolumeClaim:
                claimName: postgres-backup-pvc
```

Apply:
```bash
kubectl apply -f infrastructure/kubernetes/cronjobs/postgres-backup.yaml
```

**Task 6.8: Test Backup Restore**
```bash
# Restore from backup to verify backup integrity
gunzip -c /backup/authentication_20250107.sql.gz | psql -h postgres -U postgres -d authentication_test
```

### Days 4-5: Canary Deployment

**Task 6.9: Deploy Canary Version (10%)**

**Step 1**: Deploy canary deployments (10% traffic):
```yaml
# infrastructure/kubernetes/services/authentication/deployment-canary.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: authentication-service-canary
  namespace: production
  labels:
    app: authentication-service
    version: canary
spec:
  replicas: 1  # 10% of traffic (9 stable + 1 canary = 10 total)
  selector:
    matchLabels:
      app: authentication-service
      version: canary
  template:
    metadata:
      labels:
        app: authentication-service
        version: canary
    spec:
      containers:
        - name: app
          image: registry.example.com/ai-workflow/authentication:v1.0.0
          # ... rest of spec
```

Deploy:
```bash
kubectl apply -f infrastructure/kubernetes/services/authentication/deployment-canary.yaml
```

**Step 2**: Configure Istio traffic split:
```yaml
# infrastructure/istio/virtual-service-canary.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: authentication-service
  namespace: production
spec:
  hosts:
    - authentication-service
  http:
    - match:
        - headers:
            x-canary:
              exact: "true"
      route:
        - destination:
            host: authentication-service
            subset: canary
    - route:
        - destination:
            host: authentication-service
            subset: stable
          weight: 90
        - destination:
            host: authentication-service
            subset: canary
          weight: 10
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: authentication-service
  namespace: production
spec:
  host: authentication-service
  subsets:
    - name: stable
      labels:
        version: stable
    - name: canary
      labels:
        version: canary
```

Apply:
```bash
kubectl apply -f infrastructure/istio/virtual-service-canary.yaml
```

**Task 6.10: Monitor Canary (30 minutes)**

Watch metrics in Grafana:
- Error rate: should be < 1%
- Latency P95: should be < 200ms
- Request rate: should match expected traffic

```bash
# Watch canary pods
kubectl get pods -n production -l version=canary -w

# Check logs
kubectl logs -n production -l version=canary -c app -f

# Check error rate in Prometheus
# Query: rate(http_requests_total{namespace="production",version="canary",status=~"5.."}[5m])
```

**Task 6.11: Increase to 50% Traffic**

If canary is healthy after 30 minutes, increase to 50%:
```yaml
# Update VirtualService weights
- route:
    - destination:
        host: authentication-service
        subset: stable
      weight: 50
    - destination:
        host: authentication-service
        subset: canary
      weight: 50
```

Apply:
```bash
kubectl apply -f infrastructure/istio/virtual-service-canary.yaml
```

Monitor for 30 minutes.

**Task 6.12: Increase to 100% Traffic**

If canary is still healthy, increase to 100%:
```yaml
- route:
    - destination:
        host: authentication-service
        subset: canary
      weight: 100
```

Apply:
```bash
kubectl apply -f infrastructure/istio/virtual-service-canary.yaml
```

**Task 6.13: Promote Canary to Stable**

Once canary is proven stable:
```bash
# Update stable deployment to canary version
kubectl set image deployment/authentication-service-stable \
  app=registry.example.com/ai-workflow/authentication:v1.0.0 \
  -n production

# Remove canary deployment
kubectl delete deployment authentication-service-canary -n production

# Reset traffic to 100% stable
kubectl apply -f infrastructure/istio/virtual-service-stable.yaml
```

**Task 6.14: Repeat for All Services**

Repeat Tasks 6.9-6.13 for each service:
- Authentication Service ✅
- Audit & Logging Service
- Agent Manager Service
- Validation Service
- Notification Service
- Workflow Engine Service

### Documentation References
- [06-cicd/05-deployment-strategies.md](06-cicd/05-deployment-strategies.md) - **PRIMARY REFERENCE** for canary
- [07-operations/01-operations-overview.md](07-operations/01-operations-overview.md) - SRE principles
- [07-operations/02-monitoring-alerting.md](07-operations/02-monitoring-alerting.md) - Monitoring during deployment
- [03-infrastructure/05-disaster-recovery.md](03-infrastructure/05-disaster-recovery.md) - Backup procedures

### Validation Checkpoint (Production Deployment)

**Acceptance Criteria**:
- ✅ Production namespace configured with quotas and network policies
- ✅ Production databases created and migrated
- ✅ Automated backups running and tested
- ✅ All 6 services deployed via canary strategy
- ✅ All canary deployments promoted to stable (100% traffic)
- ✅ No errors during canary rollout
- ✅ All SLOs met (P95 < 200ms, error rate < 1%)
- ✅ Monitoring and alerting active

**Verification Commands**:
```bash
# Check all production pods
kubectl get pods -n production

# Check all services healthy
kubectl get deployments -n production
kubectl get services -n production

# Check traffic distribution (should be 100% stable after promotion)
kubectl get virtualservices -n production -o yaml

# Check metrics in Grafana
# Open production dashboard, verify all services green

# Check logs in Loki
# Open Loki, query: {namespace="production"}

# Test API endpoints
curl https://api.example.com/health
curl https://api.example.com/auth/health
curl https://api.example.com/workflows/health
```

**Expected Results**:
- All pods: `Running`
- All deployments: Available replicas = desired replicas
- All health checks: `{"status":"ok"}`
- Grafana: All metrics green, SLOs met
- Loki: No errors in logs

**If all pass**: ✅ **PRODUCTION DEPLOYMENT COMPLETE** 🎉
**If any fail**: ❌ Rollback and debug before retrying

---

## Post-Deployment: Operations Handoff

### Week 13+: Ongoing Operations

**Operations Team Responsibilities**:

1. **Daily Monitoring** ([07-operations/02-monitoring-alerting.md](07-operations/02-monitoring-alerting.md))
   - Check Grafana dashboards daily
   - Review error rates and latency
   - Monitor resource utilization

2. **Incident Response** ([07-operations/03-incident-response.md](07-operations/03-incident-response.md))
   - On-call rotation configured
   - Escalation procedures documented
   - Postmortem process after incidents

3. **Backup Verification** ([07-operations/04-backup-recovery.md](07-operations/04-backup-recovery.md))
   - Weekly backup restore tests
   - Verify backup integrity
   - Test disaster recovery procedures

4. **Performance Tuning** ([07-operations/05-performance-tuning.md](07-operations/05-performance-tuning.md))
   - Monthly load testing
   - Optimize slow queries
   - Scale resources as needed

5. **Security Updates**
   - Weekly security scans
   - Monthly dependency updates
   - Quarterly penetration testing

---

## Summary: Implementation Checklist

### Phase 0: Environment Setup ✅
- [ ] PHP 8.3, Composer, Symfony CLI installed
- [ ] Docker Desktop running
- [ ] kubectl, helm, istioctl installed
- [ ] IDE configured
- [ ] Local PostgreSQL, Redis, RabbitMQ running

### Phase 1: Infrastructure Foundation ✅
- [ ] Kubernetes cluster deployed
- [ ] Namespaces created (dev, staging, production, observability, security)
- [ ] RBAC configured
- [ ] Istio service mesh deployed
- [ ] mTLS enabled (STRICT mode)
- [ ] Observability stack deployed (Prometheus, Grafana, Loki, Tempo)
- [ ] Dashboards configured

### Phase 2: Security Infrastructure ✅
- [ ] HashiCorp Vault deployed and initialized
- [ ] Vault secret engines configured (KV, Database)
- [ ] Vault policies created for each service
- [ ] Keycloak deployed
- [ ] OAuth2 realm and clients configured
- [ ] Kong API Gateway deployed
- [ ] OAuth2 and rate limiting plugins configured

### Phase 3: Core Services Implementation ✅
- [ ] Authentication Service (Week 5)
  - [ ] Domain, Application, Infrastructure layers
  - [ ] Tests passing (PHPStan Level 9, 80% coverage)
  - [ ] Deployed to dev namespace
- [ ] Audit & Logging Service (Week 6)
  - [ ] Domain, Application, Infrastructure layers
  - [ ] Tests passing
  - [ ] Deployed to dev namespace
- [ ] Agent Manager Service (Week 7)
  - [ ] Domain, Application, Infrastructure layers
  - [ ] Multi-provider support (OpenAI, Anthropic, Google AI)
  - [ ] Tests passing
  - [ ] Deployed to dev namespace
- [ ] Validation Service (Week 7, parallel)
  - [ ] Domain, Application, Infrastructure layers
  - [ ] Rule engine with 4 validator types
  - [ ] Tests passing
  - [ ] Deployed to dev namespace
- [ ] Notification Service (Week 9)
  - [ ] Domain, Application, Infrastructure layers
  - [ ] Multi-channel support (email, SMS, webhook, in-app)
  - [ ] Tests passing
  - [ ] Deployed to dev namespace
- [ ] Workflow Engine (Week 10)
  - [ ] Domain, Application, Infrastructure layers
  - [ ] State machine with 10 states
  - [ ] Saga pattern implementation
  - [ ] 4 step executor types
  - [ ] Tests passing
  - [ ] Deployed to dev namespace

### Phase 4: CI/CD Pipeline ✅
- [ ] GitHub Actions CI pipeline configured
- [ ] Quality gates enforced (PHPStan Level 9, 80% coverage, security scans)
- [ ] Docker images built and pushed
- [ ] ArgoCD installed and configured
- [ ] Applications syncing automatically

### Phase 5: Integration Testing ✅
- [ ] E2E tests created and passing (5+ scenarios)
- [ ] Load testing performed (P95 < 200ms, error rate < 1%)
- [ ] Security scans passed (no HIGH/CRITICAL vulnerabilities)
- [ ] Penetration testing completed

### Phase 6: Production Deployment ✅
- [ ] Production namespace configured
- [ ] Production databases created and migrated
- [ ] Automated backups configured and tested
- [ ] All services deployed via canary strategy
- [ ] Canary deployments promoted to stable (100% traffic)
- [ ] Monitoring and alerting active
- [ ] Operations team trained and on-call rotation configured

---

## Rollback Procedures

### Immediate Rollback (During Canary Deployment)

If canary shows errors or high latency:

```bash
# 1. Set traffic to 0% canary, 100% stable
kubectl apply -f infrastructure/istio/virtual-service-stable.yaml

# 2. Delete canary deployment
kubectl delete deployment <service-name>-canary -n production

# 3. Investigate issue
kubectl logs -n production -l version=canary -c app --tail=100

# 4. Fix issue and retry canary deployment
```

### Rollback After Full Deployment

If production shows errors after full deployment:

```bash
# 1. Identify previous stable version
kubectl rollout history deployment/<service-name> -n production

# 2. Rollback to previous version
kubectl rollout undo deployment/<service-name> -n production

# 3. Verify rollback
kubectl rollout status deployment/<service-name> -n production

# 4. Check metrics
# Open Grafana, verify error rate and latency return to normal
```

---

## Troubleshooting Common Issues

### Issue: CI Pipeline Failing

**Symptoms**: GitHub Actions jobs failing

**Debug Steps**:
1. Check logs in GitHub Actions UI
2. Run tests locally: `vendor/bin/phpunit`
3. Run PHPStan locally: `vendor/bin/phpstan analyse --level=9 src/`
4. Check security scans locally: `trivy fs .`

**Common Causes**:
- PHPStan errors → Fix type declarations
- Test failures → Fix broken tests
- Security vulnerabilities → Update dependencies

---

### Issue: ArgoCD Not Syncing

**Symptoms**: Applications stuck in "OutOfSync" state

**Debug Steps**:
```bash
# Check ArgoCD application status
argocd app get <app-name>

# Check sync errors
kubectl get application <app-name> -n argocd -o yaml | grep -A 10 "conditions:"

# Manual sync
argocd app sync <app-name>
```

**Common Causes**:
- Invalid Kubernetes manifests → Validate with `kubectl apply --dry-run`
- Image pull errors → Check registry credentials
- Resource conflicts → Check for duplicate resources

---

### Issue: Canary Deployment Showing High Error Rate

**Symptoms**: Canary version has > 1% error rate

**Debug Steps**:
```bash
# Check canary logs
kubectl logs -n production -l version=canary -c app --tail=100

# Check canary metrics
# Query in Prometheus: rate(http_requests_total{namespace="production",version="canary",status=~"5.."}[5m])

# Check database connectivity
kubectl exec -n production <canary-pod> -c app -- curl http://postgres:5432

# Check Vault secrets
kubectl exec -n production <canary-pod> -c app -- ls -la /vault/secrets/
```

**Common Causes**:
- Database connection errors → Check Vault database credentials
- Missing secrets → Check Vault policies
- Integration errors → Check service-to-service communication

**Solution**: Rollback canary (set traffic to 0%), fix issue, retry deployment

---

## Final Notes

**Total Implementation Time**: 13 weeks (3 months)
**Team Size Recommendation**: 3-5 developers for optimal parallelization
**Cost Estimate**: Varies by cloud provider and resource usage

**Success Criteria**:
- ✅ All 7 services deployed and running
- ✅ All infrastructure components operational
- ✅ CI/CD pipeline automating deployments
- ✅ All SLOs met (P95 < 200ms, error rate < 1%, uptime > 99.9%)
- ✅ Security compliance achieved (GDPR, SOC2, ISO27001, NIS2)
- ✅ Operations team trained and on-call

**Next Steps After Production**:
1. Monitor platform performance and user feedback
2. Iterate on features based on real-world usage
3. Add optional services (File Storage, BFF) as needed
4. Scale infrastructure based on load
5. Continuous improvement (performance, security, features)

---

**Last Updated**: 2025-01-07
**Roadmap Version**: 1.0.0
**Status**: Ready for Implementation

**For Questions**: Refer to [LLM_USAGE_GUIDE.md](LLM_USAGE_GUIDE.md) for task-based navigation and [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md) for complete documentation index.
