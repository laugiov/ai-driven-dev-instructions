# Infrastructure Overview

**Document Version**: 1.0
**Last Updated**: 2025-01-07
**Status**: Complete

## Table of Contents

1. [Overview](#overview)
2. [Infrastructure Architecture](#infrastructure-architecture)
3. [Cloud-Agnostic Design](#cloud-agnostic-design)
4. [Infrastructure Components](#infrastructure-components)
5. [Container Orchestration (Kubernetes)](#container-orchestration-kubernetes)
6. [Service Mesh (Istio)](#service-mesh-istio)
7. [Infrastructure Services](#infrastructure-services)
8. [Observability Stack](#observability-stack)
9. [Storage Architecture](#storage-architecture)
10. [Network Architecture](#network-architecture)
11. [High Availability](#high-availability)
12. [Disaster Recovery](#disaster-recovery)
13. [Scalability Strategy](#scalability-strategy)
14. [Infrastructure as Code](#infrastructure-as-code)
15. [Cost Optimization](#cost-optimization)
16. [Security Considerations](#security-considerations)

## Overview

This document provides a comprehensive overview of the infrastructure architecture for the AI Workflow Processing Platform. Our infrastructure is designed to be cloud-agnostic, highly available, scalable, secure, and cost-effective while meeting enterprise-grade requirements.

### Infrastructure Principles

Our infrastructure design follows these core principles:

1. **Cloud Agnostic**: No vendor lock-in, portable across AWS, Azure, GCP
2. **Infrastructure as Code**: Everything defined in code (Terraform, Helm)
3. **Immutable Infrastructure**: Replace, don't modify
4. **Zero Trust Security**: Trust nothing, verify everything
5. **High Availability**: Multi-AZ deployment, no single points of failure
6. **Auto-Scaling**: Horizontal scaling based on metrics
7. **Observability First**: Built-in monitoring, logging, tracing
8. **Cost Optimized**: Right-sizing, spot instances, reserved capacity
9. **GitOps**: Declarative, version-controlled infrastructure
10. **Self-Healing**: Automated recovery from failures

### Design Goals

| Goal | Target | Implementation |
|------|--------|----------------|
| **Availability** | 99.9% (43 minutes downtime/month) | Multi-AZ, redundancy, health checks |
| **Scalability** | 10x current load | Horizontal pod autoscaling, cluster autoscaling |
| **Performance** | P95 < 200ms API response | Caching, optimized queries, CDN |
| **Recovery Time Objective (RTO)** | < 1 hour | Automated failover, documented procedures |
| **Recovery Point Objective (RPO)** | < 15 minutes | Continuous replication, frequent backups |
| **Security** | Zero Trust | mTLS, network policies, RBAC, encryption |
| **Cost Efficiency** | < $10k/month at current scale | Spot instances, auto-scaling, reserved capacity |

## Infrastructure Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          External Users / APIs                           │
└────────────────────────────┬────────────────────────────────────────────┘
                             │ HTTPS (TLS 1.3)
                             ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                         CDN / DDoS Protection                            │
│                     (CloudFlare / AWS CloudFront)                        │
└────────────────────────────┬────────────────────────────────────────────┘
                             │
                             ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                          Load Balancer                                   │
│                    (Cloud Provider L4/L7 LB)                            │
└────────────────────────────┬────────────────────────────────────────────┘
                             │
                             ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster (Multi-AZ)                        │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    Control Plane (Managed)                        │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │  │
│  │  │   Master 1  │  │   Master 2  │  │   Master 3  │              │  │
│  │  │    (AZ-1)   │  │    (AZ-2)   │  │    (AZ-3)   │              │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘              │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                      Istio Service Mesh                           │  │
│  │  ┌─────────────────────────────────────────────────────────────┐ │  │
│  │  │              Istio Ingress Gateway (AZ-1,2,3)               │ │  │
│  │  └────────────────────┬────────────────────────────────────────┘ │  │
│  │                       │ mTLS                                      │  │
│  │  ┌────────────────────▼──────────────────────────────────────┐   │  │
│  │  │                    Kong API Gateway                        │   │  │
│  │  │            (Authentication, Rate Limiting)                 │   │  │
│  │  └────────────────────┬──────────────────────────────────────┘   │  │
│  │                       │ mTLS                                      │  │
│  │  ┌────────────────────▼──────────────────────────────────────┐   │  │
│  │  │              Application Services (Namespace)              │   │  │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │   │  │
│  │  │  │   BFF    │  │   LLM    │  │ Workflow │  │Validation│  │   │  │
│  │  │  │ Service  │  │  Agent   │  │Orchestr. │  │ Service  │  │   │  │
│  │  │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘  │   │  │
│  │  │       │ mTLS        │ mTLS        │ mTLS        │ mTLS   │   │  │
│  │  │  ┌────▼─────┐  ┌────▼─────┐  ┌────▼─────┐  ┌────▼─────┐  │   │  │
│  │  │  │Notificat.│  │  Audit   │  │   File   │  │          │  │   │  │
│  │  │  │ Service  │  │ Logging  │  │ Storage  │  │          │  │   │  │
│  │  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │   │  │
│  │  └───────────────────────────────────────────────────────────┘   │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                 Data Layer (Namespace: data)                      │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐ │  │
│  │  │PostgreSQL  │  │ RabbitMQ   │  │   Redis    │  │  MinIO /   │ │  │
│  │  │  Cluster   │  │  Cluster   │  │  Cluster   │  │    S3      │ │  │
│  │  │ (Per Svc)  │  │            │  │            │  │            │ │  │
│  │  └────────────┘  └────────────┘  └────────────┘  └────────────┘ │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │          Infrastructure Services (Namespace: infra)               │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐ │  │
│  │  │ Keycloak   │  │   Vault    │  │   Kong     │  │  ArgoCD    │ │  │
│  │  │   (IAM)    │  │ (Secrets)  │  │  (API GW)  │  │  (GitOps)  │ │  │
│  │  └────────────┘  └────────────┘  └────────────┘  └────────────┘ │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │         Observability Stack (Namespace: observability)            │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐ │  │
│  │  │Prometheus  │  │  Grafana   │  │    Loki    │  │   Tempo    │ │  │
│  │  │ (Metrics)  │  │   (Viz)    │  │   (Logs)   │  │  (Traces)  │ │  │
│  │  └────────────┘  └────────────┘  └────────────┘  └────────────┘ │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                        Worker Nodes                               │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │  │
│  │  │  Node Pool  │  │  Node Pool  │  │  Node Pool  │              │  │
│  │  │  Application│  │     Data    │  │Infrastructure│              │  │
│  │  │   (AZ-1,2,3)│  │   (AZ-1,2,3)│  │   (AZ-1,2,3)│              │  │
│  │  │             │  │             │  │             │              │  │
│  │  │ - General   │  │ - High CPU  │  │ - General   │              │  │
│  │  │ - Spot OK   │  │ - High Mem  │  │ - On-Demand │              │  │
│  │  │ - Auto-scale│  │ - On-Demand │  │ - Reserved  │              │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘              │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                             │
                             ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                    External Dependencies                                 │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐       │
│  │  OpenAI    │  │   SMTP     │  │   DNS      │  │  Backup    │       │
│  │    API     │  │  Service   │  │  Provider  │  │  Storage   │       │
│  └────────────┘  └────────────┘  └────────────┘  └────────────┘       │
└─────────────────────────────────────────────────────────────────────────┘
```

### Infrastructure Layers

| Layer | Purpose | Components | Scaling Strategy |
|-------|---------|------------|------------------|
| **Edge** | Traffic management, DDoS protection | CloudFlare, Cloud LB | Global distribution |
| **Ingress** | API Gateway, TLS termination | Istio Gateway, Kong | Horizontal (3-10 replicas) |
| **Application** | Business logic | 7 microservices | Horizontal (HPA) |
| **Data** | Data persistence | PostgreSQL, RabbitMQ, Redis | Vertical + replication |
| **Infrastructure** | Platform services | Keycloak, Vault, ArgoCD | HA pairs (2-3 replicas) |
| **Observability** | Monitoring, logging | Prometheus, Grafana, Loki | Horizontal + retention policies |

## Cloud-Agnostic Design

### Abstraction Strategy

We use Kubernetes and cloud-agnostic tools to avoid vendor lock-in:

| Capability | Cloud-Agnostic Solution | AWS Alternative | Azure Alternative | GCP Alternative |
|------------|------------------------|-----------------|-------------------|-----------------|
| **Compute** | Kubernetes (any CNCF certified) | EKS | AKS | GKE |
| **Storage** | CSI drivers + vendor StorageClass | EBS, EFS | Azure Disk, Files | Persistent Disk |
| **Load Balancer** | Kubernetes Ingress/Service | ALB, NLB | Azure LB | Cloud Load Balancing |
| **Database** | PostgreSQL on K8s or managed | RDS PostgreSQL | Azure Database | Cloud SQL |
| **Object Storage** | MinIO on K8s or S3-compatible | S3 | Blob Storage | Cloud Storage |
| **Message Queue** | RabbitMQ on K8s | Amazon MQ | Azure Service Bus | Cloud Pub/Sub |
| **DNS** | External DNS + any provider | Route 53 | Azure DNS | Cloud DNS |
| **Secrets** | HashiCorp Vault | Secrets Manager | Key Vault | Secret Manager |
| **Monitoring** | Prometheus/Grafana | CloudWatch | Azure Monitor | Cloud Monitoring |

### Multi-Cloud Deployment Options

**Option 1: Single Cloud (Recommended for MVP)**
- Deploy entire platform in one cloud region
- Simplest operations
- Lower initial cost
- Easiest compliance (data residency)

**Option 2: Multi-Cloud Active-Passive**
- Primary deployment in Cloud A
- Backup deployment in Cloud B (disaster recovery)
- Higher availability
- Moderate complexity

**Option 3: Multi-Cloud Active-Active**
- Deploy across multiple clouds
- Highest availability
- Complex data synchronization
- Higher cost

**Current Recommendation**: Start with **Option 1** (Single Cloud), design for **Option 2** (have DR plan), evolve to **Option 3** if needed.

## Infrastructure Components

### Kubernetes Cluster Specification

**Control Plane** (Managed by cloud provider):
- 3 master nodes (HA)
- Distributed across 3 availability zones
- Automatic backups of etcd
- Automatic version upgrades (with testing)

**Worker Nodes** - 3 node pools:

#### 1. Application Node Pool
```yaml
Node Pool: application-pool
Purpose: Run application microservices
Instance Type:
  - AWS: t3.xlarge (4 vCPU, 16GB RAM)
  - Azure: Standard_D4s_v3
  - GCP: n2-standard-4
Spot/Preemptible: Yes (up to 70% cost savings)
Min Nodes: 3 (one per AZ)
Max Nodes: 20
Auto-scaling: Yes (CPU > 70% or Memory > 80%)
Taints: None
Labels:
  - workload: application
  - spot: "true"
```

#### 2. Data Node Pool
```yaml
Node Pool: data-pool
Purpose: Run stateful services (databases)
Instance Type:
  - AWS: r5.xlarge (4 vCPU, 32GB RAM)
  - Azure: Standard_E4s_v3
  - GCP: n2-highmem-4
Spot/Preemptible: No (on-demand for stability)
Min Nodes: 3 (one per AZ)
Max Nodes: 6
Auto-scaling: Manual (stateful services)
Taints:
  - workload=data:NoSchedule
Labels:
  - workload: data
  - spot: "false"
Storage:
  - High-performance SSD
  - Encrypted
```

#### 3. Infrastructure Node Pool
```yaml
Node Pool: infrastructure-pool
Purpose: Run infrastructure services (Vault, Keycloak, etc.)
Instance Type:
  - AWS: t3.large (2 vCPU, 8GB RAM)
  - Azure: Standard_D2s_v3
  - GCP: n2-standard-2
Spot/Preemptible: No (critical services)
Min Nodes: 3 (one per AZ)
Max Nodes: 6
Auto-scaling: No (stable sizing)
Taints:
  - workload=infrastructure:NoSchedule
Labels:
  - workload: infrastructure
  - spot: "false"
```

### Kubernetes Configuration

**Cluster Sizing** (Initial):
- Total nodes: 9 (3 per pool)
- Total vCPU: ~30
- Total RAM: ~150 GB
- Estimated cost: $1,500-2,000/month (with spot instances)

**Kubernetes Version**:
- Production: 1.28+ (stable)
- Upgrade strategy: N-1 version (stay one version behind latest)

**Add-ons**:
- CoreDNS (cluster DNS)
- Metrics Server (resource metrics)
- CSI drivers (storage)
- External DNS (DNS automation)
- Cert-manager (certificate management)
- Cluster Autoscaler

## Container Orchestration (Kubernetes)

### Namespace Strategy

```yaml
# Application workloads
apiVersion: v1
kind: Namespace
metadata:
  name: application
  labels:
    name: application
    istio-injection: enabled
    pod-security.kubernetes.io/enforce: restricted

---
# Data layer (databases, message queues)
apiVersion: v1
kind: Namespace
metadata:
  name: data
  labels:
    name: data
    istio-injection: enabled
    pod-security.kubernetes.io/enforce: baseline

---
# Infrastructure services
apiVersion: v1
kind: Namespace
metadata:
  name: infrastructure
  labels:
    name: infrastructure
    istio-injection: enabled
    pod-security.kubernetes.io/enforce: restricted

---
# Observability stack
apiVersion: v1
kind: Namespace
metadata:
  name: observability
  labels:
    name: observability
    istio-injection: disabled
    pod-security.kubernetes.io/enforce: baseline

---
# Service mesh control plane
apiVersion: v1
kind: Namespace
metadata:
  name: istio-system
  labels:
    name: istio-system
    istio-injection: disabled

---
# GitOps
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    name: argocd
    istio-injection: disabled
```

### Resource Management

**Resource Requests and Limits** - Every pod must specify:

```yaml
# Example: LLM Agent Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llm-agent-service
  namespace: application
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: llm-agent
        image: platform/llm-agent-service:v1.2.3
        resources:
          requests:
            cpu: 500m        # Guaranteed CPU
            memory: 1Gi      # Guaranteed RAM
          limits:
            cpu: 2000m       # Max CPU burst
            memory: 2Gi      # Max RAM (hard limit)

        # Liveness probe (restart if unhealthy)
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3

        # Readiness probe (remove from service if not ready)
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3

        # Startup probe (for slow-starting containers)
        startupProbe:
          httpGet:
            path: /health/startup
            port: 8080
          initialDelaySeconds: 0
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 30  # 5 minutes max startup time
```

### Horizontal Pod Autoscaler (HPA)

```yaml
# HPA for LLM Agent Service
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: llm-agent-hpa
  namespace: application
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: llm-agent-service

  minReplicas: 3
  maxReplicas: 20

  metrics:
  # Scale based on CPU utilization
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70

  # Scale based on memory utilization
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80

  # Scale based on custom metric (RabbitMQ queue length)
  - type: External
    external:
      metric:
        name: rabbitmq_queue_messages
        selector:
          matchLabels:
            queue: llm-agent-tasks
      target:
        type: AverageValue
        averageValue: "10"  # Scale up if >10 messages per pod

  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Wait 5 minutes before scaling down
      policies:
      - type: Percent
        value: 50  # Scale down by max 50% at a time
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0  # Scale up immediately
      policies:
      - type: Percent
        value: 100  # Can double replicas
        periodSeconds: 60
      - type: Pods
        value: 4  # Or add 4 pods
        periodSeconds: 60
      selectPolicy: Max  # Use the policy that scales faster
```

### Pod Disruption Budgets

Ensure availability during voluntary disruptions (node upgrades, etc.):

```yaml
# PDB for LLM Agent Service
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: llm-agent-pdb
  namespace: application
spec:
  minAvailable: 2  # Always keep at least 2 pods running
  selector:
    matchLabels:
      app: llm-agent-service

---
# Alternative: specify max unavailable
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: workflow-orchestrator-pdb
  namespace: application
spec:
  maxUnavailable: 1  # Allow max 1 pod to be down
  selector:
    matchLabels:
      app: workflow-orchestrator-service
```

### Affinity and Anti-Affinity

Spread pods across nodes and availability zones:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llm-agent-service
spec:
  template:
    spec:
      # Anti-affinity: Don't schedule on nodes with same app
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: llm-agent-service
              topologyKey: kubernetes.io/hostname

          # Required: Spread across availability zones
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: llm-agent-service
              topologyKey: topology.kubernetes.io/zone

        # Node affinity: Prefer application node pool
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: workload
                operator: In
                values:
                - application
```

## Service Mesh (Istio)

### Istio Architecture

Istio provides transparent service-to-service communication, security (mTLS), observability, and traffic management.

**Components**:
- **Istiod**: Control plane (configuration, certificate authority)
- **Envoy Proxy**: Data plane (sidecar in each pod)
- **Ingress Gateway**: Entry point for external traffic
- **Egress Gateway**: Exit point for external calls

See [02-service-mesh.md](02-service-mesh.md) for complete Istio configuration.

## Infrastructure Services

### Identity and Access Management (Keycloak)

**Purpose**: Central authentication and authorization

**Deployment**:
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: keycloak
  namespace: infrastructure
spec:
  serviceName: keycloak
  replicas: 3
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: keycloak
            topologyKey: kubernetes.io/hostname

      containers:
      - name: keycloak
        image: quay.io/keycloak/keycloak:23.0
        args:
        - start
        - --optimized
        env:
        - name: KC_DB
          value: postgres
        - name: KC_DB_URL
          value: jdbc:postgresql://keycloak-postgres:5432/keycloak
        - name: KC_DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: keycloak-db-credentials
              key: username
        - name: KC_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: keycloak-db-credentials
              key: password
        - name: KC_HOSTNAME
          value: keycloak.platform.local
        - name: KC_PROXY
          value: edge
        - name: KEYCLOAK_ADMIN
          valueFrom:
            secretKeyRef:
              name: keycloak-admin-credentials
              key: username
        - name: KEYCLOAK_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: keycloak-admin-credentials
              key: password

        ports:
        - name: http
          containerPort: 8080

        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2000m
            memory: 2Gi

        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 10

        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 5
```

### Secrets Management (HashiCorp Vault)

**Purpose**: Centralized secrets storage, dynamic credentials, encryption as a service

See [../02-security/04-secrets-management.md](../02-security/04-secrets-management.md) for complete Vault configuration.

**Deployment**: HA cluster with 3 replicas, auto-unseal, audit logging enabled.

### API Gateway (Kong)

**Purpose**: API management, rate limiting, request transformation

See [../02-security/05-network-security.md](../02-security/05-network-security.md) for complete Kong configuration.

**Deployment**: 3 replicas, backed by PostgreSQL, integrated with Keycloak.

### GitOps (ArgoCD)

**Purpose**: Declarative continuous delivery

**Deployment**:
```yaml
# Install via Helm
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd \
  --namespace argocd \
  --set server.replicas=2 \
  --set repoServer.replicas=2 \
  --set controller.replicas=1
```

**Application Structure**:
```yaml
# Application of Applications pattern
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/platform-gitops
    targetRevision: main
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

## Observability Stack

### Monitoring (Prometheus + Grafana)

**Prometheus** collects metrics from all services:
- Service metrics (request rate, latency, errors)
- Infrastructure metrics (CPU, memory, disk)
- Business metrics (workflows created, completions, etc.)

**Grafana** visualizes metrics:
- Pre-built dashboards for each service
- Infrastructure dashboards
- Business intelligence dashboards

See [04-observability-stack.md](04-observability-stack.md) for complete configuration.

### Logging (Loki)

**Loki** aggregates logs from all pods:
- Application logs
- Access logs
- Audit logs
- System logs

**Log Retention**:
- 7 days: High-detail logs (all levels)
- 30 days: Important logs (INFO and above)
- 1 year: Audit logs

### Tracing (Tempo)

**Tempo** provides distributed tracing:
- Trace requests across microservices
- Identify bottlenecks
- Debug complex interactions

**Integration**: Automatic via Istio + OpenTelemetry

## Storage Architecture

### Storage Classes

```yaml
# High-performance SSD for databases
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs  # Or azure-disk, gce-pd
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
  kmsKeyId: "arn:aws:kms:..."
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true

---
# Standard SSD for general use
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard-ssd
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true

---
# Shared filesystem for file storage service
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: shared-filesystem
provisioner: efs.csi.aws.com  # Or azure-file, filestore
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-xxxxx
  directoryPerms: "700"
volumeBindingMode: Immediate
```

### Persistent Volume Claims

```yaml
# PostgreSQL volume
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-llm-agent-pvc
  namespace: data
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 100Gi
```

### Backup Storage

- **Local backups**: Kubernetes PVCs (short-term, 7 days)
- **Remote backups**: S3-compatible object storage (long-term, 90 days)
- **Disaster recovery**: Cross-region replication

## Network Architecture

### CNI (Container Network Interface)

**Recommended**: Calico or Cilium

**Calico** advantages:
- Network policies enforcement
- eBPF mode for high performance
- Multi-cloud support

**Cilium** advantages:
- eBPF-based (even better performance)
- Advanced network policies
- Built-in observability

### Service Types

```yaml
# ClusterIP (internal only)
apiVersion: v1
kind: Service
metadata:
  name: llm-agent-service
  namespace: application
spec:
  type: ClusterIP
  selector:
    app: llm-agent-service
  ports:
  - port: 8080
    targetPort: 8080
    name: http

---
# LoadBalancer (external access)
apiVersion: v1
kind: Service
metadata:
  name: istio-ingressgateway
  namespace: istio-system
spec:
  type: LoadBalancer
  selector:
    app: istio-ingressgateway
  ports:
  - port: 80
    targetPort: 8080
    name: http
  - port: 443
    targetPort: 8443
    name: https
```

### DNS

**Internal DNS**: CoreDNS (automatic)
- Service discovery: `llm-agent-service.application.svc.cluster.local`

**External DNS**: External-DNS controller
- Automatic DNS record creation for LoadBalancer services
- Supports Route 53, Azure DNS, Cloud DNS, CloudFlare

```yaml
# External DNS configuration
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-dns
  namespace: kube-system

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: external-dns
rules:
- apiGroups: [""]
  resources: ["services", "endpoints", "pods"]
  verbs: ["get", "watch", "list"]
- apiGroups: ["extensions", "networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "watch", "list"]

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: external-dns
  template:
    metadata:
      labels:
        app: external-dns
    spec:
      serviceAccountName: external-dns
      containers:
      - name: external-dns
        image: registry.k8s.io/external-dns/external-dns:v0.14.0
        args:
        - --source=service
        - --source=ingress
        - --domain-filter=platform.local
        - --provider=aws  # Or azure, google, cloudflare
        - --policy=upsert-only
        - --txt-owner-id=platform-cluster
        - --log-level=info
```

## High Availability

### Multi-AZ Deployment

All critical components deployed across 3 availability zones:

| Component | Replicas | Distribution |
|-----------|----------|--------------|
| **Istio Ingress Gateway** | 3 | 1 per AZ |
| **Kong API Gateway** | 3 | 1 per AZ |
| **BFF Service** | 3 | 1 per AZ |
| **LLM Agent Service** | 3-20 | Evenly distributed |
| **Workflow Orchestrator** | 3-10 | Evenly distributed |
| **PostgreSQL** | 1 primary + 2 replicas | 1 per AZ |
| **RabbitMQ** | 3 | 1 per AZ |
| **Keycloak** | 3 | 1 per AZ |
| **Vault** | 3 | 1 per AZ |

### Health Checks

Every service implements health endpoints:
- `/health/live` - Liveness (restart if fails)
- `/health/ready` - Readiness (remove from load balancer if fails)
- `/health/startup` - Startup (allow slow startup)

### Graceful Shutdown

All services handle SIGTERM gracefully:
1. Stop accepting new requests
2. Finish processing current requests (30s timeout)
3. Close connections
4. Exit

```php
// PHP example
pcntl_signal(SIGTERM, function() {
    $this->logger->info('Received SIGTERM, shutting down gracefully');
    $this->isShuttingDown = true;

    // Wait for active requests to finish (max 30s)
    $timeout = time() + 30;
    while ($this->activeRequests > 0 && time() < $timeout) {
        sleep(1);
    }

    exit(0);
});
```

### Circuit Breakers

See [../02-security/05-network-security.md](../02-security/05-network-security.md) for Istio circuit breaker configuration.

## Disaster Recovery

### Backup Strategy

**Database Backups**:
- **Continuous WAL archiving** to S3
- **Full backup** every 6 hours
- **Point-in-time recovery** (PITR) up to 7 days
- **Long-term backups** weekly (retained 90 days)

**Configuration Backups**:
- **Git repository** for all IaC (Terraform, Helm values)
- **etcd backups** every hour (managed by cloud provider)
- **Vault backups** encrypted, daily

**Retention**:
- Hourly: 24 hours
- Daily: 7 days
- Weekly: 4 weeks
- Monthly: 12 months

### Disaster Recovery Plan

**RTO (Recovery Time Objective)**: 1 hour
**RPO (Recovery Point Objective)**: 15 minutes

**Scenarios**:

1. **Single AZ failure**: Automatic (pods rescheduled to other AZs)
2. **Region failure**: Manual failover to DR region (1 hour)
3. **Data corruption**: Restore from backup (30 minutes)
4. **Complete cluster loss**: Rebuild from IaC + restore data (2 hours)

See [05-disaster-recovery.md](05-disaster-recovery.md) for detailed procedures.

## Scalability Strategy

### Horizontal Scaling

**Application Services**: HPA based on CPU, memory, custom metrics
**Cluster**: Cluster Autoscaler adds/removes nodes automatically

```yaml
# Cluster Autoscaler configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    spec:
      containers:
      - name: cluster-autoscaler
        image: registry.k8s.io/autoscaling/cluster-autoscaler:v1.28.0
        command:
        - ./cluster-autoscaler
        - --cloud-provider=aws  # Or azure, gce
        - --namespace=kube-system
        - --nodes=3:20:application-pool
        - --scale-down-enabled=true
        - --scale-down-delay-after-add=5m
        - --scale-down-unneeded-time=5m
        - --skip-nodes-with-local-storage=false
        - --skip-nodes-with-system-pods=false
```

### Vertical Scaling

**Databases**: Manual vertical scaling during maintenance windows
- Stop writes
- Take backup
- Resize instance
- Restart
- Verify

**VPA (Vertical Pod Autoscaler)**: Recommend optimal resource requests/limits

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: llm-agent-vpa
  namespace: application
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: llm-agent-service
  updatePolicy:
    updateMode: "Off"  # Recommendation only, don't auto-apply
```

### Performance Optimization

- **Caching**: Redis for frequently accessed data
- **Database**: Connection pooling, prepared statements, indexes
- **CDN**: Static assets cached at edge
- **Compression**: gzip/brotli for API responses
- **Lazy loading**: Load data on-demand

See [06-scalability-strategy.md](06-scalability-strategy.md) for detailed strategies.

## Infrastructure as Code

### Terraform Structure

```
terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   ├── staging/
│   └── production/
├── modules/
│   ├── kubernetes-cluster/
│   ├── networking/
│   ├── storage/
│   └── monitoring/
└── shared/
    ├── provider.tf
    └── backend.tf
```

**Example Terraform** (EKS cluster):

```hcl
# terraform/modules/kubernetes-cluster/main.tf
resource "aws_eks_cluster" "platform" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.allowed_cidrs
    security_group_ids      = [aws_security_group.cluster.id]
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.cluster.arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  tags = var.tags
}

resource "aws_eks_node_group" "application" {
  cluster_name    = aws_eks_cluster.platform.name
  node_group_name = "application-pool"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = 3
    max_size     = 20
    min_size     = 3
  }

  instance_types = ["t3.xlarge"]
  capacity_type  = "SPOT"  # Cost savings

  labels = {
    workload = "application"
    spot     = "true"
  }

  tags = var.tags
}
```

### Helm Charts

All applications deployed via Helm:

```yaml
# helm/llm-agent-service/values.yaml
replicaCount: 3

image:
  repository: platform/llm-agent-service
  tag: v1.2.3
  pullPolicy: IfNotPresent

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2000m
    memory: 2Gi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

service:
  type: ClusterIP
  port: 8080

ingress:
  enabled: false  # Handled by Istio

env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: llm-agent-db-credentials
        key: url
  - name: VAULT_ADDR
    value: http://vault.infrastructure:8200
```

### GitOps Workflow

1. Developer commits code to Git
2. CI builds and tests
3. CI updates Helm chart version in GitOps repo
4. ArgoCD detects change
5. ArgoCD applies changes to cluster
6. Health checks verify deployment

## Cost Optimization

### Strategies

1. **Spot Instances**: 70% savings for application workloads
2. **Reserved Capacity**: Commit to 1-year for infrastructure (40% savings)
3. **Right-sizing**: Use VPA recommendations
4. **Auto-scaling**: Scale down during low traffic
5. **Storage optimization**: Lifecycle policies, compression
6. **Network optimization**: Minimize cross-AZ traffic
7. **Observability retention**: Shorter retention for high-volume logs

### Cost Breakdown (Estimated)

| Component | Monthly Cost | Notes |
|-----------|--------------|-------|
| **Kubernetes Control Plane** | $200 | Managed by cloud provider |
| **Worker Nodes** | $1,000 | Mix of spot and on-demand |
| **Load Balancers** | $50 | 2 LBs |
| **Storage** | $300 | 2TB total (databases + backups) |
| **Data Transfer** | $200 | Moderate traffic |
| **Monitoring/Logging** | $150 | Prometheus, Loki, Tempo |
| **DNS** | $20 | Hosted zones |
| **Secrets Management** | $0 | Self-hosted Vault |
| **Container Registry** | $50 | Private registry |
| **Backups** | $100 | S3 storage |
| **Total** | **~$2,070/month** | At initial scale |

**Scaling costs**: Linear with nodes, ~$100/node/month

## Security Considerations

See complete security documentation in [../02-security/](../02-security/) folder.

**Infrastructure Security Highlights**:
- ✅ All data encrypted at rest and in transit
- ✅ Network policies deny all by default
- ✅ mTLS for all service-to-service communication
- ✅ RBAC with least privilege
- ✅ Secrets in Vault (never in Git)
- ✅ Automated security scanning (Trivy, Checkov)
- ✅ Pod Security Standards enforced
- ✅ Regular security audits

## Monitoring and Alerting

**Key Infrastructure Metrics**:
- Node CPU/Memory/Disk utilization
- Pod restart count
- Failed deployments
- Network latency
- Storage IOPS
- Certificate expiration

**Alerts** (send to on-call):
- Node not ready (5+ minutes)
- Pod CrashLoopBackOff
- Persistent volume full (>90%)
- High pod restart rate
- Certificate expiring (<7 days)
- Cluster autoscaler failures

## Deployment Strategy

### Blue-Green Deployment

1. Deploy new version to "green" environment
2. Run smoke tests
3. Switch traffic to green
4. Monitor for issues
5. Keep blue as rollback option (1 hour)
6. Delete blue environment

### Canary Deployment

Istio supports gradual traffic shifting:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: llm-agent-canary
spec:
  hosts:
  - llm-agent-service
  http:
  - match:
    - headers:
        x-canary:
          exact: "true"
    route:
    - destination:
        host: llm-agent-service
        subset: v2
  - route:
    - destination:
        host: llm-agent-service
        subset: v1
      weight: 90
    - destination:
        host: llm-agent-service
        subset: v2
      weight: 10  # 10% traffic to new version
```

## Best Practices

1. **Immutable Infrastructure**: Never modify running resources, always replace
2. **GitOps**: All changes through Git (audit trail)
3. **Least Privilege**: Minimal permissions for everything
4. **Encryption Everywhere**: At rest, in transit, in memory
5. **Observability**: Comprehensive logging, metrics, tracing
6. **Automated Testing**: CI/CD with quality gates
7. **Documentation**: Keep docs up-to-date with infrastructure
8. **Regular Reviews**: Quarterly infrastructure audits
9. **Disaster Recovery Drills**: Test DR procedures regularly
10. **Cost Monitoring**: Track costs, optimize continuously

## Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)
- [ ] Provision Kubernetes cluster (Terraform)
- [ ] Configure networking (VPC, subnets, security groups)
- [ ] Deploy cert-manager
- [ ] Set up GitOps (ArgoCD)
- [ ] Configure storage classes

### Phase 2: Infrastructure Services (Weeks 3-4)
- [ ] Deploy Vault
- [ ] Deploy Keycloak
- [ ] Deploy Kong
- [ ] Set up External DNS
- [ ] Configure Istio service mesh

### Phase 3: Data Layer (Week 5)
- [ ] Deploy PostgreSQL clusters (per service)
- [ ] Deploy RabbitMQ cluster
- [ ] Deploy Redis cluster
- [ ] Configure backups

### Phase 4: Observability (Week 6)
- [ ] Deploy Prometheus + Grafana
- [ ] Deploy Loki
- [ ] Deploy Tempo
- [ ] Configure alerting
- [ ] Create dashboards

### Phase 5: Application Deployment (Weeks 7-8)
- [ ] Deploy microservices
- [ ] Configure HPA
- [ ] Set up network policies
- [ ] Enable mTLS
- [ ] Configure monitoring

### Phase 6: Production Hardening (Weeks 9-10)
- [ ] Security audit
- [ ] Performance testing
- [ ] Disaster recovery testing
- [ ] Documentation review
- [ ] Go-live preparation

## References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Terraform Documentation](https://www.terraform.io/docs)
- [Helm Documentation](https://helm.sh/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [CNCF Landscape](https://landscape.cncf.io/)

## Related Documentation

- [02-kubernetes-architecture.md](02-kubernetes-architecture.md) - Detailed Kubernetes configuration
- [03-service-mesh.md](03-service-mesh.md) - Istio service mesh details
- [04-observability-stack.md](04-observability-stack.md) - Monitoring, logging, tracing
- [05-disaster-recovery.md](05-disaster-recovery.md) - DR procedures
- [06-scalability-strategy.md](06-scalability-strategy.md) - Scaling strategies
- [../02-security/05-network-security.md](../02-security/05-network-security.md) - Network security
- [../06-cicd/](../06-cicd/) - CI/CD pipelines

---

**Document Maintainers**: Platform Team, Infrastructure Team
**Review Cycle**: Quarterly or after significant infrastructure changes
**Next Review**: 2025-04-07
