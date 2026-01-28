# Symfony Best Practices

**Document Version**: 1.0
**Last Updated**: 2025-01-07
**Status**: Complete

## Table of Contents

1. [Overview](#overview)
2. [Project Structure](#project-structure)
3. [Configuration](#configuration)
4. [Controllers](#controllers)
5. [Services](#services)
6. [Doctrine ORM](#doctrine-orm)
7. [Forms](#forms)
8. [Validation](#validation)
9. [Security](#security)
10. [Event Handling](#event-handling)
11. [Console Commands](#console-commands)
12. [Testing](#testing)
13. [Performance](#performance)

## Overview

This document provides Symfony 7-specific best practices for the AI Workflow Processing Platform, complementing the general PHP coding guidelines.

### Symfony Version

- **Production**: Symfony 7.0+
- **LTS Support**: Follow Symfony LTS releases
- **Upgrade Strategy**: Upgrade within 6 months of new major version

## Project Structure

### Recommended Directory Structure

```
src/
├── Application/          # Application layer (CQRS)
│   ├── Command/         # Write operations
│   ├── Query/           # Read operations
│   ├── Handler/         # Command/Query handlers
│   └── DTO/             # Data Transfer Objects
├── Domain/              # Domain layer (business logic)
│   ├── Entity/          # Domain entities
│   ├── ValueObject/     # Value objects
│   ├── Repository/      # Repository interfaces
│   ├── Service/         # Domain services
│   └── Event/           # Domain events
├── Infrastructure/      # Infrastructure layer
│   ├── Persistence/     # Doctrine implementations
│   ├── Http/            # Controllers, middleware
│   ├── Messaging/       # Message bus, handlers
│   ├── Security/        # Security implementations
│   └── ExternalService/ # Third-party integrations
└── Presentation/        # Presentation layer (if needed)
    └── Api/             # API resources, transformers
```

### Namespace Organization

```php
<?php

// Application layer
namespace App\Application\LLMAgent\Command;
namespace App\Application\LLMAgent\Query;
namespace App\Application\LLMAgent\Handler;

// Domain layer
namespace App\Domain\LLMAgent\Entity;
namespace App\Domain\LLMAgent\Repository;

// Infrastructure layer
namespace App\Infrastructure\Persistence\Doctrine\LLMAgent;
namespace App\Infrastructure\Http\Controller\LLMAgent;
```

## Configuration

### Environment-Based Configuration

```yaml
# config/packages/doctrine.yaml
doctrine:
    dbal:
        url: '%env(resolve:DATABASE_URL)%'
        server_version: '15'
        charset: utf8mb4

    orm:
        auto_generate_proxy_classes: false
        naming_strategy: doctrine.orm.naming_strategy.underscore_number_aware
        auto_mapping: true
        mappings:
            App:
                is_bundle: false
                dir: '%kernel.project_dir%/src/Domain'
                prefix: 'App\Domain'
                alias: App

# config/packages/dev/doctrine.yaml (development overrides)
doctrine:
    orm:
        auto_generate_proxy_classes: true
    dbal:
        logging: true
        profiling: true
```

### Service Configuration

```yaml
# config/services.yaml
services:
    _defaults:
        autowire: true
        autoconfigure: true
        bind:
            # Bind parameters
            $projectDir: '%kernel.project_dir%'
            $environment: '%kernel.environment%'

    # Auto-register services
    App\:
        resource: '../src/'
        exclude:
            - '../src/Domain/*/Entity/'
            - '../src/Application/*/DTO/'
            - '../src/Kernel.php'

    # Application handlers
    App\Application\:
        resource: '../src/Application/**/Handler/'
        tags:
            - { name: messenger.message_handler }

    # Repositories
    App\Domain\LLMAgent\Repository\AgentRepositoryInterface:
        class: App\Infrastructure\Persistence\Doctrine\LLMAgent\AgentRepository
        arguments:
            - '@doctrine.orm.entity_manager'
```

### Parameters and Secrets

```yaml
# config/packages/framework.yaml
framework:
    secrets:
        vault_directory: '%kernel.project_dir%/config/secrets/%kernel.environment%'
        local_dotenv_file: '%kernel.project_dir%/.env.local'
        decryption_env_var: base64:default::SYMFONY_DECRYPTION_SECRET

# Usage in services
services:
    App\Infrastructure\LLM\OpenAIClient:
        arguments:
            $apiKey: '%env(OPENAI_API_KEY)%'
            $organization: '%env(OPENAI_ORGANIZATION)%'
```

## Controllers

### Slim Controllers

Controllers should be thin, delegating to application services:

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Http\Controller\LLMAgent;

use App\Application\LLMAgent\Command\CreateAgentCommand;
use App\Application\LLMAgent\Query\GetAgentQuery;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Messenger\MessageBusInterface;
use Symfony\Component\Messenger\Stamp\HandledStamp;
use Symfony\Component\Routing\Annotation\Route;

#[Route('/api/v1/agents')]
final class AgentController extends AbstractController
{
    public function __construct(
        private readonly MessageBusInterface $commandBus,
        private readonly MessageBusInterface $queryBus,
    ) {
    }

    #[Route('', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        // Validate input
        $data = json_decode($request->getContent(), true);

        // Create command
        $command = new CreateAgentCommand(
            name: $data['name'],
            model: $data['model'],
            systemPrompt: $data['system_prompt'],
            configuration: $data['configuration'] ?? []
        );

        // Dispatch to handler
        $envelope = $this->commandBus->dispatch($command);

        // Get result
        $agentId = $envelope->last(HandledStamp::class)?->getResult();

        return $this->json([
            'id' => $agentId,
            'status' => 'created'
        ], Response::HTTP_CREATED);
    }

    #[Route('/{id}', methods: ['GET'])]
    public function get(string $id): JsonResponse
    {
        $query = new GetAgentQuery($id);

        $envelope = $this->queryBus->dispatch($query);
        $agent = $envelope->last(HandledStamp::class)?->getResult();

        if ($agent === null) {
            return $this->json(
                ['error' => 'Agent not found'],
                Response::HTTP_NOT_FOUND
            );
        }

        return $this->json($agent);
    }
}
```

### Route Attributes

Use PHP attributes for routing:

```php
<?php

#[Route('/api/v1/workflows')]
#[IsGranted('ROLE_USER')]
final class WorkflowController extends AbstractController
{
    #[Route('', methods: ['GET'])]
    public function list(): JsonResponse
    {
        // List workflows
    }

    #[Route('/{id}', methods: ['GET'], requirements: ['id' => '\d+'])]
    public function get(int $id): JsonResponse
    {
        // Get workflow
    }

    #[Route('', methods: ['POST'])]
    #[IsGranted('ROLE_WORKFLOW_CREATE')]
    public function create(Request $request): JsonResponse
    {
        // Create workflow
    }
}
```

### API Versioning

```php
<?php

// Version in route prefix
#[Route('/api/v1/agents')]
final class AgentV1Controller {}

#[Route('/api/v2/agents')]
final class AgentV2Controller {}

// Or use Accept header versioning
#[Route('/api/agents', condition: "request.headers.get('Accept') matches '/application\/vnd\\.platform\\.v1\\+json/'")]
final class AgentController {}
```

## Services

### Service Definition

```php
<?php

declare(strict_types=1);

namespace App\Application\LLMAgent\Handler;

use App\Application\LLMAgent\Command\CreateAgentCommand;
use App\Domain\LLMAgent\Entity\Agent;
use App\Domain\LLMAgent\Repository\AgentRepositoryInterface;
use Symfony\Component\Messenger\Attribute\AsMessageHandler;

#[AsMessageHandler]
final class CreateAgentHandler
{
    public function __construct(
        private readonly AgentRepositoryInterface $agentRepository,
    ) {
    }

    public function __invoke(CreateAgentCommand $command): string
    {
        // Create entity
        $agent = Agent::create(
            name: $command->name,
            model: $command->model,
            systemPrompt: $command->systemPrompt,
            configuration: $command->configuration
        );

        // Persist
        $this->agentRepository->save($agent);

        return $agent->getId();
    }
}
```

### Dependency Injection

```php
<?php

// Constructor injection (preferred)
final class CompletionService
{
    public function __construct(
        private readonly LLMClientInterface $llmClient,
        private readonly LoggerInterface $logger,
    ) {
    }
}

// Setter injection (avoid unless necessary)
final class OptionalFeatureService
{
    private ?CacheInterface $cache = null;

    #[Required]
    public function setCache(CacheInterface $cache): void
    {
        $this->cache = $cache;
    }
}
```

### Service Decoration

```php
<?php

// Base service
final class AgentService
{
    public function createAgent(string $name): Agent
    {
        // Create agent
    }
}

// Decorator with caching
final class CachedAgentService implements AgentServiceInterface
{
    public function __construct(
        private readonly AgentServiceInterface $decorated,
        private readonly CacheInterface $cache,
    ) {
    }

    public function createAgent(string $name): Agent
    {
        $cacheKey = "agent:{$name}";

        return $this->cache->get($cacheKey, function() use ($name) {
            return $this->decorated->createAgent($name);
        });
    }
}

// Configuration
services:
    App\Application\LLMAgent\Service\AgentService: ~

    App\Application\LLMAgent\Service\CachedAgentService:
        decorates: App\Application\LLMAgent\Service\AgentService
        arguments:
            $decorated: '@.inner'
```

## Doctrine ORM

### Entity Mapping

```php
<?php

declare(strict_types=1);

namespace App\Domain\LLMAgent\Entity;

use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity(repositoryClass: AgentRepository::class)]
#[ORM\Table(name: 'agents')]
#[ORM\Index(columns: ['status'], name: 'idx_agent_status')]
#[ORM\Index(columns: ['created_at'], name: 'idx_agent_created_at')]
final class Agent
{
    #[ORM\Id]
    #[ORM\Column(type: 'uuid', unique: true)]
    private string $id;

    #[ORM\Column(type: 'string', length: 255)]
    private string $name;

    #[ORM\Column(type: 'string', length: 100)]
    private string $model;

    #[ORM\Column(type: 'text')]
    private string $systemPrompt;

    #[ORM\Column(type: 'json')]
    private array $configuration;

    #[ORM\Column(type: 'string', length: 50)]
    private string $status;

    #[ORM\Column(type: 'datetime_immutable')]
    private \DateTimeImmutable $createdAt;

    #[ORM\Column(type: 'datetime_immutable', nullable: true)]
    private ?\DateTimeImmutable $updatedAt = null;

    private function __construct()
    {
        $this->id = Uuid::v4()->toString();
        $this->createdAt = new \DateTimeImmutable();
    }

    public static function create(
        string $name,
        string $model,
        string $systemPrompt,
        array $configuration
    ): self {
        $agent = new self();
        $agent->name = $name;
        $agent->model = $model;
        $agent->systemPrompt = $systemPrompt;
        $agent->configuration = $configuration;
        $agent->status = 'active';

        return $agent;
    }

    public function update(string $name, string $systemPrompt): void
    {
        $this->name = $name;
        $this->systemPrompt = $systemPrompt;
        $this->updatedAt = new \DateTimeImmutable();
    }

    // Getters
    public function getId(): string { return $this->id; }
    public function getName(): string { return $this->name; }
    // ... other getters
}
```

### Repository Pattern

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Persistence\Doctrine\LLMAgent;

use App\Domain\LLMAgent\Entity\Agent;
use App\Domain\LLMAgent\Repository\AgentRepositoryInterface;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

final class AgentRepository extends ServiceEntityRepository implements AgentRepositoryInterface
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Agent::class);
    }

    public function save(Agent $agent): void
    {
        $this->getEntityManager()->persist($agent);
        $this->getEntityManager()->flush();
    }

    public function findById(string $id): ?Agent
    {
        return $this->find($id);
    }

    public function findByUserId(string $userId): array
    {
        return $this->createQueryBuilder('a')
            ->where('a.userId = :userId')
            ->andWhere('a.status = :status')
            ->setParameter('userId', $userId)
            ->setParameter('status', 'active')
            ->orderBy('a.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    public function findActiveAgents(): array
    {
        return $this->createQueryBuilder('a')
            ->where('a.status = :status')
            ->setParameter('status', 'active')
            ->getQuery()
            ->getResult();
    }
}
```

### Query Optimization

```php
<?php

// Bad: N+1 query
$workflows = $workflowRepository->findAll();
foreach ($workflows as $workflow) {
    echo $workflow->getSteps()->count(); // Lazy load - N queries
}

// Good: Eager loading with JOIN
$workflows = $workflowRepository->createQueryBuilder('w')
    ->leftJoin('w.steps', 's')
    ->addSelect('s')
    ->getQuery()
    ->getResult();

foreach ($workflows as $workflow) {
    echo $workflow->getSteps()->count(); // Already loaded - 0 queries
}

// Good: Use DTO for read-only queries
$results = $entityManager->createQuery(
    'SELECT NEW App\Application\DTO\WorkflowSummary(w.id, w.name, COUNT(s.id))
     FROM App\Domain\Workflow\Entity\Workflow w
     LEFT JOIN w.steps s
     GROUP BY w.id, w.name'
)->getResult();
```

## Forms

### Form Type

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Http\Form;

use Symfony\Component\Form\AbstractType;
use Symfony\Component\Form\Extension\Core\Type\TextType;
use Symfony\Component\Form\Extension\Core\Type\NumberType;
use Symfony\Component\Form\FormBuilderInterface;
use Symfony\Component\OptionsResolver\OptionsResolver;
use Symfony\Component\Validator\Constraints as Assert;

final class CreateAgentType extends AbstractType
{
    public function buildForm(FormBuilderInterface $builder, array $options): void
    {
        $builder
            ->add('name', TextType::class, [
                'constraints' => [
                    new Assert\NotBlank(),
                    new Assert\Length(min: 3, max: 255),
                ],
            ])
            ->add('model', TextType::class, [
                'constraints' => [
                    new Assert\NotBlank(),
                    new Assert\Choice(['gpt-4', 'gpt-3.5-turbo', 'claude-3']),
                ],
            ])
            ->add('system_prompt', TextType::class, [
                'constraints' => [
                    new Assert\NotBlank(),
                    new Assert\Length(min: 10, max: 4000),
                ],
            ])
            ->add('temperature', NumberType::class, [
                'constraints' => [
                    new Assert\Range(min: 0, max: 2),
                ],
                'required' => false,
            ]);
    }

    public function configureOptions(OptionsResolver $resolver): void
    {
        $resolver->setDefaults([
            'data_class' => null,
            'csrf_protection' => true,
        ]);
    }
}
```

### Form Handling

```php
<?php

#[Route('/agents', methods: ['POST'])]
public function create(Request $request): JsonResponse
{
    $form = $this->createForm(CreateAgentType::class);
    $form->submit($request->request->all());

    if (!$form->isValid()) {
        return $this->json([
            'errors' => $this->getFormErrors($form)
        ], Response::HTTP_BAD_REQUEST);
    }

    $data = $form->getData();

    $command = new CreateAgentCommand(
        name: $data['name'],
        model: $data['model'],
        systemPrompt: $data['system_prompt'],
        configuration: ['temperature' => $data['temperature'] ?? 1.0]
    );

    $agentId = $this->commandBus->dispatch($command);

    return $this->json(['id' => $agentId], Response::HTTP_CREATED);
}
```

## Validation

### Constraint Annotations

```php
<?php

use Symfony\Component\Validator\Constraints as Assert;

final class CreateWorkflowCommand
{
    public function __construct(
        #[Assert\NotBlank]
        #[Assert\Length(min: 3, max: 255)]
        public readonly string $name,

        #[Assert\NotBlank]
        #[Assert\Json]
        public readonly string $definition,

        #[Assert\Uuid]
        public readonly string $userId,
    ) {
    }
}
```

### Custom Validator

```php
<?php

// Constraint
#[\Attribute]
final class ValidWorkflowDefinition extends Constraint
{
    public string $message = 'The workflow definition is invalid: {{ reason }}';
}

// Validator
final class ValidWorkflowDefinitionValidator extends ConstraintValidator
{
    public function validate($value, Constraint $constraint): void
    {
        if (!$constraint instanceof ValidWorkflowDefinition) {
            throw new UnexpectedTypeException($constraint, ValidWorkflowDefinition::class);
        }

        if (null === $value || '' === $value) {
            return;
        }

        $definition = json_decode($value, true);

        if (!isset($definition['steps']) || !is_array($definition['steps'])) {
            $this->context->buildViolation($constraint->message)
                ->setParameter('{{ reason }}', 'Missing or invalid steps')
                ->addViolation();
        }

        // Additional validation logic
    }
}
```

## Security

### Voters for Authorization

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Security\Voter;

use App\Domain\Workflow\Entity\Workflow;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;
use Symfony\Component\Security\Core\Authorization\Voter\Voter;
use Symfony\Component\Security\Core\User\UserInterface;

final class WorkflowVoter extends Voter
{
    public const VIEW = 'WORKFLOW_VIEW';
    public const EDIT = 'WORKFLOW_EDIT';
    public const DELETE = 'WORKFLOW_DELETE';

    protected function supports(string $attribute, mixed $subject): bool
    {
        return in_array($attribute, [self::VIEW, self::EDIT, self::DELETE])
            && $subject instanceof Workflow;
    }

    protected function voteOnAttribute(
        string $attribute,
        mixed $subject,
        TokenInterface $token
    ): bool {
        $user = $token->getUser();

        if (!$user instanceof UserInterface) {
            return false;
        }

        /** @var Workflow $workflow */
        $workflow = $subject;

        return match($attribute) {
            self::VIEW => $this->canView($workflow, $user),
            self::EDIT => $this->canEdit($workflow, $user),
            self::DELETE => $this->canDelete($workflow, $user),
            default => false,
        };
    }

    private function canView(Workflow $workflow, UserInterface $user): bool
    {
        // Owner can view
        if ($workflow->getUserId() === $user->getUserIdentifier()) {
            return true;
        }

        // Admin can view all
        return in_array('ROLE_ADMIN', $user->getRoles());
    }

    private function canEdit(Workflow $workflow, UserInterface $user): bool
    {
        // Only owner can edit
        return $workflow->getUserId() === $user->getUserIdentifier();
    }

    private function canDelete(Workflow $workflow, UserInterface $user): bool
    {
        // Only owner can delete
        return $workflow->getUserId() === $user->getUserIdentifier();
    }
}
```

### Usage in Controller

```php
<?php

#[Route('/workflows/{id}', methods: ['DELETE'])]
public function delete(string $id): JsonResponse
{
    $workflow = $this->workflowRepository->findById($id);

    // Check authorization
    $this->denyAccessUnlessGranted(WorkflowVoter::DELETE, $workflow);

    // Delete workflow
    $this->workflowRepository->delete($workflow);

    return $this->json(null, Response::HTTP_NO_CONTENT);
}
```

## Event Handling

### Domain Events

```php
<?php

// Event
final readonly class WorkflowCreated
{
    public function __construct(
        public string $workflowId,
        public string $userId,
        public \DateTimeImmutable $occurredAt,
    ) {
    }
}

// Event Listener
#[AsEventListener(event: WorkflowCreated::class)]
final class SendWorkflowCreatedNotification
{
    public function __construct(
        private readonly NotificationService $notificationService,
    ) {
    }

    public function __invoke(WorkflowCreated $event): void
    {
        $this->notificationService->send(
            userId: $event->userId,
            message: "Workflow {$event->workflowId} created"
        );
    }
}

// Dispatch event
$event = new WorkflowCreated($workflow->getId(), $workflow->getUserId(), new \DateTimeImmutable());
$this->eventDispatcher->dispatch($event);
```

## Console Commands

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Console;

use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Console\Style\SymfonyStyle;

#[AsCommand(
    name: 'app:cleanup-old-workflows',
    description: 'Delete workflows older than specified days',
)]
final class CleanupOldWorkflowsCommand extends Command
{
    public function __construct(
        private readonly WorkflowRepository $workflowRepository,
    ) {
        parent::__construct();
    }

    protected function configure(): void
    {
        $this->addOption(
            'days',
            'd',
            InputOption::VALUE_REQUIRED,
            'Delete workflows older than N days',
            90
        );

        $this->addOption(
            'dry-run',
            null,
            InputOption::VALUE_NONE,
            'Run without actually deleting'
        );
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $io = new SymfonyStyle($input, $output);

        $days = (int) $input->getOption('days');
        $dryRun = $input->getOption('dry-run');

        $cutoffDate = new \DateTimeImmutable("-{$days} days");

        $workflows = $this->workflowRepository->findOlderThan($cutoffDate);

        $io->info(sprintf('Found %d workflows to delete', count($workflows)));

        if ($dryRun) {
            $io->warning('DRY RUN - No workflows will be deleted');
            return Command::SUCCESS;
        }

        $progressBar = $io->createProgressBar(count($workflows));
        $progressBar->start();

        foreach ($workflows as $workflow) {
            $this->workflowRepository->delete($workflow);
            $progressBar->advance();
        }

        $progressBar->finish();
        $io->newLine(2);
        $io->success(sprintf('Deleted %d workflows', count($workflows)));

        return Command::SUCCESS;
    }
}
```

## Testing

See [04-testing-strategy.md](04-testing-strategy.md) for complete testing guidelines.

## Performance

### Caching

```php
<?php

use Symfony\Contracts\Cache\CacheInterface;
use Symfony\Contracts\Cache\ItemInterface;

final class CachedWorkflowService
{
    public function __construct(
        private readonly WorkflowRepository $repository,
        private readonly CacheInterface $cache,
    ) {
    }

    public function getWorkflow(string $id): Workflow
    {
        return $this->cache->get(
            "workflow_{$id}",
            function (ItemInterface $item) use ($id) {
                $item->expiresAfter(3600); // 1 hour

                return $this->repository->findById($id);
            }
        );
    }
}
```

### Profiler

```bash
# Enable profiler in development
# Visit /_profiler to see all requests
# Click on any request to see detailed performance data

# Disable in production (automatic in prod environment)
```

## Best Practices Summary

1. ✅ Use dependency injection
2. ✅ Keep controllers thin
3. ✅ Use command/query buses
4. ✅ Optimize database queries
5. ✅ Use caching strategically
6. ✅ Implement proper error handling
7. ✅ Write tests for all business logic
8. ✅ Use Symfony profiler in development
9. ✅ Follow security best practices
10. ✅ Keep dependencies up to date

## References

- [Symfony Documentation](https://symfony.com/doc/current/index.html)
- [Symfony Best Practices](https://symfony.com/doc/current/best_practices.html)
- [Doctrine Best Practices](https://www.doctrine-project.org/projects/doctrine-orm/en/latest/reference/best-practices.html)

## Related Documentation

- [02-coding-guidelines-php.md](02-coding-guidelines-php.md) - PHP coding standards
- [04-testing-strategy.md](04-testing-strategy.md) - Testing strategy
- [../01-architecture/03-hexagonal-architecture.md](../01-architecture/03-hexagonal-architecture.md) - Architecture patterns

---

**Document Maintainers**: Engineering Team
**Review Cycle**: After each Symfony major version upgrade
**Next Review**: 2025-04-07
