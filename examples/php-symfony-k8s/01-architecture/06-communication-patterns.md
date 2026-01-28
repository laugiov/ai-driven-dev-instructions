# Communication Patterns

## Overview

This document defines how microservices communicate with each other in the platform. We use a hybrid approach: synchronous communication (REST/gRPC) for immediate responses and asynchronous communication (events) for loose coupling and resilience.

## Communication Strategy

### Decision Matrix

| Scenario | Pattern | Protocol | Rationale |
|----------|---------|----------|-----------|
| **Client → BFF** | Synchronous | REST/HTTP | User expects immediate response |
| **BFF → Services** | Synchronous | REST/HTTP | Aggregate data for single request |
| **Service → Service (Query)** | Synchronous | REST/HTTP | Need immediate data |
| **Service → Service (Command)** | Asynchronous | Events/RabbitMQ | Loose coupling, eventual consistency |
| **Workflow Orchestration** | Hybrid | REST + Events | Coordination + notifications |
| **Notifications** | Asynchronous | Events/RabbitMQ | Fire-and-forget |
| **Audit Logging** | Asynchronous | Events/RabbitMQ | Non-blocking |
| **High-Performance Internal** | Synchronous | gRPC (optional) | Low latency, binary protocol |

## Synchronous Communication (REST)

### When to Use

✅ **Use REST when**:
- Client needs immediate response
- Request-response pattern fits naturally
- Querying data from another service
- Simple CRUD operations
- Human-facing APIs

❌ **Don't use REST when**:
- Operation is long-running (> 5s)
- Caller doesn't need immediate response
- High volume of calls (consider async)
- Caller should not be blocked

### REST API Design

**Base URL Pattern**:
```
https://api.example.com/api/v1/{service}/{resource}
```

**Example**:
```
GET    /api/v1/workflows/{id}           # Get workflow
POST   /api/v1/workflows                # Create workflow
PUT    /api/v1/workflows/{id}           # Update workflow
DELETE /api/v1/workflows/{id}           # Delete workflow
POST   /api/v1/workflows/{id}/execute   # Execute workflow (action)
```

### HTTP Methods

| Method | Purpose | Idempotent | Safe |
|--------|---------|------------|------|
| **GET** | Retrieve resource | Yes | Yes |
| **POST** | Create resource or action | No | No |
| **PUT** | Replace resource | Yes | No |
| **PATCH** | Partial update | No | No |
| **DELETE** | Delete resource | Yes | No |

### Status Codes

```
Success:
200 OK              - Successful GET, PUT, PATCH, DELETE
201 Created         - Successful POST (resource created)
202 Accepted        - Async operation started
204 No Content      - Successful DELETE (no body)

Client Errors:
400 Bad Request     - Invalid input
401 Unauthorized    - Authentication required
403 Forbidden       - Authenticated but not authorized
404 Not Found       - Resource doesn't exist
409 Conflict        - Conflict with current state
422 Unprocessable   - Validation failed
429 Too Many Requests - Rate limit exceeded

Server Errors:
500 Internal Server Error - Unexpected error
502 Bad Gateway           - Upstream service error
503 Service Unavailable   - Service temporarily down
504 Gateway Timeout       - Upstream service timeout
```

### Request/Response Format

**Standard Success Response**:
```json
{
  "data": {
    "id": "uuid",
    "name": "Workflow Name",
    "status": "active"
  },
  "meta": {
    "timestamp": "2025-01-07T10:30:00Z",
    "requestId": "req-uuid"
  }
}
```

**Standard Error Response**:
```json
{
  "error": {
    "code": "WORKFLOW_NOT_FOUND",
    "message": "Workflow with ID 'uuid' not found",
    "details": {},
    "timestamp": "2025-01-07T10:30:00Z",
    "requestId": "req-uuid",
    "traceId": "trace-uuid"
  }
}
```

### REST Client Implementation

**Symfony HTTP Client**:

```php
// src/Infrastructure/Http/Client/WorkflowServiceClient.php
namespace App\Infrastructure\Http\Client;

use Symfony\Contracts\HttpClient\HttpClientInterface;

final readonly class WorkflowServiceClient
{
    private const BASE_URL = 'http://workflow-service:8080/api/v1';

    public function __construct(
        private HttpClientInterface $httpClient,
    ) {}

    public function getWorkflow(string $workflowId): array
    {
        $response = $this->httpClient->request(
            'GET',
            self::BASE_URL . "/workflows/{$workflowId}",
            [
                'headers' => [
                    'Accept' => 'application/json',
                    'X-Request-ID' => Uuid::v4()->toString(),
                ],
                'timeout' => 5, // 5 seconds timeout
            ]
        );

        if ($response->getStatusCode() === 404) {
            throw new WorkflowNotFoundException($workflowId);
        }

        if ($response->getStatusCode() >= 400) {
            throw new WorkflowServiceException(
                "Workflow service error: {$response->getStatusCode()}"
            );
        }

        return $response->toArray();
    }

    public function executeWorkflow(string $workflowId, array $parameters): array
    {
        $response = $this->httpClient->request(
            'POST',
            self::BASE_URL . "/workflows/{$workflowId}/execute",
            [
                'json' => ['parameters' => $parameters],
                'headers' => [
                    'Content-Type' => 'application/json',
                    'Accept' => 'application/json',
                ],
                'timeout' => 30,
            ]
        );

        return $response->toArray();
    }
}
```

### Service-to-Service Authentication

**mTLS (Mutual TLS)**:
```yaml
# Via Istio service mesh
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT  # All traffic must be mTLS
```

**JWT Tokens (Alternative)**:
```php
public function getWorkflow(string $workflowId): array
{
    $token = $this->jwtProvider->getServiceToken();

    $response = $this->httpClient->request('GET', $url, [
        'headers' => [
            'Authorization' => "Bearer {$token}",
        ],
    ]);
}
```

## Asynchronous Communication (Events)

### When to Use

✅ **Use Events when**:
- Multiple services need to react to same event
- Caller doesn't need immediate response
- Loose coupling is desired
- Operations can be retried
- Fire-and-forget pattern

❌ **Don't use Events when**:
- Caller needs immediate response
- Synchronous transaction required
- Real-time coordination needed

### Event Types

**1. Domain Events** (Internal to service):
```php
// Published when aggregate state changes
class WorkflowStarted implements DomainEventInterface
{
    public function __construct(
        public readonly WorkflowId $workflowId,
        public readonly DateTimeImmutable $occurredAt,
    ) {}
}
```

**2. Integration Events** (Between services):
```php
// Published to event bus for other services
class WorkflowCompletedIntegrationEvent
{
    public function __construct(
        public readonly string $workflowId,
        public readonly string $workflowName,
        public readonly array $result,
        public readonly string $completedAt,
    ) {}

    public function toMessage(): array
    {
        return [
            'eventType' => 'workflow.completed',
            'version' => '1.0',
            'eventId' => Uuid::v4()->toString(),
            'timestamp' => $this->completedAt,
            'payload' => [
                'workflowId' => $this->workflowId,
                'workflowName' => $this->workflowName,
                'result' => $this->result,
            ],
        ];
    }
}
```

### Event Structure

**Standard Event Format**:
```json
{
  "eventId": "uuid",
  "eventType": "workflow.completed",
  "version": "1.0",
  "timestamp": "2025-01-07T10:30:00Z",
  "source": "workflow-service",
  "traceId": "trace-uuid",
  "payload": {
    "workflowId": "uuid",
    "workflowName": "My Workflow",
    "status": "completed",
    "result": {}
  },
  "metadata": {
    "correlationId": "corr-uuid",
    "causationId": "cause-uuid"
  }
}
```

**Event Naming Convention**:
- Past tense: `WorkflowCompleted` not `CompleteWorkflow`
- Specific: `AgentExecutionFailed` not `AgentEvent`
- Namespace: `workflow.completed`, `agent.execution.completed`

### Message Broker: RabbitMQ

**Exchange Types**:

**1. Direct Exchange** (Point-to-point):
```yaml
# Workflow commands
exchange: workflow.commands
routing_key: workflow.execute
queue: workflow-service.commands
```

**2. Topic Exchange** (Pub/Sub with patterns):
```yaml
# All workflow events
exchange: workflow.events
routing_key: workflow.*
queue: audit-service.workflow-events

# Only completion events
routing_key: workflow.completed
queue: notification-service.workflow-completed
```

**3. Fanout Exchange** (Broadcast):
```yaml
# System-wide events
exchange: system.events
queue: audit-service.system-events
queue: monitoring-service.system-events
```

### RabbitMQ Configuration

**Exchange and Queue Setup**:

```php
// src/Infrastructure/Messaging/RabbitMQConfiguration.php
namespace App\Infrastructure\Messaging;

final readonly class RabbitMQConfiguration
{
    public function configure(AMQPChannel $channel): void
    {
        // Declare exchange
        $channel->exchange_declare(
            exchange: 'workflow.events',
            type: 'topic',
            passive: false,
            durable: true,      // Survives broker restart
            auto_delete: false,
        );

        // Declare queue
        $channel->queue_declare(
            queue: 'notification-service.workflow-events',
            passive: false,
            durable: true,
            exclusive: false,
            auto_delete: false,
            arguments: [
                'x-message-ttl' => 86400000,        // 24 hours
                'x-max-length' => 100000,           // Max 100k messages
                'x-dead-letter-exchange' => 'dlx',  // Dead letter exchange
            ]
        );

        // Bind queue to exchange
        $channel->queue_bind(
            queue: 'notification-service.workflow-events',
            exchange: 'workflow.events',
            routing_key: 'workflow.*',
        );
    }
}
```

### Publishing Events

**Using Symfony Messenger**:

```yaml
# config/packages/messenger.yaml
framework:
    messenger:
        transports:
            async:
                dsn: '%env(RABBITMQ_DSN)%'
                options:
                    exchange:
                        name: workflow.events
                        type: topic
                    queues:
                        workflow-events:
                            binding_keys:
                                - workflow.*

        routing:
            'App\Domain\Event\WorkflowCompleted': async
```

**Publishing Code**:

```php
// src/Infrastructure/Messaging/SymfonyMessengerEventPublisher.php
namespace App\Infrastructure\Messaging;

use App\Domain\Event\DomainEventInterface;
use Symfony\Component\Messenger\MessageBusInterface;
use Symfony\Component\Messenger\Stamp\DelayStamp;

final readonly class SymfonyMessengerEventPublisher implements EventPublisherInterface
{
    public function __construct(
        private MessageBusInterface $eventBus,
    ) {}

    public function publish(DomainEventInterface $event): void
    {
        $this->eventBus->dispatch($event);
    }

    public function publishDelayed(DomainEventInterface $event, int $delayMs): void
    {
        $this->eventBus->dispatch($event, [
            new DelayStamp($delayMs),
        ]);
    }
}
```

### Consuming Events

**Message Handler**:

```php
// src/Infrastructure/Messaging/Handler/WorkflowCompletedHandler.php
namespace App\Infrastructure\Messaging\Handler;

use App\Domain\Event\WorkflowCompleted;
use Symfony\Component\Messenger\Attribute\AsMessageHandler;

#[AsMessageHandler]
final readonly class WorkflowCompletedHandler
{
    public function __construct(
        private NotificationService $notificationService,
        private AuditService $auditService,
    ) {}

    public function __invoke(WorkflowCompleted $event): void
    {
        // Send notification
        $this->notificationService->sendWorkflowCompletedNotification(
            $event->workflowId,
            $event->workflowName,
        );

        // Log audit event
        $this->auditService->logEvent(
            eventType: 'workflow.completed',
            resourceId: $event->workflowId->toString(),
            metadata: ['name' => $event->workflowName],
        );
    }
}
```

**Consumer Configuration**:

```yaml
# config/packages/messenger.yaml
framework:
    messenger:
        transports:
            async:
                dsn: '%env(RABBITMQ_DSN)%'
                retry_strategy:
                    max_retries: 3
                    delay: 1000           # 1 second
                    multiplier: 2         # Exponential backoff
                    max_delay: 30000      # 30 seconds max

        failure_transport: failed

        consumers:
            async:
                options:
                    prefetch_count: 10    # Process 10 messages concurrently
```

### Error Handling

**Retry Strategy**:

```php
// Automatic retry with exponential backoff
// Attempt 1: Immediate
// Attempt 2: After 1 second
// Attempt 3: After 2 seconds
// Attempt 4: After 4 seconds
// After max retries → Dead Letter Queue
```

**Dead Letter Queue (DLQ)**:

```yaml
# DLQ for failed messages
arguments:
    x-dead-letter-exchange: 'dlx'
    x-dead-letter-routing-key: 'failed'
```

**DLQ Handler** (Manual inspection):

```php
#[AsMessageHandler(fromTransport: 'failed')]
final class FailedMessageHandler
{
    public function __invoke(object $message): void
    {
        // Log to monitoring system
        $this->logger->critical('Message permanently failed', [
            'message' => $message,
            'class' => get_class($message),
        ]);

        // Alert operations team
        $this->alertingService->sendAlert(
            severity: 'critical',
            message: 'Message in DLQ requires manual intervention',
        );

        // Optionally: Store in database for manual retry
        $this->failedMessageRepository->save($message);
    }
}
```

## Circuit Breaker Pattern

**Purpose**: Prevent cascading failures when downstream service is unavailable.

**States**:
- **Closed**: Normal operation, requests pass through
- **Open**: Service is down, requests fail immediately
- **Half-Open**: Testing if service recovered

**Implementation**:

```php
// src/Infrastructure/Resilience/CircuitBreaker.php
namespace App\Infrastructure\Resilience;

final class CircuitBreaker
{
    private const FAILURE_THRESHOLD = 5;
    private const TIMEOUT_SECONDS = 60;
    private const HALF_OPEN_MAX_REQUESTS = 3;

    private int $failureCount = 0;
    private string $state = 'closed'; // closed, open, half_open
    private ?DateTimeImmutable $openedAt = null;
    private int $halfOpenSuccesses = 0;

    public function execute(callable $operation): mixed
    {
        if ($this->isOpen()) {
            if ($this->shouldAttemptReset()) {
                $this->state = 'half_open';
            } else {
                throw new CircuitBreakerOpenException('Circuit breaker is open');
            }
        }

        try {
            $result = $operation();
            $this->recordSuccess();
            return $result;
        } catch (\Exception $e) {
            $this->recordFailure();
            throw $e;
        }
    }

    private function recordSuccess(): void
    {
        if ($this->state === 'half_open') {
            $this->halfOpenSuccesses++;

            if ($this->halfOpenSuccesses >= self::HALF_OPEN_MAX_REQUESTS) {
                // Service recovered
                $this->state = 'closed';
                $this->failureCount = 0;
                $this->halfOpenSuccesses = 0;
                $this->openedAt = null;
            }
        } else {
            $this->failureCount = 0;
        }
    }

    private function recordFailure(): void
    {
        $this->failureCount++;

        if ($this->failureCount >= self::FAILURE_THRESHOLD) {
            $this->state = 'open';
            $this->openedAt = new DateTimeImmutable();
            $this->halfOpenSuccesses = 0;
        }
    }

    private function isOpen(): bool
    {
        return $this->state === 'open';
    }

    private function shouldAttemptReset(): bool
    {
        if ($this->openedAt === null) {
            return false;
        }

        $now = new DateTimeImmutable();
        $elapsed = $now->getTimestamp() - $this->openedAt->getTimestamp();

        return $elapsed >= self::TIMEOUT_SECONDS;
    }
}
```

**Usage**:

```php
final readonly class WorkflowServiceClient
{
    public function __construct(
        private HttpClientInterface $httpClient,
        private CircuitBreaker $circuitBreaker,
    ) {}

    public function getWorkflow(string $workflowId): array
    {
        return $this->circuitBreaker->execute(function () use ($workflowId) {
            $response = $this->httpClient->request('GET', "/workflows/{$workflowId}");
            return $response->toArray();
        });
    }
}
```

## Retry Pattern

**Exponential Backoff with Jitter**:

```php
// src/Infrastructure/Resilience/RetryPolicy.php
namespace App\Infrastructure\Resilience;

final class RetryPolicy
{
    private const MAX_RETRIES = 3;
    private const BASE_DELAY_MS = 1000;
    private const MAX_DELAY_MS = 30000;

    public function execute(callable $operation): mixed
    {
        $attempt = 0;

        while (true) {
            try {
                return $operation();
            } catch (\Exception $e) {
                $attempt++;

                if ($attempt >= self::MAX_RETRIES) {
                    throw $e;
                }

                if (!$this->isRetryable($e)) {
                    throw $e;
                }

                $this->delay($attempt);
            }
        }
    }

    private function isRetryable(\Exception $e): bool
    {
        // Retry on transient errors only
        return $e instanceof TimeoutException
            || $e instanceof ConnectionException
            || $e instanceof ServiceUnavailableException;
    }

    private function delay(int $attempt): void
    {
        // Exponential backoff: 1s, 2s, 4s, 8s...
        $delay = min(
            self::BASE_DELAY_MS * (2 ** ($attempt - 1)),
            self::MAX_DELAY_MS
        );

        // Add jitter (±25%) to prevent thundering herd
        $jitter = random_int((int)($delay * 0.75), (int)($delay * 1.25));

        usleep($jitter * 1000);
    }
}
```

## Timeout Pattern

**Always Set Timeouts**:

```php
// HTTP client timeout
$response = $this->httpClient->request('GET', $url, [
    'timeout' => 5,           // 5 seconds connection + read timeout
    'max_duration' => 30,     // 30 seconds total operation timeout
]);

// Database query timeout
$this->entityManager->getConnection()->executeQuery(
    'SELECT * FROM large_table',
    [],
    [],
    ['timeout' => 10]  // 10 seconds
);

// Message consumer timeout
$this->consumer->consume([
    'timeout' => 60,  // 60 seconds per message
]);
```

## Rate Limiting

**Token Bucket Algorithm**:

```php
// src/Infrastructure/RateLimit/TokenBucket.php
namespace App\Infrastructure\RateLimit;

final class TokenBucket
{
    private int $tokens;
    private DateTimeImmutable $lastRefill;

    public function __construct(
        private readonly int $capacity,
        private readonly int $refillRate,  // tokens per second
        private readonly CacheInterface $cache,
        private readonly string $key,
    ) {
        $this->restore();
    }

    public function consume(int $tokens = 1): bool
    {
        $this->refill();

        if ($this->tokens >= $tokens) {
            $this->tokens -= $tokens;
            $this->persist();
            return true;
        }

        return false;
    }

    private function refill(): void
    {
        $now = new DateTimeImmutable();
        $elapsed = $now->getTimestamp() - $this->lastRefill->getTimestamp();

        $tokensToAdd = $elapsed * $this->refillRate;
        $this->tokens = min($this->capacity, $this->tokens + $tokensToAdd);
        $this->lastRefill = $now;
    }

    private function persist(): void
    {
        $this->cache->set($this->key, [
            'tokens' => $this->tokens,
            'lastRefill' => $this->lastRefill->getTimestamp(),
        ], ttl: 3600);
    }

    private function restore(): void
    {
        $data = $this->cache->get($this->key);

        if ($data === null) {
            $this->tokens = $this->capacity;
            $this->lastRefill = new DateTimeImmutable();
        } else {
            $this->tokens = $data['tokens'];
            $this->lastRefill = (new DateTimeImmutable())->setTimestamp($data['lastRefill']);
        }
    }
}
```

**API Gateway Rate Limiting** (Kong):

```yaml
# Kong rate limiting plugin
plugins:
  - name: rate-limiting
    config:
      minute: 1000      # 1000 requests per minute per user
      hour: 10000       # 10000 requests per hour per user
      policy: redis     # Use Redis for distributed rate limiting
      redis_host: redis
      redis_port: 6379
      fault_tolerant: true
```

## Correlation and Tracing

**Request ID Propagation**:

```php
// Generate or extract request ID
$requestId = $request->headers->get('X-Request-ID')
    ?? Uuid::v4()->toString();

// Add to response
$response->headers->set('X-Request-ID', $requestId);

// Pass to downstream services
$this->httpClient->request('GET', $url, [
    'headers' => [
        'X-Request-ID' => $requestId,
        'X-Correlation-ID' => $correlationId,
    ],
]);

// Log with request ID
$this->logger->info('Processing request', [
    'requestId' => $requestId,
    'correlationId' => $correlationId,
]);
```

**Distributed Tracing** (OpenTelemetry):

```php
// Start span
$span = $tracer->spanBuilder('workflow.execute')
    ->setSpanKind(SpanKind::KIND_SERVER)
    ->startSpan();

try {
    // Add attributes
    $span->setAttribute('workflow.id', $workflowId);
    $span->setAttribute('workflow.name', $workflowName);

    // Do work
    $result = $this->executeWorkflow($workflowId);

    // Mark success
    $span->setStatus(StatusCode::STATUS_OK);

    return $result;
} catch (\Exception $e) {
    // Mark error
    $span->setStatus(StatusCode::STATUS_ERROR, $e->getMessage());
    $span->recordException($e);
    throw $e;
} finally {
    $span->end();
}
```

## Service Communication Examples

### Example 1: BFF Aggregating Data from Multiple Services

```php
// src/Application/Query/GetWorkflowDashboardHandler.php
final readonly class GetWorkflowDashboardHandler
{
    public function __construct(
        private WorkflowServiceClient $workflowService,
        private ValidationServiceClient $validationService,
        private AuditServiceClient $auditService,
    ) {}

    public function __invoke(GetWorkflowDashboardQuery $query): DashboardDTO
    {
        // Call services in parallel
        $workflowPromise = $this->workflowService->getWorkflowsAsync($query->userId);
        $validationPromise = $this->validationService->getRecentValidationsAsync($query->userId);
        $auditPromise = $this->auditService->getRecentActivityAsync($query->userId);

        // Wait for all responses
        $workflows = $workflowPromise->wait();
        $validations = $validationPromise->wait();
        $recentActivity = $auditPromise->wait();

        // Aggregate
        return new DashboardDTO(
            workflows: $workflows,
            validations: $validations,
            recentActivity: $recentActivity,
        );
    }
}
```

### Example 2: Workflow Orchestrator Coordinating Multiple Services

```php
// Synchronous calls for immediate data
$workflow = $this->workflowService->getWorkflow($workflowId);

foreach ($workflow->getSteps() as $step) {
    if ($step->getType() === 'agent') {
        // Synchronous: Wait for LLM response
        $result = $this->llmAgentService->execute($step->getAgentId(), $input);

        // Synchronous: Validate immediately
        $validation = $this->validationService->validate($result);

        if (!$validation->passed()) {
            // Async: Notify about failure (fire-and-forget)
            $this->eventPublisher->publish(new ValidationFailed($workflowId, $validation));
            throw new ValidationFailedException();
        }

        $input = $result; // Pass to next step
    }
}

// Async: Notify about completion (fire-and-forget)
$this->eventPublisher->publish(new WorkflowCompleted($workflowId));
```

## Performance Considerations

### Batching

**Batch Multiple Operations**:

```php
// ❌ Bad: N individual calls
foreach ($workflowIds as $id) {
    $workflow = $this->workflowService->getWorkflow($id);
}

// ✅ Good: Single batch call
$workflows = $this->workflowService->getWorkflowsBatch($workflowIds);
```

### Caching

**Cache Frequently Accessed Data**:

```php
public function getWorkflow(string $workflowId): Workflow
{
    return $this->cache->get(
        "workflow:{$workflowId}",
        function () use ($workflowId) {
            return $this->workflowService->getWorkflow($workflowId);
        },
        ttl: 300  // 5 minutes
    );
}
```

### Compression

**Enable HTTP Compression**:

```php
$response = $this->httpClient->request('GET', $url, [
    'headers' => [
        'Accept-Encoding' => 'gzip, deflate',
    ],
]);
```

## Monitoring

**Track Communication Metrics**:

```yaml
# Prometheus metrics
- http_request_duration_seconds
- http_requests_total
- rabbitmq_messages_published_total
- rabbitmq_messages_consumed_total
- circuit_breaker_state
- rate_limit_exceeded_total
```

**Alerts**:

```yaml
- alert: HighServiceLatency
  expr: http_request_duration_seconds{quantile="0.95"} > 1
  for: 5m

- alert: ServiceUnavailable
  expr: up{job="workflow-service"} == 0
  for: 1m

- alert: MessageQueueBacklog
  expr: rabbitmq_queue_messages > 10000
  for: 10m
```

## Conclusion

Communication patterns ensure:

✅ **Resilience**: Circuit breakers, retries, timeouts
✅ **Performance**: Caching, batching, compression
✅ **Observability**: Tracing, correlation IDs, metrics
✅ **Scalability**: Async events, message queues
✅ **Loose Coupling**: Event-driven architecture
✅ **Consistency**: Saga pattern for distributed transactions

Use synchronous for queries, asynchronous for commands and notifications.
