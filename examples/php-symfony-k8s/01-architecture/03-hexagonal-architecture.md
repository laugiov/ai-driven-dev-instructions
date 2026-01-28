# Hexagonal Architecture (Ports & Adapters)

## Overview

This document explains the implementation of Hexagonal Architecture (also known as Ports and Adapters pattern) across all microservices in the system. This architectural pattern ensures that business logic remains independent of technical infrastructure concerns.

## Why Hexagonal Architecture?

### Problems It Solves

**1. Framework Lock-In**
- Traditional layered architecture tightly couples business logic to frameworks
- Changing frameworks requires rewriting business logic
- Testing requires framework initialization

**2. Technical Debt**
- Business logic mixed with infrastructure code
- Hard to understand what code does vs. how it does it
- Difficult to test without database, APIs, etc.

**3. Evolution**
- Hard to swap databases, message brokers, APIs
- Infrastructure changes ripple through business logic
- Technology upgrades are risky

### Benefits Provided

✅ **Framework Independence**: Business logic doesn't depend on Symfony, Doctrine, etc.
✅ **Testability**: Business logic tested in isolation with mocks
✅ **Infrastructure Flexibility**: Swap databases, APIs, queues without touching domain
✅ **Clear Separation**: Explicit boundaries between "what" and "how"
✅ **Domain-Centric**: Business logic is the center, not infrastructure
✅ **Maintainability**: Changes to infrastructure don't affect business rules

## Core Concepts

### 1. The Hexagon (Application Core)

The hexagon represents the application core containing:
- **Domain Layer**: Pure business logic (entities, value objects, domain services)
- **Application Layer**: Use cases, orchestration (command/query handlers)

**Key Principle**: The hexagon doesn't know about the outside world. It defines interfaces (ports) for what it needs, but doesn't implement them.

### 2. Ports

**Ports are interfaces** that define contracts for communication.

**Two Types**:

**A. Inbound Ports (Driving/Primary)**
- How external actors use the application
- Examples: `CreateUserCommandHandler`, `GetWorkflowQueryHandler`
- Called BY adapters (API controllers, CLI commands)

**B. Outbound Ports (Driven/Secondary)**
- How the application uses external services
- Examples: `UserRepositoryInterface`, `LLMProviderInterface`, `EventPublisherInterface`
- Implemented BY adapters (Doctrine repository, OpenAI client, RabbitMQ publisher)

### 3. Adapters

**Adapters are concrete implementations** that connect the outside world to ports.

**Two Types**:

**A. Inbound Adapters (Primary/Driving)**
- REST API controllers
- GraphQL resolvers
- CLI commands
- Message consumers
- Scheduled jobs

**B. Outbound Adapters (Secondary/Driven)**
- Database repositories (Doctrine)
- HTTP clients (Guzzle)
- Message publishers (RabbitMQ)
- File systems
- External APIs

### Visualization

```
┌─────────────────────────────────────────────────────────────────┐
│                     Inbound Adapters                            │
│  (REST Controller, CLI, GraphQL, Message Consumer)              │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Inbound Ports                               │
│         (Command Handlers, Query Handlers)                      │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    HEXAGON (Application Core)                   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │               APPLICATION LAYER                          │  │
│  │  - Use Cases                                             │  │
│  │  - Command/Query Handlers                                │  │
│  │  - Application Services                                  │  │
│  │  - DTOs                                                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          │                                      │
│                          ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  DOMAIN LAYER                            │  │
│  │  - Entities (Aggregate Roots)                            │  │
│  │  - Value Objects                                         │  │
│  │  - Domain Services                                       │  │
│  │  - Domain Events                                         │  │
│  │  - Business Rules                                        │  │
│  │                                                           │  │
│  │  Pure PHP - No Framework Dependencies                    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          │                                      │
│                          ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │               Outbound Ports (Interfaces)                │  │
│  │  - RepositoryInterface                                   │  │
│  │  - EventPublisherInterface                               │  │
│  │  - ExternalServiceInterface                              │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Outbound Adapters                             │
│  (Doctrine Repo, OpenAI Client, RabbitMQ, Redis, S3)           │
└─────────────────────────────────────────────────────────────────┘
```

## Layer Responsibilities

### Domain Layer (innermost)

**Purpose**: Contains the core business logic. This is the heart of your application.

**Characteristics**:
- ✅ Pure PHP (no framework dependencies)
- ✅ Framework-agnostic
- ✅ Contains all business rules
- ✅ Highly testable (unit tests)
- ❌ No Symfony annotations/attributes
- ❌ No Doctrine annotations/attributes
- ❌ No I/O operations
- ❌ No infrastructure concerns

**Contains**:

**1. Entities (Aggregate Roots)**
```php
// src/Domain/Entity/Workflow.php
namespace App\Domain\Entity;

final class Workflow
{
    private WorkflowId $id;
    private string $name;
    private WorkflowState $state;
    private Collection $steps;

    public function __construct(WorkflowId $id, string $name)
    {
        $this->id = $id;
        $this->name = $name;
        $this->state = WorkflowState::draft();
        $this->steps = new Collection();
    }

    public function start(): void
    {
        if (!$this->state->isDraft()) {
            throw new WorkflowAlreadyStartedException($this->id);
        }

        $this->state = WorkflowState::running();
        $this->recordEvent(new WorkflowStarted($this->id));
    }

    public function addStep(Step $step): void
    {
        if (!$this->state->isDraft()) {
            throw new CannotModifyRunningWorkflowException($this->id);
        }

        $this->steps->add($step);
    }

    // Pure business logic, no infrastructure
}
```

**2. Value Objects**
```php
// src/Domain/ValueObject/WorkflowId.php
namespace App\Domain\ValueObject;

final readonly class WorkflowId
{
    private string $value;

    public function __construct(string $value)
    {
        if (!Uuid::isValid($value)) {
            throw new InvalidWorkflowIdException($value);
        }
        $this->value = $value;
    }

    public function toString(): string
    {
        return $this->value;
    }

    public function equals(WorkflowId $other): bool
    {
        return $this->value === $other->value;
    }
}
```

**3. Domain Services**
```php
// src/Domain/Service/WorkflowValidator.php
namespace App\Domain\Service;

final readonly class WorkflowValidator
{
    public function validateWorkflowDefinition(Workflow $workflow): ValidationResult
    {
        $errors = [];

        if ($workflow->getSteps()->isEmpty()) {
            $errors[] = 'Workflow must have at least one step';
        }

        if ($this->hasCircularDependencies($workflow)) {
            $errors[] = 'Workflow contains circular dependencies';
        }

        return new ValidationResult($errors);
    }

    private function hasCircularDependencies(Workflow $workflow): bool
    {
        // Complex domain logic
    }
}
```

**4. Domain Events**
```php
// src/Domain/Event/WorkflowStarted.php
namespace App\Domain\Event;

final readonly class WorkflowStarted implements DomainEventInterface
{
    public function __construct(
        public WorkflowId $workflowId,
        public DateTimeImmutable $occurredAt = new DateTimeImmutable(),
    ) {}
}
```

**5. Repository Interfaces (Outbound Ports)**
```php
// src/Domain/Repository/WorkflowRepositoryInterface.php
namespace App\Domain\Repository;

interface WorkflowRepositoryInterface
{
    public function save(Workflow $workflow): void;
    public function findById(WorkflowId $id): ?Workflow;
    public function findByState(WorkflowState $state): Collection;
    public function delete(WorkflowId $id): void;
}
```

**6. Domain Exceptions**
```php
// src/Domain/Exception/WorkflowNotFoundException.php
namespace App\Domain\Exception;

final class WorkflowNotFoundException extends DomainException
{
    public function __construct(WorkflowId $id)
    {
        parent::__construct("Workflow {$id->toString()} not found");
    }
}
```

### Application Layer

**Purpose**: Orchestrates domain objects to implement use cases. Coordinates between domain and infrastructure.

**Characteristics**:
- ✅ Uses domain objects
- ✅ Orchestrates use cases
- ✅ Can use Symfony services (DI)
- ✅ Transactional boundaries
- ❌ No business rules (delegate to domain)
- ❌ No infrastructure details (use ports)

**Contains**:

**1. Command Handlers (Inbound Ports)**
```php
// src/Application/Command/CreateWorkflowCommand.php
namespace App\Application\Command;

final readonly class CreateWorkflowCommand
{
    public function __construct(
        public string $name,
        public array $steps,
    ) {}
}

// src/Application/Handler/CreateWorkflowHandler.php
namespace App\Application\Handler;

final readonly class CreateWorkflowHandler
{
    public function __construct(
        private WorkflowRepositoryInterface $workflowRepository,
        private EventPublisherInterface $eventPublisher,
        private WorkflowValidator $validator,
    ) {}

    public function __invoke(CreateWorkflowCommand $command): WorkflowId
    {
        // 1. Create domain entity
        $id = WorkflowId::generate();
        $workflow = new Workflow($id, $command->name);

        foreach ($command->steps as $stepData) {
            $step = Step::fromArray($stepData);
            $workflow->addStep($step);
        }

        // 2. Validate using domain service
        $result = $this->validator->validateWorkflowDefinition($workflow);
        if (!$result->isValid()) {
            throw new InvalidWorkflowException($result->getErrors());
        }

        // 3. Persist via repository (port)
        $this->workflowRepository->save($workflow);

        // 4. Publish domain events (port)
        foreach ($workflow->pullDomainEvents() as $event) {
            $this->eventPublisher->publish($event);
        }

        return $id;
    }
}
```

**2. Query Handlers (Inbound Ports)**
```php
// src/Application/Query/GetWorkflowQuery.php
namespace App\Application\Query;

final readonly class GetWorkflowQuery
{
    public function __construct(
        public string $workflowId,
    ) {}
}

// src/Application/Handler/GetWorkflowHandler.php
namespace App\Application\Handler;

final readonly class GetWorkflowHandler
{
    public function __construct(
        private WorkflowRepositoryInterface $workflowRepository,
    ) {}

    public function __invoke(GetWorkflowQuery $query): WorkflowDTO
    {
        $id = new WorkflowId($query->workflowId);
        $workflow = $this->workflowRepository->findById($id);

        if ($workflow === null) {
            throw new WorkflowNotFoundException($id);
        }

        return WorkflowDTO::fromEntity($workflow);
    }
}
```

**3. DTOs (Data Transfer Objects)**
```php
// src/Application/DTO/WorkflowDTO.php
namespace App\Application\DTO;

final readonly class WorkflowDTO
{
    public function __construct(
        public string $id,
        public string $name,
        public string $state,
        public array $steps,
        public string $createdAt,
    ) {}

    public static function fromEntity(Workflow $workflow): self
    {
        return new self(
            id: $workflow->getId()->toString(),
            name: $workflow->getName(),
            state: $workflow->getState()->toString(),
            steps: array_map(
                fn(Step $step) => StepDTO::fromEntity($step),
                $workflow->getSteps()->toArray()
            ),
            createdAt: $workflow->getCreatedAt()->format('c'),
        );
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'state' => $this->state,
            'steps' => $this->steps,
            'createdAt' => $this->createdAt,
        ];
    }
}
```

**4. Application Services**
```php
// src/Application/Service/WorkflowExecutionService.php
namespace App\Application\Service;

final readonly class WorkflowExecutionService
{
    public function __construct(
        private WorkflowRepositoryInterface $workflowRepository,
        private LLMAgentClientInterface $llmAgentClient,
        private EventPublisherInterface $eventPublisher,
    ) {}

    public function execute(WorkflowId $id, array $input): void
    {
        $workflow = $this->workflowRepository->findById($id);

        if ($workflow === null) {
            throw new WorkflowNotFoundException($id);
        }

        $workflow->start();
        $this->workflowRepository->save($workflow);

        // Orchestrate external calls via ports
        foreach ($workflow->getSteps() as $step) {
            if ($step->isAgentStep()) {
                $this->llmAgentClient->execute($step->getAgentId(), $input);
            }
        }

        $this->eventPublisher->publish(new WorkflowStarted($id));
    }
}
```

### Infrastructure Layer (outermost)

**Purpose**: Implements the ports (interfaces) defined by the application core. Handles all technical concerns.

**Characteristics**:
- ✅ Implements outbound ports
- ✅ Contains all framework code
- ✅ Database access (Doctrine)
- ✅ HTTP clients
- ✅ Message queues
- ✅ File systems
- ❌ No business logic

**Contains**:

**1. Inbound Adapters - REST Controllers**
```php
// src/Infrastructure/Http/Controller/WorkflowController.php
namespace App\Infrastructure\Http\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Annotation\Route;
use Symfony\Component\Messenger\MessageBusInterface;

#[Route('/api/v1/workflows')]
final class WorkflowController extends AbstractController
{
    public function __construct(
        private readonly MessageBusInterface $commandBus,
        private readonly MessageBusInterface $queryBus,
    ) {}

    #[Route('', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);

        $command = new CreateWorkflowCommand(
            name: $data['name'],
            steps: $data['steps'],
        );

        $workflowId = $this->commandBus->dispatch($command);

        return $this->json(['id' => $workflowId->toString()], 201);
    }

    #[Route('/{id}', methods: ['GET'])]
    public function get(string $id): JsonResponse
    {
        $query = new GetWorkflowQuery($id);
        $dto = $this->queryBus->dispatch($query);

        return $this->json($dto->toArray());
    }
}
```

**2. Outbound Adapters - Repository Implementation**
```php
// src/Infrastructure/Persistence/DoctrineWorkflowRepository.php
namespace App\Infrastructure\Persistence;

use App\Domain\Entity\Workflow;
use App\Domain\Repository\WorkflowRepositoryInterface;
use App\Domain\ValueObject\WorkflowId;
use Doctrine\ORM\EntityManagerInterface;

final readonly class DoctrineWorkflowRepository implements WorkflowRepositoryInterface
{
    public function __construct(
        private EntityManagerInterface $entityManager,
    ) {}

    public function save(Workflow $workflow): void
    {
        $this->entityManager->persist($workflow);
        $this->entityManager->flush();
    }

    public function findById(WorkflowId $id): ?Workflow
    {
        return $this->entityManager
            ->getRepository(Workflow::class)
            ->find($id->toString());
    }

    public function findByState(WorkflowState $state): Collection
    {
        $results = $this->entityManager
            ->getRepository(Workflow::class)
            ->findBy(['state' => $state->toString()]);

        return new Collection($results);
    }

    public function delete(WorkflowId $id): void
    {
        $workflow = $this->findById($id);
        if ($workflow !== null) {
            $this->entityManager->remove($workflow);
            $this->entityManager->flush();
        }
    }
}
```

**3. Outbound Adapters - External Service Clients**
```php
// src/Infrastructure/ExternalService/OpenAILLMProvider.php
namespace App\Infrastructure\ExternalService;

use App\Domain\Service\LLMProviderInterface;

final readonly class OpenAILLMProvider implements LLMProviderInterface
{
    public function __construct(
        private HttpClientInterface $httpClient,
        private string $apiKey,
    ) {}

    public function execute(Prompt $prompt, Model $model, Configuration $config): Response
    {
        $response = $this->httpClient->request('POST', 'https://api.openai.com/v1/chat/completions', [
            'headers' => [
                'Authorization' => "Bearer {$this->apiKey}",
                'Content-Type' => 'application/json',
            ],
            'json' => [
                'model' => $model->toString(),
                'messages' => $prompt->toMessages(),
                'temperature' => $config->temperature,
                'max_tokens' => $config->maxTokens,
            ],
        ]);

        $data = $response->toArray();

        return new Response(
            content: $data['choices'][0]['message']['content'],
            tokensUsed: $data['usage']['total_tokens'],
            model: $model,
        );
    }
}
```

**4. Outbound Adapters - Event Publisher**
```php
// src/Infrastructure/Messaging/RabbitMQEventPublisher.php
namespace App\Infrastructure\Messaging;

use App\Domain\Event\DomainEventInterface;
use App\Domain\Service\EventPublisherInterface;
use Symfony\Component\Messenger\MessageBusInterface;

final readonly class RabbitMQEventPublisher implements EventPublisherInterface
{
    public function __construct(
        private MessageBusInterface $eventBus,
    ) {}

    public function publish(DomainEventInterface $event): void
    {
        $this->eventBus->dispatch($event);
    }

    public function publishBatch(array $events): void
    {
        foreach ($events as $event) {
            $this->publish($event);
        }
    }
}
```

**5. Doctrine Mapping (XML/YAML, not annotations)**
```yaml
# config/doctrine/Workflow.orm.yaml
App\Domain\Entity\Workflow:
  type: entity
  table: workflows
  id:
    id:
      type: workflow_id  # Custom Doctrine type
      generator:
        strategy: NONE
  fields:
    name:
      type: string
      length: 255
    state:
      type: workflow_state  # Custom Doctrine type
    createdAt:
      type: datetime_immutable
      column: created_at
  oneToMany:
    steps:
      targetEntity: App\Domain\Entity\Step
      mappedBy: workflow
      cascade: [persist, remove]
```

**6. Custom Doctrine Types**
```php
// src/Infrastructure/Persistence/Type/WorkflowIdType.php
namespace App\Infrastructure\Persistence\Type;

use App\Domain\ValueObject\WorkflowId;
use Doctrine\DBAL\Types\Type;
use Doctrine\DBAL\Platforms\AbstractPlatform;

final class WorkflowIdType extends Type
{
    public const NAME = 'workflow_id';

    public function getSQLDeclaration(array $column, AbstractPlatform $platform): string
    {
        return $platform->getGuidTypeDeclarationSQL($column);
    }

    public function convertToPHPValue($value, AbstractPlatform $platform): ?WorkflowId
    {
        return $value === null ? null : new WorkflowId($value);
    }

    public function convertToDatabaseValue($value, AbstractPlatform $platform): ?string
    {
        return $value instanceof WorkflowId ? $value->toString() : null;
    }

    public function getName(): string
    {
        return self::NAME;
    }
}
```

## Directory Structure

```
src/
├── Domain/                          # Pure business logic
│   ├── Entity/
│   │   ├── Workflow.php
│   │   ├── Step.php
│   │   └── WorkflowInstance.php
│   ├── ValueObject/
│   │   ├── WorkflowId.php
│   │   ├── WorkflowState.php
│   │   └── StepConfiguration.php
│   ├── Repository/                  # Interfaces (ports)
│   │   ├── WorkflowRepositoryInterface.php
│   │   └── WorkflowInstanceRepositoryInterface.php
│   ├── Service/                     # Domain services
│   │   ├── WorkflowValidator.php
│   │   └── StepExecutor.php
│   ├── Event/                       # Domain events
│   │   ├── WorkflowStarted.php
│   │   ├── StepCompleted.php
│   │   └── WorkflowFailed.php
│   ├── Exception/                   # Domain exceptions
│   │   ├── WorkflowNotFoundException.php
│   │   └── InvalidWorkflowException.php
│   └── Collection/                  # Domain collections
│       └── StepCollection.php
│
├── Application/                     # Use cases & orchestration
│   ├── Command/                     # Write operations
│   │   ├── CreateWorkflowCommand.php
│   │   ├── StartWorkflowCommand.php
│   │   └── DeleteWorkflowCommand.php
│   ├── Query/                       # Read operations
│   │   ├── GetWorkflowQuery.php
│   │   └── ListWorkflowsQuery.php
│   ├── Handler/                     # Command/Query handlers
│   │   ├── CreateWorkflowHandler.php
│   │   ├── StartWorkflowHandler.php
│   │   ├── GetWorkflowHandler.php
│   │   └── ListWorkflowsHandler.php
│   ├── DTO/                         # Data transfer objects
│   │   ├── WorkflowDTO.php
│   │   └── StepDTO.php
│   └── Service/                     # Application services
│       ├── WorkflowExecutionService.php
│       └── WorkflowQueryService.php
│
└── Infrastructure/                  # Technical implementation
    ├── Http/                        # Inbound adapter: REST API
    │   ├── Controller/
    │   │   ├── WorkflowController.php
    │   │   └── HealthController.php
    │   ├── Request/
    │   │   └── CreateWorkflowRequest.php
    │   └── Response/
    │       └── WorkflowResponse.php
    ├── Cli/                         # Inbound adapter: CLI
    │   └── Command/
    │       └── ExecuteWorkflowCommand.php
    ├── Messaging/                   # Inbound/Outbound: Message queue
    │   ├── Consumer/
    │   │   └── WorkflowEventConsumer.php
    │   └── Publisher/
    │       └── RabbitMQEventPublisher.php
    ├── Persistence/                 # Outbound adapter: Database
    │   ├── Repository/
    │   │   ├── DoctrineWorkflowRepository.php
    │   │   └── DoctrineWorkflowInstanceRepository.php
    │   └── Type/
    │       ├── WorkflowIdType.php
    │       └── WorkflowStateType.php
    ├── ExternalService/             # Outbound adapter: External APIs
    │   ├── OpenAILLMProvider.php
    │   ├── AnthropicLLMProvider.php
    │   └── LLMProviderFactory.php
    ├── Security/
    │   ├── Voter/
    │   │   └── WorkflowVoter.php
    │   └── Guard/
    │       └── ApiKeyAuthenticator.php
    └── EventListener/
        ├── ExceptionListener.php
        └── DomainEventListener.php
```

## Dependency Rules

### The Dependency Rule (Critical)

**Dependencies always point inward:**

```
Infrastructure → Application → Domain
                              ↑
                              |
                    (Domain depends on NOTHING)
```

**Rules**:
1. **Domain** depends on nothing (pure PHP)
2. **Application** depends only on Domain
3. **Infrastructure** depends on Application and Domain

**Enforcement**:
- Use PHPStan with `deptrac` to enforce dependency rules
- Automated checks in CI/CD pipeline
- Pull request reviews

### Dependency Injection

**Register adapters as implementations of ports:**

```yaml
# config/services.yaml
services:
  # Domain services (no dependencies on infrastructure)
  App\Domain\Service\WorkflowValidator: ~

  # Application services (depend on ports/interfaces)
  App\Application\Handler\CreateWorkflowHandler:
    arguments:
      $workflowRepository: '@App\Domain\Repository\WorkflowRepositoryInterface'
      $eventPublisher: '@App\Domain\Service\EventPublisherInterface'
      $validator: '@App\Domain\Service\WorkflowValidator'

  # Infrastructure adapters (implement ports)
  App\Infrastructure\Persistence\DoctrineWorkflowRepository: ~

  # Bind interface to implementation
  App\Domain\Repository\WorkflowRepositoryInterface:
    alias: App\Infrastructure\Persistence\DoctrineWorkflowRepository

  App\Domain\Service\EventPublisherInterface:
    alias: App\Infrastructure\Messaging\RabbitMQEventPublisher

  # LLM Provider factory
  App\Infrastructure\ExternalService\LLMProviderFactory:
    arguments:
      $providers:
        openai: '@App\Infrastructure\ExternalService\OpenAILLMProvider'
        anthropic: '@App\Infrastructure\ExternalService\AnthropicLLMProvider'
```

## Testing Strategy

### 1. Domain Layer Tests (Unit Tests)

**Fast, isolated, no dependencies:**

```php
// tests/Unit/Domain/Entity/WorkflowTest.php
namespace App\Tests\Unit\Domain\Entity;

use PHPUnit\Framework\TestCase;

final class WorkflowTest extends TestCase
{
    public function testCannotStartWorkflowTwice(): void
    {
        $workflow = new Workflow(
            WorkflowId::generate(),
            'Test Workflow'
        );

        $workflow->start();

        $this->expectException(WorkflowAlreadyStartedException::class);
        $workflow->start();
    }

    public function testCannotAddStepToRunningWorkflow(): void
    {
        $workflow = new Workflow(
            WorkflowId::generate(),
            'Test Workflow'
        );

        $workflow->start();

        $this->expectException(CannotModifyRunningWorkflowException::class);
        $workflow->addStep(new Step(/* ... */));
    }
}
```

### 2. Application Layer Tests (Integration Tests)

**Test with mocked ports:**

```php
// tests/Integration/Application/Handler/CreateWorkflowHandlerTest.php
namespace App\Tests\Integration\Application\Handler;

use PHPUnit\Framework\TestCase;
use PHPUnit\Framework\MockObject\MockObject;

final class CreateWorkflowHandlerTest extends TestCase
{
    private WorkflowRepositoryInterface|MockObject $repository;
    private EventPublisherInterface|MockObject $eventPublisher;
    private CreateWorkflowHandler $handler;

    protected function setUp(): void
    {
        $this->repository = $this->createMock(WorkflowRepositoryInterface::class);
        $this->eventPublisher = $this->createMock(EventPublisherInterface::class);
        $this->handler = new CreateWorkflowHandler(
            $this->repository,
            $this->eventPublisher,
            new WorkflowValidator()
        );
    }

    public function testCreatesWorkflowSuccessfully(): void
    {
        $command = new CreateWorkflowCommand(
            name: 'Test Workflow',
            steps: [/* ... */]
        );

        $this->repository
            ->expects($this->once())
            ->method('save')
            ->with($this->isInstanceOf(Workflow::class));

        $this->eventPublisher
            ->expects($this->once())
            ->method('publish');

        $id = ($this->handler)($command);

        $this->assertInstanceOf(WorkflowId::class, $id);
    }
}
```

### 3. Infrastructure Tests (Functional Tests)

**Test real adapters:**

```php
// tests/Functional/Infrastructure/Persistence/DoctrineWorkflowRepositoryTest.php
namespace App\Tests\Functional\Infrastructure\Persistence;

use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;

final class DoctrineWorkflowRepositoryTest extends KernelTestCase
{
    private DoctrineWorkflowRepository $repository;

    protected function setUp(): void
    {
        self::bootKernel();
        $this->repository = self::getContainer()->get(DoctrineWorkflowRepository::class);
    }

    public function testSavesAndRetrievesWorkflow(): void
    {
        $workflow = new Workflow(
            WorkflowId::generate(),
            'Test Workflow'
        );

        $this->repository->save($workflow);

        $retrieved = $this->repository->findById($workflow->getId());

        $this->assertEquals($workflow->getId(), $retrieved->getId());
        $this->assertEquals($workflow->getName(), $retrieved->getName());
    }
}
```

## Common Pitfalls & Solutions

### ❌ Pitfall 1: Leaking Infrastructure into Domain

**Bad:**
```php
// src/Domain/Entity/Workflow.php
use Doctrine\ORM\Mapping as ORM;  // ❌ Doctrine in domain!

#[ORM\Entity]  // ❌ Framework annotation in domain!
class Workflow
{
    #[ORM\Id]
    #[ORM\Column(type: 'uuid')]
    private string $id;
}
```

**Good:**
```php
// src/Domain/Entity/Workflow.php
// ✅ Pure PHP, no framework dependencies
class Workflow
{
    private WorkflowId $id;

    // Business logic only
}

// config/doctrine/Workflow.orm.yaml
# ✅ Mapping in infrastructure layer
```

### ❌ Pitfall 2: Business Logic in Controllers

**Bad:**
```php
#[Route('/workflows', methods: ['POST'])]
public function create(Request $request): JsonResponse
{
    $data = json_decode($request->getContent(), true);

    // ❌ Business logic in controller!
    if (empty($data['name'])) {
        throw new \InvalidArgumentException('Name required');
    }

    $workflow = new Workflow(/* ... */);
    $this->entityManager->persist($workflow);
    $this->entityManager->flush();

    return $this->json(['id' => $workflow->getId()]);
}
```

**Good:**
```php
#[Route('/workflows', methods: ['POST'])]
public function create(Request $request): JsonResponse
{
    $data = json_decode($request->getContent(), true);

    // ✅ Delegate to application layer
    $command = new CreateWorkflowCommand($data['name'], $data['steps']);
    $id = $this->commandBus->dispatch($command);

    return $this->json(['id' => $id->toString()], 201);
}
```

### ❌ Pitfall 3: Domain Depending on Application

**Bad:**
```php
// src/Domain/Entity/Workflow.php
use App\Application\DTO\WorkflowDTO;  // ❌ Domain depends on application!

class Workflow
{
    public function toDTO(): WorkflowDTO  // ❌ Domain knows about DTO!
    {
        return new WorkflowDTO(/* ... */);
    }
}
```

**Good:**
```php
// src/Application/DTO/WorkflowDTO.php
class WorkflowDTO
{
    // ✅ Application layer knows about domain, not vice versa
    public static function fromEntity(Workflow $workflow): self
    {
        return new self(
            id: $workflow->getId()->toString(),
            name: $workflow->getName(),
        );
    }
}
```

## Benefits Realized

### 1. Testability
- Domain: 100% unit test coverage without infrastructure
- Application: Integration tests with mocked ports
- Infrastructure: Functional tests with real implementations

### 2. Flexibility
- Swap OpenAI for Anthropic: Change one adapter
- Migrate from PostgreSQL to MongoDB: Change repository adapter
- Switch from REST to GraphQL: Add new inbound adapter

### 3. Maintainability
- Business logic isolated and clearly defined
- Infrastructure changes don't affect business rules
- Easy to understand: "What" vs "How" clearly separated

### 4. Evolution
- Upgrade Symfony: Only infrastructure layer affected
- New PHP version: Gradually adopt in layers
- New database: Implement new adapter, run in parallel

## Conclusion

Hexagonal Architecture ensures:
- ✅ **Business logic purity**: Domain layer is pure PHP
- ✅ **Framework independence**: Can replace Symfony without touching domain
- ✅ **High testability**: Each layer tested in isolation
- ✅ **Clear boundaries**: Explicit separation of concerns
- ✅ **Flexibility**: Easy to swap infrastructure components

This architecture is the foundation for long-term maintainability and scalability of the platform.
