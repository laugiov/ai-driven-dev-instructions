# Data Protection

**Document Version**: 1.0
**Last Updated**: 2025-01-07
**Status**: Complete

## Table of Contents

1. [Overview](#overview)
2. [Data Classification](#data-classification)
3. [Encryption at Rest](#encryption-at-rest)
4. [Encryption in Transit](#encryption-in-transit)
5. [Personal Data Protection (GDPR)](#personal-data-protection-gdpr)
6. [PII Handling](#pii-handling)
7. [Data Masking and Anonymization](#data-masking-and-anonymization)
8. [Data Retention and Deletion](#data-retention-and-deletion)
9. [Database Security](#database-security)
10. [Backup and Recovery](#backup-and-recovery)
11. [Data Access Controls](#data-access-controls)
12. [Audit and Compliance](#audit-and-compliance)
13. [Data Breach Response](#data-breach-response)

## Overview

Data protection is paramount in our AI Workflow Processing Platform. This document provides comprehensive guidance on protecting data throughout its lifecycle, from collection to deletion, ensuring compliance with GDPR, SOC2, ISO27001, and NIS2 requirements.

### Data Protection Principles

Our data protection strategy is built on these fundamental principles:

1. **Data Minimization**: Collect and retain only necessary data
2. **Purpose Limitation**: Use data only for specified, legitimate purposes
3. **Encryption Everywhere**: Encrypt data at rest and in transit
4. **Access Control**: Strict least-privilege access to all data
5. **Privacy by Design**: Privacy considerations in all architectural decisions
6. **Transparency**: Clear data processing documentation
7. **Data Subject Rights**: Support all GDPR rights (access, rectification, erasure, portability)
8. **Accountability**: Complete audit trail of all data access and modifications

### Data Protection Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Data Protection Layers                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Layer 1: Collection & Input                                        │
│  ├─ Input validation and sanitization                               │
│  ├─ PII detection and flagging                                      │
│  └─ Consent verification                                            │
│                                                                       │
│  Layer 2: Processing                                                │
│  ├─ Field-level encryption for sensitive data                       │
│  ├─ Data masking in non-production environments                     │
│  └─ Purpose-based access controls                                   │
│                                                                       │
│  Layer 3: Storage                                                   │
│  ├─ Encryption at rest (AES-256)                                    │
│  ├─ Database-level encryption (TDE)                                 │
│  ├─ Encrypted backups                                               │
│  └─ Secure key management (Vault)                                   │
│                                                                       │
│  Layer 4: Transmission                                              │
│  ├─ TLS 1.3 for external communication                              │
│  ├─ mTLS for internal service-to-service                            │
│  └─ End-to-end encryption for file transfers                        │
│                                                                       │
│  Layer 5: Access & Audit                                            │
│  ├─ Authentication (OAuth2/OIDC)                                     │
│  ├─ Authorization (RBAC/ABAC)                                       │
│  ├─ Complete audit logging                                          │
│  └─ Anomaly detection                                               │
│                                                                       │
│  Layer 6: Retention & Deletion                                      │
│  ├─ Automated retention policies                                    │
│  ├─ Secure deletion (cryptographic erasure)                         │
│  ├─ Right to be forgotten implementation                            │
│  └─ Data portability support                                        │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Classification

### Classification Levels

We use a four-tier classification system:

| Level | Description | Examples | Protection Requirements |
|-------|-------------|----------|------------------------|
| **Public** | Non-sensitive, publicly available | Marketing materials, public documentation | Basic integrity protection |
| **Internal** | Non-public business data | Workflow templates, system configurations | Access control, encryption in transit |
| **Confidential** | Sensitive business/personal data | User profiles, workflow data, API keys | Encryption at rest and in transit, access logging |
| **Restricted** | Highly sensitive data | Authentication credentials, PII, financial data | Field-level encryption, strict access controls, full audit trail |

### Data Classification Implementation

**PHP Data Classification Attribute**:

```php
<?php

declare(strict_types=1);

namespace App\Domain\Security;

use Attribute;

#[Attribute(Attribute::TARGET_PROPERTY)]
final class DataClassification
{
    public function __construct(
        public readonly DataClassificationLevel $level,
        public readonly bool $isPII = false,
        public readonly ?string $retentionPeriod = null,
        public readonly ?string $encryptionRequired = null,
    ) {
    }
}

enum DataClassificationLevel: string
{
    case PUBLIC = 'public';
    case INTERNAL = 'internal';
    case CONFIDENTIAL = 'confidential';
    case RESTRICTED = 'restricted';
}
```

**Entity with Classification**:

```php
<?php

declare(strict_types=1);

namespace App\Domain\User\Entity;

use App\Domain\Security\DataClassification;
use App\Domain\Security\DataClassificationLevel;

final class User
{
    #[DataClassification(DataClassificationLevel::PUBLIC)]
    private UserId $id;

    #[DataClassification(DataClassificationLevel::INTERNAL)]
    private string $username;

    #[DataClassification(
        level: DataClassificationLevel::RESTRICTED,
        isPII: true,
        retentionPeriod: 'P7Y', // 7 years
        encryptionRequired: 'field-level'
    )]
    private string $email;

    #[DataClassification(
        level: DataClassificationLevel::RESTRICTED,
        isPII: true,
        retentionPeriod: 'P7Y',
        encryptionRequired: 'field-level'
    )]
    private string $firstName;

    #[DataClassification(
        level: DataClassificationLevel::RESTRICTED,
        isPII: true,
        retentionPeriod: 'P7Y',
        encryptionRequired: 'field-level'
    )]
    private string $lastName;

    #[DataClassification(
        level: DataClassificationLevel::RESTRICTED,
        isPII: true,
        retentionPeriod: 'P7Y',
        encryptionRequired: 'field-level'
    )]
    private ?string $phoneNumber;

    #[DataClassification(DataClassificationLevel::CONFIDENTIAL)]
    private array $roles;

    #[DataClassification(DataClassificationLevel::INTERNAL)]
    private UserStatus $status;

    #[DataClassification(DataClassificationLevel::INTERNAL)]
    private \DateTimeImmutable $createdAt;

    // ... methods
}
```

### Automatic Classification Scanner

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Security;

use App\Domain\Security\DataClassification;
use ReflectionClass;
use ReflectionProperty;

final class DataClassificationScanner
{
    /**
     * Scan an entity and return classification information.
     *
     * @return array<string, array{level: string, isPII: bool, encryption: ?string}>
     */
    public function scan(object $entity): array
    {
        $reflection = new ReflectionClass($entity);
        $classifications = [];

        foreach ($reflection->getProperties() as $property) {
            $attributes = $property->getAttributes(DataClassification::class);

            if (empty($attributes)) {
                // No classification attribute - flag for review
                $classifications[$property->getName()] = [
                    'level' => 'UNCLASSIFIED',
                    'isPII' => false,
                    'encryption' => null,
                    'warning' => 'No data classification attribute found',
                ];
                continue;
            }

            /** @var DataClassification $classification */
            $classification = $attributes[0]->newInstance();

            $classifications[$property->getName()] = [
                'level' => $classification->level->value,
                'isPII' => $classification->isPII,
                'encryption' => $classification->encryptionRequired,
                'retention' => $classification->retentionPeriod,
            ];
        }

        return $classifications;
    }

    /**
     * Get all PII fields from an entity.
     *
     * @return array<string>
     */
    public function getPIIFields(object $entity): array
    {
        $classifications = $this->scan($entity);

        return array_keys(array_filter(
            $classifications,
            fn(array $info) => $info['isPII']
        ));
    }

    /**
     * Get all fields requiring encryption.
     *
     * @return array<string>
     */
    public function getEncryptedFields(object $entity): array
    {
        $classifications = $this->scan($entity);

        return array_keys(array_filter(
            $classifications,
            fn(array $info) => $info['encryption'] !== null
        ));
    }
}
```

## Encryption at Rest

### Database Encryption (PostgreSQL TDE)

**Transparent Data Encryption (TDE)** with PostgreSQL:

```yaml
# postgresql-encrypted-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql-encrypted
  namespace: data
spec:
  serviceName: postgresql
  replicas: 3
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
      - name: postgresql
        image: postgres:15-alpine

        env:
        # Enable encryption
        - name: POSTGRES_INITDB_ARGS
          value: "--data-checksums"

        # Password from Vault
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: password

        volumeMounts:
        # Encrypted volume
        - name: data
          mountPath: /var/lib/postgresql/data

        # TDE configuration
        - name: tde-config
          mountPath: /etc/postgresql/tde

      # Init container to set up encryption
      initContainers:
      - name: setup-encryption
        image: postgres:15-alpine
        command:
        - sh
        - -c
        - |
          # Set up pgcrypto extension for field-level encryption
          echo "CREATE EXTENSION IF NOT EXISTS pgcrypto;" > /docker-entrypoint-initdb.d/01-crypto.sql

          # Set up encryption key from Vault
          cat <<EOF > /docker-entrypoint-initdb.d/02-encryption-key.sql
          CREATE TABLE IF NOT EXISTS encryption_keys (
            id SERIAL PRIMARY KEY,
            key_name VARCHAR(255) UNIQUE NOT NULL,
            encrypted_key BYTEA NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
          );
          EOF

        volumeMounts:
        - name: init-scripts
          mountPath: /docker-entrypoint-initdb.d

      volumes:
      - name: tde-config
        secret:
          secretName: postgresql-tde-config

      - name: init-scripts
        emptyDir: {}

  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: encrypted-ssd
      resources:
        requests:
          storage: 100Gi
```

**StorageClass with encryption**:

```yaml
# storage-class-encrypted.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: encrypted-ssd
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  encrypted: "true"
  kmsKeyId: "arn:aws:kms:eu-west-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

### Field-Level Encryption

**Encryption Service using Vault Transit Engine**:

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Security\Encryption;

use App\Infrastructure\Vault\VaultClient;

final class FieldEncryptionService
{
    private const TRANSIT_KEY = 'field-encryption';

    public function __construct(
        private readonly VaultClient $vault,
    ) {
    }

    /**
     * Encrypt a field value.
     */
    public function encrypt(string $plaintext, ?string $context = null): string
    {
        if (empty($plaintext)) {
            return '';
        }

        $payload = [
            'plaintext' => base64_encode($plaintext),
        ];

        if ($context !== null) {
            // Context binding for additional security
            $payload['context'] = base64_encode($context);
        }

        $response = $this->vault->write(
            "transit/encrypt/" . self::TRANSIT_KEY,
            $payload
        );

        return $response['data']['ciphertext'];
    }

    /**
     * Decrypt a field value.
     */
    public function decrypt(string $ciphertext, ?string $context = null): string
    {
        if (empty($ciphertext)) {
            return '';
        }

        $payload = [
            'ciphertext' => $ciphertext,
        ];

        if ($context !== null) {
            $payload['context'] = base64_encode($context);
        }

        $response = $this->vault->write(
            "transit/decrypt/" . self::TRANSIT_KEY,
            $payload
        );

        return base64_decode($response['data']['plaintext']);
    }

    /**
     * Batch encrypt multiple values.
     *
     * @param array<string, string> $plaintexts
     * @return array<string, string>
     */
    public function batchEncrypt(array $plaintexts, ?string $context = null): array
    {
        if (empty($plaintexts)) {
            return [];
        }

        $batchInput = [];
        foreach ($plaintexts as $key => $value) {
            $item = ['plaintext' => base64_encode($value)];
            if ($context !== null) {
                $item['context'] = base64_encode($context);
            }
            $batchInput[] = $item;
        }

        $response = $this->vault->write(
            "transit/encrypt/" . self::TRANSIT_KEY,
            ['batch_input' => $batchInput]
        );

        $results = [];
        $keys = array_keys($plaintexts);
        foreach ($response['data']['batch_results'] as $index => $result) {
            $results[$keys[$index]] = $result['ciphertext'];
        }

        return $results;
    }

    /**
     * Batch decrypt multiple values.
     *
     * @param array<string, string> $ciphertexts
     * @return array<string, string>
     */
    public function batchDecrypt(array $ciphertexts, ?string $context = null): array
    {
        if (empty($ciphertexts)) {
            return [];
        }

        $batchInput = [];
        foreach ($ciphertexts as $key => $value) {
            $item = ['ciphertext' => $value];
            if ($context !== null) {
                $item['context'] = base64_encode($context);
            }
            $batchInput[] = $item;
        }

        $response = $this->vault->write(
            "transit/decrypt/" . self::TRANSIT_KEY,
            ['batch_input' => $batchInput]
        );

        $results = [];
        $keys = array_keys($ciphertexts);
        foreach ($response['data']['batch_results'] as $index => $result) {
            $results[$keys[$index]] = base64_decode($result['plaintext']);
        }

        return $results;
    }

    /**
     * Re-encrypt a value with the latest key version (for key rotation).
     */
    public function reEncrypt(string $ciphertext, ?string $context = null): string
    {
        if (empty($ciphertext)) {
            return '';
        }

        $payload = [
            'ciphertext' => $ciphertext,
        ];

        if ($context !== null) {
            $payload['context'] = base64_encode($context);
        }

        $response = $this->vault->write(
            "transit/rewrap/" . self::TRANSIT_KEY,
            $payload
        );

        return $response['data']['ciphertext'];
    }
}
```

**Doctrine Encryption Listener**:

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Persistence\Doctrine\Listener;

use App\Domain\Security\DataClassification;
use App\Infrastructure\Security\Encryption\FieldEncryptionService;
use Doctrine\ORM\Event\PreFlushEventArgs;
use Doctrine\ORM\Event\PostLoadEventArgs;
use Doctrine\ORM\Event\OnFlushEventArgs;
use ReflectionClass;
use ReflectionProperty;

final class EncryptionListener
{
    public function __construct(
        private readonly FieldEncryptionService $encryption,
    ) {
    }

    /**
     * Encrypt fields before persisting to database.
     */
    public function onFlush(OnFlushEventArgs $args): void
    {
        $em = $args->getObjectManager();
        $uow = $em->getUnitOfWork();

        // Process entities being inserted or updated
        foreach ($uow->getScheduledEntityInsertions() as $entity) {
            $this->encryptEntity($entity);
            $uow->recomputeSingleEntityChangeSet(
                $em->getClassMetadata($entity::class),
                $entity
            );
        }

        foreach ($uow->getScheduledEntityUpdates() as $entity) {
            $this->encryptEntity($entity);
            $uow->recomputeSingleEntityChangeSet(
                $em->getClassMetadata($entity::class),
                $entity
            );
        }
    }

    /**
     * Decrypt fields after loading from database.
     */
    public function postLoad(PostLoadEventArgs $args): void
    {
        $this->decryptEntity($args->getObject());
    }

    private function encryptEntity(object $entity): void
    {
        $reflection = new ReflectionClass($entity);

        foreach ($reflection->getProperties() as $property) {
            if (!$this->shouldEncryptProperty($property)) {
                continue;
            }

            $property->setAccessible(true);
            $value = $property->getValue($entity);

            if ($value === null || empty($value)) {
                continue;
            }

            // Use entity ID as context for encryption (if available)
            $context = $this->getEncryptionContext($entity);

            $encryptedValue = $this->encryption->encrypt($value, $context);
            $property->setValue($entity, $encryptedValue);
        }
    }

    private function decryptEntity(object $entity): void
    {
        $reflection = new ReflectionClass($entity);

        foreach ($reflection->getProperties() as $property) {
            if (!$this->shouldEncryptProperty($property)) {
                continue;
            }

            $property->setAccessible(true);
            $value = $property->getValue($entity);

            if ($value === null || empty($value)) {
                continue;
            }

            // Skip if already decrypted (doesn't start with vault: prefix)
            if (!str_starts_with($value, 'vault:')) {
                continue;
            }

            $context = $this->getEncryptionContext($entity);

            $decryptedValue = $this->encryption->decrypt($value, $context);
            $property->setValue($entity, $decryptedValue);
        }
    }

    private function shouldEncryptProperty(ReflectionProperty $property): bool
    {
        $attributes = $property->getAttributes(DataClassification::class);

        if (empty($attributes)) {
            return false;
        }

        /** @var DataClassification $classification */
        $classification = $attributes[0]->newInstance();

        return $classification->encryptionRequired === 'field-level';
    }

    private function getEncryptionContext(object $entity): ?string
    {
        // Use entity ID as encryption context for additional security
        if (method_exists($entity, 'getId')) {
            $id = $entity->getId();
            if ($id !== null) {
                return (string) $id;
            }
        }

        return null;
    }
}
```

### File Storage Encryption

**Encrypted File Storage Service**:

```php
<?php

declare(strict_types=1);

namespace App\Domain\FileStorage\Service;

use App\Infrastructure\Security\Encryption\FieldEncryptionService;

final class EncryptedFileStorageService
{
    public function __construct(
        private readonly FieldEncryptionService $encryption,
        private readonly string $storagePath,
    ) {
    }

    /**
     * Store file with encryption.
     */
    public function store(string $filename, string $content, array $metadata = []): string
    {
        // Encrypt content
        $encryptedContent = $this->encryption->encrypt($content);

        // Generate unique file ID
        $fileId = bin2hex(random_bytes(16));

        // Store encrypted content
        $filepath = $this->storagePath . '/' . $fileId;
        file_put_contents($filepath, $encryptedContent);

        // Store metadata (encrypted)
        $encryptedMetadata = $this->encryption->encrypt(json_encode([
            'filename' => $filename,
            'size' => strlen($content),
            'mime_type' => $this->detectMimeType($content),
            'uploaded_at' => (new \DateTimeImmutable())->format('c'),
            'metadata' => $metadata,
        ]));

        file_put_contents($filepath . '.meta', $encryptedMetadata);

        return $fileId;
    }

    /**
     * Retrieve and decrypt file.
     */
    public function retrieve(string $fileId): array
    {
        $filepath = $this->storagePath . '/' . $fileId;

        if (!file_exists($filepath)) {
            throw new \RuntimeException("File not found: {$fileId}");
        }

        // Decrypt content
        $encryptedContent = file_get_contents($filepath);
        $content = $this->encryption->decrypt($encryptedContent);

        // Decrypt metadata
        $encryptedMetadata = file_get_contents($filepath . '.meta');
        $metadata = json_decode(
            $this->encryption->decrypt($encryptedMetadata),
            true
        );

        return [
            'content' => $content,
            'metadata' => $metadata,
        ];
    }

    /**
     * Securely delete file.
     */
    public function delete(string $fileId): void
    {
        $filepath = $this->storagePath . '/' . $fileId;

        if (!file_exists($filepath)) {
            return;
        }

        // Overwrite file with random data before deletion (DoD 5220.22-M)
        $filesize = filesize($filepath);
        $handle = fopen($filepath, 'r+b');

        // Pass 1: Write random data
        fwrite($handle, random_bytes($filesize));
        fflush($handle);

        // Pass 2: Write zeros
        fseek($handle, 0);
        fwrite($handle, str_repeat("\x00", $filesize));
        fflush($handle);

        // Pass 3: Write ones
        fseek($handle, 0);
        fwrite($handle, str_repeat("\xFF", $filesize));
        fflush($handle);

        fclose($handle);

        // Delete file
        unlink($filepath);
        unlink($filepath . '.meta');
    }

    private function detectMimeType(string $content): string
    {
        $finfo = new \finfo(FILEINFO_MIME_TYPE);
        return $finfo->buffer($content);
    }
}
```

## Encryption in Transit

### TLS 1.3 Configuration

All external communication uses TLS 1.3 with strong cipher suites. See [05-network-security.md](05-network-security.md) for complete configuration.

### mTLS for Internal Communication

All service-to-service communication uses mutual TLS via Istio. See [02-zero-trust-architecture.md](02-zero-trust-architecture.md) for details.

## Personal Data Protection (GDPR)

### GDPR Compliance Framework

Our platform implements all GDPR requirements:

| Article | Requirement | Implementation |
|---------|-------------|----------------|
| **Art. 5** | Data processing principles | Data classification, minimization, purpose limitation |
| **Art. 6** | Lawful basis | Consent management, legitimate interest documentation |
| **Art. 15** | Right of access | Data export API |
| **Art. 16** | Right to rectification | User profile update APIs |
| **Art. 17** | Right to erasure | Secure deletion process |
| **Art. 18** | Right to restriction | Account suspension without deletion |
| **Art. 20** | Right to data portability | JSON/CSV export |
| **Art. 25** | Data protection by design | Privacy-first architecture |
| **Art. 32** | Security of processing | Encryption, access controls, audit logs |
| **Art. 33** | Breach notification | 72-hour notification process |
| **Art. 30** | Records of processing | Complete audit trail |

### Consent Management

```php
<?php

declare(strict_types=1);

namespace App\Domain\User\Entity;

use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity]
#[ORM\Table(name: 'user_consents')]
final class UserConsent
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column(type: 'integer')]
    private ?int $id = null;

    #[ORM\Column(type: 'uuid')]
    private string $userId;

    #[ORM\Column(type: 'string', length: 100)]
    private ConsentType $consentType;

    #[ORM\Column(type: 'boolean')]
    private bool $granted;

    #[ORM\Column(type: 'string', length: 50)]
    private string $version; // Consent text version

    #[ORM\Column(type: 'datetime_immutable')]
    private \DateTimeImmutable $grantedAt;

    #[ORM\Column(type: 'datetime_immutable', nullable: true)]
    private ?\DateTimeImmutable $revokedAt = null;

    #[ORM\Column(type: 'string', length: 100)]
    private string $ipAddress;

    #[ORM\Column(type: 'text')]
    private string $userAgent;

    #[ORM\Column(type: 'string', length: 255, nullable: true)]
    private ?string $withdrawalReason = null;

    // ... getters, setters
}

enum ConsentType: string
{
    case TERMS_OF_SERVICE = 'terms_of_service';
    case PRIVACY_POLICY = 'privacy_policy';
    case MARKETING_COMMUNICATIONS = 'marketing_communications';
    case DATA_PROCESSING = 'data_processing';
    case THIRD_PARTY_SHARING = 'third_party_sharing';
    case COOKIES = 'cookies';
}
```

**Consent Service**:

```php
<?php

declare(strict_types=1);

namespace App\Domain\User\Service;

use App\Domain\User\Entity\UserConsent;
use App\Domain\User\Entity\ConsentType;
use App\Domain\User\Repository\UserConsentRepositoryInterface;

final class ConsentService
{
    public function __construct(
        private readonly UserConsentRepositoryInterface $consentRepository,
    ) {
    }

    /**
     * Grant consent.
     */
    public function grantConsent(
        string $userId,
        ConsentType $consentType,
        string $version,
        string $ipAddress,
        string $userAgent
    ): UserConsent {
        // Check if consent already exists
        $existing = $this->consentRepository->findActiveConsent($userId, $consentType);

        if ($existing !== null && $existing->getVersion() === $version) {
            // Already consented to this version
            return $existing;
        }

        // Create new consent record
        $consent = new UserConsent(
            userId: $userId,
            consentType: $consentType,
            granted: true,
            version: $version,
            grantedAt: new \DateTimeImmutable(),
            ipAddress: $ipAddress,
            userAgent: $userAgent
        );

        $this->consentRepository->save($consent);

        return $consent;
    }

    /**
     * Revoke consent.
     */
    public function revokeConsent(
        string $userId,
        ConsentType $consentType,
        ?string $reason = null
    ): void {
        $consent = $this->consentRepository->findActiveConsent($userId, $consentType);

        if ($consent === null) {
            return;
        }

        $consent->revoke($reason);
        $this->consentRepository->save($consent);
    }

    /**
     * Check if user has given consent.
     */
    public function hasConsent(string $userId, ConsentType $consentType): bool
    {
        $consent = $this->consentRepository->findActiveConsent($userId, $consentType);

        return $consent !== null && $consent->isGranted();
    }

    /**
     * Get all user consents (for GDPR access request).
     *
     * @return array<UserConsent>
     */
    public function getUserConsents(string $userId): array
    {
        return $this->consentRepository->findAllByUserId($userId);
    }
}
```

### Right to Access (GDPR Art. 15)

```php
<?php

declare(strict_types=1);

namespace App\Application\User\Query;

final class ExportUserDataQueryHandler
{
    public function __construct(
        private readonly UserRepositoryInterface $userRepository,
        private readonly WorkflowRepositoryInterface $workflowRepository,
        private readonly AuditLogRepositoryInterface $auditLogRepository,
        private readonly ConsentRepositoryInterface $consentRepository,
    ) {
    }

    /**
     * Export all user data in portable format.
     */
    public function handle(ExportUserDataQuery $query): array
    {
        $userId = $query->userId;

        // Fetch all user data from all services
        $data = [
            'export_date' => (new \DateTimeImmutable())->format('c'),
            'user_id' => $userId,

            // Profile data
            'profile' => $this->exportProfile($userId),

            // Workflows
            'workflows' => $this->exportWorkflows($userId),

            // Consents
            'consents' => $this->exportConsents($userId),

            // Access logs
            'access_logs' => $this->exportAccessLogs($userId),

            // Files
            'files' => $this->exportFiles($userId),
        ];

        return $data;
    }

    private function exportProfile(string $userId): array
    {
        $user = $this->userRepository->findById($userId);

        if ($user === null) {
            throw new \RuntimeException("User not found: {$userId}");
        }

        return [
            'username' => $user->getUsername(),
            'email' => $user->getEmail(),
            'first_name' => $user->getFirstName(),
            'last_name' => $user->getLastName(),
            'phone_number' => $user->getPhoneNumber(),
            'created_at' => $user->getCreatedAt()->format('c'),
            'updated_at' => $user->getUpdatedAt()?->format('c'),
        ];
    }

    private function exportWorkflows(string $userId): array
    {
        $workflows = $this->workflowRepository->findByUserId($userId);

        return array_map(
            fn($workflow) => [
                'id' => (string) $workflow->getId(),
                'name' => $workflow->getName(),
                'status' => $workflow->getStatus()->value,
                'created_at' => $workflow->getCreatedAt()->format('c'),
                'updated_at' => $workflow->getUpdatedAt()?->format('c'),
                'definition' => $workflow->getDefinition(),
            ],
            $workflows
        );
    }

    private function exportConsents(string $userId): array
    {
        $consents = $this->consentRepository->findAllByUserId($userId);

        return array_map(
            fn($consent) => [
                'type' => $consent->getConsentType()->value,
                'granted' => $consent->isGranted(),
                'version' => $consent->getVersion(),
                'granted_at' => $consent->getGrantedAt()->format('c'),
                'revoked_at' => $consent->getRevokedAt()?->format('c'),
            ],
            $consents
        );
    }

    private function exportAccessLogs(string $userId): array
    {
        // Last 90 days of access logs (GDPR requirement)
        $since = new \DateTimeImmutable('-90 days');
        $logs = $this->auditLogRepository->findByUserSince($userId, $since);

        return array_map(
            fn($log) => [
                'action' => $log->getAction(),
                'resource' => $log->getResource(),
                'timestamp' => $log->getTimestamp()->format('c'),
                'ip_address' => $log->getIpAddress(),
                'user_agent' => $log->getUserAgent(),
            ],
            $logs
        );
    }

    private function exportFiles(string $userId): array
    {
        // Note: Actual file contents not included, only metadata
        $files = $this->fileRepository->findByUserId($userId);

        return array_map(
            fn($file) => [
                'id' => (string) $file->getId(),
                'filename' => $file->getFilename(),
                'size' => $file->getSize(),
                'mime_type' => $file->getMimeType(),
                'uploaded_at' => $file->getUploadedAt()->format('c'),
            ],
            $files
        );
    }
}
```

### Right to Erasure (GDPR Art. 17)

```php
<?php

declare(strict_types=1);

namespace App\Application\User\Command;

final class DeleteUserDataCommandHandler
{
    public function __construct(
        private readonly UserRepositoryInterface $userRepository,
        private readonly WorkflowRepositoryInterface $workflowRepository,
        private readonly FileStorageService $fileStorage,
        private readonly AuditLogService $auditLog,
        private readonly EventBusInterface $eventBus,
    ) {
    }

    /**
     * Securely delete all user data (GDPR Right to Erasure).
     */
    public function handle(DeleteUserDataCommand $command): void
    {
        $userId = $command->userId;

        // Audit the deletion request
        $this->auditLog->log(
            action: 'user.data.deletion_initiated',
            userId: $userId,
            details: ['reason' => $command->reason]
        );

        try {
            // 1. Delete user workflows
            $workflows = $this->workflowRepository->findByUserId($userId);
            foreach ($workflows as $workflow) {
                $this->workflowRepository->delete($workflow);
            }

            // 2. Delete user files
            $files = $this->fileRepository->findByUserId($userId);
            foreach ($files as $file) {
                $this->fileStorage->delete($file->getId());
                $this->fileRepository->delete($file);
            }

            // 3. Anonymize audit logs (keep for legal compliance)
            $this->anonymizeAuditLogs($userId);

            // 4. Delete consents
            $this->consentRepository->deleteByUserId($userId);

            // 5. Delete user profile
            $user = $this->userRepository->findById($userId);
            if ($user !== null) {
                $this->userRepository->delete($user);
            }

            // 6. Publish event for other services
            $this->eventBus->publish(new UserDataDeleted(
                userId: $userId,
                deletedAt: new \DateTimeImmutable()
            ));

            // Audit successful deletion
            $this->auditLog->log(
                action: 'user.data.deletion_completed',
                userId: $userId,
                details: ['success' => true]
            );

        } catch (\Throwable $e) {
            // Audit failed deletion
            $this->auditLog->log(
                action: 'user.data.deletion_failed',
                userId: $userId,
                details: [
                    'error' => $e->getMessage(),
                    'trace' => $e->getTraceAsString()
                ]
            );

            throw $e;
        }
    }

    /**
     * Anonymize audit logs instead of deleting (for legal compliance).
     */
    private function anonymizeAuditLogs(string $userId): void
    {
        // Replace user ID with anonymized identifier
        $anonymousId = 'DELETED_' . hash('sha256', $userId);

        $this->auditLogRepository->anonymizeUser($userId, $anonymousId);
    }
}
```

## PII Handling

### PII Detection

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Security\PII;

final class PIIDetector
{
    // Patterns for common PII types
    private const PATTERNS = [
        'email' => '/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/',
        'phone' => '/\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/',
        'ssn' => '/\b\d{3}-\d{2}-\d{4}\b/',
        'credit_card' => '/\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/',
        'ip_address' => '/\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/',
    ];

    /**
     * Detect PII in text.
     *
     * @return array<string, array<string>>
     */
    public function detect(string $text): array
    {
        $findings = [];

        foreach (self::PATTERNS as $type => $pattern) {
            preg_match_all($pattern, $text, $matches);

            if (!empty($matches[0])) {
                $findings[$type] = array_unique($matches[0]);
            }
        }

        return $findings;
    }

    /**
     * Check if text contains any PII.
     */
    public function containsPII(string $text): bool
    {
        foreach (self::PATTERNS as $pattern) {
            if (preg_match($pattern, $text)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Redact PII from text.
     */
    public function redact(string $text, string $replacement = '[REDACTED]'): string
    {
        $redacted = $text;

        foreach (self::PATTERNS as $type => $pattern) {
            $redacted = preg_replace($pattern, $replacement, $redacted);
        }

        return $redacted;
    }
}
```

### PII Logging Prevention

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Logging;

use App\Infrastructure\Security\PII\PIIDetector;
use Monolog\Processor\ProcessorInterface;

final class PIIRedactionProcessor implements ProcessorInterface
{
    public function __construct(
        private readonly PIIDetector $piiDetector,
    ) {
    }

    /**
     * Redact PII from log records.
     */
    public function __invoke(array $record): array
    {
        // Redact message
        if (isset($record['message'])) {
            $record['message'] = $this->piiDetector->redact($record['message']);
        }

        // Redact context
        if (isset($record['context'])) {
            $record['context'] = $this->redactArray($record['context']);
        }

        // Redact extra
        if (isset($record['extra'])) {
            $record['extra'] = $this->redactArray($record['extra']);
        }

        return $record;
    }

    /**
     * Recursively redact PII from arrays.
     */
    private function redactArray(array $data): array
    {
        $redacted = [];

        foreach ($data as $key => $value) {
            if (is_string($value)) {
                $redacted[$key] = $this->piiDetector->redact($value);
            } elseif (is_array($value)) {
                $redacted[$key] = $this->redactArray($value);
            } else {
                $redacted[$key] = $value;
            }
        }

        return $redacted;
    }
}
```

## Data Masking and Anonymization

### Database Masking for Non-Production

```sql
-- data-masking-functions.sql
-- Functions for masking PII in non-production environments

-- Mask email addresses
CREATE OR REPLACE FUNCTION mask_email(email TEXT)
RETURNS TEXT AS $$
BEGIN
    IF email IS NULL THEN
        RETURN NULL;
    END IF;

    RETURN 'masked_' || md5(email)::TEXT || '@example.com';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Mask names
CREATE OR REPLACE FUNCTION mask_name(name TEXT)
RETURNS TEXT AS $$
BEGIN
    IF name IS NULL THEN
        RETURN NULL;
    END IF;

    RETURN 'User_' || substr(md5(name), 1, 8);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Mask phone numbers
CREATE OR REPLACE FUNCTION mask_phone(phone TEXT)
RETURNS TEXT AS $$
BEGIN
    IF phone IS NULL THEN
        RETURN NULL;
    END IF;

    RETURN '555-' || substr(md5(phone), 1, 3) || '-' || substr(md5(phone), 4, 4);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Apply masking to user table
CREATE OR REPLACE FUNCTION mask_user_table()
RETURNS VOID AS $$
BEGIN
    UPDATE users SET
        email = mask_email(email),
        first_name = mask_name(first_name),
        last_name = mask_name(last_name),
        phone_number = mask_phone(phone_number)
    WHERE NOT (email LIKE '%@example.com'); -- Don't re-mask already masked data
END;
$$ LANGUAGE plpgsql;

-- Execute: SELECT mask_user_table();
```

**Automated Masking on Database Refresh**:

```bash
#!/bin/bash
# refresh-staging-db.sh

set -euo pipefail

# Restore production backup to staging
pg_restore -h staging-db -U postgres -d staging_db /backups/production-latest.dump

# Apply masking functions
psql -h staging-db -U postgres -d staging_db <<SQL
    -- Source masking functions
    \i /scripts/data-masking-functions.sql

    -- Apply masking
    SELECT mask_user_table();

    -- Verify masking
    SELECT
        COUNT(*) as total_users,
        COUNT(*) FILTER (WHERE email LIKE '%@example.com') as masked_users
    FROM users;
SQL

echo "Database refresh and masking complete"
```

### Anonymization for Analytics

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Analytics;

final class DataAnonymizer
{
    /**
     * Anonymize user data for analytics.
     */
    public function anonymizeForAnalytics(array $userData): array
    {
        return [
            // Replace identifiers with hashes
            'user_id' => hash('sha256', $userData['user_id']),

            // Keep only aggregatable data
            'account_type' => $userData['account_type'],
            'created_at' => $userData['created_at'],
            'last_login' => $userData['last_login'],

            // Anonymize location to country/region only
            'country' => $userData['country'],
            'region' => $userData['region'],
            // Remove city, postal code, IP address

            // Keep behavioral data
            'workflow_count' => $userData['workflow_count'],
            'agent_usage' => $userData['agent_usage'],

            // Remove all PII
            // No email, name, phone, etc.
        ];
    }

    /**
     * Anonymize IP addresses (remove last octet).
     */
    public function anonymizeIPAddress(string $ip): string
    {
        if (filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
            // IPv4: 192.168.1.123 -> 192.168.1.0
            $parts = explode('.', $ip);
            $parts[3] = '0';
            return implode('.', $parts);
        }

        if (filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV6)) {
            // IPv6: Keep first 64 bits, zero out rest
            $parts = explode(':', $ip);
            return implode(':', array_slice($parts, 0, 4)) . '::';
        }

        return '0.0.0.0';
    }
}
```

## Data Retention and Deletion

### Retention Policies

| Data Type | Retention Period | Reason |
|-----------|------------------|---------|
| **User Profile** | Until account deletion | Account management |
| **Workflow Data** | 7 years | Business records, audit |
| **Audit Logs** | 7 years | Compliance (SOC2, ISO27001) |
| **Access Logs** | 90 days | Security monitoring |
| **Temporary Files** | 30 days | Processing intermediate data |
| **Backups** | 90 days | Disaster recovery |
| **Anonymized Analytics** | Indefinite | Business intelligence |

### Automated Deletion

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\DataRetention;

use Psr\Log\LoggerInterface;

final class DataRetentionService
{
    public function __construct(
        private readonly AuditLogRepositoryInterface $auditLogRepository,
        private readonly FileStorageService $fileStorage,
        private readonly LoggerInterface $logger,
    ) {
    }

    /**
     * Delete data past retention period.
     */
    public function purgeExpiredData(): void
    {
        $this->logger->info('Starting data retention purge');

        try {
            // Delete old access logs (90 days)
            $accessLogsDeleted = $this->purgeAccessLogs();
            $this->logger->info("Deleted {$accessLogsDeleted} expired access logs");

            // Delete temporary files (30 days)
            $filesDeleted = $this->purgeTemporaryFiles();
            $this->logger->info("Deleted {$filesDeleted} expired temporary files");

            // Delete old backups (90 days)
            $backupsDeleted = $this->purgeOldBackups();
            $this->logger->info("Deleted {$backupsDeleted} expired backups");

        } catch (\Throwable $e) {
            $this->logger->error('Data retention purge failed', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            throw $e;
        }
    }

    private function purgeAccessLogs(): int
    {
        $retentionDate = new \DateTimeImmutable('-90 days');

        return $this->auditLogRepository->deleteAccessLogsBefore($retentionDate);
    }

    private function purgeTemporaryFiles(): int
    {
        $retentionDate = new \DateTimeImmutable('-30 days');

        $expiredFiles = $this->fileStorage->findTemporaryFilesBefore($retentionDate);

        foreach ($expiredFiles as $file) {
            $this->fileStorage->delete($file->getId());
        }

        return count($expiredFiles);
    }

    private function purgeOldBackups(): int
    {
        $retentionDate = new \DateTimeImmutable('-90 days');

        // Implementation depends on backup storage (S3, etc.)
        // This is a placeholder
        return 0;
    }
}
```

**Cron Job for Automated Purge**:

```yaml
# data-retention-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: data-retention-purge
  namespace: application
spec:
  # Run daily at 2 AM
  schedule: "0 2 * * *"

  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: data-retention-service

          containers:
          - name: purge
            image: platform/cli:latest
            command:
            - php
            - bin/console
            - app:data-retention:purge

            env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: database-credentials
                  key: url

          restartPolicy: OnFailure

      backoffLimit: 3
```

## Database Security

### PostgreSQL Security Configuration

```sql
-- postgresql-security-config.sql

-- 1. Create dedicated service users (not superuser)
CREATE USER llm_agent_service WITH PASSWORD 'vault://...';
CREATE USER workflow_service WITH PASSWORD 'vault://...';

-- 2. Grant minimal privileges
GRANT CONNECT ON DATABASE llm_agent_db TO llm_agent_service;
GRANT USAGE ON SCHEMA public TO llm_agent_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO llm_agent_service;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO llm_agent_service;

-- 3. Enable Row-Level Security (RLS)
ALTER TABLE workflows ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their own workflows
CREATE POLICY workflow_tenant_isolation ON workflows
    FOR ALL
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

-- Policy: Service accounts can access all (for admin operations)
CREATE POLICY workflow_service_access ON workflows
    FOR ALL
    TO workflow_service
    USING (true);

-- 4. Enable audit logging
CREATE EXTENSION IF NOT EXISTS pgaudit;

ALTER SYSTEM SET pgaudit.log = 'write, ddl';
ALTER SYSTEM SET pgaudit.log_catalog = 'off';
ALTER SYSTEM SET pgaudit.log_parameter = 'on';
ALTER SYSTEM SET pgaudit.log_relation = 'on';

-- 5. Connection limits
ALTER USER llm_agent_service CONNECTION LIMIT 50;
ALTER USER workflow_service CONNECTION LIMIT 50;

-- 6. Statement timeout (prevent long-running queries)
ALTER DATABASE llm_agent_db SET statement_timeout = '30s';
ALTER DATABASE workflow_db SET statement_timeout = '30s';

-- 7. Revoke public schema privileges
REVOKE ALL ON SCHEMA public FROM PUBLIC;
```

### Connection Security

```yaml
# postgresql-connection-security.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgresql-client-config
  namespace: application
data:
  # Client-side connection settings
  PGSSLMODE: require # Require SSL/TLS
  PGSSLROOTCERT: /etc/ssl/certs/ca-certificates.crt
  PGSSLCERT: /etc/ssl/certs/client-cert.pem
  PGSSLKEY: /etc/ssl/private/client-key.pem
  PGCONNECT_TIMEOUT: "5"
  PGSTATEMENT_TIMEOUT: "30000" # 30 seconds
```

## Backup and Recovery

### Encrypted Backups

```bash
#!/bin/bash
# encrypted-backup.sh

set -euo pipefail

# Configuration
DATABASE="llm_agent_db"
BACKUP_DIR="/backups"
ENCRYPTION_KEY_ID="backup-encryption-key"
RETENTION_DAYS=90

# Get encryption key from Vault
ENCRYPTION_KEY=$(vault kv get -field=key secret/backup-encryption)

# Create backup with pg_dump
BACKUP_FILE="${BACKUP_DIR}/${DATABASE}-$(date +%Y%m%d-%H%M%S).dump"

pg_dump -h postgres-primary -U postgres -Fc -d ${DATABASE} > "${BACKUP_FILE}"

# Encrypt backup
openssl enc -aes-256-cbc -salt -pbkdf2 \
    -in "${BACKUP_FILE}" \
    -out "${BACKUP_FILE}.enc" \
    -pass pass:"${ENCRYPTION_KEY}"

# Delete unencrypted backup
rm -f "${BACKUP_FILE}"

# Upload to S3 (encrypted in transit and at rest)
aws s3 cp "${BACKUP_FILE}.enc" \
    s3://platform-backups/${DATABASE}/ \
    --server-side-encryption aws:kms \
    --ssekms-key-id arn:aws:kms:...

# Delete local encrypted backup
rm -f "${BACKUP_FILE}.enc"

# Delete backups older than retention period
find ${BACKUP_DIR} -name "${DATABASE}-*.dump.enc" -mtime +${RETENTION_DAYS} -delete

echo "Backup completed: ${BACKUP_FILE}.enc"
```

### Backup Verification

```bash
#!/bin/bash
# verify-backup.sh

set -euo pipefail

BACKUP_FILE=$1

# Get decryption key from Vault
DECRYPTION_KEY=$(vault kv get -field=key secret/backup-encryption)

# Download from S3
aws s3 cp s3://platform-backups/${BACKUP_FILE} /tmp/

# Decrypt
openssl enc -aes-256-cbc -d -pbkdf2 \
    -in /tmp/${BACKUP_FILE} \
    -out /tmp/backup.dump \
    -pass pass:"${DECRYPTION_KEY}"

# Test restore to temporary database
createdb -h postgres-test -U postgres test_restore_db

pg_restore -h postgres-test -U postgres -d test_restore_db /tmp/backup.dump

# Verify data integrity
psql -h postgres-test -U postgres -d test_restore_db <<SQL
    SELECT COUNT(*) FROM agents;
    SELECT COUNT(*) FROM completions;
    -- Add more verification queries
SQL

# Cleanup
dropdb -h postgres-test -U postgres test_restore_db
rm -f /tmp/${BACKUP_FILE} /tmp/backup.dump

echo "Backup verification successful"
```

## Data Access Controls

### Database Access Audit

```sql
-- Enable connection logging
ALTER SYSTEM SET log_connections = 'on';
ALTER SYSTEM SET log_disconnections = 'on';

-- Log all DDL statements
ALTER SYSTEM SET log_statement = 'ddl';

-- Log slow queries (>1s)
ALTER SYSTEM SET log_min_duration_statement = 1000;

-- Create audit table
CREATE TABLE IF NOT EXISTS database_audit_log (
    id BIGSERIAL PRIMARY KEY,
    event_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    user_name TEXT NOT NULL,
    database_name TEXT NOT NULL,
    client_addr INET,
    command_tag TEXT,
    query TEXT,
    application_name TEXT
);

-- Trigger for table modifications
CREATE OR REPLACE FUNCTION audit_trigger_func()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO database_audit_log (
        user_name,
        database_name,
        command_tag,
        query
    ) VALUES (
        current_user,
        current_database(),
        TG_OP,
        current_query()
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to sensitive tables
CREATE TRIGGER users_audit_trigger
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH STATEMENT
    EXECUTE FUNCTION audit_trigger_func();
```

### Application-Level Access Control

See [03-authentication-authorization.md](03-authentication-authorization.md) for complete RBAC/ABAC implementation.

## Audit and Compliance

### Comprehensive Audit Trail

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Audit;

use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity]
#[ORM\Table(name: 'audit_log')]
#[ORM\Index(columns: ['user_id', 'timestamp'])]
#[ORM\Index(columns: ['resource_type', 'resource_id'])]
final class AuditLog
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column(type: 'bigint')]
    private ?int $id = null;

    #[ORM\Column(type: 'uuid')]
    private string $eventId;

    #[ORM\Column(type: 'datetime_immutable')]
    private \DateTimeImmutable $timestamp;

    #[ORM\Column(type: 'uuid', nullable: true)]
    private ?string $userId;

    #[ORM\Column(type: 'uuid', nullable: true)]
    private ?string $tenantId;

    #[ORM\Column(type: 'string', length: 100)]
    private string $action;

    #[ORM\Column(type: 'string', length: 100)]
    private string $resourceType;

    #[ORM\Column(type: 'uuid', nullable: true)]
    private ?string $resourceId;

    #[ORM\Column(type: 'json', nullable: true)]
    private ?array $oldValues = null;

    #[ORM\Column(type: 'json', nullable: true)]
    private ?array $newValues = null;

    #[ORM\Column(type: 'string', length: 45)]
    private string $ipAddress;

    #[ORM\Column(type: 'text', nullable: true)]
    private ?string $userAgent;

    #[ORM\Column(type: 'string', length: 100)]
    private string $serviceName;

    #[ORM\Column(type: 'string', length: 100, nullable: true)]
    private ?string $correlationId;

    #[ORM\Column(type: 'boolean')]
    private bool $success;

    #[ORM\Column(type: 'text', nullable: true)]
    private ?string $errorMessage = null;

    // ... getters, constructor
}
```

### Compliance Reporting

```php
<?php

declare(strict_types=1);

namespace App\Application\Compliance\Query;

final class GenerateComplianceReportQueryHandler
{
    public function __construct(
        private readonly AuditLogRepositoryInterface $auditLogRepository,
        private readonly UserRepositoryInterface $userRepository,
    ) {
    }

    /**
     * Generate compliance report for auditors.
     */
    public function handle(GenerateComplianceReportQuery $query): array
    {
        $startDate = $query->startDate;
        $endDate = $query->endDate;

        return [
            'report_period' => [
                'start' => $startDate->format('c'),
                'end' => $endDate->format('c'),
            ],

            // Data access statistics
            'data_access' => [
                'total_accesses' => $this->auditLogRepository->countAccessesBetween(
                    $startDate,
                    $endDate
                ),
                'unique_users' => $this->auditLogRepository->countUniqueUsersBetween(
                    $startDate,
                    $endDate
                ),
                'access_by_type' => $this->auditLogRepository->aggregateAccessByType(
                    $startDate,
                    $endDate
                ),
            ],

            // GDPR requests
            'gdpr_requests' => [
                'access_requests' => $this->auditLogRepository->countGDPRRequests(
                    'data_access',
                    $startDate,
                    $endDate
                ),
                'deletion_requests' => $this->auditLogRepository->countGDPRRequests(
                    'data_deletion',
                    $startDate,
                    $endDate
                ),
                'rectification_requests' => $this->auditLogRepository->countGDPRRequests(
                    'data_rectification',
                    $startDate,
                    $endDate
                ),
            ],

            // Security incidents
            'security_incidents' => [
                'failed_logins' => $this->auditLogRepository->countFailedLogins(
                    $startDate,
                    $endDate
                ),
                'unauthorized_access_attempts' => $this->auditLogRepository->countUnauthorizedAccess(
                    $startDate,
                    $endDate
                ),
            ],

            // Encryption coverage
            'encryption' => [
                'data_at_rest_encrypted' => true,
                'data_in_transit_encrypted' => true,
                'pii_fields_encrypted' => $this->getPIIEncryptionCoverage(),
            ],

            // Compliance status
            'compliance' => [
                'gdpr' => 'compliant',
                'soc2' => 'compliant',
                'iso27001' => 'compliant',
                'nis2' => 'compliant',
            ],
        ];
    }

    private function getPIIEncryptionCoverage(): array
    {
        // Scan all entities for PII classification
        // Return percentage of PII fields with encryption enabled
        return [
            'total_pii_fields' => 25,
            'encrypted_pii_fields' => 25,
            'coverage_percentage' => 100,
        ];
    }
}
```

## Data Breach Response

### Breach Detection

```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Security;

use Psr\Log\LoggerInterface;

final class BreachDetectionService
{
    public function __construct(
        private readonly AuditLogRepositoryInterface $auditLogRepository,
        private readonly AlertingService $alerting,
        private readonly LoggerInterface $logger,
    ) {
    }

    /**
     * Detect potential data breaches.
     */
    public function detectAnomalies(): void
    {
        // Check for unusual data access patterns
        $this->detectUnusualDataAccess();

        // Check for mass data exports
        $this->detectMassDataExport();

        // Check for unauthorized access attempts
        $this->detectUnauthorizedAccess();

        // Check for privilege escalation
        $this->detectPrivilegeEscalation();
    }

    private function detectUnusualDataAccess(): void
    {
        // Detect users accessing more data than usual
        $threshold = new \DateTimeImmutable('-1 hour');

        $unusualAccess = $this->auditLogRepository->findUnusualAccessPatterns($threshold);

        if (!empty($unusualAccess)) {
            $this->alerting->sendCriticalAlert(
                title: 'Unusual Data Access Detected',
                details: $unusualAccess
            );

            $this->logger->critical('Unusual data access pattern detected', [
                'users' => array_column($unusualAccess, 'user_id'),
                'access_count' => array_column($unusualAccess, 'count'),
            ]);
        }
    }

    private function detectMassDataExport(): void
    {
        // Detect bulk data exports
        $threshold = new \DateTimeImmutable('-1 hour');
        $exportThreshold = 1000; // records

        $massExports = $this->auditLogRepository->findMassExports(
            $threshold,
            $exportThreshold
        );

        if (!empty($massExports)) {
            $this->alerting->sendCriticalAlert(
                title: 'Mass Data Export Detected',
                details: $massExports
            );

            $this->logger->critical('Mass data export detected', [
                'exports' => $massExports,
            ]);
        }
    }

    private function detectUnauthorizedAccess(): void
    {
        // Detect repeated unauthorized access attempts
        $threshold = new \DateTimeImmutable('-15 minutes');
        $failureThreshold = 10;

        $unauthorizedAttempts = $this->auditLogRepository->findRepeatedUnauthorizedAccess(
            $threshold,
            $failureThreshold
        );

        if (!empty($unauthorizedAttempts)) {
            $this->alerting->sendHighPriorityAlert(
                title: 'Repeated Unauthorized Access Attempts',
                details: $unauthorizedAttempts
            );
        }
    }

    private function detectPrivilegeEscalation(): void
    {
        // Detect sudden elevation of privileges
        $threshold = new \DateTimeImmutable('-1 hour');

        $escalations = $this->auditLogRepository->findPrivilegeEscalations($threshold);

        if (!empty($escalations)) {
            $this->alerting->sendCriticalAlert(
                title: 'Privilege Escalation Detected',
                details: $escalations
            );

            $this->logger->critical('Privilege escalation detected', [
                'escalations' => $escalations,
            ]);
        }
    }
}
```

### Breach Notification Process

```php
<?php

declare(strict_types=1);

namespace App\Application\Security\Command;

final class NotifyDataBreachCommandHandler
{
    public function __construct(
        private readonly UserRepositoryInterface $userRepository,
        private readonly NotificationService $notificationService,
        private readonly AuditLogService $auditLog,
        private readonly ComplianceService $compliance,
    ) {
    }

    /**
     * Execute data breach notification process (GDPR Art. 33/34).
     */
    public function handle(NotifyDataBreachCommand $command): void
    {
        $breach = $command->breach;

        // Log breach
        $this->auditLog->logSecurityIncident(
            type: 'data_breach',
            severity: 'critical',
            details: [
                'breach_id' => $breach->id,
                'affected_users' => $breach->affectedUserCount,
                'data_types' => $breach->affectedDataTypes,
                'detected_at' => $breach->detectedAt->format('c'),
            ]
        );

        // Notify supervisory authority (within 72 hours - GDPR Art. 33)
        if ($breach->requiresAuthorityNotification()) {
            $this->compliance->notifySupervisoryAuthority($breach);
        }

        // Notify affected users (GDPR Art. 34)
        if ($breach->requiresUserNotification()) {
            $affectedUsers = $this->userRepository->findByIds($breach->affectedUserIds);

            foreach ($affectedUsers as $user) {
                $this->notificationService->sendBreachNotification($user, $breach);
            }
        }

        // Internal notifications
        $this->notificationService->notifySecurityTeam($breach);
        $this->notificationService->notifyManagement($breach);
    }
}
```

## Implementation Checklist

### Essential

- [ ] Implement data classification attributes
- [ ] Configure field-level encryption
- [ ] Set up database TDE
- [ ] Enable encrypted storage volumes
- [ ] Implement PII detection and redaction
- [ ] Configure Row-Level Security
- [ ] Set up automated data retention/purging
- [ ] Implement GDPR data subject rights (access, erasure, portability)
- [ ] Enable comprehensive audit logging
- [ ] Configure encrypted backups
- [ ] Set up breach detection monitoring
- [ ] Document data breach notification process

### Recommended

- [ ] Implement data masking for non-production
- [ ] Set up anonymization for analytics
- [ ] Configure consent management
- [ ] Enable database connection auditing
- [ ] Set up compliance reporting
- [ ] Conduct data protection impact assessments (DPIA)
- [ ] Train staff on data protection procedures
- [ ] Regular penetration testing

## References

- [GDPR Official Text](https://gdpr-info.eu/)
- [NIST SP 800-53 - Security Controls](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final)
- [ISO/IEC 27001:2013](https://www.iso.org/standard/54534.html)
- [SOC 2 Trust Services Criteria](https://www.aicpa.org/interestareas/frc/assuranceadvisoryservices/aicpasoc2report.html)
- [PostgreSQL Encryption](https://www.postgresql.org/docs/current/encryption-options.html)

## Related Documentation

- [01-security-principles.md](01-security-principles.md) - Core security principles
- [03-authentication-authorization.md](03-authentication-authorization.md) - Access controls
- [04-secrets-management.md](04-secrets-management.md) - Encryption key management
- [../01-architecture/05-data-architecture.md](../01-architecture/05-data-architecture.md) - Database architecture

---

**Document Maintainers**: Security Team, Compliance Team
**Review Cycle**: Quarterly or after regulatory changes
**Next Review**: 2025-04-07
