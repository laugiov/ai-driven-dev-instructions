# PHP Coding Guidelines

## Overview

This document defines the PHP coding standards for the platform, ensuring consistency, readability, and maintainability across all PHP code.

## PSR Standards

### PSR-1: Basic Coding Standard

**File Structure**:
```php
<?php

declare(strict_types=1);

namespace App\Domain\Entity;

use App\Domain\ValueObject\WorkflowId;
use App\Domain\ValueObject\WorkflowState;

final class Workflow
{
    // Class content
}
```

**Requirements**:
- ✅ Files MUST use `<?php` tag only
- ✅ Files MUST use UTF-8 without BOM
- ✅ Files SHOULD either declare symbols OR cause side-effects, not both
- ✅ Namespaces and classes MUST follow PSR-4
- ✅ Class names MUST be declared in StudlyCaps
- ✅ Constants MUST be declared in UPPER_CASE
- ✅ Method names MUST be declared in camelCase

### PSR-4: Autoloading Standard

```json
{
    "autoload": {
        "psr-4": {
            "App\\": "src/"
        }
    },
    "autoload-dev": {
        "psr-4": {
            "App\\Tests\\": "tests/"
        }
    }
}
```

**Directory Structure**:
```
src/
└── Domain/
    └── Entity/
        └── Workflow.php    → App\Domain\Entity\Workflow
```

### PSR-12: Extended Coding Style

**Indentation**: 4 spaces (no tabs)

**Line Length**: Soft limit 120 characters, hard limit 150

**Namespace and Use Declarations**:
```php
<?php

declare(strict_types=1);

namespace App\Domain\Service;

use App\Domain\Entity\Workflow;
use App\Domain\Repository\WorkflowRepositoryInterface;
use App\Domain\ValueObject\WorkflowId;

final readonly class WorkflowValidator
{
    // ...
}
```

**Class Declaration**:
```php
final class Workflow extends AbstractEntity implements WorkflowInterface
{
    // Properties, then methods
}
```

**Method Declaration**:
```php
public function executeWorkflow(
    WorkflowId $id,
    array $parameters = [],
): WorkflowResult {
    // Method body
}
```

## PHP 8.3 Features Usage

### 1. Strict Types (Always)

```php
<?php

declare(strict_types=1);  // ✅ Always include

// This ensures:
// - No silent type coercion
// - Type errors throw exceptions
// - Better static analysis
```

### 2. Constructor Property Promotion

```php
// ✅ Good: Property promotion
final readonly class WorkflowId
{
    public function __construct(
        private string $value,
    ) {
        if (!Uuid::isValid($value)) {
            throw new InvalidWorkflowIdException($value);
        }
    }
}

// ❌ Bad: Verbose
final readonly class WorkflowId
{
    private string $value;

    public function __construct(string $value)
    {
        $this->value = $value;
    }
}
```

### 3. Readonly Classes and Properties

```php
// ✅ Readonly class (PHP 8.2+)
final readonly class WorkflowDTO
{
    public function __construct(
        public string $id,
        public string $name,
        public string $state,
        public array $steps,
    ) {}
}

// All properties automatically readonly
```

### 4. Union Types

```php
public function find(WorkflowId|string $id): ?Workflow
{
    if ($id instanceof WorkflowId) {
        return $this->findById($id);
    }

    return $this->findById(new WorkflowId($id));
}
```

### 5. Named Arguments

```php
// ✅ Good: Clear and maintainable
$workflow = new Workflow(
    id: WorkflowId::generate(),
    name: 'My Workflow',
    createdBy: $userId,
);

// ❌ Avoid: Unclear what arguments represent
$workflow = new Workflow(
    WorkflowId::generate(),
    'My Workflow',
    $userId,
);
```

### 6. Match Expressions

```php
// ✅ Good: Match expression
$statusCode = match ($state) {
    WorkflowState::DRAFT => 200,
    WorkflowState::RUNNING => 202,
    WorkflowState::COMPLETED => 200,
    WorkflowState::FAILED => 500,
    default => throw new InvalidStateException($state),
};

// ❌ Avoid: Switch statement (more verbose)
switch ($state) {
    case WorkflowState::DRAFT:
        $statusCode = 200;
        break;
    // ...
}
```

### 7. Enums (PHP 8.1+)

```php
enum WorkflowState: string
{
    case DRAFT = 'draft';
    case RUNNING = 'running';
    case COMPLETED = 'completed';
    case FAILED = 'failed';

    public function isTerminal(): bool
    {
        return match($this) {
            self::COMPLETED, self::FAILED => true,
            default => false,
        };
    }
}

// Usage
$state = WorkflowState::RUNNING;
if ($state->isTerminal()) {
    // ...
}
```

### 8. Attributes (Instead of Annotations)

```php
// ✅ Good: PHP 8 attributes
#[Route('/api/v1/workflows', methods: ['POST'])]
#[IsGranted('WORKFLOW_CREATE')]
public function create(Request $request): JsonResponse
{
    // ...
}

// ❌ Old: Doctrine/Symfony annotations
/**
 * @Route("/api/v1/workflows", methods={"POST"})
 * @IsGranted("WORKFLOW_CREATE")
 */
public function create(Request $request): JsonResponse
{
    // ...
}
```

### 9. Null Coalescing and Assignment

```php
// Null coalescing operator
$name = $workflow->getName() ?? 'Unnamed Workflow';

// Null coalescing assignment operator (PHP 7.4+)
$this->cache ??= new ArrayCache();
```

### 10. Typed Properties

```php
final class Workflow
{
    // ✅ Always type properties
    private WorkflowId $id;
    private string $name;
    private WorkflowState $state;
    private ?DateTimeImmutable $completedAt = null;  // Nullable

    // ❌ Never untyped
    private $id;  // Bad!
}
```

## Type Safety

### Return Types (Always)

```php
// ✅ Always declare return types
public function findById(WorkflowId $id): ?Workflow
{
    return $this->repository->find($id->toString());
}

public function count(): int
{
    return $this->repository->count([]);
}

public function delete(WorkflowId $id): void
{
    $this->repository->delete($id);
}
```

### Null Safety

```php
// ✅ Explicit null handling
public function findById(WorkflowId $id): ?Workflow
{
    $workflow = $this->repository->find($id->toString());

    if ($workflow === null) {
        throw new WorkflowNotFoundException($id);
    }

    return $workflow;
}

// Or return nullable
public function findByIdOrNull(WorkflowId $id): ?Workflow
{
    return $this->repository->find($id->toString());
}
```

### Array Types (PHPDoc)

```php
/**
 * @param array<Step> $steps
 * @return array<string, mixed>
 */
public function processSteps(array $steps): array
{
    // ...
}

// Better: Use collection object
public function processSteps(StepCollection $steps): array
{
    // ...
}
```

## Naming Conventions

### Classes

```php
// ✅ Noun, StudlyCaps
class Workflow
class WorkflowValidator
class CreateWorkflowHandler

// ✅ Interfaces: Adjective ending in "Interface" or "able"
interface WorkflowRepositoryInterface
interface Executable

// ✅ Traits: Adjective ending in "Trait"
trait TimestampableTrait

// ✅ Enums: Singular noun
enum WorkflowState
enum Permission

// ✅ Exceptions: Noun ending in "Exception"
class WorkflowNotFoundException extends NotFoundException
class InvalidWorkflowException extends DomainException
```

### Methods

```php
// ✅ Verb, camelCase
public function executeWorkflow(): void
public function validateInput(): bool
public function findById(): ?Workflow

// ✅ Boolean methods: is/has/can
public function isCompleted(): bool
public function hasSteps(): bool
public function canExecute(): bool

// ✅ Getters: get prefix
public function getId(): WorkflowId
public function getName(): string

// ❌ Avoid: set prefix (prefer immutability)
public function setName(string $name): void  // Bad
```

### Properties

```php
// ✅ camelCase
private WorkflowId $workflowId;
private string $userName;
private int $attemptCount;

// ❌ Avoid: abbreviations
private $wfId;  // Bad
private $usrNm;  // Bad
```

### Constants

```php
// ✅ UPPER_SNAKE_CASE
public const MAX_RETRY_ATTEMPTS = 3;
public const DEFAULT_TIMEOUT_SECONDS = 30;

// ✅ Enum instead of class constants (PHP 8.1+)
enum WorkflowState: string {
    case DRAFT = 'draft';
    case RUNNING = 'running';
}
```

## Code Organization

### Class Structure

```php
final class Workflow
{
    // 1. Constants
    private const MAX_STEPS = 100;

    // 2. Properties (grouped by visibility)
    private WorkflowId $id;
    private string $name;
    private WorkflowState $state;

    // 3. Constructor
    public function __construct(
        WorkflowId $id,
        string $name,
    ) {
        $this->id = $id;
        $this->name = $name;
        $this->state = WorkflowState::DRAFT;
    }

    // 4. Public methods
    public function start(): void
    {
        // ...
    }

    // 5. Protected methods (if not final)
    protected function validate(): void
    {
        // ...
    }

    // 6. Private methods
    private function recordEvent(DomainEventInterface $event): void
    {
        // ...
    }

    // 7. Getters at the end
    public function getId(): WorkflowId
    {
        return $this->id;
    }
}
```

### File Organization

```php
<?php

declare(strict_types=1);

// 1. Namespace
namespace App\Domain\Entity;

// 2. Use statements (alphabetically)
use App\Domain\Event\WorkflowStarted;
use App\Domain\Exception\WorkflowException;
use App\Domain\ValueObject\WorkflowId;
use App\Domain\ValueObject\WorkflowState;

// 3. Class declaration
final class Workflow
{
    // Class content
}
```

## Error Handling

### Exception Hierarchy

```php
// Base domain exception
abstract class DomainException extends \RuntimeException
{
}

// Specific exceptions
final class WorkflowNotFoundException extends DomainException
{
    public function __construct(WorkflowId $id)
    {
        parent::__construct("Workflow {$id->toString()} not found");
    }
}

final class InvalidWorkflowException extends DomainException
{
    public function __construct(string $reason)
    {
        parent::__construct("Invalid workflow: {$reason}");
    }
}
```

### Error Handling Pattern

```php
public function execute(WorkflowId $id): void
{
    // 1. Validate input
    if ($id === null) {
        throw new \InvalidArgumentException('Workflow ID cannot be null');
    }

    // 2. Fetch with null check
    $workflow = $this->repository->findById($id);

    if ($workflow === null) {
        throw new WorkflowNotFoundException($id);
    }

    // 3. Business logic with domain exceptions
    try {
        $workflow->start();
    } catch (WorkflowAlreadyStartedException $e) {
        // Re-throw or handle
        throw $e;
    }

    // 4. Persist
    $this->repository->save($workflow);
}
```

## Immutability

### Prefer Immutable Objects

```php
// ✅ Immutable Value Object
final readonly class Money
{
    public function __construct(
        private int $amount,
        private Currency $currency,
    ) {}

    public function add(Money $other): self
    {
        if (!$this->currency->equals($other->currency)) {
            throw new CurrencyMismatchException();
        }

        // Return NEW instance
        return new self(
            $this->amount + $other->amount,
            $this->currency,
        );
    }
}

// ❌ Mutable (avoid for Value Objects)
final class Money
{
    private int $amount;

    public function add(Money $other): void
    {
        $this->amount += $other->amount;  // Mutates state
    }
}
```

### Entities Can Be Mutable

```php
// ✅ Entities have identity, can mutate
final class Workflow
{
    private WorkflowId $id;  // Identity never changes
    private WorkflowState $state;  // State can change

    public function start(): void
    {
        // Mutation OK for entities
        $this->state = WorkflowState::RUNNING;
        $this->recordEvent(new WorkflowStarted($this->id));
    }
}
```

## Dependency Injection

### Constructor Injection (Preferred)

```php
// ✅ Constructor injection
final readonly class CreateWorkflowHandler
{
    public function __construct(
        private WorkflowRepositoryInterface $repository,
        private EventPublisherInterface $eventPublisher,
        private WorkflowValidator $validator,
    ) {}

    public function __invoke(CreateWorkflowCommand $command): WorkflowId
    {
        // Use injected dependencies
    }
}
```

### Service Locator (Avoid)

```php
// ❌ Bad: Service locator anti-pattern
final class CreateWorkflowHandler
{
    public function __construct(
        private ContainerInterface $container,  // Bad!
    ) {}

    public function __invoke(CreateWorkflowCommand $command): WorkflowId
    {
        $repository = $this->container->get('workflow_repository');  // Bad!
    }
}
```

## Static Analysis

### PHPStan Configuration

```neon
# phpstan.neon
parameters:
    level: 9  # Maximum level
    paths:
        - src
    excludePaths:
        - src/Kernel.php
    checkMissingIterableValueType: true
    checkGenericClassInNonGenericObjectType: true
    reportUnmatchedIgnoredErrors: true
```

### Psalm Configuration

```xml
<!-- psalm.xml -->
<?xml version="1.0"?>
<psalm
    errorLevel="1"
    resolveFromConfigFile="true"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns="https://getpsalm.org/schema/config"
    xsi:schemaLocation="https://getpsalm.org/schema/config vendor/vimeo/psalm/config.xsd"
>
    <projectFiles>
        <directory name="src" />
        <ignoreFiles>
            <directory name="vendor" />
        </ignoreFiles>
    </projectFiles>
</psalm>
```

## Documentation

### PHPDoc

```php
/**
 * Executes a workflow with the given parameters.
 *
 * @param WorkflowId $id The workflow identifier
 * @param array<string, mixed> $parameters Execution parameters
 *
 * @return WorkflowResult The execution result
 *
 * @throws WorkflowNotFoundException If workflow doesn't exist
 * @throws InvalidParametersException If parameters are invalid
 */
public function execute(WorkflowId $id, array $parameters): WorkflowResult
{
    // ...
}
```

### When to Use PHPDoc

- ✅ Complex array types: `@param array<string, mixed> $data`
- ✅ Generics: `@return Collection<Workflow>`
- ✅ Additional context: `@throws`, `@deprecated`
- ❌ Redundant info: Don't document what's obvious from types

```php
// ❌ Redundant PHPDoc
/**
 * Get the workflow ID.
 *
 * @return WorkflowId The workflow ID
 */
public function getId(): WorkflowId  // Type already clear
{
    return $this->id;
}

// ✅ No PHPDoc needed
public function getId(): WorkflowId
{
    return $this->id;
}
```

## Testing Standards

### Test Method Naming

```php
// ✅ Clear test names
public function testCannotStartWorkflowTwice(): void
public function testValidatesWorkflowNameLength(): void
public function testThrowsExceptionWhenWorkflowNotFound(): void

// ❌ Vague test names
public function testWorkflow(): void
public function testStart(): void
```

### Test Structure (Arrange-Act-Assert)

```php
public function testCreatesWorkflowSuccessfully(): void
{
    // Arrange
    $id = WorkflowId::generate();
    $name = 'Test Workflow';

    // Act
    $workflow = new Workflow($id, $name);

    // Assert
    $this->assertEquals($id, $workflow->getId());
    $this->assertEquals($name, $workflow->getName());
    $this->assertTrue($workflow->getState()->isDraft());
}
```

## Performance Best Practices

### 1. Avoid N+1 Queries

```php
// ❌ Bad: N+1 query problem
$workflows = $this->workflowRepository->findAll();
foreach ($workflows as $workflow) {
    // Triggers separate query for each workflow
    $steps = $workflow->getSteps();  // N queries
}

// ✅ Good: Eager loading
$workflows = $this->workflowRepository->findAllWithSteps();
foreach ($workflows as $workflow) {
    $steps = $workflow->getSteps();  // Already loaded
}
```

### 2. Use Generators for Large Datasets

```php
// ✅ Memory efficient with generators
public function findAllIterator(): \Generator
{
    $offset = 0;
    $limit = 100;

    while (true) {
        $workflows = $this->repository->findBy([], null, $limit, $offset);

        if (empty($workflows)) {
            break;
        }

        foreach ($workflows as $workflow) {
            yield $workflow;
        }

        $offset += $limit;
    }
}
```

### 3. Cache Expensive Operations

```php
public function getWorkflowStats(): array
{
    return $this->cache->get('workflow_stats', function () {
        // Expensive computation
        return $this->computeStats();
    }, ttl: 3600);
}
```

## Code Quality Tools

### PHP-CS-Fixer

```php
// .php-cs-fixer.php
<?php

$finder = PhpCsFixer\Finder::create()
    ->in(__DIR__ . '/src')
    ->in(__DIR__ . '/tests');

return (new PhpCsFixer\Config())
    ->setRules([
        '@PSR12' => true,
        'array_syntax' => ['syntax' => 'short'],
        'ordered_imports' => ['sort_algorithm' => 'alpha'],
        'no_unused_imports' => true,
        'strict_types_declaration' => true,
        'declare_strict_types' => true,
    ])
    ->setFinder($finder);
```

### Running Quality Checks

```bash
# Static analysis
vendor/bin/phpstan analyse src --level=9

# Psalm
vendor/bin/psalm --show-info=true

# Code style
vendor/bin/php-cs-fixer fix --dry-run --diff

# All checks
composer check
```

## Common Mistakes to Avoid

### 1. Global State

```php
// ❌ Bad: Global state
class Workflow
{
    private static array $cache = [];  // Avoid static state
}

// ✅ Good: Inject dependencies
class WorkflowService
{
    public function __construct(
        private CacheInterface $cache,
    ) {}
}
```

### 2. Mixed Concerns

```php
// ❌ Bad: Mixed concerns
public function createWorkflow(array $data): JsonResponse
{
    // Validation
    if (empty($data['name'])) {
        return new JsonResponse(['error' => 'Name required'], 400);
    }

    // Business logic
    $workflow = new Workflow(/* ... */);

    // Persistence
    $this->entityManager->persist($workflow);
    $this->entityManager->flush();

    // HTTP response
    return new JsonResponse($workflow->toArray(), 201);
}

// ✅ Good: Separated concerns
public function createWorkflow(Request $request): JsonResponse
{
    $command = new CreateWorkflowCommand($request->request->all());
    $workflowId = $this->commandBus->dispatch($command);

    return new JsonResponse(['id' => $workflowId->toString()], 201);
}
```

### 3. Magic Methods Overuse

```php
// ❌ Avoid: Magic methods hide behavior
public function __call(string $method, array $args)
{
    // Hard to understand, bad for static analysis
}

// ✅ Prefer: Explicit methods
public function executeWorkflow(): void
{
    // Clear and analyzable
}
```

## Conclusion

Following these guidelines ensures:
- ✅ Consistent code style across the project
- ✅ Better static analysis and IDE support
- ✅ Improved maintainability
- ✅ Fewer bugs through type safety
- ✅ Better performance
- ✅ Easier code reviews

Automated tools (PHPStan, Psalm, PHP-CS-Fixer) enforce most of these rules.
