# Container Diagram (C4 Level 2)

## Overview

The Container diagram zooms into the AI Workflow Platform system boundary, showing the high-level technical containers (applications, data stores, microservices) and how they interact.

## Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                             │
│                           End Users (Web, Mobile, CLI)                                      │
│                                                                                             │
└────────────────────────────────────────┬────────────────────────────────────────────────────┘
                                         │
                                    HTTPS │
                                         │
                    ┌────────────────────▼──────────────────────┐
                    │                                            │
                    │          API Gateway (Kong)                │
                    │                                            │
                    │  - Rate Limiting                           │
                    │  - Authentication (JWT validation)         │
                    │  - WAF                                     │
                    │  - Request Routing                         │
                    │                                            │
                    └────────────┬───────────────────────────────┘
                                 │
                                 │ HTTP
                                 │
┌────────────────────────────────▼─────────────────────────────────────────────────────────┐
│                                                                                          │
│                        Service Mesh (Istio)                                              │
│                   - mTLS between all services                                            │
│                   - Traffic management (circuit breakers, retries)                       │
│                   - Observability (metrics, logs, traces)                                │
│                                                                                          │
└────────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬─────────┘
         │      │      │      │      │      │      │      │      │      │      │
    ┌────▼──┐┌──▼──┐┌──▼──┐┌──▼──┐┌──▼──┐┌──▼──┐┌──▼──┐┌──▼──┐┌──▼──┐┌──▼──┐┌──▼──┐
    │       ││     ││     ││     ││     ││     ││     ││     ││     ││     ││     │
    │  BFF  ││ LLM ││ Work││Valid││Notif││Audit││File ││Prome││Grafa││ Loki││Tempo│
    │Service││Agent││flow ││ation││ica- ││ &   ││Stor.││theus││na   ││     ││     │
    │       ││Serv.││Orch.││Serv.││tion ││Log. ││Serv.││     ││     ││     ││     │
    │       ││     ││Serv.││     ││Serv.││Serv.││     ││     ││     ││     ││     │
    │(Symf.)││(Sym)││(Sym)││(Sym)││(Sym)││(Sym)││(Sym)││(Time││(Vis)││(Logs││(Trac│
    │       ││     ││     ││     ││     ││     ││     ││Ser.)││     ││     ││ing) │
    └───┬───┘└──┬──┘└──┬──┘└──┬──┘└──┬──┘└──┬──┘└──┬──┘└──┬──┘└──┬──┘└──┬──┘└─────┘
        │       │      │      │      │      │      │      │      │      │
        │       │      │      │      │      │      │      │      │      │
        ├───────┴──────┴──────┴──────┴──────┴──────┴──────┘      │      │
        │                                                          │      │
        │                  ┌───────────────────────────────────────┘      │
        │                  │                                               │
        ▼                  ▼                                               ▼
┌──────────────┐  ┌──────────────┐                                ┌──────────────┐
│              │  │              │                                │              │
│  RabbitMQ    │  │   Redis      │                                │  OpenTelem.  │
│              │  │   Cache      │                                │  Collector   │
│ - Events     │  │              │                                │              │
│ - Commands   │  │ - Session    │                                │ - Traces     │
│ - DLQ        │  │ - App Cache  │                                │ - Metrics    │
│              │  │ - Rate Limit │                                │              │
└──────────────┘  └──────────────┘                                └──────────────┘

┌────────────────────────────────────────────────────────────────────────────────┐
│                          PostgreSQL Databases                                  │
│  (One database per microservice - database-per-service pattern)               │
│                                                                                │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │  LLM     │ │ Workflow │ │Validation│ │Notifica- │ │  Audit   │  ...      │
│  │  Agent   │ │   DB     │ │    DB    │ │  tion DB │ │    DB    │           │
│  │   DB     │ │          │ │          │ │          │ │(TimescDB)│           │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘           │
│                                                                                │
│  Features: ACID, JSONB, Full-text search, Extensions                          │
└────────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────────┐
│                       S3-Compatible Object Storage                             │
│                                                                                │
│  - Uploaded files                                                              │
│  - File versions                                                               │
│  - Database backups                                                            │
│  - Encryption at rest (AES-256)                                                │
└────────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────────┐
│                         HashiCorp Vault                                        │
│                                                                                │
│  - API keys (OpenAI, Anthropic, etc.)                                          │
│  - Database credentials                                                        │
│  - Encryption keys                                                             │
│  - Certificates for mTLS                                                       │
│  - Dynamic secret generation                                                   │
└────────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────────┐
│                            Keycloak                                            │
│                                                                                │
│  - User authentication (OAuth2/OIDC)                                           │
│  - JWT token issuance                                                          │
│  - Multi-factor authentication                                                 │
│  - User federation (LDAP/AD)                                                   │
└────────────────────────────────────────────────────────────────────────────────┘

                                    │
                                    │ HTTPS
                                    │
                                    ▼
                        ┌───────────────────────┐
                        │  External Services    │
                        │                       │
                        │  - OpenAI API         │
                        │  - Anthropic API      │
                        │  - SMTP Server        │
                        │  - Twilio API         │
                        └───────────────────────┘
```

## Containers Detail

### 1. API Gateway (Kong)

**Technology**: Kong (Nginx-based)
**Language**: Lua
**Port**: 443 (HTTPS)

**Responsibilities**:
- Route requests to appropriate microservices
- Validate JWT tokens (from Keycloak)
- Rate limiting per user/API key
- Web Application Firewall (WAF)
- Request/response transformation
- CORS handling
- API analytics

**Configuration**:
```yaml
plugins:
  - jwt-auth
  - rate-limiting
  - cors
  - request-transformer
  - response-transformer
  - prometheus
```

**Scaling**: Stateless, horizontal scaling (10+ replicas)

**Why Kong?**:
- High performance (Nginx core)
- Rich plugin ecosystem
- Declarative configuration (GitOps friendly)
- Prometheus metrics out-of-box

### 2. Service Mesh (Istio)

**Technology**: Istio
**Components**:
- Envoy proxy (sidecar)
- Pilot (control plane)
- Citadel (certificate management)

**Responsibilities**:
- Automatic mTLS between services
- Traffic management (retries, circuit breakers, timeouts)
- Load balancing
- Service discovery
- Distributed tracing
- Metrics collection
- Authorization policies

**Why Istio?**:
- Zero trust network security
- Observability without code changes
- Sophisticated traffic management
- Multi-cluster support (future)

### 3. BFF Service (Backend for Frontend)

**Technology**: PHP 8.3 + Symfony 7
**Port**: 8080
**Database**: None (stateless)

**Responsibilities**:
- Aggregate data from multiple services
- Client-specific API optimization
- Response transformation
- Reduce API chattiness

**Dependencies**:
- → All backend services (HTTP)
- → Redis (caching)

**Scaling**: Stateless, auto-scale based on CPU > 70%

**Endpoints**:
```
GET  /api/v1/dashboard
GET  /api/v1/workflows/{id}/complete
POST /api/v1/workflows/execute
```

### 4. LLM Agent Service

**Technology**: PHP 8.3 + Symfony 7
**Port**: 8080
**Database**: PostgreSQL (llm_agent_db)

**Responsibilities**:
- Manage AI agents and configurations
- Execute prompts against LLM providers
- Parse and structure responses
- Track token usage and costs
- Maintain conversation context
- Provider abstraction (OpenAI, Anthropic, etc.)

**Dependencies**:
- → OpenAI API (HTTPS)
- → Anthropic API (HTTPS)
- → Vault (secret retrieval)
- → RabbitMQ (publish events)

**Scaling**: CPU-based auto-scaling, queue depth monitoring

**Database Tables**:
- agents
- executions
- contexts
- token_usage

### 5. Workflow Orchestrator Service

**Technology**: PHP 8.3 + Symfony 7
**Port**: 8080
**Database**: PostgreSQL (workflow_db)

**Responsibilities**:
- Define and manage workflow templates
- Execute multi-step workflows
- Coordinate agent executions
- Implement saga pattern for distributed transactions
- Handle workflow state machine
- Retry and compensation logic

**Dependencies**:
- → LLM Agent Service (HTTP)
- → Validation Service (HTTP)
- → Notification Service (events)
- → RabbitMQ (commands, events)

**Scaling**: Task queue depth monitoring, horizontal scaling

**Database Tables**:
- workflows
- workflow_instances
- tasks
- saga_compensations

### 6. Validation Service

**Technology**: PHP 8.3 + Symfony 7
**Port**: 8080
**Database**: PostgreSQL (validation_db)

**Responsibilities**:
- Define validation rules
- Execute validations (regex, NLP, custom)
- Score outputs
- Generate feedback
- Track validation history

**Dependencies**:
- → RabbitMQ (events)
- → Redis (rule caching)

**Scaling**: Stateless, CPU-based auto-scaling

**Database Tables**:
- validation_rules
- validation_results
- scoring_models

### 7. Notification Service

**Technology**: PHP 8.3 + Symfony 7
**Port**: 8080
**Database**: PostgreSQL (notification_db)

**Responsibilities**:
- Send multi-channel notifications (email, SMS, webhook)
- Template management
- Delivery tracking
- User preferences
- Retry failed deliveries

**Dependencies**:
- → SMTP Server (email)
- → Twilio API (SMS)
- → RabbitMQ (consume events, async delivery)

**Scaling**: Queue-based processing, horizontal scaling

**Database Tables**:
- notification_templates
- notifications
- notification_preferences

### 8. Audit & Logging Service

**Technology**: PHP 8.3 + Symfony 7
**Port**: 8080
**Database**: PostgreSQL + TimescaleDB (audit_db)

**Responsibilities**:
- Capture all system events
- Immutable audit trail
- Compliance reporting (GDPR, SOC2, ISO27001, NIS2)
- Data retention and anonymization
- Forensic analysis

**Dependencies**:
- → RabbitMQ (consume all events)
- → S3 (export reports)

**Scaling**: Write-heavy optimization, partitioned tables

**Database Tables**:
- audit_events (hypertable)
- retention_policies
- compliance_reports

### 9. File Storage Service

**Technology**: PHP 8.3 + Symfony 7
**Port**: 8080
**Database**: PostgreSQL (file_storage_db)

**Responsibilities**:
- File upload/download
- Virus scanning (ClamAV)
- Version management
- Access control
- Generate pre-signed URLs

**Dependencies**:
- → S3-compatible storage
- → ClamAV (virus scanning)
- → RabbitMQ (async scanning)

**Scaling**: Upload queue management, horizontal scaling

**Database Tables**:
- files
- file_versions
- file_permissions
- scan_results

### 10. RabbitMQ (Message Broker)

**Technology**: RabbitMQ 3.12+
**Ports**: 5672 (AMQP), 15672 (Management UI)

**Responsibilities**:
- Event bus (integration events)
- Command queue (async commands)
- Dead letter queue (failed messages)
- Message persistence
- Guaranteed delivery

**Exchanges**:
- `workflow.events` (topic)
- `agent.events` (topic)
- `system.events` (fanout)
- `dlx` (dead letter exchange)

**Queues**:
- Per-service event queues
- Command queues
- DLQ for manual inspection

**Why RabbitMQ?**:
- Flexible routing (exchanges, bindings)
- Message acknowledgments
- Publisher confirms
- Easier setup than Kafka

**Alternative**: Kafka for high-throughput scenarios (>100k msgs/sec)

### 11. Redis (Cache)

**Technology**: Redis 7+
**Port**: 6379

**Use Cases**:
- Session storage
- Application cache (API responses, rules)
- Rate limiting counters
- Distributed locks
- Pub/Sub (real-time updates)

**Data Structures**:
- String (simple cache)
- Hash (user sessions)
- Set (rate limiting)
- Sorted Set (leaderboards, time-based data)

**Scaling**: Redis Cluster for high availability

### 12. PostgreSQL Databases

**Technology**: PostgreSQL 15+
**Port**: 5432

**Pattern**: Database per service

**Configuration**:
- Connection pooling (PgBouncer)
- Read replicas for query scaling
- WAL archiving for PITR
- Automated backups (daily full + continuous WAL)

**Extensions**:
- TimescaleDB (audit service, time-series)
- pgvector (future: embeddings)
- pg_stat_statements (query performance)

**Why PostgreSQL?**:
- ACID compliance
- Rich features (JSONB, full-text search)
- Excellent performance
- Strong ecosystem

### 13. S3-Compatible Object Storage

**Technology**: AWS S3 / MinIO / GCS
**Protocol**: S3 API

**Stored Data**:
- Uploaded files (all versions)
- Database backups
- Log archives
- Compliance report exports

**Features**:
- Server-side encryption (AES-256)
- Versioning enabled
- Lifecycle policies (archive old data)
- Cross-region replication (production)

**Access**:
- IAM policies
- Pre-signed URLs (time-limited)
- S3 bucket policies

### 14. HashiCorp Vault

**Technology**: Vault 1.15+
**Port**: 8200 (HTTPS)

**Stored Secrets**:
- LLM API keys (OpenAI, Anthropic)
- Database credentials
- SMTP credentials
- Twilio API keys
- Encryption keys
- mTLS certificates

**Features**:
- Dynamic secret generation
- Automatic rotation
- Encryption as a service
- Audit logging
- Lease management

**Access**:
- Kubernetes service accounts
- AppRole authentication
- Least privilege policies

### 15. Keycloak

**Technology**: Keycloak 23+
**Port**: 8080

**Responsibilities**:
- User authentication (login, logout)
- JWT token issuance
- Multi-factor authentication
- User management
- Role-Based Access Control (RBAC)
- User federation (LDAP, Active Directory)

**Integration**:
- OAuth2/OIDC provider
- Services validate JWT tokens
- User info endpoint for profile data

**Deployment**: High availability (2+ replicas)

### 16. Prometheus (Metrics)

**Technology**: Prometheus 2.45+
**Port**: 9090

**Responsibilities**:
- Scrape metrics from all services
- Store time-series data
- Query metrics (PromQL)
- Alerting rules
- Service discovery (Kubernetes)

**Metrics Sources**:
- Microservices (HTTP /metrics endpoint)
- PostgreSQL Exporter
- RabbitMQ Exporter
- Redis Exporter
- Istio metrics
- Node Exporter (infrastructure)

**Retention**: 30 days (high resolution), longer in Thanos (optional)

### 17. Grafana (Visualization)

**Technology**: Grafana 10+
**Port**: 3000

**Responsibilities**:
- Visualize metrics from Prometheus
- Visualize logs from Loki
- Visualize traces from Tempo
- Pre-built dashboards per service
- Alerting (via Alertmanager)

**Dashboards**:
- System overview
- Per-service dashboards
- Business metrics (workflows, validations)
- SLO dashboard

### 18. Loki (Log Aggregation)

**Technology**: Grafana Loki 2.9+
**Port**: 3100

**Responsibilities**:
- Aggregate logs from all services
- Index logs by labels (service, level, etc.)
- Query logs (LogQL - similar to PromQL)
- Integrate with Grafana

**Log Sources**:
- All microservices (JSON logs)
- Kubernetes pod logs
- Istio access logs

**Retention**: 30 days

### 19. Tempo (Distributed Tracing)

**Technology**: Grafana Tempo 2.3+
**Port**: 3200

**Responsibilities**:
- Collect traces from OpenTelemetry
- Store trace data
- Query traces by trace ID
- Integrate with Grafana

**Instrumentation**: OpenTelemetry SDK in all services

**Sampling**: 10% of requests (configurable)

### 20. OpenTelemetry Collector

**Technology**: OpenTelemetry Collector
**Ports**: 4317 (gRPC), 4318 (HTTP)

**Responsibilities**:
- Receive traces from services
- Receive metrics from services
- Process and transform telemetry
- Export to Tempo (traces) and Prometheus (metrics)

**Pipeline**: Receive → Process → Export

## Communication Patterns

### Synchronous (HTTP/REST)

```
BFF Service ──HTTP──> LLM Agent Service
BFF Service ──HTTP──> Workflow Service
Workflow Service ──HTTP──> LLM Agent Service
Workflow Service ──HTTP──> Validation Service
```

**Use Case**: Immediate response needed

### Asynchronous (Events/RabbitMQ)

```
Workflow Service ──publish──> RabbitMQ ──subscribe──> Notification Service
LLM Agent Service ──publish──> RabbitMQ ──subscribe──> Audit Service
Validation Service ──publish──> RabbitMQ ──subscribe──> Audit Service
```

**Use Case**: Fire-and-forget, multiple subscribers

### Database Access

```
Each Service ──direct access──> Its own PostgreSQL database
Service A ──NEVER──> Service B's database  ❌
```

**Rule**: No cross-service database access (database-per-service)

## Security Between Containers

### Authentication

**User → API Gateway**:
- JWT token (from Keycloak)
- API key (for programmatic access)

**Service → Service**:
- mTLS (via Istio)
- JWT tokens (alternative)

### Authorization

**API Gateway**:
- Rate limiting
- Basic authorization (API key check)

**Microservices**:
- Detailed authorization (RBAC/ABAC)
- Domain-specific rules

### Encryption

**In Transit**:
- TLS 1.3 (external)
- mTLS (internal)

**At Rest**:
- Database: Transparent Data Encryption
- S3: Server-side encryption (AES-256)
- Vault: All secrets encrypted

## Deployment

All containers deployed on **Kubernetes**:

```yaml
# Example: Workflow service deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: workflow-service
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: workflow
        image: workflow-service:1.0.0
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
```

## Monitoring & Observability

**Metrics**: Prometheus scrapes `/metrics` from each service
**Logs**: Structured JSON logs to stdout → Loki
**Traces**: OpenTelemetry instrumentation → Tempo
**Dashboards**: Grafana visualizes all three

## Scaling Strategy

| Container | Scaling Trigger | Min | Max |
|-----------|----------------|-----|-----|
| BFF Service | CPU > 70% | 2 | 20 |
| LLM Agent Service | CPU > 70% | 3 | 30 |
| Workflow Service | Queue depth > 100 | 2 | 20 |
| Validation Service | CPU > 70% | 2 | 10 |
| Notification Service | Queue depth > 1000 | 2 | 10 |
| Audit Service | Write throughput | 2 | 10 |
| File Storage Service | Upload queue > 100 | 2 | 10 |

**Stateless Services**: Scale horizontally with ease
**Stateful Services** (databases): Vertical scaling + read replicas

## Conclusion

The Container diagram shows:

✅ **7 Microservices**: Clear responsibilities, bounded contexts
✅ **Database per Service**: Data ownership and autonomy
✅ **Message Broker**: Asynchronous, event-driven communication
✅ **Observability Stack**: Complete visibility (metrics, logs, traces)
✅ **Security Infrastructure**: Vault, Keycloak, mTLS
✅ **Caching & Storage**: Redis, PostgreSQL, S3

This architecture supports independent deployment, scaling, and evolution of each container while maintaining strong operational excellence and security.
