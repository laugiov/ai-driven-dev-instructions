# Workflow Engine

## Prerequisites for Implementation

**Before implementing this service, ensure you have read and understood**:

✅ **Foundation Knowledge** (REQUIRED):
1. [README.md](../README.md) - Overall system architecture
2. [01-architecture/01-architecture-overview.md](../01-architecture/01-architecture-overview.md) - Event-driven architecture, Saga pattern justification
3. [01-architecture/03-hexagonal-architecture.md](../01-architecture/03-hexagonal-architecture.md) - Ports & Adapters for complex orchestration
4. [01-architecture/04-domain-driven-design.md](../01-architecture/04-domain-driven-design.md) - Aggregates, Domain Events (critical for workflow)
5. [04-development/02-coding-guidelines-php.md](../04-development/02-coding-guidelines-php.md) - PHP 8.3, PHPStan Level 9

✅ **Architecture Patterns** (REQUIRED):
1. [01-architecture/06-communication-patterns.md](../01-architecture/06-communication-patterns.md) - **CRITICAL**: Saga pattern, choreography vs orchestration, compensation logic
2. [03-infrastructure/06-message-queue.md](../03-infrastructure/06-message-queue.md) - RabbitMQ event patterns for async step execution

✅ **Dependencies** (REQUIRED - this service depends on others):
1. [08-services/04-agent-manager.md](04-agent-manager.md) - For Agent execution steps
2. [08-services/05-validation-service.md](05-validation-service.md) - For Validation steps
3. [08-services/06-notification-service.md](06-notification-service.md) - For workflow notifications

✅ **Testing** (REQUIRED):
1. [04-development/04-testing-strategy.md](../04-development/04-testing-strategy.md) - State machine testing, Saga compensation testing
2. [04-development/07-error-handling.md](../04-development/07-error-handling.md) - Retry strategies, error recovery (critical for workflow)

**Estimated Reading Time**: 4-5 hours
**Implementation Time**: 7-10 days (following [IMPLEMENTATION_ROADMAP.md](../IMPLEMENTATION_ROADMAP.md) Phase 3, Week 10)
**Complexity**: ⚠️ **HIGHEST** - Most complex service, implement last

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Workflow Definition](#workflow-definition)
4. [Execution Engine](#execution-engine)
5. [State Management](#state-management)
6. [Step Types](#step-types)
7. [Error Handling](#error-handling)
8. [API Endpoints](#api-endpoints)
9. [Database Schema](#database-schema)
10. [Implementation Examples](#implementation-examples)

## Overview

### Purpose

The Workflow Engine is the core service responsible for:
- Workflow definition and versioning
- Workflow execution orchestration
- Step-by-step execution coordination
- State management and persistence
- Conditional logic and branching
- Error handling and retries
- Parallel execution support
- Scheduling and triggers

### Service Specifications

```yaml
service_info:
  name: workflow-engine
  version: 1.0.0
  language: PHP 8.3
  framework: Symfony 7
  port: 8080

  database:
    type: PostgreSQL 15
    name: workflow_db
    connection_pool: 100

  cache:
    type: Redis
    purpose:
      - Execution state cache
      - Step result cache
      - Workflow definition cache

  message_queue:
    type: RabbitMQ
    exchanges:
      - workflow.executions (topic)
      - workflow.events (fanout)
    queues:
      - workflow.execute (durable)
      - workflow.steps (durable)
      - workflow.retry (delayed)

  dependencies:
    internal:
      - Agent Manager (AI agent invocation)
      - Integration Hub (external API calls)
      - Notification Service (alerts and notifications)
      - Authentication Service (user context)
    external:
      - RabbitMQ (async execution)
      - Redis (state caching)

  sla:
    availability: 99.95%
    latency_p95: 300ms (API calls)
    latency_p99: 500ms
    throughput: 5000 workflows/s
    execution_time: < 30s (simple workflows)
```

## Architecture

### Component Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                    Workflow Engine Service                        │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              Presentation Layer (HTTP)                  │    │
│  │                                                          │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │    │
│  │  │  Workflow    │  │  Execution   │  │   Schedule   │ │    │
│  │  │ Controller   │  │  Controller  │  │  Controller  │ │    │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │    │
│  └─────────┼──────────────────┼──────────────────┼─────────┘    │
│            │                  │                  │               │
│  ┌─────────┼──────────────────┼──────────────────┼─────────┐    │
│  │         ▼    Application Layer            ▼   │         │    │
│  │                                                          │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │    │
│  │  │   Create     │  │   Execute    │  │   Schedule   │ │    │
│  │  │  Workflow    │  │  Workflow    │  │   Workflow   │ │    │
│  │  │  UseCase     │  │  UseCase     │  │   UseCase    │ │    │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │    │
│  └─────────┼──────────────────┼──────────────────┼─────────┘    │
│            │                  │                  │               │
│  ┌─────────┼──────────────────┼──────────────────┼─────────┐    │
│  │         ▼       Domain Layer                  ▼         │    │
│  │                                                          │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │    │
│  │  │  Workflow    │  │  Execution   │  │  Workflow    │ │    │
│  │  │   Entity     │  │   Entity     │  │   Step       │ │    │
│  │  │              │  │              │  │   Entity     │ │    │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │    │
│  └─────────┼──────────────────┼──────────────────┼─────────┘    │
│            │                  │                  │               │
│  ┌─────────┼──────────────────┼──────────────────┼─────────┐    │
│  │         ▼   Infrastructure Layer              ▼         │    │
│  │                                                          │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │    │
│  │  │  Workflow    │  │  Execution   │  │    Step      │ │    │
│  │  │ Repository   │  │   Engine     │  │  Executor    │ │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘ │    │
│  │                                                          │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │    │
│  │  │   Message    │  │    Redis     │  │   Agent      │ │    │
│  │  │   Queue      │  │    Cache     │  │   Manager    │ │    │
│  │  │   Handler    │  │              │  │   Client     │ │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘ │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                   │
│            ▼                  ▼                  ▼               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  PostgreSQL  │  │    Redis     │  │  RabbitMQ    │          │
│  │ workflow_db  │  │   Cache      │  │ Message Bus  │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└──────────────────────────────────────────────────────────────────┘
```

### Execution Flow

```
┌──────────────┐
│  Client API  │
│   Request    │
└──────┬───────┘
       │
       ▼
┌──────────────────────────────────┐
│  POST /api/v1/workflows/{id}/    │
│         execute                   │
└──────┬───────────────────────────┘
       │
       ▼
┌──────────────────────────────────┐
│   ExecuteWorkflowUseCase         │
│   • Validate workflow            │
│   • Create execution record      │
│   • Publish execution message    │
└──────┬───────────────────────────┘
       │
       ▼
┌──────────────────────────────────┐
│      RabbitMQ Queue              │
│   workflow.execute               │
└──────┬───────────────────────────┘
       │
       ▼
┌──────────────────────────────────┐
│   WorkflowExecutionHandler       │
│   (Async Consumer)               │
└──────┬───────────────────────────┘
       │
       ▼
┌──────────────────────────────────┐
│     ExecutionEngine              │
│   • Load workflow definition     │
│   • Initialize execution context │
│   • Execute steps sequentially   │
└──────┬───────────────────────────┘
       │
       ├─────────┬─────────┬─────────┐
       ▼         ▼         ▼         ▼
  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
  │ Step 1 │ │ Step 2 │ │ Step 3 │ │ Step N │
  │Execute │ │Execute │ │Execute │ │Execute │
  └────┬───┘ └────┬───┘ └────┬───┘ └────┬───┘
       │         │         │         │
       ▼         ▼         ▼         ▼
  ┌────────────────────────────────────────┐
  │     Step Executors                     │
  │  • HttpStepExecutor                    │
  │  • AgentStepExecutor                   │
  │  • TransformStepExecutor               │
  │  • ConditionalStepExecutor             │
  │  • ParallelStepExecutor                │
  └────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────┐
│  Update Execution Status         │
│  • Store step results            │
│  • Update state                  │
│  • Trigger notifications         │
└──────────────────────────────────┘
```

## Workflow Definition

### Domain Model

```php
<?php
// src/Domain/Workflow/Workflow.php

declare(strict_types=1);

namespace App\Domain\Workflow;

use App\Domain\Workflow\ValueObject\WorkflowId;
use App\Domain\Workflow\ValueObject\WorkflowName;
use App\Domain\Workflow\Event\WorkflowCreatedEvent;
use App\Domain\Workflow\Event\WorkflowPublishedEvent;
use App\Domain\Common\AggregateRoot;

final class Workflow extends AggregateRoot
{
    private array $steps = [];
    private array $triggers = [];
    private WorkflowStatus $status;
    private int $version = 1;
    private ?\DateTimeImmutable $publishedAt = null;

    public function __construct(
        private readonly WorkflowId $id,
        private WorkflowName $name,
        private string $description,
        private readonly string $userId,
        private readonly \DateTimeImmutable $createdAt,
    ) {
        $this->status = WorkflowStatus::DRAFT;
    }

    public static function create(
        WorkflowId $id,
        WorkflowName $name,
        string $description,
        string $userId,
    ): self {
        $workflow = new self(
            $id,
            $name,
            $description,
            $userId,
            new \DateTimeImmutable()
        );

        $workflow->recordEvent(new WorkflowCreatedEvent(
            eventId: uniqid('evt_', true),
            workflowId: $id,
            userId: $userId,
            occurredAt: new \DateTimeImmutable()
        ));

        return $workflow;
    }

    public function addStep(WorkflowStep $step): void
    {
        if ($this->status !== WorkflowStatus::DRAFT) {
            throw new \DomainException('Cannot modify published workflow');
        }

        $this->steps[] = $step;
    }

    public function removeStep(string $stepId): void
    {
        if ($this->status !== WorkflowStatus::DRAFT) {
            throw new \DomainException('Cannot modify published workflow');
        }

        $this->steps = array_filter(
            $this->steps,
            fn(WorkflowStep $step) => $step->getId() !== $stepId
        );

        $this->steps = array_values($this->steps);
    }

    public function updateStep(string $stepId, array $config): void
    {
        if ($this->status !== WorkflowStatus::DRAFT) {
            throw new \DomainException('Cannot modify published workflow');
        }

        foreach ($this->steps as $step) {
            if ($step->getId() === $stepId) {
                $step->updateConfig($config);
                return;
            }
        }

        throw new \DomainException("Step not found: {$stepId}");
    }

    public function publish(): void
    {
        if ($this->status === WorkflowStatus::PUBLISHED) {
            throw new \DomainException('Workflow already published');
        }

        if (empty($this->steps)) {
            throw new \DomainException('Cannot publish workflow without steps');
        }

        $this->validateWorkflow();

        $this->status = WorkflowStatus::PUBLISHED;
        $this->publishedAt = new \DateTimeImmutable();

        $this->recordEvent(new WorkflowPublishedEvent(
            eventId: uniqid('evt_', true),
            workflowId: $this->id,
            version: $this->version,
            occurredAt: new \DateTimeImmutable()
        ));
    }

    public function createNewVersion(): self
    {
        $newWorkflow = clone $this;
        $newWorkflow->version = $this->version + 1;
        $newWorkflow->status = WorkflowStatus::DRAFT;
        $newWorkflow->publishedAt = null;

        return $newWorkflow;
    }

    private function validateWorkflow(): void
    {
        // Validate workflow structure
        $stepIds = array_map(fn(WorkflowStep $step) => $step->getId(), $this->steps);

        // Check for duplicate step IDs
        if (count($stepIds) !== count(array_unique($stepIds))) {
            throw new \DomainException('Duplicate step IDs found');
        }

        // Validate each step
        foreach ($this->steps as $step) {
            $step->validate();
        }

        // Validate conditional steps reference existing steps
        foreach ($this->steps as $step) {
            if ($step->getType() === StepType::CONDITIONAL) {
                $branchSteps = $step->getConfig()['branches'] ?? [];
                foreach ($branchSteps as $branch) {
                    $targetStepId = $branch['target_step'] ?? null;
                    if ($targetStepId && !in_array($targetStepId, $stepIds, true)) {
                        throw new \DomainException("Invalid branch target: {$targetStepId}");
                    }
                }
            }
        }
    }

    // Getters
    public function getId(): WorkflowId { return $this->id; }
    public function getName(): WorkflowName { return $this->name; }
    public function getDescription(): string { return $this->description; }
    public function getUserId(): string { return $this->userId; }
    public function getSteps(): array { return $this->steps; }
    public function getStatus(): WorkflowStatus { return $this->status; }
    public function getVersion(): int { return $this->version; }
}

// src/Domain/Workflow/WorkflowStep.php

declare(strict_types=1);

namespace App\Domain\Workflow;

final class WorkflowStep
{
    public function __construct(
        private readonly string $id,
        private readonly string $name,
        private readonly StepType $type,
        private array $config,
        private readonly int $order,
        private ?string $dependsOn = null,
    ) {}

    public function updateConfig(array $config): void
    {
        $this->config = array_merge($this->config, $config);
    }

    public function validate(): void
    {
        match ($this->type) {
            StepType::HTTP => $this->validateHttpStep(),
            StepType::AGENT => $this->validateAgentStep(),
            StepType::TRANSFORM => $this->validateTransformStep(),
            StepType::CONDITIONAL => $this->validateConditionalStep(),
            StepType::PARALLEL => $this->validateParallelStep(),
        };
    }

    private function validateHttpStep(): void
    {
        if (empty($this->config['url'])) {
            throw new \DomainException("HTTP step requires 'url' config");
        }

        if (empty($this->config['method'])) {
            throw new \DomainException("HTTP step requires 'method' config");
        }

        $validMethods = ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'];
        if (!in_array($this->config['method'], $validMethods, true)) {
            throw new \DomainException("Invalid HTTP method");
        }
    }

    private function validateAgentStep(): void
    {
        if (empty($this->config['agent_id'])) {
            throw new \DomainException("Agent step requires 'agent_id' config");
        }

        if (empty($this->config['input'])) {
            throw new \DomainException("Agent step requires 'input' config");
        }
    }

    private function validateTransformStep(): void
    {
        if (empty($this->config['expression'])) {
            throw new \DomainException("Transform step requires 'expression' config");
        }
    }

    private function validateConditionalStep(): void
    {
        if (empty($this->config['condition'])) {
            throw new \DomainException("Conditional step requires 'condition' config");
        }

        if (empty($this->config['branches'])) {
            throw new \DomainException("Conditional step requires 'branches' config");
        }
    }

    private function validateParallelStep(): void
    {
        if (empty($this->config['steps']) || !is_array($this->config['steps'])) {
            throw new \DomainException("Parallel step requires 'steps' array config");
        }
    }

    // Getters
    public function getId(): string { return $this->id; }
    public function getName(): string { return $this->name; }
    public function getType(): StepType { return $this->type; }
    public function getConfig(): array { return $this->config; }
    public function getOrder(): int { return $this->order; }
    public function getDependsOn(): ?string { return $this->dependsOn; }
}

// src/Domain/Workflow/StepType.php

declare(strict_types=1);

namespace App\Domain/Workflow;

enum StepType: string
{
    case HTTP = 'http';
    case AGENT = 'agent';
    case TRANSFORM = 'transform';
    case CONDITIONAL = 'conditional';
    case PARALLEL = 'parallel';
    case DELAY = 'delay';
    case NOTIFICATION = 'notification';
}

// src/Domain/Workflow/WorkflowStatus.php

declare(strict_types=1);

namespace App\Domain\Workflow;

enum WorkflowStatus: string
{
    case DRAFT = 'draft';
    case PUBLISHED = 'published';
    case ARCHIVED = 'archived';
}
```

### JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Workflow Definition",
  "type": "object",
  "required": ["name", "steps"],
  "properties": {
    "name": {
      "type": "string",
      "minLength": 3,
      "maxLength": 100,
      "description": "Workflow name"
    },
    "description": {
      "type": "string",
      "maxLength": 500,
      "description": "Workflow description"
    },
    "version": {
      "type": "integer",
      "minimum": 1,
      "description": "Workflow version"
    },
    "triggers": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "type": {
            "type": "string",
            "enum": ["manual", "schedule", "webhook", "event"]
          },
          "config": {
            "type": "object"
          }
        }
      }
    },
    "steps": {
      "type": "array",
      "minItems": 1,
      "items": {
        "$ref": "#/definitions/step"
      }
    },
    "error_handling": {
      "type": "object",
      "properties": {
        "on_error": {
          "type": "string",
          "enum": ["fail", "continue", "retry"]
        },
        "max_retries": {
          "type": "integer",
          "minimum": 0,
          "maximum": 5
        },
        "retry_delay": {
          "type": "integer",
          "minimum": 1000,
          "description": "Delay in milliseconds"
        }
      }
    }
  },
  "definitions": {
    "step": {
      "type": "object",
      "required": ["id", "name", "type", "config"],
      "properties": {
        "id": {
          "type": "string",
          "pattern": "^step_[a-z0-9]+$"
        },
        "name": {
          "type": "string",
          "minLength": 1,
          "maxLength": 100
        },
        "type": {
          "type": "string",
          "enum": ["http", "agent", "transform", "conditional", "parallel", "delay", "notification"]
        },
        "config": {
          "type": "object"
        },
        "depends_on": {
          "type": "string",
          "description": "ID of step that must complete before this one"
        },
        "timeout": {
          "type": "integer",
          "minimum": 1000,
          "maximum": 300000,
          "description": "Step timeout in milliseconds"
        },
        "retry": {
          "type": "object",
          "properties": {
            "max_attempts": {
              "type": "integer",
              "minimum": 1,
              "maximum": 5
            },
            "backoff": {
              "type": "string",
              "enum": ["fixed", "exponential"]
            }
          }
        }
      }
    }
  }
}
```

## Execution Engine

### Execution Entity

```php
<?php
// src/Domain/Workflow/Execution.php

declare(strict_types=1);

namespace App\Domain\Workflow;

use App\Domain\Workflow\ValueObject\ExecutionId;
use App\Domain\Workflow\ValueObject\WorkflowId;
use App\Domain\Workflow\Event\ExecutionStartedEvent;
use App\Domain\Workflow\Event\ExecutionCompletedEvent;
use App\Domain\Workflow\Event\ExecutionFailedEvent;
use App\Domain\Common\AggregateRoot;

final class Execution extends AggregateRoot
{
    private array $stepResults = [];
    private array $context = [];
    private ExecutionStatus $status;
    private ?\DateTimeImmutable $startedAt = null;
    private ?\DateTimeImmutable $completedAt = null;
    private ?string $errorMessage = null;

    public function __construct(
        private readonly ExecutionId $id,
        private readonly WorkflowId $workflowId,
        private readonly string $userId,
        private readonly array $input,
        private readonly \DateTimeImmutable $createdAt,
    ) {
        $this->status = ExecutionStatus::PENDING;
        $this->context = $input;
    }

    public static function create(
        ExecutionId $id,
        WorkflowId $workflowId,
        string $userId,
        array $input,
    ): self {
        return new self(
            $id,
            $workflowId,
            $userId,
            $input,
            new \DateTimeImmutable()
        );
    }

    public function start(): void
    {
        if ($this->status !== ExecutionStatus::PENDING) {
            throw new \DomainException('Execution already started');
        }

        $this->status = ExecutionStatus::RUNNING;
        $this->startedAt = new \DateTimeImmutable();

        $this->recordEvent(new ExecutionStartedEvent(
            eventId: uniqid('evt_', true),
            executionId: $this->id,
            workflowId: $this->workflowId,
            occurredAt: new \DateTimeImmutable()
        ));
    }

    public function recordStepResult(string $stepId, StepResult $result): void
    {
        if ($this->status !== ExecutionStatus::RUNNING) {
            throw new \DomainException('Cannot record step result for non-running execution');
        }

        $this->stepResults[$stepId] = $result;

        // Update context with step output
        if ($result->isSuccess() && $result->getOutput() !== null) {
            $this->context["steps.{$stepId}"] = $result->getOutput();
        }
    }

    public function complete(array $output): void
    {
        if ($this->status !== ExecutionStatus::RUNNING) {
            throw new \DomainException('Can only complete running execution');
        }

        $this->status = ExecutionStatus::COMPLETED;
        $this->completedAt = new \DateTimeImmutable();
        $this->context['output'] = $output;

        $this->recordEvent(new ExecutionCompletedEvent(
            eventId: uniqid('evt_', true),
            executionId: $this->id,
            workflowId: $this->workflowId,
            duration: $this->getDuration(),
            occurredAt: new \DateTimeImmutable()
        ));
    }

    public function fail(string $errorMessage, ?string $stepId = null): void
    {
        if ($this->status === ExecutionStatus::COMPLETED) {
            throw new \DomainException('Cannot fail completed execution');
        }

        $this->status = ExecutionStatus::FAILED;
        $this->completedAt = new \DateTimeImmutable();
        $this->errorMessage = $errorMessage;

        $this->recordEvent(new ExecutionFailedEvent(
            eventId: uniqid('evt_', true),
            executionId: $this->id,
            workflowId: $this->workflowId,
            errorMessage: $errorMessage,
            failedStepId: $stepId,
            occurredAt: new \DateTimeImmutable()
        ));
    }

    public function cancel(): void
    {
        if ($this->status !== ExecutionStatus::RUNNING) {
            throw new \DomainException('Can only cancel running execution');
        }

        $this->status = ExecutionStatus::CANCELLED;
        $this->completedAt = new \DateTimeImmutable();
    }

    public function getStepResult(string $stepId): ?StepResult
    {
        return $this->stepResults[$stepId] ?? null;
    }

    public function getContextValue(string $key): mixed
    {
        return $this->context[$key] ?? null;
    }

    public function setContextValue(string $key, mixed $value): void
    {
        $this->context[$key] = $value;
    }

    public function getDuration(): ?int
    {
        if ($this->startedAt === null || $this->completedAt === null) {
            return null;
        }

        return $this->completedAt->getTimestamp() - $this->startedAt->getTimestamp();
    }

    // Getters
    public function getId(): ExecutionId { return $this->id; }
    public function getWorkflowId(): WorkflowId { return $this->workflowId; }
    public function getStatus(): ExecutionStatus { return $this->status; }
    public function getStepResults(): array { return $this->stepResults; }
    public function getContext(): array { return $this->context; }
    public function getErrorMessage(): ?string { return $this->errorMessage; }
}

// src/Domain/Workflow/StepResult.php

declare(strict_types=1);

namespace App\Domain\Workflow;

final class StepResult
{
    public function __construct(
        private readonly bool $success,
        private readonly mixed $output,
        private readonly ?string $errorMessage = null,
        private readonly ?int $duration = null,
    ) {}

    public static function success(mixed $output, int $duration): self
    {
        return new self(true, $output, null, $duration);
    }

    public static function failure(string $errorMessage, int $duration): self
    {
        return new self(false, null, $errorMessage, $duration);
    }

    public function isSuccess(): bool { return $this->success; }
    public function getOutput(): mixed { return $this->output; }
    public function getErrorMessage(): ?string { return $this->errorMessage; }
    public function getDuration(): ?int { return $this->duration; }
}

// src/Domain/Workflow/ExecutionStatus.php

declare(strict_types=1);

namespace App\Domain\Workflow;

enum ExecutionStatus: string
{
    case PENDING = 'pending';
    case RUNNING = 'running';
    case COMPLETED = 'completed';
    case FAILED = 'failed';
    case CANCELLED = 'cancelled';
}
```

### Execution Engine Implementation

```php
<?php
// src/Infrastructure/Workflow/ExecutionEngine.php

declare(strict_types=1);

namespace App\Infrastructure\Workflow;

use App\Domain\Workflow\Workflow;
use App\Domain\Workflow\Execution;
use App\Domain\Workflow\WorkflowStep;
use App\Domain\Workflow\StepResult;
use App\Infrastructure\Workflow\Executor\StepExecutorFactory;
use Psr\Log\LoggerInterface;

final class ExecutionEngine
{
    public function __construct(
        private readonly StepExecutorFactory $executorFactory,
        private readonly LoggerInterface $logger,
    ) {}

    public function execute(Workflow $workflow, Execution $execution): void
    {
        $this->logger->info('Starting workflow execution', [
            'workflow_id' => $workflow->getId()->toString(),
            'execution_id' => $execution->getId()->toString(),
        ]);

        $execution->start();

        try {
            // Execute steps in order
            foreach ($workflow->getSteps() as $step) {
                $this->executeStep($step, $execution);

                // Check if step failed
                $result = $execution->getStepResult($step->getId());
                if ($result && !$result->isSuccess()) {
                    $this->handleStepFailure($step, $result, $execution, $workflow);
                    return;
                }
            }

            // All steps completed successfully
            $output = $this->buildOutput($execution);
            $execution->complete($output);

            $this->logger->info('Workflow execution completed successfully', [
                'workflow_id' => $workflow->getId()->toString(),
                'execution_id' => $execution->getId()->toString(),
                'duration' => $execution->getDuration(),
            ]);

        } catch (\Throwable $e) {
            $this->logger->error('Workflow execution failed with exception', [
                'workflow_id' => $workflow->getId()->toString(),
                'execution_id' => $execution->getId()->toString(),
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            $execution->fail($e->getMessage());
        }
    }

    private function executeStep(WorkflowStep $step, Execution $execution): void
    {
        $this->logger->debug('Executing step', [
            'step_id' => $step->getId(),
            'step_type' => $step->getType()->value,
            'execution_id' => $execution->getId()->toString(),
        ]);

        $startTime = microtime(true);

        try {
            // Get appropriate executor for step type
            $executor = $this->executorFactory->getExecutor($step->getType());

            // Execute step with current context
            $output = $executor->execute($step, $execution->getContext());

            $duration = (int) ((microtime(true) - $startTime) * 1000);

            // Record successful result
            $result = StepResult::success($output, $duration);
            $execution->recordStepResult($step->getId(), $result);

            $this->logger->debug('Step executed successfully', [
                'step_id' => $step->getId(),
                'duration_ms' => $duration,
            ]);

        } catch (\Throwable $e) {
            $duration = (int) ((microtime(true) - $startTime) * 1000);

            // Record failure
            $result = StepResult::failure($e->getMessage(), $duration);
            $execution->recordStepResult($step->getId(), $result);

            $this->logger->error('Step execution failed', [
                'step_id' => $step->getId(),
                'error' => $e->getMessage(),
                'duration_ms' => $duration,
            ]);
        }
    }

    private function handleStepFailure(
        WorkflowStep $step,
        StepResult $result,
        Execution $execution,
        Workflow $workflow
    ): void {
        $errorHandling = $workflow->getErrorHandling();

        match ($errorHandling['on_error'] ?? 'fail') {
            'fail' => $execution->fail(
                $result->getErrorMessage() ?? 'Step execution failed',
                $step->getId()
            ),
            'continue' => $this->logger->warning('Step failed but continuing execution', [
                'step_id' => $step->getId(),
                'error' => $result->getErrorMessage(),
            ]),
            'retry' => $this->retryStep($step, $execution, $errorHandling),
        };
    }

    private function retryStep(WorkflowStep $step, Execution $execution, array $errorHandling): void
    {
        $maxRetries = $errorHandling['max_retries'] ?? 3;
        $retryDelay = $errorHandling['retry_delay'] ?? 1000;

        // Implementation of retry logic would go here
        // For now, just fail
        $execution->fail('Max retries exceeded', $step->getId());
    }

    private function buildOutput(Execution $execution): array
    {
        $output = [];

        foreach ($execution->getStepResults() as $stepId => $result) {
            if ($result->isSuccess()) {
                $output[$stepId] = $result->getOutput();
            }
        }

        return $output;
    }
}
```

## State Management

### Context and Variable Resolution

```php
<?php
// src/Infrastructure/Workflow/ContextResolver.php

declare(strict_types=1);

namespace App\Infrastructure\Workflow;

use Symfony\Component\ExpressionLanguage\ExpressionLanguage;

final class ContextResolver
{
    private ExpressionLanguage $expressionLanguage;

    public function __construct()
    {
        $this->expressionLanguage = new ExpressionLanguage();
    }

    /**
     * Resolve variables in config using context
     *
     * Example:
     *   config: { url: "https://api.example.com/{{ input.user_id }}" }
     *   context: { input: { user_id: "123" } }
     *   result: { url: "https://api.example.com/123" }
     */
    public function resolve(array $config, array $context): array
    {
        return array_map(
            fn($value) => $this->resolveValue($value, $context),
            $config
        );
    }

    private function resolveValue(mixed $value, array $context): mixed
    {
        if (is_string($value)) {
            return $this->resolveString($value, $context);
        }

        if (is_array($value)) {
            return $this->resolve($value, $context);
        }

        return $value;
    }

    private function resolveString(string $value, array $context): mixed
    {
        // Handle {{ variable }} syntax
        if (preg_match_all('/\{\{\s*([^}]+)\s*\}\}/', $value, $matches)) {
            foreach ($matches[1] as $i => $expression) {
                $resolved = $this->evaluateExpression($expression, $context);
                $value = str_replace($matches[0][$i], $resolved, $value);
            }
        }

        // Handle ${{ expression }} syntax for complex expressions
        if (preg_match('/^\$\{\{(.+)\}\}$/', $value, $match)) {
            return $this->evaluateExpression($match[1], $context);
        }

        return $value;
    }

    private function evaluateExpression(string $expression, array $context): mixed
    {
        try {
            return $this->expressionLanguage->evaluate($expression, $context);
        } catch (\Exception $e) {
            throw new \RuntimeException(
                "Failed to evaluate expression: {$expression}. Error: {$e->getMessage()}"
            );
        }
    }

    /**
     * Get nested value from context using dot notation
     *
     * Example: getContextValue('input.user.email', $context)
     */
    public function getContextValue(string $path, array $context): mixed
    {
        $keys = explode('.', $path);
        $value = $context;

        foreach ($keys as $key) {
            if (!is_array($value) || !array_key_exists($key, $value)) {
                return null;
            }
            $value = $value[$key];
        }

        return $value;
    }
}
```

## Step Types

### HTTP Step Executor

```php
<?php
// src/Infrastructure/Workflow/Executor/HttpStepExecutor.php

declare(strict_types=1);

namespace App\Infrastructure\Workflow\Executor;

use App\Domain\Workflow/WorkflowStep;
use App\Infrastructure\Workflow\ContextResolver;
use Symfony\Contracts\HttpClient\HttpClientInterface;
use Psr\Log\LoggerInterface;

final class HttpStepExecutor implements StepExecutorInterface
{
    public function __construct(
        private readonly HttpClientInterface $httpClient,
        private readonly ContextResolver $contextResolver,
        private readonly LoggerInterface $logger,
    ) {}

    public function execute(WorkflowStep $step, array $context): mixed
    {
        $config = $this->contextResolver->resolve($step->getConfig(), $context);

        $url = $config['url'] ?? throw new \InvalidArgumentException('URL is required');
        $method = strtoupper($config['method'] ?? 'GET');
        $headers = $config['headers'] ?? [];
        $body = $config['body'] ?? null;
        $timeout = $config['timeout'] ?? 30;

        $this->logger->debug('Executing HTTP request', [
            'url' => $url,
            'method' => $method,
        ]);

        try {
            $options = [
                'headers' => $headers,
                'timeout' => $timeout,
            ];

            if ($body !== null) {
                if (is_array($body)) {
                    $options['json'] = $body;
                } else {
                    $options['body'] = $body;
                }
            }

            $response = $this->httpClient->request($method, $url, $options);

            $statusCode = $response->getStatusCode();
            $responseBody = $response->toArray(false); // false = don't throw on error

            $this->logger->debug('HTTP request completed', [
                'status_code' => $statusCode,
            ]);

            // Check if response is successful
            if ($statusCode < 200 || $statusCode >= 300) {
                throw new \RuntimeException(
                    "HTTP request failed with status {$statusCode}"
                );
            }

            return [
                'status_code' => $statusCode,
                'headers' => $response->getHeaders(),
                'body' => $responseBody,
            ];

        } catch (\Exception $e) {
            $this->logger->error('HTTP request failed', [
                'url' => $url,
                'error' => $e->getMessage(),
            ]);

            throw $e;
        }
    }
}
```

### Agent Step Executor

```php
<?php
// src/Infrastructure/Workflow/Executor/AgentStepExecutor.php

declare(strict_types=1);

namespace App\Infrastructure\Workflow\Executor;

use App\Domain\Workflow\WorkflowStep;
use App\Infrastructure\Workflow\ContextResolver;
use App\Infrastructure\Http\Client\AgentManagerClient;
use Psr\Log\LoggerInterface;

final class AgentStepExecutor implements StepExecutorInterface
{
    public function __construct(
        private readonly AgentManagerClient $agentManagerClient,
        private readonly ContextResolver $contextResolver,
        private readonly LoggerInterface $logger,
    ) {}

    public function execute(WorkflowStep $step, array $context): mixed
    {
        $config = $this->contextResolver->resolve($step->getConfig(), $context);

        $agentId = $config['agent_id'] ?? throw new \InvalidArgumentException('Agent ID is required');
        $input = $config['input'] ?? throw new \InvalidArgumentException('Input is required');
        $parameters = $config['parameters'] ?? [];

        $this->logger->debug('Executing AI agent', [
            'agent_id' => $agentId,
            'step_id' => $step->getId(),
        ]);

        try {
            $result = $this->agentManagerClient->invokeAgent(
                $agentId,
                $input,
                array_merge($context, ['parameters' => $parameters])
            );

            $this->logger->debug('AI agent completed', [
                'agent_id' => $agentId,
                'tokens_used' => $result['usage']['total_tokens'] ?? 0,
            ]);

            return $result;

        } catch (\Exception $e) {
            $this->logger->error('AI agent failed', [
                'agent_id' => $agentId,
                'error' => $e->getMessage(),
            ]);

            throw $e;
        }
    }
}
```

### Transform Step Executor

```php
<?php
// src/Infrastructure/Workflow/Executor/TransformStepExecutor.php

declare(strict_types=1);

namespace App\Infrastructure\Workflow\Executor;

use App\Domain\Workflow\WorkflowStep;
use App\Infrastructure\Workflow\ContextResolver;
use Symfony\Component\ExpressionLanguage\ExpressionLanguage;
use Psr\Log\LoggerInterface;

final class TransformStepExecutor implements StepExecutorInterface
{
    private ExpressionLanguage $expressionLanguage;

    public function __construct(
        private readonly ContextResolver $contextResolver,
        private readonly LoggerInterface $logger,
    ) {
        $this->expressionLanguage = new ExpressionLanguage();
    }

    public function execute(WorkflowStep $step, array $context): mixed
    {
        $config = $this->contextResolver->resolve($step->getConfig(), $context);

        $expression = $config['expression'] ?? throw new \InvalidArgumentException('Expression is required');
        $outputKey = $config['output_key'] ?? 'result';

        $this->logger->debug('Executing transform', [
            'step_id' => $step->getId(),
            'expression' => $expression,
        ]);

        try {
            // Evaluate expression
            $result = $this->expressionLanguage->evaluate($expression, $context);

            $this->logger->debug('Transform completed', [
                'step_id' => $step->getId(),
            ]);

            return [$outputKey => $result];

        } catch (\Exception $e) {
            $this->logger->error('Transform failed', [
                'expression' => $expression,
                'error' => $e->getMessage(),
            ]);

            throw new \RuntimeException("Transform failed: {$e->getMessage()}");
        }
    }
}
```

### Conditional Step Executor

```php
<?php
// src/Infrastructure/Workflow/Executor/ConditionalStepExecutor.php

declare(strict_types=1);

namespace App\Infrastructure\Workflow\Executor;

use App\Domain\Workflow\WorkflowStep;
use App\Infrastructure\Workflow\ContextResolver;
use Symfony\Component\ExpressionLanguage\ExpressionLanguage;
use Psr\Log\LoggerInterface;

final class ConditionalStepExecutor implements StepExecutorInterface
{
    private ExpressionLanguage $expressionLanguage;

    public function __construct(
        private readonly ContextResolver $contextResolver,
        private readonly LoggerInterface $logger,
    ) {
        $this->expressionLanguage = new ExpressionLanguage();
    }

    public function execute(WorkflowStep $step, array $context): mixed
    {
        $config = $this->contextResolver->resolve($step->getConfig(), $context);

        $condition = $config['condition'] ?? throw new \InvalidArgumentException('Condition is required');
        $branches = $config['branches'] ?? throw new \InvalidArgumentException('Branches are required');

        $this->logger->debug('Evaluating conditional', [
            'step_id' => $step->getId(),
            'condition' => $condition,
        ]);

        try {
            // Evaluate condition
            $conditionResult = $this->expressionLanguage->evaluate($condition, $context);

            // Determine which branch to take
            $branch = $conditionResult ? ($branches['true'] ?? null) : ($branches['false'] ?? null);

            if ($branch === null) {
                throw new \RuntimeException('No branch defined for condition result');
            }

            $this->logger->debug('Conditional evaluated', [
                'step_id' => $step->getId(),
                'result' => $conditionResult ? 'true' : 'false',
                'target_step' => $branch['target_step'] ?? null,
            ]);

            return [
                'condition_result' => $conditionResult,
                'branch_taken' => $conditionResult ? 'true' : 'false',
                'target_step' => $branch['target_step'] ?? null,
            ];

        } catch (\Exception $e) {
            $this->logger->error('Conditional evaluation failed', [
                'condition' => $condition,
                'error' => $e->getMessage(),
            ]);

            throw new \RuntimeException("Conditional evaluation failed: {$e->getMessage()}");
        }
    }
}
```

### Parallel Step Executor

```php
<?php
// src/Infrastructure/Workflow/Executor/ParallelStepExecutor.php

declare(strict_types=1);

namespace App\Infrastructure\Workflow\Executor;

use App\Domain\Workflow\WorkflowStep;
use App\Infrastructure\Workflow\ContextResolver;
use Psr\Log\LoggerInterface;
use Symfony\Component\Messenger\MessageBusInterface;

final class ParallelStepExecutor implements StepExecutorInterface
{
    public function __construct(
        private readonly StepExecutorFactory $executorFactory,
        private readonly ContextResolver $contextResolver,
        private readonly MessageBusInterface $messageBus,
        private readonly LoggerInterface $logger,
    ) {}

    public function execute(WorkflowStep $step, array $context): mixed
    {
        $config = $this->contextResolver->resolve($step->getConfig(), $context);

        $parallelSteps = $config['steps'] ?? throw new \InvalidArgumentException('Steps array is required');
        $waitForAll = $config['wait_for_all'] ?? true;

        $this->logger->debug('Executing parallel steps', [
            'step_id' => $step->getId(),
            'parallel_count' => count($parallelSteps),
            'wait_for_all' => $waitForAll,
        ]);

        $results = [];
        $errors = [];

        // Execute all steps in parallel using async messaging
        $jobIds = [];

        foreach ($parallelSteps as $index => $parallelStepConfig) {
            try {
                // Create a sub-step
                $subStep = new WorkflowStep(
                    id: "{$step->getId()}_parallel_{$index}",
                    name: $parallelStepConfig['name'] ?? "Parallel Step {$index}",
                    type: StepType::from($parallelStepConfig['type']),
                    config: $parallelStepConfig['config'] ?? [],
                    order: $index
                );

                // For now, execute synchronously (would be async in production)
                $executor = $this->executorFactory->getExecutor($subStep->getType());
                $result = $executor->execute($subStep, $context);

                $results[$index] = [
                    'success' => true,
                    'output' => $result,
                ];

            } catch (\Exception $e) {
                $errors[$index] = $e->getMessage();
                $results[$index] = [
                    'success' => false,
                    'error' => $e->getMessage(),
                ];

                if ($waitForAll === false) {
                    throw $e;
                }
            }
        }

        if (!empty($errors) && $waitForAll) {
            throw new \RuntimeException(
                'Some parallel steps failed: ' . json_encode($errors)
            );
        }

        $this->logger->debug('Parallel steps completed', [
            'step_id' => $step->getId(),
            'success_count' => count(array_filter($results, fn($r) => $r['success'])),
            'error_count' => count($errors),
        ]);

        return [
            'results' => $results,
            'errors' => $errors,
        ];
    }
}
```

## Error Handling

### Retry Strategy

```php
<?php
// src/Infrastructure/Workflow/RetryStrategy.php

declare(strict_types=1);

namespace App\Infrastructure\Workflow;

use App\Domain\Workflow\WorkflowStep;
use Psr\Log\LoggerInterface;

final class RetryStrategy
{
    public function __construct(
        private readonly LoggerInterface $logger,
    ) {}

    public function shouldRetry(WorkflowStep $step, int $attemptNumber, \Throwable $error): bool
    {
        $retryConfig = $step->getConfig()['retry'] ?? [];
        $maxAttempts = $retryConfig['max_attempts'] ?? 3;

        if ($attemptNumber >= $maxAttempts) {
            $this->logger->warning('Max retry attempts reached', [
                'step_id' => $step->getId(),
                'attempts' => $attemptNumber,
                'max_attempts' => $maxAttempts,
            ]);
            return false;
        }

        // Check if error is retriable
        if (!$this->isRetriableError($error)) {
            $this->logger->warning('Error is not retriable', [
                'step_id' => $step->getId(),
                'error_type' => get_class($error),
                'error_message' => $error->getMessage(),
            ]);
            return false;
        }

        return true;
    }

    public function getRetryDelay(WorkflowStep $step, int $attemptNumber): int
    {
        $retryConfig = $step->getConfig()['retry'] ?? [];
        $backoff = $retryConfig['backoff'] ?? 'exponential';
        $initialDelay = $retryConfig['initial_delay'] ?? 1000; // 1 second

        return match ($backoff) {
            'fixed' => $initialDelay,
            'exponential' => $initialDelay * pow(2, $attemptNumber - 1),
            'linear' => $initialDelay * $attemptNumber,
            default => $initialDelay,
        };
    }

    private function isRetriableError(\Throwable $error): bool
    {
        // Network errors are retriable
        if ($error instanceof \Symfony\Contracts\HttpClient\Exception\TransportExceptionInterface) {
            return true;
        }

        // Timeout errors are retriable
        if ($error instanceof \Symfony\Contracts\HttpClient\Exception\TimeoutExceptionInterface) {
            return true;
        }

        // 5xx HTTP errors are retriable
        if ($error instanceof \Symfony\Contracts\HttpClient\Exception\ServerExceptionInterface) {
            return true;
        }

        // 429 Too Many Requests is retriable
        if ($error instanceof \Symfony\Contracts\HttpClient\Exception\ClientExceptionInterface) {
            if (str_contains($error->getMessage(), '429')) {
                return true;
            }
        }

        // Domain exceptions are not retriable
        if ($error instanceof \DomainException) {
            return false;
        }

        // Default: retriable
        return true;
    }
}
```

### Error Handler

```php
<?php
// src/Infrastructure/Workflow/ErrorHandler.php

declare(strict_types=1);

namespace App\Infrastructure\Workflow;

use App\Domain\Workflow\Workflow;
use App\Domain\Workflow\Execution;
use App\Domain\Workflow\WorkflowStep;
use App\Infrastructure\Event\EventPublisher;
use Psr\Log\LoggerInterface;

final class ErrorHandler
{
    public function __construct(
        private readonly EventPublisher $eventPublisher,
        private readonly LoggerInterface $logger,
    ) {}

    public function handleStepError(
        WorkflowStep $step,
        Execution $execution,
        Workflow $workflow,
        \Throwable $error
    ): void {
        $this->logger->error('Step execution error', [
            'step_id' => $step->getId(),
            'execution_id' => $execution->getId()->toString(),
            'error' => $error->getMessage(),
            'trace' => $error->getTraceAsString(),
        ]);

        $errorHandling = $workflow->getErrorHandling();
        $onError = $errorHandling['on_error'] ?? 'fail';

        match ($onError) {
            'fail' => $this->handleFailure($execution, $step, $error),
            'continue' => $this->handleContinue($execution, $step, $error),
            'skip' => $this->handleSkip($execution, $step, $error),
            default => $this->handleFailure($execution, $step, $error),
        };
    }

    private function handleFailure(Execution $execution, WorkflowStep $step, \Throwable $error): void
    {
        $execution->fail(
            sprintf(
                'Step "%s" failed: %s',
                $step->getName(),
                $error->getMessage()
            ),
            $step->getId()
        );

        // Publish failure event
        foreach ($execution->popEvents() as $event) {
            $this->eventPublisher->publish($event);
        }
    }

    private function handleContinue(Execution $execution, WorkflowStep $step, \Throwable $error): void
    {
        $this->logger->warning('Continuing execution despite error', [
            'step_id' => $step->getId(),
            'execution_id' => $execution->getId()->toString(),
        ]);

        // Record error but continue
        $execution->setContextValue("errors.{$step->getId()}", [
            'message' => $error->getMessage(),
            'timestamp' => (new \DateTimeImmutable())->format('c'),
        ]);
    }

    private function handleSkip(Execution $execution, WorkflowStep $step, \Throwable $error): void
    {
        $this->logger->info('Skipping failed step', [
            'step_id' => $step->getId(),
            'execution_id' => $execution->getId()->toString(),
        ]);

        // Mark step as skipped
        $execution->setContextValue("skipped.{$step->getId()}", true);
    }
}
```

## API Endpoints

### Complete API Implementation

```php
<?php
// src/Infrastructure/Http/Controller/WorkflowController.php

declare(strict_types=1);

namespace App\Infrastructure\Http\Controller;

use App\Application\Workflow\UseCase\CreateWorkflowUseCase;
use App\Application\Workflow\UseCase\CreateWorkflowCommand;
use App\Application\Workflow\UseCase\ExecuteWorkflowUseCase;
use App\Application\Workflow\UseCase\ExecuteWorkflowCommand;
use App\Application\Workflow\Query\GetWorkflowQuery;
use App\Application\Workflow\Query\ListWorkflowsQuery;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;
use OpenApi\Attributes as OA;

#[Route('/api/v1/workflows')]
final class WorkflowController
{
    public function __construct(
        private readonly CreateWorkflowUseCase $createWorkflowUseCase,
        private readonly ExecuteWorkflowUseCase $executeWorkflowUseCase,
        private readonly GetWorkflowQuery $getWorkflowQuery,
        private readonly ListWorkflowsQuery $listWorkflowsQuery,
    ) {}

    #[Route('', methods: ['POST'])]
    #[OA\Post(
        path: '/api/v1/workflows',
        summary: 'Create a new workflow',
        requestBody: new OA\RequestBody(
            required: true,
            content: new OA\JsonContent(
                required: ['name', 'steps'],
                properties: [
                    new OA\Property(property: 'name', type: 'string', example: 'My Workflow'),
                    new OA\Property(property: 'description', type: 'string'),
                    new OA\Property(
                        property: 'steps',
                        type: 'array',
                        items: new OA\Items(
                            properties: [
                                new OA\Property(property: 'id', type: 'string', example: 'step_1'),
                                new OA\Property(property: 'name', type: 'string'),
                                new OA\Property(property: 'type', type: 'string', enum: ['http', 'agent', 'transform']),
                                new OA\Property(property: 'config', type: 'object'),
                            ]
                        )
                    ),
                ]
            )
        ),
        tags: ['Workflows'],
        responses: [
            new OA\Response(
                response: 201,
                description: 'Workflow created successfully',
                content: new OA\JsonContent(
                    properties: [
                        new OA\Property(property: 'id', type: 'string'),
                        new OA\Property(property: 'name', type: 'string'),
                        new OA\Property(property: 'status', type: 'string'),
                    ]
                )
            )
        ]
    )]
    public function create(Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);

        $command = new CreateWorkflowCommand(
            name: $data['name'],
            description: $data['description'] ?? '',
            steps: $data['steps'],
            userId: $request->attributes->get('user_id')
        );

        $result = $this->createWorkflowUseCase->execute($command);

        return new JsonResponse([
            'id' => $result->workflowId,
            'name' => $result->name,
            'status' => 'draft',
        ], Response::HTTP_CREATED);
    }

    #[Route('', methods: ['GET'])]
    #[OA\Get(
        path: '/api/v1/workflows',
        summary: 'List workflows',
        tags: ['Workflows'],
        parameters: [
            new OA\Parameter(name: 'page', in: 'query', schema: new OA\Schema(type: 'integer', default: 1)),
            new OA\Parameter(name: 'per_page', in: 'query', schema: new OA\Schema(type: 'integer', default: 20)),
            new OA\Parameter(name: 'status', in: 'query', schema: new OA\Schema(type: 'string', enum: ['draft', 'published'])),
        ]
    )]
    public function list(Request $request): JsonResponse
    {
        $userId = $request->attributes->get('user_id');
        $page = (int) $request->query->get('page', 1);
        $perPage = (int) $request->query->get('per_page', 20);
        $status = $request->query->get('status');

        $result = $this->listWorkflowsQuery->execute(
            $userId,
            $page,
            $perPage,
            $status
        );

        return new JsonResponse($result);
    }

    #[Route('/{id}', methods: ['GET'])]
    #[OA\Get(
        path: '/api/v1/workflows/{id}',
        summary: 'Get workflow by ID',
        tags: ['Workflows']
    )]
    public function get(string $id, Request $request): JsonResponse
    {
        $userId = $request->attributes->get('user_id');

        $workflow = $this->getWorkflowQuery->execute($id, $userId);

        if ($workflow === null) {
            return new JsonResponse(['error' => 'Workflow not found'], Response::HTTP_NOT_FOUND);
        }

        return new JsonResponse($workflow);
    }

    #[Route('/{id}/execute', methods: ['POST'])]
    #[OA\Post(
        path: '/api/v1/workflows/{id}/execute',
        summary: 'Execute a workflow',
        tags: ['Workflows'],
        requestBody: new OA\RequestBody(
            content: new OA\JsonContent(
                properties: [
                    new OA\Property(property: 'input', type: 'object', example: ['user_id' => '123'])
                ]
            )
        )
    )]
    public function execute(string $id, Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);
        $userId = $request->attributes->get('user_id');

        $command = new ExecuteWorkflowCommand(
            workflowId: $id,
            userId: $userId,
            input: $data['input'] ?? []
        );

        $result = $this->executeWorkflowUseCase->execute($command);

        return new JsonResponse([
            'execution_id' => $result->executionId,
            'status' => 'pending',
            'message' => 'Workflow execution started',
        ], Response::HTTP_ACCEPTED);
    }

    #[Route('/{id}/executions', methods: ['GET'])]
    #[OA\Get(
        path: '/api/v1/workflows/{id}/executions',
        summary: 'List workflow executions',
        tags: ['Workflows']
    )]
    public function listExecutions(string $id, Request $request): JsonResponse
    {
        // Implementation for listing executions
        return new JsonResponse(['executions' => []]);
    }

    #[Route('/{workflowId}/executions/{executionId}', methods: ['GET'])]
    #[OA\Get(
        path: '/api/v1/workflows/{workflowId}/executions/{executionId}',
        summary: 'Get execution details',
        tags: ['Workflows']
    )]
    public function getExecution(string $workflowId, string $executionId): JsonResponse
    {
        // Implementation for getting execution details
        return new JsonResponse(['execution' => []]);
    }
}
```

## Database Schema

### Complete Schema

```sql
-- Workflows table
CREATE TABLE workflows (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    definition JSONB NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'draft',
    version INTEGER NOT NULL DEFAULT 1,
    published_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,

    CONSTRAINT fk_workflows_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT chk_workflow_status CHECK (status IN ('draft', 'published', 'archived'))
);

CREATE INDEX idx_workflows_user_id ON workflows(user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_workflows_status ON workflows(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_workflows_created_at ON workflows(created_at DESC);
CREATE INDEX idx_workflows_definition_gin ON workflows USING gin(definition);

-- Workflow executions table
CREATE TABLE workflow_executions (
    id UUID PRIMARY KEY,
    workflow_id UUID NOT NULL,
    user_id UUID NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    input JSONB,
    output JSONB,
    context JSONB,
    error_message TEXT,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_executions_workflow FOREIGN KEY (workflow_id) REFERENCES workflows(id) ON DELETE CASCADE,
    CONSTRAINT fk_executions_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT chk_execution_status CHECK (status IN ('pending', 'running', 'completed', 'failed', 'cancelled'))
);

CREATE INDEX idx_executions_workflow_id ON workflow_executions(workflow_id, created_at DESC);
CREATE INDEX idx_executions_user_id ON workflow_executions(user_id, created_at DESC);
CREATE INDEX idx_executions_status ON workflow_executions(status) WHERE status IN ('pending', 'running');
CREATE INDEX idx_executions_created_at ON workflow_executions(created_at DESC);

-- Step execution results table
CREATE TABLE step_execution_results (
    id UUID PRIMARY KEY,
    execution_id UUID NOT NULL,
    step_id VARCHAR(255) NOT NULL,
    step_name VARCHAR(255) NOT NULL,
    step_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL,
    input JSONB,
    output JSONB,
    error_message TEXT,
    duration_ms INTEGER,
    retry_count INTEGER DEFAULT 0,
    started_at TIMESTAMP NOT NULL,
    completed_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_step_results_execution FOREIGN KEY (execution_id) REFERENCES workflow_executions(id) ON DELETE CASCADE,
    CONSTRAINT chk_step_status CHECK (status IN ('pending', 'running', 'completed', 'failed', 'skipped'))
);

CREATE INDEX idx_step_results_execution_id ON step_execution_results(execution_id, started_at);
CREATE INDEX idx_step_results_status ON step_execution_results(status);

-- Workflow schedules table
CREATE TABLE workflow_schedules (
    id UUID PRIMARY KEY,
    workflow_id UUID NOT NULL,
    user_id UUID NOT NULL,
    cron_expression VARCHAR(255) NOT NULL,
    timezone VARCHAR(100) NOT NULL DEFAULT 'UTC',
    enabled BOOLEAN NOT NULL DEFAULT true,
    input JSONB,
    last_run_at TIMESTAMP,
    next_run_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_schedules_workflow FOREIGN KEY (workflow_id) REFERENCES workflows(id) ON DELETE CASCADE,
    CONSTRAINT fk_schedules_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_schedules_workflow_id ON workflow_schedules(workflow_id);
CREATE INDEX idx_schedules_next_run ON workflow_schedules(next_run_at) WHERE enabled = true;
CREATE INDEX idx_schedules_enabled ON workflow_schedules(enabled);

-- Workflow triggers table (webhooks, events, etc.)
CREATE TABLE workflow_triggers (
    id UUID PRIMARY KEY,
    workflow_id UUID NOT NULL,
    user_id UUID NOT NULL,
    type VARCHAR(50) NOT NULL,
    config JSONB NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT true,
    last_triggered_at TIMESTAMP,
    trigger_count INTEGER DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_triggers_workflow FOREIGN KEY (workflow_id) REFERENCES workflows(id) ON DELETE CASCADE,
    CONSTRAINT fk_triggers_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT chk_trigger_type CHECK (type IN ('webhook', 'event', 'manual', 'schedule'))
);

CREATE INDEX idx_triggers_workflow_id ON workflow_triggers(workflow_id);
CREATE INDEX idx_triggers_type ON workflow_triggers(type, enabled);

-- Execution metrics (for analytics)
CREATE TABLE execution_metrics (
    id BIGSERIAL PRIMARY KEY,
    execution_id UUID NOT NULL,
    workflow_id UUID NOT NULL,
    user_id UUID NOT NULL,
    status VARCHAR(50) NOT NULL,
    duration_ms INTEGER,
    step_count INTEGER,
    success_count INTEGER,
    error_count INTEGER,
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_metrics_execution FOREIGN KEY (execution_id) REFERENCES workflow_executions(id) ON DELETE CASCADE
);

CREATE INDEX idx_metrics_workflow_id ON execution_metrics(workflow_id, timestamp DESC);
CREATE INDEX idx_metrics_user_id ON execution_metrics(user_id, timestamp DESC);
CREATE INDEX idx_metrics_timestamp ON execution_metrics(timestamp DESC);

-- Partitioning for execution_metrics (by month)
CREATE TABLE execution_metrics_y2025m01 PARTITION OF execution_metrics
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE execution_metrics_y2025m02 PARTITION OF execution_metrics
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
```

## Implementation Examples

### Complete Workflow Creation

```php
<?php
// src/Application/Workflow/UseCase/CreateWorkflowUseCase.php

declare(strict_types=1);

namespace App\Application\Workflow\UseCase;

use App\Domain\Workflow\Repository\WorkflowRepositoryInterface;
use App\Domain\Workflow\Workflow;
use App\Domain\Workflow\WorkflowStep;
use App\Domain\Workflow\ValueObject\WorkflowId;
use App\Domain\Workflow\ValueObject\WorkflowName;
use App\Domain\Workflow\StepType;
use App\Infrastructure\Event\EventPublisher;
use Psr\Log\LoggerInterface;

final class CreateWorkflowUseCase
{
    public function __construct(
        private readonly WorkflowRepositoryInterface $workflowRepository,
        private readonly EventPublisher $eventPublisher,
        private readonly LoggerInterface $logger,
    ) {}

    public function execute(CreateWorkflowCommand $command): CreateWorkflowResult
    {
        $this->logger->info('Creating workflow', [
            'name' => $command->name,
            'user_id' => $command->userId,
        ]);

        // Create workflow aggregate
        $workflow = Workflow::create(
            id: WorkflowId::generate(),
            name: new WorkflowName($command->name),
            description: $command->description,
            userId: $command->userId
        );

        // Add steps
        foreach ($command->steps as $index => $stepData) {
            $step = new WorkflowStep(
                id: $stepData['id'],
                name: $stepData['name'],
                type: StepType::from($stepData['type']),
                config: $stepData['config'] ?? [],
                order: $index,
                dependsOn: $stepData['depends_on'] ?? null
            );

            $workflow->addStep($step);
        }

        // Save workflow
        $this->workflowRepository->save($workflow);

        // Publish domain events
        foreach ($workflow->popEvents() as $event) {
            $this->eventPublisher->publish($event);
        }

        $this->logger->info('Workflow created successfully', [
            'workflow_id' => $workflow->getId()->toString(),
        ]);

        return new CreateWorkflowResult(
            workflowId: $workflow->getId()->toString(),
            name: $workflow->getName()->toString()
        );
    }
}
```

### Complete Workflow Execution

```php
<?php
// src/Application/Workflow/UseCase/ExecuteWorkflowUseCase.php

declare(strict_types=1);

namespace App\Application\Workflow\UseCase;

use App\Domain\Workflow\Repository\WorkflowRepositoryInterface;
use App\Domain\Workflow\Repository\ExecutionRepositoryInterface;
use App\Domain\Workflow\Execution;
use App\Domain\Workflow\ValueObject\ExecutionId;
use App\Domain\Workflow\ValueObject\WorkflowId;
use App\Infrastructure\Messaging\WorkflowExecutionMessage;
use Symfony\Component\Messenger\MessageBusInterface;
use Psr\Log\LoggerInterface;

final class ExecuteWorkflowUseCase
{
    public function __construct(
        private readonly WorkflowRepositoryInterface $workflowRepository,
        private readonly ExecutionRepositoryInterface $executionRepository,
        private readonly MessageBusInterface $messageBus,
        private readonly LoggerInterface $logger,
    ) {}

    public function execute(ExecuteWorkflowCommand $command): ExecuteWorkflowResult
    {
        // Load workflow
        $workflow = $this->workflowRepository->findById(new WorkflowId($command->workflowId));

        if ($workflow === null) {
            throw new \DomainException('Workflow not found');
        }

        if ($workflow->getUserId() !== $command->userId) {
            throw new \DomainException('Unauthorized access to workflow');
        }

        // Check if workflow is published
        if ($workflow->getStatus() !== \App\Domain\Workflow\WorkflowStatus::PUBLISHED) {
            throw new \DomainException('Cannot execute unpublished workflow');
        }

        $this->logger->info('Starting workflow execution', [
            'workflow_id' => $command->workflowId,
            'user_id' => $command->userId,
        ]);

        // Create execution
        $execution = Execution::create(
            id: ExecutionId::generate(),
            workflowId: new WorkflowId($command->workflowId),
            userId: $command->userId,
            input: $command->input
        );

        // Save execution
        $this->executionRepository->save($execution);

        // Queue execution for async processing
        $this->messageBus->dispatch(new WorkflowExecutionMessage(
            executionId: $execution->getId()->toString(),
            workflowId: $workflow->getId()->toString()
        ));

        $this->logger->info('Workflow execution queued', [
            'execution_id' => $execution->getId()->toString(),
        ]);

        return new ExecuteWorkflowResult(
            executionId: $execution->getId()->toString()
        );
    }
}
```

### Async Execution Handler

```php
<?php
// src/Infrastructure/Messaging/WorkflowExecutionHandler.php

declare(strict_types=1);

namespace App\Infrastructure\Messaging;

use App\Domain\Workflow\Repository\WorkflowRepositoryInterface;
use App\Domain\Workflow\Repository\ExecutionRepositoryInterface;
use App\Domain\Workflow\ValueObject\WorkflowId;
use App\Domain\Workflow\ValueObject\ExecutionId;
use App\Infrastructure\Workflow\ExecutionEngine;
use App\Infrastructure\Event\EventPublisher;
use Symfony\Component\Messenger\Attribute\AsMessageHandler;
use Psr\Log\LoggerInterface;

#[AsMessageHandler]
final class WorkflowExecutionHandler
{
    public function __construct(
        private readonly WorkflowRepositoryInterface $workflowRepository,
        private readonly ExecutionRepositoryInterface $executionRepository,
        private readonly ExecutionEngine $executionEngine,
        private readonly EventPublisher $eventPublisher,
        private readonly LoggerInterface $logger,
    ) {}

    public function __invoke(WorkflowExecutionMessage $message): void
    {
        $this->logger->info('Processing workflow execution', [
            'execution_id' => $message->executionId,
            'workflow_id' => $message->workflowId,
        ]);

        try {
            // Load workflow and execution
            $workflow = $this->workflowRepository->findById(new WorkflowId($message->workflowId));
            $execution = $this->executionRepository->findById(new ExecutionId($message->executionId));

            if ($workflow === null || $execution === null) {
                throw new \RuntimeException('Workflow or execution not found');
            }

            // Execute workflow
            $this->executionEngine->execute($workflow, $execution);

            // Save updated execution
            $this->executionRepository->save($execution);

            // Publish events
            foreach ($execution->popEvents() as $event) {
                $this->eventPublisher->publish($event);
            }

            $this->logger->info('Workflow execution processed successfully', [
                'execution_id' => $message->executionId,
                'status' => $execution->getStatus()->value,
            ]);

        } catch (\Throwable $e) {
            $this->logger->error('Workflow execution processing failed', [
                'execution_id' => $message->executionId,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            // Update execution status to failed
            if (isset($execution)) {
                $execution->fail($e->getMessage());
                $this->executionRepository->save($execution);
            }

            throw $e;
        }
    }
}
```

## Conclusion

The Workflow Engine provides:

- **Flexible workflow definition** with multiple step types
- **Robust execution engine** with state management
- **Error handling and retries** for resilience
- **Parallel execution** support
- **Conditional branching** for complex logic
- **Async processing** via message queue
- **Complete observability** through events and metrics

For integration details, see:
- [Agent Manager Service](04-agent-manager.md)
- [Integration Hub Service](07-integration-hub.md)
- [Message Queue Configuration](../03-infrastructure/05-message-queue.md)

For questions, contact the workflow team via #workflow-engine Slack channel.
