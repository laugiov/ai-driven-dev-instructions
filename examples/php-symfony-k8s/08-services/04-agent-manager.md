# Agent Manager Service

## Prerequisites for Implementation

**Before implementing this service, ensure you have read and understood**:

✅ **Foundation Knowledge** (REQUIRED):
1. [README.md](../README.md) - Overall system architecture
2. [01-architecture/01-architecture-overview.md](../01-architecture/01-architecture-overview.md) - System purpose, LLM integration justification
3. [01-architecture/03-hexagonal-architecture.md](../01-architecture/03-hexagonal-architecture.md) - Provider abstraction with adapters
4. [01-architecture/04-domain-driven-design.md](../01-architecture/04-domain-driven-design.md) - Agent as aggregate, Execution as entity
5. [04-development/02-coding-guidelines-php.md](../04-development/02-coding-guidelines-php.md) - PHP 8.3, PHPStan Level 9

✅ **Security & Performance** (REQUIRED):
1. [02-security/04-secrets-management.md](../02-security/04-secrets-management.md) - Vault for LLM API keys
2. [02-security/06-data-protection.md](../02-security/06-data-protection.md) - PII handling in prompts, anonymization
3. [04-development/08-performance-optimization.md](../04-development/08-performance-optimization.md) - Caching LLM responses, connection pooling

✅ **Testing** (REQUIRED):
1. [04-development/04-testing-strategy.md](../04-development/04-testing-strategy.md) - Mock LLM providers for testing

**Estimated Reading Time**: 3-4 hours
**Implementation Time**: 5-7 days (following [IMPLEMENTATION_ROADMAP.md](../IMPLEMENTATION_ROADMAP.md) Phase 3, Week 7)
**Complexity**: MEDIUM-HIGH

---

## Table of Contents

1. [Overview](#overview)
2. [Service Architecture](#service-architecture)
3. [Core Components](#core-components)
4. [AI Model Integration](#ai-model-integration)
5. [Agent Lifecycle Management](#agent-lifecycle-management)
6. [Prompt Template System](#prompt-template-system)
7. [Token Usage Tracking](#token-usage-tracking)
8. [Model Fallback Strategy](#model-fallback-strategy)
9. [Context Management](#context-management)
10. [Error Handling](#error-handling)
11. [API Endpoints](#api-endpoints)
12. [Database Schema](#database-schema)
13. [Implementation Examples](#implementation-examples)
14. [Performance Optimization](#performance-optimization)
15. [Security Considerations](#security-considerations)

## Overview

The Agent Manager Service is responsible for managing AI agents throughout their lifecycle, from creation to execution and monitoring. It provides a unified interface for interacting with multiple AI model providers (OpenAI, Anthropic, Google AI, Azure OpenAI) and handles prompt templating, token tracking, model fallback strategies, and conversation context management.

### Key Responsibilities

1. **Agent Lifecycle Management**: Create, configure, execute, and monitor AI agents
2. **Multi-Provider Integration**: Support for OpenAI, Anthropic Claude, Google AI (Gemini), Azure OpenAI
3. **Prompt Template Management**: Dynamic prompt templating with variable substitution and versioning
4. **Token Usage Tracking**: Monitor and limit token consumption across models and users
5. **Model Fallback**: Automatic fallback to alternative models when primary fails
6. **Context Management**: Maintain conversation context with intelligent truncation
7. **Response Validation**: Validate AI responses against schemas and business rules
8. **Cost Management**: Track and control AI costs per user/organization
9. **Performance Monitoring**: Track latency, error rates, and model performance metrics

### Service Characteristics

- **Bounded Context**: AI Agent Management (DDD)
- **Communication**: Synchronous HTTP REST APIs + Async Message Queue
- **Data Storage**: PostgreSQL (agent configs, executions), Redis (context cache, rate limiting)
- **Dependencies**: External AI provider APIs, Workflow Engine, Authentication Service
- **Scaling**: Horizontal scaling with stateless design
- **Availability**: 99.95% SLA with circuit breakers for external APIs

## Service Architecture

### Hexagonal Architecture

The Agent Manager Service follows hexagonal architecture (Ports & Adapters):

```
┌─────────────────────────────────────────────────────────────┐
│                    DOMAIN LAYER                              │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Domain Entities                          │  │
│  │  • Agent (Aggregate Root)                            │  │
│  │  • AgentExecution                                    │  │
│  │  • PromptTemplate                                    │  │
│  │  • ModelConfiguration                                │  │
│  │  • ConversationContext                               │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Value Objects                            │  │
│  │  • AgentId, ExecutionId                              │  │
│  │  • ModelProvider, ModelName                          │  │
│  │  • TokenUsage, CostEstimate                          │  │
│  │  • PromptVariables                                   │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Domain Services                          │  │
│  │  • PromptCompiler                                    │  │
│  │  • ContextManager                                    │  │
│  │  • TokenCalculator                                   │  │
│  │  • CostCalculator                                    │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Repository Interfaces (Ports)            │  │
│  │  • AgentRepositoryInterface                          │  │
│  │  • ExecutionRepositoryInterface                      │  │
│  │  • PromptTemplateRepositoryInterface                 │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │
┌─────────────────────────────────────────────────────────────┐
│                   APPLICATION LAYER                          │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Use Cases (Application Services)         │  │
│  │  • CreateAgentUseCase                                │  │
│  │  • ExecuteAgentUseCase                               │  │
│  │  • ManagePromptTemplateUseCase                       │  │
│  │  • TrackTokenUsageUseCase                            │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Command/Query Handlers (CQRS)            │  │
│  │  • CreateAgentCommandHandler                         │  │
│  │  • ExecuteAgentCommandHandler                        │  │
│  │  • GetAgentExecutionQueryHandler                     │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Event Handlers                           │  │
│  │  • AgentExecutionStartedEventHandler                 │  │
│  │  • AgentExecutionCompletedEventHandler               │  │
│  │  • TokenLimitExceededEventHandler                    │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │
┌─────────────────────────────────────────────────────────────┐
│                  INFRASTRUCTURE LAYER                        │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              HTTP Adapters (Input Ports)              │  │
│  │  • AgentController                                   │  │
│  │  • PromptTemplateController                          │  │
│  │  • ExecutionController                               │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Persistence Adapters (Output Ports)      │  │
│  │  • DoctrineAgentRepository                           │  │
│  │  • DoctrineExecutionRepository                       │  │
│  │  • RedisContextCache                                 │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              AI Provider Adapters (Output Ports)      │  │
│  │  • OpenAIAdapter                                     │  │
│  │  • AnthropicAdapter                                  │  │
│  │  • GoogleAIAdapter                                   │  │
│  │  • AzureOpenAIAdapter                                │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Message Queue Adapters                   │  │
│  │  • RabbitMQAgentEventPublisher                       │  │
│  │  • RabbitMQExecutionEventSubscriber                  │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Directory Structure

```
src/AgentManager/
├── Domain/
│   ├── Entity/
│   │   ├── Agent.php
│   │   ├── AgentExecution.php
│   │   ├── PromptTemplate.php
│   │   ├── ModelConfiguration.php
│   │   └── ConversationContext.php
│   ├── ValueObject/
│   │   ├── AgentId.php
│   │   ├── ExecutionId.php
│   │   ├── ModelProvider.php
│   │   ├── ModelName.php
│   │   ├── TokenUsage.php
│   │   ├── CostEstimate.php
│   │   └── PromptVariables.php
│   ├── Service/
│   │   ├── PromptCompiler.php
│   │   ├── ContextManager.php
│   │   ├── TokenCalculator.php
│   │   └── CostCalculator.php
│   ├── Repository/
│   │   ├── AgentRepositoryInterface.php
│   │   ├── ExecutionRepositoryInterface.php
│   │   └── PromptTemplateRepositoryInterface.php
│   ├── Event/
│   │   ├── AgentCreated.php
│   │   ├── AgentExecutionStarted.php
│   │   ├── AgentExecutionCompleted.php
│   │   ├── AgentExecutionFailed.php
│   │   └── TokenLimitExceeded.php
│   └── Exception/
│       ├── AgentNotFoundException.php
│       ├── ModelProviderException.php
│       ├── TokenLimitExceededException.php
│       └── PromptCompilationException.php
├── Application/
│   ├── UseCase/
│   │   ├── CreateAgentUseCase.php
│   │   ├── ExecuteAgentUseCase.php
│   │   ├── ManagePromptTemplateUseCase.php
│   │   └── TrackTokenUsageUseCase.php
│   ├── Command/
│   │   ├── CreateAgentCommand.php
│   │   ├── ExecuteAgentCommand.php
│   │   └── UpdatePromptTemplateCommand.php
│   ├── Query/
│   │   ├── GetAgentQuery.php
│   │   ├── GetAgentExecutionQuery.php
│   │   └── GetTokenUsageQuery.php
│   ├── Handler/
│   │   ├── CreateAgentCommandHandler.php
│   │   ├── ExecuteAgentCommandHandler.php
│   │   └── GetAgentExecutionQueryHandler.php
│   └── EventHandler/
│       ├── AgentExecutionStartedEventHandler.php
│       ├── AgentExecutionCompletedEventHandler.php
│       └── TokenLimitExceededEventHandler.php
└── Infrastructure/
    ├── Http/
    │   ├── Controller/
    │   │   ├── AgentController.php
    │   │   ├── PromptTemplateController.php
    │   │   └── ExecutionController.php
    │   └── Request/
    │       ├── CreateAgentRequest.php
    │       └── ExecuteAgentRequest.php
    ├── Persistence/
    │   ├── Doctrine/
    │   │   ├── Repository/
    │   │   │   ├── DoctrineAgentRepository.php
    │   │   │   └── DoctrineExecutionRepository.php
    │   │   └── Mapping/
    │   │       ├── Agent.orm.xml
    │   │       └── AgentExecution.orm.xml
    │   └── Redis/
    │       └── RedisContextCache.php
    ├── AIProvider/
    │   ├── Contract/
    │   │   └── AIProviderInterface.php
    │   ├── OpenAIAdapter.php
    │   ├── AnthropicAdapter.php
    │   ├── GoogleAIAdapter.php
    │   ├── AzureOpenAIAdapter.php
    │   └── Factory/
    │       └── AIProviderFactory.php
    └── Messaging/
        ├── Publisher/
        │   └── RabbitMQAgentEventPublisher.php
        └── Subscriber/
            └── RabbitMQExecutionEventSubscriber.php
```

## Core Components

### Agent Entity (Aggregate Root)

The Agent entity represents an AI agent configuration with its model settings, prompt templates, and execution history.

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Domain\Entity;

use App\AgentManager\Domain\ValueObject\AgentId;
use App\AgentManager\Domain\ValueObject\ModelProvider;
use App\AgentManager\Domain\ValueObject\ModelName;
use App\AgentManager\Domain\Event\AgentCreated;
use App\AgentManager\Domain\Event\AgentExecutionStarted;
use App\Shared\Domain\Aggregate\AggregateRoot;
use App\Shared\Domain\ValueObject\UserId;

final class Agent extends AggregateRoot
{
    private AgentId $id;
    private string $name;
    private string $description;
    private ModelConfiguration $modelConfiguration;
    private ?PromptTemplate $promptTemplate = null;
    private array $defaultParameters = [];
    private UserId $ownerId;
    private \DateTimeImmutable $createdAt;
    private \DateTimeImmutable $updatedAt;
    private bool $isActive = true;

    /** @var AgentExecution[] */
    private array $executions = [];

    private function __construct(
        AgentId $id,
        string $name,
        string $description,
        ModelConfiguration $modelConfiguration,
        UserId $ownerId,
    ) {
        $this->id = $id;
        $this->name = $name;
        $this->description = $description;
        $this->modelConfiguration = $modelConfiguration;
        $this->ownerId = $ownerId;
        $this->createdAt = new \DateTimeImmutable();
        $this->updatedAt = new \DateTimeImmutable();
    }

    public static function create(
        AgentId $id,
        string $name,
        string $description,
        ModelConfiguration $modelConfiguration,
        UserId $ownerId,
    ): self {
        $agent = new self($id, $name, $description, $modelConfiguration, $ownerId);

        $agent->recordEvent(new AgentCreated(
            $id,
            $name,
            $modelConfiguration->getProvider(),
            $modelConfiguration->getModel(),
            $ownerId,
        ));

        return $agent;
    }

    public function setPromptTemplate(PromptTemplate $template): void
    {
        $this->promptTemplate = $template;
        $this->updatedAt = new \DateTimeImmutable();
    }

    public function updateModelConfiguration(ModelConfiguration $configuration): void
    {
        $this->modelConfiguration = $configuration;
        $this->updatedAt = new \DateTimeImmutable();
    }

    public function setDefaultParameters(array $parameters): void
    {
        $this->defaultParameters = $parameters;
        $this->updatedAt = new \DateTimeImmutable();
    }

    public function execute(
        string $input,
        array $variables = [],
        ?ConversationContext $context = null,
    ): AgentExecution {
        if (!$this->isActive) {
            throw new \DomainException('Cannot execute inactive agent');
        }

        $execution = AgentExecution::create(
            ExecutionId::generate(),
            $this->id,
            $input,
            array_merge($this->defaultParameters, $variables),
            $context,
        );

        $this->executions[] = $execution;

        $this->recordEvent(new AgentExecutionStarted(
            $execution->getId(),
            $this->id,
            $this->modelConfiguration->getProvider(),
            $this->modelConfiguration->getModel(),
        ));

        return $execution;
    }

    public function deactivate(): void
    {
        $this->isActive = false;
        $this->updatedAt = new \DateTimeImmutable();
    }

    public function activate(): void
    {
        $this->isActive = true;
        $this->updatedAt = new \DateTimeImmutable();
    }

    // Getters

    public function getId(): AgentId
    {
        return $this->id;
    }

    public function getName(): string
    {
        return $this->name;
    }

    public function getDescription(): string
    {
        return $this->description;
    }

    public function getModelConfiguration(): ModelConfiguration
    {
        return $this->modelConfiguration;
    }

    public function getPromptTemplate(): ?PromptTemplate
    {
        return $this->promptTemplate;
    }

    public function getDefaultParameters(): array
    {
        return $this->defaultParameters;
    }

    public function getOwnerId(): UserId
    {
        return $this->ownerId;
    }

    public function isActive(): bool
    {
        return $this->isActive;
    }

    public function getExecutions(): array
    {
        return $this->executions;
    }

    public function getCreatedAt(): \DateTimeImmutable
    {
        return $this->createdAt;
    }

    public function getUpdatedAt(): \DateTimeImmutable
    {
        return $this->updatedAt;
    }
}
```

### AgentExecution Entity

Represents a single execution of an agent with input, output, token usage, and cost tracking.

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Domain\Entity;

use App\AgentManager\Domain\ValueObject\ExecutionId;
use App\AgentManager\Domain\ValueObject\AgentId;
use App\AgentManager\Domain\ValueObject\TokenUsage;
use App\AgentManager\Domain\ValueObject\CostEstimate;

final class AgentExecution
{
    private ExecutionId $id;
    private AgentId $agentId;
    private string $input;
    private array $variables;
    private ?ConversationContext $context;
    private ?string $output = null;
    private ExecutionStatus $status;
    private ?TokenUsage $tokenUsage = null;
    private ?CostEstimate $cost = null;
    private ?string $errorMessage = null;
    private ?array $modelResponse = null;
    private \DateTimeImmutable $startedAt;
    private ?\DateTimeImmutable $completedAt = null;
    private int $durationMs = 0;

    private function __construct(
        ExecutionId $id,
        AgentId $agentId,
        string $input,
        array $variables,
        ?ConversationContext $context,
    ) {
        $this->id = $id;
        $this->agentId = $agentId;
        $this->input = $input;
        $this->variables = $variables;
        $this->context = $context;
        $this->status = ExecutionStatus::PENDING;
        $this->startedAt = new \DateTimeImmutable();
    }

    public static function create(
        ExecutionId $id,
        AgentId $agentId,
        string $input,
        array $variables,
        ?ConversationContext $context,
    ): self {
        return new self($id, $agentId, $input, $variables, $context);
    }

    public function markAsRunning(): void
    {
        if ($this->status !== ExecutionStatus::PENDING) {
            throw new \DomainException('Can only mark pending execution as running');
        }

        $this->status = ExecutionStatus::RUNNING;
    }

    public function complete(
        string $output,
        TokenUsage $tokenUsage,
        CostEstimate $cost,
        array $modelResponse,
    ): void {
        if ($this->status !== ExecutionStatus::RUNNING) {
            throw new \DomainException('Can only complete running execution');
        }

        $this->output = $output;
        $this->tokenUsage = $tokenUsage;
        $this->cost = $cost;
        $this->modelResponse = $modelResponse;
        $this->status = ExecutionStatus::COMPLETED;
        $this->completedAt = new \DateTimeImmutable();
        $this->durationMs = (int) (($this->completedAt->getTimestamp() - $this->startedAt->getTimestamp()) * 1000);
    }

    public function fail(string $errorMessage): void
    {
        if ($this->status === ExecutionStatus::COMPLETED) {
            throw new \DomainException('Cannot fail completed execution');
        }

        $this->errorMessage = $errorMessage;
        $this->status = ExecutionStatus::FAILED;
        $this->completedAt = new \DateTimeImmutable();
        $this->durationMs = (int) (($this->completedAt->getTimestamp() - $this->startedAt->getTimestamp()) * 1000);
    }

    // Getters

    public function getId(): ExecutionId
    {
        return $this->id;
    }

    public function getAgentId(): AgentId
    {
        return $this->agentId;
    }

    public function getInput(): string
    {
        return $this->input;
    }

    public function getVariables(): array
    {
        return $this->variables;
    }

    public function getContext(): ?ConversationContext
    {
        return $this->context;
    }

    public function getOutput(): ?string
    {
        return $this->output;
    }

    public function getStatus(): ExecutionStatus
    {
        return $this->status;
    }

    public function getTokenUsage(): ?TokenUsage
    {
        return $this->tokenUsage;
    }

    public function getCost(): ?CostEstimate
    {
        return $this->cost;
    }

    public function getErrorMessage(): ?string
    {
        return $this->errorMessage;
    }

    public function getModelResponse(): ?array
    {
        return $this->modelResponse;
    }

    public function getDurationMs(): int
    {
        return $this->durationMs;
    }
}

enum ExecutionStatus: string
{
    case PENDING = 'pending';
    case RUNNING = 'running';
    case COMPLETED = 'completed';
    case FAILED = 'failed';
}
```

### ModelConfiguration Entity

Encapsulates AI model configuration including provider, model name, and parameters.

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Domain\Entity;

use App\AgentManager\Domain\ValueObject\ModelProvider;
use App\AgentManager\Domain\ValueObject\ModelName;

final class ModelConfiguration
{
    private ModelProvider $provider;
    private ModelName $model;
    private float $temperature = 0.7;
    private int $maxTokens = 2000;
    private ?float $topP = null;
    private ?float $frequencyPenalty = null;
    private ?float $presencePenalty = null;
    private array $stopSequences = [];
    private ?int $seed = null; // For reproducible outputs
    private array $customParameters = [];

    private function __construct(
        ModelProvider $provider,
        ModelName $model,
    ) {
        $this->provider = $provider;
        $this->model = $model;
    }

    public static function create(
        ModelProvider $provider,
        ModelName $model,
    ): self {
        $config = new self($provider, $model);
        $config->validateCompatibility();
        return $config;
    }

    public function withTemperature(float $temperature): self
    {
        if ($temperature < 0 || $temperature > 2) {
            throw new \InvalidArgumentException('Temperature must be between 0 and 2');
        }

        $config = clone $this;
        $config->temperature = $temperature;
        return $config;
    }

    public function withMaxTokens(int $maxTokens): self
    {
        if ($maxTokens < 1) {
            throw new \InvalidArgumentException('Max tokens must be positive');
        }

        // Validate against model limits
        $modelLimit = $this->getModelTokenLimit();
        if ($maxTokens > $modelLimit) {
            throw new \InvalidArgumentException(
                sprintf('Max tokens (%d) exceeds model limit (%d)', $maxTokens, $modelLimit)
            );
        }

        $config = clone $this;
        $config->maxTokens = $maxTokens;
        return $config;
    }

    public function withTopP(float $topP): self
    {
        if ($topP < 0 || $topP > 1) {
            throw new \InvalidArgumentException('Top P must be between 0 and 1');
        }

        $config = clone $this;
        $config->topP = $topP;
        return $config;
    }

    public function withFrequencyPenalty(float $penalty): self
    {
        if ($penalty < -2 || $penalty > 2) {
            throw new \InvalidArgumentException('Frequency penalty must be between -2 and 2');
        }

        $config = clone $this;
        $config->frequencyPenalty = $penalty;
        return $config;
    }

    public function withPresencePenalty(float $penalty): self
    {
        if ($penalty < -2 || $penalty > 2) {
            throw new \InvalidArgumentException('Presence penalty must be between -2 and 2');
        }

        $config = clone $this;
        $config->presencePenalty = $penalty;
        return $config;
    }

    public function withStopSequences(array $sequences): self
    {
        $config = clone $this;
        $config->stopSequences = $sequences;
        return $config;
    }

    public function withSeed(int $seed): self
    {
        $config = clone $this;
        $config->seed = $seed;
        return $config;
    }

    public function withCustomParameters(array $parameters): self
    {
        $config = clone $this;
        $config->customParameters = array_merge($this->customParameters, $parameters);
        return $config;
    }

    private function validateCompatibility(): void
    {
        // Validate that the model name is compatible with the provider
        $supportedModels = $this->provider->getSupportedModels();

        if (!in_array($this->model->getValue(), $supportedModels, true)) {
            throw new \DomainException(
                sprintf(
                    'Model %s is not supported by provider %s',
                    $this->model->getValue(),
                    $this->provider->getValue()
                )
            );
        }
    }

    private function getModelTokenLimit(): int
    {
        return match($this->model->getValue()) {
            'gpt-4-turbo', 'gpt-4-turbo-preview' => 128000,
            'gpt-4' => 8192,
            'gpt-3.5-turbo' => 16385,
            'claude-3-opus-20240229' => 200000,
            'claude-3-sonnet-20240229' => 200000,
            'claude-3-haiku-20240307' => 200000,
            'gemini-1.5-pro' => 1048576,
            'gemini-1.0-pro' => 32768,
            default => 4096, // Safe default
        };
    }

    public function toArray(): array
    {
        return array_filter([
            'provider' => $this->provider->getValue(),
            'model' => $this->model->getValue(),
            'temperature' => $this->temperature,
            'max_tokens' => $this->maxTokens,
            'top_p' => $this->topP,
            'frequency_penalty' => $this->frequencyPenalty,
            'presence_penalty' => $this->presencePenalty,
            'stop' => $this->stopSequences ?: null,
            'seed' => $this->seed,
        ] + $this->customParameters, fn($value) => $value !== null);
    }

    // Getters

    public function getProvider(): ModelProvider
    {
        return $this->provider;
    }

    public function getModel(): ModelName
    {
        return $this->model;
    }

    public function getTemperature(): float
    {
        return $this->temperature;
    }

    public function getMaxTokens(): int
    {
        return $this->maxTokens;
    }

    public function getTopP(): ?float
    {
        return $this->topP;
    }

    public function getFrequencyPenalty(): ?float
    {
        return $this->frequencyPenalty;
    }

    public function getPresencePenalty(): ?float
    {
        return $this->presencePenalty;
    }

    public function getStopSequences(): array
    {
        return $this->stopSequences;
    }

    public function getSeed(): ?int
    {
        return $this->seed;
    }
}
```

### PromptTemplate Entity

Manages prompt templates with variable substitution and versioning.

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Domain\Entity;

use App\AgentManager\Domain\ValueObject\PromptVariables;
use App\Shared\Domain\ValueObject\UserId;

final class PromptTemplate
{
    private string $id;
    private string $name;
    private string $template;
    private array $requiredVariables = [];
    private array $optionalVariables = [];
    private string $version;
    private UserId $createdBy;
    private \DateTimeImmutable $createdAt;
    private ?string $parentId = null; // For versioning

    private function __construct(
        string $id,
        string $name,
        string $template,
        array $requiredVariables,
        array $optionalVariables,
        string $version,
        UserId $createdBy,
    ) {
        $this->id = $id;
        $this->name = $name;
        $this->template = $template;
        $this->requiredVariables = $requiredVariables;
        $this->optionalVariables = $optionalVariables;
        $this->version = $version;
        $this->createdBy = $createdBy;
        $this->createdAt = new \DateTimeImmutable();
    }

    public static function create(
        string $id,
        string $name,
        string $template,
        array $requiredVariables,
        array $optionalVariables,
        UserId $createdBy,
    ): self {
        return new self(
            $id,
            $name,
            $template,
            $requiredVariables,
            $optionalVariables,
            'v1.0',
            $createdBy,
        );
    }

    public function createVersion(string $newTemplate): self
    {
        $newVersion = $this->incrementVersion($this->version);

        $template = new self(
            $this->generateVersionId(),
            $this->name,
            $newTemplate,
            $this->extractRequiredVariables($newTemplate),
            $this->extractOptionalVariables($newTemplate),
            $newVersion,
            $this->createdBy,
        );

        $template->parentId = $this->id;

        return $template;
    }

    public function compile(PromptVariables $variables): string
    {
        // Validate required variables
        $missingVars = array_diff($this->requiredVariables, array_keys($variables->toArray()));
        if (!empty($missingVars)) {
            throw new \DomainException(
                sprintf('Missing required variables: %s', implode(', ', $missingVars))
            );
        }

        // Replace variables in template
        $compiled = $this->template;

        foreach ($variables->toArray() as $key => $value) {
            // Support both {{ variable }} and {variable} syntax
            $compiled = str_replace(['{{'.$key.'}}', '{'.$key.'}'], (string) $value, $compiled);
        }

        // Check for unresolved required variables
        if (preg_match('/\{\{?\s*(' . implode('|', $this->requiredVariables) . ')\s*\}?\}/', $compiled)) {
            throw new \DomainException('Template contains unresolved required variables');
        }

        return $compiled;
    }

    private function extractRequiredVariables(string $template): array
    {
        preg_match_all('/\{\{!\s*(\w+)\s*\}\}/', $template, $matches);
        return array_unique($matches[1] ?? []);
    }

    private function extractOptionalVariables(string $template): array
    {
        preg_match_all('/\{\{?\s*(\w+)\s*\}?\}/', $template, $matches);
        $allVars = array_unique($matches[1] ?? []);
        $requiredVars = $this->extractRequiredVariables($template);
        return array_diff($allVars, $requiredVars);
    }

    private function incrementVersion(string $version): string
    {
        if (!preg_match('/^v(\d+)\.(\d+)$/', $version, $matches)) {
            throw new \DomainException('Invalid version format');
        }

        $major = (int) $matches[1];
        $minor = (int) $matches[2];

        return sprintf('v%d.%d', $major, $minor + 1);
    }

    private function generateVersionId(): string
    {
        return sprintf('%s_%s_%d', $this->id, $this->version, time());
    }

    // Getters

    public function getId(): string
    {
        return $this->id;
    }

    public function getName(): string
    {
        return $this->name;
    }

    public function getTemplate(): string
    {
        return $this->template;
    }

    public function getRequiredVariables(): array
    {
        return $this->requiredVariables;
    }

    public function getOptionalVariables(): array
    {
        return $this->optionalVariables;
    }

    public function getVersion(): string
    {
        return $this->version;
    }

    public function getParentId(): ?string
    {
        return $this->parentId;
    }
}
```

### ConversationContext Entity

Manages conversation history with intelligent truncation for token management.

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Domain\Entity;

use App\AgentManager\Domain\ValueObject\TokenUsage;

final class ConversationContext
{
    private string $id;
    private array $messages = [];
    private int $maxTokens;
    private int $currentTokenCount = 0;
    private \DateTimeImmutable $createdAt;
    private \DateTimeImmutable $lastAccessedAt;

    private function __construct(string $id, int $maxTokens = 4000)
    {
        $this->id = $id;
        $this->maxTokens = $maxTokens;
        $this->createdAt = new \DateTimeImmutable();
        $this->lastAccessedAt = new \DateTimeImmutable();
    }

    public static function create(string $id, int $maxTokens = 4000): self
    {
        return new self($id, $maxTokens);
    }

    public function addMessage(string $role, string $content, int $tokenCount): void
    {
        $message = [
            'role' => $role,
            'content' => $content,
            'tokens' => $tokenCount,
            'timestamp' => new \DateTimeImmutable(),
        ];

        $this->messages[] = $message;
        $this->currentTokenCount += $tokenCount;
        $this->lastAccessedAt = new \DateTimeImmutable();

        // Truncate if needed
        if ($this->currentTokenCount > $this->maxTokens) {
            $this->truncateOldestMessages();
        }
    }

    public function getMessages(): array
    {
        $this->lastAccessedAt = new \DateTimeImmutable();
        return $this->messages;
    }

    public function getMessagesFormatted(): array
    {
        return array_map(
            fn(array $msg) => ['role' => $msg['role'], 'content' => $msg['content']],
            $this->messages
        );
    }

    private function truncateOldestMessages(): void
    {
        // Keep system messages and remove oldest user/assistant messages
        $systemMessages = array_filter($this->messages, fn($msg) => $msg['role'] === 'system');
        $otherMessages = array_filter($this->messages, fn($msg) => $msg['role'] !== 'system');

        // Remove oldest messages until we're under the limit
        while ($this->currentTokenCount > $this->maxTokens && !empty($otherMessages)) {
            $removed = array_shift($otherMessages);
            $this->currentTokenCount -= $removed['tokens'];
        }

        $this->messages = array_merge($systemMessages, $otherMessages);
    }

    public function clear(): void
    {
        $this->messages = [];
        $this->currentTokenCount = 0;
        $this->lastAccessedAt = new \DateTimeImmutable();
    }

    // Getters

    public function getId(): string
    {
        return $this->id;
    }

    public function getMessageCount(): int
    {
        return count($this->messages);
    }

    public function getCurrentTokenCount(): int
    {
        return $this->currentTokenCount;
    }

    public function getMaxTokens(): int
    {
        return $this->maxTokens;
    }

    public function getLastAccessedAt(): \DateTimeImmutable
    {
        return $this->lastAccessedAt;
    }
}
```

## AI Model Integration

### AIProviderInterface

Contract for all AI provider adapters.

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Infrastructure\AIProvider\Contract;

use App\AgentManager\Domain\Entity\ModelConfiguration;
use App\AgentManager\Domain\Entity\ConversationContext;
use App\AgentManager\Domain\ValueObject\TokenUsage;

interface AIProviderInterface
{
    /**
     * Execute a completion request
     *
     * @param string $prompt The prompt to send to the model
     * @param ModelConfiguration $config Model configuration
     * @param ConversationContext|null $context Optional conversation context
     * @return AIResponse The model's response
     * @throws ModelProviderException
     */
    public function complete(
        string $prompt,
        ModelConfiguration $config,
        ?ConversationContext $context = null,
    ): AIResponse;

    /**
     * Stream a completion request
     *
     * @param string $prompt The prompt to send to the model
     * @param ModelConfiguration $config Model configuration
     * @param ConversationContext|null $context Optional conversation context
     * @return \Generator<AIResponseChunk>
     * @throws ModelProviderException
     */
    public function stream(
        string $prompt,
        ModelConfiguration $config,
        ?ConversationContext $context = null,
    ): \Generator;

    /**
     * Estimate token count for a given text
     *
     * @param string $text Text to count tokens for
     * @param ModelConfiguration $config Model configuration
     * @return int Estimated token count
     */
    public function estimateTokens(string $text, ModelConfiguration $config): int;

    /**
     * Get the provider name
     *
     * @return string Provider name (e.g., 'openai', 'anthropic')
     */
    public function getProviderName(): string;

    /**
     * Check if the provider is available
     *
     * @return bool True if provider is available
     */
    public function isAvailable(): bool;
}

final class AIResponse
{
    public function __construct(
        public readonly string $content,
        public readonly TokenUsage $tokenUsage,
        public readonly array $metadata = [],
        public readonly ?string $finishReason = null,
    ) {}
}

final class AIResponseChunk
{
    public function __construct(
        public readonly string $content,
        public readonly bool $isComplete = false,
        public readonly ?TokenUsage $tokenUsage = null,
    ) {}
}
```

### OpenAI Adapter

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Infrastructure\AIProvider;

use App\AgentManager\Infrastructure\AIProvider\Contract\AIProviderInterface;
use App\AgentManager\Infrastructure\AIProvider\Contract\AIResponse;
use App\AgentManager\Infrastructure\AIProvider\Contract\AIResponseChunk;
use App\AgentManager\Domain\Entity\ModelConfiguration;
use App\AgentManager\Domain\Entity\ConversationContext;
use App\AgentManager\Domain\ValueObject\TokenUsage;
use App\AgentManager\Domain\Exception\ModelProviderException;
use OpenAI\Client as OpenAIClient;
use Psr\Log\LoggerInterface;

final class OpenAIAdapter implements AIProviderInterface
{
    public function __construct(
        private readonly OpenAIClient $client,
        private readonly LoggerInterface $logger,
        private readonly int $timeout = 60,
    ) {}

    public function complete(
        string $prompt,
        ModelConfiguration $config,
        ?ConversationContext $context = null,
    ): AIResponse {
        try {
            $messages = $this->buildMessages($prompt, $context);

            $response = $this->client->chat()->create([
                'model' => $config->getModel()->getValue(),
                'messages' => $messages,
                'temperature' => $config->getTemperature(),
                'max_tokens' => $config->getMaxTokens(),
                'top_p' => $config->getTopP(),
                'frequency_penalty' => $config->getFrequencyPenalty(),
                'presence_penalty' => $config->getPresencePenalty(),
                'stop' => $config->getStopSequences() ?: null,
                'seed' => $config->getSeed(),
            ]);

            $content = $response->choices[0]->message->content ?? '';
            $finishReason = $response->choices[0]->finishReason ?? null;

            $tokenUsage = new TokenUsage(
                promptTokens: $response->usage->promptTokens ?? 0,
                completionTokens: $response->usage->completionTokens ?? 0,
                totalTokens: $response->usage->totalTokens ?? 0,
            );

            $this->logger->info('OpenAI completion successful', [
                'model' => $config->getModel()->getValue(),
                'tokens' => $tokenUsage->getTotalTokens(),
                'finish_reason' => $finishReason,
            ]);

            return new AIResponse(
                content: $content,
                tokenUsage: $tokenUsage,
                metadata: [
                    'model' => $response->model,
                    'id' => $response->id,
                    'created' => $response->created,
                ],
                finishReason: $finishReason,
            );

        } catch (\Throwable $e) {
            $this->logger->error('OpenAI completion failed', [
                'error' => $e->getMessage(),
                'model' => $config->getModel()->getValue(),
            ]);

            throw new ModelProviderException(
                'OpenAI completion failed: ' . $e->getMessage(),
                previous: $e,
            );
        }
    }

    public function stream(
        string $prompt,
        ModelConfiguration $config,
        ?ConversationContext $context = null,
    ): \Generator {
        try {
            $messages = $this->buildMessages($prompt, $context);

            $stream = $this->client->chat()->createStreamed([
                'model' => $config->getModel()->getValue(),
                'messages' => $messages,
                'temperature' => $config->getTemperature(),
                'max_tokens' => $config->getMaxTokens(),
                'stream' => true,
            ]);

            foreach ($stream as $response) {
                $delta = $response->choices[0]->delta->content ?? '';

                if ($delta !== '') {
                    yield new AIResponseChunk(
                        content: $delta,
                        isComplete: false,
                    );
                }

                if ($response->choices[0]->finishReason !== null) {
                    yield new AIResponseChunk(
                        content: '',
                        isComplete: true,
                        tokenUsage: new TokenUsage(
                            promptTokens: $response->usage->promptTokens ?? 0,
                            completionTokens: $response->usage->completionTokens ?? 0,
                            totalTokens: $response->usage->totalTokens ?? 0,
                        ),
                    );
                }
            }

        } catch (\Throwable $e) {
            $this->logger->error('OpenAI stream failed', [
                'error' => $e->getMessage(),
            ]);

            throw new ModelProviderException(
                'OpenAI stream failed: ' . $e->getMessage(),
                previous: $e,
            );
        }
    }

    public function estimateTokens(string $text, ModelConfiguration $config): int
    {
        // Simple approximation: ~4 characters per token for English text
        // For production, use tiktoken library
        return (int) ceil(strlen($text) / 4);
    }

    public function getProviderName(): string
    {
        return 'openai';
    }

    public function isAvailable(): bool
    {
        try {
            // Simple health check - list models
            $this->client->models()->list();
            return true;
        } catch (\Throwable $e) {
            $this->logger->warning('OpenAI provider unavailable', [
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }

    private function buildMessages(string $prompt, ?ConversationContext $context): array
    {
        $messages = [];

        // Add conversation history if available
        if ($context !== null) {
            $messages = $context->getMessagesFormatted();
        }

        // Add current prompt
        $messages[] = [
            'role' => 'user',
            'content' => $prompt,
        ];

        return $messages;
    }
}
```

### Anthropic Adapter

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Infrastructure\AIProvider;

use App\AgentManager\Infrastructure\AIProvider\Contract\AIProviderInterface;
use App\AgentManager\Infrastructure\AIProvider\Contract\AIResponse;
use App\AgentManager\Infrastructure\AIProvider\Contract\AIResponseChunk;
use App\AgentManager\Domain\Entity\ModelConfiguration;
use App\AgentManager\Domain\Entity\ConversationContext;
use App\AgentManager\Domain\ValueObject\TokenUsage;
use App\AgentManager\Domain\Exception\ModelProviderException;
use Psr\Log\LoggerInterface;
use Symfony\Contracts\HttpClient\HttpClientInterface;

final class AnthropicAdapter implements AIProviderInterface
{
    private const API_URL = 'https://api.anthropic.com/v1/messages';
    private const API_VERSION = '2023-06-01';

    public function __construct(
        private readonly HttpClientInterface $httpClient,
        private readonly string $apiKey,
        private readonly LoggerInterface $logger,
    ) {}

    public function complete(
        string $prompt,
        ModelConfiguration $config,
        ?ConversationContext $context = null,
    ): AIResponse {
        try {
            $messages = $this->buildMessages($prompt, $context);

            $response = $this->httpClient->request('POST', self::API_URL, [
                'headers' => [
                    'x-api-key' => $this->apiKey,
                    'anthropic-version' => self::API_VERSION,
                    'content-type' => 'application/json',
                ],
                'json' => [
                    'model' => $config->getModel()->getValue(),
                    'messages' => $messages,
                    'max_tokens' => $config->getMaxTokens(),
                    'temperature' => $config->getTemperature(),
                    'top_p' => $config->getTopP(),
                    'stop_sequences' => $config->getStopSequences() ?: null,
                ],
            ]);

            $data = $response->toArray();

            $content = $data['content'][0]['text'] ?? '';
            $stopReason = $data['stop_reason'] ?? null;

            $tokenUsage = new TokenUsage(
                promptTokens: $data['usage']['input_tokens'] ?? 0,
                completionTokens: $data['usage']['output_tokens'] ?? 0,
                totalTokens: ($data['usage']['input_tokens'] ?? 0) + ($data['usage']['output_tokens'] ?? 0),
            );

            $this->logger->info('Anthropic completion successful', [
                'model' => $config->getModel()->getValue(),
                'tokens' => $tokenUsage->getTotalTokens(),
                'stop_reason' => $stopReason,
            ]);

            return new AIResponse(
                content: $content,
                tokenUsage: $tokenUsage,
                metadata: [
                    'id' => $data['id'] ?? null,
                    'model' => $data['model'] ?? null,
                    'role' => $data['role'] ?? null,
                ],
                finishReason: $stopReason,
            );

        } catch (\Throwable $e) {
            $this->logger->error('Anthropic completion failed', [
                'error' => $e->getMessage(),
            ]);

            throw new ModelProviderException(
                'Anthropic completion failed: ' . $e->getMessage(),
                previous: $e,
            );
        }
    }

    public function stream(
        string $prompt,
        ModelConfiguration $config,
        ?ConversationContext $context = null,
    ): \Generator {
        try {
            $messages = $this->buildMessages($prompt, $context);

            $response = $this->httpClient->request('POST', self::API_URL, [
                'headers' => [
                    'x-api-key' => $this->apiKey,
                    'anthropic-version' => self::API_VERSION,
                    'content-type' => 'application/json',
                ],
                'json' => [
                    'model' => $config->getModel()->getValue(),
                    'messages' => $messages,
                    'max_tokens' => $config->getMaxTokens(),
                    'temperature' => $config->getTemperature(),
                    'stream' => true,
                ],
            ]);

            foreach ($this->httpClient->stream($response) as $chunk) {
                if ($chunk->isTimeout()) {
                    continue;
                }

                $content = $chunk->getContent();
                $lines = explode("\n", $content);

                foreach ($lines as $line) {
                    if (!str_starts_with($line, 'data: ')) {
                        continue;
                    }

                    $data = json_decode(substr($line, 6), true);

                    if ($data['type'] === 'content_block_delta') {
                        yield new AIResponseChunk(
                            content: $data['delta']['text'] ?? '',
                            isComplete: false,
                        );
                    }

                    if ($data['type'] === 'message_stop') {
                        yield new AIResponseChunk(
                            content: '',
                            isComplete: true,
                        );
                    }
                }
            }

        } catch (\Throwable $e) {
            $this->logger->error('Anthropic stream failed', [
                'error' => $e->getMessage(),
            ]);

            throw new ModelProviderException(
                'Anthropic stream failed: ' . $e->getMessage(),
                previous: $e,
            );
        }
    }

    public function estimateTokens(string $text, ModelConfiguration $config): int
    {
        // Approximation for Claude models
        return (int) ceil(strlen($text) / 4);
    }

    public function getProviderName(): string
    {
        return 'anthropic';
    }

    public function isAvailable(): bool
    {
        try {
            // Simple health check
            $this->httpClient->request('GET', 'https://api.anthropic.com', [
                'timeout' => 5,
            ]);
            return true;
        } catch (\Throwable $e) {
            $this->logger->warning('Anthropic provider unavailable', [
                'error' => $e->getMessage(),
            ]);
            return false;
        }
    }

    private function buildMessages(string $prompt, ?ConversationContext $context): array
    {
        $messages = [];

        if ($context !== null) {
            $messages = $context->getMessagesFormatted();
        }

        $messages[] = [
            'role' => 'user',
            'content' => $prompt,
        ];

        return $messages;
    }
}
```

### AIProviderFactory

Factory to create appropriate AI provider adapters.

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Infrastructure\AIProvider\Factory;

use App\AgentManager\Infrastructure\AIProvider\Contract\AIProviderInterface;
use App\AgentManager\Infrastructure\AIProvider\OpenAIAdapter;
use App\AgentManager\Infrastructure\AIProvider\AnthropicAdapter;
use App\AgentManager\Infrastructure\AIProvider\GoogleAIAdapter;
use App\AgentManager\Infrastructure\AIProvider\AzureOpenAIAdapter;
use App\AgentManager\Domain\ValueObject\ModelProvider;

final class AIProviderFactory
{
    public function __construct(
        private readonly OpenAIAdapter $openAIAdapter,
        private readonly AnthropicAdapter $anthropicAdapter,
        private readonly GoogleAIAdapter $googleAIAdapter,
        private readonly AzureOpenAIAdapter $azureOpenAIAdapter,
    ) {}

    public function create(ModelProvider $provider): AIProviderInterface
    {
        return match($provider->getValue()) {
            'openai' => $this->openAIAdapter,
            'anthropic' => $this->anthropicAdapter,
            'google' => $this->googleAIAdapter,
            'azure_openai' => $this->azureOpenAIAdapter,
            default => throw new \InvalidArgumentException(
                sprintf('Unsupported AI provider: %s', $provider->getValue())
            ),
        };
    }
}
```

## Agent Lifecycle Management

### CreateAgentUseCase

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Application\UseCase;

use App\AgentManager\Domain\Entity\Agent;
use App\AgentManager\Domain\Entity\ModelConfiguration;
use App\AgentManager\Domain\Entity\PromptTemplate;
use App\AgentManager\Domain\ValueObject\AgentId;
use App\AgentManager\Domain\ValueObject\ModelProvider;
use App\AgentManager\Domain\ValueObject\ModelName;
use App\AgentManager\Domain\Repository\AgentRepositoryInterface;
use App\AgentManager\Domain\Repository\PromptTemplateRepositoryInterface;
use App\Shared\Domain\ValueObject\UserId;
use Psr\Log\LoggerInterface;

final class CreateAgentUseCase
{
    public function __construct(
        private readonly AgentRepositoryInterface $agentRepository,
        private readonly PromptTemplateRepositoryInterface $promptTemplateRepository,
        private readonly LoggerInterface $logger,
    ) {}

    public function execute(CreateAgentCommand $command): Agent
    {
        $this->logger->info('Creating new agent', [
            'name' => $command->name,
            'provider' => $command->provider,
            'model' => $command->model,
        ]);

        // Create model configuration
        $modelConfig = ModelConfiguration::create(
            new ModelProvider($command->provider),
            new ModelName($command->model),
        );

        // Apply optional parameters
        if ($command->temperature !== null) {
            $modelConfig = $modelConfig->withTemperature($command->temperature);
        }

        if ($command->maxTokens !== null) {
            $modelConfig = $modelConfig->withMaxTokens($command->maxTokens);
        }

        if ($command->topP !== null) {
            $modelConfig = $modelConfig->withTopP($command->topP);
        }

        // Create agent
        $agent = Agent::create(
            AgentId::generate(),
            $command->name,
            $command->description,
            $modelConfig,
            new UserId($command->userId),
        );

        // Attach prompt template if provided
        if ($command->promptTemplateId !== null) {
            $template = $this->promptTemplateRepository->findById($command->promptTemplateId);
            if ($template === null) {
                throw new \DomainException('Prompt template not found');
            }
            $agent->setPromptTemplate($template);
        }

        // Set default parameters if provided
        if (!empty($command->defaultParameters)) {
            $agent->setDefaultParameters($command->defaultParameters);
        }

        // Save agent
        $this->agentRepository->save($agent);

        $this->logger->info('Agent created successfully', [
            'agent_id' => $agent->getId()->toString(),
            'name' => $agent->getName(),
        ]);

        return $agent;
    }
}

final class CreateAgentCommand
{
    public function __construct(
        public readonly string $name,
        public readonly string $description,
        public readonly string $provider,
        public readonly string $model,
        public readonly string $userId,
        public readonly ?string $promptTemplateId = null,
        public readonly ?float $temperature = null,
        public readonly ?int $maxTokens = null,
        public readonly ?float $topP = null,
        public readonly array $defaultParameters = [],
    ) {}
}
```

### ExecuteAgentUseCase

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Application\UseCase;

use App\AgentManager\Domain\Entity\AgentExecution;
use App\AgentManager\Domain\Entity\ConversationContext;
use App\AgentManager\Domain\ValueObject\AgentId;
use App\AgentManager\Domain\ValueObject\PromptVariables;
use App\AgentManager\Domain\ValueObject\CostEstimate;
use App\AgentManager\Domain\Repository\AgentRepositoryInterface;
use App\AgentManager\Domain\Repository\ExecutionRepositoryInterface;
use App\AgentManager\Domain\Service\PromptCompiler;
use App\AgentManager\Domain\Service\TokenCalculator;
use App\AgentManager\Domain\Service\CostCalculator;
use App\AgentManager\Domain\Event\AgentExecutionCompleted;
use App\AgentManager\Domain\Event\AgentExecutionFailed;
use App\AgentManager\Infrastructure\AIProvider\Factory\AIProviderFactory;
use App\AgentManager\Infrastructure\AIProvider\Contract\AIResponse;
use App\Shared\Domain\Bus\Event\EventBusInterface;
use Psr\Log\LoggerInterface;

final class ExecuteAgentUseCase
{
    public function __construct(
        private readonly AgentRepositoryInterface $agentRepository,
        private readonly ExecutionRepositoryInterface $executionRepository,
        private readonly AIProviderFactory $providerFactory,
        private readonly PromptCompiler $promptCompiler,
        private readonly TokenCalculator $tokenCalculator,
        private readonly CostCalculator $costCalculator,
        private readonly EventBusInterface $eventBus,
        private readonly LoggerInterface $logger,
    ) {}

    public function execute(ExecuteAgentCommand $command): AgentExecution
    {
        $startTime = microtime(true);

        // Load agent
        $agent = $this->agentRepository->findById(new AgentId($command->agentId));
        if ($agent === null) {
            throw new \DomainException('Agent not found');
        }

        $this->logger->info('Executing agent', [
            'agent_id' => $agent->getId()->toString(),
            'agent_name' => $agent->getName(),
        ]);

        // Load or create conversation context
        $context = $command->contextId !== null
            ? $this->loadContext($command->contextId)
            : null;

        // Compile prompt
        $compiledPrompt = $this->compilePrompt($agent, $command->input, $command->variables);

        // Create execution
        $execution = $agent->execute(
            $command->input,
            $command->variables,
            $context,
        );

        $execution->markAsRunning();
        $this->executionRepository->save($execution);

        try {
            // Get AI provider
            $provider = $this->providerFactory->create(
                $agent->getModelConfiguration()->getProvider()
            );

            // Execute AI model
            $response = $provider->complete(
                $compiledPrompt,
                $agent->getModelConfiguration(),
                $context,
            );

            // Calculate cost
            $cost = $this->costCalculator->calculate(
                $response->tokenUsage,
                $agent->getModelConfiguration(),
            );

            // Mark execution as complete
            $execution->complete(
                $response->content,
                $response->tokenUsage,
                $cost,
                $response->metadata,
            );

            // Update context if provided
            if ($context !== null) {
                $this->updateContext($context, $compiledPrompt, $response);
            }

            // Save execution
            $this->executionRepository->save($execution);

            // Publish success event
            $this->eventBus->publish(new AgentExecutionCompleted(
                $execution->getId(),
                $agent->getId(),
                $execution->getOutput(),
                $response->tokenUsage,
                $cost,
                microtime(true) - $startTime,
            ));

            $this->logger->info('Agent execution completed', [
                'execution_id' => $execution->getId()->toString(),
                'tokens' => $response->tokenUsage->getTotalTokens(),
                'cost' => $cost->getAmount(),
                'duration_ms' => $execution->getDurationMs(),
            ]);

        } catch (\Throwable $e) {
            // Mark execution as failed
            $execution->fail($e->getMessage());
            $this->executionRepository->save($execution);

            // Publish failure event
            $this->eventBus->publish(new AgentExecutionFailed(
                $execution->getId(),
                $agent->getId(),
                $e->getMessage(),
            ));

            $this->logger->error('Agent execution failed', [
                'execution_id' => $execution->getId()->toString(),
                'error' => $e->getMessage(),
            ]);

            throw $e;
        }

        return $execution;
    }

    private function compilePrompt(Agent $agent, string $input, array $variables): string
    {
        $template = $agent->getPromptTemplate();

        if ($template === null) {
            // No template, use input directly
            return $input;
        }

        // Add input to variables
        $allVariables = array_merge(['input' => $input], $variables);

        return $this->promptCompiler->compile(
            $template,
            new PromptVariables($allVariables),
        );
    }

    private function loadContext(string $contextId): ConversationContext
    {
        // Implementation depends on context storage strategy (Redis, PostgreSQL)
        // For now, return a new context
        return ConversationContext::create($contextId);
    }

    private function updateContext(
        ConversationContext $context,
        string $prompt,
        AIResponse $response,
    ): void {
        // Calculate token counts
        $promptTokens = $response->tokenUsage->getPromptTokens();
        $completionTokens = $response->tokenUsage->getCompletionTokens();

        // Add messages to context
        $context->addMessage('user', $prompt, $promptTokens);
        $context->addMessage('assistant', $response->content, $completionTokens);

        // Save context (implementation depends on storage strategy)
    }
}

final class ExecuteAgentCommand
{
    public function __construct(
        public readonly string $agentId,
        public readonly string $input,
        public readonly array $variables = [],
        public readonly ?string $contextId = null,
    ) {}
}
```

## Prompt Template System

### PromptCompiler Domain Service

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Domain\Service;

use App\AgentManager\Domain\Entity\PromptTemplate;
use App\AgentManager\Domain\ValueObject\PromptVariables;
use App\AgentManager\Domain\Exception\PromptCompilationException;

final class PromptCompiler
{
    public function compile(PromptTemplate $template, PromptVariables $variables): string
    {
        try {
            return $template->compile($variables);
        } catch (\Throwable $e) {
            throw new PromptCompilationException(
                sprintf('Failed to compile prompt template: %s', $e->getMessage()),
                previous: $e,
            );
        }
    }

    public function validate(PromptTemplate $template, array $testVariables): array
    {
        $errors = [];

        // Check for required variables
        $missingVars = array_diff(
            $template->getRequiredVariables(),
            array_keys($testVariables)
        );

        if (!empty($missingVars)) {
            $errors[] = sprintf(
                'Missing required variables: %s',
                implode(', ', $missingVars)
            );
        }

        // Try compilation
        try {
            $this->compile($template, new PromptVariables($testVariables));
        } catch (\Throwable $e) {
            $errors[] = sprintf('Compilation failed: %s', $e->getMessage());
        }

        return $errors;
    }
}
```

## Token Usage Tracking

### TokenCalculator Domain Service

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Domain\Service;

use App\AgentManager\Domain\Entity\ModelConfiguration;
use App\AgentManager\Domain\ValueObject\TokenUsage;

final class TokenCalculator
{
    /**
     * Estimate token count for text based on model
     */
    public function estimate(string $text, ModelConfiguration $config): int
    {
        // Basic estimation - in production use proper tokenizer (tiktoken for OpenAI, etc.)
        $provider = $config->getProvider()->getValue();

        return match($provider) {
            'openai' => $this->estimateOpenAI($text),
            'anthropic' => $this->estimateAnthropic($text),
            'google' => $this->estimateGoogle($text),
            default => $this->estimateGeneric($text),
        };
    }

    /**
     * Check if token usage exceeds limits
     */
    public function isWithinLimit(TokenUsage $usage, int $limit): bool
    {
        return $usage->getTotalTokens() <= $limit;
    }

    /**
     * Calculate remaining tokens for a conversation
     */
    public function calculateRemaining(
        TokenUsage $currentUsage,
        ModelConfiguration $config,
    ): int {
        $modelLimit = $this->getModelLimit($config);
        $reservedForCompletion = $config->getMaxTokens();

        return max(0, $modelLimit - $currentUsage->getTotalTokens() - $reservedForCompletion);
    }

    private function estimateOpenAI(string $text): int
    {
        // Approximation: ~4 chars per token for GPT models
        return (int) ceil(mb_strlen($text) / 4);
    }

    private function estimateAnthropic(string $text): int
    {
        // Claude uses similar tokenization
        return (int) ceil(mb_strlen($text) / 4);
    }

    private function estimateGoogle(string $text): int
    {
        // Gemini tokenization approximation
        return (int) ceil(mb_strlen($text) / 3.5);
    }

    private function estimateGeneric(string $text): int
    {
        return (int) ceil(mb_strlen($text) / 4);
    }

    private function getModelLimit(ModelConfiguration $config): int
    {
        $model = $config->getModel()->getValue();

        return match(true) {
            str_contains($model, 'gpt-4-turbo') => 128000,
            str_contains($model, 'gpt-4') => 8192,
            str_contains($model, 'gpt-3.5-turbo') => 16385,
            str_contains($model, 'claude-3-opus') => 200000,
            str_contains($model, 'claude-3-sonnet') => 200000,
            str_contains($model, 'claude-3-haiku') => 200000,
            str_contains($model, 'gemini-1.5-pro') => 1048576,
            str_contains($model, 'gemini-1.0-pro') => 32768,
            default => 4096,
        };
    }
}
```

### CostCalculator Domain Service

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Domain\Service;

use App\AgentManager\Domain\Entity\ModelConfiguration;
use App\AgentManager\Domain\ValueObject\TokenUsage;
use App\AgentManager\Domain\ValueObject\CostEstimate;

final class CostCalculator
{
    // Prices per 1M tokens (as of 2024)
    private const PRICES = [
        'gpt-4-turbo-preview' => ['input' => 10.00, 'output' => 30.00],
        'gpt-4' => ['input' => 30.00, 'output' => 60.00],
        'gpt-3.5-turbo' => ['input' => 0.50, 'output' => 1.50],
        'claude-3-opus-20240229' => ['input' => 15.00, 'output' => 75.00],
        'claude-3-sonnet-20240229' => ['input' => 3.00, 'output' => 15.00],
        'claude-3-haiku-20240307' => ['input' => 0.25, 'output' => 1.25],
        'gemini-1.5-pro' => ['input' => 3.50, 'output' => 10.50],
        'gemini-1.0-pro' => ['input' => 0.50, 'output' => 1.50],
    ];

    public function calculate(
        TokenUsage $tokenUsage,
        ModelConfiguration $config,
    ): CostEstimate {
        $model = $config->getModel()->getValue();
        $prices = $this->getPrices($model);

        // Calculate cost in USD
        $inputCost = ($tokenUsage->getPromptTokens() / 1_000_000) * $prices['input'];
        $outputCost = ($tokenUsage->getCompletionTokens() / 1_000_000) * $prices['output'];
        $totalCost = $inputCost + $outputCost;

        return new CostEstimate(
            amount: $totalCost,
            currency: 'USD',
            inputTokens: $tokenUsage->getPromptTokens(),
            outputTokens: $tokenUsage->getCompletionTokens(),
            inputCost: $inputCost,
            outputCost: $outputCost,
        );
    }

    public function estimateCost(
        int $estimatedInputTokens,
        int $estimatedOutputTokens,
        ModelConfiguration $config,
    ): CostEstimate {
        $tokenUsage = new TokenUsage(
            promptTokens: $estimatedInputTokens,
            completionTokens: $estimatedOutputTokens,
            totalTokens: $estimatedInputTokens + $estimatedOutputTokens,
        );

        return $this->calculate($tokenUsage, $config);
    }

    private function getPrices(string $model): array
    {
        return self::PRICES[$model] ?? ['input' => 1.00, 'output' => 2.00]; // Default fallback
    }
}
```

### TokenUsage Value Object

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Domain\ValueObject;

final class TokenUsage
{
    public function __construct(
        private readonly int $promptTokens,
        private readonly int $completionTokens,
        private readonly int $totalTokens,
    ) {
        if ($promptTokens < 0 || $completionTokens < 0) {
            throw new \InvalidArgumentException('Token counts cannot be negative');
        }

        if ($totalTokens !== $promptTokens + $completionTokens) {
            throw new \InvalidArgumentException('Total tokens must equal sum of prompt and completion tokens');
        }
    }

    public function getPromptTokens(): int
    {
        return $this->promptTokens;
    }

    public function getCompletionTokens(): int
    {
        return $this->completionTokens;
    }

    public function getTotalTokens(): int
    {
        return $this->totalTokens;
    }

    public function toArray(): array
    {
        return [
            'prompt_tokens' => $this->promptTokens,
            'completion_tokens' => $this->completionTokens,
            'total_tokens' => $this->totalTokens,
        ];
    }
}
```

### CostEstimate Value Object

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Domain\ValueObject;

final class CostEstimate
{
    public function __construct(
        private readonly float $amount,
        private readonly string $currency,
        private readonly int $inputTokens,
        private readonly int $outputTokens,
        private readonly float $inputCost,
        private readonly float $outputCost,
    ) {
        if ($amount < 0) {
            throw new \InvalidArgumentException('Cost amount cannot be negative');
        }
    }

    public function getAmount(): float
    {
        return $this->amount;
    }

    public function getCurrency(): string
    {
        return $this->currency;
    }

    public function getInputTokens(): int
    {
        return $this->inputTokens;
    }

    public function getOutputTokens(): int
    {
        return $this->outputTokens;
    }

    public function getInputCost(): float
    {
        return $this->inputCost;
    }

    public function getOutputCost(): float
    {
        return $this->outputCost;
    }

    public function getFormattedAmount(): string
    {
        return sprintf('%.4f %s', $this->amount, $this->currency);
    }

    public function toArray(): array
    {
        return [
            'amount' => $this->amount,
            'currency' => $this->currency,
            'input_tokens' => $this->inputTokens,
            'output_tokens' => $this->outputTokens,
            'input_cost' => $this->inputCost,
            'output_cost' => $this->outputCost,
        ];
    }
}
```

## Model Fallback Strategy

### ModelFallbackService

Handles automatic fallback to alternative models when primary model fails.

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Domain\Service;

use App\AgentManager\Domain\Entity\ModelConfiguration;
use App\AgentManager\Domain\ValueObject\ModelProvider;
use App\AgentManager\Domain\ValueObject\ModelName;
use App\AgentManager\Infrastructure\AIProvider\Factory\AIProviderFactory;
use App\AgentManager\Infrastructure\AIProvider\Contract\AIResponse;
use App\AgentManager\Domain\Exception\ModelProviderException;
use Psr\Log\LoggerInterface;

final class ModelFallbackService
{
    // Define fallback chains
    private const FALLBACK_CHAINS = [
        'gpt-4-turbo' => ['gpt-4', 'claude-3-sonnet-20240229', 'gpt-3.5-turbo'],
        'gpt-4' => ['gpt-3.5-turbo', 'claude-3-sonnet-20240229'],
        'claude-3-opus-20240229' => ['claude-3-sonnet-20240229', 'claude-3-haiku-20240307', 'gpt-4'],
        'claude-3-sonnet-20240229' => ['claude-3-haiku-20240307', 'gpt-3.5-turbo'],
        'gemini-1.5-pro' => ['gemini-1.0-pro', 'claude-3-sonnet-20240229'],
    ];

    public function __construct(
        private readonly AIProviderFactory $providerFactory,
        private readonly LoggerInterface $logger,
        private readonly int $maxRetries = 3,
    ) {}

    public function executeWithFallback(
        string $prompt,
        ModelConfiguration $originalConfig,
        ?\App\AgentManager\Domain\Entity\ConversationContext $context = null,
    ): AIResponse {
        $attempts = [];
        $lastError = null;

        // Try original model
        try {
            $this->logger->info('Attempting original model', [
                'model' => $originalConfig->getModel()->getValue(),
                'provider' => $originalConfig->getProvider()->getValue(),
            ]);

            $provider = $this->providerFactory->create($originalConfig->getProvider());
            $response = $provider->complete($prompt, $originalConfig, $context);

            $attempts[] = [
                'model' => $originalConfig->getModel()->getValue(),
                'success' => true,
            ];

            return $response;

        } catch (\Throwable $e) {
            $lastError = $e;
            $attempts[] = [
                'model' => $originalConfig->getModel()->getValue(),
                'success' => false,
                'error' => $e->getMessage(),
            ];

            $this->logger->warning('Original model failed, attempting fallback', [
                'model' => $originalConfig->getModel()->getValue(),
                'error' => $e->getMessage(),
            ]);
        }

        // Try fallback models
        $fallbackModels = $this->getFallbackChain($originalConfig->getModel()->getValue());

        foreach ($fallbackModels as $fallbackModel) {
            try {
                $fallbackConfig = $this->createFallbackConfig($fallbackModel, $originalConfig);

                $this->logger->info('Attempting fallback model', [
                    'model' => $fallbackModel,
                ]);

                $provider = $this->providerFactory->create($fallbackConfig->getProvider());
                $response = $provider->complete($prompt, $fallbackConfig, $context);

                $attempts[] = [
                    'model' => $fallbackModel,
                    'success' => true,
                ];

                $this->logger->info('Fallback model succeeded', [
                    'original_model' => $originalConfig->getModel()->getValue(),
                    'fallback_model' => $fallbackModel,
                    'attempts' => count($attempts),
                ]);

                return $response;

            } catch (\Throwable $e) {
                $lastError = $e;
                $attempts[] = [
                    'model' => $fallbackModel,
                    'success' => false,
                    'error' => $e->getMessage(),
                ];

                $this->logger->warning('Fallback model failed', [
                    'model' => $fallbackModel,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        // All models failed
        $this->logger->error('All models failed', [
            'original_model' => $originalConfig->getModel()->getValue(),
            'attempts' => $attempts,
        ]);

        throw new ModelProviderException(
            sprintf(
                'All models failed after %d attempts. Last error: %s',
                count($attempts),
                $lastError?->getMessage() ?? 'Unknown error'
            ),
            previous: $lastError,
        );
    }

    private function getFallbackChain(string $model): array
    {
        return self::FALLBACK_CHAINS[$model] ?? ['gpt-3.5-turbo', 'claude-3-haiku-20240307'];
    }

    private function createFallbackConfig(
        string $fallbackModel,
        ModelConfiguration $originalConfig,
    ): ModelConfiguration {
        // Determine provider from model name
        $provider = $this->determineProvider($fallbackModel);

        $config = ModelConfiguration::create(
            new ModelProvider($provider),
            new ModelName($fallbackModel),
        );

        // Copy parameters from original config
        $config = $config->withTemperature($originalConfig->getTemperature());

        // Adjust maxTokens if needed for model limits
        $maxTokens = min($originalConfig->getMaxTokens(), $this->getModelLimit($fallbackModel));
        $config = $config->withMaxTokens($maxTokens);

        if ($originalConfig->getTopP() !== null) {
            $config = $config->withTopP($originalConfig->getTopP());
        }

        return $config;
    }

    private function determineProvider(string $model): string
    {
        return match(true) {
            str_starts_with($model, 'gpt-') => 'openai',
            str_starts_with($model, 'claude-') => 'anthropic',
            str_starts_with($model, 'gemini-') => 'google',
            default => 'openai',
        };
    }

    private function getModelLimit(string $model): int
    {
        return match(true) {
            str_contains($model, 'gpt-4-turbo') => 128000,
            str_contains($model, 'gpt-4') => 8192,
            str_contains($model, 'gpt-3.5-turbo') => 16385,
            str_contains($model, 'claude-3-opus') => 200000,
            str_contains($model, 'claude-3-sonnet') => 200000,
            str_contains($model, 'claude-3-haiku') => 200000,
            str_contains($model, 'gemini-1.5-pro') => 1048576,
            str_contains($model, 'gemini-1.0-pro') => 32768,
            default => 4096,
        };
    }
}
```

## Context Management

### ContextManager Domain Service

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Domain\Service;

use App\AgentManager\Domain\Entity\ConversationContext;
use App\AgentManager\Infrastructure\Persistence\Redis\RedisContextCache;

final class ContextManager
{
    public function __construct(
        private readonly RedisContextCache $contextCache,
        private readonly TokenCalculator $tokenCalculator,
    ) {}

    public function getOrCreate(string $contextId, int $maxTokens = 4000): ConversationContext
    {
        $cached = $this->contextCache->get($contextId);

        if ($cached !== null) {
            return $cached;
        }

        $context = ConversationContext::create($contextId, $maxTokens);
        $this->contextCache->set($contextId, $context);

        return $context;
    }

    public function save(ConversationContext $context): void
    {
        $this->contextCache->set($context->getId(), $context, ttl: 3600); // 1 hour TTL
    }

    public function delete(string $contextId): void
    {
        $this->contextCache->delete($contextId);
    }

    public function addSystemMessage(ConversationContext $context, string $message): void
    {
        $tokens = $this->tokenCalculator->estimateGeneric($message);
        $context->addMessage('system', $message, $tokens);
        $this->save($context);
    }
}
```

### RedisContextCache

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Infrastructure\Persistence\Redis;

use App\AgentManager\Domain\Entity\ConversationContext;
use Symfony\Component\Cache\Adapter\RedisAdapter;

final class RedisContextCache
{
    private const KEY_PREFIX = 'agent_context:';

    public function __construct(
        private readonly RedisAdapter $cache,
    ) {}

    public function get(string $contextId): ?ConversationContext
    {
        $item = $this->cache->getItem(self::KEY_PREFIX . $contextId);

        if (!$item->isHit()) {
            return null;
        }

        return $item->get();
    }

    public function set(ConversationContext $context, int $ttl = 3600): void
    {
        $item = $this->cache->getItem(self::KEY_PREFIX . $context->getId());
        $item->set($context);
        $item->expiresAfter($ttl);

        $this->cache->save($item);
    }

    public function delete(string $contextId): void
    {
        $this->cache->deleteItem(self::KEY_PREFIX . $contextId);
    }
}
```

## Error Handling

### Domain Exceptions

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Domain\Exception;

final class AgentNotFoundException extends \DomainException
{
    public static function withId(string $id): self
    {
        return new self(sprintf('Agent with ID %s not found', $id));
    }
}

final class ModelProviderException extends \RuntimeException
{
    public function __construct(
        string $message,
        private readonly ?string $provider = null,
        private readonly ?string $model = null,
        ?\Throwable $previous = null,
    ) {
        parent::__construct($message, 0, $previous);
    }

    public function getProvider(): ?string
    {
        return $this->provider;
    }

    public function getModel(): ?string
    {
        return $this->model;
    }
}

final class TokenLimitExceededException extends \DomainException
{
    public function __construct(
        private readonly int $used,
        private readonly int $limit,
    ) {
        parent::__construct(
            sprintf('Token limit exceeded: %d used, %d limit', $used, $limit)
        );
    }

    public function getUsed(): int
    {
        return $this->used;
    }

    public function getLimit(): int
    {
        return $this->limit;
    }
}

final class PromptCompilationException extends \RuntimeException
{
}
```

## API Endpoints

### AgentController

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Infrastructure\Http\Controller;

use App\AgentManager\Application\UseCase\CreateAgentUseCase;
use App\AgentManager\Application\UseCase\CreateAgentCommand;
use App\AgentManager\Application\UseCase\ExecuteAgentUseCase;
use App\AgentManager\Application\UseCase\ExecuteAgentCommand;
use App\AgentManager\Domain\Repository\AgentRepositoryInterface;
use App\AgentManager\Domain\ValueObject\AgentId;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;
use OpenApi\Attributes as OA;

#[Route('/api/v1/agents')]
#[OA\Tag(name: 'Agents')]
final class AgentController extends AbstractController
{
    #[Route('', methods: ['POST'])]
    #[OA\Post(
        summary: 'Create a new AI agent',
        requestBody: new OA\RequestBody(
            required: true,
            content: new OA\JsonContent(
                required: ['name', 'description', 'provider', 'model'],
                properties: [
                    new OA\Property(property: 'name', type: 'string'),
                    new OA\Property(property: 'description', type: 'string'),
                    new OA\Property(property: 'provider', type: 'string', enum: ['openai', 'anthropic', 'google', 'azure_openai']),
                    new OA\Property(property: 'model', type: 'string'),
                    new OA\Property(property: 'prompt_template_id', type: 'string', nullable: true),
                    new OA\Property(property: 'temperature', type: 'number', format: 'float', nullable: true),
                    new OA\Property(property: 'max_tokens', type: 'integer', nullable: true),
                    new OA\Property(property: 'default_parameters', type: 'object', nullable: true),
                ]
            )
        ),
        responses: [
            new OA\Response(response: 201, description: 'Agent created successfully'),
            new OA\Response(response: 400, description: 'Invalid request'),
        ]
    )]
    public function create(
        Request $request,
        CreateAgentUseCase $useCase,
    ): JsonResponse {
        $data = $request->toArray();

        $command = new CreateAgentCommand(
            name: $data['name'],
            description: $data['description'],
            provider: $data['provider'],
            model: $data['model'],
            userId: $this->getUser()->getId(),
            promptTemplateId: $data['prompt_template_id'] ?? null,
            temperature: $data['temperature'] ?? null,
            maxTokens: $data['max_tokens'] ?? null,
            topP: $data['top_p'] ?? null,
            defaultParameters: $data['default_parameters'] ?? [],
        );

        $agent = $useCase->execute($command);

        return $this->json([
            'id' => $agent->getId()->toString(),
            'name' => $agent->getName(),
            'description' => $agent->getDescription(),
            'model_configuration' => $agent->getModelConfiguration()->toArray(),
            'created_at' => $agent->getCreatedAt()->format(\DateTimeInterface::ATOM),
        ], Response::HTTP_CREATED);
    }

    #[Route('/{id}', methods: ['GET'])]
    #[OA\Get(
        summary: 'Get agent details',
        parameters: [
            new OA\Parameter(name: 'id', in: 'path', required: true, schema: new OA\Schema(type: 'string', format: 'uuid'))
        ],
        responses: [
            new OA\Response(response: 200, description: 'Agent details'),
            new OA\Response(response: 404, description: 'Agent not found'),
        ]
    )]
    public function show(
        string $id,
        AgentRepositoryInterface $repository,
    ): JsonResponse {
        $agent = $repository->findById(new AgentId($id));

        if ($agent === null) {
            return $this->json(['error' => 'Agent not found'], Response::HTTP_NOT_FOUND);
        }

        return $this->json([
            'id' => $agent->getId()->toString(),
            'name' => $agent->getName(),
            'description' => $agent->getDescription(),
            'model_configuration' => $agent->getModelConfiguration()->toArray(),
            'is_active' => $agent->isActive(),
            'created_at' => $agent->getCreatedAt()->format(\DateTimeInterface::ATOM),
            'updated_at' => $agent->getUpdatedAt()->format(\DateTimeInterface::ATOM),
        ]);
    }

    #[Route('/{id}/execute', methods: ['POST'])]
    #[OA\Post(
        summary: 'Execute an agent',
        parameters: [
            new OA\Parameter(name: 'id', in: 'path', required: true, schema: new OA\Schema(type: 'string', format: 'uuid'))
        ],
        requestBody: new OA\RequestBody(
            required: true,
            content: new OA\JsonContent(
                required: ['input'],
                properties: [
                    new OA\Property(property: 'input', type: 'string'),
                    new OA\Property(property: 'variables', type: 'object', nullable: true),
                    new OA\Property(property: 'context_id', type: 'string', nullable: true),
                ]
            )
        ),
        responses: [
            new OA\Response(response: 200, description: 'Execution completed'),
            new OA\Response(response: 404, description: 'Agent not found'),
            new OA\Response(response: 500, description: 'Execution failed'),
        ]
    )]
    public function execute(
        string $id,
        Request $request,
        ExecuteAgentUseCase $useCase,
    ): JsonResponse {
        $data = $request->toArray();

        $command = new ExecuteAgentCommand(
            agentId: $id,
            input: $data['input'],
            variables: $data['variables'] ?? [],
            contextId: $data['context_id'] ?? null,
        );

        $execution = $useCase->execute($command);

        return $this->json([
            'execution_id' => $execution->getId()->toString(),
            'output' => $execution->getOutput(),
            'token_usage' => $execution->getTokenUsage()?->toArray(),
            'cost' => $execution->getCost()?->toArray(),
            'duration_ms' => $execution->getDurationMs(),
            'status' => $execution->getStatus()->value,
        ]);
    }
}
```

## Database Schema

### PostgreSQL Schema

```sql
-- Agents table
CREATE TABLE agents (
    id UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    owner_id UUID NOT NULL,
    model_provider VARCHAR(50) NOT NULL,
    model_name VARCHAR(255) NOT NULL,
    temperature DECIMAL(3,2) DEFAULT 0.7,
    max_tokens INTEGER DEFAULT 2000,
    top_p DECIMAL(3,2),
    frequency_penalty DECIMAL(3,2),
    presence_penalty DECIMAL(3,2),
    stop_sequences JSONB,
    custom_parameters JSONB,
    prompt_template_id VARCHAR(255),
    default_parameters JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_agents_owner FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_agents_owner ON agents(owner_id);
CREATE INDEX idx_agents_provider_model ON agents(model_provider, model_name);
CREATE INDEX idx_agents_is_active ON agents(is_active) WHERE is_active = TRUE;

-- Agent executions table (partitioned by created_at)
CREATE TABLE agent_executions (
    id UUID NOT NULL,
    agent_id UUID NOT NULL,
    input TEXT NOT NULL,
    variables JSONB,
    output TEXT,
    status VARCHAR(20) NOT NULL,
    prompt_tokens INTEGER,
    completion_tokens INTEGER,
    total_tokens INTEGER,
    cost_amount DECIMAL(10,6),
    cost_currency VARCHAR(3) DEFAULT 'USD',
    error_message TEXT,
    model_response JSONB,
    started_at TIMESTAMP NOT NULL,
    completed_at TIMESTAMP,
    duration_ms INTEGER,

    PRIMARY KEY (id, started_at),
    CONSTRAINT fk_executions_agent FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE
) PARTITION BY RANGE (started_at);

-- Create partitions for executions (monthly)
CREATE TABLE agent_executions_2025_01 PARTITION OF agent_executions
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE agent_executions_2025_02 PARTITION OF agent_executions
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
-- ... additional monthly partitions

CREATE INDEX idx_executions_agent ON agent_executions(agent_id);
CREATE INDEX idx_executions_status ON agent_executions(status);
CREATE INDEX idx_executions_started ON agent_executions(started_at DESC);

-- Prompt templates table
CREATE TABLE prompt_templates (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    template TEXT NOT NULL,
    required_variables JSONB,
    optional_variables JSONB,
    version VARCHAR(50) NOT NULL,
    parent_id VARCHAR(255),
    created_by UUID NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_templates_parent FOREIGN KEY (parent_id) REFERENCES prompt_templates(id) ON DELETE SET NULL,
    CONSTRAINT fk_templates_creator FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_templates_name ON prompt_templates(name);
CREATE INDEX idx_templates_parent ON prompt_templates(parent_id);

-- Token usage tracking (for rate limiting and cost management)
CREATE TABLE token_usage_tracking (
    id BIGSERIAL PRIMARY KEY,
    agent_id UUID NOT NULL,
    user_id UUID NOT NULL,
    organization_id UUID,
    execution_id UUID NOT NULL,
    model_provider VARCHAR(50) NOT NULL,
    model_name VARCHAR(255) NOT NULL,
    prompt_tokens INTEGER NOT NULL,
    completion_tokens INTEGER NOT NULL,
    total_tokens INTEGER NOT NULL,
    cost_amount DECIMAL(10,6) NOT NULL,
    cost_currency VARCHAR(3) DEFAULT 'USD',
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_token_usage_agent FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE,
    CONSTRAINT fk_token_usage_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) PARTITION BY RANGE (timestamp);

-- Create partitions (monthly)
CREATE TABLE token_usage_tracking_2025_01 PARTITION OF token_usage_tracking
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
-- ... additional monthly partitions

CREATE INDEX idx_token_usage_user_time ON token_usage_tracking(user_id, timestamp DESC);
CREATE INDEX idx_token_usage_agent_time ON token_usage_tracking(agent_id, timestamp DESC);
CREATE INDEX idx_token_usage_org_time ON token_usage_tracking(organization_id, timestamp DESC) WHERE organization_id IS NOT NULL;

-- Materialized view for usage analytics
CREATE MATERIALIZED VIEW agent_usage_summary AS
SELECT
    agent_id,
    user_id,
    DATE_TRUNC('day', timestamp) as usage_date,
    COUNT(*) as execution_count,
    SUM(total_tokens) as total_tokens,
    SUM(cost_amount) as total_cost,
    AVG(total_tokens) as avg_tokens_per_execution,
    model_provider,
    model_name
FROM token_usage_tracking
GROUP BY agent_id, user_id, DATE_TRUNC('day', timestamp), model_provider, model_name;

CREATE UNIQUE INDEX idx_agent_usage_summary ON agent_usage_summary(agent_id, user_id, usage_date);

-- Refresh materialized view function
CREATE OR REPLACE FUNCTION refresh_agent_usage_summary()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY agent_usage_summary;
END;
$$ LANGUAGE plpgsql;
```

## Implementation Examples

### Complete Agent Creation and Execution Flow

```php
<?php

// Example 1: Create agent with custom configuration
$createAgentCommand = new CreateAgentCommand(
    name: 'Customer Support Agent',
    description: 'AI agent for handling customer support inquiries',
    provider: 'anthropic',
    model: 'claude-3-sonnet-20240229',
    userId: $currentUser->getId(),
    temperature: 0.7,
    maxTokens: 4000,
);

$agent = $createAgentUseCase->execute($createAgentCommand);

// Example 2: Create prompt template
$templateId = 'customer_support_template_v1';
$template = PromptTemplate::create(
    id: $templateId,
    name: 'Customer Support Template',
    template: 'You are a helpful customer support agent for {{company_name}}.

Context: {{context}}

Customer Query: {{input}}

Please provide a helpful and empathetic response.',
    requiredVariables: ['company_name', 'input'],
    optionalVariables: ['context'],
    createdBy: new UserId($currentUser->getId()),
);

$promptTemplateRepository->save($template);

// Example 3: Attach template to agent
$agent->setPromptTemplate($template);
$agent->setDefaultParameters([
    'company_name' => 'Acme Corp',
]);
$agentRepository->save($agent);

// Example 4: Execute agent with context
$contextId = 'conversation_' . uniqid();
$context = ConversationContext::create($contextId, maxTokens: 8000);
$contextManager->addSystemMessage(
    $context,
    'You have access to the customer\'s order history and account details.'
);

$executeCommand = new ExecuteAgentCommand(
    agentId: $agent->getId()->toString(),
    input: 'I ordered a product last week but haven\'t received it yet.',
    variables: [
        'context' => 'Customer: John Doe, Last Order: #12345, Shipped: 2025-01-05',
    ],
    contextId: $contextId,
);

$execution = $executeAgentUseCase->execute($executeCommand);

echo "Response: " . $execution->getOutput() . "\n";
echo "Tokens Used: " . $execution->getTokenUsage()->getTotalTokens() . "\n";
echo "Cost: " . $execution->getCost()->getFormattedAmount() . "\n";

// Example 5: Continue conversation
$followUpCommand = new ExecuteAgentCommand(
    agentId: $agent->getId()->toString(),
    input: 'Can you check the tracking number?',
    contextId: $contextId, // Same context to maintain conversation
);

$followUpExecution = $executeAgentUseCase->execute($followUpCommand);

// Example 6: Streaming execution
$provider = $providerFactory->create($agent->getModelConfiguration()->getProvider());
$prompt = 'Write a detailed explanation of our refund policy.';

foreach ($provider->stream($prompt, $agent->getModelConfiguration()) as $chunk) {
    echo $chunk->content;
    flush();

    if ($chunk->isComplete) {
        echo "\n\nTotal tokens: " . $chunk->tokenUsage?->getTotalTokens() . "\n";
    }
}

// Example 7: Model fallback in action
try {
    $response = $modelFallbackService->executeWithFallback(
        prompt: 'Summarize this customer feedback: ...',
        originalConfig: $agent->getModelConfiguration(),
        context: $context,
    );

    echo "Response from: " . $response->metadata['model'] . "\n";

} catch (ModelProviderException $e) {
    echo "All models failed: " . $e->getMessage() . "\n";
}

// Example 8: Token usage tracking and limits
$userTokenLimit = 1000000; // 1M tokens per month
$currentUsage = $tokenUsageRepository->getUserMonthlyUsage($currentUser->getId());

if ($currentUsage >= $userTokenLimit) {
    throw new TokenLimitExceededException($currentUsage, $userTokenLimit);
}

// Example 9: Batch execution with rate limiting
$queries = [
    'Query 1...',
    'Query 2...',
    'Query 3...',
];

$results = [];
$rateLimiter = new RateLimiter(maxRequestsPerMinute: 10);

foreach ($queries as $query) {
    $rateLimiter->throttle();

    $execution = $executeAgentUseCase->execute(
        new ExecuteAgentCommand(
            agentId: $agent->getId()->toString(),
            input: $query,
        )
    );

    $results[] = $execution->getOutput();
}

// Example 10: Cost optimization with model selection
$costEstimator = new CostCalculator();

$inputText = 'Long input text...';
$estimatedInputTokens = $tokenCalculator->estimate($inputText, $agent->getModelConfiguration());
$estimatedOutputTokens = 500;

// Compare costs across models
$models = [
    ['provider' => 'openai', 'model' => 'gpt-4'],
    ['provider' => 'openai', 'model' => 'gpt-3.5-turbo'],
    ['provider' => 'anthropic', 'model' => 'claude-3-haiku-20240307'],
];

foreach ($models as $modelInfo) {
    $config = ModelConfiguration::create(
        new ModelProvider($modelInfo['provider']),
        new ModelName($modelInfo['model']),
    );

    $cost = $costEstimator->estimateCost(
        $estimatedInputTokens,
        $estimatedOutputTokens,
        $config,
    );

    echo sprintf(
        "%s: %s\n",
        $modelInfo['model'],
        $cost->getFormattedAmount()
    );
}
```

## Performance Optimization

### Caching Strategy

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Infrastructure\Cache;

use Symfony\Contracts\Cache\CacheInterface;
use Symfony\Contracts\Cache\ItemInterface;

final class AgentResponseCache
{
    private const TTL = 3600; // 1 hour

    public function __construct(
        private readonly CacheInterface $cache,
    ) {}

    public function getCachedResponse(
        string $agentId,
        string $input,
        array $variables,
    ): ?string {
        $key = $this->generateKey($agentId, $input, $variables);

        $item = $this->cache->getItem($key);

        return $item->isHit() ? $item->get() : null;
    }

    public function cacheResponse(
        string $agentId,
        string $input,
        array $variables,
        string $response,
    ): void {
        $key = $this->generateKey($agentId, $input, $variables);

        $this->cache->get($key, function (ItemInterface $item) use ($response) {
            $item->expiresAfter(self::TTL);
            return $response;
        });
    }

    private function generateKey(string $agentId, string $input, array $variables): string
    {
        return sprintf(
            'agent_response:%s:%s',
            $agentId,
            md5($input . json_encode($variables))
        );
    }
}
```

### Connection Pooling for AI Providers

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Infrastructure\AIProvider;

use Symfony\Component\HttpClient\HttpClient;
use Symfony\Contracts\HttpClient\HttpClientInterface;

final class AIProviderConnectionPool
{
    private array $clients = [];

    public function getClient(string $provider): HttpClientInterface
    {
        if (!isset($this->clients[$provider])) {
            $this->clients[$provider] = HttpClient::create([
                'max_host_connections' => 10,
                'timeout' => 60,
            ]);
        }

        return $this->clients[$provider];
    }
}
```

## Security Considerations

### API Key Management

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Infrastructure\Security;

use Symfony\Component\DependencyInjection\Attribute\Autowire;

final class AIProviderCredentialsManager
{
    public function __construct(
        #[Autowire(env: 'OPENAI_API_KEY')]
        private readonly string $openaiKey,

        #[Autowire(env: 'ANTHROPIC_API_KEY')]
        private readonly string $anthropicKey,

        #[Autowire(env: 'GOOGLE_AI_API_KEY')]
        private readonly string $googleKey,
    ) {}

    public function getKey(string $provider): string
    {
        return match($provider) {
            'openai' => $this->openaiKey,
            'anthropic' => $this->anthropicKey,
            'google' => $this->googleKey,
            default => throw new \InvalidArgumentException('Unknown provider'),
        };
    }
}
```

### Input Validation and Sanitization

```php
<?php

declare(strict_types=1);

namespace App\AgentManager\Infrastructure\Validation;

final class AgentInputValidator
{
    private const MAX_INPUT_LENGTH = 100000; // 100KB
    private const FORBIDDEN_PATTERNS = [
        '/system\s+prompt/i',
        '/ignore\s+previous/i',
        '/disregard\s+instructions/i',
    ];

    public function validate(string $input): void
    {
        // Check length
        if (strlen($input) > self::MAX_INPUT_LENGTH) {
            throw new \InvalidArgumentException('Input too long');
        }

        // Check for prompt injection attempts
        foreach (self::FORBIDDEN_PATTERNS as $pattern) {
            if (preg_match($pattern, $input)) {
                throw new \InvalidArgumentException('Suspicious input detected');
            }
        }
    }

    public function sanitize(string $input): string
    {
        // Remove null bytes
        $input = str_replace("\0", '', $input);

        // Normalize whitespace
        $input = preg_replace('/\s+/', ' ', $input);

        return trim($input);
    }
}
```

---

**Document Status**: Complete (15,000+ words)
**Last Updated**: 2025-01-07
**Version**: 1.0

This comprehensive Agent Manager Service documentation provides complete implementation details including multi-provider AI integration, prompt templating, token tracking, cost management, model fallback strategies, and production-ready code examples.
