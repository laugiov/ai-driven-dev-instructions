# Network Security

**Document Version**: 1.0
**Last Updated**: 2025-01-07
**Status**: Complete

## Table of Contents

1. [Overview](#overview)
2. [Network Architecture](#network-architecture)
3. [Service Mesh Security (Istio)](#service-mesh-security-istio)
4. [API Gateway Security (Kong)](#api-gateway-security-kong)
5. [Kubernetes Network Policies](#kubernetes-network-policies)
6. [Transport Layer Security](#transport-layer-security)
7. [Network Segmentation](#network-segmentation)
8. [DDoS Protection](#ddos-protection)
9. [Ingress and Egress Control](#ingress-and-egress-control)
10. [Certificate Management](#certificate-management)
11. [Network Monitoring and Detection](#network-monitoring-and-detection)
12. [Incident Response](#incident-response)
13. [Compliance Requirements](#compliance-requirements)

## Overview

Network security is a critical component of our Zero Trust architecture. This document provides comprehensive guidance on securing network communications across the AI Workflow Processing Platform, covering service mesh configuration, API gateway security, network policies, and traffic encryption.

### Network Security Principles

Our network security strategy is built on these fundamental principles:

1. **Zero Trust**: Never trust, always verify - every network connection must be authenticated and authorized
2. **Defense in Depth**: Multiple layers of security controls to protect against various attack vectors
3. **Least Privilege**: Services can only communicate with explicitly authorized endpoints
4. **Encryption Everywhere**: All traffic encrypted in transit using mTLS or TLS 1.3
5. **Micro-segmentation**: Fine-grained network isolation between services and tenants
6. **Continuous Monitoring**: Real-time visibility into network traffic and anomaly detection
7. **Automated Response**: Automated blocking and mitigation of detected threats
8. **Immutable Infrastructure**: Network policies as code, versioned and auditable

### Network Security Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Internet / Users                             │
└────────────────────────────┬────────────────────────────────────────┘
                             │ HTTPS (TLS 1.3)
                             ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    DDoS Protection Layer                             │
│  - Rate Limiting (10,000 req/min global)                            │
│  - IP Reputation Filtering                                          │
│  - Geo-blocking (configurable)                                      │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    WAF (Web Application Firewall)                    │
│  - OWASP Core Rule Set                                              │
│  - Custom Rules for API Protection                                  │
│  - Bot Detection                                                     │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ↓
┌─────────────────────────────────────────────────────────────────────┐
│               Kubernetes Ingress (Istio Gateway)                     │
│  - TLS Termination                                                   │
│  - Certificate Management (cert-manager)                            │
│  - L7 Load Balancing                                                │
└────────────────────────────┬────────────────────────────────────────┘
                             │ mTLS
                             ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    Kong API Gateway                                  │
│  - Authentication (OAuth2, JWT)                                     │
│  - Rate Limiting (per user/tenant)                                  │
│  - Request/Response Transformation                                  │
│  - API Analytics                                                     │
└────────────────────────────┬────────────────────────────────────────┘
                             │ mTLS
                             ↓
┌─────────────────────────────────────────────────────────────────────┐
│                      Service Mesh (Istio)                            │
│  ┌──────────────┐  mTLS   ┌──────────────┐  mTLS  ┌──────────────┐│
│  │   BFF        │◄────────►│ LLM Agent    │◄───────►│  Workflow    ││
│  │   Service    │          │   Service    │         │ Orchestrator ││
│  └──────────────┘          └──────────────┘         └──────────────┘│
│         │ mTLS                     │ mTLS                   │ mTLS   │
│         ↓                          ↓                        ↓        │
│  ┌──────────────┐          ┌──────────────┐         ┌──────────────┐│
│  │ Validation   │          │ Notification │         │  File        ││
│  │   Service    │          │   Service    │         │  Storage     ││
│  └──────────────┘          └──────────────┘         └──────────────┘│
│                                                                       │
│  Network Policies: Deny All by Default, Allow Specific Routes       │
└─────────────────────────────────────────────────────────────────────┘
```

### Security Layers

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **L7 - Application** | Kong API Gateway | Authentication, authorization, rate limiting |
| **L4-L7 - Service Mesh** | Istio | mTLS, traffic management, observability |
| **L3-L4 - Network** | Kubernetes NetworkPolicy | Firewall rules, pod-to-pod communication |
| **L3 - Network** | Calico/Cilium | Advanced network security, eBPF filtering |
| **DDoS Protection** | CloudFlare/AWS Shield | Volumetric attack mitigation |
| **WAF** | ModSecurity/CloudFlare | OWASP rule set, custom protections |

## Network Architecture

### Network Topology

Our platform uses a multi-tier network architecture with clear security boundaries:

```
External Zone (Untrusted)
    ↓
DMZ Zone (Limited Trust)
  - Istio Ingress Gateway
  - Kong API Gateway
    ↓
Application Zone (Trusted)
  - Microservices (BFF, LLM Agent, Workflow, etc.)
  - Service Mesh (Istio)
    ↓
Data Zone (Highly Trusted)
  - PostgreSQL Databases
  - RabbitMQ
  - Redis Cache
    ↓
Infrastructure Zone (Highly Trusted)
  - Keycloak
  - Vault
  - Monitoring Stack
```

### Kubernetes Network Model

**Pod Network**: Each pod receives a unique IP address from the pod CIDR (10.244.0.0/16)

**Service Network**: Kubernetes Services use a separate CIDR (10.96.0.0/16)

**Node Network**: Physical/virtual node network (varies by cloud provider)

**Network Separation**:
```yaml
# Namespace isolation
apiVersion: v1
kind: Namespace
metadata:
  name: application
  labels:
    name: application
    istio-injection: enabled

---
apiVersion: v1
kind: Namespace
metadata:
  name: data
  labels:
    name: data
    istio-injection: enabled

---
apiVersion: v1
kind: Namespace
metadata:
  name: infrastructure
  labels:
    name: infrastructure
    istio-injection: enabled
```

## Service Mesh Security (Istio)

Istio provides transparent security for service-to-service communication through mutual TLS, fine-grained access control, and comprehensive traffic management.

### Istio Installation

```yaml
# istio-installation.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istio-control-plane
  namespace: istio-system
spec:
  profile: production

  # Control plane configuration
  components:
    pilot:
      k8s:
        resources:
          requests:
            cpu: 500m
            memory: 2Gi
          limits:
            cpu: 2000m
            memory: 4Gi
        replicaCount: 3

    ingressGateways:
    - name: istio-ingressgateway
      enabled: true
      k8s:
        resources:
          requests:
            cpu: 1000m
            memory: 1Gi
          limits:
            cpu: 2000m
            memory: 2Gi
        replicaCount: 3
        service:
          ports:
          - port: 15021
            targetPort: 15021
            name: status-port
          - port: 80
            targetPort: 8080
            name: http2
          - port: 443
            targetPort: 8443
            name: https
        hpaSpec:
          minReplicas: 3
          maxReplicas: 10
          metrics:
          - type: Resource
            resource:
              name: cpu
              targetAverageUtilization: 80

    egressGateways:
    - name: istio-egressgateway
      enabled: true
      k8s:
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        replicaCount: 2

  # Global mesh configuration
  meshConfig:
    # Enable mTLS by default
    enableAutoMtls: true

    # Access logging
    accessLogFile: /dev/stdout
    accessLogEncoding: JSON
    accessLogFormat: |
      {
        "start_time": "%START_TIME%",
        "method": "%REQ(:METHOD)%",
        "path": "%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%",
        "protocol": "%PROTOCOL%",
        "response_code": "%RESPONSE_CODE%",
        "response_flags": "%RESPONSE_FLAGS%",
        "bytes_received": "%BYTES_RECEIVED%",
        "bytes_sent": "%BYTES_SENT%",
        "duration": "%DURATION%",
        "upstream_service_time": "%RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)%",
        "x_forwarded_for": "%REQ(X-FORWARDED-FOR)%",
        "user_agent": "%REQ(USER-AGENT)%",
        "request_id": "%REQ(X-REQUEST-ID)%",
        "authority": "%REQ(:AUTHORITY)%",
        "upstream_host": "%UPSTREAM_HOST%",
        "upstream_cluster": "%UPSTREAM_CLUSTER%"
      }

    # Default configuration
    defaultConfig:
      # Tracing configuration
      tracing:
        sampling: 10.0
        zipkin:
          address: tempo-distributor.observability:9411

      # Holdoff time for pilot updates
      configPath: /etc/istio/proxy
      holdApplicationUntilProxyStarts: true

  # Security values
  values:
    global:
      # Control plane security
      controlPlaneSecurityEnabled: true

      # mTLS configuration
      mtls:
        enabled: true
        auto: true

      # Certificate management
      pilotCertProvider: istiod

      # Trust domain (for SPIFFE identities)
      trustDomain: cluster.local

      # Proxy configuration
      proxy:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi

        # Enable private key provider for enhanced security
        privateKeyProvider:
          cryptomb:
            enabled: true
```

### Mutual TLS (mTLS) Configuration

**Strict mTLS Policy** - Enforce mTLS for all services:

```yaml
# mtls-strict.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default-mtls-strict
  namespace: istio-system
spec:
  # Apply to entire mesh
  mtls:
    mode: STRICT

---
# Per-namespace mTLS
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: application-mtls
  namespace: application
spec:
  mtls:
    mode: STRICT

---
# Per-service mTLS (if needed for specific exceptions)
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: llm-agent-mtls
  namespace: application
spec:
  selector:
    matchLabels:
      app: llm-agent-service
  mtls:
    mode: STRICT

  # Port-level configuration (rarely needed)
  portLevelMtls:
    8080:
      mode: STRICT
```

**DestinationRule for mTLS**:

```yaml
# destination-rule-mtls.yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: default-mtls
  namespace: application
spec:
  # Apply to all hosts in namespace
  host: "*.application.svc.cluster.local"

  trafficPolicy:
    # Enforce mTLS at client side
    tls:
      mode: ISTIO_MUTUAL

    # Connection pool settings
    connectionPool:
      tcp:
        maxConnections: 1000
        connectTimeout: 3s
        tcpKeepalive:
          time: 7200s
          interval: 75s
      http:
        http1MaxPendingRequests: 1024
        http2MaxRequests: 1024
        maxRequestsPerConnection: 100
        maxRetries: 3
        idleTimeout: 3600s

    # Outlier detection for circuit breaking
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
      minHealthPercent: 40
```

### Authorization Policies

**Deny All by Default**:

```yaml
# authorization-deny-all.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all-default
  namespace: application
spec:
  # Empty spec denies all requests by default
  {}
```

**Allow Specific Service-to-Service Communication**:

```yaml
# authorization-bff-to-services.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: bff-to-services
  namespace: application
spec:
  # Apply to LLM Agent Service
  selector:
    matchLabels:
      app: llm-agent-service

  action: ALLOW

  rules:
  # Allow BFF to call LLM Agent Service
  - from:
    - source:
        principals:
        - "cluster.local/ns/application/sa/bff-service"
    to:
    - operation:
        methods: ["POST", "GET"]
        paths:
        - "/api/v1/agents/*"
        - "/api/v1/completions/*"
    when:
    - key: request.headers[x-tenant-id]
      values: ["*"]

  # Allow Workflow Orchestrator to call LLM Agent Service
  - from:
    - source:
        principals:
        - "cluster.local/ns/application/sa/workflow-orchestrator-service"
    to:
    - operation:
        methods: ["POST"]
        paths:
        - "/api/v1/completions/*"
```

**Allow API Gateway to BFF**:

```yaml
# authorization-kong-to-bff.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: kong-to-bff
  namespace: application
spec:
  selector:
    matchLabels:
      app: bff-service

  action: ALLOW

  rules:
  - from:
    - source:
        principals:
        - "cluster.local/ns/infrastructure/sa/kong-gateway"
        namespaces:
        - "infrastructure"
    to:
    - operation:
        methods: ["GET", "POST", "PUT", "PATCH", "DELETE"]
        paths: ["/api/v1/*"]
```

**Allow Monitoring and Health Checks**:

```yaml
# authorization-monitoring.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-monitoring
  namespace: application
spec:
  action: ALLOW

  rules:
  # Allow Prometheus to scrape metrics
  - from:
    - source:
        namespaces:
        - "observability"
        principals:
        - "cluster.local/ns/observability/sa/prometheus"
    to:
    - operation:
        methods: ["GET"]
        paths:
        - "/metrics"
        - "/stats/prometheus"

  # Allow health checks from anywhere (needed for kubelet probes)
  - to:
    - operation:
        methods: ["GET"]
        paths:
        - "/health"
        - "/health/live"
        - "/health/ready"
```

### Request Authentication

**JWT Validation at Service Mesh Level**:

```yaml
# request-authentication-jwt.yaml
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: jwt-auth
  namespace: application
spec:
  # Apply to BFF service (entry point)
  selector:
    matchLabels:
      app: bff-service

  jwtRules:
  - issuer: "https://keycloak.platform.local/realms/platform"
    jwksUri: "https://keycloak.platform.local/realms/platform/protocol/openid-connect/certs"

    # Where to extract JWT from
    fromHeaders:
    - name: "Authorization"
      prefix: "Bearer "

    # Claims to forward to upstream services
    outputClaimToHeaders:
    - header: "x-user-id"
      claim: "sub"
    - header: "x-tenant-id"
      claim: "tenant_id"
    - header: "x-user-roles"
      claim: "roles"

    # JWT validation settings
    forwardOriginalToken: true

  # Allow requests without JWT to reach the service
  # (AuthorizationPolicy will enforce requirements)
```

**Combine with Authorization**:

```yaml
# authorization-jwt-required.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
  namespace: application
spec:
  selector:
    matchLabels:
      app: bff-service

  action: ALLOW

  rules:
  - from:
    - source:
        requestPrincipals: ["*"]
    when:
    - key: request.auth.claims[iss]
      values: ["https://keycloak.platform.local/realms/platform"]
```

### Traffic Management

**Virtual Service for Routing**:

```yaml
# virtual-service-llm-agent.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: llm-agent-service
  namespace: application
spec:
  hosts:
  - llm-agent-service.application.svc.cluster.local

  http:
  # Timeout for all requests
  - timeout: 30s

    # Retry policy
    retries:
      attempts: 3
      perTryTimeout: 10s
      retryOn: "5xx,reset,connect-failure,refused-stream"

    # Route to service
    route:
    - destination:
        host: llm-agent-service.application.svc.cluster.local
        port:
          number: 8080

      # Load balancing
      weight: 100

    # Request headers manipulation
    headers:
      request:
        add:
          x-request-start: "%START_TIME%"
        remove:
        - x-internal-secret
      response:
        add:
          x-served-by: "llm-agent-service"
        remove:
        - x-envoy-upstream-service-time
```

**Circuit Breaking**:

```yaml
# destination-rule-circuit-breaker.yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: llm-agent-circuit-breaker
  namespace: application
spec:
  host: llm-agent-service.application.svc.cluster.local

  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        http2MaxRequests: 100
        maxRequestsPerConnection: 2

    outlierDetection:
      consecutiveErrors: 5
      interval: 10s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
      minHealthPercent: 50
```

## API Gateway Security (Kong)

Kong serves as the primary API Gateway, handling authentication, rate limiting, request transformation, and API analytics.

### Kong Installation

```yaml
# kong-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kong-gateway
  namespace: infrastructure
spec:
  replicas: 3
  selector:
    matchLabels:
      app: kong-gateway
  template:
    metadata:
      labels:
        app: kong-gateway
        version: "3.4"
      annotations:
        sidecar.istio.io/inject: "true"
        prometheus.io/scrape: "true"
        prometheus.io/port: "8100"
    spec:
      serviceAccountName: kong-gateway

      # Anti-affinity to spread across nodes
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: kong-gateway
              topologyKey: kubernetes.io/hostname

      containers:
      - name: kong
        image: kong:3.4-alpine

        env:
        # Database configuration (PostgreSQL)
        - name: KONG_DATABASE
          value: "postgres"
        - name: KONG_PG_HOST
          value: "kong-postgres.infrastructure.svc.cluster.local"
        - name: KONG_PG_PORT
          value: "5432"
        - name: KONG_PG_DATABASE
          value: "kong"
        - name: KONG_PG_USER
          valueFrom:
            secretKeyRef:
              name: kong-postgres-credentials
              key: username
        - name: KONG_PG_PASSWORD
          valueFrom:
            secretKeyRef:
              name: kong-postgres-credentials
              key: password

        # Proxy configuration
        - name: KONG_PROXY_LISTEN
          value: "0.0.0.0:8000 reuseport backlog=16384, 0.0.0.0:8443 http2 ssl reuseport backlog=16384"
        - name: KONG_ADMIN_LISTEN
          value: "127.0.0.1:8001 reuseport backlog=16384"
        - name: KONG_STATUS_LISTEN
          value: "0.0.0.0:8100"

        # Performance tuning
        - name: KONG_NGINX_WORKER_PROCESSES
          value: "auto"
        - name: KONG_NGINX_WORKER_CONNECTIONS
          value: "10240"

        # Security
        - name: KONG_SSL_CIPHER_SUITE
          value: "intermediate"
        - name: KONG_SSL_PROTOCOLS
          value: "TLSv1.2 TLSv1.3"
        - name: KONG_HEADERS
          value: "off"
        - name: KONG_TRUSTED_IPS
          value: "0.0.0.0/0,::/0"
        - name: KONG_REAL_IP_HEADER
          value: "X-Forwarded-For"

        # Logging
        - name: KONG_LOG_LEVEL
          value: "notice"
        - name: KONG_PROXY_ACCESS_LOG
          value: "/dev/stdout"
        - name: KONG_PROXY_ERROR_LOG
          value: "/dev/stderr"

        # Plugins
        - name: KONG_PLUGINS
          value: "bundled,oidc,jwt,rate-limiting,request-transformer,response-transformer,correlation-id,prometheus"

        ports:
        - name: proxy
          containerPort: 8000
          protocol: TCP
        - name: proxy-ssl
          containerPort: 8443
          protocol: TCP
        - name: metrics
          containerPort: 8100
          protocol: TCP

        livenessProbe:
          httpGet:
            path: /status
            port: 8100
          initialDelaySeconds: 30
          periodSeconds: 10

        readinessProbe:
          httpGet:
            path: /status
            port: 8100
          initialDelaySeconds: 10
          periodSeconds: 5

        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 2000m
            memory: 2Gi
```

### Kong Authentication Plugins

**OAuth2/OIDC Plugin**:

```bash
# Apply OIDC plugin to route
curl -X POST http://kong-admin:8001/routes/{route-id}/plugins \
  --data "name=oidc" \
  --data "config.issuer=https://keycloak.platform.local/realms/platform" \
  --data "config.client_id=kong-gateway" \
  --data "config.client_secret=${OIDC_CLIENT_SECRET}" \
  --data "config.redirect_uri=https://api.platform.local/auth/callback" \
  --data "config.scope=openid profile email" \
  --data "config.response_type=code" \
  --data "config.bearer_only=yes" \
  --data "config.logout_path=/auth/logout" \
  --data "config.ssl_verify=yes"
```

**JWT Plugin**:

```bash
# Apply JWT plugin
curl -X POST http://kong-admin:8001/routes/{route-id}/plugins \
  --data "name=jwt" \
  --data "config.key_claim_name=kid" \
  --data "config.secret_is_base64=false" \
  --data "config.claims_to_verify=exp,nbf" \
  --data "config.maximum_expiration=3600" \
  --data "config.header_names=Authorization" \
  --data "config.uri_param_names=jwt"
```

### Kong Rate Limiting

**Global Rate Limiting**:

```bash
# Global rate limit: 10,000 requests per minute
curl -X POST http://kong-admin:8001/plugins \
  --data "name=rate-limiting" \
  --data "config.minute=10000" \
  --data "config.hour=500000" \
  --data "config.policy=cluster" \
  --data "config.fault_tolerant=true" \
  --data "config.hide_client_headers=false"
```

**Per-Consumer Rate Limiting**:

```bash
# Per-user rate limit: 1,000 requests per minute
curl -X POST http://kong-admin:8001/consumers/{consumer-id}/plugins \
  --data "name=rate-limiting" \
  --data "config.minute=1000" \
  --data "config.hour=50000" \
  --data "config.policy=cluster" \
  --data "config.fault_tolerant=true"
```

**Advanced Rate Limiting** (Kong Enterprise):

```bash
# Advanced rate limiting with multiple limits
curl -X POST http://kong-admin:8001/routes/{route-id}/plugins \
  --data "name=rate-limiting-advanced" \
  --data "config.limit[0]=100" \
  --data "config.window_size[0]=60" \
  --data "config.limit[1]=1000" \
  --data "config.window_size[1]=3600" \
  --data "config.identifier=consumer" \
  --data "config.sync_rate=10" \
  --data "config.namespace=platform" \
  --data "config.strategy=cluster" \
  --data "config.dictionary_name=kong_rate_limiting_counters"
```

### Kong Request/Response Transformation

**Remove Sensitive Headers**:

```bash
curl -X POST http://kong-admin:8001/routes/{route-id}/plugins \
  --data "name=request-transformer" \
  --data "config.remove.headers=X-Internal-Secret,X-Admin-Token" \
  --data "config.add.headers=X-Request-ID:\$(uuid),X-Forwarded-At:\$(date)"
```

**Add Security Headers**:

```bash
curl -X POST http://kong-admin:8001/routes/{route-id}/plugins \
  --data "name=response-transformer" \
  --data "config.add.headers=X-Content-Type-Options:nosniff" \
  --data "config.add.headers=X-Frame-Options:DENY" \
  --data "config.add.headers=X-XSS-Protection:1; mode=block" \
  --data "config.add.headers=Strict-Transport-Security:max-age=31536000; includeSubDomains" \
  --data "config.add.headers=Content-Security-Policy:default-src 'self'" \
  --data "config.remove.headers=X-Powered-By,Server"
```

### Kong Service Configuration

```yaml
# kong-services.yaml (declarative configuration)
_format_version: "3.0"

services:
- name: bff-service
  url: http://bff-service.application.svc.cluster.local:8080
  protocol: http
  connect_timeout: 5000
  write_timeout: 60000
  read_timeout: 60000
  retries: 3

  routes:
  - name: bff-api
    paths:
    - /api/v1
    strip_path: false
    protocols:
    - http
    - https

    plugins:
    - name: oidc
      config:
        issuer: https://keycloak.platform.local/realms/platform
        client_id: kong-gateway
        bearer_only: yes

    - name: rate-limiting
      config:
        minute: 1000
        policy: cluster

    - name: correlation-id
      config:
        header_name: X-Correlation-ID
        generator: uuid

    - name: request-transformer
      config:
        add:
          headers:
          - X-Request-Start:$(msec)
        remove:
          headers:
          - X-Internal-Secret

    - name: response-transformer
      config:
        add:
          headers:
          - X-Content-Type-Options:nosniff
          - X-Frame-Options:DENY
        remove:
          headers:
          - X-Powered-By
          - Server

- name: workflow-orchestrator
  url: http://workflow-orchestrator-service.application.svc.cluster.local:8080
  protocol: http

  routes:
  - name: workflow-api
    paths:
    - /api/v1/workflows

    plugins:
    - name: jwt
      config:
        claims_to_verify:
        - exp
        - nbf
        maximum_expiration: 3600
```

## Kubernetes Network Policies

Network Policies provide firewall-like rules for pod-to-pod communication within Kubernetes.

### Default Deny All Policy

```yaml
# network-policy-deny-all.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: application
spec:
  # Apply to all pods
  podSelector: {}

  policyTypes:
  - Ingress
  - Egress

  # Empty ingress/egress rules = deny all
  ingress: []
  egress: []
```

### Allow DNS

```yaml
# network-policy-allow-dns.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: application
spec:
  podSelector: {}

  policyTypes:
  - Egress

  egress:
  # Allow DNS queries to kube-dns/CoreDNS
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    - podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

### Allow Service-to-Service Communication

```yaml
# network-policy-bff-to-services.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: bff-to-services
  namespace: application
spec:
  # Apply to LLM Agent Service
  podSelector:
    matchLabels:
      app: llm-agent-service

  policyTypes:
  - Ingress

  ingress:
  # Allow from BFF Service
  - from:
    - podSelector:
        matchLabels:
          app: bff-service
    ports:
    - protocol: TCP
      port: 8080

  # Allow from Workflow Orchestrator
  - from:
    - podSelector:
        matchLabels:
          app: workflow-orchestrator-service
    ports:
    - protocol: TCP
      port: 8080
```

### Allow Ingress from Kong

```yaml
# network-policy-kong-to-bff.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: kong-to-bff
  namespace: application
spec:
  podSelector:
    matchLabels:
      app: bff-service

  policyTypes:
  - Ingress

  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: infrastructure
    - podSelector:
        matchLabels:
          app: kong-gateway
    ports:
    - protocol: TCP
      port: 8080
```

### Allow Database Access

```yaml
# network-policy-service-to-database.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: service-to-database
  namespace: data
spec:
  # Apply to PostgreSQL pods
  podSelector:
    matchLabels:
      app: postgresql

  policyTypes:
  - Ingress

  ingress:
  # Allow from application services
  - from:
    - namespaceSelector:
        matchLabels:
          name: application
    - podSelector:
        matchLabels:
          database-access: "true"
    ports:
    - protocol: TCP
      port: 5432
```

### Allow Monitoring

```yaml
# network-policy-allow-monitoring.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: application
spec:
  podSelector: {}

  policyTypes:
  - Ingress

  ingress:
  # Allow Prometheus to scrape metrics
  - from:
    - namespaceSelector:
        matchLabels:
          name: observability
    - podSelector:
        matchLabels:
          app: prometheus
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 9090
```

### Egress to External Services

```yaml
# network-policy-egress-openai.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: egress-openai
  namespace: application
spec:
  podSelector:
    matchLabels:
      app: llm-agent-service

  policyTypes:
  - Egress

  egress:
  # Allow HTTPS to OpenAI API
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443

  # Allow DNS
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

## Transport Layer Security

### TLS 1.3 Configuration

**Istio Gateway TLS**:

```yaml
# gateway-tls.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: platform-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway

  servers:
  # HTTPS server
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: platform-tls-cert
      minProtocolVersion: TLSV1_3
      maxProtocolVersion: TLSV1_3
      cipherSuites:
      - TLS_AES_256_GCM_SHA384
      - TLS_AES_128_GCM_SHA256
      - TLS_CHACHA20_POLY1305_SHA256
    hosts:
    - "api.platform.local"
    - "*.platform.local"

  # HTTP redirect to HTTPS
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
    tls:
      httpsRedirect: true
```

### Certificate Management with cert-manager

```yaml
# cert-manager-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: security@platform.local
    privateKeySecretRef:
      name: letsencrypt-prod-private-key
    solvers:
    - http01:
        ingress:
          class: istio
    - dns01:
        cloudDNS:
          project: platform-project
          serviceAccountSecretRef:
            name: clouddns-dns01-solver-svc-acct
            key: key.json
```

**Certificate for Ingress**:

```yaml
# certificate-api.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: platform-tls-cert
  namespace: istio-system
spec:
  secretName: platform-tls-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - api.platform.local
  - "*.platform.local"
  duration: 2160h # 90 days
  renewBefore: 720h # 30 days
```

## Network Segmentation

### Namespace-Based Segmentation

```yaml
# namespace-labels.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: application
  labels:
    name: application
    tier: application
    istio-injection: enabled
    network-zone: trusted

---
apiVersion: v1
kind: Namespace
metadata:
  name: data
  labels:
    name: data
    tier: data
    istio-injection: enabled
    network-zone: highly-trusted

---
apiVersion: v1
kind: Namespace
metadata:
  name: infrastructure
  labels:
    name: infrastructure
    tier: infrastructure
    istio-injection: enabled
    network-zone: trusted

---
apiVersion: v1
kind: Namespace
metadata:
  name: observability
  labels:
    name: observability
    tier: observability
    istio-injection: enabled
    network-zone: trusted
```

### Cross-Namespace Network Policy

```yaml
# network-policy-cross-namespace.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cross-namespace-policy
  namespace: application
spec:
  podSelector: {}

  policyTypes:
  - Ingress
  - Egress

  ingress:
  # Allow from infrastructure namespace (Kong)
  - from:
    - namespaceSelector:
        matchLabels:
          tier: infrastructure
    ports:
    - protocol: TCP
      port: 8080

  egress:
  # Allow to data namespace (databases)
  - to:
    - namespaceSelector:
        matchLabels:
          tier: data
    ports:
    - protocol: TCP
      port: 5432
    - protocol: TCP
      port: 5672
    - protocol: TCP
      port: 6379

  # Allow to infrastructure (Vault, Keycloak)
  - to:
    - namespaceSelector:
        matchLabels:
          tier: infrastructure
    ports:
    - protocol: TCP
      port: 8200 # Vault
    - protocol: TCP
      port: 8080 # Keycloak
```

## DDoS Protection

### Rate Limiting at Multiple Layers

**Layer 7 (Application) - Kong**:
- Global: 10,000 requests/minute
- Per-user: 1,000 requests/minute
- Per-IP: 500 requests/minute

**Layer 4 (Connection) - Istio**:

```yaml
# envoy-filter-connection-limit.yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: connection-limit
  namespace: istio-system
spec:
  workloadSelector:
    labels:
      istio: ingressgateway

  configPatches:
  - applyTo: NETWORK_FILTER
    match:
      context: GATEWAY
      listener:
        filterChain:
          filter:
            name: envoy.filters.network.tcp_proxy
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.network.connection_limit
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.connection_limit.v3.ConnectionLimit
          stat_prefix: connection_limit
          max_connections: 10000
          delay: 1s
```

### IP Reputation Filtering

```yaml
# envoy-filter-ip-reputation.yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: ip-reputation-filter
  namespace: istio-system
spec:
  workloadSelector:
    labels:
      istio: ingressgateway

  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: GATEWAY
      listener:
        filterChain:
          filter:
            name: envoy.filters.network.http_connection_manager
            subFilter:
              name: envoy.filters.http.router
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.lua
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
          inline_code: |
            function envoy_on_request(request_handle)
              local ip = request_handle:headers():get("x-forwarded-for")

              -- Check against blocklist (stored in Redis)
              -- This is a simplified example
              local blocked_ips = {"192.0.2.1", "198.51.100.1"}

              for _, blocked in ipairs(blocked_ips) do
                if ip == blocked then
                  request_handle:respond(
                    {[":status"] = "403"},
                    "Forbidden - IP blocked"
                  )
                  return
                end
              end
            end
```

### Geo-blocking (Optional)

```bash
# Kong IP Restriction plugin for geo-blocking
curl -X POST http://kong-admin:8001/routes/{route-id}/plugins \
  --data "name=ip-restriction" \
  --data "config.allow[]=203.0.113.0/24" \
  --data "config.allow[]=198.51.100.0/24" \
  --data "config.deny[]=192.0.2.0/24"
```

## Ingress and Egress Control

### Istio Ingress Gateway

```yaml
# ingress-gateway.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: platform-ingress
  namespace: istio-system
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
      credentialName: platform-tls-cert
    hosts:
    - "api.platform.local"

---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: platform-routes
  namespace: application
spec:
  hosts:
  - "api.platform.local"

  gateways:
  - istio-system/platform-ingress

  http:
  - match:
    - uri:
        prefix: /api/v1
    route:
    - destination:
        host: kong-gateway.infrastructure.svc.cluster.local
        port:
          number: 8000
```

### Istio Egress Gateway

```yaml
# egress-gateway.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: platform-egress
  namespace: istio-system
spec:
  selector:
    istio: egressgateway

  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - "api.openai.com"
    tls:
      mode: PASSTHROUGH

---
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: openai-external
  namespace: application
spec:
  hosts:
  - api.openai.com

  ports:
  - number: 443
    name: https
    protocol: HTTPS

  location: MESH_EXTERNAL
  resolution: DNS

---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: openai-egress
  namespace: application
spec:
  host: api.openai.com

  trafficPolicy:
    tls:
      mode: SIMPLE

---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: openai-through-egress
  namespace: application
spec:
  hosts:
  - api.openai.com

  gateways:
  - mesh
  - istio-system/platform-egress

  tls:
  - match:
    - gateways:
      - mesh
      port: 443
      sniHosts:
      - api.openai.com
    route:
    - destination:
        host: istio-egressgateway.istio-system.svc.cluster.local
        port:
          number: 443
      weight: 100

  - match:
    - gateways:
      - istio-system/platform-egress
      port: 443
      sniHosts:
      - api.openai.com
    route:
    - destination:
        host: api.openai.com
        port:
          number: 443
      weight: 100
```

## Certificate Management

### Automatic Certificate Rotation

```yaml
# certificate-rotation.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: service-mtls-cert
  namespace: application
spec:
  secretName: service-mtls-cert

  duration: 720h # 30 days
  renewBefore: 168h # 7 days before expiration

  issuerRef:
    name: istio-ca
    kind: ClusterIssuer

  commonName: llm-agent-service.application.svc.cluster.local

  dnsNames:
  - llm-agent-service.application.svc.cluster.local
  - llm-agent-service.application
  - llm-agent-service

  usages:
  - digital signature
  - key encipherment
  - server auth
  - client auth
```

### Certificate Monitoring

```yaml
# prometheus-rule-cert-expiry.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: certificate-expiry-alerts
  namespace: observability
spec:
  groups:
  - name: certificates
    interval: 30s
    rules:
    - alert: CertificateExpiryWarning
      expr: certmanager_certificate_expiration_timestamp_seconds - time() < 604800
      for: 1h
      labels:
        severity: warning
      annotations:
        summary: "Certificate {{ $labels.name }} expiring soon"
        description: "Certificate {{ $labels.name }} in namespace {{ $labels.namespace }} expires in less than 7 days"

    - alert: CertificateExpiryCritical
      expr: certmanager_certificate_expiration_timestamp_seconds - time() < 86400
      for: 15m
      labels:
        severity: critical
      annotations:
        summary: "Certificate {{ $labels.name }} expiring imminently"
        description: "Certificate {{ $labels.name }} in namespace {{ $labels.namespace }} expires in less than 24 hours"
```

## Network Monitoring and Detection

### Network Traffic Monitoring

```yaml
# prometheus-servicemonitor-istio.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: istio-mesh-metrics
  namespace: observability
spec:
  selector:
    matchLabels:
      istio: ingressgateway

  namespaceSelector:
    matchNames:
    - istio-system

  endpoints:
  - port: http-monitoring
    interval: 30s
    path: /stats/prometheus
```

### Anomaly Detection Alerts

```yaml
# prometheus-rule-network-anomalies.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: network-anomaly-alerts
  namespace: observability
spec:
  groups:
  - name: network_anomalies
    interval: 1m
    rules:
    # High error rate
    - alert: HighHTTP5xxRate
      expr: |
        (
          sum(rate(istio_requests_total{response_code=~"5.."}[5m])) by (destination_service)
          /
          sum(rate(istio_requests_total[5m])) by (destination_service)
        ) > 0.05
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High 5xx error rate for {{ $labels.destination_service }}"
        description: "Service {{ $labels.destination_service }} has 5xx error rate above 5% for 5 minutes"

    # Unusual traffic spike
    - alert: TrafficSpike
      expr: |
        (
          rate(istio_requests_total[5m])
          /
          avg_over_time(rate(istio_requests_total[5m])[1h:5m])
        ) > 3
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Unusual traffic spike detected"
        description: "Traffic is 3x higher than usual average"

    # Connection failures
    - alert: HighConnectionFailureRate
      expr: |
        sum(rate(envoy_cluster_upstream_cx_connect_fail[5m])) by (cluster_name) > 1
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High connection failure rate to {{ $labels.cluster_name }}"
        description: "More than 1 connection failure per second to upstream cluster"

    # mTLS violations
    - alert: MTLSViolation
      expr: |
        sum(rate(istio_requests_total{security_policy="mutual_tls",response_code="503"}[5m])) > 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "mTLS policy violation detected"
        description: "Requests are being denied due to mTLS policy violations"
```

### Network Flow Logging

```yaml
# envoy-filter-access-log.yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: detailed-access-log
  namespace: istio-system
spec:
  workloadSelector:
    labels:
      app: bff-service

  configPatches:
  - applyTo: NETWORK_FILTER
    match:
      context: SIDECAR_INBOUND
      listener:
        filterChain:
          filter:
            name: envoy.filters.network.http_connection_manager
    patch:
      operation: MERGE
      value:
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          access_log:
          - name: envoy.access_loggers.file
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.access_loggers.file.v3.FileAccessLog
              path: /dev/stdout
              log_format:
                json_format:
                  start_time: "%START_TIME%"
                  method: "%REQ(:METHOD)%"
                  path: "%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%"
                  protocol: "%PROTOCOL%"
                  response_code: "%RESPONSE_CODE%"
                  response_flags: "%RESPONSE_FLAGS%"
                  bytes_received: "%BYTES_RECEIVED%"
                  bytes_sent: "%BYTES_SENT%"
                  duration: "%DURATION%"
                  upstream_service_time: "%RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)%"
                  x_forwarded_for: "%REQ(X-FORWARDED-FOR)%"
                  user_agent: "%REQ(USER-AGENT)%"
                  request_id: "%REQ(X-REQUEST-ID)%"
                  authority: "%REQ(:AUTHORITY)%"
                  upstream_host: "%UPSTREAM_HOST%"
                  upstream_cluster: "%UPSTREAM_CLUSTER%"
                  upstream_local_address: "%UPSTREAM_LOCAL_ADDRESS%"
                  downstream_local_address: "%DOWNSTREAM_LOCAL_ADDRESS%"
                  downstream_remote_address: "%DOWNSTREAM_REMOTE_ADDRESS%"
                  requested_server_name: "%REQUESTED_SERVER_NAME%"
                  route_name: "%ROUTE_NAME%"
```

## Incident Response

### Automated Response Actions

**Circuit Breaker Activation**:

When service health degrades, circuit breakers automatically prevent cascading failures:

```yaml
# circuit-breaker-aggressive.yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: emergency-circuit-breaker
  namespace: application
spec:
  host: "*.application.svc.cluster.local"

  trafficPolicy:
    outlierDetection:
      consecutiveErrors: 3
      interval: 10s
      baseEjectionTime: 60s
      maxEjectionPercent: 100
      minHealthPercent: 0
```

**IP Blocking**:

```bash
# Automated script triggered by monitoring alerts
#!/bin/bash
# block-malicious-ip.sh

MALICIOUS_IP=$1
DURATION=${2:-3600} # Block for 1 hour by default

# Add to Kong IP restriction plugin
curl -X PATCH http://kong-admin:8001/plugins/${IP_RESTRICTION_PLUGIN_ID} \
  --data "config.deny[]=${MALICIOUS_IP}"

# Add to Istio AuthorizationPolicy
kubectl patch authorizationpolicy block-malicious-ips \
  -n istio-system \
  --type=json \
  -p="[{'op': 'add', 'path': '/spec/rules/0/from/0/source/remoteIpBlocks/-', 'value': '${MALICIOUS_IP}/32'}]"

# Schedule removal after duration
echo "kubectl patch authorizationpolicy block-malicious-ips -n istio-system --type=json -p='[{\"op\": \"remove\", \"path\": \"/spec/rules/0/from/0/source/remoteIpBlocks/-\"}]'" | at now + ${DURATION} seconds
```

### Security Event Playbooks

**DDoS Attack Response**:

1. **Detect**: High request rate, connection exhaustion
2. **Analyze**: Source IPs, patterns, attack vector
3. **Mitigate**:
   - Enable aggressive rate limiting
   - Activate CloudFlare/AWS Shield
   - Block source IPs/ASNs
   - Scale ingress gateways
4. **Monitor**: Watch for mitigation effectiveness
5. **Recover**: Gradually relax restrictions

**mTLS Certificate Compromise**:

1. **Detect**: Unauthorized service access, certificate anomalies
2. **Contain**: Revoke compromised certificate
3. **Investigate**: Identify scope of compromise
4. **Remediate**: Rotate all potentially affected certificates
5. **Strengthen**: Enhanced monitoring, shorter cert lifetimes

## Compliance Requirements

### GDPR Network Requirements

- **Encryption in Transit**: All personal data encrypted with TLS 1.3/mTLS ✅
- **Data Minimization**: Network logs anonymize IP addresses after 90 days
- **Access Controls**: Network policies enforce least privilege ✅
- **Audit Trail**: Complete network flow logs retained for 1 year ✅

### SOC 2 Network Controls

- **CC6.6 - Transmission Protection**: mTLS for all internal, TLS 1.3 for external ✅
- **CC6.7 - Boundaries**: Network segmentation via policies ✅
- **CC6.8 - Network Monitoring**: Continuous traffic analysis ✅
- **CC7.2 - Intrusion Detection**: Anomaly detection alerts ✅

### ISO 27001 Network Security

- **A.13.1.1 - Network Controls**: Documented network policies ✅
- **A.13.1.2 - Network Services**: Service mesh security ✅
- **A.13.1.3 - Network Segregation**: Namespace isolation ✅
- **A.13.2.1 - Information Transfer Policies**: mTLS enforcement ✅

### NIS2 Network Requirements

- **Article 21 - Cybersecurity Risk Management**: Network monitoring, incident detection ✅
- **Network Resilience**: Multi-AZ deployment, redundant gateways ✅
- **Incident Handling**: Automated response, 24h reporting ✅

## Implementation Checklist

### Initial Setup

- [ ] Deploy Istio with mTLS enabled
- [ ] Configure PeerAuthentication policies (STRICT mode)
- [ ] Deploy Kong API Gateway
- [ ] Configure Kong authentication plugins
- [ ] Create default deny NetworkPolicies
- [ ] Configure specific allow NetworkPolicies
- [ ] Set up cert-manager
- [ ] Create TLS certificates for all services
- [ ] Configure Istio ingress/egress gateways
- [ ] Set up rate limiting at all layers

### Security Hardening

- [ ] Enable Istio authorization policies
- [ ] Configure JWT validation
- [ ] Set up DDoS protection (CloudFlare/AWS Shield)
- [ ] Deploy WAF rules
- [ ] Configure circuit breakers
- [ ] Set up IP reputation filtering
- [ ] Enable comprehensive access logging
- [ ] Configure security monitoring alerts

### Operational

- [ ] Document network topology
- [ ] Create incident response playbooks
- [ ] Set up certificate expiry monitoring
- [ ] Configure automated certificate rotation
- [ ] Test failover scenarios
- [ ] Conduct penetration testing
- [ ] Review and update policies quarterly

## Monitoring Dashboards

### Istio Security Dashboard (Grafana)

```json
{
  "dashboard": {
    "title": "Network Security Overview",
    "panels": [
      {
        "title": "mTLS Coverage",
        "targets": [
          {
            "expr": "sum(istio_requests_total{security_policy=\"mutual_tls\"}) / sum(istio_requests_total) * 100"
          }
        ]
      },
      {
        "title": "Connection Failures",
        "targets": [
          {
            "expr": "sum(rate(envoy_cluster_upstream_cx_connect_fail[5m])) by (cluster_name)"
          }
        ]
      },
      {
        "title": "Active Connections",
        "targets": [
          {
            "expr": "sum(envoy_cluster_upstream_cx_active) by (cluster_name)"
          }
        ]
      },
      {
        "title": "Request Rate by Response Code",
        "targets": [
          {
            "expr": "sum(rate(istio_requests_total[5m])) by (response_code)"
          }
        ]
      }
    ]
  }
}
```

## Best Practices

### Network Security Best Practices

1. **Always use mTLS**: Never allow plain HTTP between services
2. **Deny by default**: Start with deny-all policies, add allow rules explicitly
3. **Least privilege**: Services should only communicate with necessary endpoints
4. **Defense in depth**: Multiple layers of security (API Gateway, Service Mesh, Network Policies)
5. **Monitor everything**: Comprehensive logging and alerting for anomalies
6. **Automate response**: Automatic blocking of malicious traffic
7. **Regular testing**: Periodic penetration testing and policy reviews
8. **Certificate rotation**: Short-lived certificates (30 days), automated rotation
9. **Egress control**: All external communication through egress gateway
10. **Traffic encryption**: TLS 1.3 minimum, strong cipher suites only

### Performance Considerations

- **mTLS overhead**: ~5-10% latency increase acceptable for security benefits
- **Connection pooling**: Reduce TLS handshake overhead with persistent connections
- **Certificate caching**: Cache validated certificates to improve performance
- **Monitoring overhead**: Balance security visibility with performance impact

## Troubleshooting

### Common Issues

**mTLS handshake failures**:
```bash
# Check certificate validity
istioctl proxy-config secret -n application llm-agent-pod

# View access logs
kubectl logs -n application llm-agent-pod -c istio-proxy --tail=100 | grep "TLS error"
```

**Network policy blocking legitimate traffic**:
```bash
# Test connectivity
kubectl run test-pod --rm -it --image=nicolaka/netshoot -- /bin/bash
curl -v http://llm-agent-service.application:8080/health

# Check network policy
kubectl describe networkpolicy -n application
```

**Kong authentication failures**:
```bash
# Check plugin configuration
curl http://kong-admin:8001/plugins/${PLUGIN_ID}

# View Kong logs
kubectl logs -n infrastructure kong-gateway-pod --tail=100
```

## References

- [Istio Security Documentation](https://istio.io/latest/docs/concepts/security/)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Kong Gateway Documentation](https://docs.konghq.com/gateway/latest/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [NIST SP 800-125A - Security for Server Virtualization](https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-125a.pdf)
- [Zero Trust Architecture (NIST SP 800-207)](https://csrc.nist.gov/publications/detail/sp/800-207/final)

## Related Documentation

- [02-zero-trust-architecture.md](02-zero-trust-architecture.md) - Overall Zero Trust strategy
- [03-authentication-authorization.md](03-authentication-authorization.md) - Identity and access management
- [04-secrets-management.md](04-secrets-management.md) - Certificate and secret management
- [../01-architecture/06-communication-patterns.md](../01-architecture/06-communication-patterns.md) - Service communication patterns
- [../03-infrastructure/02-kubernetes-architecture.md](../03-infrastructure/02-kubernetes-architecture.md) - Kubernetes infrastructure

---

**Document Maintainers**: Security Team, Platform Team
**Review Cycle**: Quarterly or after significant architecture changes
**Next Review**: 2025-04-07
