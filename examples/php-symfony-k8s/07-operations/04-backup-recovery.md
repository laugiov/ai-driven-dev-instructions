# Backup and Recovery

## Table of Contents

1. [Overview](#overview)
2. [Backup Strategy](#backup-strategy)
3. [Database Backups](#database-backups)
4. [Application Data Backups](#application-data-backups)
5. [Infrastructure Backups](#infrastructure-backups)
6. [Recovery Procedures](#recovery-procedures)
7. [Disaster Recovery](#disaster-recovery)
8. [Testing and Validation](#testing-and-validation)
9. [Compliance and Retention](#compliance-and-retention)

## Overview

### Purpose

Comprehensive backup and recovery procedures ensure:
- Protection against data loss
- Business continuity
- Compliance with regulations
- Fast recovery from failures
- Point-in-time recovery capability

### Recovery Objectives

```yaml
recovery_objectives:
  rto:  # Recovery Time Objective
    tier_1_critical:
      target: 1 hour
      services:
        - API Gateway
        - Authentication Service
        - Workflow Engine

    tier_2_important:
      target: 4 hours
      services:
        - Agent Manager
        - Notification Service
        - Analytics Service

    tier_3_standard:
      target: 24 hours
      services:
        - Reporting Service
        - Admin Dashboard

  rpo:  # Recovery Point Objective
    tier_1_critical:
      target: 5 minutes
      data_loss: Maximum 5 minutes of transactions

    tier_2_important:
      target: 15 minutes
      data_loss: Maximum 15 minutes of data

    tier_3_standard:
      target: 1 hour
      data_loss: Maximum 1 hour of data
```

### Backup Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Production Environment                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ PostgreSQL  │  │   Redis     │  │   S3        │         │
│  │  Cluster    │  │   Cache     │  │  Storage    │         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │
└─────────┼─────────────────┼─────────────────┼────────────────┘
          │                 │                 │
          │ WAL/PITR        │ RDB/AOF         │ Versioning
          │ Streaming       │ Snapshots       │ Replication
          ▼                 ▼                 ▼
┌──────────────────────────────────────────────────────────────┐
│                    Primary Backup Region                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   S3        │  │   S3        │  │   S3        │         │
│  │  DB Backups │  │ Redis Dumps │  │ Replication │         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │
└─────────┼─────────────────┼─────────────────┼────────────────┘
          │                 │                 │
          │ Cross-region    │ replication     │
          │ replication     │                 │
          ▼                 ▼                 ▼
┌──────────────────────────────────────────────────────────────┐
│                   Secondary Backup Region                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   S3        │  │   S3        │  │   S3        │         │
│  │  DB Backups │  │ Redis Dumps │  │ Replication │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└──────────────────────────────────────────────────────────────┘
          │                 │                 │
          │ Glacier         │ archival        │
          │ archival        │                 │
          ▼                 ▼                 ▼
┌──────────────────────────────────────────────────────────────┐
│                    Long-term Archive                          │
│                     (AWS Glacier)                             │
└──────────────────────────────────────────────────────────────┘
```

## Backup Strategy

### Backup Types

```yaml
backup_types:
  full_backup:
    description: "Complete snapshot of all data"
    frequency: Daily at 02:00 UTC
    retention: 30 days
    storage: S3 Standard
    use_case: Complete restoration

  incremental_backup:
    description: "Changes since last backup"
    frequency: Every 6 hours
    retention: 7 days
    storage: S3 Standard
    use_case: Point-in-time recovery

  continuous_backup:
    description: "Real-time transaction log"
    frequency: Continuous (WAL streaming)
    retention: 7 days
    storage: S3 Standard
    use_case: Minimal data loss recovery

  snapshot:
    description: "Instant point-in-time copy"
    frequency: Before major changes
    retention: 7 days
    storage: EBS Snapshot
    use_case: Quick rollback
```

### Backup Schedule

```yaml
backup_schedule:
  database:
    full_backup:
      time: "02:00 UTC daily"
      duration: "~45 minutes"
      size: "~500 GB"

    incremental_backup:
      times:
        - "08:00 UTC"
        - "14:00 UTC"
        - "20:00 UTC"
      duration: "~10 minutes each"
      size: "~50 GB each"

    wal_archiving:
      frequency: "Continuous"
      segment_size: "16 MB"
      retention: "7 days"

  redis:
    rdb_snapshot:
      time: "03:00 UTC daily"
      duration: "~5 minutes"
      size: "~10 GB"

    aof_rewrite:
      time: "04:00 UTC daily"
      duration: "~10 minutes"
      size: "~20 GB"

  application_data:
    s3_replication:
      frequency: "Continuous"
      destination: "us-west-2 (DR region)"

    file_snapshots:
      time: "05:00 UTC daily"
      retention: "30 days"

  configuration:
    git_backup:
      frequency: "On every commit"
      retention: "Indefinite"

    terraform_state:
      frequency: "On every apply"
      retention: "90 days"
```

## Database Backups

### PostgreSQL Backup Configuration

```yaml
# postgresql.conf - WAL archiving configuration
wal_level = replica
archive_mode = on
archive_command = 'aws s3 cp %p s3://platform-db-backups/wal/%f --region us-east-1'
archive_timeout = 300  # Force segment switch every 5 minutes

# Replication settings
max_wal_senders = 10
wal_keep_size = 1GB

# Checkpoint settings for consistent backups
checkpoint_timeout = 15min
checkpoint_completion_target = 0.9
```

### Automated Backup Script

```bash
#!/bin/bash
# scripts/backup-database.sh

set -euo pipefail

# Configuration
BACKUP_TYPE="${1:-full}"  # full or incremental
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
S3_BUCKET="s3://platform-db-backups"
DATABASE="platform_production"
BACKUP_DIR="/var/backups/postgresql"
RETENTION_DAYS=30

log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

# Send metrics to Prometheus Pushgateway
send_metric() {
    local metric_name=$1
    local metric_value=$2
    local job_name="database_backup"

    echo "${metric_name} ${metric_value}" | \
        curl --data-binary @- \
        http://pushgateway.monitoring:9091/metrics/job/${job_name}
}

# Verify prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check pg_basebackup is available
    if ! command -v pg_basebackup &> /dev/null; then
        log_error "pg_basebackup not found"
        exit 1
    fi

    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found"
        exit 1
    fi

    # Check disk space (need at least 600GB)
    local available=$(df -BG $BACKUP_DIR | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available" -lt 600 ]; then
        log_error "Insufficient disk space: ${available}GB available, need 600GB"
        exit 1
    fi

    # Check database connectivity
    if ! psql -h $DB_HOST -U $DB_USER -d postgres -c "SELECT 1" > /dev/null 2>&1; then
        log_error "Cannot connect to database"
        exit 1
    fi

    log_info "Prerequisites OK"
}

# Create full backup using pg_basebackup
full_backup() {
    local backup_name="full_${TIMESTAMP}"
    local backup_path="${BACKUP_DIR}/${backup_name}"

    log_info "Starting full backup: $backup_name"

    local start_time=$(date +%s)

    # Create base backup
    pg_basebackup \
        -h $DB_HOST \
        -U $DB_USER \
        -D "${backup_path}" \
        -Ft \
        -z \
        -P \
        -X stream \
        --checkpoint=fast \
        --label="${backup_name}"

    if [ $? -ne 0 ]; then
        log_error "Full backup failed"
        send_metric "database_backup_failed_total" 1
        exit 1
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local backup_size=$(du -sb "${backup_path}" | awk '{print $1}')

    log_info "Full backup completed in ${duration} seconds"
    log_info "Backup size: $(numfmt --to=iec-i --suffix=B $backup_size)"

    # Upload to S3
    log_info "Uploading to S3..."

    aws s3 sync "${backup_path}" \
        "${S3_BUCKET}/full/${backup_name}/" \
        --storage-class STANDARD \
        --region us-east-1

    if [ $? -ne 0 ]; then
        log_error "S3 upload failed"
        send_metric "database_backup_upload_failed_total" 1
        exit 1
    fi

    # Create backup metadata
    cat > "${backup_path}/metadata.json" <<EOF
{
    "backup_type": "full",
    "timestamp": "${TIMESTAMP}",
    "database": "${DATABASE}",
    "size_bytes": ${backup_size},
    "duration_seconds": ${duration},
    "s3_path": "${S3_BUCKET}/full/${backup_name}/",
    "recovery_target_time": "$(date -u +%Y-%m-%d\ %H:%M:%S\ UTC)"
}
EOF

    aws s3 cp "${backup_path}/metadata.json" \
        "${S3_BUCKET}/full/${backup_name}/metadata.json"

    # Send metrics
    send_metric "database_backup_duration_seconds" $duration
    send_metric "database_backup_size_bytes" $backup_size
    send_metric "database_backup_success_total" 1

    log_info "Full backup completed successfully"

    # Cleanup old local backups
    cleanup_local_backups

    # Verify backup
    verify_backup "${S3_BUCKET}/full/${backup_name}/"
}

# Create incremental backup
incremental_backup() {
    local backup_name="incremental_${TIMESTAMP}"
    local backup_path="${BACKUP_DIR}/${backup_name}"

    log_info "Starting incremental backup: $backup_name"

    # Find last full backup
    local last_full=$(aws s3 ls ${S3_BUCKET}/full/ | tail -1 | awk '{print $2}' | tr -d '/')

    if [ -z "$last_full" ]; then
        log_error "No full backup found, cannot create incremental"
        exit 1
    fi

    log_info "Last full backup: $last_full"

    local start_time=$(date +%s)

    # Create directory
    mkdir -p "${backup_path}"

    # Archive WAL files since last backup
    pg_receivewal \
        -h $DB_HOST \
        -U $DB_USER \
        -D "${backup_path}" \
        --synchronous \
        --compress=9 \
        --endpos=$(pg_current_wal_lsn)

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local backup_size=$(du -sb "${backup_path}" | awk '{print $1}')

    log_info "Incremental backup completed in ${duration} seconds"
    log_info "Backup size: $(numfmt --to=iec-i --suffix=B $backup_size)"

    # Upload to S3
    aws s3 sync "${backup_path}" \
        "${S3_BUCKET}/incremental/${backup_name}/" \
        --storage-class STANDARD

    # Create metadata
    cat > "${backup_path}/metadata.json" <<EOF
{
    "backup_type": "incremental",
    "timestamp": "${TIMESTAMP}",
    "database": "${DATABASE}",
    "base_backup": "${last_full}",
    "size_bytes": ${backup_size},
    "duration_seconds": ${duration},
    "s3_path": "${S3_BUCKET}/incremental/${backup_name}/"
}
EOF

    aws s3 cp "${backup_path}/metadata.json" \
        "${S3_BUCKET}/incremental/${backup_name}/metadata.json"

    send_metric "database_backup_duration_seconds" $duration
    send_metric "database_backup_size_bytes" $backup_size
    send_metric "database_backup_success_total" 1

    log_info "Incremental backup completed successfully"

    cleanup_local_backups
}

# Cleanup old local backups
cleanup_local_backups() {
    log_info "Cleaning up local backups older than 2 days..."

    find "${BACKUP_DIR}" -type d -mtime +2 -exec rm -rf {} + 2>/dev/null || true

    local freed_space=$(df -BG $BACKUP_DIR | awk 'NR==2 {print $4}')
    log_info "Freed space, ${freed_space} available"
}

# Verify backup integrity
verify_backup() {
    local s3_path=$1

    log_info "Verifying backup at ${s3_path}..."

    # Check if metadata exists
    if ! aws s3 ls "${s3_path}metadata.json" > /dev/null 2>&1; then
        log_error "Backup verification failed: metadata missing"
        send_metric "database_backup_verification_failed_total" 1
        return 1
    fi

    # Verify file count
    local file_count=$(aws s3 ls --recursive "${s3_path}" | wc -l)
    if [ "$file_count" -lt 3 ]; then
        log_error "Backup verification failed: insufficient files"
        send_metric "database_backup_verification_failed_total" 1
        return 1
    fi

    log_info "Backup verification passed"
    send_metric "database_backup_verification_success_total" 1
    return 0
}

# Cleanup old backups in S3
cleanup_s3_backups() {
    log_info "Cleaning up S3 backups older than ${RETENTION_DAYS} days..."

    # List and delete old full backups
    aws s3 ls ${S3_BUCKET}/full/ | while read -r line; do
        createDate=$(echo $line | awk '{print $1" "$2}')
        createDate=$(date -d "$createDate" +%s)
        olderThan=$(date -d "-${RETENTION_DAYS} days" +%s)

        if [[ $createDate -lt $olderThan ]]; then
            backup_dir=$(echo $line | awk '{print $4}')
            log_info "Deleting old backup: $backup_dir"
            aws s3 rm --recursive ${S3_BUCKET}/full/$backup_dir/
        fi
    done

    # Archive to Glacier
    aws s3 ls ${S3_BUCKET}/full/ | while read -r line; do
        createDate=$(echo $line | awk '{print $1" "$2}')
        createDate=$(date -d "$createDate" +%s)
        archiveDate=$(date -d "-90 days" +%s)

        if [[ $createDate -lt $archiveDate ]]; then
            backup_dir=$(echo $line | awk '{print $4}')
            log_info "Archiving to Glacier: $backup_dir"

            # Copy to Glacier
            aws s3 sync ${S3_BUCKET}/full/$backup_dir/ \
                s3://platform-db-backups-archive/$backup_dir/ \
                --storage-class GLACIER

            # Delete from standard storage
            aws s3 rm --recursive ${S3_BUCKET}/full/$backup_dir/
        fi
    done

    log_info "S3 cleanup completed"
}

# Main execution
main() {
    log_info "Database backup starting (type: $BACKUP_TYPE)"

    check_prerequisites

    case "$BACKUP_TYPE" in
        full)
            full_backup
            ;;
        incremental)
            incremental_backup
            ;;
        cleanup)
            cleanup_s3_backups
            ;;
        *)
            log_error "Invalid backup type: $BACKUP_TYPE"
            echo "Usage: $0 {full|incremental|cleanup}"
            exit 1
            ;;
    esac

    log_info "Database backup completed"
}

# Run
main "$@"
```

### Point-in-Time Recovery (PITR)

```yaml
# postgresql recovery configuration
pitr_configuration:
  recovery_conf:
    # Restore command to fetch WAL from S3
    restore_command: |
      aws s3 cp s3://platform-db-backups/wal/%f %p --region us-east-1

    # Recovery target (choose one)
    recovery_target_time: "2025-01-07 14:30:00 UTC"
    # recovery_target_xid: "123456"  # Transaction ID
    # recovery_target_name: "before_bad_deployment"  # Named restore point

    # Recovery behavior
    recovery_target_action: promote  # promote, pause, or shutdown
    recovery_target_inclusive: true  # include target transaction

  steps:
    - Stop PostgreSQL cluster
    - Remove data directory
    - Restore base backup
    - Create recovery.conf
    - Start PostgreSQL in recovery mode
    - Wait for recovery completion
    - Verify data integrity
```

### Database Restore Script

```bash
#!/bin/bash
# scripts/restore-database.sh

set -euo pipefail

BACKUP_NAME="${1}"
RECOVERY_TARGET_TIME="${2:-latest}"
DATA_DIR="/var/lib/postgresql/14/main"
S3_BUCKET="s3://platform-db-backups"

log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1"
}

# Stop PostgreSQL
stop_database() {
    log_info "Stopping PostgreSQL..."
    systemctl stop postgresql
    sleep 5
}

# Backup current data directory
backup_current_data() {
    if [ -d "$DATA_DIR" ]; then
        log_info "Backing up current data directory..."
        mv "$DATA_DIR" "${DATA_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
}

# Restore base backup
restore_base_backup() {
    local backup_path="${S3_BUCKET}/full/${BACKUP_NAME}/"

    log_info "Restoring base backup from ${backup_path}..."

    # Create data directory
    mkdir -p "$DATA_DIR"
    chown postgres:postgres "$DATA_DIR"
    chmod 700 "$DATA_DIR"

    # Download and extract backup
    aws s3 sync "${backup_path}" /tmp/restore/

    # Extract tarball
    cd "$DATA_DIR"
    tar -xzf /tmp/restore/base.tar.gz
    tar -xzf /tmp/restore/pg_wal.tar.gz -C pg_wal/

    chown -R postgres:postgres "$DATA_DIR"

    log_info "Base backup restored"
}

# Configure recovery
configure_recovery() {
    log_info "Configuring recovery..."

    # Create recovery.signal file (PostgreSQL 12+)
    touch "${DATA_DIR}/recovery.signal"

    # Create postgresql.auto.conf with recovery settings
    cat > "${DATA_DIR}/postgresql.auto.conf" <<EOF
# Recovery configuration
restore_command = 'aws s3 cp s3://platform-db-backups/wal/%f %p'
recovery_target_time = '${RECOVERY_TARGET_TIME}'
recovery_target_action = 'promote'
recovery_target_inclusive = true
EOF

    chown postgres:postgres "${DATA_DIR}/postgresql.auto.conf"

    log_info "Recovery configured"
}

# Start recovery
start_recovery() {
    log_info "Starting PostgreSQL recovery..."

    systemctl start postgresql

    # Monitor recovery
    while true; do
        if pg_isready -q; then
            recovery_status=$(psql -U postgres -t -c "SELECT pg_is_in_recovery();")

            if [[ "$recovery_status" == *"f"* ]]; then
                log_info "Recovery completed, database promoted"
                break
            else
                log_info "Recovery in progress..."
                sleep 10
            fi
        else
            sleep 5
        fi
    done
}

# Verify restoration
verify_restoration() {
    log_info "Verifying restoration..."

    # Check database connectivity
    if ! psql -U postgres -c "SELECT 1" > /dev/null 2>&1; then
        log_error "Database not accessible after restore"
        exit 1
    fi

    # Check table counts
    local table_count=$(psql -U postgres -d platform_production -t -c "
        SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = 'public'
    ")

    log_info "Tables found: $table_count"

    if [ "$table_count" -lt 10 ]; then
        log_error "Insufficient tables, restore may be incomplete"
        exit 1
    fi

    # Run integrity checks
    psql -U postgres -d platform_production -c "
        SELECT table_name,
               pg_size_pretty(pg_total_relation_size(quote_ident(table_name))) as size
        FROM information_schema.tables
        WHERE table_schema = 'public'
        ORDER BY pg_total_relation_size(quote_ident(table_name)) DESC
        LIMIT 10;
    "

    log_info "Verification completed"
}

# Main
main() {
    log_info "Starting database restore"
    log_info "Backup: $BACKUP_NAME"
    log_info "Recovery target: $RECOVERY_TARGET_TIME"

    read -p "This will replace the current database. Continue? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_info "Restore cancelled"
        exit 0
    fi

    stop_database
    backup_current_data
    restore_base_backup
    configure_recovery
    start_recovery
    verify_restoration

    log_info "Database restore completed successfully"
}

main "$@"
```

## Application Data Backups

### S3 Bucket Versioning

```yaml
# S3 bucket configuration
s3_backup_configuration:
  versioning:
    enabled: true
    mfa_delete: false

  lifecycle_rules:
    - id: "transition-to-ia"
      status: Enabled
      transitions:
        - days: 30
          storage_class: STANDARD_IA

    - id: "transition-to-glacier"
      status: Enabled
      transitions:
        - days: 90
          storage_class: GLACIER

    - id: "expire-old-versions"
      status: Enabled
      noncurrent_version_expiration:
        days: 180

  replication:
    role: "arn:aws:iam::ACCOUNT:role/s3-replication"
    destination:
      bucket: "arn:aws:s3:::platform-backups-dr"
      region: "us-west-2"
      storage_class: "STANDARD_IA"

  encryption:
    algorithm: "AES256"
    kms_key: "arn:aws:kms:us-east-1:ACCOUNT:key/KEY-ID"
```

### Redis Backup Configuration

```yaml
# redis.conf
save 900 1      # Save after 900 seconds if at least 1 key changed
save 300 10     # Save after 300 seconds if at least 10 keys changed
save 60 10000   # Save after 60 seconds if at least 10000 keys changed

# RDB settings
dbfilename "dump.rdb"
dir "/var/lib/redis"
rdbcompression yes
rdbchecksum yes

# AOF settings
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
```

### Redis Backup Script

```bash
#!/bin/bash
# scripts/backup-redis.sh

set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/redis"
S3_BUCKET="s3://platform-redis-backups"
REDIS_HOST="redis-primary.cache.svc.cluster.local"
REDIS_PORT=6379

log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1"
}

# Trigger Redis BGSAVE
trigger_backup() {
    log_info "Triggering Redis BGSAVE..."

    redis-cli -h $REDIS_HOST -p $REDIS_PORT BGSAVE

    # Wait for BGSAVE to complete
    while true; do
        status=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT LASTSAVE)
        sleep 5
        new_status=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT LASTSAVE)

        if [ "$status" != "$new_status" ]; then
            log_info "BGSAVE completed"
            break
        fi
    done
}

# Copy RDB file
copy_rdb() {
    local rdb_file="/var/lib/redis/dump.rdb"
    local backup_file="${BACKUP_DIR}/redis_${TIMESTAMP}.rdb"

    log_info "Copying RDB file..."

    cp "$rdb_file" "$backup_file"

    # Compress
    gzip "$backup_file"

    local backup_size=$(du -h "${backup_file}.gz" | awk '{print $1}')
    log_info "Backup size: $backup_size"

    # Upload to S3
    aws s3 cp "${backup_file}.gz" \
        "${S3_BUCKET}/${TIMESTAMP}/dump.rdb.gz" \
        --storage-class STANDARD

    log_info "Uploaded to S3"
}

# Backup AOF
backup_aof() {
    local aof_file="/var/lib/redis/appendonly.aof"
    local backup_file="${BACKUP_DIR}/redis_${TIMESTAMP}.aof"

    if [ -f "$aof_file" ]; then
        log_info "Backing up AOF..."

        cp "$aof_file" "$backup_file"
        gzip "$backup_file"

        aws s3 cp "${backup_file}.gz" \
            "${S3_BUCKET}/${TIMESTAMP}/appendonly.aof.gz"

        log_info "AOF backed up"
    fi
}

# Main
main() {
    log_info "Starting Redis backup"

    mkdir -p "$BACKUP_DIR"

    trigger_backup
    copy_rdb
    backup_aof

    # Cleanup old local backups
    find "$BACKUP_DIR" -type f -mtime +7 -delete

    log_info "Redis backup completed"
}

main "$@"
```

## Infrastructure Backups

### Terraform State Backup

```yaml
# terraform backend configuration
terraform:
  backend:
    s3:
      bucket: "platform-terraform-state"
      key: "production/terraform.tfstate"
      region: "us-east-1"
      encrypt: true
      dynamodb_table: "terraform-state-lock"

      # Versioning enabled on bucket
      versioning: true

      # Lifecycle policy
      lifecycle_rules:
        - noncurrent_version_expiration: 90 days
        - transitions:
            - days: 30
              storage_class: STANDARD_IA
```

### Configuration Backup

```bash
#!/bin/bash
# scripts/backup-configuration.sh

set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/config"
S3_BUCKET="s3://platform-config-backups"

log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1"
}

# Backup Kubernetes resources
backup_kubernetes() {
    log_info "Backing up Kubernetes resources..."

    local k8s_backup="${BACKUP_DIR}/k8s_${TIMESTAMP}"
    mkdir -p "$k8s_backup"

    # Export all resources
    for namespace in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
        log_info "Exporting namespace: $namespace"
        kubectl get all -n $namespace -o yaml > "${k8s_backup}/${namespace}_all.yaml"
        kubectl get configmaps -n $namespace -o yaml > "${k8s_backup}/${namespace}_configmaps.yaml"
        kubectl get secrets -n $namespace -o yaml > "${k8s_backup}/${namespace}_secrets.yaml"
    done

    # Compress and upload
    tar -czf "${k8s_backup}.tar.gz" -C "$BACKUP_DIR" "k8s_${TIMESTAMP}"
    aws s3 cp "${k8s_backup}.tar.gz" "${S3_BUCKET}/kubernetes/"

    rm -rf "$k8s_backup" "${k8s_backup}.tar.gz"

    log_info "Kubernetes backup completed"
}

# Backup Helm releases
backup_helm() {
    log_info "Backing up Helm releases..."

    local helm_backup="${BACKUP_DIR}/helm_${TIMESTAMP}"
    mkdir -p "$helm_backup"

    # Export all Helm releases
    for release in $(helm list -A -q); do
        namespace=$(helm list -A | grep $release | awk '{print $2}')
        log_info "Exporting release: $release (namespace: $namespace)"

        helm get values $release -n $namespace > "${helm_backup}/${release}_values.yaml"
        helm get manifest $release -n $namespace > "${helm_backup}/${release}_manifest.yaml"
    done

    tar -czf "${helm_backup}.tar.gz" -C "$BACKUP_DIR" "helm_${TIMESTAMP}"
    aws s3 cp "${helm_backup}.tar.gz" "${S3_BUCKET}/helm/"

    rm -rf "$helm_backup" "${helm_backup}.tar.gz"

    log_info "Helm backup completed"
}

# Backup ArgoCD applications
backup_argocd() {
    log_info "Backing up ArgoCD applications..."

    local argocd_backup="${BACKUP_DIR}/argocd_${TIMESTAMP}"
    mkdir -p "$argocd_backup"

    # Export all applications
    argocd app list -o yaml > "${argocd_backup}/applications.yaml"

    # Export projects
    kubectl get appprojects -n argocd -o yaml > "${argocd_backup}/projects.yaml"

    tar -czf "${argocd_backup}.tar.gz" -C "$BACKUP_DIR" "argocd_${TIMESTAMP}"
    aws s3 cp "${argocd_backup}.tar.gz" "${S3_BUCKET}/argocd/"

    rm -rf "$argocd_backup" "${argocd_backup}.tar.gz"

    log_info "ArgoCD backup completed"
}

# Main
main() {
    log_info "Starting infrastructure configuration backup"

    mkdir -p "$BACKUP_DIR"

    backup_kubernetes
    backup_helm
    backup_argocd

    # Cleanup old backups
    find "$BACKUP_DIR" -type f -mtime +7 -delete

    log_info "Infrastructure configuration backup completed"
}

main "$@"
```

## Recovery Procedures

### Database Recovery

```yaml
database_recovery_scenarios:
  scenario_1_recent_data_loss:
    description: "Recover from data loss in last few hours"
    rpo: "5 minutes"
    rto: "30 minutes"

    steps:
      - Identify point-in-time for recovery
      - Stop application traffic to database
      - Download latest full backup
      - Download WAL files since backup
      - Restore base backup
      - Configure recovery target time
      - Start recovery process
      - Wait for recovery completion
      - Verify data integrity
      - Resume application traffic

  scenario_2_database_corruption:
    description: "Recover from database corruption"
    rpo: "Last good backup (max 24 hours)"
    rto: "1-2 hours"

    steps:
      - Identify last known good backup
      - Create snapshot of corrupted database (forensics)
      - Failover to replica if available
      - Restore from last good backup
      - Verify data integrity
      - Identify missing transactions
      - Manual data reconciliation if needed
      - Resume normal operations

  scenario_3_complete_database_loss:
    description: "Recover from complete database cluster failure"
    rpo: "5 minutes (WAL)"
    rto: "2-4 hours"

    steps:
      - Declare disaster recovery
      - Provision new database cluster
      - Restore latest full backup
      - Apply incremental backups
      - Apply WAL files
      - Verify replication setup
      - Run integrity checks
      - Update application connection strings
      - Gradual traffic migration
      - Monitor for issues
```

### Application Recovery

```yaml
application_recovery_procedures:
  container_failure:
    detection: "Health check failures, pod restarts"
    automatic_recovery: true
    steps:
      - Kubernetes restarts pod automatically
      - Load balancer removes unhealthy pod
      - New pod spins up
      - Health checks pass
      - Traffic restored

  deployment_failure:
    detection: "High error rates after deployment"
    automatic_recovery: false
    steps:
      - Identify deployment as cause
      - Execute rollback procedure
      - Monitor error rates
      - Verify functionality
      - Investigate root cause

  data_corruption:
    detection: "Data integrity checks fail"
    automatic_recovery: false
    steps:
      - Stop writes to affected data
      - Identify scope of corruption
      - Restore from backup
      - Replay transactions if possible
      - Verify data integrity
      - Resume operations
```

## Disaster Recovery

### DR Strategy

```yaml
disaster_recovery_strategy:
  dr_tiers:
    tier_1_critical:
      rto: 1 hour
      rpo: 5 minutes
      strategy: "Active-passive with automated failover"
      services:
        - API Gateway
        - Authentication
        - Workflow Engine

    tier_2_important:
      rto: 4 hours
      rpo: 15 minutes
      strategy: "Cold standby with manual failover"
      services:
        - Agent Manager
        - Notification Service

    tier_3_standard:
      rto: 24 hours
      rpo: 1 hour
      strategy: "Backup and restore"
      services:
        - Analytics
        - Reporting

  dr_regions:
    primary:
      region: "us-east-1"
      availability_zones: 3
      status: "Active"

    secondary:
      region: "us-west-2"
      availability_zones: 3
      status: "Passive (warm standby)"

  failover_triggers:
    - Complete region failure > 30 minutes
    - Network partition > 1 hour
    - Data center disaster
    - Security incident requiring isolation
    - Planned DR drill
```

### DR Failover Procedure

```bash
#!/bin/bash
# scripts/dr-failover.sh

set -euo pipefail

DR_REGION="us-west-2"
PRIMARY_REGION="us-east-1"
FAILOVER_TYPE="${1:-manual}"  # manual or automatic

log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1"
}

# Verify DR readiness
verify_dr_readiness() {
    log_info "Verifying DR environment readiness..."

    # Check database replica lag
    local replica_lag=$(psql -h $DR_DB_HOST -U postgres -t -c "
        SELECT EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))
    ")

    if (( $(echo "$replica_lag > 300" | bc -l) )); then
        log_error "Replica lag too high: ${replica_lag}s"
        exit 1
    fi

    # Check infrastructure
    kubectl --context=dr-cluster get nodes
    kubectl --context=dr-cluster get pods -A

    # Verify S3 replication
    local primary_count=$(aws s3 ls s3://platform-data/ --recursive --region $PRIMARY_REGION | wc -l)
    local dr_count=$(aws s3 ls s3://platform-data-dr/ --recursive --region $DR_REGION | wc -l)

    if [ "$dr_count" -lt "$((primary_count * 95 / 100))" ]; then
        log_error "S3 replication incomplete: $dr_count/$primary_count objects"
        exit 1
    fi

    log_info "DR environment ready"
}

# Promote database replica
promote_database() {
    log_info "Promoting database replica to primary..."

    # Stop replication
    psql -h $DR_DB_HOST -U postgres -c "SELECT pg_promote();"

    # Wait for promotion
    local promoted=false
    for i in {1..60}; do
        local in_recovery=$(psql -h $DR_DB_HOST -U postgres -t -c "SELECT pg_is_in_recovery();")

        if [[ "$in_recovery" == *"f"* ]]; then
            promoted=true
            break
        fi

        sleep 5
    done

    if [ "$promoted" = false ]; then
        log_error "Database promotion failed"
        exit 1
    fi

    log_info "Database promoted successfully"
}

# Update DNS
update_dns() {
    log_info "Updating DNS to point to DR region..."

    # Update Route53
    aws route53 change-resource-record-sets \
        --hosted-zone-id $HOSTED_ZONE_ID \
        --change-batch file://dns-failover.json

    log_info "DNS updated, propagation in progress"
}

# Deploy applications to DR
deploy_applications() {
    log_info "Deploying applications to DR region..."

    kubectl --context=dr-cluster apply -k infrastructure/k8s/overlays/dr/

    # Wait for deployments
    kubectl --context=dr-cluster wait --for=condition=available --timeout=600s \
        deployment --all -n platform-production

    log_info "Applications deployed"
}

# Verify DR environment
verify_dr_environment() {
    log_info "Verifying DR environment..."

    # Run smoke tests
    ./scripts/smoke-tests.sh --region=$DR_REGION

    # Check metrics
    local error_rate=$(curl -s "http://prometheus.$DR_REGION/api/v1/query?query=rate(http_requests_total{status=~\"5..\"}[5m])/rate(http_requests_total[5m])" | jq -r '.data.result[0].value[1]')

    if (( $(echo "$error_rate > 0.05" | bc -l) )); then
        log_error "High error rate in DR: $error_rate"
        exit 1
    fi

    log_info "DR environment verified"
}

# Notify stakeholders
notify_failover() {
    log_info "Notifying stakeholders..."

    # Update status page
    curl -X POST "https://api.statuspage.io/v1/pages/$PAGE_ID/incidents" \
        -H "Authorization: OAuth $STATUSPAGE_TOKEN" \
        -d incident[name]="Failover to DR Region" \
        -d incident[status]="investigating" \
        -d incident[body]="We have initiated failover to our disaster recovery region due to issues in the primary region."

    # Send email
    aws ses send-email \
        --from "ops@platform.com" \
        --to "leadership@platform.com" \
        --subject "DR Failover Initiated" \
        --text "DR failover to $DR_REGION has been initiated. Current status: In Progress."

    log_info "Notifications sent"
}

# Main
main() {
    log_info "Starting DR failover to $DR_REGION"

    if [ "$FAILOVER_TYPE" = "manual" ]; then
        read -p "This will initiate DR failover. Continue? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            log_info "Failover cancelled"
            exit 0
        fi
    fi

    verify_dr_readiness
    promote_database
    deploy_applications
    update_dns
    verify_dr_environment
    notify_failover

    log_info "DR failover completed successfully"
    log_info "Primary region: $PRIMARY_REGION (offline)"
    log_info "Active region: $DR_REGION"
}

main "$@"
```

## Testing and Validation

### Backup Testing Schedule

```yaml
backup_testing:
  daily:
    - Automated backup verification
    - Backup size and duration monitoring
    - Upload success verification

  weekly:
    - Test restore to staging environment
    - Random sample verification
    - Backup integrity checks

  monthly:
    - Full restoration drill
    - Performance testing
    - Documentation review

  quarterly:
    - Complete DR drill
    - Failover/failback testing
    - Team training exercise
```

### Backup Validation Script

```bash
#!/bin/bash
# scripts/validate-backup.sh

set -euo pipefail

BACKUP_NAME="${1}"
S3_BUCKET="s3://platform-db-backups"
VALIDATION_DB="backup_validation"

log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1"
}

# Download backup metadata
verify_metadata() {
    log_info "Verifying backup metadata..."

    aws s3 cp "${S3_BUCKET}/full/${BACKUP_NAME}/metadata.json" /tmp/

    local size=$(jq -r '.size_bytes' /tmp/metadata.json)
    local duration=$(jq -r '.duration_seconds' /tmp/metadata.json)

    log_info "Backup size: $(numfmt --to=iec-i --suffix=B $size)"
    log_info "Backup duration: ${duration}s"

    if [ "$size" -lt 1000000000 ]; then  # Less than 1GB seems wrong
        log_error "Backup size suspiciously small"
        return 1
    fi

    return 0
}

# Restore to validation database
test_restore() {
    log_info "Testing restore to validation database..."

    # Create validation database
    psql -U postgres -c "DROP DATABASE IF EXISTS $VALIDATION_DB;"
    psql -U postgres -c "CREATE DATABASE $VALIDATION_DB;"

    # Download and restore backup
    local backup_path="${S3_BUCKET}/full/${BACKUP_NAME}/"
    aws s3 sync "$backup_path" /tmp/validation_restore/

    # Restore
    cd /tmp/validation_restore/
    pg_restore -U postgres -d $VALIDATION_DB base.tar.gz

    log_info "Restore completed"
}

# Verify data integrity
verify_data() {
    log_info "Verifying data integrity..."

    # Check table counts
    local tables=$(psql -U postgres -d $VALIDATION_DB -t -c "
        SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'
    ")

    log_info "Tables: $tables"

    if [ "$tables" -lt 10 ]; then
        log_error "Insufficient tables"
        return 1
    fi

    # Check row counts
    psql -U postgres -d $VALIDATION_DB -c "
        SELECT schemaname, tablename, n_live_tup as row_count
        FROM pg_stat_user_tables
        ORDER BY n_live_tup DESC
        LIMIT 10;
    "

    # Run integrity constraints
    psql -U postgres -d $VALIDATION_DB -c "
        SELECT conrelid::regclass AS table_name,
               conname AS constraint_name
        FROM pg_constraint
        WHERE contype IN ('f', 'p', 'u')
        ORDER BY conrelid::regclass::text;
    "

    log_info "Data integrity verified"
    return 0
}

# Cleanup
cleanup() {
    log_info "Cleaning up..."

    psql -U postgres -c "DROP DATABASE IF EXISTS $VALIDATION_DB;"
    rm -rf /tmp/validation_restore/
    rm -f /tmp/metadata.json

    log_info "Cleanup completed"
}

# Main
main() {
    log_info "Starting backup validation for: $BACKUP_NAME"

    if ! verify_metadata; then
        log_error "Metadata verification failed"
        exit 1
    fi

    if ! test_restore; then
        log_error "Restore test failed"
        cleanup
        exit 1
    fi

    if ! verify_data; then
        log_error "Data verification failed"
        cleanup
        exit 1
    fi

    cleanup

    log_info "Backup validation successful"
}

main "$@"
```

## Compliance and Retention

### Retention Policies

```yaml
retention_policies:
  database_backups:
    full_backups:
      hot_storage: 30 days
      cold_storage: 90 days
      archive: 7 years (compliance)

    incremental_backups:
      hot_storage: 7 days
      cold_storage: 30 days

    wal_archives:
      retention: 7 days

  application_data:
    user_files:
      active: Indefinite
      deleted: 90 days (soft delete)
      archive: 7 years (compliance)

    logs:
      application: 30 days
      audit: 7 years
      security: 7 years

  configuration:
    terraform_state:
      versions: 90 days
      archive: 1 year

    kubernetes_configs:
      versions: 30 days
```

### Compliance Requirements

```yaml
compliance_requirements:
  regulations:
    gdpr:
      - Right to erasure (backup purging)
      - Data portability
      - Encryption at rest and in transit

    sox:
      - 7 year retention for financial data
      - Audit trail for all changes
      - Access controls and logging

    hipaa:
      - Encryption required
      - Access audit logs
      - Disaster recovery plan

  audit_trail:
    backup_operations:
      - Who initiated backup
      - What was backed up
      - When backup occurred
      - Where backup stored
      - Verification status

    restore_operations:
      - Who initiated restore
      - What was restored
      - When restore occurred
      - Approval chain
      - Outcome status

  encryption:
    at_rest:
      - AES-256 encryption
      - KMS key rotation
      - Access logging

    in_transit:
      - TLS 1.3
      - Certificate management
      - Perfect forward secrecy
```

## Conclusion

Comprehensive backup and recovery procedures ensure:

- **Protection against data loss** through multiple backup types
- **Fast recovery** with well-defined RTO/RPO
- **Disaster recovery** capabilities with multi-region support
- **Compliance** with regulatory requirements
- **Regular testing** to validate backup integrity

**Key Practices**:
- Automate all backup operations
- Test restores regularly
- Monitor backup success/failure
- Maintain off-site copies
- Document all procedures
- Train team on recovery

For more information, see:
- [Operations Overview](01-operations-overview.md)
- [Monitoring and Alerting](02-monitoring-alerting.md)
- [Incident Response](03-incident-response.md)
- [Performance Tuning](05-performance-tuning.md)
