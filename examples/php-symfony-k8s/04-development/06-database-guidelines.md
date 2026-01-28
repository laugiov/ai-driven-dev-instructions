# Database Guidelines

**Document Version**: 1.0
**Last Updated**: 2025-01-07
**Status**: Complete

## Table of Contents

1. [Overview](#overview)
2. [Database Schema Design](#database-schema-design)
3. [Naming Conventions](#naming-conventions)
4. [Data Types](#data-types)
5. [Indexes](#indexes)
6. [Constraints](#constraints)
7. [Migrations](#migrations)
8. [Query Optimization](#query-optimization)
9. [Transactions](#transactions)
10. [Connection Management](#connection-management)
11. [Security](#security)
12. [Backup and Recovery](#backup-and-recovery)

## Overview

PostgreSQL is the primary database for all services. This document provides guidelines for database schema design, queries, and operations.

### Database Version

- **Production**: PostgreSQL 15+
- **Extensions**: pgcrypto, uuid-ossp, pg_stat_statements
- **Connection Pooling**: PgBouncer

## Database Schema Design

### Database per Service

Each microservice has its own database for data autonomy:

```
llm_agent_db           # LLM Agent Service
workflow_db            # Workflow Orchestrator Service
validation_db          # Validation Service
notification_db        # Notification Service
audit_log_db           # Audit Logging Service (TimescaleDB)
file_storage_db        # File Storage Service
```

### Table Structure Example

```sql
-- Good table structure
CREATE TABLE agents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    tenant_id UUID NOT NULL,

    name VARCHAR(255) NOT NULL,
    model VARCHAR(100) NOT NULL,
    system_prompt TEXT NOT NULL,
    configuration JSONB NOT NULL DEFAULT '{}',

    status VARCHAR(50) NOT NULL DEFAULT 'active',

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT agents_name_min_length CHECK (LENGTH(name) >= 3),
    CONSTRAINT agents_status_valid CHECK (status IN ('active', 'inactive', 'archived'))
);

-- Indexes
CREATE INDEX idx_agents_user_id ON agents(user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_agents_tenant_id ON agents(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_agents_status ON agents(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_agents_created_at ON agents(created_at DESC);

-- Comments for documentation
COMMENT ON TABLE agents IS 'LLM agents configured by users';
COMMENT ON COLUMN agents.configuration IS 'JSON configuration (temperature, max_tokens, etc.)';
```

### Normalization

**3rd Normal Form (3NF)** for most tables:

```sql
-- ❌ Bad: Denormalized (data duplication)
CREATE TABLE workflow_executions (
    id UUID PRIMARY KEY,
    workflow_id UUID NOT NULL,
    workflow_name VARCHAR(255),      -- Duplicated
    workflow_description TEXT,       -- Duplicated
    user_email VARCHAR(255),         -- Duplicated
    executed_at TIMESTAMPTZ
);

-- ✅ Good: Normalized
CREATE TABLE workflow_executions (
    id UUID PRIMARY KEY,
    workflow_id UUID NOT NULL REFERENCES workflows(id),
    executed_at TIMESTAMPTZ NOT NULL,

    FOREIGN KEY (workflow_id) REFERENCES workflows(id) ON DELETE CASCADE
);

-- Workflow data comes from workflows table
SELECT we.*, w.name, w.description, u.email
FROM workflow_executions we
JOIN workflows w ON w.id = we.workflow_id
JOIN users u ON u.id = w.user_id;
```

**Strategic Denormalization** for performance (when justified):

```sql
-- Denormalized for read performance (avoid join)
CREATE TABLE workflow_executions (
    id UUID PRIMARY KEY,
    workflow_id UUID NOT NULL,
    workflow_name VARCHAR(255) NOT NULL,  -- Denormalized for performance
    user_id UUID NOT NULL,
    executed_at TIMESTAMPTZ NOT NULL
);

-- Keep in sync with trigger
CREATE OR REPLACE FUNCTION sync_workflow_name()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE workflow_executions
    SET workflow_name = NEW.name
    WHERE workflow_id = NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_sync_workflow_name
AFTER UPDATE OF name ON workflows
FOR EACH ROW
EXECUTE FUNCTION sync_workflow_name();
```

## Naming Conventions

### Table Names

```sql
-- ✅ Good: Plural nouns, snake_case
agents
workflows
workflow_steps
user_preferences

-- ❌ Bad
Agent              -- Not plural
WorkflowSteps      -- PascalCase
workflow-steps     -- Kebab-case
tbl_workflows      -- Hungarian notation
```

### Column Names

```sql
-- ✅ Good: Descriptive, snake_case
id
user_id
created_at
first_name
is_active
total_amount

-- ❌ Bad
userId             -- camelCase
FirstName          -- PascalCase
createddate        -- Missing separator
flg_active         -- Hungarian notation
```

### Indexes

```sql
-- Pattern: idx_{table}_{columns}
CREATE INDEX idx_agents_user_id ON agents(user_id);
CREATE INDEX idx_agents_status_created ON agents(status, created_at DESC);
CREATE UNIQUE INDEX idx_agents_name_user_unique ON agents(name, user_id) WHERE deleted_at IS NULL;
```

### Constraints

```sql
-- Pattern: {table}_{column}_{type}
CONSTRAINT agents_name_min_length CHECK (LENGTH(name) >= 3)
CONSTRAINT agents_status_valid CHECK (status IN ('active', 'inactive'))
CONSTRAINT agents_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id)
```

## Data Types

### Recommended Types

| Data Type | Use Case | Example |
|-----------|----------|---------|
| **UUID** | Primary keys, foreign keys | `id UUID DEFAULT gen_random_uuid()` |
| **VARCHAR(n)** | Short text with known max length | `name VARCHAR(255)` |
| **TEXT** | Long text, no length limit | `description TEXT` |
| **INTEGER** | Whole numbers | `count INTEGER` |
| **BIGINT** | Large whole numbers | `total_bytes BIGINT` |
| **NUMERIC(p,s)** | Exact decimal | `price NUMERIC(10,2)` |
| **BOOLEAN** | True/false | `is_active BOOLEAN` |
| **TIMESTAMPTZ** | Timestamps (always use TZ!) | `created_at TIMESTAMPTZ` |
| **JSONB** | Semi-structured data | `configuration JSONB` |
| **ARRAY** | Lists | `tags TEXT[]` |

### Type Examples

```sql
-- ✅ Good type choices
CREATE TABLE products (
    id UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price NUMERIC(10,2) NOT NULL,        -- Exact decimal for money
    stock INTEGER NOT NULL DEFAULT 0,
    tags TEXT[] DEFAULT '{}',
    metadata JSONB DEFAULT '{}',
    is_available BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ❌ Bad type choices
CREATE TABLE products (
    id INTEGER,                          -- Use UUID instead
    name TEXT,                           -- Use VARCHAR(255) for bounded text
    description VARCHAR(100),            -- Use TEXT for long text
    price FLOAT,                         -- Never use FLOAT for money!
    created_at TIMESTAMP                 -- Always use TIMESTAMPTZ (with timezone)
);
```

### JSONB Usage

```sql
-- Store semi-structured configuration
CREATE TABLE agents (
    id UUID PRIMARY KEY,
    name VARCHAR(255),
    configuration JSONB NOT NULL DEFAULT '{}'
);

-- Insert with JSONB
INSERT INTO agents (name, configuration)
VALUES ('Agent 1', '{"temperature": 0.7, "max_tokens": 500}');

-- Query JSONB
SELECT * FROM agents
WHERE configuration->>'temperature' = '0.7';

SELECT * FROM agents
WHERE (configuration->>'max_tokens')::int > 400;

-- Update JSONB field
UPDATE agents
SET configuration = configuration || '{"top_p": 0.9}'
WHERE id = 'xxx';

-- Index JSONB
CREATE INDEX idx_agents_config_temperature
ON agents((configuration->>'temperature'));
```

## Indexes

### When to Create Indexes

```sql
-- ✅ Always index:
-- - Primary keys (automatic)
-- - Foreign keys
CREATE INDEX idx_workflow_steps_workflow_id ON workflow_steps(workflow_id);

-- - Columns used in WHERE clauses
CREATE INDEX idx_agents_status ON agents(status);

-- - Columns used in ORDER BY
CREATE INDEX idx_agents_created_at ON agents(created_at DESC);

-- - Columns used in JOIN conditions
CREATE INDEX idx_executions_workflow_id ON executions(workflow_id);

-- ❌ Don't index:
-- - Small tables (< 1000 rows)
-- - Columns with low cardinality (few distinct values)
-- - Columns rarely queried
```

### Composite Indexes

```sql
-- Order matters! Most selective column first
CREATE INDEX idx_agents_user_status ON agents(user_id, status);

-- This index can be used for:
-- ✅ WHERE user_id = 'xxx'
-- ✅ WHERE user_id = 'xxx' AND status = 'active'
-- ❌ WHERE status = 'active' (doesn't use index efficiently)

-- Create separate index if needed
CREATE INDEX idx_agents_status ON agents(status);
```

### Partial Indexes

```sql
-- Index only active records (more efficient)
CREATE INDEX idx_agents_active ON agents(user_id)
WHERE status = 'active' AND deleted_at IS NULL;

-- Query that uses this index
SELECT * FROM agents
WHERE user_id = 'xxx'
  AND status = 'active'
  AND deleted_at IS NULL;
```

### Index Maintenance

```sql
-- Check index usage
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC;

-- Find unused indexes
SELECT
    schemaname,
    tablename,
    indexname
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexrelname NOT LIKE 'pg_toast%';

-- Reindex if needed
REINDEX INDEX CONCURRENTLY idx_agents_user_id;
```

## Constraints

### Primary Keys

```sql
-- ✅ Always use UUID for distributed systems
CREATE TABLE workflows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid()
);

-- ❌ Don't use serial/auto-increment in distributed systems
CREATE TABLE workflows (
    id SERIAL PRIMARY KEY  -- Bad for distributed databases
);
```

### Foreign Keys

```sql
-- ✅ Always define foreign keys
CREATE TABLE workflow_steps (
    id UUID PRIMARY KEY,
    workflow_id UUID NOT NULL,

    CONSTRAINT workflow_steps_workflow_fkey
    FOREIGN KEY (workflow_id)
    REFERENCES workflows(id)
    ON DELETE CASCADE
);

-- CASCADE options:
-- ON DELETE CASCADE  - Delete child when parent deleted
-- ON DELETE SET NULL - Set FK to NULL when parent deleted
-- ON DELETE RESTRICT - Prevent parent deletion if children exist (default)
```

### Check Constraints

```sql
-- Validate data at database level
CREATE TABLE agents (
    id UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    temperature NUMERIC(3,2),

    CONSTRAINT agents_name_not_empty
    CHECK (LENGTH(TRIM(name)) > 0),

    CONSTRAINT agents_temperature_range
    CHECK (temperature >= 0 AND temperature <= 2),

    CONSTRAINT agents_name_min_length
    CHECK (LENGTH(name) >= 3)
);
```

### Unique Constraints

```sql
-- Single column unique
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE
);

-- Composite unique constraint
CREATE TABLE agents (
    id UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    user_id UUID NOT NULL,
    deleted_at TIMESTAMPTZ,

    -- Unique name per user (excluding soft-deleted)
    CONSTRAINT agents_name_user_unique
    UNIQUE (name, user_id)
    WHERE deleted_at IS NULL
);
```

## Migrations

### Migration File Structure

```php
<?php
// migrations/Version20250107000001.php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20250107000001 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Create agents table';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('
            CREATE TABLE agents (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NOT NULL,
                name VARCHAR(255) NOT NULL,
                model VARCHAR(100) NOT NULL,
                system_prompt TEXT NOT NULL,
                configuration JSONB NOT NULL DEFAULT \'{}\',
                status VARCHAR(50) NOT NULL DEFAULT \'active\',
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMPTZ,

                CONSTRAINT agents_name_min_length CHECK (LENGTH(name) >= 3)
            )
        ');

        $this->addSql('CREATE INDEX idx_agents_user_id ON agents(user_id)');
        $this->addSql('CREATE INDEX idx_agents_status ON agents(status)');

        $this->addSql('COMMENT ON TABLE agents IS \'LLM agents\'');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('DROP TABLE agents');
    }
}
```

### Migration Best Practices

```sql
-- ✅ Always make migrations reversible
public function down(Schema $schema): void {
    // Implement reverse of up()
}

-- ✅ Use transactions (automatic with Doctrine)
-- ✅ Create indexes CONCURRENTLY in production
CREATE INDEX CONCURRENTLY idx_agents_user_id ON agents(user_id);

-- ✅ Add NOT NULL in steps:
-- Step 1: Add column as nullable
ALTER TABLE agents ADD COLUMN email VARCHAR(255);

-- Step 2: Populate data
UPDATE agents SET email = user_email FROM users WHERE users.id = agents.user_id;

-- Step 3: Add NOT NULL constraint
ALTER TABLE agents ALTER COLUMN email SET NOT NULL;
```

## Query Optimization

### Use EXPLAIN ANALYZE

```sql
-- Analyze query performance
EXPLAIN ANALYZE
SELECT a.*, u.email
FROM agents a
JOIN users u ON u.id = a.user_id
WHERE a.status = 'active'
ORDER BY a.created_at DESC
LIMIT 20;

-- Look for:
-- - Seq Scan (bad on large tables)
-- - Index Scan (good)
-- - Execution time
-- - Rows returned vs rows scanned
```

### Avoid N+1 Queries

```php
<?php

// ❌ Bad: N+1 query problem
$workflows = $entityManager->getRepository(Workflow::class)->findAll();
foreach ($workflows as $workflow) {
    echo $workflow->getUser()->getEmail();  // N queries!
}

// ✅ Good: Eager loading with JOIN
$workflows = $entityManager->createQueryBuilder()
    ->select('w', 'u')
    ->from(Workflow::class, 'w')
    ->join('w.user', 'u')
    ->getQuery()
    ->getResult();

foreach ($workflows as $workflow) {
    echo $workflow->getUser()->getEmail();  // 0 queries!
}
```

### Use Appropriate JOINs

```sql
-- INNER JOIN - Only matching rows
SELECT a.*, u.email
FROM agents a
INNER JOIN users u ON u.id = a.user_id;

-- LEFT JOIN - All left rows + matching right
SELECT a.*, u.email
FROM agents a
LEFT JOIN users u ON u.id = a.user_id;

-- WHERE vs ON in LEFT JOIN
-- ❌ Wrong: Filters after join (defeats LEFT JOIN)
SELECT a.*, u.email
FROM agents a
LEFT JOIN users u ON u.id = a.user_id
WHERE u.status = 'active';  -- Turns into INNER JOIN!

-- ✅ Correct: Filter in ON clause
SELECT a.*, u.email
FROM agents a
LEFT JOIN users u ON u.id = a.user_id AND u.status = 'active';
```

### Use CTEs for Readability

```sql
-- Complex query with CTE
WITH active_users AS (
    SELECT id, email
    FROM users
    WHERE status = 'active'
),
recent_workflows AS (
    SELECT workflow_id, COUNT(*) as execution_count
    FROM workflow_executions
    WHERE executed_at > NOW() - INTERVAL '30 days'
    GROUP BY workflow_id
)
SELECT
    u.email,
    w.name,
    rw.execution_count
FROM active_users u
JOIN workflows w ON w.user_id = u.id
LEFT JOIN recent_workflows rw ON rw.workflow_id = w.id
ORDER BY rw.execution_count DESC NULLS LAST;
```

## Transactions

### ACID Properties

```php
<?php

// ✅ Use transactions for multiple related operations
$entityManager->beginTransaction();

try {
    // Create workflow
    $workflow = new Workflow('Test Workflow');
    $entityManager->persist($workflow);

    // Create steps
    foreach ($steps as $stepData) {
        $step = new WorkflowStep($workflow, $stepData);
        $entityManager->persist($step);
    }

    // Commit all changes
    $entityManager->flush();
    $entityManager->commit();

} catch (\Exception $e) {
    // Rollback on error
    $entityManager->rollback();
    throw $e;
}
```

### Isolation Levels

```sql
-- Default: READ COMMITTED (good for most cases)

-- Use SERIALIZABLE for critical operations
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- Critical operations here
COMMIT;
```

### Locking

```sql
-- Pessimistic locking (lock rows)
SELECT * FROM accounts WHERE id = 'xxx' FOR UPDATE;
UPDATE accounts SET balance = balance - 100 WHERE id = 'xxx';

-- Optimistic locking (version column)
CREATE TABLE workflows (
    id UUID PRIMARY KEY,
    name VARCHAR(255),
    version INTEGER NOT NULL DEFAULT 1
);

-- Update with version check
UPDATE workflows
SET name = 'New Name', version = version + 1
WHERE id = 'xxx' AND version = 5;  -- Fails if version changed
```

## Connection Management

### Connection Pooling with PgBouncer

```ini
# pgbouncer.ini
[databases]
llm_agent_db = host=postgres port=5432 dbname=llm_agent_db

[pgbouncer]
pool_mode = transaction
max_client_conn = 10000
default_pool_size = 25
reserve_pool_size = 10
```

### Doctrine Connection Configuration

```yaml
# config/packages/doctrine.yaml
doctrine:
    dbal:
        url: '%env(resolve:DATABASE_URL)%'

        # Connection pooling
        options:
            1002: 'SET search_path TO public'  # PDO::ATTR_INIT_COMMAND

        # Logging
        logging: '%kernel.debug%'
        profiling: '%kernel.debug%'
```

## Security

### SQL Injection Prevention

```php
<?php

// ❌ NEVER concatenate user input
$sql = "SELECT * FROM users WHERE email = '" . $_POST['email'] . "'";

// ✅ Always use parameterized queries
$stmt = $pdo->prepare('SELECT * FROM users WHERE email = :email');
$stmt->execute(['email' => $email]);

// ✅ Doctrine Query Builder (safe)
$users = $entityManager->createQueryBuilder()
    ->select('u')
    ->from(User::class, 'u')
    ->where('u.email = :email')
    ->setParameter('email', $email)
    ->getQuery()
    ->getResult();
```

### Encryption at Rest

```sql
-- Use pgcrypto for sensitive data
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Encrypt column
INSERT INTO users (email, ssn)
VALUES ('user@example.com', pgp_sym_encrypt('123-45-6789', 'encryption_key'));

-- Decrypt column
SELECT email, pgp_sym_decrypt(ssn, 'encryption_key') as ssn
FROM users;
```

### Row-Level Security

```sql
-- Enable RLS
ALTER TABLE workflows ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own workflows
CREATE POLICY workflow_isolation ON workflows
    FOR ALL
    TO authenticated_user
    USING (user_id = current_setting('app.current_user_id')::UUID);

-- Set current user in application
SET LOCAL app.current_user_id = 'user-uuid';
```

## Backup and Recovery

See [../03-infrastructure/05-disaster-recovery.md](../03-infrastructure/05-disaster-recovery.md) for complete backup strategy.

### Quick Backup Commands

```bash
# Backup single database
pg_dump -h localhost -U postgres -Fc llm_agent_db > backup.dump

# Restore
pg_restore -h localhost -U postgres -d llm_agent_db backup.dump

# Backup all databases
pg_dumpall -h localhost -U postgres > all_databases.sql
```

## Performance Monitoring

```sql
-- Enable pg_stat_statements
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Find slow queries
SELECT
    calls,
    total_exec_time,
    mean_exec_time,
    query
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Find missing indexes
SELECT
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation
FROM pg_stats
WHERE schemaname = 'public'
  AND n_distinct > 100
  AND correlation < 0.1;
```

## Best Practices Summary

1. ✅ Use UUID for primary keys
2. ✅ Always use TIMESTAMPTZ (not TIMESTAMP)
3. ✅ Index foreign keys and WHERE/ORDER BY columns
4. ✅ Use JSONB for semi-structured data
5. ✅ Write reversible migrations
6. ✅ Use transactions for related operations
7. ✅ Always use parameterized queries
8. ✅ Add constraints at database level
9. ✅ Use connection pooling (PgBouncer)
10. ✅ Monitor query performance
11. ✅ Regular VACUUM and ANALYZE
12. ✅ Implement backups and test recovery

## References

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [PostgreSQL Performance](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Doctrine ORM](https://www.doctrine-project.org/projects/doctrine-orm/en/latest/)

## Related Documentation

- [../01-architecture/05-data-architecture.md](../01-architecture/05-data-architecture.md) - Database architecture
- [../03-infrastructure/05-disaster-recovery.md](../03-infrastructure/05-disaster-recovery.md) - Backup strategy
- [03-symfony-best-practices.md](03-symfony-best-practices.md) - Doctrine ORM usage

---

**Document Maintainers**: Engineering Team, Database Team
**Review Cycle**: Quarterly
**Next Review**: 2025-04-07
