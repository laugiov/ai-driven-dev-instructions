# Zero Trust Architecture

## Overview

This document details the implementation of Zero Trust principles across the platform. Zero Trust operates on the principle **"Never trust, always verify"** - no implicit trust is granted based on network location.

## Core Principles

### 1. Verify Explicitly

**Principle**: Always authenticate and authorize based on all available data points.

**Implementation**:
```
Every request requires:
├── Authentication (Who are you?)
│   ├── User: JWT token from Keycloak
│   ├── Service: mTLS certificate
│   └── External: API key
├── Authorization (What can you do?)
│   ├── RBAC: Role-based permissions
│   ├── ABAC: Attribute-based conditions
│   └── Resource ownership checks
└── Context (Under what conditions?)
    ├── Time of day
    ├── Source IP/location
    ├── Device posture
    └── Risk score
```

### 2. Use Least Privilege Access

**Principle**: Limit user/service access with Just-In-Time and Just-Enough-Access (JIT/JEA).

**Implementation**:
- Minimal permissions by default
- Time-limited elevated access
- Regular access reviews
- Automatic revocation of unused permissions

### 3. Assume Breach

**Principle**: Minimize blast radius and segment access.

**Implementation**:
- Micro-segmentation via network policies
- Encrypt all data (in transit and at rest)
- Continuous monitoring and anomaly detection
- Automated incident response

## Network Segmentation

### Kubernetes Network Policies

**Principle**: Pod-to-pod communication is explicitly allowed, denied by default.

**Default Deny Policy**:
```yaml
# Deny all traffic by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

**Allow Specific Traffic**:
```yaml
# Allow Workflow Service → LLM Agent Service
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: workflow-to-llm-agent
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: llm-agent-service
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: workflow-service
    ports:
    - protocol: TCP
      port: 8080
```

**Database Access Restriction**:
```yaml
# Only LLM Agent Service can access its database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: llm-agent-db-access
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: postgresql-llm-agent
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: llm-agent-service
    ports:
    - protocol: TCP
      port: 5432
```

### Istio Authorization Policies

**Service-to-Service Authorization**:

```yaml
# Only Workflow Service can call LLM Agent Service
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: llm-agent-authz
  namespace: production
spec:
  selector:
    matchLabels:
      app: llm-agent-service
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster.local/ns/production/sa/workflow-service"
    to:
    - operation:
        methods: ["POST"]
        paths: ["/api/v1/agents/*/execute"]
```

**Deny by Default**:
```yaml
# Explicit deny all policy
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  {}  # Empty spec = deny all
```

## Mutual TLS (mTLS)

### Istio mTLS Configuration

**Strict mTLS Mode** (all traffic must be mTLS):

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT
```

**How mTLS Works**:

```
1. Service A initiates connection to Service B
   ├── Service A's sidecar (Envoy) intercepts request
   └── Establishes TLS connection with Service B's sidecar

2. Mutual Authentication
   ├── Service A presents certificate (signed by Istio CA)
   ├── Service B validates A's certificate
   ├── Service B presents certificate
   └── Service A validates B's certificate

3. Encrypted Communication
   └── All traffic encrypted with TLS 1.3
```

**Certificate Management**:
- Certificates issued by Istio Citadel
- Automatic rotation every 24 hours
- Stored in Kubernetes secrets
- Never expires past 90 days

**Verification**:
```bash
# Check mTLS status
istioctl x describe pod workflow-service-xyz -n production

# Expected output:
# mTLS: STRICT
# Certificate expiry: 2025-01-08T10:30:00Z
```

## Identity and Access Management

### User Authentication

**OAuth2/OIDC Flow** (via Keycloak):

```
1. User → API Gateway
   ├── No token: Redirect to Keycloak login
   └── Has token: Validate with Keycloak

2. Keycloak Login
   ├── Username + Password
   ├── MFA (if enabled)
   └── Issue JWT tokens:
       ├── Access Token (15 min)
       └── Refresh Token (7 days)

3. API Gateway → Backend Services
   ├── Forward validated JWT
   └── Services verify JWT signature
```

**JWT Token Structure**:
```json
{
  "sub": "user-uuid",
  "name": "John Doe",
  "email": "john@example.com",
  "roles": ["workflow_creator", "workflow_executor"],
  "permissions": ["workflow:create", "workflow:execute"],
  "iss": "https://keycloak.example.com",
  "aud": "ai-workflow-platform",
  "exp": 1704632400,
  "iat": 1704631500,
  "nbf": 1704631500
}
```

**Token Validation** (in services):
```php
// src/Infrastructure/Security/JwtAuthenticator.php
final readonly class JwtAuthenticator
{
    public function authenticate(string $token): User
    {
        // 1. Verify signature (RS256 with public key from Keycloak)
        $decoded = JWT::decode($token, $this->publicKey, ['RS256']);

        // 2. Verify expiration
        if ($decoded->exp < time()) {
            throw new TokenExpiredException();
        }

        // 3. Verify audience
        if ($decoded->aud !== 'ai-workflow-platform') {
            throw new InvalidAudienceException();
        }

        // 4. Verify issuer
        if ($decoded->iss !== $this->keycloakUrl) {
            throw new InvalidIssuerException();
        }

        // 5. Extract user information
        return new User(
            id: $decoded->sub,
            email: $decoded->email,
            roles: $decoded->roles,
            permissions: $decoded->permissions,
        );
    }
}
```

### Service-to-Service Authentication

**Option 1: mTLS** (Recommended via Istio):
- Automatic certificate management
- No application code changes
- Strong cryptographic identity

**Option 2: Service JWT**:
```php
// Generate service token from Vault
$serviceToken = $this->vault->read('auth/kubernetes/login', [
    'role' => 'workflow-service',
    'jwt' => file_get_contents('/var/run/secrets/kubernetes.io/serviceaccount/token'),
]);

// Use token for service-to-service calls
$response = $this->httpClient->request('POST', $url, [
    'headers' => [
        'Authorization' => "Bearer {$serviceToken['auth']['client_token']}",
    ],
]);
```

### Multi-Factor Authentication (MFA)

**Keycloak MFA Configuration**:
```
Supported methods:
├── TOTP (Time-based One-Time Password)
│   └── Google Authenticator, Authy, etc.
├── SMS (via Twilio)
└── Email OTP
```

**Enforcement**:
```yaml
# Require MFA for admin users
authentication:
  requiredActions:
    - CONFIGURE_TOTP
  flows:
    - browser:
        - Username/Password
        - OTP (if configured)
```

## Authorization

### Role-Based Access Control (RBAC)

**Role Hierarchy**:
```
Roles:
├── User (default)
│   ├── Can create workflows
│   ├── Can execute own workflows
│   └── Can view own results
├── Power User
│   ├── Inherits User permissions
│   ├── Can execute any workflow
│   └── Can view validation details
├── Admin
│   ├── Inherits Power User permissions
│   ├── Can manage workflows
│   ├── Can manage users
│   └── Can view audit logs
└── Super Admin
    ├── Inherits Admin permissions
    ├── Can manage system configuration
    └── Can access all data
```

**Implementation**:
```php
// src/Infrastructure/Security/Voter/WorkflowVoter.php
final class WorkflowVoter extends Voter
{
    protected function supports(string $attribute, mixed $subject): bool
    {
        return in_array($attribute, ['WORKFLOW_VIEW', 'WORKFLOW_EDIT', 'WORKFLOW_DELETE'])
            && $subject instanceof Workflow;
    }

    protected function voteOnAttribute(string $attribute, mixed $subject, TokenInterface $token): bool
    {
        $user = $token->getUser();
        $workflow = $subject;

        return match($attribute) {
            'WORKFLOW_VIEW' => $this->canView($user, $workflow),
            'WORKFLOW_EDIT' => $this->canEdit($user, $workflow),
            'WORKFLOW_DELETE' => $this->canDelete($user, $workflow),
            default => false,
        };
    }

    private function canView(User $user, Workflow $workflow): bool
    {
        // Super Admin can view all
        if ($user->hasRole('SUPER_ADMIN')) {
            return true;
        }

        // Users can view own workflows
        if ($workflow->getOwnerId()->equals($user->getId())) {
            return true;
        }

        // Power Users can view all
        if ($user->hasRole('POWER_USER')) {
            return true;
        }

        return false;
    }

    private function canEdit(User $user, Workflow $workflow): bool
    {
        // Only owner or admin can edit
        return $workflow->getOwnerId()->equals($user->getId())
            || $user->hasRole('ADMIN');
    }

    private function canDelete(User $user, Workflow $workflow): bool
    {
        // Only owner or super admin can delete
        return $workflow->getOwnerId()->equals($user->getId())
            || $user->hasRole('SUPER_ADMIN');
    }
}
```

### Attribute-Based Access Control (ABAC)

**Policy Example** (using Open Policy Agent - OPA):

```rego
# policy.rego
package authz

default allow = false

# Allow if user owns the resource
allow {
    input.resource.owner_id == input.user.id
}

# Allow if user has admin role
allow {
    input.user.roles[_] == "admin"
}

# Allow workflow execution only during business hours
allow {
    input.action == "workflow:execute"
    input.user.roles[_] == "user"
    business_hours
}

business_hours {
    now := time.now_ns()
    day := time.weekday(now)
    day != "Saturday"
    day != "Sunday"
    hour := time.clock(now)[0]
    hour >= 8
    hour < 18
}
```

**Usage**:
```php
$decision = $this->opaClient->evaluate([
    'input' => [
        'user' => [
            'id' => $user->getId(),
            'roles' => $user->getRoles(),
        ],
        'resource' => [
            'type' => 'workflow',
            'id' => $workflowId,
            'owner_id' => $workflow->getOwnerId(),
        ],
        'action' => 'workflow:execute',
    ],
]);

if (!$decision['result']['allow']) {
    throw new AccessDeniedException();
}
```

## Data Protection

### Encryption in Transit

**External Traffic** (TLS 1.3):
```yaml
# API Gateway TLS configuration
apiVersion: v1
kind: Secret
metadata:
  name: api-gateway-tls
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-gateway
spec:
  tls:
  - hosts:
    - api.example.com
    secretName: api-gateway-tls
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-gateway
            port:
              number: 443
```

**Internal Traffic** (mTLS via Istio):
- Automatically enforced by Istio
- TLS 1.3 with strong ciphers
- Certificates rotated every 24 hours

### Encryption at Rest

**Database Encryption**:
```sql
-- PostgreSQL Transparent Data Encryption (TDE)
-- Via file system encryption (LUKS) or cloud provider (AWS RDS encryption)

-- Column-level encryption for highly sensitive data
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Encrypt Social Security Number
INSERT INTO users (ssn_encrypted)
VALUES (pgp_sym_encrypt('123-45-6789', current_setting('app.encryption_key')));

-- Decrypt when needed
SELECT pgp_sym_decrypt(ssn_encrypted, current_setting('app.encryption_key'))
FROM users;
```

**S3 Encryption**:
```yaml
# Server-side encryption (SSE-S3 or SSE-KMS)
s3:
  buckets:
    - name: workflow-files
      encryption:
        type: SSE-KMS
        kms_key_id: arn:aws:kms:us-east-1:123456789:key/abc-def
      versioning: enabled
      lifecycle:
        - id: archive-old-files
          status: Enabled
          transitions:
            - days: 90
              storage_class: GLACIER
```

### Secrets Management (Vault)

**Dynamic Database Credentials**:
```php
// Request temporary database credentials from Vault
$credentials = $this->vault->read('database/creds/workflow-db-role');

// Credentials valid for 1 hour, then auto-revoked
$dsn = sprintf(
    'postgresql://%s:%s@postgres:5432/workflow_db',
    $credentials['data']['username'],
    $credentials['data']['password']
);

// Vault automatically rotates root database password
```

**API Key Retrieval**:
```php
// Never store API keys in environment variables or code
$openaiKey = $this->vault->read('secret/data/openai')['data']['data']['api_key'];

// Vault audit logs all secret access
```

## Continuous Verification

### Real-Time Monitoring

**Anomaly Detection**:
```
Monitored behaviors:
├── Unusual login times (user logs in at 3 AM)
├── Unusual locations (login from new country)
├── High-volume requests (rate limit exceeded)
├── Failed authentication attempts (brute force)
├── Privilege escalation attempts
└── Data exfiltration patterns (large downloads)
```

**Automated Response**:
```yaml
# Falco rule: Detect unauthorized file access
- rule: Unauthorized File Access
  desc: Detect access to sensitive files by unauthorized processes
  condition: >
    open_read and
    sensitive_files and
    not authorized_processes
  output: >
    Unauthorized file access
    (user=%user.name file=%fd.name process=%proc.name)
  priority: WARNING
  action:
    - alert: security-team
    - block: process
```

### Session Monitoring

**Continuous Token Validation**:
```php
// Middleware: Check token on every request
public function __invoke(Request $request, callable $next): Response
{
    $token = $this->extractToken($request);

    // 1. Verify token signature and expiration
    $user = $this->jwtAuthenticator->authenticate($token);

    // 2. Check if token was revoked (Redis blacklist)
    if ($this->tokenBlacklist->isRevoked($token)) {
        throw new TokenRevokedException();
    }

    // 3. Check session validity (Keycloak)
    if (!$this->keycloak->isSessionValid($user->getId(), $token)) {
        throw new SessionExpiredException();
    }

    // 4. Update last activity
    $this->sessionManager->updateLastActivity($user->getId());

    return $next($request);
}
```

**Automatic Logout**:
```
Conditions for automatic logout:
├── Token expiration (15 minutes)
├── Inactivity timeout (30 minutes)
├── Concurrent session limit exceeded (max 3 sessions)
├── Suspicious activity detected
└── Admin-initiated revocation
```

## Incident Response

### Automated Breach Response

**Phase 1: Detection**
```yaml
# Alert triggers
alerts:
  - name: FailedAuthenticationSpike
    condition: rate(failed_authentications_total[5m]) > 100
    action: block_ip_temporarily

  - name: UnauthorizedAPIAccess
    condition: unauthorized_access_attempts > 10
    action: revoke_token

  - name: DataExfiltration
    condition: data_transfer_bytes > 1GB in 1 minute
    action: suspend_account
```

**Phase 2: Containment**
```php
// Automated containment actions
class BreachResponseService
{
    public function handleSuspiciousActivity(SecurityEvent $event): void
    {
        match($event->severity) {
            Severity::CRITICAL => $this->executeCriticalResponse($event),
            Severity::HIGH => $this->executeHighResponse($event),
            Severity::MEDIUM => $this->executeMediumResponse($event),
            default => $this->logEvent($event),
        };
    }

    private function executeCriticalResponse(SecurityEvent $event): void
    {
        // 1. Block user immediately
        $this->accessControl->blockUser($event->userId);

        // 2. Revoke all active sessions
        $this->sessionManager->revokeAllSessions($event->userId);

        // 3. Isolate affected service
        $this->networkPolicy->isolateService($event->serviceName);

        // 4. Alert security team
        $this->alerting->sendCriticalAlert($event);

        // 5. Create incident ticket
        $this->incidentManagement->createIncident($event);
    }
}
```

**Phase 3: Investigation**
```
Investigation process:
├── Collect audit logs from Audit Service
├── Analyze access patterns
├── Identify compromised accounts/services
├── Determine blast radius
└── Generate forensic report
```

**Phase 4: Recovery**
```
Recovery steps:
├── Rotate all secrets (Vault)
├── Reset compromised user passwords
├── Review and update access policies
├── Patch vulnerabilities
└── Restore from clean backups if needed
```

## Zero Trust Maturity Model

### Level 1: Initial (Current State)

✅ **Achieved**:
- mTLS between all services
- JWT authentication for users
- Network policies in place
- Secrets in Vault
- Audit logging enabled

### Level 2: Advanced (Next 6 months)

🚧 **In Progress**:
- Context-aware access policies (ABAC with OPA)
- Real-time anomaly detection
- Automated threat response
- User behavior analytics
- Risk-based authentication (adaptive MFA)

### Level 3: Optimal (Next 12 months)

📋 **Planned**:
- AI-powered threat detection
- Predictive security analytics
- Zero standing privileges (JIT access)
- Microsegmentation at container level
- Continuous compliance validation

## Compliance Alignment

### GDPR
- ✅ Data encryption (in transit and at rest)
- ✅ Access controls (who accessed what)
- ✅ Audit trail (immutable logs)
- ✅ Right to be forgotten (data anonymization)

### SOC 2
- ✅ Logical access controls
- ✅ Encryption
- ✅ Change management (GitOps)
- ✅ Monitoring and alerting

### ISO 27001
- ✅ Access control (A.9)
- ✅ Cryptography (A.10)
- ✅ Communications security (A.13)
- ✅ Information security incident management (A.16)

### NIS2
- ✅ Risk management measures
- ✅ Incident handling procedures
- ✅ Business continuity management
- ✅ Supply chain security

## Testing Zero Trust

### Penetration Testing Scenarios

```
Test 1: Lateral Movement Prevention
├── Compromise one service
├── Attempt to access other services
└── Expected: Blocked by mTLS and network policies

Test 2: Privilege Escalation
├── Login as regular user
├── Attempt admin operations
└── Expected: Blocked by RBAC/ABAC

Test 3: Token Theft
├── Steal JWT token
├── Use from different IP/location
└── Expected: Flagged as suspicious, MFA challenge

Test 4: Data Exfiltration
├── Download large amounts of data
├── Transfer to external system
└── Expected: Rate limited, flagged, blocked
```

## Conclusion

Zero Trust architecture ensures:

✅ **No Implicit Trust**: Every request verified
✅ **Least Privilege**: Minimal permissions by default
✅ **Micro-Segmentation**: Network policies limit blast radius
✅ **Continuous Verification**: Real-time monitoring and response
✅ **Encryption Everywhere**: TLS 1.3 external, mTLS internal
✅ **Audit Everything**: Complete traceability
✅ **Automated Response**: Rapid containment of threats

This architecture assumes breach and minimizes damage through defense in depth, making the platform resilient against both external attacks and insider threats.
