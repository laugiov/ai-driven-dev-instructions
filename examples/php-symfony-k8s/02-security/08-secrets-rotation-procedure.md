# Secrets Rotation Procedure

**Document Version**: 1.0
**Last Updated**: 2025-11-09
**Status**: Complete

## Table of Contents

1. [Overview](#overview)
2. [Rotation Schedule](#rotation-schedule)
3. [Secrets Inventory](#secrets-inventory)
4. [Rotation Procedures](#rotation-procedures)
5. [Emergency Rotation](#emergency-rotation)
6. [Automation](#automation)
7. [Verification](#verification)
8. [Rollback](#rollback)

## Overview

This document provides step-by-step procedures for rotating secrets across all ScamBuster microservices. Regular secret rotation is a critical security practice that minimizes the impact of potential credential compromise.

### Why Rotate Secrets?

- **Limit exposure window**: Compromised secrets have limited lifetime
- **Compliance**: Meet SOC2, ISO27001, PCI DSS rotation requirements
- **Defense in depth**: Multiple layers of temporal security
- **Audit trail**: Track who accessed what and when
- **Least privilege**: Ensure secrets are still needed

### Principles

1. **Zero-downtime rotation**: Services continue running during rotation
2. **Backward compatibility**: Support both old and new secrets during transition
3. **Automated verification**: Confirm new secrets work before decommissioning old ones
4. **Audit everything**: Log all rotation activities
5. **Fail-safe**: Ability to quickly rollback if issues occur

## Rotation Schedule

### Regular Schedule

| Secret Type | Rotation Frequency | Auto/Manual | Owner |
|-------------|-------------------|-------------|-------|
| **Database credentials** | 90 days | Automated | DevOps |
| **API keys (external)** | 180 days | Manual | Security |
| **JWT signing secret** | 365 days | Manual | Security |
| **Encryption keys** | 365 days | Automated | Security |
| **Service account tokens** | 30 days | Automated | DevOps |
| **TLS certificates** | 90 days (auto-renew 30d before) | Automated | DevOps |
| **SSH keys** | 180 days | Manual | DevOps |
| **Vault root token** | Never (break glass only) | Manual | CTO |

### Compliance Requirements

- **SOC 2**: Rotate credentials quarterly (90 days)
- **PCI DSS**: Rotate keys annually, secrets quarterly
- **ISO 27001**: Document rotation procedures and maintain audit logs
- **NIS2**: Rotate after personnel changes, incidents, or 90 days max

## Secrets Inventory

### Authentication Service

| Secret | Location | Type | Current Version | Last Rotated |
|--------|----------|------|----------------|--------------|
| JWT_SECRET | Vault: `secret/auth/jwt` | HS256 key | v3 | 2025-11-09 |
| DATABASE_URL | Vault: `database/creds/auth-service` | Dynamic | - | Auto (30d) |
| REDIS_PASSWORD | Vault: `secret/auth/redis` | Static | v2 | 2025-10-01 |
| SENDGRID_API_KEY | Vault: `secret/auth/sendgrid` | External | v1 | 2025-09-01 |
| VAULT_TOKEN | Kubernetes Secret | AppRole | - | Auto (1d) |

### Audit & Logging Service

| Secret | Location | Type | Current Version | Last Rotated |
|--------|----------|------|----------------|--------------|
| DATABASE_URL | Vault: `database/creds/audit-service` | Dynamic | - | Auto (30d) |
| ENCRYPTION_KEY | Vault: `transit/keys/audit-pii` | Transit | v5 | Auto |
| VAULT_TOKEN | Kubernetes Secret | AppRole | - | Auto (1d) |

### Infrastructure

| Secret | Location | Type | Current Version | Last Rotated |
|--------|----------|------|----------------|--------------|
| RabbitMQ credentials | Vault: `rabbitmq/creds/platform` | Dynamic | - | Auto (30d) |
| PostgreSQL root | Vault: `database/config/connection` | Static | v1 | Manual only |
| Vault auto-unseal key | AWS KMS | KMS | - | Never |

## Rotation Procedures

### 1. JWT Secret Rotation (Manual)

**Frequency**: Annually or after security incident

**Prerequisites**:
- [ ] Maintenance window scheduled (or use dual-secret approach)
- [ ] Backup of current secret
- [ ] Communication sent to users about potential re-login

**Procedure**:

```bash
# 1. Generate new secret (64+ characters)
NEW_SECRET=$(openssl rand -base64 48)
echo "New JWT Secret: $NEW_SECRET"

# 2. Add new secret to Vault (keep old one temporarily)
vault kv put secret/auth/jwt \
  current_secret="<old_secret>" \
  new_secret="$NEW_SECRET" \
  rotation_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# 3. Update application to accept BOTH secrets (deploy)
# Edit config to read both current_secret and new_secret
# Verify JWT with current_secret first, fallback to new_secret

# 4. Deploy updated application
kubectl rollout restart deployment/authentication-service -n application

# 5. Wait for rollout completion
kubectl rollout status deployment/authentication-service -n application

# 6. Monitor for errors
kubectl logs -f deployment/authentication-service -n application | grep -i "jwt\|token"

# 7. After 24 hours, promote new secret to primary
vault kv put secret/auth/jwt \
  current_secret="$NEW_SECRET" \
  old_secret="<old_secret>" \
  rotation_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# 8. After another 24 hours, remove old secret
vault kv put secret/auth/jwt \
  current_secret="$NEW_SECRET" \
  rotation_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# 9. Update .env.example with note
echo "# JWT Secret rotated on $(date -u +%Y-%m-%d)" >> services/authentication/.env.example

# 10. Document rotation in audit log
vault audit list
```

**Verification**:
```bash
# Test token generation with new secret
curl -X POST https://api.scambuster.local/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!@#"}'

# Verify old tokens still work (during overlap period)
curl https://api.scambuster.local/api/v1/users/me \
  -H "Authorization: Bearer <old_token>"

# Verify new tokens work
curl https://api.scambuster.local/api/v1/users/me \
  -H "Authorization: Bearer <new_token>"
```

### 2. Database Credentials Rotation (Automated via Vault)

**Frequency**: 90 days (automated)

**Configuration**:

```bash
# Enable database secrets engine
vault secrets enable database

# Configure PostgreSQL connection
vault write database/config/postgresql \
  plugin_name=postgresql-database-plugin \
  allowed_roles="auth-service,audit-service" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/postgres?sslmode=require" \
  username="vault_admin" \
  password="<admin_password>"

# Create role with 90-day TTL
vault write database/roles/auth-service \
  db_name=postgresql \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' IN ROLE auth_role; \
    GRANT auth_role TO \"{{name}}\";" \
  default_ttl="2160h" \
  max_ttl="4320h"

# Rotate root credentials (one-time setup)
vault write -force database/rotate-root/postgresql
```

**How It Works**:
1. Service requests database credentials from Vault
2. Vault generates temporary credentials with 90-day expiry
3. Service uses credentials
4. After 60 days, Vault generates renewal warning
5. After 90 days, credentials expire automatically
6. Service requests new credentials on next startup

**Manual Trigger** (if needed):
```bash
# Revoke specific lease
vault lease revoke database/creds/auth-service/<lease_id>

# Revoke all leases for role
vault lease revoke -prefix database/creds/auth-service
```

### 3. Encryption Key Rotation (Automated via Vault Transit)

**Frequency**: Automatic on-demand (Vault Transit handles this)

**Configuration**:

```bash
# Enable transit secrets engine
vault secrets enable transit

# Create encryption key with auto-rotation
vault write transit/keys/audit-pii \
  auto_rotate_period=2160h \
  deletion_allowed=false \
  exportable=false

# Configure key rotation
vault write transit/keys/audit-pii/rotate
```

**Verification**:
```bash
# Check current key version
vault read transit/keys/audit-pii

# Encrypt data with latest version
vault write transit/encrypt/audit-pii \
  plaintext=$(echo "test@example.com" | base64)

# Decrypt data (works with any key version)
vault write transit/decrypt/audit-pii \
  ciphertext="vault:v5:..."

# Rewrap data to latest key version
vault write transit/rewrap/audit-pii \
  ciphertext="vault:v3:..."
```

### 4. External API Keys Rotation (Manual)

**Frequency**: 180 days or vendor-specific

**Example: SendGrid API Key**:

```bash
# 1. Generate new API key in SendGrid dashboard
# 2. Test new key works
curl -X POST https://api.sendgrid.com/v3/mail/send \
  -H "Authorization: Bearer <new_key>" \
  -H "Content-Type: application/json" \
  -d '{"personalizations":[{"to":[{"email":"test@example.com"}]}],"from":{"email":"noreply@scambuster.local"},"subject":"Test","content":[{"type":"text/plain","value":"Test"}]}'

# 3. Store new key in Vault
vault kv put secret/auth/sendgrid \
  api_key="<new_key>" \
  rotation_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  previous_key="<old_key>"

# 4. Restart services to pick up new key
kubectl rollout restart deployment/authentication-service -n application

# 5. Verify emails are sending
# Check logs for successful sends

# 6. After 7 days, revoke old key in SendGrid dashboard

# 7. Remove old key from Vault
vault kv put secret/auth/sendgrid \
  api_key="<new_key>" \
  rotation_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

### 5. TLS Certificate Rotation (Automated via cert-manager)

**Frequency**: 90 days (Let's Encrypt), auto-renew 30 days before expiry

**Configuration**:

```yaml
# cert-manager ClusterIssuer
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: security@scambuster.local
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

**Automatic Renewal**:
- cert-manager monitors certificates
- Renews 30 days before expiry
- Updates Kubernetes secrets
- Istio/Ingress automatically picks up new certificates

**Manual Force Rotation**:
```bash
# Delete certificate to force renewal
kubectl delete certificate api-scambuster-local -n application

# Check renewal status
kubectl describe certificate api-scambuster-local -n application

# Verify new certificate
kubectl get secret api-scambuster-local-tls -n application -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates
```

## Emergency Rotation

### Triggers for Emergency Rotation

1. **Credential compromise**: Secret exposed in code, logs, or stolen
2. **Personnel change**: Employee with access leaves company
3. **Security incident**: Breach or unauthorized access detected
4. **Vendor breach**: Third-party provider compromised
5. **Compliance requirement**: Audit finding or regulatory demand

### Emergency Procedure

```bash
# 1. IMMEDIATELY revoke compromised secret in Vault
vault kv delete secret/path/to/compromised-secret

# 2. Generate and deploy new secret (URGENT)
NEW_SECRET=$(openssl rand -base64 48)
vault kv put secret/path/to/new-secret \
  value="$NEW_SECRET" \
  rotation_reason="emergency" \
  rotation_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  incident_id="INC-2025-001"

# 3. Restart all affected services immediately
kubectl delete pods -l app=authentication-service -n application

# 4. Verify services come back healthy
kubectl get pods -n application -w

# 5. Monitor for unauthorized access attempts
kubectl logs -f deployment/authentication-service -n application | grep -i "unauthorized\|failed\|error"

# 6. File security incident report
# 7. Update runbook with lessons learned
# 8. Notify stakeholders
```

## Automation

### Automated Rotation Script

Create rotation automation with Vault and Kubernetes CronJobs:

```bash
# Create rotation script
cat > /scripts/rotate-secrets.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Rotate database credentials
vault lease revoke -prefix database/creds/auth-service
echo "$(date): Database credentials rotated" >> /var/log/rotation.log

# Rotate service account tokens
kubectl create token auth-service-sa -n application --duration=30d > /tmp/sa-token
kubectl create secret generic auth-service-token \
  --from-file=token=/tmp/sa-token \
  --dry-run=client -o yaml | kubectl apply -f -
echo "$(date): Service account token rotated" >> /var/log/rotation.log

# Trigger key rotation in Vault Transit
vault write -force transit/keys/audit-pii/rotate
echo "$(date): Transit key rotated" >> /var/log/rotation.log

# Send notification
curl -X POST <webhook_url> \
  -d "Secret rotation completed: $(date)"
EOF

chmod +x /scripts/rotate-secrets.sh
```

### Kubernetes CronJob for Automated Rotation

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: secrets-rotation
  namespace: operations
spec:
  schedule: "0 2 1 * *"  # 2 AM on 1st of every month
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: secrets-rotator
          containers:
          - name: rotator
            image: hashicorp/vault:latest
            command: ["/scripts/rotate-secrets.sh"]
            volumeMounts:
            - name: rotation-scripts
              mountPath: /scripts
            env:
            - name: VAULT_ADDR
              value: "https://vault.scambuster.local"
            - name: VAULT_TOKEN
              valueFrom:
                secretKeyRef:
                  name: vault-token
                  key: token
          volumes:
          - name: rotation-scripts
            configMap:
              name: rotation-scripts
              defaultMode: 0755
          restartPolicy: OnFailure
```

## Verification

### Post-Rotation Checklist

After every secret rotation:

- [ ] All services restarted successfully
- [ ] No authentication errors in logs
- [ ] API health checks passing
- [ ] End-to-end tests passing
- [ ] Monitoring dashboards green
- [ ] Old secret decommissioned after grace period
- [ ] Rotation documented in audit log
- [ ] New secret backed up securely
- [ ] Team notified of rotation completion

### Verification Commands

```bash
# Check service health
kubectl get pods -n application -o wide

# Check for authentication errors
kubectl logs -n application --all-containers=true --since=1h | grep -i "auth.*error\|credential.*fail"

# Run smoke tests
./scripts/smoke-tests.sh

# Verify Vault audit log
vault read sys/audit/file/file_path

# Check certificate expiry
kubectl get certificates -A -o custom-columns=NAME:.metadata.name,READY:.status.conditions[0].status,EXPIRY:.status.notAfter
```

## Rollback

### When to Rollback

- Services failing to start with new secret
- Authentication failures increase
- Data access errors
- Test suite failures
- Customer impact reported

### Rollback Procedure

```bash
# 1. Restore old secret from backup
vault kv put secret/path/to/secret \
  value="<old_secret>" \
  rollback="true" \
  rollback_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# 2. Restart services
kubectl rollout restart deployment/authentication-service -n application

# 3. Verify services healthy
kubectl rollout status deployment/authentication-service -n application

# 4. Monitor for 15 minutes
kubectl logs -f deployment/authentication-service -n application

# 5. If stable, investigate rotation failure
# 6. Plan corrective rotation

# 7. Document rollback in incident log
echo "$(date): Rolled back secret rotation. Reason: <reason>" >> /var/log/rotation-incidents.log
```

## Audit & Compliance

### Audit Log Format

All rotations must be logged with:

- Timestamp (UTC)
- Secret name/type
- Who initiated rotation (user or automated)
- Old secret version (reference only, not value)
- New secret version
- Reason for rotation (scheduled, emergency, personnel)
- Verification status (success/failure)
- Services impacted

### Example Audit Entry

```json
{
  "timestamp": "2025-11-09T12:00:00Z",
  "secret_type": "JWT_SECRET",
  "secret_path": "secret/auth/jwt",
  "initiated_by": "security-team",
  "reason": "scheduled_rotation",
  "old_version": "v3",
  "new_version": "v4",
  "verification": "success",
  "services_impacted": ["authentication-service"],
  "downtime": "0s",
  "rollback_performed": false
}
```

## References

- [Vault Database Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/databases)
- [Vault Transit Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/transit)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [04-secrets-management.md](04-secrets-management.md) - Secrets management overview
- [SOC 2 Credential Rotation Requirements](https://www.aicpa.org/soc2)

## Related Documentation

- [04-secrets-management.md](04-secrets-management.md) - HashiCorp Vault integration
- [02-zero-trust-architecture.md](02-zero-trust-architecture.md) - Zero Trust principles
- [07-security-checklist.md](07-security-checklist.md) - Security audit checklist

---

**Document Maintainers**: Security Team, DevOps Team
**Review Cycle**: Quarterly or after security incidents
**Next Review**: 2026-02-09

**Emergency Contacts**:
- Security Lead: security@scambuster.local
- DevOps Lead: devops@scambuster.local
- On-call: oncall@scambuster.local
