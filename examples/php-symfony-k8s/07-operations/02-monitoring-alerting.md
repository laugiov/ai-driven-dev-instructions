# Monitoring and Alerting

## Table of Contents

1. [Overview](#overview)
2. [Monitoring Architecture](#monitoring-architecture)
3. [Metrics Collection](#metrics-collection)
4. [Logging Strategy](#logging-strategy)
5. [Distributed Tracing](#distributed-tracing)
6. [Alerting Framework](#alerting-framework)
7. [Dashboards](#dashboards)
8. [Alert Rules](#alert-rules)
9. [On-Call Integration](#on-call-integration)
10. [Observability Best Practices](#observability-best-practices)

## Overview

### Purpose

Comprehensive monitoring and alerting ensures:
- Early detection of issues before customer impact
- Fast root cause identification
- Data-driven operational decisions
- SLO compliance tracking
- Capacity planning insights

### Observability Pillars

```yaml
observability_pillars:
  metrics:
    description: "Quantitative measurements over time"
    use_cases:
      - Performance monitoring
      - Resource utilization
      - Business metrics
      - SLO tracking
    retention: 90 days
    granularity: 15 seconds

  logs:
    description: "Discrete events with context"
    use_cases:
      - Debugging
      - Audit trail
      - Error investigation
      - Security analysis
    retention: 30 days
    volume: ~500 GB/day

  traces:
    description: "Request flow through distributed system"
    use_cases:
      - Performance optimization
      - Dependency mapping
      - Latency analysis
      - Error correlation
    retention: 7 days
    sampling: 10% of requests
```

## Monitoring Architecture

### Component Overview

```
┌──────────────────────────────────────────────────────────────┐
│                     Applications                             │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐        │
│  │Workflow │  │ Agent   │  │Notif.   │  │ API     │        │
│  │ Engine  │  │ Manager │  │ Service │  │ Gateway │        │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘        │
│       │            │             │             │             │
└───────┼────────────┼─────────────┼─────────────┼─────────────┘
        │            │             │             │
        │ metrics    │ logs        │ traces      │
        ▼            ▼             ▼             ▼
┌──────────────────────────────────────────────────────────────┐
│                   Collection Layer                           │
│  ┌────────────┐  ┌───────────┐  ┌──────────────┐           │
│  │ Prometheus │  │  Loki     │  │    Tempo     │           │
│  │  Exporters │  │  Agent    │  │ OpenTelemetry│           │
│  └─────┬──────┘  └─────┬─────┘  └──────┬───────┘           │
└────────┼────────────────┼────────────────┼───────────────────┘
         │                │                │
         ▼                ▼                ▼
┌──────────────────────────────────────────────────────────────┐
│                   Storage Layer                              │
│  ┌────────────┐  ┌───────────┐  ┌──────────────┐           │
│  │ Prometheus │  │   Loki    │  │    Tempo     │           │
│  │   (TSDB)   │  │ (S3+Index)│  │    (S3)      │           │
│  └─────┬──────┘  └─────┬─────┘  └──────┬───────┘           │
└────────┼────────────────┼────────────────┼───────────────────┘
         │                │                │
         └────────────────┴────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│                  Visualization Layer                         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    Grafana                           │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │   │
│  │  │ Metrics  │  │   Logs   │  │     Traces       │  │   │
│  │  │Dashboards│  │  Search  │  │  Visualization   │  │   │
│  │  └──────────┘  └──────────┘  └──────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│                    Alerting Layer                            │
│  ┌────────────┐  ┌───────────┐  ┌──────────────┐           │
│  │ Prometheus │  │   Loki    │  │  PagerDuty   │           │
│  │AlertManager│  │  Alerting │  │              │           │
│  └─────┬──────┘  └─────┬─────┘  └──────┬───────┘           │
└────────┼────────────────┼────────────────┼───────────────────┘
         │                │                │
         └────────────────┴────────────────┘
                          │
                          ▼
                  ┌──────────────┐
                  │   On-Call    │
                  │   Engineers  │
                  └──────────────┘
```

### Deployment Architecture

```yaml
# Monitoring cluster configuration
monitoring_cluster:
  prometheus:
    replicas: 3
    retention: 90d
    storage_size: 1TB per replica
    scrape_interval: 15s
    resources:
      cpu: "8000m"
      memory: "32Gi"

  loki:
    replicas: 3
    retention: 30d
    storage: S3
    index: DynamoDB
    resources:
      cpu: "4000m"
      memory: "16Gi"

  tempo:
    replicas: 3
    retention: 7d
    storage: S3
    sampling_rate: 10%
    resources:
      cpu: "4000m"
      memory: "16Gi"

  grafana:
    replicas: 2
    storage: PostgreSQL (dashboards, users)
    resources:
      cpu: "2000m"
      memory: "4Gi"
```

## Metrics Collection

### Prometheus Configuration

```yaml
# prometheus-config.yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'platform-production'
    environment: 'production'

# Scrape configurations
scrape_configs:
  # Kubernetes API server
  - job_name: 'kubernetes-apiservers'
    kubernetes_sd_configs:
      - role: endpoints
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
      - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
        action: keep
        regex: default;kubernetes;https

  # Kubernetes nodes
  - job_name: 'kubernetes-nodes'
    kubernetes_sd_configs:
      - role: node
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)

  # Application pods
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      # Only scrape pods with prometheus.io/scrape annotation
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true

      # Use port from annotation if specified
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: (.+)
        target_label: __address__
        replacement: $1

      # Use path from annotation if specified
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)

      # Add pod labels
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)

      - source_labels: [__meta_kubernetes_namespace]
        target_label: namespace
      - source_labels: [__meta_kubernetes_pod_name]
        target_label: pod

  # PostgreSQL
  - job_name: 'postgresql'
    static_configs:
      - targets:
          - 'postgres-exporter.database:9187'
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        regex: '([^:]+):.*'

  # Redis
  - job_name: 'redis'
    static_configs:
      - targets:
          - 'redis-exporter.cache:9121'

  # RabbitMQ
  - job_name: 'rabbitmq'
    static_configs:
      - targets:
          - 'rabbitmq.messaging:15692'

# Remote write for long-term storage
remote_write:
  - url: https://prometheus-long-term.platform.com/api/v1/write
    queue_config:
      capacity: 10000
      max_shards: 50
      min_shards: 1
      max_samples_per_send: 5000
      batch_send_deadline: 5s
      min_backoff: 30ms
      max_backoff: 100ms
```

### Application Metrics

```php
<?php
// src/Infrastructure/Metrics/MetricsCollector.php

declare(strict_types=1);

namespace App\Infrastructure\Metrics;

use Prometheus\CollectorRegistry;
use Prometheus\Counter;
use Prometheus\Histogram;
use Prometheus\Gauge;

final class MetricsCollector
{
    private Counter $httpRequestsTotal;
    private Histogram $httpRequestDuration;
    private Counter $httpRequestsErrors;
    private Histogram $dbQueryDuration;
    private Counter $dbQueriesTotal;
    private Gauge $activeConnections;
    private Counter $workflowExecutions;
    private Histogram $workflowDuration;

    public function __construct(
        private readonly CollectorRegistry $registry,
    ) {
        $this->initializeMetrics();
    }

    private function initializeMetrics(): void
    {
        // HTTP request metrics
        $this->httpRequestsTotal = $this->registry->getOrRegisterCounter(
            'app',
            'http_requests_total',
            'Total HTTP requests',
            ['method', 'endpoint', 'status']
        );

        $this->httpRequestDuration = $this->registry->getOrRegisterHistogram(
            'app',
            'http_request_duration_seconds',
            'HTTP request duration in seconds',
            ['method', 'endpoint'],
            [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
        );

        $this->httpRequestsErrors = $this->registry->getOrRegisterCounter(
            'app',
            'http_requests_errors_total',
            'Total HTTP request errors',
            ['method', 'endpoint', 'error_type']
        );

        // Database metrics
        $this->dbQueryDuration = $this->registry->getOrRegisterHistogram(
            'app',
            'db_query_duration_seconds',
            'Database query duration in seconds',
            ['operation', 'table'],
            [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0]
        );

        $this->dbQueriesTotal = $this->registry->getOrRegisterCounter(
            'app',
            'db_queries_total',
            'Total database queries',
            ['operation', 'table', 'status']
        );

        $this->activeConnections = $this->registry->getOrRegisterGauge(
            'app',
            'db_connections_active',
            'Active database connections',
            ['pool']
        );

        // Business metrics
        $this->workflowExecutions = $this->registry->getOrRegisterCounter(
            'app',
            'workflow_executions_total',
            'Total workflow executions',
            ['workflow_type', 'status']
        );

        $this->workflowDuration = $this->registry->getOrRegisterHistogram(
            'app',
            'workflow_execution_duration_seconds',
            'Workflow execution duration in seconds',
            ['workflow_type'],
            [1, 5, 10, 30, 60, 120, 300, 600, 1800, 3600]
        );
    }

    // HTTP metrics
    public function recordHttpRequest(
        string $method,
        string $endpoint,
        int $statusCode,
        float $duration
    ): void {
        $this->httpRequestsTotal->inc([
            'method' => $method,
            'endpoint' => $endpoint,
            'status' => (string) $statusCode
        ]);

        $this->httpRequestDuration->observe(
            $duration,
            ['method' => $method, 'endpoint' => $endpoint]
        );
    }

    public function recordHttpError(
        string $method,
        string $endpoint,
        string $errorType
    ): void {
        $this->httpRequestsErrors->inc([
            'method' => $method,
            'endpoint' => $endpoint,
            'error_type' => $errorType
        ]);
    }

    // Database metrics
    public function recordDatabaseQuery(
        string $operation,
        string $table,
        float $duration,
        bool $success
    ): void {
        $this->dbQueriesTotal->inc([
            'operation' => $operation,
            'table' => $table,
            'status' => $success ? 'success' : 'error'
        ]);

        $this->dbQueryDuration->observe(
            $duration,
            ['operation' => $operation, 'table' => $table]
        );
    }

    public function setActiveConnections(string $pool, int $count): void
    {
        $this->activeConnections->set($count, ['pool' => $pool]);
    }

    // Business metrics
    public function recordWorkflowExecution(
        string $workflowType,
        string $status,
        float $duration
    ): void {
        $this->workflowExecutions->inc([
            'workflow_type' => $workflowType,
            'status' => $status
        ]);

        $this->workflowDuration->observe(
            $duration,
            ['workflow_type' => $workflowType]
        );
    }
}
```

### Metrics Endpoint

```php
<?php
// src/Infrastructure/Http/Controller/MetricsController.php

declare(strict_types=1);

namespace App\Infrastructure\Http\Controller;

use Prometheus\CollectorRegistry;
use Prometheus\RenderTextFormat;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

final class MetricsController
{
    public function __construct(
        private readonly CollectorRegistry $registry,
    ) {}

    #[Route('/metrics', name: 'metrics', methods: ['GET'])]
    public function metrics(): Response
    {
        $renderer = new RenderTextFormat();
        $metrics = $renderer->render($this->registry->getMetricFamilySamples());

        return new Response(
            $metrics,
            Response::HTTP_OK,
            ['Content-Type' => RenderTextFormat::MIME_TYPE]
        );
    }
}
```

### Custom Metrics

```yaml
# Custom business metrics
custom_metrics:
  user_signups:
    type: counter
    labels: [plan_type, source]
    description: "Total user signups"

  active_workflows:
    type: gauge
    labels: [user_id, status]
    description: "Currently active workflows"

  workflow_success_rate:
    type: histogram
    labels: [workflow_type]
    buckets: [0.5, 0.7, 0.8, 0.9, 0.95, 0.99, 1.0]
    description: "Workflow success rate distribution"

  agent_invocations:
    type: counter
    labels: [agent_type, model, status]
    description: "Total AI agent invocations"

  token_usage:
    type: counter
    labels: [agent_type, model]
    description: "Total tokens consumed"

  billing_events:
    type: counter
    labels: [event_type, plan_type]
    description: "Billing-related events"
```

## Logging Strategy

### Log Levels and Usage

```yaml
log_levels:
  DEBUG:
    usage: "Detailed diagnostic information"
    examples:
      - Function entry/exit
      - Variable values
      - SQL queries
    retention: 7 days
    sampling: 10% in production

  INFO:
    usage: "General informational messages"
    examples:
      - Request received
      - Task completed
      - State changes
    retention: 30 days
    sampling: 100%

  WARNING:
    usage: "Warning messages for recoverable issues"
    examples:
      - Deprecated API usage
      - Retry attempts
      - Performance degradation
    retention: 30 days
    sampling: 100%

  ERROR:
    usage: "Error messages for failures"
    examples:
      - Exception caught
      - Request failed
      - Database error
    retention: 90 days
    sampling: 100%

  CRITICAL:
    usage: "Critical system failures"
    examples:
      - Service unavailable
      - Data corruption
      - Security breach
    retention: 365 days
    sampling: 100%
```

### Structured Logging

```php
<?php
// src/Infrastructure/Logging/StructuredLogger.php

declare(strict_types=1);

namespace App\Infrastructure\Logging;

use Psr\Log\LoggerInterface;
use Symfony\Component\HttpFoundation\RequestStack;

final class StructuredLogger
{
    public function __construct(
        private readonly LoggerInterface $logger,
        private readonly RequestStack $requestStack,
    ) {}

    public function log(
        string $level,
        string $message,
        array $context = []
    ): void {
        // Add standard context
        $enrichedContext = array_merge(
            $this->getStandardContext(),
            $context
        );

        $this->logger->log($level, $message, $enrichedContext);
    }

    private function getStandardContext(): array
    {
        $request = $this->requestStack->getCurrentRequest();

        $context = [
            'environment' => $_ENV['APP_ENV'] ?? 'unknown',
            'service' => 'workflow-engine',
            'version' => $_ENV['APP_VERSION'] ?? 'unknown',
            'hostname' => gethostname(),
            'process_id' => getmypid(),
        ];

        if ($request !== null) {
            $context['request'] = [
                'id' => $request->headers->get('X-Request-ID'),
                'method' => $request->getMethod(),
                'uri' => $request->getRequestUri(),
                'client_ip' => $request->getClientIp(),
                'user_agent' => $request->headers->get('User-Agent'),
            ];

            // Add trace context for distributed tracing
            if ($request->headers->has('X-Trace-ID')) {
                $context['trace'] = [
                    'trace_id' => $request->headers->get('X-Trace-ID'),
                    'span_id' => $request->headers->get('X-Span-ID'),
                    'parent_span_id' => $request->headers->get('X-Parent-Span-ID'),
                ];
            }

            // Add user context if authenticated
            if ($request->attributes->has('user_id')) {
                $context['user'] = [
                    'id' => $request->attributes->get('user_id'),
                    'email' => $request->attributes->get('user_email'),
                ];
            }
        }

        return $context;
    }

    // Convenience methods
    public function debug(string $message, array $context = []): void
    {
        $this->log('debug', $message, $context);
    }

    public function info(string $message, array $context = []): void
    {
        $this->log('info', $message, $context);
    }

    public function warning(string $message, array $context = []): void
    {
        $this->log('warning', $message, $context);
    }

    public function error(string $message, array $context = []): void
    {
        $this->log('error', $message, $context);
    }

    public function critical(string $message, array $context = []): void
    {
        $this->log('critical', $message, $context);
    }
}
```

### Loki Configuration

```yaml
# loki-config.yaml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 3
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s
  max_transfer_retries: 0

schema_config:
  configs:
    - from: 2024-01-01
      store: boltdb-shipper
      object_store: s3
      schema: v11
      index:
        prefix: loki_index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/index_cache
    shared_store: s3

  aws:
    s3: s3://us-east-1/loki-logs
    s3forcepathstyle: true

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h  # 7 days
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20

chunk_store_config:
  max_look_back_period: 720h  # 30 days

table_manager:
  retention_deletes_enabled: true
  retention_period: 720h  # 30 days
```

### Log Aggregation

```yaml
# promtail-config.yaml (log shipper)
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  # Application logs from Kubernetes
  - job_name: kubernetes-pods
    kubernetes_sd_configs:
      - role: pod
    pipeline_stages:
      # Parse JSON logs
      - json:
          expressions:
            level: level
            message: message
            timestamp: timestamp
            service: service
            trace_id: trace.trace_id

      # Extract labels
      - labels:
          level:
          service:
          trace_id:

      # Parse timestamp
      - timestamp:
          source: timestamp
          format: RFC3339

      # Drop debug logs in production
      - match:
          selector: '{level="debug"}'
          action: drop

    relabel_configs:
      # Add Kubernetes metadata
      - source_labels: [__meta_kubernetes_pod_label_app]
        target_label: app
      - source_labels: [__meta_kubernetes_pod_label_version]
        target_label: version
      - source_labels: [__meta_kubernetes_namespace]
        target_label: namespace
      - source_labels: [__meta_kubernetes_pod_name]
        target_label: pod
```

## Distributed Tracing

### OpenTelemetry Configuration

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024

  # Sampling
  probabilistic_sampler:
    sampling_percentage: 10

  # Add resource attributes
  resource:
    attributes:
      - key: service.name
        action: upsert
        from_attribute: service
      - key: deployment.environment
        value: production
        action: insert

  # Filter out health check traces
  filter:
    traces:
      span:
        - 'attributes["http.target"] == "/health"'

exporters:
  # Export to Tempo
  otlp/tempo:
    endpoint: tempo:4317
    tls:
      insecure: true

  # Export to Jaeger for visualization
  jaeger:
    endpoint: jaeger-collector:14250
    tls:
      insecure: true

  # Also send metrics
  prometheus:
    endpoint: "0.0.0.0:8889"

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch, probabilistic_sampler, resource, filter]
      exporters: [otlp/tempo, jaeger]

    metrics:
      receivers: [otlp]
      processors: [batch, resource]
      exporters: [prometheus]
```

### Application Tracing

```php
<?php
// src/Infrastructure/Tracing/TracingMiddleware.php

declare(strict_types=1);

namespace App\Infrastructure\Tracing;

use OpenTelemetry\API\Trace\SpanKind;
use OpenTelemetry\API\Trace\TracerInterface;
use OpenTelemetry\Context\Context;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Event\RequestEvent;
use Symfony\Component\HttpKernel\Event\ResponseEvent;
use Symfony\Component\HttpKernel\Event\ExceptionEvent;

final class TracingMiddleware
{
    public function __construct(
        private readonly TracerInterface $tracer,
    ) {}

    public function onKernelRequest(RequestEvent $event): void
    {
        if (!$event->isMainRequest()) {
            return;
        }

        $request = $event->getRequest();

        // Start span
        $span = $this->tracer
            ->spanBuilder('http.request')
            ->setSpanKind(SpanKind::KIND_SERVER)
            ->startSpan();

        // Add attributes
        $span->setAttribute('http.method', $request->getMethod());
        $span->setAttribute('http.url', $request->getUri());
        $span->setAttribute('http.target', $request->getRequestUri());
        $span->setAttribute('http.host', $request->getHost());
        $span->setAttribute('http.scheme', $request->getScheme());
        $span->setAttribute('http.user_agent', $request->headers->get('User-Agent'));
        $span->setAttribute('http.client_ip', $request->getClientIp());

        // Store span in request attributes
        $request->attributes->set('_tracing_span', $span);
        $request->attributes->set('_tracing_scope', $span->activate());
    }

    public function onKernelResponse(ResponseEvent $event): void
    {
        if (!$event->isMainRequest()) {
            return;
        }

        $request = $event->getRequest();
        $response = $event->getResponse();

        $span = $request->attributes->get('_tracing_span');
        $scope = $request->attributes->get('_tracing_scope');

        if ($span === null) {
            return;
        }

        // Add response attributes
        $span->setAttribute('http.status_code', $response->getStatusCode());
        $span->setAttribute('http.response_content_length', $response->headers->get('Content-Length'));

        // Set span status
        if ($response->getStatusCode() >= 500) {
            $span->setStatus(\OpenTelemetry\API\Trace\StatusCode::STATUS_ERROR);
        } else {
            $span->setStatus(\OpenTelemetry\API\Trace\StatusCode::STATUS_OK);
        }

        // End span
        $scope?->detach();
        $span->end();
    }

    public function onKernelException(ExceptionEvent $event): void
    {
        $request = $event->getRequest();
        $exception = $event->getThrowable();

        $span = $request->attributes->get('_tracing_span');
        $scope = $request->attributes->get('_tracing_scope');

        if ($span === null) {
            return;
        }

        // Record exception
        $span->recordException($exception);
        $span->setStatus(\OpenTelemetry\API\Trace\StatusCode::STATUS_ERROR, $exception->getMessage());

        $scope?->detach();
        $span->end();
    }
}
```

### Database Query Tracing

```php
<?php
// src/Infrastructure/Tracing/DatabaseTracer.php

declare(strict_types=1);

namespace App\Infrastructure\Tracing;

use Doctrine\DBAL\Logging\SQLLogger;
use OpenTelemetry\API\Trace\TracerInterface;
use OpenTelemetry\API\Trace\SpanKind;

final class DatabaseTracer implements SQLLogger
{
    private ?\OpenTelemetry\API\Trace\SpanInterface $currentSpan = null;

    public function __construct(
        private readonly TracerInterface $tracer,
    ) {}

    public function startQuery($sql, ?array $params = null, ?array $types = null): void
    {
        $this->currentSpan = $this->tracer
            ->spanBuilder('db.query')
            ->setSpanKind(SpanKind::KIND_CLIENT)
            ->startSpan();

        $this->currentSpan->setAttribute('db.system', 'postgresql');
        $this->currentSpan->setAttribute('db.statement', $sql);

        if ($params !== null) {
            $this->currentSpan->setAttribute('db.params', json_encode($params));
        }

        // Extract table name from SQL
        if (preg_match('/(?:FROM|INTO|UPDATE)\s+([a-z_]+)/i', $sql, $matches)) {
            $this->currentSpan->setAttribute('db.sql.table', $matches[1]);
        }

        // Extract operation
        if (preg_match('/^(SELECT|INSERT|UPDATE|DELETE)/i', $sql, $matches)) {
            $this->currentSpan->setAttribute('db.operation', strtoupper($matches[1]));
        }
    }

    public function stopQuery(): void
    {
        if ($this->currentSpan !== null) {
            $this->currentSpan->end();
            $this->currentSpan = null;
        }
    }
}
```

## Alerting Framework

### Alert Manager Configuration

```yaml
# alertmanager-config.yaml
global:
  resolve_timeout: 5m
  slack_api_url: 'https://hooks.slack.com/services/XXX/YYY/ZZZ'
  pagerduty_url: 'https://events.pagerduty.com/v2/enqueue'

# Alert routing tree
route:
  receiver: 'default'
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

  routes:
    # Critical alerts go to PagerDuty
    - match:
        severity: critical
      receiver: 'pagerduty-critical'
      continue: true

    # High severity to PagerDuty during business hours
    - match:
        severity: high
      receiver: 'pagerduty-high'
      continue: true

    # All alerts to Slack
    - match_re:
        severity: (warning|high|critical)
      receiver: 'slack-alerts'

# Inhibition rules (suppress alerts)
inhibit_rules:
  # Suppress warning if critical alert is firing
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'cluster', 'service']

  # Suppress instance alerts if node is down
  - source_match:
      alertname: 'NodeDown'
    target_match_re:
      alertname: '.*'
    equal: ['instance']

receivers:
  - name: 'default'
    slack_configs:
      - channel: '#monitoring'
        title: 'Alert: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

  - name: 'pagerduty-critical'
    pagerduty_configs:
      - service_key: 'PAGERDUTY_SERVICE_KEY'
        severity: 'critical'
        description: '{{ .GroupLabels.alertname }}: {{ .GroupLabels.instance }}'
        details:
          firing: '{{ template "pagerduty.default.instances" .Alerts.Firing }}'

  - name: 'pagerduty-high'
    pagerduty_configs:
      - service_key: 'PAGERDUTY_SERVICE_KEY'
        severity: 'error'

  - name: 'slack-alerts'
    slack_configs:
      - channel: '#alerts'
        title: '[{{ .Status | toUpper }}] {{ .GroupLabels.alertname }}'
        text: |
          *Alert:* {{ .GroupLabels.alertname }}
          *Severity:* {{ .CommonLabels.severity }}
          *Description:* {{ .CommonAnnotations.description }}
          *Runbook:* {{ .CommonAnnotations.runbook_url }}
```

## Alert Rules

### SLO-Based Alerts

```yaml
# prometheus-rules/slo-alerts.yaml
groups:
  - name: slo_alerts
    interval: 30s
    rules:
      # Fast burn alert (2% budget in 1 hour)
      - alert: ErrorBudgetFastBurn
        expr: |
          (
            1 - (
              sum(rate(http_requests_total{status!~"5.."}[1h]))
              /
              sum(rate(http_requests_total[1h]))
            )
          ) > 0.14 * 0.02  # 14x burn rate for 1h window
        for: 5m
        labels:
          severity: critical
          component: slo
        annotations:
          summary: "Error budget burning too fast"
          description: |
            Service {{ $labels.service }} is consuming error budget at 14x rate.
            Current error rate: {{ $value | humanizePercentage }}
            At this rate, monthly budget will be exhausted in 2 days.
          runbook_url: "https://runbooks.platform.com/ErrorBudgetFastBurn"

      # Slow burn alert (5% budget in 1 day)
      - alert: ErrorBudgetSlowBurn
        expr: |
          (
            1 - (
              sum(rate(http_requests_total{status!~"5.."}[24h]))
              /
              sum(rate(http_requests_total[24h]))
            )
          ) > 0.05
        for: 30m
        labels:
          severity: high
          component: slo
        annotations:
          summary: "Error budget burning steadily"
          description: |
            Service {{ $labels.service }} has consumed 5% error budget in 24h.
            Current error rate: {{ $value | humanizePercentage }}

      # Budget depletion warning
      - alert: ErrorBudgetLow
        expr: |
          (
            1 - (
              sum(rate(http_requests_total{status!~"5.."}[30d]))
              /
              sum(rate(http_requests_total[30d]))
            )
          ) > 0.0004  # 80% of 0.05% budget consumed
        for: 1h
        labels:
          severity: warning
          component: slo
        annotations:
          summary: "Error budget running low"
          description: |
            Service {{ $labels.service }} has consumed 80% of monthly error budget.
            Remaining budget: {{ humanizePercentage (0.0005 - $value) }}

      # Latency SLO violation
      - alert: LatencySLOViolation
        expr: |
          histogram_quantile(0.95,
            sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service)
          ) > 0.3  # P95 > 300ms
        for: 10m
        labels:
          severity: high
          component: slo
        annotations:
          summary: "Latency SLO violated"
          description: |
            Service {{ $labels.service }} P95 latency is {{ $value }}s (SLO: 300ms).
          runbook_url: "https://runbooks.platform.com/LatencySLOViolation"
```

### Infrastructure Alerts

```yaml
# prometheus-rules/infrastructure-alerts.yaml
groups:
  - name: infrastructure_alerts
    interval: 30s
    rules:
      # Node down
      - alert: NodeDown
        expr: up{job="kubernetes-nodes"} == 0
        for: 5m
        labels:
          severity: critical
          component: infrastructure
        annotations:
          summary: "Node {{ $labels.instance }} is down"
          description: "Kubernetes node has been unreachable for 5 minutes."

      # High CPU usage
      - alert: HighCPUUsage
        expr: |
          (
            100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
          ) > 85
        for: 15m
        labels:
          severity: warning
          component: infrastructure
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is {{ $value }}% for 15 minutes."

      # High memory usage
      - alert: HighMemoryUsage
        expr: |
          (
            (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)
            / node_memory_MemTotal_bytes * 100
          ) > 90
        for: 10m
        labels:
          severity: warning
          component: infrastructure
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is {{ $value }}%."

      # Disk space low
      - alert: DiskSpaceLow
        expr: |
          (
            (node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lxcfs"}
            / node_filesystem_size_bytes) * 100
          ) < 15
        for: 10m
        labels:
          severity: warning
          component: infrastructure
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
          description: "Disk {{ $labels.device }} has only {{ $value }}% free space."

      # Pod restart loop
      - alert: PodRestartLoop
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 5m
        labels:
          severity: high
          component: kubernetes
        annotations:
          summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} restarting"
          description: "Pod has restarted {{ $value }} times in 15 minutes."
```

### Application Alerts

```yaml
# prometheus-rules/application-alerts.yaml
groups:
  - name: application_alerts
    interval: 30s
    rules:
      # High error rate
      - alert: HighErrorRate
        expr: |
          (
            sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
            /
            sum(rate(http_requests_total[5m])) by (service)
          ) > 0.05
        for: 5m
        labels:
          severity: high
          component: application
        annotations:
          summary: "High error rate in {{ $labels.service }}"
          description: "Error rate is {{ $value | humanizePercentage }}."
          runbook_url: "https://runbooks.platform.com/HighErrorRate"

      # Slow response time
      - alert: SlowResponseTime
        expr: |
          histogram_quantile(0.95,
            sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service)
          ) > 1.0
        for: 10m
        labels:
          severity: warning
          component: application
        annotations:
          summary: "Slow response time in {{ $labels.service }}"
          description: "P95 latency is {{ $value }}s."

      # Database connection pool exhausted
      - alert: DatabasePoolExhausted
        expr: |
          (
            app_db_connections_active{pool="default"}
            / app_db_connections_max{pool="default"}
          ) > 0.9
        for: 5m
        labels:
          severity: high
          component: database
        annotations:
          summary: "Database connection pool nearly exhausted"
          description: "{{ $value | humanizePercentage }} of connections in use."

      # Workflow execution failures
      - alert: WorkflowExecutionFailures
        expr: |
          (
            sum(rate(app_workflow_executions_total{status="failed"}[5m]))
            /
            sum(rate(app_workflow_executions_total[5m]))
          ) > 0.1
        for: 10m
        labels:
          severity: high
          component: application
        annotations:
          summary: "High workflow execution failure rate"
          description: "{{ $value | humanizePercentage }} of workflows are failing."
```

## Dashboards

### Executive Dashboard

```yaml
# grafana-dashboard-executive.json (simplified)
dashboard:
  title: "Executive Overview"
  refresh: "1m"

  panels:
    - title: "Overall Platform Health"
      type: "stat"
      targets:
        - expr: 'avg(up{job=~".*"})'
      thresholds:
        - value: 0.99
          color: green
        - value: 0.95
          color: yellow
        - value: 0
          color: red

    - title: "Request Rate"
      type: "graph"
      targets:
        - expr: 'sum(rate(http_requests_total[5m]))'
          legend: "Total Requests/sec"

    - title: "Error Rate"
      type: "graph"
      targets:
        - expr: 'sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))'
          legend: "Error Rate"

    - title: "P95 Latency by Service"
      type: "graph"
      targets:
        - expr: 'histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))'
          legend: "{{ service }}"

    - title: "Active Users"
      type: "stat"
      targets:
        - expr: 'count(count by (user_id) (rate(http_requests_total[5m]) > 0))'

    - title: "SLO Compliance"
      type: "gauge"
      targets:
        - expr: '(1 - (sum(rate(http_requests_total{status=~"5.."}[30d])) / sum(rate(http_requests_total[30d])))) * 100'
      thresholds:
        - value: 99.95
          color: green
        - value: 99.9
          color: yellow
        - value: 0
          color: red

    - title: "Error Budget Remaining"
      type: "gauge"
      targets:
        - expr: '(0.0005 - (1 - (sum(rate(http_requests_total{status!~"5.."}[30d])) / sum(rate(http_requests_total[30d]))))) / 0.0005 * 100'
```

## On-Call Integration

### PagerDuty Setup

```yaml
pagerduty_integration:
  services:
    - name: "Platform Critical"
      escalation_policy: "SRE Primary → SRE Secondary → Engineering Manager"
      integration_key: "${PAGERDUTY_CRITICAL_KEY}"
      urgency: high
      auto_resolve: true

    - name: "Platform Non-Critical"
      escalation_policy: "SRE Primary → SRE Secondary"
      integration_key: "${PAGERDUTY_NONCRITICAL_KEY}"
      urgency: low
      auto_resolve: true

  escalation_policies:
    sre_primary:
      - level: 1
        timeout: 5m
        targets: [on_call_primary]
      - level: 2
        timeout: 15m
        targets: [on_call_secondary]
      - level: 3
        timeout: 30m
        targets: [engineering_manager]

  schedules:
    on_call_primary:
      type: weekly
      rotation: round_robin
      members: [alice, bob, charlie]

    on_call_secondary:
      type: weekly
      rotation: round_robin
      members: [dave, eve, frank]
```

## Observability Best Practices

### Golden Signals

```yaml
golden_signals:
  latency:
    metric: "http_request_duration_seconds"
    aggregation: "P50, P95, P99"
    threshold:
      p95: 300ms
      p99: 500ms

  traffic:
    metric: "http_requests_total"
    aggregation: "rate per second"
    threshold: "> 1000 req/s"

  errors:
    metric: "http_requests_total{status=~'5..'}"
    aggregation: "error rate"
    threshold: "< 0.5%"

  saturation:
    metrics:
      - "container_cpu_usage_seconds_total"
      - "container_memory_usage_bytes"
      - "db_connections_active"
    threshold: "< 80%"
```

### Cardinality Management

```yaml
cardinality_limits:
  # Limit label values to prevent cardinality explosion
  label_limits:
    user_id: 10000    # Max 10k unique user IDs in metrics
    endpoint: 1000    # Max 1k unique endpoints
    error_message: 100 # Group similar errors

  # Use hashing for high-cardinality labels
  hash_labels:
    - user_id
    - request_id
    - trace_id

  # Drop unnecessary labels
  drop_labels:
    - user_agent (too high cardinality)
    - full_url (use normalized endpoint instead)
```

## Conclusion

This comprehensive monitoring and alerting strategy provides:

- **Complete visibility** through metrics, logs, and traces
- **Proactive alerting** based on SLOs and error budgets
- **Fast incident response** with on-call integration
- **Data-driven decisions** through dashboards
- **Scalable observability** architecture

For more information, see:
- [Operations Overview](01-operations-overview.md)
- [Incident Response](03-incident-response.md)
- [Backup and Recovery](04-backup-recovery.md)
- [Performance Tuning](05-performance-tuning.md)
