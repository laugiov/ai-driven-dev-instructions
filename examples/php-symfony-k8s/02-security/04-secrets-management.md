# Secrets Management

## Overview

This document provides comprehensive guidance on managing secrets (API keys, passwords, certificates, encryption keys) using HashiCorp Vault. Proper secrets management is critical for security, compliance, and operational excellence.

## Why HashiCorp Vault?

### Problems with Traditional Secrets Management

**❌ Environment Variables**
- Visible in process listings
- Logged in application crashes
- No rotation mechanism
- No audit trail
- Difficult to revoke

**❌ Configuration Files**
- Committed to Git (even accidentally)
- No encryption at rest
- Static, never rotated
- Shared across environments
- No access control

**❌ Kubernetes Secrets**
- Base64 encoded (not encrypted)
- Visible to all pods in namespace
- No rotation
- Limited audit capabilities

### ✅ Vault Benefits

**Security**
- Encrypted at rest and in transit
- Dynamic secrets (generated on-demand)
- Automatic rotation
- Lease-based access
- Complete audit trail

**Operations**
- Centralized management
- Fine-grained access control
- Versioned secrets
- Rollback capability
- Multi-cloud support

**Compliance**
- Complete audit logs
- Access policies
- Encryption as a service
- Meets SOC2, ISO27001, GDPR requirements

## Vault Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Applications                             │
│  (Microservices requesting secrets)                         │
└────────────┬────────────────────────────────────────────────┘
             │
             │ HTTPS + TLS
             │
┌────────────▼────────────────────────────────────────────────┐
│                  Vault API                                   │
│  - Authentication                                            │
│  - Authorization                                             │
│  - Lease Management                                          │
└────────────┬────────────────────────────────────────────────┘
             │
    ┌────────┴────────┐
    │                 │
┌───▼──────────┐  ┌──▼──────────────┐
│ Secret       │  │  Dynamic Secret  │
│ Engines      │  │  Engines         │
│              │  │                  │
│ - KV v2      │  │ - Database       │
│ - Transit    │  │ - AWS            │
│ - PKI        │  │ - SSH            │
└──────────────┘  └──────────────────┘
       │                  │
       └────────┬─────────┘
                │
    ┌───────────▼──────────┐
    │  Storage Backend     │
    │  (Encrypted)         │
    │                      │
    │  - Consul            │
    │  - etcd              │
    │  - PostgreSQL        │
    └──────────────────────┘
```

## Vault Deployment

### Kubernetes Deployment

```yaml
# vault-deployment.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault
  namespace: vault
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vault-auth-delegator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
  - kind: ServiceAccount
    name: vault
    namespace: vault
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: vault
  namespace: vault
spec:
  serviceName: vault
  replicas: 3  # High availability
  selector:
    matchLabels:
      app: vault
  template:
    metadata:
      labels:
        app: vault
    spec:
      serviceAccountName: vault
      containers:
      - name: vault
        image: hashicorp/vault:1.15
        ports:
        - containerPort: 8200
          name: api
        - containerPort: 8201
          name: cluster
        env:
        - name: VAULT_ADDR
          value: "https://127.0.0.1:8200"
        - name: VAULT_API_ADDR
          value: "https://vault.vault.svc.cluster.local:8200"
        - name: SKIP_CHOWN
          value: "true"
        - name: SKIP_SETCAP
          value: "true"
        volumeMounts:
        - name: config
          mountPath: /vault/config
        - name: data
          mountPath: /vault/data
        securityContext:
          runAsNonRoot: true
          runAsUser: 100
          capabilities:
            add:
            - IPC_LOCK
        resources:
          requests:
            memory: 256Mi
            cpu: 250m
          limits:
            memory: 512Mi
            cpu: 500m
        livenessProbe:
          httpGet:
            path: /v1/sys/health?standbyok=true
            port: 8200
            scheme: HTTPS
          initialDelaySeconds: 60
          periodSeconds: 5
        readinessProbe:
          httpGet:
            path: /v1/sys/health?standbyok=true&perfstandbyok=true
            port: 8200
            scheme: HTTPS
          initialDelaySeconds: 5
          periodSeconds: 3
      volumes:
      - name: config
        configMap:
          name: vault-config
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
---
apiVersion: v1
kind: Service
metadata:
  name: vault
  namespace: vault
spec:
  selector:
    app: vault
  ports:
  - name: api
    port: 8200
    targetPort: 8200
  - name: cluster
    port: 8201
    targetPort: 8201
  clusterIP: None  # Headless for StatefulSet
```

### Vault Configuration

```hcl
# vault-config.hcl
ui = true

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_cert_file = "/vault/tls/tls.crt"
  tls_key_file = "/vault/tls/tls.key"
  tls_min_version = "tls13"
}

storage "postgresql" {
  connection_url = "postgresql://vault:password@postgres:5432/vault?sslmode=require"
  ha_enabled = true
}

seal "awskms" {
  region = "us-east-1"
  kms_key_id = "alias/vault-unseal-key"
}

api_addr = "https://vault.vault.svc.cluster.local:8200"
cluster_addr = "https://vault-0.vault.vault.svc.cluster.local:8201"

telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = true
}
```

### Initialization and Unsealing

```bash
# Initialize Vault (do this ONCE)
kubectl exec -it vault-0 -n vault -- vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  > vault-keys.txt

# IMPORTANT: Store unseal keys and root token securely
# - 5 unseal key shares generated
# - Need 3 shares to unseal
# - Root token for initial setup

# Unseal Vault (required after restart)
kubectl exec -it vault-0 -n vault -- vault operator unseal <KEY1>
kubectl exec -it vault-0 -n vault -- vault operator unseal <KEY2>
kubectl exec -it vault-0 -n vault -- vault operator unseal <KEY3>

# Check status
kubectl exec -it vault-0 -n vault -- vault status
```

**Auto-Unseal with AWS KMS** (Production):
```hcl
# No manual unsealing required
seal "awskms" {
  region = "us-east-1"
  kms_key_id = "alias/vault-unseal-key"
}
```

## Secret Engines

### 1. KV (Key-Value) Version 2

**Use Case**: Static secrets (API keys, passwords, certificates)

**Enable**:
```bash
vault secrets enable -path=secret kv-v2
```

**Features**:
- Versioning (keep history of secret changes)
- Soft delete (can restore deleted secrets)
- Metadata (when created, who accessed)
- Check-and-Set (prevent concurrent updates)

**Write Secret**:
```bash
# Store OpenAI API key
vault kv put secret/openai \
  api_key="sk-proj-..." \
  organization="org-..."

# Store database credentials
vault kv put secret/database/workflow \
  username="workflow_user" \
  password="secure_password_here" \
  host="postgres-workflow.production.svc.cluster.local" \
  port="5432" \
  database="workflow_db"

# Store with metadata
vault kv metadata put secret/openai \
  max-versions=5 \
  cas-required=false
```

**Read Secret**:
```bash
# Latest version
vault kv get secret/openai

# Specific version
vault kv get -version=2 secret/openai

# Get as JSON
vault kv get -format=json secret/openai | jq -r '.data.data.api_key'
```

**Versioning**:
```bash
# List versions
vault kv metadata get secret/openai

# Rollback to previous version
vault kv rollback -version=2 secret/openai

# Delete specific version
vault kv delete -versions=3 secret/openai

# Undelete
vault kv undelete -versions=3 secret/openai

# Destroy (permanent)
vault kv destroy -versions=3 secret/openai
```

### 2. Database Secrets Engine

**Use Case**: Dynamic database credentials (generated on-demand, auto-rotated)

**Enable and Configure**:
```bash
# Enable database engine
vault secrets enable database

# Configure PostgreSQL connection
vault write database/config/workflow-db \
  plugin_name=postgresql-database-plugin \
  allowed_roles="workflow-readonly,workflow-readwrite" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/workflow_db?sslmode=require" \
  username="vault_admin" \
  password="vault_admin_password"

# Rotate root credentials (Vault becomes the only one who knows)
vault write -force database/rotate-root/workflow-db
```

**Create Roles**:
```bash
# Read-only role
vault write database/roles/workflow-readonly \
  db_name=workflow-db \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

# Read-write role
vault write database/roles/workflow-readwrite \
  db_name=workflow-db \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"
```

**Generate Credentials**:
```bash
# Get temporary database credentials
vault read database/creds/workflow-readwrite

# Output:
# Key                Value
# ---                -----
# lease_id           database/creds/workflow-readwrite/abc123
# lease_duration     1h
# lease_renewable    true
# password           A1a-randompassword
# username           v-token-workflow-readwrite-xyz
```

**PHP Usage**:
```php
// src/Infrastructure/Vault/VaultDatabaseCredentials.php
final readonly class VaultDatabaseCredentials
{
    public function __construct(
        private VaultClientInterface $vault,
    ) {}

    public function getCredentials(string $role): DatabaseCredentials
    {
        $response = $this->vault->read("database/creds/{$role}");

        return new DatabaseCredentials(
            username: $response['data']['username'],
            password: $response['data']['password'],
            leaseId: $response['lease_id'],
            leaseDuration: $response['lease_duration'],
        );
    }

    public function renewLease(string $leaseId, int $increment = 3600): void
    {
        $this->vault->write('sys/leases/renew', [
            'lease_id' => $leaseId,
            'increment' => $increment,
        ]);
    }

    public function revokeLease(string $leaseId): void
    {
        $this->vault->write('sys/leases/revoke', [
            'lease_id' => $leaseId,
        ]);
    }
}

// Usage in service
$credentials = $this->vaultCredentials->getCredentials('workflow-readwrite');

$dsn = sprintf(
    'postgresql://%s:%s@postgres:5432/workflow_db',
    $credentials->username,
    $credentials->password
);

// Create connection
$connection = new PDO($dsn);

// Renew lease before expiration
$this->vaultCredentials->renewLease($credentials->leaseId);

// Revoke when done (credentials deleted from database)
$this->vaultCredentials->revokeLease($credentials->leaseId);
```

**Benefits**:
- ✅ Credentials generated on-demand
- ✅ Automatic expiration (1 hour default)
- ✅ No long-lived credentials
- ✅ Automatic cleanup on expiration
- ✅ Complete audit trail

### 3. Transit Secrets Engine

**Use Case**: Encryption as a Service (encrypt/decrypt data without storing encryption keys in application)

**Enable and Configure**:
```bash
# Enable transit engine
vault secrets enable transit

# Create encryption key
vault write -f transit/keys/workflow-data

# Configure key
vault write transit/keys/workflow-data/config \
  min_decryption_version=1 \
  min_encryption_version=0 \
  deletion_allowed=false \
  exportable=false \
  allow_plaintext_backup=false
```

**Encrypt/Decrypt**:
```bash
# Encrypt data
vault write transit/encrypt/workflow-data \
  plaintext=$(echo -n "sensitive data" | base64)

# Output:
# ciphertext: vault:v1:abcdefghijk...

# Decrypt data
vault write transit/decrypt/workflow-data \
  ciphertext="vault:v1:abcdefghijk..."

# Output (base64):
# plaintext: c2Vuc2l0aXZlIGRhdGE=
```

**PHP Usage**:
```php
// src/Infrastructure/Encryption/VaultEncryption.php
final readonly class VaultEncryption implements EncryptionInterface
{
    public function __construct(
        private VaultClientInterface $vault,
        private string $keyName = 'workflow-data',
    ) {}

    public function encrypt(string $plaintext): string
    {
        $response = $this->vault->write("transit/encrypt/{$this->keyName}", [
            'plaintext' => base64_encode($plaintext),
        ]);

        return $response['data']['ciphertext'];
    }

    public function decrypt(string $ciphertext): string
    {
        $response = $this->vault->write("transit/decrypt/{$this->keyName}", [
            'ciphertext' => $ciphertext,
        ]);

        return base64_decode($response['data']['plaintext']);
    }

    public function encryptBatch(array $plaintexts): array
    {
        $batchInput = array_map(
            fn($text) => ['plaintext' => base64_encode($text)],
            $plaintexts
        );

        $response = $this->vault->write("transit/encrypt/{$this->keyName}", [
            'batch_input' => $batchInput,
        ]);

        return array_column($response['data']['batch_results'], 'ciphertext');
    }

    public function rotateKey(): void
    {
        $this->vault->write("transit/keys/{$this->keyName}/rotate", []);
    }
}

// Usage: Encrypt PII before storing
$encrypted = $this->encryption->encrypt($user->getEmail());
$user->setEmailEncrypted($encrypted);

// Decrypt when needed
$email = $this->encryption->decrypt($user->getEmailEncrypted());
```

**Key Rotation**:
```bash
# Rotate encryption key
vault write -f transit/keys/workflow-data/rotate

# Old data stays encrypted with old key version
# New data encrypted with new key version
# Both can be decrypted transparently

# Rewrap to new key version
vault write transit/rewrap/workflow-data \
  ciphertext="vault:v1:abcdefghijk..."
```

### 4. PKI Secrets Engine

**Use Case**: Generate TLS certificates dynamically

**Enable and Configure**:
```bash
# Enable PKI engine
vault secrets enable pki

# Set max lease TTL to 10 years
vault secrets tune -max-lease-ttl=87600h pki

# Generate root CA
vault write -field=certificate pki/root/generate/internal \
  common_name="AI Workflow Platform Root CA" \
  ttl=87600h > CA_cert.crt

# Configure CA and CRL URLs
vault write pki/config/urls \
  issuing_certificates="https://vault.example.com:8200/v1/pki/ca" \
  crl_distribution_points="https://vault.example.com:8200/v1/pki/crl"

# Create role for service certificates
vault write pki/roles/workflow-service \
  allowed_domains="workflow-service.production.svc.cluster.local" \
  allow_subdomains=false \
  max_ttl="720h" \
  ttl="24h"
```

**Generate Certificate**:
```bash
# Request certificate
vault write pki/issue/workflow-service \
  common_name="workflow-service.production.svc.cluster.local" \
  ttl="24h"

# Output:
# certificate     -----BEGIN CERTIFICATE-----...
# issuing_ca      -----BEGIN CERTIFICATE-----...
# private_key     -----BEGIN RSA PRIVATE KEY-----...
# serial_number   39:dd:2e...
```

**Automatic Certificate Renewal** (sidecar):
```yaml
# cert-renewer-sidecar.yaml
- name: cert-renewer
  image: hashicorp/vault:1.15
  command:
  - /bin/sh
  - -c
  - |
    while true; do
      vault write -format=json pki/issue/workflow-service \
        common_name="workflow-service.production.svc.cluster.local" \
        ttl="24h" \
        | jq -r '.data.certificate' > /certs/tls.crt

      vault write -format=json pki/issue/workflow-service \
        common_name="workflow-service.production.svc.cluster.local" \
        ttl="24h" \
        | jq -r '.data.private_key' > /certs/tls.key

      sleep 21600  # Renew every 6 hours (24h cert)
    done
  volumeMounts:
  - name: certs
    mountPath: /certs
```

## Authentication Methods

### 1. Kubernetes Auth

**Enable and Configure**:
```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Configure with K8s API
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token

# Create role for workflow service
vault write auth/kubernetes/role/workflow-service \
  bound_service_account_names=workflow-service \
  bound_service_account_namespaces=production \
  policies=workflow-service-policy \
  ttl=1h
```

**Service Authentication** (in Pod):
```php
// src/Infrastructure/Vault/KubernetesVaultAuth.php
final readonly class KubernetesVaultAuth
{
    public function __construct(
        private string $vaultAddr,
        private string $role,
    ) {}

    public function authenticate(): string
    {
        // Read Kubernetes service account JWT
        $jwt = file_get_contents('/var/run/secrets/kubernetes.io/serviceaccount/token');

        // Login to Vault
        $response = $this->httpClient->request('POST', "{$this->vaultAddr}/v1/auth/kubernetes/login", [
            'json' => [
                'role' => $this->role,
                'jwt' => $jwt,
            ],
        ]);

        $data = $response->toArray();

        // Return Vault token
        return $data['auth']['client_token'];
    }
}

// Usage
$vaultToken = $this->kubernetesAuth->authenticate();

// Use token for subsequent Vault requests
$this->vaultClient->setToken($vaultToken);
```

### 2. AppRole Auth

**Use Case**: For non-Kubernetes workloads (CI/CD, external scripts)

**Configure**:
```bash
# Enable AppRole
vault auth enable approle

# Create policy
vault policy write workflow-ci -<<EOF
path "secret/data/ci/*" {
  capabilities = ["read"]
}
path "database/creds/workflow-readonly" {
  capabilities = ["read"]
}
EOF

# Create AppRole
vault write auth/approle/role/workflow-ci \
  token_policies="workflow-ci" \
  token_ttl=1h \
  token_max_ttl=4h

# Get Role ID (not secret, can be in config)
vault read auth/approle/role/workflow-ci/role-id

# Generate Secret ID (secret, inject at runtime)
vault write -f auth/approle/role/workflow-ci/secret-id
```

**Usage in CI/CD**:
```bash
# GitHub Actions workflow
- name: Authenticate with Vault
  env:
    VAULT_ROLE_ID: ${{ secrets.VAULT_ROLE_ID }}
    VAULT_SECRET_ID: ${{ secrets.VAULT_SECRET_ID }}
  run: |
    VAULT_TOKEN=$(vault write -field=token auth/approle/login \
      role_id="$VAULT_ROLE_ID" \
      secret_id="$VAULT_SECRET_ID")

    echo "VAULT_TOKEN=$VAULT_TOKEN" >> $GITHUB_ENV

- name: Get secrets
  run: |
    vault kv get -field=api_key secret/ci/openai > openai_key.txt
```

### 3. Token Auth

**Use Case**: Temporary tokens for testing/development

```bash
# Create token with specific policy
vault token create -policy=workflow-service-policy -ttl=1h

# Create periodic token (can be renewed indefinitely)
vault token create -policy=workflow-service-policy -period=24h

# Lookup token info
vault token lookup <TOKEN>

# Renew token
vault token renew <TOKEN>

# Revoke token
vault token revoke <TOKEN>
```

## Access Policies

### Policy Structure

```hcl
# workflow-service-policy.hcl

# Read OpenAI credentials
path "secret/data/openai" {
  capabilities = ["read"]
}

# Read Anthropic credentials
path "secret/data/anthropic" {
  capabilities = ["read"]
}

# Generate database credentials
path "database/creds/workflow-readwrite" {
  capabilities = ["read"]
}

# Encrypt/decrypt with Transit
path "transit/encrypt/workflow-data" {
  capabilities = ["update"]
}

path "transit/decrypt/workflow-data" {
  capabilities = ["update"]
}

# Issue TLS certificates
path "pki/issue/workflow-service" {
  capabilities = ["create", "update"]
}

# Renew leases
path "sys/leases/renew" {
  capabilities = ["update"]
}

# Deny access to other secrets
path "secret/data/*" {
  capabilities = ["deny"]
}
```

**Apply Policy**:
```bash
vault policy write workflow-service-policy workflow-service-policy.hcl

# List policies
vault policy list

# Read policy
vault policy read workflow-service-policy
```

### Principle of Least Privilege

**Per-Service Policies**:

```hcl
# llm-agent-service-policy.hcl
path "secret/data/openai" {
  capabilities = ["read"]
}

path "secret/data/anthropic" {
  capabilities = ["read"]
}

path "database/creds/llm-agent-readwrite" {
  capabilities = ["read"]
}

# notification-service-policy.hcl
path "secret/data/smtp" {
  capabilities = ["read"]
}

path "secret/data/twilio" {
  capabilities = ["read"]
}

path "database/creds/notification-readwrite" {
  capabilities = ["read"]
}

# audit-service-policy.hcl
path "database/creds/audit-readonly" {
  capabilities = ["read"]
}

path "database/creds/audit-readwrite" {
  capabilities = ["read"]
}
```

## Vault Client Integration

### PHP Vault Client

```php
// src/Infrastructure/Vault/VaultClient.php
namespace App\Infrastructure\Vault;

use Symfony\Contracts\HttpClient\HttpClientInterface;

final class VaultClient implements VaultClientInterface
{
    private ?string $token = null;

    public function __construct(
        private readonly HttpClientInterface $httpClient,
        private readonly string $vaultAddr,
        private readonly KubernetesVaultAuth $auth,
        private readonly CacheInterface $cache,
    ) {}

    public function read(string $path): array
    {
        $this->ensureAuthenticated();

        $response = $this->httpClient->request('GET', "{$this->vaultAddr}/v1/{$path}", [
            'headers' => [
                'X-Vault-Token' => $this->token,
            ],
        ]);

        return $response->toArray();
    }

    public function write(string $path, array $data): array
    {
        $this->ensureAuthenticated();

        $response = $this->httpClient->request('POST', "{$this->vaultAddr}/v1/{$path}", [
            'headers' => [
                'X-Vault-Token' => $this->token,
            ],
            'json' => $data,
        ]);

        return $response->toArray();
    }

    public function list(string $path): array
    {
        $this->ensureAuthenticated();

        $response = $this->httpClient->request('LIST', "{$this->vaultAddr}/v1/{$path}", [
            'headers' => [
                'X-Vault-Token' => $this->token,
            ],
        ]);

        return $response->toArray()['data']['keys'] ?? [];
    }

    private function ensureAuthenticated(): void
    {
        if ($this->token === null || $this->isTokenExpired()) {
            $this->token = $this->auth->authenticate();

            // Cache token
            $this->cache->set('vault_token', $this->token, ttl: 3000); // 50 min (token TTL is 1h)
        }
    }

    private function isTokenExpired(): bool
    {
        try {
            $response = $this->httpClient->request('GET', "{$this->vaultAddr}/v1/auth/token/lookup-self", [
                'headers' => [
                    'X-Vault-Token' => $this->token,
                ],
            ]);

            $data = $response->toArray();
            $ttl = $data['data']['ttl'];

            return $ttl < 300; // Renew if less than 5 minutes left
        } catch (\Exception $e) {
            return true;
        }
    }

    public function setToken(string $token): void
    {
        $this->token = $token;
    }
}
```

### Secrets Service

```php
// src/Infrastructure/Vault/SecretsService.php
final readonly class SecretsService
{
    public function __construct(
        private VaultClientInterface $vault,
        private CacheInterface $cache,
    ) {}

    public function getOpenAIKey(): string
    {
        return $this->cache->get('secret_openai_key', function() {
            $response = $this->vault->read('secret/data/openai');
            return $response['data']['data']['api_key'];
        }, ttl: 3600);
    }

    public function getAnthropicKey(): string
    {
        return $this->cache->get('secret_anthropic_key', function() {
            $response = $this->vault->read('secret/data/anthropic');
            return $response['data']['data']['api_key'];
        }, ttl: 3600);
    }

    public function getDatabaseCredentials(string $role): DatabaseCredentials
    {
        // Don't cache database credentials (they're dynamic)
        $response = $this->vault->read("database/creds/{$role}");

        return new DatabaseCredentials(
            username: $response['data']['username'],
            password: $response['data']['password'],
            leaseId: $response['lease_id'],
            leaseDuration: $response['lease_duration'],
        );
    }

    public function encrypt(string $plaintext): string
    {
        $response = $this->vault->write('transit/encrypt/workflow-data', [
            'plaintext' => base64_encode($plaintext),
        ]);

        return $response['data']['ciphertext'];
    }

    public function decrypt(string $ciphertext): string
    {
        $response = $this->vault->write('transit/decrypt/workflow-data', [
            'ciphertext' => $ciphertext,
        ]);

        return base64_decode($response['data']['plaintext']);
    }
}
```

## Secret Rotation

### Automatic Rotation

**Database Root Credentials**:
```bash
# Rotate database root password
# Vault updates the password and becomes the only one who knows it
vault write -force database/rotate-root/workflow-db
```

**Encryption Keys**:
```bash
# Rotate Transit encryption key
vault write -f transit/keys/workflow-data/rotate

# Old data can still be decrypted
# New encryptions use new key version
# Rewrap old data to new key version
vault write transit/rewrap/workflow-data \
  ciphertext="vault:v1:old_ciphertext"
```

### Manual Secret Updates

```bash
# Update secret (creates new version)
vault kv put secret/openai api_key="sk-proj-new-key"

# Application automatically gets new version on next read
```

### Rotation Schedule

| Secret Type | Rotation Frequency | Method |
|-------------|-------------------|--------|
| API Keys | 90 days | Manual update in Vault |
| Database Root | 30 days | Automatic (Vault) |
| Database Dynamic | 1 hour | Automatic (lease expiration) |
| TLS Certificates | 24 hours | Automatic (PKI engine) |
| Encryption Keys | 90 days | Automatic (Transit engine) |
| Service Tokens | 1 hour | Automatic (Kubernetes auth) |

## Audit Logging

### Enable Audit Device

```bash
# Enable file audit device
vault audit enable file file_path=/vault/audit/audit.log

# Enable syslog audit device
vault audit enable syslog
```

### Audit Log Format

```json
{
  "time": "2025-01-07T10:30:00Z",
  "type": "response",
  "auth": {
    "client_token": "hmac-sha256:abcd1234",
    "accessor": "hmac-sha256:xyz789",
    "display_name": "kubernetes-production-workflow-service",
    "policies": ["default", "workflow-service-policy"],
    "token_policies": ["default", "workflow-service-policy"],
    "metadata": {
      "role": "workflow-service",
      "service_account_name": "workflow-service",
      "service_account_namespace": "production"
    }
  },
  "request": {
    "id": "unique-request-id",
    "operation": "read",
    "client_token": "hmac-sha256:abcd1234",
    "client_token_accessor": "hmac-sha256:xyz789",
    "path": "secret/data/openai",
    "data": null,
    "remote_address": "10.244.0.5"
  },
  "response": {
    "data": {
      "data": {
        "api_key": "hmac-sha256:encrypted_value"
      },
      "metadata": {
        "created_time": "2025-01-01T00:00:00Z",
        "deletion_time": "",
        "destroyed": false,
        "version": 3
      }
    }
  }
}
```

**Important**: Secret values are HMAC-SHA256 hashed in audit logs, not plaintext.

### Monitoring Audit Logs

```bash
# Failed authentication attempts
grep '"error":"permission denied"' /vault/audit/audit.log

# Secret access by path
grep '"path":"secret/data/openai"' /vault/audit/audit.log

# Access by service
grep '"service_account_name":"workflow-service"' /vault/audit/audit.log
```

## Disaster Recovery

### Backup

**Vault Data Backup**:
```bash
# Snapshot (requires root token or sudo permission)
vault operator raft snapshot save vault-snapshot.snap

# Restore
vault operator raft snapshot restore vault-snapshot.snap
```

**Auto-Backup Script**:
```bash
#!/bin/bash
# backup-vault.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/vault"

# Take snapshot
vault operator raft snapshot save "$BACKUP_DIR/vault-$DATE.snap"

# Upload to S3
aws s3 cp "$BACKUP_DIR/vault-$DATE.snap" s3://backups/vault/

# Keep only last 30 days locally
find "$BACKUP_DIR" -name "vault-*.snap" -mtime +30 -delete

# Keep 90 days in S3 (lifecycle policy)
```

### Disaster Recovery Plan

**Scenario 1: Vault Pod Failure**
- Kubernetes automatically restarts pod
- Pod reseals (if not using auto-unseal)
- Unseal with 3 of 5 keys
- Services reconnect automatically

**Scenario 2: Complete Vault Loss**
1. Deploy new Vault cluster
2. Restore from snapshot
3. Unseal with keys
4. Verify data integrity
5. Update Vault address in services
6. Services reconnect

**Scenario 3: Lost Unseal Keys**
- With auto-unseal (AWS KMS): No problem, automatic
- Without auto-unseal: Cannot recover (emphasizes importance of key management)

## Security Best Practices

### ✅ DO

- ✅ Use dynamic secrets whenever possible
- ✅ Rotate secrets regularly
- ✅ Use short TTLs (1 hour for database credentials)
- ✅ Enable audit logging
- ✅ Use auto-unseal in production
- ✅ Restrict policies to least privilege
- ✅ Monitor failed authentication attempts
- ✅ Backup Vault data regularly
- ✅ Use mTLS for Vault communication
- ✅ Store unseal keys separately (different locations)

### ❌ DON'T

- ❌ Store root token in code or config
- ❌ Use long-lived credentials when dynamic available
- ❌ Grant broad policies (e.g., `secret/*`)
- ❌ Disable audit logging
- ❌ Use same credentials across environments
- ❌ Share tokens between services
- ❌ Log plaintext secrets
- ❌ Commit secrets to Git
- ❌ Use manual unseal in production
- ❌ Store all unseal keys together

## Monitoring

### Metrics to Track

```yaml
# Prometheus metrics from Vault
- vault_core_unsealed (should be 1)
- vault_core_active (should be 1 for active node)
- vault_runtime_alloc_bytes
- vault_runtime_sys_bytes
- vault_expire_num_leases
- vault_audit_log_request_duration_seconds
```

### Alerts

```yaml
- alert: VaultDown
  expr: up{job="vault"} == 0
  for: 1m
  severity: critical

- alert: VaultSealed
  expr: vault_core_unsealed == 0
  for: 1m
  severity: critical

- alert: VaultHighLeaseCount
  expr: vault_expire_num_leases > 10000
  for: 10m
  severity: warning

- alert: VaultAuditLogErrors
  expr: rate(vault_audit_log_request_errors[5m]) > 0
  for: 5m
  severity: warning
```

## Compliance

### GDPR
- ✅ Secrets access logged (audit trail)
- ✅ Secrets can be deleted (right to be forgotten)
- ✅ Access control (who can access what)

### SOC 2
- ✅ Encryption at rest and in transit
- ✅ Access logging (audit device)
- ✅ Role-based access control
- ✅ Secrets rotation

### ISO 27001
- ✅ Cryptographic controls (A.10)
- ✅ Access control (A.9)
- ✅ Key management (A.10.1.2)

## Conclusion

HashiCorp Vault provides:

✅ **Centralized Secrets Management**: All secrets in one place
✅ **Dynamic Secrets**: Generated on-demand, auto-rotated
✅ **Encryption as a Service**: No keys in application code
✅ **Complete Audit Trail**: Every access logged
✅ **Fine-Grained Access Control**: Least privilege policies
✅ **High Availability**: Multi-node cluster with auto-failover
✅ **Compliance Ready**: GDPR, SOC2, ISO27001 support

With Vault, the platform achieves enterprise-grade secrets management, eliminating the need for static credentials and providing a secure, auditable, and automated approach to handling sensitive data.