# Services Overview

## Table of Contents

1. [Introduction](#introduction)
2. [Microservices Architecture](#microservices-architecture)
3. [Service Catalog](#service-catalog)
4. [Inter-Service Communication](#inter-service-communication)
5. [Service Mesh](#service-mesh)
6. [API Gateway](#api-gateway)
7. [Service Discovery](#service-discovery)
8. [Service Dependencies](#service-dependencies)
9. [Deployment Architecture](#deployment-architecture)

## Introduction

### Purpose

The AI Workflow Processing Platform is built using a microservices architecture, where each service is responsible for a specific business capability. This document provides an overview of all services, their responsibilities, and how they interact.

### Architectural Principles

```yaml
architectural_principles:
  bounded_contexts:
    description: "Each service owns its domain and data"
    implementation: "Domain-Driven Design with clear boundaries"

  single_responsibility:
    description: "One service, one business capability"
    implementation: "Focused, cohesive services"

  autonomy:
    description: "Services can be deployed independently"
    implementation: "Separate databases, independent deployments"

  resilience:
    description: "Failure isolation and graceful degradation"
    implementation: "Circuit breakers, retries, fallbacks"

  scalability:
    description: "Scale services independently"
    implementation: "Kubernetes HPA, resource optimization"

  observability:
    description: "Full visibility into service behavior"
    implementation: "Metrics, logs, traces for all services"
```

## Microservices Architecture

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         External Clients                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Web App    │  │  Mobile App  │  │  Third Party │         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │
└─────────┼──────────────────┼──────────────────┼──────────────────┘
          │                  │                  │
          └──────────────────┴──────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Kong API Gateway                           │
│  • Authentication          • Rate Limiting                       │
│  • Request Routing         • Request Transformation             │
│  • SSL Termination         • API Analytics                      │
└─────────────────────────┬───────────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          │               │               │
          ▼               ▼               ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│Authentication│  │  Workflow    │  │    Agent     │
│   Service    │  │   Engine     │  │   Manager    │
│              │  │              │  │              │
│ • JWT Auth   │  │ • Execution  │  │ • AI Agents  │
│ • OAuth2     │  │ • Scheduling │  │ • Models     │
│ • RBAC       │  │ • State Mgmt │  │ • Prompts    │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                  │
       │                 │                  │
       ▼                 ▼                  ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│Notification  │  │  Analytics   │  │  Integration │
│   Service    │  │   Service    │  │    Hub       │
│              │  │              │  │              │
│ • Email      │  │ • Metrics    │  │ • External   │
│ • SMS        │  │ • Reports    │  │   APIs       │
│ • Push       │  │ • Insights   │  │ • Webhooks   │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                  │
       └─────────────────┴──────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Istio Service Mesh                           │
│  • mTLS Encryption         • Traffic Management                 │
│  • Circuit Breaking        • Load Balancing                     │
│  • Observability           • Fault Injection                    │
└─────────────────────────────────────────────────────────────────┘
                         │
          ┌──────────────┼──────────────┐
          │              │              │
          ▼              ▼              ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  PostgreSQL  │  │    Redis     │  │  RabbitMQ    │
│  (Primary)   │  │    Cache     │  │ Message Bus  │
└──────────────┘  └──────────────┘  └──────────────┘
```

### Architecture Layers

```yaml
architecture_layers:
  presentation_layer:
    components:
      - API Gateway (Kong)
      - Web Application (SPA)
      - Mobile Applications
    responsibilities:
      - Request routing
      - Authentication/Authorization
      - Rate limiting
      - API composition

  application_layer:
    components:
      - Workflow Engine
      - Agent Manager
      - Notification Service
      - Analytics Service
      - Integration Hub
    responsibilities:
      - Business logic
      - Use case orchestration
      - Domain operations
      - Event publishing

  domain_layer:
    components:
      - Domain models
      - Domain services
      - Domain events
      - Value objects
    responsibilities:
      - Core business rules
      - Domain invariants
      - Business validation

  infrastructure_layer:
    components:
      - Repositories
      - External adapters
      - Message handlers
      - Cache adapters
    responsibilities:
      - Data persistence
      - External integrations
      - Technical concerns
      - Cross-cutting concerns
```

## Service Catalog

### Core Services

```yaml
core_services:
  authentication_service:
    name: "Authentication Service"
    version: "v1.0.0"
    language: PHP 8.3
    framework: Symfony 7
    port: 8080
    database: PostgreSQL (auth_db)
    cache: Redis

    responsibilities:
      - User authentication (JWT, OAuth2)
      - User registration and management
      - Role-Based Access Control (RBAC)
      - Session management
      - Password management
      - Multi-factor authentication

    endpoints:
      - POST /api/v1/auth/register
      - POST /api/v1/auth/login
      - POST /api/v1/auth/logout
      - POST /api/v1/auth/refresh
      - GET  /api/v1/auth/me
      - POST /api/v1/auth/forgot-password
      - POST /api/v1/auth/reset-password
      - POST /api/v1/auth/verify-email

    dependencies:
      - Redis (session storage)
      - PostgreSQL (user data)
      - SMTP (email notifications)

    sla:
      availability: 99.99%
      latency_p95: 100ms
      latency_p99: 200ms

  workflow_engine:
    name: "Workflow Engine"
    version: "v1.0.0"
    language: PHP 8.3
    framework: Symfony 7
    port: 8080
    database: PostgreSQL (workflow_db)
    cache: Redis
    message_queue: RabbitMQ

    responsibilities:
      - Workflow definition management
      - Workflow execution orchestration
      - Step execution coordination
      - State management
      - Retry logic
      - Error handling
      - Workflow scheduling

    endpoints:
      - POST   /api/v1/workflows
      - GET    /api/v1/workflows
      - GET    /api/v1/workflows/{id}
      - PUT    /api/v1/workflows/{id}
      - DELETE /api/v1/workflows/{id}
      - POST   /api/v1/workflows/{id}/execute
      - GET    /api/v1/workflows/{id}/executions
      - GET    /api/v1/workflows/{id}/executions/{executionId}
      - POST   /api/v1/workflows/{id}/executions/{executionId}/cancel

    dependencies:
      - Agent Manager (AI agent invocation)
      - Integration Hub (external API calls)
      - Notification Service (alerts)
      - PostgreSQL (workflow data)
      - Redis (execution state cache)
      - RabbitMQ (async execution)

    sla:
      availability: 99.95%
      latency_p95: 300ms
      latency_p99: 500ms
      throughput: 5000 workflows/s

  agent_manager:
    name: "Agent Manager"
    version: "v1.0.0"
    language: PHP 8.3
    framework: Symfony 7
    port: 8080
    database: PostgreSQL (agent_db)
    cache: Redis

    responsibilities:
      - AI agent lifecycle management
      - Model selection and configuration
      - Prompt template management
      - Agent invocation and response handling
      - Token usage tracking
      - Agent performance monitoring
      - Model fallback handling

    endpoints:
      - POST /api/v1/agents
      - GET  /api/v1/agents
      - GET  /api/v1/agents/{id}
      - PUT  /api/v1/agents/{id}
      - DELETE /api/v1/agents/{id}
      - POST /api/v1/agents/{id}/invoke
      - GET  /api/v1/agents/{id}/invocations
      - GET  /api/v1/models
      - GET  /api/v1/prompts

    dependencies:
      - OpenAI API
      - Anthropic API
      - Google AI API
      - PostgreSQL (agent config)
      - Redis (response cache)

    sla:
      availability: 99.9%
      latency_p95: 2000ms (depends on AI provider)
      latency_p99: 5000ms

  notification_service:
    name: "Notification Service"
    version: "v1.0.0"
    language: PHP 8.3
    framework: Symfony 7
    port: 8080
    database: PostgreSQL (notification_db)
    message_queue: RabbitMQ

    responsibilities:
      - Multi-channel notifications (email, SMS, push)
      - Notification templating
      - Delivery scheduling
      - Retry on failure
      - Delivery status tracking
      - User preferences management

    endpoints:
      - POST /api/v1/notifications
      - GET  /api/v1/notifications
      - GET  /api/v1/notifications/{id}
      - POST /api/v1/notifications/{id}/resend
      - GET  /api/v1/notifications/preferences
      - PUT  /api/v1/notifications/preferences

    dependencies:
      - SMTP (SendGrid)
      - SMS (Twilio)
      - Push (Firebase)
      - PostgreSQL (notification log)
      - RabbitMQ (async delivery)

    sla:
      availability: 99.5%
      latency_p95: 1000ms
      latency_p99: 2000ms
      throughput: 10000 notifications/s

  analytics_service:
    name: "Analytics Service"
    version: "v1.0.0"
    language: PHP 8.3
    framework: Symfony 7
    port: 8080
    database: PostgreSQL (analytics_db)
    timeseries_db: TimescaleDB

    responsibilities:
      - Metrics collection and aggregation
      - Usage analytics
      - Performance metrics
      - Business intelligence
      - Report generation
      - Data visualization support

    endpoints:
      - GET /api/v1/analytics/dashboard
      - GET /api/v1/analytics/workflows
      - GET /api/v1/analytics/agents
      - GET /api/v1/analytics/users
      - GET /api/v1/analytics/performance
      - POST /api/v1/analytics/reports
      - GET  /api/v1/analytics/reports/{id}

    dependencies:
      - TimescaleDB (time-series data)
      - PostgreSQL (aggregated data)
      - Redis (query cache)

    sla:
      availability: 99.9%
      latency_p95: 500ms
      latency_p99: 1000ms

  integration_hub:
    name: "Integration Hub"
    version: "v1.0.0"
    language: PHP 8.3
    framework: Symfony 7
    port: 8080
    database: PostgreSQL (integration_db)

    responsibilities:
      - External API integrations
      - OAuth connection management
      - Webhook handling
      - API request/response transformation
      - Rate limit management
      - Integration error handling

    endpoints:
      - POST /api/v1/integrations
      - GET  /api/v1/integrations
      - GET  /api/v1/integrations/{id}
      - PUT  /api/v1/integrations/{id}
      - DELETE /api/v1/integrations/{id}
      - POST /api/v1/integrations/{id}/test
      - POST /api/v1/webhooks/{integrationId}
      - GET  /api/v1/integrations/{id}/logs

    dependencies:
      - External APIs (various)
      - PostgreSQL (integration config)
      - Redis (OAuth tokens)

    sla:
      availability: 99.9%
      latency_p95: 1000ms (depends on external APIs)
      latency_p99: 3000ms
```

## Inter-Service Communication

### Communication Patterns

```yaml
communication_patterns:
  synchronous:
    protocol: HTTP/REST
    use_cases:
      - Direct service-to-service calls
      - Query operations
      - Real-time responses required

    implementation:
      - HTTP/2 with gRPC for performance-critical paths
      - REST for standard CRUD operations
      - Circuit breakers for resilience
      - Retries with exponential backoff

    example:
      workflow_engine → agent_manager:
        method: POST
        endpoint: /api/v1/agents/{id}/invoke
        timeout: 30s
        retries: 3

  asynchronous:
    protocol: Message Queue (RabbitMQ)
    use_cases:
      - Long-running operations
      - Event-driven workflows
      - Decoupled communication
      - Fire-and-forget operations

    implementation:
      - RabbitMQ with topic exchanges
      - Dead letter queues
      - Message persistence
      - At-least-once delivery

    example:
      workflow_engine → notification_service:
        exchange: notifications
        routing_key: workflow.completed
        message:
          workflow_id: "uuid"
          user_id: "uuid"
          status: "completed"

  event_driven:
    protocol: Event Bus (RabbitMQ)
    use_cases:
      - Domain events
      - Cross-service data sync
      - Audit logging
      - Analytics tracking

    implementation:
      - Event sourcing for critical domains
      - Event replay capability
      - Schema versioning
      - Event store (PostgreSQL)

    example:
      event: WorkflowCompleted
      publisher: workflow_engine
      subscribers:
        - analytics_service
        - notification_service
        - audit_service
```

### Service Communication Example

```php
<?php
// src/Infrastructure/Http/Client/AgentManagerClient.php

declare(strict_types=1);

namespace App\Infrastructure\Http\Client;

use Symfony\Contracts\HttpClient\HttpClientInterface;
use Symfony\Contracts\HttpClient\Exception\TransportExceptionInterface;
use Psr\Log\LoggerInterface;

final class AgentManagerClient
{
    private const TIMEOUT = 30;
    private const MAX_RETRIES = 3;

    public function __construct(
        private readonly HttpClientInterface $httpClient,
        private readonly LoggerInterface $logger,
        private readonly string $agentManagerBaseUrl,
    ) {}

    public function invokeAgent(
        string $agentId,
        array $input,
        array $context = []
    ): array {
        $url = sprintf('%s/api/v1/agents/%s/invoke', $this->agentManagerBaseUrl, $agentId);

        $attempt = 0;
        $lastException = null;

        while ($attempt < self::MAX_RETRIES) {
            $attempt++;

            try {
                $response = $this->httpClient->request('POST', $url, [
                    'json' => [
                        'input' => $input,
                        'context' => $context,
                    ],
                    'timeout' => self::TIMEOUT,
                    'headers' => [
                        'Content-Type' => 'application/json',
                        'X-Request-ID' => uniqid('req_', true),
                        'X-Service' => 'workflow-engine',
                    ],
                ]);

                $statusCode = $response->getStatusCode();

                if ($statusCode === 200) {
                    $data = $response->toArray();

                    $this->logger->info('Agent invoked successfully', [
                        'agent_id' => $agentId,
                        'attempt' => $attempt,
                    ]);

                    return $data;
                }

                // Handle retriable errors (503, 429, etc.)
                if (in_array($statusCode, [429, 503, 504], true)) {
                    $this->logger->warning('Retriable error from agent manager', [
                        'agent_id' => $agentId,
                        'status_code' => $statusCode,
                        'attempt' => $attempt,
                    ]);

                    // Exponential backoff
                    $sleepTime = min(pow(2, $attempt) * 1000000, 10000000); // Max 10s
                    usleep($sleepTime);
                    continue;
                }

                // Non-retriable error
                throw new \RuntimeException(
                    sprintf('Agent invocation failed with status %d', $statusCode)
                );

            } catch (TransportExceptionInterface $e) {
                $lastException = $e;

                $this->logger->error('Transport error invoking agent', [
                    'agent_id' => $agentId,
                    'attempt' => $attempt,
                    'error' => $e->getMessage(),
                ]);

                if ($attempt < self::MAX_RETRIES) {
                    $sleepTime = min(pow(2, $attempt) * 1000000, 10000000);
                    usleep($sleepTime);
                    continue;
                }
            }
        }

        throw new \RuntimeException(
            sprintf('Failed to invoke agent after %d attempts', self::MAX_RETRIES),
            0,
            $lastException
        );
    }
}
```

### Event Publishing

```php
<?php
// src/Infrastructure/Event/EventPublisher.php

declare(strict_types=1);

namespace App\Infrastructure\Event;

use App\Domain\Common\DomainEventInterface;
use Symfony\Component\Messenger\MessageBusInterface;
use Psr\Log\LoggerInterface;

final class EventPublisher
{
    public function __construct(
        private readonly MessageBusInterface $eventBus,
        private readonly LoggerInterface $logger,
    ) {}

    public function publish(DomainEventInterface $event): void
    {
        $this->logger->info('Publishing domain event', [
            'event_type' => $event::class,
            'event_id' => $event->getEventId(),
            'aggregate_id' => $event->getAggregateId(),
            'occurred_at' => $event->getOccurredAt()->format('Y-m-d H:i:s'),
        ]);

        try {
            $this->eventBus->dispatch($event);
        } catch (\Throwable $e) {
            $this->logger->error('Failed to publish domain event', [
                'event_type' => $event::class,
                'error' => $e->getMessage(),
            ]);

            throw $e;
        }
    }

    public function publishBatch(array $events): void
    {
        foreach ($events as $event) {
            $this->publish($event);
        }
    }
}

// Domain event example
// src/Domain/Workflow/Event/WorkflowCompletedEvent.php

declare(strict_types=1);

namespace App\Domain\Workflow\Event;

use App\Domain\Common\DomainEventInterface;
use App\Domain\Workflow\WorkflowId;

final class WorkflowCompletedEvent implements DomainEventInterface
{
    public function __construct(
        private readonly string $eventId,
        private readonly WorkflowId $workflowId,
        private readonly string $userId,
        private readonly \DateTimeImmutable $occurredAt,
        private readonly array $metadata = [],
    ) {}

    public function getEventId(): string
    {
        return $this->eventId;
    }

    public function getAggregateId(): string
    {
        return $this->workflowId->toString();
    }

    public function getOccurredAt(): \DateTimeImmutable
    {
        return $this->occurredAt;
    }

    public function toArray(): array
    {
        return [
            'event_id' => $this->eventId,
            'event_type' => 'workflow.completed',
            'workflow_id' => $this->workflowId->toString(),
            'user_id' => $this->userId,
            'occurred_at' => $this->occurredAt->format('c'),
            'metadata' => $this->metadata,
        ];
    }
}
```

## Service Mesh

### Istio Configuration

```yaml
# Service mesh configuration
istio_configuration:
  virtual_services:
    - name: workflow-engine
      hosts:
        - workflow-engine
      http:
        - match:
            - headers:
                user-type:
                  exact: premium
          route:
            - destination:
                host: workflow-engine
                subset: v2
              weight: 100

        - route:
            - destination:
                host: workflow-engine
                subset: v1
              weight: 100

        timeout: 30s
        retries:
          attempts: 3
          perTryTimeout: 10s
          retryOn: 5xx,reset,connect-failure

  destination_rules:
    - name: workflow-engine
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
        - name: v1
          labels:
            version: v1
        - name: v2
          labels:
            version: v2

  peer_authentication:
    name: default
    namespace: platform-production
    mtls:
      mode: STRICT

  authorization_policies:
    - name: workflow-engine-authz
      namespace: platform-production
      selector:
        matchLabels:
          app: workflow-engine
      rules:
        - from:
            - source:
                principals:
                  - cluster.local/ns/platform-production/sa/api-gateway
          to:
            - operation:
                methods: ["GET", "POST", "PUT", "DELETE"]
                paths: ["/api/v1/*"]
```

## API Gateway

### Kong Configuration

```yaml
# Kong API Gateway configuration
kong_configuration:
  services:
    - name: authentication-service
      url: http://authentication-service.platform-production.svc.cluster.local:8080
      retries: 3
      connect_timeout: 5000
      write_timeout: 60000
      read_timeout: 60000

      routes:
        - name: auth-routes
          paths:
            - /api/v1/auth
          strip_path: false
          preserve_host: false

      plugins:
        - name: rate-limiting
          config:
            minute: 60
            hour: 1000
            policy: local

        - name: cors
          config:
            origins: ["*"]
            methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
            headers: ["Accept", "Authorization", "Content-Type"]
            exposed_headers: ["X-Auth-Token"]
            credentials: true
            max_age: 3600

    - name: workflow-engine
      url: http://workflow-engine.platform-production.svc.cluster.local:8080
      retries: 3

      routes:
        - name: workflow-routes
          paths:
            - /api/v1/workflows
          strip_path: false

      plugins:
        - name: jwt
          config:
            key_claim_name: kid
            secret_is_base64: false
            claims_to_verify: ["exp"]

        - name: rate-limiting
          config:
            minute: 120
            hour: 5000
            policy: redis
            redis_host: redis
            redis_port: 6379

        - name: request-transformer
          config:
            add:
              headers:
                - X-Service-Name:workflow-engine
                - X-Request-ID:$(uuid)

        - name: prometheus
          config:
            per_consumer: true

  global_plugins:
    - name: correlation-id
      config:
        header_name: X-Request-ID
        generator: uuid
        echo_downstream: true

    - name: prometheus
      config:
        per_consumer: false
```

## Service Discovery

### Kubernetes Service Discovery

```yaml
# Service discovery via Kubernetes DNS
service_discovery:
  pattern: "{service-name}.{namespace}.svc.cluster.local"

  examples:
    workflow_engine:
      internal: "workflow-engine.platform-production.svc.cluster.local:8080"
      short: "workflow-engine:8080"

    agent_manager:
      internal: "agent-manager.platform-production.svc.cluster.local:8080"
      short: "agent-manager:8080"

    notification_service:
      internal: "notification-service.platform-production.svc.cluster.local:8080"
      short: "notification-service:8080"

  service_definition:
    apiVersion: v1
    kind: Service
    metadata:
      name: workflow-engine
      namespace: platform-production
      labels:
        app: workflow-engine
        tier: backend
    spec:
      type: ClusterIP
      selector:
        app: workflow-engine
      ports:
        - name: http
          port: 8080
          targetPort: 8080
          protocol: TCP
      sessionAffinity: None
```

## Service Dependencies

### Dependency Graph

```
Authentication Service
    ↓ (no dependencies on other services)

Workflow Engine
    ↓ depends on
    ├─ Agent Manager (AI invocation)
    ├─ Integration Hub (external APIs)
    ├─ Notification Service (alerts)
    └─ Analytics Service (metrics)

Agent Manager
    ↓ depends on
    └─ (External AI APIs only)

Notification Service
    ↓ depends on
    └─ (External SMTP/SMS/Push APIs only)

Analytics Service
    ↓ depends on
    ├─ Workflow Engine (data collection)
    ├─ Agent Manager (data collection)
    └─ Authentication Service (user data)

Integration Hub
    ↓ depends on
    └─ (External APIs only)
```

### Dependency Matrix

```yaml
dependency_matrix:
  authentication_service:
    depends_on: []
    depended_by:
      - workflow_engine
      - agent_manager
      - notification_service
      - analytics_service
      - integration_hub

  workflow_engine:
    depends_on:
      - authentication_service (user context)
      - agent_manager (AI invocation)
      - integration_hub (external APIs)
      - notification_service (notifications)
    depended_by:
      - analytics_service

  agent_manager:
    depends_on:
      - authentication_service (user context)
    depended_by:
      - workflow_engine
      - analytics_service

  notification_service:
    depends_on:
      - authentication_service (user preferences)
    depended_by:
      - workflow_engine
      - agent_manager

  analytics_service:
    depends_on:
      - workflow_engine (data)
      - agent_manager (data)
      - authentication_service (user data)
    depended_by: []

  integration_hub:
    depends_on:
      - authentication_service (OAuth tokens)
    depended_by:
      - workflow_engine
```

## Deployment Architecture

### Multi-Region Deployment

```yaml
deployment_regions:
  primary:
    region: us-east-1
    availability_zones: 3
    services:
      - authentication-service (10 replicas)
      - workflow-engine (20 replicas)
      - agent-manager (15 replicas)
      - notification-service (10 replicas)
      - analytics-service (5 replicas)
      - integration-hub (8 replicas)

    databases:
      postgresql_primary: Multi-AZ RDS
      redis_primary: ElastiCache cluster
      rabbitmq: Clustered (3 nodes)

  secondary:
    region: us-west-2
    availability_zones: 3
    mode: Active-Passive (DR)
    services:
      - All services (minimal replicas)

    databases:
      postgresql_replica: Read replica
      redis_replica: Replication enabled
      rabbitmq: Clustered (3 nodes)

  edge_locations:
    - us-east-1
    - us-west-2
    - eu-west-1
    - ap-southeast-1

    cdn: CloudFront
    api_gateway: Kong (regional)
```

### Namespace Organization

```yaml
kubernetes_namespaces:
  platform-production:
    services:
      - authentication-service
      - workflow-engine
      - agent-manager
      - notification-service
      - analytics-service
      - integration-hub

    resource_quotas:
      requests.cpu: "100"
      requests.memory: "200Gi"
      limits.cpu: "200"
      limits.memory: "400Gi"
      persistentvolumeclaims: "50"

  platform-staging:
    services: [same as production]
    resource_quotas:
      requests.cpu: "20"
      requests.memory: "40Gi"

  platform-development:
    services: [same as production]
    resource_quotas:
      requests.cpu: "10"
      requests.memory: "20Gi"

  monitoring:
    services:
      - prometheus
      - grafana
      - loki
      - tempo

  infrastructure:
    services:
      - kong
      - rabbitmq
      - redis
```

## Conclusion

This services overview establishes:

- **Clear service boundaries** with single responsibility
- **Well-defined communication patterns** (sync, async, events)
- **Service mesh** for observability and resilience
- **API Gateway** for external access and cross-cutting concerns
- **Service discovery** via Kubernetes DNS
- **Dependency management** with clear understanding of relationships
- **Multi-region deployment** for high availability

**Next Steps**:
1. Review individual service documentation:
   - [Authentication Service](02-authentication-service.md)
   - [Workflow Engine](03-workflow-engine.md)
   - [Agent Manager](04-agent-manager.md)
   - [Notification Service](05-notification-service.md)
   - [Analytics Service](06-analytics-service.md)
   - [Integration Hub](07-integration-hub.md)

For architecture questions, contact the platform team via #platform-architecture Slack channel.
