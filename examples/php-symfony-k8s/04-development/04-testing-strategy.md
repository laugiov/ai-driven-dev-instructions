# Testing Strategy

**Document Version**: 1.0
**Last Updated**: 2025-01-07
**Status**: Complete

## Table of Contents

1. [Overview](#overview)
2. [Testing Pyramid](#testing-pyramid)
3. [Unit Testing](#unit-testing)
4. [Integration Testing](#integration-testing)
5. [Functional Testing](#functional-testing)
6. [End-to-End Testing](#end-to-end-testing)
7. [Test Coverage](#test-coverage)
8. [Test Data Management](#test-data-management)
9. [Continuous Testing](#continuous-testing)
10. [Performance Testing](#performance-testing)

## Overview

Comprehensive testing ensures code quality, prevents regressions, and enables confident refactoring. Our testing strategy follows industry best practices with a focus on fast, reliable, and maintainable tests.

### Testing Goals

- **Coverage**: Minimum 80% code coverage
- **Speed**: Unit tests < 100ms, integration tests < 1s
- **Reliability**: Zero flaky tests
- **Maintainability**: Tests as first-class code
- **Documentation**: Tests as living documentation

## Testing Pyramid

```
         /\
        /  \  E2E Tests (5%)
       /____\
      /      \  Integration Tests (15%)
     /________\
    /          \  Unit Tests (80%)
   /__________/\
```

| Level | Percentage | Speed | Scope | Tools |
|-------|-----------|-------|-------|-------|
| **Unit** | 80% | Fast (ms) | Single class/method | PHPUnit |
| **Integration** | 15% | Medium (s) | Multiple components | PHPUnit + DB |
| **E2E** | 5% | Slow (min) | Full system | Behat/Cypress |

## Unit Testing

### Unit Test Structure

```php
<?php

declare(strict_types=1);

namespace Tests\Unit\Domain\LLMAgent\Entity;

use App\Domain\LLMAgent\Entity\Agent;
use App\Domain\LLMAgent\ValueObject\Model;
use PHPUnit\Framework\TestCase;

final class AgentTest extends TestCase
{
    /**
     * @test
     */
    public function it_creates_agent_with_valid_data(): void
    {
        // Arrange
        $name = 'Test Agent';
        $model = Model::GPT4;
        $systemPrompt = 'You are a helpful assistant';

        // Act
        $agent = Agent::create($name, $model, $systemPrompt);

        // Assert
        $this->assertSame($name, $agent->getName());
        $this->assertSame($model, $agent->getModel());
        $this->assertSame($systemPrompt, $agent->getSystemPrompt());
        $this->assertTrue($agent->isActive());
    }

    /**
     * @test
     */
    public function it_throws_exception_for_empty_name(): void
    {
        // Arrange
        $this->expectException(\InvalidArgumentException::class);
        $this->expectExceptionMessage('Agent name cannot be empty');

        // Act
        Agent::create('', Model::GPT4, 'System prompt');
    }

    /**
     * @test
     */
    public function it_deactivates_agent(): void
    {
        // Arrange
        $agent = Agent::create('Test Agent', Model::GPT4, 'Prompt');

        // Act
        $agent->deactivate();

        // Assert
        $this->assertFalse($agent->isActive());
    }
}
```

### Test Naming Convention

```php
// ✅ Good: Descriptive test names
public function it_creates_workflow_with_valid_definition(): void
public function it_throws_exception_when_workflow_name_is_too_long(): void
public function it_calculates_total_cost_correctly(): void

// ❌ Bad: Unclear test names
public function testWorkflow(): void
public function test1(): void
public function testCreateMethod(): void
```

### AAA Pattern (Arrange-Act-Assert)

```php
public function it_processes_completion_request(): void
{
    // Arrange - Set up test data and dependencies
    $prompt = 'Test prompt';
    $mockClient = $this->createMock(LLMClientInterface::class);
    $mockClient->expects($this->once())
        ->method('complete')
        ->with($prompt)
        ->willReturn(new CompletionResult('Response'));

    $service = new CompletionService($mockClient);

    // Act - Execute the behavior being tested
    $result = $service->process($prompt);

    // Assert - Verify the expected outcome
    $this->assertInstanceOf(CompletionResult::class, $result);
    $this->assertSame('Response', $result->getText());
}
```

### Test Doubles

```php
<?php

use PHPUnit\Framework\TestCase;

final class WorkflowServiceTest extends TestCase
{
    // Stub: Returns predefined values
    public function it_uses_stub_for_repository(): void
    {
        $stub = $this->createStub(WorkflowRepository::class);
        $stub->method('findById')->willReturn(new Workflow('123'));

        $service = new WorkflowService($stub);
        $workflow = $service->getWorkflow('123');

        $this->assertSame('123', $workflow->getId());
    }

    // Mock: Verifies interactions
    public function it_uses_mock_to_verify_save_called(): void
    {
        $mock = $this->createMock(WorkflowRepository::class);
        $mock->expects($this->once())
            ->method('save')
            ->with($this->isInstanceOf(Workflow::class));

        $service = new WorkflowService($mock);
        $service->createWorkflow('Test');
    }

    // Spy: Records method calls for later verification
    public function it_uses_spy_to_track_calls(): void
    {
        $spy = $this->createMock(EventDispatcher::class);
        $spy->expects($this->exactly(2))
            ->method('dispatch');

        $service = new WorkflowService($spy);
        $service->process();
    }

    // Fake: Working implementation for testing
    public function it_uses_fake_repository(): void
    {
        $fake = new InMemoryWorkflowRepository();
        $service = new WorkflowService($fake);

        $workflow = $service->createWorkflow('Test');
        $found = $service->getWorkflow($workflow->getId());

        $this->assertEquals($workflow, $found);
    }
}
```

### Testing Value Objects

```php
<?php

final class TemperatureTest extends TestCase
{
    /**
     * @test
     * @dataProvider validTemperatureProvider
     */
    public function it_creates_temperature_with_valid_value(float $value): void
    {
        $temperature = new Temperature($value);
        $this->assertSame($value, $temperature->getValue());
    }

    public static function validTemperatureProvider(): array
    {
        return [
            'minimum' => [0.0],
            'default' => [1.0],
            'maximum' => [2.0],
            'mid-range' => [1.5],
        ];
    }

    /**
     * @test
     * @dataProvider invalidTemperatureProvider
     */
    public function it_throws_exception_for_invalid_value(float $value): void
    {
        $this->expectException(\InvalidArgumentException::class);
        new Temperature($value);
    }

    public static function invalidTemperatureProvider(): array
    {
        return [
            'negative' => [-0.1],
            'too_high' => [2.1],
            'way_too_high' => [10.0],
        ];
    }
}
```

## Integration Testing

### Database Integration Tests

```php
<?php

declare(strict_types=1);

namespace Tests\Integration\Infrastructure\Persistence\Doctrine;

use App\Domain\LLMAgent\Entity\Agent;
use App\Infrastructure\Persistence\Doctrine\AgentRepository;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;

final class AgentRepositoryTest extends KernelTestCase
{
    private AgentRepository $repository;

    protected function setUp(): void
    {
        self::bootKernel();

        $this->repository = self::getContainer()->get(AgentRepository::class);

        // Start transaction for test isolation
        self::getContainer()->get('doctrine')->getConnection()->beginTransaction();
    }

    protected function tearDown(): void
    {
        // Rollback transaction to clean database
        self::getContainer()->get('doctrine')->getConnection()->rollBack();

        parent::tearDown();
    }

    /**
     * @test
     */
    public function it_persists_agent_to_database(): void
    {
        // Arrange
        $agent = Agent::create('Test Agent', Model::GPT4, 'System prompt');

        // Act
        $this->repository->save($agent);
        $found = $this->repository->findById($agent->getId());

        // Assert
        $this->assertNotNull($found);
        $this->assertSame($agent->getId(), $found->getId());
        $this->assertSame($agent->getName(), $found->getName());
    }

    /**
     * @test
     */
    public function it_finds_agents_by_user_id(): void
    {
        // Arrange
        $userId = 'user-123';
        $agent1 = Agent::create('Agent 1', Model::GPT4, 'Prompt 1', $userId);
        $agent2 = Agent::create('Agent 2', Model::GPT35, 'Prompt 2', $userId);
        $agent3 = Agent::create('Agent 3', Model::GPT4, 'Prompt 3', 'user-456');

        $this->repository->save($agent1);
        $this->repository->save($agent2);
        $this->repository->save($agent3);

        // Act
        $agents = $this->repository->findByUserId($userId);

        // Assert
        $this->assertCount(2, $agents);
        $this->assertContains($agent1->getId(), array_map(fn($a) => $a->getId(), $agents));
        $this->assertContains($agent2->getId(), array_map(fn($a) => $a->getId(), $agents));
    }
}
```

### API Integration Tests

```php
<?php

declare(strict_types=1);

namespace Tests\Integration\Infrastructure\Http\Controller;

use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;

final class AgentControllerTest extends WebTestCase
{
    /**
     * @test
     */
    public function it_creates_agent_via_api(): void
    {
        $client = static::createClient();

        $client->request('POST', '/api/v1/agents', [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer ' . $this->getValidToken(),
        ], json_encode([
            'name' => 'Test Agent',
            'model' => 'gpt-4',
            'system_prompt' => 'You are a helpful assistant',
        ]));

        $this->assertResponseStatusCodeSame(Response::HTTP_CREATED);

        $data = json_decode($client->getResponse()->getContent(), true);
        $this->assertArrayHasKey('id', $data);
        $this->assertIsString($data['id']);
    }

    /**
     * @test
     */
    public function it_returns_validation_errors_for_invalid_data(): void
    {
        $client = static::createClient();

        $client->request('POST', '/api/v1/agents', [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer ' . $this->getValidToken(),
        ], json_encode([
            'name' => '', // Invalid: empty name
            'model' => 'invalid-model',
        ]));

        $this->assertResponseStatusCodeSame(Response::HTTP_BAD_REQUEST);

        $data = json_decode($client->getResponse()->getContent(), true);
        $this->assertArrayHasKey('errors', $data);
    }

    private function getValidToken(): string
    {
        // Generate or retrieve valid JWT token for testing
        return 'test-token';
    }
}
```

### Message Bus Integration Tests

```php
<?php

final class CreateAgentHandlerTest extends KernelTestCase
{
    /**
     * @test
     */
    public function it_handles_create_agent_command(): void
    {
        self::bootKernel();

        $messageBus = self::getContainer()->get('messenger.bus.default');

        $command = new CreateAgentCommand(
            name: 'Test Agent',
            model: 'gpt-4',
            systemPrompt: 'Test prompt'
        );

        $envelope = $messageBus->dispatch($command);

        $handledStamp = $envelope->last(HandledStamp::class);
        $this->assertInstanceOf(HandledStamp::class, $handledStamp);

        $agentId = $handledStamp->getResult();
        $this->assertIsString($agentId);
    }
}
```

## Functional Testing

### Feature Testing with Behat

```gherkin
# features/agent_management.feature
Feature: Agent Management
  As a user
  I want to manage my AI agents
  So that I can use them in workflows

  Background:
    Given I am authenticated as "user@example.com"

  Scenario: Create a new agent
    When I create an agent with:
      | name          | Test Agent                    |
      | model         | gpt-4                         |
      | system_prompt | You are a helpful assistant   |
    Then the agent should be created successfully
    And I should see the agent in my agent list

  Scenario: Cannot create agent with invalid model
    When I create an agent with:
      | name          | Test Agent      |
      | model         | invalid-model   |
      | system_prompt | Test prompt     |
    Then I should see an error "Invalid model"
    And the agent should not be created

  Scenario: Update agent configuration
    Given I have an agent named "Test Agent"
    When I update the agent with:
      | temperature | 1.5 |
      | max_tokens  | 500 |
    Then the agent configuration should be updated
```

### Behat Context

```php
<?php

use Behat\Behat\Context\Context;
use Symfony\Component\HttpFoundation\Response;

final class AgentContext implements Context
{
    private ?Response $response = null;
    private array $agentData = [];

    /**
     * @When I create an agent with:
     */
    public function iCreateAnAgentWith(TableNode $table): void
    {
        $this->agentData = [];
        foreach ($table->getRowsHash() as $key => $value) {
            $this->agentData[$key] = $value;
        }

        $this->response = $this->client->request(
            'POST',
            '/api/v1/agents',
            json_encode($this->agentData)
        );
    }

    /**
     * @Then the agent should be created successfully
     */
    public function theAgentShouldBeCreatedSuccessfully(): void
    {
        Assert::assertEquals(201, $this->response->getStatusCode());
    }

    /**
     * @Then I should see an error :message
     */
    public function iShouldSeeAnError(string $message): void
    {
        $data = json_decode($this->response->getContent(), true);
        Assert::assertStringContainsString($message, $data['error']);
    }
}
```

## End-to-End Testing

### E2E Test Example

```php
<?php

namespace Tests\E2E;

use Facebook\WebDriver\WebDriverBy;
use Symfony\Component\Panther\PantherTestCase;

final class WorkflowCreationE2ETest extends PantherTestCase
{
    /**
     * @test
     */
    public function user_can_create_workflow(): void
    {
        $client = static::createPantherClient();

        // Login
        $crawler = $client->request('GET', '/login');
        $form = $crawler->selectButton('Login')->form([
            'email' => 'test@example.com',
            'password' => 'password',
        ]);
        $client->submit($form);

        // Navigate to workflows page
        $client->clickLink('Workflows');
        $this->assertSelectorTextContains('h1', 'My Workflows');

        // Create new workflow
        $client->clickLink('New Workflow');
        $crawler = $client->waitFor('#workflow-form');

        $form = $crawler->selectButton('Create')->form([
            'workflow[name]' => 'Test Workflow',
            'workflow[description]' => 'E2E test workflow',
        ]);
        $client->submit($form);

        // Verify creation
        $client->waitFor('.alert-success');
        $this->assertSelectorTextContains('.alert-success', 'Workflow created');

        // Verify in list
        $client->clickLink('Workflows');
        $this->assertSelectorTextContains('.workflow-list', 'Test Workflow');
    }
}
```

## Test Coverage

### PHPUnit Configuration

```xml
<!-- phpunit.xml.dist -->
<phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="vendor/phpunit/phpunit/phpunit.xsd"
         colors="true"
         bootstrap="tests/bootstrap.php">

    <testsuites>
        <testsuite name="Unit">
            <directory>tests/Unit</directory>
        </testsuite>
        <testsuite name="Integration">
            <directory>tests/Integration</directory>
        </testsuite>
    </testsuites>

    <coverage>
        <include>
            <directory suffix=".php">src</directory>
        </include>
        <exclude>
            <directory>src/Kernel.php</directory>
            <directory>src/*/Entity</directory>
            <directory>src/*/DTO</directory>
        </exclude>
        <report>
            <html outputDirectory="coverage/html"/>
            <clover outputFile="coverage/clover.xml"/>
        </report>
    </coverage>

    <php>
        <env name="APP_ENV" value="test"/>
        <env name="DATABASE_URL" value="postgresql://test:test@localhost:5432/test_db"/>
    </php>
</phpunit>
```

### Coverage Requirements

```bash
# Minimum coverage thresholds (enforced in CI)
./vendor/bin/phpunit --coverage-text --coverage-html=coverage \
  --coverage-clover=coverage.xml \
  --coverage-filter=src \
  --fail-on-warning

# Coverage gates in CI
if [ $(php -r "echo floor((simplexml_load_file('coverage.xml')->project->metrics['coveredstatements'] / simplexml_load_file('coverage.xml')->project->metrics['statements']) * 100);") -lt 80 ]; then
  echo "Coverage below 80%"
  exit 1
fi
```

### Mutation Testing

```bash
# Install Infection
composer require --dev infection/infection

# Run mutation tests
./vendor/bin/infection --threads=4 --min-msi=80 --min-covered-msi=90

# Configuration
{
  "source": {
    "directories": ["src"]
  },
  "logs": {
    "text": "infection.log",
    "html": "infection-report.html"
  },
  "mutators": {
    "@default": true
  }
}
```

## Test Data Management

### Fixtures

```php
<?php

declare(strict_types=1);

namespace Tests\Fixtures;

use App\Domain\LLMAgent\Entity\Agent;
use Doctrine\Bundle\FixturesBundle\Fixture;
use Doctrine\Persistence\ObjectManager;

final class AgentFixtures extends Fixture
{
    public const AGENT_GPT4 = 'agent-gpt4';
    public const AGENT_GPT35 = 'agent-gpt35';

    public function load(ObjectManager $manager): void
    {
        $agent1 = Agent::create(
            'GPT-4 Agent',
            Model::GPT4,
            'You are a helpful assistant'
        );
        $manager->persist($agent1);
        $this->addReference(self::AGENT_GPT4, $agent1);

        $agent2 = Agent::create(
            'GPT-3.5 Agent',
            Model::GPT35,
            'You are a helpful assistant'
        );
        $manager->persist($agent2);
        $this->addReference(self::AGENT_GPT35, $agent2);

        $manager->flush();
    }
}
```

### Factory Pattern for Test Data

```php
<?php

final class AgentFactory
{
    public static function create(array $overrides = []): Agent
    {
        $defaults = [
            'name' => 'Test Agent',
            'model' => Model::GPT4,
            'systemPrompt' => 'Test prompt',
            'configuration' => [],
        ];

        $data = array_merge($defaults, $overrides);

        return Agent::create(
            $data['name'],
            $data['model'],
            $data['systemPrompt'],
            $data['configuration']
        );
    }

    public static function createMany(int $count, array $overrides = []): array
    {
        $agents = [];
        for ($i = 0; $i < $count; $i++) {
            $agents[] = self::create(array_merge($overrides, [
                'name' => "Test Agent {$i}",
            ]));
        }
        return $agents;
    }
}

// Usage in tests
$agent = AgentFactory::create(['name' => 'Custom Name']);
$agents = AgentFactory::createMany(10);
```

## Continuous Testing

### Test Automation in CI

```yaml
# .github/workflows/tests.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_DB: test_db
          POSTGRES_PASSWORD: test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v3

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: 8.3
          coverage: xdebug

      - name: Install dependencies
        run: composer install --no-progress

      - name: Run PHPUnit
        run: ./vendor/bin/phpunit --coverage-clover=coverage.xml

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.xml
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Running tests before commit..."

# Run unit tests
./vendor/bin/phpunit tests/Unit --stop-on-failure

if [ $? -ne 0 ]; then
  echo "❌ Unit tests failed. Commit aborted."
  exit 1
fi

echo "✅ All tests passed!"
```

## Performance Testing

### Load Testing

```php
<?php

use K6\K6;

// k6 load test script
export default function() {
    const url = 'https://api.platform.local/api/v1/agents';

    const payload = JSON.stringify({
        name: 'Load Test Agent',
        model: 'gpt-4',
        system_prompt: 'Test',
    });

    const params = {
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${__ENV.API_TOKEN}`,
        },
    };

    const response = http.post(url, payload, params);

    check(response, {
        'status is 201': (r) => r.status === 201,
        'response time < 200ms': (r) => r.timings.duration < 200,
    });
}
```

## Test Best Practices

1. ✅ **One assertion per test** (when possible)
2. ✅ **Test behavior, not implementation**
3. ✅ **Use descriptive test names**
4. ✅ **Keep tests independent**
5. ✅ **Use test data builders/factories**
6. ✅ **Mock external dependencies**
7. ✅ **Test edge cases and error conditions**
8. ✅ **Maintain test code quality**
9. ✅ **Run tests in parallel when possible**
10. ✅ **Keep tests fast**

## Common Anti-Patterns

### ❌ Testing Implementation Details

```php
// Bad: Testing private method
$reflection = new ReflectionClass($service);
$method = $reflection->getMethod('privateMethod');
$method->setAccessible(true);
$result = $method->invoke($service, $arg);

// Good: Test public behavior
$result = $service->publicMethod($arg);
```

### ❌ Over-mocking

```php
// Bad: Mocking everything
$mock1 = $this->createMock(Dependency1::class);
$mock2 = $this->createMock(Dependency2::class);
$mock3 = $this->createMock(Dependency3::class);

// Good: Use real objects when simple
$service = new Service(
    new SimpleDependency(),
    $mockComplexDependency
);
```

### ❌ Test Interdependence

```php
// Bad: Tests depend on execution order
public function test1_creates_user() { /* creates user */ }
public function test2_updates_user() { /* assumes user from test1 */ }

// Good: Each test is independent
public function it_creates_user() { /* creates and tests */ }
public function it_updates_user() { /* creates user, then updates */ }
```

## References

- [PHPUnit Documentation](https://phpunit.de/documentation.html)
- [Behat Documentation](https://docs.behat.org/)
- [Symfony Testing](https://symfony.com/doc/current/testing.html)
- [Test Driven Development](https://martinfowler.com/bliki/TestDrivenDevelopment.html)

## Related Documentation

- [02-coding-guidelines-php.md](02-coding-guidelines-php.md) - PHP coding standards
- [03-symfony-best-practices.md](03-symfony-best-practices.md) - Symfony patterns
- [../06-cicd/04-quality-gates.md](../06-cicd/04-quality-gates.md) - CI quality gates

---

**Document Maintainers**: Engineering Team, QA Team
**Review Cycle**: Quarterly
**Next Review**: 2025-04-07
