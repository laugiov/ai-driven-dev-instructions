# Deployment Strategies

## Table of Contents

1. [Overview](#overview)
2. [Blue-Green Deployment](#blue-green-deployment)
3. [Canary Deployment](#canary-deployment)
4. [Rolling Updates](#rolling-updates)
5. [A/B Testing Deployments](#ab-testing-deployments)
6. [Traffic Splitting Strategies](#traffic-splitting-strategies)
7. [Rollback Procedures](#rollback-procedures)
8. [Database Migration Strategies](#database-migration-strategies)
9. [Zero-Downtime Deployment](#zero-downtime-deployment)
10. [Feature Flags Integration](#feature-flags-integration)
11. [Deployment Decision Matrix](#deployment-decision-matrix)
12. [Monitoring and Validation](#monitoring-and-validation)

## Overview

### Purpose

This document provides comprehensive guidance on deployment strategies for the AI Workflow Processing Platform. Each strategy is designed to minimize risk, ensure high availability, and enable rapid rollback when necessary.

### Strategic Objectives

```yaml
deployment_objectives:
  availability:
    target: 99.95%
    max_downtime: 4.38 hours/year
    deployment_impact: zero downtime

  safety:
    automated_validation: required
    progressive_rollout: default
    instant_rollback: < 60 seconds

  velocity:
    deployment_frequency: multiple per day
    lead_time: < 1 hour
    mean_time_to_recovery: < 5 minutes

  quality:
    pre_deployment_validation: comprehensive
    post_deployment_validation: automated
    user_impact: minimal
```

### Strategy Selection Criteria

| Strategy | Use Case | Risk Level | Complexity | Cost | Rollback Speed |
|----------|----------|------------|------------|------|----------------|
| Blue-Green | Major releases, infrastructure changes | Low | Medium | High (2x resources) | Instant |
| Canary | Feature releases, service updates | Low | High | Medium | Fast (1-5 min) |
| Rolling | Minor updates, patches | Medium | Low | Low | Medium (5-15 min) |
| A/B Testing | UX changes, algorithm variants | Low | High | Medium | Instant |
| Feature Flags | Experimental features, gradual rollout | Very Low | Medium | Low | Instant |

## Blue-Green Deployment

### Overview

Blue-Green deployment maintains two identical production environments. At any time, one environment (Blue) serves production traffic while the other (Green) is idle or used for testing. During deployment, the new version is deployed to the idle environment, validated, and then traffic is switched over.

### Architecture

```yaml
# Blue-Green Environment Configuration
environments:
  blue:
    namespace: platform-production-blue
    active: true
    version: v1.24.0
    resources:
      replicas: 10
      cpu: "4000m"
      memory: "8Gi"
    endpoints:
      - https://api.platform.com
      - https://app.platform.com

  green:
    namespace: platform-production-green
    active: false
    version: v1.25.0
    resources:
      replicas: 10
      cpu: "4000m"
      memory: "8Gi"
    endpoints:
      - https://api-green.platform.internal
      - https://app-green.platform.internal

traffic_management:
  router: istio
  switch_method: virtualservice_update
  warmup_period: 300s
  connection_drain: 30s
```

### Implementation with Kubernetes and Istio

#### Service Definitions

```yaml
# blue-green-services.yaml
---
apiVersion: v1
kind: Service
metadata:
  name: workflow-engine-blue
  namespace: platform-production-blue
  labels:
    app: workflow-engine
    environment: blue
    version: v1.24.0
spec:
  type: ClusterIP
  selector:
    app: workflow-engine
    environment: blue
  ports:
    - name: http
      port: 80
      targetPort: 8080
    - name: grpc
      port: 9090
      targetPort: 9090
    - name: metrics
      port: 9091
      targetPort: 9091

---
apiVersion: v1
kind: Service
metadata:
  name: workflow-engine-green
  namespace: platform-production-green
  labels:
    app: workflow-engine
    environment: green
    version: v1.25.0
spec:
  type: ClusterIP
  selector:
    app: workflow-engine
    environment: green
  ports:
    - name: http
      port: 80
      targetPort: 8080
    - name: grpc
      port: 9090
      targetPort: 9090
    - name: metrics
      port: 9091
      targetPort: 9091
```

#### Istio VirtualService for Traffic Switching

```yaml
# blue-green-virtualservice.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: workflow-engine
  namespace: platform-production
spec:
  hosts:
    - workflow-engine.platform.svc.cluster.local
    - api.platform.com
  gateways:
    - platform-gateway
    - mesh
  http:
    - name: "production-traffic"
      match:
        - uri:
            prefix: "/api/v1/workflows"
      route:
        - destination:
            host: workflow-engine-blue.platform-production-blue.svc.cluster.local
            port:
              number: 80
          weight: 100
        - destination:
            host: workflow-engine-green.platform-production-green.svc.cluster.local
            port:
              number: 80
          weight: 0
      timeout: 30s
      retries:
        attempts: 3
        perTryTimeout: 10s
        retryOn: 5xx,reset,connect-failure,refused-stream
```

#### Blue-Green Deployment Script

```bash
#!/bin/bash
# scripts/deploy-blue-green.sh

set -euo pipefail

# Configuration
NAMESPACE_BLUE="platform-production-blue"
NAMESPACE_GREEN="platform-production-green"
SERVICE_NAME="workflow-engine"
IMAGE_TAG="${1:-latest}"
VALIDATION_TIMEOUT=600
SMOKE_TEST_SCRIPT="./scripts/smoke-tests.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Determine current active environment
determine_active_environment() {
    log_info "Determining current active environment..."

    CURRENT_WEIGHT=$(kubectl get virtualservice workflow-engine \
        -n platform-production \
        -o jsonpath='{.spec.http[0].route[0].weight}')

    if [ "$CURRENT_WEIGHT" -eq 100 ]; then
        ACTIVE_ENV="blue"
        TARGET_ENV="green"
        ACTIVE_NAMESPACE="$NAMESPACE_BLUE"
        TARGET_NAMESPACE="$NAMESPACE_GREEN"
    else
        ACTIVE_ENV="green"
        TARGET_ENV="blue"
        ACTIVE_NAMESPACE="$NAMESPACE_GREEN"
        TARGET_NAMESPACE="$NAMESPACE_BLUE"
    fi

    log_info "Active environment: $ACTIVE_ENV"
    log_info "Target environment: $TARGET_ENV"
}

# Step 2: Deploy to inactive environment
deploy_to_target() {
    log_info "Deploying version $IMAGE_TAG to $TARGET_ENV environment..."

    # Update image in target deployment
    kubectl set image deployment/$SERVICE_NAME \
        $SERVICE_NAME=registry.platform.com/$SERVICE_NAME:$IMAGE_TAG \
        -n $TARGET_NAMESPACE

    # Wait for rollout to complete
    log_info "Waiting for rollout to complete..."
    kubectl rollout status deployment/$SERVICE_NAME \
        -n $TARGET_NAMESPACE \
        --timeout=${VALIDATION_TIMEOUT}s

    # Verify all pods are ready
    READY_PODS=$(kubectl get deployment $SERVICE_NAME \
        -n $TARGET_NAMESPACE \
        -o jsonpath='{.status.readyReplicas}')

    DESIRED_PODS=$(kubectl get deployment $SERVICE_NAME \
        -n $TARGET_NAMESPACE \
        -o jsonpath='{.spec.replicas}')

    if [ "$READY_PODS" != "$DESIRED_PODS" ]; then
        log_error "Not all pods are ready. Ready: $READY_PODS, Desired: $DESIRED_PODS"
        return 1
    fi

    log_info "Deployment complete. All $READY_PODS pods are ready."
}

# Step 3: Warmup target environment
warmup_target() {
    log_info "Warming up $TARGET_ENV environment..."

    # Get internal endpoint
    TARGET_ENDPOINT=$(kubectl get service $SERVICE_NAME-$TARGET_ENV \
        -n $TARGET_NAMESPACE \
        -o jsonpath='{.spec.clusterIP}')

    # Send warmup requests
    for i in {1..100}; do
        curl -s -o /dev/null -w "%{http_code}" \
            http://$TARGET_ENDPOINT/health/ready || true
        sleep 0.1
    done

    log_info "Warmup complete"
}

# Step 4: Run smoke tests against target environment
run_smoke_tests() {
    log_info "Running smoke tests against $TARGET_ENV environment..."

    TARGET_ENDPOINT=$(kubectl get service $SERVICE_NAME-$TARGET_ENV \
        -n $TARGET_NAMESPACE \
        -o jsonpath='{.spec.clusterIP}')

    export TEST_ENDPOINT="http://$TARGET_ENDPOINT"

    if $SMOKE_TEST_SCRIPT; then
        log_info "Smoke tests passed"
        return 0
    else
        log_error "Smoke tests failed"
        return 1
    fi
}

# Step 5: Gradually switch traffic
switch_traffic() {
    log_info "Switching traffic to $TARGET_ENV environment..."

    # Calculate weights
    if [ "$TARGET_ENV" = "blue" ]; then
        TARGET_WEIGHT=100
        SOURCE_WEIGHT=0
    else
        TARGET_WEIGHT=100
        SOURCE_WEIGHT=0
    fi

    # Update VirtualService
    kubectl patch virtualservice workflow-engine \
        -n platform-production \
        --type=json \
        -p="[
            {\"op\": \"replace\", \"path\": \"/spec/http/0/route/0/weight\", \"value\": $SOURCE_WEIGHT},
            {\"op\": \"replace\", \"path\": \"/spec/http/0/route/1/weight\", \"value\": $TARGET_WEIGHT}
        ]"

    log_info "Traffic switched to $TARGET_ENV"
}

# Step 6: Validate production traffic
validate_production() {
    log_info "Validating production traffic on $TARGET_ENV..."

    # Wait for traffic to stabilize
    sleep 30

    # Check error rate
    ERROR_RATE=$(kubectl exec -n monitoring \
        deployment/prometheus \
        -- promtool query instant \
        'http://localhost:9090' \
        'rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])' \
        | jq -r '.data.result[0].value[1]')

    if (( $(echo "$ERROR_RATE > 0.01" | bc -l) )); then
        log_error "Error rate too high: $ERROR_RATE"
        return 1
    fi

    # Check latency
    P95_LATENCY=$(kubectl exec -n monitoring \
        deployment/prometheus \
        -- promtool query instant \
        'http://localhost:9090' \
        'histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))' \
        | jq -r '.data.result[0].value[1]')

    if (( $(echo "$P95_LATENCY > 1.0" | bc -l) )); then
        log_warn "P95 latency elevated: ${P95_LATENCY}s"
    fi

    log_info "Production validation passed"
    return 0
}

# Step 7: Rollback if needed
rollback() {
    log_error "Rolling back to $ACTIVE_ENV environment..."

    # Switch traffic back
    if [ "$ACTIVE_ENV" = "blue" ]; then
        kubectl patch virtualservice workflow-engine \
            -n platform-production \
            --type=json \
            -p='[
                {"op": "replace", "path": "/spec/http/0/route/0/weight", "value": 100},
                {"op": "replace", "path": "/spec/http/0/route/1/weight", "value": 0}
            ]'
    else
        kubectl patch virtualservice workflow-engine \
            -n platform-production \
            --type=json \
            -p='[
                {"op": "replace", "path": "/spec/http/0/route/0/weight", "value": 0},
                {"op": "replace", "path": "/spec/http/0/route/1/weight", "value": 100}
            ]'
    fi

    log_info "Rollback complete"
}

# Main deployment flow
main() {
    log_info "Starting Blue-Green deployment for $SERVICE_NAME:$IMAGE_TAG"

    # Determine environments
    determine_active_environment

    # Deploy to target
    if ! deploy_to_target; then
        log_error "Deployment failed"
        exit 1
    fi

    # Warmup
    warmup_target

    # Run smoke tests
    if ! run_smoke_tests; then
        log_error "Smoke tests failed, aborting deployment"
        exit 1
    fi

    # Switch traffic
    switch_traffic

    # Validate production
    if ! validate_production; then
        rollback
        exit 1
    fi

    log_info "Blue-Green deployment completed successfully"
    log_info "Active environment is now: $TARGET_ENV"
}

# Execute
main "$@"
```

### Blue-Green Deployment Workflow

```yaml
# .github/workflows/deploy-blue-green.yml
name: Blue-Green Deployment

on:
  workflow_dispatch:
    inputs:
      service:
        description: 'Service to deploy'
        required: true
        type: choice
        options:
          - workflow-engine
          - agent-manager
          - notification-service
      version:
        description: 'Version to deploy'
        required: true
        type: string

jobs:
  deploy:
    name: Deploy ${{ inputs.service }}
    runs-on: ubuntu-latest
    environment: production
    timeout-minutes: 30

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure kubectl
        uses: azure/k8s-set-context@v3
        with:
          method: kubeconfig
          kubeconfig: ${{ secrets.KUBE_CONFIG }}

      - name: Determine active environment
        id: active_env
        run: |
          WEIGHT=$(kubectl get virtualservice ${{ inputs.service }} \
            -n platform-production \
            -o jsonpath='{.spec.http[0].route[0].weight}')

          if [ "$WEIGHT" -eq 100 ]; then
            echo "active=blue" >> $GITHUB_OUTPUT
            echo "target=green" >> $GITHUB_OUTPUT
          else
            echo "active=green" >> $GITHUB_OUTPUT
            echo "target=blue" >> $GITHUB_OUTPUT
          fi

      - name: Deploy to ${{ steps.active_env.outputs.target }}
        run: |
          ./scripts/deploy-blue-green.sh \
            ${{ inputs.service }} \
            ${{ inputs.version }} \
            ${{ steps.active_env.outputs.target }}

      - name: Run smoke tests
        run: |
          export TEST_ENV=${{ steps.active_env.outputs.target }}
          ./scripts/smoke-tests.sh

      - name: Switch traffic
        run: |
          kubectl patch virtualservice ${{ inputs.service }} \
            -n platform-production \
            --type=json \
            -p='${{ steps.active_env.outputs.target == "blue" &&
                   "[{\"op\": \"replace\", \"path\": \"/spec/http/0/route/0/weight\", \"value\": 100},
                     {\"op\": \"replace\", \"path\": \"/spec/http/0/route/1/weight\", \"value\": 0}]" ||
                   "[{\"op\": \"replace\", \"path\": \"/spec/http/0/route/0/weight\", \"value\": 0},
                     {\"op\": \"replace\", \"path\": \"/spec/http/0/route/1/weight\", \"value\": 100}]" }}'

      - name: Monitor for 5 minutes
        run: |
          ./scripts/monitor-deployment.sh \
            ${{ inputs.service }} \
            300

      - name: Rollback on failure
        if: failure()
        run: |
          kubectl patch virtualservice ${{ inputs.service }} \
            -n platform-production \
            --type=json \
            -p='${{ steps.active_env.outputs.active == "blue" &&
                   "[{\"op\": \"replace\", \"path\": \"/spec/http/0/route/0/weight\", \"value\": 100},
                     {\"op\": \"replace\", \"path\": \"/spec/http/0/route/1/weight\", \"value\": 0}]" ||
                   "[{\"op\": \"replace\", \"path\": \"/spec/http/0/route/0/weight\", \"value\": 0},
                     {\"op\": \"replace\", \"path\": \"/spec/http/0/route/1/weight\", \"value\": 100}]" }}'

      - name: Notify deployment result
        if: always()
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: |
            Blue-Green Deployment ${{ job.status }}
            Service: ${{ inputs.service }}
            Version: ${{ inputs.version }}
            Target: ${{ steps.active_env.outputs.target }}
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### Advantages and Disadvantages

**Advantages**:
- Instant rollback capability
- Zero downtime deployments
- Complete isolation between versions
- Easy to validate before switching traffic
- Simple mental model

**Disadvantages**:
- Requires 2x infrastructure resources
- Database migrations can be complex
- State synchronization challenges
- Higher operational costs

## Canary Deployment

### Overview

Canary deployment releases new versions to a small subset of users before rolling out to the entire infrastructure. This allows real-world validation with minimal impact.

### Progressive Rollout Strategy

```yaml
canary_rollout:
  phases:
    - name: "Initial Canary"
      weight: 10
      duration: 10m
      success_criteria:
        error_rate: < 1%
        latency_p95: < 500ms
        saturation: < 80%

    - name: "Extended Canary"
      weight: 50
      duration: 20m
      success_criteria:
        error_rate: < 0.5%
        latency_p95: < 400ms
        saturation: < 75%

    - name: "Full Rollout"
      weight: 100
      duration: 30m
      success_criteria:
        error_rate: < 0.3%
        latency_p95: < 300ms
        saturation: < 70%

  automated_rollback:
    enabled: true
    triggers:
      - metric: error_rate
        threshold: 2%
        duration: 2m
      - metric: latency_p95
        threshold: 1000ms
        duration: 5m
      - metric: pod_crashes
        threshold: 3
        duration: 5m
```

### Implementation with Argo Rollouts

#### Rollout Configuration

```yaml
# canary-rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: workflow-engine
  namespace: platform-production
spec:
  replicas: 20
  strategy:
    canary:
      # Progressive traffic shifting
      steps:
        - setWeight: 10
        - pause:
            duration: 10m
        - analysis:
            templates:
              - templateName: success-rate
              - templateName: latency-check
            args:
              - name: service-name
                value: workflow-engine

        - setWeight: 25
        - pause:
            duration: 10m

        - setWeight: 50
        - pause:
            duration: 15m
        - analysis:
            templates:
              - templateName: success-rate
              - templateName: latency-check

        - setWeight: 75
        - pause:
            duration: 10m

        - setWeight: 100

      # Traffic routing with Istio
      trafficRouting:
        istio:
          virtualService:
            name: workflow-engine
            routes:
              - primary
          destinationRule:
            name: workflow-engine
            canarySubsetName: canary
            stableSubsetName: stable

      # Automated analysis and rollback
      analysis:
        templates:
          - templateName: success-rate
          - templateName: latency-check
          - templateName: error-rate
        startingStep: 2
        args:
          - name: service-name
            value: workflow-engine
          - name: prometheus-url
            value: http://prometheus.monitoring:9090

  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app: workflow-engine

  template:
    metadata:
      labels:
        app: workflow-engine
        version: stable
    spec:
      containers:
        - name: workflow-engine
          image: registry.platform.com/workflow-engine:v1.25.0
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
            - name: grpc
              containerPort: 9090
              protocol: TCP
            - name: metrics
              containerPort: 9091
              protocol: TCP

          env:
            - name: APP_ENV
              value: "production"
            - name: APP_DEBUG
              value: "false"
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: database-credentials
                  key: url

          resources:
            requests:
              cpu: "1000m"
              memory: "2Gi"
            limits:
              cpu: "2000m"
              memory: "4Gi"

          livenessProbe:
            httpGet:
              path: /health/live
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3

          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 2
```

#### Analysis Templates

```yaml
# analysis-templates.yaml
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
  namespace: platform-production
spec:
  args:
    - name: service-name
    - name: prometheus-url
      value: http://prometheus.monitoring:9090

  metrics:
    - name: success-rate
      interval: 1m
      count: 5
      successCondition: result[0] >= 0.95
      failureLimit: 3
      provider:
        prometheus:
          address: "{{args.prometheus-url}}"
          query: |
            sum(rate(
              http_requests_total{
                job="{{args.service-name}}",
                status!~"5.."
              }[2m]
            ))
            /
            sum(rate(
              http_requests_total{
                job="{{args.service-name}}"
              }[2m]
            ))

---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: latency-check
  namespace: platform-production
spec:
  args:
    - name: service-name
    - name: prometheus-url
      value: http://prometheus.monitoring:9090

  metrics:
    - name: p95-latency
      interval: 1m
      count: 5
      successCondition: result[0] <= 500
      failureLimit: 3
      provider:
        prometheus:
          address: "{{args.prometheus-url}}"
          query: |
            histogram_quantile(0.95,
              sum(rate(
                http_request_duration_seconds_bucket{
                  job="{{args.service-name}}"
                }[2m]
              )) by (le)
            ) * 1000

    - name: p99-latency
      interval: 1m
      count: 5
      successCondition: result[0] <= 1000
      failureLimit: 2
      provider:
        prometheus:
          address: "{{args.prometheus-url}}"
          query: |
            histogram_quantile(0.99,
              sum(rate(
                http_request_duration_seconds_bucket{
                  job="{{args.service-name}}"
                }[2m]
              )) by (le)
            ) * 1000

---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: error-rate
  namespace: platform-production
spec:
  args:
    - name: service-name
    - name: prometheus-url
      value: http://prometheus.monitoring:9090

  metrics:
    - name: error-rate
      interval: 1m
      count: 10
      successCondition: result[0] <= 0.01
      failureLimit: 3
      provider:
        prometheus:
          address: "{{args.prometheus-url}}"
          query: |
            sum(rate(
              http_requests_total{
                job="{{args.service-name}}",
                status=~"5.."
              }[2m]
            ))
            /
            sum(rate(
              http_requests_total{
                job="{{args.service-name}}"
              }[2m]
            ))
```

#### Istio Configuration for Canary

```yaml
# canary-virtualservice.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: workflow-engine
  namespace: platform-production
spec:
  hosts:
    - workflow-engine
    - api.platform.com
  gateways:
    - platform-gateway
    - mesh
  http:
    - name: primary
      match:
        - uri:
            prefix: "/api/v1/workflows"
      route:
        - destination:
            host: workflow-engine
            subset: stable
          weight: 90
        - destination:
            host: workflow-engine
            subset: canary
          weight: 10
      timeout: 30s
      retries:
        attempts: 3
        perTryTimeout: 10s
        retryOn: 5xx,reset,connect-failure

---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: workflow-engine
  namespace: platform-production
spec:
  host: workflow-engine
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        http2MaxRequests: 100
        maxRequestsPerConnection: 2
    loadBalancer:
      simple: LEAST_REQUEST
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
      minHealthPercent: 40

  subsets:
    - name: stable
      labels:
        version: stable
      trafficPolicy:
        connectionPool:
          tcp:
            maxConnections: 100

    - name: canary
      labels:
        version: canary
      trafficPolicy:
        connectionPool:
          tcp:
            maxConnections: 20
```

### Canary Deployment Automation

```bash
#!/bin/bash
# scripts/deploy-canary.sh

set -euo pipefail

SERVICE_NAME="${1}"
IMAGE_TAG="${2}"
NAMESPACE="platform-production"
ROLLOUT_TIMEOUT=3600

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

# Update rollout with new image
update_rollout() {
    log_info "Updating rollout $SERVICE_NAME with image $IMAGE_TAG"

    kubectl argo rollouts set image $SERVICE_NAME \
        $SERVICE_NAME=registry.platform.com/$SERVICE_NAME:$IMAGE_TAG \
        -n $NAMESPACE

    log_info "Rollout updated"
}

# Watch rollout progress
watch_rollout() {
    log_info "Watching rollout progress..."

    kubectl argo rollouts watch $SERVICE_NAME \
        -n $NAMESPACE \
        --timeout ${ROLLOUT_TIMEOUT}s

    if [ $? -eq 0 ]; then
        log_info "Rollout completed successfully"
        return 0
    else
        log_error "Rollout failed or timed out"
        return 1
    fi
}

# Get rollout status
get_status() {
    kubectl argo rollouts status $SERVICE_NAME \
        -n $NAMESPACE
}

# Promote rollout
promote() {
    log_info "Promoting rollout to full deployment..."

    kubectl argo rollouts promote $SERVICE_NAME \
        -n $NAMESPACE \
        --full

    log_info "Rollout promoted"
}

# Abort rollout
abort() {
    log_error "Aborting rollout..."

    kubectl argo rollouts abort $SERVICE_NAME \
        -n $NAMESPACE

    kubectl argo rollouts undo $SERVICE_NAME \
        -n $NAMESPACE

    log_error "Rollout aborted and rolled back"
}

# Main
main() {
    update_rollout

    if watch_rollout; then
        log_info "Canary deployment completed successfully"
        get_status
        exit 0
    else
        abort
        exit 1
    fi
}

main "$@"
```

### GitHub Actions Workflow for Canary

```yaml
# .github/workflows/deploy-canary.yml
name: Canary Deployment

on:
  push:
    branches:
      - main
    paths:
      - 'src/**'
      - 'composer.json'
      - 'Dockerfile'

jobs:
  build:
    name: Build and Push Image
    runs-on: ubuntu-latest
    outputs:
      image_tag: ${{ steps.meta.outputs.version }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Docker meta
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: registry.platform.com/workflow-engine
          tags: |
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy-canary:
    name: Deploy Canary
    needs: build
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup kubectl
        uses: azure/k8s-set-context@v3
        with:
          method: kubeconfig
          kubeconfig: ${{ secrets.KUBE_CONFIG }}

      - name: Install Argo Rollouts Plugin
        run: |
          curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
          chmod +x kubectl-argo-rollouts-linux-amd64
          sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts

      - name: Start Canary Rollout
        run: |
          kubectl argo rollouts set image workflow-engine \
            workflow-engine=registry.platform.com/workflow-engine:${{ needs.build.outputs.image_tag }} \
            -n platform-production

      - name: Wait for Initial Canary (10%)
        run: |
          kubectl argo rollouts watch workflow-engine \
            -n platform-production \
            --timeout 600s

      - name: Check Canary Metrics
        id: canary_check
        run: |
          # Query Prometheus for canary metrics
          ERROR_RATE=$(curl -s "http://prometheus.monitoring:9090/api/v1/query" \
            --data-urlencode 'query=rate(http_requests_total{job="workflow-engine",status=~"5.."}[5m])/rate(http_requests_total{job="workflow-engine"}[5m])' \
            | jq -r '.data.result[0].value[1]')

          if (( $(echo "$ERROR_RATE > 0.02" | bc -l) )); then
            echo "status=failed" >> $GITHUB_OUTPUT
            echo "error_rate=$ERROR_RATE" >> $GITHUB_OUTPUT
            exit 1
          fi

          echo "status=success" >> $GITHUB_OUTPUT

      - name: Promote to 50%
        if: steps.canary_check.outputs.status == 'success'
        run: |
          kubectl argo rollouts promote workflow-engine \
            -n platform-production

      - name: Wait for 50% Canary
        if: steps.canary_check.outputs.status == 'success'
        run: |
          kubectl argo rollouts watch workflow-engine \
            -n platform-production \
            --timeout 1200s

      - name: Final Promotion
        if: steps.canary_check.outputs.status == 'success'
        run: |
          kubectl argo rollouts promote workflow-engine \
            -n platform-production \
            --full

      - name: Rollback on Failure
        if: failure()
        run: |
          kubectl argo rollouts abort workflow-engine \
            -n platform-production
          kubectl argo rollouts undo workflow-engine \
            -n platform-production

      - name: Notify Result
        if: always()
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: |
            Canary Deployment ${{ job.status }}
            Image: ${{ needs.build.outputs.image_tag }}
            Error Rate: ${{ steps.canary_check.outputs.error_rate || 'N/A' }}
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### Advantages and Disadvantages

**Advantages**:
- Minimal blast radius for failures
- Real-world validation with production traffic
- Automated analysis and rollback
- Gradual confidence building
- Cost-effective (no 2x resources)

**Disadvantages**:
- Complex setup with Argo Rollouts
- Requires comprehensive metrics
- Longer deployment time
- Partial rollouts can be confusing for monitoring

## Rolling Updates

### Overview

Rolling updates gradually replace old pods with new ones, maintaining service availability throughout the deployment. This is the default Kubernetes deployment strategy.

### Configuration

```yaml
# rolling-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: workflow-engine
  namespace: platform-production
spec:
  replicas: 20
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 5          # Maximum number of pods above desired count
      maxUnavailable: 2    # Maximum number of pods unavailable during update

  minReadySeconds: 30      # Minimum time before pod is considered ready
  progressDeadlineSeconds: 600  # Timeout for deployment progress

  selector:
    matchLabels:
      app: workflow-engine

  template:
    metadata:
      labels:
        app: workflow-engine
        version: v1.25.0
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9091"
        prometheus.io/path: "/metrics"

    spec:
      # Graceful shutdown
      terminationGracePeriodSeconds: 60

      containers:
        - name: workflow-engine
          image: registry.platform.com/workflow-engine:v1.25.0
          imagePullPolicy: IfNotPresent

          ports:
            - name: http
              containerPort: 8080
            - name: grpc
              containerPort: 9090
            - name: metrics
              containerPort: 9091

          resources:
            requests:
              cpu: "1000m"
              memory: "2Gi"
            limits:
              cpu: "2000m"
              memory: "4Gi"

          # Startup probe for slow-starting containers
          startupProbe:
            httpGet:
              path: /health/startup
              port: 8080
            initialDelaySeconds: 0
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 60  # 5min max startup time

          # Liveness probe
          livenessProbe:
            httpGet:
              path: /health/live
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3

          # Readiness probe
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 3
            successThreshold: 1
            failureThreshold: 2

          # Graceful shutdown handling
          lifecycle:
            preStop:
              exec:
                command:
                  - /bin/sh
                  - -c
                  - |
                    # Stop accepting new requests
                    touch /tmp/shutdown

                    # Wait for active requests to complete
                    sleep 15

                    # Send SIGTERM to PHP-FPM
                    kill -SIGTERM 1

          env:
            - name: APP_ENV
              value: "production"
            - name: APP_DEBUG
              value: "false"
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: database-credentials
                  key: url
            - name: REDIS_URL
              valueFrom:
                secretKeyRef:
                  name: redis-credentials
                  key: url
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace

          volumeMounts:
            - name: config
              mountPath: /app/config/production
              readOnly: true
            - name: cache
              mountPath: /app/var/cache
            - name: tmp
              mountPath: /tmp

      volumes:
        - name: config
          configMap:
            name: workflow-engine-config
        - name: cache
          emptyDir:
            sizeLimit: 1Gi
        - name: tmp
          emptyDir:
            sizeLimit: 500Mi

      # Pod anti-affinity to spread across nodes
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app
                      operator: In
                      values:
                        - workflow-engine
                topologyKey: kubernetes.io/hostname
```

### Health Check Endpoints

```php
<?php
// src/Infrastructure/Http/Controller/HealthController.php

declare(strict_types=1);

namespace App\Infrastructure\Http\Controller;

use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;
use Doctrine\DBAL\Connection;
use Predis\Client as RedisClient;

final class HealthController
{
    public function __construct(
        private readonly Connection $database,
        private readonly RedisClient $redis,
    ) {}

    /**
     * Startup probe - checks if application has finished booting
     * Used by Kubernetes to know when container is ready to receive traffic
     */
    #[Route('/health/startup', name: 'health_startup', methods: ['GET'])]
    public function startup(): Response
    {
        // Check if critical boot operations are complete
        if (!file_exists('/tmp/app_booted')) {
            return new JsonResponse(
                ['status' => 'starting'],
                Response::HTTP_SERVICE_UNAVAILABLE
            );
        }

        return new JsonResponse(['status' => 'started']);
    }

    /**
     * Liveness probe - checks if application is alive and not deadlocked
     * Kubernetes will restart container if this fails
     */
    #[Route('/health/live', name: 'health_live', methods: ['GET'])]
    public function liveness(): Response
    {
        // Check for shutdown signal
        if (file_exists('/tmp/shutdown')) {
            return new JsonResponse(
                ['status' => 'shutting_down'],
                Response::HTTP_SERVICE_UNAVAILABLE
            );
        }

        // Basic health check - application is running
        return new JsonResponse([
            'status' => 'alive',
            'timestamp' => time(),
        ]);
    }

    /**
     * Readiness probe - checks if application is ready to serve traffic
     * Kubernetes will remove pod from service endpoints if this fails
     */
    #[Route('/health/ready', name: 'health_ready', methods: ['GET'])]
    public function readiness(): Response
    {
        $checks = [];
        $healthy = true;

        // Check database connection
        try {
            $this->database->executeQuery('SELECT 1');
            $checks['database'] = 'ok';
        } catch (\Exception $e) {
            $checks['database'] = 'failed: ' . $e->getMessage();
            $healthy = false;
        }

        // Check Redis connection
        try {
            $this->redis->ping();
            $checks['redis'] = 'ok';
        } catch (\Exception $e) {
            $checks['redis'] = 'failed: ' . $e->getMessage();
            $healthy = false;
        }

        // Check for shutdown signal
        if (file_exists('/tmp/shutdown')) {
            $checks['shutdown'] = 'in_progress';
            $healthy = false;
        }

        $status = $healthy ? 'ready' : 'not_ready';
        $httpStatus = $healthy ? Response::HTTP_OK : Response::HTTP_SERVICE_UNAVAILABLE;

        return new JsonResponse([
            'status' => $status,
            'checks' => $checks,
            'timestamp' => time(),
        ], $httpStatus);
    }

    /**
     * Deep health check for monitoring (not used by Kubernetes probes)
     */
    #[Route('/health', name: 'health', methods: ['GET'])]
    public function health(): Response
    {
        $checks = [
            'database' => $this->checkDatabase(),
            'redis' => $this->checkRedis(),
            'disk_space' => $this->checkDiskSpace(),
            'memory' => $this->checkMemory(),
        ];

        $healthy = !in_array('unhealthy', array_column($checks, 'status'), true);

        return new JsonResponse([
            'status' => $healthy ? 'healthy' : 'unhealthy',
            'checks' => $checks,
            'timestamp' => time(),
            'version' => $_ENV['APP_VERSION'] ?? 'unknown',
        ], $healthy ? Response::HTTP_OK : Response::HTTP_SERVICE_UNAVAILABLE);
    }

    private function checkDatabase(): array
    {
        try {
            $start = microtime(true);
            $this->database->executeQuery('SELECT 1');
            $duration = (microtime(true) - $start) * 1000;

            return [
                'status' => 'healthy',
                'response_time_ms' => round($duration, 2),
            ];
        } catch (\Exception $e) {
            return [
                'status' => 'unhealthy',
                'error' => $e->getMessage(),
            ];
        }
    }

    private function checkRedis(): array
    {
        try {
            $start = microtime(true);
            $this->redis->ping();
            $duration = (microtime(true) - $start) * 1000;

            return [
                'status' => 'healthy',
                'response_time_ms' => round($duration, 2),
            ];
        } catch (\Exception $e) {
            return [
                'status' => 'unhealthy',
                'error' => $e->getMessage(),
            ];
        }
    }

    private function checkDiskSpace(): array
    {
        $free = disk_free_space('/');
        $total = disk_total_space('/');
        $used = $total - $free;
        $percentUsed = ($used / $total) * 100;

        return [
            'status' => $percentUsed < 90 ? 'healthy' : 'unhealthy',
            'used_percent' => round($percentUsed, 2),
            'free_bytes' => $free,
            'total_bytes' => $total,
        ];
    }

    private function checkMemory(): array
    {
        $memoryLimit = ini_get('memory_limit');
        $memoryUsage = memory_get_usage(true);
        $memoryPeak = memory_get_peak_usage(true);

        // Convert memory_limit to bytes
        $limit = $this->convertToBytes($memoryLimit);
        $percentUsed = ($memoryUsage / $limit) * 100;

        return [
            'status' => $percentUsed < 90 ? 'healthy' : 'unhealthy',
            'used_percent' => round($percentUsed, 2),
            'used_bytes' => $memoryUsage,
            'peak_bytes' => $memoryPeak,
            'limit_bytes' => $limit,
        ];
    }

    private function convertToBytes(string $value): int
    {
        $unit = strtolower(substr($value, -1));
        $value = (int) $value;

        return match ($unit) {
            'g' => $value * 1024 * 1024 * 1024,
            'm' => $value * 1024 * 1024,
            'k' => $value * 1024,
            default => $value,
        };
    }
}
```

### Rolling Update Script

```bash
#!/bin/bash
# scripts/rolling-update.sh

set -euo pipefail

DEPLOYMENT="${1}"
IMAGE_TAG="${2}"
NAMESPACE="${3:-platform-production}"
TIMEOUT=600

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

# Perform rolling update
perform_update() {
    log_info "Starting rolling update for $DEPLOYMENT"
    log_info "New image tag: $IMAGE_TAG"

    # Update deployment
    kubectl set image deployment/$DEPLOYMENT \
        $DEPLOYMENT=registry.platform.com/$DEPLOYMENT:$IMAGE_TAG \
        -n $NAMESPACE \
        --record

    log_info "Deployment updated, waiting for rollout..."
}

# Monitor rollout
monitor_rollout() {
    local start_time=$(date +%s)

    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        if [ $elapsed -gt $TIMEOUT ]; then
            log_error "Rollout timeout after ${TIMEOUT}s"
            return 1
        fi

        # Check rollout status
        if kubectl rollout status deployment/$DEPLOYMENT \
            -n $NAMESPACE \
            --timeout=10s 2>/dev/null; then
            log_info "Rollout completed successfully in ${elapsed}s"
            return 0
        fi

        # Check for failed pods
        local failed_pods=$(kubectl get pods \
            -n $NAMESPACE \
            -l app=$DEPLOYMENT \
            --field-selector=status.phase=Failed \
            --no-headers \
            | wc -l)

        if [ "$failed_pods" -gt 0 ]; then
            log_error "Found $failed_pods failed pods"
            kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT
            return 1
        fi

        # Show progress
        local ready=$(kubectl get deployment $DEPLOYMENT \
            -n $NAMESPACE \
            -o jsonpath='{.status.readyReplicas}')
        local desired=$(kubectl get deployment $DEPLOYMENT \
            -n $NAMESPACE \
            -o jsonpath='{.spec.replicas}')

        log_info "Progress: $ready/$desired pods ready (${elapsed}s elapsed)"

        sleep 5
    done
}

# Validate deployment
validate_deployment() {
    log_info "Validating deployment..."

    # Check all pods are ready
    local ready=$(kubectl get deployment $DEPLOYMENT \
        -n $NAMESPACE \
        -o jsonpath='{.status.readyReplicas}')
    local desired=$(kubectl get deployment $DEPLOYMENT \
        -n $NAMESPACE \
        -o jsonpath='{.spec.replicas}')

    if [ "$ready" != "$desired" ]; then
        log_error "Not all pods are ready: $ready/$desired"
        return 1
    fi

    # Check image version
    local current_image=$(kubectl get deployment $DEPLOYMENT \
        -n $NAMESPACE \
        -o jsonpath='{.spec.template.spec.containers[0].image}')

    if [[ ! "$current_image" =~ "$IMAGE_TAG" ]]; then
        log_error "Image version mismatch. Expected: $IMAGE_TAG, Got: $current_image"
        return 1
    fi

    log_info "Deployment validated successfully"
    return 0
}

# Rollback deployment
rollback_deployment() {
    log_error "Rolling back deployment..."

    kubectl rollout undo deployment/$DEPLOYMENT \
        -n $NAMESPACE

    kubectl rollout status deployment/$DEPLOYMENT \
        -n $NAMESPACE \
        --timeout=${TIMEOUT}s

    log_info "Rollback completed"
}

# Main execution
main() {
    perform_update

    if monitor_rollout && validate_deployment; then
        log_info "Rolling update completed successfully"

        # Show deployment info
        kubectl get deployment $DEPLOYMENT -n $NAMESPACE
        kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT

        exit 0
    else
        log_error "Rolling update failed"
        rollback_deployment
        exit 1
    fi
}

main "$@"
```

### Advantages and Disadvantages

**Advantages**:
- Simple to understand and implement
- Built into Kubernetes
- No additional tools required
- Predictable resource usage
- Automatic rollback on failure

**Disadvantages**:
- Both versions running simultaneously during rollout
- No fine-grained traffic control
- Harder to validate before full rollout
- Can't easily target specific users

## A/B Testing Deployments

### Overview

A/B testing deployments route users to different versions based on specific criteria (e.g., user segment, geographic location, device type) to compare performance and user experience.

### Architecture

```yaml
ab_testing:
  variants:
    - name: "control"
      version: "v1.24.0"
      traffic_percentage: 50
      targeting:
        user_segments:
          - free_tier
          - basic_tier
        regions:
          - us-east
          - us-west

    - name: "treatment"
      version: "v1.25.0"
      traffic_percentage: 50
      targeting:
        user_segments:
          - free_tier
          - basic_tier
        regions:
          - us-east
          - us-west

  metrics:
    primary:
      - name: "conversion_rate"
        goal: maximize
        threshold: 0.05  # 5% improvement
      - name: "task_completion_time"
        goal: minimize
        threshold: -0.10  # 10% reduction

    secondary:
      - name: "error_rate"
        goal: minimize
        guardrail: 0.02  # Max 2% error rate
      - name: "user_satisfaction"
        goal: maximize

  duration: 14d
  confidence_level: 0.95
```

### Implementation with Istio

```yaml
# ab-testing-configuration.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: workflow-engine-ab-test
  namespace: platform-production
spec:
  hosts:
    - workflow-engine
    - api.platform.com
  gateways:
    - platform-gateway
    - mesh

  http:
    # Route based on user segment header
    - name: "premium-users"
      match:
        - headers:
            x-user-segment:
              exact: "premium"
      route:
        - destination:
            host: workflow-engine
            subset: v1-25-0
          weight: 100

    # A/B test for free and basic users
    - name: "ab-test-cohort"
      match:
        - headers:
            x-user-segment:
              regex: "free|basic"
      route:
        # Control group - v1.24.0
        - destination:
            host: workflow-engine
            subset: v1-24-0
          weight: 50
          headers:
            response:
              set:
                x-variant: "control"
                x-version: "v1.24.0"

        # Treatment group - v1.25.0
        - destination:
            host: workflow-engine
            subset: v1-25-0
          weight: 50
          headers:
            response:
              set:
                x-variant: "treatment"
                x-version: "v1.25.0"

    # Default route
    - name: "default"
      route:
        - destination:
            host: workflow-engine
            subset: v1-24-0
          weight: 100

---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: workflow-engine-ab-test
  namespace: platform-production
spec:
  host: workflow-engine

  subsets:
    - name: v1-24-0
      labels:
        version: v1.24.0

    - name: v1-25-0
      labels:
        version: v1.25.0
```

### User Segmentation Middleware

```php
<?php
// src/Infrastructure/Http/Middleware/UserSegmentMiddleware.php

declare(strict_types=1);

namespace App\Infrastructure\Http\Middleware;

use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Event\RequestEvent;
use App\Domain\User\Repository\UserRepositoryInterface;

final class UserSegmentMiddleware
{
    public function __construct(
        private readonly UserRepositoryInterface $userRepository,
    ) {}

    public function onKernelRequest(RequestEvent $event): void
    {
        $request = $event->getRequest();

        // Skip if header already set
        if ($request->headers->has('x-user-segment')) {
            return;
        }

        // Extract user ID from JWT or session
        $userId = $this->extractUserId($request);

        if ($userId === null) {
            $request->headers->set('x-user-segment', 'anonymous');
            return;
        }

        // Load user and determine segment
        $user = $this->userRepository->findById($userId);

        if ($user === null) {
            $request->headers->set('x-user-segment', 'anonymous');
            return;
        }

        // Determine segment based on subscription
        $segment = match ($user->getSubscriptionTier()) {
            'free' => 'free',
            'basic' => 'basic',
            'premium' => 'premium',
            'enterprise' => 'enterprise',
            default => 'free',
        };

        $request->headers->set('x-user-segment', $segment);

        // Add region for geo-based routing
        $region = $this->determineRegion($request);
        $request->headers->set('x-user-region', $region);

        // Add consistent user hash for sticky routing
        $userHash = $this->getUserHash($userId);
        $request->headers->set('x-user-hash', $userHash);
    }

    private function extractUserId(Request $request): ?string
    {
        // Extract from JWT Authorization header
        $authHeader = $request->headers->get('Authorization');

        if ($authHeader === null || !str_starts_with($authHeader, 'Bearer ')) {
            return null;
        }

        $token = substr($authHeader, 7);

        // Parse JWT (simplified - use proper JWT library)
        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            return null;
        }

        $payload = json_decode(base64_decode($parts[1]), true);

        return $payload['sub'] ?? null;
    }

    private function determineRegion(Request $request): string
    {
        // Use CloudFront or similar header
        $cfRegion = $request->headers->get('CloudFront-Viewer-Country');

        return match ($cfRegion) {
            'US', 'CA', 'MX' => 'us',
            'GB', 'FR', 'DE', 'IT', 'ES' => 'eu',
            'JP', 'KR', 'SG', 'AU' => 'apac',
            default => 'us',
        };
    }

    private function getUserHash(string $userId): string
    {
        // Create consistent hash for user (0-99)
        $hash = crc32($userId) % 100;
        return (string) $hash;
    }
}
```

### A/B Test Metrics Collection

```php
<?php
// src/Infrastructure/Analytics/ABTestMetricsCollector.php

declare(strict_types=1);

namespace App\Infrastructure\Analytics;

use Prometheus\CollectorRegistry;
use Prometheus\Counter;
use Prometheus\Histogram;

final class ABTestMetricsCollector
{
    private Counter $requestCounter;
    private Counter $conversionCounter;
    private Histogram $taskCompletionTime;
    private Counter $errorCounter;

    public function __construct(
        private readonly CollectorRegistry $registry,
    ) {
        $this->requestCounter = $registry->getOrRegisterCounter(
            'ab_test',
            'requests_total',
            'Total requests per variant',
            ['variant', 'endpoint']
        );

        $this->conversionCounter = $registry->getOrRegisterCounter(
            'ab_test',
            'conversions_total',
            'Total conversions per variant',
            ['variant', 'conversion_type']
        );

        $this->taskCompletionTime = $registry->getOrRegisterHistogram(
            'ab_test',
            'task_completion_seconds',
            'Task completion time per variant',
            ['variant', 'task_type'],
            [0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0]
        );

        $this->errorCounter = $registry->getOrRegisterCounter(
            'ab_test',
            'errors_total',
            'Total errors per variant',
            ['variant', 'error_type']
        );
    }

    public function recordRequest(string $variant, string $endpoint): void
    {
        $this->requestCounter->inc(['variant' => $variant, 'endpoint' => $endpoint]);
    }

    public function recordConversion(string $variant, string $conversionType): void
    {
        $this->conversionCounter->inc([
            'variant' => $variant,
            'conversion_type' => $conversionType
        ]);
    }

    public function recordTaskCompletion(string $variant, string $taskType, float $duration): void
    {
        $this->taskCompletionTime->observe(
            $duration,
            ['variant' => $variant, 'task_type' => $taskType]
        );
    }

    public function recordError(string $variant, string $errorType): void
    {
        $this->errorCounter->inc(['variant' => $variant, 'error_type' => $errorType]);
    }
}
```

### A/B Test Analysis Script

```python
#!/usr/bin/env python3
# scripts/analyze-ab-test.py

import argparse
import requests
from datetime import datetime, timedelta
from scipy import stats
import numpy as np

class ABTestAnalyzer:
    def __init__(self, prometheus_url: str):
        self.prometheus_url = prometheus_url

    def query_prometheus(self, query: str, time_range: str = '7d') -> dict:
        """Query Prometheus for metrics"""
        response = requests.get(
            f"{self.prometheus_url}/api/v1/query",
            params={'query': query}
        )
        return response.json()

    def get_conversion_rate(self, variant: str) -> float:
        """Calculate conversion rate for variant"""
        conversions_query = f'sum(ab_test_conversions_total{{variant="{variant}"}})'
        requests_query = f'sum(ab_test_requests_total{{variant="{variant}"}})'

        conversions = self.query_prometheus(conversions_query)
        requests = self.query_prometheus(requests_query)

        conversions_value = float(conversions['data']['result'][0]['value'][1])
        requests_value = float(requests['data']['result'][0]['value'][1])

        return conversions_value / requests_value if requests_value > 0 else 0

    def get_task_completion_time(self, variant: str) -> tuple[float, float]:
        """Get mean and std of task completion time"""
        query = f'''
        histogram_quantile(0.5,
          sum(rate(ab_test_task_completion_seconds_bucket{{variant="{variant}"}}[7d]))
          by (le)
        )
        '''

        result = self.query_prometheus(query)
        mean = float(result['data']['result'][0]['value'][1])

        # For simplicity, estimate std from P95-P50
        p95_query = query.replace('0.5', '0.95')
        p95_result = self.query_prometheus(p95_query)
        p95 = float(p95_result['data']['result'][0]['value'][1])

        std = (p95 - mean) / 1.645  # Approximate std from P95

        return mean, std

    def get_error_rate(self, variant: str) -> float:
        """Calculate error rate for variant"""
        errors_query = f'sum(ab_test_errors_total{{variant="{variant}"}})'
        requests_query = f'sum(ab_test_requests_total{{variant="{variant}"}})'

        errors = self.query_prometheus(errors_query)
        requests = self.query_prometheus(requests_query)

        errors_value = float(errors['data']['result'][0]['value'][1])
        requests_value = float(requests['data']['result'][0]['value'][1])

        return errors_value / requests_value if requests_value > 0 else 0

    def calculate_statistical_significance(
        self,
        control_rate: float,
        treatment_rate: float,
        control_n: int,
        treatment_n: int
    ) -> tuple[float, float]:
        """Calculate p-value and confidence interval"""

        # Two-proportion z-test
        pooled_rate = (control_rate * control_n + treatment_rate * treatment_n) / (control_n + treatment_n)

        se = np.sqrt(pooled_rate * (1 - pooled_rate) * (1/control_n + 1/treatment_n))
        z_score = (treatment_rate - control_rate) / se

        p_value = 2 * (1 - stats.norm.cdf(abs(z_score)))

        # Confidence interval for difference
        ci_se = np.sqrt(
            control_rate * (1 - control_rate) / control_n +
            treatment_rate * (1 - treatment_rate) / treatment_n
        )

        ci_lower = (treatment_rate - control_rate) - 1.96 * ci_se
        ci_upper = (treatment_rate - control_rate) + 1.96 * ci_se

        return p_value, (ci_lower, ci_upper)

    def analyze(self) -> dict:
        """Perform complete A/B test analysis"""
        print("Analyzing A/B test results...")

        # Get metrics for both variants
        control_conversion = self.get_conversion_rate('control')
        treatment_conversion = self.get_conversion_rate('treatment')

        control_completion, control_completion_std = self.get_task_completion_time('control')
        treatment_completion, treatment_completion_std = self.get_task_completion_time('treatment')

        control_errors = self.get_error_rate('control')
        treatment_errors = self.get_error_rate('treatment')

        # Get sample sizes
        control_requests = int(self.query_prometheus('sum(ab_test_requests_total{variant="control"})')['data']['result'][0]['value'][1])
        treatment_requests = int(self.query_prometheus('sum(ab_test_requests_total{variant="treatment"})')['data']['result'][0]['value'][1])

        # Statistical significance for conversion rate
        conv_p_value, conv_ci = self.calculate_statistical_significance(
            control_conversion,
            treatment_conversion,
            control_requests,
            treatment_requests
        )

        # Calculate relative improvement
        conv_improvement = ((treatment_conversion - control_conversion) / control_conversion) * 100
        time_improvement = ((control_completion - treatment_completion) / control_completion) * 100

        results = {
            'conversion_rate': {
                'control': control_conversion,
                'treatment': treatment_conversion,
                'relative_improvement': conv_improvement,
                'p_value': conv_p_value,
                'confidence_interval': conv_ci,
                'significant': conv_p_value < 0.05
            },
            'task_completion_time': {
                'control': {
                    'mean': control_completion,
                    'std': control_completion_std
                },
                'treatment': {
                    'mean': treatment_completion,
                    'std': treatment_completion_std
                },
                'relative_improvement': time_improvement
            },
            'error_rate': {
                'control': control_errors,
                'treatment': treatment_errors,
                'relative_change': ((treatment_errors - control_errors) / control_errors) * 100 if control_errors > 0 else 0
            },
            'sample_size': {
                'control': control_requests,
                'treatment': treatment_requests
            }
        }

        return results

    def print_report(self, results: dict) -> None:
        """Print analysis report"""
        print("\n" + "="*80)
        print("A/B TEST ANALYSIS REPORT")
        print("="*80)

        print("\n1. CONVERSION RATE")
        print(f"   Control:    {results['conversion_rate']['control']:.4f}")
        print(f"   Treatment:  {results['conversion_rate']['treatment']:.4f}")
        print(f"   Improvement: {results['conversion_rate']['relative_improvement']:+.2f}%")
        print(f"   P-value:    {results['conversion_rate']['p_value']:.4f}")
        print(f"   Significant: {'YES' if results['conversion_rate']['significant'] else 'NO'}")

        print("\n2. TASK COMPLETION TIME")
        print(f"   Control:    {results['task_completion_time']['control']['mean']:.2f}s (± {results['task_completion_time']['control']['std']:.2f}s)")
        print(f"   Treatment:  {results['task_completion_time']['treatment']['mean']:.2f}s (± {results['task_completion_time']['treatment']['std']:.2f}s)")
        print(f"   Improvement: {results['task_completion_time']['relative_improvement']:+.2f}%")

        print("\n3. ERROR RATE")
        print(f"   Control:    {results['error_rate']['control']:.4f}")
        print(f"   Treatment:  {results['error_rate']['treatment']:.4f}")
        print(f"   Change:     {results['error_rate']['relative_change']:+.2f}%")

        print("\n4. SAMPLE SIZE")
        print(f"   Control:    {results['sample_size']['control']:,} requests")
        print(f"   Treatment:  {results['sample_size']['treatment']:,} requests")

        print("\n5. RECOMMENDATION")
        if results['conversion_rate']['significant'] and results['conversion_rate']['relative_improvement'] > 5:
            print("   ✓ DEPLOY TREATMENT - Statistically significant improvement")
        elif results['conversion_rate']['significant'] and results['conversion_rate']['relative_improvement'] < -5:
            print("   ✗ REJECT TREATMENT - Statistically significant decline")
        else:
            print("   ⚠ CONTINUE TEST - No significant difference yet")

        print("\n" + "="*80)

def main():
    parser = argparse.ArgumentParser(description='Analyze A/B test results')
    parser.add_argument('--prometheus-url', required=True, help='Prometheus server URL')

    args = parser.parse_args()

    analyzer = ABTestAnalyzer(args.prometheus_url)
    results = analyzer.analyze()
    analyzer.print_report(results)

if __name__ == '__main__':
    main()
```

## Database Migration Strategies

### Overview

Database migrations during deployments require careful planning to maintain data integrity and zero downtime.

### Migration Patterns

```yaml
migration_patterns:
  expand_contract:
    description: "Add new schema, migrate data, remove old schema"
    phases:
      - expand: "Add new columns/tables alongside old ones"
      - migrate: "Copy/transform data from old to new schema"
      - contract: "Remove old columns/tables"
    suitable_for: "Schema changes, column renames"

  backward_compatible:
    description: "Make all changes backward compatible"
    phases:
      - deploy_code: "Deploy code that works with both schemas"
      - migrate_schema: "Apply schema changes"
    suitable_for: "Adding nullable columns, new tables"

  maintenance_window:
    description: "Brief downtime for complex migrations"
    phases:
      - stop_traffic: "Stop accepting new requests"
      - migrate: "Apply schema changes"
      - restart: "Deploy new version and resume traffic"
    suitable_for: "Major schema refactoring, data type changes"
```

### Expand-Contract Pattern Example

```php
<?php
// migrations/Version20250107120000.php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Expand phase: Add new column alongside old one
 * This migration is safe to run while old code is still deployed
 */
final class Version20250107120000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Expand: Add user_email_normalized column for case-insensitive lookup';
    }

    public function up(Schema $schema): void
    {
        // Add new normalized email column (nullable initially)
        $this->addSql('
            ALTER TABLE users
            ADD COLUMN user_email_normalized VARCHAR(255) NULL
        ');

        // Create index for new column
        $this->addSql('
            CREATE INDEX idx_users_email_normalized
            ON users(user_email_normalized)
        ');

        // Populate new column from existing data
        $this->addSql('
            UPDATE users
            SET user_email_normalized = LOWER(user_email)
            WHERE user_email_normalized IS NULL
        ');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE users DROP COLUMN user_email_normalized');
    }
}
```

```php
<?php
// migrations/Version20250107130000.php

/**
 * Migrate phase: Update application code to use new column
 * Deploy application version that reads/writes to user_email_normalized
 */

// This is not a migration file - deploy new application code here
```

```php
<?php
// migrations/Version20250107140000.php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Contract phase: Remove old column
 * Only run after new code is fully deployed and stable
 */
final class Version20250107140000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Contract: Make user_email_normalized NOT NULL and remove old constraints';
    }

    public function up(Schema $schema): void
    {
        // Make new column NOT NULL
        $this->addSql('
            ALTER TABLE users
            ALTER COLUMN user_email_normalized SET NOT NULL
        ');

        // Note: We keep user_email for now but could remove it in a future migration
        // after confirming everything works with the new column
    }

    public function down(Schema $schema): void
    {
        $this->addSql('
            ALTER TABLE users
            ALTER COLUMN user_email_normalized DROP NOT NULL
        ');
    }
}
```

### Zero-Downtime Migration Script

```bash
#!/bin/bash
# scripts/migrate-database-zero-downtime.sh

set -euo pipefail

MIGRATION_VERSION="${1}"
PHASE="${2}"  # expand, migrate, or contract
DATABASE_URL="${DATABASE_URL}"

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

# Run migration with rollback on failure
run_migration() {
    local version=$1

    log_info "Running migration $version (phase: $PHASE)"

    # Start transaction
    vendor/bin/doctrine-migrations migrate \
        --no-interaction \
        --query-time \
        "$version"

    if [ $? -eq 0 ]; then
        log_info "Migration completed successfully"
        return 0
    else
        log_error "Migration failed"
        return 1
    fi
}

# Verify data integrity
verify_data() {
    log_info "Verifying data integrity..."

    # Run application-specific integrity checks
    php bin/console app:verify-data-integrity

    if [ $? -eq 0 ]; then
        log_info "Data integrity verified"
        return 0
    else
        log_error "Data integrity check failed"
        return 1
    fi
}

# Monitor database load
monitor_load() {
    log_info "Monitoring database load..."

    # Check active connections
    local connections=$(psql "$DATABASE_URL" -t -c "
        SELECT count(*)
        FROM pg_stat_activity
        WHERE state = 'active'
    ")

    log_info "Active connections: $connections"

    # Check locks
    local locks=$(psql "$DATABASE_URL" -t -c "
        SELECT count(*)
        FROM pg_locks
        WHERE granted = false
    ")

    if [ "$locks" -gt 0 ]; then
        log_error "Found $locks waiting locks"
        return 1
    fi

    return 0
}

# Main execution
main() {
    case "$PHASE" in
        expand)
            log_info "Executing EXPAND phase..."
            run_migration "$MIGRATION_VERSION"
            verify_data
            ;;

        migrate)
            log_info "Executing MIGRATE phase (data copy)..."
            # This phase typically handled by application code
            log_info "Deploy application with dual-write logic"
            ;;

        contract)
            log_info "Executing CONTRACT phase..."
            log_info "Ensure new application version is fully deployed"
            read -p "Continue with CONTRACT phase? (yes/no): " confirm

            if [ "$confirm" != "yes" ]; then
                log_error "CONTRACT phase aborted"
                exit 1
            fi

            run_migration "$MIGRATION_VERSION"
            verify_data
            ;;

        *)
            log_error "Invalid phase: $PHASE"
            echo "Usage: $0 <migration_version> <expand|migrate|contract>"
            exit 1
            ;;
    esac

    monitor_load
}

main "$@"
```

## Zero-Downtime Deployment

### Complete Zero-Downtime Checklist

```yaml
zero_downtime_requirements:
  infrastructure:
    - Load balancer with health checks
    - Multiple replicas (minimum 3)
    - Pod disruption budgets
    - Resource quotas and limits
    - Horizontal pod autoscaling

  application:
    - Graceful shutdown handling
    - Health check endpoints (startup, liveness, readiness)
    - Connection draining
    - Idempotent operations
    - Database connection pooling

  deployment:
    - Rolling update strategy
    - Progressive traffic shifting
    - Automated validation
    - Instant rollback capability
    - Database backward compatibility

  monitoring:
    - Real-time error rate tracking
    - Latency monitoring (P50, P95, P99)
    - Success rate tracking
    - Resource utilization alerts
    - Deployment event correlation
```

### Pod Disruption Budget

```yaml
# pod-disruption-budget.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: workflow-engine-pdb
  namespace: platform-production
spec:
  minAvailable: 80%
  selector:
    matchLabels:
      app: workflow-engine

  # Alternative: maxUnavailable: 20%

  unhealthyPodEvictionPolicy: AlwaysAllow
```

### Graceful Shutdown Implementation

```php
<?php
// src/Kernel.php

declare(strict_types=1);

namespace App;

use Symfony\Bundle\FrameworkBundle\Kernel\MicroKernelTrait;
use Symfony\Component\HttpKernel\Kernel as BaseKernel;

class Kernel extends BaseKernel
{
    use MicroKernelTrait;

    private bool $shuttingDown = false;

    public function boot(): void
    {
        parent::boot();

        // Register shutdown handler
        $this->registerShutdownHandler();
    }

    private function registerShutdownHandler(): void
    {
        // Handle SIGTERM gracefully
        if (extension_loaded('pcntl')) {
            pcntl_signal(SIGTERM, function () {
                $this->initiateGracefulShutdown();
            });

            pcntl_signal(SIGINT, function () {
                $this->initiateGracefulShutdown();
            });
        }

        // Also register PHP shutdown function
        register_shutdown_function(function () {
            if ($this->shuttingDown) {
                $this->completeShutdown();
            }
        });
    }

    private function initiateGracefulShutdown(): void
    {
        if ($this->shuttingDown) {
            return;  // Already shutting down
        }

        $this->shuttingDown = true;

        // Create shutdown marker for health checks
        touch('/tmp/shutdown');

        // Log shutdown initiation
        if ($this->container->has('logger')) {
            $this->container->get('logger')->info('Graceful shutdown initiated');
        }

        // Wait for active requests to complete (max 30 seconds)
        $maxWait = 30;
        $waited = 0;

        while ($this->hasActiveRequests() && $waited < $maxWait) {
            sleep(1);
            $waited++;

            if ($waited % 5 === 0) {
                $activeCount = $this->getActiveRequestCount();
                $this->container->get('logger')->info(
                    "Waiting for active requests to complete",
                    ['active_requests' => $activeCount, 'waited_seconds' => $waited]
                );
            }
        }

        // Close connections
        $this->closeConnections();
    }

    private function hasActiveRequests(): bool
    {
        // Check if there are active requests
        // Implementation depends on your application architecture
        // Could check message queue consumers, async jobs, etc.

        return false;  // Simplified
    }

    private function getActiveRequestCount(): int
    {
        // Return count of active requests
        return 0;  // Simplified
    }

    private function closeConnections(): void
    {
        // Close database connections
        if ($this->container->has('doctrine')) {
            $doctrine = $this->container->get('doctrine');
            $connections = $doctrine->getConnections();

            foreach ($connections as $connection) {
                $connection->close();
            }
        }

        // Close Redis connections
        if ($this->container->has('redis')) {
            $this->container->get('redis')->disconnect();
        }

        // Close message queue connections
        if ($this->container->has('messenger.transport.async')) {
            // Close RabbitMQ connection
        }
    }

    private function completeShutdown(): void
    {
        if ($this->container->has('logger')) {
            $this->container->get('logger')->info('Graceful shutdown completed');
        }

        // Flush any pending logs
        if ($this->container->has('monolog.handler.main')) {
            $this->container->get('monolog.handler.main')->close();
        }
    }

    public function isShuttingDown(): bool
    {
        return $this->shuttingDown;
    }
}
```

## Feature Flags Integration

### Feature Flag Architecture

```yaml
feature_flags:
  provider: "LaunchDarkly"  # or custom solution

  evaluation:
    method: "server_side"
    caching: true
    cache_ttl: 60s

  targeting:
    user_attributes:
      - user_id
      - email
      - subscription_tier
      - region
      - signup_date

    custom_attributes:
      - organization_id
      - feature_access_level
      - beta_tester

  rollout_strategies:
    - percentage_based
    - user_targeting
    - schedule_based
    - prerequisite_based
```

### Feature Flag Implementation

```php
<?php
// src/Infrastructure/FeatureFlag/FeatureFlagService.php

declare(strict_types=1);

namespace App\Infrastructure\FeatureFlag;

use LaunchDarkly\LDClient;
use LaunchDarkly\LDUser;
use Psr\Log\LoggerInterface;

final class FeatureFlagService
{
    public function __construct(
        private readonly LDClient $client,
        private readonly LoggerInterface $logger,
    ) {}

    public function isEnabled(string $flagKey, ?string $userId = null, array $context = []): bool
    {
        try {
            $user = $this->buildUser($userId, $context);
            $enabled = $this->client->variation($flagKey, $user, false);

            $this->logger->debug('Feature flag evaluated', [
                'flag' => $flagKey,
                'user_id' => $userId,
                'enabled' => $enabled,
            ]);

            return $enabled;
        } catch (\Exception $e) {
            $this->logger->error('Feature flag evaluation failed', [
                'flag' => $flagKey,
                'error' => $e->getMessage(),
            ]);

            // Fail closed - disable feature on error
            return false;
        }
    }

    public function getVariation(string $flagKey, ?string $userId = null, array $context = [], mixed $default = null): mixed
    {
        try {
            $user = $this->buildUser($userId, $context);
            $variation = $this->client->variation($flagKey, $user, $default);

            $this->logger->debug('Feature flag variation evaluated', [
                'flag' => $flagKey,
                'user_id' => $userId,
                'variation' => $variation,
            ]);

            return $variation;
        } catch (\Exception $e) {
            $this->logger->error('Feature flag variation evaluation failed', [
                'flag' => $flagKey,
                'error' => $e->getMessage(),
            ]);

            return $default;
        }
    }

    public function trackEvent(string $eventKey, ?string $userId = null, array $context = [], array $data = []): void
    {
        try {
            $user = $this->buildUser($userId, $context);
            $this->client->track($eventKey, $user, $data);
        } catch (\Exception $e) {
            $this->logger->error('Feature flag event tracking failed', [
                'event' => $eventKey,
                'error' => $e->getMessage(),
            ]);
        }
    }

    private function buildUser(?string $userId, array $context): LDUser
    {
        $userBuilder = (new LDUser($userId ?? 'anonymous'));

        if (isset($context['email'])) {
            $userBuilder = $userBuilder->email($context['email']);
        }

        if (isset($context['name'])) {
            $userBuilder = $userBuilder->name($context['name']);
        }

        // Custom attributes
        $customAttributes = [
            'subscription_tier' => $context['subscription_tier'] ?? 'free',
            'region' => $context['region'] ?? 'unknown',
            'organization_id' => $context['organization_id'] ?? null,
            'beta_tester' => $context['beta_tester'] ?? false,
        ];

        foreach ($customAttributes as $key => $value) {
            if ($value !== null) {
                $userBuilder = $userBuilder->custom($key, $value);
            }
        }

        return $userBuilder;
    }
}
```

### Feature Flag Usage Example

```php
<?php
// src/Application/Workflow/UseCase/ExecuteWorkflowUseCase.php

declare(strict_types=1);

namespace App\Application\Workflow\UseCase;

use App\Domain\Workflow\WorkflowId;
use App\Infrastructure\FeatureFlag\FeatureFlagService;

final class ExecuteWorkflowUseCase
{
    public function __construct(
        private readonly FeatureFlagService $featureFlags,
        private readonly WorkflowExecutorInterface $executor,
        private readonly OptimizedWorkflowExecutorInterface $optimizedExecutor,
    ) {}

    public function execute(WorkflowId $workflowId, string $userId): void
    {
        // Check feature flag for new optimized executor
        $useOptimizedExecutor = $this->featureFlags->isEnabled(
            'optimized-workflow-executor',
            $userId,
            [
                'subscription_tier' => $this->getUserSubscriptionTier($userId),
                'region' => $this->getUserRegion($userId),
            ]
        );

        if ($useOptimizedExecutor) {
            // Track conversion for A/B test
            $this->featureFlags->trackEvent('workflow-executed', $userId, [], [
                'executor_version' => 'optimized',
                'workflow_id' => $workflowId->toString(),
            ]);

            $this->optimizedExecutor->execute($workflowId);
        } else {
            $this->featureFlags->trackEvent('workflow-executed', $userId, [], [
                'executor_version' => 'standard',
                'workflow_id' => $workflowId->toString(),
            ]);

            $this->executor->execute($workflowId);
        }
    }
}
```

## Deployment Decision Matrix

### Decision Tree

```
┌─────────────────────────────────────────┐
│   What type of change are you making?  │
└─────────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
   ┌────▼─────┐          ┌─────▼────┐
   │ Critical │          │   Minor  │
   │  Change  │          │   Change │
   └────┬─────┘          └─────┬────┘
        │                      │
        │                      │
    ┌───▼────┐            ┌────▼───┐
    │ Blue-  │            │Rolling │
    │ Green  │            │Update  │
    └────────┘            └────────┘


┌──────────────────────────────────────────┐
│ Do you need to validate with real users?│
└──────────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
   ┌────▼─────┐          ┌─────▼────┐
   │   Yes    │          │    No    │
   └────┬─────┘          └─────┬────┘
        │                      │
    ┌───▼────┐            ┌────▼───┐
    │Canary  │            │Rolling │
    │Deploy  │            │Update  │
    └────────┘            └────────┘


┌──────────────────────────────────────────┐
│   Are you testing UX or algorithms?     │
└──────────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
   ┌────▼─────┐          ┌─────▼────┐
   │   Yes    │          │    No    │
   └────┬─────┘          └─────┬────┘
        │                      │
    ┌───▼────┐            ┌────▼───┐
    │  A/B   │            │Canary  │
    │Testing │            │Deploy  │
    └────────┘            └────────┘
```

### Strategy Selection Table

| Scenario | Recommended Strategy | Rationale |
|----------|---------------------|-----------|
| Hotfix for production bug | Blue-Green | Instant rollback, minimal risk |
| New microservice | Rolling Update | Simple, no user impact |
| API breaking change | Blue-Green + Feature Flags | Control rollout, easy rollback |
| UI redesign | A/B Testing | Validate with users, measure impact |
| Performance optimization | Canary | Gradual validation, automated metrics |
| Database schema change | Expand-Contract + Rolling | Zero downtime, backward compatible |
| Algorithm change | A/B Testing + Feature Flags | Compare results, target users |
| Security patch | Blue-Green or Canary | Fast deployment, validation |
| Infrastructure upgrade | Blue-Green | Complete isolation, easy rollback |
| Minor bug fix | Rolling Update | Low risk, simple deployment |

## Monitoring and Validation

### Deployment Metrics Dashboard

```yaml
# grafana-dashboard-deployments.json (simplified)
dashboard:
  title: "Deployment Monitoring"

  panels:
    - title: "Deployment Timeline"
      type: "graph"
      targets:
        - expr: 'changes(deployment_version{namespace="platform-production"}[1h])'

    - title: "Error Rate by Version"
      type: "graph"
      targets:
        - expr: 'rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])'
          legend: "{{version}}"

    - title: "P95 Latency by Version"
      type: "graph"
      targets:
        - expr: 'histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))'
          legend: "{{version}}"

    - title: "Pod Restarts"
      type: "graph"
      targets:
        - expr: 'rate(kube_pod_container_status_restarts_total[5m])'

    - title: "Active Connections"
      type: "graph"
      targets:
        - expr: 'sum(pg_stat_activity_count) by (datname)'

    - title: "Deployment Status"
      type: "stat"
      targets:
        - expr: 'kube_deployment_status_replicas_available / kube_deployment_spec_replicas'
```

### Post-Deployment Validation

```bash
#!/bin/bash
# scripts/validate-deployment.sh

set -euo pipefail

SERVICE_NAME="${1}"
NAMESPACE="${2:-platform-production}"
VERSION="${3}"
VALIDATION_DURATION=300  # 5 minutes

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

# Check deployment status
check_deployment_status() {
    log_info "Checking deployment status..."

    local ready=$(kubectl get deployment $SERVICE_NAME \
        -n $NAMESPACE \
        -o jsonpath='{.status.readyReplicas}')

    local desired=$(kubectl get deployment $SERVICE_NAME \
        -n $NAMESPACE \
        -o jsonpath='{.spec.replicas}')

    if [ "$ready" != "$desired" ]; then
        log_error "Not all replicas are ready: $ready/$desired"
        return 1
    fi

    log_info "All $ready replicas are ready"
    return 0
}

# Check error rate
check_error_rate() {
    log_info "Checking error rate..."

    local error_rate=$(kubectl exec -n monitoring deployment/prometheus -- \
        promtool query instant http://localhost:9090 \
        "rate(http_requests_total{job=\"$SERVICE_NAME\",status=~\"5..\"}[5m]) / rate(http_requests_total{job=\"$SERVICE_NAME\"}[5m])" \
        | jq -r '.data.result[0].value[1] // "0"')

    local threshold=0.02

    if (( $(echo "$error_rate > $threshold" | bc -l) )); then
        log_error "Error rate too high: $error_rate (threshold: $threshold)"
        return 1
    fi

    log_info "Error rate OK: $error_rate"
    return 0
}

# Check latency
check_latency() {
    log_info "Checking latency..."

    local p95_latency=$(kubectl exec -n monitoring deployment/prometheus -- \
        promtool query instant http://localhost:9090 \
        "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job=\"$SERVICE_NAME\"}[5m])) * 1000" \
        | jq -r '.data.result[0].value[1] // "0"')

    local threshold=500

    if (( $(echo "$p95_latency > $threshold" | bc -l) )); then
        log_error "P95 latency too high: ${p95_latency}ms (threshold: ${threshold}ms)"
        return 1
    fi

    log_info "P95 latency OK: ${p95_latency}ms"
    return 0
}

# Check version
check_version() {
    log_info "Checking deployed version..."

    local deployed_version=$(kubectl get deployment $SERVICE_NAME \
        -n $NAMESPACE \
        -o jsonpath='{.spec.template.spec.containers[0].image}' \
        | cut -d: -f2)

    if [ "$deployed_version" != "$VERSION" ]; then
        log_error "Version mismatch. Expected: $VERSION, Got: $deployed_version"
        return 1
    fi

    log_info "Version correct: $deployed_version"
    return 0
}

# Run smoke tests
run_smoke_tests() {
    log_info "Running smoke tests..."

    if ./scripts/smoke-tests.sh "$SERVICE_NAME" "$NAMESPACE"; then
        log_info "Smoke tests passed"
        return 0
    else
        log_error "Smoke tests failed"
        return 1
    fi
}

# Monitor for duration
monitor() {
    log_info "Monitoring deployment for ${VALIDATION_DURATION}s..."

    local start_time=$(date +%s)
    local errors=0

    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        if [ $elapsed -gt $VALIDATION_DURATION ]; then
            log_info "Monitoring period complete"
            break
        fi

        # Check metrics every 30 seconds
        if ! check_error_rate || ! check_latency; then
            errors=$((errors + 1))

            if [ $errors -gt 3 ]; then
                log_error "Too many validation failures"
                return 1
            fi
        else
            errors=0
        fi

        sleep 30
    done

    return 0
}

# Main execution
main() {
    log_info "Starting deployment validation for $SERVICE_NAME:$VERSION"

    if ! check_deployment_status; then
        log_error "Deployment status check failed"
        exit 1
    fi

    if ! check_version; then
        log_error "Version check failed"
        exit 1
    fi

    if ! run_smoke_tests; then
        log_error "Smoke tests failed"
        exit 1
    fi

    if ! monitor; then
        log_error "Monitoring detected issues"
        exit 1
    fi

    log_info "Deployment validation successful"
    exit 0
}

main "$@"
```

## Conclusion

This comprehensive guide covers all deployment strategies used in the AI Workflow Processing Platform:

- **Blue-Green Deployment**: For critical changes requiring instant rollback
- **Canary Deployment**: For progressive rollout with automated validation
- **Rolling Updates**: For minor changes with minimal risk
- **A/B Testing**: For validating UX and algorithm changes
- **Feature Flags**: For runtime control and gradual rollout

Each strategy is production-ready with complete implementations, automation scripts, and monitoring integration. Choose the appropriate strategy based on your change type, risk tolerance, and validation requirements.

**Key Principles**:
1. Always prioritize zero downtime
2. Automate validation and rollback
3. Monitor continuously during deployments
4. Use database migration patterns for schema changes
5. Implement comprehensive health checks
6. Test deployment procedures regularly

For more information, see:
- [CI/CD Overview](01-cicd-overview.md)
- [Pipeline Stages](02-pipeline-stages.md)
- [GitOps Workflow](03-gitops-workflow.md)
- [Quality Gates](04-quality-gates.md)
