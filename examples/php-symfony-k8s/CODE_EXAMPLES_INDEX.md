# Code Examples Index

**Purpose**: Complete index of all code examples throughout the documentation, organized by category and use case.

**Last Updated**: 2025-01-07
**Total Examples**: 500+ across all documentation files
**Target Audience**: Developers and LLMs looking for specific code patterns

---

## 📋 Table of Contents

1. [Quick Reference: Most Common Patterns](#quick-reference-most-common-patterns)
2. [Domain-Driven Design Examples](#domain-driven-design-examples)
3. [Hexagonal Architecture Examples](#hexagonal-architecture-examples)
4. [PHP 8.3 Features Examples](#php-83-features-examples)
5. [Testing Examples](#testing-examples)
6. [Kubernetes & Infrastructure Examples](#kubernetes--infrastructure-examples)
7. [Security Examples](#security-examples)
8. [Service-Specific Examples](#service-specific-examples)
9. [Database Examples](#database-examples)
10. [Event-Driven Architecture Examples](#event-driven-architecture-examples)

---

## Quick Reference: Most Common Patterns

### Entity with Aggregate Root

**Location**: [01-architecture/04-domain-driven-design.md](01-architecture/04-domain-driven-design.md#entity-implementation)
**Use Case**: Creating domain entities with identity and business logic

```php
final class User
{
    private array $domainEvents = [];

    public function __construct(
        private readonly UserId $id,
        private Email $email,
        private string $passwordHash,
    ) {
        $this->domainEvents[] = new UserCreated($this->id, $this->email);
    }

    public static function create(Email $email, string $passwordHash): self
    {
        return new self(UserId::generate(), $email, $passwordHash);
    }

    public function changeEmail(Email $newEmail): void
    {
        $this->email = $newEmail;
        $this->domainEvents[] = new UserEmailChanged($this->id, $newEmail);
    }

    public function popDomainEvents(): array
    {
        $events = $this->domainEvents;
        $this->domainEvents = [];
        return $events;
    }
}
```

**Related Examples**:
- Value Object: [01-architecture/04-domain-driven-design.md](01-architecture/04-domain-driven-design.md#value-object-implementation)
- Domain Events: [01-architecture/04-domain-driven-design.md](01-architecture/04-domain-driven-design.md#domain-events)

---

### Value Object (Immutable)

**Location**: [01-architecture/04-domain-driven-design.md](01-architecture/04-domain-driven-design.md#value-object-implementation)
**Use Case**: Creating immutable value objects with validation

```php
final readonly class Email
{
    public function __construct(
        private string $value,
    ) {
        if (!filter_var($value, FILTER_VALIDATE_EMAIL)) {
            throw new \InvalidArgumentException("Invalid email: {$value}");
        }
    }

    public function value(): string
    {
        return $this->value;
    }

    public function equals(Email $other): bool
    {
        return $this->value === $other->value;
    }

    public function __toString(): string
    {
        return $this->value;
    }
}
```

**Related Examples**:
- UserId Value Object: [08-services/02-authentication-service.md](08-services/02-authentication-service.md#userid-value-object)
- WorkflowState Value Object: [08-services/03-workflow-engine.md](08-services/03-workflow-engine.md#workflow-state)

---

### Use Case (Command Handler)

**Location**: [01-architecture/03-hexagonal-architecture.md](01-architecture/03-hexagonal-architecture.md#application-layer-use-cases)
**Use Case**: Implementing use cases in application layer

```php
final readonly class CreateUser
{
    public function __construct(
        private UserRepository $userRepository,
        private PasswordHasher $passwordHasher,
        private EventDispatcher $eventDispatcher,
    ) {}

    public function execute(CreateUserCommand $command): User
    {
        $email = new Email($command->email);

        if ($this->userRepository->findByEmail($email) !== null) {
            throw new UserAlreadyExistsException("User with email {$email} already exists");
        }

        $passwordHash = $this->passwordHasher->hash($command->password);
        $user = User::create($email, $passwordHash);

        $this->userRepository->save($user);

        // Dispatch domain events
        foreach ($user->popDomainEvents() as $event) {
            $this->eventDispatcher->dispatch($event);
        }

        return $user;
    }
}
```

**Related Examples**:
- Query Handler: [01-architecture/03-hexagonal-architecture.md](01-architecture/03-hexagonal-architecture.md#query-handlers)
- Command Bus: [04-development/03-symfony-best-practices.md](04-development/03-symfony-best-practices.md#symfony-messenger)

---

### Repository Interface (Port)

**Location**: [01-architecture/03-hexagonal-architecture.md](01-architecture/03-hexagonal-architecture.md#repository-ports)
**Use Case**: Defining repository interfaces in domain layer

```php
interface UserRepository
{
    public function save(User $user): void;
    public function findById(UserId $id): ?User;
    public function findByEmail(Email $email): ?User;
    public function remove(User $user): void;
}
```

**Related Examples**:
- Repository Implementation (Adapter): [01-architecture/03-hexagonal-architecture.md](01-architecture/03-hexagonal-architecture.md#repository-implementation)

---

### Repository Implementation (Adapter - Doctrine)

**Location**: [01-architecture/03-hexagonal-architecture.md](01-architecture/03-hexagonal-architecture.md#repository-implementation)
**Use Case**: Implementing repositories with Doctrine ORM

```php
final readonly class DoctrineUserRepository implements UserRepository
{
    public function __construct(
        private EntityManagerInterface $entityManager,
    ) {}

    public function save(User $user): void
    {
        $this->entityManager->persist($user);
        $this->entityManager->flush();
    }

    public function findById(UserId $id): ?User
    {
        return $this->entityManager->find(User::class, $id->value());
    }

    public function findByEmail(Email $email): ?User
    {
        return $this->entityManager->getRepository(User::class)
            ->findOneBy(['email.value' => $email->value()]);
    }

    public function remove(User $user): void
    {
        $this->entityManager->remove($user);
        $this->entityManager->flush();
    }
}
```

**Related Examples**:
- Custom Doctrine Query: [04-development/06-database-guidelines.md](04-development/06-database-guidelines.md#custom-queries)

---

## Domain-Driven Design Examples

### Strategic DDD

#### Bounded Context Mapping

**Location**: [01-architecture/04-domain-driven-design.md](01-architecture/04-domain-driven-design.md#bounded-contexts)

**7 Bounded Contexts**:
1. **Authentication Context** - User identity, roles, permissions
2. **Workflow Context** - Workflow orchestration, state machine
3. **Agent Context** - LLM agents, prompt templates, executions
4. **Validation Context** - Rules, validators, scoring
5. **Notification Context** - Multi-channel messaging
6. **Audit Context** - Compliance logging, tamper detection
7. **Integration Context** - External system integrations

**Context Map Example**:
```
[Authentication Context] --Customer/Supplier--> [Workflow Context]
                         (provides User identity)

[Workflow Context] --Orchestrator--> [Agent Context]
                                 \--> [Validation Context]
                                 \--> [Notification Context]

[All Contexts] --Conformist--> [Audit Context]
               (all must log to audit)
```

---

### Tactical DDD

#### Aggregate Example (Complex)

**Location**: [08-services/03-workflow-engine.md](08-services/03-workflow-engine.md#workflow-aggregate)

```php
final class Workflow
{
    private WorkflowId $id;
    private UserId $userId;
    private WorkflowDefinition $definition;
    private WorkflowState $state;
    /** @var WorkflowStep[] */
    private array $steps = [];
    private array $domainEvents = [];

    public function start(): void
    {
        if (!$this->state->equals(WorkflowState::draft())) {
            throw new InvalidWorkflowStateException("Cannot start workflow in state {$this->state}");
        }

        $this->state = WorkflowState::running();
        $this->domainEvents[] = new WorkflowStarted($this->id, $this->userId);
    }

    public function completeStep(WorkflowStepId $stepId, mixed $result): void
    {
        $step = $this->findStep($stepId);
        $step->complete($result);

        $this->domainEvents[] = new WorkflowStepCompleted($this->id, $stepId, $result);

        // Check if all steps completed
        if ($this->allStepsCompleted()) {
            $this->complete();
        }
    }

    public function fail(string $reason): void
    {
        $this->state = WorkflowState::failed();
        $this->domainEvents[] = new WorkflowFailed($this->id, $reason);

        // Trigger compensation (Saga pattern)
        $this->compensate();
    }

    private function compensate(): void
    {
        foreach (array_reverse($this->steps) as $step) {
            if ($step->isCompleted()) {
                $step->compensate();
                $this->domainEvents[] = new WorkflowStepCompensated($this->id, $step->id());
            }
        }
    }
}
```

**Related**: [01-architecture/06-communication-patterns.md](01-architecture/06-communication-patterns.md#saga-pattern)

---

#### Domain Service Example

**Location**: [01-architecture/04-domain-driven-design.md](01-architecture/04-domain-driven-design.md#domain-services)

```php
final readonly class TokenCalculator
{
    public function calculateCost(TokenUsage $usage, Provider $provider): Money
    {
        return match ($provider) {
            Provider::OpenAI => $this->calculateOpenAICost($usage),
            Provider::Anthropic => $this->calculateAnthropicCost($usage),
            Provider::GoogleAI => $this->calculateGoogleAICost($usage),
            Provider::AzureOpenAI => $this->calculateAzureCost($usage),
        };
    }

    private function calculateOpenAICost(TokenUsage $usage): Money
    {
        // GPT-4 pricing: $0.03 per 1K input tokens, $0.06 per 1K output tokens
        $inputCost = ($usage->inputTokens() / 1000) * 0.03;
        $outputCost = ($usage->outputTokens() / 1000) * 0.06;

        return Money::fromFloat($inputCost + $outputCost, 'USD');
    }

    // ... other providers
}
```

**Related**: [08-services/04-agent-manager.md](08-services/04-agent-manager.md#token-calculation)

---

## Hexagonal Architecture Examples

### Complete Service Structure

**Location**: [01-architecture/03-hexagonal-architecture.md](01-architecture/03-hexagonal-architecture.md#directory-structure)

```
src/
├── Domain/                          # PURE business logic (no infra dependencies)
│   ├── Entity/
│   │   ├── User.php                # Aggregate root
│   │   ├── Role.php
│   │   └── Permission.php
│   ├── ValueObject/
│   │   ├── UserId.php
│   │   ├── Email.php
│   │   └── PasswordHash.php
│   ├── Event/
│   │   ├── UserCreated.php
│   │   ├── UserLoggedIn.php
│   │   └── UserEmailChanged.php
│   ├── Service/
│   │   └── PasswordHasher.php      # Domain service interface
│   ├── Repository/
│   │   └── UserRepository.php      # Repository interface (port)
│   └── Exception/
│       ├── UserNotFoundException.php
│       └── UserAlreadyExistsException.php
│
├── Application/                     # Use cases and orchestration
│   ├── UseCase/
│   │   ├── CreateUser.php          # Command handler
│   │   ├── LoginUser.php
│   │   └── ChangeUserEmail.php
│   ├── Query/
│   │   ├── GetUser.php             # Query handler
│   │   └── ListUsers.php
│   ├── DTO/
│   │   ├── CreateUserCommand.php
│   │   ├── LoginUserCommand.php
│   │   └── UserDTO.php
│   └── Service/
│       └── UserService.php         # Application service
│
└── Infrastructure/                  # Technical implementation (adapters)
    ├── Persistence/
    │   ├── Doctrine/
    │   │   ├── DoctrineUserRepository.php    # Repository implementation
    │   │   ├── Mapping/
    │   │   │   ├── User.orm.xml
    │   │   │   └── Role.orm.xml
    │   │   └── Type/
    │   │       ├── UserIdType.php
    │   │       └── EmailType.php
    │   └── Migrations/
    │       └── Version20250107120000.php
    ├── HTTP/
    │   ├── Controller/
    │   │   ├── UserController.php            # REST API controller
    │   │   └── AuthController.php
    │   └── Request/
    │       ├── CreateUserRequest.php
    │       └── LoginRequest.php
    ├── Messaging/
    │   ├── RabbitMQ/
    │   │   ├── UserEventPublisher.php        # Event publisher
    │   │   └── UserEventConsumer.php
    │   └── Event/
    │       └── UserCreatedMessage.php
    ├── Security/
    │   ├── Symfony/
    │   │   ├── SymfonyPasswordHasher.php     # Password hasher implementation
    │   │   └── SymfonyUserProvider.php
    │   └── JWT/
    │       └── JWTTokenManager.php
    └── Configuration/
        ├── services.yaml
        ├── routes.yaml
        └── doctrine.yaml
```

---

### Dependency Injection (Symfony)

**Location**: [04-development/03-symfony-best-practices.md](04-development/03-symfony-best-practices.md#dependency-injection)

```yaml
# config/services.yaml
services:
    _defaults:
        autowire: true
        autoconfigure: true

    # Domain layer has NO dependencies on infrastructure
    App\Domain\:
        resource: '../src/Domain/'

    # Application layer depends only on domain
    App\Application\:
        resource: '../src/Application/'

    # Infrastructure layer provides implementations
    App\Infrastructure\:
        resource: '../src/Infrastructure/'
        exclude:
            - '../src/Infrastructure/Persistence/Doctrine/Mapping/'
            - '../src/Infrastructure/Persistence/Migrations/'

    # Explicit bindings for interfaces
    App\Domain\Repository\UserRepository:
        class: App\Infrastructure\Persistence\Doctrine\DoctrineUserRepository

    App\Domain\Service\PasswordHasher:
        class: App\Infrastructure\Security\Symfony\SymfonyPasswordHasher
```

---

## PHP 8.3 Features Examples

### Readonly Classes

**Location**: [04-development/02-coding-guidelines-php.md](04-development/02-coding-guidelines-php.md#readonly-classes)

```php
readonly class UserDTO
{
    public function __construct(
        public string $id,
        public string $email,
        public array $roles,
    ) {}
}

// Usage
$userDTO = new UserDTO($user->id(), $user->email(), $user->roles());
// $userDTO->email = 'new@email.com'; // Error: Cannot modify readonly property
```

---

### Enums for Value Objects

**Location**: [04-development/02-coding-guidelines-php.md](04-development/02-coding-guidelines-php.md#enums)

```php
enum WorkflowState: string
{
    case DRAFT = 'draft';
    case RUNNING = 'running';
    case PAUSED = 'paused';
    case COMPLETED = 'completed';
    case FAILED = 'failed';

    public function canTransitionTo(WorkflowState $newState): bool
    {
        return match ($this) {
            self::DRAFT => $newState === self::RUNNING,
            self::RUNNING => in_array($newState, [self::PAUSED, self::COMPLETED, self::FAILED]),
            self::PAUSED => in_array($newState, [self::RUNNING, self::FAILED]),
            self::COMPLETED, self::FAILED => false,
        };
    }

    public function isTerminal(): bool
    {
        return in_array($this, [self::COMPLETED, self::FAILED]);
    }
}
```

---

### Never Return Type

**Location**: [04-development/02-coding-guidelines-php.md](04-development/02-coding-guidelines-php.md#never-type)

```php
function throwUserNotFoundException(UserId $id): never
{
    throw new UserNotFoundException("User {$id->value()} not found");
}

// Usage
$user = $this->userRepository->findById($userId)
    ?? throwUserNotFoundException($userId);
```

---

### DNF Types (Disjunctive Normal Form)

**Location**: [04-development/02-coding-guidelines-php.md](04-development/02-coding-guidelines-php.md#dnf-types)

```php
function processResult((SuccessResult&Serializable)|(ErrorResult&Serializable) $result): array
{
    return $result->serialize();
}
```

---

## Testing Examples

### Unit Test (Domain Layer)

**Location**: [04-development/04-testing-strategy.md](04-development/04-testing-strategy.md#unit-testing)

```php
final class UserTest extends TestCase
{
    public function testCreateUser(): void
    {
        $email = new Email('user@example.com');
        $user = User::create($email, 'hashed_password');

        $this->assertInstanceOf(UserId::class, $user->id());
        $this->assertEquals($email, $user->email());
        $this->assertCount(1, $user->popDomainEvents());
    }

    public function testChangeEmail(): void
    {
        $user = User::create(new Email('old@example.com'), 'hash');
        $newEmail = new Email('new@example.com');

        $user->changeEmail($newEmail);

        $this->assertEquals($newEmail, $user->email());
        $events = $user->popDomainEvents();
        $this->assertCount(2, $events); // UserCreated + UserEmailChanged
        $this->assertInstanceOf(UserEmailChanged::class, $events[1]);
    }

    public function testInvalidEmail(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        new Email('invalid-email');
    }
}
```

---

### Integration Test (Use Case)

**Location**: [04-development/04-testing-strategy.md](04-development/04-testing-strategy.md#integration-testing)

```php
final class CreateUserTest extends KernelTestCase
{
    private CreateUser $useCase;
    private UserRepository $userRepository;

    protected function setUp(): void
    {
        self::bootKernel();
        $container = self::getContainer();

        $this->useCase = $container->get(CreateUser::class);
        $this->userRepository = $container->get(UserRepository::class);
    }

    public function testExecute(): void
    {
        $command = new CreateUserCommand('user@example.com', 'password123');

        $user = $this->useCase->execute($command);

        $this->assertNotNull($user->id());
        $this->assertEquals('user@example.com', $user->email()->value());

        // Verify persistence
        $savedUser = $this->userRepository->findById($user->id());
        $this->assertNotNull($savedUser);
    }

    public function testDuplicateEmailThrowsException(): void
    {
        $command = new CreateUserCommand('duplicate@example.com', 'password123');
        $this->useCase->execute($command);

        $this->expectException(UserAlreadyExistsException::class);
        $this->useCase->execute($command); // Duplicate email
    }
}
```

---

### E2E Test (Behat)

**Location**: [04-development/04-testing-strategy.md](04-development/04-testing-strategy.md#e2e-testing)

```gherkin
# tests/E2E/Features/authentication.feature
Feature: User Authentication
  As a user
  I want to register and login
  So that I can access the system

  Scenario: Successful registration
    Given I am not authenticated
    When I register with email "user@example.com" and password "SecurePass123!"
    Then I should receive a success response
    And a user should exist with email "user@example.com"

  Scenario: Successful login
    Given a user exists with email "user@example.com" and password "SecurePass123!"
    When I login with email "user@example.com" and password "SecurePass123!"
    Then I should receive an access token
    And the token should be valid

  Scenario: Failed login with invalid credentials
    Given a user exists with email "user@example.com" and password "SecurePass123!"
    When I login with email "user@example.com" and password "WrongPassword"
    Then I should receive an error response
    And the error should be "Invalid credentials"
```

**Context Implementation**:
```php
final class AuthenticationContext implements Context
{
    public function __construct(
        private HttpClient $client,
        private UserRepository $userRepository,
    ) {}

    #[When('I register with email :email and password :password')]
    public function iRegisterWith(string $email, string $password): void
    {
        $this->response = $this->client->post('/auth/register', [
            'json' => ['email' => $email, 'password' => $password],
        ]);
    }

    #[Then('a user should exist with email :email')]
    public function aUserShouldExist(string $email): void
    {
        $user = $this->userRepository->findByEmail(new Email($email));
        Assert::notNull($user, "User with email {$email} should exist");
    }
}
```

---

### Mutation Testing

**Location**: [04-development/04-testing-strategy.md](04-development/04-testing-strategy.md#mutation-testing)

```bash
# infection.json.dist
{
    "source": {
        "directories": ["src/Domain", "src/Application"]
    },
    "logs": {
        "text": "build/infection.log"
    },
    "mutators": {
        "@default": true
    },
    "minMsi": 70,
    "minCoveredMsi": 80
}
```

**Run**:
```bash
vendor/bin/infection --threads=4
```

---

## Kubernetes & Infrastructure Examples

### Deployment Manifest

**Location**: [03-infrastructure/02-kubernetes-architecture.md](03-infrastructure/02-kubernetes-architecture.md#deployment-manifests)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: authentication-service
  namespace: production
  labels:
    app: authentication-service
    version: stable
spec:
  replicas: 3
  selector:
    matchLabels:
      app: authentication-service
      version: stable
  template:
    metadata:
      labels:
        app: authentication-service
        version: stable
        monitoring: "true"  # For ServiceMonitor
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "authentication-service"
        vault.hashicorp.com/agent-inject-secret-database: "database/creds/authentication"
        vault.hashicorp.com/agent-inject-secret-jwt: "secret/data/authentication/jwt"
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: authentication-service
      containers:
        - name: app
          image: registry.example.com/ai-workflow/authentication:v1.0.0
          ports:
            - name: http
              containerPort: 8000
            - name: metrics
              containerPort: 9090
          env:
            - name: APP_ENV
              value: "production"
            - name: DATABASE_URL
              value: "file:///vault/secrets/database"
            - name: JWT_SECRET_KEY
              value: "file:///vault/secrets/jwt"
          resources:
            requests:
              memory: "256Mi"
              cpu: "200m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /ready
              port: 8000
            initialDelaySeconds: 10
            periodSeconds: 5
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
```

---

### Istio VirtualService

**Location**: [03-infrastructure/03-service-mesh.md](03-infrastructure/03-service-mesh.md#virtualservice)

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: authentication-service
  namespace: production
spec:
  hosts:
    - authentication-service
  http:
    - match:
        - headers:
            x-canary:
              exact: "true"
      route:
        - destination:
            host: authentication-service
            subset: canary
      timeout: 10s
      retries:
        attempts: 3
        perTryTimeout: 3s
        retryOn: "5xx,reset,connect-failure,refused-stream"
    - route:
        - destination:
            host: authentication-service
            subset: stable
          weight: 90
        - destination:
            host: authentication-service
            subset: canary
          weight: 10
      timeout: 10s
      retries:
        attempts: 3
        perTryTimeout: 3s
```

---

### ArgoCD Application

**Location**: [06-cicd/03-gitops-workflow.md](06-cicd/03-gitops-workflow.md#argocd-application)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: authentication-service
  namespace: argocd
spec:
  project: ai-workflow-platform
  source:
    repoURL: https://github.com/your-org/ai-workflow-platform
    targetRevision: main
    path: infrastructure/kubernetes/services/authentication
    helm:
      valueFiles:
        - values-production.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=false
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas  # Ignore HPA-managed replicas
```

---

## Security Examples

### OAuth2 Client Credentials Flow

**Location**: [02-security/03-authentication-authorization.md](02-security/03-authentication-authorization.md#client-credentials-flow)

```php
final readonly class OAuth2TokenGenerator
{
    public function __construct(
        private ClientRepository $clientRepository,
        private JWTEncoder $jwtEncoder,
    ) {}

    public function generateClientCredentialsToken(
        string $clientId,
        string $clientSecret,
        array $scopes,
    ): AccessToken {
        $client = $this->clientRepository->findById($clientId)
            ?? throw new InvalidClientException("Client {$clientId} not found");

        if (!$client->verifySecret($clientSecret)) {
            throw new InvalidClientException("Invalid client secret");
        }

        if (!$client->hasScopes($scopes)) {
            throw new InsufficientScopesException("Client does not have required scopes");
        }

        $payload = [
            'iss' => 'https://auth.example.com',
            'sub' => $clientId,
            'aud' => 'https://api.example.com',
            'exp' => time() + 3600,
            'iat' => time(),
            'scope' => implode(' ', $scopes),
            'token_type' => 'Bearer',
        ];

        $jwt = $this->jwtEncoder->encode($payload);

        return new AccessToken($jwt, 3600, $scopes);
    }
}
```

---

### JWT Validation

**Location**: [02-security/03-authentication-authorization.md](02-security/03-authentication-authorization.md#jwt-validation)

```php
final readonly class JWTValidator
{
    public function __construct(
        private JWTDecoder $jwtDecoder,
        private string $issuer,
        private string $audience,
    ) {}

    public function validate(string $jwt): TokenPayload
    {
        try {
            $payload = $this->jwtDecoder->decode($jwt);
        } catch (DecodeException $e) {
            throw new InvalidTokenException("Invalid JWT format", previous: $e);
        }

        // Verify issuer
        if ($payload['iss'] !== $this->issuer) {
            throw new InvalidTokenException("Invalid issuer: {$payload['iss']}");
        }

        // Verify audience
        if ($payload['aud'] !== $this->audience) {
            throw new InvalidTokenException("Invalid audience: {$payload['aud']}");
        }

        // Verify expiration
        if ($payload['exp'] < time()) {
            throw new TokenExpiredException("Token expired");
        }

        // Verify not before
        if (isset($payload['nbf']) && $payload['nbf'] > time()) {
            throw new TokenNotYetValidException("Token not yet valid");
        }

        return new TokenPayload($payload);
    }
}
```

---

### Vault Dynamic Database Credentials

**Location**: [02-security/04-secrets-management.md](02-security/04-secrets-management.md#dynamic-secrets)

```bash
# Configure PostgreSQL secrets engine
vault write database/config/postgresql \
  plugin_name=postgresql-database-plugin \
  allowed_roles="*" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/postgres" \
  username="vault" \
  password="vault-password"

# Create role with limited TTL
vault write database/roles/authentication-service \
  db_name=postgresql \
  creation_statements="CREATE USER \"{{name}}\" WITH PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

# Generate credentials (automatically rotated)
vault read database/creds/authentication-service
# Key              Value
# lease_id         database/creds/authentication-service/abc123
# lease_duration   1h
# username         v-auth-service-abc123
# password         A1B2C3D4E5F6G7H8
```

---

## Service-Specific Examples

### Authentication Service: Complete Login Flow

**Location**: [08-services/02-authentication-service.md](08-services/02-authentication-service.md#login-use-case)

```php
final readonly class LoginUser
{
    public function __construct(
        private UserRepository $userRepository,
        private PasswordHasher $passwordHasher,
        private JWTTokenGenerator $tokenGenerator,
        private EventDispatcher $eventDispatcher,
    ) {}

    public function execute(LoginUserCommand $command): LoginResult
    {
        $email = new Email($command->email);
        $user = $this->userRepository->findByEmail($email)
            ?? throw new InvalidCredentialsException("Invalid credentials");

        if (!$this->passwordHasher->verify($command->password, $user->passwordHash())) {
            throw new InvalidCredentialsException("Invalid credentials");
        }

        if (!$user->isActive()) {
            throw new UserNotActiveException("User account is not active");
        }

        $accessToken = $this->tokenGenerator->generate($user, TokenType::Access);
        $refreshToken = $this->tokenGenerator->generate($user, TokenType::Refresh);

        $user->recordLogin();
        $this->userRepository->save($user);

        $this->eventDispatcher->dispatch(new UserLoggedIn($user->id(), $user->email()));

        return new LoginResult($accessToken, $refreshToken, $user->toDTO());
    }
}
```

---

### Workflow Engine: State Machine

**Location**: [08-services/03-workflow-engine.md](08-services/03-workflow-engine.md#state-machine)

```php
final readonly class WorkflowStateMachine
{
    public function transition(Workflow $workflow, WorkflowState $newState): void
    {
        $currentState = $workflow->state();

        if (!$this->canTransition($currentState, $newState)) {
            throw new InvalidStateTransitionException(
                "Cannot transition from {$currentState->value} to {$newState->value}"
            );
        }

        $workflow->setState($newState);
    }

    private function canTransition(WorkflowState $from, WorkflowState $to): bool
    {
        $allowedTransitions = [
            WorkflowState::DRAFT => [WorkflowState::RUNNING],
            WorkflowState::RUNNING => [WorkflowState::PAUSED, WorkflowState::COMPLETED, WorkflowState::FAILED],
            WorkflowState::PAUSED => [WorkflowState::RUNNING, WorkflowState::CANCELLED],
            WorkflowState::COMPLETED => [], // Terminal state
            WorkflowState::FAILED => [WorkflowState::DRAFT], // Allow retry from draft
            WorkflowState::CANCELLED => [], // Terminal state
        ];

        return in_array($to, $allowedTransitions[$from] ?? []);
    }
}
```

---

### Agent Manager: Multi-Provider Abstraction

**Location**: [08-services/04-agent-manager.md](08-services/04-agent-manager.md#provider-abstraction)

```php
interface LLMProvider
{
    public function execute(AgentExecution $execution): AgentResult;
    public function supports(Provider $provider): bool;
}

final readonly class OpenAIProvider implements LLMProvider
{
    public function __construct(
        private HttpClient $httpClient,
        private string $apiKey,
    ) {}

    public function execute(AgentExecution $execution): AgentResult
    {
        $response = $this->httpClient->post('https://api.openai.com/v1/chat/completions', [
            'headers' => ['Authorization' => "Bearer {$this->apiKey}"],
            'json' => [
                'model' => $execution->modelName(),
                'messages' => $execution->messages(),
                'temperature' => $execution->temperature(),
                'max_tokens' => $execution->maxTokens(),
            ],
        ]);

        $data = $response->toArray();

        return new AgentResult(
            content: $data['choices'][0]['message']['content'],
            tokenUsage: new TokenUsage(
                inputTokens: $data['usage']['prompt_tokens'],
                outputTokens: $data['usage']['completion_tokens'],
            ),
            provider: Provider::OpenAI,
            model: $data['model'],
        );
    }

    public function supports(Provider $provider): bool
    {
        return $provider === Provider::OpenAI || $provider === Provider::AzureOpenAI;
    }
}
```

---

## Database Examples

### PostgreSQL Schema (Authentication Service)

**Location**: [08-services/02-authentication-service.md](08-services/02-authentication-service.md#database-schema)

```sql
-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMP
);

-- Index for email lookups
CREATE INDEX idx_users_email ON users(email);

-- Index for active users
CREATE INDEX idx_users_is_active ON users(is_active) WHERE is_active = TRUE;

-- Roles table
CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Permissions table
CREATE TABLE permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    resource VARCHAR(50) NOT NULL,
    action VARCHAR(50) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- User-Role junction table
CREATE TABLE user_roles (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, role_id)
);

CREATE INDEX idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX idx_user_roles_role_id ON user_roles(role_id);

-- Role-Permission junction table
CREATE TABLE role_permissions (
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    granted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (role_id, permission_id)
);

CREATE INDEX idx_role_permissions_role_id ON role_permissions(role_id);
```

---

### Database Migration (Doctrine)

**Location**: [04-development/06-database-guidelines.md](04-development/06-database-guidelines.md#migrations)

```php
final class Version20250107120000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Create users, roles, and permissions tables';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('CREATE TABLE users (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            email VARCHAR(255) NOT NULL UNIQUE,
            password_hash VARCHAR(255) NOT NULL,
            is_active BOOLEAN NOT NULL DEFAULT TRUE,
            created_at TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
            last_login_at TIMESTAMP
        )');

        $this->addSql('CREATE INDEX idx_users_email ON users(email)');
        $this->addSql('CREATE INDEX idx_users_is_active ON users(is_active) WHERE is_active = TRUE');

        // ... additional tables
    }

    public function down(Schema $schema): void
    {
        $this->addSql('DROP TABLE user_roles');
        $this->addSql('DROP TABLE role_permissions');
        $this->addSql('DROP TABLE permissions');
        $this->addSql('DROP TABLE roles');
        $this->addSql('DROP TABLE users');
    }
}
```

---

### Partitioning (Audit Logs Time-Series)

**Location**: [04-development/06-database-guidelines.md](04-development/06-database-guidelines.md#partitioning)

```sql
-- Create partitioned table
CREATE TABLE audit_events (
    id BIGSERIAL NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    user_id UUID,
    resource VARCHAR(100),
    action VARCHAR(50),
    data JSONB,
    ip_address INET,
    user_agent TEXT,
    checksum VARCHAR(64) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Create partitions (monthly)
CREATE TABLE audit_events_2025_01 PARTITION OF audit_events
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE audit_events_2025_02 PARTITION OF audit_events
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Indexes on each partition (automatically inherited)
CREATE INDEX idx_audit_events_user_id ON audit_events(user_id);
CREATE INDEX idx_audit_events_event_type ON audit_events(event_type);
CREATE INDEX idx_audit_events_created_at ON audit_events(created_at);

-- Automate partition creation with pg_partman
CREATE EXTENSION pg_partman;

SELECT partman.create_parent(
    p_parent_table => 'public.audit_events',
    p_control => 'created_at',
    p_type => 'native',
    p_interval => '1 month',
    p_premake => 3
);
```

---

## Event-Driven Architecture Examples

### Domain Event

**Location**: [01-architecture/06-communication-patterns.md](01-architecture/06-communication-patterns.md#domain-events)

```php
final readonly class WorkflowCompleted implements DomainEvent
{
    public function __construct(
        public WorkflowId $workflowId,
        public UserId $userId,
        public mixed $result,
        public \DateTimeImmutable $occurredAt = new \DateTimeImmutable(),
    ) {}

    public function eventName(): string
    {
        return 'workflow.completed';
    }

    public function toArray(): array
    {
        return [
            'workflow_id' => $this->workflowId->value(),
            'user_id' => $this->userId->value(),
            'result' => $this->result,
            'occurred_at' => $this->occurredAt->format(\DateTimeInterface::RFC3339),
        ];
    }
}
```

---

### Event Publisher (RabbitMQ)

**Location**: [03-infrastructure/06-message-queue.md](03-infrastructure/06-message-queue.md#event-publisher)

```php
final readonly class RabbitMQEventPublisher implements EventPublisher
{
    public function __construct(
        private AMQPStreamConnection $connection,
        private string $exchangeName = 'domain_events',
    ) {}

    public function publish(DomainEvent $event): void
    {
        $channel = $this->connection->channel();

        // Declare exchange (idempotent)
        $channel->exchange_declare(
            exchange: $this->exchangeName,
            type: AMQPExchangeType::TOPIC,
            passive: false,
            durable: true,
            auto_delete: false,
        );

        // Create message
        $message = new AMQPMessage(
            body: json_encode($event->toArray(), JSON_THROW_ON_ERROR),
            properties: [
                'content_type' => 'application/json',
                'delivery_mode' => AMQPMessage::DELIVERY_MODE_PERSISTENT,
                'timestamp' => $event->occurredAt()->getTimestamp(),
                'message_id' => Uuid::uuid4()->toString(),
                'type' => $event->eventName(),
            ],
        );

        // Publish with routing key
        $channel->basic_publish(
            msg: $message,
            exchange: $this->exchangeName,
            routing_key: $event->eventName(),
        );

        $channel->close();
    }
}
```

---

### Event Consumer (RabbitMQ)

**Location**: [03-infrastructure/06-message-queue.md](03-infrastructure/06-message-queue.md#event-consumer)

```php
final readonly class WorkflowEventConsumer
{
    public function __construct(
        private AMQPStreamConnection $connection,
        private NotificationService $notificationService,
        private string $queueName = 'workflow_notifications',
    ) {}

    public function consume(): void
    {
        $channel = $this->connection->channel();

        // Declare queue
        $channel->queue_declare(
            queue: $this->queueName,
            passive: false,
            durable: true,
            exclusive: false,
            auto_delete: false,
        );

        // Bind to exchange
        $channel->queue_bind(
            queue: $this->queueName,
            exchange: 'domain_events',
            routing_key: 'workflow.*', // Listen to all workflow events
        );

        // Set QoS (prefetch 1 message at a time)
        $channel->basic_qos(
            prefetch_size: 0,
            prefetch_count: 1,
            a_global: false,
        );

        // Define callback
        $callback = function (AMQPMessage $message) {
            try {
                $data = json_decode($message->body, true, 512, JSON_THROW_ON_ERROR);
                $eventType = $message->get('type');

                if ($eventType === 'workflow.completed') {
                    $this->handleWorkflowCompleted($data);
                } elseif ($eventType === 'workflow.failed') {
                    $this->handleWorkflowFailed($data);
                }

                // Acknowledge message
                $message->ack();
            } catch (\Throwable $e) {
                // Negative acknowledge (requeue)
                $message->nack(requeue: true);
                throw $e;
            }
        };

        // Start consuming
        $channel->basic_consume(
            queue: $this->queueName,
            consumer_tag: '',
            no_local: false,
            no_ack: false,
            exclusive: false,
            nowait: false,
            callback: $callback,
        );

        while ($channel->is_consuming()) {
            $channel->wait();
        }
    }

    private function handleWorkflowCompleted(array $data): void
    {
        $this->notificationService->sendNotification(
            userId: $data['user_id'],
            channel: NotificationChannel::Email,
            template: 'workflow_completed',
            context: $data,
        );
    }

    private function handleWorkflowFailed(array $data): void
    {
        $this->notificationService->sendNotification(
            userId: $data['user_id'],
            channel: NotificationChannel::Email,
            template: 'workflow_failed',
            context: $data,
        );
    }
}
```

---

## Summary: Code Examples by Category

| Category | Count | Primary Location |
|----------|-------|------------------|
| **DDD Patterns** | 50+ | [01-architecture/04-domain-driven-design.md](01-architecture/04-domain-driven-design.md) |
| **Hexagonal Architecture** | 40+ | [01-architecture/03-hexagonal-architecture.md](01-architecture/03-hexagonal-architecture.md) |
| **PHP 8.3 Features** | 30+ | [04-development/02-coding-guidelines-php.md](04-development/02-coding-guidelines-php.md) |
| **Testing** | 100+ | [04-development/04-testing-strategy.md](04-development/04-testing-strategy.md) |
| **Kubernetes** | 60+ | [03-infrastructure/02-kubernetes-architecture.md](03-infrastructure/02-kubernetes-architecture.md) |
| **Istio Service Mesh** | 40+ | [03-infrastructure/03-service-mesh.md](03-infrastructure/03-service-mesh.md) |
| **Security** | 50+ | [02-security/](02-security/) (all files) |
| **Database** | 40+ | [04-development/06-database-guidelines.md](04-development/06-database-guidelines.md) |
| **Events & Messaging** | 30+ | [03-infrastructure/06-message-queue.md](03-infrastructure/06-message-queue.md) |
| **Service Implementation** | 100+ | [08-services/](08-services/) (all files) |

**Total**: 500+ complete, production-ready code examples

---

## How to Use This Index

### For LLM Agents

1. **Find Pattern by Name**: Use browser/editor search (Ctrl+F) to find specific pattern
2. **Navigate to Source**: Click markdown links to open full documentation
3. **Copy-Paste Ready**: All examples are complete and runnable
4. **Context Included**: Each example includes "Location" and "Use Case" for context

### For Developers

1. **Quick Reference**: Bookmark this page for quick pattern lookups
2. **Learn by Example**: Read examples with their explanations
3. **Adapt to Your Needs**: Examples are generic enough to adapt to your specific use case
4. **Follow Links**: Navigate to full documentation for deeper understanding

---

## Contributing

When adding new code examples to documentation:

1. **Add to this index**: Update the relevant section with link to example
2. **Include context**: Specify "Location" and "Use Case" for each example
3. **Complete examples**: Provide full, runnable code (not fragments)
4. **Follow standards**: Use PSR-1/PSR-4/PSR-12, PHP 8.3 features, PHPStan Level 9

---

**Last Updated**: 2025-01-07
**Index Version**: 1.0.0
**Total Examples Indexed**: 500+

**For Questions**: Refer to [LLM_USAGE_GUIDE.md](LLM_USAGE_GUIDE.md) for navigation guidance and [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md) for complete file listing.
