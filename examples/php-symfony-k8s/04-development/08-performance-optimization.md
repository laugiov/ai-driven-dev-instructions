# Performance Optimization Guide

## Table of Contents

1. [Introduction](#introduction)
2. [Performance Goals and Metrics](#performance-goals-and-metrics)
3. [PHP Performance Optimization](#php-performance-optimization)
4. [Database Optimization](#database-optimization)
5. [Caching Strategies](#caching-strategies)
6. [API Performance](#api-performance)
7. [Asynchronous Processing](#asynchronous-processing)
8. [Memory Management](#memory-management)
9. [Profiling and Monitoring](#profiling-and-monitoring)
10. [Load Testing](#load-testing)
11. [Common Performance Antipatterns](#common-performance-antipatterns)

## Introduction

This document provides comprehensive guidelines for optimizing the performance of the AI Workflow Processing Platform. Performance optimization is critical for delivering excellent user experience, managing infrastructure costs, and ensuring system scalability.

### Performance Principles

**Measure First**: Always measure before optimizing. Use profiling tools to identify actual bottlenecks.

**Optimize for Common Cases**: Focus optimization efforts on code paths that are executed most frequently.

**Balance Trade-offs**: Consider trade-offs between performance, maintainability, and complexity.

**Design for Performance**: Build performance considerations into the architecture from the start.

**Monitor Continuously**: Implement comprehensive monitoring to detect performance regressions early.

**Cache Aggressively**: Use caching at multiple layers to reduce redundant computations and queries.

## Performance Goals and Metrics

### Target Performance Metrics

**API Response Times:**
- P50 (median): < 100ms
- P95: < 200ms
- P99: < 500ms
- Maximum: < 2000ms

**Database Query Performance:**
- Simple queries: < 10ms
- Complex queries: < 50ms
- Aggregations: < 100ms
- Maximum query time: < 500ms

**Memory Usage:**
- Per request: < 50MB
- PHP-FPM worker: < 128MB
- Background jobs: < 256MB

**Throughput:**
- API Gateway: 10,000 requests/second
- BFF Service: 5,000 requests/second
- LLM Agent Service: 1,000 requests/second (limited by LLM provider)
- Workflow Orchestrator: 500 workflows/second

**Resource Utilization:**
- CPU: < 70% average, < 90% peak
- Memory: < 80% average, < 95% peak
- Database connections: < 80% of pool size

### Service Level Objectives (SLOs)

```yaml
# config/slo.yaml
slos:
  api_availability:
    target: 99.9%
    window: 30d

  api_latency_p95:
    target: 200ms
    window: 24h

  api_error_rate:
    target: 0.1%
    window: 1h

  database_query_latency_p95:
    target: 50ms
    window: 1h
```

## PHP Performance Optimization

### OPcache Configuration

```ini
; config/php/opcache.ini

; Enable OPcache
opcache.enable=1
opcache.enable_cli=0

; Memory settings
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000

; Revalidation
opcache.revalidate_freq=0
opcache.validate_timestamps=0  ; Disable in production

; Optimization settings
opcache.optimization_level=0x7FFEBFFF
opcache.save_comments=1
opcache.enable_file_override=1

; JIT compilation (PHP 8+)
opcache.jit_buffer_size=128M
opcache.jit=tracing

; Preloading
opcache.preload=/var/www/html/config/preload.php
opcache.preload_user=www-data
```

### Preloading Configuration

```php
<?php
// config/preload.php

declare(strict_types=1);

// Preload the application for improved performance
// This loads frequently used classes into memory before handling requests

if (PHP_VERSION_ID < 70400) {
    return;
}

$projectRoot = dirname(__DIR__);

require_once $projectRoot . '/vendor/autoload.php';

// Preload Symfony kernel
require_once $projectRoot . '/src/Kernel.php';

// Preload commonly used classes
$classesToPreload = [
    // Domain entities
    \App\Domain\Agent\Agent::class,
    \App\Domain\Workflow\Workflow::class,
    \App\Domain\Workflow\WorkflowStep::class,

    // Value objects
    \App\Domain\Agent\ValueObject\AgentId::class,
    \App\Domain\Workflow\ValueObject\WorkflowId::class,
    \App\Domain\Workflow\ValueObject\StepId::class,

    // Commands
    \App\Application\Agent\Command\CreateAgentCommand::class,
    \App\Application\Agent\Command\UpdateAgentCommand::class,
    \App\Application\Workflow\Command\ExecuteWorkflowCommand::class,

    // Queries
    \App\Application\Agent\Query\GetAgentQuery::class,
    \App\Application\Agent\Query\ListAgentsQuery::class,

    // Exceptions
    \App\Domain\Agent\Exception\AgentNotFoundException::class,
    \App\Domain\Workflow\Exception\WorkflowNotFoundException::class,

    // Repositories
    \App\Infrastructure\Persistence\Agent\DoctrineAgentRepository::class,
    \App\Infrastructure\Persistence\Workflow\DoctrineWorkflowRepository::class,
];

foreach ($classesToPreload as $class) {
    if (class_exists($class)) {
        opcache_compile_file(
            (new \ReflectionClass($class))->getFileName()
        );
    }
}

// Preload Symfony components
$symfonyClasses = [
    \Symfony\Component\HttpFoundation\Request::class,
    \Symfony\Component\HttpFoundation\Response::class,
    \Symfony\Component\HttpFoundation\JsonResponse::class,
    \Symfony\Component\Messenger\MessageBusInterface::class,
    \Symfony\Component\Validator\Validator\ValidatorInterface::class,
    \Symfony\Component\Serializer\SerializerInterface::class,
];

foreach ($symfonyClasses as $class) {
    if (class_exists($class)) {
        opcache_compile_file(
            (new \ReflectionClass($class))->getFileName()
        );
    }
}
```

### PHP-FPM Tuning

```ini
; config/php/php-fpm.conf

[global]
error_log = /var/log/php-fpm/error.log
emergency_restart_threshold = 10
emergency_restart_interval = 1m
process_control_timeout = 10s

[www]
user = www-data
group = www-data

listen = 9000
listen.backlog = 65535

; Process management
pm = dynamic
pm.max_children = 50
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 20
pm.max_requests = 500

; Slow log
slowlog = /var/log/php-fpm/slow.log
request_slowlog_timeout = 5s

; Resource limits
pm.process_idle_timeout = 10s
pm.max_spawn_rate = 10

; Status
pm.status_path = /status
ping.path = /ping
```

### Efficient Object Creation

```php
<?php

declare(strict_types=1);

namespace App\Domain\Agent;

use App\Domain\Agent\ValueObject\AgentId;

final class Agent
{
    private function __construct(
        private readonly AgentId $id,
        private readonly string $userId,
        private string $name,
        private string $model,
        private string $systemPrompt,
        private array $configuration,
        private string $status,
        private \DateTimeImmutable $createdAt,
        private \DateTimeImmutable $updatedAt,
    ) {}

    /**
     * Named constructor for creating new agents.
     */
    public static function create(
        AgentId $id,
        string $userId,
        string $name,
        string $model,
        string $systemPrompt
    ): self {
        $now = new \DateTimeImmutable();

        return new self(
            id: $id,
            userId: $userId,
            name: $name,
            model: $model,
            systemPrompt: $systemPrompt,
            configuration: [],
            status: 'active',
            createdAt: $now,
            updatedAt: $now,
        );
    }

    /**
     * Named constructor for hydrating from database.
     * Use this instead of reflection-based hydration for better performance.
     */
    public static function fromDatabase(array $data): self
    {
        return new self(
            id: AgentId::fromString($data['id']),
            userId: $data['user_id'],
            name: $data['name'],
            model: $data['model'],
            systemPrompt: $data['system_prompt'],
            configuration: json_decode($data['configuration'], true),
            status: $data['status'],
            createdAt: new \DateTimeImmutable($data['created_at']),
            updatedAt: new \DateTimeImmutable($data['updated_at']),
        );
    }

    // Getters...
}
```

### Lazy Loading

```php
<?php

declare(strict_types=1);

namespace App\Domain\Workflow;

use App\Domain\Workflow\ValueObject\WorkflowId;
use App\Domain\Workflow\ValueObject\StepId;

final class Workflow
{
    private ?array $steps = null;
    private ?array $executions = null;

    private function __construct(
        private readonly WorkflowId $id,
        private readonly string $userId,
        private string $name,
        private string $description,
        private string $status,
        private readonly \DateTimeImmutable $createdAt,
        private \DateTimeImmutable $updatedAt,
    ) {}

    /**
     * Lazy load workflow steps only when needed.
     */
    public function getSteps(): array
    {
        if ($this->steps === null) {
            // Steps will be loaded by repository when first accessed
            throw new \LogicException('Steps not loaded. Use repository->loadSteps()');
        }

        return $this->steps;
    }

    /**
     * Set steps after loading from repository.
     *
     * @internal Used by repository for hydration
     */
    public function setSteps(array $steps): void
    {
        $this->steps = $steps;
    }

    /**
     * Check if steps are loaded without triggering load.
     */
    public function hasLoadedSteps(): bool
    {
        return $this->steps !== null;
    }
}

// Repository implementation
final class DoctrineWorkflowRepository implements WorkflowRepositoryInterface
{
    public function findById(WorkflowId $id): ?Workflow
    {
        $data = $this->connection->fetchAssociative(
            'SELECT * FROM workflows WHERE id = ?',
            [$id->toString()]
        );

        if (!$data) {
            return null;
        }

        // Create workflow without loading steps
        return Workflow::fromDatabase($data);
    }

    public function findByIdWithSteps(WorkflowId $id): ?Workflow
    {
        $workflow = $this->findById($id);

        if ($workflow === null) {
            return null;
        }

        // Load steps separately
        $this->loadSteps($workflow);

        return $workflow;
    }

    public function loadSteps(Workflow $workflow): void
    {
        if ($workflow->hasLoadedSteps()) {
            return;
        }

        $stepsData = $this->connection->fetchAllAssociative(
            'SELECT * FROM workflow_steps WHERE workflow_id = ? ORDER BY order_index',
            [$workflow->getId()->toString()]
        );

        $steps = array_map(
            fn($data) => WorkflowStep::fromDatabase($data),
            $stepsData
        );

        $workflow->setSteps($steps);
    }
}
```

### String Operations Optimization

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Serializer;

final class JsonSerializer
{
    /**
     * Efficient JSON encoding with flags.
     */
    public function serialize(mixed $data): string
    {
        // Use JSON_THROW_ON_ERROR for better performance (no need to check return value)
        // Use JSON_UNESCAPED_SLASHES and JSON_UNESCAPED_UNICODE for smaller output
        return json_encode(
            $data,
            JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE
        );
    }

    /**
     * Efficient JSON decoding.
     */
    public function deserialize(string $json): mixed
    {
        return json_decode($json, true, 512, JSON_THROW_ON_ERROR);
    }
}

// String concatenation optimization
final class QueryBuilder
{
    /**
     * GOOD: Use array implode for multiple concatenations.
     */
    public function buildQuery(array $conditions): string
    {
        $parts = ['SELECT * FROM agents WHERE 1=1'];

        foreach ($conditions as $field => $value) {
            $parts[] = "AND {$field} = ?";
        }

        return implode(' ', $parts);
    }

    /**
     * BAD: String concatenation in loop.
     */
    public function buildQuerySlow(array $conditions): string
    {
        $query = 'SELECT * FROM agents WHERE 1=1';

        foreach ($conditions as $field => $value) {
            $query .= " AND {$field} = ?";  // Creates new string each iteration
        }

        return $query;
    }
}
```

## Database Optimization

### Query Optimization

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Persistence\Agent;

use Doctrine\DBAL\Connection;

final class OptimizedAgentQueries
{
    public function __construct(
        private readonly Connection $connection,
    ) {}

    /**
     * GOOD: Select only needed columns.
     */
    public function getAgentSummary(string $userId): array
    {
        return $this->connection->fetchAllAssociative(
            'SELECT id, name, model, status, created_at
             FROM agents
             WHERE user_id = ?
             ORDER BY created_at DESC
             LIMIT 100',
            [$userId]
        );
    }

    /**
     * BAD: Selecting all columns when not needed.
     */
    public function getAgentSummarySlow(string $userId): array
    {
        return $this->connection->fetchAllAssociative(
            'SELECT * FROM agents WHERE user_id = ? ORDER BY created_at DESC',
            [$userId]
        );
    }

    /**
     * GOOD: Use JOIN instead of separate queries (avoiding N+1).
     */
    public function getAgentsWithExecutionCount(string $userId): array
    {
        return $this->connection->fetchAllAssociative(
            'SELECT
                a.id,
                a.name,
                a.model,
                COUNT(ae.id) as execution_count,
                MAX(ae.created_at) as last_execution
             FROM agents a
             LEFT JOIN agent_executions ae ON ae.agent_id = a.id
             WHERE a.user_id = ?
             GROUP BY a.id, a.name, a.model
             ORDER BY last_execution DESC NULLS LAST',
            [$userId]
        );
    }

    /**
     * GOOD: Use EXISTS for existence checks instead of COUNT.
     */
    public function hasActiveWorkflows(string $userId): bool
    {
        $result = $this->connection->fetchOne(
            'SELECT EXISTS(
                SELECT 1
                FROM workflows
                WHERE user_id = ?
                AND status IN (?, ?)
                LIMIT 1
            )',
            [$userId, 'running', 'pending']
        );

        return (bool) $result;
    }

    /**
     * BAD: Using COUNT when only checking existence.
     */
    public function hasActiveWorkflowsSlow(string $userId): bool
    {
        $count = $this->connection->fetchOne(
            'SELECT COUNT(*)
             FROM workflows
             WHERE user_id = ?
             AND status IN (?, ?)',
            [$userId, 'running', 'pending']
        );

        return $count > 0;
    }

    /**
     * GOOD: Batch operations to reduce round trips.
     */
    public function updateMultipleAgentStatuses(array $agentIds, string $status): void
    {
        if (empty($agentIds)) {
            return;
        }

        $placeholders = implode(',', array_fill(0, count($agentIds), '?'));
        $params = [...$agentIds, $status];

        $this->connection->executeStatement(
            "UPDATE agents
             SET status = ?, updated_at = NOW()
             WHERE id IN ({$placeholders})",
            array_reverse($params)  // Reverse because status comes first in query
        );
    }

    /**
     * GOOD: Use CTEs for complex queries.
     */
    public function getWorkflowStatistics(string $userId): array
    {
        return $this->connection->fetchAssociative(
            'WITH workflow_stats AS (
                SELECT
                    workflow_id,
                    COUNT(*) as execution_count,
                    AVG(EXTRACT(EPOCH FROM (completed_at - started_at))) as avg_duration_seconds,
                    SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) as success_count,
                    SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) as failure_count
                FROM workflow_executions
                WHERE created_at > NOW() - INTERVAL \'30 days\'
                GROUP BY workflow_id
            )
            SELECT
                w.id,
                w.name,
                COALESCE(ws.execution_count, 0) as execution_count,
                COALESCE(ws.avg_duration_seconds, 0) as avg_duration_seconds,
                COALESCE(ws.success_count, 0) as success_count,
                COALESCE(ws.failure_count, 0) as failure_count,
                CASE
                    WHEN ws.execution_count > 0
                    THEN ROUND((ws.success_count::numeric / ws.execution_count) * 100, 2)
                    ELSE 0
                END as success_rate
            FROM workflows w
            LEFT JOIN workflow_stats ws ON ws.workflow_id = w.id
            WHERE w.user_id = ?
            ORDER BY ws.execution_count DESC NULLS LAST',
            ['completed', 'failed', $userId]
        );
    }
}
```

### Index Optimization

```sql
-- Use partial indexes for filtered queries
CREATE INDEX idx_agents_active_user
ON agents(user_id, created_at DESC)
WHERE status = 'active';

-- Use covering indexes to avoid table lookups
CREATE INDEX idx_agents_summary
ON agents(user_id, name, model, status, created_at)
WHERE status IN ('active', 'paused');

-- Use expression indexes for computed values
CREATE INDEX idx_workflows_name_lower
ON workflows(LOWER(name));

-- Use multi-column indexes with proper column order
-- Rule: Equality conditions first, then range conditions, then sort columns
CREATE INDEX idx_workflow_executions_composite
ON workflow_executions(workflow_id, status, created_at DESC);

-- Analyze index usage
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan ASC;

-- Find unused indexes
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
AND idx_scan = 0
AND indexname NOT LIKE '%_pkey';
```

### Connection Pooling

```yaml
# config/packages/doctrine.yaml
doctrine:
    dbal:
        driver: 'pdo_pgsql'
        server_version: '15'
        charset: utf8

        # Connection pooling with PgBouncer
        host: '%env(DATABASE_HOST)%'  # PgBouncer host
        port: 6432                     # PgBouncer port

        # Options for optimal pooling
        options:
            # Disable prepared statements with PgBouncer in transaction mode
            !php/const PDO::ATTR_EMULATE_PREPARES: true

        # Connection limits
        connections:
            default:
                pooling: true
                pool_size: 20
                max_connections: 100

    orm:
        # Query caching
        metadata_cache_driver:
            type: redis
            host: '%env(REDIS_HOST)%'
            port: 6379

        query_cache_driver:
            type: redis
            host: '%env(REDIS_HOST)%'
            port: 6379

        result_cache_driver:
            type: redis
            host: '%env(REDIS_HOST)%'
            port: 6379
```

### Query Result Caching

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Persistence\Agent;

use Doctrine\DBAL\Connection;
use Psr\Cache\CacheItemPoolInterface;

final class CachedAgentRepository implements AgentRepositoryInterface
{
    private const CACHE_TTL = 300; // 5 minutes

    public function __construct(
        private readonly Connection $connection,
        private readonly CacheItemPoolInterface $cache,
    ) {}

    public function findById(AgentId $id): ?Agent
    {
        $cacheKey = "agent.{$id->toString()}";
        $cacheItem = $this->cache->getItem($cacheKey);

        if ($cacheItem->isHit()) {
            return $cacheItem->get();
        }

        $data = $this->connection->fetchAssociative(
            'SELECT * FROM agents WHERE id = ?',
            [$id->toString()]
        );

        if (!$data) {
            return null;
        }

        $agent = Agent::fromDatabase($data);

        $cacheItem->set($agent);
        $cacheItem->expiresAfter(self::CACHE_TTL);
        $this->cache->save($cacheItem);

        return $agent;
    }

    public function save(Agent $agent): void
    {
        // Save to database
        $this->connection->executeStatement(
            'INSERT INTO agents (id, user_id, name, model, system_prompt, configuration, status, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
             ON CONFLICT (id) DO UPDATE SET
                name = EXCLUDED.name,
                model = EXCLUDED.model,
                system_prompt = EXCLUDED.system_prompt,
                configuration = EXCLUDED.configuration,
                status = EXCLUDED.status,
                updated_at = EXCLUDED.updated_at',
            [
                $agent->getId()->toString(),
                $agent->getUserId(),
                $agent->getName(),
                $agent->getModel(),
                $agent->getSystemPrompt(),
                json_encode($agent->getConfiguration()),
                $agent->getStatus(),
                $agent->getCreatedAt()->format('Y-m-d H:i:s'),
                $agent->getUpdatedAt()->format('Y-m-d H:i:s'),
            ]
        );

        // Invalidate cache
        $this->cache->deleteItem("agent.{$agent->getId()->toString()}");
        $this->cache->deleteItem("agents.user.{$agent->getUserId()}");
    }

    public function findByUserId(string $userId, int $limit = 100, int $offset = 0): array
    {
        $cacheKey = "agents.user.{$userId}.{$limit}.{$offset}";
        $cacheItem = $this->cache->getItem($cacheKey);

        if ($cacheItem->isHit()) {
            return $cacheItem->get();
        }

        $data = $this->connection->fetchAllAssociative(
            'SELECT * FROM agents
             WHERE user_id = ?
             ORDER BY created_at DESC
             LIMIT ? OFFSET ?',
            [$userId, $limit, $offset]
        );

        $agents = array_map(
            fn($row) => Agent::fromDatabase($row),
            $data
        );

        $cacheItem->set($agents);
        $cacheItem->expiresAfter(self::CACHE_TTL);
        $this->cache->save($cacheItem);

        return $agents;
    }
}
```

## Caching Strategies

### Multi-Layer Caching

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Cache;

use Psr\Cache\CacheItemPoolInterface;

/**
 * Two-tier caching: Local (APCu) + Distributed (Redis).
 */
final class TwoTierCache implements CacheItemPoolInterface
{
    public function __construct(
        private readonly CacheItemPoolInterface $localCache,   // APCu
        private readonly CacheItemPoolInterface $distributedCache,  // Redis
        private readonly int $localTtl = 60,
    ) {}

    public function getItem(string $key): CacheItemInterface
    {
        // Check local cache first
        $localItem = $this->localCache->getItem($key);
        if ($localItem->isHit()) {
            return $localItem;
        }

        // Check distributed cache
        $distributedItem = $this->distributedCache->getItem($key);
        if ($distributedItem->isHit()) {
            // Populate local cache
            $localItem->set($distributedItem->get());
            $localItem->expiresAfter($this->localTtl);
            $this->localCache->save($localItem);

            return $distributedItem;
        }

        return $distributedItem;
    }

    public function save(CacheItemInterface $item): bool
    {
        // Save to both caches
        $distributedSaved = $this->distributedCache->save($item);

        $localItem = $this->localCache->getItem($item->getKey());
        $localItem->set($item->get());
        $localItem->expiresAfter($this->localTtl);
        $localSaved = $this->localCache->save($localItem);

        return $distributedSaved && $localSaved;
    }

    public function deleteItem(string $key): bool
    {
        $localDeleted = $this->localCache->deleteItem($key);
        $distributedDeleted = $this->distributedCache->deleteItem($key);

        return $localDeleted && $distributedDeleted;
    }

    // Implement other CacheItemPoolInterface methods...
}
```

### HTTP Caching

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Http\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/api/v1/agents')]
final class AgentController extends AbstractController
{
    #[Route('/{id}', methods: ['GET'])]
    public function get(string $id, Request $request): Response
    {
        $agent = $this->queryBus->query(new GetAgentQuery($id));

        if ($agent === null) {
            return $this->json(['error' => 'Agent not found'], Response::HTTP_NOT_FOUND);
        }

        $response = $this->json($agent);

        // Set cache headers
        $response->setMaxAge(300);          // Browser cache: 5 minutes
        $response->setSharedMaxAge(600);    // CDN cache: 10 minutes
        $response->setPublic();              // Allow public caching

        // ETag for conditional requests
        $etag = md5(json_encode($agent));
        $response->setETag($etag);

        // Last-Modified header
        $response->setLastModified($agent->getUpdatedAt());

        // Check if client has fresh version
        if ($response->isNotModified($request)) {
            return $response;
        }

        // Vary header for content negotiation
        $response->setVary(['Accept', 'Accept-Encoding', 'Accept-Language']);

        return $response;
    }

    #[Route('', methods: ['GET'])]
    public function list(Request $request): Response
    {
        $userId = $this->getUser()->getId();
        $agents = $this->queryBus->query(new ListAgentsQuery($userId));

        $response = $this->json(['data' => $agents]);

        // Shorter cache for list endpoints
        $response->setMaxAge(60);           // 1 minute
        $response->setSharedMaxAge(120);    // 2 minutes
        $response->setPublic();

        // Vary by user (using custom header)
        $response->setVary(['Accept', 'X-User-ID']);

        return $response;
    }
}
```

### Cache Warming

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Cache;

use Psr\Cache\CacheItemPoolInterface;
use Psr\Log\LoggerInterface;

final class CacheWarmer
{
    public function __construct(
        private readonly AgentRepositoryInterface $agentRepository,
        private readonly CacheItemPoolInterface $cache,
        private readonly LoggerInterface $logger,
    ) {}

    /**
     * Warm cache with frequently accessed data.
     */
    public function warmAgentCache(array $userIds): void
    {
        $startTime = microtime(true);
        $warmedCount = 0;

        foreach ($userIds as $userId) {
            try {
                // Load user's agents
                $agents = $this->agentRepository->findByUserId($userId);

                foreach ($agents as $agent) {
                    $cacheKey = "agent.{$agent->getId()->toString()}";
                    $cacheItem = $this->cache->getItem($cacheKey);

                    if (!$cacheItem->isHit()) {
                        $cacheItem->set($agent);
                        $cacheItem->expiresAfter(300);
                        $this->cache->save($cacheItem);
                        $warmedCount++;
                    }
                }

            } catch (\Throwable $e) {
                $this->logger->error('Cache warming failed for user', [
                    'user_id' => $userId,
                    'exception' => $e->getMessage(),
                ]);
            }
        }

        $duration = microtime(true) - $startTime;

        $this->logger->info('Cache warming completed', [
            'duration_seconds' => round($duration, 2),
            'items_warmed' => $warmedCount,
        ]);
    }

    /**
     * Warm cache for most active users.
     */
    public function warmPopularData(): void
    {
        // Get most active users from the last 24 hours
        $activeUsers = $this->connection->fetchFirstColumn(
            'SELECT DISTINCT user_id
             FROM agent_executions
             WHERE created_at > NOW() - INTERVAL \'24 hours\'
             ORDER BY created_at DESC
             LIMIT 1000'
        );

        $this->warmAgentCache($activeUsers);
    }
}
```

### Cache Invalidation

```php
<?php

declare(strict_types=1);

namespace App\Application\Agent\EventSubscriber;

use App\Domain\Agent\Event\AgentCreated;
use App\Domain\Agent\Event\AgentUpdated;
use App\Domain\Agent\Event\AgentDeleted;
use Psr\Cache\CacheItemPoolInterface;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;

final class AgentCacheInvalidationSubscriber implements EventSubscriberInterface
{
    public function __construct(
        private readonly CacheItemPoolInterface $cache,
    ) {}

    public static function getSubscribedEvents(): array
    {
        return [
            AgentCreated::class => 'onAgentCreated',
            AgentUpdated::class => 'onAgentUpdated',
            AgentDeleted::class => 'onAgentDeleted',
        ];
    }

    public function onAgentCreated(AgentCreated $event): void
    {
        // Invalidate user's agent list cache
        $this->invalidateUserAgentsList($event->getUserId());
    }

    public function onAgentUpdated(AgentUpdated $event): void
    {
        // Invalidate specific agent cache
        $this->cache->deleteItem("agent.{$event->getAgentId()}");

        // Invalidate user's agent list cache
        $this->invalidateUserAgentsList($event->getUserId());
    }

    public function onAgentDeleted(AgentDeleted $event): void
    {
        // Invalidate specific agent cache
        $this->cache->deleteItem("agent.{$event->getAgentId()}");

        // Invalidate user's agent list cache
        $this->invalidateUserAgentsList($event->getUserId());
    }

    private function invalidateUserAgentsList(string $userId): void
    {
        // Invalidate all pagination combinations
        // In production, consider using cache tags instead
        for ($offset = 0; $offset < 1000; $offset += 100) {
            $this->cache->deleteItem("agents.user.{$userId}.100.{$offset}");
        }
    }
}
```

## API Performance

### Response Compression

```yaml
# config/packages/framework.yaml
framework:
    http_client:
        default_options:
            headers:
                'Accept-Encoding': 'gzip, deflate'

# Nginx configuration
# /etc/nginx/nginx.conf
http {
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/rss+xml
        application/atom+xml
        image/svg+xml;
    gzip_min_length 1000;
}
```

### Pagination Optimization

```php
<?php

declare(strict_types=1);

namespace App\Application\Agent\Query;

final class ListAgentsQuery
{
    public function __construct(
        public readonly string $userId,
        public readonly int $page = 1,
        public readonly int $perPage = 100,
        public readonly ?string $sortBy = 'created_at',
        public readonly string $sortOrder = 'desc',
    ) {
        if ($this->perPage > 100) {
            throw new \InvalidArgumentException('Maximum page size is 100');
        }

        if ($this->perPage < 1) {
            throw new \InvalidArgumentException('Minimum page size is 1');
        }
    }

    public function getOffset(): int
    {
        return ($this->page - 1) * $this->perPage;
    }
}

final class ListAgentsQueryHandler
{
    public function __construct(
        private readonly Connection $connection,
    ) {}

    public function __invoke(ListAgentsQuery $query): array
    {
        // Use cursor-based pagination for better performance on large datasets
        $sql = '
            SELECT id, user_id, name, model, status, created_at, updated_at
            FROM agents
            WHERE user_id = ?
            ORDER BY created_at DESC
            LIMIT ?
            OFFSET ?
        ';

        $agents = $this->connection->fetchAllAssociative(
            $sql,
            [
                $query->userId,
                $query->perPage,
                $query->getOffset(),
            ]
        );

        // Get total count for pagination metadata (cached)
        $totalCount = $this->getTotalCount($query->userId);

        return [
            'data' => $agents,
            'pagination' => [
                'current_page' => $query->page,
                'per_page' => $query->perPage,
                'total' => $totalCount,
                'total_pages' => (int) ceil($totalCount / $query->perPage),
            ],
        ];
    }

    private function getTotalCount(string $userId): int
    {
        // Cache total count as it doesn't change often
        $cacheKey = "agents.count.{$userId}";
        // Implementation omitted for brevity

        return $this->connection->fetchOne(
            'SELECT COUNT(*) FROM agents WHERE user_id = ?',
            [$userId]
        );
    }
}
```

### Field Selection (Sparse Fieldsets)

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Http\Controller;

use Symfony\Component\HttpFoundation\Request;

#[Route('/api/v1/agents')]
final class AgentController extends AbstractController
{
    #[Route('', methods: ['GET'])]
    public function list(Request $request): Response
    {
        $userId = $this->getUser()->getId();

        // Parse fields parameter: ?fields=id,name,model
        $requestedFields = $this->parseFields($request);

        $query = new ListAgentsQuery(
            userId: $userId,
            fields: $requestedFields
        );

        $agents = $this->queryBus->query($query);

        return $this->json(['data' => $agents]);
    }

    private function parseFields(Request $request): ?array
    {
        $fieldsParam = $request->query->get('fields');

        if ($fieldsParam === null) {
            return null;  // Return all fields
        }

        $fields = array_map('trim', explode(',', $fieldsParam));

        // Validate requested fields
        $allowedFields = ['id', 'name', 'model', 'status', 'created_at', 'updated_at'];
        $validFields = array_intersect($fields, $allowedFields);

        // Always include ID
        if (!in_array('id', $validFields, true)) {
            $validFields[] = 'id';
        }

        return $validFields;
    }
}

// Query handler with field selection
final class ListAgentsQueryHandler
{
    public function __invoke(ListAgentsQuery $query): array
    {
        // Build SELECT clause based on requested fields
        $fields = $query->fields ?? ['id', 'user_id', 'name', 'model', 'status', 'created_at', 'updated_at'];
        $selectClause = implode(', ', $fields);

        $sql = "
            SELECT {$selectClause}
            FROM agents
            WHERE user_id = ?
            ORDER BY created_at DESC
            LIMIT ? OFFSET ?
        ";

        return $this->connection->fetchAllAssociative(
            $sql,
            [
                $query->userId,
                $query->perPage,
                $query->getOffset(),
            ]
        );
    }
}
```

## Asynchronous Processing

### Message Queue Configuration

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\MessageQueue;

use App\Application\Agent\Command\ExecuteAgentCommand;
use App\Application\Workflow\Command\ExecuteWorkflowCommand;
use Symfony\Component\Messenger\Attribute\AsMessageHandler;

// High-priority queue for user-facing operations
#[AsMessageHandler(
    fromTransport: 'high_priority',
    priority: 10
)]
final class ExecuteAgentCommandHandler
{
    public function __invoke(ExecuteAgentCommand $command): void
    {
        // Execute agent synchronously or async depending on configuration
    }
}

// Low-priority queue for background tasks
#[AsMessageHandler(
    fromTransport: 'low_priority',
    priority: 1
)]
final class WorkflowCleanupHandler
{
    public function __invoke(CleanupOldWorkflowsCommand $command): void
    {
        // Clean up old workflow data
    }
}
```

```yaml
# config/packages/messenger.yaml
framework:
    messenger:
        failure_transport: failed

        transports:
            # High priority - user-facing operations
            high_priority:
                dsn: '%env(RABBITMQ_DSN)%'
                options:
                    exchange:
                        name: high_priority
                        type: direct
                    queues:
                        high_priority:
                            binding_keys: ['#']
                retry_strategy:
                    max_retries: 3
                    delay: 1000
                    multiplier: 2
                    max_delay: 10000

            # Default priority - standard operations
            async:
                dsn: '%env(RABBITMQ_DSN)%'
                options:
                    exchange:
                        name: async
                        type: direct
                    queues:
                        async:
                            binding_keys: ['#']
                retry_strategy:
                    max_retries: 3
                    delay: 1000
                    multiplier: 2

            # Low priority - background tasks
            low_priority:
                dsn: '%env(RABBITMQ_DSN)%'
                options:
                    exchange:
                        name: low_priority
                        type: direct
                    queues:
                        low_priority:
                            binding_keys: ['#']
                retry_strategy:
                    max_retries: 5
                    delay: 5000

            # Failed messages
            failed: 'doctrine://default?queue_name=failed'

        routing:
            App\Application\Agent\Command\ExecuteAgentCommand: high_priority
            App\Application\Workflow\Command\ExecuteWorkflowCommand: high_priority
            App\Application\Notification\Command\SendNotificationCommand: async
            App\Application\Audit\Command\LogAuditEventCommand: low_priority
```

### Async Event Processing

```php
<?php

declare(strict_types=1);

namespace App\Domain\Agent\Event;

use Symfony\Component\Messenger\Attribute\AsMessage;

#[AsMessage(transport: 'async')]
final readonly class AgentExecutionCompleted
{
    public function __construct(
        public string $agentId,
        public string $executionId,
        public string $status,
        public float $durationSeconds,
        public int $tokensUsed,
        public \DateTimeImmutable $completedAt,
    ) {}
}

// Event subscriber for async processing
final class AgentExecutionCompletedSubscriber
{
    public function __construct(
        private readonly MetricsCollector $metrics,
        private readonly NotificationService $notifications,
    ) {}

    public function __invoke(AgentExecutionCompleted $event): void
    {
        // Record metrics (non-blocking)
        $this->metrics->recordAgentExecution(
            $event->agentId,
            $event->durationSeconds,
            $event->tokensUsed
        );

        // Send notification if execution took too long
        if ($event->durationSeconds > 30.0) {
            $this->notifications->sendSlowExecutionAlert($event);
        }
    }
}
```

## Memory Management

### Memory-Efficient Batch Processing

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Batch;

use Doctrine\DBAL\Connection;

final class BatchProcessor
{
    private const BATCH_SIZE = 1000;

    public function __construct(
        private readonly Connection $connection,
    ) {}

    /**
     * Process large dataset in batches to avoid memory exhaustion.
     */
    public function processAllAgents(callable $processor): void
    {
        $offset = 0;
        $processedCount = 0;

        while (true) {
            // Fetch batch
            $agents = $this->connection->fetchAllAssociative(
                'SELECT * FROM agents ORDER BY id LIMIT ? OFFSET ?',
                [self::BATCH_SIZE, $offset]
            );

            if (empty($agents)) {
                break;
            }

            foreach ($agents as $agentData) {
                $processor($agentData);
                $processedCount++;
            }

            $offset += self::BATCH_SIZE;

            // Force garbage collection after each batch
            gc_collect_cycles();

            // Log progress
            if ($processedCount % 10000 === 0) {
                $memoryUsage = memory_get_usage(true) / 1024 / 1024;
                echo sprintf(
                    "Processed %d agents (Memory: %.2f MB)\n",
                    $processedCount,
                    $memoryUsage
                );
            }
        }
    }

    /**
     * Stream large result set using generator.
     */
    public function streamAgents(): \Generator
    {
        $stmt = $this->connection->executeQuery('SELECT * FROM agents ORDER BY id');

        while ($row = $stmt->fetchAssociative()) {
            yield Agent::fromDatabase($row);
        }
    }
}

// Usage
$processor = new BatchProcessor($connection);

foreach ($processor->streamAgents() as $agent) {
    // Process agent
    // Memory usage remains constant as only one agent is in memory at a time
}
```

### Resource Cleanup

```php
<?php

declare(strict_types=1);

namespace App\Application\Workflow\CommandHandler;

final class ExecuteWorkflowCommandHandler
{
    public function __invoke(ExecuteWorkflowCommand $command): void
    {
        $workflow = null;
        $connection = null;

        try {
            // Acquire resources
            $connection = $this->connectionPool->acquire();
            $workflow = $this->workflowRepository->findById($command->workflowId);

            // Execute workflow
            $result = $workflow->execute();

            // Commit
            $connection->commit();

        } catch (\Throwable $e) {
            // Rollback on error
            $connection?->rollBack();
            throw $e;

        } finally {
            // Always release resources
            if ($connection !== null) {
                $this->connectionPool->release($connection);
            }

            // Clear large objects from memory
            $workflow = null;
            $result = null;

            // Force garbage collection for long-running processes
            if (memory_get_usage(true) > 100 * 1024 * 1024) {  // > 100MB
                gc_collect_cycles();
            }
        }
    }
}
```

## Profiling and Monitoring

### Blackfire Integration

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Profiling;

use Blackfire\Client;
use Blackfire\Profile\Configuration;

final class BlackfireProfiler
{
    public function __construct(
        private readonly Client $blackfire,
    ) {}

    /**
     * Profile a specific operation.
     */
    public function profile(string $title, callable $operation): mixed
    {
        $config = new Configuration();
        $config->setTitle($title);
        $config->setSamples(10);

        $probe = $this->blackfire->createProbe($config);

        try {
            $result = $operation();

            return $result;

        } finally {
            $this->blackfire->endProbe($probe);
        }
    }
}

// Usage
$profiler = new BlackfireProfiler($blackfireClient);

$result = $profiler->profile('Agent Execution', function() {
    return $this->agentExecutor->execute($agentId, $input);
});
```

### Custom Performance Monitoring

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Monitoring;

use Psr\Log\LoggerInterface;
use Prometheus\CollectorRegistry;

final class PerformanceMonitor
{
    private Histogram $requestDuration;
    private Histogram $dbQueryDuration;
    private Counter $queryCounter;

    public function __construct(
        private readonly CollectorRegistry $registry,
        private readonly LoggerInterface $logger,
    ) {
        $this->requestDuration = $registry->getOrRegisterHistogram(
            'app',
            'http_request_duration_seconds',
            'HTTP request duration',
            ['method', 'route', 'status'],
            [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
        );

        $this->dbQueryDuration = $registry->getOrRegisterHistogram(
            'app',
            'db_query_duration_seconds',
            'Database query duration',
            ['query_type'],
            [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0]
        );

        $this->queryCounter = $registry->getOrRegisterCounter(
            'app',
            'db_queries_total',
            'Total database queries',
            ['query_type', 'status']
        );
    }

    public function measureRequest(string $method, string $route, callable $operation): mixed
    {
        $startTime = microtime(true);
        $startMemory = memory_get_usage(true);

        try {
            $result = $operation();
            $status = 'success';

            return $result;

        } catch (\Throwable $e) {
            $status = 'error';
            throw $e;

        } finally {
            $duration = microtime(true) - $startTime;
            $memoryUsed = memory_get_usage(true) - $startMemory;

            $this->requestDuration->observe($duration, [$method, $route, $status]);

            // Log slow requests
            if ($duration > 1.0) {
                $this->logger->warning('Slow request detected', [
                    'method' => $method,
                    'route' => $route,
                    'duration_seconds' => round($duration, 3),
                    'memory_mb' => round($memoryUsed / 1024 / 1024, 2),
                ]);
            }
        }
    }

    public function measureQuery(string $queryType, callable $query): mixed
    {
        $startTime = microtime(true);

        try {
            $result = $query();
            $status = 'success';

            return $result;

        } catch (\Throwable $e) {
            $status = 'error';
            throw $e;

        } finally {
            $duration = microtime(true) - $startTime;

            $this->dbQueryDuration->observe($duration, [$queryType]);
            $this->queryCounter->inc([$queryType, $status]);

            // Log slow queries
            if ($duration > 0.1) {
                $this->logger->warning('Slow query detected', [
                    'query_type' => $queryType,
                    'duration_seconds' => round($duration, 3),
                ]);
            }
        }
    }
}
```

## Load Testing

### K6 Load Test Scripts

```javascript
// tests/load/agent-execution.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');

// Test configuration
export const options = {
  stages: [
    { duration: '2m', target: 100 },   // Ramp up to 100 users
    { duration: '5m', target: 100 },   // Stay at 100 users
    { duration: '2m', target: 200 },   // Ramp up to 200 users
    { duration: '5m', target: 200 },   // Stay at 200 users
    { duration: '2m', target: 0 },     // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<200', 'p(99)<500'],
    errors: ['rate<0.01'],
    http_req_failed: ['rate<0.01'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8000';
const API_KEY = __ENV.API_KEY;

export default function() {
  // Create agent
  let createRes = http.post(
    `${BASE_URL}/api/v1/agents`,
    JSON.stringify({
      name: `Test Agent ${__VU}-${__ITER}`,
      model: 'gpt-4',
      system_prompt: 'You are a helpful assistant.',
    }),
    {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${API_KEY}`,
      },
    }
  );

  check(createRes, {
    'agent created successfully': (r) => r.status === 201,
    'agent has id': (r) => JSON.parse(r.body).id !== undefined,
  }) || errorRate.add(1);

  if (createRes.status !== 201) {
    console.error(`Failed to create agent: ${createRes.status} ${createRes.body}`);
    return;
  }

  const agentId = JSON.parse(createRes.body).id;

  sleep(1);

  // Execute agent
  let executeRes = http.post(
    `${BASE_URL}/api/v1/agents/${agentId}/execute`,
    JSON.stringify({
      input: 'What is the capital of France?',
    }),
    {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${API_KEY}`,
      },
    }
  );

  check(executeRes, {
    'agent executed successfully': (r) => r.status === 200,
    'response has output': (r) => JSON.parse(r.body).output !== undefined,
    'response time < 2s': (r) => r.timings.duration < 2000,
  }) || errorRate.add(1);

  sleep(1);

  // Get agent
  let getRes = http.get(
    `${BASE_URL}/api/v1/agents/${agentId}`,
    {
      headers: {
        'Authorization': `Bearer ${API_KEY}`,
      },
    }
  );

  check(getRes, {
    'agent retrieved successfully': (r) => r.status === 200,
    'response time < 100ms': (r) => r.timings.duration < 100,
  }) || errorRate.add(1);

  sleep(1);

  // Delete agent
  let deleteRes = http.del(
    `${BASE_URL}/api/v1/agents/${agentId}`,
    null,
    {
      headers: {
        'Authorization': `Bearer ${API_KEY}`,
      },
    }
  );

  check(deleteRes, {
    'agent deleted successfully': (r) => r.status === 204,
  }) || errorRate.add(1);

  sleep(1);
}

// Teardown function
export function teardown(data) {
  console.log('Load test completed');
}
```

```bash
#!/bin/bash
# tests/load/run-load-tests.sh

set -e

echo "Starting load tests..."

# Workflow execution load test
echo "Running workflow execution load test..."
k6 run \
  --out json=results/workflow-load-test.json \
  --summary-export=results/workflow-summary.json \
  tests/load/workflow-execution.js

# Agent execution load test
echo "Running agent execution load test..."
k6 run \
  --out json=results/agent-load-test.json \
  --summary-export=results/agent-summary.json \
  tests/load/agent-execution.js

# Spike test
echo "Running spike test..."
k6 run \
  --stage "0s:0,10s:1000,20s:0" \
  --out json=results/spike-test.json \
  tests/load/spike-test.js

# Stress test
echo "Running stress test..."
k6 run \
  --stage "5m:100,10m:200,15m:300,20m:400,25m:500" \
  --out json=results/stress-test.json \
  tests/load/stress-test.js

echo "Load tests completed! Results saved to results/ directory."
```

## Common Performance Antipatterns

### N+1 Query Problem

```php
<?php

// BAD: N+1 queries
final class WorkflowListService
{
    public function getUserWorkflows(string $userId): array
    {
        $workflows = $this->connection->fetchAllAssociative(
            'SELECT * FROM workflows WHERE user_id = ?',
            [$userId]
        );

        $result = [];
        foreach ($workflows as $workflow) {
            // This executes a query for each workflow!
            $stepCount = $this->connection->fetchOne(
                'SELECT COUNT(*) FROM workflow_steps WHERE workflow_id = ?',
                [$workflow['id']]
            );

            $result[] = [
                'id' => $workflow['id'],
                'name' => $workflow['name'],
                'step_count' => $stepCount,
            ];
        }

        return $result;
    }
}

// GOOD: Single query with JOIN
final class WorkflowListService
{
    public function getUserWorkflows(string $userId): array
    {
        return $this->connection->fetchAllAssociative(
            'SELECT
                w.id,
                w.name,
                COUNT(ws.id) as step_count
             FROM workflows w
             LEFT JOIN workflow_steps ws ON ws.workflow_id = w.id
             WHERE w.user_id = ?
             GROUP BY w.id, w.name',
            [$userId]
        );
    }
}
```

### Premature Optimization

```php
<?php

// BAD: Overly complex optimization that hurts readability
final class AgentExecutor
{
    public function execute(string $agentId, string $input): string
    {
        // Unreadable one-liner that saves microseconds
        return $this->cache->remember("agent.{$agentId}.result." . md5($input), 3600, fn() => $this->llm->complete($this->agents[$agentId] ?? throw new AgentNotFoundException(), $input));
    }
}

// GOOD: Clear code with measured optimization
final class AgentExecutor
{
    public function execute(string $agentId, string $input): string
    {
        // Check cache (worthwhile optimization based on profiling)
        $cacheKey = "agent.{$agentId}.result." . md5($input);
        $cached = $this->cache->get($cacheKey);

        if ($cached !== null) {
            return $cached;
        }

        // Load agent
        $agent = $this->agentRepository->findById(AgentId::fromString($agentId));

        if ($agent === null) {
            throw AgentNotFoundException::withId(AgentId::fromString($agentId));
        }

        // Execute
        $result = $this->llm->complete($agent, $input);

        // Cache result
        $this->cache->set($cacheKey, $result, 3600);

        return $result;
    }
}
```

### Inefficient Loops

```php
<?php

// BAD: Inefficient array operations in loop
$activeAgents = [];
foreach ($allAgents as $agent) {
    if ($agent['status'] === 'active') {
        $activeAgents[] = $agent;
    }
}

// GOOD: Use array_filter
$activeAgents = array_filter(
    $allAgents,
    fn($agent) => $agent['status'] === 'active'
);

// BAD: Multiple loops over same data
$activeCount = 0;
foreach ($agents as $agent) {
    if ($agent['status'] === 'active') {
        $activeCount++;
    }
}

$inactiveCount = 0;
foreach ($agents as $agent) {
    if ($agent['status'] === 'inactive') {
        $inactiveCount++;
    }
}

// GOOD: Single loop
$statusCounts = array_reduce(
    $agents,
    function($carry, $agent) {
        $carry[$agent['status']] = ($carry[$agent['status']] ?? 0) + 1;
        return $carry;
    },
    []
);

$activeCount = $statusCounts['active'] ?? 0;
$inactiveCount = $statusCounts['inactive'] ?? 0;
```

## Summary

This performance optimization guide provides:

1. **PHP Optimization**: OPcache, preloading, PHP-FPM tuning for optimal PHP performance
2. **Database Optimization**: Query optimization, indexing strategies, connection pooling
3. **Caching**: Multi-layer caching, HTTP caching, cache warming and invalidation
4. **API Performance**: Compression, pagination, field selection
5. **Async Processing**: Message queues, event-driven architecture
6. **Memory Management**: Batch processing, resource cleanup, generators
7. **Profiling**: Blackfire integration, custom monitoring
8. **Load Testing**: K6 scripts for various load scenarios
9. **Antipatterns**: Common performance mistakes and their solutions

Follow these guidelines to ensure the platform delivers excellent performance at scale while maintaining code quality and maintainability.
