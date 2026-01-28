# Observability Stack

**Document Version**: 1.0
**Last Updated**: 2025-01-07
**Status**: Complete

## Table of Contents

1. [Overview](#overview)
2. [Observability Architecture](#observability-architecture)
3. [Metrics (Prometheus + Grafana)](#metrics-prometheus--grafana)
4. [Logging (Loki)](#logging-loki)
5. [Tracing (Tempo)](#tracing-tempo)
6. [Alerting (AlertManager)](#alerting-alertmanager)
7. [Dashboards](#dashboards)
8. [Data Retention](#data-retention)
9. [Performance Considerations](#performance-considerations)

## Overview

Complete observability is critical for operating a production platform. Our observability stack provides comprehensive metrics, logs, and traces for all services.

### The Three Pillars

| Pillar | Tool | Purpose | Retention |
|--------|------|---------|-----------|
| **Metrics** | Prometheus + Grafana | Performance monitoring, alerting | 30 days |
| **Logs** | Loki | Application and system logs | 7-30 days |
| **Traces** | Tempo | Distributed request tracing | 7 days |

### Stack Components

```
┌─────────────────────────────────────────────────────────────┐
│                   Observability Stack                        │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Prometheus  │  │     Loki     │  │    Tempo     │      │
│  │  (Metrics)   │  │    (Logs)    │  │   (Traces)   │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │              │
│         └──────────────────┼──────────────────┘              │
│                            │                                 │
│                    ┌───────▼────────┐                        │
│                    │    Grafana     │                        │
│                    │ (Visualization)│                        │
│                    └────────────────┘                        │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐                         │
│  │AlertManager  │  │   Promtail   │                         │
│  │  (Alerts)    │  │ (Log Collector)│                       │
│  └──────────────┘  └──────────────┘                         │
└─────────────────────────────────────────────────────────────┘
```

## Observability Architecture

### Data Flow

```
Application Pods
  ├─> Metrics endpoint (:9090) ──> Prometheus ──> Grafana
  ├─> Logs (stdout/stderr) ──> Promtail ──> Loki ──> Grafana
  └─> Traces (OTLP) ──> Tempo ──> Grafana
```

### Namespace

All observability components deployed in `observability` namespace:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: observability
  labels:
    name: observability
    tier: observability
    istio-injection: disabled  # Avoid circular dependency
```

## Metrics (Prometheus + Grafana)

### Prometheus Installation

Using kube-prometheus-stack Helm chart:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --create-namespace \
  --values - <<EOF
prometheus:
  prometheusSpec:
    replicas: 2
    retention: 30d
    retentionSize: "50GB"
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: standard-ssd
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 100Gi

    resources:
      requests:
        cpu: 500m
        memory: 2Gi
      limits:
        cpu: 2000m
        memory: 4Gi

    # Service monitors
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false

grafana:
  replicas: 2
  persistence:
    enabled: true
    storageClassName: standard-ssd
    size: 10Gi

  adminPassword: <vault-secret>

  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
      - name: Prometheus
        type: prometheus
        url: http://kube-prometheus-stack-prometheus:9090
        access: proxy
        isDefault: true

      - name: Loki
        type: loki
        url: http://loki:3100
        access: proxy

      - name: Tempo
        type: tempo
        url: http://tempo:3100
        access: proxy

alertmanager:
  alertmanagerSpec:
    replicas: 3
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: standard-ssd
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
EOF
```

### Service Monitor Example

Expose metrics from services:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: llm-agent-metrics
  namespace: application
  labels:
    app: llm-agent-service
spec:
  selector:
    matchLabels:
      app: llm-agent-service
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
    scheme: http
```

### Key Metrics

**RED Metrics** (Rate, Errors, Duration):
- `http_requests_total` - Request count
- `http_request_duration_seconds` - Request latency
- `http_requests_errors_total` - Error count

**USE Metrics** (Utilization, Saturation, Errors):
- CPU/Memory utilization
- Queue depth (saturation)
- Error rates

### Prometheus Queries

```promql
# Request rate (per second)
rate(http_requests_total[5m])

# P95 latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Error rate
rate(http_requests_errors_total[5m]) / rate(http_requests_total[5m])

# Pod CPU usage
container_cpu_usage_seconds_total{namespace="application"}

# Pod memory usage
container_memory_usage_bytes{namespace="application"}
```

## Logging (Loki)

### Loki Installation

```bash
helm repo add grafana https://grafana.github.io/helm-charts

helm install loki grafana/loki-stack \
  --namespace observability \
  --values - <<EOF
loki:
  enabled: true
  replicas: 3

  persistence:
    enabled: true
    storageClassName: standard-ssd
    size: 100Gi

  config:
    auth_enabled: false

    ingester:
      chunk_idle_period: 3m
      chunk_block_size: 262144
      chunk_retain_period: 1m
      max_transfer_retries: 0
      lifecycler:
        ring:
          kvstore:
            store: inmemory
          replication_factor: 3

    limits_config:
      enforce_metric_name: false
      reject_old_samples: true
      reject_old_samples_max_age: 168h
      retention_period: 168h  # 7 days

    schema_config:
      configs:
      - from: 2024-01-01
        store: boltdb-shipper
        object_store: filesystem
        schema: v11
        index:
          prefix: index_
          period: 24h

    server:
      http_listen_port: 3100

    storage_config:
      boltdb_shipper:
        active_index_directory: /data/loki/boltdb-shipper-active
        cache_location: /data/loki/boltdb-shipper-cache
        cache_ttl: 24h
        shared_store: filesystem
      filesystem:
        directory: /data/loki/chunks

  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 2Gi

promtail:
  enabled: true

  config:
    clients:
    - url: http://loki:3100/loki/api/v1/push

    scrapeConfigs: |
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
        - role: pod

        relabel_configs:
        # Add namespace label
        - source_labels: [__meta_kubernetes_namespace]
          target_label: namespace

        # Add pod name label
        - source_labels: [__meta_kubernetes_pod_name]
          target_label: pod

        # Add container name label
        - source_labels: [__meta_kubernetes_pod_container_name]
          target_label: container

        # Drop pods without logging
        - source_labels: [__meta_kubernetes_pod_label_app]
          action: keep
          regex: .+

  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
EOF
```

### LogQL Queries

```logql
# All logs from namespace
{namespace="application"}

# Logs from specific service
{namespace="application", app="llm-agent-service"}

# Error logs only
{namespace="application"} |= "ERROR"

# Filter by log level
{namespace="application"} | json | level="error"

# Count errors per minute
sum(count_over_time({namespace="application"} |= "ERROR"[1m]))
```

### Structured Logging

All services log in JSON format:

```json
{
  "timestamp": "2025-01-07T10:30:45.123Z",
  "level": "INFO",
  "message": "Workflow started",
  "context": {
    "workflow_id": "wf-123",
    "user_id": "usr-456",
    "tenant_id": "tnt-789"
  },
  "trace_id": "abc123...",
  "span_id": "def456..."
}
```

## Tracing (Tempo)

### Tempo Installation

```bash
helm install tempo grafana/tempo \
  --namespace observability \
  --values - <<EOF
tempo:
  replicas: 3

  retention: 168h  # 7 days

  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318

  storage:
    trace:
      backend: local
      local:
        path: /var/tempo/traces
      wal:
        path: /var/tempo/wal

  persistence:
    enabled: true
    storageClassName: standard-ssd
    size: 100Gi

  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 2Gi
EOF
```

### OpenTelemetry Integration

Istio automatically instruments traces. Application code can add custom spans:

```php
<?php
// PHP OpenTelemetry example
use OpenTelemetry\API\Trace\Span;
use OpenTelemetry\SDK\Trace\TracerProvider;

$tracer = TracerProvider::getInstance()->getTracer('llm-agent-service');

$span = $tracer->spanBuilder('process_completion')
    ->startSpan();

try {
    // Business logic here
    $result = $this->processCompletion($request);

    $span->setAttribute('completion.tokens', $result->tokenCount);
    $span->setStatus(\OpenTelemetry\API\Trace\StatusCode::STATUS_OK);
} catch (\Exception $e) {
    $span->recordException($e);
    $span->setStatus(\OpenTelemetry\API\Trace\StatusCode::STATUS_ERROR);
    throw $e;
} finally {
    $span->end();
}
```

## Alerting (AlertManager)

### Alert Rules

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: application-alerts
  namespace: observability
spec:
  groups:
  - name: application
    interval: 30s
    rules:
    # High error rate
    - alert: HighErrorRate
      expr: |
        (
          rate(http_requests_errors_total{namespace="application"}[5m])
          /
          rate(http_requests_total{namespace="application"}[5m])
        ) > 0.05
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High error rate on {{ $labels.app }}"
        description: "Error rate is {{ $value | humanizePercentage }} for 5 minutes"

    # High latency
    - alert: HighLatency
      expr: |
        histogram_quantile(0.95,
          rate(http_request_duration_seconds_bucket{namespace="application"}[5m])
        ) > 1.0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High P95 latency on {{ $labels.app }}"
        description: "P95 latency is {{ $value }}s"

    # Pod not ready
    - alert: PodNotReady
      expr: |
        kube_pod_status_phase{namespace="application",phase!="Running"} == 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Pod {{ $labels.pod }} not ready"
        description: "Pod in phase {{ $labels.phase }}"

    # Pod restart loop
    - alert: PodRestartLoop
      expr: |
        rate(kube_pod_container_status_restarts_total{namespace="application"}[15m]) > 0.1
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Pod {{ $labels.pod }} restarting frequently"
        description: "Restart rate: {{ $value }}/s"
```

### AlertManager Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: observability
data:
  alertmanager.yml: |
    global:
      resolve_timeout: 5m

    route:
      receiver: 'default'
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h

      routes:
      # Critical alerts go to PagerDuty
      - match:
          severity: critical
        receiver: pagerduty
        continue: true

      # All alerts go to Slack
      - match_re:
          severity: warning|critical
        receiver: slack

    receivers:
    - name: 'default'
      slack_configs:
      - api_url: '<slack-webhook-url>'
        channel: '#alerts'
        title: 'Platform Alert'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}\n{{ .Annotations.description }}\n{{ end }}'

    - name: 'pagerduty'
      pagerduty_configs:
      - service_key: '<pagerduty-key>'
        description: '{{ .CommonAnnotations.summary }}'

    - name: 'slack'
      slack_configs:
      - api_url: '<slack-webhook-url>'
        channel: '#alerts'
```

## Dashboards

### Grafana Dashboards

**1. Platform Overview**
- Total requests/second
- P95/P99 latency
- Error rate
- Active users
- Resource utilization

**2. Service Dashboard (per service)**
- Request rate
- Latency percentiles (P50, P95, P99)
- Error rate
- CPU/Memory usage
- Pod count

**3. Infrastructure Dashboard**
- Node CPU/Memory
- Disk usage
- Network I/O
- Pod distribution

**4. Database Dashboard**
- Connection pool usage
- Query duration
- Slow queries
- Replication lag

**5. RabbitMQ Dashboard**
- Queue length
- Message rate
- Consumer count
- Memory usage

### Dashboard as Code

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-llm-agent
  namespace: observability
  labels:
    grafana_dashboard: "1"
data:
  llm-agent-dashboard.json: |
    {
      "dashboard": {
        "title": "LLM Agent Service",
        "panels": [
          {
            "title": "Request Rate",
            "targets": [{
              "expr": "rate(http_requests_total{app=\"llm-agent-service\"}[5m])"
            }]
          },
          {
            "title": "P95 Latency",
            "targets": [{
              "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app=\"llm-agent-service\"}[5m]))"
            }]
          }
        ]
      }
    }
```

## Data Retention

### Retention Policies

| Data Type | Retention | Storage | Cost/Month |
|-----------|-----------|---------|------------|
| **Prometheus Metrics** | 30 days | 100 GB | $10 |
| **Loki Logs (detailed)** | 7 days | 200 GB | $20 |
| **Loki Logs (important)** | 30 days | 100 GB | $10 |
| **Tempo Traces** | 7 days | 100 GB | $10 |
| **Long-term metrics** | 1 year | 50 GB | $5 |

**Total**: ~$55/month for observability storage

### Retention Configuration

**Prometheus**:
```yaml
retention: 30d
retentionSize: "50GB"
```

**Loki**:
```yaml
limits_config:
  retention_period: 168h  # 7 days
```

**Tempo**:
```yaml
retention: 168h  # 7 days
```

## Performance Considerations

### Resource Requirements

| Component | CPU Request | Memory Request | Storage |
|-----------|-------------|----------------|---------|
| **Prometheus** | 500m | 2Gi | 100Gi |
| **Grafana** | 200m | 512Mi | 10Gi |
| **Loki** | 500m | 1Gi | 100Gi |
| **Promtail** (per node) | 100m | 128Mi | - |
| **Tempo** | 500m | 1Gi | 100Gi |
| **AlertManager** | 100m | 256Mi | 10Gi |

**Total cluster overhead**: ~3 CPUs, ~6 GB RAM

### Optimization Tips

1. **Sample rate**: Reduce Prometheus scrape frequency for non-critical metrics
2. **Log filtering**: Drop debug logs in production
3. **Trace sampling**: Sample 10% of traces (not 100%)
4. **Compression**: Enable compression for all components
5. **Retention**: Shorter retention = lower storage costs

## Monitoring the Monitors

Monitor the observability stack itself:

```yaml
# Alert if Prometheus is down
- alert: PrometheusDown
  expr: up{job="prometheus"} == 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Prometheus is down"

# Alert if Loki is down
- alert: LokiDown
  expr: up{job="loki"} == 0
  for: 5m
  labels:
    severity: critical
```

## Troubleshooting

### Common Issues

**High cardinality metrics**:
```bash
# Find high cardinality metrics
kubectl exec -it prometheus-0 -n observability -- \
  promtool tsdb analyze /prometheus
```

**Loki out of disk**:
```bash
# Check Loki disk usage
kubectl exec -it loki-0 -n observability -- df -h

# Delete old data
kubectl exec -it loki-0 -n observability -- \
  rm -rf /data/loki/chunks/fake/*
```

**Missing traces**:
```bash
# Check Tempo is receiving traces
kubectl logs -n observability tempo-0 | grep "received spans"

# Check app is sending traces
kubectl logs -n application <app-pod> | grep "trace"
```

## Best Practices

1. **Structure logs as JSON**: Easier to query
2. **Include trace/span IDs in logs**: Correlate logs with traces
3. **Use labels wisely**: Don't use high-cardinality labels
4. **Set up alerts**: Don't just collect data, alert on it
5. **Dashboard for every service**: Standardize dashboards
6. **Test alerts**: Regularly verify alerts fire correctly
7. **Monitor costs**: Track storage and ingestion costs

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [Tempo Documentation](https://grafana.com/docs/tempo/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)

## Related Documentation

- [02-kubernetes-architecture.md](02-kubernetes-architecture.md) - Kubernetes configuration
- [../02-security/05-network-security.md](../02-security/05-network-security.md) - Network monitoring
- [../07-operations/01-monitoring-alerting.md](../07-operations/01-monitoring-alerting.md) - Operations monitoring

---

**Document Maintainers**: Platform Team, SRE Team
**Review Cycle**: Quarterly
**Next Review**: 2025-04-07
