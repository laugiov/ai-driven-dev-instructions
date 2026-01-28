# Kubernetes Architecture

**Document Version**: 1.0
**Last Updated**: 2025-01-07
**Status**: Complete

## Table of Contents

1. [Overview](#overview)
2. [Cluster Architecture](#cluster-architecture)
3. [Node Pools Configuration](#node-pools-configuration)
4. [Namespace Strategy](#namespace-strategy)
5. [Resource Management](#resource-management)
6. [Pod Security](#pod-security)
7. [Storage Configuration](#storage-configuration)
8. [Networking](#networking)
9. [Auto-Scaling](#auto-scaling)
10. [High Availability](#high-availability)
11. [Security Hardening](#security-hardening)
12. [Monitoring and Logging](#monitoring-and-logging)
13. [Backup and Recovery](#backup-and-recovery)
14. [Troubleshooting](#troubleshooting)

## Overview

This document provides detailed Kubernetes architecture and configuration for the AI Workflow Processing Platform. Our Kubernetes cluster is designed for high availability, security, scalability, and operational excellence.

### Kubernetes Version Strategy

- **Production**: Kubernetes 1.28+ (current stable)
- **Upgrade Policy**: Stay N-1 (one version behind latest stable)
- **Testing**: All upgrades tested in staging first
- **Schedule**: Quarterly upgrade reviews

### Cluster Design Principles

1. **Multi-AZ Deployment**: Spread across 3 availability zones
2. **Immutable Infrastructure**: Nodes replaced, never modified
3. **Security by Default**: Pod Security Standards, RBAC, Network Policies
4. **Observable**: Comprehensive metrics, logs, traces
5. **Self-Healing**: Automatic recovery from failures
6. **Cost-Optimized**: Spot instances, auto-scaling, right-sizing

## Cluster Architecture

### Control Plane (Managed)

The control plane is managed by the cloud provider (EKS/AKS/GKE):

```
┌─────────────────────────────────────────────────────────────┐
│                    Control Plane (Managed)                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  API Server  │  │  API Server  │  │  API Server  │      │
│  │    (AZ-1)    │  │    (AZ-2)    │  │    (AZ-3)    │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │              │
│  ┌──────▼──────────────────▼──────────────────▼───────┐     │
│  │              etcd Cluster (HA)                      │     │
│  │         (Automatically backed up)                   │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Controller   │  │  Scheduler   │  │ Cloud Ctrl   │      │
│  │  Manager     │  │              │  │  Manager     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

**Components**:
- **API Server**: RESTful API for cluster management (load balanced)
- **etcd**: Distributed key-value store for cluster state (HA)
- **Scheduler**: Assigns pods to nodes
- **Controller Manager**: Runs controllers (replication, endpoints, etc.)
- **Cloud Controller Manager**: Cloud-specific control loops

### Data Plane (Worker Nodes)

```
┌─────────────────────────────────────────────────────────────┐
│                       Worker Nodes                           │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │           Application Node Pool (Spot)                 │  │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐  ...    │  │
│  │  │  Node 1   │  │  Node 2   │  │  Node 3   │         │  │
│  │  │  (AZ-1)   │  │  (AZ-2)   │  │  (AZ-3)   │         │  │
│  │  │ t3.xlarge │  │ t3.xlarge │  │ t3.xlarge │         │  │
│  │  └───────────┘  └───────────┘  └───────────┘         │  │
│  │  Min: 3  Max: 20  Auto-scaling: Enabled              │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │              Data Node Pool (On-Demand)                │  │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐         │  │
│  │  │  Node 1   │  │  Node 2   │  │  Node 3   │         │  │
│  │  │  (AZ-1)   │  │  (AZ-2)   │  │  (AZ-3)   │         │  │
│  │  │ r5.xlarge │  │ r5.xlarge │  │ r5.xlarge │         │  │
│  │  └───────────┘  └───────────┘  └───────────┘         │  │
│  │  Min: 3  Max: 6  Auto-scaling: Manual                │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │          Infrastructure Node Pool (On-Demand)          │  │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐         │  │
│  │  │  Node 1   │  │  Node 2   │  │  Node 3   │         │  │
│  │  │  (AZ-1)   │  │  (AZ-2)   │  │  (AZ-3)   │         │  │
│  │  │ t3.large  │  │ t3.large  │  │ t3.large  │         │  │
│  │  └───────────┘  └───────────┘  └───────────┘         │  │
│  │  Min: 3  Max: 6  Auto-scaling: Disabled              │  │
│  └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Node Pools Configuration

### 1. Application Node Pool

**Purpose**: Run application microservices (BFF, LLM Agent, Workflow Orchestrator, etc.)

**Terraform Configuration** (AWS EKS):

```hcl
resource "aws_eks_node_group" "application" {
  cluster_name    = aws_eks_cluster.platform.name
  node_group_name = "application-pool"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = 3
    max_size     = 20
    min_size     = 3
  }

  # Use spot instances for cost savings
  capacity_type = "SPOT"

  instance_types = [
    "t3.xlarge",    # 4 vCPU, 16 GB RAM
    "t3a.xlarge",   # AMD variant (cheaper)
  ]

  labels = {
    workload = "application"
    spot     = "true"
  }

  # Allow scheduling on spot instances
  # (no taints, all workloads can schedule here)

  update_config {
    max_unavailable_percentage = 33  # Update 1/3 nodes at a time
  }

  # Spread across AZs
  ami_type = "AL2_x86_64"

  tags = merge(
    var.common_tags,
    {
      Name = "platform-application-pool"
      Pool = "application"
    }
  )
}
```

**Node Specifications**:
- **vCPU**: 4
- **RAM**: 16 GB
- **Disk**: 100 GB gp3 SSD
- **Network**: Up to 5 Gbps
- **Cost**: ~$50/node/month (spot pricing)

**Workloads**: All stateless application services

### 2. Data Node Pool

**Purpose**: Run stateful services (databases, message queues)

**Terraform Configuration**:

```hcl
resource "aws_eks_node_group" "data" {
  cluster_name    = aws_eks_cluster.platform.name
  node_group_name = "data-pool"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = 3
    max_size     = 6
    min_size     = 3
  }

  # Use on-demand for stability (databases need stable nodes)
  capacity_type = "ON_DEMAND"

  instance_types = [
    "r5.xlarge",  # 4 vCPU, 32 GB RAM (memory-optimized)
  ]

  labels = {
    workload = "data"
    spot     = "false"
  }

  # Taint to prevent non-data workloads from scheduling
  taint {
    key    = "workload"
    value  = "data"
    effect = "NO_SCHEDULE"
  }

  update_config {
    max_unavailable = 1  # Update one node at a time
  }

  tags = merge(
    var.common_tags,
    {
      Name = "platform-data-pool"
      Pool = "data"
    }
  )
}
```

**Node Specifications**:
- **vCPU**: 4
- **RAM**: 32 GB (memory-optimized)
- **Disk**: 200 GB gp3 SSD (higher IOPS)
- **Network**: Up to 10 Gbps
- **Cost**: ~$150/node/month

**Workloads**: PostgreSQL, RabbitMQ, Redis, TimescaleDB

### 3. Infrastructure Node Pool

**Purpose**: Run critical infrastructure services (Vault, Keycloak, Kong)

**Terraform Configuration**:

```hcl
resource "aws_eks_node_group" "infrastructure" {
  cluster_name    = aws_eks_cluster.platform.name
  node_group_name = "infrastructure-pool"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = 3
    max_size     = 6
    min_size     = 3
  }

  # On-demand for critical services
  capacity_type = "ON_DEMAND"

  instance_types = [
    "t3.large",  # 2 vCPU, 8 GB RAM
  ]

  labels = {
    workload = "infrastructure"
    spot     = "false"
  }

  taint {
    key    = "workload"
    value  = "infrastructure"
    effect = "NO_SCHEDULE"
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(
    var.common_tags,
    {
      Name = "platform-infrastructure-pool"
      Pool = "infrastructure"
    }
  )
}
```

**Node Specifications**:
- **vCPU**: 2
- **RAM**: 8 GB
- **Disk**: 50 GB gp3 SSD
- **Network**: Up to 5 Gbps
- **Cost**: ~$50/node/month

**Workloads**: Keycloak, Vault, Kong, ArgoCD, Istio control plane

## Namespace Strategy

### Core Namespaces

```yaml
# namespaces.yaml
---
# Application workloads
apiVersion: v1
kind: Namespace
metadata:
  name: application
  labels:
    name: application
    tier: application
    istio-injection: enabled
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted

---
# Data services
apiVersion: v1
kind: Namespace
metadata:
  name: data
  labels:
    name: data
    tier: data
    istio-injection: enabled
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/warn: baseline

---
# Infrastructure services
apiVersion: v1
kind: Namespace
metadata:
  name: infrastructure
  labels:
    name: infrastructure
    tier: infrastructure
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
    tier: observability
    istio-injection: disabled  # Avoid circular dependency
    pod-security.kubernetes.io/enforce: baseline

---
# Service mesh
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

### Resource Quotas

**Application Namespace** (prevent resource exhaustion):

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: application-quota
  namespace: application
spec:
  hard:
    requests.cpu: "50"          # Total CPU requests
    requests.memory: "100Gi"    # Total memory requests
    limits.cpu: "100"           # Total CPU limits
    limits.memory: "200Gi"      # Total memory limits
    pods: "100"                 # Max pods
    services: "50"              # Max services
    persistentvolumeclaims: "20"  # Max PVCs
    requests.storage: "500Gi"   # Total storage
```

### Limit Ranges

**Application Namespace** (default resource limits):

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: application-limits
  namespace: application
spec:
  limits:
  # Container defaults
  - type: Container
    default:
      cpu: "1"
      memory: "1Gi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    max:
      cpu: "4"
      memory: "8Gi"
    min:
      cpu: "50m"
      memory: "64Mi"

  # Pod limits
  - type: Pod
    max:
      cpu: "8"
      memory: "16Gi"
    min:
      cpu: "50m"
      memory: "64Mi"

  # PVC limits
  - type: PersistentVolumeClaim
    max:
      storage: "100Gi"
    min:
      storage: "1Gi"
```

## Resource Management

### Pod Resource Specifications

Every pod **must** specify requests and limits:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llm-agent-service
  namespace: application
spec:
  replicas: 3
  selector:
    matchLabels:
      app: llm-agent-service
  template:
    metadata:
      labels:
        app: llm-agent-service
        version: v1.2.3
    spec:
      # Scheduling preferences
      affinity:
        # Spread across nodes
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: llm-agent-service
              topologyKey: kubernetes.io/hostname

        # Spread across zones
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: llm-agent-service
              topologyKey: topology.kubernetes.io/zone

        # Prefer application nodes
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: workload
                operator: In
                values:
                - application

      # Security context
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault

      containers:
      - name: llm-agent
        image: platform/llm-agent-service:v1.2.3
        imagePullPolicy: IfNotPresent

        # Security context
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop:
            - ALL

        # Resource management
        resources:
          requests:
            cpu: "500m"      # 0.5 CPU guaranteed
            memory: "1Gi"    # 1 GB RAM guaranteed
            ephemeral-storage: "1Gi"
          limits:
            cpu: "2"         # Can burst to 2 CPUs
            memory: "2Gi"    # Hard limit 2 GB
            ephemeral-storage: "2Gi"

        # Health checks
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 3

        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 3

        startupProbe:
          httpGet:
            path: /health/startup
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 0
          periodSeconds: 10
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 30  # 5 minutes total

        # Environment variables
        env:
        - name: APP_ENV
          value: production
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: llm-agent-db-credentials
              key: url
        - name: VAULT_ADDR
          value: "http://vault.infrastructure:8200"

        # Ports
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        - name: metrics
          containerPort: 9090
          protocol: TCP

        # Volume mounts
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/var/cache

      # Volumes
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}

      # Service account
      serviceAccountName: llm-agent-service

      # DNS config
      dnsPolicy: ClusterFirst

      # Termination grace period
      terminationGracePeriodSeconds: 30

      # Image pull secrets (if using private registry)
      imagePullSecrets:
      - name: registry-credentials
```

### Quality of Service Classes

Kubernetes assigns QoS classes based on resource specifications:

**Guaranteed** (highest priority):
```yaml
resources:
  requests:
    cpu: "1"
    memory: "2Gi"
  limits:
    cpu: "1"       # Same as request
    memory: "2Gi"  # Same as request
```

**Burstable** (medium priority):
```yaml
resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "2"       # Higher than request
    memory: "4Gi"  # Higher than request
```

**BestEffort** (lowest priority - avoid):
```yaml
# No resources specified - NOT RECOMMENDED
```

**Recommendation**: Use **Burstable** for most applications (allows efficient resource utilization).

## Pod Security

### Pod Security Standards

We enforce **Restricted** profile for application namespaces:

```yaml
# Enforced via namespace labels (see Namespace Strategy above)
pod-security.kubernetes.io/enforce: restricted
pod-security.kubernetes.io/audit: restricted
pod-security.kubernetes.io/warn: restricted
```

**Restricted Profile Requirements**:
- ✅ Must run as non-root
- ✅ Must drop ALL capabilities
- ✅ No privilege escalation
- ✅ Read-only root filesystem (when possible)
- ✅ Seccomp profile required
- ✅ No host namespaces
- ✅ No host ports
- ✅ No host paths

### Service Accounts

Every deployment uses a dedicated service account:

```yaml
# Service account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: llm-agent-service
  namespace: application
  annotations:
    # Vault integration
    vault.hashicorp.com/role: "llm-agent-service"

automountServiceAccountToken: true

---
# Role (namespace-scoped permissions)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: llm-agent-service
  namespace: application
rules:
# Read ConfigMaps
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]

# Read Secrets (only specific ones)
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["llm-agent-db-credentials"]
  verbs: ["get"]

---
# RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: llm-agent-service
  namespace: application
subjects:
- kind: ServiceAccount
  name: llm-agent-service
  namespace: application
roleRef:
  kind: Role
  name: llm-agent-service
  apiGroup: rbac.authorization.k8s.io
```

## Storage Configuration

### Storage Classes

```yaml
# High-performance SSD for databases
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: ebs.csi.aws.com  # Or disk.csi.azure.com, pd.csi.storage.gke.io
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
  kmsKeyId: "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Retain

---
# Standard SSD (default)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard-ssd
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete

---
# Shared filesystem (EFS/Azure Files/Filestore)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: shared-filesystem
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-12345678
  directoryPerms: "700"
  uid: "1000"
  gid: "1000"
volumeBindingMode: Immediate
reclaimPolicy: Retain
```

### Persistent Volume Claims

```yaml
# PostgreSQL PVC
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

### Volume Snapshots

```yaml
# Snapshot class
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-snapshots
driver: ebs.csi.aws.com
deletionPolicy: Retain

---
# Create snapshot
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: postgres-snapshot-daily
  namespace: data
spec:
  volumeSnapshotClassName: csi-snapshots
  source:
    persistentVolumeClaimName: postgres-llm-agent-pvc
```

## Networking

### CNI Plugin

**Recommended**: Calico or Cilium

**Calico Installation**:
```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

**Cilium Installation** (eBPF mode):
```bash
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --version 1.14.5 \
  --namespace kube-system \
  --set eni.enabled=true \
  --set ipam.mode=eni \
  --set egressMasqueradeInterfaces=eth0 \
  --set routingMode=native
```

### Service Types

**ClusterIP** (internal only):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: llm-agent-service
  namespace: application
spec:
  type: ClusterIP
  clusterIP: None  # Headless service for StatefulSet
  selector:
    app: llm-agent-service
  ports:
  - name: http
    port: 8080
    targetPort: 8080
    protocol: TCP
  - name: metrics
    port: 9090
    targetPort: 9090
    protocol: TCP
```

**LoadBalancer** (external access):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: istio-ingressgateway
  namespace: istio-system
  annotations:
    # AWS annotations
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
spec:
  type: LoadBalancer
  selector:
    app: istio-ingressgateway
  ports:
  - name: http
    port: 80
    targetPort: 8080
  - name: https
    port: 443
    targetPort: 8443
```

### Network Policies

See [../02-security/05-network-security.md](../02-security/05-network-security.md) for complete network policy configuration.

## Auto-Scaling

### Horizontal Pod Autoscaler (HPA)

```yaml
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
  # CPU utilization
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70

  # Memory utilization
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80

  # Custom metric: RabbitMQ queue length
  - type: External
    external:
      metric:
        name: rabbitmq_queue_messages
        selector:
          matchLabels:
            queue: llm-agent-tasks
      target:
        type: AverageValue
        averageValue: "10"

  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
      - type: Pods
        value: 2
        periodSeconds: 60
      selectPolicy: Min

    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
      - type: Pods
        value: 4
        periodSeconds: 60
      selectPolicy: Max
```

### Cluster Autoscaler

```yaml
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
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
      - name: cluster-autoscaler
        image: registry.k8s.io/autoscaling/cluster-autoscaler:v1.28.0
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/platform-cluster
        - --balance-similar-node-groups
        - --skip-nodes-with-system-pods=false
        - --scale-down-delay-after-add=5m
        - --scale-down-unneeded-time=5m
        - --scale-down-utilization-threshold=0.5
        resources:
          requests:
            cpu: 100m
            memory: 300Mi
          limits:
            cpu: 1000m
            memory: 1Gi
```

### Vertical Pod Autoscaler (VPA)

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
    updateMode: "Off"  # Recommendation only

  resourcePolicy:
    containerPolicies:
    - containerName: llm-agent
      minAllowed:
        cpu: 100m
        memory: 256Mi
      maxAllowed:
        cpu: 4
        memory: 8Gi
      controlledResources:
      - cpu
      - memory
```

## High Availability

### Pod Disruption Budgets

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: llm-agent-pdb
  namespace: application
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: llm-agent-service
```

### Multi-AZ Topology

```yaml
# Topology spread constraints
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llm-agent-service
spec:
  template:
    spec:
      topologySpreadConstraints:
      # Spread across zones
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: llm-agent-service

      # Spread across nodes
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app: llm-agent-service
```

## Security Hardening

### RBAC Policies

```yaml
# Cluster-wide: No one has cluster-admin in production
# Each service has minimal permissions via dedicated ServiceAccount

# Example: Read-only user
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: readonly-user
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets"]
  verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: readonly-users
subjects:
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: readonly-user
  apiGroup: rbac.authorization.k8s.io
```

### API Server Hardening

Managed clusters (EKS/AKS/GKE) come with security hardening by default:
- ✅ Anonymous auth disabled
- ✅ RBAC enabled
- ✅ Audit logging enabled
- ✅ Admission controllers enabled
- ✅ Encryption at rest (etcd)
- ✅ TLS for all communication

### Admission Controllers

```yaml
# (Managed by cloud provider, but for reference)
--enable-admission-plugins=NodeRestriction,PodSecurity,LimitRanger,ResourceQuota,MutatingAdmissionWebhook,ValidatingAdmissionWebhook
```

## Monitoring and Logging

### Metrics Server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Verify:
```bash
kubectl top nodes
kubectl top pods -n application
```

### Prometheus ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: llm-agent-metrics
  namespace: application
spec:
  selector:
    matchLabels:
      app: llm-agent-service
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### Logging

All pods log to stdout/stderr, collected by:
- **Promtail** → Loki (log aggregation)
- **Fluent Bit** → Loki (alternative)

See [04-observability-stack.md](04-observability-stack.md) for complete configuration.

## Backup and Recovery

### etcd Backups

Managed by cloud provider (automatic, every hour).

### Application Data Backups

See [05-disaster-recovery.md](05-disaster-recovery.md) for complete backup strategy.

## Troubleshooting

### Common Issues

**Pods not scheduling**:
```bash
kubectl describe pod <pod-name> -n application
# Check: Events section for reason (resources, taints, affinity)

# Check node resources
kubectl describe nodes | grep -A 5 "Allocated resources"
```

**Pods crashing**:
```bash
kubectl logs <pod-name> -n application --previous
kubectl describe pod <pod-name> -n application
```

**Network connectivity issues**:
```bash
# Test DNS
kubectl run test-pod --rm -it --image=busybox -- nslookup kubernetes.default

# Test service connectivity
kubectl run test-pod --rm -it --image=nicolaka/netshoot -- /bin/bash
curl http://llm-agent-service.application:8080/health
```

**Resource exhaustion**:
```bash
kubectl top nodes
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --sort-by=memory
```

### Useful Commands

```bash
# Get all resources in namespace
kubectl get all -n application

# Watch pod status
kubectl get pods -n application -w

# Get pod YAML
kubectl get pod <pod-name> -n application -o yaml

# Port forward for debugging
kubectl port-forward -n application <pod-name> 8080:8080

# Execute command in pod
kubectl exec -it <pod-name> -n application -- /bin/bash

# Copy files from pod
kubectl cp application/<pod-name>:/app/logs /tmp/logs

# View events
kubectl get events -n application --sort-by='.lastTimestamp'

# View resource usage
kubectl top pod <pod-name> -n application --containers
```

## Best Practices

1. **Always specify resource requests and limits**
2. **Use health checks (liveness, readiness, startup)**
3. **Run as non-root user**
4. **Use read-only root filesystem**
5. **Drop all capabilities**
6. **Use dedicated service accounts**
7. **Implement PodDisruptionBudgets**
8. **Spread pods across AZs**
9. **Use Network Policies**
10. **Monitor everything**

## References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

## Related Documentation

- [01-infrastructure-overview.md](01-infrastructure-overview.md) - Infrastructure overview
- [03-service-mesh.md](03-service-mesh.md) - Istio service mesh
- [04-observability-stack.md](04-observability-stack.md) - Monitoring and logging
- [05-disaster-recovery.md](05-disaster-recovery.md) - Backup and recovery
- [06-scalability-strategy.md](06-scalability-strategy.md) - Scaling strategies

---

**Document Maintainers**: Platform Team, SRE Team
**Review Cycle**: Quarterly or after Kubernetes upgrades
**Next Review**: 2025-04-07
