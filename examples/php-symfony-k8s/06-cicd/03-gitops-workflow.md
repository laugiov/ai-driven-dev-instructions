# GitOps Workflow

## Table of Contents

1. [Introduction](#introduction)
2. [GitOps Principles](#gitops-principles)
3. [Repository Structure](#repository-structure)
4. [ArgoCD Configuration](#argocd-configuration)
5. [Application Management](#application-management)
6. [Environment Promotion](#environment-promotion)
7. [Rollback Procedures](#rollback-procedures)
8. [Secret Management](#secret-management)
9. [Multi-Cluster Setup](#multi-cluster-setup)
10. [Best Practices](#best-practices)

## Introduction

GitOps is a declarative approach to continuous delivery where the desired state of infrastructure and applications is stored in Git. Changes are made through pull requests, and automated systems ensure the actual state matches the desired state defined in Git.

### Why GitOps?

**Single Source of Truth**: Git is the source of truth for infrastructure and applications.

**Version Control**: All changes tracked with full audit trail.

**Automated Sync**: Continuous reconciliation ensures actual state matches desired state.

**Easy Rollback**: Revert to any previous state by reverting Git commits.

**Security**: Git provides authentication, authorization, and encryption.

**Collaboration**: Pull request workflow enables peer review and approval.

### GitOps vs Traditional CD

```
Traditional CD:
Developer → CI/CD Pipeline → kubectl apply → Cluster
          (push-based, no audit trail)

GitOps:
Developer → Git Repository → ArgoCD → Cluster
          (pull-based, full audit trail)
```

## GitOps Principles

### 1. Declarative

The entire system is described declaratively using Kubernetes manifests, Kustomize, or Helm charts.

```yaml
# Declarative: Describes desired state
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bff
spec:
  replicas: 3
  template:
    spec:
      containers:
        - name: bff
          image: ghcr.io/platform/bff:v1.2.3
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"
```

### 2. Versioned and Immutable

All desired state is stored in Git, providing version control and immutability.

```bash
# Every change is a commit with full history
git log --oneline

a1b2c3d deploy: update bff to v1.2.3
d4e5f6g feat: add new workflow service
g7h8i9j fix: correct resource limits
```

### 3. Pulled Automatically

ArgoCD continuously monitors Git and pulls changes to the cluster.

```
┌──────────────┐
│     Git      │
│  Repository  │
└──────┬───────┘
       │
       │ ArgoCD polls every 3 minutes
       │ or webhook triggers immediately
       ▼
┌──────────────┐
│   ArgoCD     │
│   Server     │
└──────┬───────┘
       │
       │ Apply changes
       │
       ▼
┌──────────────┐
│  Kubernetes  │
│   Cluster    │
└──────────────┘
```

### 4. Continuously Reconciled

ArgoCD ensures the actual state matches the desired state defined in Git.

```yaml
# If someone manually changes replicas to 5...
kubectl scale deployment bff --replicas=5

# ArgoCD detects drift and reconciles back to desired state (3)
# This can be automatic (self-heal) or manual
```

## Repository Structure

### Monorepo Layout

```
platform/
├── infrastructure/
│   ├── argocd/
│   │   ├── applications/          # ArgoCD Application definitions
│   │   │   ├── platform-dev.yaml
│   │   │   ├── platform-staging.yaml
│   │   │   └── platform-production.yaml
│   │   ├── projects/              # ArgoCD Projects
│   │   │   └── platform.yaml
│   │   └── app-of-apps.yaml       # App of Apps pattern
│   │
│   └── k8s/
│       ├── base/                  # Base Kubernetes manifests
│       │   ├── bff/
│       │   │   ├── deployment.yaml
│       │   │   ├── service.yaml
│       │   │   ├── hpa.yaml
│       │   │   └── kustomization.yaml
│       │   ├── llm-agent/
│       │   ├── workflow-orchestrator/
│       │   └── common/
│       │       ├── namespace.yaml
│       │       ├── serviceaccount.yaml
│       │       └── rbac.yaml
│       │
│       └── overlays/              # Environment-specific configs
│           ├── development/
│           │   ├── kustomization.yaml
│           │   ├── configmap.yaml
│           │   └── patches/
│           │       └── replicas.yaml
│           ├── staging/
│           │   ├── kustomization.yaml
│           │   ├── configmap.yaml
│           │   └── patches/
│           │       └── replicas.yaml
│           └── production/
│               ├── kustomization.yaml
│               ├── configmap.yaml
│               ├── sealed-secrets.yaml
│               └── patches/
│                   ├── replicas.yaml
│                   └── resources.yaml
│
├── services/                      # Application source code
│   ├── bff/
│   ├── llm-agent/
│   └── workflow-orchestrator/
│
└── docs/                          # Documentation
```

### Base Manifests

```yaml
# infrastructure/k8s/base/bff/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bff
  labels:
    app: bff
    component: api
spec:
  replicas: 1  # Overridden by overlays
  selector:
    matchLabels:
      app: bff
  template:
    metadata:
      labels:
        app: bff
        version: stable
    spec:
      serviceAccountName: bff
      containers:
        - name: bff
          image: ghcr.io/platform/bff:latest  # Overridden by overlays
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
          env:
            - name: APP_ENV
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: APP_ENV
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: DATABASE_URL
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /health/live
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health/ready
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
```

```yaml
# infrastructure/k8s/base/bff/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - hpa.yaml
  - servicemonitor.yaml

commonLabels:
  app.kubernetes.io/name: bff
  app.kubernetes.io/part-of: platform
  app.kubernetes.io/managed-by: kustomize

configMapGenerator:
  - name: app-config
    literals:
      - APP_NAME=bff
      - LOG_LEVEL=info
```

### Environment Overlays

```yaml
# infrastructure/k8s/overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: platform-production

bases:
  - ../../base/bff
  - ../../base/llm-agent
  - ../../base/workflow-orchestrator
  - ../../base/validation
  - ../../base/notification
  - ../../base/audit
  - ../../base/file-storage

resources:
  - namespace.yaml
  - networkpolicies.yaml
  - sealed-secrets.yaml

replicas:
  - name: bff
    count: 5
  - name: llm-agent
    count: 10
  - name: workflow-orchestrator
    count: 5

images:
  - name: ghcr.io/platform/bff
    newTag: v1.2.3
  - name: ghcr.io/platform/llm-agent
    newTag: v1.2.3

configMapGenerator:
  - name: app-config
    behavior: merge
    literals:
      - APP_ENV=production
      - LOG_LEVEL=warning
      - CACHE_TTL=3600
      - RATE_LIMIT_ENABLED=true

patches:
  - path: patches/replicas.yaml
  - path: patches/resources-production.yaml
  - path: patches/hpa-production.yaml
```

```yaml
# infrastructure/k8s/overlays/production/patches/resources-production.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bff
spec:
  template:
    spec:
      containers:
        - name: bff
          resources:
            requests:
              memory: "512Mi"
              cpu: "500m"
            limits:
              memory: "1Gi"
              cpu: "1000m"
```

## ArgoCD Configuration

### ArgoCD Installation

```yaml
# infrastructure/argocd/install.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: argocd

---
# Install ArgoCD using Helm
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argo-cd
    targetRevision: 5.51.0
    helm:
      values: |
        global:
          image:
            tag: v2.9.3

        server:
          ingress:
            enabled: true
            hosts:
              - argocd.example.com
            tls:
              - secretName: argocd-tls
                hosts:
                  - argocd.example.com

          config:
            url: https://argocd.example.com
            application.instanceLabelKey: argocd.argoproj.io/instance

            # Git repository credentials
            repositories: |
              - url: https://github.com/organization/platform
                name: platform
                type: git

          rbacConfig:
            policy.default: role:readonly
            policy.csv: |
              p, role:org-admin, applications, *, */*, allow
              p, role:org-admin, clusters, *, *, allow
              p, role:org-admin, repositories, *, *, allow
              g, platform-admins, role:org-admin

        repoServer:
          replicas: 2
          resources:
            requests:
              cpu: 250m
              memory: 512Mi
            limits:
              cpu: 500m
              memory: 1Gi

        applicationSet:
          enabled: true

        notifications:
          enabled: true
          argocdUrl: https://argocd.example.com
          notifiers:
            service.slack: |
              token: $slack-token
          templates:
            template.app-deployed: |
              message: |
                Application {{.app.metadata.name}} is now running new version.
              slack:
                attachments: |
                  [{
                    "title": "{{ .app.metadata.name}}",
                    "title_link":"{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
                    "color": "#18be52",
                    "fields": [
                      {
                        "title": "Sync Status",
                        "value": "{{.app.status.sync.status}}",
                        "short": true
                      },
                      {
                        "title": "Repository",
                        "value": "{{.app.spec.source.repoURL}}",
                        "short": true
                      }
                    ]
                  }]
          triggers:
            trigger.on-deployed: |
              - when: app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'
                send: [app-deployed]

  destination:
    server: https://kubernetes.default.svc
    namespace: argocd

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### ArgoCD Project

```yaml
# infrastructure/argocd/projects/platform.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: platform
  namespace: argocd
spec:
  description: Platform microservices

  # Source repositories
  sourceRepos:
    - 'https://github.com/organization/platform'

  # Destination clusters and namespaces
  destinations:
    - namespace: 'platform-*'
      server: https://kubernetes.default.svc
    - namespace: argocd
      server: https://kubernetes.default.svc

  # Allowed cluster resources
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
    - group: rbac.authorization.k8s.io
      kind: ClusterRole
    - group: rbac.authorization.k8s.io
      kind: ClusterRoleBinding

  # Allowed namespace resources
  namespaceResourceWhitelist:
    - group: ''
      kind: '*'
    - group: apps
      kind: '*'
    - group: batch
      kind: '*'
    - group: networking.k8s.io
      kind: '*'
    - group: autoscaling
      kind: '*'
    - group: policy
      kind: '*'
    - group: monitoring.coreos.com
      kind: '*'

  # Deny specific resources
  namespaceResourceBlacklist:
    - group: ''
      kind: ResourceQuota
    - group: ''
      kind: LimitRange

  # Roles
  roles:
    - name: developer
      description: Developers can view and sync applications
      policies:
        - p, proj:platform:developer, applications, get, platform/*, allow
        - p, proj:platform:developer, applications, sync, platform/*, allow
      groups:
        - platform-developers

    - name: admin
      description: Admins have full access
      policies:
        - p, proj:platform:admin, applications, *, platform/*, allow
      groups:
        - platform-admins
```

## Application Management

### Application Definition

```yaml
# infrastructure/argocd/applications/platform-production.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-production
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: platform

  source:
    repoURL: https://github.com/organization/platform
    targetRevision: main
    path: infrastructure/k8s/overlays/production

  destination:
    server: https://kubernetes.default.svc
    namespace: platform-production

  syncPolicy:
    automated:
      prune: true       # Delete resources not in Git
      selfHeal: true    # Sync when cluster state differs from Git
      allowEmpty: false # Prevent empty sync

    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true

    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m

  # Ignore differences in certain fields
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas  # Ignore if HPA manages replicas

  # Health assessment customization
  health:
    - group: argoproj.io
      kind: Rollout
      check: |
        hs = {}
        if obj.status ~= nil then
          if obj.status.phase == "Healthy" then
            hs.status = "Healthy"
            hs.message = "Rollout is healthy"
            return hs
          end
          if obj.status.phase == "Degraded" then
            hs.status = "Degraded"
            hs.message = "Rollout is degraded"
            return hs
          end
        end
        hs.status = "Progressing"
        hs.message = "Waiting for rollout"
        return hs

  revisionHistoryLimit: 10
```

### App of Apps Pattern

```yaml
# infrastructure/argocd/app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-apps
  namespace: argocd
spec:
  project: platform

  source:
    repoURL: https://github.com/organization/platform
    targetRevision: main
    path: infrastructure/argocd/applications

  destination:
    server: https://kubernetes.default.svc
    namespace: argocd

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

This creates all applications from the `applications/` directory automatically.

### ApplicationSet for Multiple Environments

```yaml
# infrastructure/argocd/applicationset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: platform
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - environment: development
            url: https://dev-cluster.example.com
            namespace: platform-dev
          - environment: staging
            url: https://staging-cluster.example.com
            namespace: platform-staging
          - environment: production
            url: https://prod-cluster.example.com
            namespace: platform-production

  template:
    metadata:
      name: 'platform-{{environment}}'
      labels:
        environment: '{{environment}}'
    spec:
      project: platform

      source:
        repoURL: https://github.com/organization/platform
        targetRevision: main
        path: 'infrastructure/k8s/overlays/{{environment}}'

      destination:
        server: '{{url}}'
        namespace: '{{namespace}}'

      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

## Environment Promotion

### Workflow

```
Development → Staging → Production

1. Developer commits to feature branch
2. CI builds and tests
3. Merge to main → Auto-deploy to Development
4. Manual promotion to Staging (PR)
5. E2E tests in Staging
6. Manual promotion to Production (PR with approval)
```

### Promotion Script

```bash
#!/bin/bash
# scripts/promote.sh

set -e

SOURCE_ENV=$1
TARGET_ENV=$2

if [ -z "$SOURCE_ENV" ] || [ -z "$TARGET_ENV" ]; then
    echo "Usage: $0 <source-env> <target-env>"
    echo "Example: $0 staging production"
    exit 1
fi

echo "Promoting from $SOURCE_ENV to $TARGET_ENV..."

# Get current image tags from source
SOURCE_DIR="infrastructure/k8s/overlays/$SOURCE_ENV"
TARGET_DIR="infrastructure/k8s/overlays/$TARGET_ENV"

# Extract image tags from source kustomization
BFF_TAG=$(yq eval '.images[] | select(.name == "ghcr.io/platform/bff") | .newTag' "$SOURCE_DIR/kustomization.yaml")
LLM_TAG=$(yq eval '.images[] | select(.name == "ghcr.io/platform/llm-agent") | .newTag' "$SOURCE_DIR/kustomization.yaml")

echo "BFF: $BFF_TAG"
echo "LLM Agent: $LLM_TAG"

# Create promotion branch
BRANCH="promote-$SOURCE_ENV-to-$TARGET_ENV-$(date +%Y%m%d-%H%M%S)"
git checkout -b "$BRANCH"

# Update target kustomization
cd "$TARGET_DIR"
kustomize edit set image \
    "ghcr.io/platform/bff:$BFF_TAG" \
    "ghcr.io/platform/llm-agent:$LLM_TAG"

cd -

# Commit and push
git add "$TARGET_DIR/kustomization.yaml"
git commit -m "promote: $SOURCE_ENV to $TARGET_ENV

BFF: $BFF_TAG
LLM Agent: $LLM_TAG"

git push origin "$BRANCH"

# Create Pull Request
gh pr create \
    --title "Promote $SOURCE_ENV to $TARGET_ENV" \
    --body "Promoting tested changes from $SOURCE_ENV to $TARGET_ENV

**Images:**
- BFF: \`$BFF_TAG\`
- LLM Agent: \`$LLM_TAG\`

**Checklist:**
- [ ] All tests passed in $SOURCE_ENV
- [ ] No incidents in $SOURCE_ENV
- [ ] Deployment plan reviewed
- [ ] Rollback plan ready" \
    --base main \
    --head "$BRANCH"

echo "✅ Pull request created for promotion"
```

### Automated Promotion with Tests

```yaml
# .github/workflows/promote.yml
name: Promote to Production

on:
  workflow_dispatch:
    inputs:
      source_environment:
        description: 'Source environment'
        required: true
        default: 'staging'
      target_environment:
        description: 'Target environment'
        required: true
        default: 'production'

jobs:
  validate:
    name: Validate Source Environment
    runs-on: ubuntu-latest
    steps:
      - name: Check Staging Health
        run: |
          HEALTH=$(curl -s https://staging.platform.example.com/health)
          if [ "$(echo $HEALTH | jq -r '.status')" != "healthy" ]; then
            echo "Staging is not healthy!"
            exit 1
          fi

      - name: Check Error Rate
        run: |
          ERROR_RATE=$(curl -s "https://prometheus.example.com/api/v1/query?query=rate(http_requests_total{status=~\"5..\",env=\"staging\"}[5m])")
          # Fail if error rate > 1%
          if [ "$(echo $ERROR_RATE | jq '.data.result[0].value[1]')" -gt "0.01" ]; then
            echo "Error rate too high!"
            exit 1
          fi

  promote:
    name: Promote
    needs: validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run promotion script
        run: |
          ./scripts/promote.sh ${{ github.event.inputs.source_environment }} ${{ github.event.inputs.target_environment }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Rollback Procedures

### Automatic Rollback with Argo Rollouts

```yaml
# infrastructure/k8s/base/bff/rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: bff
spec:
  replicas: 5
  revisionHistoryLimit: 5

  strategy:
    canary:
      steps:
        - setWeight: 10
        - pause: {duration: 2m}
        - setWeight: 50
        - pause: {duration: 5m}

      analysis:
        templates:
          - templateName: success-rate
          - templateName: latency
        args:
          - name: service-name
            value: bff

  template:
    spec:
      containers:
        - name: bff
          image: ghcr.io/platform/bff:latest

---
# infrastructure/k8s/base/bff/analysis.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
    - name: service-name

  metrics:
    - name: success-rate
      interval: 1m
      successCondition: result[0] >= 0.95
      failureLimit: 3
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            sum(rate(
              http_requests_total{
                service="{{args.service-name}}",
                status=~"2.."
              }[5m]
            )) /
            sum(rate(
              http_requests_total{
                service="{{args.service-name}}"
              }[5m]
            ))
```

If analysis fails, Argo Rollouts automatically rolls back to the previous version.

### Manual Rollback

```bash
# Rollback using ArgoCD
argocd app rollback platform-production <revision>

# List available revisions
argocd app history platform-production

# Or revert Git commit
git revert <commit-sha>
git push origin main
# ArgoCD will automatically sync to previous state
```

### Emergency Rollback Procedure

```bash
#!/bin/bash
# scripts/emergency-rollback.sh

set -e

APP_NAME="platform-production"
ARGOCD_SERVER="argocd.example.com"

echo "⚠️  EMERGENCY ROLLBACK INITIATED"

# Get last successful revision
LAST_GOOD_REVISION=$(argocd app history $APP_NAME \
    --output json \
    | jq -r '.[] | select(.deployedAt != null and .status == "Succeeded") | .revision' \
    | head -1)

echo "Rolling back to: $LAST_GOOD_REVISION"

# Perform rollback
argocd app rollback $APP_NAME $LAST_GOOD_REVISION \
    --server $ARGOCD_SERVER

# Wait for sync
argocd app wait $APP_NAME \
    --sync \
    --health \
    --timeout 600

# Verify health
HEALTH=$(argocd app get $APP_NAME -o json | jq -r '.status.health.status')

if [ "$HEALTH" == "Healthy" ]; then
    echo "✅ Rollback successful"

    # Notify team
    curl -X POST $SLACK_WEBHOOK \
        -H 'Content-Type: application/json' \
        -d "{\"text\":\"✅ Emergency rollback completed for $APP_NAME\"}"
else
    echo "❌ Rollback failed - manual intervention required"
    exit 1
fi
```

## Secret Management

### Sealed Secrets

```bash
# Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Install kubeseal CLI
brew install kubeseal
```

```yaml
# Create secret
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: platform-production
type: Opaque
stringData:
  database-password: "super-secret-password"
  openai-api-key: "sk-..."

# Seal it
kubeseal \
    --controller-namespace kube-system \
    --controller-name sealed-secrets-controller \
    --format yaml \
    < secret.yaml \
    > sealed-secret.yaml

# Sealed secret can be committed to Git
# infrastructure/k8s/overlays/production/sealed-secrets.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: app-secrets
  namespace: platform-production
spec:
  encryptedData:
    database-password: AgB7... # Encrypted
    openai-api-key: AgC8...    # Encrypted
  template:
    metadata:
      name: app-secrets
      namespace: platform-production
    type: Opaque
```

### External Secrets Operator

```yaml
# infrastructure/k8s/base/external-secrets/secret-store.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault
  namespace: platform-production
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "platform-production"

---
# infrastructure/k8s/base/external-secrets/external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
  namespace: platform-production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault
    kind: SecretStore

  target:
    name: app-secrets
    creationPolicy: Owner

  data:
    - secretKey: database-password
      remoteRef:
        key: platform/production/database
        property: password

    - secretKey: openai-api-key
      remoteRef:
        key: platform/production/llm
        property: api_key
```

## Multi-Cluster Setup

### Cluster Registration

```bash
# Add remote cluster to ArgoCD
argocd cluster add staging-cluster \
    --name staging \
    --server https://staging-k8s.example.com

argocd cluster add production-cluster \
    --name production \
    --server https://prod-k8s.example.com
```

### ApplicationSet for Multi-Cluster

```yaml
# infrastructure/argocd/applicationset-multi-cluster.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: platform-multi-cluster
  namespace: argocd
spec:
  generators:
    - matrix:
        generators:
          # Cluster generator
          - clusters:
              selector:
                matchLabels:
                  environment: production

          # Service generator
          - list:
              elements:
                - service: bff
                - service: llm-agent
                - service: workflow-orchestrator

  template:
    metadata:
      name: '{{service}}-{{name}}'
    spec:
      project: platform

      source:
        repoURL: https://github.com/organization/platform
        targetRevision: main
        path: 'infrastructure/k8s/overlays/{{metadata.labels.environment}}'

      destination:
        server: '{{server}}'
        namespace: 'platform-{{metadata.labels.environment}}'

      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

## Best Practices

### 1. Small, Frequent Commits

```bash
# ✅ GOOD: Small, focused changes
git commit -m "feat(bff): update to v1.2.3"
git commit -m "fix(llm): increase memory limits"

# ❌ BAD: Large, bundled changes
git commit -m "update all services and configs"
```

### 2. Use Kustomize for Environment Differences

```yaml
# ✅ GOOD: Base + overlays
base/
  deployment.yaml  # Common configuration
overlays/
  production/
    kustomization.yaml  # Production-specific settings
    patches/

# ❌ BAD: Duplicated manifests per environment
production/
  deployment-production.yaml
staging/
  deployment-staging.yaml
```

### 3. Separate App Code from Config

```
# ✅ GOOD: Separate repositories
platform/              # Application code
platform-gitops/       # Kubernetes manifests

# Or monorepo with clear separation
platform/
  services/            # Application code
  infrastructure/      # Kubernetes manifests
```

### 4. Use Sync Waves for Ordering

```yaml
# Apply namespaces first
apiVersion: v1
kind: Namespace
metadata:
  name: platform-production
  annotations:
    argocd.argoproj.io/sync-wave: "0"

---
# Then config maps
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  annotations:
    argocd.argoproj.io/sync-wave: "1"

---
# Finally deployments
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bff
  annotations:
    argocd.argoproj.io/sync-wave: "2"
```

### 5. Use Sync Windows

```yaml
# Only allow syncs during maintenance window
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-production
spec:
  syncPolicy:
    syncOptions:
      - CreateNamespace=true

    # Sync windows
    syncWindows:
      - kind: allow
        schedule: '0 2 * * *'  # 2 AM daily
        duration: 2h
        applications:
          - '*'
        manualSync: true  # Allow manual sync anytime
```

### 6. Monitor ArgoCD Itself

```yaml
# infrastructure/argocd/monitoring/servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
    - port: metrics
```

### 7. Use Pre-Sync and Post-Sync Hooks

```yaml
# Run database migrations before deployment
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
        - name: migrate
          image: ghcr.io/platform/bff:v1.2.3
          command: ["php", "bin/console", "doctrine:migrations:migrate"]
      restartPolicy: Never

---
# Run smoke tests after deployment
apiVersion: batch/v1
kind: Job
metadata:
  name: smoke-tests
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
        - name: test
          image: ghcr.io/platform/e2e-tests:latest
          command: ["npm", "run", "test:smoke"]
      restartPolicy: Never
```

## Summary

This GitOps workflow document provides:

1. **Complete GitOps Setup**: From principles to implementation
2. **Repository Structure**: Organized for scalability
3. **ArgoCD Configuration**: Production-ready setup
4. **Environment Promotion**: Safe, tested promotion workflow
5. **Rollback Procedures**: Automatic and manual rollback strategies
6. **Secret Management**: Secure secret handling with Sealed Secrets
7. **Multi-Cluster**: Managing multiple environments and clusters
8. **Best Practices**: Industry-standard GitOps patterns

GitOps provides a declarative, version-controlled, and auditable approach to continuous deployment, ensuring consistency and reliability across all environments.
