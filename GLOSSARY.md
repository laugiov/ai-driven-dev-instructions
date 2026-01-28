# Glossary

> Definitions of key terms used throughout this documentation.

## AI-Driven Development Terms

### AI Agent
An AI system (like Claude, GPT-4, or Copilot) that reads documentation and generates or modifies code based on instructions. In this context, AI agents are the primary consumers of this documentation.

### AI-Driven Development (AIDD)
A methodology where technical documentation is specifically designed to be consumed and acted upon by AI coding assistants, enabling autonomous software development.

### Autonomous Development
The ability of an AI agent to implement features, fix bugs, or modify code without requiring human intervention at each step.

### Context Window
The maximum amount of text an AI agent can process in a single interaction. Documentation should be structured to work within typical context limits (4K-128K tokens).

### Prompt
Input text provided to an AI agent to guide its behavior. In AIDD, documentation serves as an extended prompt.

### Task-Based Navigation
Organizing documentation by what needs to be accomplished rather than by technical category. Example: "Implement Authentication" instead of "Security Documentation".

### Validation Checkpoint
Explicit criteria that allow an AI agent to verify its implementation is correct before proceeding to the next task.

---

## Architectural Terms

### Aggregate
A cluster of domain objects (entities and value objects) treated as a single unit for data changes. Has a root entity that controls all access.

```php
// WorkflowAggregate contains Steps, but all changes go through Workflow
$workflow->addStep($step);  // Correct
$step->setWorkflow($workflow);  // Wrong - bypasses aggregate root
```

### Bounded Context
A logical boundary within which a particular domain model applies. Different bounded contexts may have different meanings for the same term.

```
User Context: User = account holder with login credentials
Billing Context: User = customer with payment information
Notification Context: User = recipient with contact preferences
```

### CQRS (Command Query Responsibility Segregation)
Pattern separating read operations (queries) from write operations (commands). Allows optimizing each independently.

```
Command: CreateWorkflowCommand → writes to PostgreSQL
Query: GetWorkflowQuery → reads from optimized read model
```

### Domain Event
An immutable record of something significant that happened in the domain. Used for communication between bounded contexts.

```php
// Event when workflow completes
final readonly class WorkflowCompletedEvent
{
    public function __construct(
        public string $workflowId,
        public DateTimeImmutable $completedAt,
        public array $results,
    ) {}
}
```

### Domain-Driven Design (DDD)
An approach to software development that focuses on modeling the business domain. Uses patterns like entities, value objects, aggregates, and bounded contexts.

### Entity
A domain object with a unique identity that persists over time. Two entities with the same attributes but different IDs are different entities.

```php
// Two users with same name are different entities
$user1 = new User(id: 'uuid-1', name: 'John');
$user2 = new User(id: 'uuid-2', name: 'John');
// $user1 !== $user2
```

### Hexagonal Architecture (Ports & Adapters)
Architecture pattern isolating business logic from infrastructure concerns. Business logic defines ports (interfaces); infrastructure provides adapters (implementations).

```
Domain Layer (center) → defines UserRepositoryInterface (port)
Infrastructure Layer → provides PostgresUserRepository (adapter)
```

### Microservice
A small, independently deployable service focused on a single business capability. Owns its data and communicates via APIs or events.

### Port
An interface defined by the domain layer that describes how it interacts with the outside world. Implemented by adapters.

### Adapter
A concrete implementation of a port. Connects the domain to external systems (databases, APIs, message queues).

### Saga Pattern
A pattern for managing distributed transactions across multiple services using a sequence of local transactions with compensation logic.

```
CreateOrder → ReserveInventory → ChargePayment → ShipOrder
     ↓ (failure)        ↓              ↓
CancelOrder ← ReleaseInventory ← RefundPayment
```

### Value Object
An immutable domain object defined by its attributes, not identity. Two value objects with the same attributes are equal.

```php
// Two emails with same value are equal
$email1 = new Email('user@example.com');
$email2 = new Email('user@example.com');
// $email1->equals($email2) === true
```

---

## Infrastructure Terms

### GitOps
Using Git as the single source of truth for declarative infrastructure and applications. Changes are made via pull requests, and automation syncs the cluster state.

### Helm
A package manager for Kubernetes. Helm charts bundle Kubernetes manifests with configurable values.

### Infrastructure as Code (IaC)
Managing infrastructure through machine-readable definition files rather than manual configuration. Examples: Terraform, Pulumi.

### Istio
A service mesh that provides traffic management, security (mTLS), and observability for microservices running on Kubernetes.

### Kubernetes (K8s)
Container orchestration platform. Manages deployment, scaling, and operations of containerized applications.

### mTLS (Mutual TLS)
TLS where both client and server authenticate each other using certificates. Ensures service-to-service communication is encrypted and authenticated.

### Namespace (Kubernetes)
A virtual cluster within Kubernetes for resource isolation. Different environments (dev, staging, prod) typically use different namespaces.

### Pod
The smallest deployable unit in Kubernetes. Contains one or more containers that share storage and network.

### Service Mesh
An infrastructure layer that handles service-to-service communication. Provides traffic management, security, and observability without changing application code.

---

## Security Terms

### ABAC (Attribute-Based Access Control)
Access control based on attributes of the user, resource, and environment. More flexible than RBAC.

```
Allow if: user.department == "engineering"
          AND resource.classification != "secret"
          AND time.hour BETWEEN 9 AND 17
```

### JWT (JSON Web Token)
A compact, URL-safe token format for transmitting claims between parties. Self-contained with signature verification.

### OAuth2
Authorization framework allowing third-party applications to access resources on behalf of a user without sharing credentials.

### OIDC (OpenID Connect)
Identity layer on top of OAuth2. Adds authentication (who the user is) to OAuth2's authorization (what they can access).

### RBAC (Role-Based Access Control)
Access control based on roles assigned to users. Users inherit permissions from their roles.

```
Role: admin → Permissions: [create, read, update, delete]
Role: viewer → Permissions: [read]
User: john → Roles: [admin] → Can create, read, update, delete
```

### SAST (Static Application Security Testing)
Security testing that analyzes source code without executing it. Finds vulnerabilities like SQL injection, XSS.

### DAST (Dynamic Application Security Testing)
Security testing that analyzes running applications. Finds vulnerabilities by simulating attacks.

### SCA (Software Composition Analysis)
Security testing that identifies vulnerabilities in third-party dependencies.

### Zero Trust
Security model assuming no implicit trust. Every access request must be verified regardless of origin.

```
Traditional: Trust internal network, verify external
Zero Trust: Verify everyone, every time, everywhere
```

---

## Operations Terms

### Circuit Breaker
Pattern preventing cascading failures by stopping requests to a failing service. After timeout, allows limited requests to test recovery.

```
States: Closed (normal) → Open (failing) → Half-Open (testing)
```

### Observability
The ability to understand system state from external outputs: metrics, logs, and traces. The "three pillars" of observability.

### RTO (Recovery Time Objective)
Maximum acceptable time to restore service after an outage. Example: RTO of 1 hour means service must be restored within 1 hour.

### RPO (Recovery Point Objective)
Maximum acceptable data loss measured in time. Example: RPO of 15 minutes means backups must be no older than 15 minutes.

### SLA (Service Level Agreement)
Contractual commitment for service availability and performance. Legal/business document.

### SLI (Service Level Indicator)
Quantitative measure of service behavior. Example: request latency, error rate.

### SLO (Service Level Objective)
Target value for an SLI. Example: 99.9% of requests complete in < 200ms.

---

## Development Terms

### DTOs (Data Transfer Objects)
Simple objects for transferring data between layers or services. No business logic.

### PHPStan
Static analysis tool for PHP. Level 9 is the strictest setting, catching the most potential errors.

### PSR (PHP Standards Recommendations)
Standards for PHP code interoperability:
- PSR-1: Basic coding standard
- PSR-4: Autoloading standard
- PSR-12: Extended coding style guide

### Strict Types
PHP declaration requiring exact type matching. Prevents implicit type coercion.

```php
declare(strict_types=1);  // Must be first line after <?php
```

### Use Case
In hexagonal architecture, a class that orchestrates a single business operation. Entry point to the application layer.

```php
class CreateWorkflowUseCase
{
    public function execute(CreateWorkflowCommand $command): WorkflowId
    {
        // Orchestrate domain operations
    }
}
```

---

## Message Queue Terms

### Dead Letter Queue (DLQ)
Queue for messages that couldn't be processed after maximum retry attempts. Used for debugging and manual intervention.

### Exchange (RabbitMQ)
Component that routes messages to queues based on routing rules. Types: direct, topic, fanout, headers.

### Consumer
Application that receives and processes messages from a queue.

### Publisher
Application that sends messages to an exchange or queue.

---

## See Also

- [METHODOLOGY.md](METHODOLOGY.md) - AI-Driven Development methodology
- [Architecture Overview](examples/php-symfony-k8s/01-architecture/01-architecture-overview.md) - Architecture concepts in context (PHP/Symfony example)
- [Security Principles](examples/php-symfony-k8s/02-security/01-security-principles.md) - Security concepts in context (PHP/Symfony example)
