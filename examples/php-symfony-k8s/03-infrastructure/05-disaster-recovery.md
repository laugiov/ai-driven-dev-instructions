# Disaster Recovery

**Document Version**: 1.0
**Last Updated**: 2025-01-07
**Status**: Complete

## Table of Contents

1. [Overview](#overview)
2. [Recovery Objectives](#recovery-objectives)
3. [Backup Strategy](#backup-strategy)
4. [Recovery Procedures](#recovery-procedures)
5. [Testing and Validation](#testing-and-validation)

## Overview

This document defines the disaster recovery strategy for the AI Workflow Processing Platform, ensuring business continuity in case of failures.

## Recovery Objectives

| Metric | Target | Justification |
|--------|--------|---------------|
| **RTO** (Recovery Time Objective) | < 1 hour | Maximum acceptable downtime |
| **RPO** (Recovery Point Objective) | < 15 minutes | Maximum acceptable data loss |
| **Availability Target** | 99.9% | 43 minutes downtime/month |

## Backup Strategy

### Database Backups

**PostgreSQL**:
- **Continuous WAL archiving** to S3 (RPO: 1 minute)
- **Full backup** every 6 hours
- **Point-in-time recovery** (PITR) available
- **Retention**: 7 days PITR + 90 days weekly backups

```bash
#!/bin/bash
# PostgreSQL backup script
DATABASE="llm_agent_db"
BACKUP_DIR="/backups"
S3_BUCKET="s3://platform-backups"

# Full backup
pg_dump -h postgres-primary -U postgres -Fc -d ${DATABASE} \
  | gzip > "${BACKUP_DIR}/${DATABASE}-$(date +%Y%m%d-%H%M%S).dump.gz"

# Upload to S3 with encryption
aws s3 cp "${BACKUP_DIR}/${DATABASE}-$(date +%Y%m%d-%H%M%S).dump.gz" \
  ${S3_BUCKET}/${DATABASE}/ \
  --server-side-encryption aws:kms \
  --ssekms-key-id arn:aws:kms:...

# WAL archiving (continuous)
archive_command = 'aws s3 cp %p ${S3_BUCKET}/wal/%f'
```

### Application State Backups

**Kubernetes Resources**:
- **Git repository** stores all Infrastructure as Code
- **etcd snapshots** every hour (managed by cloud provider)
- **Velero** for cluster backup

```bash
# Install Velero
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket platform-velero-backups \
  --backup-location-config region=us-east-1 \
  --snapshot-location-config region=us-east-1 \
  --secret-file ./credentials-velero

# Create backup schedule
velero schedule create daily-backup \
  --schedule="0 2 * * *" \
  --include-namespaces application,data,infrastructure \
  --ttl 720h
```

### Secrets and Configuration

**HashiCorp Vault**:
- **Automated snapshots** every 4 hours
- **Encrypted backups** stored in S3
- **Retention**: 30 days

```bash
# Vault snapshot
vault operator raft snapshot save backup.snap

# Encrypt and upload
openssl enc -aes-256-cbc -salt -pbkdf2 \
  -in backup.snap \
  -out backup.snap.enc \
  -pass pass:"${ENCRYPTION_KEY}"

aws s3 cp backup.snap.enc s3://platform-backups/vault/
```

## Recovery Procedures

### Scenario 1: Single AZ Failure

**Impact**: Minimal - automatic failover
**Recovery Time**: < 5 minutes (automatic)

**Procedure**:
1. Kubernetes automatically reschedules pods to healthy AZs
2. Load balancer removes failed AZ from rotation
3. Monitor for full recovery

**Validation**:
```bash
# Check pod distribution
kubectl get pods -n application -o wide | grep -c "us-east-1a"
kubectl get pods -n application -o wide | grep -c "us-east-1b"
kubectl get pods -n application -o wide | grep -c "us-east-1c"
```

### Scenario 2: Region Failure

**Impact**: Major - requires DR region activation
**Recovery Time**: < 1 hour (manual)

**Procedure**:

1. **Activate DR Region** (pre-deployed standby):
```bash
# Update DNS to point to DR region
aws route53 change-resource-record-sets \
  --hosted-zone-id Z123456 \
  --change-batch file://dr-failover.json
```

2. **Restore Latest Data**:
```bash
# Restore PostgreSQL from latest backup
pg_restore -h dr-postgres -U postgres -d llm_agent_db \
  /backups/llm_agent_db-latest.dump
```

3. **Verify Services**:
```bash
# Check all services healthy
kubectl get pods -n application
curl https://dr-api.platform.local/health
```

4. **Notify Stakeholders**: Send incident notification

**Rollback**: Switch DNS back to primary region

### Scenario 3: Data Corruption

**Impact**: Moderate - restore from backup
**Recovery Time**: 15-30 minutes

**Procedure**:

1. **Stop Writes** to affected database:
```bash
# Revoke write permissions temporarily
psql -h postgres -U postgres -c \
  "REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM llm_agent_service;"
```

2. **Restore from PITR**:
```bash
# Restore to 15 minutes ago
pg_restore -h postgres-restore -U postgres \
  --time="$(date -d '15 minutes ago' --iso-8601=seconds)" \
  /backups/llm_agent_db-latest.dump
```

3. **Verify Data Integrity**:
```bash
# Run data validation queries
psql -h postgres-restore -U postgres -d llm_agent_db -f verify.sql
```

4. **Switch Application** to restored database:
```bash
# Update connection string
kubectl set env deployment/llm-agent-service \
  -n application \
  DATABASE_URL="postgresql://postgres-restore:5432/llm_agent_db"
```

5. **Re-enable Writes**

### Scenario 4: Complete Cluster Loss

**Impact**: Critical - full rebuild required
**Recovery Time**: 2-4 hours

**Procedure**:

1. **Provision New Cluster**:
```bash
# Run Terraform
cd terraform/environments/production
terraform init
terraform apply -auto-approve
```

2. **Deploy Infrastructure Services**:
```bash
# ArgoCD will automatically deploy from Git
kubectl apply -f argocd/bootstrap.yaml

# Wait for all apps to sync
argocd app wait --all --health
```

3. **Restore Data**:
```bash
# Restore all databases from latest backups
./scripts/restore-all-databases.sh
```

4. **Validate System**:
```bash
# Run smoke tests
./scripts/smoke-tests.sh production
```

5. **Update DNS** to point to new cluster

**Time Estimate**: 2-4 hours depending on data size

## Testing and Validation

### DR Drill Schedule

- **Monthly**: Test database restore
- **Quarterly**: Full DR failover drill
- **Annually**: Complete cluster rebuild test

### Test Checklist

**Database Restore Test**:
- [ ] Backup exists and is accessible
- [ ] Restore completes without errors
- [ ] Data integrity verified
- [ ] Application connects successfully
- [ ] Performance acceptable
- [ ] Time to restore < 15 minutes

**DR Failover Test**:
- [ ] DR region is operational
- [ ] DNS failover works
- [ ] All services start successfully
- [ ] Data replication is current
- [ ] Application fully functional
- [ ] RTO achieved (< 1 hour)

**Backup Validation**:
```bash
# Automated backup verification
#!/bin/bash
set -e

# Download latest backup
LATEST_BACKUP=$(aws s3 ls s3://platform-backups/llm_agent_db/ | tail -1 | awk '{print $4}')
aws s3 cp s3://platform-backups/llm_agent_db/${LATEST_BACKUP} /tmp/

# Test restore to temp database
createdb -h test-postgres -U postgres test_restore
pg_restore -h test-postgres -U postgres -d test_restore /tmp/${LATEST_BACKUP}

# Verify record counts
EXPECTED_COUNT=$(psql -h production-postgres -U postgres -d llm_agent_db -t -c "SELECT COUNT(*) FROM agents;")
ACTUAL_COUNT=$(psql -h test-postgres -U postgres -d test_restore -t -c "SELECT COUNT(*) FROM agents;")

if [ "$EXPECTED_COUNT" -eq "$ACTUAL_COUNT" ]; then
  echo "✅ Backup verification successful"
else
  echo "❌ Backup verification failed: Expected $EXPECTED_COUNT, got $ACTUAL_COUNT"
  exit 1
fi

# Cleanup
dropdb -h test-postgres -U postgres test_restore
rm /tmp/${LATEST_BACKUP}
```

### Monitoring

**Backup Monitoring Alerts**:

```yaml
# Alert if backup failed
- alert: BackupFailed
  expr: |
    time() - backup_last_success_timestamp_seconds > 21600
  for: 1h
  labels:
    severity: critical
  annotations:
    summary: "Database backup has not succeeded in 6 hours"

# Alert if backup size anomaly
- alert: BackupSizeAnomaly
  expr: |
    abs(backup_size_bytes - avg_over_time(backup_size_bytes[7d])) >
    0.3 * avg_over_time(backup_size_bytes[7d])
  for: 1h
  labels:
    severity: warning
  annotations:
    summary: "Backup size is significantly different from average"
```

## Documentation and Runbooks

All recovery procedures documented in:
- `docs/runbooks/disaster-recovery/`
- Emergency contact list
- Access credentials (in Vault)
- External service contacts (AWS, etc.)

## Business Continuity

### Communication Plan

**During incident**:
1. Incident Commander declares disaster
2. Status page updated (status.platform.local)
3. Email notification to all users
4. Regular updates every 30 minutes

**Post-incident**:
1. Post-mortem within 48 hours
2. Root cause analysis
3. Action items to prevent recurrence

## Cost Considerations

**DR Infrastructure Costs**:
- **Hot standby (DR region)**: $2,000/month (minimal cluster)
- **Backups (S3)**: $300/month (all backups)
- **Cross-region data transfer**: $500/month (replication)

**Total DR cost**: ~$2,800/month (~30% of production costs)

**Cost optimization**:
- Use smaller instances in DR region
- Reduce DR replica count
- Use S3 Intelligent-Tiering for backups

## References

- [AWS Disaster Recovery Whitepaper](https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/disaster-recovery-workloads-on-aws.html)
- [Kubernetes Disaster Recovery](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#backing-up-an-etcd-cluster)
- [PostgreSQL PITR](https://www.postgresql.org/docs/current/continuous-archiving.html)

## Related Documentation

- [01-infrastructure-overview.md](01-infrastructure-overview.md) - Infrastructure overview
- [02-kubernetes-architecture.md](02-kubernetes-architecture.md) - Kubernetes architecture
- [../07-operations/04-backup-restore.md](../07-operations/04-backup-restore.md) - Operational backup procedures

---

**Document Maintainers**: SRE Team, Platform Team
**Review Cycle**: Quarterly and after each DR drill
**Next Review**: 2025-04-07
