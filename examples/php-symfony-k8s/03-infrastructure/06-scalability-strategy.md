# Scalability Strategy

**Document Version**: 1.0
**Last Updated**: 2025-01-07
**Status**: Complete

## Table of Contents

1. [Overview](#overview)
2. [Scaling Dimensions](#scaling-dimensions)
3. [Horizontal Scaling](#horizontal-scaling)
4. [Vertical Scaling](#vertical-scaling)
5. [Database Scaling](#database-scaling)
6. [Caching Strategy](#caching-strategy)
7. [Performance Optimization](#performance-optimization)
8. [Load Testing](#load-testing)
9. [Capacity Planning](#capacity-planning)

## Overview

This document defines the scalability strategy to support 10x growth in traffic and data while maintaining performance targets.

### Scalability Goals

| Metric | Current | Target (10x) | Strategy |
|--------|---------|--------------|----------|
| **Requests/second** | 100 | 1,000 | Horizontal pod scaling |
| **Concurrent users** | 500 | 5,000 | Horizontal + caching |
| **Database size** | 100 GB | 1 TB | Read replicas + partitioning |
| **Response time (P95)** | < 200ms | < 200ms | Optimization + CDN |

## Scaling Dimensions

### 1. Compute Scaling (Kubernetes Pods)

**Horizontal Pod Autoscaler** (HPA):

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: llm-agent-hpa
  namespace: application
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: llm-agent-service
  minReplicas: 3
  maxReplicas: 50  # Scale to 50 pods under load
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100  # Double pods
        periodSeconds: 60
      - type: Pods
        value: 5    # Or add 5 pods
        periodSeconds: 60
      selectPolicy: Max
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50   # Scale down max 50% at a time
        periodSeconds: 60
```

**Cluster Autoscaler**: Automatically adds nodes when pods can't schedule

### 2. Data Layer Scaling

**PostgreSQL**:
- **Primary-Replica architecture**: 1 primary + 2 read replicas
- **Connection pooling**: PgBouncer (up to 10,000 connections)
- **Partitioning**: Time-based partitioning for large tables
- **Vertical scaling**: Upgrade to larger instances when needed

**RabbitMQ**:
- **Cluster**: 3-node cluster with quorum queues
- **Sharding**: Multiple queues for parallel processing
- **Federation**: Cross-region message routing

### 3. Storage Scaling

- **Object storage**: S3/MinIO (virtually unlimited)
- **Persistent volumes**: Auto-expand enabled
- **CDN**: CloudFlare for static assets

## Horizontal Scaling

### Stateless Services

All application services are stateless and can scale horizontally:

```
Current: 3 replicas/service → Target: 50 replicas/service
```

**Scaling triggers**:
1. CPU > 70%
2. Memory > 80%
3. Custom metrics (queue length, request latency)

### Scaling Patterns

**Pattern 1: Request-based Scaling**
```yaml
# Scale based on request rate
- type: Pods
  resource:
    name: custom.googleapis.com|http_requests_per_second
    target:
      type: AverageValue
      averageValue: "100"  # 100 req/s per pod
```

**Pattern 2: Queue-based Scaling**
```yaml
# Scale based on RabbitMQ queue length
- type: External
  external:
    metric:
      name: rabbitmq_queue_messages
      selector:
        matchLabels:
          queue: llm-agent-tasks
    target:
      type: AverageValue
      averageValue: "10"  # 10 messages per pod
```

### Load Balancing

**Service-level**: Kubernetes Service (round-robin)
**Istio**: Intelligent routing with circuit breakers

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: llm-agent-lb
spec:
  host: llm-agent-service
  trafficPolicy:
    loadBalancer:
      consistentHash:
        httpHeaderName: X-User-ID  # Session affinity
    connectionPool:
      tcp:
        maxConnections: 1000
      http:
        http1MaxPendingRequests: 1024
        maxRequestsPerConnection: 10
```

## Vertical Scaling

### When to Scale Vertically

- **Databases**: Scale up before horizontal scaling
- **Memory-intensive services**: LLM Agent Service
- **Stateful services**: Better to scale up than out

### Database Vertical Scaling

```hcl
# Terraform - upgrade PostgreSQL instance
resource "aws_rds_instance" "postgres" {
  identifier = "platform-postgres"

  # Start: db.r5.xlarge (4 vCPU, 32 GB)
  # Scale: db.r5.2xlarge (8 vCPU, 64 GB)
  # Max: db.r5.8xlarge (32 vCPU, 256 GB)
  instance_class = var.db_instance_class

  allocated_storage = 500  # GB
  max_allocated_storage = 2000  # Auto-expand to 2 TB

  # ... other config
}
```

**Scaling procedure** (zero downtime):
1. Create read replica with larger instance
2. Wait for replication to catch up
3. Promote replica to primary
4. Update application connection strings
5. Delete old primary

## Database Scaling

### Read Replicas

```
┌─────────────┐
│   Primary   │ ◄── Writes
│ (Master DB) │
└──────┬──────┘
       │ Replication
       ├──────────────┬──────────────┐
       ↓              ↓              ↓
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│  Replica 1  │ │  Replica 2  │ │  Replica 3  │ ◄── Reads
│   (Read)    │ │   (Read)    │ │   (Read)    │
└─────────────┘ └─────────────┘ └─────────────┘
```

**PHP Connection Routing**:

```php
<?php
// DatabaseConnectionFactory.php
final class DatabaseConnectionFactory
{
    public function __construct(
        private readonly string $primaryDsn,
        private readonly array $replicaDsns,
    ) {
    }

    public function getWriteConnection(): PDO
    {
        return new PDO($this->primaryDsn);
    }

    public function getReadConnection(): PDO
    {
        // Load balance across replicas
        $dsn = $this->replicaDsns[array_rand($this->replicaDsns)];
        return new PDO($dsn);
    }
}

// Usage
$writeDb = $factory->getWriteConnection();
$writeDb->exec("INSERT INTO workflows ...");

$readDb = $factory->getReadConnection();
$results = $readDb->query("SELECT * FROM workflows WHERE ...");
```

### Table Partitioning

For large tables (> 10M rows), use partitioning:

```sql
-- Partition audit_log table by month
CREATE TABLE audit_log (
    id BIGSERIAL,
    created_at TIMESTAMPTZ NOT NULL,
    -- ... other columns
) PARTITION BY RANGE (created_at);

-- Create partitions
CREATE TABLE audit_log_2025_01 PARTITION OF audit_log
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE audit_log_2025_02 PARTITION OF audit_log
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Automatic partition management
CREATE OR REPLACE FUNCTION create_next_partition()
RETURNS void AS $$
DECLARE
    partition_date DATE := DATE_TRUNC('month', NOW() + INTERVAL '1 month');
    partition_name TEXT := 'audit_log_' || TO_CHAR(partition_date, 'YYYY_MM');
BEGIN
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS %I PARTITION OF audit_log
         FOR VALUES FROM (%L) TO (%L)',
        partition_name,
        partition_date,
        partition_date + INTERVAL '1 month'
    );
END;
$$ LANGUAGE plpgsql;

-- Schedule via cron
SELECT cron.schedule('create-partition', '0 0 1 * *', 'SELECT create_next_partition()');
```

### Connection Pooling

**PgBouncer** reduces connection overhead:

```ini
# pgbouncer.ini
[databases]
llm_agent_db = host=postgres-primary port=5432 dbname=llm_agent_db

[pgbouncer]
pool_mode = transaction
max_client_conn = 10000
default_pool_size = 25
reserve_pool_size = 10
reserve_pool_timeout = 3

# Timeouts
server_idle_timeout = 600
server_lifetime = 3600
```

**Deployment**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pgbouncer
  namespace: data
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: pgbouncer
        image: edoburu/pgbouncer:1.20
        resources:
          requests:
            cpu: 500m
            memory: 256Mi
          limits:
            cpu: 1000m
            memory: 512Mi
```

## Caching Strategy

### Multi-Layer Caching

```
Request
  │
  ├──> CDN (CloudFlare) ◄── Static assets, API responses (public)
  │         TTL: 1 hour
  │
  ├──> Application Cache (Redis) ◄── Session data, computed results
  │         TTL: 5-60 minutes
  │
  ├──> Database Query Cache (PostgreSQL) ◄── Query results
  │         TTL: Variable
  │
  └──> Database
```

### Redis Caching

```php
<?php
// Cache workflow results
final class WorkflowCacheService
{
    public function __construct(
        private readonly \Redis $redis,
        private readonly WorkflowRepository $repository,
    ) {
    }

    public function getWorkflow(string $workflowId): Workflow
    {
        $cacheKey = "workflow:{$workflowId}";

        // Try cache first
        $cached = $this->redis->get($cacheKey);
        if ($cached !== false) {
            return unserialize($cached);
        }

        // Cache miss - fetch from database
        $workflow = $this->repository->findById($workflowId);

        // Cache for 10 minutes
        $this->redis->setex($cacheKey, 600, serialize($workflow));

        return $workflow;
    }

    public function invalidate(string $workflowId): void
    {
        $this->redis->del("workflow:{$workflowId}");
    }
}
```

### Cache Invalidation

**Strategy**: Write-through cache with TTL

```php
// On workflow update
public function updateWorkflow(Workflow $workflow): void
{
    // Update database
    $this->repository->save($workflow);

    // Invalidate cache
    $this->cache->invalidate($workflow->getId());

    // Publish event for distributed cache invalidation
    $this->eventBus->publish(new WorkflowUpdated($workflow->getId()));
}
```

## Performance Optimization

### Database Optimization

**1. Indexes**:
```sql
-- Index frequently queried columns
CREATE INDEX CONCURRENTLY idx_workflows_user_id ON workflows(user_id);
CREATE INDEX CONCURRENTLY idx_workflows_status ON workflows(status);
CREATE INDEX CONCURRENTLY idx_workflows_created_at ON workflows(created_at);

-- Composite index for common query
CREATE INDEX CONCURRENTLY idx_workflows_user_status
    ON workflows(user_id, status, created_at DESC);
```

**2. Query Optimization**:
```sql
-- Bad: N+1 query
SELECT * FROM workflows WHERE user_id = '123';
-- Then for each workflow:
SELECT * FROM steps WHERE workflow_id = '{workflow_id}';

-- Good: JOIN
SELECT w.*, array_agg(s.*) as steps
FROM workflows w
LEFT JOIN steps s ON w.id = s.workflow_id
WHERE w.user_id = '123'
GROUP BY w.id;
```

**3. Connection Pooling** (see above)

### Application Optimization

**1. Async Processing**:
```php
// Don't wait for slow operations
public function createWorkflow(CreateWorkflowCommand $command): string
{
    // Create workflow (fast)
    $workflow = Workflow::create($command);
    $this->repository->save($workflow);

    // Queue async tasks (don't wait)
    $this->messageBus->dispatch(new ValidateWorkflowMessage($workflow->getId()));
    $this->messageBus->dispatch(new NotifyUserMessage($workflow->getUserId()));

    // Return immediately
    return $workflow->getId();
}
```

**2. Lazy Loading**:
```php
// Load related data only when accessed
class Workflow
{
    private ?array $steps = null;

    public function getSteps(): array
    {
        if ($this->steps === null) {
            $this->steps = $this->stepRepository->findByWorkflowId($this->id);
        }
        return $this->steps;
    }
}
```

**3. Batch Operations**:
```php
// Bad: Individual saves
foreach ($workflows as $workflow) {
    $this->repository->save($workflow);  // N queries
}

// Good: Batch save
$this->repository->saveAll($workflows);  // 1 query
```

## Load Testing

### Load Testing Tools

**Apache JMeter**: HTTP load testing
**K6**: Modern load testing
**Locust**: Python-based distributed load testing

### Load Test Scenarios

**Scenario 1: Normal Load**
- 100 requests/second
- 80% reads, 20% writes
- Duration: 1 hour

**Scenario 2: Peak Load (10x)**
- 1,000 requests/second
- 80% reads, 20% writes
- Duration: 30 minutes

**Scenario 3: Spike Test**
- Ramp from 100 to 1,000 req/s in 1 minute
- Hold for 10 minutes
- Ramp down

**Scenario 4: Soak Test**
- Steady 300 req/s
- Duration: 24 hours
- Check for memory leaks

### K6 Load Test Example

```javascript
// loadtest.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 },   // Ramp up to 100 users
    { duration: '5m', target: 100 },   // Stay at 100 users
    { duration: '2m', target: 1000 },  // Ramp up to 1000 users
    { duration: '10m', target: 1000 }, // Stay at 1000 users (10x load)
    { duration: '2m', target: 0 },     // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<200'],  // 95% of requests < 200ms
    http_req_failed: ['rate<0.01'],    // Error rate < 1%
  },
};

export default function () {
  // Simulate workflow creation
  let payload = JSON.stringify({
    name: 'Test Workflow',
    definition: { /* ... */ },
  });

  let params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + __ENV.API_TOKEN,
    },
  };

  let res = http.post('https://api.platform.local/api/v1/workflows', payload, params);

  check(res, {
    'status is 201': (r) => r.status === 201,
    'response time < 200ms': (r) => r.timings.duration < 200,
  });

  sleep(1);
}
```

### Running Load Tests

```bash
# Run load test
k6 run --out influxdb=http://localhost:8086/k6 loadtest.js

# View results in Grafana
# Dashboard: K6 Load Testing Results
```

## Capacity Planning

### Resource Estimation

**Current capacity** (3 replicas per service):
- Handles: 100 req/s
- CPU: 10 cores
- Memory: 30 GB

**Target capacity** (10x):
- Needs: 1,000 req/s
- Estimated CPU: 100 cores
- Estimated Memory: 300 GB

### Cost Projection

| Scale | Nodes | Cost/Month |
|-------|-------|------------|
| **Current (1x)** | 9 | $1,500 |
| **5x** | 30 | $5,000 |
| **10x** | 60 | $10,000 |

**Optimization opportunities**:
- Spot instances: 70% savings on application nodes
- Reserved instances: 40% savings on data nodes
- Right-sizing: Use VPA recommendations

### Scaling Roadmap

**Phase 1: 2x Scale** (Month 1-3)
- [x] Enable HPA on all services
- [x] Add read replicas
- [x] Implement caching
- [ ] Load test at 2x

**Phase 2: 5x Scale** (Month 4-6)
- [ ] Database partitioning
- [ ] Multi-region read replicas
- [ ] CDN for all assets
- [ ] Load test at 5x

**Phase 3: 10x Scale** (Month 7-12)
- [ ] Multi-region active-active
- [ ] Advanced caching (Redis Cluster)
- [ ] Database sharding
- [ ] Load test at 10x

## Monitoring Scaling

### Key Metrics

```promql
# Pod count by service
count(kube_pod_info{namespace="application"}) by (pod)

# CPU/Memory utilization
container_cpu_usage_seconds_total{namespace="application"}
container_memory_usage_bytes{namespace="application"}

# HPA status
kube_horizontalpodautoscaler_status_current_replicas
kube_horizontalpodautoscaler_status_desired_replicas

# Request rate
rate(http_requests_total{namespace="application"}[5m])

# Database connections
pg_stat_database_numbackends
```

### Scaling Alerts

```yaml
- alert: HPAMaxedOut
  expr: |
    kube_horizontalpodautoscaler_status_current_replicas ==
    kube_horizontalpodautoscaler_spec_max_replicas
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "HPA {{ $labels.horizontalpodautoscaler }} has reached max replicas"

- alert: DatabaseConnectionsHigh
  expr: pg_stat_database_numbackends > 900
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Database connections > 90% of limit"
```

## Best Practices

1. **Design for horizontal scaling**: Stateless services
2. **Use caching aggressively**: Reduce database load
3. **Implement circuit breakers**: Prevent cascading failures
4. **Monitor everything**: Know when to scale
5. **Load test regularly**: Validate scaling strategy
6. **Plan capacity ahead**: Don't scale reactively
7. **Optimize first**: Scaling costs money
8. **Use auto-scaling**: Let Kubernetes handle it

## References

- [Kubernetes HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [PostgreSQL Scaling](https://www.postgresql.org/docs/current/high-availability.html)
- [K6 Load Testing](https://k6.io/docs/)

## Related Documentation

- [01-infrastructure-overview.md](01-infrastructure-overview.md) - Infrastructure overview
- [02-kubernetes-architecture.md](02-kubernetes-architecture.md) - Kubernetes auto-scaling
- [04-observability-stack.md](04-observability-stack.md) - Monitoring for scaling

---

**Document Maintainers**: Platform Team, SRE Team
**Review Cycle**: Quarterly and before major traffic increases
**Next Review**: 2025-04-07
