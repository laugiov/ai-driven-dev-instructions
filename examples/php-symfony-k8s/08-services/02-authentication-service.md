# Authentication Service

## Prerequisites for Implementation

**Before implementing this service, ensure you have read and understood**:

✅ **Foundation Knowledge** (REQUIRED):
1. [README.md](../README.md) - Overall system architecture and navigation
2. [01-architecture/01-architecture-overview.md](../01-architecture/01-architecture-overview.md) - System purpose, tech stack, ADRs
3. [01-architecture/03-hexagonal-architecture.md](../01-architecture/03-hexagonal-architecture.md) - Ports & Adapters pattern (used throughout)
4. [01-architecture/04-domain-driven-design.md](../01-architecture/04-domain-driven-design.md) - DDD tactical patterns (entities, value objects, aggregates)
5. [04-development/02-coding-guidelines-php.md](../04-development/02-coding-guidelines-php.md) - PHP 8.3 standards, PSR compliance, PHPStan Level 9

✅ **Security Context** (REQUIRED):
1. [02-security/03-authentication-authorization.md](../02-security/03-authentication-authorization.md) - OAuth2/OIDC flows, JWT, RBAC/ABAC patterns
2. [02-security/04-secrets-management.md](../02-security/04-secrets-management.md) - Vault integration for JWT keys and database credentials

✅ **Testing & Quality** (REQUIRED):
1. [04-development/04-testing-strategy.md](../04-development/04-testing-strategy.md) - Unit, integration, E2E testing approach (80% coverage minimum)

**Estimated Reading Time**: 2-3 hours
**Implementation Time**: 7-10 days (following [IMPLEMENTATION_ROADMAP.md](../IMPLEMENTATION_ROADMAP.md) Phase 3, Week 5)

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Authentication Methods](#authentication-methods)
4. [Authorization](#authorization)
5. [API Endpoints](#api-endpoints)
6. [Database Schema](#database-schema)
7. [Security](#security)
8. [Implementation](#implementation)

## Overview

### Purpose

The Authentication Service is responsible for:
- User registration and authentication
- JWT token generation and validation
- OAuth2 integration (Google, GitHub, etc.)
- Role-Based Access Control (RBAC)
- Multi-Factor Authentication (MFA)
- Password management
- Session management

### Service Specifications

```yaml
service_info:
  name: authentication-service
  version: 1.0.0
  language: PHP 8.3
  framework: Symfony 7
  port: 8080

  database:
    type: PostgreSQL 15
    name: auth_db
    connection_pool: 50

  cache:
    type: Redis
    purpose:
      - Session storage
      - Token blacklist
      - Rate limiting

  dependencies:
    internal: []
    external:
      - SMTP (SendGrid)
      - OAuth providers (Google, GitHub)

  sla:
    availability: 99.99%
    latency_p95: 100ms
    latency_p99: 200ms
    throughput: 5000 req/s
```

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│              Authentication Service                          │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │         Presentation Layer (HTTP)                  │    │
│  │                                                     │    │
│  │  ┌──────────────┐  ┌──────────────┐              │    │
│  │  │   Auth       │  │   User       │              │    │
│  │  │ Controller   │  │ Controller   │              │    │
│  │  └──────┬───────┘  └──────┬───────┘              │    │
│  └─────────┼──────────────────┼──────────────────────┘    │
│            │                  │                            │
│  ┌─────────┼──────────────────┼──────────────────────────┐│
│  │         ▼        Application Layer       ▼            ││
│  │                                                        ││
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ ││
│  │  │   Login      │  │  Register    │  │   OAuth    │ ││
│  │  │  UseCase     │  │  UseCase     │  │  UseCase   │ ││
│  │  └──────┬───────┘  └──────┬───────┘  └─────┬──────┘ ││
│  └─────────┼──────────────────┼─────────────────┼────────┘│
│            │                  │                 │          │
│  ┌─────────┼──────────────────┼─────────────────┼────────┐│
│  │         ▼       Domain Layer              ▼  │        ││
│  │                                                        ││
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ ││
│  │  │     User     │  │     Role     │  │ Permission │ ││
│  │  │   Entity     │  │   Entity     │  │   Entity   │ ││
│  │  └──────┬───────┘  └──────┬───────┘  └─────┬──────┘ ││
│  └─────────┼──────────────────┼─────────────────┼────────┘│
│            │                  │                 │          │
│  ┌─────────┼──────────────────┼─────────────────┼────────┐│
│  │         ▼   Infrastructure Layer           ▼  │        ││
│  │                                                        ││
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ ││
│  │  │     User     │  │   JWT Token  │  │   Redis    │ ││
│  │  │ Repository   │  │   Service    │  │   Cache    │ ││
│  │  └──────────────┘  └──────────────┘  └────────────┘ ││
│  └────────────────────────────────────────────────────────┘│
│                                                              │
│            ▼                  ▼                 ▼            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │  PostgreSQL  │  │    Redis     │  │  SendGrid    │    │
│  │   auth_db    │  │   Session    │  │    SMTP      │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Domain Model

```php
<?php
// src/Domain/User/User.php

declare(strict_types=1);

namespace App\Domain\User;

use App\Domain\User\ValueObject\UserId;
use App\Domain\User\ValueObject\Email;
use App\Domain\User\ValueObject\HashedPassword;
use App\Domain\User\Event\UserRegisteredEvent;
use App\Domain\User\Event\UserEmailVerifiedEvent;
use App\Domain\Common\AggregateRoot;

final class User extends AggregateRoot
{
    private array $roles = [];
    private ?\DateTimeImmutable $emailVerifiedAt = null;
    private ?string $mfaSecret = null;
    private bool $mfaEnabled = false;
    private array $oauthProviders = [];

    public function __construct(
        private readonly UserId $id,
        private Email $email,
        private HashedPassword $password,
        private string $firstName,
        private string $lastName,
        private readonly \DateTimeImmutable $createdAt,
    ) {
        $this->roles = ['ROLE_USER'];
    }

    public static function register(
        UserId $id,
        Email $email,
        HashedPassword $password,
        string $firstName,
        string $lastName,
    ): self {
        $user = new self(
            $id,
            $email,
            $password,
            $firstName,
            $lastName,
            new \DateTimeImmutable()
        );

        $user->recordEvent(new UserRegisteredEvent(
            eventId: uniqid('evt_', true),
            userId: $id,
            email: $email,
            occurredAt: new \DateTimeImmutable()
        ));

        return $user;
    }

    public function verifyEmail(): void
    {
        if ($this->emailVerifiedAt !== null) {
            throw new \DomainException('Email already verified');
        }

        $this->emailVerifiedAt = new \DateTimeImmutable();

        $this->recordEvent(new UserEmailVerifiedEvent(
            eventId: uniqid('evt_', true),
            userId: $this->id,
            occurredAt: new \DateTimeImmutable()
        ));
    }

    public function changePassword(HashedPassword $newPassword): void
    {
        $this->password = $newPassword;
    }

    public function enableMfa(string $secret): void
    {
        $this->mfaSecret = $secret;
        $this->mfaEnabled = true;
    }

    public function disableMfa(): void
    {
        $this->mfaSecret = null;
        $this->mfaEnabled = false;
    }

    public function verifyMfaToken(string $token): bool
    {
        if (!$this->mfaEnabled || $this->mfaSecret === null) {
            return false;
        }

        // Verify TOTP token
        $google2fa = new \PragmaRX\Google2FA\Google2FA();
        return $google2fa->verifyKey($this->mfaSecret, $token);
    }

    public function addRole(string $role): void
    {
        if (!in_array($role, $this->roles, true)) {
            $this->roles[] = $role;
        }
    }

    public function removeRole(string $role): void
    {
        $this->roles = array_values(array_filter(
            $this->roles,
            fn($r) => $r !== $role
        ));
    }

    public function hasRole(string $role): bool
    {
        return in_array($role, $this->roles, true);
    }

    public function linkOAuthProvider(string $provider, string $providerId): void
    {
        $this->oauthProviders[$provider] = $providerId;
    }

    // Getters
    public function getId(): UserId { return $this->id; }
    public function getEmail(): Email { return $this->email; }
    public function getPassword(): HashedPassword { return $this->password; }
    public function getFirstName(): string { return $this->firstName; }
    public function getLastName(): string { return $this->lastName; }
    public function getRoles(): array { return $this->roles; }
    public function isMfaEnabled(): bool { return $this->mfaEnabled; }
    public function isEmailVerified(): bool { return $this->emailVerifiedAt !== null; }
}
```

## Authentication Methods

### JWT Authentication

```php
<?php
// src/Application/Auth/UseCase/LoginUseCase.php

declare(strict_types=1);

namespace App\Application\Auth\UseCase;

use App\Domain\User\Repository\UserRepositoryInterface;
use App\Infrastructure\Auth\JwtTokenService;
use App\Infrastructure\Security\PasswordHasher;
use Psr\Log\LoggerInterface;

final class LoginUseCase
{
    public function __construct(
        private readonly UserRepositoryInterface $userRepository,
        private readonly PasswordHasher $passwordHasher,
        private readonly JwtTokenService $jwtTokenService,
        private readonly LoggerInterface $logger,
    ) {}

    public function execute(LoginCommand $command): LoginResult
    {
        // Find user by email
        $user = $this->userRepository->findByEmail($command->email);

        if ($user === null) {
            $this->logger->warning('Login attempt for non-existent user', [
                'email' => $command->email,
            ]);

            throw new InvalidCredentialsException('Invalid credentials');
        }

        // Verify password
        if (!$this->passwordHasher->verify($command->password, $user->getPassword()->toString())) {
            $this->logger->warning('Login attempt with invalid password', [
                'user_id' => $user->getId()->toString(),
                'email' => $command->email,
            ]);

            throw new InvalidCredentialsException('Invalid credentials');
        }

        // Check email verification
        if (!$user->isEmailVerified()) {
            throw new EmailNotVerifiedException('Email not verified');
        }

        // Check MFA
        if ($user->isMfaEnabled()) {
            if ($command->mfaToken === null) {
                return new LoginResult(
                    success: false,
                    mfaRequired: true,
                    tempToken: $this->jwtTokenService->generateTempToken($user)
                );
            }

            if (!$user->verifyMfaToken($command->mfaToken)) {
                throw new InvalidMfaTokenException('Invalid MFA token');
            }
        }

        // Generate JWT tokens
        $accessToken = $this->jwtTokenService->generateAccessToken($user);
        $refreshToken = $this->jwtTokenService->generateRefreshToken($user);

        $this->logger->info('User logged in successfully', [
            'user_id' => $user->getId()->toString(),
            'email' => $command->email,
        ]);

        return new LoginResult(
            success: true,
            accessToken: $accessToken,
            refreshToken: $refreshToken,
            expiresIn: 3600,
            user: [
                'id' => $user->getId()->toString(),
                'email' => $user->getEmail()->toString(),
                'first_name' => $user->getFirstName(),
                'last_name' => $user->getLastName(),
                'roles' => $user->getRoles(),
            ]
        );
    }
}
```

### JWT Token Service

```php
<?php
// src/Infrastructure/Auth/JwtTokenService.php

declare(strict_types=1);

namespace App\Infrastructure\Auth;

use App\Domain\User\User;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Psr\Cache\CacheItemPoolInterface;

final class JwtTokenService
{
    private const ACCESS_TOKEN_EXPIRY = 3600;        // 1 hour
    private const REFRESH_TOKEN_EXPIRY = 2592000;    // 30 days
    private const TEMP_TOKEN_EXPIRY = 300;           // 5 minutes

    public function __construct(
        private readonly string $jwtSecret,
        private readonly string $jwtIssuer,
        private readonly CacheItemPoolInterface $cache,
    ) {}

    public function generateAccessToken(User $user): string
    {
        $now = time();

        $payload = [
            'iss' => $this->jwtIssuer,
            'sub' => $user->getId()->toString(),
            'iat' => $now,
            'exp' => $now + self::ACCESS_TOKEN_EXPIRY,
            'type' => 'access',
            'user' => [
                'id' => $user->getId()->toString(),
                'email' => $user->getEmail()->toString(),
                'roles' => $user->getRoles(),
            ],
        ];

        return JWT::encode($payload, $this->jwtSecret, 'HS256');
    }

    public function generateRefreshToken(User $user): string
    {
        $now = time();
        $tokenId = bin2hex(random_bytes(32));

        $payload = [
            'iss' => $this->jwtIssuer,
            'sub' => $user->getId()->toString(),
            'iat' => $now,
            'exp' => $now + self::REFRESH_TOKEN_EXPIRY,
            'type' => 'refresh',
            'jti' => $tokenId,
        ];

        // Store refresh token in cache for validation
        $cacheItem = $this->cache->getItem("refresh_token:{$tokenId}");
        $cacheItem->set([
            'user_id' => $user->getId()->toString(),
            'created_at' => $now,
        ]);
        $cacheItem->expiresAfter(self::REFRESH_TOKEN_EXPIRY);
        $this->cache->save($cacheItem);

        return JWT::encode($payload, $this->jwtSecret, 'HS256');
    }

    public function generateTempToken(User $user): string
    {
        $now = time();

        $payload = [
            'iss' => $this->jwtIssuer,
            'sub' => $user->getId()->toString(),
            'iat' => $now,
            'exp' => $now + self::TEMP_TOKEN_EXPIRY,
            'type' => 'temp_mfa',
        ];

        return JWT::encode($payload, $this->jwtSecret, 'HS256');
    }

    public function validateToken(string $token): array
    {
        try {
            $decoded = JWT::decode($token, new Key($this->jwtSecret, 'HS256'));
            return (array) $decoded;
        } catch (\Exception $e) {
            throw new InvalidTokenException('Invalid token: ' . $e->getMessage());
        }
    }

    public function validateRefreshToken(string $token): array
    {
        $payload = $this->validateToken($token);

        if (($payload['type'] ?? '') !== 'refresh') {
            throw new InvalidTokenException('Not a refresh token');
        }

        // Check if token exists in cache (not revoked)
        $tokenId = $payload['jti'] ?? '';
        $cacheItem = $this->cache->getItem("refresh_token:{$tokenId}");

        if (!$cacheItem->isHit()) {
            throw new InvalidTokenException('Refresh token revoked or expired');
        }

        return $payload;
    }

    public function revokeRefreshToken(string $token): void
    {
        $payload = $this->validateToken($token);
        $tokenId = $payload['jti'] ?? '';

        $this->cache->deleteItem("refresh_token:{$tokenId}");
    }

    public function blacklistToken(string $token): void
    {
        $payload = $this->validateToken($token);
        $exp = $payload['exp'] ?? 0;

        $cacheItem = $this->cache->getItem("blacklist:{$token}");
        $cacheItem->set(true);
        $cacheItem->expiresAt(new \DateTimeImmutable("@{$exp}"));
        $this->cache->save($cacheItem);
    }

    public function isTokenBlacklisted(string $token): bool
    {
        $cacheItem = $this->cache->getItem("blacklist:{$token}");
        return $cacheItem->isHit();
    }
}
```

### OAuth2 Integration

```php
<?php
// src/Application/Auth/UseCase/OAuth/GoogleLoginUseCase.php

declare(strict_types=1);

namespace App\Application\Auth\UseCase\OAuth;

use App\Domain\User\Repository\UserRepositoryInterface;
use App\Domain\User\User;
use App\Domain\User\ValueObject\UserId;
use App\Domain\User\ValueObject\Email;
use App\Domain\User\ValueObject\HashedPassword;
use App\Infrastructure\Auth\JwtTokenService;
use Google\Client as GoogleClient;
use Psr\Log\LoggerInterface;

final class GoogleLoginUseCase
{
    public function __construct(
        private readonly UserRepositoryInterface $userRepository,
        private readonly JwtTokenService $jwtTokenService,
        private readonly GoogleClient $googleClient,
        private readonly LoggerInterface $logger,
    ) {}

    public function execute(GoogleLoginCommand $command): LoginResult
    {
        // Verify Google ID token
        $payload = $this->googleClient->verifyIdToken($command->idToken);

        if (!$payload) {
            throw new InvalidOAuthTokenException('Invalid Google ID token');
        }

        $googleId = $payload['sub'];
        $email = $payload['email'];
        $emailVerified = $payload['email_verified'] ?? false;
        $firstName = $payload['given_name'] ?? '';
        $lastName = $payload['family_name'] ?? '';

        // Find or create user
        $user = $this->userRepository->findByOAuthProvider('google', $googleId);

        if ($user === null) {
            // Check if user exists with this email
            $user = $this->userRepository->findByEmail(new Email($email));

            if ($user === null) {
                // Create new user
                $user = User::register(
                    id: UserId::generate(),
                    email: new Email($email),
                    password: HashedPassword::fromPlainPassword(bin2hex(random_bytes(32))), // Random password
                    firstName: $firstName,
                    lastName: $lastName
                );

                if ($emailVerified) {
                    $user->verifyEmail();
                }

                $this->userRepository->save($user);

                $this->logger->info('New user registered via Google OAuth', [
                    'user_id' => $user->getId()->toString(),
                    'email' => $email,
                ]);
            }

            // Link OAuth provider
            $user->linkOAuthProvider('google', $googleId);
            $this->userRepository->save($user);
        }

        // Generate tokens
        $accessToken = $this->jwtTokenService->generateAccessToken($user);
        $refreshToken = $this->jwtTokenService->generateRefreshToken($user);

        return new LoginResult(
            success: true,
            accessToken: $accessToken,
            refreshToken: $refreshToken,
            expiresIn: 3600,
            user: [
                'id' => $user->getId()->toString(),
                'email' => $user->getEmail()->toString(),
                'first_name' => $user->getFirstName(),
                'last_name' => $user->getLastName(),
                'roles' => $user->getRoles(),
            ]
        );
    }
}
```

## Authorization

### RBAC Implementation

```php
<?php
// src/Domain/User/Authorization/RoleHierarchy.php

declare(strict_types=1);

namespace App\Domain\User\Authorization;

final class RoleHierarchy
{
    private const HIERARCHY = [
        'ROLE_ADMIN' => [
            'ROLE_MANAGER',
            'ROLE_USER',
        ],
        'ROLE_MANAGER' => [
            'ROLE_USER',
        ],
        'ROLE_USER' => [],
    ];

    public function getReachableRoles(array $roles): array
    {
        $reachableRoles = [];

        foreach ($roles as $role) {
            $reachableRoles[] = $role;
            $reachableRoles = array_merge($reachableRoles, $this->getChildRoles($role));
        }

        return array_unique($reachableRoles);
    }

    private function getChildRoles(string $role): array
    {
        $children = self::HIERARCHY[$role] ?? [];
        $allChildren = [];

        foreach ($children as $child) {
            $allChildren[] = $child;
            $allChildren = array_merge($allChildren, $this->getChildRoles($child));
        }

        return $allChildren;
    }

    public function isGranted(array $userRoles, string $requiredRole): bool
    {
        $reachableRoles = $this->getReachableRoles($userRoles);
        return in_array($requiredRole, $reachableRoles, true);
    }
}

// src/Infrastructure/Security/AuthorizationService.php

declare(strict_types=1);

namespace App\Infrastructure\Security;

use App\Domain\User\User;
use App\Domain\User\Authorization\RoleHierarchy;
use App\Domain\User\Authorization\Permission;

final class AuthorizationService
{
    public function __construct(
        private readonly RoleHierarchy $roleHierarchy,
    ) {}

    public function canAccessResource(User $user, string $resource, string $action): bool
    {
        // Check role-based permissions
        $requiredRole = $this->getRequiredRole($resource, $action);

        if ($requiredRole && $this->roleHierarchy->isGranted($user->getRoles(), $requiredRole)) {
            return true;
        }

        // Check attribute-based permissions (ABAC)
        return $this->checkAttributeBasedAccess($user, $resource, $action);
    }

    private function getRequiredRole(string $resource, string $action): ?string
    {
        $permissions = [
            'workflows' => [
                'create' => 'ROLE_USER',
                'read' => 'ROLE_USER',
                'update' => 'ROLE_USER',
                'delete' => 'ROLE_USER',
                'execute' => 'ROLE_USER',
            ],
            'users' => [
                'create' => 'ROLE_ADMIN',
                'read' => 'ROLE_MANAGER',
                'update' => 'ROLE_MANAGER',
                'delete' => 'ROLE_ADMIN',
            ],
            'analytics' => [
                'read' => 'ROLE_MANAGER',
            ],
        ];

        return $permissions[$resource][$action] ?? null;
    }

    private function checkAttributeBasedAccess(User $user, string $resource, string $action): bool
    {
        // Attribute-Based Access Control logic
        // Example: User can only modify their own resources

        // This would be implemented based on specific business rules
        return false;
    }
}
```

## API Endpoints

### Registration

```php
<?php
// src/Infrastructure/Http/Controller/AuthController.php

declare(strict_types=1);

namespace App\Infrastructure\Http\Controller;

use App\Application\Auth\UseCase\RegisterUseCase;
use App\Application\Auth\UseCase\RegisterCommand;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;
use Symfony\Component\Validator\Validator\ValidatorInterface;

final class AuthController
{
    public function __construct(
        private readonly RegisterUseCase $registerUseCase,
        private readonly ValidatorInterface $validator,
    ) {}

    /**
     * Register a new user
     *
     * @Route("/api/v1/auth/register", methods={"POST"})
     */
    public function register(Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);

        // Validate input
        $errors = $this->validator->validate($data, [
            'email' => [
                new Assert\NotBlank(),
                new Assert\Email(),
            ],
            'password' => [
                new Assert\NotBlank(),
                new Assert\Length(['min' => 8]),
                new Assert\Regex([
                    'pattern' => '/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/',
                    'message' => 'Password must contain uppercase, lowercase, and numbers',
                ]),
            ],
            'first_name' => [
                new Assert\NotBlank(),
                new Assert\Length(['min' => 2, 'max' => 50]),
            ],
            'last_name' => [
                new Assert\NotBlank(),
                new Assert\Length(['min' => 2, 'max' => 50]),
            ],
        ]);

        if (count($errors) > 0) {
            return new JsonResponse([
                'error' => 'Validation failed',
                'details' => (string) $errors,
            ], Response::HTTP_BAD_REQUEST);
        }

        try {
            $command = new RegisterCommand(
                email: $data['email'],
                password: $data['password'],
                firstName: $data['first_name'],
                lastName: $data['last_name']
            );

            $result = $this->registerUseCase->execute($command);

            return new JsonResponse([
                'message' => 'User registered successfully',
                'user' => [
                    'id' => $result->userId,
                    'email' => $result->email,
                ],
            ], Response::HTTP_CREATED);

        } catch (\DomainException $e) {
            return new JsonResponse([
                'error' => $e->getMessage(),
            ], Response::HTTP_BAD_REQUEST);
        }
    }

    /**
     * Login
     *
     * @Route("/api/v1/auth/login", methods={"POST"})
     *
     * @OA\Post(
     *     path="/api/v1/auth/login",
     *     summary="User login",
     *     tags={"Authentication"},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"email", "password"},
     *             @OA\Property(property="email", type="string", format="email", example="user@example.com"),
     *             @OA\Property(property="password", type="string", format="password", example="Password123"),
     *             @OA\Property(property="mfa_token", type="string", example="123456", description="Required if MFA is enabled")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Login successful",
     *         @OA\JsonContent(
     *             @OA\Property(property="access_token", type="string"),
     *             @OA\Property(property="refresh_token", type="string"),
     *             @OA\Property(property="expires_in", type="integer", example=3600),
     *             @OA\Property(property="user", type="object")
     *         )
     *     ),
     *     @OA\Response(response=401, description="Invalid credentials"),
     *     @OA\Response(response=403, description="MFA required")
     * )
     */
    public function login(Request $request): JsonResponse
    {
        // Implementation similar to register
    }

    /**
     * Refresh token
     *
     * @Route("/api/v1/auth/refresh", methods={"POST"})
     */
    public function refresh(Request $request): JsonResponse
    {
        // Implementation for token refresh
    }

    /**
     * Logout
     *
     * @Route("/api/v1/auth/logout", methods={"POST"})
     */
    public function logout(Request $request): JsonResponse
    {
        // Implementation for logout (blacklist token)
    }

    /**
     * Get current user
     *
     * @Route("/api/v1/auth/me", methods={"GET"})
     */
    public function me(Request $request): JsonResponse
    {
        // Implementation to get current authenticated user
    }

    /**
     * Forgot password
     *
     * @Route("/api/v1/auth/forgot-password", methods={"POST"})
     */
    public function forgotPassword(Request $request): JsonResponse
    {
        // Implementation for password reset request
    }

    /**
     * Reset password
     *
     * @Route("/api/v1/auth/reset-password", methods={"POST"})
     */
    public function resetPassword(Request $request): JsonResponse
    {
        // Implementation for password reset
    }

    /**
     * Verify email
     *
     * @Route("/api/v1/auth/verify-email/{token}", methods={"GET"})
     */
    public function verifyEmail(string $token): JsonResponse
    {
        // Implementation for email verification
    }
}
```

## Database Schema

### Tables

```sql
-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email_verified_at TIMESTAMP,
    mfa_enabled BOOLEAN DEFAULT FALSE,
    mfa_secret VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,

    CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$')
);

CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_created_at ON users(created_at DESC);

-- User roles table
CREATE TABLE user_roles (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL,
    granted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    granted_by UUID REFERENCES users(id),

    UNIQUE(user_id, role)
);

CREATE INDEX idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX idx_user_roles_role ON user_roles(role);

-- OAuth providers table
CREATE TABLE oauth_providers (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(50) NOT NULL,
    provider_user_id VARCHAR(255) NOT NULL,
    access_token TEXT,
    refresh_token TEXT,
    expires_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(provider, provider_user_id)
);

CREATE INDEX idx_oauth_providers_user_id ON oauth_providers(user_id);
CREATE INDEX idx_oauth_providers_provider ON oauth_providers(provider, provider_user_id);

-- Password reset tokens
CREATE TABLE password_reset_tokens (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_password_reset_tokens_token ON password_reset_tokens(token) WHERE used_at IS NULL;
CREATE INDEX idx_password_reset_tokens_user_id ON password_reset_tokens(user_id);

-- Email verification tokens
CREATE TABLE email_verification_tokens (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    verified_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_email_verification_tokens_token ON email_verification_tokens(token);

-- Login history (for security auditing)
CREATE TABLE login_history (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ip_address INET NOT NULL,
    user_agent TEXT,
    successful BOOLEAN NOT NULL,
    failure_reason VARCHAR(255),
    mfa_used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_login_history_user_id ON login_history(user_id, created_at DESC);
CREATE INDEX idx_login_history_created_at ON login_history(created_at DESC);
CREATE INDEX idx_login_history_failed ON login_history(user_id, successful, created_at DESC) WHERE successful = FALSE;
```

## Security

### Security Measures

```yaml
security_measures:
  password_policy:
    min_length: 8
    require_uppercase: true
    require_lowercase: true
    require_numbers: true
    require_special_chars: false
    max_age_days: 90
    prevent_reuse: 5  # Last 5 passwords

  rate_limiting:
    login_attempts:
      limit: 5 attempts per 15 minutes
      lockout: 30 minutes

    registration:
      limit: 3 per hour per IP

    password_reset:
      limit: 3 per hour per email

  token_security:
    jwt_algorithm: HS256
    access_token_ttl: 3600s  # 1 hour
    refresh_token_ttl: 2592000s  # 30 days
    token_rotation: true
    blacklist_on_logout: true

  mfa:
    algorithm: TOTP (RFC 6238)
    digits: 6
    period: 30s
    window: 1  # Accept 1 period before/after

  session:
    storage: Redis
    ttl: 3600s
    regenerate_on_login: true
    destroy_on_logout: true

  brute_force_protection:
    failed_login_threshold: 5
    lockout_duration: 1800s  # 30 minutes
    progressive_delays: true
    ip_based_limiting: true
    captcha_after: 3 failed attempts
```

### Security Middleware

```php
<?php
// src/Infrastructure/Security/Middleware/RateLimitMiddleware.php

declare(strict_types=1);

namespace App\Infrastructure\Security\Middleware;

use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Event\RequestEvent;
use Psr\Cache\CacheItemPoolInterface;

final class RateLimitMiddleware
{
    private const LOGIN_LIMIT = 5;
    private const LOGIN_WINDOW = 900; // 15 minutes

    public function __construct(
        private readonly CacheItemPoolInterface $cache,
    ) {}

    public function onKernelRequest(RequestEvent $event): void
    {
        if (!$event->isMainRequest()) {
            return;
        }

        $request = $event->getRequest();

        // Only apply to login endpoint
        if ($request->getPathInfo() !== '/api/v1/auth/login') {
            return;
        }

        $ip = $request->getClientIp();
        $cacheKey = "rate_limit:login:{$ip}";

        $item = $this->cache->getItem($cacheKey);

        if ($item->isHit()) {
            $attempts = $item->get();

            if ($attempts >= self::LOGIN_LIMIT) {
                $event->setResponse(new JsonResponse([
                    'error' => 'Too many login attempts. Please try again later.',
                ], Response::HTTP_TOO_MANY_REQUESTS));
                return;
            }

            $item->set($attempts + 1);
        } else {
            $item->set(1);
            $item->expiresAfter(self::LOGIN_WINDOW);
        }

        $this->cache->save($item);
    }
}
```

## Implementation

### Complete Registration Flow

```php
<?php
// src/Application/Auth/UseCase/RegisterUseCase.php

declare(strict_types=1);

namespace App\Application\Auth\UseCase;

use App\Domain\User\Repository\UserRepositoryInterface;
use App\Domain\User\User;
use App\Domain\User\ValueObject\UserId;
use App\Domain\User\ValueObject\Email;
use App\Domain\User\ValueObject\HashedPassword;
use App\Infrastructure\Email\EmailService;
use App\Infrastructure\Event\EventPublisher;
use Psr\Log\LoggerInterface;

final class RegisterUseCase
{
    public function __construct(
        private readonly UserRepositoryInterface $userRepository,
        private readonly EmailService $emailService,
        private readonly EventPublisher $eventPublisher,
        private readonly LoggerInterface $logger,
    ) {}

    public function execute(RegisterCommand $command): RegisterResult
    {
        $email = new Email($command->email);

        // Check if user already exists
        if ($this->userRepository->findByEmail($email) !== null) {
            throw new \DomainException('User with this email already exists');
        }

        // Create user
        $user = User::register(
            id: UserId::generate(),
            email: $email,
            password: HashedPassword::fromPlainPassword($command->password),
            firstName: $command->firstName,
            lastName: $command->lastName
        );

        // Save user
        $this->userRepository->save($user);

        // Publish domain events
        foreach ($user->popEvents() as $event) {
            $this->eventPublisher->publish($event);
        }

        // Send verification email
        $this->emailService->sendEmailVerification($user);

        $this->logger->info('User registered successfully', [
            'user_id' => $user->getId()->toString(),
            'email' => $email->toString(),
        ]);

        return new RegisterResult(
            userId: $user->getId()->toString(),
            email: $email->toString()
        );
    }
}
```

## Conclusion

The Authentication Service provides:

- **Secure authentication** with JWT and OAuth2
- **Role-based authorization** with hierarchical roles
- **Multi-factor authentication** for enhanced security
- **Password management** with secure hashing
- **Rate limiting** for brute-force protection
- **Comprehensive audit logging** for security compliance

For integration details, see:
- [API Gateway Configuration](../03-infrastructure/03-api-gateway.md)
- [Security Best Practices](../02-security/01-security-overview.md)

For questions, contact the authentication team via #auth-team Slack channel.
