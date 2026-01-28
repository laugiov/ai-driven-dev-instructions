# Security Principles

## Overview

This document defines the core security principles that govern all design and implementation decisions in the platform. These principles ensure security is built into every layer, not bolted on as an afterthought.

## Core Principles

### 1. Security by Design

**Definition**: Security considerations are integrated into every phase of development, from initial design through deployment.

**Implementation**:
- ✅ Threat modeling during design phase
- ✅ Security requirements defined before development
- ✅ Security architecture review before implementation
- ✅ Security testing integrated into CI/CD
- ✅ Security monitoring in production

**Example**:
```
Design Phase:
│
├─ Identify assets (data, services, users)
├─ Identify threats (STRIDE model)
├─ Define security controls
├─ Document security requirements
│
Development Phase:
│
├─ Implement security controls
├─ Code review with security checklist
├─ SAST/DAST scanning
├─ Penetration testing
│
Deployment Phase:
│
├─ Security configuration validation
├─ Runtime security monitoring (Falco)
├─ Continuous vulnerability scanning
└─ Incident response readiness
```

### 2. Defense in Depth

**Definition**: Multiple layers of security controls ensure that if one layer fails, others still provide protection.

**Security Layers**:

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 7: Application Security                              │
│ - Input validation, output encoding                        │
│ - Authentication, authorization                            │
│ - Secure session management                                │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│ Layer 6: API Gateway Security                              │
│ - Rate limiting, WAF                                        │
│ - API key validation, OAuth2                               │
│ - Request/response transformation                          │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│ Layer 5: Service Mesh Security                             │
│ - mTLS between services                                     │
│ - Service-to-service authorization                          │
│ - Traffic encryption                                        │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│ Layer 4: Network Security                                  │
│ - Network policies (Kubernetes NetworkPolicy)              │
│ - Micro-segmentation                                        │
│ - Firewall rules                                            │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: Infrastructure Security                           │
│ - Pod security policies/standards                          │
│ - Resource quotas, limits                                  │
│ - Read-only root filesystem                                │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Data Security                                     │
│ - Encryption at rest (AES-256)                             │
│ - Encryption in transit (TLS 1.3)                          │
│ - Database access controls                                 │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: Physical/Cloud Security                           │
│ - Cloud provider security controls                         │
│ - Physical access controls                                 │
│ - Hardware security modules (HSM)                          │
└─────────────────────────────────────────────────────────────┘
```

**Rationale**: Single point of failure is eliminated. Attackers must breach multiple layers.

### 3. Least Privilege

**Definition**: Every user, service, and process has only the minimum permissions required to perform its function.

**Implementation**:

**User Level**:
```yaml
# Bad: Admin role for everything
roles:
  - admin: ['*']

# Good: Granular permissions
roles:
  - workflow_creator:
      - workflow:create
      - workflow:read_own
  - workflow_executor:
      - workflow:read
      - workflow:execute
  - workflow_admin:
      - workflow:create
      - workflow:read
      - workflow:update
      - workflow:delete
      - workflow:execute
```

**Service Level (Kubernetes RBAC)**:
```yaml
# Service account with minimal permissions
apiVersion: v1
kind: ServiceAccount
metadata:
  name: llm-agent-service
  namespace: production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: llm-agent-role
  namespace: production
rules:
  # Only read ConfigMaps (not create/delete)
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list"]
  # Only read Secrets (not create/delete)
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get"]
```

**Database Level**:
```sql
-- Application user: Read/write only to own schema
CREATE USER llm_agent_app WITH PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE llm_agent TO llm_agent_app;
GRANT USAGE ON SCHEMA llm_agent TO llm_agent_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA llm_agent TO llm_agent_app;

-- No DROP, TRUNCATE, ALTER permissions
-- No access to other schemas
```

### 4. Zero Trust Architecture

**Definition**: Never trust, always verify. No implicit trust based on network location.

**Principles**:
1. **Verify explicitly**: Authenticate and authorize every request
2. **Least privilege access**: Minimize access scope
3. **Assume breach**: Segment access, minimize blast radius

**Implementation**: See [02-zero-trust-architecture.md](02-zero-trust-architecture.md)

### 5. Fail Secure (Fail Closed)

**Definition**: When errors occur, system defaults to secure state, not permissive state.

**Examples**:

**Bad (Fail Open)**:
```php
public function authorize(User $user, Resource $resource): bool
{
    try {
        return $this->authorizationService->check($user, $resource);
    } catch (\Exception $e) {
        // ❌ Failing open: Grant access on error
        $this->logger->error('Authorization failed', ['error' => $e]);
        return true;  // Dangerous!
    }
}
```

**Good (Fail Secure)**:
```php
public function authorize(User $user, Resource $resource): bool
{
    try {
        return $this->authorizationService->check($user, $resource);
    } catch (\Exception $e) {
        // ✅ Failing closed: Deny access on error
        $this->logger->critical('Authorization check failed', [
            'user' => $user->getId(),
            'resource' => $resource->getId(),
            'error' => $e->getMessage(),
        ]);
        return false;  // Safe default
    }
}
```

**Circuit Breaker Example**:
```php
public function executeWorkflow(WorkflowId $id): void
{
    if ($this->circuitBreaker->isOpen()) {
        // ✅ Fail secure: Reject request when downstream is failing
        throw new ServiceUnavailableException('Workflow service temporarily unavailable');
    }

    try {
        $this->workflowService->execute($id);
        $this->circuitBreaker->recordSuccess();
    } catch (\Exception $e) {
        $this->circuitBreaker->recordFailure();
        throw $e;
    }
}
```

### 6. Complete Mediation

**Definition**: Every access to every resource must be checked for authorization. No bypass.

**Implementation**:

**API Level**:
```php
#[Route('/api/v1/workflows/{id}', methods: ['GET'])]
#[IsGranted('WORKFLOW_READ', 'workflow')]  // ✅ Every endpoint protected
public function get(string $id): JsonResponse
{
    $workflow = $this->workflowRepository->findById(new WorkflowId($id));
    return $this->json(WorkflowDTO::fromEntity($workflow));
}

#[Route('/api/v1/workflows/{id}', methods: ['DELETE'])]
#[IsGranted('WORKFLOW_DELETE', 'workflow')]  // ✅ Different permission
public function delete(string $id): JsonResponse
{
    // ...
}
```

**Service Level**:
```php
public function execute(WorkflowId $id, UserId $userId): void
{
    $workflow = $this->repository->findById($id);

    // ✅ Check authorization even within service
    if (!$this->authorizationService->canExecute($userId, $workflow)) {
        throw new ForbiddenException('User cannot execute this workflow');
    }

    $workflow->execute();
}
```

**Database Level**: Use PostgreSQL Row-Level Security (RLS)
```sql
-- Enable RLS on workflows table
ALTER TABLE workflows ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own workflows
CREATE POLICY workflow_isolation ON workflows
  FOR SELECT
  USING (owner_id = current_setting('app.current_user_id')::uuid);
```

### 7. Separation of Duties

**Definition**: Critical operations require multiple parties/steps, preventing single point of compromise.

**Examples**:

**Deployment**:
```yaml
# GitHub Actions: Build and test
- Developer: Writes code, creates PR
- CI: Runs automated tests, security scans
- Reviewer: Code review, approval
- CI: Builds artifact, pushes to registry
- ArgoCD: Deploys to cluster (automated)
- Operations: Monitors deployment

# No single person can deploy without checks
```

**Secret Management**:
```bash
# Splitting secret access
- Vault Admin: Can create policies, but not read secrets
- Developer: Can read development secrets only
- Operations: Can read production secrets only
- No one person has all secrets
```

**Database**:
```sql
-- Separate roles for different responsibilities
CREATE ROLE app_read;  -- Read-only queries
CREATE ROLE app_write;  -- Insert, update, delete
CREATE ROLE app_admin;  -- Schema changes (used by migrations only)

-- Application uses app_read and app_write, never app_admin at runtime
```

### 8. Audit Everything

**Definition**: All security-relevant events are logged immutably for forensic analysis.

**What to Audit**:
- ✅ Authentication attempts (success and failure)
- ✅ Authorization decisions
- ✅ Data access (especially sensitive data)
- ✅ Configuration changes
- ✅ Administrative actions
- ✅ Security policy changes
- ✅ Privilege escalations

**Audit Event Structure**:
```json
{
  "eventId": "uuid",
  "timestamp": "2025-11-07T10:30:00Z",
  "eventType": "AUTHENTICATION_FAILURE",
  "actor": {
    "userId": "user-123",
    "ipAddress": "192.168.1.100",
    "userAgent": "Mozilla/5.0..."
  },
  "action": "LOGIN",
  "resource": {
    "type": "USER_ACCOUNT",
    "id": "user-123"
  },
  "result": "FAILURE",
  "reason": "INVALID_CREDENTIALS",
  "metadata": {
    "attemptCount": 3,
    "accountLocked": false
  },
  "checksum": "sha256:abcd1234..."
}
```

**Implementation**: See [../08-services/audit-logging-service/](../08-services/audit-logging-service/)

### 9. Secure by Default

**Definition**: Default configuration is secure. Insecure options must be explicitly enabled.

**Examples**:

**Symfony Security**:
```yaml
# config/packages/security.yaml
security:
  # ✅ Strict mode by default
  hide_user_not_found: true  # Don't reveal if user exists
  erase_credentials: true    # Clear sensitive data after auth

  password_hashers:
    # ✅ Strong hashing by default
    Symfony\Component\Security\Core\User\PasswordAuthenticatedUserInterface:
      algorithm: 'auto'
      cost: 15  # High cost for bcrypt

  firewalls:
    main:
      # ✅ HTTPS required
      require_previous_session: false
      stateless: true

      # ✅ CSRF protection enabled
      csrf_token_generator: security.csrf.token_manager
```

**HTTP Headers**:
```php
// All responses include security headers by default
public function configureResponseHeaders(Response $response): void
{
    $response->headers->set('X-Content-Type-Options', 'nosniff');
    $response->headers->set('X-Frame-Options', 'DENY');
    $response->headers->set('X-XSS-Protection', '1; mode=block');
    $response->headers->set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
    $response->headers->set('Content-Security-Policy', "default-src 'self'");
    $response->headers->set('Referrer-Policy', 'no-referrer');
    $response->headers->set('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');
}
```

**Database Connections**:
```yaml
# config/packages/doctrine.yaml
doctrine:
  dbal:
    # ✅ Secure by default
    url: '%env(resolve:DATABASE_URL)%'
    options:
      # Force SSL for database connections
      !php/const PDO::MYSQL_ATTR_SSL_CA: '%kernel.project_dir%/config/certs/ca.pem'
      !php/const PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT: true
```

### 10. Privacy by Design

**Definition**: Privacy protection integrated from the start, compliant with GDPR, CCPA.

**Principles**:

**Data Minimization**:
```php
// ❌ Bad: Collect everything
class User
{
    private string $fullName;
    private string $email;
    private string $phone;
    private string $address;
    private string $ssn;  // Why do we need this?
    private \DateTimeImmutable $birthDate;
}

// ✅ Good: Collect only what's needed
class User
{
    private string $email;  // Required for account
    private string $displayName;  // Required for UI
    // That's it. Nothing more unless justified.
}
```

**Purpose Limitation**:
```php
interface ConsentInterface
{
    public function hasConsentFor(Purpose $purpose): bool;
    public function grantConsent(Purpose $purpose): void;
    public function revokeConsent(Purpose $purpose): void;
}

// Usage
if (!$user->hasConsentFor(Purpose::MARKETING_EMAILS)) {
    // Don't send marketing emails
    return;
}
```

**Right to be Forgotten**:
```php
public function anonymizeUser(UserId $userId): void
{
    $user = $this->userRepository->findById($userId);

    // Anonymize personal data
    $user->setEmail('deleted-' . $userId->toString() . '@anonymized.local');
    $user->setName('Deleted User');

    // Keep audit trail with anonymized data
    $this->auditService->log(new UserAnonymized($userId));

    // Notify dependent services to anonymize their data
    $this->eventPublisher->publish(new UserAnonymizationRequested($userId));
}
```

**Data Portability**:
```php
public function exportUserData(UserId $userId): array
{
    return [
        'user' => $this->userRepository->findById($userId)->toArray(),
        'workflows' => $this->workflowRepository->findByUserId($userId)->toArray(),
        'executions' => $this->executionRepository->findByUserId($userId)->toArray(),
        'files' => $this->fileRepository->findByUserId($userId)->toArray(),
        // All user data in machine-readable format
    ];
}
```

## OWASP Top 10 Mitigation

### A01: Broken Access Control

**Mitigations**:
- ✅ Deny by default: `#[IsGranted]` on every endpoint
- ✅ Enforce access control at service layer, not just UI
- ✅ Log access control failures
- ✅ Use Symfony Security Voters for complex authorization

### A02: Cryptographic Failures

**Mitigations**:
- ✅ TLS 1.3 for all external communication
- ✅ mTLS for service-to-service communication
- ✅ AES-256 encryption at rest
- ✅ Secrets stored in Vault, never in code/env files
- ✅ Strong password hashing (bcrypt cost 15+)

### A03: Injection

**Mitigations**:
- ✅ Parameterized queries (Doctrine QueryBuilder, DQL)
- ✅ Input validation (Symfony Validator)
- ✅ Output encoding (Twig auto-escaping)
- ✅ Prepared statements always
- ✅ ORM usage (no raw SQL unless necessary)

```php
// ✅ Good: Parameterized query
$workflows = $this->entityManager
    ->createQuery('SELECT w FROM App\Domain\Entity\Workflow w WHERE w.name = :name')
    ->setParameter('name', $userInput)
    ->getResult();

// ❌ Bad: String concatenation (SQL injection!)
$sql = "SELECT * FROM workflows WHERE name = '" . $userInput . "'";
```

### A04: Insecure Design

**Mitigations**:
- ✅ Threat modeling during design
- ✅ Security architecture review
- ✅ Secure design patterns (hexagonal, DDD)
- ✅ Rate limiting, circuit breakers
- ✅ Input validation at boundaries

### A05: Security Misconfiguration

**Mitigations**:
- ✅ Infrastructure as Code (no manual config)
- ✅ Automated security scanning (Trivy, Grype)
- ✅ Principle of least privilege
- ✅ Disable debug mode in production
- ✅ Remove default accounts/passwords
- ✅ Security headers on all responses

### A06: Vulnerable and Outdated Components

**Mitigations**:
- ✅ Automated dependency scanning (Dependabot, Renovate)
- ✅ Software Composition Analysis (SCA) in CI/CD
- ✅ Regular updates (monthly security patches)
- ✅ Dependency pinning (`composer.lock`)
- ✅ Remove unused dependencies

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "composer"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
    labels:
      - "dependencies"
      - "security"
```

### A07: Identification and Authentication Failures

**Mitigations**:
- ✅ Multi-factor authentication (Keycloak)
- ✅ Strong password policy (min 12 chars, complexity)
- ✅ Rate limiting on login attempts
- ✅ Account lockout after failed attempts
- ✅ Secure session management (HttpOnly, Secure, SameSite cookies)
- ✅ JWT with short expiration (15 min access, 7 day refresh)

### A08: Software and Data Integrity Failures

**Mitigations**:
- ✅ Code signing (Git commit signing)
- ✅ Artifact signing (Docker image signing with Cosign)
- ✅ Dependency integrity (lock files, checksums)
- ✅ CI/CD pipeline security (signed commits, audit logs)
- ✅ Immutable audit logs (checksums, signatures)

### A09: Security Logging and Monitoring Failures

**Mitigations**:
- ✅ Comprehensive audit logging (see Audit Service)
- ✅ Centralized log aggregation (Loki)
- ✅ Real-time alerting (Prometheus Alertmanager)
- ✅ Anomaly detection
- ✅ Incident response procedures
- ✅ Log integrity (immutable, checksummed)

### A10: Server-Side Request Forgery (SSRF)

**Mitigations**:
- ✅ Whitelist allowed external hosts
- ✅ Validate and sanitize URLs
- ✅ Network segmentation (no direct internet access from app pods)
- ✅ Use service mesh for external calls
- ✅ Disable URL redirects or validate redirect targets

```php
// ✅ Good: Whitelist allowed hosts
class LLMProviderClient
{
    private const ALLOWED_HOSTS = [
        'api.openai.com',
        'api.anthropic.com',
        'api.cohere.ai',
    ];

    public function request(string $url): Response
    {
        $host = parse_url($url, PHP_URL_HOST);

        if (!in_array($host, self::ALLOWED_HOSTS, true)) {
            throw new ForbiddenHostException("Host $host is not allowed");
        }

        return $this->httpClient->request('POST', $url, [/* ... */]);
    }
}
```

## Security Testing

### 1. Static Application Security Testing (SAST)

**Tools**:
- **PHPStan**: Static analysis, detect type errors
- **Psalm**: Static analysis, taint analysis
- **PHP-CS-Fixer**: Code style, security patterns

```bash
# Run in CI/CD
vendor/bin/phpstan analyse src --level=9
vendor/bin/psalm --show-info=true
vendor/bin/php-cs-fixer fix --dry-run --diff
```

### 2. Dynamic Application Security Testing (DAST)

**Tools**:
- **OWASP ZAP**: Automated vulnerability scanning
- **Burp Suite**: Manual penetration testing

```yaml
# .github/workflows/dast.yml
- name: OWASP ZAP Scan
  uses: zaproxy/action-full-scan@v0.4.0
  with:
    target: 'https://staging.example.com'
```

### 3. Software Composition Analysis (SCA)

**Tools**:
- **Composer Audit**: Check for known vulnerabilities
- **Trivy**: Container and dependency scanning
- **Grype**: Vulnerability scanner

```bash
composer audit
trivy image your-image:latest
grype your-image:latest
```

### 4. Interactive Application Security Testing (IAST)

**Tools**:
- **Contrast Security**: Runtime instrumentation
- **Sqreen**: Runtime protection

### 5. Penetration Testing

- **Frequency**: Quarterly for production
- **Scope**: External attack surface + internal services
- **Report**: Detailed findings with severity + remediation

## Compliance Requirements

### GDPR (General Data Protection Regulation)

**Requirements**:
- ✅ Data protection by design and by default
- ✅ Right to access (data export)
- ✅ Right to be forgotten (anonymization)
- ✅ Data portability
- ✅ Consent management
- ✅ Data breach notification (72 hours)
- ✅ Data Processing Agreements (DPAs)

**Implementation**: See [06-data-protection.md](06-data-protection.md)

### SOC 2 (Service Organization Control 2)

**Trust Service Criteria**:
- ✅ **Security**: Protection against unauthorized access
- ✅ **Availability**: System available for operation and use
- ✅ **Processing Integrity**: System processing is complete, valid, accurate, timely, authorized
- ✅ **Confidentiality**: Information designated as confidential is protected
- ✅ **Privacy**: Personal information is collected, used, retained, disclosed, and disposed of properly

**Implementation**:
- Access controls (IAM, RBAC)
- Encryption (TLS, AES-256)
- Audit logging (all access, changes)
- Monitoring and alerting
- Incident response procedures
- Backup and disaster recovery

### ISO 27001 (Information Security Management)

**Key Controls**:
- ✅ Information security policies
- ✅ Organization of information security
- ✅ Human resource security
- ✅ Asset management
- ✅ Access control
- ✅ Cryptography
- ✅ Physical and environmental security
- ✅ Operations security
- ✅ Communications security
- ✅ System acquisition, development, maintenance
- ✅ Supplier relationships
- ✅ Information security incident management
- ✅ Business continuity management
- ✅ Compliance

### NIS2 (Network and Information Security Directive 2)

**Requirements**:
- ✅ Risk management measures
- ✅ Incident handling
- ✅ Business continuity
- ✅ Supply chain security
- ✅ Security in network and information systems acquisition
- ✅ Policies and procedures to assess effectiveness
- ✅ Cybersecurity training
- ✅ Encryption and cryptography

## Security Incident Response

### Incident Classification

| Severity | Description | Response Time | Example |
|----------|-------------|---------------|---------|
| **SEV1 - Critical** | Data breach, complete service outage | Immediate (< 15 min) | Database exposed publicly |
| **SEV2 - High** | Partial outage, security vulnerability exploited | < 1 hour | SQL injection exploited |
| **SEV3 - Medium** | Degraded service, potential security issue | < 4 hours | Rate limiting bypass |
| **SEV4 - Low** | Minor issue, no security impact | < 24 hours | Informational log entry |

### Response Process

1. **Detection**: Automated alerts + manual reports
2. **Triage**: Classify severity, assign responder
3. **Containment**: Isolate affected systems
4. **Eradication**: Remove threat, patch vulnerability
5. **Recovery**: Restore services, validate security
6. **Post-Mortem**: Document incident, improve controls

**See**: [../07-operations/03-incident-response.md](../07-operations/03-incident-response.md)

## Conclusion

These security principles form the foundation of a secure, compliant platform:

- ✅ **Security by Design**: Built-in, not bolted on
- ✅ **Defense in Depth**: Multiple security layers
- ✅ **Zero Trust**: Never trust, always verify
- ✅ **Least Privilege**: Minimal permissions
- ✅ **Audit Everything**: Complete traceability
- ✅ **Privacy by Design**: GDPR compliant from start
- ✅ **Secure by Default**: Safe out of the box
- ✅ **Continuous Monitoring**: Detect and respond quickly

Security is not a one-time effort but a continuous process of improvement and vigilance.
