# Common Antipatterns

## Table of Contents

1. [Introduction](#introduction)
2. [Domain Model Antipatterns](#domain-model-antipatterns)
3. [Architecture Antipatterns](#architecture-antipatterns)
4. [Database Antipatterns](#database-antipatterns)
5. [API Design Antipatterns](#api-design-antipatterns)
6. [Testing Antipatterns](#testing-antipatterns)
7. [Performance Antipatterns](#performance-antipatterns)
8. [Security Antipatterns](#security-antipatterns)
9. [Code Organization Antipatterns](#code-organization-antipatterns)
10. [Concurrency Antipatterns](#concurrency-antipatterns)

## Introduction

This document catalogs common antipatterns found in software development, particularly in the context of our AI Workflow Processing Platform. Recognizing these antipatterns during code review helps maintain code quality and architectural integrity.

### What is an Antipattern?

An **antipattern** is a common response to a recurring problem that is usually ineffective and risks being highly counterproductive. Unlike patterns (which are effective solutions), antipatterns are solutions that initially seem beneficial but create more problems than they solve.

### How to Use This Document

**During Code Review**: Reference this document to identify antipatterns in submitted code.

**During Development**: Consult this before implementing solutions to avoid common pitfalls.

**During Refactoring**: Use as a guide to identify code that needs improvement.

## Domain Model Antipatterns

### Anemic Domain Model

**Problem**: Domain objects contain only data (getters/setters) with no behavior, while all business logic resides in services.

```php
<?php

// ❌ ANTIPATTERN: Anemic domain model
namespace App\Domain\Agent;

final class Agent
{
    private AgentId $id;
    private string $name;
    private string $status;

    // Only getters and setters, no behavior
    public function getId(): AgentId { return $this->id; }
    public function setId(AgentId $id): void { $this->id = $id; }
    public function getName(): string { return $this->name; }
    public function setName(string $name): void { $this->name = $name; }
    public function getStatus(): string { return $this->status; }
    public function setStatus(string $status): void { $this->status = $status; }
}

// Business logic in service
final class AgentService
{
    public function deactivateAgent(Agent $agent): void
    {
        // Business rules in service instead of domain
        if ($agent->getStatus() === 'active') {
            $agent->setStatus('inactive');
            $agent->setDeactivatedAt(new \DateTimeImmutable());
        }
    }
}

// ✅ CORRECT: Rich domain model
namespace App\Domain\Agent;

final class Agent
{
    private AgentId $id;
    private string $name;
    private AgentStatus $status;
    private ?\DateTimeImmutable $deactivatedAt = null;

    // Business logic in domain
    public function deactivate(): void
    {
        // Domain enforces business rules
        if ($this->status === AgentStatus::Inactive) {
            throw AgentAlreadyInactiveException::for($this->id);
        }

        $this->status = AgentStatus::Inactive;
        $this->deactivatedAt = new \DateTimeImmutable();

        $this->recordEvent(new AgentDeactivated($this->id));
    }

    public function isActive(): bool
    {
        return $this->status === AgentStatus::Active;
    }

    // Encapsulation - no direct setters
    public function getId(): AgentId { return $this->id; }
    public function getName(): string { return $this->name; }
    public function getStatus(): AgentStatus { return $this->status; }
}
```

**Why It's Bad**:
- Business logic scattered across services
- No single source of truth for business rules
- Hard to maintain and test
- Violates encapsulation

**How to Fix**:
- Move business logic into domain entities
- Use methods that express business operations
- Encapsulate state (no setters)
- Enforce invariants in the domain

---

### Primitive Obsession

**Problem**: Using primitive types (string, int, float) instead of value objects for domain concepts.

```php
<?php

// ❌ ANTIPATTERN: Primitive obsession
final class Agent
{
    public function __construct(
        private string $id,          // Should be AgentId
        private string $email,       // Should be Email value object
        private float $temperature,  // Should be Temperature value object
        private int $maxTokens,      // Should be MaxTokens value object
    ) {
        // Validation scattered everywhere
        if ($temperature < 0.0 || $temperature > 2.0) {
            throw new \InvalidArgumentException('Invalid temperature');
        }

        if ($maxTokens < 1 || $maxTokens > 128000) {
            throw new \InvalidArgumentException('Invalid max tokens');
        }
    }

    public function updateTemperature(float $temperature): void
    {
        // Same validation duplicated
        if ($temperature < 0.0 || $temperature > 2.0) {
            throw new \InvalidArgumentException('Invalid temperature');
        }

        $this->temperature = $temperature;
    }
}

// ✅ CORRECT: Value objects for domain concepts
final readonly class Temperature
{
    private const MIN_VALUE = 0.0;
    private const MAX_VALUE = 2.0;

    private function __construct(private float $value)
    {
        if ($value < self::MIN_VALUE || $value > self::MAX_VALUE) {
            throw new \InvalidArgumentException(
                sprintf('Temperature must be between %.1f and %.1f', self::MIN_VALUE, self::MAX_VALUE)
            );
        }
    }

    public static function fromFloat(float $value): self
    {
        return new self($value);
    }

    public function toFloat(): float
    {
        return $this->value;
    }

    public function equals(self $other): bool
    {
        return abs($this->value - $other->value) < 0.001;
    }
}

final readonly class AgentId
{
    private function __construct(private string $value)
    {
        if (!$this->isValidUuid($value)) {
            throw new \InvalidArgumentException("Invalid agent ID: {$value}");
        }
    }

    public static function fromString(string $value): self
    {
        return new self($value);
    }

    public static function generate(): self
    {
        return new self(Uuid::uuid4()->toString());
    }

    public function toString(): string
    {
        return $this->value;
    }

    private function isValidUuid(string $value): bool
    {
        return (bool) preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i', $value);
    }
}

final class Agent
{
    public function __construct(
        private AgentId $id,
        private Email $email,
        private Temperature $temperature,
        private MaxTokens $maxTokens,
    ) {
        // Validation centralized in value objects
    }

    public function updateTemperature(Temperature $temperature): void
    {
        $this->temperature = $temperature;  // Already validated
    }
}
```

**Why It's Bad**:
- Validation logic duplicated
- No type safety for domain concepts
- Easy to pass wrong values
- Hard to add domain logic

**How to Fix**:
- Create value objects for domain concepts
- Centralize validation in value objects
- Make value objects immutable
- Add domain logic to value objects

---

### God Object

**Problem**: A single class that knows too much or does too much.

```php
<?php

// ❌ ANTIPATTERN: God object
final class WorkflowManager
{
    // Knows everything, does everything
    public function __construct(
        private Connection $connection,
        private HttpClientInterface $httpClient,
        private MailerInterface $mailer,
        private LoggerInterface $logger,
        private CacheInterface $cache,
        private EventDispatcherInterface $dispatcher,
        // ... 20 more dependencies
    ) {}

    public function createWorkflow(array $data): string { /* ... */ }
    public function updateWorkflow(string $id, array $data): void { /* ... */ }
    public function deleteWorkflow(string $id): void { /* ... */ }
    public function executeWorkflow(string $id, array $context): array { /* ... */ }
    public function validateWorkflow(string $id): bool { /* ... */ }
    public function publishWorkflow(string $id): void { /* ... */ }
    public function getWorkflowStatistics(string $id): array { /* ... */ }
    public function sendWorkflowNotification(string $id): void { /* ... */ }
    public function exportWorkflow(string $id): string { /* ... */ }
    public function importWorkflow(string $data): string { /* ... */ }
    public function cloneWorkflow(string $id): string { /* ... */ }
    public function archiveWorkflow(string $id): void { /* ... */ }
    // ... 50 more methods
}

// ✅ CORRECT: Separated responsibilities
// Domain
final class Workflow
{
    public function execute(array $context): WorkflowExecution { /* ... */ }
    public function publish(): void { /* ... */ }
    public function validate(): ValidationResult { /* ... */ }
}

// Application - Command handlers
final class CreateWorkflowCommandHandler
{
    public function __construct(
        private WorkflowRepositoryInterface $repository,
        private EventDispatcherInterface $dispatcher,
    ) {}

    public function __invoke(CreateWorkflowCommand $command): string { /* ... */ }
}

final class ExecuteWorkflowCommandHandler
{
    public function __construct(
        private WorkflowRepositoryInterface $repository,
        private WorkflowExecutor $executor,
    ) {}

    public function __invoke(ExecuteWorkflowCommand $command): string { /* ... */ }
}

// Application - Query handlers
final class GetWorkflowStatisticsQueryHandler
{
    public function __construct(
        private Connection $connection,
    ) {}

    public function __invoke(GetWorkflowStatisticsQuery $query): array { /* ... */ }
}

// Infrastructure
final class WorkflowNotificationService
{
    public function __construct(
        private MailerInterface $mailer,
    ) {}

    public function sendExecutionCompleted(WorkflowId $id): void { /* ... */ }
}
```

**Why It's Bad**:
- Hard to understand and maintain
- Too many responsibilities
- Changes affect many areas
- Difficult to test
- Hard to reuse

**How to Fix**:
- Apply Single Responsibility Principle
- Split into multiple focused classes
- Use CQRS pattern (separate commands and queries)
- Delegate to specialized services

## Architecture Antipatterns

### Layer Violation

**Problem**: Higher layers depend on lower layers, or layers are bypassed.

```php
<?php

// ❌ ANTIPATTERN: Domain depends on infrastructure
namespace App\Domain\Agent;

use Doctrine\ORM\EntityManagerInterface;  // Infrastructure dependency!
use Symfony\Component\HttpFoundation\Request;  // Infrastructure dependency!

final class Agent
{
    public function __construct(
        private EntityManagerInterface $em,  // WRONG!
    ) {}

    public function execute(Request $request): string  // WRONG!
    {
        // Domain making HTTP calls directly
        $response = file_get_contents('https://api.openai.com/...');

        // Domain persisting directly
        $this->em->persist($this);
        $this->em->flush();

        return $response;
    }
}

// ✅ CORRECT: Proper layer separation
namespace App\Domain\Agent;

// Domain - no infrastructure dependencies
final class Agent
{
    public function execute(string $input): ExecutionRequest
    {
        // Pure business logic
        if (!$this->isActive()) {
            throw AgentNotExecutableException::dueToStatus($this->id, $this->status);
        }

        return ExecutionRequest::create(
            agentId: $this->id,
            input: $input,
            configuration: $this->getConfiguration()
        );
    }
}

namespace App\Application\Agent\CommandHandler;

// Application - orchestrates use case
final class ExecuteAgentCommandHandler
{
    public function __construct(
        private AgentRepositoryInterface $repository,      // Port
        private LLMServiceInterface $llmService,           // Port
        private EventDispatcherInterface $dispatcher,      // Port
    ) {}

    public function __invoke(ExecuteAgentCommand $command): string
    {
        $agent = $this->repository->findById($command->agentId);
        $executionRequest = $agent->execute($command->input);

        // Infrastructure through interface
        $result = $this->llmService->complete(
            $executionRequest->getPrompt(),
            $executionRequest->getConfiguration()
        );

        $this->repository->save($agent);

        return $result->getId();
    }
}

namespace App\Infrastructure\LLM;

// Infrastructure - implements port
final class OpenAIService implements LLMServiceInterface
{
    public function __construct(
        private HttpClientInterface $client,
        private string $apiKey,
    ) {}

    public function complete(string $prompt, array $configuration): LLMResult
    {
        // HTTP call in infrastructure layer
        $response = $this->client->request('POST', 'https://api.openai.com/...');
        // ...
    }
}
```

**Why It's Bad**:
- Tight coupling between layers
- Hard to test
- Cannot swap implementations
- Violates hexagonal architecture

**How to Fix**:
- Define interfaces (ports) in domain
- Implement interfaces (adapters) in infrastructure
- Application layer orchestrates through ports
- Dependencies point inward

---

### Service Locator

**Problem**: Using a global registry to fetch dependencies instead of dependency injection.

```php
<?php

// ❌ ANTIPATTERN: Service locator
final class AgentService
{
    public function createAgent(string $name, string $model): Agent
    {
        // Fetching dependencies from global registry
        $repository = ServiceLocator::get('agent_repository');
        $dispatcher = ServiceLocator::get('event_dispatcher');
        $logger = ServiceLocator::get('logger');

        $agent = Agent::create(/* ... */);

        $repository->save($agent);
        $dispatcher->dispatch(new AgentCreated($agent->getId()));
        $logger->info('Agent created');

        return $agent;
    }
}

// ✅ CORRECT: Constructor injection
final class AgentService
{
    public function __construct(
        private readonly AgentRepositoryInterface $repository,
        private readonly EventDispatcherInterface $dispatcher,
        private readonly LoggerInterface $logger,
    ) {}

    public function createAgent(string $name, string $model): Agent
    {
        $agent = Agent::create(/* ... */);

        $this->repository->save($agent);
        $this->dispatcher->dispatch(new AgentCreated($agent->getId()));
        $this->logger->info('Agent created');

        return $agent;
    }
}
```

**Why It's Bad**:
- Hidden dependencies
- Hard to test
- Runtime errors instead of compile-time
- Global state

**How to Fix**:
- Use constructor injection
- Make dependencies explicit
- Let DI container manage dependencies

---

### Tight Coupling Between Services

**Problem**: Services directly call each other synchronously, creating tight coupling.

```php
<?php

// ❌ ANTIPATTERN: Tight coupling via HTTP
namespace App\AgentService\Application;

final class ExecuteAgentCommandHandler
{
    public function __construct(
        private HttpClientInterface $httpClient,
    ) {}

    public function __invoke(ExecuteAgentCommand $command): string
    {
        // Execute agent logic...

        // Direct HTTP call to audit service - tight coupling!
        $this->httpClient->request('POST', 'http://audit-service:8080/api/audit', [
            'json' => ['event' => 'agent_executed'],
        ]);

        // Direct HTTP call to notification service
        $this->httpClient->request('POST', 'http://notification-service:8080/api/notify', [
            'json' => ['user_id' => $userId],
        ]);

        // If any service is down, execution fails!

        return $executionId;
    }
}

// ✅ CORRECT: Loose coupling via events
namespace App\AgentService\Application;

final class ExecuteAgentCommandHandler
{
    public function __construct(
        private AgentRepositoryInterface $repository,
        private EventDispatcherInterface $dispatcher,
    ) {}

    public function __invoke(ExecuteAgentCommand $command): string
    {
        // Execute agent logic...

        // Publish event - loosely coupled
        $this->dispatcher->dispatch(new AgentExecutionCompleted(
            agentId: $agentId,
            executionId: $executionId,
            userId: $userId,
            result: $result
        ));

        return $executionId;
    }
}

// Other services subscribe to events
namespace App\AuditService\EventSubscriber;

final class AgentExecutionCompletedSubscriber
{
    public function __invoke(AgentExecutionCompleted $event): void
    {
        // Create audit log asynchronously
        // Service failure doesn't affect agent execution
    }
}

namespace App\NotificationService\EventSubscriber;

final class AgentExecutionCompletedSubscriber
{
    public function __invoke(AgentExecutionCompleted $event): void
    {
        // Send notification asynchronously
    }
}
```

**Why It's Bad**:
- Services cannot operate independently
- Cascade failures
- Difficult to scale
- Synchronous bottlenecks

**How to Fix**:
- Use event-driven architecture
- Communicate through message broker
- Embrace eventual consistency
- Each service can operate independently

## Database Antipatterns

### N+1 Query Problem

**Problem**: Executing N additional queries instead of one efficient query.

```php
<?php

// ❌ ANTIPATTERN: N+1 queries
final class WorkflowListService
{
    public function getUserWorkflows(string $userId): array
    {
        // 1 query to fetch workflows
        $workflows = $this->connection->fetchAllAssociative(
            'SELECT * FROM workflows WHERE user_id = ?',
            [$userId]
        );

        $result = [];
        foreach ($workflows as $workflow) {
            // N queries - one for each workflow!
            $stepCount = $this->connection->fetchOne(
                'SELECT COUNT(*) FROM workflow_steps WHERE workflow_id = ?',
                [$workflow['id']]
            );

            // N more queries!
            $executionCount = $this->connection->fetchOne(
                'SELECT COUNT(*) FROM workflow_executions WHERE workflow_id = ?',
                [$workflow['id']]
            );

            $result[] = [
                'workflow' => $workflow,
                'step_count' => $stepCount,
                'execution_count' => $executionCount,
            ];
        }

        return $result;  // Executed 1 + N + N queries!
    }
}

// ✅ CORRECT: Single efficient query
final class WorkflowListService
{
    public function getUserWorkflows(string $userId): array
    {
        // Single query with JOINs and aggregation
        return $this->connection->fetchAllAssociative(
            'SELECT
                w.id,
                w.name,
                w.description,
                COUNT(DISTINCT ws.id) as step_count,
                COUNT(DISTINCT we.id) as execution_count
             FROM workflows w
             LEFT JOIN workflow_steps ws ON ws.workflow_id = w.id
             LEFT JOIN workflow_executions we ON we.workflow_id = w.id
             WHERE w.user_id = ?
             GROUP BY w.id, w.name, w.description',
            [$userId]
        );
    }
}
```

**Why It's Bad**:
- Extremely slow with large datasets
- Wastes database resources
- Network overhead

**How to Fix**:
- Use JOINs to fetch related data
- Use eager loading
- Batch queries when JOIN not possible
- Profile queries to detect N+1

---

### SELECT * Queries

**Problem**: Selecting all columns when only a few are needed.

```php
<?php

// ❌ ANTIPATTERN: SELECT *
public function getAgentList(string $userId): array
{
    // Fetches all columns including large TEXT fields
    return $this->connection->fetchAllAssociative(
        'SELECT * FROM agents WHERE user_id = ?',
        [$userId]
    );
}

// ✅ CORRECT: Select only needed columns
public function getAgentList(string $userId): array
{
    // Only fetch what's needed for the list view
    return $this->connection->fetchAllAssociative(
        'SELECT id, name, model, status, created_at
         FROM agents
         WHERE user_id = ?',
        [$userId]
    );
}
```

**Why It's Bad**:
- Wastes bandwidth
- Slower queries
- More memory usage
- Breaks when columns added/removed

**How to Fix**:
- Select only needed columns
- Use dedicated DTOs for different views

---

### No Indexes on Foreign Keys

**Problem**: Missing indexes on columns used in WHERE, JOIN, or ORDER BY clauses.

```sql
-- ❌ ANTIPATTERN: No indexes
CREATE TABLE workflow_steps (
    id UUID PRIMARY KEY,
    workflow_id UUID NOT NULL,  -- No index!
    agent_id UUID NOT NULL,     -- No index!
    name VARCHAR(255) NOT NULL,
    order_index INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

-- Query will be slow!
SELECT * FROM workflow_steps WHERE workflow_id = ?;

-- ✅ CORRECT: Indexes on foreign keys and query columns
CREATE TABLE workflow_steps (
    id UUID PRIMARY KEY,
    workflow_id UUID NOT NULL,
    agent_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    order_index INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_workflow FOREIGN KEY (workflow_id)
        REFERENCES workflows(id) ON DELETE CASCADE
);

-- Indexes for common queries
CREATE INDEX idx_workflow_steps_workflow_id
    ON workflow_steps(workflow_id);

CREATE INDEX idx_workflow_steps_agent_id
    ON workflow_steps(agent_id);

CREATE INDEX idx_workflow_steps_workflow_order
    ON workflow_steps(workflow_id, order_index);

-- Queries will be fast!
```

**Why It's Bad**:
- Slow queries
- Full table scans
- Performance degrades with data growth

**How to Fix**:
- Add indexes on foreign keys
- Index columns used in WHERE clauses
- Create composite indexes for common queries
- Use EXPLAIN to analyze queries

## API Design Antipatterns

### Chatty API

**Problem**: Requiring multiple API calls to accomplish a single task.

```php
<?php

// ❌ ANTIPATTERN: Chatty API
// Client needs to make 4 requests to execute workflow:

// 1. Get workflow
GET /api/v1/workflows/{id}

// 2. Get workflow steps
GET /api/v1/workflows/{id}/steps

// 3. Validate each step's agent exists (N requests!)
GET /api/v1/agents/{agent1_id}
GET /api/v1/agents/{agent2_id}
GET /api/v1/agents/{agent3_id}

// 4. Finally execute
POST /api/v1/workflows/{id}/execute

// ✅ CORRECT: Single request with all needed data
POST /api/v1/workflows/{id}/execute
{
  "context": {
    "input": "user input"
  }
}

// Response includes everything needed
{
  "execution_id": "exec-123",
  "status": "running",
  "workflow": {
    "id": "wf-456",
    "name": "My Workflow",
    "steps": [
      {
        "id": "step-1",
        "agent": {
          "id": "agent-1",
          "name": "Agent 1"
        }
      }
    ]
  },
  "links": {
    "self": "/api/v1/executions/exec-123",
    "cancel": "/api/v1/executions/exec-123/cancel"
  }
}
```

**Why It's Bad**:
- High latency (multiple round trips)
- Network overhead
- Complex client code
- Poor mobile performance

**How to Fix**:
- Provide composite endpoints
- Include related data in responses
- Support field selection (GraphQL or sparse fieldsets)
- Batch operations where appropriate

---

### Breaking Changes Without Versioning

**Problem**: Making breaking changes to existing API endpoints.

```php
<?php

// ❌ ANTIPATTERN: Breaking change in existing endpoint
// Before
#[Route('/api/v1/agents', methods: ['POST'])]
public function create(Request $request): JsonResponse
{
    return $this->json([
        'id' => $agentId,
    ], Response::HTTP_CREATED);
}

// After - BREAKING CHANGE!
#[Route('/api/v1/agents', methods: ['POST'])]
public function create(Request $request): JsonResponse
{
    $data = json_decode($request->getContent(), true);

    // Now requires 'temperature' field - breaks existing clients!
    $command = new CreateAgentCommand(
        name: $data['name'],
        model: $data['model'],
        systemPrompt: $data['system_prompt'],
        temperature: $data['temperature'],  // Required field added!
    );

    // Response structure changed - breaks clients!
    return $this->json([
        'agent_id' => $agentId,  // Changed from 'id' to 'agent_id'
        'created_at' => time(),
    ], Response::HTTP_CREATED);
}

// ✅ CORRECT: Backward compatible or new version
// Option 1: Make new field optional (backward compatible)
#[Route('/api/v1/agents', methods: ['POST'])]
public function create(Request $request): JsonResponse
{
    $data = json_decode($request->getContent(), true);

    $command = new CreateAgentCommand(
        name: $data['name'],
        model: $data['model'],
        systemPrompt: $data['system_prompt'],
        temperature: $data['temperature'] ?? 0.7,  // Optional with default
    );

    return $this->json([
        'id' => $agentId,  // Keep existing field
    ], Response::HTTP_CREATED);
}

// Option 2: Create new version for breaking changes
#[Route('/api/v2/agents', methods: ['POST'])]
public function createV2(Request $request): JsonResponse
{
    $data = json_decode($request->getContent(), true);

    $command = new CreateAgentCommand(
        name: $data['name'],
        model: $data['model'],
        systemPrompt: $data['system_prompt'],
        temperature: $data['temperature'],  // Required in v2
    );

    return $this->json([
        'agent_id' => $agentId,  // New field name in v2
        'created_at' => time(),
    ], Response::HTTP_CREATED);
}
```

**Why It's Bad**:
- Breaks existing clients
- No migration path
- Forces simultaneous updates
- Customer frustration

**How to Fix**:
- Version your APIs
- Add fields instead of changing them
- Deprecate gradually
- Maintain backward compatibility

## Testing Antipatterns

### Testing Implementation Details

**Problem**: Tests coupled to implementation rather than behavior.

```php
<?php

// ❌ ANTIPATTERN: Testing implementation details
final class AgentTest extends TestCase
{
    public function test_agent_creation(): void
    {
        $agent = new Agent();

        // Testing private method - implementation detail!
        $reflection = new \ReflectionClass($agent);
        $method = $reflection->getMethod('validateName');
        $method->setAccessible(true);

        $this->assertTrue($method->invoke($agent, 'Valid Name'));

        // Testing private property - implementation detail!
        $property = $reflection->getProperty('recordedEvents');
        $property->setAccessible(true);

        $this->assertCount(1, $property->getValue($agent));
    }
}

// ✅ CORRECT: Testing behavior through public API
final class AgentTest extends TestCase
{
    public function test_it_creates_agent_with_valid_name(): void
    {
        // Arrange
        $name = 'Valid Agent Name';

        // Act
        $agent = Agent::create(
            id: AgentId::generate(),
            userId: 'user-123',
            name: $name,
            model: 'gpt-4',
            systemPrompt: 'Test'
        );

        // Assert behavior, not implementation
        $this->assertSame($name, $agent->getName());
        $this->assertTrue($agent->isActive());
    }

    public function test_it_throws_exception_for_invalid_name(): void
    {
        $this->expectException(\InvalidArgumentException::class);

        Agent::create(
            id: AgentId::generate(),
            userId: 'user-123',
            name: 'AB',  // Too short
            model: 'gpt-4',
            systemPrompt: 'Test'
        );
    }
}
```

**Why It's Bad**:
- Tests break when refactoring
- Hard to maintain
- Doesn't test actual behavior
- False sense of security

**How to Fix**:
- Test public API only
- Test behavior, not implementation
- Focus on inputs and outputs
- Allow refactoring without breaking tests

---

### Fragile Tests

**Problem**: Tests that break easily due to unrelated changes.

```php
<?php

// ❌ ANTIPATTERN: Fragile test
final class AgentApiTest extends WebTestCase
{
    public function test_create_agent(): void
    {
        $client = static::createClient();

        $client->request('POST', '/api/v1/agents', [], [], [
            'CONTENT_TYPE' => 'application/json',
        ], json_encode([
            'name' => 'Test Agent',
            'model' => 'gpt-4',
            'system_prompt' => 'Test',
        ]));

        $response = $client->getResponse();

        // Fragile: Depends on exact JSON structure
        $this->assertJsonStringEqualsJsonString(
            '{"id":"00000000-0000-0000-0000-000000000000","created_at":1234567890}',
            $response->getContent()
        );

        // Fragile: Depends on specific database state
        $this->assertSame(1, $this->countAgentsInDatabase());
    }

    private function countAgentsInDatabase(): int
    {
        return $this->connection->fetchOne('SELECT COUNT(*) FROM agents');
    }
}

// ✅ CORRECT: Robust test
final class AgentApiTest extends WebTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        // Clean state for each test
        $this->connection->executeStatement('TRUNCATE agents CASCADE');
    }

    public function test_create_agent_returns_201_with_agent_id(): void
    {
        $client = static::createClient();

        $client->request('POST', '/api/v1/agents', [], [], [
            'CONTENT_TYPE' => 'application/json',
        ], json_encode([
            'name' => 'Test Agent',
            'model' => 'gpt-4',
            'system_prompt' => 'Test',
        ]));

        $response = $client->getResponse();

        // Test status
        $this->assertResponseStatusCodeSame(Response::HTTP_CREATED);

        // Test structure, not exact values
        $data = json_decode($response->getContent(), true);
        $this->assertArrayHasKey('id', $data);
        $this->assertIsString($data['id']);
        $this->assertMatchesRegularExpression(
            '/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i',
            $data['id']
        );

        // Verify agent was created
        $agent = $this->connection->fetchAssociative(
            'SELECT * FROM agents WHERE id = ?',
            [$data['id']]
        );

        $this->assertNotFalse($agent);
        $this->assertSame('Test Agent', $agent['name']);
    }
}
```

**Why It's Bad**:
- Tests break for unrelated reasons
- High maintenance cost
- Discourages refactoring
- Slows development

**How to Fix**:
- Test behavior, not exact values
- Use test fixtures
- Clean state before each test
- Assert on structure, not content

## Performance Antipatterns

### Premature Optimization

**Problem**: Optimizing code before identifying actual bottlenecks.

```php
<?php

// ❌ ANTIPATTERN: Premature optimization
final class AgentExecutor
{
    // Complex caching added without profiling
    private array $cache = [];
    private array $cacheTimestamps = [];
    private const CACHE_TTL = 300;

    public function execute(AgentId $agentId, string $input): string
    {
        // Complex cache key generation
        $cacheKey = md5($agentId->toString() . $input . time());

        // Check cache
        if (isset($this->cache[$cacheKey])) {
            if (time() - $this->cacheTimestamps[$cacheKey] < self::CACHE_TTL) {
                return $this->cache[$cacheKey];
            }
            unset($this->cache[$cacheKey], $this->cacheTimestamps[$cacheKey]);
        }

        // Execute
        $result = $this->doExecute($agentId, $input);

        // Store in cache
        $this->cache[$cacheKey] = $result;
        $this->cacheTimestamps[$cacheKey] = time();

        // Evict old cache entries
        foreach ($this->cacheTimestamps as $key => $timestamp) {
            if (time() - $timestamp >= self::CACHE_TTL) {
                unset($this->cache[$key], $this->cacheTimestamps[$key]);
            }
        }

        return $result;
    }
}

// ✅ CORRECT: Simple, readable code first
final class AgentExecutor
{
    public function execute(AgentId $agentId, string $input): string
    {
        $agent = $this->repository->findById($agentId);

        if ($agent === null) {
            throw AgentNotFoundException::withId($agentId);
        }

        $executionRequest = $agent->execute($input);

        return $this->llmService->complete(
            $executionRequest->getPrompt(),
            $executionRequest->getConfiguration()
        );
    }
}

// If profiling shows this is slow, THEN optimize
final class CachedAgentExecutor implements AgentExecutorInterface
{
    public function __construct(
        private AgentExecutorInterface $decorated,
        private CacheInterface $cache,
    ) {}

    public function execute(AgentId $agentId, string $input): string
    {
        $cacheKey = "agent_execution.{$agentId->toString()}." . md5($input);

        return $this->cache->get($cacheKey, function () use ($agentId, $input) {
            return $this->decorated->execute($agentId, $input);
        });
    }
}
```

**Why It's Bad**:
- Wastes development time
- Makes code complex
- Optimizes wrong parts
- Hard to maintain

**How to Fix**:
- Write simple code first
- Profile to find bottlenecks
- Optimize hot paths only
- Measure impact of optimizations

## Security Antipatterns

### Hardcoded Credentials

**Problem**: Credentials stored directly in code.

```php
<?php

// ❌ ANTIPATTERN: Hardcoded credentials
final class OpenAIService
{
    public function __construct()
    {
        // Hardcoded API key - NEVER DO THIS!
        $this->apiKey = 'sk-proj-abcdef1234567890';
        $this->apiUrl = 'https://api.openai.com/v1';
    }
}

// Database credentials in code
$pdo = new \PDO(
    'pgsql:host=localhost;dbname=myapp',
    'admin',      // Hardcoded username
    'password123' // Hardcoded password
);

// ✅ CORRECT: Environment variables and secret management
final class OpenAIService
{
    public function __construct(
        #[Autowire('%env(OPENAI_API_KEY)%')]
        private readonly string $apiKey,
        #[Autowire('%env(OPENAI_API_URL)%')]
        private readonly string $apiUrl,
    ) {}
}

// Or use Vault
final class OpenAIServiceFactory
{
    public function __construct(
        private readonly VaultClient $vault,
    ) {}

    public function create(): OpenAIService
    {
        $secrets = $this->vault->read('secret/data/llm/openai');

        return new OpenAIService(
            apiKey: $secrets['data']['api_key'],
            apiUrl: $secrets['data']['api_url']
        );
    }
}
```

**Why It's Bad**:
- Credentials in version control
- Hard to rotate
- Security breach risk
- Compliance violations

**How to Fix**:
- Use environment variables
- Use secret management (Vault)
- Never commit .env files
- Rotate credentials regularly

---

### Trusting User Input

**Problem**: Using user input without validation or sanitization.

```php
<?php

// ❌ ANTIPATTERN: SQL injection
public function getAgent(string $id): ?array
{
    // Direct string interpolation - SQL INJECTION!
    $sql = "SELECT * FROM agents WHERE id = '{$id}'";

    return $this->connection->fetchAssociative($sql);
}

// ❌ ANTIPATTERN: Command injection
public function convertFile(string $inputPath, string $outputPath): void
{
    // User-controlled input in shell command - COMMAND INJECTION!
    exec("convert {$inputPath} {$outputPath}");
}

// ✅ CORRECT: Always validate and use parameterized queries
public function getAgent(string $id): ?array
{
    // Validate input
    if (!preg_match('/^[a-f0-9\-]{36}$/i', $id)) {
        throw new \InvalidArgumentException('Invalid agent ID format');
    }

    // Use parameterized query
    return $this->connection->fetchAssociative(
        'SELECT * FROM agents WHERE id = ?',
        [$id]
    );
}

// Use library instead of shell command
public function convertFile(string $inputPath, string $outputPath): void
{
    // Validate path
    $allowedDir = '/var/www/uploads/';
    $realPath = realpath($inputPath);

    if ($realPath === false || !str_starts_with($realPath, $allowedDir)) {
        throw new \InvalidArgumentException('Invalid file path');
    }

    // Use library
    $converter = new ImageConverter();
    $converter->convert($inputPath, $outputPath);
}
```

**Why It's Bad**:
- Security vulnerabilities
- Data breaches
- System compromise

**How to Fix**:
- Always validate input
- Use parameterized queries
- Avoid shell commands
- Sanitize output
- Implement principle of least privilege

## Code Organization Antipatterns

### Magic Numbers

**Problem**: Using literal numbers without explanation.

```php
<?php

// ❌ ANTIPATTERN: Magic numbers
public function shouldRetry(\Throwable $exception, int $attempt): bool
{
    if ($attempt >= 3) {  // What does 3 mean?
        return false;
    }

    if ($exception instanceof RateLimitException) {
        sleep(60);  // What does 60 mean?
        return true;
    }

    if ($exception->getCode() === 500 || $exception->getCode() === 503) {
        sleep(pow(2, $attempt) * 1000);  // What's this formula?
        return true;
    }

    return false;
}

// ✅ CORRECT: Named constants
final class RetryPolicy
{
    private const MAX_ATTEMPTS = 3;
    private const RATE_LIMIT_WAIT_SECONDS = 60;
    private const EXPONENTIAL_BACKOFF_BASE_MS = 1000;

    private const RETRYABLE_HTTP_CODES = [
        Response::HTTP_INTERNAL_SERVER_ERROR,    // 500
        Response::HTTP_SERVICE_UNAVAILABLE,      // 503
    ];

    public function shouldRetry(\Throwable $exception, int $attempt): bool
    {
        if ($attempt >= self::MAX_ATTEMPTS) {
            return false;
        }

        if ($exception instanceof RateLimitException) {
            sleep(self::RATE_LIMIT_WAIT_SECONDS);
            return true;
        }

        if (in_array($exception->getCode(), self::RETRYABLE_HTTP_CODES, true)) {
            $waitMs = pow(2, $attempt) * self::EXPONENTIAL_BACKOFF_BASE_MS;
            usleep($waitMs * 1000);
            return true;
        }

        return false;
    }
}
```

**Why It's Bad**:
- Hard to understand
- Easy to misuse
- Difficult to change
- No documentation

**How to Fix**:
- Use named constants
- Group related constants in enums or classes
- Add comments explaining formulas

## Concurrency Antipatterns

### Race Conditions

**Problem**: Multiple processes accessing shared resources without proper synchronization.

```php
<?php

// ❌ ANTIPATTERN: Race condition
public function incrementExecutionCount(AgentId $agentId): void
{
    // Read
    $agent = $this->connection->fetchAssociative(
        'SELECT execution_count FROM agents WHERE id = ?',
        [$agentId->toString()]
    );

    $newCount = $agent['execution_count'] + 1;

    // Update
    // Race condition if two requests execute simultaneously!
    $this->connection->executeStatement(
        'UPDATE agents SET execution_count = ? WHERE id = ?',
        [$newCount, $agentId->toString()]
    );
}

// ✅ CORRECT: Atomic operation
public function incrementExecutionCount(AgentId $agentId): void
{
    // Atomic increment - no race condition
    $this->connection->executeStatement(
        'UPDATE agents SET execution_count = execution_count + 1 WHERE id = ?',
        [$agentId->toString()]
    );
}

// For more complex operations, use locks
public function processWithLock(AgentId $agentId): void
{
    // Acquire lock
    $this->connection->executeStatement(
        'SELECT * FROM agents WHERE id = ? FOR UPDATE',
        [$agentId->toString()]
    );

    // Critical section - only one process at a time
    // ... complex logic ...

    // Lock released when transaction commits
    $this->connection->commit();
}
```

**Why It's Bad**:
- Data corruption
- Inconsistent state
- Hard to reproduce bugs
- Difficult to debug

**How to Fix**:
- Use atomic database operations
- Use database locks when needed
- Use distributed locks for cross-service coordination
- Design for idempotency

## Summary

This document covers the most common antipatterns to watch for:

1. **Domain Model**: Anemic models, primitive obsession, god objects
2. **Architecture**: Layer violations, service locators, tight coupling
3. **Database**: N+1 queries, missing indexes, SELECT *
4. **API Design**: Chatty APIs, breaking changes
5. **Testing**: Testing implementation, fragile tests
6. **Performance**: Premature optimization
7. **Security**: Hardcoded credentials, trusting user input
8. **Code Organization**: Magic numbers
9. **Concurrency**: Race conditions

Always look for these patterns during code review and refactor when found.
