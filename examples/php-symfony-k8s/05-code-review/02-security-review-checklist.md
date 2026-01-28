# Security Review Checklist

## Table of Contents

1. [Introduction](#introduction)
2. [OWASP Top 10 Review](#owasp-top-10-review)
3. [Authentication and Authorization](#authentication-and-authorization)
4. [Input Validation](#input-validation)
5. [Output Encoding](#output-encoding)
6. [SQL Injection Prevention](#sql-injection-prevention)
7. [Cryptography](#cryptography)
8. [Secrets Management](#secrets-management)
9. [API Security](#api-security)
10. [Session Management](#session-management)
11. [File Operations](#file-operations)
12. [Dependencies and Supply Chain](#dependencies-and-supply-chain)
13. [Logging and Monitoring](#logging-and-monitoring)
14. [Infrastructure Security](#infrastructure-security)

## Introduction

This security review checklist ensures all code changes are reviewed for security vulnerabilities before merging. Security is everyone's responsibility, and this checklist helps reviewers systematically identify potential security issues.

### Security Review Principles

**Defense in Depth**: Security controls at multiple layers (application, infrastructure, network).

**Least Privilege**: Grant minimum necessary permissions and access.

**Fail Securely**: Systems should fail safely, not open.

**Assume Breach**: Design with the assumption that some controls will fail.

**Zero Trust**: Verify every request, never trust by default.

### Review Severity Levels

**Critical (P0)**: Immediate security risk requiring hotfix
- Remote code execution
- SQL injection allowing data exfiltration
- Authentication bypass
- Hardcoded credentials in production

**High (P1)**: Significant security risk requiring immediate fix
- XSS vulnerabilities
- Authorization bypass
- Sensitive data exposure
- Insecure cryptography

**Medium (P2)**: Moderate security risk requiring fix before release
- Missing rate limiting
- Insufficient logging
- Weak validation
- Security misconfiguration

**Low (P3)**: Minor security issue for future improvement
- Missing security headers
- Verbose error messages
- Minor information disclosure

## OWASP Top 10 Review

### A01:2021 - Broken Access Control

```php
<?php

// ✅ GOOD: Proper authorization check
#[Route('/api/v1/agents/{id}', methods: ['DELETE'])]
public function delete(string $id): JsonResponse
{
    $agent = $this->queryBus->query(new GetAgentQuery($id));

    if ($agent === null) {
        return $this->json(
            ['error' => 'Agent not found'],
            Response::HTTP_NOT_FOUND
        );
    }

    // Check ownership before allowing deletion
    if ($agent->getUserId() !== $this->getUser()->getId()) {
        $this->logger->warning('Unauthorized agent deletion attempt', [
            'agent_id' => $id,
            'user_id' => $this->getUser()->getId(),
            'owner_id' => $agent->getUserId(),
        ]);

        return $this->json(
            ['error' => 'Access denied'],
            Response::HTTP_FORBIDDEN
        );
    }

    $this->commandBus->dispatch(new DeleteAgentCommand($id));

    return $this->json(null, Response::HTTP_NO_CONTENT);
}

// ❌ BAD: No authorization check
#[Route('/api/v1/agents/{id}', methods: ['DELETE'])]
public function delete(string $id): JsonResponse
{
    // No check if user owns this agent!
    $this->commandBus->dispatch(new DeleteAgentCommand($id));

    return $this->json(null, Response::HTTP_NO_CONTENT);
}
```

**Review Checklist**:
- [ ] Authorization checked for all sensitive operations
- [ ] User can only access their own resources
- [ ] Admin-only endpoints require admin role
- [ ] Horizontal privilege escalation prevented (user A cannot access user B's data)
- [ ] Vertical privilege escalation prevented (regular user cannot perform admin actions)
- [ ] Direct object references are validated
- [ ] API endpoints enforce authentication
- [ ] CORS configured restrictively

### A02:2021 - Cryptographic Failures

```php
<?php

// ✅ GOOD: Secure password hashing
use Symfony\Component\PasswordHasher\Hasher\PasswordHasherFactoryInterface;

final class UserRegistrationService
{
    public function __construct(
        private readonly PasswordHasherFactoryInterface $hasherFactory,
    ) {}

    public function registerUser(string $email, string $password): User
    {
        $hasher = $this->hasherFactory->getPasswordHasher(User::class);

        // Use strong algorithm (Argon2id or bcrypt)
        $hashedPassword = $hasher->hash($password);

        $user = User::create($email, $hashedPassword);

        $this->repository->save($user);

        return $user;
    }
}

// ❌ BAD: Weak or no hashing
final class UserRegistrationService
{
    public function registerUser(string $email, string $password): User
    {
        // MD5 is cryptographically broken!
        $hashedPassword = md5($password);

        // OR even worse - storing plain text!
        $user = User::create($email, $password);

        $this->repository->save($user);

        return $user;
    }
}

// ✅ GOOD: Encryption of sensitive data
use App\Infrastructure\Encryption\FieldEncryption;

final class ApiKeyRepository
{
    public function __construct(
        private readonly Connection $connection,
        private readonly FieldEncryption $encryption,
    ) {}

    public function save(ApiKey $apiKey): void
    {
        // Encrypt API key before storing
        $encryptedValue = $this->encryption->encrypt($apiKey->getValue());

        $this->connection->insert('api_keys', [
            'id' => $apiKey->getId()->toString(),
            'user_id' => $apiKey->getUserId(),
            'encrypted_value' => $encryptedValue,
            'created_at' => $apiKey->getCreatedAt()->format('Y-m-d H:i:s'),
        ]);
    }

    public function findById(ApiKeyId $id): ?ApiKey
    {
        $data = $this->connection->fetchAssociative(
            'SELECT * FROM api_keys WHERE id = ?',
            [$id->toString()]
        );

        if (!$data) {
            return null;
        }

        // Decrypt when reading
        $decryptedValue = $this->encryption->decrypt($data['encrypted_value']);

        return ApiKey::fromDatabase([
            ...$data,
            'value' => $decryptedValue,
        ]);
    }
}

// ❌ BAD: Storing sensitive data in plain text
final class ApiKeyRepository
{
    public function save(ApiKey $apiKey): void
    {
        // API key stored in plain text!
        $this->connection->insert('api_keys', [
            'id' => $apiKey->getId()->toString(),
            'user_id' => $apiKey->getUserId(),
            'value' => $apiKey->getValue(),  // Plain text!
            'created_at' => $apiKey->getCreatedAt()->format('Y-m-d H:i:s'),
        ]);
    }
}
```

**Review Checklist**:
- [ ] Passwords hashed with strong algorithm (Argon2id or bcrypt)
- [ ] No hardcoded encryption keys
- [ ] Sensitive data encrypted at rest
- [ ] TLS/HTTPS used for all external communication
- [ ] No weak cryptographic algorithms (MD5, SHA1, DES)
- [ ] Random values generated with cryptographically secure PRNG
- [ ] Encryption keys rotated regularly
- [ ] No sensitive data in logs or error messages

### A03:2021 - Injection

```php
<?php

// ✅ GOOD: Parameterized queries prevent SQL injection
final class AgentRepository
{
    public function findByUserId(string $userId): array
    {
        // Using prepared statements with parameter binding
        return $this->connection->fetchAllAssociative(
            'SELECT * FROM agents WHERE user_id = ?',
            [$userId]  // Parameter binding
        );
    }

    public function search(string $userId, string $searchTerm): array
    {
        // Even for LIKE queries, use parameters
        return $this->connection->fetchAllAssociative(
            'SELECT * FROM agents
             WHERE user_id = ?
             AND (name ILIKE ? OR description ILIKE ?)',
            [
                $userId,
                "%{$searchTerm}%",
                "%{$searchTerm}%"
            ]
        );
    }
}

// ❌ BAD: SQL injection vulnerability
final class AgentRepository
{
    public function findByUserId(string $userId): array
    {
        // Direct string concatenation - SQL INJECTION!
        $sql = "SELECT * FROM agents WHERE user_id = '{$userId}'";

        return $this->connection->fetchAllAssociative($sql);
    }

    public function search(string $userId, string $searchTerm): array
    {
        // SQL injection via search term
        $sql = "SELECT * FROM agents
                WHERE user_id = '{$userId}'
                AND name LIKE '%{$searchTerm}%'";

        return $this->connection->fetchAllAssociative($sql);
    }
}

// ✅ GOOD: Command injection prevention
final class FileProcessor
{
    public function convertFile(string $inputPath, string $outputPath): void
    {
        // Validate input path
        if (!$this->isValidPath($inputPath)) {
            throw new \InvalidArgumentException('Invalid input path');
        }

        // Use library instead of shell command
        $converter = new ImageConverter();
        $converter->convert($inputPath, $outputPath);
    }

    private function isValidPath(string $path): bool
    {
        // Whitelist validation
        $allowedDir = '/var/www/uploads/';
        $realPath = realpath($path);

        return $realPath !== false
            && str_starts_with($realPath, $allowedDir)
            && !str_contains($path, '..');
    }
}

// ❌ BAD: Command injection vulnerability
final class FileProcessor
{
    public function convertFile(string $inputPath, string $outputPath): void
    {
        // Command injection - user controls input!
        // Input like: "file.jpg; rm -rf /"
        exec("convert {$inputPath} {$outputPath}");
    }
}
```

**Review Checklist**:
- [ ] SQL queries use prepared statements with parameter binding
- [ ] No string concatenation in SQL queries
- [ ] User input never passed directly to shell commands
- [ ] ORM used correctly (no raw SQL with user input)
- [ ] LDAP queries parameterized
- [ ] XML parsers configured to prevent XXE
- [ ] Template engines configured to prevent SSTI
- [ ] NoSQL queries sanitized

### A04:2021 - Insecure Design

```php
<?php

// ✅ GOOD: Secure password reset with token
final class PasswordResetService
{
    private const TOKEN_EXPIRY_HOURS = 1;
    private const MAX_ATTEMPTS_PER_HOUR = 3;

    public function requestPasswordReset(string $email): void
    {
        // Rate limiting
        if ($this->hasExceededResetAttempts($email)) {
            $this->logger->warning('Password reset rate limit exceeded', [
                'email' => $email,
            ]);

            // Don't reveal rate limiting to prevent enumeration
            return;
        }

        $user = $this->userRepository->findByEmail($email);

        // Don't reveal if email exists
        if ($user === null) {
            $this->logger->info('Password reset requested for non-existent email', [
                'email' => $email,
            ]);
            return;
        }

        // Generate cryptographically secure token
        $token = bin2hex(random_bytes(32));
        $expiresAt = new \DateTimeImmutable("+{$self::TOKEN_EXPIRY_HOURS} hours");

        $this->tokenRepository->save(new PasswordResetToken(
            token: $token,
            userId: $user->getId(),
            expiresAt: $expiresAt
        ));

        $this->mailer->sendPasswordResetEmail($user->getEmail(), $token);

        $this->recordResetAttempt($email);
    }

    public function resetPassword(string $token, string $newPassword): void
    {
        $resetToken = $this->tokenRepository->findByToken($token);

        if ($resetToken === null || $resetToken->isExpired()) {
            throw new InvalidPasswordResetTokenException();
        }

        // Invalidate token immediately
        $this->tokenRepository->delete($resetToken);

        // Update password
        $user = $this->userRepository->findById($resetToken->getUserId());
        $user->changePassword($this->hasher->hash($newPassword));

        $this->userRepository->save($user);

        // Invalidate all sessions
        $this->sessionRepository->deleteAllForUser($user->getId());

        // Send notification
        $this->mailer->sendPasswordChangedNotification($user->getEmail());
    }

    private function hasExceededResetAttempts(string $email): bool
    {
        $attempts = $this->cache->get("password_reset_attempts:{$email}") ?? 0;

        return $attempts >= self::MAX_ATTEMPTS_PER_HOUR;
    }

    private function recordResetAttempt(string $email): void
    {
        $key = "password_reset_attempts:{$email}";
        $attempts = $this->cache->get($key) ?? 0;
        $this->cache->set($key, $attempts + 1, 3600);
    }
}

// ❌ BAD: Insecure password reset
final class PasswordResetService
{
    public function requestPasswordReset(string $email): void
    {
        $user = $this->userRepository->findByEmail($email);

        // Reveals if email exists!
        if ($user === null) {
            throw new \Exception('Email not found');
        }

        // Predictable token!
        $token = md5($email . time());

        // No expiry!
        $this->tokenRepository->save(new PasswordResetToken(
            token: $token,
            userId: $user->getId()
        ));

        $this->mailer->sendPasswordResetEmail($email, $token);
    }

    public function resetPassword(string $token, string $newPassword): void
    {
        $resetToken = $this->tokenRepository->findByToken($token);

        if ($resetToken === null) {
            throw new \Exception('Invalid token');
        }

        // Token not invalidated - can be reused!
        $user = $this->userRepository->findById($resetToken->getUserId());
        $user->changePassword($this->hasher->hash($newPassword));

        $this->userRepository->save($user);

        // No session invalidation
        // No notification
    }
}
```

**Review Checklist**:
- [ ] Rate limiting implemented on sensitive endpoints
- [ ] No user enumeration vulnerabilities
- [ ] Tokens are cryptographically secure and unpredictable
- [ ] Tokens have expiration
- [ ] One-time tokens are invalidated after use
- [ ] Password reset doesn't reveal if email exists
- [ ] Multi-factor authentication for sensitive operations
- [ ] Account lockout after failed attempts
- [ ] Secure session management

### A05:2021 - Security Misconfiguration

```yaml
# ✅ GOOD: Secure configuration
# config/packages/prod/framework.yaml
framework:
    # Disable debug mode in production
    secret: '%env(APP_SECRET)%'

    http_client:
        default_options:
            verify_peer: true
            verify_host: true
            timeout: 30

    session:
        cookie_secure: true
        cookie_httponly: true
        cookie_samesite: 'strict'

    php_errors:
        log: true

# ✅ GOOD: Security headers
# config/packages/nelmio_security.yaml
nelmio_security:
    clickjacking:
        paths:
            '^/.*': DENY

    content_type:
        nosniff: true

    xss_protection:
        enabled: true
        mode_block: true

    referrer_policy:
        enabled: true
        policies:
            - 'no-referrer-when-downgrade'
            - 'strict-origin-when-cross-origin'

    csp:
        enabled: true
        report_endpoint: '/csp-report'
        compat_headers: false
        hosts: []
        report_logger_service: logger
        hash:
            algorithm: sha256
        directives:
            default-src: ['self']
            script-src: ['self']
            style-src: ['self']
            img-src: ['self', 'data:']
            font-src: ['self']
            connect-src: ['self']
            frame-ancestors: ['none']

# ❌ BAD: Insecure configuration
# config/packages/prod/framework.yaml
framework:
    # Debug mode enabled in production!
    debug: true

    http_client:
        default_options:
            # SSL verification disabled!
            verify_peer: false
            verify_host: false

    session:
        # Insecure session cookies
        cookie_secure: false
        cookie_httponly: false
```

**Review Checklist**:
- [ ] Debug mode disabled in production
- [ ] Error messages don't reveal stack traces
- [ ] Default passwords changed
- [ ] Unnecessary features disabled
- [ ] Security headers configured (CSP, HSTS, X-Frame-Options)
- [ ] CORS configured restrictively
- [ ] SSL/TLS certificate validation enabled
- [ ] Secure cookie flags set (Secure, HttpOnly, SameSite)
- [ ] Directory listing disabled
- [ ] Unused dependencies removed

### A06:2021 - Vulnerable and Outdated Components

```bash
# ✅ GOOD: Regular dependency updates
composer audit
composer outdated

# Update dependencies
composer update

# Check for security advisories
symfony security:check

# ❌ BAD: Outdated dependencies
# composer.json with old versions
{
    "require": {
        "symfony/framework-bundle": "^5.4",  # EOL version
        "guzzlehttp/guzzle": "^6.0"  # Has known vulnerabilities
    }
}
```

**Review Checklist**:
- [ ] Dependencies up to date
- [ ] No known vulnerabilities (`composer audit`)
- [ ] Transitive dependencies checked
- [ ] Security advisories monitored
- [ ] Dependencies from trusted sources
- [ ] Dependency licenses reviewed
- [ ] Automated dependency updates configured (Dependabot)
- [ ] No vendored dependencies with modifications

### A07:2021 - Identification and Authentication Failures

```php
<?php

// ✅ GOOD: Secure authentication
final class AuthenticationService
{
    private const MAX_LOGIN_ATTEMPTS = 5;
    private const LOCKOUT_DURATION_MINUTES = 30;

    public function authenticate(string $email, string $password): ?string
    {
        // Check if account is locked
        if ($this->isAccountLocked($email)) {
            $this->logger->warning('Login attempt on locked account', [
                'email' => $email,
            ]);

            throw new AccountLockedException(
                'Account is temporarily locked due to too many failed attempts'
            );
        }

        $user = $this->userRepository->findByEmail($email);

        if ($user === null) {
            // Record failed attempt even for non-existent users
            $this->recordFailedAttempt($email);

            // Use constant-time comparison to prevent timing attacks
            $this->hasher->verify('dummy_hash', $password);

            throw new InvalidCredentialsException('Invalid credentials');
        }

        // Verify password
        if (!$this->hasher->verify($user->getPasswordHash(), $password)) {
            $this->recordFailedAttempt($email);

            throw new InvalidCredentialsException('Invalid credentials');
        }

        // Check if MFA is required
        if ($user->hasMfaEnabled()) {
            // Return temporary session requiring MFA verification
            return $this->createMfaPendingSession($user);
        }

        // Reset failed attempts
        $this->resetFailedAttempts($email);

        // Create session
        return $this->createSession($user);
    }

    public function verifyMfa(string $sessionToken, string $mfaCode): string
    {
        $session = $this->sessionRepository->findByToken($sessionToken);

        if ($session === null || !$session->isMfaPending()) {
            throw new InvalidSessionException();
        }

        $user = $this->userRepository->findById($session->getUserId());

        if (!$this->mfaService->verifyCode($user, $mfaCode)) {
            $this->recordFailedMfaAttempt($user);

            throw new InvalidMfaCodeException('Invalid MFA code');
        }

        // Upgrade session to authenticated
        $session->completeAuthentication();
        $this->sessionRepository->save($session);

        return $session->getToken();
    }

    private function isAccountLocked(string $email): bool
    {
        $attempts = $this->getFailedAttempts($email);

        return $attempts >= self::MAX_LOGIN_ATTEMPTS;
    }

    private function getFailedAttempts(string $email): int
    {
        $key = "login_attempts:{$email}";

        return $this->cache->get($key) ?? 0;
    }

    private function recordFailedAttempt(string $email): void
    {
        $key = "login_attempts:{$email}";
        $attempts = $this->getFailedAttempts($email) + 1;

        $this->cache->set(
            $key,
            $attempts,
            self::LOCKOUT_DURATION_MINUTES * 60
        );

        $this->logger->warning('Failed login attempt', [
            'email' => $email,
            'attempts' => $attempts,
        ]);
    }

    private function resetFailedAttempts(string $email): void
    {
        $this->cache->delete("login_attempts:{$email}");
    }
}

// ❌ BAD: Insecure authentication
final class AuthenticationService
{
    public function authenticate(string $email, string $password): ?string
    {
        $user = $this->userRepository->findByEmail($email);

        // Reveals if user exists via different error messages
        if ($user === null) {
            throw new \Exception('User not found');
        }

        // Timing attack vulnerability - direct comparison
        if ($user->getPassword() !== md5($password)) {
            throw new \Exception('Invalid password');
        }

        // No rate limiting
        // No MFA
        // No session management

        return $user->getId();
    }
}
```

**Review Checklist**:
- [ ] Account lockout after failed attempts
- [ ] Multi-factor authentication available
- [ ] Password complexity requirements enforced
- [ ] Session tokens are cryptographically secure
- [ ] Session timeout implemented
- [ ] No credentials in URLs
- [ ] Password reset process secure
- [ ] Timing attack prevention
- [ ] No default credentials

### A08:2021 - Software and Data Integrity Failures

```php
<?php

// ✅ GOOD: Webhook signature verification
final class WebhookController
{
    #[Route('/webhooks/llm-provider', methods: ['POST'])]
    public function handleWebhook(Request $request): JsonResponse
    {
        // Verify webhook signature
        $signature = $request->headers->get('X-Webhook-Signature');
        $payload = $request->getContent();

        if (!$this->verifySignature($payload, $signature)) {
            $this->logger->warning('Invalid webhook signature', [
                'ip' => $request->getClientIp(),
            ]);

            return $this->json(
                ['error' => 'Invalid signature'],
                Response::HTTP_UNAUTHORIZED
            );
        }

        // Process webhook
        $data = json_decode($payload, true);
        $this->commandBus->dispatch(new ProcessWebhookCommand($data));

        return $this->json(['status' => 'ok']);
    }

    private function verifySignature(string $payload, ?string $signature): bool
    {
        if ($signature === null) {
            return false;
        }

        $expected = hash_hmac(
            'sha256',
            $payload,
            $this->webhookSecret
        );

        return hash_equals($expected, $signature);
    }
}

// ✅ GOOD: Secure deserialization
final class QueueMessageHandler
{
    public function handleMessage(string $message): void
    {
        // Use JSON instead of serialize/unserialize
        $data = json_decode($message, true);

        if ($data === null) {
            throw new \InvalidArgumentException('Invalid message format');
        }

        // Validate message structure
        if (!isset($data['type'], $data['payload'])) {
            throw new \InvalidArgumentException('Missing required fields');
        }

        // Whitelist allowed message types
        $allowedTypes = ['agent.created', 'workflow.completed'];

        if (!in_array($data['type'], $allowedTypes, true)) {
            throw new \InvalidArgumentException('Invalid message type');
        }

        // Process message
        $this->processMessageByType($data['type'], $data['payload']);
    }
}

// ❌ BAD: Insecure deserialization
final class QueueMessageHandler
{
    public function handleMessage(string $message): void
    {
        // unserialize() can lead to code execution!
        $data = unserialize($message);

        // No validation
        $this->processMessage($data);
    }
}
```

**Review Checklist**:
- [ ] Digital signatures verified for updates
- [ ] Dependencies downloaded from trusted sources
- [ ] CI/CD pipeline secured
- [ ] No deserialization of untrusted data
- [ ] Webhook signatures verified
- [ ] Integrity checks for uploads
- [ ] Code signing implemented
- [ ] Software updates verified

### A09:2021 - Security Logging and Monitoring Failures

```php
<?php

// ✅ GOOD: Comprehensive security logging
final class SecurityEventLogger
{
    public function __construct(
        private readonly LoggerInterface $logger,
        private readonly MetricsCollector $metrics,
    ) {}

    public function logLoginSuccess(User $user, Request $request): void
    {
        $this->logger->info('Successful login', [
            'event' => 'authentication.login.success',
            'user_id' => $user->getId(),
            'email' => $user->getEmail(),
            'ip_address' => $request->getClientIp(),
            'user_agent' => $request->headers->get('User-Agent'),
            'timestamp' => time(),
        ]);

        $this->metrics->incrementCounter('auth_success');
    }

    public function logLoginFailure(string $email, Request $request, string $reason): void
    {
        $this->logger->warning('Failed login attempt', [
            'event' => 'authentication.login.failure',
            'email' => $email,
            'reason' => $reason,
            'ip_address' => $request->getClientIp(),
            'user_agent' => $request->headers->get('User-Agent'),
            'timestamp' => time(),
        ]);

        $this->metrics->incrementCounter('auth_failure');
    }

    public function logAuthorizationFailure(
        User $user,
        string $resource,
        string $action,
        Request $request
    ): void {
        $this->logger->warning('Authorization denied', [
            'event' => 'authorization.denied',
            'user_id' => $user->getId(),
            'resource' => $resource,
            'action' => $action,
            'ip_address' => $request->getClientIp(),
            'timestamp' => time(),
        ]);

        $this->metrics->incrementCounter('authz_denied', [
            'resource' => $resource,
            'action' => $action,
        ]);
    }

    public function logDataAccess(User $user, string $resource, string $resourceId): void
    {
        $this->logger->info('Data access', [
            'event' => 'data.access',
            'user_id' => $user->getId(),
            'resource' => $resource,
            'resource_id' => $resourceId,
            'timestamp' => time(),
        ]);
    }

    public function logSecurityEvent(string $eventType, array $context): void
    {
        $this->logger->warning('Security event', [
            'event' => "security.{$eventType}",
            ...$context,
            'timestamp' => time(),
        ]);

        $this->metrics->incrementCounter('security_events', [
            'type' => $eventType,
        ]);
    }
}

// ❌ BAD: Insufficient logging
final class AuthenticationService
{
    public function authenticate(string $email, string $password): ?string
    {
        $user = $this->userRepository->findByEmail($email);

        if ($user === null || !$this->hasher->verify($user->getPassword(), $password)) {
            // No logging of failed attempts
            throw new InvalidCredentialsException();
        }

        // No logging of successful login
        return $this->createSession($user);
    }
}
```

**Review Checklist**:
- [ ] Authentication events logged (success and failure)
- [ ] Authorization failures logged
- [ ] Input validation failures logged
- [ ] Security exceptions logged
- [ ] Logs include timestamp, user ID, IP address
- [ ] Logs don't contain sensitive data (passwords, tokens)
- [ ] Log tampering prevented
- [ ] Alerting configured for suspicious patterns
- [ ] Logs centralized and monitored
- [ ] Log retention policy implemented

### A10:2021 - Server-Side Request Forgery (SSRF)

```php
<?php

// ✅ GOOD: SSRF prevention
final class WebhookService
{
    private const ALLOWED_PROTOCOLS = ['https'];
    private const BLOCKED_HOSTS = [
        'localhost',
        '127.0.0.1',
        '0.0.0.0',
        '169.254.169.254',  // AWS metadata service
        '::1',
    ];

    private const BLOCKED_IP_RANGES = [
        '10.0.0.0/8',      // Private network
        '172.16.0.0/12',   // Private network
        '192.168.0.0/16',  // Private network
        '127.0.0.0/8',     // Loopback
        '169.254.0.0/16',  // Link-local
    ];

    public function __construct(
        private readonly HttpClientInterface $client,
        private readonly LoggerInterface $logger,
    ) {}

    public function sendWebhook(string $url, array $payload): void
    {
        // Validate URL
        if (!$this->isValidWebhookUrl($url)) {
            throw new InvalidWebhookUrlException(
                'Invalid or disallowed webhook URL'
            );
        }

        try {
            $this->client->request('POST', $url, [
                'json' => $payload,
                'timeout' => 5,
                'max_duration' => 10,
                // Follow redirects with caution
                'max_redirects' => 2,
            ]);

        } catch (\Throwable $e) {
            $this->logger->error('Webhook delivery failed', [
                'url' => $url,
                'exception' => $e->getMessage(),
            ]);

            throw new WebhookDeliveryException('Webhook delivery failed', 0, $e);
        }
    }

    private function isValidWebhookUrl(string $url): bool
    {
        $parsed = parse_url($url);

        if ($parsed === false) {
            return false;
        }

        // Check protocol
        $scheme = $parsed['scheme'] ?? '';
        if (!in_array($scheme, self::ALLOWED_PROTOCOLS, true)) {
            return false;
        }

        // Check host
        $host = $parsed['host'] ?? '';
        if (in_array(strtolower($host), self::BLOCKED_HOSTS, true)) {
            return false;
        }

        // Resolve to IP and check ranges
        $ip = gethostbyname($host);

        if ($ip === $host) {
            // Could not resolve
            return false;
        }

        return !$this->isBlockedIp($ip);
    }

    private function isBlockedIp(string $ip): bool
    {
        foreach (self::BLOCKED_IP_RANGES as $range) {
            if ($this->ipInRange($ip, $range)) {
                return true;
            }
        }

        return false;
    }

    private function ipInRange(string $ip, string $range): bool
    {
        [$subnet, $mask] = explode('/', $range);

        $ipLong = ip2long($ip);
        $subnetLong = ip2long($subnet);
        $maskLong = -1 << (32 - (int)$mask);

        return ($ipLong & $maskLong) === ($subnetLong & $maskLong);
    }
}

// ❌ BAD: SSRF vulnerability
final class WebhookService
{
    public function sendWebhook(string $url, array $payload): void
    {
        // No URL validation - SSRF vulnerability!
        // Attacker can provide: http://localhost:6379/
        // Or: http://169.254.169.254/latest/meta-data/
        $this->client->request('POST', $url, [
            'json' => $payload,
        ]);
    }
}
```

**Review Checklist**:
- [ ] URL validation for external requests
- [ ] Private IP ranges blocked
- [ ] Cloud metadata endpoints blocked
- [ ] URL protocol whitelist enforced
- [ ] DNS rebinding prevention
- [ ] Network segmentation in place
- [ ] Timeouts configured
- [ ] Redirect limits enforced

## Authentication and Authorization

```php
<?php

// ✅ GOOD: Granular permissions
final class AgentController
{
    #[Route('/api/v1/agents/{id}', methods: ['DELETE'])]
    #[IsGranted('AGENT_DELETE', 'agent')]
    public function delete(string $id): JsonResponse
    {
        $agent = $this->queryBus->query(new GetAgentQuery($id));

        if ($agent === null) {
            throw $this->createNotFoundException();
        }

        // Additional ownership check
        $this->denyAccessUnlessGranted('delete', $agent);

        $this->commandBus->dispatch(new DeleteAgentCommand($id));

        return $this->json(null, Response::HTTP_NO_CONTENT);
    }
}

// Security voter for fine-grained control
final class AgentVoter extends Voter
{
    public const VIEW = 'view';
    public const EDIT = 'edit';
    public const DELETE = 'delete';

    protected function supports(string $attribute, mixed $subject): bool
    {
        return in_array($attribute, [self::VIEW, self::EDIT, self::DELETE], true)
            && $subject instanceof Agent;
    }

    protected function voteOnAttribute(
        string $attribute,
        mixed $subject,
        TokenInterface $token
    ): bool {
        $user = $token->getUser();

        if (!$user instanceof User) {
            return false;
        }

        /** @var Agent $agent */
        $agent = $subject;

        return match ($attribute) {
            self::VIEW => $this->canView($agent, $user),
            self::EDIT => $this->canEdit($agent, $user),
            self::DELETE => $this->canDelete($agent, $user),
            default => false,
        };
    }

    private function canView(Agent $agent, User $user): bool
    {
        // Users can view their own agents
        // Admins can view all agents
        return $agent->getUserId() === $user->getId()
            || in_array('ROLE_ADMIN', $user->getRoles(), true);
    }

    private function canEdit(Agent $agent, User $user): bool
    {
        // Only owners can edit
        return $agent->getUserId() === $user->getId();
    }

    private function canDelete(Agent $agent, User $user): bool
    {
        // Only owners can delete
        return $agent->getUserId() === $user->getId();
    }
}
```

**Review Checklist**:
- [ ] Authentication required for all protected endpoints
- [ ] Authorization checked before sensitive operations
- [ ] Fine-grained permissions (not just admin/user)
- [ ] Security voters used for complex authorization
- [ ] API endpoints have proper security attributes
- [ ] JWT tokens validated correctly
- [ ] Token expiration enforced
- [ ] Refresh token rotation implemented

## Input Validation

```php
<?php

// ✅ GOOD: Comprehensive input validation
use Symfony\Component\Validator\Constraints as Assert;

final class CreateAgentCommand
{
    public function __construct(
        #[Assert\NotBlank]
        #[Assert\Length(min: 3, max: 255)]
        #[Assert\Regex(
            pattern: '/^[a-zA-Z0-9\s\-_]+$/',
            message: 'Name can only contain letters, numbers, spaces, hyphens, and underscores'
        )]
        public readonly string $name,

        #[Assert\NotBlank]
        #[Assert\Choice(choices: ['gpt-4', 'gpt-3.5-turbo', 'claude-3-opus'])]
        public readonly string $model,

        #[Assert\NotBlank]
        #[Assert\Length(min: 10, max: 10000)]
        public readonly string $systemPrompt,

        #[Assert\Range(min: 0.0, max: 2.0)]
        public readonly float $temperature = 0.7,

        #[Assert\Range(min: 1, max: 128000)]
        public readonly int $maxTokens = 4000,

        #[Assert\NotBlank]
        #[Assert\Uuid]
        public readonly string $userId,
    ) {}
}

// ❌ BAD: No validation
final class CreateAgentCommand
{
    public function __construct(
        public readonly string $name,
        public readonly string $model,
        public readonly string $systemPrompt,
        public readonly float $temperature,
        public readonly int $maxTokens,
        public readonly string $userId,
    ) {}
}
```

**Review Checklist**:
- [ ] All user inputs validated
- [ ] Whitelist validation used (not blacklist)
- [ ] Length limits enforced
- [ ] Type validation enforced
- [ ] Format validation (email, UUID, etc.)
- [ ] Range validation for numbers
- [ ] File upload validation (type, size, content)
- [ ] API request validation
- [ ] Validation errors don't reveal system internals

## Output Encoding

```php
<?php

// ✅ GOOD: Proper output encoding
#[Route('/agents/{id}/details')]
public function details(string $id): Response
{
    $agent = $this->queryBus->query(new GetAgentQuery($id));

    // Twig automatically escapes output
    return $this->render('agent/details.html.twig', [
        'agent' => $agent,
    ]);
}

// In template (Twig)
{# Automatic escaping #}
<h1>{{ agent.name }}</h1>

{# Raw output when needed (be careful!) #}
<div>{{ agent.description|raw }}</div>

{# JSON encoding #}
<script>
    const agent = {{ agent|json_encode|raw }};
</script>

// ❌ BAD: No output encoding
public function details(string $id): Response
{
    $agent = $this->queryBus->query(new GetAgentQuery($id));

    // Direct output without escaping - XSS!
    $html = "<h1>{$agent->getName()}</h1>";

    return new Response($html);
}
```

**Review Checklist**:
- [ ] Template engine with auto-escaping used
- [ ] HTML entities encoded
- [ ] JavaScript output encoded
- [ ] URL parameters encoded
- [ ] CSS output encoded
- [ ] JSON properly encoded
- [ ] No raw output without sanitization
- [ ] Content-Type headers set correctly

## SQL Injection Prevention

```php
<?php

// ✅ GOOD: Safe database queries
final class WorkflowRepository
{
    public function search(string $userId, string $query, string $sortBy): array
    {
        // Parameterized query
        $qb = $this->connection->createQueryBuilder();

        $qb->select('*')
            ->from('workflows')
            ->where('user_id = :userId')
            ->andWhere('(name ILIKE :query OR description ILIKE :query)')
            ->setParameter('userId', $userId)
            ->setParameter('query', "%{$query}%");

        // Whitelist for sort column
        $allowedSortColumns = ['name', 'created_at', 'updated_at'];
        $sortColumn = in_array($sortBy, $allowedSortColumns, true) ? $sortBy : 'created_at';

        $qb->orderBy($sortColumn, 'DESC');

        return $qb->executeQuery()->fetchAllAssociative();
    }
}

// ❌ BAD: SQL injection vulnerability
final class WorkflowRepository
{
    public function search(string $userId, string $query, string $sortBy): array
    {
        // String concatenation - SQL INJECTION!
        $sql = "SELECT * FROM workflows
                WHERE user_id = '{$userId}'
                AND (name ILIKE '%{$query}%' OR description ILIKE '%{$query}%')
                ORDER BY {$sortBy} DESC";

        return $this->connection->fetchAllAssociative($sql);
    }
}
```

**Review Checklist**:
- [ ] Prepared statements used
- [ ] Parameter binding used
- [ ] No string concatenation in SQL
- [ ] Dynamic ORDER BY uses whitelist
- [ ] ORM used correctly
- [ ] Stored procedures parameterized
- [ ] LIKE queries use parameters

## Cryptography

```php
<?php

// ✅ GOOD: Secure encryption
final class FieldEncryption
{
    private const CIPHER = 'aes-256-gcm';

    public function __construct(
        #[Autowire('%env(ENCRYPTION_KEY)%')]
        private readonly string $key,
    ) {
        if (strlen($this->key) !== 32) {
            throw new \InvalidArgumentException('Encryption key must be 32 bytes');
        }
    }

    public function encrypt(string $plaintext): string
    {
        $iv = random_bytes(openssl_cipher_iv_length(self::CIPHER));
        $tag = '';

        $ciphertext = openssl_encrypt(
            $plaintext,
            self::CIPHER,
            $this->key,
            OPENSSL_RAW_DATA,
            $iv,
            $tag,
            '',
            16
        );

        if ($ciphertext === false) {
            throw new \RuntimeException('Encryption failed');
        }

        // Return iv + tag + ciphertext
        return base64_encode($iv . $tag . $ciphertext);
    }

    public function decrypt(string $encrypted): string
    {
        $data = base64_decode($encrypted, true);

        if ($data === false) {
            throw new \InvalidArgumentException('Invalid encrypted data');
        }

        $ivLength = openssl_cipher_iv_length(self::CIPHER);
        $iv = substr($data, 0, $ivLength);
        $tag = substr($data, $ivLength, 16);
        $ciphertext = substr($data, $ivLength + 16);

        $plaintext = openssl_decrypt(
            $ciphertext,
            self::CIPHER,
            $this->key,
            OPENSSL_RAW_DATA,
            $iv,
            $tag
        );

        if ($plaintext === false) {
            throw new \RuntimeException('Decryption failed');
        }

        return $plaintext;
    }
}

// ❌ BAD: Weak encryption
final class FieldEncryption
{
    public function encrypt(string $plaintext): string
    {
        // ECB mode is insecure!
        // No authentication tag!
        return base64_encode(openssl_encrypt(
            $plaintext,
            'aes-256-ecb',
            'hardcoded-key',  // Hardcoded key!
            0
        ));
    }
}
```

**Review Checklist**:
- [ ] Strong encryption algorithms (AES-256-GCM)
- [ ] No hardcoded encryption keys
- [ ] Keys stored in environment variables or secret manager
- [ ] Initialization vectors (IV) generated securely
- [ ] Authenticated encryption used (GCM mode)
- [ ] No deprecated algorithms (DES, RC4, MD5, SHA1 for passwords)
- [ ] Random values from cryptographically secure source
- [ ] Key rotation strategy implemented

## Secrets Management

```php
<?php

// ✅ GOOD: Using Vault for secrets
final class LLMServiceFactory
{
    public function __construct(
        private readonly VaultClient $vault,
    ) {}

    public function createOpenAIService(): LLMServiceInterface
    {
        // Retrieve API key from Vault
        $apiKey = $this->vault->read('secret/data/llm/openai')['data']['api_key'];

        return new OpenAIService($apiKey);
    }
}

// ❌ BAD: Hardcoded secrets
final class LLMServiceFactory
{
    public function createOpenAIService(): LLMServiceInterface
    {
        // Hardcoded API key - NEVER DO THIS!
        $apiKey = 'sk-proj-abcdef1234567890';

        return new OpenAIService($apiKey);
    }
}

// ❌ BAD: Secrets in version control
# .env (committed to git)
OPENAI_API_KEY=sk-proj-abcdef1234567890
DATABASE_URL=postgresql://user:password@localhost/db
```

**Review Checklist**:
- [ ] No hardcoded secrets
- [ ] Secrets not in version control
- [ ] `.env` files in `.gitignore`
- [ ] Secrets retrieved from Vault/secret manager
- [ ] Secrets rotated regularly
- [ ] No secrets in logs
- [ ] No secrets in error messages
- [ ] API keys have restricted permissions

## API Security

```php
<?php

// ✅ GOOD: Rate-limited API endpoint
use Symfony\Component\RateLimiter\RateLimiterFactory;

#[Route('/api/v1/agents')]
final class AgentController
{
    public function __construct(
        private readonly RateLimiterFactory $apiLimiter,
    ) {}

    #[Route('', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        // Rate limiting
        $limiter = $this->apiLimiter->create($request->getClientIp());

        if (!$limiter->consume(1)->isAccepted()) {
            return $this->json(
                ['error' => 'Too many requests'],
                Response::HTTP_TOO_MANY_REQUESTS
            );
        }

        // Authentication required
        $this->denyAccessUnlessGranted('IS_AUTHENTICATED_FULLY');

        // Process request
        $data = json_decode($request->getContent(), true);

        // Validate input
        $violations = $this->validator->validate($data, new CreateAgentConstraints());

        if (count($violations) > 0) {
            return $this->json(
                ['error' => 'Validation failed', 'violations' => $violations],
                Response::HTTP_UNPROCESSABLE_ENTITY
            );
        }

        $command = new CreateAgentCommand(/* ... */);
        $agentId = $this->commandBus->dispatch($command);

        return $this->json(['id' => $agentId], Response::HTTP_CREATED);
    }
}
```

**Review Checklist**:
- [ ] Rate limiting implemented
- [ ] Authentication required
- [ ] Authorization enforced
- [ ] Input validation
- [ ] CORS configured restrictively
- [ ] Request size limits
- [ ] Pagination enforced
- [ ] API versioning
- [ ] Proper HTTP methods used
- [ ] Security headers set

## Summary

This security review checklist ensures:

1. **OWASP Top 10** coverage
2. **Authentication/Authorization** properly implemented
3. **Input validation** comprehensive
4. **Output encoding** prevents XSS
5. **SQL injection** prevented
6. **Cryptography** uses strong algorithms
7. **Secrets** properly managed
8. **API security** enforced
9. **Logging** captures security events
10. **Dependencies** kept updated

Every code review should include security considerations. When in doubt, mark as security risk and escalate to security team.
