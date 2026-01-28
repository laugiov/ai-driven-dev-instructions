# Domain-Driven Design (DDD)

## Overview

This document explains how Domain-Driven Design principles are applied across the platform. DDD provides patterns and practices for modeling complex business domains and ensuring the codebase reflects business reality.

## Why Domain-Driven Design?

### Problems It Solves

**1. Complexity Management**
- Business logic scattered across codebase
- Unclear business rules and invariants
- Difficulty understanding what code does from business perspective

**2. Communication Gap**
- Developers and domain experts speak different languages
- Requirements misunderstood or lost in translation
- Code doesn't reflect business concepts

**3. Evolution Challenges**
- Changes to business rules require changes throughout codebase
- Unclear boundaries between different areas of system
- Tight coupling makes changes risky

### Benefits

✅ **Shared Understanding**: Ubiquitous language bridges developers and domain experts
✅ **Clear Boundaries**: Bounded contexts separate concerns
✅ **Business-Centric**: Code reflects business concepts directly
✅ **Maintainability**: Changes to business rules localized
✅ **Testability**: Business rules tested independently
✅ **Scalability**: Clear boundaries enable microservices

## Strategic DDD: Bounded Contexts

### What is a Bounded Context?

A **Bounded Context** is an explicit boundary within which a domain model is defined and applicable. It defines the scope where a particular ubiquitous language is valid.

### Our Bounded Contexts

```
┌─────────────────────────────────────────────────────────────────┐
│                     Business Domain                              │
│           AI-Powered Workflow Processing Platform                 │
└─────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┴───────────────────┐
          │                                       │
┌─────────▼──────────┐                 ┌─────────▼──────────┐
│  AI Processing     │                 │ Process Management │
│  Context           │                 │ Context            │
│                    │                 │                    │
│ - Agent            │                 │ - Workflow         │
│ - Execution        │                 │ - WorkflowInstance │
│ - Prompt           │                 │ - Task             │
│ - Response         │                 │ - Step             │
│ - Context          │                 │ - Execution Graph  │
│ - Token            │                 │                    │
│                    │                 │ Language:          │
│ Language:          │                 │ "workflow",        │
│ "agent", "prompt", │                 │ "orchestration",   │
│ "execution"        │                 │ "saga"             │
└────────────────────┘                 └────────────────────┘
          │                                       │
          └───────────────────┬───────────────────┘
                              │
          ┌───────────────────┴───────────────────┐
          │                                       │
┌─────────▼──────────┐                 ┌─────────▼──────────┐
│ Quality Control    │                 │  Communication     │
│ Context            │                 │  Context           │
│                    │                 │                    │
│ - ValidationRule   │                 │ - Notification     │
│ - ValidationResult │                 │ - Template         │
│ - Score            │                 │ - Recipient        │
│ - Feedback         │                 │ - Channel          │
│ - Threshold        │                 │ - Delivery         │
│                    │                 │                    │
│ Language:          │                 │ Language:          │
│ "validation",      │                 │ "notification",    │
│ "quality check"    │                 │ "delivery"         │
└────────────────────┘                 └────────────────────┘
          │                                       │
          └───────────────────┬───────────────────┘
                              │
          ┌───────────────────┴───────────────────┐
          │                                       │
┌─────────▼──────────┐                 ┌─────────▼──────────┐
│  Compliance        │                 │ Document Mgmt      │
│  Context           │                 │ Context            │
│                    │                 │                    │
│ - AuditEvent       │                 │ - File             │
│ - ComplianceReport │                 │ - FileVersion      │
│ - RetentionPolicy  │                 │ - Permission       │
│ - AccessLog        │                 │ - ScanResult       │
│                    │                 │ - Storage          │
│                    │                 │                    │
│ Language:          │                 │ Language:          │
│ "audit", "trail",  │                 │ "file", "upload",  │
│ "compliance"       │                 │ "storage"          │
└────────────────────┘                 └────────────────────┘
          │                                       │
          └───────────────────┬───────────────────┘
                              │
                    ┌─────────▼──────────┐
                    │ Identity & Access  │
                    │ Context            │
                    │ (Keycloak)         │
                    │                    │
                    │ - User             │
                    │ - Role             │
                    │ - Permission       │
                    │ - Token            │
                    │                    │
                    │ Language:          │
                    │ "authentication",  │
                    │ "authorization"    │
                    └────────────────────┘
```

### Context Mapping

**Relationship Types**:

**1. Partnership**: Two contexts collaborate closely
- AI Processing ↔ Process Management
- Both evolve together to support workflows

**2. Customer-Supplier**: Upstream context serves downstream
- Quality Control (supplier) → Process Management (customer)
- Validation results feed workflow decisions

**3. Conformist**: Downstream conforms to upstream model
- All contexts → Identity & Access (Keycloak)
- All services conform to Keycloak's user model

**4. Anti-Corruption Layer (ACL)**: Translate between contexts
- AI Processing → External LLM APIs
- ACL translates between our domain model and OpenAI's API

**5. Published Language**: Standardized schema for integration
- All contexts → Event Bus
- Events use standardized JSON schema

## Tactical DDD: Building Blocks

### 1. Entities

**Definition**: Objects with unique identity that persists over time, even if attributes change.

**Characteristics**:
- Has unique identifier (ID)
- Mutable (state can change)
- Identity matters more than attributes
- Continuity through state changes

**Example**:

```php
// src/Domain/Entity/Workflow.php
namespace App\Domain\Entity;

final class Workflow
{
    private WorkflowId $id;  // ← Identity
    private string $name;
    private WorkflowState $state;  // ← Can change
    private Collection $steps;
    private array $domainEvents = [];

    public function __construct(WorkflowId $id, string $name)
    {
        $this->id = $id;
        $this->name = $name;
        $this->state = WorkflowState::draft();
        $this->steps = new Collection();

        $this->recordEvent(new WorkflowCreated($id, $name));
    }

    // Identity-based equality
    public function equals(Workflow $other): bool
    {
        return $this->id->equals($other->id);
    }

    // State transitions with business rules
    public function start(): void
    {
        if (!$this->state->isDraft()) {
            throw new WorkflowAlreadyStartedException($this->id);
        }

        $this->state = WorkflowState::running();
        $this->recordEvent(new WorkflowStarted($this->id));
    }

    // Getters, business methods...
}
```

**Guidelines**:
- Always use Value Object for ID (not primitive string)
- Enforce invariants in constructor and methods
- Record domain events for state changes
- Equality based on ID, not attributes

### 2. Value Objects

**Definition**: Objects defined by their attributes, not identity. Immutable.

**Characteristics**:
- No unique identifier
- Immutable (readonly in PHP 8.3)
- Equality based on attributes
- Replaceability (if equal, interchangeable)
- Self-validating

**Example**:

```php
// src/Domain/ValueObject/WorkflowId.php
namespace App\Domain\ValueObject;

final readonly class WorkflowId
{
    private string $value;

    private function __construct(string $value)
    {
        if (!Uuid::isValid($value)) {
            throw new InvalidWorkflowIdException($value);
        }
        $this->value = $value;
    }

    public static function fromString(string $value): self
    {
        return new self($value);
    }

    public static function generate(): self
    {
        return new self(Uuid::v4()->toString());
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

```php
// src/Domain/ValueObject/EmailAddress.php
namespace App\Domain\ValueObject;

final readonly class EmailAddress
{
    private string $value;

    private function __construct(string $value)
    {
        if (!filter_var($value, FILTER_VALIDATE_EMAIL)) {
            throw new InvalidEmailAddressException($value);
        }
        $this->value = strtolower($value);
    }

    public static function fromString(string $value): self
    {
        return new self($value);
    }

    public function toString(): string
    {
        return $this->value;
    }

    public function getDomain(): string
    {
        return explode('@', $this->value)[1];
    }
}
```

```php
// src/Domain/ValueObject/Money.php
namespace App\Domain\ValueObject;

final readonly class Money
{
    private int $amount;  // Store in cents to avoid float issues
    private Currency $currency;

    private function __construct(int $amount, Currency $currency)
    {
        if ($amount < 0) {
            throw new InvalidAmountException('Amount cannot be negative');
        }
        $this->amount = $amount;
        $this->currency = $currency;
    }

    public static function fromCents(int $cents, Currency $currency): self
    {
        return new self($cents, $currency);
    }

    public static function fromFloat(float $amount, Currency $currency): self
    {
        return new self((int) round($amount * 100), $currency);
    }

    public function add(Money $other): self
    {
        if (!$this->currency->equals($other->currency)) {
            throw new CurrencyMismatchException();
        }
        return new self($this->amount + $other->amount, $this->currency);
    }

    public function multiply(int $factor): self
    {
        return new self($this->amount * $factor, $this->currency);
    }

    public function toFloat(): float
    {
        return $this->amount / 100;
    }
}
```

**When to Use Value Objects**:
- IDs, email addresses, phone numbers
- Money, quantities, measurements
- Dates, time ranges
- Addresses, coordinates
- Status codes, types, categories

**Guidelines**:
- Make immutable (readonly class/properties)
- Validate in constructor
- Use private constructor + named constructors
- Implement equals() method
- Provide rich behavior (not just data bags)

### 3. Aggregates

**Definition**: Cluster of entities and value objects with a consistency boundary. Has one Aggregate Root.

**Characteristics**:
- Aggregate Root is an Entity that controls access
- External objects can only reference the root
- Invariants enforced within aggregate boundary
- Transactional consistency boundary
- One aggregate per database transaction

**Example**:

```php
// Workflow is the Aggregate Root
// Steps are internal entities
namespace App\Domain\Entity;

final class Workflow  // ← Aggregate Root
{
    private WorkflowId $id;
    private string $name;
    private WorkflowState $state;
    private StepCollection $steps;  // ← Internal entities

    // External code cannot directly create Steps
    // Must go through Workflow methods

    public function addStep(
        string $name,
        StepType $type,
        StepConfiguration $config
    ): void {
        // Enforce invariants
        if (!$this->state->isDraft()) {
            throw new CannotModifyRunningWorkflowException($this->id);
        }

        if ($this->steps->count() >= 100) {
            throw new TooManyStepsException($this->id);
        }

        // Create step internally
        $step = new Step(
            StepId::generate(),
            $this->id,  // ← Link to parent
            $name,
            $type,
            $config
        );

        $this->steps->add($step);
        $this->recordEvent(new StepAdded($this->id, $step->getId()));
    }

    public function removeStep(StepId $stepId): void
    {
        if (!$this->state->isDraft()) {
            throw new CannotModifyRunningWorkflowException($this->id);
        }

        $step = $this->steps->findById($stepId);
        if ($step === null) {
            throw new StepNotFoundException($stepId);
        }

        $this->steps->remove($step);
        $this->recordEvent(new StepRemoved($this->id, $stepId));
    }

    // Repository saves entire aggregate atomically
}
```

**Aggregate Rules**:
1. ✅ Reference other aggregates by ID only
2. ✅ One aggregate per transaction
3. ✅ Enforce invariants within boundary
4. ✅ Use domain events for eventual consistency
5. ❌ Don't hold references to other aggregate roots
6. ❌ Don't access internal entities from outside

**Example: Workflow Instance (Another Aggregate)**

```php
namespace App\Domain\Entity;

final class WorkflowInstance  // ← Separate aggregate
{
    private InstanceId $id;
    private WorkflowId $workflowId;  // ← Reference by ID
    private InstanceState $state;
    private TaskCollection $tasks;  // ← Internal entities

    public function executeNextTask(LLMProviderInterface $llmProvider): void
    {
        $task = $this->tasks->findNextPending();

        if ($task === null) {
            $this->complete();
            return;
        }

        $task->execute($llmProvider);
        $this->recordEvent(new TaskExecuted($this->id, $task->getId()));

        // If this was the last task, complete
        if ($this->tasks->allCompleted()) {
            $this->complete();
        }
    }

    private function complete(): void
    {
        $this->state = InstanceState::completed();
        $this->recordEvent(new WorkflowInstanceCompleted($this->id));
    }
}
```

**Designing Aggregate Boundaries**:
- **Small aggregates**: Easier to scale, less contention
- **Business rules**: What must be consistent immediately?
- **Invariants**: What rules cannot be broken?
- **Transaction**: What must be saved together?

### 4. Domain Services

**Definition**: Operations that don't naturally belong to an Entity or Value Object.

**When to Use**:
- Operation involves multiple aggregates
- Operation doesn't have natural home in any entity
- Algorithm or calculation spans multiple entities
- External domain expertise

**Example**:

```php
// src/Domain/Service/WorkflowValidator.php
namespace App\Domain\Service;

final readonly class WorkflowValidator
{
    public function validateDefinition(Workflow $workflow): ValidationResult
    {
        $errors = [];

        // Must have at least one step
        if ($workflow->getSteps()->isEmpty()) {
            $errors[] = 'Workflow must have at least one step';
        }

        // Check for circular dependencies
        if ($this->hasCircularDependencies($workflow)) {
            $errors[] = 'Workflow contains circular dependencies';
        }

        // Check for unreachable steps
        $unreachable = $this->findUnreachableSteps($workflow);
        if (!empty($unreachable)) {
            $errors[] = sprintf(
                'Steps are unreachable: %s',
                implode(', ', $unreachable)
            );
        }

        return new ValidationResult($errors);
    }

    private function hasCircularDependencies(Workflow $workflow): bool
    {
        // Graph traversal algorithm
        // Complex logic that doesn't belong in Workflow entity
    }

    private function findUnreachableSteps(Workflow $workflow): array
    {
        // Another complex algorithm
    }
}
```

```php
// src/Domain/Service/TokenCalculator.php
namespace App\Domain/Service;

final readonly class TokenCalculator
{
    // Collaborates with multiple entities
    public function calculateCost(
        Execution $execution,
        PricingPolicy $policy
    ): Money {
        $tokensUsed = $execution->getTokensUsed();
        $model = $execution->getModel();

        $pricePerToken = $policy->getPriceForModel($model);

        return $pricePerToken->multiply($tokensUsed);
    }

    public function estimateTokens(Prompt $prompt): int
    {
        // Complex estimation algorithm
        // Doesn't belong in Prompt value object
    }
}
```

**Guidelines**:
- Keep stateless (readonly class)
- Use only when operation doesn't fit in entity/VO
- Don't overuse (prefer rich domain models)
- Name clearly: `WorkflowValidator`, not `WorkflowService`

### 5. Domain Events

**Definition**: Something that happened in the domain that domain experts care about.

**Characteristics**:
- Immutable (readonly)
- Past tense naming (WorkflowStarted, not StartWorkflow)
- Contains relevant data
- Timestamp of occurrence
- Reflects business events

**Example**:

```php
// src/Domain/Event/WorkflowStarted.php
namespace App\Domain\Event;

final readonly class WorkflowStarted implements DomainEventInterface
{
    public function __construct(
        public WorkflowId $workflowId,
        public string $workflowName,
        public UserId $startedBy,
        public DateTimeImmutable $occurredAt = new DateTimeImmutable(),
    ) {}

    public function toArray(): array
    {
        return [
            'workflowId' => $this->workflowId->toString(),
            'workflowName' => $this->workflowName,
            'startedBy' => $this->startedBy->toString(),
            'occurredAt' => $this->occurredAt->format(DateTimeImmutable::ATOM),
        ];
    }
}
```

**Recording Events in Aggregates**:

```php
final class Workflow
{
    private array $domainEvents = [];

    protected function recordEvent(DomainEventInterface $event): void
    {
        $this->domainEvents[] = $event;
    }

    public function pullDomainEvents(): array
    {
        $events = $this->domainEvents;
        $this->domainEvents = [];
        return $events;
    }

    public function start(): void
    {
        // Business logic
        $this->state = WorkflowState::running();

        // Record event
        $this->recordEvent(new WorkflowStarted(
            $this->id,
            $this->name,
            $this->startedBy
        ));
    }
}
```

**Publishing Events (in Application Layer)**:

```php
// src/Application/Handler/StartWorkflowHandler.php
final readonly class StartWorkflowHandler
{
    public function __construct(
        private WorkflowRepositoryInterface $repository,
        private EventPublisherInterface $eventPublisher,
    ) {}

    public function __invoke(StartWorkflowCommand $command): void
    {
        $workflow = $this->repository->findById($command->workflowId);

        // Domain logic
        $workflow->start();

        // Persist
        $this->repository->save($workflow);

        // Publish events
        foreach ($workflow->pullDomainEvents() as $event) {
            $this->eventPublisher->publish($event);
        }
    }
}
```

**Event Types**:

**1. Domain Events (internal to bounded context)**
```php
WorkflowStarted
StepCompleted
ValidationFailed
```

**2. Integration Events (between bounded contexts)**
```php
WorkflowCompletedIntegrationEvent  // Consumed by other services
AgentExecutionCompletedIntegrationEvent
```

**Guidelines**:
- Past tense names
- Immutable data
- Include relevant context (IDs, timestamps)
- Don't include entire aggregates (just IDs)
- Record in domain layer, publish in application layer

### 6. Repositories

**Definition**: Interface for accessing aggregates, abstracts persistence.

**Characteristics**:
- Interface in domain layer
- Implementation in infrastructure layer
- Collection-like API
- Works with aggregate roots only
- Hides persistence details

**Example**:

```php
// src/Domain/Repository/WorkflowRepositoryInterface.php
namespace App\Domain\Repository;

interface WorkflowRepositoryInterface
{
    public function save(Workflow $workflow): void;

    public function findById(WorkflowId $id): ?Workflow;

    public function findByUserId(UserId $userId): WorkflowCollection;

    public function findByState(WorkflowState $state): WorkflowCollection;

    public function delete(WorkflowId $id): void;

    public function nextIdentity(): WorkflowId;
}
```

**Guidelines**:
- ✅ Return aggregates, not DTOs
- ✅ Return null or throw exception for not found
- ✅ Use domain types (WorkflowId, not string)
- ✅ Collection-like methods (findById, findByX)
- ❌ Don't expose query builder
- ❌ Don't return collections of multiple aggregate types

### 7. Factories

**Definition**: Encapsulates complex creation logic.

**When to Use**:
- Complex construction process
- Multiple steps or dependencies
- Creation from external data
- Reconstitution from storage

**Example**:

```php
// src/Domain/Factory/WorkflowFactory.php
namespace App\Domain\Factory;

final readonly class WorkflowFactory
{
    public function createFromTemplate(
        WorkflowTemplate $template,
        UserId $createdBy
    ): Workflow {
        $id = WorkflowId::generate();
        $workflow = new Workflow($id, $template->getName(), $createdBy);

        foreach ($template->getStepDefinitions() as $stepDef) {
            $workflow->addStep(
                $stepDef->getName(),
                $stepDef->getType(),
                $stepDef->getConfiguration()
            );
        }

        return $workflow;
    }

    public function reconstitute(array $data): Workflow
    {
        // Complex reconstitution from array
        // Used by repository when loading from database
    }
}
```

## Ubiquitous Language

**Definition**: A language structured around the domain model, used by all team members.

### Our Ubiquitous Language

**AI Processing Context**:
- **Agent**: An AI entity configured with a specific prompt and model
- **Execution**: A single invocation of an agent with a prompt
- **Prompt**: The input text sent to an LLM
- **Response**: The output text returned by an LLM
- **Context**: The conversation history maintained for an agent
- **Token**: Unit of text consumption for LLM APIs

**Process Management Context**:
- **Workflow**: A defined sequence of steps to accomplish a goal
- **Workflow Instance**: A running execution of a workflow
- **Step**: An individual operation within a workflow
- **Task**: A concrete execution of a step
- **Orchestration**: Coordinating multiple steps/agents
- **Saga**: A long-running transaction with compensation logic

**Quality Control Context**:
- **Validation**: Checking output against rules
- **Rule**: A criterion that output must satisfy
- **Score**: Numeric quality assessment (0-1)
- **Feedback**: Actionable improvement suggestions
- **Threshold**: Minimum acceptable score

### Using Ubiquitous Language

**✅ DO**:
```php
// Code reflects domain language
$workflow->start();
$agent->execute($prompt);
$validator->validate($output);
```

**❌ DON'T**:
```php
// Generic technical terms
$process->run();
$service->call($input);
$checker->check($data);
```

**In Conversations**:
> "When a workflow is started, each step is converted to a task. The workflow orchestrator executes tasks sequentially or in parallel based on dependencies. After each agent execution, the validation service checks the output against configured rules. If the validation score exceeds the threshold, the workflow proceeds to the next step."

**In Documentation**:
- Use domain terms consistently
- Define terms in glossary
- Update language as domain evolves
- Avoid technical jargon in domain layer

## Layered Architecture with DDD

```
┌──────────────────────────────────────────────────────────┐
│                  User Interface Layer                     │
│              (Controllers, CLI, GraphQL)                  │
└────────────────────────┬─────────────────────────────────┘
                         │
┌────────────────────────▼─────────────────────────────────┐
│                  Application Layer                        │
│        (Use Cases, Command/Query Handlers, DTOs)          │
└────────────────────────┬─────────────────────────────────┘
                         │
┌────────────────────────▼─────────────────────────────────┐
│                    Domain Layer                           │
│  (Entities, VOs, Aggregates, Services, Events, Repos)    │
│                                                           │
│               *** PURE BUSINESS LOGIC ***                 │
└────────────────────────┬─────────────────────────────────┘
                         │
┌────────────────────────▼─────────────────────────────────┐
│                Infrastructure Layer                       │
│      (Doctrine, HTTP Clients, RabbitMQ, File System)     │
└──────────────────────────────────────────────────────────┘
```

## Best Practices

### 1. Keep Aggregates Small
**Bad**: Workflow aggregate contains all instances, tasks, executions
**Good**: Workflow and WorkflowInstance are separate aggregates

### 2. Use Value Objects Liberally
**Bad**: `string $email`, `string $workflowId`
**Good**: `EmailAddress $email`, `WorkflowId $workflowId`

### 3. Enforce Invariants
**Bad**: Public setters allowing invalid state
**Good**: Methods that enforce business rules

```php
// Bad
$workflow->setState('invalid-state');  // No validation

// Good
$workflow->start();  // Enforces state transition rules
```

### 4. Don't Let Domain Depend on Infrastructure
**Bad**: `use Doctrine\ORM\Mapping;` in domain entity
**Good**: Doctrine mapping in XML/YAML in infrastructure

### 5. Use Domain Events for Side Effects
**Bad**: Send email directly in entity method
**Good**: Record event, handler sends email

### 6. Test Domain Logic in Isolation
```php
public function testCannotStartWorkflowTwice(): void
{
    $workflow = new Workflow(/* ... */);
    $workflow->start();

    $this->expectException(WorkflowAlreadyStartedException::class);
    $workflow->start();
}
// No database, no framework, pure domain test
```

## Common Pitfalls

### ❌ Anemic Domain Model
**Problem**: Entities are just data bags, all logic in services

```php
// Anemic
class Workflow
{
    public string $name;
    public string $state;

    // No behavior, just getters/setters
}

class WorkflowService
{
    public function startWorkflow(Workflow $workflow)
    {
        // All logic here
    }
}
```

**Solution**: Rich domain model with behavior

```php
// Rich
class Workflow
{
    private WorkflowState $state;

    public function start(): void
    {
        // Business logic in entity
        if (!$this->state->isDraft()) {
            throw new WorkflowAlreadyStartedException();
        }
        $this->state = WorkflowState::running();
    }
}
```

### ❌ Large Aggregates
**Problem**: Performance issues, lock contention

**Solution**: Separate aggregates, use eventual consistency

### ❌ Missing Ubiquitous Language
**Problem**: Code uses generic terms (process, data, item)

**Solution**: Use domain-specific terms (workflow, execution, agent)

## Conclusion

DDD provides:
- ✅ **Bounded Contexts**: Clear service boundaries
- ✅ **Ubiquitous Language**: Shared vocabulary
- ✅ **Rich Domain Models**: Business logic where it belongs
- ✅ **Aggregates**: Consistency boundaries
- ✅ **Domain Events**: Decoupled communication
- ✅ **Repositories**: Persistence abstraction

This enables a maintainable, evolvable, business-centric architecture.
