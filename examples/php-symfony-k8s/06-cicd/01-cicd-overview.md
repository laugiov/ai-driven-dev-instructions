# CI/CD Overview

## Table of Contents

1. [Introduction](#introduction)
2. [CI/CD Philosophy](#cicd-philosophy)
3. [Pipeline Architecture](#pipeline-architecture)
4. [GitHub Actions Workflows](#github-actions-workflows)
5. [Environment Strategy](#environment-strategy)
6. [GitOps with ArgoCD](#gitops-with-argocd)
7. [Deployment Strategies](#deployment-strategies)
8. [Security in CI/CD](#security-in-cicd)
9. [Monitoring and Observability](#monitoring-and-observability)
10. [Rollback Procedures](#rollback-procedures)

## Introduction

This document provides a comprehensive overview of the Continuous Integration and Continuous Deployment (CI/CD) strategy for the AI Workflow Processing Platform. Our CI/CD approach emphasizes automation, quality, security, and rapid feedback.

### CI/CD Goals

**Speed**: Deploy changes to production quickly and safely.

**Quality**: Prevent defects from reaching production through automated testing.

**Reliability**: Ensure deployments are consistent and repeatable.

**Security**: Integrate security checks throughout the pipeline.

**Transparency**: Provide visibility into the deployment process.

**Rollback Safety**: Enable quick rollback if issues arise.

### Key Principles

**Automate Everything**: Manual steps are error-prone and slow.

**Fail Fast**: Detect issues as early as possible in the pipeline.

**Test at Every Stage**: Unit, integration, and end-to-end tests.

**Security by Default**: Security scans in every build.

**Immutable Artifacts**: Build once, deploy many times.

**Infrastructure as Code**: All infrastructure defined in version control.

## CI/CD Philosophy

### Continuous Integration

**Definition**: Developers integrate code into a shared repository frequently, ideally several times per day. Each integration triggers automated builds and tests.

**Benefits**:
- Detect integration issues early
- Reduce integration problems
- Faster feedback to developers
- Higher code quality

**Our Approach**:
```
Developer Push → CI Pipeline
    ↓
    ├── Code Quality Checks (PHPStan, Psalm)
    ├── Security Scans (Snyk, Trivy)
    ├── Unit Tests (PHPUnit)
    ├── Integration Tests
    └── Build Docker Images
    ↓
Artifacts Ready for Deployment
```

### Continuous Deployment

**Definition**: Every change that passes automated tests is automatically deployed to production.

**Benefits**:
- Faster time to market
- Reduced deployment risk (smaller changes)
- Immediate feedback from users
- Lower stress deployments

**Our Approach**:
```
Merge to Main → Automated Deployment
    ↓
    ├── Deploy to Staging
    ├── Automated Tests in Staging
    ├── Security Validation
    └── Deploy to Production (via ArgoCD)
    ↓
Monitoring & Alerting
```

### Deployment Frequency

**Target Metrics**:
- **Deployment Frequency**: Multiple times per day
- **Lead Time for Changes**: < 1 hour (commit to production)
- **Mean Time to Recovery (MTTR)**: < 15 minutes
- **Change Failure Rate**: < 15%

## Pipeline Architecture

### Pipeline Stages

```yaml
# High-level pipeline flow
stages:
  - validate      # Code quality, linting
  - test          # Unit, integration tests
  - security      # Security scans
  - build         # Docker images
  - deploy-dev    # Deploy to development
  - deploy-staging # Deploy to staging
  - e2e-tests     # End-to-end tests
  - deploy-prod   # Deploy to production
  - smoke-tests   # Production smoke tests
```

### Pipeline Visualization

```
┌─────────────────────────────────────────────────────────────────┐
│                         GitHub Push/PR                           │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    VALIDATE STAGE (3-5 min)                      │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │  PHPStan    │  │   Psalm     │  │  PHP CS     │            │
│  │  Level 9    │  │  Level 1    │  │   Fixer     │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      TEST STAGE (5-10 min)                       │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │    Unit     │  │ Integration │  │  Mutation   │            │
│  │   Tests     │  │    Tests    │  │   Testing   │            │
│  │  (80% cov)  │  │             │  │  (70% MSI)  │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SECURITY STAGE (5-8 min)                      │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │    Snyk     │  │    Trivy    │  │   License   │            │
│  │  Dependency │  │   Docker    │  │   Check     │            │
│  │    Scan     │  │    Scan     │  │             │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                     BUILD STAGE (8-12 min)                       │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Build Multi-arch Docker Images                          │  │
│  │  - Tag with commit SHA, branch, latest                   │  │
│  │  - Push to Container Registry (GHCR)                     │  │
│  │  - Sign images with Cosign                               │  │
│  │  - Generate SBOM (Software Bill of Materials)            │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                  DEPLOY TO STAGING (2-3 min)                     │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  ArgoCD Deploys to Staging Cluster                       │  │
│  │  - Rolling update strategy                               │  │
│  │  - Health checks                                         │  │
│  │  - Smoke tests                                           │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                   E2E TESTS STAGE (10-15 min)                    │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Run E2E tests against Staging                           │  │
│  │  - API workflow tests                                    │  │
│  │  - Integration scenarios                                 │  │
│  │  - Performance tests                                     │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│               DEPLOY TO PRODUCTION (5-10 min)                    │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  ArgoCD Deploys to Production                            │  │
│  │  - Blue-Green deployment                                 │  │
│  │  - Canary rollout (10% → 50% → 100%)                     │  │
│  │  - Automated rollback on errors                          │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                   PRODUCTION VALIDATION                          │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  - Smoke tests                                           │  │
│  │  - Health checks                                         │  │
│  │  - Metrics validation                                    │  │
│  │  - Slack notification                                    │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

**Total Pipeline Time**:
- **PR Validation**: 15-20 minutes
- **Full Deployment to Production**: 35-50 minutes

## GitHub Actions Workflows

### Main Workflows

#### 1. Pull Request Workflow

```yaml
# .github/workflows/pr.yml
name: Pull Request

on:
  pull_request:
    branches: [main, develop]

jobs:
  validate:
    name: Code Quality
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          extensions: mbstring, xml, ctype, iconv, intl, pdo_pgsql
          coverage: xdebug

      - name: Get Composer Cache Directory
        id: composer-cache
        run: echo "dir=$(composer config cache-files-dir)" >> $GITHUB_OUTPUT

      - name: Cache Composer dependencies
        uses: actions/cache@v3
        with:
          path: ${{ steps.composer-cache.outputs.dir }}
          key: ${{ runner.os }}-composer-${{ hashFiles('**/composer.lock') }}
          restore-keys: ${{ runner.os }}-composer-

      - name: Install dependencies
        run: composer install --prefer-dist --no-progress --no-suggest

      - name: PHPStan
        run: vendor/bin/phpstan analyse --level=9 --error-format=github

      - name: Psalm
        run: vendor/bin/psalm --output-format=github --show-info=false

      - name: PHP CS Fixer
        run: vendor/bin/php-cs-fixer fix --dry-run --diff --format=github

  test:
    name: Tests
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_DB: test_db
          POSTGRES_USER: test_user
          POSTGRES_PASSWORD: test_pass
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          extensions: mbstring, xml, ctype, iconv, intl, pdo_pgsql, redis
          coverage: xdebug

      - name: Install dependencies
        run: composer install --prefer-dist --no-progress

      - name: Run migrations
        run: php bin/console doctrine:migrations:migrate --no-interaction
        env:
          DATABASE_URL: postgresql://test_user:test_pass@localhost:5432/test_db

      - name: Run Unit Tests
        run: vendor/bin/phpunit --testsuite=Unit --coverage-clover=coverage.xml

      - name: Check Coverage
        run: php tools/coverage-checker.php coverage.xml 80

      - name: Run Integration Tests
        run: vendor/bin/phpunit --testsuite=Integration
        env:
          DATABASE_URL: postgresql://test_user:test_pass@localhost:5432/test_db
          REDIS_URL: redis://localhost:6379

      - name: Upload Coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.xml
          fail_ci_if_error: true

  security:
    name: Security Scans
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Snyk Security Scan
        uses: snyk/actions/php@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy results to GitHub Security tab
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'
```

#### 2. Main Branch Workflow (CI/CD)

```yaml
# .github/workflows/main.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  validate-and-test:
    name: Validate and Test
    runs-on: ubuntu-latest
    # ... same as PR workflow ...

  build:
    name: Build Docker Images
    needs: [validate-and-test]
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write  # For Cosign

    strategy:
      matrix:
        service:
          - bff
          - llm-agent
          - workflow-orchestrator
          - validation
          - notification
          - audit
          - file-storage

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}/${{ matrix.service }}
          tags: |
            type=ref,event=branch
            type=sha,prefix={{branch}}-
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}

      - name: Build and push Docker image
        id: build-and-push
        uses: docker/build-push-action@v5
        with:
          context: ./services/${{ matrix.service }}
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          build-args: |
            BUILD_DATE=${{ github.event.head_commit.timestamp }}
            VCS_REF=${{ github.sha }}
            VERSION=${{ steps.meta.outputs.version }}

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Sign container image
        run: |
          cosign sign --yes \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}/${{ matrix.service }}@${{ steps.build-and-push.outputs.digest }}

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}/${{ matrix.service }}@${{ steps.build-and-push.outputs.digest }}
          format: cyclonedx-json
          output-file: sbom-${{ matrix.service }}.json

      - name: Upload SBOM
        uses: actions/upload-artifact@v3
        with:
          name: sbom-${{ matrix.service }}
          path: sbom-${{ matrix.service }}.json

  deploy-staging:
    name: Deploy to Staging
    needs: [build]
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging.platform.example.com

    steps:
      - uses: actions/checkout@v4

      - name: Update ArgoCD Application
        run: |
          # Update image tags in kustomize overlay
          cd infrastructure/k8s/overlays/staging
          kustomize edit set image \
            bff=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}/bff:${{ github.sha }} \
            llm-agent=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}/llm-agent:${{ github.sha }}
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add .
          git commit -m "Update staging to ${{ github.sha }}"
          git push

      - name: Wait for ArgoCD Sync
        run: |
          argocd app wait platform-staging \
            --sync \
            --health \
            --timeout 600

      - name: Run Smoke Tests
        run: |
          npm ci
          npm run test:smoke -- --baseUrl=https://staging.platform.example.com

  e2e-tests:
    name: E2E Tests
    needs: [deploy-staging]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install Playwright
        run: |
          npm ci
          npx playwright install --with-deps

      - name: Run E2E Tests
        run: npx playwright test
        env:
          BASE_URL: https://staging.platform.example.com
          API_KEY: ${{ secrets.STAGING_API_KEY }}

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: playwright-report
          path: playwright-report/

  deploy-production:
    name: Deploy to Production
    needs: [e2e-tests]
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://platform.example.com

    steps:
      - uses: actions/checkout@v4

      - name: Update ArgoCD Application
        run: |
          cd infrastructure/k8s/overlays/production
          kustomize edit set image \
            bff=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}/bff:${{ github.sha }}
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add .
          git commit -m "Deploy to production: ${{ github.sha }}"
          git push

      - name: Wait for Canary Rollout
        run: |
          # ArgoCD progressive sync with Argo Rollouts
          argocd app wait platform-production \
            --sync \
            --timeout 900

      - name: Validate Production
        run: |
          npm run test:smoke -- --baseUrl=https://platform.example.com

      - name: Notify Slack
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "✅ Production Deployment Successful",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Production Deployment Successful*\n\nCommit: `${{ github.sha }}`\nAuthor: ${{ github.actor }}\nTime: ${{ github.event.head_commit.timestamp }}"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

## Environment Strategy

### Environment Tiers

```
┌───────────────────────────────────────────────────────────────┐
│                       DEVELOPMENT                              │
├───────────────────────────────────────────────────────────────┤
│ Purpose: Active development                                   │
│ Deploys: On every commit to develop branch                    │
│ Data: Synthetic/test data                                     │
│ Access: All developers                                        │
│ Monitoring: Basic                                             │
└───────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌───────────────────────────────────────────────────────────────┐
│                        STAGING                                 │
├───────────────────────────────────────────────────────────────┤
│ Purpose: Pre-production testing                               │
│ Deploys: On merge to main (before production)                 │
│ Data: Anonymized production data                             │
│ Access: Developers, QA team                                   │
│ Monitoring: Full monitoring (same as prod)                    │
│ Infrastructure: Same as production                            │
└───────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌───────────────────────────────────────────────────────────────┐
│                       PRODUCTION                               │
├───────────────────────────────────────────────────────────────┤
│ Purpose: Live system                                          │
│ Deploys: After successful staging validation                  │
│ Data: Real customer data                                      │
│ Access: Operations team only                                  │
│ Monitoring: Comprehensive monitoring & alerting               │
│ Backup: Automated backups every 6 hours                       │
└───────────────────────────────────────────────────────────────┘
```

### Environment Configuration

```yaml
# infrastructure/k8s/overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: platform-production

resources:
  - ../../base

replicas:
  - name: bff
    count: 3
  - name: llm-agent
    count: 5
  - name: workflow-orchestrator
    count: 3

configMapGenerator:
  - name: app-config
    literals:
      - APP_ENV=production
      - LOG_LEVEL=warning
      - CACHE_TTL=3600

secretGenerator:
  - name: app-secrets
    files:
      - .env.production

images:
  - name: bff
    newName: ghcr.io/platform/bff
    newTag: v1.2.3
```

## GitOps with ArgoCD

### ArgoCD Application Definition

```yaml
# infrastructure/argocd/applications/platform-production.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-production
  namespace: argocd
spec:
  project: default

  source:
    repoURL: https://github.com/organization/platform
    targetRevision: main
    path: infrastructure/k8s/overlays/production

  destination:
    server: https://kubernetes.default.svc
    namespace: platform-production

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
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

  # Progressive sync with Argo Rollouts
  revisionHistoryLimit: 10
```

### Argo Rollouts for Canary Deployment

```yaml
# infrastructure/k8s/base/rollouts/bff-rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: bff
spec:
  replicas: 5
  strategy:
    canary:
      steps:
        - setWeight: 10
        - pause: {duration: 2m}
        - setWeight: 20
        - pause: {duration: 2m}
        - setWeight: 50
        - pause: {duration: 5m}
        - setWeight: 100

      trafficRouting:
        istio:
          virtualService:
            name: bff
            routes:
              - primary

      analysis:
        templates:
          - templateName: success-rate
        args:
          - name: service-name
            value: bff

  revisionHistoryLimit: 3

  selector:
    matchLabels:
      app: bff

  template:
    metadata:
      labels:
        app: bff
        version: stable
    spec:
      containers:
        - name: bff
          image: ghcr.io/platform/bff:latest
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health/live
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 20
```

### Analysis Template for Automated Rollback

```yaml
# infrastructure/k8s/base/analysis/success-rate.yaml
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

    - name: error-rate
      interval: 1m
      successCondition: result[0] <= 0.05
      failureLimit: 3
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            sum(rate(
              http_requests_total{
                service="{{args.service-name}}",
                status=~"5.."
              }[5m]
            )) /
            sum(rate(
              http_requests_total{
                service="{{args.service-name}}"
              }[5m]
            ))

    - name: latency-p95
      interval: 1m
      successCondition: result[0] <= 0.2
      failureLimit: 3
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            histogram_quantile(0.95,
              sum(rate(
                http_request_duration_seconds_bucket{
                  service="{{args.service-name}}"
                }[5m]
              )) by (le)
            )
```

## Deployment Strategies

### Blue-Green Deployment

```yaml
# For database migrations and major changes
apiVersion: v1
kind: Service
metadata:
  name: bff
spec:
  selector:
    app: bff
    version: blue  # Switch to green when ready
  ports:
    - port: 80
      targetPort: 8080

---
# Blue deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bff-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: bff
      version: blue
  template:
    metadata:
      labels:
        app: bff
        version: blue
    spec:
      containers:
        - name: bff
          image: ghcr.io/platform/bff:v1.2.3

---
# Green deployment (new version)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bff-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: bff
      version: green
  template:
    metadata:
      labels:
        app: bff
        version: green
    spec:
      containers:
        - name: bff
          image: ghcr.io/platform/bff:v1.3.0
```

### Canary Deployment (Default)

Controlled by Argo Rollouts (see above).

**Benefits**:
- Gradual rollout
- Automated rollback on errors
- Real-time monitoring
- Low risk

### Rolling Update

```yaml
# For minor updates
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bff
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    spec:
      containers:
        - name: bff
          image: ghcr.io/platform/bff:latest
```

## Security in CI/CD

### Secret Management

```yaml
# Using Sealed Secrets
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: app-secrets
  namespace: platform-production
spec:
  encryptedData:
    database-password: AgBx...encrypted...
    openai-api-key: AgCy...encrypted...
```

### Image Signing with Cosign

```bash
# Sign image
cosign sign --key cosign.key ghcr.io/platform/bff:v1.2.3

# Verify signature
cosign verify --key cosign.pub ghcr.io/platform/bff:v1.2.3
```

### SBOM (Software Bill of Materials)

Generated for every image to track dependencies and vulnerabilities.

## Monitoring and Observability

### Deployment Metrics

```yaml
# Prometheus ServiceMonitor for deployments
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: deployment-metrics
spec:
  selector:
    matchLabels:
      app: platform
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

### Key Metrics Tracked

- **Deployment Frequency**: Deployments per day
- **Lead Time**: Commit to production time
- **Change Failure Rate**: % of deployments causing incidents
- **MTTR**: Mean time to recovery
- **Success Rate**: % of successful requests
- **Latency**: P50, P95, P99 response times
- **Error Rate**: 4xx and 5xx errors

## Rollback Procedures

### Automatic Rollback

Argo Rollouts automatically rolls back if analysis fails.

### Manual Rollback

```bash
# Rollback to previous version
kubectl argo rollouts undo bff

# Rollback to specific revision
kubectl argo rollouts undo bff --to-revision=3

# View rollout history
kubectl argo rollouts history bff
```

### Emergency Rollback

```bash
# Immediate rollback by updating ArgoCD application
argocd app set platform-production \
  --revision <previous-commit-sha>

argocd app sync platform-production
```

## Summary

This CI/CD overview provides:

1. **Automated Pipeline**: From commit to production in < 1 hour
2. **Quality Gates**: PHPStan, tests, security scans at every stage
3. **GitOps**: Declarative infrastructure with ArgoCD
4. **Progressive Delivery**: Canary deployments with automated rollback
5. **Security**: Image signing, SBOM generation, secret management
6. **Observability**: Comprehensive metrics and monitoring
7. **Safety**: Multiple environments, automated tests, quick rollback

The pipeline ensures rapid, safe deployments with minimal manual intervention.
