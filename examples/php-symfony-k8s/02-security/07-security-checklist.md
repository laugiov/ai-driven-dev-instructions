# Security Checklist

**Document Version**: 1.0
**Last Updated**: 2025-01-07
**Status**: Complete

## Table of Contents

1. [Overview](#overview)
2. [Pre-Deployment Checklist](#pre-deployment-checklist)
3. [Infrastructure Security](#infrastructure-security)
4. [Application Security](#application-security)
5. [Data Security](#data-security)
6. [Network Security](#network-security)
7. [Identity and Access Management](#identity-and-access-management)
8. [Secrets Management](#secrets-management)
9. [Monitoring and Detection](#monitoring-and-detection)
10. [Incident Response](#incident-response)
11. [Compliance](#compliance)
12. [Operational Security](#operational-security)
13. [Security Testing](#security-testing)
14. [Post-Deployment Verification](#post-deployment-verification)
15. [Quarterly Security Review](#quarterly-security-review)

## Overview

This comprehensive security checklist ensures that all security controls are properly implemented and verified before deployment and maintained throughout the system lifecycle. Use this checklist for:

- **Pre-deployment validation** - Before any production deployment
- **Security audits** - Quarterly security reviews
- **Incident investigation** - Verify security posture after incidents
- **Compliance audits** - Support SOC2, ISO27001, GDPR, NIS2 compliance
- **New service onboarding** - Validate security of new microservices

### Checklist Usage

**Symbols**:
- ✅ Requirement met and verified
- ⚠️ Partially implemented or needs improvement
- ❌ Not implemented
- N/A Not applicable to current deployment

**Severity Levels**:
- **CRITICAL** - Must be implemented before production deployment
- **HIGH** - Should be implemented within 30 days
- **MEDIUM** - Should be implemented within 90 days
- **LOW** - Nice to have, implement as resources allow

## Pre-Deployment Checklist

### Critical Security Gates

Before any production deployment, all CRITICAL items must be ✅:

#### Infrastructure

- [ ] **CRITICAL**: All Kubernetes nodes patched to latest stable version
- [ ] **CRITICAL**: Network policies deny all traffic by default
- [ ] **CRITICAL**: TLS 1.3 enforced for all external communication
- [ ] **CRITICAL**: mTLS enforced for all service-to-service communication
- [ ] **CRITICAL**: Secrets stored in Vault (never in code or ConfigMaps)
- [ ] **CRITICAL**: Container images scanned for vulnerabilities (no HIGH/CRITICAL)
- [ ] **CRITICAL**: Resource limits set on all pods
- [ ] **CRITICAL**: RBAC policies configured (no cluster-admin in production)

#### Application

- [ ] **CRITICAL**: Authentication required for all API endpoints
- [ ] **CRITICAL**: Authorization checks on all protected resources
- [ ] **CRITICAL**: Input validation on all user inputs
- [ ] **CRITICAL**: SQL injection protection (parameterized queries)
- [ ] **CRITICAL**: XSS protection (output encoding)
- [ ] **CRITICAL**: CSRF protection enabled
- [ ] **CRITICAL**: Rate limiting configured
- [ ] **CRITICAL**: Security headers configured (CSP, X-Frame-Options, etc.)

#### Data

- [ ] **CRITICAL**: Database encryption at rest enabled
- [ ] **CRITICAL**: PII fields encrypted at field level
- [ ] **CRITICAL**: Backups encrypted
- [ ] **CRITICAL**: Database credentials rotated
- [ ] **CRITICAL**: Row-Level Security enabled where applicable

#### Monitoring

- [ ] **CRITICAL**: Security monitoring enabled (Prometheus + AlertManager)
- [ ] **CRITICAL**: Audit logging enabled for all services
- [ ] **CRITICAL**: Alert rules configured for security events
- [ ] **CRITICAL**: On-call rotation established for security incidents

## Infrastructure Security

### Kubernetes Cluster

#### Cluster Configuration

- [ ] **HIGH**: Kubernetes version supported (latest stable or N-1)
- [ ] **HIGH**: Control plane HA configured (3+ masters)
- [ ] **MEDIUM**: Node OS hardened (CIS Benchmark Level 1)
- [ ] **HIGH**: etcd encryption enabled
- [ ] **HIGH**: Audit logging enabled for API server
- [ ] **MEDIUM**: Pod Security Standards enforced (restricted profile)
- [ ] **HIGH**: API server anonymous auth disabled
- [ ] **CRITICAL**: API server certificate rotation enabled

**Verification**:
```bash
# Check Kubernetes version
kubectl version --short

# Check audit logging
kubectl get pods -n kube-system -l component=kube-apiserver -o yaml | grep audit

# Check etcd encryption
kubectl get secrets -n kube-system | grep encryption-config

# Check PSA
kubectl get namespace application -o yaml | grep pod-security
```

#### Node Security

- [ ] **HIGH**: Nodes use immutable OS (Flatcar/Bottlerocket)
- [ ] **HIGH**: Automatic security updates enabled
- [ ] **MEDIUM**: SSH access restricted (bastion/SSM only)
- [ ] **HIGH**: kubelet authentication enabled
- [ ] **HIGH**: kubelet authorization mode set to Webhook
- [ ] **MEDIUM**: Kernel security modules enabled (AppArmor/SELinux)

**Verification**:
```bash
# Check node OS
kubectl get nodes -o wide

# Check kubelet config
kubectl get --raw /api/v1/nodes/<node-name>/proxy/configz
```

### Container Security

#### Image Security

- [ ] **CRITICAL**: All images from trusted registries only
- [ ] **CRITICAL**: Images scanned for vulnerabilities (Trivy/Snyk)
- [ ] **HIGH**: Images signed and signature verified
- [ ] **HIGH**: No images use 'latest' tag
- [ ] **CRITICAL**: Base images updated regularly
- [ ] **HIGH**: Images run as non-root user
- [ ] **MEDIUM**: Multi-stage builds used to minimize image size

**Verification**:
```bash
# Scan image for vulnerabilities
trivy image platform/llm-agent-service:v1.2.3

# Check image user
docker inspect platform/llm-agent-service:v1.2.3 | jq '.[0].Config.User'

# Verify image signature
cosign verify --key cosign.pub platform/llm-agent-service:v1.2.3
```

#### Runtime Security

- [ ] **CRITICAL**: Pod security context configured (runAsNonRoot: true)
- [ ] **CRITICAL**: Read-only root filesystem where possible
- [ ] **HIGH**: No privileged containers
- [ ] **HIGH**: No hostPath volumes (except for specific needs)
- [ ] **MEDIUM**: Seccomp profile applied
- [ ] **MEDIUM**: AppArmor/SELinux profiles applied
- [ ] **HIGH**: Capabilities dropped (drop: ALL, add specific only)

**Verification**:
```bash
# Check pod security context
kubectl get pods -n application -o json | jq '.items[].spec.securityContext'

# Check for privileged pods
kubectl get pods -n application -o json | jq '.items[] | select(.spec.containers[].securityContext.privileged == true)'
```

### Service Mesh (Istio)

- [ ] **CRITICAL**: Istio installed and configured
- [ ] **CRITICAL**: mTLS STRICT mode enabled mesh-wide
- [ ] **HIGH**: Authorization policies configured (deny by default)
- [ ] **HIGH**: Egress gateway configured for external traffic
- [ ] **MEDIUM**: Istio ingress gateway hardened
- [ ] **MEDIUM**: Telemetry v2 enabled
- [ ] **HIGH**: Certificate rotation automated

**Verification**:
```bash
# Check mTLS status
istioctl x describe pod llm-agent-pod -n application | grep mTLS

# Check authorization policies
kubectl get authorizationpolicies -A

# Verify cert rotation
kubectl get secrets -n istio-system -l istio.io/cert-signer
```

## Application Security

### Authentication

- [ ] **CRITICAL**: OAuth2/OIDC implemented via Keycloak
- [ ] **CRITICAL**: JWT tokens validated on every request
- [ ] **CRITICAL**: Token expiration enforced (< 1 hour)
- [ ] **HIGH**: Refresh tokens implemented
- [ ] **HIGH**: MFA enabled for admin users
- [ ] **MEDIUM**: MFA available for all users
- [ ] **HIGH**: Failed login attempts rate limited
- [ ] **HIGH**: Session management secure (HttpOnly, Secure, SameSite cookies)

**Verification**:
```bash
# Test authentication endpoint
curl -X POST https://api.platform.local/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"wrong"}' \
  -v

# Check JWT validation
curl https://api.platform.local/api/v1/workflows \
  -H "Authorization: Bearer invalid_token" \
  -v

# Check cookie flags
curl https://api.platform.local/auth/login -v | grep Set-Cookie
```

### Authorization

- [ ] **CRITICAL**: RBAC implemented for all resources
- [ ] **HIGH**: ABAC implemented for fine-grained control
- [ ] **CRITICAL**: Authorization checked on every endpoint
- [ ] **HIGH**: Principle of least privilege enforced
- [ ] **MEDIUM**: Regular permission audits conducted
- [ ] **HIGH**: Service accounts use minimal permissions
- [ ] **HIGH**: No hardcoded admin accounts

**Verification**:
```bash
# Test unauthorized access
curl https://api.platform.local/api/v1/admin/users \
  -H "Authorization: Bearer user_token" \
  -v

# Test cross-tenant access
curl https://api.platform.local/api/v1/workflows/<other-tenant-workflow-id> \
  -H "Authorization: Bearer tenant1_token" \
  -v
```

### Input Validation

- [ ] **CRITICAL**: All user inputs validated
- [ ] **CRITICAL**: Allow-list validation used (not deny-list)
- [ ] **CRITICAL**: Length limits enforced
- [ ] **HIGH**: Type validation enforced
- [ ] **HIGH**: Format validation (regex patterns)
- [ ] **CRITICAL**: File upload validation (type, size, content)
- [ ] **HIGH**: JSON/XML parsers configured securely

**Code Review**:
```php
// ✅ Good - Whitelist validation
public function updateWorkflow(UpdateWorkflowRequest $request): JsonResponse
{
    $validated = $request->validated(); // Uses validation rules
    // ...
}

// ❌ Bad - No validation
public function updateWorkflow(Request $request): JsonResponse
{
    $data = $request->all(); // Accepts anything
    // ...
}
```

### Output Encoding

- [ ] **CRITICAL**: HTML encoding for all user-generated content
- [ ] **CRITICAL**: JSON encoding for API responses
- [ ] **HIGH**: URL encoding for redirects
- [ ] **HIGH**: SQL query parameterization
- [ ] **CRITICAL**: Template auto-escaping enabled (Twig)

**Code Review**:
```php
// ✅ Good - Twig auto-escapes
{{ workflow.name }}

// ⚠️ Caution - Explicitly unescaping (must be sanitized first)
{{ workflow.description|raw }}

// ✅ Good - Parameterized query
$stmt = $pdo->prepare('SELECT * FROM workflows WHERE id = :id');
$stmt->execute(['id' => $workflowId]);

// ❌ Bad - SQL injection risk
$result = $pdo->query("SELECT * FROM workflows WHERE id = {$workflowId}");
```

### Security Headers

- [ ] **CRITICAL**: Content-Security-Policy configured
- [ ] **CRITICAL**: X-Frame-Options: DENY
- [ ] **CRITICAL**: X-Content-Type-Options: nosniff
- [ ] **HIGH**: X-XSS-Protection: 1; mode=block
- [ ] **CRITICAL**: Strict-Transport-Security with includeSubDomains
- [ ] **HIGH**: Referrer-Policy: strict-origin-when-cross-origin
- [ ] **HIGH**: Permissions-Policy configured

**Verification**:
```bash
# Check security headers
curl -I https://api.platform.local/api/v1/workflows

# Expected headers:
# Strict-Transport-Security: max-age=31536000; includeSubDomains
# X-Frame-Options: DENY
# X-Content-Type-Options: nosniff
# Content-Security-Policy: default-src 'self'
```

### API Security

- [ ] **CRITICAL**: Rate limiting implemented (global and per-user)
- [ ] **HIGH**: API versioning implemented
- [ ] **HIGH**: Request/response size limits enforced
- [ ] **HIGH**: CORS configured restrictively
- [ ] **HIGH**: API documentation doesn't expose sensitive info
- [ ] **MEDIUM**: GraphQL query depth limiting (if applicable)
- [ ] **HIGH**: No sensitive data in URLs (use POST body)

**Verification**:
```bash
# Test rate limiting
for i in {1..100}; do
  curl https://api.platform.local/api/v1/workflows &
done

# Should return 429 Too Many Requests after threshold

# Test CORS
curl https://api.platform.local/api/v1/workflows \
  -H "Origin: https://evil.com" \
  -v

# Should not return Access-Control-Allow-Origin for untrusted origin
```

### Error Handling

- [ ] **HIGH**: No stack traces exposed to users
- [ ] **HIGH**: Generic error messages for authentication failures
- [ ] **HIGH**: Detailed errors logged server-side
- [ ] **MEDIUM**: Error codes don't reveal system information
- [ ] **HIGH**: Exceptions caught and handled gracefully

**Code Review**:
```php
// ✅ Good - Generic error message
try {
    $user = $this->userRepository->findById($userId);
} catch (\Exception $e) {
    $this->logger->error('User retrieval failed', ['error' => $e->getMessage()]);
    throw new ApiException('Unable to retrieve user', 500);
}

// ❌ Bad - Exposes internal details
try {
    $user = $this->userRepository->findById($userId);
} catch (\Exception $e) {
    throw $e; // Exposes stack trace to client
}
```

### Dependency Management

- [ ] **HIGH**: All dependencies from trusted sources
- [ ] **CRITICAL**: Automated vulnerability scanning (Dependabot/Snyk)
- [ ] **HIGH**: Dependencies updated regularly
- [ ] **HIGH**: No known HIGH/CRITICAL vulnerabilities
- [ ] **MEDIUM**: Dependency licenses reviewed
- [ ] **HIGH**: Lockfiles committed (composer.lock)

**Verification**:
```bash
# Scan PHP dependencies
composer audit

# Scan npm dependencies (if applicable)
npm audit

# Check for outdated packages
composer outdated
```

## Data Security

### Encryption at Rest

- [ ] **CRITICAL**: Database TDE enabled
- [ ] **CRITICAL**: Storage volumes encrypted
- [ ] **CRITICAL**: Backups encrypted
- [ ] **CRITICAL**: PII fields encrypted at field level
- [ ] **HIGH**: Encryption keys in Vault (not in code)
- [ ] **HIGH**: Key rotation automated
- [ ] **MEDIUM**: Dead Letter Queue encrypted

**Verification**:
```bash
# Check volume encryption
kubectl get storageclass encrypted-ssd -o yaml | grep encrypted

# Check database encryption
psql -h postgres -U postgres -c "SHOW data_checksums;"

# Verify field encryption (should show vault: prefix)
psql -h postgres -U postgres -d users_db -c "SELECT email FROM users LIMIT 1;"
```

### Encryption in Transit

- [ ] **CRITICAL**: TLS 1.3 for external traffic
- [ ] **CRITICAL**: mTLS for internal service-to-service
- [ ] **HIGH**: TLS certificate auto-renewal (cert-manager)
- [ ] **HIGH**: Strong cipher suites only
- [ ] **MEDIUM**: OCSP stapling enabled
- [ ] **HIGH**: Certificate pinning for critical connections

**Verification**:
```bash
# Check TLS version
nmap --script ssl-enum-ciphers -p 443 api.platform.local

# Check internal mTLS
istioctl x describe pod llm-agent-pod -n application
```

### Data Classification

- [ ] **HIGH**: Data classification policy defined
- [ ] **HIGH**: PII identified and tagged
- [ ] **HIGH**: Sensitive fields marked in code
- [ ] **MEDIUM**: Classification scanner automated
- [ ] **HIGH**: Different handling per classification level

**Code Review**:
```php
// ✅ Good - Data classification attributes
#[DataClassification(
    level: DataClassificationLevel::RESTRICTED,
    isPII: true,
    encryptionRequired: 'field-level'
)]
private string $email;

// ⚠️ Missing - No classification
private string $phoneNumber; // Should be classified
```

### Data Retention

- [ ] **HIGH**: Retention policies documented
- [ ] **HIGH**: Automated purging of expired data
- [ ] **CRITICAL**: GDPR right to erasure implemented
- [ ] **HIGH**: Backup retention policy enforced
- [ ] **MEDIUM**: Archived data encrypted
- [ ] **HIGH**: Audit logs retained per compliance requirements

**Verification**:
```bash
# Check data retention job
kubectl get cronjobs -n application | grep retention

# Verify last purge
kubectl logs -n application <retention-cronjob-pod>
```

### PII Protection

- [ ] **CRITICAL**: PII detection implemented
- [ ] **HIGH**: PII not logged
- [ ] **HIGH**: PII masked in non-production
- [ ] **HIGH**: PII redacted in exports
- [ ] **CRITICAL**: Consent management implemented
- [ ] **HIGH**: PII access audited

**Code Review**:
```php
// ✅ Good - PII redaction before logging
$this->logger->info('User updated', [
    'user_id' => $user->getId(),
    'email' => $this->piiRedactor->redact($user->getEmail()),
]);

// ❌ Bad - PII in logs
$this->logger->info('User updated', [
    'email' => $user->getEmail(), // Raw PII
]);
```

### Database Security

- [ ] **HIGH**: Row-Level Security enabled
- [ ] **CRITICAL**: Dedicated service accounts (no shared accounts)
- [ ] **HIGH**: Principle of least privilege for DB access
- [ ] **HIGH**: Connection encryption required
- [ ] **HIGH**: Database audit logging enabled
- [ ] **MEDIUM**: Query timeout configured
- [ ] **HIGH**: No default/weak passwords

**Verification**:
```bash
# Check RLS policies
psql -h postgres -U postgres -d workflows_db \
  -c "\d workflows" | grep POLICY

# Check user privileges
psql -h postgres -U postgres \
  -c "\du workflow_service"

# Test connection encryption
psql "postgresql://workflow_service@postgres/workflows_db?sslmode=require"
```

## Network Security

### Network Policies

- [ ] **CRITICAL**: Default deny policy in all namespaces
- [ ] **CRITICAL**: Explicit allow policies for required communication
- [ ] **HIGH**: Egress filtering configured
- [ ] **HIGH**: DNS access allowed
- [ ] **MEDIUM**: Monitoring access configured
- [ ] **HIGH**: Cross-namespace policies reviewed

**Verification**:
```bash
# Check default deny policy
kubectl get networkpolicies -n application

# Test connectivity
kubectl run test-pod --rm -it --image=nicolaka/netshoot -- /bin/bash
curl llm-agent-service.application:8080/health
```

### Service Mesh Policies

- [ ] **CRITICAL**: PeerAuthentication STRICT mode
- [ ] **CRITICAL**: Authorization policies deny by default
- [ ] **HIGH**: Request authentication configured
- [ ] **HIGH**: JWT validation at mesh level
- [ ] **HIGH**: Rate limiting configured
- [ ] **MEDIUM**: Circuit breakers configured
- [ ] **HIGH**: Retry policies configured

**Verification**:
```bash
# Check mTLS enforcement
kubectl get peerauthentication -n application

# Check authz policies
kubectl get authorizationpolicies -n application

# Test unauthorized access
kubectl exec -it <pod> -- curl http://llm-agent-service:8080/api/v1/agents
# Should be denied without valid JWT
```

### Ingress/Egress

- [ ] **HIGH**: Ingress controller configured securely
- [ ] **HIGH**: TLS termination at ingress
- [ ] **HIGH**: Egress gateway for external calls
- [ ] **MEDIUM**: Egress filtering (allow-list)
- [ ] **HIGH**: DDoS protection enabled
- [ ] **HIGH**: WAF configured (OWASP rules)

**Verification**:
```bash
# Check ingress configuration
kubectl get gateway -n istio-system

# Check egress gateway
kubectl get gateway platform-egress -n istio-system

# Test egress filtering
kubectl exec -it <pod> -- curl https://google.com
# Should be blocked if not in allow-list
```

### Network Monitoring

- [ ] **HIGH**: Network traffic logged
- [ ] **HIGH**: Anomaly detection enabled
- [ ] **HIGH**: Security alerts configured
- [ ] **MEDIUM**: Network flow analysis
- [ ] **HIGH**: mTLS violations alerted

**Verification**:
```bash
# Check for network monitoring
kubectl get servicemonitor -n observability | grep istio

# Check alert rules
kubectl get prometheusrules -n observability | grep network
```

## Identity and Access Management

### Keycloak Configuration

- [ ] **CRITICAL**: Keycloak deployed with HA
- [ ] **CRITICAL**: Admin console access restricted
- [ ] **HIGH**: Password policies enforced (complexity, rotation)
- [ ] **HIGH**: MFA enabled for admins
- [ ] **HIGH**: Session timeout configured
- [ ] **HIGH**: Brute force protection enabled
- [ ] **MEDIUM**: Account lockout policy configured

**Verification**:
```bash
# Check Keycloak replication
kubectl get pods -n infrastructure | grep keycloak

# Test password policy
curl -X POST https://keycloak.platform.local/auth/realms/platform/account/password \
  -d "password=weak" # Should be rejected

# Test brute force protection
for i in {1..20}; do
  curl -X POST https://keycloak.platform.local/auth/realms/platform/protocol/openid-connect/token \
    -d "username=test&password=wrong&grant_type=password"
done
# Account should be locked
```

### Service Account Management

- [ ] **CRITICAL**: Unique service account per microservice
- [ ] **HIGH**: No default service account usage
- [ ] **HIGH**: Token automounting disabled where not needed
- [ ] **HIGH**: Token audience binding configured
- [ ] **MEDIUM**: Service account tokens rotated regularly

**Verification**:
```bash
# Check service accounts
kubectl get serviceaccounts -n application

# Check for default SA usage
kubectl get pods -n application -o json | jq '.items[] | select(.spec.serviceAccountName == "default")'

# Check token automounting
kubectl get serviceaccount llm-agent-service -n application -o yaml | grep automountServiceAccountToken
```

### RBAC Configuration

- [ ] **CRITICAL**: No cluster-admin in production
- [ ] **HIGH**: Role-based separation of duties
- [ ] **HIGH**: Least privilege principle enforced
- [ ] **HIGH**: Regular RBAC audits conducted
- [ ] **MEDIUM**: RBAC policies documented
- [ ] **HIGH**: No wildcard permissions (*, *, *)

**Verification**:
```bash
# Check for cluster-admin bindings
kubectl get clusterrolebindings -o json | jq '.items[] | select(.roleRef.name == "cluster-admin")'

# Check for overly permissive roles
kubectl get roles -A -o json | jq '.items[] | select(.rules[].verbs[] == "*")'

# Audit user permissions
kubectl auth can-i --list --as=system:serviceaccount:application:llm-agent-service
```

## Secrets Management

### Vault Configuration

- [ ] **CRITICAL**: Vault deployed with HA
- [ ] **CRITICAL**: Vault auto-unseal configured
- [ ] **HIGH**: Vault audit logging enabled
- [ ] **HIGH**: Vault policies follow least privilege
- [ ] **HIGH**: Secret engines configured properly
- [ ] **HIGH**: Dynamic secrets used where possible
- [ ] **MEDIUM**: Secret versioning enabled

**Verification**:
```bash
# Check Vault status
vault status

# Check audit log
vault audit list

# Check policies
vault policy list
vault policy read llm-agent-service

# Test dynamic secrets
vault read database/creds/llm-agent-role
```

### Secret Rotation

- [ ] **HIGH**: Automated secret rotation configured
- [ ] **HIGH**: Database credentials rotated regularly (< 90 days)
- [ ] **HIGH**: API keys rotated regularly
- [ ] **CRITICAL**: No secrets in code repositories
- [ ] **CRITICAL**: No secrets in container images
- [ ] **HIGH**: Secret rotation documented

**Verification**:
```bash
# Check for secrets in git history
git log -p | grep -i 'password\|secret\|api_key'

# Check secret age
vault kv metadata get secret/database/workflow-db

# Verify no secrets in images
docker inspect platform/llm-agent-service:v1.2.3 | grep -i password
```

### Secret Access

- [ ] **HIGH**: Kubernetes auth method configured
- [ ] **HIGH**: AppRole for CI/CD
- [ ] **MEDIUM**: Token TTL configured (< 24 hours)
- [ ] **HIGH**: Secret access audited
- [ ] **HIGH**: No long-lived tokens

**Verification**:
```bash
# Check auth methods
vault auth list

# Check token TTL
vault token lookup | grep ttl

# Review secret access logs
vault audit log | grep secret/database
```

## Monitoring and Detection

### Logging

- [ ] **CRITICAL**: Centralized logging configured (Loki)
- [ ] **CRITICAL**: All services logging to stdout/stderr
- [ ] **HIGH**: Structured logging (JSON format)
- [ ] **HIGH**: Log retention policy configured
- [ ] **HIGH**: PII redacted from logs
- [ ] **MEDIUM**: Log sampling for high-volume logs
- [ ] **HIGH**: Audit logs separate from application logs

**Verification**:
```bash
# Check log aggregation
kubectl get pods -n observability | grep loki

# Check log format
kubectl logs -n application llm-agent-pod | head -1 | jq .

# Verify PII redaction
kubectl logs -n application llm-agent-pod | grep -i email
# Should show redacted values, not real emails
```

### Metrics

- [ ] **HIGH**: Prometheus scraping all services
- [ ] **HIGH**: Security metrics exposed
- [ ] **HIGH**: SLI/SLO metrics defined
- [ ] **MEDIUM**: Custom business metrics
- [ ] **HIGH**: Metrics retention configured

**Verification**:
```bash
# Check Prometheus targets
kubectl port-forward -n observability prometheus-0 9090:9090
# Visit http://localhost:9090/targets

# Check for security metrics
curl prometheus:9090/api/v1/query?query=istio_requests_total
```

### Alerting

- [ ] **CRITICAL**: AlertManager configured
- [ ] **CRITICAL**: Security alerts defined
- [ ] **HIGH**: Alert severity levels configured
- [ ] **HIGH**: On-call rotation configured
- [ ] **HIGH**: Alert fatigue minimized (proper thresholds)
- [ ] **HIGH**: Alerts tested regularly

**Verification**:
```bash
# Check alert rules
kubectl get prometheusrules -n observability

# Check alert manager config
kubectl get secret -n observability alertmanager-config -o yaml

# Test alert
curl -X POST prometheus:9090/api/v1/alerts # Simulate alert
```

### Security Monitoring

- [ ] **HIGH**: Failed authentication attempts monitored
- [ ] **HIGH**: Privilege escalation detected
- [ ] **HIGH**: Unusual data access monitored
- [ ] **HIGH**: Network anomalies detected
- [ ] **MEDIUM**: Threat intelligence feed integrated
- [ ] **HIGH**: SIEM integration (if applicable)

**Alert Examples**:
```yaml
# High failed authentication rate
- alert: HighFailedAuthRate
  expr: rate(auth_failed_total[5m]) > 10
  for: 5m
  severity: high

# Privilege escalation
- alert: PrivilegeEscalation
  expr: changes(rbac_role_bindings[5m]) > 0
  severity: critical

# Mass data export
- alert: MassDataExport
  expr: rate(data_export_total[1h]) > 1000
  severity: high
```

## Incident Response

### Preparation

- [ ] **HIGH**: Incident response plan documented
- [ ] **HIGH**: Security runbooks created
- [ ] **HIGH**: On-call rotation established
- [ ] **HIGH**: Communication channels defined
- [ ] **MEDIUM**: Incident response team trained
- [ ] **HIGH**: Post-incident review process defined

### Detection

- [ ] **HIGH**: Intrusion detection system configured
- [ ] **HIGH**: Anomaly detection enabled
- [ ] **HIGH**: Security alerts to on-call
- [ ] **HIGH**: Log correlation configured
- [ ] **MEDIUM**: Threat hunting procedures defined

### Response

- [ ] **HIGH**: Automated blocking for obvious threats
- [ ] **HIGH**: Manual review process for complex incidents
- [ ] **HIGH**: Forensic data collection automated
- [ ] **HIGH**: Communication templates prepared
- [ ] **CRITICAL**: Data breach notification process (< 72 hours GDPR)

### Recovery

- [ ] **HIGH**: Backup restoration tested
- [ ] **HIGH**: Disaster recovery plan documented
- [ ] **HIGH**: RTO/RPO defined and tested
- [ ] **MEDIUM**: Failover procedures automated
- [ ] **HIGH**: Post-incident hardening checklist

## Compliance

### GDPR

- [ ] **CRITICAL**: Privacy policy published
- [ ] **CRITICAL**: Consent management implemented
- [ ] **CRITICAL**: Right to access (Art. 15) implemented
- [ ] **CRITICAL**: Right to erasure (Art. 17) implemented
- [ ] **CRITICAL**: Right to portability (Art. 20) implemented
- [ ] **HIGH**: Data protection by design (Art. 25)
- [ ] **CRITICAL**: Data breach notification process (Art. 33/34)
- [ ] **HIGH**: DPO appointed (if required)
- [ ] **HIGH**: DPIA conducted for high-risk processing

**Verification**:
```bash
# Test data export
curl https://api.platform.local/api/v1/users/me/export \
  -H "Authorization: Bearer user_token"

# Test data deletion
curl -X DELETE https://api.platform.local/api/v1/users/me \
  -H "Authorization: Bearer user_token"

# Check consent management
curl https://api.platform.local/api/v1/users/me/consents \
  -H "Authorization: Bearer user_token"
```

### SOC 2

- [ ] **HIGH**: CC6.1 - Logical access controls
- [ ] **HIGH**: CC6.6 - Encryption in transit
- [ ] **HIGH**: CC6.7 - Encryption at rest
- [ ] **HIGH**: CC7.2 - Threat detection
- [ ] **HIGH**: CC7.3 - Security monitoring
- [ ] **HIGH**: CC7.5 - Incident response
- [ ] **HIGH**: CC8.1 - Change management
- [ ] **HIGH**: Audit reports generated regularly

### ISO 27001

- [ ] **HIGH**: A.9.1 - Access control policy
- [ ] **HIGH**: A.9.4 - Privileged access management
- [ ] **HIGH**: A.10.1 - Cryptographic controls
- [ ] **HIGH**: A.12.3 - Information backup
- [ ] **HIGH**: A.12.4 - Logging and monitoring
- [ ] **HIGH**: A.13.1 - Network security
- [ ] **HIGH**: A.16.1 - Incident management
- [ ] **HIGH**: Information Security Management System (ISMS) documented

### NIS2

- [ ] **HIGH**: Art. 21 - Risk management measures
- [ ] **HIGH**: Supply chain security measures
- [ ] **HIGH**: Incident handling capability
- [ ] **CRITICAL**: Incident reporting (< 24 hours)
- [ ] **HIGH**: Business continuity measures
- [ ] **HIGH**: Crisis response procedures

## Operational Security

### Change Management

- [ ] **HIGH**: All changes reviewed (pull requests)
- [ ] **HIGH**: Security review for significant changes
- [ ] **HIGH**: Automated testing in CI/CD
- [ ] **HIGH**: Staging environment testing mandatory
- [ ] **HIGH**: Rollback plan for all changes
- [ ] **MEDIUM**: Change approval process documented

### Patch Management

- [ ] **CRITICAL**: Critical security patches within 48 hours
- [ ] **HIGH**: Regular patch schedule (monthly)
- [ ] **HIGH**: Automated vulnerability scanning
- [ ] **HIGH**: Patch testing in non-production
- [ ] **HIGH**: Emergency patching procedure documented

### Access Management

- [ ] **HIGH**: User access reviews quarterly
- [ ] **HIGH**: Offboarding checklist (revoke all access)
- [ ] **HIGH**: Privileged access logged and reviewed
- [ ] **HIGH**: Just-in-time access for sensitive operations
- [ ] **MEDIUM**: Access request workflow automated

### Security Training

- [ ] **HIGH**: Security awareness training for all staff
- [ ] **HIGH**: Secure coding training for developers
- [ ] **MEDIUM**: Phishing simulation exercises
- [ ] **HIGH**: Incident response drills
- [ ] **MEDIUM**: Security champion program

## Security Testing

### Automated Testing

- [ ] **HIGH**: SAST in CI/CD pipeline (PHPStan level 9)
- [ ] **HIGH**: Dependency vulnerability scanning
- [ ] **HIGH**: Container image scanning
- [ ] **HIGH**: Infrastructure as Code scanning (Checkov)
- [ ] **MEDIUM**: Secret scanning in commits

**CI/CD Integration**:
```yaml
# .github/workflows/security.yml
- name: SAST
  run: ./vendor/bin/phpstan analyse --level=9

- name: Dependency scan
  run: composer audit

- name: Container scan
  run: trivy image $IMAGE_NAME

- name: IaC scan
  run: checkov -d ./terraform
```

### Manual Testing

- [ ] **HIGH**: Penetration testing annually
- [ ] **HIGH**: Security code review for critical features
- [ ] **MEDIUM**: Threat modeling for new features
- [ ] **HIGH**: Red team exercises (if applicable)
- [ ] **MEDIUM**: Bug bounty program considered

### Compliance Testing

- [ ] **HIGH**: GDPR compliance audit
- [ ] **HIGH**: SOC 2 Type II audit (annually)
- [ ] **MEDIUM**: ISO 27001 certification audit
- [ ] **HIGH**: PCI DSS audit (if handling cards)
- [ ] **HIGH**: Compliance findings remediated

## Post-Deployment Verification

### Immediate Verification (Day 1)

Within 24 hours of deployment:

- [ ] All services healthy and responding
- [ ] Authentication working correctly
- [ ] Authorization policies enforcing access
- [ ] TLS certificates valid
- [ ] mTLS enforced between services
- [ ] Rate limiting active
- [ ] Monitoring and alerting functional
- [ ] Audit logging working
- [ ] Backups running

**Verification Script**:
```bash
#!/bin/bash
# post-deployment-check.sh

echo "=== Service Health ==="
kubectl get pods -n application
echo

echo "=== Authentication Test ==="
curl -f https://api.platform.local/api/v1/workflows || echo "FAIL: Requires auth ✅"
echo

echo "=== mTLS Verification ==="
istioctl x describe pod -n application llm-agent-pod | grep "mTLS"
echo

echo "=== Rate Limiting Test ==="
for i in {1..50}; do
  curl -s https://api.platform.local/api/v1/health &
done
wait
echo "Check for 429 responses ✅"
echo

echo "=== Monitoring Check ==="
kubectl get servicemonitors -n observability
echo

echo "=== Alert Rules ==="
kubectl get prometheusrules -n observability
```

### First Week Verification

- [ ] Review all security alerts
- [ ] Analyze access patterns
- [ ] Check for anomalies
- [ ] Review audit logs
- [ ] Verify backup success
- [ ] Check error rates
- [ ] Review performance metrics

### First Month Verification

- [ ] Conduct security review
- [ ] Review incident response effectiveness
- [ ] Analyze false positive rate
- [ ] Optimize alert thresholds
- [ ] Review compliance posture
- [ ] Update documentation

## Quarterly Security Review

Every 3 months, conduct comprehensive security review:

### Access Review

- [ ] Review all user accounts (disable unused)
- [ ] Review all service accounts
- [ ] Review RBAC policies
- [ ] Review API keys (rotate old ones)
- [ ] Review Vault policies
- [ ] Audit privileged access logs

### Policy Review

- [ ] Review and update security policies
- [ ] Review authorization policies
- [ ] Review network policies
- [ ] Review data classification
- [ ] Review retention policies
- [ ] Update incident response procedures

### Vulnerability Management

- [ ] Review open vulnerabilities
- [ ] Prioritize and remediate HIGH/CRITICAL
- [ ] Update dependency versions
- [ ] Review security advisories
- [ ] Conduct penetration test
- [ ] Update threat model

### Compliance Review

- [ ] Review GDPR compliance
- [ ] Review SOC 2 controls
- [ ] Review ISO 27001 controls
- [ ] Generate compliance reports
- [ ] Document control changes
- [ ] Prepare for external audits

### Training Review

- [ ] Conduct security training
- [ ] Review security incidents (lessons learned)
- [ ] Update security documentation
- [ ] Share security best practices
- [ ] Celebrate security wins

## Severity-Based Remediation Timeline

| Severity | Remediation Deadline | Escalation |
|----------|---------------------|------------|
| **CRITICAL** | 48 hours | CISO, CTO |
| **HIGH** | 30 days | Security Lead |
| **MEDIUM** | 90 days | Team Lead |
| **LOW** | Next planning cycle | Backlog |

## Security Metrics

Track these metrics over time:

- **Mean Time to Detect (MTTD)** - Time from incident to detection
- **Mean Time to Respond (MTTR)** - Time from detection to mitigation
- **Vulnerability Remediation Time** - Time from discovery to fix
- **Failed Authentication Rate** - Indicator of attacks
- **False Positive Rate** - Alert quality metric
- **Security Training Completion** - Staff preparedness
- **Patch Coverage** - % systems patched to latest

## Tools Reference

### Security Testing Tools

| Tool | Purpose | Usage |
|------|---------|-------|
| **PHPStan** | SAST for PHP | `./vendor/bin/phpstan analyse --level=9` |
| **Composer Audit** | Dependency scanning | `composer audit` |
| **Trivy** | Container scanning | `trivy image <image>` |
| **Checkov** | IaC scanning | `checkov -d ./terraform` |
| **OWASP ZAP** | DAST | Manual penetration testing |
| **Snyk** | Dependency scanning | `snyk test` |
| **git-secrets** | Secret scanning | `git secrets --scan` |

### Kubernetes Security Tools

| Tool | Purpose | Usage |
|------|---------|-------|
| **kubectl-who-can** | RBAC analysis | `kubectl who-can get secrets` |
| **kube-bench** | CIS benchmark | `kube-bench run` |
| **kube-hunter** | Penetration testing | `kube-hunter --remote <cluster>` |
| **Polaris** | Config validation | `polaris audit` |
| **Falco** | Runtime security | Monitors container behavior |

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [GDPR Official Text](https://gdpr-info.eu/)
- [SOC 2 Trust Services Criteria](https://www.aicpa.org/interestareas/frc/assuranceadvisoryservices/aicpasoc2report.html)

## Related Documentation

- [01-security-principles.md](01-security-principles.md) - Core security principles
- [02-zero-trust-architecture.md](02-zero-trust-architecture.md) - Zero Trust implementation
- [03-authentication-authorization.md](03-authentication-authorization.md) - Identity & access
- [04-secrets-management.md](04-secrets-management.md) - Secrets handling
- [05-network-security.md](05-network-security.md) - Network controls
- [06-data-protection.md](06-data-protection.md) - Data security

---

**Document Maintainers**: Security Team, Compliance Team
**Review Cycle**: Quarterly and before each major deployment
**Next Review**: 2025-04-07

**Template Usage**: Copy this checklist for each deployment/audit, mark items as you verify them, and store completed checklists as audit evidence.
