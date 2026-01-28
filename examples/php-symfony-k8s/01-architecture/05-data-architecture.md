# Data Architecture

## Overview

This document defines the data architecture for the platform, including database design principles, data ownership patterns, consistency strategies, and migration approaches. Each microservice owns its data following the database-per-service pattern.

## Core Principles

### 1. Database Per Service

**Principle**: Each microservice has its own database that only it can access directly.

**Rationale**:
- ✅ Service autonomy: Services can choose optimal data model
- ✅ Independent scaling: Scale databases independently
- ✅ Failure isolation: Database failure doesn't cascade
- ✅ Technology flexibility: Different services can use different databases
- ✅ Clear ownership: No ambiguity about data ownership

**Implementation**:

```
┌─────────────────────┐     ┌─────────────────────┐
│  LLM Agent Service  │     │  Workflow Service   │
│                     │     │                     │
│  ┌───────────────┐  │     │  ┌───────────────┐  │
│  │   Business    │  │     │  │   Business    │  │
│  │     Logic     │  │     │  │     Logic     │  │
│  └───────┬───────┘  │     │  └───────┬───────┘  │
│          │          │     │          │          │
│  ┌───────▼───────┐  │     │  ┌───────▼───────┐  │
│  │  PostgreSQL   │  │     │  │  PostgreSQL   │  │
│  │  llm_agent_db │  │     │  │  workflow_db  │  │
│  └───────────────┘  │     │  └───────────────┘  │
└─────────────────────┘     └─────────────────────┘
         ❌                           ❌
         No direct access between services
```

**Rules**:
- ✅ Each service owns its database schema
- ✅ Services communicate via APIs or events, never direct DB access
- ✅ Data duplication is acceptable for service autonomy
- ✅ Use eventual consistency for cross-service data

### 2. PostgreSQL for All Services

**Choice**: PostgreSQL 15+ as the standard database for all services.

**Rationale**:
- ✅ **ACID Compliance**: Strong consistency guarantees
- ✅ **Rich Features**: JSONB, full-text search, CTEs, window functions
- ✅ **Extensions**: pgvector (AI embeddings), TimescaleDB (time-series)
- ✅ **Performance**: Excellent query optimizer, parallel queries
- ✅ **Operational Simplicity**: One database technology to maintain
- ✅ **Mature Tooling**: Backups, replication, monitoring

**Configuration**:
```yaml
# Database per service
databases:
  - llm_agent_db      # LLM Agent Service
  - workflow_db       # Workflow Orchestrator
  - validation_db     # Validation Service
  - notification_db   # Notification Service
  - audit_db          # Audit & Logging Service
  - file_storage_db   # File Storage Service
  - bff_cache_db      # BFF Service (cache only, optional)
```

### 3. Schema Design Principles

**Normalize for Consistency, Denormalize for Performance**

**Approach**:
- Start with normalized schema (3NF)
- Denormalize selectively based on access patterns
- Use JSONB for semi-structured data
- Maintain referential integrity

## Database Design Per Service

### LLM Agent Service Database

**Schema**:

```sql
-- Agents table (Aggregate Root)
CREATE TABLE agents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    model VARCHAR(100) NOT NULL, -- 'gpt-4', 'gpt-3.5-turbo', 'claude-3-opus'
    provider VARCHAR(50) NOT NULL, -- 'openai', 'anthropic'
    system_prompt TEXT NOT NULL,
    configuration JSONB NOT NULL DEFAULT '{}', -- temperature, max_tokens, etc.
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,

    CONSTRAINT agents_status_check CHECK (status IN ('active', 'inactive', 'archived'))
);

CREATE INDEX idx_agents_status ON agents(status);
CREATE INDEX idx_agents_created_by ON agents(created_by);
CREATE INDEX idx_agents_provider ON agents(provider);

-- Executions table (Entity)
CREATE TABLE executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    prompt TEXT NOT NULL,
    response TEXT,
    tokens_used INTEGER,
    latency_ms INTEGER,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    error_message TEXT,
    executed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,

    CONSTRAINT executions_status_check CHECK (status IN ('pending', 'running', 'completed', 'failed'))
);

CREATE INDEX idx_executions_agent_id ON executions(agent_id);
CREATE INDEX idx_executions_status ON executions(status);
CREATE INDEX idx_executions_executed_at ON executions(executed_at DESC);

-- Contexts table (for conversation history)
CREATE TABLE contexts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    messages JSONB NOT NULL DEFAULT '[]', -- Array of {role, content, timestamp}
    window_size INTEGER NOT NULL DEFAULT 10,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_contexts_agent_id ON contexts(agent_id);

-- Token usage tracking (for billing/limits)
CREATE TABLE token_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    execution_id UUID REFERENCES executions(id) ON DELETE SET NULL,
    tokens_prompt INTEGER NOT NULL,
    tokens_completion INTEGER NOT NULL,
    tokens_total INTEGER NOT NULL,
    cost_usd DECIMAL(10, 6), -- Cost in USD
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_token_usage_agent_id ON token_usage(agent_id);
CREATE INDEX idx_token_usage_recorded_at ON token_usage(recorded_at DESC);
```

**Data Ownership**:
- Agents and their configurations
- Execution history
- Context/conversation state
- Token usage metrics

### Workflow Orchestrator Database

**Schema**:

```sql
-- Workflows table (Aggregate Root - Template)
CREATE TABLE workflows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    version INTEGER NOT NULL DEFAULT 1,
    status VARCHAR(50) NOT NULL DEFAULT 'draft',
    definition JSONB NOT NULL, -- Workflow steps, conditions, etc.
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,

    CONSTRAINT workflows_status_check CHECK (status IN ('draft', 'active', 'deprecated'))
);

CREATE INDEX idx_workflows_status ON workflows(status);
CREATE INDEX idx_workflows_created_by ON workflows(created_by);

-- Workflow instances (Aggregate Root - Execution)
CREATE TABLE workflow_instances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_id UUID NOT NULL REFERENCES workflows(id) ON DELETE RESTRICT,
    current_step_index INTEGER NOT NULL DEFAULT 0,
    state VARCHAR(50) NOT NULL DEFAULT 'pending',
    context JSONB NOT NULL DEFAULT '{}', -- Shared data between steps
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    error_message TEXT,
    created_by UUID NOT NULL,

    CONSTRAINT workflow_instances_state_check CHECK (
        state IN ('pending', 'running', 'paused', 'completed', 'failed', 'cancelled')
    )
);

CREATE INDEX idx_workflow_instances_workflow_id ON workflow_instances(workflow_id);
CREATE INDEX idx_workflow_instances_state ON workflow_instances(state);
CREATE INDEX idx_workflow_instances_created_by ON workflow_instances(created_by);
CREATE INDEX idx_workflow_instances_started_at ON workflow_instances(started_at DESC);

-- Tasks (Entity - Individual step execution)
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id UUID NOT NULL REFERENCES workflow_instances(id) ON DELETE CASCADE,
    step_id VARCHAR(255) NOT NULL, -- From workflow definition
    step_type VARCHAR(50) NOT NULL, -- 'agent', 'validation', 'parallel', 'decision'
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    input JSONB,
    output JSONB,
    error_message TEXT,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    max_attempts INTEGER NOT NULL DEFAULT 3,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    duration_ms INTEGER,

    CONSTRAINT tasks_status_check CHECK (
        status IN ('pending', 'running', 'completed', 'failed', 'skipped')
    )
);

CREATE INDEX idx_tasks_instance_id ON tasks(instance_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_started_at ON tasks(started_at DESC);

-- Saga compensation log (for distributed transactions)
CREATE TABLE saga_compensations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id UUID NOT NULL REFERENCES workflow_instances(id) ON DELETE CASCADE,
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    compensation_action TEXT NOT NULL,
    compensation_data JSONB,
    executed_at TIMESTAMPTZ,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    error_message TEXT,

    CONSTRAINT saga_compensations_status_check CHECK (
        status IN ('pending', 'executing', 'completed', 'failed')
    )
);

CREATE INDEX idx_saga_compensations_instance_id ON saga_compensations(instance_id);
```

**Data Ownership**:
- Workflow definitions (templates)
- Workflow instances (executions)
- Task state and results
- Saga compensation logs

### Validation Service Database

**Schema**:

```sql
-- Validation rules (Aggregate Root)
CREATE TABLE validation_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    rule_type VARCHAR(50) NOT NULL, -- 'regex', 'nlp', 'custom', 'composite'
    configuration JSONB NOT NULL, -- Rule-specific config
    severity VARCHAR(50) NOT NULL DEFAULT 'error',
    weight DECIMAL(3, 2) NOT NULL DEFAULT 1.0, -- For scoring
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT validation_rules_type_check CHECK (
        rule_type IN ('regex', 'nlp', 'length', 'custom', 'composite')
    ),
    CONSTRAINT validation_rules_severity_check CHECK (
        severity IN ('error', 'warning', 'info')
    ),
    CONSTRAINT validation_rules_status_check CHECK (
        status IN ('active', 'inactive')
    ),
    CONSTRAINT validation_rules_weight_check CHECK (weight >= 0 AND weight <= 1)
);

CREATE INDEX idx_validation_rules_type ON validation_rules(rule_type);
CREATE INDEX idx_validation_rules_status ON validation_rules(status);

-- Validation results (Entity)
CREATE TABLE validation_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_type VARCHAR(50) NOT NULL, -- 'agent_response', 'workflow_output'
    source_id UUID NOT NULL,
    content TEXT NOT NULL,
    overall_score DECIMAL(3, 2) NOT NULL, -- 0.00 to 1.00
    status VARCHAR(50) NOT NULL, -- 'passed', 'failed', 'warning'
    rule_results JSONB NOT NULL, -- Array of individual rule results
    validated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT validation_results_score_check CHECK (
        overall_score >= 0 AND overall_score <= 1
    ),
    CONSTRAINT validation_results_status_check CHECK (
        status IN ('passed', 'failed', 'warning')
    )
);

CREATE INDEX idx_validation_results_source ON validation_results(source_type, source_id);
CREATE INDEX idx_validation_results_validated_at ON validation_results(validated_at DESC);
CREATE INDEX idx_validation_results_status ON validation_results(status);

-- Scoring models (for weighted scoring)
CREATE TABLE scoring_models (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    rules JSONB NOT NULL, -- Array of {rule_id, weight}
    pass_threshold DECIMAL(3, 2) NOT NULL DEFAULT 0.7,
    warning_threshold DECIMAL(3, 2) NOT NULL DEFAULT 0.5,
    version INTEGER NOT NULL DEFAULT 1,
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT scoring_models_status_check CHECK (status IN ('active', 'inactive'))
);
```

**Data Ownership**:
- Validation rules
- Validation results
- Scoring models

### Notification Service Database

**Schema**:

```sql
-- Notification templates (Aggregate Root)
CREATE TABLE notification_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL UNIQUE,
    channel VARCHAR(50) NOT NULL, -- 'email', 'sms', 'webhook', 'in_app'
    subject VARCHAR(500), -- For email
    body TEXT NOT NULL, -- Twig template
    variables JSONB NOT NULL DEFAULT '[]', -- Array of variable names
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT notification_templates_channel_check CHECK (
        channel IN ('email', 'sms', 'webhook', 'in_app')
    ),
    CONSTRAINT notification_templates_status_check CHECK (
        status IN ('active', 'inactive')
    )
);

CREATE INDEX idx_notification_templates_channel ON notification_templates(channel);
CREATE INDEX idx_notification_templates_status ON notification_templates(status);

-- Notifications (Aggregate Root)
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID NOT NULL, -- User ID
    template_id UUID REFERENCES notification_templates(id) ON DELETE SET NULL,
    channel VARCHAR(50) NOT NULL,
    priority VARCHAR(50) NOT NULL DEFAULT 'normal',
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    subject VARCHAR(500),
    body TEXT NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}',
    scheduled_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,
    error_message TEXT,
    retry_count INTEGER NOT NULL DEFAULT 0,
    max_retries INTEGER NOT NULL DEFAULT 3,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT notifications_channel_check CHECK (
        channel IN ('email', 'sms', 'webhook', 'in_app')
    ),
    CONSTRAINT notifications_priority_check CHECK (
        priority IN ('low', 'normal', 'high', 'urgent')
    ),
    CONSTRAINT notifications_status_check CHECK (
        status IN ('pending', 'sending', 'sent', 'delivered', 'failed', 'bounced', 'cancelled')
    )
);

CREATE INDEX idx_notifications_recipient_id ON notifications(recipient_id);
CREATE INDEX idx_notifications_status ON notifications(status);
CREATE INDEX idx_notifications_scheduled_at ON notifications(scheduled_at);
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);

-- Notification preferences (per user)
CREATE TABLE notification_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    channel VARCHAR(50) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT true,
    frequency VARCHAR(50) NOT NULL DEFAULT 'immediate', -- 'immediate', 'digest', 'off'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(user_id, channel),
    CONSTRAINT notification_preferences_channel_check CHECK (
        channel IN ('email', 'sms', 'webhook', 'in_app')
    ),
    CONSTRAINT notification_preferences_frequency_check CHECK (
        frequency IN ('immediate', 'hourly', 'daily', 'weekly', 'off')
    )
);

CREATE INDEX idx_notification_preferences_user_id ON notification_preferences(user_id);
```

**Data Ownership**:
- Notification templates
- Notification history and status
- User preferences

### Audit & Logging Service Database

**Schema** (Optimized for write-heavy workload):

```sql
-- Enable TimescaleDB extension for time-series optimization
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Audit events (Immutable, append-only)
CREATE TABLE audit_events (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    event_type VARCHAR(100) NOT NULL, -- 'user_action', 'system_event', 'security_event'
    actor_type VARCHAR(50) NOT NULL, -- 'user', 'service', 'system'
    actor_id UUID NOT NULL,
    actor_ip_address INET,
    action VARCHAR(100) NOT NULL, -- 'create', 'read', 'update', 'delete', 'execute'
    resource_type VARCHAR(100) NOT NULL,
    resource_id UUID,
    result VARCHAR(50) NOT NULL, -- 'success', 'failure', 'partial'
    metadata JSONB NOT NULL DEFAULT '{}',
    before_state JSONB, -- Previous state (for updates)
    after_state JSONB, -- New state (for creates/updates)
    trace_id UUID, -- For distributed tracing
    session_id UUID,
    checksum VARCHAR(64) NOT NULL, -- SHA-256 for integrity

    PRIMARY KEY (id, timestamp),

    CONSTRAINT audit_events_actor_type_check CHECK (
        actor_type IN ('user', 'service', 'system', 'anonymous')
    ),
    CONSTRAINT audit_events_result_check CHECK (
        result IN ('success', 'failure', 'partial')
    )
);

-- Convert to hypertable for time-series optimization
SELECT create_hypertable('audit_events', 'timestamp', chunk_time_interval => INTERVAL '1 month');

-- Indexes for common queries
CREATE INDEX idx_audit_events_actor ON audit_events(actor_id, timestamp DESC);
CREATE INDEX idx_audit_events_resource ON audit_events(resource_type, resource_id, timestamp DESC);
CREATE INDEX idx_audit_events_event_type ON audit_events(event_type, timestamp DESC);
CREATE INDEX idx_audit_events_trace_id ON audit_events(trace_id) WHERE trace_id IS NOT NULL;

-- Retention policies (for GDPR compliance)
CREATE TABLE retention_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(100) NOT NULL UNIQUE,
    retention_days INTEGER NOT NULL, -- How long to keep
    anonymize_after_days INTEGER, -- When to anonymize PII
    deletion_strategy VARCHAR(50) NOT NULL DEFAULT 'hard_delete',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT retention_policies_deletion_check CHECK (
        deletion_strategy IN ('hard_delete', 'anonymize', 'archive')
    )
);

-- Compliance reports
CREATE TABLE compliance_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_type VARCHAR(100) NOT NULL, -- 'gdpr', 'soc2', 'iso27001', 'nis2'
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    filters JSONB,
    status VARCHAR(50) NOT NULL DEFAULT 'generating',
    file_path TEXT,
    generated_at TIMESTAMPTZ,
    generated_by UUID,

    CONSTRAINT compliance_reports_type_check CHECK (
        report_type IN ('gdpr', 'soc2', 'iso27001', 'nis2', 'custom')
    ),
    CONSTRAINT compliance_reports_status_check CHECK (
        status IN ('generating', 'completed', 'failed')
    )
);

CREATE INDEX idx_compliance_reports_type ON compliance_reports(report_type);
CREATE INDEX idx_compliance_reports_generated_at ON compliance_reports(generated_at DESC);
```

**Data Ownership**:
- All audit events (immutable)
- Retention policies
- Compliance reports

### File Storage Service Database

**Schema**:

```sql
-- Files table (Aggregate Root)
CREATE TABLE files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(500) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    size_bytes BIGINT NOT NULL,
    owner_id UUID NOT NULL,
    storage_key TEXT NOT NULL UNIQUE, -- S3 path
    status VARCHAR(50) NOT NULL DEFAULT 'uploading',
    current_version_id UUID, -- Points to latest version
    metadata JSONB NOT NULL DEFAULT '{}', -- tags, description, custom fields
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_accessed_at TIMESTAMPTZ,

    CONSTRAINT files_status_check CHECK (
        status IN ('uploading', 'scanning', 'available', 'quarantined', 'deleted')
    ),
    CONSTRAINT files_size_check CHECK (size_bytes >= 0)
);

CREATE INDEX idx_files_owner_id ON files(owner_id);
CREATE INDEX idx_files_status ON files(status);
CREATE INDEX idx_files_uploaded_at ON files(uploaded_at DESC);
CREATE INDEX idx_files_storage_key ON files(storage_key);

-- File versions (Entity)
CREATE TABLE file_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_id UUID NOT NULL REFERENCES files(id) ON DELETE CASCADE,
    version_number INTEGER NOT NULL,
    storage_key TEXT NOT NULL UNIQUE,
    size_bytes BIGINT NOT NULL,
    checksum VARCHAR(64) NOT NULL, -- SHA-256
    uploaded_by UUID NOT NULL,
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(file_id, version_number),
    CONSTRAINT file_versions_size_check CHECK (size_bytes >= 0)
);

CREATE INDEX idx_file_versions_file_id ON file_versions(file_id);

-- File permissions (Entity)
CREATE TABLE file_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_id UUID NOT NULL REFERENCES files(id) ON DELETE CASCADE,
    principal_type VARCHAR(50) NOT NULL, -- 'user', 'role', 'public'
    principal_id UUID, -- User ID or Role ID (NULL for public)
    permission_level VARCHAR(50) NOT NULL, -- 'read', 'write', 'delete'
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL,

    CONSTRAINT file_permissions_principal_type_check CHECK (
        principal_type IN ('user', 'role', 'public')
    ),
    CONSTRAINT file_permissions_level_check CHECK (
        permission_level IN ('read', 'write', 'delete', 'admin')
    )
);

CREATE INDEX idx_file_permissions_file_id ON files_permissions(file_id);
CREATE INDEX idx_file_permissions_principal ON file_permissions(principal_type, principal_id);

-- Scan results (for virus scanning)
CREATE TABLE scan_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_id UUID NOT NULL REFERENCES files(id) ON DELETE CASCADE,
    version_id UUID NOT NULL REFERENCES file_versions(id) ON DELETE CASCADE,
    scanner VARCHAR(100) NOT NULL DEFAULT 'ClamAV',
    status VARCHAR(50) NOT NULL,
    threats JSONB, -- Array of detected threats
    scanned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT scan_results_status_check CHECK (
        status IN ('clean', 'infected', 'error', 'skipped')
    )
);

CREATE INDEX idx_scan_results_file_id ON scan_results(file_id);
CREATE INDEX idx_scan_results_status ON scan_results(status);
```

**Data Ownership**:
- File metadata
- Version history
- Permissions
- Scan results

## Data Consistency Patterns

### Strong Consistency (Within Service)

**Use Case**: Operations within a single service boundary

**Implementation**: ACID transactions

```php
// Example: Creating a workflow with steps (single service)
$this->entityManager->beginTransaction();
try {
    $workflow = new Workflow($id, $name);

    foreach ($steps as $stepData) {
        $step = Step::fromArray($stepData);
        $workflow->addStep($step);
    }

    $this->entityManager->persist($workflow);
    $this->entityManager->flush();
    $this->entityManager->commit();
} catch (\Exception $e) {
    $this->entityManager->rollback();
    throw $e;
}
```

### Eventual Consistency (Across Services)

**Use Case**: Operations spanning multiple services

**Implementation**: Domain events + message broker

```php
// Service A: Workflow completed
$workflow->complete();
$this->workflowRepository->save($workflow);

// Publish event
$event = new WorkflowCompletedEvent($workflow->getId());
$this->eventPublisher->publish($event);

// Service B: Notification service listens
class WorkflowCompletedHandler
{
    public function __invoke(WorkflowCompletedEvent $event): void
    {
        // Eventually consistent: Notification sent after workflow completion
        $this->notificationService->sendWorkflowCompletedNotification($event->getWorkflowId());
    }
}
```

### Saga Pattern (Distributed Transactions)

**Use Case**: Multi-step process across services requiring compensation

**Implementation**:

```php
// Orchestrator coordinates saga
class WorkflowExecutionSaga
{
    public function execute(WorkflowInstance $instance): void
    {
        $compensations = [];

        try {
            // Step 1: Execute agent
            $agentResult = $this->llmAgentService->execute($agentId, $input);
            $compensations[] = fn() => $this->llmAgentService->cancelExecution($agentResult->getId());

            // Step 2: Validate result
            $validationResult = $this->validationService->validate($agentResult);

            if (!$validationResult->passed()) {
                throw new ValidationFailedException();
            }

            // Step 3: Send notification
            $this->notificationService->send($notification);

            // All steps succeeded
            $instance->complete();
        } catch (\Exception $e) {
            // Execute compensations in reverse order
            foreach (array_reverse($compensations) as $compensate) {
                try {
                    $compensate();
                } catch (\Exception $compensationError) {
                    // Log and continue
                    $this->logger->error('Compensation failed', ['error' => $compensationError]);
                }
            }

            $instance->fail($e->getMessage());
            throw $e;
        }
    }
}
```

## Data Duplication Strategy

### When to Duplicate Data

✅ **DO Duplicate**:
- Reference data needed for queries (IDs, names, timestamps)
- Data needed for service autonomy
- Read-optimized views (CQRS read models)
- Cached data for performance

❌ **DON'T Duplicate**:
- Rapidly changing data
- Large binary data
- Sensitive data (unless encrypted)

**Example**:

```sql
-- Workflow service stores minimal agent info for display
CREATE TABLE workflow_agent_cache (
    agent_id UUID PRIMARY KEY,
    agent_name VARCHAR(255) NOT NULL,
    last_synced_at TIMESTAMPTZ NOT NULL,

    -- Refreshed periodically from LLM Agent Service via events
);

-- Update cache when AgentUpdated event received
```

## Migration Strategy

### Schema Migrations

**Tool**: Doctrine Migrations

**Process**:

```bash
# 1. Generate migration from entity changes
bin/console doctrine:migrations:diff

# 2. Review generated migration
# migrations/Version20250107100000.php

# 3. Test in development
bin/console doctrine:migrations:migrate --no-interaction

# 4. Deploy to production (via CI/CD)
```

**Migration Example**:

```php
// migrations/Version20250107100000.php
final class Version20250107100000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Add status column to workflows table';
    }

    public function up(Schema $schema): void
    {
        // Safe: Adding nullable column
        $this->addSql('ALTER TABLE workflows ADD COLUMN status VARCHAR(50)');

        // Backfill with default value
        $this->addSql("UPDATE workflows SET status = 'active' WHERE status IS NULL");

        // Make NOT NULL after backfill
        $this->addSql('ALTER TABLE workflows ALTER COLUMN status SET NOT NULL');

        // Add check constraint
        $this->addSql("ALTER TABLE workflows ADD CONSTRAINT workflows_status_check CHECK (status IN ('draft', 'active', 'deprecated'))");
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE workflows DROP CONSTRAINT workflows_status_check');
        $this->addSql('ALTER TABLE workflows DROP COLUMN status');
    }
}
```

### Zero-Downtime Migrations

**Expand-Contract Pattern**:

**Phase 1: Expand** (Add new schema without breaking old code)
```sql
-- Add new column (nullable)
ALTER TABLE users ADD COLUMN email_verified BOOLEAN;
```

**Phase 2: Dual Write** (Write to both old and new)
```php
$user->setEmail($email);
$user->setEmailVerified(true); // New field
```

**Phase 3: Migrate** (Backfill data)
```sql
UPDATE users SET email_verified = true WHERE email IS NOT NULL;
```

**Phase 4: Contract** (Remove old schema)
```sql
-- After all code deployed and data migrated
ALTER TABLE users ALTER COLUMN email_verified SET NOT NULL;
```

## Backup and Recovery

### Backup Strategy

**Frequency**:
- **Full Backup**: Daily at 2 AM UTC
- **Incremental Backup**: Every 6 hours
- **WAL Archiving**: Continuous (for point-in-time recovery)

**Retention**:
- Daily backups: 30 days
- Weekly backups: 90 days
- Monthly backups: 1 year

**Implementation**:

```bash
# PostgreSQL backup with pg_dump
pg_dump -Fc -h $DB_HOST -U $DB_USER $DB_NAME > backup_$(date +%Y%m%d_%H%M%S).dump

# WAL archiving for PITR
archive_command = 'cp %p /var/lib/postgresql/wal_archive/%f'
```

### Recovery Procedures

**Point-in-Time Recovery (PITR)**:

```bash
# 1. Restore base backup
pg_restore -d $DB_NAME backup_20250107_020000.dump

# 2. Create recovery.conf
cat > recovery.conf <<EOF
restore_command = 'cp /var/lib/postgresql/wal_archive/%f %p'
recovery_target_time = '2025-01-07 14:30:00'
EOF

# 3. Start PostgreSQL (applies WAL up to target time)
pg_ctl start
```

**RTO/RPO Targets**:
- **RTO** (Recovery Time Objective): < 4 hours
- **RPO** (Recovery Point Objective): < 15 minutes (with WAL archiving)

## Performance Optimization

### Indexing Strategy

**Rules**:
1. Index foreign keys
2. Index columns used in WHERE clauses
3. Index columns used in ORDER BY
4. Composite indexes for multi-column queries
5. Partial indexes for filtered queries

**Example**:

```sql
-- Composite index for common query
CREATE INDEX idx_executions_agent_status_date
ON executions(agent_id, status, executed_at DESC);

-- Partial index for active items only
CREATE INDEX idx_workflows_active
ON workflows(created_at DESC)
WHERE status = 'active';

-- GIN index for JSONB queries
CREATE INDEX idx_workflows_definition_gin
ON workflows USING GIN (definition);
```

### Query Optimization

**Use EXPLAIN ANALYZE**:

```sql
EXPLAIN ANALYZE
SELECT w.*, COUNT(wi.id) as instance_count
FROM workflows w
LEFT JOIN workflow_instances wi ON wi.workflow_id = w.id
WHERE w.status = 'active'
GROUP BY w.id
ORDER BY w.created_at DESC
LIMIT 20;
```

**Optimize N+1 Queries**:

```php
// ❌ Bad: N+1 queries
$workflows = $this->workflowRepository->findAll();
foreach ($workflows as $workflow) {
    $instances = $workflow->getInstances(); // Separate query per workflow
}

// ✅ Good: Eager loading
$workflows = $this->workflowRepository->findAllWithInstances();
foreach ($workflows as $workflow) {
    $instances = $workflow->getInstances(); // Already loaded
}
```

### Connection Pooling

**PgBouncer Configuration**:

```ini
[databases]
llm_agent_db = host=postgres-llm port=5432 dbname=llm_agent_db
workflow_db = host=postgres-workflow port=5432 dbname=workflow_db

[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
min_pool_size = 5
reserve_pool_size = 5
reserve_pool_timeout = 3
```

## Monitoring

### Key Metrics

**Database Health**:
- Connection count
- Query latency (P50, P95, P99)
- Slow queries (> 1s)
- Lock waits
- Deadlocks
- Cache hit ratio (> 90%)
- Index usage

**Prometheus Metrics**:

```yaml
# PostgreSQL Exporter metrics
- pg_stat_database_tup_returned
- pg_stat_database_tup_fetched
- pg_stat_database_conflicts
- pg_stat_database_deadlocks
- pg_stat_user_tables_n_tup_ins
- pg_stat_user_tables_n_tup_upd
- pg_stat_user_tables_n_tup_del
```

### Alerts

```yaml
# Prometheus alerting rules
groups:
  - name: postgresql
    rules:
      - alert: PostgreSQLDown
        expr: pg_up == 0
        for: 1m
        severity: critical

      - alert: PostgreSQLSlowQueries
        expr: rate(pg_stat_statements_mean_time_seconds[5m]) > 1
        for: 5m
        severity: warning

      - alert: PostgreSQLHighConnections
        expr: pg_stat_database_numbackends / pg_settings_max_connections > 0.8
        for: 5m
        severity: warning

      - alert: PostgreSQLCacheHitRatioLow
        expr: pg_stat_database_blks_hit / (pg_stat_database_blks_hit + pg_stat_database_blks_read) < 0.9
        for: 10m
        severity: warning
```

## Security

### Row-Level Security (RLS)

**Enable for Multi-Tenant Tables**:

```sql
-- Enable RLS
ALTER TABLE workflows ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own workflows
CREATE POLICY workflow_isolation ON workflows
    FOR ALL
    USING (owner_id = current_setting('app.current_user_id')::uuid);

-- Set user context in application
SET LOCAL app.current_user_id = 'user-uuid-here';
```

### Encryption

**At Rest**: PostgreSQL Transparent Data Encryption (TDE)
**In Transit**: TLS 1.3 required
**Column-Level**: Use pgcrypto for sensitive columns

```sql
-- Encrypt sensitive column
CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE users ADD COLUMN ssn_encrypted BYTEA;

-- Encrypt on insert
INSERT INTO users (ssn_encrypted)
VALUES (pgp_sym_encrypt('123-45-6789', 'encryption_key'));

-- Decrypt on select
SELECT pgp_sym_decrypt(ssn_encrypted, 'encryption_key') as ssn FROM users;
```

### Access Control

**Database Users**:
- `app_read`: SELECT only
- `app_write`: SELECT, INSERT, UPDATE, DELETE
- `app_admin`: DDL operations (migrations only)
- `app_backup`: Backup operations

```sql
-- Create read-only user
CREATE ROLE app_read WITH LOGIN PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE llm_agent_db TO app_read;
GRANT USAGE ON SCHEMA public TO app_read;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_read;

-- Application uses app_write
CREATE ROLE app_write WITH LOGIN PASSWORD 'secure_password';
GRANT app_read TO app_write;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_write;
```

## Conclusion

This data architecture ensures:

✅ **Service Autonomy**: Database per service pattern
✅ **Data Consistency**: Strong within service, eventual across services
✅ **Performance**: Optimized schemas, indexing, connection pooling
✅ **Reliability**: Backups, PITR, replication
✅ **Security**: Encryption, RLS, least privilege access
✅ **Compliance**: Audit trails, retention policies
✅ **Scalability**: Read replicas, partitioning, caching

Each service owns its data completely, communicating through well-defined APIs and events, enabling independent evolution and scaling.
