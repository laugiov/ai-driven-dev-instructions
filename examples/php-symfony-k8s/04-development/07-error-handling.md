# Error Handling Strategy

## Table of Contents

1. [Introduction](#introduction)
2. [Error Handling Philosophy](#error-handling-philosophy)
3. [Exception Hierarchy](#exception-hierarchy)
4. [Domain Exceptions](#domain-exceptions)
5. [Application Exceptions](#application-exceptions)
6. [Infrastructure Exceptions](#infrastructure-exceptions)
7. [Exception Handling Patterns](#exception-handling-patterns)
8. [Error Response Formats](#error-response-formats)
9. [Logging and Monitoring](#logging-and-monitoring)
10. [Recovery Strategies](#recovery-strategies)
11. [User-Facing Error Messages](#user-facing-error-messages)
12. [Testing Error Scenarios](#testing-error-scenarios)

## Introduction

This document defines the comprehensive error handling strategy for the AI Workflow Processing Platform. Effective error handling is critical for system reliability, user experience, and maintainability. Our approach follows hexagonal architecture principles, ensuring errors are properly handled at each layer with appropriate recovery mechanisms.

### Key Principles

**Fail Fast**: Detect and report errors as early as possible in the request lifecycle.

**Explicit Error Types**: Use strongly-typed exceptions that clearly communicate the error context.

**Layer-Appropriate Handling**: Each architectural layer handles errors appropriate to its concerns.

**Operational Visibility**: All errors are logged and monitored for operational awareness.

**User-Friendly Messages**: External-facing errors provide actionable information without exposing implementation details.

**Graceful Degradation**: Systems should degrade gracefully rather than failing completely when possible.

## Error Handling Philosophy

### Exceptions vs Return Values

**When to Use Exceptions:**

```php
<?php

declare(strict_types=1);

namespace App\Domain\Agent\Exception;

// Use exceptions for exceptional conditions that prevent normal operation
final class AgentNotFoundException extends DomainException
{
    public static function withId(AgentId $id): self
    {
        return new self(
            sprintf('Agent with ID "%s" was not found', $id->toString())
        );
    }
}

// Example usage in domain
final class Agent
{
    public static function fromId(
        AgentId $id,
        AgentRepositoryInterface $repository
    ): self {
        $agent = $repository->findById($id);

        if ($agent === null) {
            throw AgentNotFoundException::withId($id);
        }

        return $agent;
    }
}
```

**When to Use Return Values:**

```php
<?php

declare(strict_types=1);

namespace App\Domain\Workflow;

use App\Domain\Shared\Result;

// Use Result objects for expected business outcomes
final class WorkflowExecutor
{
    public function execute(WorkflowId $workflowId): Result
    {
        try {
            $workflow = $this->repository->findById($workflowId);

            if ($workflow === null) {
                return Result::failure('Workflow not found');
            }

            if (!$workflow->canExecute()) {
                return Result::failure('Workflow is not in executable state');
            }

            $result = $workflow->execute();

            return Result::success($result);

        } catch (InfrastructureException $e) {
            // Infrastructure failures are exceptional
            throw $e;
        }
    }
}

// Result implementation
final class Result
{
    private function __construct(
        private readonly bool $isSuccess,
        private readonly mixed $value = null,
        private readonly ?string $error = null
    ) {}

    public static function success(mixed $value): self
    {
        return new self(true, $value);
    }

    public static function failure(string $error): self
    {
        return new self(false, null, $error);
    }

    public function isSuccess(): bool
    {
        return $this->isSuccess;
    }

    public function getValue(): mixed
    {
        if (!$this->isSuccess) {
            throw new \LogicException('Cannot get value from failed result');
        }

        return $this->value;
    }

    public function getError(): ?string
    {
        return $this->error;
    }
}
```

### Exception Guidelines

**DO:**
- Use exceptions for exceptional conditions
- Create specific exception types for different error scenarios
- Include context in exception messages
- Use named constructors for exception creation
- Document exceptions in PHPDoc
- Catch exceptions at appropriate boundaries

**DON'T:**
- Use exceptions for control flow
- Catch and ignore exceptions without logging
- Expose sensitive information in exception messages
- Create overly generic exception types
- Throw exceptions from destructors or __toString()
- Catch base Exception class unless necessary

## Exception Hierarchy

### Base Exception Structure

```php
<?php

declare(strict_types=1);

namespace App\Shared\Exception;

use Throwable;

/**
 * Base exception for all application exceptions.
 *
 * This provides common functionality for all custom exceptions
 * including error codes, context, and HTTP status mapping.
 */
abstract class ApplicationException extends \RuntimeException
{
    protected array $context = [];
    protected ?string $errorCode = null;
    protected int $httpStatusCode = 500;

    public function __construct(
        string $message = '',
        int $code = 0,
        ?Throwable $previous = null,
        array $context = []
    ) {
        parent::__construct($message, $code, $previous);
        $this->context = $context;
    }

    public function getContext(): array
    {
        return $this->context;
    }

    public function getErrorCode(): ?string
    {
        return $this->errorCode;
    }

    public function getHttpStatusCode(): int
    {
        return $this->httpStatusCode;
    }

    public function withContext(array $context): self
    {
        $exception = clone $this;
        $exception->context = array_merge($this->context, $context);

        return $exception;
    }
}

/**
 * Domain layer exceptions - business rule violations.
 */
abstract class DomainException extends ApplicationException
{
    protected int $httpStatusCode = 400;
}

/**
 * Application layer exceptions - use case failures.
 */
abstract class ApplicationLayerException extends ApplicationException
{
    protected int $httpStatusCode = 422;
}

/**
 * Infrastructure layer exceptions - technical failures.
 */
abstract class InfrastructureException extends ApplicationException
{
    protected int $httpStatusCode = 503;
}

/**
 * Validation exceptions - input validation failures.
 */
abstract class ValidationException extends ApplicationException
{
    protected int $httpStatusCode = 422;
    protected array $violations = [];

    public function __construct(
        string $message,
        array $violations = [],
        int $code = 0,
        ?Throwable $previous = null
    ) {
        parent::__construct($message, $code, $previous);
        $this->violations = $violations;
        $this->errorCode = 'VALIDATION_ERROR';
    }

    public function getViolations(): array
    {
        return $this->violations;
    }
}

/**
 * Authorization exceptions - permission denied.
 */
abstract class AuthorizationException extends ApplicationException
{
    protected int $httpStatusCode = 403;
}

/**
 * Authentication exceptions - authentication required or failed.
 */
abstract class AuthenticationException extends ApplicationException
{
    protected int $httpStatusCode = 401;
}

/**
 * Not found exceptions - requested resource doesn't exist.
 */
abstract class NotFoundException extends ApplicationException
{
    protected int $httpStatusCode = 404;
}

/**
 * Conflict exceptions - resource state conflicts with request.
 */
abstract class ConflictException extends ApplicationException
{
    protected int $httpStatusCode = 409;
}
```

## Domain Exceptions

### Domain-Specific Exceptions

```php
<?php

declare(strict_types=1);

namespace App\Domain\Agent\Exception;

use App\Domain\Agent\ValueObject\AgentId;
use App\Shared\Exception\DomainException;
use App\Shared\Exception\NotFoundException;
use App\Shared\Exception\ConflictException;

/**
 * Thrown when an agent is not found.
 */
final class AgentNotFoundException extends NotFoundException
{
    public static function withId(AgentId $id): self
    {
        $exception = new self(
            sprintf('Agent with ID "%s" was not found', $id->toString())
        );
        $exception->errorCode = 'AGENT_NOT_FOUND';
        $exception->context = ['agent_id' => $id->toString()];

        return $exception;
    }

    public static function withName(string $name, string $userId): self
    {
        $exception = new self(
            sprintf('Agent with name "%s" was not found for user', $name)
        );
        $exception->errorCode = 'AGENT_NOT_FOUND';
        $exception->context = [
            'agent_name' => $name,
            'user_id' => $userId,
        ];

        return $exception;
    }
}

/**
 * Thrown when an agent name already exists for the user.
 */
final class DuplicateAgentNameException extends ConflictException
{
    public static function forUser(string $name, string $userId): self
    {
        $exception = new self(
            sprintf('An agent with name "%s" already exists for this user', $name)
        );
        $exception->errorCode = 'DUPLICATE_AGENT_NAME';
        $exception->context = [
            'agent_name' => $name,
            'user_id' => $userId,
        ];

        return $exception;
    }
}

/**
 * Thrown when an agent cannot be executed due to its state.
 */
final class AgentNotExecutableException extends DomainException
{
    public static function dueToStatus(AgentId $id, string $status): self
    {
        $exception = new self(
            sprintf(
                'Agent "%s" cannot be executed because it is in "%s" status',
                $id->toString(),
                $status
            )
        );
        $exception->errorCode = 'AGENT_NOT_EXECUTABLE';
        $exception->context = [
            'agent_id' => $id->toString(),
            'status' => $status,
        ];

        return $exception;
    }

    public static function missingConfiguration(AgentId $id): self
    {
        $exception = new self(
            sprintf('Agent "%s" is missing required configuration', $id->toString())
        );
        $exception->errorCode = 'AGENT_MISSING_CONFIGURATION';
        $exception->context = ['agent_id' => $id->toString()];

        return $exception;
    }
}

/**
 * Thrown when agent configuration is invalid.
 */
final class InvalidAgentConfigurationException extends DomainException
{
    public static function invalidModel(string $model): self
    {
        $exception = new self(
            sprintf('Invalid model "%s" specified for agent', $model)
        );
        $exception->errorCode = 'INVALID_AGENT_MODEL';
        $exception->context = ['model' => $model];

        return $exception;
    }

    public static function invalidTemperature(float $temperature): self
    {
        $exception = new self(
            sprintf('Temperature must be between 0.0 and 2.0, got %.2f', $temperature)
        );
        $exception->errorCode = 'INVALID_TEMPERATURE';
        $exception->context = ['temperature' => $temperature];

        return $exception;
    }

    public static function invalidMaxTokens(int $maxTokens): self
    {
        $exception = new self(
            sprintf('Max tokens must be between 1 and 128000, got %d', $maxTokens)
        );
        $exception->errorCode = 'INVALID_MAX_TOKENS';
        $exception->context = ['max_tokens' => $maxTokens];

        return $exception;
    }
}
```

### Workflow Domain Exceptions

```php
<?php

declare(strict_types=1);

namespace App\Domain\Workflow\Exception;

use App\Domain\Workflow\ValueObject\WorkflowId;
use App\Domain\Workflow\ValueObject\StepId;
use App\Shared\Exception\DomainException;
use App\Shared\Exception\NotFoundException;

final class WorkflowNotFoundException extends NotFoundException
{
    public static function withId(WorkflowId $id): self
    {
        $exception = new self(
            sprintf('Workflow with ID "%s" was not found', $id->toString())
        );
        $exception->errorCode = 'WORKFLOW_NOT_FOUND';
        $exception->context = ['workflow_id' => $id->toString()];

        return $exception;
    }
}

final class InvalidWorkflowStateException extends DomainException
{
    public static function cannotTransition(
        WorkflowId $id,
        string $fromStatus,
        string $toStatus
    ): self {
        $exception = new self(
            sprintf(
                'Workflow "%s" cannot transition from "%s" to "%s"',
                $id->toString(),
                $fromStatus,
                $toStatus
            )
        );
        $exception->errorCode = 'INVALID_WORKFLOW_TRANSITION';
        $exception->context = [
            'workflow_id' => $id->toString(),
            'from_status' => $fromStatus,
            'to_status' => $toStatus,
        ];

        return $exception;
    }
}

final class WorkflowStepFailedException extends DomainException
{
    public static function withReason(
        WorkflowId $workflowId,
        StepId $stepId,
        string $reason,
        ?\Throwable $previous = null
    ): self {
        $exception = new self(
            sprintf(
                'Step "%s" in workflow "%s" failed: %s',
                $stepId->toString(),
                $workflowId->toString(),
                $reason
            ),
            0,
            $previous
        );
        $exception->errorCode = 'WORKFLOW_STEP_FAILED';
        $exception->context = [
            'workflow_id' => $workflowId->toString(),
            'step_id' => $stepId->toString(),
            'reason' => $reason,
        ];

        return $exception;
    }
}

final class CircularWorkflowDependencyException extends DomainException
{
    public static function detected(array $stepIds): self
    {
        $exception = new self(
            'Circular dependency detected in workflow steps'
        );
        $exception->errorCode = 'CIRCULAR_WORKFLOW_DEPENDENCY';
        $exception->context = [
            'step_ids' => array_map(fn($id) => $id->toString(), $stepIds),
        ];

        return $exception;
    }
}
```

## Application Exceptions

### Command Handler Exceptions

```php
<?php

declare(strict_types=1);

namespace App\Application\Exception;

use App\Shared\Exception\ApplicationLayerException;
use App\Shared\Exception\ValidationException;

/**
 * Thrown when a command cannot be handled.
 */
final class CommandHandlerException extends ApplicationLayerException
{
    public static function handlerNotFound(string $commandClass): self
    {
        $exception = new self(
            sprintf('No handler found for command "%s"', $commandClass)
        );
        $exception->errorCode = 'HANDLER_NOT_FOUND';
        $exception->context = ['command_class' => $commandClass];

        return $exception;
    }

    public static function handlerFailed(
        string $commandClass,
        string $reason,
        ?\Throwable $previous = null
    ): self {
        $exception = new self(
            sprintf('Handler for command "%s" failed: %s', $commandClass, $reason),
            0,
            $previous
        );
        $exception->errorCode = 'HANDLER_FAILED';
        $exception->context = [
            'command_class' => $commandClass,
            'reason' => $reason,
        ];

        return $exception;
    }
}

/**
 * Thrown when command validation fails.
 */
final class CommandValidationException extends ValidationException
{
    public static function withViolations(string $commandClass, array $violations): self
    {
        $exception = new self(
            sprintf('Validation failed for command "%s"', $commandClass),
            $violations
        );
        $exception->context = ['command_class' => $commandClass];

        return $exception;
    }
}

/**
 * Thrown when a query cannot be handled.
 */
final class QueryHandlerException extends ApplicationLayerException
{
    public static function handlerNotFound(string $queryClass): self
    {
        $exception = new self(
            sprintf('No handler found for query "%s"', $queryClass)
        );
        $exception->errorCode = 'HANDLER_NOT_FOUND';
        $exception->context = ['query_class' => $queryClass];

        return $exception;
    }
}
```

### Use Case Exceptions

```php
<?php

declare(strict_types=1);

namespace App\Application\Agent\Exception;

use App\Shared\Exception\ApplicationLayerException;
use App\Shared\Exception\AuthorizationException;

final class AgentQuotaExceededException extends ApplicationLayerException
{
    public static function forUser(string $userId, int $currentCount, int $maxAllowed): self
    {
        $exception = new self(
            sprintf(
                'User has reached maximum number of agents (%d/%d)',
                $currentCount,
                $maxAllowed
            )
        );
        $exception->errorCode = 'AGENT_QUOTA_EXCEEDED';
        $exception->httpStatusCode = 429;
        $exception->context = [
            'user_id' => $userId,
            'current_count' => $currentCount,
            'max_allowed' => $maxAllowed,
        ];

        return $exception;
    }
}

final class AgentAccessDeniedException extends AuthorizationException
{
    public static function userNotOwner(string $agentId, string $userId): self
    {
        $exception = new self(
            'You do not have permission to access this agent'
        );
        $exception->errorCode = 'AGENT_ACCESS_DENIED';
        $exception->context = [
            'agent_id' => $agentId,
            'user_id' => $userId,
        ];

        return $exception;
    }
}
```

## Infrastructure Exceptions

### Database Exceptions

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Persistence\Exception;

use App\Shared\Exception\InfrastructureException;

final class DatabaseConnectionException extends InfrastructureException
{
    public static function cannotConnect(string $dsn, ?\Throwable $previous = null): self
    {
        $exception = new self(
            'Unable to establish database connection',
            0,
            $previous
        );
        $exception->errorCode = 'DATABASE_CONNECTION_FAILED';
        $exception->context = ['dsn' => self::sanitizeDsn($dsn)];

        return $exception;
    }

    private static function sanitizeDsn(string $dsn): string
    {
        // Remove password from DSN for logging
        return preg_replace('/password=[^;]+/', 'password=***', $dsn) ?? $dsn;
    }
}

final class DatabaseQueryException extends InfrastructureException
{
    public static function queryFailed(
        string $query,
        string $errorMessage,
        ?\Throwable $previous = null
    ): self {
        $exception = new self(
            'Database query failed',
            0,
            $previous
        );
        $exception->errorCode = 'DATABASE_QUERY_FAILED';
        $exception->context = [
            'query' => self::sanitizeQuery($query),
            'error' => $errorMessage,
        ];

        return $exception;
    }

    private static function sanitizeQuery(string $query): string
    {
        // Truncate long queries and remove sensitive data
        $query = substr($query, 0, 500);
        $query = preg_replace('/password\s*=\s*[\'"][^\'"]+[\'"]/', 'password=***', $query) ?? $query;

        return $query;
    }
}

final class DatabaseTransactionException extends InfrastructureException
{
    public static function cannotStart(?\Throwable $previous = null): self
    {
        $exception = new self(
            'Unable to start database transaction',
            0,
            $previous
        );
        $exception->errorCode = 'TRANSACTION_START_FAILED';

        return $exception;
    }

    public static function cannotCommit(?\Throwable $previous = null): self
    {
        $exception = new self(
            'Unable to commit database transaction',
            0,
            $previous
        );
        $exception->errorCode = 'TRANSACTION_COMMIT_FAILED';

        return $exception;
    }

    public static function cannotRollback(?\Throwable $previous = null): self
    {
        $exception = new self(
            'Unable to rollback database transaction',
            0,
            $previous
        );
        $exception->errorCode = 'TRANSACTION_ROLLBACK_FAILED';

        return $exception;
    }
}
```

### External Service Exceptions

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\ExternalService\Exception;

use App\Shared\Exception\InfrastructureException;

final class LLMServiceException extends InfrastructureException
{
    public static function apiCallFailed(
        string $provider,
        int $statusCode,
        string $responseBody,
        ?\Throwable $previous = null
    ): self {
        $exception = new self(
            sprintf('LLM API call to %s failed with status %d', $provider, $statusCode),
            0,
            $previous
        );
        $exception->errorCode = 'LLM_API_CALL_FAILED';
        $exception->context = [
            'provider' => $provider,
            'status_code' => $statusCode,
            'response_body' => substr($responseBody, 0, 500),
        ];

        return $exception;
    }

    public static function rateLimitExceeded(string $provider, ?int $retryAfter = null): self
    {
        $message = sprintf('Rate limit exceeded for %s', $provider);
        if ($retryAfter !== null) {
            $message .= sprintf(' (retry after %d seconds)', $retryAfter);
        }

        $exception = new self($message);
        $exception->errorCode = 'LLM_RATE_LIMIT_EXCEEDED';
        $exception->httpStatusCode = 429;
        $exception->context = [
            'provider' => $provider,
            'retry_after' => $retryAfter,
        ];

        return $exception;
    }

    public static function invalidApiKey(string $provider): self
    {
        $exception = new self(
            sprintf('Invalid API key for %s', $provider)
        );
        $exception->errorCode = 'LLM_INVALID_API_KEY';
        $exception->context = ['provider' => $provider];

        return $exception;
    }

    public static function timeout(string $provider, int $timeoutSeconds): self
    {
        $exception = new self(
            sprintf('Request to %s timed out after %d seconds', $provider, $timeoutSeconds)
        );
        $exception->errorCode = 'LLM_REQUEST_TIMEOUT';
        $exception->context = [
            'provider' => $provider,
            'timeout_seconds' => $timeoutSeconds,
        ];

        return $exception;
    }
}

final class MessageBrokerException extends InfrastructureException
{
    public static function cannotPublish(
        string $exchange,
        string $routingKey,
        ?\Throwable $previous = null
    ): self {
        $exception = new self(
            sprintf('Cannot publish message to exchange "%s"', $exchange),
            0,
            $previous
        );
        $exception->errorCode = 'MESSAGE_BROKER_PUBLISH_FAILED';
        $exception->context = [
            'exchange' => $exchange,
            'routing_key' => $routingKey,
        ];

        return $exception;
    }

    public static function cannotConsume(string $queue, ?\Throwable $previous = null): self
    {
        $exception = new self(
            sprintf('Cannot consume messages from queue "%s"', $queue),
            0,
            $previous
        );
        $exception->errorCode = 'MESSAGE_BROKER_CONSUME_FAILED';
        $exception->context = ['queue' => $queue];

        return $exception;
    }
}

final class CacheException extends InfrastructureException
{
    public static function cannotRead(string $key, ?\Throwable $previous = null): self
    {
        $exception = new self(
            'Cannot read from cache',
            0,
            $previous
        );
        $exception->errorCode = 'CACHE_READ_FAILED';
        $exception->context = ['key' => $key];

        return $exception;
    }

    public static function cannotWrite(string $key, ?\Throwable $previous = null): self
    {
        $exception = new self(
            'Cannot write to cache',
            0,
            $previous
        );
        $exception->errorCode = 'CACHE_WRITE_FAILED';
        $exception->context = ['key' => $key];

        return $exception;
    }
}
```

## Exception Handling Patterns

### Controller Exception Handling

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Http\Controller;

use App\Application\Agent\Command\CreateAgentCommand;
use App\Application\Exception\CommandValidationException;
use App\Domain\Agent\Exception\DuplicateAgentNameException;
use App\Shared\Exception\ApplicationException;
use Psr\Log\LoggerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Messenger\Exception\HandlerFailedException;
use Symfony\Component\Messenger\MessageBusInterface;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/api/v1/agents')]
final class AgentController extends AbstractController
{
    public function __construct(
        private readonly MessageBusInterface $commandBus,
        private readonly LoggerInterface $logger,
    ) {}

    #[Route('', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        try {
            $data = json_decode($request->getContent(), true);

            $command = new CreateAgentCommand(
                name: $data['name'] ?? '',
                model: $data['model'] ?? '',
                systemPrompt: $data['system_prompt'] ?? '',
                userId: $this->getUser()->getId()
            );

            $envelope = $this->commandBus->dispatch($command);
            $agentId = $envelope->last(HandledStamp::class)?->getResult();

            return $this->json(
                ['id' => $agentId],
                Response::HTTP_CREATED,
                ['Location' => "/api/v1/agents/{$agentId}"]
            );

        } catch (HandlerFailedException $e) {
            // Unwrap the real exception from Symfony Messenger
            return $this->handleException($e->getPrevious() ?? $e, $request);

        } catch (\Throwable $e) {
            return $this->handleException($e, $request);
        }
    }

    private function handleException(\Throwable $e, Request $request): JsonResponse
    {
        // Log the exception with context
        $this->logger->error('Request failed', [
            'exception' => get_class($e),
            'message' => $e->getMessage(),
            'file' => $e->getFile(),
            'line' => $e->getLine(),
            'trace' => $e->getTraceAsString(),
            'request_id' => $request->headers->get('X-Request-ID'),
            'user_id' => $this->getUser()?->getId(),
            'uri' => $request->getRequestUri(),
            'method' => $request->getMethod(),
        ]);

        // Handle application exceptions with proper HTTP status codes
        if ($e instanceof ApplicationException) {
            return $this->json(
                $this->formatApplicationException($e, $request),
                $e->getHttpStatusCode()
            );
        }

        // Handle validation exceptions
        if ($e instanceof CommandValidationException) {
            return $this->json(
                $this->formatValidationException($e, $request),
                Response::HTTP_UNPROCESSABLE_ENTITY
            );
        }

        // Handle all other exceptions as internal server errors
        return $this->json(
            $this->formatGenericException($request),
            Response::HTTP_INTERNAL_SERVER_ERROR
        );
    }

    private function formatApplicationException(
        ApplicationException $e,
        Request $request
    ): array {
        $response = [
            'error' => [
                'code' => $e->getErrorCode() ?? 'APPLICATION_ERROR',
                'message' => $e->getMessage(),
                'request_id' => $request->headers->get('X-Request-ID'),
            ],
        ];

        // Include context in development environment
        if ($this->getParameter('kernel.environment') === 'dev') {
            $response['error']['context'] = $e->getContext();
            $response['error']['trace'] = $e->getTraceAsString();
        }

        return $response;
    }

    private function formatValidationException(
        CommandValidationException $e,
        Request $request
    ): array {
        return [
            'error' => [
                'code' => 'VALIDATION_ERROR',
                'message' => 'The request contains invalid data',
                'violations' => $e->getViolations(),
                'request_id' => $request->headers->get('X-Request-ID'),
            ],
        ];
    }

    private function formatGenericException(Request $request): array
    {
        return [
            'error' => [
                'code' => 'INTERNAL_SERVER_ERROR',
                'message' => 'An unexpected error occurred',
                'request_id' => $request->headers->get('X-Request-ID'),
            ],
        ];
    }
}
```

### Global Exception Handler

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Http\EventListener;

use App\Shared\Exception\ApplicationException;
use App\Shared\Exception\AuthenticationException;
use App\Shared\Exception\AuthorizationException;
use App\Shared\Exception\ValidationException;
use Psr\Log\LoggerInterface;
use Symfony\Component\EventDispatcher\Attribute\AsEventListener;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Event\ExceptionEvent;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\KernelInterface;

#[AsEventListener(event: ExceptionEvent::class)]
final class ExceptionListener
{
    public function __construct(
        private readonly LoggerInterface $logger,
        private readonly KernelInterface $kernel,
    ) {}

    public function __invoke(ExceptionEvent $event): void
    {
        $exception = $event->getThrowable();
        $request = $event->getRequest();

        // Log exception based on severity
        $this->logException($exception, $request);

        // Determine HTTP status code
        $statusCode = $this->getStatusCode($exception);

        // Format error response
        $responseData = $this->formatErrorResponse($exception, $request);

        // Create JSON response
        $response = new JsonResponse($responseData, $statusCode);

        // Set response
        $event->setResponse($response);
    }

    private function logException(\Throwable $exception, $request): void
    {
        $context = [
            'exception' => get_class($exception),
            'message' => $exception->getMessage(),
            'file' => $exception->getFile(),
            'line' => $exception->getLine(),
            'request_id' => $request->headers->get('X-Request-ID'),
            'uri' => $request->getRequestUri(),
            'method' => $request->getMethod(),
        ];

        if ($exception instanceof ApplicationException) {
            $context = array_merge($context, $exception->getContext());
        }

        // Log level based on exception type and status code
        if ($exception instanceof AuthenticationException
            || $exception instanceof AuthorizationException
        ) {
            $this->logger->warning('Access denied', $context);
        } elseif ($exception instanceof ValidationException) {
            $this->logger->info('Validation failed', $context);
        } elseif ($this->getStatusCode($exception) >= 500) {
            $this->logger->error('Server error', $context);
        } else {
            $this->logger->notice('Client error', $context);
        }
    }

    private function getStatusCode(\Throwable $exception): int
    {
        if ($exception instanceof ApplicationException) {
            return $exception->getHttpStatusCode();
        }

        if ($exception instanceof HttpExceptionInterface) {
            return $exception->getStatusCode();
        }

        return Response::HTTP_INTERNAL_SERVER_ERROR;
    }

    private function formatErrorResponse(\Throwable $exception, $request): array
    {
        $isDev = $this->kernel->getEnvironment() === 'dev';

        $response = [
            'error' => [
                'code' => $this->getErrorCode($exception),
                'message' => $this->getErrorMessage($exception),
                'request_id' => $request->headers->get('X-Request-ID'),
            ],
        ];

        // Add validation violations
        if ($exception instanceof ValidationException) {
            $response['error']['violations'] = $exception->getViolations();
        }

        // Add context in development
        if ($isDev) {
            $response['error']['context'] = $this->getExceptionContext($exception);
            $response['error']['trace'] = $exception->getTraceAsString();
        }

        return $response;
    }

    private function getErrorCode(\Throwable $exception): string
    {
        if ($exception instanceof ApplicationException && $exception->getErrorCode()) {
            return $exception->getErrorCode();
        }

        $statusCode = $this->getStatusCode($exception);

        return match ($statusCode) {
            400 => 'BAD_REQUEST',
            401 => 'UNAUTHORIZED',
            403 => 'FORBIDDEN',
            404 => 'NOT_FOUND',
            409 => 'CONFLICT',
            422 => 'UNPROCESSABLE_ENTITY',
            429 => 'TOO_MANY_REQUESTS',
            default => 'INTERNAL_SERVER_ERROR',
        };
    }

    private function getErrorMessage(\Throwable $exception): string
    {
        $statusCode = $this->getStatusCode($exception);

        // For 5xx errors, don't expose internal details in production
        if ($statusCode >= 500 && $this->kernel->getEnvironment() === 'prod') {
            return 'An unexpected error occurred';
        }

        return $exception->getMessage();
    }

    private function getExceptionContext(\Throwable $exception): array
    {
        $context = [
            'class' => get_class($exception),
            'file' => $exception->getFile(),
            'line' => $exception->getLine(),
        ];

        if ($exception instanceof ApplicationException) {
            $context['app_context'] = $exception->getContext();
        }

        if ($previous = $exception->getPrevious()) {
            $context['previous'] = [
                'class' => get_class($previous),
                'message' => $previous->getMessage(),
            ];
        }

        return $context;
    }
}
```

### Service Layer Try-Catch Patterns

```php
<?php

declare(strict_types=1);

namespace App\Application\Agent\CommandHandler;

use App\Application\Agent\Command\CreateAgentCommand;
use App\Application\Exception\CommandHandlerException;
use App\Domain\Agent\Agent;
use App\Domain\Agent\AgentRepositoryInterface;
use App\Domain\Agent\Exception\DuplicateAgentNameException;
use App\Domain\Agent\ValueObject\AgentId;
use App\Infrastructure\Persistence\Exception\DatabaseException;
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
        try {
            // Check for duplicate name
            if ($this->repository->existsByNameAndUserId($command->name, $command->userId)) {
                throw DuplicateAgentNameException::forUser(
                    $command->name,
                    $command->userId
                );
            }

            // Create agent
            $agent = Agent::create(
                id: AgentId::generate(),
                userId: $command->userId,
                name: $command->name,
                model: $command->model,
                systemPrompt: $command->systemPrompt
            );

            // Persist
            $this->repository->save($agent);

            $this->logger->info('Agent created', [
                'agent_id' => $agent->getId()->toString(),
                'user_id' => $command->userId,
                'name' => $command->name,
            ]);

            return $agent->getId()->toString();

        } catch (DuplicateAgentNameException $e) {
            // Domain exception - let it bubble up
            throw $e;

        } catch (DatabaseException $e) {
            // Infrastructure exception - wrap with context
            $this->logger->error('Failed to create agent due to database error', [
                'command' => get_class($command),
                'user_id' => $command->userId,
                'exception' => $e->getMessage(),
            ]);

            throw CommandHandlerException::handlerFailed(
                get_class($command),
                'Database error occurred',
                $e
            );

        } catch (\Throwable $e) {
            // Unexpected exception - log and wrap
            $this->logger->critical('Unexpected error creating agent', [
                'command' => get_class($command),
                'user_id' => $command->userId,
                'exception' => get_class($e),
                'message' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            throw CommandHandlerException::handlerFailed(
                get_class($command),
                'Unexpected error occurred',
                $e
            );
        }
    }
}
```

## Error Response Formats

### Standardized Error Response

```json
{
  "error": {
    "code": "AGENT_NOT_FOUND",
    "message": "Agent with ID \"01234567-89ab-cdef-0123-456789abcdef\" was not found",
    "request_id": "req-abc123xyz789"
  }
}
```

### Validation Error Response

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The request contains invalid data",
    "violations": [
      {
        "field": "name",
        "message": "Name must be at least 3 characters long"
      },
      {
        "field": "model",
        "message": "Model must be one of: gpt-4, gpt-3.5-turbo, claude-3-opus"
      }
    ],
    "request_id": "req-abc123xyz789"
  }
}
```

### Authorization Error Response

```json
{
  "error": {
    "code": "AGENT_ACCESS_DENIED",
    "message": "You do not have permission to access this agent",
    "request_id": "req-abc123xyz789"
  }
}
```

### Rate Limit Error Response

```json
{
  "error": {
    "code": "LLM_RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded for openai (retry after 60 seconds)",
    "request_id": "req-abc123xyz789",
    "retry_after": 60
  }
}
```

## Logging and Monitoring

### Structured Logging

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Logging;

use Psr\Log\LoggerInterface;

final class ExceptionLogger
{
    public function __construct(
        private readonly LoggerInterface $logger,
    ) {}

    public function logException(
        \Throwable $exception,
        string $context = 'application',
        array $additionalData = []
    ): void {
        $severity = $this->determineSeverity($exception);

        $logData = [
            'exception_class' => get_class($exception),
            'message' => $exception->getMessage(),
            'code' => $exception->getCode(),
            'file' => $exception->getFile(),
            'line' => $exception->getLine(),
            'context' => $context,
            'trace' => $this->sanitizeTrace($exception->getTraceAsString()),
        ];

        if ($exception instanceof ApplicationException) {
            $logData['error_code'] = $exception->getErrorCode();
            $logData['app_context'] = $exception->getContext();
        }

        if ($previous = $exception->getPrevious()) {
            $logData['previous_exception'] = [
                'class' => get_class($previous),
                'message' => $previous->getMessage(),
            ];
        }

        $logData = array_merge($logData, $additionalData);

        match ($severity) {
            'critical' => $this->logger->critical('Critical exception occurred', $logData),
            'error' => $this->logger->error('Exception occurred', $logData),
            'warning' => $this->logger->warning('Exception occurred', $logData),
            default => $this->logger->notice('Exception occurred', $logData),
        };
    }

    private function determineSeverity(\Throwable $exception): string
    {
        // Database failures are critical
        if ($exception instanceof DatabaseConnectionException) {
            return 'critical';
        }

        // Infrastructure failures are errors
        if ($exception instanceof InfrastructureException) {
            return 'error';
        }

        // Authentication/Authorization are warnings
        if ($exception instanceof AuthenticationException
            || $exception instanceof AuthorizationException
        ) {
            return 'warning';
        }

        // Default to notice
        return 'notice';
    }

    private function sanitizeTrace(string $trace): string
    {
        // Remove sensitive data from stack traces
        $trace = preg_replace('/password[\'"]?\s*=>?\s*[\'"]([^\'"]+)[\'"]/', 'password=>***', $trace);
        $trace = preg_replace('/token[\'"]?\s*=>?\s*[\'"]([^\'"]+)[\'"]/', 'token=>***', $trace);

        return $trace ?? '';
    }
}
```

### Monitoring Integration

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Monitoring;

use App\Shared\Exception\ApplicationException;
use Prometheus\CollectorRegistry;

final class ErrorMetricsCollector
{
    private Counter $errorCounter;
    private Histogram $errorDuration;

    public function __construct(
        private readonly CollectorRegistry $registry,
    ) {
        $this->errorCounter = $registry->getOrRegisterCounter(
            'app',
            'errors_total',
            'Total number of errors',
            ['type', 'code', 'severity']
        );

        $this->errorDuration = $registry->getOrRegisterHistogram(
            'app',
            'error_processing_duration_seconds',
            'Time spent processing errors',
            ['type']
        );
    }

    public function recordError(\Throwable $exception): void
    {
        $type = $this->getExceptionType($exception);
        $code = $exception instanceof ApplicationException
            ? $exception->getErrorCode() ?? 'unknown'
            : 'unknown';
        $severity = $this->getSeverity($exception);

        $this->errorCounter->inc([$type, $code, $severity]);
    }

    private function getExceptionType(\Throwable $exception): string
    {
        return match (true) {
            $exception instanceof DomainException => 'domain',
            $exception instanceof ApplicationLayerException => 'application',
            $exception instanceof InfrastructureException => 'infrastructure',
            $exception instanceof ValidationException => 'validation',
            $exception instanceof AuthorizationException => 'authorization',
            $exception instanceof AuthenticationException => 'authentication',
            default => 'unknown',
        };
    }

    private function getSeverity(\Throwable $exception): string
    {
        if ($exception instanceof ApplicationException) {
            $statusCode = $exception->getHttpStatusCode();

            return match (true) {
                $statusCode >= 500 => 'critical',
                $statusCode >= 400 => 'warning',
                default => 'info',
            };
        }

        return 'error';
    }
}
```

## Recovery Strategies

### Retry Logic

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Resilience;

use App\Infrastructure\ExternalService\Exception\LLMServiceException;
use Psr\Log\LoggerInterface;

final class RetryHandler
{
    private const MAX_ATTEMPTS = 3;
    private const INITIAL_DELAY_MS = 100;
    private const MAX_DELAY_MS = 5000;

    public function __construct(
        private readonly LoggerInterface $logger,
    ) {}

    /**
     * Execute a callable with exponential backoff retry logic.
     *
     * @template T
     * @param callable(): T $operation
     * @param array<class-string<\Throwable>> $retryableExceptions
     * @param int $maxAttempts
     * @return T
     */
    public function execute(
        callable $operation,
        array $retryableExceptions = [],
        int $maxAttempts = self::MAX_ATTEMPTS
    ): mixed {
        $attempt = 1;
        $lastException = null;

        while ($attempt <= $maxAttempts) {
            try {
                return $operation();

            } catch (\Throwable $e) {
                $lastException = $e;

                // Check if exception is retryable
                if (!$this->isRetryable($e, $retryableExceptions)) {
                    throw $e;
                }

                // Don't retry on last attempt
                if ($attempt >= $maxAttempts) {
                    break;
                }

                // Calculate delay with exponential backoff
                $delay = min(
                    self::INITIAL_DELAY_MS * (2 ** ($attempt - 1)),
                    self::MAX_DELAY_MS
                );

                $this->logger->warning('Operation failed, retrying', [
                    'attempt' => $attempt,
                    'max_attempts' => $maxAttempts,
                    'delay_ms' => $delay,
                    'exception' => get_class($e),
                    'message' => $e->getMessage(),
                ]);

                // Sleep with jitter
                usleep($delay * 1000 + random_int(0, 100 * 1000));

                $attempt++;
            }
        }

        throw $lastException;
    }

    private function isRetryable(\Throwable $e, array $retryableExceptions): bool
    {
        // Empty list means retry all exceptions
        if (empty($retryableExceptions)) {
            return true;
        }

        foreach ($retryableExceptions as $exceptionClass) {
            if ($e instanceof $exceptionClass) {
                return true;
            }
        }

        return false;
    }
}

// Usage example
final class LLMServiceAdapter
{
    public function __construct(
        private readonly HttpClientInterface $client,
        private readonly RetryHandler $retryHandler,
    ) {}

    public function complete(string $prompt): string
    {
        return $this->retryHandler->execute(
            operation: fn() => $this->doComplete($prompt),
            retryableExceptions: [
                LLMServiceException::class,
                \RuntimeException::class,
            ],
            maxAttempts: 3
        );
    }

    private function doComplete(string $prompt): string
    {
        // Make API call
        $response = $this->client->request('POST', '/completions', [
            'json' => ['prompt' => $prompt],
        ]);

        if ($response->getStatusCode() !== 200) {
            throw LLMServiceException::apiCallFailed(
                'openai',
                $response->getStatusCode(),
                $response->getContent()
            );
        }

        return $response->toArray()['completion'];
    }
}
```

### Circuit Breaker

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Resilience;

use Psr\Cache\CacheItemPoolInterface;
use Psr\Log\LoggerInterface;

final class CircuitBreaker
{
    private const STATE_CLOSED = 'closed';
    private const STATE_OPEN = 'open';
    private const STATE_HALF_OPEN = 'half_open';

    public function __construct(
        private readonly CacheItemPoolInterface $cache,
        private readonly LoggerInterface $logger,
        private readonly int $failureThreshold = 5,
        private readonly int $successThreshold = 2,
        private readonly int $timeout = 60,
    ) {}

    /**
     * Execute operation with circuit breaker protection.
     *
     * @template T
     * @param string $serviceName
     * @param callable(): T $operation
     * @return T
     */
    public function execute(string $serviceName, callable $operation): mixed
    {
        $state = $this->getState($serviceName);

        if ($state === self::STATE_OPEN) {
            if ($this->shouldAttemptReset($serviceName)) {
                $this->setState($serviceName, self::STATE_HALF_OPEN);
            } else {
                throw new CircuitBreakerOpenException(
                    sprintf('Circuit breaker is open for service: %s', $serviceName)
                );
            }
        }

        try {
            $result = $operation();
            $this->onSuccess($serviceName);

            return $result;

        } catch (\Throwable $e) {
            $this->onFailure($serviceName);
            throw $e;
        }
    }

    private function onSuccess(string $serviceName): void
    {
        $state = $this->getState($serviceName);

        if ($state === self::STATE_HALF_OPEN) {
            $successCount = $this->incrementSuccessCount($serviceName);

            if ($successCount >= $this->successThreshold) {
                $this->logger->info('Circuit breaker closed', [
                    'service' => $serviceName,
                ]);
                $this->setState($serviceName, self::STATE_CLOSED);
                $this->resetCounters($serviceName);
            }
        } elseif ($state === self::STATE_CLOSED) {
            $this->resetCounters($serviceName);
        }
    }

    private function onFailure(string $serviceName): void
    {
        $failureCount = $this->incrementFailureCount($serviceName);

        if ($failureCount >= $this->failureThreshold) {
            $this->logger->warning('Circuit breaker opened', [
                'service' => $serviceName,
                'failure_count' => $failureCount,
            ]);
            $this->setState($serviceName, self::STATE_OPEN);
            $this->setOpenedAt($serviceName, time());
        }
    }

    private function shouldAttemptReset(string $serviceName): bool
    {
        $openedAt = $this->getOpenedAt($serviceName);

        return $openedAt !== null && (time() - $openedAt) >= $this->timeout;
    }

    private function getState(string $serviceName): string
    {
        $item = $this->cache->getItem("circuit_breaker.{$serviceName}.state");

        return $item->isHit() ? $item->get() : self::STATE_CLOSED;
    }

    private function setState(string $serviceName, string $state): void
    {
        $item = $this->cache->getItem("circuit_breaker.{$serviceName}.state");
        $item->set($state);
        $this->cache->save($item);
    }

    private function incrementFailureCount(string $serviceName): int
    {
        $item = $this->cache->getItem("circuit_breaker.{$serviceName}.failures");
        $count = $item->isHit() ? $item->get() + 1 : 1;
        $item->set($count);
        $this->cache->save($item);

        return $count;
    }

    private function incrementSuccessCount(string $serviceName): int
    {
        $item = $this->cache->getItem("circuit_breaker.{$serviceName}.successes");
        $count = $item->isHit() ? $item->get() + 1 : 1;
        $item->set($count);
        $this->cache->save($item);

        return $count;
    }

    private function resetCounters(string $serviceName): void
    {
        $this->cache->deleteItems([
            "circuit_breaker.{$serviceName}.failures",
            "circuit_breaker.{$serviceName}.successes",
            "circuit_breaker.{$serviceName}.opened_at",
        ]);
    }

    private function setOpenedAt(string $serviceName, int $timestamp): void
    {
        $item = $this->cache->getItem("circuit_breaker.{$serviceName}.opened_at");
        $item->set($timestamp);
        $this->cache->save($item);
    }

    private function getOpenedAt(string $serviceName): ?int
    {
        $item = $this->cache->getItem("circuit_breaker.{$serviceName}.opened_at");

        return $item->isHit() ? $item->get() : null;
    }
}

final class CircuitBreakerOpenException extends \RuntimeException
{
}
```

## User-Facing Error Messages

### Error Message Guidelines

**DO:**
- Be clear and specific about what went wrong
- Provide actionable steps for resolution
- Use plain language without technical jargon
- Include relevant identifiers (request ID, etc.)

**DON'T:**
- Expose internal implementation details
- Include stack traces or file paths
- Reveal sensitive information
- Use vague messages like "Something went wrong"

### Error Message Examples

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\ErrorMessage;

final class UserFriendlyErrorMessages
{
    public static function agentNotFound(string $agentId): string
    {
        return sprintf(
            "We couldn't find the agent you're looking for (ID: %s). " .
            "Please check the agent ID and try again.",
            $agentId
        );
    }

    public static function agentQuotaExceeded(int $maxAllowed): string
    {
        return sprintf(
            "You've reached the maximum number of agents (%d) for your account. " .
            "Please upgrade your plan or delete unused agents to create new ones.",
            $maxAllowed
        );
    }

    public static function duplicateAgentName(string $name): string
    {
        return sprintf(
            "You already have an agent named '%s'. " .
            "Please choose a different name.",
            $name
        );
    }

    public static function invalidConfiguration(string $field, string $reason): string
    {
        return sprintf(
            "The configuration value for '%s' is invalid: %s",
            $field,
            $reason
        );
    }

    public static function serviceUnavailable(string $serviceName): string
    {
        return sprintf(
            "The %s service is temporarily unavailable. " .
            "Please try again in a few moments.",
            $serviceName
        );
    }

    public static function rateLimitExceeded(int $retryAfterSeconds): string
    {
        return sprintf(
            "You've made too many requests. " .
            "Please wait %d seconds before trying again.",
            $retryAfterSeconds
        );
    }

    public static function authenticationRequired(): string
    {
        return "You must be logged in to perform this action. " .
               "Please log in and try again.";
    }

    public static function accessDenied(string $resource): string
    {
        return sprintf(
            "You don't have permission to access this %s. " .
            "Please contact your administrator if you believe this is an error.",
            $resource
        );
    }

    public static function validationFailed(array $violations): string
    {
        $messages = array_map(
            fn($v) => sprintf("- %s: %s", $v['field'], $v['message']),
            $violations
        );

        return "The request contains invalid data:\n" . implode("\n", $messages);
    }
}
```

## Testing Error Scenarios

### Unit Testing Exceptions

```php
<?php

declare(strict_types=1);

namespace App\Tests\Unit\Domain\Agent;

use App\Domain\Agent\Agent;
use App\Domain\Agent\Exception\InvalidAgentConfigurationException;
use App\Domain\Agent\ValueObject\AgentId;
use PHPUnit\Framework\TestCase;

final class AgentTest extends TestCase
{
    public function test_it_throws_exception_for_invalid_temperature(): void
    {
        // Arrange
        $this->expectException(InvalidAgentConfigurationException::class);
        $this->expectExceptionMessage('Temperature must be between 0.0 and 2.0');

        // Act
        Agent::create(
            id: AgentId::generate(),
            userId: 'user-123',
            name: 'Test Agent',
            model: 'gpt-4',
            systemPrompt: 'Test',
            temperature: 3.0 // Invalid
        );
    }

    public function test_it_includes_context_in_exception(): void
    {
        // Arrange & Act
        try {
            Agent::create(
                id: AgentId::generate(),
                userId: 'user-123',
                name: 'Test Agent',
                model: 'gpt-4',
                systemPrompt: 'Test',
                temperature: 3.0
            );

            $this->fail('Expected exception was not thrown');

        } catch (InvalidAgentConfigurationException $e) {
            // Assert
            $this->assertSame('INVALID_TEMPERATURE', $e->getErrorCode());
            $this->assertArrayHasKey('temperature', $e->getContext());
            $this->assertSame(3.0, $e->getContext()['temperature']);
        }
    }
}
```

### Integration Testing Error Handling

```php
<?php

declare(strict_types=1);

namespace App\Tests\Integration\Application\Agent;

use App\Application\Agent\Command\CreateAgentCommand;
use App\Domain\Agent\Exception\DuplicateAgentNameException;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;
use Symfony\Component\Messenger\MessageBusInterface;

final class CreateAgentCommandHandlerTest extends KernelTestCase
{
    private MessageBusInterface $commandBus;

    protected function setUp(): void
    {
        self::bootKernel();
        $this->commandBus = self::getContainer()->get(MessageBusInterface::class);
    }

    public function test_it_throws_exception_for_duplicate_name(): void
    {
        // Arrange
        $command1 = new CreateAgentCommand(
            name: 'Test Agent',
            model: 'gpt-4',
            systemPrompt: 'Test',
            userId: 'user-123'
        );

        $this->commandBus->dispatch($command1);

        // Act & Assert
        $this->expectException(DuplicateAgentNameException::class);

        $command2 = new CreateAgentCommand(
            name: 'Test Agent',
            model: 'gpt-4',
            systemPrompt: 'Test',
            userId: 'user-123'
        );

        $this->commandBus->dispatch($command2);
    }
}
```

### API Testing Error Responses

```php
<?php

declare(strict_types=1);

namespace App\Tests\Functional\Api;

use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;

final class AgentApiTest extends WebTestCase
{
    public function test_it_returns_404_for_nonexistent_agent(): void
    {
        // Arrange
        $client = static::createClient();

        // Act
        $client->request('GET', '/api/v1/agents/00000000-0000-0000-0000-000000000000');

        // Assert
        $this->assertResponseStatusCodeSame(Response::HTTP_NOT_FOUND);

        $responseData = json_decode($client->getResponse()->getContent(), true);

        $this->assertArrayHasKey('error', $responseData);
        $this->assertSame('AGENT_NOT_FOUND', $responseData['error']['code']);
        $this->assertArrayHasKey('message', $responseData['error']);
        $this->assertArrayHasKey('request_id', $responseData['error']);
    }

    public function test_it_returns_422_for_validation_errors(): void
    {
        // Arrange
        $client = static::createClient();

        // Act
        $client->request('POST', '/api/v1/agents', [], [], [
            'CONTENT_TYPE' => 'application/json',
        ], json_encode([
            'name' => 'AB', // Too short
            'model' => 'invalid-model',
        ]));

        // Assert
        $this->assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);

        $responseData = json_decode($client->getResponse()->getContent(), true);

        $this->assertArrayHasKey('error', $responseData);
        $this->assertSame('VALIDATION_ERROR', $responseData['error']['code']);
        $this->assertArrayHasKey('violations', $responseData['error']);
        $this->assertGreaterThan(0, count($responseData['error']['violations']));
    }

    public function test_it_returns_403_for_unauthorized_access(): void
    {
        // Arrange
        $client = static::createClient();
        $agentId = $this->createAgentForDifferentUser();

        // Act
        $client->request('DELETE', "/api/v1/agents/{$agentId}");

        // Assert
        $this->assertResponseStatusCodeSame(Response::HTTP_FORBIDDEN);

        $responseData = json_decode($client->getResponse()->getContent(), true);

        $this->assertSame('AGENT_ACCESS_DENIED', $responseData['error']['code']);
    }
}
```

## Summary

This error handling strategy provides:

1. **Comprehensive Exception Hierarchy**: Well-organized exceptions for domain, application, and infrastructure layers
2. **Consistent Error Handling**: Standardized patterns across all architectural layers
3. **Operational Visibility**: Detailed logging and monitoring of all errors
4. **User Experience**: Clear, actionable error messages for API consumers
5. **Resilience**: Retry logic and circuit breakers for handling transient failures
6. **Testability**: All error scenarios are fully testable

The strategy ensures errors are detected early, handled appropriately, logged comprehensively, and communicated clearly to users while maintaining security by not exposing sensitive implementation details.
