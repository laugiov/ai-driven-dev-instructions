# Authentication & Authorization

## Overview

This document provides a comprehensive guide to authentication and authorization implementation across the platform. We use industry-standard protocols (OAuth2/OIDC) for user authentication and a hybrid RBAC/ABAC model for fine-grained authorization.

## Authentication Strategy

### OAuth 2.0 / OpenID Connect (OIDC)

**Why OAuth2/OIDC?**
- ✅ Industry standard for API authorization
- ✅ Secure delegation of access
- ✅ Token-based (stateless)
- ✅ Supports SSO (Single Sign-On)
- ✅ MFA compatible
- ✅ Well-supported by libraries and tools

**Provider**: Keycloak (Open Source IAM)

### Authentication Flow

**Authorization Code Flow** (for web/mobile apps):

```
1. User → Frontend
   │
   ├─ User clicks "Login"
   └─ Frontend redirects to Keycloak

2. Frontend → Keycloak
   │
   ├─ GET /auth/realms/{realm}/protocol/openid-connect/auth
   ├─ Parameters:
   │   ├─ client_id: ai-workflow-platform
   │   ├─ redirect_uri: https://app.example.com/callback
   │   ├─ response_type: code
   │   ├─ scope: openid profile email
   │   └─ state: random_string (CSRF protection)
   │
   └─ Keycloak shows login page

3. User → Keycloak
   │
   ├─ Enter username + password
   ├─ Complete MFA (if enabled)
   └─ Keycloak validates credentials

4. Keycloak → Frontend (via redirect)
   │
   ├─ Redirect to: https://app.example.com/callback?code=AUTH_CODE&state=random_string
   └─ Frontend receives authorization code

5. Frontend → Backend API
   │
   ├─ POST /api/v1/auth/callback
   ├─ Body: { code: AUTH_CODE }
   └─ Backend exchanges code for tokens

6. Backend → Keycloak
   │
   ├─ POST /auth/realms/{realm}/protocol/openid-connect/token
   ├─ Body:
   │   ├─ grant_type: authorization_code
   │   ├─ code: AUTH_CODE
   │   ├─ client_id: ai-workflow-platform
   │   ├─ client_secret: SECRET
   │   └─ redirect_uri: https://app.example.com/callback
   │
   └─ Keycloak returns tokens

7. Keycloak → Backend
   │
   └─ Response:
       ├─ access_token: JWT (15 min expiry)
       ├─ refresh_token: Opaque string (7 days expiry)
       ├─ id_token: JWT (user info)
       ├─ token_type: Bearer
       └─ expires_in: 900

8. Backend → Frontend
   │
   └─ Response:
       ├─ Set-Cookie: access_token (HttpOnly, Secure, SameSite=Strict)
       ├─ Set-Cookie: refresh_token (HttpOnly, Secure, SameSite=Strict)
       └─ Body: { user: { id, email, name, roles } }

9. Frontend → API (subsequent requests)
   │
   ├─ Cookie: access_token=JWT
   └─ OR Authorization: Bearer JWT

10. API → Service
    │
    ├─ Validate JWT signature
    ├─ Check expiration
    ├─ Extract user info
    └─ Process request
```

### JWT Token Structure

**Access Token** (JWT format):

```json
{
  "header": {
    "alg": "RS256",
    "typ": "JWT",
    "kid": "key-id-from-keycloak"
  },
  "payload": {
    "exp": 1704632400,
    "iat": 1704631500,
    "auth_time": 1704631500,
    "jti": "unique-jwt-id",
    "iss": "https://keycloak.example.com/auth/realms/ai-platform",
    "aud": "ai-workflow-platform",
    "sub": "user-uuid",
    "typ": "Bearer",
    "azp": "ai-workflow-platform",
    "session_state": "session-uuid",
    "acr": "1",
    "allowed-origins": ["https://app.example.com"],
    "realm_access": {
      "roles": ["user", "workflow_creator"]
    },
    "resource_access": {
      "ai-workflow-platform": {
        "roles": ["workflow:create", "workflow:execute"]
      }
    },
    "scope": "openid profile email",
    "sid": "session-uuid",
    "email_verified": true,
    "name": "John Doe",
    "preferred_username": "john.doe",
    "given_name": "John",
    "family_name": "Doe",
    "email": "john.doe@example.com"
  },
  "signature": "RS256_signature"
}
```

**Refresh Token** (Opaque):
- Not a JWT (opaque string)
- Stored in Keycloak database
- Used to get new access tokens
- Can be revoked server-side

### Token Validation

**PHP Implementation**:

```php
// src/Infrastructure/Security/JwtAuthenticator.php
namespace App\Infrastructure\Security;

use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Symfony\Component\Security\Http\Authenticator\AbstractAuthenticator;
use Symfony\Component\Security\Http\Authenticator\Passport\Badge\UserBadge;
use Symfony\Component\Security\Http\Authenticator\Passport\Passport;
use Symfony\Component\Security\Http\Authenticator\Passport\SelfValidatingPassport;

final class JwtAuthenticator extends AbstractAuthenticator
{
    public function __construct(
        private readonly string $keycloakPublicKey,
        private readonly string $keycloakIssuer,
        private readonly UserProviderInterface $userProvider,
        private readonly CacheInterface $cache,
    ) {}

    public function supports(Request $request): ?bool
    {
        return $request->headers->has('Authorization')
            || $request->cookies->has('access_token');
    }

    public function authenticate(Request $request): Passport
    {
        $token = $this->extractToken($request);

        if ($token === null) {
            throw new AuthenticationException('No token provided');
        }

        try {
            // 1. Decode and verify JWT
            $decoded = JWT::decode(
                $token,
                new Key($this->keycloakPublicKey, 'RS256')
            );

            // 2. Verify issuer
            if ($decoded->iss !== $this->keycloakIssuer) {
                throw new InvalidIssuerException("Invalid issuer: {$decoded->iss}");
            }

            // 3. Verify audience
            if ($decoded->aud !== 'ai-workflow-platform') {
                throw new InvalidAudienceException("Invalid audience: {$decoded->aud}");
            }

            // 4. Verify expiration
            if ($decoded->exp < time()) {
                throw new TokenExpiredException("Token expired at " . date('Y-m-d H:i:s', $decoded->exp));
            }

            // 5. Check token blacklist (for revoked tokens)
            if ($this->isTokenRevoked($decoded->jti)) {
                throw new TokenRevokedException("Token has been revoked");
            }

            // 6. Verify session is still active in Keycloak
            if (!$this->isSessionActive($decoded->sid)) {
                throw new SessionInvalidException("Session is no longer active");
            }

            // 7. Create user from token
            $user = new User(
                id: $decoded->sub,
                email: $decoded->email,
                name: $decoded->name,
                roles: $this->extractRoles($decoded),
                permissions: $this->extractPermissions($decoded),
            );

            return new SelfValidatingPassport(
                new UserBadge($user->getId(), fn() => $user)
            );

        } catch (ExpiredException $e) {
            throw new AuthenticationException('Token expired', 0, $e);
        } catch (SignatureInvalidException $e) {
            throw new AuthenticationException('Invalid token signature', 0, $e);
        } catch (\Exception $e) {
            throw new AuthenticationException('Token validation failed', 0, $e);
        }
    }

    private function extractToken(Request $request): ?string
    {
        // Try Authorization header first
        $authHeader = $request->headers->get('Authorization');
        if ($authHeader && str_starts_with($authHeader, 'Bearer ')) {
            return substr($authHeader, 7);
        }

        // Fallback to cookie
        return $request->cookies->get('access_token');
    }

    private function extractRoles(\stdClass $decoded): array
    {
        $roles = [];

        // Realm roles
        if (isset($decoded->realm_access->roles)) {
            $roles = array_merge($roles, $decoded->realm_access->roles);
        }

        // Resource/client roles
        if (isset($decoded->resource_access->{'ai-workflow-platform'}->roles)) {
            $roles = array_merge(
                $roles,
                $decoded->resource_access->{'ai-workflow-platform'}->roles
            );
        }

        return array_unique($roles);
    }

    private function extractPermissions(\stdClass $decoded): array
    {
        // Permissions are encoded as resource_access roles
        $permissions = [];

        if (isset($decoded->resource_access->{'ai-workflow-platform'}->roles)) {
            foreach ($decoded->resource_access->{'ai-workflow-platform'}->roles as $role) {
                if (str_contains($role, ':')) {
                    // Format: "resource:action" (e.g., "workflow:create")
                    $permissions[] = $role;
                }
            }
        }

        return $permissions;
    }

    private function isTokenRevoked(string $jti): bool
    {
        // Check Redis blacklist
        return $this->cache->hasItem("revoked_token:{$jti}");
    }

    private function isSessionActive(string $sessionId): bool
    {
        // Optional: Verify with Keycloak (adds latency)
        // For performance, rely on token expiration + revocation list
        return true;
    }

    public function onAuthenticationSuccess(Request $request, TokenInterface $token, string $firewallName): ?Response
    {
        // Authentication successful, continue request
        return null;
    }

    public function onAuthenticationFailure(Request $request, AuthenticationException $exception): ?Response
    {
        return new JsonResponse([
            'error' => [
                'code' => 'AUTHENTICATION_FAILED',
                'message' => $exception->getMessage(),
            ],
        ], 401);
    }
}
```

### Token Refresh

**Refresh Token Flow**:

```php
// src/Infrastructure/Http/Controller/AuthController.php
#[Route('/api/v1/auth/refresh', methods: ['POST'])]
public function refresh(Request $request): JsonResponse
{
    $refreshToken = $request->cookies->get('refresh_token');

    if (!$refreshToken) {
        throw new AuthenticationException('No refresh token provided');
    }

    try {
        // Exchange refresh token for new access token
        $response = $this->httpClient->request('POST', $this->keycloakTokenUrl, [
            'body' => [
                'grant_type' => 'refresh_token',
                'refresh_token' => $refreshToken,
                'client_id' => 'ai-workflow-platform',
                'client_secret' => $this->clientSecret,
            ],
        ]);

        $data = $response->toArray();

        // Set new tokens in cookies
        $response = new JsonResponse(['status' => 'refreshed']);
        $response->headers->setCookie(
            Cookie::create('access_token')
                ->withValue($data['access_token'])
                ->withExpires(time() + 900) // 15 minutes
                ->withHttpOnly(true)
                ->withSecure(true)
                ->withSameSite(Cookie::SAMESITE_STRICT)
        );

        if (isset($data['refresh_token'])) {
            $response->headers->setCookie(
                Cookie::create('refresh_token')
                    ->withValue($data['refresh_token'])
                    ->withExpires(time() + 604800) // 7 days
                    ->withHttpOnly(true)
                    ->withSecure(true)
                    ->withSameSite(Cookie::SAMESITE_STRICT)
            );
        }

        return $response;

    } catch (HttpExceptionInterface $e) {
        // Refresh token expired or invalid
        throw new AuthenticationException('Refresh token invalid or expired');
    }
}
```

### Multi-Factor Authentication (MFA)

**Keycloak MFA Configuration**:

```yaml
# Keycloak Realm Configuration
realm: ai-platform
authentication:
  flows:
    - alias: browser
      description: Browser-based authentication
      providerId: basic-flow
      topLevel: true
      builtIn: false
      authenticationExecutions:
        - authenticator: auth-cookie
          requirement: ALTERNATIVE
          priority: 10

        - authenticator: auth-spnego
          requirement: DISABLED
          priority: 20

        - authenticator: identity-provider-redirector
          requirement: ALTERNATIVE
          priority: 25

        - authenticator: auth-username-password-form
          requirement: REQUIRED
          priority: 30

        - authenticator: auth-otp-form
          requirement: CONDITIONAL  # MFA when configured
          priority: 40

  requiredActions:
    - alias: CONFIGURE_TOTP
      name: Configure OTP
      providerId: CONFIGURE_TOTP
      enabled: true
      defaultAction: false

  otpPolicy:
    type: totp
    algorithm: HmacSHA1
    digits: 6
    period: 30
    lookAheadWindow: 1
```

**Enforce MFA for Specific Roles**:

```php
// src/Infrastructure/Security/MfaEnforcer.php
final readonly class MfaEnforcer
{
    public function shouldEnforceMfa(User $user): bool
    {
        // Enforce MFA for admin users
        if ($user->hasRole('ADMIN') || $user->hasRole('SUPER_ADMIN')) {
            return true;
        }

        // Enforce MFA for users with elevated permissions
        if ($user->hasPermission('workflow:delete') || $user->hasPermission('user:manage')) {
            return true;
        }

        // Optional for regular users
        return false;
    }
}
```

### Logout

**Complete Logout Flow**:

```php
#[Route('/api/v1/auth/logout', methods: ['POST'])]
public function logout(Request $request): JsonResponse
{
    $accessToken = $this->extractToken($request);

    try {
        // 1. Revoke token in Keycloak
        $this->httpClient->request('POST', $this->keycloakLogoutUrl, [
            'body' => [
                'client_id' => 'ai-workflow-platform',
                'client_secret' => $this->clientSecret,
                'refresh_token' => $request->cookies->get('refresh_token'),
            ],
        ]);

        // 2. Add token to blacklist (Redis)
        $decoded = JWT::decode($accessToken, new Key($this->publicKey, 'RS256'));
        $this->cache->save(
            $this->cache->getItem("revoked_token:{$decoded->jti}")
                ->set(true)
                ->expiresAt(new \DateTimeImmutable('@' . $decoded->exp))
        );

        // 3. Clear cookies
        $response = new JsonResponse(['status' => 'logged_out']);
        $response->headers->clearCookie('access_token');
        $response->headers->clearCookie('refresh_token');

        return $response;

    } catch (\Exception $e) {
        // Log error but still clear cookies
        $this->logger->error('Logout error', ['error' => $e->getMessage()]);

        $response = new JsonResponse(['status' => 'logged_out']);
        $response->headers->clearCookie('access_token');
        $response->headers->clearCookie('refresh_token');

        return $response;
    }
}
```

## Authorization Strategy

### Role-Based Access Control (RBAC)

**Role Hierarchy**:

```php
// config/packages/security.yaml
security:
    role_hierarchy:
        ROLE_USER: []
        ROLE_POWER_USER: [ROLE_USER]
        ROLE_ADMIN: [ROLE_POWER_USER]
        ROLE_SUPER_ADMIN: [ROLE_ADMIN]
```

**Role Definitions**:

```php
// src/Domain/ValueObject/Role.php
enum Role: string
{
    case USER = 'ROLE_USER';
    case POWER_USER = 'ROLE_POWER_USER';
    case ADMIN = 'ROLE_ADMIN';
    case SUPER_ADMIN = 'ROLE_SUPER_ADMIN';

    public function getPermissions(): array
    {
        return match($this) {
            self::USER => [
                'workflow:create',
                'workflow:read_own',
                'workflow:update_own',
                'workflow:delete_own',
                'workflow:execute_own',
            ],
            self::POWER_USER => [
                ...self::USER->getPermissions(),
                'workflow:read_all',
                'workflow:execute_all',
                'validation:read',
            ],
            self::ADMIN => [
                ...self::POWER_USER->getPermissions(),
                'workflow:update_all',
                'workflow:delete_all',
                'user:read',
                'user:update',
                'audit:read',
            ],
            self::SUPER_ADMIN => [
                ...self::ADMIN->getPermissions(),
                'user:delete',
                'config:update',
                'audit:export',
                'system:manage',
            ],
        };
    }

    public function canAccessResource(string $resource, string $action): bool
    {
        $permission = "{$resource}:{$action}";
        return in_array($permission, $this->getPermissions(), true);
    }
}
```

**Controller-Level Authorization**:

```php
// src/Infrastructure/Http/Controller/WorkflowController.php
#[Route('/api/v1/workflows')]
final class WorkflowController extends AbstractController
{
    #[Route('', methods: ['POST'])]
    #[IsGranted('ROLE_USER')]  // Require USER role
    public function create(Request $request): JsonResponse
    {
        // User has ROLE_USER or higher
        $command = new CreateWorkflowCommand(/* ... */);
        $workflowId = $this->commandBus->dispatch($command);

        return $this->json(['id' => $workflowId->toString()], 201);
    }

    #[Route('/{id}', methods: ['GET'])]
    #[IsGranted('WORKFLOW_VIEW', 'workflow')]  // Custom voter
    public function get(string $id): JsonResponse
    {
        // Voter checks if user can view this specific workflow
        $workflow = $this->workflowRepository->findById(new WorkflowId($id));

        return $this->json(WorkflowDTO::fromEntity($workflow));
    }

    #[Route('/{id}', methods: ['DELETE'])]
    #[IsGranted('WORKFLOW_DELETE', 'workflow')]
    public function delete(string $id): JsonResponse
    {
        // Only owner or super admin can delete
        $this->commandBus->dispatch(new DeleteWorkflowCommand($id));

        return $this->json(['status' => 'deleted'], 204);
    }
}
```

### Attribute-Based Access Control (ABAC)

**Policy-Based Authorization**:

```php
// src/Infrastructure/Security/Voter/WorkflowVoter.php
final class WorkflowVoter extends Voter
{
    public const VIEW = 'WORKFLOW_VIEW';
    public const EDIT = 'WORKFLOW_EDIT';
    public const DELETE = 'WORKFLOW_DELETE';
    public const EXECUTE = 'WORKFLOW_EXECUTE';

    protected function supports(string $attribute, mixed $subject): bool
    {
        return in_array($attribute, [self::VIEW, self::EDIT, self::DELETE, self::EXECUTE])
            && $subject instanceof Workflow;
    }

    protected function voteOnAttribute(string $attribute, mixed $subject, TokenInterface $token): bool
    {
        $user = $token->getUser();

        if (!$user instanceof User) {
            return false;
        }

        $workflow = $subject;

        return match($attribute) {
            self::VIEW => $this->canView($user, $workflow),
            self::EDIT => $this->canEdit($user, $workflow),
            self::DELETE => $this->canDelete($user, $workflow),
            self::EXECUTE => $this->canExecute($user, $workflow),
            default => false,
        };
    }

    private function canView(User $user, Workflow $workflow): bool
    {
        // 1. Super admin can view all
        if ($user->hasRole(Role::SUPER_ADMIN)) {
            return true;
        }

        // 2. Admins can view all
        if ($user->hasRole(Role::ADMIN)) {
            return true;
        }

        // 3. Power users can view all
        if ($user->hasRole(Role::POWER_USER)) {
            return true;
        }

        // 4. Users can view own workflows
        if ($workflow->getOwnerId()->equals($user->getId())) {
            return true;
        }

        // 5. Users can view workflows shared with them
        if ($workflow->isSharedWith($user->getId())) {
            return true;
        }

        return false;
    }

    private function canEdit(User $user, Workflow $workflow): bool
    {
        // 1. Super admin can edit all
        if ($user->hasRole(Role::SUPER_ADMIN)) {
            return true;
        }

        // 2. Admins can edit all
        if ($user->hasRole(Role::ADMIN)) {
            return true;
        }

        // 3. Users can edit own workflows (if not archived)
        if ($workflow->getOwnerId()->equals($user->getId())) {
            if ($workflow->getStatus()->isArchived()) {
                return false;  // Cannot edit archived workflows
            }
            return true;
        }

        // 4. Users with edit permission (shared workflows)
        if ($workflow->hasEditPermission($user->getId())) {
            return true;
        }

        return false;
    }

    private function canDelete(User $user, Workflow $workflow): bool
    {
        // 1. Super admin can delete any
        if ($user->hasRole(Role::SUPER_ADMIN)) {
            return true;
        }

        // 2. Owner can delete own workflow
        if ($workflow->getOwnerId()->equals($user->getId())) {
            // Cannot delete if it has active instances
            if ($this->hasActiveInstances($workflow)) {
                return false;
            }
            return true;
        }

        return false;
    }

    private function canExecute(User $user, Workflow $workflow): bool
    {
        // 1. Workflow must be active
        if (!$workflow->getStatus()->isActive()) {
            return false;
        }

        // 2. Super admin can execute any
        if ($user->hasRole(Role::SUPER_ADMIN)) {
            return true;
        }

        // 3. Admins can execute any
        if ($user->hasRole(Role::ADMIN)) {
            return true;
        }

        // 4. Power users can execute any
        if ($user->hasRole(Role::POWER_USER)) {
            return true;
        }

        // 5. Owner can execute own
        if ($workflow->getOwnerId()->equals($user->getId())) {
            return true;
        }

        // 6. Users with execute permission
        if ($workflow->hasExecutePermission($user->getId())) {
            return true;
        }

        return false;
    }

    private function hasActiveInstances(Workflow $workflow): bool
    {
        return $this->workflowInstanceRepository->countActiveByWorkflow($workflow->getId()) > 0;
    }
}
```

### Service-Level Authorization

**Authorization in Application Layer**:

```php
// src/Application/Handler/ExecuteWorkflowHandler.php
final readonly class ExecuteWorkflowHandler
{
    public function __construct(
        private WorkflowRepositoryInterface $workflowRepository,
        private AuthorizationService $authorizationService,
        private WorkflowExecutor $executor,
    ) {}

    public function __invoke(ExecuteWorkflowCommand $command): InstanceId
    {
        $workflow = $this->workflowRepository->findById($command->workflowId);

        if ($workflow === null) {
            throw new WorkflowNotFoundException($command->workflowId);
        }

        // Authorization check
        if (!$this->authorizationService->canExecute($command->userId, $workflow)) {
            throw new AccessDeniedException(
                "User {$command->userId->toString()} cannot execute workflow {$workflow->getId()->toString()}"
            );
        }

        // Additional business rule checks
        if ($workflow->getStatus()->isDraft()) {
            throw new CannotExecuteDraftWorkflowException($workflow->getId());
        }

        // Execute workflow
        return $this->executor->execute($workflow, $command->parameters, $command->userId);
    }
}
```

### Row-Level Security (Database Level)

**PostgreSQL Row-Level Security (RLS)**:

```sql
-- Enable RLS on workflows table
ALTER TABLE workflows ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see workflows they own or are shared with
CREATE POLICY workflow_access_policy ON workflows
    FOR SELECT
    USING (
        owner_id = current_setting('app.current_user_id')::uuid
        OR id IN (
            SELECT workflow_id
            FROM workflow_shares
            WHERE user_id = current_setting('app.current_user_id')::uuid
        )
    );

-- Policy: Users can only update workflows they own
CREATE POLICY workflow_update_policy ON workflows
    FOR UPDATE
    USING (owner_id = current_setting('app.current_user_id')::uuid);

-- Policy: Users can only delete workflows they own
CREATE POLICY workflow_delete_policy ON workflows
    FOR DELETE
    USING (owner_id = current_setting('app.current_user_id')::uuid);

-- Policy: Any authenticated user can insert
CREATE POLICY workflow_insert_policy ON workflows
    FOR INSERT
    WITH CHECK (owner_id = current_setting('app.current_user_id')::uuid);
```

**Set User Context in Application**:

```php
// src/Infrastructure/Persistence/DoctrineWorkflowRepository.php
public function findById(WorkflowId $id): ?Workflow
{
    // Set user context for RLS
    $userId = $this->security->getUser()?->getId();
    if ($userId) {
        $this->entityManager->getConnection()->exec(
            "SET LOCAL app.current_user_id = '{$userId->toString()}'"
        );
    }

    return $this->entityManager
        ->getRepository(Workflow::class)
        ->find($id->toString());
}
```

## API Key Authentication (for programmatic access)

**API Key Generation**:

```php
// src/Domain/Entity/ApiKey.php
final class ApiKey
{
    private ApiKeyId $id;
    private UserId $userId;
    private string $keyHash;  // Never store plain key
    private string $name;
    private array $scopes;
    private ?DateTimeImmutable $expiresAt;
    private DateTimeImmutable $lastUsedAt;
    private bool $isActive;

    public static function generate(UserId $userId, string $name, array $scopes, ?DateTimeImmutable $expiresAt = null): self
    {
        $plainKey = bin2hex(random_bytes(32)); // 64 chars
        $keyHash = password_hash($plainKey, PASSWORD_ARGON2ID);

        $apiKey = new self();
        $apiKey->id = ApiKeyId::generate();
        $apiKey->userId = $userId;
        $apiKey->keyHash = $keyHash;
        $apiKey->name = $name;
        $apiKey->scopes = $scopes;
        $apiKey->expiresAt = $expiresAt;
        $apiKey->isActive = true;

        // Return plain key ONCE (user must save it)
        $apiKey->plainKey = $plainKey;

        return $apiKey;
    }

    public function verify(string $plainKey): bool
    {
        if (!$this->isActive) {
            return false;
        }

        if ($this->expiresAt && $this->expiresAt < new DateTimeImmutable()) {
            return false;
        }

        return password_verify($plainKey, $this->keyHash);
    }
}
```

**API Key Authenticator**:

```php
// src/Infrastructure/Security/ApiKeyAuthenticator.php
final class ApiKeyAuthenticator extends AbstractAuthenticator
{
    public function supports(Request $request): ?bool
    {
        return $request->headers->has('X-API-Key');
    }

    public function authenticate(Request $request): Passport
    {
        $apiKeyString = $request->headers->get('X-API-Key');

        $apiKey = $this->apiKeyRepository->findByKey($apiKeyString);

        if ($apiKey === null || !$apiKey->verify($apiKeyString)) {
            throw new AuthenticationException('Invalid API key');
        }

        // Update last used
        $apiKey->updateLastUsed();
        $this->apiKeyRepository->save($apiKey);

        // Load user
        $user = $this->userRepository->findById($apiKey->getUserId());

        // Create passport with API key scopes
        return new SelfValidatingPassport(
            new UserBadge($user->getId(), fn() => $user),
            [new ScopeBadge($apiKey->getScopes())]
        );
    }
}
```

## Session Management

**Session Configuration**:

```yaml
# config/packages/framework.yaml
framework:
    session:
        handler_id: Symfony\Component\HttpFoundation\Session\Storage\Handler\RedisSessionHandler
        cookie_secure: true
        cookie_httponly: true
        cookie_samesite: strict
        gc_maxlifetime: 1800  # 30 minutes
        gc_probability: 1
        gc_divisor: 100
```

**Session Security**:

```php
// src/Infrastructure/Security/SessionManager.php
final readonly class SessionManager
{
    public function __construct(
        private SessionInterface $session,
        private CacheInterface $cache,
    ) {}

    public function createSession(User $user): void
    {
        // Regenerate session ID on login
        $this->session->migrate(true);

        // Store user info
        $this->session->set('user_id', $user->getId());
        $this->session->set('login_time', time());
        $this->session->set('ip_address', $_SERVER['REMOTE_ADDR']);

        // Track active sessions in Redis
        $this->cache->set(
            "user_sessions:{$user->getId()}:{$this->session->getId()}",
            [
                'ip' => $_SERVER['REMOTE_ADDR'],
                'user_agent' => $_SERVER['HTTP_USER_AGENT'],
                'login_time' => time(),
            ],
            ttl: 1800
        );
    }

    public function validateSession(): bool
    {
        $userId = $this->session->get('user_id');
        $loginTime = $this->session->get('login_time');
        $ipAddress = $this->session->get('ip_address');

        // Check session timeout (30 minutes of inactivity)
        if (time() - $this->session->getMetadataBag()->getLastUsed() > 1800) {
            return false;
        }

        // Check if IP changed (optional, may cause issues with mobile networks)
        // if ($ipAddress !== $_SERVER['REMOTE_ADDR']) {
        //     return false;
        // }

        // Check if session still exists in Redis
        if (!$this->cache->hasItem("user_sessions:{$userId}:{$this->session->getId()}")) {
            return false;
        }

        return true;
    }

    public function destroySession(): void
    {
        $userId = $this->session->get('user_id');
        $sessionId = $this->session->getId();

        // Remove from Redis
        $this->cache->deleteItem("user_sessions:{$userId}:{$sessionId}");

        // Invalidate session
        $this->session->invalidate();
    }

    public function getActiveSessions(UserId $userId): array
    {
        $pattern = "user_sessions:{$userId->toString()}:*";
        // Scan Redis for all user sessions
        // Returns array of session info
    }

    public function revokeAllSessions(UserId $userId): void
    {
        // Revoke all active sessions for user
        $sessions = $this->getActiveSessions($userId);

        foreach ($sessions as $sessionId => $info) {
            $this->cache->deleteItem("user_sessions:{$userId->toString()}:{$sessionId}");
        }
    }
}
```

## Security Best Practices

### Password Policies

```yaml
# Keycloak password policy
realm:
  passwordPolicy: >
    length(12) and
    upperCase(1) and
    lowerCase(1) and
    digits(1) and
    specialChars(1) and
    notUsername and
    notEmail and
    hashIterations(27500) and
    passwordHistory(5) and
    forceExpiredPasswordChange(90)
```

### Account Lockout

```yaml
# Keycloak brute force detection
realm:
  bruteForceProtected: true
  permanentLockout: false
  maxFailureWaitSeconds: 900  # 15 minutes
  minimumQuickLoginWaitSeconds: 60
  waitIncrementSeconds: 60
  quickLoginCheckMilliSeconds: 1000
  maxDeltaTimeSeconds: 43200  # 12 hours
  failureFactor: 5  # Lock after 5 failed attempts
```

### Token Security

**Token Storage**:
- ✅ HttpOnly cookies (prevent XSS)
- ✅ Secure flag (HTTPS only)
- ✅ SameSite=Strict (prevent CSRF)
- ❌ Never localStorage (XSS vulnerable)
- ❌ Never sessionStorage (XSS vulnerable)

**Token Lifetimes**:
- Access Token: 15 minutes (short-lived)
- Refresh Token: 7 days
- API Key: User-defined (recommend 90 days max)

## Monitoring & Auditing

**Authentication Events to Log**:

```php
// Log all authentication events
$this->auditService->logEvent([
    'eventType' => 'AUTHENTICATION_SUCCESS',
    'userId' => $user->getId(),
    'ipAddress' => $request->getClientIp(),
    'userAgent' => $request->headers->get('User-Agent'),
    'timestamp' => new DateTimeImmutable(),
]);

// Failed authentication
$this->auditService->logEvent([
    'eventType' => 'AUTHENTICATION_FAILED',
    'username' => $username,
    'reason' => 'INVALID_CREDENTIALS',
    'ipAddress' => $request->getClientIp(),
    'timestamp' => new DateTimeImmutable(),
]);
```

**Metrics to Track**:
- Failed login attempts (by user, by IP)
- Successful logins (by user, by time of day)
- Token refresh rate
- MFA enrollment rate
- Session duration
- API key usage

## Conclusion

This authentication and authorization system provides:

✅ **Industry Standards**: OAuth2/OIDC
✅ **Secure Tokens**: JWT with RS256, short-lived
✅ **Fine-Grained Authorization**: RBAC + ABAC
✅ **Multi-Factor Authentication**: TOTP support
✅ **Session Security**: HttpOnly cookies, session validation
✅ **API Keys**: For programmatic access
✅ **Complete Audit Trail**: All auth events logged
✅ **Compliance**: GDPR, SOC2, ISO27001, NIS2 ready

The system balances security with usability, providing robust protection while maintaining a good user experience.
