# Code Review Checklist

## Table of Contents

1. [Introduction](#introduction)
2. [Code Review Philosophy](#code-review-philosophy)
3. [General Code Quality](#general-code-quality)
4. [Architecture and Design](#architecture-and-design)
5. [Domain-Driven Design](#domain-driven-design)
6. [Security Review](#security-review)
7. [Performance Review](#performance-review)
8. [Testing](#testing)
9. [Error Handling](#error-handling)
10. [Documentation](#documentation)
11. [Database Changes](#database-changes)
12. [API Changes](#api-changes)
13. [Dependencies](#dependencies)
14. [Pull Request Hygiene](#pull-request-hygiene)

## Introduction

This comprehensive code review checklist ensures consistent, high-quality code reviews across the AI Workflow Processing Platform. Code reviews are essential for maintaining code quality, sharing knowledge, catching bugs early, and ensuring architectural consistency.

### Review Goals

**Quality Assurance**: Identify bugs, security vulnerabilities, and performance issues before they reach production.

**Knowledge Sharing**: Spread understanding of the codebase and best practices across the team.

**Consistency**: Ensure adherence to architectural patterns and coding standards.

**Mentoring**: Provide constructive feedback to help developers grow.

**Documentation**: Verify that code is well-documented and understandable.

### Review Principles

**Be Kind and Constructive**: Focus on the code, not the person. Frame feedback positively.

**Ask Questions**: Instead of commanding changes, ask questions to understand the reasoning.

**Provide Context**: Explain why a change is needed, linking to documentation or examples.

**Approve Quickly**: Don't let perfect be the enemy of good. Minor issues can be addressed in follow-up PRs.

**Use Automation**: Let tools handle formatting, linting, and basic quality checks.

## Code Review Philosophy

### The 20-Minute Rule

First pass reviews should take approximately 20 minutes. If a PR requires longer:
- The PR is likely too large and should be split
- Request the author to add more context or documentation
- Schedule a synchronous review session

### Review Depth Levels

**Level 1 - Quick Scan (5 minutes)**:
- Automated checks passing
- PR description complete
- No obvious red flags
- Tests included

**Level 2 - Standard Review (20 minutes)**:
- Code logic and correctness
- Test coverage and quality
- Documentation completeness
- Adherence to patterns

**Level 3 - Deep Review (60+ minutes)**:
- Architecture impact analysis
- Performance implications
- Security audit
- Cross-service compatibility

Most reviews should be Level 2. Reserve Level 3 for:
- New services or major features
- Security-critical changes
- Performance-sensitive code
- Breaking API changes

### Review Response Times

**Critical/Hotfix**: Within 2 hours
**High Priority**: Within 4 hours
**Normal Priority**: Within 24 hours
**Low Priority**: Within 48 hours

## General Code Quality

### Code Readability

```php
<?php

// ✅ GOOD: Clear, self-documenting code
final class AgentExecutor
{
    public function executeAgent(Agent $agent, string $input): ExecutionResult
    {
        $this->validateAgentConfiguration($agent);
        $this->checkRateLimits($agent);

        $prompt = $this->buildPrompt($agent, $input);
        $response = $this->llmClient->complete($prompt);

        return ExecutionResult::success($response);
    }

    private function validateAgentConfiguration(Agent $agent): void
    {
        if (!$agent->hasValidConfiguration()) {
            throw InvalidAgentConfigurationException::missingRequiredFields(
                $agent->getId()
            );
        }
    }
}

// ❌ BAD: Unclear, requires mental parsing
final class AgentExecutor
{
    public function exec(Agent $a, string $i): array
    {
        if (!$a->cfg()) throw new \Exception('bad cfg');
        if ($this->rl->check($a->id())) throw new \Exception('rl');
        $p = $this->bp($a, $i);
        $r = $this->llm->c($p);
        return ['s' => true, 'r' => $r];
    }
}
```

**Review Checklist**:
- [ ] Variable names are descriptive and meaningful
- [ ] Function names clearly describe their purpose
- [ ] Code is formatted consistently (handled by PHP CS Fixer)
- [ ] Magic numbers are extracted to named constants
- [ ] Complex logic is broken into smaller, named functions
- [ ] Nesting depth is reasonable (max 3-4 levels)
- [ ] Functions are focused (single responsibility)
- [ ] No commented-out code (use git history instead)

### Type Safety

```php
<?php

// ✅ GOOD: Strict types and proper type hints
declare(strict_types=1);

final class WorkflowExecutor
{
    public function __construct(
        private readonly WorkflowRepositoryInterface $repository,
        private readonly EventDispatcherInterface $dispatcher,
        private readonly LoggerInterface $logger,
    ) {}

    public function execute(WorkflowId $id, array $context): ExecutionResult
    {
        $workflow = $this->repository->findById($id);

        if ($workflow === null) {
            throw WorkflowNotFoundException::withId($id);
        }

        return $workflow->execute($context);
    }
}

// ❌ BAD: Missing type hints and declare strict_types
final class WorkflowExecutor
{
    public function __construct($repository, $dispatcher, $logger)
    {
        $this->repository = $repository;
        $this->dispatcher = $dispatcher;
        $this->logger = $logger;
    }

    public function execute($id, $context)
    {
        $workflow = $this->repository->findById($id);
        if (!$workflow) {
            throw new \Exception('Not found');
        }
        return $workflow->execute($context);
    }
}
```

**Review Checklist**:
- [ ] `declare(strict_types=1)` is present in every PHP file
- [ ] All function parameters have type hints
- [ ] All function return types are declared
- [ ] Property types are declared (PHP 7.4+)
- [ ] Nullable types use `?Type` or `Type|null` syntax
- [ ] Union types are used appropriately (PHP 8.0+)
- [ ] No `mixed` type unless absolutely necessary
- [ ] Arrays use `array<Type>` or `Type[]` in PHPDoc when containing specific types

### Code Duplication

```php
<?php

// ✅ GOOD: Extracted common logic
final class AgentValidator
{
    private function validateConfiguration(array $configuration, array $requiredFields): void
    {
        foreach ($requiredFields as $field) {
            if (!isset($configuration[$field])) {
                throw ValidationException::missingField($field);
            }
        }
    }

    public function validateAgentConfiguration(Agent $agent): void
    {
        $this->validateConfiguration(
            $agent->getConfiguration(),
            ['model', 'temperature', 'max_tokens']
        );
    }

    public function validateWorkflowConfiguration(Workflow $workflow): void
    {
        $this->validateConfiguration(
            $workflow->getConfiguration(),
            ['timeout', 'retry_policy']
        );
    }
}

// ❌ BAD: Duplicated validation logic
final class AgentValidator
{
    public function validateAgentConfiguration(Agent $agent): void
    {
        $config = $agent->getConfiguration();
        if (!isset($config['model'])) {
            throw ValidationException::missingField('model');
        }
        if (!isset($config['temperature'])) {
            throw ValidationException::missingField('temperature');
        }
        if (!isset($config['max_tokens'])) {
            throw ValidationException::missingField('max_tokens');
        }
    }

    public function validateWorkflowConfiguration(Workflow $workflow): void
    {
        $config = $workflow->getConfiguration();
        if (!isset($config['timeout'])) {
            throw ValidationException::missingField('timeout');
        }
        if (!isset($config['retry_policy'])) {
            throw ValidationException::missingField('retry_policy');
        }
    }
}
```

**Review Checklist**:
- [ ] No duplicated code blocks (DRY principle)
- [ ] Common patterns extracted to reusable functions
- [ ] Similar classes share a common interface or base class
- [ ] Repeated logic is centralized in shared services
- [ ] Copy-paste errors are not present

## Architecture and Design

### Hexagonal Architecture

```php
<?php

// ✅ GOOD: Clear separation of concerns
namespace App\Domain\Agent;

// Domain layer - pure business logic
final class Agent
{
    public function execute(string $input): ExecutionResult
    {
        $this->ensureCanExecute();

        return ExecutionResult::pending($this->id, $input);
    }

    private function ensureCanExecute(): void
    {
        if ($this->status !== AgentStatus::Active) {
            throw AgentNotExecutableException::dueToStatus($this->id, $this->status);
        }
    }
}

namespace App\Application\Agent\CommandHandler;

// Application layer - use case orchestration
#[AsMessageHandler]
final class ExecuteAgentCommandHandler
{
    public function __construct(
        private readonly AgentRepositoryInterface $repository,
        private readonly LLMServiceInterface $llmService,
        private readonly EventDispatcherInterface $dispatcher,
    ) {}

    public function __invoke(ExecuteAgentCommand $command): string
    {
        $agent = $this->repository->findById($command->agentId);

        if ($agent === null) {
            throw AgentNotFoundException::withId($command->agentId);
        }

        $result = $agent->execute($command->input);
        $this->repository->save($agent);

        $this->dispatcher->dispatch(
            new AgentExecutionStarted($agent->getId(), $result->getId())
        );

        return $result->getId()->toString();
    }
}

namespace App\Infrastructure\LLM;

// Infrastructure layer - technical implementation
final class OpenAILLMService implements LLMServiceInterface
{
    public function __construct(
        private readonly HttpClientInterface $client,
        private readonly string $apiKey,
    ) {}

    public function complete(string $prompt, array $options): string
    {
        $response = $this->client->request('POST', 'https://api.openai.com/v1/chat/completions', [
            'headers' => ['Authorization' => "Bearer {$this->apiKey}"],
            'json' => [
                'model' => $options['model'] ?? 'gpt-4',
                'messages' => [['role' => 'user', 'content' => $prompt]],
            ],
        ]);

        return $response->toArray()['choices'][0]['message']['content'];
    }
}

// ❌ BAD: Mixed concerns
final class Agent
{
    public function execute(string $input): string
    {
        // Domain logic mixed with infrastructure
        $response = file_get_contents('https://api.openai.com/v1/chat/completions', false, stream_context_create([
            'http' => [
                'method' => 'POST',
                'header' => "Authorization: Bearer {$this->apiKey}",
                'content' => json_encode(['prompt' => $input]),
            ],
        ]));

        // Saving directly in domain
        $pdo = new \PDO('pgsql:host=localhost;dbname=app', 'user', 'pass');
        $pdo->exec("UPDATE agents SET last_execution = NOW() WHERE id = '{$this->id}'");

        return json_decode($response, true)['completion'];
    }
}
```

**Review Checklist**:
- [ ] Domain layer contains only business logic (no infrastructure dependencies)
- [ ] Domain entities use value objects for complex types
- [ ] Application layer orchestrates use cases using domain services
- [ ] Infrastructure implementations are behind interfaces (ports)
- [ ] Dependencies point inward (infrastructure → application → domain)
- [ ] No direct database access in domain or application layers
- [ ] External services accessed through adapters

### Dependency Injection

```php
<?php

// ✅ GOOD: Constructor injection with interfaces
final class AgentService
{
    public function __construct(
        private readonly AgentRepositoryInterface $repository,
        private readonly LLMServiceInterface $llmService,
        private readonly EventDispatcherInterface $dispatcher,
        private readonly LoggerInterface $logger,
    ) {}

    public function createAgent(string $name, string $model): Agent
    {
        $agent = Agent::create(
            id: AgentId::generate(),
            name: $name,
            model: $model
        );

        $this->repository->save($agent);
        $this->dispatcher->dispatch(new AgentCreated($agent->getId()));

        return $agent;
    }
}

// ❌ BAD: Service locator pattern and concrete dependencies
final class AgentService
{
    public function createAgent(string $name, string $model): Agent
    {
        // Service locator anti-pattern
        $repository = ServiceLocator::get('agent_repository');
        $dispatcher = ServiceLocator::get('event_dispatcher');

        // Concrete dependency
        $logger = new FileLogger('/var/log/app.log');

        // Static call
        $agent = Agent::create(
            id: AgentId::generate(),
            name: $name,
            model: $model
        );

        $repository->save($agent);
        $dispatcher->dispatch(new AgentCreated($agent->getId()));

        return $agent;
    }
}
```

**Review Checklist**:
- [ ] Dependencies injected through constructor
- [ ] Dependencies are interfaces, not concrete classes
- [ ] No service locator pattern
- [ ] No static method calls (except for factories and value objects)
- [ ] No `new` keyword for services (only for value objects and DTOs)
- [ ] Services are marked `final` (composition over inheritance)

## Domain-Driven Design

### Bounded Context Boundaries

```php
<?php

// ✅ GOOD: Clear bounded context separation
namespace App\Domain\Agent;

final class Agent
{
    // Agent context manages its own agent concept
    public function execute(string $input): ExecutionResult
    {
        return ExecutionResult::pending($this->id, $input);
    }
}

namespace App\Domain\Workflow;

final class Workflow
{
    // Workflow context has its own agent reference (anti-corruption layer)
    public function addStep(string $agentId, string $name): void
    {
        $step = WorkflowStep::create(
            id: StepId::generate(),
            workflowId: $this->id,
            agentId: AgentId::fromString($agentId),  // Reference by ID only
            name: $name
        );

        $this->steps[] = $step;
    }
}

// Integration through events
final class AgentDeletedEventSubscriber
{
    public function __invoke(AgentDeleted $event): void
    {
        // Workflow context reacts to agent deletion
        $this->workflowService->handleAgentDeleted($event->getAgentId());
    }
}

// ❌ BAD: Tight coupling between contexts
namespace App\Domain\Workflow;

use App\Domain\Agent\Agent;  // Direct dependency on other context

final class Workflow
{
    public function addStep(Agent $agent, string $name): void  // Accepting entity from other context
    {
        // Direct access to agent internals
        if ($agent->getStatus() !== 'active') {
            throw new \Exception('Agent must be active');
        }

        $step = WorkflowStep::create(
            id: StepId::generate(),
            workflowId: $this->id,
            agent: $agent,  // Storing entire agent entity
            name: $name
        );

        $this->steps[] = $step;
    }
}
```

**Review Checklist**:
- [ ] Bounded contexts are clearly separated by namespace
- [ ] Cross-context references use IDs, not entity objects
- [ ] Integration between contexts uses events or API calls
- [ ] No direct database joins across contexts
- [ ] Each context has its own repository interfaces
- [ ] Shared concepts are duplicated (not shared) between contexts
- [ ] Anti-corruption layers protect context boundaries

### Aggregate Design

```php
<?php

// ✅ GOOD: Proper aggregate design
final class Workflow  // Aggregate root
{
    private WorkflowId $id;
    private string $userId;
    private string $name;

    /** @var WorkflowStep[] */
    private array $steps = [];  // Entities within aggregate

    // All modifications go through aggregate root
    public function addStep(string $name, string $agentId, int $orderIndex): void
    {
        $this->ensureNotCompleted();

        $step = WorkflowStep::create(
            id: StepId::generate(),
            workflowId: $this->id,
            name: $name,
            agentId: AgentId::fromString($agentId),
            orderIndex: $orderIndex
        );

        $this->steps[] = $step;

        // Domain event raised through aggregate root
        $this->recordEvent(new WorkflowStepAdded($this->id, $step->getId()));
    }

    public function removeStep(StepId $stepId): void
    {
        $this->ensureNotCompleted();

        $index = $this->findStepIndex($stepId);

        if ($index === null) {
            throw WorkflowStepNotFoundException::withId($stepId);
        }

        array_splice($this->steps, $index, 1);

        $this->recordEvent(new WorkflowStepRemoved($this->id, $stepId));
    }

    // Aggregate root enforces invariants
    private function ensureNotCompleted(): void
    {
        if ($this->status === WorkflowStatus::Completed) {
            throw InvalidWorkflowStateException::cannotModifyCompleted($this->id);
        }
    }
}

// ❌ BAD: Anemic domain model
final class Workflow
{
    public WorkflowId $id;
    public string $userId;
    public string $name;
    public array $steps = [];

    // No behavior, just getters/setters
    public function getId(): WorkflowId { return $this->id; }
    public function setName(string $name): void { $this->name = $name; }
    public function getSteps(): array { return $this->steps; }
    public function setSteps(array $steps): void { $this->steps = $steps; }
}

// Business logic in service instead of domain
final class WorkflowService
{
    public function addStep(Workflow $workflow, string $name, string $agentId): void
    {
        // Invariant checking in service, not domain
        if ($workflow->status === 'completed') {
            throw new \Exception('Cannot modify completed workflow');
        }

        $step = new WorkflowStep();
        $step->setWorkflowId($workflow->getId());
        $step->setName($name);
        $step->setAgentId($agentId);

        // Direct manipulation of aggregate internals
        $steps = $workflow->getSteps();
        $steps[] = $step;
        $workflow->setSteps($steps);
    }
}
```

**Review Checklist**:
- [ ] Aggregate roots identified and enforced
- [ ] All modifications to aggregate go through root
- [ ] Aggregate boundaries are clear and consistent
- [ ] Aggregates are not too large (keep them small)
- [ ] Child entities cannot be accessed directly
- [ ] Domain events raised from aggregate root
- [ ] Invariants enforced within aggregate
- [ ] No anemic domain models (behavior in domain, not services)

### Value Objects

```php
<?php

// ✅ GOOD: Immutable value object with validation
final readonly class AgentId
{
    private function __construct(
        private string $value,
    ) {
        if (!$this->isValidUuid($value)) {
            throw new \InvalidArgumentException(
                "Invalid agent ID format: {$value}"
            );
        }
    }

    public static function generate(): self
    {
        return new self(Uuid::uuid4()->toString());
    }

    public static function fromString(string $value): self
    {
        return new self($value);
    }

    public function toString(): string
    {
        return $this->value;
    }

    public function equals(self $other): bool
    {
        return $this->value === $other->value;
    }

    private function isValidUuid(string $value): bool
    {
        return (bool) preg_match(
            '/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i',
            $value
        );
    }
}

// ✅ GOOD: Value object with business rules
final readonly class Temperature
{
    private const MIN_VALUE = 0.0;
    private const MAX_VALUE = 2.0;

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
        return new self(0.7);
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

// ❌ BAD: Primitive obsession
final class Agent
{
    public function __construct(
        private string $id,  // Should be AgentId value object
        private float $temperature,  // Should be Temperature value object
        private string $email,  // Should be Email value object
    ) {}

    public function setTemperature(float $temperature): void
    {
        // Validation scattered throughout codebase
        if ($temperature < 0.0 || $temperature > 2.0) {
            throw new \Exception('Invalid temperature');
        }
        $this->temperature = $temperature;
    }
}
```

**Review Checklist**:
- [ ] Value objects used instead of primitives for domain concepts
- [ ] Value objects are immutable (readonly properties)
- [ ] Validation logic centralized in value object constructor
- [ ] Value objects implement `equals()` method
- [ ] Named constructors for clarity (`fromString()`, `fromInt()`)
- [ ] No primitive obsession (string IDs, float money, etc.)

## Security Review

Refer to [02-security-review-checklist.md](02-security-review-checklist.md) for comprehensive security review guidelines. Key security checks:

**Review Checklist**:
- [ ] No SQL injection vulnerabilities (use prepared statements)
- [ ] No XSS vulnerabilities (proper output encoding)
- [ ] Authentication and authorization properly implemented
- [ ] Sensitive data not logged or exposed
- [ ] Input validation on all user inputs
- [ ] CSRF protection on state-changing operations
- [ ] Secrets not hardcoded or committed
- [ ] Rate limiting on public endpoints
- [ ] Proper error messages (no sensitive info in errors)
- [ ] Dependencies scanned for known vulnerabilities

## Performance Review

Refer to [04-development/08-performance-optimization.md](../04-development/08-performance-optimization.md) for detailed performance guidelines. Key performance checks:

**Review Checklist**:
- [ ] No N+1 query problems
- [ ] Database queries optimized (use EXPLAIN)
- [ ] Appropriate indexes exist for queries
- [ ] Caching used where appropriate
- [ ] Large datasets paginated
- [ ] Heavy operations run asynchronously
- [ ] No memory leaks in long-running processes
- [ ] Efficient algorithms used (avoid O(n²) where possible)
- [ ] Resources properly cleaned up (connections, file handles)
- [ ] Batch operations for bulk updates

## Testing

### Test Coverage

```php
<?php

// ✅ GOOD: Comprehensive test coverage
final class AgentTest extends TestCase
{
    public function test_it_creates_agent_with_valid_data(): void
    {
        $agent = Agent::create(
            id: AgentId::generate(),
            userId: 'user-123',
            name: 'Test Agent',
            model: 'gpt-4',
            systemPrompt: 'You are helpful'
        );

        $this->assertTrue($agent->isActive());
        $this->assertSame('Test Agent', $agent->getName());
    }

    public function test_it_throws_exception_for_invalid_temperature(): void
    {
        $this->expectException(InvalidAgentConfigurationException::class);
        $this->expectExceptionMessage('Temperature must be between 0.0 and 2.0');

        Agent::create(
            id: AgentId::generate(),
            userId: 'user-123',
            name: 'Test Agent',
            model: 'gpt-4',
            systemPrompt: 'Test',
            temperature: 3.0  // Invalid
        );
    }

    public function test_it_cannot_execute_when_inactive(): void
    {
        $agent = Agent::create(/* ... */);
        $agent->deactivate();

        $this->expectException(AgentNotExecutableException::class);

        $agent->execute('test input');
    }

    /** @dataProvider invalidNameProvider */
    public function test_it_validates_name(string $invalidName): void
    {
        $this->expectException(InvalidArgumentException::class);

        Agent::create(
            id: AgentId::generate(),
            userId: 'user-123',
            name: $invalidName,
            model: 'gpt-4',
            systemPrompt: 'Test'
        );
    }

    public function invalidNameProvider(): array
    {
        return [
            'empty' => [''],
            'too short' => ['AB'],
            'too long' => [str_repeat('A', 256)],
            'invalid chars' => ['Test<script>'],
        ];
    }
}

// ❌ BAD: Insufficient test coverage
final class AgentTest extends TestCase
{
    public function test_it_works(): void
    {
        $agent = new Agent();
        $agent->setName('Test');

        $this->assertSame('Test', $agent->getName());
    }
}
```

**Review Checklist**:
- [ ] New code has unit tests
- [ ] Tests cover happy path and error cases
- [ ] Edge cases are tested
- [ ] Tests use data providers for multiple scenarios
- [ ] Tests are independent and can run in any order
- [ ] Test names clearly describe what is being tested
- [ ] No test logic in production code
- [ ] Mocks used appropriately (not over-mocked)
- [ ] Integration tests for complex workflows
- [ ] Test coverage meets minimum threshold (80%)

### Test Quality

```php
<?php

// ✅ GOOD: Clear, focused test
final class WorkflowExecutionTest extends TestCase
{
    private WorkflowExecutor $executor;
    private WorkflowRepositoryInterface $repository;
    private EventDispatcherInterface $dispatcher;

    protected function setUp(): void
    {
        $this->repository = $this->createMock(WorkflowRepositoryInterface::class);
        $this->dispatcher = $this->createMock(EventDispatcherInterface::class);
        $this->executor = new WorkflowExecutor($this->repository, $this->dispatcher);
    }

    public function test_it_executes_workflow_successfully(): void
    {
        // Arrange
        $workflowId = WorkflowId::generate();
        $workflow = $this->createCompletedWorkflow($workflowId);

        $this->repository
            ->expects($this->once())
            ->method('findById')
            ->with($workflowId)
            ->willReturn($workflow);

        // Act
        $result = $this->executor->execute($workflowId, ['input' => 'test']);

        // Assert
        $this->assertTrue($result->isSuccess());
        $this->assertSame('completed', $result->getStatus());
    }

    private function createCompletedWorkflow(WorkflowId $id): Workflow
    {
        return Workflow::create(
            id: $id,
            userId: 'user-123',
            name: 'Test Workflow',
            description: 'Test'
        );
    }
}

// ❌ BAD: Unclear, unfocused test
final class WorkflowTest extends TestCase
{
    public function test_workflow(): void
    {
        $w = new Workflow();
        $w->setName('Test');
        $this->assertSame('Test', $w->getName());

        $w->execute(['input' => 'test']);
        $this->assertTrue(true);  // Meaningless assertion

        $steps = $w->getSteps();
        // No assertion on steps
    }
}
```

**Review Checklist**:
- [ ] Tests follow Arrange-Act-Assert pattern
- [ ] Test names describe the scenario being tested
- [ ] Tests test one thing at a time
- [ ] Assertions are meaningful and specific
- [ ] No `assertTrue(true)` or similar meaningless assertions
- [ ] Setup code extracted to `setUp()` or helper methods
- [ ] Tests are readable and maintainable

## Error Handling

```php
<?php

// ✅ GOOD: Proper error handling
final class ExecuteAgentCommandHandler
{
    public function __invoke(ExecuteAgentCommand $command): string
    {
        try {
            $agent = $this->repository->findById($command->agentId);

            if ($agent === null) {
                throw AgentNotFoundException::withId($command->agentId);
            }

            $result = $agent->execute($command->input);

            $this->repository->save($agent);

            return $result->getId()->toString();

        } catch (AgentNotFoundException $e) {
            // Let domain exceptions bubble up
            throw $e;

        } catch (DatabaseException $e) {
            // Wrap infrastructure exceptions with context
            $this->logger->error('Failed to execute agent', [
                'agent_id' => $command->agentId->toString(),
                'exception' => $e->getMessage(),
            ]);

            throw CommandHandlerException::handlerFailed(
                get_class($command),
                'Database error',
                $e
            );

        } catch (\Throwable $e) {
            // Catch unexpected exceptions
            $this->logger->critical('Unexpected error executing agent', [
                'agent_id' => $command->agentId->toString(),
                'exception' => get_class($e),
                'message' => $e->getMessage(),
            ]);

            throw CommandHandlerException::handlerFailed(
                get_class($command),
                'Unexpected error',
                $e
            );
        }
    }
}

// ❌ BAD: Poor error handling
final class ExecuteAgentCommandHandler
{
    public function __invoke(ExecuteAgentCommand $command): string
    {
        try {
            $agent = $this->repository->findById($command->agentId);
            $result = $agent->execute($command->input);  // Potential null pointer
            $this->repository->save($agent);
            return $result->getId()->toString();
        } catch (\Exception $e) {
            // Catching too broad, no logging
            throw new \Exception('Something went wrong');
        }
    }
}
```

**Review Checklist**:
- [ ] Errors are caught at appropriate boundaries
- [ ] Specific exception types used (not generic `Exception`)
- [ ] Exceptions include context for debugging
- [ ] Errors logged with appropriate severity
- [ ] No empty catch blocks
- [ ] No catching `Throwable` unless necessary
- [ ] Exceptions don't expose sensitive information
- [ ] User-facing errors have helpful messages

## Documentation

```php
<?php

// ✅ GOOD: Well-documented code
/**
 * Executes a workflow with the provided context.
 *
 * This method validates the workflow state, executes each step in order,
 * and handles step failures according to the retry policy.
 *
 * @param WorkflowId $id The workflow to execute
 * @param array<string, mixed> $context Initial context for workflow execution
 *
 * @return ExecutionResult The result of the workflow execution
 *
 * @throws WorkflowNotFoundException If the workflow doesn't exist
 * @throws InvalidWorkflowStateException If the workflow is not in an executable state
 * @throws WorkflowExecutionException If a critical error occurs during execution
 */
public function execute(WorkflowId $id, array $context): ExecutionResult
{
    $workflow = $this->findWorkflow($id);

    $this->validateWorkflowState($workflow);

    return $this->executeSteps($workflow, $context);
}

// ❌ BAD: Undocumented or poorly documented
// Executes workflow
public function execute($id, $ctx)
{
    // ...
}
```

**Review Checklist**:
- [ ] Public methods have PHPDoc comments
- [ ] Complex algorithms explained with comments
- [ ] PHPDoc includes `@param`, `@return`, `@throws`
- [ ] Type information in PHPDoc matches actual types
- [ ] No outdated comments
- [ ] Comments explain "why", not "what" (code should be self-explanatory)
- [ ] No commented-out code
- [ ] README updated for significant changes

## Database Changes

```php
<?php

// ✅ GOOD: Reversible migration
final class Version20240115000000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Add execution_count and last_executed_at to agents table';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('
            ALTER TABLE agents
            ADD COLUMN execution_count INTEGER NOT NULL DEFAULT 0,
            ADD COLUMN last_executed_at TIMESTAMPTZ
        ');

        $this->addSql('
            CREATE INDEX idx_agents_last_executed
            ON agents(last_executed_at DESC)
            WHERE last_executed_at IS NOT NULL
        ');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('DROP INDEX idx_agents_last_executed');
        $this->addSql('
            ALTER TABLE agents
            DROP COLUMN execution_count,
            DROP COLUMN last_executed_at
        ');
    }
}

// ❌ BAD: Non-reversible, potentially dangerous migration
final class Version20240115000000 extends AbstractMigration
{
    public function up(Schema $schema): void
    {
        // Dropping column without backup - data loss!
        $this->addSql('ALTER TABLE agents DROP COLUMN old_field');

        // No index for new column that will be queried frequently
        $this->addSql('ALTER TABLE agents ADD COLUMN status VARCHAR(50)');
    }

    public function down(Schema $schema): void
    {
        // Cannot reverse data loss
        throw new \Exception('Cannot reverse this migration');
    }
}
```

**Review Checklist**:
- [ ] Migration has both `up()` and `down()` methods
- [ ] Migration is reversible (down method works)
- [ ] No data loss in migrations
- [ ] Indexes added for new foreign keys and frequently queried columns
- [ ] Column types appropriate for data
- [ ] Default values provided for NOT NULL columns
- [ ] Migration tested locally
- [ ] Large migrations consider table locking impact
- [ ] Migrations are idempotent when possible

## API Changes

```php
<?php

// ✅ GOOD: Backward-compatible API change
final class AgentController extends AbstractController
{
    #[Route('/api/v1/agents', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);

        $command = new CreateAgentCommand(
            name: $data['name'],
            model: $data['model'],
            systemPrompt: $data['system_prompt'],
            // New optional parameter - backward compatible
            temperature: $data['temperature'] ?? 0.7,
            userId: $this->getUser()->getId()
        );

        $agentId = $this->commandBus->dispatch($command);

        return $this->json(
            ['id' => $agentId],
            Response::HTTP_CREATED
        );
    }
}

// ❌ BAD: Breaking API change
final class AgentController extends AbstractController
{
    #[Route('/api/v1/agents', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);

        $command = new CreateAgentCommand(
            name: $data['name'],
            model: $data['model'],
            systemPrompt: $data['system_prompt'],
            // Required parameter breaks existing clients!
            temperature: $data['temperature'],
            userId: $this->getUser()->getId()
        );

        // Changed response structure - breaks clients!
        return $this->json(
            ['agent_id' => $agentId, 'created_at' => time()],
            Response::HTTP_CREATED
        );
    }
}
```

**Review Checklist**:
- [ ] API changes are backward compatible
- [ ] New required fields have defaults or are optional
- [ ] Response structure unchanged (or new version endpoint created)
- [ ] Deprecation warnings added for fields being removed
- [ ] API versioning strategy followed
- [ ] OpenAPI/Swagger documentation updated
- [ ] API changelog updated
- [ ] Breaking changes communicated to consumers

## Dependencies

```json
{
  "require": {
    "symfony/framework-bundle": "^7.0",
    "doctrine/orm": "^2.17",
    "php": "^8.3"
  }
}
```

**Review Checklist**:
- [ ] New dependencies justified and necessary
- [ ] Dependencies from trusted sources
- [ ] License compatible with project (check SPDX)
- [ ] No security vulnerabilities (run `composer audit`)
- [ ] Version constraints appropriate (`^` for minor updates)
- [ ] No duplicate dependencies (check for conflicts)
- [ ] Dependencies added to correct section (require vs require-dev)
- [ ] `composer.lock` updated

## Pull Request Hygiene

### PR Description

```markdown
## ✅ GOOD PR Description

## Summary
Adds execution history tracking to agents. Each agent execution is now recorded with timestamp, duration, token usage, and outcome.

## Changes
- Added `AgentExecution` entity with execution metadata
- Created `AgentExecutionRepository` for persistence
- Updated `AgentExecutor` to record execution history
- Added indexes on `agent_id` and `created_at` for efficient queries
- Added API endpoint to retrieve execution history

## Testing
- Unit tests for `AgentExecution` entity
- Integration tests for `AgentExecutionRepository`
- Functional tests for new API endpoint
- Manual testing with 1000+ executions

## Migration
- Database migration included (reversible)
- No data loss, backward compatible

## Related
- Closes #123
- Related to #456

---

## ❌ BAD PR Description

Added stuff for agents.
```

**Review Checklist**:
- [ ] PR title is clear and descriptive
- [ ] PR description explains what and why
- [ ] PR is reasonably sized (< 500 lines preferred)
- [ ] Commits are logical and well-organized
- [ ] Commit messages follow conventional commits format
- [ ] No merge commits (rebased on main)
- [ ] All CI checks passing
- [ ] No unrelated changes included
- [ ] Screenshots/videos for UI changes
- [ ] Related issues linked

### Common PR Feedback Phrases

**Positive Feedback:**
- "Great use of [pattern/technique]! This makes the code much more [maintainable/testable/readable]."
- "I like how you extracted this into a separate method. Makes it much clearer."
- "Good catch on this edge case!"

**Constructive Feedback:**
- "Could we extract this logic into a separate method for better testability?"
- "I'm concerned about the performance implications here. Have you considered [alternative]?"
- "This looks like it might be duplicating logic from [other file]. Could we reuse that?"
- "nit: Could we rename this to [better name] for clarity?"
- "Question: What happens if [edge case]?"

**Blocking Issues:**
- "This introduces a security vulnerability: [explanation]. We need to fix this before merging."
- "This is a breaking change for [consumers]. We need to either make it backward compatible or version it."
- "Tests are failing on this scenario: [scenario]. We need coverage here."

## Summary

This comprehensive code review checklist ensures:

1. **Code Quality**: Readability, type safety, no duplication
2. **Architecture**: Proper hexagonal architecture, DI, separation of concerns
3. **Domain Design**: Proper aggregates, value objects, bounded contexts
4. **Security**: No vulnerabilities, proper auth/authz
5. **Performance**: Optimized queries, caching, async processing
6. **Testing**: Good coverage and quality
7. **Error Handling**: Proper exception handling and logging
8. **Documentation**: Clear comments and up-to-date docs
9. **Database**: Safe, reversible migrations
10. **API**: Backward compatibility maintained
11. **Dependencies**: Justified and secure
12. **PR Quality**: Clear description and logical commits

Reviewers should use this checklist as a guide, not a strict rulebook. The goal is to maintain high code quality while being pragmatic and supportive of team members.
