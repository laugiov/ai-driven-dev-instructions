# Microservices Catalog

## Overview

This document provides a comprehensive catalog of all microservices in the system, their responsibilities, boundaries, and interactions. Each service is aligned with a specific bounded context following Domain-Driven Design principles.

## Service Overview Matrix

| Service | Bounded Context | Primary Responsibility | Data Ownership | Dependencies |
|---------|----------------|----------------------|----------------|--------------|
| **BFF Service** | User Interface | Client-specific API composition | None (stateless) | All services |
| **LLM Agent Service** | AI Processing | LLM interaction and management | Agent state, prompts, responses | None |
| **Workflow Orchestrator** | Process Management | Workflow execution and coordination | Workflow state, tasks | LLM Agent, Validation |
| **Validation Service** | Quality Control | Result validation and scoring | Validation rules, results | None |
| **Notification Service** | Communication | Multi-channel notifications | Notification templates, history | None |
| **Audit & Logging Service** | Compliance | Audit trail and compliance logs | Audit logs, events | None |
| **File Storage Service** | Document Management | File upload, storage, retrieval | File metadata, versions | None |

## Detailed Service Specifications

### 1. BFF Service (Backend for Frontend)

#### Purpose
Provides client-optimized APIs by aggregating and transforming data from multiple backend services. Acts as a facade to simplify client integration.

#### Bounded Context
**User Interface Context** - Focused on presentation and user interaction patterns.

#### Core Responsibilities
- **API Composition**: Aggregate data from multiple services into single responses
- **Request Orchestration**: Coordinate calls to multiple services
- **Response Transformation**: Format responses for specific client needs (web, mobile, CLI)
- **Client-Specific Optimization**: Reduce chattiness, minimize payload size
- **GraphQL Gateway** (optional): Provide flexible query interface

#### Data Ownership
- **None**: BFF is stateless and does not own any data
- May cache responses temporarily (Redis) for performance

#### Key Interactions
- **Inbound**: External clients (Web UI, Mobile App, CLI)
- **Outbound**: All backend services via REST/gRPC

#### API Examples
```
GET /api/v1/workflows/{id}/complete
  → Aggregates: workflow details + execution history + validation results

POST /api/v1/agents/execute
  → Orchestrates: LLM Agent + Workflow + Notification

GET /api/v1/dashboard/summary
  → Composes: Active workflows + recent results + system health
```

#### Technology Stack
- Symfony 7 (API Platform)
- HTTP/REST primary
- Redis for response caching
- No database

#### Scaling Characteristics
- **Stateless**: Highly scalable horizontally
- **Auto-scaling trigger**: CPU > 70%
- **Expected load**: 1000 req/sec at peak

#### Anti-Patterns to Avoid
- ❌ **NO business logic**: All business rules belong in domain services
- ❌ **NO data persistence**: BFF must remain stateless
- ❌ **NO direct database access**: Always through backend services

---

### 2. LLM Agent Service

#### Purpose
Manages interactions with Large Language Model providers, handles prompt engineering, response parsing, and maintains conversation context.

#### Bounded Context
**AI Processing Context** - Everything related to LLM interaction and AI agent behavior.

#### Core Responsibilities
- **LLM Provider Abstraction**: Adapter pattern for multiple providers (OpenAI, Anthropic, etc.)
- **Prompt Management**: Template-based prompts with variable substitution
- **Response Parsing**: Extract structured data from LLM responses
- **Context Management**: Maintain conversation history and context windows
- **Token Management**: Track usage, estimate costs, enforce limits
- **Retry Logic**: Handle transient failures with exponential backoff
- **Rate Limiting**: Respect provider rate limits
- **Result Caching**: Cache deterministic responses (optional)

#### Data Ownership
- **Agent Configurations**: Stored prompts, templates, settings
- **Execution History**: LLM requests and responses
- **Context State**: Conversation threads and context windows
- **Token Usage**: Consumption metrics per agent/user

#### Domain Model (Key Entities)
```
Agent (Aggregate Root)
├── AgentId (Identity)
├── Name
├── Model (GPT-4, GPT-3.5, etc.)
├── SystemPrompt (ValueObject)
├── Configuration (temperature, max_tokens, etc.)
└── Status (active, inactive, rate_limited)

Execution (Entity)
├── ExecutionId
├── AgentId
├── Prompt (ValueObject)
├── Response (ValueObject)
├── TokensUsed
├── Latency
├── Status (pending, completed, failed)
└── CreatedAt

Context (Entity)
├── ContextId
├── AgentId
├── Messages[] (role, content, timestamp)
└── WindowSize
```

#### LLM Provider Adapter Interface
```php
interface LLMProviderInterface
{
    public function execute(
        Prompt $prompt,
        Model $model,
        Configuration $config
    ): Response;

    public function streamExecute(
        Prompt $prompt,
        Model $model,
        Configuration $config
    ): StreamInterface;

    public function estimateTokens(Prompt $prompt): int;

    public function getSupportedModels(): array;
}
```

#### Supported Providers (via Adapters)
- **OpenAI** (GPT-4, GPT-3.5-turbo) - Primary
- **Anthropic** (Claude 3 Opus, Sonnet, Haiku)
- **Google** (PaLM, Gemini)
- **Azure OpenAI** (Enterprise deployments)
- **Local Models** (Ollama, LM Studio) - for development/testing

#### Key Interactions
- **Inbound**: Workflow Orchestrator, BFF Service
- **Outbound**: LLM Provider APIs (OpenAI, etc.), Audit Service (events)

#### Events Published
- `AgentExecutionRequested`
- `AgentExecutionCompleted`
- `AgentExecutionFailed`
- `RateLimitExceeded`
- `TokenLimitApproaching`

#### API Examples
```
POST /api/v1/agents/{agentId}/execute
  Request: { prompt, context, parameters }
  Response: { executionId, response, tokensUsed, latency }

GET /api/v1/agents/{agentId}/executions
  Response: Paginated execution history

POST /api/v1/agents
  Request: { name, model, systemPrompt, configuration }
  Response: Created agent details

GET /api/v1/providers
  Response: Available LLM providers and models
```

#### Technology Stack
- Symfony 7
- PostgreSQL (agent configs, executions)
- Redis (response caching, rate limiting)
- HTTP client (Guzzle) for provider APIs

#### Scaling Characteristics
- **Stateless execution**: Each request independent
- **Auto-scaling trigger**: Request queue depth > 100
- **Rate limiting**: Per-provider, per-agent
- **Expected load**: 500 concurrent executions

#### Security Considerations
- **API Keys**: Stored in Vault, rotated regularly
- **PII Filtering**: Detect and redact sensitive data in prompts
- **Audit Trail**: All executions logged to Audit Service
- **Cost Control**: Token limits per user/tenant

---

### 3. Workflow Orchestrator Service

#### Purpose
Orchestrates complex multi-step AI workflows involving multiple agents, validations, and decision points. Implements saga pattern for distributed transactions.

#### Bounded Context
**Process Management Context** - Workflow execution, task scheduling, state management.

#### Core Responsibilities
- **Workflow Definition**: Define multi-step workflows with decision trees
- **State Machine**: Manage workflow state transitions
- **Saga Orchestration**: Coordinate distributed transactions with compensation
- **Task Scheduling**: Schedule agent executions in sequence or parallel
- **Conditional Logic**: Branch based on validation results or agent outputs
- **Retry & Compensation**: Handle failures with retries and rollback
- **Progress Tracking**: Monitor and report workflow progress
- **Timeout Management**: Enforce workflow and step timeouts

#### Data Ownership
- **Workflow Definitions**: Workflow templates and configurations
- **Workflow Instances**: Active and completed workflow executions
- **Task State**: Individual task status and results
- **Execution Graph**: DAG of task dependencies

#### Domain Model
```
Workflow (Aggregate Root)
├── WorkflowId (Identity)
├── Name
├── Version
├── Steps[] (Step)
│   ├── StepId
│   ├── Type (agent, validation, decision, parallel)
│   ├── Configuration
│   └── NextSteps[] (conditional)
├── Status (draft, active, deprecated)
└── CreatedAt

WorkflowInstance (Aggregate Root)
├── InstanceId (Identity)
├── WorkflowId
├── CurrentStep
├── State (running, paused, completed, failed)
├── Context (shared data between steps)
├── Tasks[] (Task)
│   ├── TaskId
│   ├── StepId
│   ├── Status (pending, running, completed, failed)
│   ├── Input
│   ├── Output
│   ├── AttemptCount
│   └── Duration
├── StartedAt
├── CompletedAt
└── Metadata

WorkflowEvent (Domain Event)
├── EventId
├── InstanceId
├── Type (started, step_completed, failed, compensated)
├── Payload
└── OccurredAt
```

#### Workflow Patterns Supported
1. **Sequential**: Steps execute one after another
2. **Parallel**: Multiple steps execute concurrently
3. **Conditional**: Branch based on previous results
4. **Loop**: Repeat steps until condition met
5. **Saga**: Distributed transaction with compensation
6. **Human-in-the-Loop**: Wait for manual approval

#### Example Workflow: Multi-Agent Validation
```yaml
workflow:
  name: "Multi-Agent Content Validation"
  version: "1.0"
  steps:
    - id: "generate"
      type: "agent"
      agent: "content-generator"
      next: "validate-parallel"

    - id: "validate-parallel"
      type: "parallel"
      steps:
        - id: "validate-grammar"
          type: "agent"
          agent: "grammar-checker"

        - id: "validate-facts"
          type: "agent"
          agent: "fact-checker"

        - id: "validate-tone"
          type: "agent"
          agent: "tone-analyzer"
      next: "aggregate-results"

    - id: "aggregate-results"
      type: "validation"
      service: "validation-service"
      decision:
        - condition: "score >= 0.8"
          next: "notify-success"
        - condition: "score < 0.8"
          next: "regenerate"

    - id: "regenerate"
      type: "agent"
      agent: "content-generator"
      context: "previous-feedback"
      next: "validate-parallel"
      max-iterations: 3

    - id: "notify-success"
      type: "notification"
      template: "workflow-completed"
```

#### Key Interactions
- **Inbound**: BFF Service, scheduled jobs, webhooks
- **Outbound**: LLM Agent Service, Validation Service, Notification Service

#### Events Published
- `WorkflowStarted`
- `StepCompleted`
- `StepFailed`
- `WorkflowCompleted`
- `WorkflowFailed`
- `CompensationTriggered`

#### API Examples
```
POST /api/v1/workflows
  Request: Workflow definition YAML/JSON
  Response: { workflowId, version }

POST /api/v1/workflows/{workflowId}/execute
  Request: { input, parameters }
  Response: { instanceId, status }

GET /api/v1/workflows/instances/{instanceId}
  Response: Current state, completed steps, pending steps

POST /api/v1/workflows/instances/{instanceId}/pause
POST /api/v1/workflows/instances/{instanceId}/resume
POST /api/v1/workflows/instances/{instanceId}/cancel
```

#### Technology Stack
- Symfony 7 (Symfony Messenger for task queue)
- PostgreSQL (workflow definitions, instances)
- RabbitMQ (task queue, event bus)
- Redis (distributed locks for state management)

#### Scaling Characteristics
- **State Persistence**: All state in PostgreSQL
- **Distributed Execution**: Workers can scale horizontally
- **Auto-scaling trigger**: Queue depth > 500
- **Expected load**: 10,000 workflows/day

#### Saga Implementation
- **Compensation Actions**: Each step defines compensation logic
- **Idempotency**: All operations idempotent (safe to retry)
- **Timeout Handling**: Steps timeout → trigger compensation
- **Dead Letter Queue**: Failed compensations logged for manual intervention

---

### 4. Validation Service

#### Purpose
Validates outputs from LLM agents against predefined rules, quality standards, and business logic. Provides scoring and feedback for workflow decision-making.

#### Bounded Context
**Quality Control Context** - Validation rules, quality checks, result scoring.

#### Core Responsibilities
- **Rule-Based Validation**: Define and execute validation rules
- **Scoring Engine**: Calculate quality scores based on multiple criteria
- **Pattern Matching**: Regex, NLP-based content validation
- **Business Rule Execution**: Domain-specific validation logic
- **Feedback Generation**: Provide actionable feedback for improvement
- **Validation History**: Track validation results over time
- **A/B Testing**: Compare validation strategies

#### Data Ownership
- **Validation Rules**: Rule definitions, configurations
- **Validation Results**: Historical validation outcomes
- **Scoring Models**: Weighted scoring formulas
- **Feedback Templates**: Structured feedback messages

#### Domain Model
```
ValidationRule (Aggregate Root)
├── RuleId (Identity)
├── Name
├── Type (regex, nlp, custom, composite)
├── Configuration
├── Severity (error, warning, info)
├── Weight (for scoring)
└── Status (active, inactive)

ValidationRequest (Entity)
├── RequestId
├── SourceType (agent_response, workflow_output)
├── SourceId
├── Content
├── RuleIds[]
└── Context

ValidationResult (Value Object)
├── ResultId
├── RequestId
├── OverallScore (0-1)
├── RuleResults[]
│   ├── RuleId
│   ├── Passed (boolean)
│   ├── Score
│   ├── Feedback
│   └── Details
├── Status (passed, failed, warning)
└── ValidatedAt

ScoringModel (Entity)
├── ModelId
├── Name
├── Rules[] (RuleId + Weight)
├── Thresholds (pass/fail)
└── Version
```

#### Validation Rule Types

**1. Regex-Based**
```yaml
rule:
  type: regex
  pattern: "^[A-Z].*[.!?]$"
  description: "Sentence starts with capital, ends with punctuation"
```

**2. NLP-Based**
```yaml
rule:
  type: nlp
  check: sentiment
  expected: positive
  threshold: 0.7
```

**3. Length-Based**
```yaml
rule:
  type: length
  min: 100
  max: 500
  unit: characters
```

**4. Custom PHP Logic**
```php
class CustomValidationRule implements ValidationRuleInterface
{
    public function validate(Content $content, Context $context): RuleResult
    {
        // Custom business logic
        return new RuleResult($passed, $score, $feedback);
    }
}
```

**5. Composite (Multiple Rules)**
```yaml
rule:
  type: composite
  operator: AND
  rules:
    - rule-1
    - rule-2
    - rule-3
  aggregation: weighted_average
```

#### Key Interactions
- **Inbound**: Workflow Orchestrator, LLM Agent Service
- **Outbound**: Audit Service (validation events)

#### Events Published
- `ValidationRequested`
- `ValidationCompleted`
- `ValidationFailed`
- `ThresholdExceeded`

#### API Examples
```
POST /api/v1/validations/validate
  Request: { content, rules[], context }
  Response: { resultId, score, passed, feedback[] }

POST /api/v1/validations/rules
  Request: Rule definition
  Response: { ruleId }

GET /api/v1/validations/rules
  Response: Paginated rule list

GET /api/v1/validations/results/{resultId}
  Response: Detailed validation result
```

#### Technology Stack
- Symfony 7
- PostgreSQL (rules, results)
- Redis (rule caching)
- NLP Libraries (if needed): spaCy via Python microservice

#### Scaling Characteristics
- **Stateless**: Each validation independent
- **Cache Rules**: Rules cached in Redis
- **Auto-scaling trigger**: CPU > 70%
- **Expected load**: 5,000 validations/hour

---

### 5. Notification Service

#### Purpose
Delivers multi-channel notifications (email, SMS, webhooks, in-app) to users based on system events and workflow outcomes.

#### Bounded Context
**Communication Context** - Notification delivery, template management, channel abstraction.

#### Core Responsibilities
- **Multi-Channel Delivery**: Email, SMS, webhook, in-app notifications
- **Template Management**: Twig-based templates with variable substitution
- **Delivery Scheduling**: Immediate, delayed, or scheduled delivery
- **Retry Logic**: Handle failed deliveries with exponential backoff
- **Delivery Tracking**: Track delivery status, opens, clicks
- **Preference Management**: User notification preferences
- **Batching**: Group notifications for efficiency
- **Rate Limiting**: Prevent notification spam

#### Data Ownership
- **Templates**: Notification templates per channel
- **Notification History**: Sent notifications and delivery status
- **User Preferences**: Opt-in/opt-out settings per channel
- **Delivery Logs**: Success/failure logs

#### Domain Model
```
NotificationTemplate (Aggregate Root)
├── TemplateId (Identity)
├── Name
├── Type (email, sms, webhook, in_app)
├── Subject (for email)
├── Body (Twig template)
├── Variables[]
└── Status (active, inactive)

Notification (Aggregate Root)
├── NotificationId (Identity)
├── RecipientId
├── TemplateId
├── Channel (email, sms, webhook, in_app)
├── Priority (low, normal, high, urgent)
├── Status (pending, sent, failed, bounced)
├── ScheduledAt (nullable)
├── SentAt (nullable)
├── Metadata (tracking, context)
└── Retries

NotificationPreference (Entity)
├── UserId
├── Channel
├── Enabled (boolean)
└── Frequency (immediate, digest, off)

DeliveryLog (Value Object)
├── NotificationId
├── Attempt
├── Status
├── Provider (SMTP, Twilio, etc.)
├── Error (nullable)
└── Timestamp
```

#### Supported Channels

**1. Email (SMTP)**
- Provider: SendGrid, AWS SES, Postmark
- Features: HTML templates, attachments, tracking

**2. SMS (Twilio)**
- Provider: Twilio, AWS SNS
- Features: International delivery, delivery receipts

**3. Webhook**
- POST to external URLs
- Retry with exponential backoff
- Signature verification

**4. In-App**
- Push to WebSocket or polling endpoint
- Real-time delivery
- Read/unread status

#### Key Interactions
- **Inbound**: All services (via events), Workflow Orchestrator
- **Outbound**: External providers (SMTP, Twilio), Audit Service

#### Events Consumed
- `WorkflowCompleted` → Send success notification
- `WorkflowFailed` → Send failure alert
- `ValidationFailed` → Send quality alert
- `SystemAlert` → Send admin notification

#### Events Published
- `NotificationSent`
- `NotificationFailed`
- `NotificationBounced`

#### API Examples
```
POST /api/v1/notifications/send
  Request: { recipientId, templateId, variables, channel, priority }
  Response: { notificationId, status }

GET /api/v1/notifications/{notificationId}/status
  Response: { status, sentAt, deliveredAt, error }

POST /api/v1/notifications/templates
  Request: Template definition
  Response: { templateId }

PUT /api/v1/users/{userId}/preferences
  Request: { channel, enabled, frequency }
```

#### Technology Stack
- Symfony 7 (Symfony Mailer, Notifier)
- PostgreSQL (templates, history, preferences)
- RabbitMQ (async delivery queue)
- Redis (rate limiting)

#### Scaling Characteristics
- **Async Processing**: All notifications via message queue
- **Batch Processing**: Group emails for efficiency
- **Auto-scaling trigger**: Queue depth > 1000
- **Expected load**: 50,000 notifications/day

---

### 6. Audit & Logging Service

#### Purpose
Provides comprehensive audit trail for compliance (GDPR, SOC2, ISO27001, NIS2), captures all system events, and enables forensic analysis.

#### Bounded Context
**Compliance Context** - Audit logs, event capture, compliance reporting.

#### Core Responsibilities
- **Event Capture**: Capture all domain events from all services
- **Audit Trail**: Immutable log of all actions (who, what, when, where)
- **Compliance Reporting**: Generate reports for auditors
- **Data Retention**: Enforce retention policies (GDPR right to be forgotten)
- **Tamper Detection**: Ensure log integrity (hashing, signing)
- **Search & Query**: Powerful search across audit logs
- **Anonymization**: Pseudonymize/anonymize PII in logs
- **Export**: Export logs in standard formats (JSON, CSV, SIEM)

#### Data Ownership
- **Audit Logs**: All captured events
- **Compliance Metadata**: Retention policies, anonymization rules
- **Access Logs**: Who accessed what data when

#### Domain Model
```
AuditEvent (Aggregate Root, Immutable)
├── EventId (Identity, UUID)
├── Timestamp (microsecond precision)
├── EventType (user_action, system_event, security_event)
├── Actor (userId, serviceId, IP address)
├── Action (create, read, update, delete, execute)
├── Resource (type, id)
├── Result (success, failure, partial)
├── Metadata (request_id, session_id, trace_id)
├── Before (previous state, nullable)
├── After (new state, nullable)
├── Checksum (SHA-256 hash for integrity)
└── Signature (optional, for critical events)

ComplianceReport (Entity)
├── ReportId
├── Type (gdpr, soc2, iso27001, nis2)
├── StartDate
├── EndDate
├── Filters
├── GeneratedAt
└── Status (generating, completed, failed)

RetentionPolicy (Entity)
├── PolicyId
├── EventType
├── RetentionPeriod (days)
├── AnonymizationRules[]
└── DeletionStrategy (hard_delete, anonymize)
```

#### Event Categories

**1. User Actions**
- Login/logout
- Data access (read sensitive data)
- Data modifications (create, update, delete)
- Configuration changes

**2. System Events**
- Service started/stopped
- Workflow execution
- Agent execution
- Validation results

**3. Security Events**
- Authentication failures
- Authorization denials
- Suspicious activity
- Rate limit exceeded
- Token expiration

**4. Compliance Events**
- GDPR data export request
- Right to be forgotten request
- Consent given/revoked
- Data breach detection

#### Key Interactions
- **Inbound**: All services (via event bus)
- **Outbound**: SIEM systems, log aggregation (Loki)

#### Events Consumed
- **All domain events** from all services

#### API Examples
```
POST /api/v1/audit/events
  Request: Event data (internal API, not exposed externally)

GET /api/v1/audit/events
  Query: { actorId, resourceType, dateRange, limit }
  Response: Paginated events

POST /api/v1/audit/reports/generate
  Request: { type, startDate, endDate, filters }
  Response: { reportId, status }

GET /api/v1/audit/reports/{reportId}/download
  Response: Report file (PDF, CSV, JSON)

POST /api/v1/audit/retention/apply
  Request: { policyId }
  Response: { eventsAffected, status }
```

#### Technology Stack
- Symfony 7
- PostgreSQL (with partitioning by date)
- TimescaleDB extension (time-series optimization)
- Elasticsearch (optional, for advanced search)
- RabbitMQ (event ingestion)

#### Scaling Characteristics
- **Write-Heavy**: Optimized for high write throughput
- **Partitioning**: Partition tables by month
- **Async Ingestion**: Events buffered in RabbitMQ
- **Auto-scaling trigger**: Write throughput > 10k events/sec
- **Expected load**: 1M events/day

#### Compliance Features

**GDPR**
- Right to access: Export all user data
- Right to be forgotten: Anonymize or delete user data
- Data portability: Export in machine-readable format
- Consent tracking: Log consent given/revoked

**SOC2**
- Access logging: All data access logged
- Change tracking: All modifications logged
- Incident response: Security events tracked
- Availability logging: System uptime events

**ISO27001 / NIS2**
- Security event logging
- Configuration change tracking
- Incident management
- Risk assessment data

---

### 7. File Storage Service

#### Purpose
Manages secure file upload, storage, retrieval, and lifecycle management with virus scanning and access control.

#### Bounded Context
**Document Management Context** - File operations, metadata, versioning, access control.

#### Core Responsibilities
- **File Upload**: Multipart upload, resumable uploads, chunking
- **Virus Scanning**: Scan all uploads with ClamAV
- **Storage Management**: Store in S3-compatible object storage
- **Access Control**: Fine-grained permissions (who can read/write)
- **Versioning**: Track file versions
- **Metadata Management**: Store file metadata (tags, description)
- **Temporary URLs**: Generate pre-signed URLs for secure access
- **Lifecycle Management**: Auto-delete old files, archive cold storage
- **Encryption**: At-rest encryption (AES-256)
- **Thumbnails**: Generate thumbnails for images

#### Data Ownership
- **File Metadata**: Filename, size, MIME type, owner, permissions
- **Version History**: File versions and changes
- **Access Logs**: Who accessed which file when
- **Storage Keys**: Mapping between logical IDs and storage paths

#### Domain Model
```
File (Aggregate Root)
├── FileId (Identity, UUID)
├── Name
├── MimeType
├── Size (bytes)
├── OwnerId
├── StorageKey (S3 path)
├── Status (uploading, scanning, available, quarantined, deleted)
├── Versions[] (FileVersion)
│   ├── VersionId
│   ├── StorageKey
│   ├── Size
│   ├── UploadedAt
│   └── UploadedBy
├── Metadata (tags, description, custom fields)
├── Permissions[] (FilePermission)
│   ├── UserId / RoleId
│   ├── Level (read, write, delete)
│   └── ExpiresAt (nullable)
├── UploadedAt
└── LastAccessedAt

FileVersion (Entity)
├── VersionId
├── FileId
├── VersionNumber
├── StorageKey
├── Size
├── Checksum (SHA-256)
├── UploadedBy
└── UploadedAt

ScanResult (Value Object)
├── FileId
├── VersionId
├── Scanner (ClamAV)
├── Status (clean, infected, error)
├── Threats[] (if infected)
└── ScannedAt
```

#### File Upload Flow
1. **Initiate Upload**: Client requests upload → Receive uploadId
2. **Upload Chunks**: Client uploads file in chunks (multipart)
3. **Complete Upload**: Client signals completion → Assemble chunks
4. **Virus Scan**: ClamAV scans assembled file
5. **Store**: If clean, move to S3; if infected, quarantine
6. **Notify**: Publish `FileUploaded` or `FileQuarantined` event

#### Key Interactions
- **Inbound**: BFF Service, Workflow Orchestrator, external clients
- **Outbound**: S3-compatible storage, ClamAV, Audit Service

#### Events Published
- `FileUploaded`
- `FileScanned`
- `FileQuarantined`
- `FileDeleted`
- `FileAccessGranted`
- `FileAccessRevoked`

#### API Examples
```
POST /api/v1/files/upload/initiate
  Request: { filename, size, mimeType }
  Response: { uploadId, chunkSize }

PUT /api/v1/files/upload/{uploadId}/chunk/{chunkNumber}
  Request: Binary chunk data
  Response: { status }

POST /api/v1/files/upload/{uploadId}/complete
  Response: { fileId, status }

GET /api/v1/files/{fileId}
  Response: File metadata

GET /api/v1/files/{fileId}/download
  Response: Pre-signed URL (redirect) or file stream

DELETE /api/v1/files/{fileId}
  Response: { status }

POST /api/v1/files/{fileId}/permissions
  Request: { userId, level, expiresAt }
  Response: { permissionId }
```

#### Technology Stack
- Symfony 7
- PostgreSQL (metadata, permissions)
- S3-compatible storage (MinIO, AWS S3, GCS)
- ClamAV (virus scanning)
- Redis (upload session state)
- RabbitMQ (async scanning queue)

#### Scaling Characteristics
- **Upload Processing**: Async via queue
- **Storage**: S3 provides automatic scaling
- **Database**: Metadata only, minimal load
- **Auto-scaling trigger**: Upload queue > 100
- **Expected load**: 10,000 uploads/day, 100TB total storage

#### Security Features
- **Encryption at Rest**: S3 server-side encryption (AES-256)
- **Encryption in Transit**: TLS 1.3
- **Virus Scanning**: All uploads scanned before availability
- **Access Control**: Fine-grained permissions
- **Pre-Signed URLs**: Time-limited, revocable URLs
- **Audit Trail**: All access logged to Audit Service

---

## Service Communication Matrix

| From → To | BFF | LLM Agent | Workflow | Validation | Notification | Audit | File Storage |
|-----------|-----|-----------|----------|------------|--------------|-------|--------------|
| **BFF** | - | REST | REST | REST | REST | - | REST |
| **LLM Agent** | - | - | Events | - | - | Events | - |
| **Workflow** | - | REST | - | REST | REST | Events | REST |
| **Validation** | - | - | - | - | - | Events | - |
| **Notification** | - | - | - | - | - | Events | - |
| **Audit** | - | - | - | - | - | - | - |
| **File Storage** | - | - | - | - | - | Events | - |

**Legend**:
- **REST**: Synchronous HTTP/REST calls
- **Events**: Asynchronous via RabbitMQ
- **-**: No direct communication

## Data Flow Example: Multi-Agent Workflow

```
1. User → BFF: POST /api/v1/workflows/execute
2. BFF → Workflow: POST /api/v1/workflows/{id}/execute
3. Workflow → LLM Agent: POST /api/v1/agents/{id}/execute (Agent 1)
4. LLM Agent → Audit: Publish AgentExecutionCompleted event
5. Workflow → Validation: POST /api/v1/validations/validate (Agent 1 output)
6. Validation → Audit: Publish ValidationCompleted event
7. Workflow → LLM Agent: POST /api/v1/agents/{id}/execute (Agent 2, based on validation)
8. LLM Agent → Audit: Publish AgentExecutionCompleted event
9. Workflow → Notification: POST /api/v1/notifications/send (workflow complete)
10. Notification → Audit: Publish NotificationSent event
11. Workflow → Audit: Publish WorkflowCompleted event
12. BFF ← Workflow: Return final result
13. User ← BFF: Return aggregated response
```

## Service Boundary Guidelines

### ✅ DO
- **Own your data**: Each service has exclusive write access to its database
- **Publish events**: Notify other services of state changes via events
- **Accept dependencies**: It's OK for services to call each other (with circuit breakers)
- **Validate at boundaries**: Validate all inputs at service entry points
- **Use DTOs**: Don't expose internal domain models via APIs

### ❌ DON'T
- **Share databases**: Never access another service's database directly
- **Circular dependencies**: Avoid Service A → Service B → Service A
- **Distributed transactions**: Use sagas, not 2PC
- **Shared libraries with business logic**: Infrastructure only
- **Synchronous chains**: Prefer events for non-blocking workflows

## Adding New Services: Checklist

When adding a new microservice:

1. **Define Bounded Context**: What domain does it represent?
2. **Identify Responsibilities**: What is it solely responsible for?
3. **Define Data Ownership**: What data does it own exclusively?
4. **Design Domain Model**: Entities, value objects, aggregates
5. **Define API Contract**: OpenAPI specification
6. **Identify Events**: What events does it publish/consume?
7. **Plan Dependencies**: What services does it depend on?
8. **Security Model**: Authentication, authorization, secrets
9. **Database Schema**: PostgreSQL schema design
10. **Deployment Config**: Kubernetes manifests, Helm chart
11. **Observability**: Metrics, logs, traces
12. **Documentation**: Update this catalog, architecture diagrams

## Conclusion

This microservices architecture balances:
- **Autonomy**: Each service can be developed, deployed, scaled independently
- **Cohesion**: Services are aligned with bounded contexts
- **Resilience**: Failure isolation prevents cascading failures
- **Compliance**: Dedicated audit service ensures regulatory compliance
- **Performance**: Async communication prevents blocking workflows

The catalog ensures all developers have a clear understanding of service boundaries, responsibilities, and interactions.
