# Quality Standards

## Table of Contents

1. [Introduction](#introduction)
2. [Code Quality Metrics](#code-quality-metrics)
3. [Static Analysis](#static-analysis)
4. [Code Coverage](#code-coverage)
5. [Coding Standards](#coding-standards)
6. [Complexity Metrics](#complexity-metrics)
7. [Documentation Standards](#documentation-standards)
8. [Testing Standards](#testing-standards)
9. [Performance Standards](#performance-standards)
10. [Security Standards](#security-standards)
11. [Quality Gates](#quality-gates)
12. [Continuous Quality Improvement](#continuous-quality-improvement)

## Introduction

This document defines the quality standards for the AI Workflow Processing Platform. These standards ensure code maintainability, reliability, and consistency across the entire codebase.

### Quality Philosophy

**Prevention over Detection**: Catch quality issues early in development.

**Automation**: Automate quality checks wherever possible.

**Continuous Improvement**: Regularly review and improve quality standards.

**Measurable**: Quality standards must be objective and measurable.

**Pragmatic**: Balance ideal quality with practical delivery.

### Quality Pyramid

```
         ┌─────────────────┐
         │   Architecture  │  (High-level design)
         ├─────────────────┤
         │     Design      │  (SOLID, DDD patterns)
         ├─────────────────┤
         │      Code       │  (Clean, readable)
         ├─────────────────┤
         │     Tests       │  (Comprehensive)
         └─────────────────┘
```

## Code Quality Metrics

### Overall Quality Targets

```yaml
# .quality-standards.yaml
quality_metrics:
  phpstan_level: 9
  code_coverage: 80
  mutation_score: 70
  maintainability_index: 70
  technical_debt_ratio: < 5%
  duplication: < 3%
  complexity:
    cyclomatic: < 10
    cognitive: < 15
```

### PHPStan Configuration

```neon
# phpstan.neon
parameters:
    level: 9
    paths:
        - src
        - tests

    # Stricter rules
    checkMissingIterableValueType: true
    checkGenericClassInNonGenericObjectType: true
    reportUnmatchedIgnoredErrors: true

    # Type coverage
    checkAlwaysTrueCheckTypeFunctionCall: true
    checkAlwaysTrueInstanceof: true
    checkAlwaysTrueStrictComparison: true

    # Exception rules
    exceptions:
        check:
            missingCheckedExceptionInThrows: true
            tooWideThrowType: true
        checkedExceptionClasses:
            - App\Shared\Exception\ApplicationException

    # Bleeding edge
    treatPhpDocTypesAsCertain: false

    ignoreErrors:
        # Ignore specific cases with justification
        -
            message: '#Parameter .* of method .* has invalid typehint type#'
            path: src/Infrastructure/Symfony/DependencyInjection
            # Reason: Symfony DI requires dynamic types
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
        <directory name="tests" />
        <ignoreFiles>
            <directory name="vendor" />
        </ignoreFiles>
    </projectFiles>

    <issueHandlers>
        <MissingReturnType errorLevel="error" />
        <MissingParamType errorLevel="error" />
        <MissingPropertyType errorLevel="error" />
        <InvalidReturnType errorLevel="error" />
        <InvalidArgument errorLevel="error" />
    </issueHandlers>
</psalm>
```

## Static Analysis

### Automated Checks

```php
<?php

// ✅ GOOD: Passes all static analysis
declare(strict_types=1);

namespace App\Application\Agent\CommandHandler;

use App\Application\Agent\Command\CreateAgentCommand;
use App\Domain\Agent\Agent;
use App\Domain\Agent\AgentRepositoryInterface;
use App\Domain\Agent\ValueObject\AgentId;
use Psr\Log\LoggerInterface;
use Symfony\Component\Messenger\Attribute\AsMessageHandler;

#[AsMessageHandler]
final class CreateAgentCommandHandler
{
    public function __construct(
        private readonly AgentRepositoryInterface $repository,
        private readonly LoggerInterface $logger,
    ) {}

    public function __invoke(CreateAgentCommand $command): string
    {
        $agent = Agent::create(
            id: AgentId::generate(),
            userId: $command->userId,
            name: $command->name,
            model: $command->model,
            systemPrompt: $command->systemPrompt
        );

        $this->repository->save($agent);

        $this->logger->info('Agent created', [
            'agent_id' => $agent->getId()->toString(),
            'user_id' => $command->userId,
        ]);

        return $agent->getId()->toString();
    }
}

// ❌ BAD: Multiple static analysis issues
namespace App\Application\Agent\CommandHandler;

// Missing declare(strict_types=1)
class CreateAgentCommandHandler  // Not final
{
    private $repository;  // Missing type
    private $logger;      // Missing type

    public function __construct($repository, $logger)  // Missing types
    {
        $this->repository = $repository;
        $this->logger = $logger;
    }

    public function __invoke($command)  // Missing type
    {
        // Missing return type
        $agent = Agent::create(
            $command->userId,
            $command->name,
            $command->model,
            $command->systemPrompt
        );

        $this->repository->save($agent);

        return $agent->getId()->toString();
    }
}
```

### Required Tools

**PHPStan (Level 9)**:
```bash
vendor/bin/phpstan analyse --level=9 src tests
```

**Psalm (Level 1)**:
```bash
vendor/bin/psalm --show-info=true
```

**PHP CS Fixer**:
```bash
vendor/bin/php-cs-fixer fix --config=.php-cs-fixer.php --dry-run --diff
```

**PHP_CodeSniffer**:
```bash
vendor/bin/phpcs --standard=PSR12 src tests
```

**Review Checklist**:
- [ ] PHPStan Level 9 passes with zero errors
- [ ] Psalm Level 1 passes
- [ ] PHP CS Fixer applied
- [ ] PSR-12 coding standard followed
- [ ] No suppressed errors without justification
- [ ] All `@var`, `@param`, `@return` tags accurate
- [ ] No `@phpstan-ignore` or `@psalm-suppress` without documented reason

## Code Coverage

### Coverage Targets

**Minimum Coverage**: 80% overall
- Unit Tests: 90%
- Integration Tests: 70%
- Functional Tests: 60%

**Critical Paths**: 100% coverage
- Payment processing
- Authentication/Authorization
- Data encryption
- Security validations

### PHPUnit Configuration

```xml
<!-- phpunit.xml.dist -->
<?xml version="1.0" encoding="UTF-8"?>
<phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="vendor/phpunit/phpunit/phpunit.xsd"
         bootstrap="tests/bootstrap.php"
         colors="true"
         failOnRisky="true"
         failOnWarning="true"
>
    <testsuites>
        <testsuite name="Unit">
            <directory>tests/Unit</directory>
        </testsuite>
        <testsuite name="Integration">
            <directory>tests/Integration</directory>
        </testsuite>
        <testsuite name="Functional">
            <directory>tests/Functional</directory>
        </testsuite>
    </testsuites>

    <coverage processUncoveredFiles="true">
        <include>
            <directory suffix=".php">src</directory>
        </include>
        <exclude>
            <directory>src/Infrastructure/Symfony</directory>
            <file>src/Kernel.php</file>
        </exclude>
        <report>
            <html outputDirectory="coverage/html"/>
            <clover outputFile="coverage/clover.xml"/>
            <text outputFile="php://stdout" showUncoveredFiles="false"/>
        </report>
    </coverage>

    <php>
        <env name="SYMFONY_DEPRECATIONS_HELPER" value="weak"/>
        <env name="APP_ENV" value="test"/>
    </php>
</phpunit>
```

### Measuring Coverage

```bash
# Generate coverage report
vendor/bin/phpunit --coverage-html coverage/html --coverage-clover coverage/clover.xml

# Check coverage threshold
vendor/bin/phpunit --coverage-text --coverage-clover=coverage/clover.xml
php coverage-checker.php coverage/clover.xml 80
```

```php
<?php
// coverage-checker.php

$inputFile  = $argv[1];
$percentage = min(100, max(0, (int) $argv[2]));

if (!file_exists($inputFile)) {
    throw new \InvalidArgumentException('Invalid input file provided');
}

$xml = new \SimpleXMLElement(file_get_contents($inputFile));
$metrics = $xml->xpath('//metrics');
$totalElements = 0;
$checkedElements = 0;

foreach ($metrics as $metric) {
    $totalElements += (int) $metric['elements'];
    $checkedElements += (int) $metric['coveredelements'];
}

$coverage = ($totalElements > 0) ? ($checkedElements / $totalElements) * 100 : 0;

if ($coverage < $percentage) {
    echo "Code coverage is {$coverage}%, which is below the accepted {$percentage}%\n";
    exit(1);
}

echo "Code coverage is {$coverage}% - OK!\n";
```

**Review Checklist**:
- [ ] Overall coverage ≥ 80%
- [ ] No decrease in coverage from previous version
- [ ] New code has tests
- [ ] Critical paths have 100% coverage
- [ ] Coverage report reviewed
- [ ] Untested code justified with comments

## Coding Standards

### PHP CS Fixer Configuration

```php
<?php
// .php-cs-fixer.php

$finder = PhpCsFixer\Finder::create()
    ->in([
        __DIR__ . '/src',
        __DIR__ . '/tests',
    ])
    ->exclude([
        'var',
        'vendor',
    ]);

$config = new PhpCsFixer\Config();

return $config
    ->setRiskyAllowed(true)
    ->setRules([
        '@PSR12' => true,
        '@Symfony' => true,
        '@PHP83Migration' => true,

        // Strict types
        'declare_strict_types' => true,
        'strict_param' => true,

        // Imports
        'ordered_imports' => [
            'imports_order' => ['class', 'function', 'const'],
            'sort_algorithm' => 'alpha',
        ],
        'no_unused_imports' => true,
        'global_namespace_import' => [
            'import_classes' => true,
            'import_constants' => true,
            'import_functions' => true,
        ],

        // Arrays
        'array_syntax' => ['syntax' => 'short'],
        'trailing_comma_in_multiline' => [
            'elements' => ['arrays', 'arguments', 'parameters'],
        ],

        // Functions
        'void_return' => true,
        'return_type_declaration' => ['space_before' => 'none'],
        'native_function_invocation' => [
            'include' => ['@all'],
            'scope' => 'namespaced',
        ],

        // Classes
        'final_class' => true,
        'final_internal_class' => true,
        'self_accessor' => true,
        'class_attributes_separation' => [
            'elements' => [
                'const' => 'one',
                'method' => 'one',
                'property' => 'one',
            ],
        ],

        // PHPDoc
        'phpdoc_align' => ['align' => 'left'],
        'phpdoc_separation' => true,
        'phpdoc_summary' => true,
        'phpdoc_trim' => true,
        'phpdoc_types_order' => [
            'null_adjustment' => 'always_last',
            'sort_algorithm' => 'none',
        ],

        // Operators
        'binary_operator_spaces' => [
            'operators' => [
                '=>' => 'align_single_space_minimal',
                '=' => 'align_single_space_minimal',
            ],
        ],
        'concat_space' => ['spacing' => 'one'],

        // Control structures
        'yoda_style' => ['equal' => false, 'identical' => false],
        'no_superfluous_elseif' => true,

        // Whitespace
        'blank_line_after_opening_tag' => true,
        'no_extra_blank_lines' => [
            'tokens' => ['extra', 'throw', 'use'],
        ],

        // Risky rules
        'strict_comparison' => true,
        'declare_equal_normalize' => ['space' => 'none'],
    ])
    ->setFinder($finder);
```

**Review Checklist**:
- [ ] Code formatted with PHP CS Fixer
- [ ] PSR-12 standard followed
- [ ] Consistent naming conventions
- [ ] Proper indentation (4 spaces)
- [ ] Line length reasonable (< 120 characters)
- [ ] No trailing whitespace
- [ ] Files end with newline

## Complexity Metrics

### Cyclomatic Complexity

**Target**: < 10 per method
**Maximum**: 15 per method

```php
<?php

// ✅ GOOD: Low complexity (3)
final class AgentValidator
{
    public function validate(Agent $agent): void
    {
        if (strlen($agent->getName()) < 3) {
            throw new ValidationException('Name too short');
        }

        if (strlen($agent->getName()) > 255) {
            throw new ValidationException('Name too long');
        }

        if (!$this->isValidModel($agent->getModel())) {
            throw new ValidationException('Invalid model');
        }
    }

    private function isValidModel(string $model): bool
    {
        return in_array($model, ['gpt-4', 'gpt-3.5-turbo', 'claude-3-opus'], true);
    }
}

// ❌ BAD: High complexity (15+)
final class AgentValidator
{
    public function validate(Agent $agent): void
    {
        $name = $agent->getName();
        if (strlen($name) < 3) {
            if ($agent->isRequired()) {
                throw new ValidationException('Name too short');
            } else {
                if ($agent->hasDefault()) {
                    $agent->setName($agent->getDefault());
                } else {
                    if ($this->config->allowEmpty()) {
                        // OK
                    } else {
                        throw new ValidationException('Name required');
                    }
                }
            }
        } elseif (strlen($name) > 255) {
            throw new ValidationException('Name too long');
        } elseif (preg_match('/[^a-z0-9]/i', $name)) {
            if ($this->config->allowSpecialChars()) {
                // OK
            } else {
                throw new ValidationException('Invalid characters');
            }
        }
        // ... more nested conditions
    }
}
```

### Cognitive Complexity

**Target**: < 15 per method
**Maximum**: 20 per method

### NPath Complexity

**Target**: < 200 per method

### Measuring Complexity

```bash
# Using phpmetrics
vendor/bin/phpmetrics --report-html=metrics src

# Using phploc
vendor/bin/phploc src

# Using pdepend
vendor/bin/pdepend --summary-xml=metrics/summary.xml src
```

**Review Checklist**:
- [ ] Cyclomatic complexity < 10
- [ ] Cognitive complexity < 15
- [ ] NPath complexity < 200
- [ ] Deeply nested code refactored
- [ ] Complex methods split into smaller ones
- [ ] Guard clauses used to reduce nesting

## Documentation Standards

### PHPDoc Requirements

```php
<?php

// ✅ GOOD: Comprehensive documentation
declare(strict_types=1);

namespace App\Domain\Agent;

use App\Domain\Agent\ValueObject\AgentId;
use App\Domain\Agent\Exception\AgentNotFoundException;

/**
 * Represents an AI agent that can process user inputs.
 *
 * An agent encapsulates an LLM configuration and system prompt,
 * allowing users to create specialized AI assistants for specific tasks.
 *
 * @final This class is not meant to be extended
 */
final class Agent
{
    /**
     * Creates a new agent with the specified configuration.
     *
     * The agent is created in an active state and can be executed immediately.
     * All configuration parameters are validated during creation.
     *
     * @param AgentId $id Unique identifier for the agent
     * @param string $userId ID of the user who owns this agent
     * @param string $name Display name for the agent (3-255 characters)
     * @param string $model LLM model to use (e.g., "gpt-4", "claude-3-opus")
     * @param string $systemPrompt Instructions for the agent's behavior
     *
     * @return self The newly created agent
     *
     * @throws \InvalidArgumentException If name is too short or too long
     * @throws \InvalidArgumentException If model is not supported
     */
    public static function create(
        AgentId $id,
        string $userId,
        string $name,
        string $model,
        string $systemPrompt
    ): self {
        // Implementation...
    }

    /**
     * Executes the agent with the provided input.
     *
     * This method validates that the agent is in an executable state,
     * then creates an execution request that will be processed by
     * the LLM service.
     *
     * @param string $input User input to process
     *
     * @return ExecutionRequest Request object containing execution details
     *
     * @throws AgentNotExecutableException If the agent is not active
     * @throws \InvalidArgumentException If input is empty
     */
    public function execute(string $input): ExecutionRequest
    {
        // Implementation...
    }

    /**
     * Returns the agent's unique identifier.
     *
     * @return AgentId The agent's ID
     */
    public function getId(): AgentId
    {
        return $this->id;
    }
}

// ❌ BAD: Missing or incomplete documentation
final class Agent
{
    // No class documentation

    // Incomplete PHPDoc
    /**
     * Creates agent
     */
    public static function create($id, $userId, $name, $model, $systemPrompt)
    {
        // Missing types
        // Missing exception documentation
    }

    // No documentation
    public function execute($input)
    {
    }

    public function getId()
    {
        // Missing return type documentation
    }
}
```

### Documentation Checklist

**Review Checklist**:
- [ ] All classes have PHPDoc comments
- [ ] Class purpose clearly explained
- [ ] All public methods documented
- [ ] Parameters documented with types
- [ ] Return types documented
- [ ] Exceptions documented with `@throws`
- [ ] Complex algorithms explained
- [ ] Edge cases noted
- [ ] Examples provided for complex APIs

## Testing Standards

### Test Organization

```
tests/
├── Unit/                    # Fast, isolated tests
│   ├── Domain/
│   │   ├── Agent/
│   │   │   ├── AgentTest.php
│   │   │   └── ValueObject/
│   │   │       └── AgentIdTest.php
│   │   └── Workflow/
│   └── Application/
├── Integration/             # Tests with dependencies
│   ├── Repository/
│   └── Service/
└── Functional/              # End-to-end tests
    └── Api/
```

### Test Quality

```php
<?php

// ✅ GOOD: Well-structured test
declare(strict_types=1);

namespace App\Tests\Unit\Domain\Agent;

use App\Domain\Agent\Agent;
use App\Domain\Agent\ValueObject\AgentId;
use App\Domain\Agent\Exception\AgentNotExecutableException;
use PHPUnit\Framework\TestCase;

/**
 * @covers \App\Domain\Agent\Agent
 */
final class AgentTest extends TestCase
{
    private AgentId $agentId;
    private string $userId;

    protected function setUp(): void
    {
        $this->agentId = AgentId::generate();
        $this->userId = 'user-123';
    }

    /**
     * @test
     */
    public function it_creates_agent_with_valid_data(): void
    {
        // Arrange
        $name = 'Test Agent';
        $model = 'gpt-4';
        $systemPrompt = 'You are a helpful assistant';

        // Act
        $agent = Agent::create(
            id: $this->agentId,
            userId: $this->userId,
            name: $name,
            model: $model,
            systemPrompt: $systemPrompt
        );

        // Assert
        $this->assertTrue($agent->isActive());
        $this->assertSame($name, $agent->getName());
        $this->assertSame($model, $agent->getModel());
        $this->assertTrue($this->agentId->equals($agent->getId()));
    }

    /**
     * @test
     */
    public function it_throws_exception_when_name_is_too_short(): void
    {
        // Arrange
        $this->expectException(\InvalidArgumentException::class);
        $this->expectExceptionMessage('Name must be at least 3 characters');

        // Act
        Agent::create(
            id: $this->agentId,
            userId: $this->userId,
            name: 'AB',  // Too short
            model: 'gpt-4',
            systemPrompt: 'Test'
        );
    }

    /**
     * @test
     * @dataProvider invalidModelProvider
     */
    public function it_throws_exception_for_invalid_model(string $invalidModel): void
    {
        // Arrange
        $this->expectException(\InvalidArgumentException::class);

        // Act
        Agent::create(
            id: $this->agentId,
            userId: $this->userId,
            name: 'Test Agent',
            model: $invalidModel,
            systemPrompt: 'Test'
        );
    }

    /**
     * @test
     */
    public function it_cannot_execute_when_deactivated(): void
    {
        // Arrange
        $agent = $this->createAgent();
        $agent->deactivate();

        $this->expectException(AgentNotExecutableException::class);
        $this->expectExceptionMessage('Agent is not active');

        // Act
        $agent->execute('test input');
    }

    /**
     * @return array<string, array<string>>
     */
    public function invalidModelProvider(): array
    {
        return [
            'empty string' => [''],
            'unknown model' => ['unknown-model'],
            'deprecated model' => ['gpt-3'],
        ];
    }

    private function createAgent(string $name = 'Test Agent'): Agent
    {
        return Agent::create(
            id: $this->agentId,
            userId: $this->userId,
            name: $name,
            model: 'gpt-4',
            systemPrompt: 'Test'
        );
    }
}

// ❌ BAD: Poor test quality
final class AgentTest extends TestCase
{
    // No test isolation - uses shared state
    private static $agent;

    // Vague test name
    public function testAgent(): void
    {
        // No Arrange/Act/Assert structure
        $agent = new Agent();
        $agent->setName('Test');
        $this->assertTrue(true);  // Meaningless assertion
    }

    // No edge cases tested
    // No exception testing
    // No data providers
    // Tests multiple things
    public function testEverything(): void
    {
        $agent = new Agent();
        $agent->setName('Test');
        $this->assertSame('Test', $agent->getName());

        $agent->execute('input');
        // No assertion about execution

        $agent->deactivate();
        // No assertion about state
    }
}
```

**Review Checklist**:
- [ ] Tests follow Arrange-Act-Assert pattern
- [ ] Test names clearly describe what is being tested
- [ ] One assertion concept per test
- [ ] Tests are independent and isolated
- [ ] Setup/teardown used appropriately
- [ ] Data providers used for parameterized tests
- [ ] Edge cases covered
- [ ] Exceptions tested
- [ ] Test doubles (mocks/stubs) used appropriately
- [ ] No test logic (if/loops in tests)

## Performance Standards

### Response Time Targets

```yaml
performance_standards:
  api_endpoints:
    p50: < 100ms
    p95: < 200ms
    p99: < 500ms
    max: < 2000ms

  database_queries:
    simple: < 10ms
    complex: < 50ms
    aggregations: < 100ms
    max: < 500ms

  external_api_calls:
    timeout: 30s
    p95: < 5000ms
```

### Performance Testing

```php
<?php

// ✅ GOOD: Performance-conscious code
final class AgentListService
{
    public function listAgents(string $userId, int $page, int $perPage): array
    {
        // Efficient query with pagination
        return $this->connection->fetchAllAssociative(
            'SELECT id, name, model, status, created_at
             FROM agents
             WHERE user_id = ?
             ORDER BY created_at DESC
             LIMIT ? OFFSET ?',
            [$userId, $perPage, ($page - 1) * $perPage]
        );
    }
}

// ❌ BAD: Performance issues
final class AgentListService
{
    public function listAgents(string $userId): array
    {
        // Fetches all agents - no pagination!
        $agents = $this->connection->fetchAllAssociative(
            'SELECT * FROM agents WHERE user_id = ?',
            [$userId]
        );

        $result = [];
        foreach ($agents as $agent) {
            // N+1 query problem!
            $executionCount = $this->connection->fetchOne(
                'SELECT COUNT(*) FROM executions WHERE agent_id = ?',
                [$agent['id']]
            );

            $result[] = [
                'agent' => $agent,
                'execution_count' => $executionCount,
            ];
        }

        return $result;
    }
}
```

**Review Checklist**:
- [ ] No N+1 query problems
- [ ] Pagination implemented for lists
- [ ] Database indexes exist for queries
- [ ] Caching implemented where appropriate
- [ ] Async processing for non-critical operations
- [ ] Query performance measured
- [ ] Memory usage monitored
- [ ] Load tests pass

## Security Standards

### Security Requirements

```php
<?php

// ✅ GOOD: Security best practices
final class AgentController extends AbstractController
{
    #[Route('/api/v1/agents/{id}', methods: ['GET'])]
    public function get(string $id): JsonResponse
    {
        // Authentication required
        $this->denyAccessUnlessGranted('IS_AUTHENTICATED_FULLY');

        $agent = $this->queryBus->query(new GetAgentQuery($id));

        if ($agent === null) {
            throw $this->createNotFoundException();
        }

        // Authorization check
        $this->denyAccessUnlessGranted('view', $agent);

        // Input validation (ID format)
        if (!preg_match('/^[a-f0-9\-]{36}$/', $id)) {
            throw new BadRequestException('Invalid agent ID format');
        }

        return $this->json(['data' => $agent]);
    }
}

// ❌ BAD: Security issues
final class AgentController extends AbstractController
{
    #[Route('/api/v1/agents/{id}', methods: ['GET'])]
    public function get(string $id): JsonResponse
    {
        // No authentication check
        // No authorization check
        // No input validation

        $agent = $this->connection->fetchAssociative(
            "SELECT * FROM agents WHERE id = '{$id}'"  // SQL injection!
        );

        return $this->json($agent);  // May expose sensitive data
    }
}
```

**Review Checklist**:
- [ ] Authentication enforced
- [ ] Authorization checks present
- [ ] Input validation implemented
- [ ] SQL injection prevented
- [ ] XSS prevention in place
- [ ] CSRF protection enabled
- [ ] Secrets not hardcoded
- [ ] No sensitive data in logs
- [ ] Security headers configured
- [ ] Dependencies scanned for vulnerabilities

## Quality Gates

### Pre-Commit Checks

```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Running pre-commit quality checks..."

# PHPStan
echo "Running PHPStan..."
vendor/bin/phpstan analyse --level=9 src tests
if [ $? -ne 0 ]; then
    echo "PHPStan failed. Commit aborted."
    exit 1
fi

# PHP CS Fixer
echo "Running PHP CS Fixer..."
vendor/bin/php-cs-fixer fix --config=.php-cs-fixer.php --dry-run
if [ $? -ne 0 ]; then
    echo "PHP CS Fixer found issues. Please run: vendor/bin/php-cs-fixer fix"
    exit 1
fi

# Unit tests
echo "Running unit tests..."
vendor/bin/phpunit --testsuite=Unit
if [ $? -ne 0 ]; then
    echo "Unit tests failed. Commit aborted."
    exit 1
fi

echo "All checks passed!"
exit 0
```

### CI Pipeline Quality Gates

```yaml
# .github/workflows/quality.yml
name: Quality Checks

on: [push, pull_request]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          coverage: xdebug

      - name: Install dependencies
        run: composer install --prefer-dist --no-progress

      - name: PHPStan
        run: vendor/bin/phpstan analyse --level=9 --error-format=github

      - name: Psalm
        run: vendor/bin/psalm --output-format=github

      - name: PHP CS Fixer
        run: vendor/bin/php-cs-fixer fix --dry-run --diff

      - name: Unit Tests
        run: vendor/bin/phpunit --testsuite=Unit --coverage-clover=coverage.xml

      - name: Coverage Check
        run: php coverage-checker.php coverage.xml 80

      - name: Mutation Testing
        run: vendor/bin/infection --min-msi=70
```

### Quality Gate Criteria

**All Must Pass**:
- [ ] PHPStan Level 9 with zero errors
- [ ] Psalm Level 1 with zero errors
- [ ] All unit tests passing
- [ ] Code coverage ≥ 80%
- [ ] Mutation score ≥ 70%
- [ ] No PHP CS Fixer violations
- [ ] No security vulnerabilities

**May Block Merge**:
- [ ] Integration tests passing
- [ ] Performance benchmarks met
- [ ] No increase in technical debt ratio
- [ ] Documentation updated

## Continuous Quality Improvement

### Quality Metrics Dashboard

```yaml
# quality-metrics.yaml
metrics:
  - name: Code Coverage
    current: 85%
    target: 90%
    trend: +2%

  - name: Technical Debt Ratio
    current: 3.2%
    target: < 5%
    trend: -0.5%

  - name: PHPStan Errors
    current: 0
    target: 0
    trend: stable

  - name: Cyclomatic Complexity (avg)
    current: 4.2
    target: < 5
    trend: -0.3

  - name: Duplicated Lines
    current: 1.8%
    target: < 3%
    trend: -0.2%
```

### Quality Review Schedule

**Daily**: Automated checks in CI
**Weekly**: Code review metrics review
**Monthly**: Quality metrics dashboard review
**Quarterly**: Quality standards review and update

### Quality Improvement Process

1. **Identify Issues**: Use metrics to find quality problems
2. **Prioritize**: Focus on high-impact, high-frequency issues
3. **Plan**: Create actionable improvement tasks
4. **Implement**: Make incremental improvements
5. **Measure**: Track impact of changes
6. **Iterate**: Continuously improve

## Summary

This quality standards document ensures:

1. **Measurable Quality**: Objective metrics for all quality aspects
2. **Automation**: Automated checks prevent quality issues
3. **Consistency**: Standards applied uniformly across codebase
4. **Documentation**: Code is well-documented and understandable
5. **Testing**: Comprehensive test coverage
6. **Performance**: Code meets performance targets
7. **Security**: Security best practices enforced
8. **Continuous Improvement**: Quality metrics tracked and improved

All code must meet these standards before merging to main branch.
