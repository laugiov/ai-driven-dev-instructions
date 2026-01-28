# Architecture Review Checklist

## Table of Contents

1. [Introduction](#introduction)
2. [Hexagonal Architecture Compliance](#hexagonal-architecture-compliance)
3. [Domain-Driven Design](#domain-driven-design)
4. [Service Boundaries](#service-boundaries)
5. [Dependency Management](#dependency-management)
6. [API Design](#api-design)
7. [Event-Driven Architecture](#event-driven-architecture)
8. [Data Architecture](#data-architecture)
9. [Scalability and Performance](#scalability-and-performance)
10. [Resilience Patterns](#resilience-patterns)
11. [Observability](#observability)
12. [Technical Debt](#technical-debt)

## Introduction

This architecture review checklist ensures that code changes align with the platform's architectural principles and patterns. Architectural consistency is critical for long-term maintainability, scalability, and team productivity.

### Architecture Review Goals

**Consistency**: Ensure new code follows established architectural patterns.

**Quality**: Maintain high architectural quality standards.

**Knowledge Sharing**: Educate team members on architectural decisions.

**Prevent Erosion**: Stop architectural drift before it becomes technical debt.

**Enable Evolution**: Ensure architecture can evolve without breaking changes.

### When to Perform Architecture Review

**Always Required**:
- New services or microservices
- New bounded contexts
- Breaking API changes
- Major refactoring
- New infrastructure components
- Cross-service integration changes

**Recommended**:
- New aggregate roots
- New domain events
- Repository implementations
- External service integrations
- Performance-critical code

**Optional**:
- Minor bug fixes
- Documentation updates
- Test improvements
- Configuration changes

## Hexagonal Architecture Compliance

### Layer Separation

```php
<?php

// ✅ GOOD: Proper layer separation
namespace App\Domain\Agent;

// Domain layer - no infrastructure dependencies
final class Agent
{
    private function __construct(
        private readonly AgentId $id,
        private readonly string $userId,
        private string $name,
        private string $model,
        private string $systemPrompt,
        private AgentStatus $status,
        private readonly \DateTimeImmutable $createdAt,
        private \DateTimeImmutable $updatedAt,
    ) {}

    public static function create(
        AgentId $id,
        string $userId,
        string $name,
        string $model,
        string $systemPrompt
    ): self {
        // Business logic validation
        if (strlen($name) < 3) {
            throw new InvalidArgumentException('Agent name must be at least 3 characters');
        }

        $agent = new self(
            id: $id,
            userId: $userId,
            name: $name,
            model: $model,
            systemPrompt: $systemPrompt,
            status: AgentStatus::Active,
            createdAt: new \DateTimeImmutable(),
            updatedAt: new \DateTimeImmutable(),
        );

        // Raise domain event
        $agent->recordEvent(new AgentCreated($id, $userId));

        return $agent;
    }

    public function execute(string $input): ExecutionRequest
    {
        // Business rules
        if ($this->status !== AgentStatus::Active) {
            throw AgentNotExecutableException::dueToStatus($this->id, $this->status);
        }

        // Return request object - actual execution handled by infrastructure
        return ExecutionRequest::create(
            agentId: $this->id,
            input: $input,
            configuration: [
                'model' => $this->model,
                'system_prompt' => $this->systemPrompt,
            ]
        );
    }
}

namespace App\Application\Agent\CommandHandler;

// Application layer - orchestrates use cases
#[AsMessageHandler]
final class ExecuteAgentCommandHandler
{
    public function __construct(
        private readonly AgentRepositoryInterface $agentRepository,
        private readonly LLMServiceInterface $llmService,
        private readonly ExecutionRepositoryInterface $executionRepository,
        private readonly EventDispatcherInterface $eventDispatcher,
        private readonly LoggerInterface $logger,
    ) {}

    public function __invoke(ExecuteAgentCommand $command): string
    {
        // Load aggregate
        $agent = $this->agentRepository->findById($command->agentId);

        if ($agent === null) {
            throw AgentNotFoundException::withId($command->agentId);
        }

        // Execute domain logic
        $executionRequest = $agent->execute($command->input);

        // Use infrastructure service (through port/interface)
        $result = $this->llmService->complete(
            $executionRequest->getPrompt(),
            $executionRequest->getConfiguration()
        );

        // Create execution record
        $execution = AgentExecution::create(
            id: ExecutionId::generate(),
            agentId: $agent->getId(),
            input: $command->input,
            output: $result->getOutput(),
            tokensUsed: $result->getTokensUsed(),
            durationMs: $result->getDurationMs()
        );

        // Persist
        $this->executionRepository->save($execution);

        // Dispatch events
        foreach ($agent->getRecordedEvents() as $event) {
            $this->eventDispatcher->dispatch($event);
        }

        $this->logger->info('Agent executed successfully', [
            'agent_id' => $agent->getId()->toString(),
            'execution_id' => $execution->getId()->toString(),
        ]);

        return $execution->getId()->toString();
    }
}

namespace App\Infrastructure\LLM\OpenAI;

// Infrastructure layer - technical implementation
final class OpenAIService implements LLMServiceInterface
{
    public function __construct(
        private readonly HttpClientInterface $httpClient,
        #[Autowire('%env(OPENAI_API_KEY)%')]
        private readonly string $apiKey,
        private readonly LoggerInterface $logger,
    ) {}

    public function complete(string $prompt, array $configuration): LLMResult
    {
        $startTime = hrtime(true);

        try {
            $response = $this->httpClient->request('POST', 'https://api.openai.com/v1/chat/completions', [
                'headers' => [
                    'Authorization' => "Bearer {$this->apiKey}",
                    'Content-Type' => 'application/json',
                ],
                'json' => [
                    'model' => $configuration['model'] ?? 'gpt-4',
                    'messages' => [
                        [
                            'role' => 'system',
                            'content' => $configuration['system_prompt'] ?? '',
                        ],
                        [
                            'role' => 'user',
                            'content' => $prompt,
                        ],
                    ],
                    'temperature' => $configuration['temperature'] ?? 0.7,
                    'max_tokens' => $configuration['max_tokens'] ?? 4000,
                ],
                'timeout' => 30,
            ]);

            $data = $response->toArray();

            $durationMs = (int) ((hrtime(true) - $startTime) / 1_000_000);

            return LLMResult::create(
                output: $data['choices'][0]['message']['content'],
                tokensUsed: $data['usage']['total_tokens'],
                durationMs: $durationMs
            );

        } catch (\Throwable $e) {
            $this->logger->error('OpenAI API call failed', [
                'exception' => $e->getMessage(),
            ]);

            throw LLMServiceException::apiCallFailed('openai', $e->getMessage(), $e);
        }
    }
}

// ❌ BAD: Mixed concerns and layer violations
namespace App\Domain\Agent;

// Domain layer with infrastructure dependencies - WRONG!
final class Agent
{
    public function __construct(
        private readonly Connection $connection,  // Infrastructure dependency!
        private readonly HttpClientInterface $httpClient,  // Infrastructure dependency!
    ) {}

    public function execute(string $input): string
    {
        // Business logic mixed with infrastructure
        $response = $this->httpClient->request('POST', 'https://api.openai.com/v1/...', [
            'json' => ['prompt' => $input],
        ]);

        $result = $response->toArray()['completion'];

        // Direct database access in domain!
        $this->connection->executeStatement(
            "INSERT INTO executions (agent_id, result) VALUES (?, ?)",
            [$this->id, $result]
        );

        return $result;
    }
}
```

**Review Checklist**:
- [ ] Domain layer has no infrastructure dependencies
- [ ] Domain layer only depends on domain interfaces (ports)
- [ ] Application layer orchestrates use cases without business logic
- [ ] Infrastructure layer implements domain interfaces (adapters)
- [ ] Dependencies point inward (Infrastructure → Application → Domain)
- [ ] No direct database access in domain or application layers
- [ ] External services accessed through interfaces
- [ ] Domain events used for cross-layer communication

### Port and Adapter Pattern

```php
<?php

// ✅ GOOD: Clean port and adapter implementation

// Port (interface in domain)
namespace App\Domain\Agent\Port;

interface LLMServiceInterface
{
    /**
     * Complete a prompt using the LLM service.
     *
     * @param string $prompt The prompt to complete
     * @param array<string, mixed> $configuration Service configuration
     * @return LLMResult The completion result
     * @throws LLMServiceException If the service call fails
     */
    public function complete(string $prompt, array $configuration): LLMResult;
}

// Domain value object for result
namespace App\Domain\Agent\ValueObject;

final readonly class LLMResult
{
    private function __construct(
        public string $output,
        public int $tokensUsed,
        public int $durationMs,
    ) {}

    public static function create(string $output, int $tokensUsed, int $durationMs): self
    {
        return new self($output, $tokensUsed, $durationMs);
    }
}

// Adapter (implementation in infrastructure)
namespace App\Infrastructure\LLM\OpenAI;

final class OpenAIAdapter implements LLMServiceInterface
{
    public function __construct(
        private readonly HttpClientInterface $httpClient,
        private readonly string $apiKey,
    ) {}

    public function complete(string $prompt, array $configuration): LLMResult
    {
        // Implementation details...
    }
}

// Another adapter for different provider
namespace App\Infrastructure\LLM\Anthropic;

final class AnthropicAdapter implements LLMServiceInterface
{
    public function __construct(
        private readonly HttpClientInterface $httpClient,
        private readonly string $apiKey,
    ) {}

    public function complete(string $prompt, array $configuration): LLMResult
    {
        // Different implementation, same interface
    }
}

// Service configuration
# config/services.yaml
services:
    # Bind interface to implementation
    App\Domain\Agent\Port\LLMServiceInterface:
        class: App\Infrastructure\LLM\OpenAI\OpenAIAdapter
        arguments:
            $apiKey: '%env(OPENAI_API_KEY)%'

// ❌ BAD: No abstraction, tight coupling
namespace App\Domain\Agent;

// Domain directly depends on infrastructure class
use App\Infrastructure\LLM\OpenAI\OpenAIClient;

final class Agent
{
    public function __construct(
        private readonly OpenAIClient $openAIClient,  // Concrete dependency!
    ) {}

    public function execute(string $input): string
    {
        // Tightly coupled to OpenAI - cannot switch providers
        return $this->openAIClient->complete($input);
    }
}
```

**Review Checklist**:
- [ ] Interfaces (ports) defined in domain layer
- [ ] Implementations (adapters) in infrastructure layer
- [ ] Application layer depends on ports, not adapters
- [ ] Multiple adapters can implement same port
- [ ] Adapters are swappable through configuration
- [ ] No leaky abstractions (port doesn't expose implementation details)
- [ ] Adapter pattern documented

## Domain-Driven Design

### Aggregate Boundaries

```php
<?php

// ✅ GOOD: Well-defined aggregate with clear boundaries
namespace App\Domain\Workflow;

// Workflow is the aggregate root
final class Workflow
{
    private WorkflowId $id;
    private string $userId;
    private string $name;
    private WorkflowStatus $status;

    /** @var WorkflowStep[] */
    private array $steps = [];

    /** @var WorkflowExecution[] */
    private array $executions = [];

    private function __construct(/* ... */) {}

    // Factory method
    public static function create(
        WorkflowId $id,
        string $userId,
        string $name,
        string $description
    ): self {
        $workflow = new self(
            id: $id,
            userId: $userId,
            name: $name,
            description: $description,
            status: WorkflowStatus::Draft,
            createdAt: new \DateTimeImmutable(),
            updatedAt: new \DateTimeImmutable(),
        );

        $workflow->recordEvent(new WorkflowCreated($id, $userId));

        return $workflow;
    }

    // All modifications go through aggregate root
    public function addStep(
        string $name,
        string $agentId,
        int $orderIndex,
        array $configuration = []
    ): WorkflowStep {
        // Invariant: Cannot modify published workflow
        if ($this->status === WorkflowStatus::Published) {
            throw InvalidWorkflowStateException::cannotModifyPublished($this->id);
        }

        // Invariant: Order index must be unique
        if ($this->hasStepAtIndex($orderIndex)) {
            throw DuplicateStepIndexException::atIndex($this->id, $orderIndex);
        }

        $step = WorkflowStep::create(
            id: StepId::generate(),
            workflowId: $this->id,
            name: $name,
            agentId: AgentId::fromString($agentId),
            orderIndex: $orderIndex,
            configuration: $configuration
        );

        $this->steps[] = $step;
        $this->updatedAt = new \DateTimeImmutable();

        $this->recordEvent(new WorkflowStepAdded($this->id, $step->getId()));

        return $step;
    }

    public function removeStep(StepId $stepId): void
    {
        if ($this->status === WorkflowStatus::Published) {
            throw InvalidWorkflowStateException::cannotModifyPublished($this->id);
        }

        $index = $this->findStepIndex($stepId);

        if ($index === null) {
            throw WorkflowStepNotFoundException::withId($stepId);
        }

        $step = $this->steps[$index];
        array_splice($this->steps, $index, 1);

        $this->updatedAt = new \DateTimeImmutable();

        $this->recordEvent(new WorkflowStepRemoved($this->id, $stepId));
    }

    public function publish(): void
    {
        // Invariant: Must have at least one step
        if (empty($this->steps)) {
            throw InvalidWorkflowStateException::cannotPublishWithoutSteps($this->id);
        }

        // Invariant: All steps must be valid
        $this->validateSteps();

        $this->status = WorkflowStatus::Published;
        $this->updatedAt = new \DateTimeImmutable();

        $this->recordEvent(new WorkflowPublished($this->id));
    }

    public function execute(array $context): WorkflowExecution
    {
        // Invariant: Can only execute published workflows
        if ($this->status !== WorkflowStatus::Published) {
            throw InvalidWorkflowStateException::cannotExecuteUnpublished($this->id);
        }

        $execution = WorkflowExecution::create(
            id: ExecutionId::generate(),
            workflowId: $this->id,
            context: $context
        );

        $this->executions[] = $execution;

        $this->recordEvent(new WorkflowExecutionStarted($this->id, $execution->getId()));

        return $execution;
    }

    // Private methods for invariant enforcement
    private function hasStepAtIndex(int $orderIndex): bool
    {
        foreach ($this->steps as $step) {
            if ($step->getOrderIndex() === $orderIndex) {
                return true;
            }
        }

        return false;
    }

    private function findStepIndex(StepId $stepId): ?int
    {
        foreach ($this->steps as $index => $step) {
            if ($step->getId()->equals($stepId)) {
                return $index;
            }
        }

        return null;
    }

    private function validateSteps(): void
    {
        // Check for circular dependencies
        $graph = $this->buildDependencyGraph();

        if ($this->hasCircularDependency($graph)) {
            throw CircularDependencyException::inWorkflow($this->id);
        }
    }

    // Getters provide access but not modification
    public function getId(): WorkflowId
    {
        return $this->id;
    }

    public function getSteps(): array
    {
        // Return copy to prevent external modification
        return $this->steps;
    }
}

// Entity within the aggregate
final class WorkflowStep
{
    private function __construct(
        private readonly StepId $id,
        private readonly WorkflowId $workflowId,
        private string $name,
        private readonly AgentId $agentId,
        private int $orderIndex,
        private array $configuration,
    ) {}

    // Cannot be created directly, only through Workflow aggregate
    public static function create(
        StepId $id,
        WorkflowId $workflowId,
        string $name,
        AgentId $agentId,
        int $orderIndex,
        array $configuration
    ): self {
        return new self($id, $workflowId, $name, $agentId, $orderIndex, $configuration);
    }

    // Getters only - modification through Workflow
    public function getId(): StepId { return $this->id; }
    public function getName(): string { return $this->name; }
    public function getOrderIndex(): int { return $this->orderIndex; }
}

// ❌ BAD: Anemic aggregate with no boundaries
final class Workflow
{
    public WorkflowId $id;
    public string $userId;
    public string $name;
    public array $steps = [];

    // Public setters allow bypassing invariants
    public function setName(string $name): void { $this->name = $name; }
    public function setSteps(array $steps): void { $this->steps = $steps; }
}

// Business logic in service instead of aggregate
final class WorkflowService
{
    public function addStep(Workflow $workflow, array $stepData): void
    {
        // Invariant checking in service - WRONG!
        if ($workflow->status === 'published') {
            throw new \Exception('Cannot modify published workflow');
        }

        $step = new WorkflowStep();
        $step->workflowId = $workflow->id;
        $step->name = $stepData['name'];
        // Direct manipulation of aggregate internals
        $workflow->steps[] = $step;
    }
}
```

**Review Checklist**:
- [ ] Aggregate root clearly identified
- [ ] All modifications go through aggregate root
- [ ] Aggregate enforces business invariants
- [ ] Aggregate boundaries are transactional boundaries
- [ ] Child entities cannot be accessed directly outside aggregate
- [ ] Aggregate is not too large (prefer smaller aggregates)
- [ ] Cross-aggregate references use IDs, not object references
- [ ] Domain events used for cross-aggregate communication
- [ ] Repository operates on aggregate root only

### Bounded Context Integration

```php
<?php

// ✅ GOOD: Proper bounded context separation and integration

// Agent Context
namespace App\Domain\Agent;

final class Agent
{
    // Agent context doesn't know about Workflow context
    public function getId(): AgentId { return $this->id; }
}

// Workflow Context
namespace App\Domain\Workflow;

final class Workflow
{
    /** @var WorkflowStep[] */
    private array $steps = [];

    // References Agent by ID only (not entity)
    public function addStep(string $name, string $agentId, int $orderIndex): WorkflowStep
    {
        $step = WorkflowStep::create(
            id: StepId::generate(),
            workflowId: $this->id,
            name: $name,
            agentId: AgentId::fromString($agentId),  // Reference by ID
            orderIndex: $orderIndex
        );

        $this->steps[] = $step;

        return $step;
    }
}

// Integration through events (anti-corruption layer)
namespace App\Application\Workflow\EventSubscriber;

#[AsEventListener]
final class AgentDeletedEventSubscriber
{
    public function __construct(
        private readonly WorkflowRepositoryInterface $workflowRepository,
        private readonly LoggerInterface $logger,
    ) {}

    public function __invoke(AgentDeleted $event): void
    {
        // Workflow context reacts to Agent context events
        $agentIdString = $event->getAgentId()->toString();

        // Find workflows using this agent
        $workflows = $this->workflowRepository->findByAgentId($agentIdString);

        foreach ($workflows as $workflow) {
            // Handle in workflow context's terms
            $workflow->handleAgentDeleted($agentIdString);
            $this->workflowRepository->save($workflow);
        }

        $this->logger->info('Updated workflows after agent deletion', [
            'agent_id' => $agentIdString,
            'workflow_count' => count($workflows),
        ]);
    }
}

// Application service for cross-context operations
namespace App\Application\Workflow\Service;

final class WorkflowStepValidationService
{
    public function __construct(
        private readonly AgentRepositoryInterface $agentRepository,
    ) {}

    public function validateStepAgent(string $agentId, string $userId): void
    {
        // Check if agent exists and belongs to user
        $agent = $this->agentRepository->findById(AgentId::fromString($agentId));

        if ($agent === null) {
            throw new InvalidStepConfigurationException("Agent {$agentId} not found");
        }

        if ($agent->getUserId() !== $userId) {
            throw new InvalidStepConfigurationException("Agent {$agentId} does not belong to user");
        }
    }
}

// ❌ BAD: Tight coupling between contexts
namespace App\Domain\Workflow;

use App\Domain\Agent\Agent;  // Direct dependency on other context!

final class Workflow
{
    /** @var Agent[] */
    private array $agents = [];  // Storing entities from other context!

    public function addStep(Agent $agent, string $name): void  // Accepting entity from other context
    {
        // Direct access to agent internals
        if ($agent->getStatus() !== 'active') {
            throw new \Exception('Agent must be active');
        }

        // Storing entire entity
        $this->agents[] = $agent;
    }
}
```

**Review Checklist**:
- [ ] Bounded contexts clearly separated
- [ ] Cross-context references use IDs, not entities
- [ ] Integration through events or API calls
- [ ] No direct database joins across contexts
- [ ] Anti-corruption layers protect context boundaries
- [ ] Shared kernel minimal or non-existent
- [ ] Context map documented
- [ ] Each context has its own ubiquitous language

### Value Objects

```php
<?php

// ✅ GOOD: Rich value objects with validation
namespace App\Domain\Agent\ValueObject;

final readonly class Temperature
{
    private const MIN_VALUE = 0.0;
    private const MAX_VALUE = 2.0;
    private const DEFAULT_VALUE = 0.7;

    private function __construct(
        private float $value,
    ) {
        if ($value < self::MIN_VALUE || $value > self::MAX_VALUE) {
            throw new \InvalidArgumentException(
                sprintf(
                    'Temperature must be between %.1f and %.1f, got %.2f',
                    self::MIN_VALUE,
                    self::MAX_VALUE,
                    $value
                )
            );
        }
    }

    public static function fromFloat(float $value): self
    {
        return new self($value);
    }

    public static function default(): self
    {
        return new self(self::DEFAULT_VALUE);
    }

    public function toFloat(): float
    {
        return $this->value;
    }

    public function equals(self $other): bool
    {
        // Float comparison with tolerance
        return abs($this->value - $other->value) < 0.001;
    }

    public function isHighCreativity(): bool
    {
        return $this->value >= 1.0;
    }

    public function isLowCreativity(): bool
    {
        return $this->value <= 0.3;
    }
}

// ✅ GOOD: Email value object with validation
final readonly class Email
{
    private function __construct(
        private string $value,
    ) {
        if (!filter_var($value, FILTER_VALIDATE_EMAIL)) {
            throw new \InvalidArgumentException("Invalid email address: {$value}");
        }

        if (strlen($value) > 255) {
            throw new \InvalidArgumentException('Email address too long');
        }
    }

    public static function fromString(string $value): self
    {
        return new self(strtolower(trim($value)));
    }

    public function toString(): string
    {
        return $this->value;
    }

    public function getDomain(): string
    {
        return substr($this->value, strpos($this->value, '@') + 1);
    }

    public function equals(self $other): bool
    {
        return $this->value === $other->value;
    }
}

// ❌ BAD: Primitive obsession
final class Agent
{
    public function __construct(
        private string $id,  // Should be AgentId
        private float $temperature,  // Should be Temperature value object
        private string $email,  // Should be Email value object
    ) {
        // Validation scattered everywhere
        if ($temperature < 0.0 || $temperature > 2.0) {
            throw new \Exception('Invalid temperature');
        }
    }
}
```

**Review Checklist**:
- [ ] Value objects used instead of primitives for domain concepts
- [ ] Value objects are immutable
- [ ] Validation centralized in value object constructor
- [ ] Value objects implement `equals()` method
- [ ] Named constructors for clarity
- [ ] No primitive obsession
- [ ] Value objects contain domain logic related to the value

## Service Boundaries

### Microservice Communication

```php
<?php

// ✅ GOOD: Service communication through events
namespace App\Application\Agent\EventSubscriber;

#[AsEventListener]
final class AgentExecutionCompletedSubscriber
{
    public function __construct(
        private readonly MessageBusInterface $eventBus,
        private readonly LoggerInterface $logger,
    ) {}

    public function __invoke(AgentExecutionCompleted $event): void
    {
        // Publish event to message broker for other services
        $this->eventBus->dispatch(new Message(
            body: json_encode([
                'event_type' => 'agent.execution.completed',
                'event_id' => Uuid::uuid4()->toString(),
                'occurred_at' => time(),
                'payload' => [
                    'agent_id' => $event->getAgentId()->toString(),
                    'execution_id' => $event->getExecutionId()->toString(),
                    'status' => $event->getStatus(),
                    'duration_ms' => $event->getDurationMs(),
                ],
            ]),
            stamps: [
                new AmqpStamp(routingKey: 'agent.execution.completed'),
            ],
        ));

        $this->logger->info('Published agent execution completed event', [
            'agent_id' => $event->getAgentId()->toString(),
            'execution_id' => $event->getExecutionId()->toString(),
        ]);
    }
}

// Event consumer in another service
namespace App\AuditService\EventConsumer;

#[AsMessageHandler(fromTransport: 'async')]
final class AgentExecutionEventConsumer
{
    public function __construct(
        private readonly AuditLogRepository $auditLogRepository,
    ) {}

    public function __invoke(AgentExecutionCompletedEvent $event): void
    {
        // Create audit log entry
        $auditLog = AuditLog::create(
            id: AuditLogId::generate(),
            eventType: 'agent.execution.completed',
            resourceId: $event->getAgentId(),
            data: $event->toArray(),
            occurredAt: $event->getOccurredAt()
        );

        $this->auditLogRepository->save($auditLog);
    }
}

// ❌ BAD: Direct service-to-service HTTP calls
namespace App\Application\Agent\CommandHandler;

final class ExecuteAgentCommandHandler
{
    public function __construct(
        private readonly HttpClientInterface $httpClient,
    ) {}

    public function __invoke(ExecuteAgentCommand $command): string
    {
        // Execute agent logic...

        // Direct HTTP call to audit service - tight coupling!
        $this->httpClient->request('POST', 'http://audit-service:8080/api/audit-logs', [
            'json' => [
                'event_type' => 'agent.execution.completed',
                'agent_id' => $agentId,
            ],
        ]);

        // If audit service is down, execution fails!
        // No retry logic, no queue

        return $executionId;
    }
}
```

**Review Checklist**:
- [ ] Services communicate asynchronously through events
- [ ] No synchronous HTTP calls between services for business operations
- [ ] Event schemas versioned and documented
- [ ] Events contain all necessary data (no chatty communication)
- [ ] Services can operate independently
- [ ] Eventual consistency handled appropriately
- [ ] Saga pattern used for distributed transactions
- [ ] Circuit breakers for service-to-service calls

## Dependency Management

### Dependency Inversion

```php
<?php

// ✅ GOOD: Dependency inversion principle
namespace App\Application\Agent\Service;

// Application defines what it needs (interface)
interface NotificationServiceInterface
{
    public function sendAgentExecutionNotification(
        string $userId,
        string $agentId,
        string $executionId,
        string $status
    ): void;
}

// Application service depends on interface
final class AgentExecutionService
{
    public function __construct(
        private readonly AgentRepositoryInterface $agentRepository,
        private readonly NotificationServiceInterface $notificationService,
    ) {}

    public function completeExecution(string $executionId, string $result): void
    {
        // Business logic...

        // Call through interface
        $this->notificationService->sendAgentExecutionNotification(
            $userId,
            $agentId,
            $executionId,
            'completed'
        );
    }
}

// Infrastructure provides implementation
namespace App\Infrastructure\Notification;

final class EmailNotificationService implements NotificationServiceInterface
{
    public function __construct(
        private readonly MailerInterface $mailer,
    ) {}

    public function sendAgentExecutionNotification(
        string $userId,
        string $agentId,
        string $executionId,
        string $status
    ): void {
        // Email implementation
        $this->mailer->send(/* ... */);
    }
}

// Can be swapped with different implementation
namespace App\Infrastructure\Notification;

final class SlackNotificationService implements NotificationServiceInterface
{
    public function __construct(
        private readonly HttpClientInterface $httpClient,
        private readonly string $webhookUrl,
    ) {}

    public function sendAgentExecutionNotification(
        string $userId,
        string $agentId,
        string $executionId,
        string $status
    ): void {
        // Slack implementation
        $this->httpClient->request('POST', $this->webhookUrl, [
            'json' => [
                'text' => "Agent execution {$status}: {$executionId}",
            ],
        ]);
    }
}

// ❌ BAD: Direct dependency on concrete class
namespace App\Application\Agent\Service;

use App\Infrastructure\Notification\EmailService;  // Concrete class!

final class AgentExecutionService
{
    public function __construct(
        private readonly EmailService $emailService,  // Depends on concrete implementation
    ) {}

    public function completeExecution(string $executionId, string $result): void
    {
        // Tightly coupled to email - cannot switch to Slack without changing code
        $this->emailService->send(/* ... */);
    }
}
```

**Review Checklist**:
- [ ] High-level modules don't depend on low-level modules
- [ ] Both depend on abstractions (interfaces)
- [ ] Interfaces defined in consuming module, not implementing module
- [ ] No concrete dependencies across architectural layers
- [ ] Implementations are swappable
- [ ] Constructor injection used for dependencies
- [ ] No static dependencies

## API Design

### RESTful API Consistency

```php
<?php

// ✅ GOOD: Consistent RESTful API design
namespace App\Infrastructure\Http\Controller;

#[Route('/api/v1/agents')]
final class AgentController extends AbstractController
{
    // List agents: GET /api/v1/agents
    #[Route('', methods: ['GET'])]
    public function list(Request $request): JsonResponse
    {
        $page = (int) $request->query->get('page', 1);
        $perPage = (int) $request->query->get('per_page', 20);

        $query = new ListAgentsQuery(
            userId: $this->getUser()->getId(),
            page: $page,
            perPage: min($perPage, 100)  // Cap at 100
        );

        $result = $this->queryBus->query($query);

        return $this->json([
            'data' => $result['data'],
            'meta' => [
                'current_page' => $result['pagination']['current_page'],
                'per_page' => $result['pagination']['per_page'],
                'total' => $result['pagination']['total'],
                'total_pages' => $result['pagination']['total_pages'],
            ],
            'links' => [
                'self' => "/api/v1/agents?page={$page}&per_page={$perPage}",
                'next' => $result['pagination']['next_page']
                    ? "/api/v1/agents?page={$result['pagination']['next_page']}&per_page={$perPage}"
                    : null,
            ],
        ]);
    }

    // Get single agent: GET /api/v1/agents/{id}
    #[Route('/{id}', methods: ['GET'])]
    public function get(string $id): JsonResponse
    {
        $agent = $this->queryBus->query(new GetAgentQuery($id));

        if ($agent === null) {
            throw $this->createNotFoundException('Agent not found');
        }

        $this->denyAccessUnlessGranted('view', $agent);

        return $this->json(['data' => $agent]);
    }

    // Create agent: POST /api/v1/agents
    #[Route('', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);

        $command = new CreateAgentCommand(
            name: $data['name'],
            model: $data['model'],
            systemPrompt: $data['system_prompt'],
            userId: $this->getUser()->getId()
        );

        $agentId = $this->commandBus->dispatch($command);

        return $this->json(
            ['data' => ['id' => $agentId]],
            Response::HTTP_CREATED,
            ['Location' => "/api/v1/agents/{$agentId}"]
        );
    }

    // Update agent: PUT /api/v1/agents/{id}
    #[Route('/{id}', methods: ['PUT'])]
    public function update(string $id, Request $request): JsonResponse
    {
        $agent = $this->queryBus->query(new GetAgentQuery($id));

        if ($agent === null) {
            throw $this->createNotFoundException('Agent not found');
        }

        $this->denyAccessUnlessGranted('edit', $agent);

        $data = json_decode($request->getContent(), true);

        $command = new UpdateAgentCommand(
            id: $id,
            name: $data['name'],
            systemPrompt: $data['system_prompt']
        );

        $this->commandBus->dispatch($command);

        return $this->json(['data' => ['id' => $id]]);
    }

    // Partial update: PATCH /api/v1/agents/{id}
    #[Route('/{id}', methods: ['PATCH'])]
    public function patch(string $id, Request $request): JsonResponse
    {
        $agent = $this->queryBus->query(new GetAgentQuery($id));

        if ($agent === null) {
            throw $this->createNotFoundException('Agent not found');
        }

        $this->denyAccessUnlessGranted('edit', $agent);

        $data = json_decode($request->getContent(), true);

        $command = new PatchAgentCommand(
            id: $id,
            name: $data['name'] ?? null,
            systemPrompt: $data['system_prompt'] ?? null
        );

        $this->commandBus->dispatch($command);

        return $this->json(['data' => ['id' => $id]]);
    }

    // Delete agent: DELETE /api/v1/agents/{id}
    #[Route('/{id}', methods: ['DELETE'])]
    public function delete(string $id): JsonResponse
    {
        $agent = $this->queryBus->query(new GetAgentQuery($id));

        if ($agent === null) {
            throw $this->createNotFoundException('Agent not found');
        }

        $this->denyAccessUnlessGranted('delete', $agent);

        $this->commandBus->dispatch(new DeleteAgentCommand($id));

        return $this->json(null, Response::HTTP_NO_CONTENT);
    }

    // Sub-resource: GET /api/v1/agents/{id}/executions
    #[Route('/{id}/executions', methods: ['GET'])]
    public function getExecutions(string $id, Request $request): JsonResponse
    {
        $agent = $this->queryBus->query(new GetAgentQuery($id));

        if ($agent === null) {
            throw $this->createNotFoundException('Agent not found');
        }

        $this->denyAccessUnlessGranted('view', $agent);

        $executions = $this->queryBus->query(
            new GetAgentExecutionsQuery($id)
        );

        return $this->json(['data' => $executions]);
    }

    // Action: POST /api/v1/agents/{id}/execute
    #[Route('/{id}/execute', methods: ['POST'])]
    public function execute(string $id, Request $request): JsonResponse
    {
        $agent = $this->queryBus->query(new GetAgentQuery($id));

        if ($agent === null) {
            throw $this->createNotFoundException('Agent not found');
        }

        $this->denyAccessUnlessGranted('execute', $agent);

        $data = json_decode($request->getContent(), true);

        $executionId = $this->commandBus->dispatch(
            new ExecuteAgentCommand($id, $data['input'])
        );

        return $this->json(
            ['data' => ['execution_id' => $executionId]],
            Response::HTTP_ACCEPTED,
            ['Location' => "/api/v1/executions/{$executionId}"]
        );
    }
}

// ❌ BAD: Inconsistent API design
#[Route('/api/v1/agents')]
final class AgentController
{
    // Inconsistent naming
    #[Route('/getAll', methods: ['GET'])]  // Should be: ''
    public function getAllAgents(): JsonResponse { }

    // Wrong HTTP method
    #[Route('/delete/{id}', methods: ['GET'])]  // Should be DELETE method
    public function delete(string $id): JsonResponse { }

    // RPC-style instead of REST
    #[Route('/createNewAgent', methods: ['POST'])]  // Should be: ''
    public function createNewAgent(): JsonResponse { }

    // No pagination
    #[Route('', methods: ['GET'])]
    public function list(): JsonResponse
    {
        // Returns all agents - no pagination!
        $agents = $this->agentRepository->findAll();
        return $this->json($agents);
    }
}
```

**Review Checklist**:
- [ ] RESTful conventions followed
- [ ] Correct HTTP methods used (GET, POST, PUT, PATCH, DELETE)
- [ ] HTTP status codes appropriate
- [ ] Consistent URL structure
- [ ] Pagination implemented for list endpoints
- [ ] Filtering and sorting supported
- [ ] Response format consistent across endpoints
- [ ] API versioning strategy followed
- [ ] Hypermedia links included (HATEOAS)
- [ ] Documentation generated/updated

## Event-Driven Architecture

### Domain Events

```php
<?php

// ✅ GOOD: Well-designed domain events
namespace App\Domain\Agent\Event;

final readonly class AgentExecutionCompleted
{
    public function __construct(
        public AgentId $agentId,
        public ExecutionId $executionId,
        public string $status,
        public int $tokensUsed,
        public int $durationMs,
        public \DateTimeImmutable $completedAt,
    ) {}

    public function toArray(): array
    {
        return [
            'agent_id' => $this->agentId->toString(),
            'execution_id' => $this->executionId->toString(),
            'status' => $this->status,
            'tokens_used' => $this->tokensUsed,
            'duration_ms' => $this->durationMs,
            'completed_at' => $this->completedAt->format(\DateTimeInterface::RFC3339),
        ];
    }

    public static function fromArray(array $data): self
    {
        return new self(
            agentId: AgentId::fromString($data['agent_id']),
            executionId: ExecutionId::fromString($data['execution_id']),
            status: $data['status'],
            tokensUsed: $data['tokens_used'],
            durationMs: $data['duration_ms'],
            completedAt: new \DateTimeImmutable($data['completed_at']),
        );
    }
}

// Event raised from aggregate
namespace App\Domain\Agent;

final class Agent
{
    private array $recordedEvents = [];

    public function completeExecution(
        ExecutionId $executionId,
        string $result,
        int $tokensUsed,
        int $durationMs
    ): void {
        // Business logic...

        // Record event
        $this->recordEvent(new AgentExecutionCompleted(
            agentId: $this->id,
            executionId: $executionId,
            status: 'completed',
            tokensUsed: $tokensUsed,
            durationMs: $durationMs,
            completedAt: new \DateTimeImmutable(),
        ));
    }

    private function recordEvent(object $event): void
    {
        $this->recordedEvents[] = $event;
    }

    public function getRecordedEvents(): array
    {
        return $this->recordedEvents;
    }

    public function clearRecordedEvents(): void
    {
        $this->recordedEvents = [];
    }
}

// Events dispatched after persistence
namespace App\Application\Agent\CommandHandler;

#[AsMessageHandler]
final class CompleteAgentExecutionCommandHandler
{
    public function __construct(
        private readonly AgentRepositoryInterface $agentRepository,
        private readonly EventDispatcherInterface $eventDispatcher,
    ) {}

    public function __invoke(CompleteAgentExecutionCommand $command): void
    {
        $agent = $this->agentRepository->findById($command->agentId);

        $agent->completeExecution(
            $command->executionId,
            $command->result,
            $command->tokensUsed,
            $command->durationMs
        );

        // Persist first
        $this->agentRepository->save($agent);

        // Then dispatch events
        foreach ($agent->getRecordedEvents() as $event) {
            $this->eventDispatcher->dispatch($event);
        }

        $agent->clearRecordedEvents();
    }
}
```

**Review Checklist**:
- [ ] Domain events represent past occurrences
- [ ] Event names in past tense (AgentCreated, not CreateAgent)
- [ ] Events are immutable
- [ ] Events contain all necessary data
- [ ] Events don't contain entities, only IDs and values
- [ ] Events raised from aggregates
- [ ] Events dispatched after successful persistence
- [ ] Event versioning strategy in place
- [ ] Events serializable to JSON

## Data Architecture

### Repository Pattern

```php
<?php

// ✅ GOOD: Clean repository implementation
namespace App\Infrastructure\Persistence\Agent;

final class DoctrineAgentRepository implements AgentRepositoryInterface
{
    public function __construct(
        private readonly Connection $connection,
    ) {}

    public function findById(AgentId $id): ?Agent
    {
        $data = $this->connection->fetchAssociative(
            'SELECT * FROM agents WHERE id = ?',
            [$id->toString()]
        );

        if (!$data) {
            return null;
        }

        return $this->hydrate($data);
    }

    public function save(Agent $agent): void
    {
        $data = [
            'id' => $agent->getId()->toString(),
            'user_id' => $agent->getUserId(),
            'name' => $agent->getName(),
            'model' => $agent->getModel(),
            'system_prompt' => $agent->getSystemPrompt(),
            'status' => $agent->getStatus()->value,
            'created_at' => $agent->getCreatedAt()->format('Y-m-d H:i:s'),
            'updated_at' => $agent->getUpdatedAt()->format('Y-m-d H:i:s'),
        ];

        $exists = $this->connection->fetchOne(
            'SELECT 1 FROM agents WHERE id = ?',
            [$agent->getId()->toString()]
        );

        if ($exists) {
            $this->connection->update('agents', $data, ['id' => $agent->getId()->toString()]);
        } else {
            $this->connection->insert('agents', $data);
        }
    }

    private function hydrate(array $data): Agent
    {
        return Agent::fromDatabase([
            'id' => $data['id'],
            'user_id' => $data['user_id'],
            'name' => $data['name'],
            'model' => $data['model'],
            'system_prompt' => $data['system_prompt'],
            'status' => $data['status'],
            'created_at' => $data['created_at'],
            'updated_at' => $data['updated_at'],
        ]);
    }
}

// ❌ BAD: Leaky repository abstraction
interface AgentRepositoryInterface
{
    // Returns Doctrine QueryBuilder - leaky abstraction!
    public function createQueryBuilder(): QueryBuilder;

    // Exposes ORM details
    public function getEntityManager(): EntityManagerInterface;
}
```

**Review Checklist**:
- [ ] Repository interface in domain layer
- [ ] Repository implementation in infrastructure layer
- [ ] Repository operates on aggregates, not database tables
- [ ] No ORM-specific types in repository interface
- [ ] Repository methods named from domain perspective
- [ ] No `getEntityManager()` or similar leaky methods
- [ ] Queries return domain objects, not arrays
- [ ] Repository doesn't contain business logic

## Scalability and Performance

```php
<?php

// ✅ GOOD: Performance-conscious implementation
final class WorkflowExecutionService
{
    public function listRecentExecutions(string $workflowId, int $limit = 50): array
    {
        // Efficient query with limit
        return $this->connection->fetchAllAssociative(
            'SELECT id, status, started_at, completed_at, duration_ms
             FROM workflow_executions
             WHERE workflow_id = ?
             ORDER BY started_at DESC
             LIMIT ?',
            [$workflowId, min($limit, 100)]  // Cap limit
        );
    }

    public function getExecutionStatistics(string $workflowId): array
    {
        // Single query with aggregation
        $stats = $this->connection->fetchAssociative(
            'SELECT
                COUNT(*) as total_count,
                SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) as success_count,
                SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) as failure_count,
                AVG(duration_ms) as avg_duration_ms,
                MAX(duration_ms) as max_duration_ms
             FROM workflow_executions
             WHERE workflow_id = ?
             AND created_at > NOW() - INTERVAL \'30 days\'',
            ['completed', 'failed', $workflowId]
        );

        return $stats;
    }
}

// ❌ BAD: N+1 query problem
final class WorkflowExecutionService
{
    public function listRecentExecutions(string $workflowId): array
    {
        $executions = $this->connection->fetchAllAssociative(
            'SELECT * FROM workflow_executions WHERE workflow_id = ?',
            [$workflowId]
        );

        $result = [];
        foreach ($executions as $execution) {
            // N+1 query - executes for each execution!
            $steps = $this->connection->fetchAllAssociative(
                'SELECT * FROM execution_steps WHERE execution_id = ?',
                [$execution['id']]
            );

            $result[] = [
                'execution' => $execution,
                'steps' => $steps,
            ];
        }

        return $result;
    }
}
```

**Review Checklist**:
- [ ] No N+1 query problems
- [ ] Database queries optimized
- [ ] Appropriate indexes exist
- [ ] Caching implemented where beneficial
- [ ] Pagination implemented for large datasets
- [ ] Async processing for non-critical operations
- [ ] Batch operations for bulk updates
- [ ] Connection pooling configured

## Resilience Patterns

```php
<?php

// ✅ GOOD: Circuit breaker pattern
final class ResilientLLMService implements LLMServiceInterface
{
    public function __construct(
        private readonly LLMServiceInterface $decorated,
        private readonly CircuitBreaker $circuitBreaker,
        private readonly RetryHandler $retryHandler,
    ) {}

    public function complete(string $prompt, array $configuration): LLMResult
    {
        return $this->circuitBreaker->execute(
            serviceName: 'llm_service',
            operation: function () use ($prompt, $configuration) {
                return $this->retryHandler->execute(
                    operation: fn() => $this->decorated->complete($prompt, $configuration),
                    retryableExceptions: [
                        LLMServiceException::class,
                        \RuntimeException::class,
                    ],
                    maxAttempts: 3
                );
            }
        );
    }
}
```

**Review Checklist**:
- [ ] Circuit breakers for external services
- [ ] Retry logic with exponential backoff
- [ ] Timeouts configured
- [ ] Graceful degradation implemented
- [ ] Bulkheads prevent cascade failures
- [ ] Health checks implemented
- [ ] Fallback strategies defined

## Observability

```php
<?php

// ✅ GOOD: Comprehensive observability
final class ObservableAgentExecutor
{
    public function __construct(
        private readonly AgentExecutorInterface $decorated,
        private readonly MetricsCollector $metrics,
        private readonly LoggerInterface $logger,
    ) {}

    public function execute(AgentId $agentId, string $input): ExecutionResult
    {
        $startTime = hrtime(true);

        try {
            $result = $this->decorated->execute($agentId, $input);

            $duration = (hrtime(true) - $startTime) / 1_000_000_000;

            $this->metrics->recordHistogram('agent_execution_duration_seconds', $duration, [
                'status' => 'success',
            ]);

            $this->logger->info('Agent executed successfully', [
                'agent_id' => $agentId->toString(),
                'duration_seconds' => round($duration, 3),
                'tokens_used' => $result->getTokensUsed(),
            ]);

            return $result;

        } catch (\Throwable $e) {
            $duration = (hrtime(true) - $startTime) / 1_000_000_000;

            $this->metrics->incrementCounter('agent_execution_errors_total', [
                'error_type' => get_class($e),
            ]);

            $this->logger->error('Agent execution failed', [
                'agent_id' => $agentId->toString(),
                'duration_seconds' => round($duration, 3),
                'exception' => $e->getMessage(),
            ]);

            throw $e;
        }
    }
}
```

**Review Checklist**:
- [ ] Structured logging implemented
- [ ] Metrics collected for key operations
- [ ] Distributed tracing configured
- [ ] Log levels appropriate
- [ ] No sensitive data in logs
- [ ] Correlation IDs used
- [ ] Dashboards exist for key metrics
- [ ] Alerts configured for anomalies

## Technical Debt

```php
<?php

// ✅ GOOD: Technical debt documented
/**
 * Temporary implementation using simple array-based cache.
 *
 * TODO: Replace with Redis-based distributed cache
 * Ticket: TECH-123
 * Reason: Need distributed cache for multi-instance deployment
 * Estimate: 2 days
 * Priority: High
 * Target: Sprint 23
 */
final class SimpleCache implements CacheInterface
{
    private array $cache = [];

    public function get(string $key): mixed
    {
        return $this->cache[$key] ?? null;
    }

    public function set(string $key, mixed $value, int $ttl): void
    {
        $this->cache[$key] = $value;
        // TODO: Implement TTL
    }
}

// ❌ BAD: Hidden technical debt
final class SimpleCache implements CacheInterface
{
    private array $cache = [];

    // No documentation of limitations
    // No plan to improve
    public function get(string $key): mixed
    {
        return $this->cache[$key] ?? null;
    }
}
```

**Review Checklist**:
- [ ] Technical debt documented with TODO comments
- [ ] Tickets created for significant debt
- [ ] Reason for debt explained
- [ ] Estimate provided
- [ ] Priority assigned
- [ ] No "temporary" solutions without plan
- [ ] Workarounds clearly marked
- [ ] Impact of debt understood

## Summary

This architecture review checklist ensures:

1. **Hexagonal Architecture**: Proper layer separation and dependency flow
2. **DDD**: Well-defined aggregates, value objects, and bounded contexts
3. **Service Boundaries**: Loose coupling through events
4. **Dependency Management**: Dependency inversion principle
5. **API Design**: RESTful consistency
6. **Events**: Proper event-driven architecture
7. **Data**: Clean repository pattern
8. **Scalability**: Performance-conscious code
9. **Resilience**: Circuit breakers and retries
10. **Observability**: Comprehensive logging and metrics
11. **Technical Debt**: Documented and tracked

Use this checklist to maintain architectural integrity across all code changes.
