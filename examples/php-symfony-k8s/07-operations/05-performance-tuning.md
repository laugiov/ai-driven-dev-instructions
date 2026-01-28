# Performance Tuning

## Table of Contents

1. [Overview](#overview)
2. [Performance Baselines](#performance-baselines)
3. [Application Performance](#application-performance)
4. [Database Optimization](#database-optimization)
5. [Caching Strategies](#caching-strategies)
6. [Network Optimization](#network-optimization)
7. [Resource Optimization](#resource-optimization)
8. [Load Testing](#load-testing)
9. [Performance Monitoring](#performance-monitoring)
10. [Optimization Checklist](#optimization-checklist)

## Overview

### Purpose

Performance tuning ensures the platform delivers:
- Fast response times under all load conditions
- Efficient resource utilization
- Scalability for growth
- Cost-effective operations
- Excellent user experience

### Performance Goals

```yaml
performance_targets:
  latency:
    api_endpoints:
      p50: < 50ms
      p95: < 200ms
      p99: < 500ms

    workflow_execution:
      simple: < 1s
      complex: < 5s
      background: < 30s

    database_queries:
      simple: < 10ms
      complex: < 100ms
      reports: < 1s

  throughput:
    api_gateway: 20,000 req/s
    workflow_engine: 5,000 workflows/s
    notification_service: 10,000 notifications/s

  resource_utilization:
    cpu: 60-70% (target)
    memory: 70-80% (target)
    network: < 70%
    disk_io: < 80%

  error_rates:
    http_5xx: < 0.1%
    timeouts: < 0.5%
    connection_errors: < 0.1%
```

## Performance Baselines

### Establishing Baselines

```yaml
baseline_methodology:
  measurement_period: 7 days
  conditions: Normal production traffic
  metrics_tracked:
    - Request latency (P50, P95, P99)
    - Throughput (req/s)
    - Error rates
    - Resource utilization
    - Database performance

  baseline_scenarios:
    typical_load:
      description: "Average weekday traffic"
      rps: 5,000-8,000
      concurrent_users: 2,000-3,000

    peak_load:
      description: "Peak business hours"
      rps: 15,000-20,000
      concurrent_users: 8,000-10,000

    minimal_load:
      description: "Off-peak hours"
      rps: 1,000-2,000
      concurrent_users: 500-1,000
```

### Current Performance Metrics

```yaml
# Example baseline from production
current_baselines:
  api_gateway:
    latency_ms:
      p50: 45
      p95: 180
      p99: 420
    throughput_rps: 12,000
    error_rate: 0.08%
    cpu_usage: 55%
    memory_usage: 68%

  workflow_engine:
    latency_ms:
      p50: 890
      p95: 2,100
      p99: 4,800
    throughput_wps: 3,200  # workflows per second
    error_rate: 0.12%
    cpu_usage: 72%
    memory_usage: 75%

  database:
    query_latency_ms:
      p50: 8
      p95: 65
      p99: 180
    connections_active: 250
    qps: 45,000  # queries per second
    cache_hit_rate: 92%
```

## Application Performance

### PHP-FPM Tuning

```ini
; /etc/php/8.3/fpm/pool.d/www.conf

[www]
user = www-data
group = www-data

; Process manager configuration
pm = dynamic
pm.max_children = 100        ; Maximum number of child processes
pm.start_servers = 20        ; Number started on startup
pm.min_spare_servers = 10    ; Minimum idle processes
pm.max_spare_servers = 30    ; Maximum idle processes
pm.max_requests = 1000       ; Restart worker after N requests (prevents memory leaks)

; Process timeout
request_terminate_timeout = 60s
request_slowlog_timeout = 10s
slowlog = /var/log/php-fpm/slow.log

; Performance settings
pm.status_path = /status
ping.path = /ping

; Resource limits
rlimit_files = 65535
rlimit_core = unlimited

; Emergency restart
emergency_restart_threshold = 10
emergency_restart_interval = 1m

; Logging
catch_workers_output = yes
decorate_workers_output = no
```

```ini
; /etc/php/8.3/fpm/php.ini

; Memory settings
memory_limit = 512M
max_execution_time = 60
max_input_time = 60

; OPcache settings
[opcache]
opcache.enable = 1
opcache.enable_cli = 0
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 16
opcache.max_accelerated_files = 20000
opcache.validate_timestamps = 0  ; Disable in production
opcache.revalidate_freq = 0
opcache.save_comments = 0
opcache.fast_shutdown = 1

; JIT compilation (PHP 8+)
opcache.jit = tracing
opcache.jit_buffer_size = 128M

; Realpath cache
realpath_cache_size = 4M
realpath_cache_ttl = 600

; File handling
max_file_uploads = 20
upload_max_filesize = 10M
post_max_size = 10M

; Session handling
session.save_handler = redis
session.save_path = "tcp://redis:6379?database=0"
```

### OPcache Preloading

```php
<?php
// config/preload.php

declare(strict_types=1);

/**
 * OPcache preloading script
 * Loaded classes are compiled and stored in shared memory
 */

$projectRoot = dirname(__DIR__);

// Autoloader
require_once $projectRoot . '/vendor/autoload.php';

// Preload Symfony kernel
opcache_compile_file($projectRoot . '/src/Kernel.php');

// Preload commonly used Symfony components
$symfonyComponents = [
    'HttpFoundation/Request.php',
    'HttpFoundation/Response.php',
    'HttpFoundation/JsonResponse.php',
    'HttpKernel/HttpKernelInterface.php',
    'Routing/RouterInterface.php',
    'EventDispatcher/EventDispatcherInterface.php',
    'DependencyInjection/ContainerInterface.php',
];

foreach ($symfonyComponents as $component) {
    $file = $projectRoot . '/vendor/symfony/http-foundation/' . $component;
    if (file_exists($file)) {
        opcache_compile_file($file);
    }
}

// Preload application classes
$preloadPaths = [
    '/src/Domain',
    '/src/Application',
    '/src/Infrastructure',
];

$iterator = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator($projectRoot . '/src')
);

foreach ($iterator as $file) {
    if ($file->getExtension() === 'php') {
        opcache_compile_file($file->getRealPath());
    }
}

// Preload Doctrine entities
$entityPath = $projectRoot . '/src/Domain';
$entityIterator = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator($entityPath)
);

foreach ($entityIterator as $file) {
    if ($file->getExtension() === 'php' &&
        strpos($file->getFilename(), 'Repository') === false) {
        opcache_compile_file($file->getRealPath());
    }
}
```

### Symfony Framework Optimization

```yaml
# config/packages/framework.yaml
framework:
    # HTTP cache
    http_cache:
        enabled: true

    # Session configuration
    session:
        handler_id: 'snc_redis.session.handler'
        cookie_secure: auto
        cookie_samesite: lax

    # Cache configuration
    cache:
        app: cache.adapter.redis
        system: cache.adapter.redis
        default_redis_provider: 'redis://redis:6379'

        pools:
            cache.app:
                adapter: cache.adapter.redis
                default_lifetime: 3600

            cache.workflow_definitions:
                adapter: cache.adapter.redis
                default_lifetime: 86400  # 24 hours

            cache.user_permissions:
                adapter: cache.adapter.redis
                default_lifetime: 1800  # 30 minutes

    # Serializer
    serializer:
        enabled: true
        enable_annotations: false  # Use attributes instead
        default_context:
            enable_max_depth: true

    # Property access
    property_access:
        magic_methods_enabled: false

# config/packages/doctrine.yaml
doctrine:
    dbal:
        # Connection pooling
        driver: 'pdo_pgsql'
        server_version: '15'
        charset: utf8

        options:
            persistent: true

        # Connection pool configuration
        max_connections: 100
        idle_timeout: 600

    orm:
        auto_generate_proxy_classes: false  # Disable in production

        # Query result cache
        result_cache_driver:
            type: redis
            host: redis
            port: 6379

        # Metadata cache
        metadata_cache_driver:
            type: redis
            host: redis
            port: 6379

        # Query cache
        query_cache_driver:
            type: redis
            host: redis
            port: 6379

        # Hydration cache
        hydration_cache_driver:
            type: redis
            host: redis
            port: 6379

# config/packages/monolog.yaml
monolog:
    handlers:
        main:
            type: fingers_crossed  # Only log errors by default
            action_level: error
            handler: grouped

        grouped:
            type: group
            members: [streamed, buffer]

        streamed:
            type: stream
            path: "php://stderr"
            level: debug

        buffer:
            type: buffer
            handler: async
            buffer_size: 1000  # Batch logs

        async:
            type: service
            id: monolog.handler.async_service
```

### Async Processing

```php
<?php
// config/packages/messenger.yaml

/*
framework:
    messenger:
        failure_transport: failed

        transports:
            async:
                dsn: '%env(MESSENGER_TRANSPORT_DSN)%'
                options:
                    exchange:
                        name: messages
                        type: direct
                    queues:
                        messages:
                            binding_keys: ['*']
                retry_strategy:
                    max_retries: 3
                    multiplier: 2
                    delay: 1000

            async_priority_high:
                dsn: '%env(MESSENGER_TRANSPORT_DSN)%'
                options:
                    exchange:
                        name: messages_priority
                        type: direct
                    queues:
                        messages_priority:
                            binding_keys: ['high']
                            arguments:
                                x-max-priority: 10

            failed:
                dsn: 'doctrine://default?queue_name=failed'

        routing:
            'App\Message\SendNotification': async
            'App\Message\ProcessWorkflow': async_priority_high
            'App\Message\GenerateReport': async
*/

// src/Message/SendNotification.php
declare(strict_types=1);

namespace App\Message;

final class SendNotification
{
    public function __construct(
        public readonly string $userId,
        public readonly string $title,
        public readonly string $message,
        public readonly string $channel,
    ) {}
}

// src/MessageHandler/SendNotificationHandler.php
declare(strict_types=1);

namespace App\MessageHandler;

use App\Message\SendNotification;
use App\Service\NotificationService;
use Symfony\Component\Messenger\Attribute\AsMessageHandler;

#[AsMessageHandler]
final class SendNotificationHandler
{
    public function __construct(
        private readonly NotificationService $notificationService,
    ) {}

    public function __invoke(SendNotification $message): void
    {
        $this->notificationService->send(
            $message->userId,
            $message->title,
            $message->message,
            $message->channel
        );
    }
}
```

## Database Optimization

### PostgreSQL Configuration

```conf
# postgresql.conf

# Connection settings
max_connections = 200
superuser_reserved_connections = 3

# Memory settings
shared_buffers = 8GB                    # 25% of system RAM
effective_cache_size = 24GB             # 75% of system RAM
maintenance_work_mem = 2GB              # For VACUUM, CREATE INDEX
work_mem = 32MB                         # Per query operation
temp_buffers = 16MB

# WAL settings
wal_level = replica
wal_buffers = 16MB
min_wal_size = 2GB
max_wal_size = 8GB
wal_compression = on

# Checkpoint settings
checkpoint_timeout = 15min
checkpoint_completion_target = 0.9

# Query planning
default_statistics_target = 100
random_page_cost = 1.1                  # SSD optimized
effective_io_concurrency = 200          # SSD optimized
max_parallel_workers_per_gather = 4
max_parallel_workers = 8
max_worker_processes = 8

# Planner cost constants
seq_page_cost = 1.0
random_page_cost = 1.1
cpu_tuple_cost = 0.01
cpu_index_tuple_cost = 0.005
cpu_operator_cost = 0.0025

# Logging
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_min_duration_statement = 1000       # Log slow queries > 1s
log_line_prefix = '%t [%p]: user=%u,db=%d,app=%a,client=%h '
log_lock_waits = on
log_temp_files = 0
log_checkpoints = on
log_connections = on
log_disconnections = on

# Auto-vacuum settings
autovacuum = on
autovacuum_max_workers = 4
autovacuum_naptime = 30s
autovacuum_vacuum_threshold = 50
autovacuum_analyze_threshold = 50
autovacuum_vacuum_scale_factor = 0.1
autovacuum_analyze_scale_factor = 0.05
autovacuum_vacuum_cost_delay = 10ms

# Connection pooling
shared_preload_libraries = 'pg_stat_statements'

# Monitoring
track_activities = on
track_counts = on
track_io_timing = on
track_functions = all
```

### Query Optimization

```sql
-- Create appropriate indexes
-- workflows table
CREATE INDEX CONCURRENTLY idx_workflows_user_id_status
    ON workflows(user_id, status)
    WHERE status IN ('active', 'pending');

CREATE INDEX CONCURRENTLY idx_workflows_created_at_desc
    ON workflows(created_at DESC);

CREATE INDEX CONCURRENTLY idx_workflows_user_created
    ON workflows(user_id, created_at DESC);

-- workflow_executions table
CREATE INDEX CONCURRENTLY idx_executions_workflow_status
    ON workflow_executions(workflow_id, status)
    WHERE status IN ('running', 'pending');

CREATE INDEX CONCURRENTLY idx_executions_started_at
    ON workflow_executions(started_at)
    WHERE started_at IS NOT NULL;

-- Partial index for active records
CREATE INDEX CONCURRENTLY idx_active_workflows
    ON workflows(id, user_id)
    WHERE deleted_at IS NULL;

-- Composite indexes for common queries
CREATE INDEX CONCURRENTLY idx_workflows_composite
    ON workflows(user_id, status, created_at DESC)
    INCLUDE (name, description);

-- Expression indexes
CREATE INDEX CONCURRENTLY idx_workflows_name_lower
    ON workflows(LOWER(name));

-- Update statistics
ANALYZE workflows;
ANALYZE workflow_executions;
ANALYZE workflow_steps;
```

```php
<?php
// src/Infrastructure/Persistence/Doctrine/Repository/WorkflowRepository.php

declare(strict_types=1);

namespace App\Infrastructure\Persistence\Doctrine\Repository;

use App\Domain\Workflow\Workflow;
use App\Domain\Workflow\WorkflowId;
use App\Domain\Workflow\Repository\WorkflowRepositoryInterface;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

final class WorkflowRepository extends ServiceEntityRepository implements WorkflowRepositoryInterface
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Workflow::class);
    }

    // GOOD: Efficient query with proper joins and filtering
    public function findActiveWorkflowsForUser(string $userId, int $limit = 20): array
    {
        return $this->createQueryBuilder('w')
            ->select('w', 's', 'e')  // Fetch related entities eagerly
            ->leftJoin('w.steps', 's')
            ->leftJoin('w.executions', 'e', 'WITH', 'e.status = :status')
            ->where('w.userId = :userId')
            ->andWhere('w.deletedAt IS NULL')
            ->andWhere('w.status = :activeStatus')
            ->setParameter('userId', $userId)
            ->setParameter('status', 'running')
            ->setParameter('activeStatus', 'active')
            ->orderBy('w.createdAt', 'DESC')
            ->setMaxResults($limit)
            ->getQuery()
            ->useQueryCache(true)
            ->setQueryCacheLifetime(300)  // 5 minutes
            ->getResult();
    }

    // GOOD: Use native SQL for complex queries
    public function getWorkflowStatistics(string $userId): array
    {
        $conn = $this->getEntityManager()->getConnection();

        $sql = '
            SELECT
                COUNT(DISTINCT w.id) as total_workflows,
                COUNT(DISTINCT CASE WHEN w.status = :active THEN w.id END) as active_workflows,
                COUNT(DISTINCT we.id) as total_executions,
                COUNT(DISTINCT CASE WHEN we.status = :success THEN we.id END) as successful_executions,
                AVG(EXTRACT(EPOCH FROM (we.completed_at - we.started_at))) as avg_duration_seconds
            FROM workflows w
            LEFT JOIN workflow_executions we ON we.workflow_id = w.id
            WHERE w.user_id = :userId
              AND w.deleted_at IS NULL
        ';

        $result = $conn->executeQuery($sql, [
            'userId' => $userId,
            'active' => 'active',
            'success' => 'success',
        ])->fetchAssociative();

        return $result;
    }

    // BAD: N+1 query problem
    public function findWorkflowsWithStepsBad(string $userId): array
    {
        $workflows = $this->createQueryBuilder('w')
            ->where('w.userId = :userId')
            ->setParameter('userId', $userId)
            ->getQuery()
            ->getResult();

        // This causes N+1 queries (one query per workflow to load steps)
        foreach ($workflows as $workflow) {
            $steps = $workflow->getSteps();  // Lazy loading here
            // Process steps...
        }

        return $workflows;
    }

    // GOOD: Eager loading to avoid N+1
    public function findWorkflowsWithStepsGood(string $userId): array
    {
        return $this->createQueryBuilder('w')
            ->select('w', 's')  // Fetch steps in same query
            ->leftJoin('w.steps', 's')
            ->where('w.userId = :userId')
            ->setParameter('userId', $userId)
            ->getQuery()
            ->getResult();
    }

    // GOOD: Pagination for large result sets
    public function findWorkflowsPaginated(string $userId, int $page, int $perPage): array
    {
        $qb = $this->createQueryBuilder('w')
            ->where('w.userId = :userId')
            ->andWhere('w.deletedAt IS NULL')
            ->setParameter('userId', $userId)
            ->orderBy('w.createdAt', 'DESC')
            ->setFirstResult(($page - 1) * $perPage)
            ->setMaxResults($perPage);

        return $qb->getQuery()->getResult();
    }
}
```

### Connection Pooling

```yaml
# PgBouncer configuration
[databases]
platform_production = host=postgres-primary port=5432 dbname=platform_production

[pgbouncer]
# Connection pool mode
pool_mode = transaction  # transaction, session, or statement

# Connection limits
max_client_conn = 1000
default_pool_size = 25
min_pool_size = 10
reserve_pool_size = 5
reserve_pool_timeout = 3

# Timeouts
server_lifetime = 3600
server_idle_timeout = 600
query_timeout = 0
query_wait_timeout = 120
client_idle_timeout = 0
idle_transaction_timeout = 0

# Performance
max_db_connections = 100
max_user_connections = 100
```

## Caching Strategies

### Multi-Layer Caching

```
┌──────────────────────────────────────────────────┐
│             Application Layer                    │
│  ┌──────────────────────────────────────────┐   │
│  │   In-Memory Cache (APCu)                 │   │
│  │   - Configuration                        │   │
│  │   - Static data                          │   │
│  │   TTL: Process lifetime                  │   │
│  └──────────────────┬───────────────────────┘   │
│                     │ miss                       │
│                     ▼                            │
│  ┌──────────────────────────────────────────┐   │
│  │   Redis Cache (L1)                       │   │
│  │   - Session data                         │   │
│  │   - User permissions                     │   │
│  │   - Frequently accessed data             │   │
│  │   TTL: 5-30 minutes                      │   │
│  └──────────────────┬───────────────────────┘   │
│                     │ miss                       │
│                     ▼                            │
│  ┌──────────────────────────────────────────┐   │
│  │   Redis Cache (L2)                       │   │
│  │   - Computed results                     │   │
│  │   - Aggregations                         │   │
│  │   - Report data                          │   │
│  │   TTL: 1-24 hours                        │   │
│  └──────────────────┬───────────────────────┘   │
│                     │ miss                       │
│                     ▼                            │
│  ┌──────────────────────────────────────────┐   │
│  │   Database Query Result Cache            │   │
│  │   - Doctrine query cache                 │   │
│  │   TTL: 5-60 minutes                      │   │
│  └──────────────────┬───────────────────────┘   │
│                     │ miss                       │
│                     ▼                            │
│  ┌──────────────────────────────────────────┐   │
│  │   Database                               │   │
│  └──────────────────────────────────────────┘   │
└──────────────────────────────────────────────────┘
```

### Cache Implementation

```php
<?php
// src/Infrastructure/Cache/CacheService.php

declare(strict_types=1);

namespace App\Infrastructure\Cache;

use Psr\Cache\CacheItemPoolInterface;
use Psr\Log\LoggerInterface;

final class CacheService
{
    private const CACHE_VERSION = 'v1';

    public function __construct(
        private readonly CacheItemPoolInterface $cache,
        private readonly LoggerInterface $logger,
    ) {}

    public function get(string $key, callable $callback, int $ttl = 3600): mixed
    {
        $cacheKey = $this->generateKey($key);

        $item = $this->cache->getItem($cacheKey);

        if ($item->isHit()) {
            $this->logger->debug('Cache hit', ['key' => $key]);
            return $item->get();
        }

        $this->logger->debug('Cache miss', ['key' => $key]);

        $value = $callback();

        $item->set($value);
        $item->expiresAfter($ttl);
        $this->cache->save($item);

        return $value;
    }

    public function remember(string $key, int $ttl, callable $callback): mixed
    {
        return $this->get($key, $callback, $ttl);
    }

    public function forget(string $key): void
    {
        $cacheKey = $this->generateKey($key);
        $this->cache->deleteItem($cacheKey);
    }

    public function tags(array $tags): self
    {
        // Implement tag-based cache invalidation
        return $this;
    }

    private function generateKey(string $key): string
    {
        return self::CACHE_VERSION . ':' . $key;
    }
}

// Usage example
// src/Application/Workflow/Query/GetWorkflowStatistics.php

declare(strict_types=1);

namespace App\Application\Workflow\Query;

use App\Infrastructure\Cache\CacheService;
use App\Domain\Workflow\Repository\WorkflowRepositoryInterface;

final class GetWorkflowStatistics
{
    public function __construct(
        private readonly WorkflowRepositoryInterface $repository,
        private readonly CacheService $cache,
    ) {}

    public function execute(string $userId): array
    {
        $cacheKey = "workflow_stats:{$userId}";

        return $this->cache->remember($cacheKey, 300, function () use ($userId) {
            return $this->repository->getWorkflowStatistics($userId);
        });
    }
}
```

### HTTP Caching

```php
<?php
// src/Infrastructure/Http/CacheMiddleware.php

declare(strict_types=1);

namespace App\Infrastructure\Http;

use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Event\ResponseEvent;

final class CacheMiddleware
{
    public function onKernelResponse(ResponseEvent $event): void
    {
        if (!$event->isMainRequest()) {
            return;
        }

        $request = $event->getRequest();
        $response = $event->getResponse();

        // Don't cache non-GET requests
        if (!$request->isMethod('GET')) {
            return;
        }

        // Don't cache authenticated requests by default
        if ($request->headers->has('Authorization')) {
            $response->headers->set('Cache-Control', 'private, no-cache, no-store, must-revalidate');
            return;
        }

        // Set cache headers based on route
        $route = $request->attributes->get('_route');

        match ($route) {
            'api_public_data' => $this->setCacheHeaders($response, 3600, true),
            'api_workflow_list' => $this->setCacheHeaders($response, 300, false),
            'api_static_content' => $this->setCacheHeaders($response, 86400, true),
            default => null,
        };
    }

    private function setCacheHeaders(Response $response, int $maxAge, bool $public): void
    {
        $visibility = $public ? 'public' : 'private';

        $response->headers->set('Cache-Control', "{$visibility}, max-age={$maxAge}");
        $response->headers->set('Expires', gmdate('D, d M Y H:i:s', time() + $maxAge) . ' GMT');
        $response->setEtag(md5($response->getContent()));
        $response->setLastModified(new \DateTime());
    }
}
```

## Network Optimization

### CDN Configuration

```yaml
# CloudFront distribution
cdn_configuration:
  origins:
    - domain: api.platform.com
      protocol: HTTPS only
      custom_headers:
        X-CDN-Request: true

  cache_behaviors:
    - path_pattern: "/api/v1/public/*"
      min_ttl: 3600
      default_ttl: 86400
      max_ttl: 31536000
      compress: true
      allowed_methods: [GET, HEAD, OPTIONS]

    - path_pattern: "/api/v1/*"
      min_ttl: 0
      default_ttl: 0
      max_ttl: 0
      compress: true
      allowed_methods: [GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE]
      forward_cookies: [session_id]
      forward_headers: [Authorization]

  compression:
    enabled: true
    formats: [gzip, br]  # Brotli compression

  geo_restriction:
    type: none

  viewer_protocol_policy: redirect-to-https

  price_class: PriceClass_100  # US, Europe, Asia
```

### HTTP/2 and HTTP/3

```yaml
# nginx configuration for HTTP/2 and HTTP/3
nginx_http2_http3:
  listen:
    - "443 ssl http2"
    - "443 http3 reuseport"

  http2_settings:
    http2_max_concurrent_streams: 128
    http2_max_field_size: 16k
    http2_max_header_size: 32k

  http3_settings:
    quic_retry: on
    quic_gso: on

  server_push:
    http2_push: /css/main.css
    http2_push: /js/app.js

  headers:
    alt-svc: 'h3=":443"; ma=86400'
```

### Connection Keep-Alive

```nginx
# nginx.conf
http {
    keepalive_timeout 65;
    keepalive_requests 100;

    upstream php_backend {
        server php-fpm:9000;
        keepalive 32;  # Keep 32 connections open
    }

    server {
        location ~ \.php$ {
            fastcgi_pass php_backend;
            fastcgi_keep_conn on;  # Keep PHP-FPM connections

            # FastCGI buffering
            fastcgi_buffering on;
            fastcgi_buffer_size 16k;
            fastcgi_buffers 16 16k;
        }
    }
}
```

## Resource Optimization

### Container Resource Limits

```yaml
# kubernetes deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: workflow-engine
spec:
  replicas: 10
  template:
    spec:
      containers:
        - name: workflow-engine
          image: workflow-engine:v1.25.0

          # Resource requests and limits
          resources:
            requests:
              cpu: "1000m"       # 1 CPU core
              memory: "2Gi"      # 2 GB RAM
            limits:
              cpu: "2000m"       # 2 CPU cores max
              memory: "4Gi"      # 4 GB RAM max

          # Horizontal Pod Autoscaler
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: workflow-engine-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: workflow-engine

  minReplicas: 10
  maxReplicas: 50

  metrics:
    # CPU-based scaling
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70

    # Memory-based scaling
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80

    # Custom metric scaling
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: "1000"

  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # 5 minutes
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60  # 1 minute
      policies:
        - type: Percent
          value: 100
          periodSeconds: 30
```

### Vertical Pod Autoscaler

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: workflow-engine-vpa
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind: Deployment
    name: workflow-engine

  updatePolicy:
    updateMode: "Auto"  # or "Recreate", "Initial", "Off"

  resourcePolicy:
    containerPolicies:
      - containerName: workflow-engine
        minAllowed:
          cpu: 500m
          memory: 1Gi
        maxAllowed:
          cpu: 4000m
          memory: 8Gi
        controlledResources: ["cpu", "memory"]
```

## Load Testing

### Load Test Strategy

```yaml
load_test_strategy:
  tools:
    - k6 (primary)
    - Gatling (complex scenarios)
    - Apache JMeter (compatibility)

  test_types:
    smoke_test:
      duration: 5 minutes
      virtual_users: 10
      purpose: "Verify system functions under minimal load"

    load_test:
      duration: 30 minutes
      virtual_users: 100-500
      purpose: "Test normal expected load"

    stress_test:
      duration: 60 minutes
      virtual_users: 1000-5000
      purpose: "Find breaking point"

    spike_test:
      duration: 30 minutes
      pattern: "Sudden spike to 10x normal load"
      purpose: "Test auto-scaling and resilience"

    soak_test:
      duration: 6-24 hours
      virtual_users: 300
      purpose: "Detect memory leaks and degradation"
```

### K6 Load Test Script

```javascript
// load-tests/workflow-api.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const workflowCreationTime = new Trend('workflow_creation_duration');

// Test configuration
export const options = {
    stages: [
        { duration: '2m', target: 100 },   // Ramp up to 100 users
        { duration: '5m', target: 100 },   // Stay at 100 users
        { duration: '2m', target: 200 },   // Ramp up to 200 users
        { duration: '5m', target: 200 },   // Stay at 200 users
        { duration: '2m', target: 500 },   // Spike to 500 users
        { duration: '3m', target: 500 },   // Stay at spike
        { duration: '2m', target: 0 },     // Ramp down
    ],

    thresholds: {
        'http_req_duration': ['p(95)<500', 'p(99)<1000'],  // 95% < 500ms, 99% < 1s
        'http_req_failed': ['rate<0.01'],                   // Error rate < 1%
        'errors': ['rate<0.05'],                            // Custom error rate < 5%
    },
};

// Test data
const BASE_URL = __ENV.BASE_URL || 'https://api.platform.com';
const API_TOKEN = __ENV.API_TOKEN;

export function setup() {
    // Setup: Authenticate and get token if needed
    return {
        token: API_TOKEN,
    };
}

export default function (data) {
    const headers = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${data.token}`,
    };

    // Test 1: List workflows
    let response = http.get(`${BASE_URL}/api/v1/workflows`, { headers });

    check(response, {
        'list workflows status is 200': (r) => r.status === 200,
        'list workflows duration < 200ms': (r) => r.timings.duration < 200,
    }) || errorRate.add(1);

    sleep(1);

    // Test 2: Create workflow
    const workflowPayload = JSON.stringify({
        name: `Load Test Workflow ${Date.now()}`,
        description: 'Created by k6 load test',
        steps: [
            {
                type: 'http',
                config: { url: 'https://example.com', method: 'GET' }
            }
        ]
    });

    const startTime = Date.now();
    response = http.post(`${BASE_URL}/api/v1/workflows`, workflowPayload, { headers });
    const duration = Date.now() - startTime;

    workflowCreationTime.add(duration);

    const created = check(response, {
        'create workflow status is 201': (r) => r.status === 201,
        'create workflow has ID': (r) => JSON.parse(r.body).id !== undefined,
    });

    if (!created) {
        errorRate.add(1);
        return;
    }

    const workflowId = JSON.parse(response.body).id;

    sleep(2);

    // Test 3: Get workflow details
    response = http.get(`${BASE_URL}/api/v1/workflows/${workflowId}`, { headers });

    check(response, {
        'get workflow status is 200': (r) => r.status === 200,
        'get workflow returns correct ID': (r) => JSON.parse(r.body).id === workflowId,
    }) || errorRate.add(1);

    sleep(1);

    // Test 4: Execute workflow
    response = http.post(
        `${BASE_URL}/api/v1/workflows/${workflowId}/execute`,
        JSON.stringify({}),
        { headers }
    );

    check(response, {
        'execute workflow status is 200': (r) => r.status === 200,
    }) || errorRate.add(1);

    sleep(3);
}

export function teardown(data) {
    // Cleanup if needed
}
```

### Running Load Tests

```bash
#!/bin/bash
# scripts/run-load-test.sh

set -euo pipefail

TEST_TYPE="${1:-load}"  # smoke, load, stress, spike, soak
ENVIRONMENT="${2:-staging}"

case "$TEST_TYPE" in
    smoke)
        k6 run \
            --vus 10 \
            --duration 5m \
            --env BASE_URL="https://api-${ENVIRONMENT}.platform.com" \
            --env API_TOKEN="${API_TOKEN}" \
            load-tests/workflow-api.js
        ;;

    load)
        k6 run \
            --env BASE_URL="https://api-${ENVIRONMENT}.platform.com" \
            --env API_TOKEN="${API_TOKEN}" \
            --out influxdb=http://influxdb:8086/k6 \
            load-tests/workflow-api.js
        ;;

    stress)
        k6 run \
            --vus 5000 \
            --duration 60m \
            --env BASE_URL="https://api-${ENVIRONMENT}.platform.com" \
            --env API_TOKEN="${API_TOKEN}" \
            load-tests/workflow-api.js
        ;;

    spike)
        k6 run \
            --stage 30s:10 \
            --stage 1m:1000 \
            --stage 10m:1000 \
            --stage 1m:10 \
            --env BASE_URL="https://api-${ENVIRONMENT}.platform.com" \
            --env API_TOKEN="${API_TOKEN}" \
            load-tests/workflow-api.js
        ;;

    soak)
        k6 run \
            --vus 300 \
            --duration 24h \
            --env BASE_URL="https://api-${ENVIRONMENT}.platform.com" \
            --env API_TOKEN="${API_TOKEN}" \
            --out influxdb=http://influxdb:8086/k6 \
            load-tests/workflow-api.js
        ;;

    *)
        echo "Unknown test type: $TEST_TYPE"
        echo "Usage: $0 {smoke|load|stress|spike|soak} [environment]"
        exit 1
        ;;
esac
```

## Performance Monitoring

### Application Performance Monitoring

```yaml
# Elastic APM configuration
elastic_apm:
  server_url: https://apm.platform.com
  service_name: workflow-engine
  environment: production

  # Sampling
  transaction_sample_rate: 0.1  # 10% of transactions

  # Capture settings
  capture_body: errors  # all, errors, transactions, off
  capture_headers: true

  # Performance thresholds
  transaction_max_spans: 500
  span_frames_min_duration: 5ms

  # Stack trace
  stack_trace_limit: 50
```

### Performance Dashboard

```yaml
# Grafana dashboard for performance
performance_dashboard:
  panels:
    - title: "Response Time Percentiles"
      metrics:
        - p50: histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))
        - p95: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
        - p99: histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))

    - title: "Throughput"
      metric: sum(rate(http_requests_total[5m]))

    - title: "Error Rate"
      metric: sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))

    - title: "Database Query Performance"
      metrics:
        - query_p95: histogram_quantile(0.95, rate(db_query_duration_seconds_bucket[5m]))
        - slow_queries: sum(rate(db_query_duration_seconds_count{duration>1}[5m]))

    - title: "Cache Hit Rate"
      metric: sum(rate(cache_hits[5m])) / sum(rate(cache_requests[5m]))

    - title: "Resource Utilization"
      metrics:
        - cpu: avg(rate(container_cpu_usage_seconds_total[5m]))
        - memory: avg(container_memory_working_set_bytes)
```

## Optimization Checklist

### Pre-Deployment Checklist

```yaml
pre_deployment_checklist:
  application:
    - [ ] OPcache enabled and configured
    - [ ] JIT compilation enabled
    - [ ] Preloading configured
    - [ ] Debug mode disabled
    - [ ] Query cache enabled
    - [ ] Proper error handling (no var_dump, print_r in production)

  database:
    - [ ] Indexes created for all queries
    - [ ] Query plan analysis done
    - [ ] Connection pooling configured
    - [ ] Auto-vacuum tuned
    - [ ] Statistics up to date

  caching:
    - [ ] Redis configured and tested
    - [ ] Cache warming implemented
    - [ ] Cache invalidation strategy defined
    - [ ] HTTP caching headers set
    - [ ] CDN configured

  resources:
    - [ ] Resource limits set
    - [ ] Auto-scaling configured
    - [ ] Load tests passed
    - [ ] Performance benchmarks met

  monitoring:
    - [ ] APM configured
    - [ ] Custom metrics added
    - [ ] Alerts configured
    - [ ] Dashboards created
```

## Conclusion

Performance tuning is an ongoing process that requires:

- **Continuous monitoring** of metrics and user experience
- **Regular optimization** based on data and profiling
- **Load testing** before major releases
- **Capacity planning** for growth
- **Team knowledge** of performance best practices

**Key Practices**:
1. Measure before optimizing
2. Focus on biggest bottlenecks first
3. Test optimizations thoroughly
4. Monitor impact of changes
5. Document findings and decisions

For more information, see:
- [Operations Overview](01-operations-overview.md)
- [Monitoring and Alerting](02-monitoring-alerting.md)
- [Incident Response](03-incident-response.md)
- [Backup and Recovery](04-backup-recovery.md)
