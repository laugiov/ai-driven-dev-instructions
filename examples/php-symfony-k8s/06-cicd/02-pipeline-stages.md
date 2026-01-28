# Pipeline Stages

## Table of Contents

1. [Introduction](#introduction)
2. [Validate Stage](#validate-stage)
3. [Test Stage](#test-stage)
4. [Security Stage](#security-stage)
5. [Build Stage](#build-stage)
6. [Deploy Staging Stage](#deploy-staging-stage)
7. [E2E Tests Stage](#e2e-tests-stage)
8. [Deploy Production Stage](#deploy-production-stage)
9. [Post-Deployment Stage](#post-deployment-stage)
10. [Stage Dependencies](#stage-dependencies)
11. [Stage Failure Handling](#stage-failure-handling)

## Introduction

This document provides detailed specifications for each stage of the CI/CD pipeline. Each stage has specific responsibilities, success criteria, and failure handling procedures.

### Pipeline Stage Overview

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  VALIDATE   │────▶│    TEST     │────▶│  SECURITY   │────▶│    BUILD    │
│   (3-5m)    │     │  (5-10m)    │     │   (5-8m)    │     │  (8-12m)    │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                                                     │
                                                                     ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│POST-DEPLOY  │◀────│DEPLOY PROD  │◀────│ E2E TESTS   │◀────│DEPLOY STAGE │
│   (2-3m)    │     │  (5-10m)    │     │ (10-15m)    │     │   (2-3m)    │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

### Stage Execution Rules

**Sequential Execution**: Stages run in order; failure stops the pipeline.

**Parallel Jobs**: Within a stage, jobs can run in parallel.

**Caching**: Build artifacts and dependencies cached between stages.

**Timeout**: Each stage has a maximum execution time.

**Retries**: Transient failures retry automatically (max 3 attempts).

## Validate Stage

### Purpose

Ensure code quality and coding standards before running expensive tests.

### Duration

**Target**: 3-5 minutes
**Timeout**: 10 minutes

### Jobs

#### 1. Static Analysis - PHPStan

```yaml
phpstan:
  name: PHPStan Level 9
  runs-on: ubuntu-latest
  timeout-minutes: 10

  steps:
    - uses: actions/checkout@v4

    - name: Setup PHP
      uses: shivammathur/setup-php@v2
      with:
        php-version: '8.3'
        tools: composer:v2
        coverage: none

    - name: Cache Composer packages
      uses: actions/cache@v3
      with:
        path: vendor
        key: ${{ runner.os }}-php-${{ hashFiles('**/composer.lock') }}
        restore-keys: ${{ runner.os }}-php-

    - name: Install dependencies
      run: composer install --prefer-dist --no-progress --no-dev --optimize-autoloader

    - name: Run PHPStan
      run: |
        vendor/bin/phpstan analyse \
          --level=9 \
          --error-format=github \
          --no-progress \
          --memory-limit=2G \
          src tests

    - name: Upload PHPStan results
      if: failure()
      uses: actions/upload-artifact@v3
      with:
        name: phpstan-results
        path: phpstan-report.json
```

**Success Criteria**:
- Zero errors at level 9
- No new violations compared to baseline
- Execution time < 5 minutes

**Failure Actions**:
- Stop pipeline
- Notify developer via PR comment
- Generate detailed error report

#### 2. Static Analysis - Psalm

```yaml
psalm:
  name: Psalm Static Analysis
  runs-on: ubuntu-latest
  timeout-minutes: 10

  steps:
    - uses: actions/checkout@v4

    - name: Setup PHP
      uses: shivammathur/setup-php@v2
      with:
        php-version: '8.3'
        tools: composer:v2
        coverage: none

    - name: Install dependencies
      run: composer install --prefer-dist --no-progress

    - name: Run Psalm
      run: |
        vendor/bin/psalm \
          --output-format=github \
          --no-progress \
          --show-info=false \
          --threads=4 \
          --shepherd

    - name: Generate Psalm baseline if needed
      if: failure()
      run: vendor/bin/psalm --set-baseline=psalm-baseline.xml
```

**Success Criteria**:
- Zero errors at level 1
- No type mismatches
- No missing return types

#### 3. Code Style - PHP CS Fixer

```yaml
php-cs-fixer:
  name: PHP CS Fixer
  runs-on: ubuntu-latest
  timeout-minutes: 5

  steps:
    - uses: actions/checkout@v4

    - name: Setup PHP
      uses: shivammathur/setup-php@v2
      with:
        php-version: '8.3'
        tools: composer:v2, php-cs-fixer
        coverage: none

    - name: Run PHP CS Fixer
      run: |
        php-cs-fixer fix \
          --config=.php-cs-fixer.php \
          --dry-run \
          --diff \
          --format=github \
          --verbose

    - name: Auto-fix and commit
      if: failure()
      run: |
        php-cs-fixer fix --config=.php-cs-fixer.php
        git config user.name "GitHub Actions"
        git config user.email "actions@github.com"
        git add .
        git commit -m "style: apply PHP CS Fixer" || true
        git push
```

**Success Criteria**:
- All files comply with PSR-12
- No formatting violations
- Consistent code style

#### 4. Architecture Validation

```yaml
deptrac:
  name: Architecture Validation
  runs-on: ubuntu-latest
  timeout-minutes: 5

  steps:
    - uses: actions/checkout@v4

    - name: Setup PHP
      uses: shivammathur/setup-php@v2
      with:
        php-version: '8.3'

    - name: Install Deptrac
      run: composer require --dev qossmic/deptrac-shim

    - name: Run Deptrac
      run: |
        vendor/bin/deptrac analyse \
          --config-file=deptrac.yaml \
          --formatter=github-actions \
          --fail-on-uncovered
```

**Deptrac Configuration**:

```yaml
# deptrac.yaml
deptrac:
  paths:
    - ./src

  layers:
    - name: Domain
      collectors:
        - type: directory
          regex: src/Domain/.*

    - name: Application
      collectors:
        - type: directory
          regex: src/Application/.*

    - name: Infrastructure
      collectors:
        - type: directory
          regex: src/Infrastructure/.*

  ruleset:
    Domain: ~
    Application:
      - Domain
    Infrastructure:
      - Application
      - Domain
```

**Success Criteria**:
- No layer violations
- Dependencies flow inward only
- No circular dependencies

### Stage Output

**Artifacts**:
- Static analysis reports
- Code style report
- Architecture validation report

**Metrics**:
- Number of violations (should be 0)
- Execution time per job
- Cache hit rate

## Test Stage

### Purpose

Validate application behavior through automated tests at multiple levels.

### Duration

**Target**: 5-10 minutes
**Timeout**: 20 minutes

### Jobs

#### 1. Unit Tests

```yaml
unit-tests:
  name: Unit Tests
  runs-on: ubuntu-latest
  timeout-minutes: 10

  strategy:
    matrix:
      php-version: ['8.3']

  steps:
    - uses: actions/checkout@v4

    - name: Setup PHP
      uses: shivammathur/setup-php@v2
      with:
        php-version: ${{ matrix.php-version }}
        extensions: mbstring, xml, ctype, iconv, intl, pdo_pgsql
        coverage: xdebug
        ini-values: memory_limit=512M

    - name: Install dependencies
      run: composer install --prefer-dist --no-progress

    - name: Run Unit Tests with Coverage
      run: |
        vendor/bin/phpunit \
          --testsuite=Unit \
          --coverage-clover=coverage.xml \
          --coverage-html=coverage/html \
          --log-junit=junit.xml \
          --testdox

    - name: Check Coverage Threshold
      run: |
        php tools/coverage-checker.php coverage.xml 80

    - name: Upload Coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        files: ./coverage.xml
        flags: unit
        name: unit-tests
        fail_ci_if_error: true

    - name: Upload Test Results
      if: always()
      uses: actions/upload-artifact@v3
      with:
        name: unit-test-results
        path: |
          junit.xml
          coverage/
```

**Coverage Checker Script**:

```php
<?php
// tools/coverage-checker.php

if ($argc < 3) {
    echo "Usage: php coverage-checker.php <clover.xml> <threshold>\n";
    exit(1);
}

$inputFile = $argv[1];
$threshold = min(100, max(0, (int) $argv[2]));

if (!file_exists($inputFile)) {
    throw new InvalidArgumentException("Coverage file not found: {$inputFile}");
}

$xml = new SimpleXMLElement(file_get_contents($inputFile));
$metrics = $xml->xpath('//metrics');

$totalElements = 0;
$checkedElements = 0;

foreach ($metrics as $metric) {
    $totalElements += (int) $metric['elements'];
    $checkedElements += (int) $metric['coveredelements'];
}

$coverage = ($totalElements > 0) ? ($checkedElements / $totalElements) * 100 : 0;

echo sprintf("Coverage: %.2f%%\n", $coverage);

if ($coverage < $threshold) {
    echo sprintf(
        "❌ Coverage %.2f%% is below threshold of %d%%\n",
        $coverage,
        $threshold
    );
    exit(1);
}

echo sprintf("✅ Coverage %.2f%% meets threshold of %d%%\n", $coverage, $threshold);
exit(0);
```

**Success Criteria**:
- All tests pass
- Coverage ≥ 80%
- No skipped tests
- Execution time < 5 minutes

#### 2. Integration Tests

```yaml
integration-tests:
  name: Integration Tests
  runs-on: ubuntu-latest
  timeout-minutes: 15

  services:
    postgres:
      image: postgres:15-alpine
      env:
        POSTGRES_DB: test_db
        POSTGRES_USER: test_user
        POSTGRES_PASSWORD: test_pass
        POSTGRES_HOST_AUTH_METHOD: trust
      ports:
        - 5432:5432
      options: >-
        --health-cmd pg_isready
        --health-interval 10s
        --health-timeout 5s
        --health-retries 5

    redis:
      image: redis:7-alpine
      ports:
        - 6379:6379
      options: >-
        --health-cmd "redis-cli ping"
        --health-interval 10s
        --health-timeout 5s
        --health-retries 5

    rabbitmq:
      image: rabbitmq:3-management-alpine
      ports:
        - 5672:5672
        - 15672:15672
      env:
        RABBITMQ_DEFAULT_USER: test
        RABBITMQ_DEFAULT_PASS: test
      options: >-
        --health-cmd "rabbitmq-diagnostics -q ping"
        --health-interval 10s
        --health-timeout 5s
        --health-retries 5

  steps:
    - uses: actions/checkout@v4

    - name: Setup PHP
      uses: shivammathur/setup-php@v2
      with:
        php-version: '8.3'
        extensions: mbstring, xml, ctype, iconv, intl, pdo_pgsql, redis, amqp

    - name: Install dependencies
      run: composer install --prefer-dist --no-progress

    - name: Setup Database
      run: |
        php bin/console doctrine:database:create --env=test
        php bin/console doctrine:migrations:migrate --no-interaction --env=test
        php bin/console doctrine:fixtures:load --no-interaction --env=test
      env:
        DATABASE_URL: postgresql://test_user:test_pass@localhost:5432/test_db

    - name: Run Integration Tests
      run: |
        vendor/bin/phpunit \
          --testsuite=Integration \
          --log-junit=integration-junit.xml
      env:
        DATABASE_URL: postgresql://test_user:test_pass@localhost:5432/test_db
        REDIS_URL: redis://localhost:6379
        MESSENGER_TRANSPORT_DSN: amqp://test:test@localhost:5672/%2f/messages

    - name: Upload Test Results
      if: always()
      uses: actions/upload-artifact@v3
      with:
        name: integration-test-results
        path: integration-junit.xml
```

**Success Criteria**:
- All integration tests pass
- Database interactions work correctly
- Message queue integration functional
- Cache operations working

#### 3. Mutation Testing

```yaml
mutation-tests:
  name: Mutation Testing
  runs-on: ubuntu-latest
  timeout-minutes: 20

  steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0  # Required for infection

    - name: Setup PHP
      uses: shivammathur/setup-php@v2
      with:
        php-version: '8.3'
        coverage: xdebug

    - name: Install dependencies
      run: composer install --prefer-dist --no-progress

    - name: Run Infection
      run: |
        vendor/bin/infection \
          --min-msi=70 \
          --min-covered-msi=80 \
          --threads=4 \
          --log-verbosity=default \
          --show-mutations \
          --no-interaction
      env:
        INFECTION_BADGE_API_KEY: ${{ secrets.INFECTION_BADGE_API_KEY }}

    - name: Upload Mutation Report
      if: always()
      uses: actions/upload-artifact@v3
      with:
        name: infection-report
        path: infection.log
```

**Infection Configuration**:

```json
{
    "source": {
        "directories": [
            "src"
        ],
        "excludes": [
            "Infrastructure/Symfony"
        ]
    },
    "logs": {
        "text": "infection.log",
        "badge": {
            "branch": "main"
        }
    },
    "mutators": {
        "@default": true,
        "global-ignoreSourceCodeByRegex": [
            ".*Test\\.php$"
        ]
    },
    "minMsi": 70,
    "minCoveredMsi": 80
}
```

**Success Criteria**:
- Mutation Score Indicator (MSI) ≥ 70%
- Covered MSI ≥ 80%
- No escaped mutants in critical code

### Stage Output

**Artifacts**:
- Test results (JUnit XML)
- Coverage reports (Clover XML, HTML)
- Mutation testing report

**Metrics**:
- Test count and pass rate
- Code coverage percentage
- Mutation score
- Test execution time

## Security Stage

### Purpose

Identify security vulnerabilities in code and dependencies.

### Duration

**Target**: 5-8 minutes
**Timeout**: 15 minutes

### Jobs

#### 1. Dependency Scanning - Snyk

```yaml
snyk-security:
  name: Snyk Security Scan
  runs-on: ubuntu-latest
  timeout-minutes: 10

  steps:
    - uses: actions/checkout@v4

    - name: Run Snyk to check for vulnerabilities
      uses: snyk/actions/php@master
      env:
        SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
      with:
        args: >
          --severity-threshold=high
          --fail-on=upgradable
          --project-name=platform-${{ github.ref_name }}

    - name: Upload Snyk results to GitHub Code Scanning
      uses: github/codeql-action/upload-sarif@v2
      if: always()
      with:
        sarif_file: snyk.sarif

    - name: Generate Snyk report
      if: always()
      run: |
        snyk test --json > snyk-report.json || true

    - name: Upload Snyk Report
      if: always()
      uses: actions/upload-artifact@v3
      with:
        name: snyk-report
        path: snyk-report.json
```

**Success Criteria**:
- No high or critical vulnerabilities
- All upgradable vulnerabilities fixed
- License compliance maintained

#### 2. Container Scanning - Trivy

```yaml
trivy-scan:
  name: Trivy Container Scan
  runs-on: ubuntu-latest
  timeout-minutes: 10

  steps:
    - uses: actions/checkout@v4

    - name: Build Docker image
      run: |
        docker build -t test-image:${{ github.sha }} .

    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: test-image:${{ github.sha }}
        format: 'sarif'
        output: 'trivy-results.sarif'
        severity: 'CRITICAL,HIGH'
        exit-code: '1'

    - name: Upload Trivy results to GitHub Security tab
      uses: github/codeql-action/upload-sarif@v2
      if: always()
      with:
        sarif_file: 'trivy-results.sarif'

    - name: Run Trivy with table output
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: test-image:${{ github.sha }}
        format: 'table'
        output: 'trivy-report.txt'

    - name: Upload Trivy Report
      if: always()
      uses: actions/upload-artifact@v3
      with:
        name: trivy-report
        path: trivy-report.txt
```

**Success Criteria**:
- No critical vulnerabilities in base images
- No high vulnerabilities in dependencies
- OS packages up to date

#### 3. SAST - SonarQube

```yaml
sonarqube:
  name: SonarQube Analysis
  runs-on: ubuntu-latest
  timeout-minutes: 10

  steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0  # Shallow clones disabled for SonarQube

    - name: Setup PHP
      uses: shivammathur/setup-php@v2
      with:
        php-version: '8.3'
        coverage: xdebug

    - name: Install dependencies
      run: composer install --prefer-dist --no-progress

    - name: Run tests with coverage
      run: vendor/bin/phpunit --coverage-clover=coverage.xml

    - name: SonarQube Scan
      uses: sonarsource/sonarqube-scan-action@master
      env:
        SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
      with:
        args: >
          -Dsonar.projectKey=platform
          -Dsonar.sources=src
          -Dsonar.tests=tests
          -Dsonar.php.coverage.reportPaths=coverage.xml
          -Dsonar.php.tests.reportPath=junit.xml

    - name: Check Quality Gate
      uses: sonarsource/sonarqube-quality-gate-action@master
      timeout-minutes: 5
      env:
        SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

**Quality Gate Criteria**:
- No new bugs
- No new vulnerabilities
- Security rating: A
- Maintainability rating: A
- Coverage ≥ 80%
- Duplicated lines < 3%

#### 4. Secret Scanning

```yaml
secret-scan:
  name: Secret Scanning
  runs-on: ubuntu-latest
  timeout-minutes: 5

  steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Run Gitleaks
      uses: gitleaks/gitleaks-action@v2
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}

    - name: Run TruffleHog
      uses: trufflesecurity/trufflehog@main
      with:
        path: ./
        base: ${{ github.event.repository.default_branch }}
        head: HEAD
```

**Success Criteria**:
- No secrets detected in code
- No API keys in commits
- No passwords in configuration files

### Stage Output

**Artifacts**:
- Vulnerability reports (SARIF)
- SonarQube analysis results
- Secret scanning results

**Metrics**:
- Number of vulnerabilities by severity
- Security rating
- Secret scan findings

## Build Stage

### Purpose

Build production-ready Docker images for all microservices.

### Duration

**Target**: 8-12 minutes
**Timeout**: 20 minutes

### Jobs

#### Build Multi-Service Images

```yaml
build:
  name: Build Docker Images
  runs-on: ubuntu-latest
  timeout-minutes: 20

  permissions:
    contents: read
    packages: write
    id-token: write  # For Cosign

  strategy:
    matrix:
      service:
        - bff
        - llm-agent
        - workflow-orchestrator
        - validation
        - notification
        - audit
        - file-storage

  steps:
    - uses: actions/checkout@v4

    - name: Set up QEMU
      uses: docker/setup-qemu-action@v3

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3
      with:
        driver-opts: |
          image=moby/buildkit:latest
          network=host

    - name: Log in to GitHub Container Registry
      uses: docker/login-action@v3
      with:
        registry: ghcr.io
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ghcr.io/${{ github.repository }}/${{ matrix.service }}
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=sha,prefix={{branch}}-
          type=semver,pattern={{version}}
          type=semver,pattern={{major}}.{{minor}}
          type=raw,value=latest,enable={{is_default_branch}}
        labels: |
          org.opencontainers.image.title=${{ matrix.service }}
          org.opencontainers.image.description=Platform ${{ matrix.service }} service
          org.opencontainers.image.vendor=Platform Team

    - name: Build and push Docker image
      id: build-and-push
      uses: docker/build-push-action@v5
      with:
        context: ./services/${{ matrix.service }}
        file: ./services/${{ matrix.service }}/Dockerfile
        platforms: linux/amd64,linux/arm64
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha,scope=${{ matrix.service }}
        cache-to: type=gha,mode=max,scope=${{ matrix.service }}
        build-args: |
          BUILD_DATE=${{ fromJSON(steps.meta.outputs.json).labels['org.opencontainers.image.created'] }}
          VCS_REF=${{ github.sha }}
          VERSION=${{ fromJSON(steps.meta.outputs.json).labels['org.opencontainers.image.version'] }}

    - name: Install Cosign
      uses: sigstore/cosign-installer@v3

    - name: Sign container image
      run: |
        cosign sign --yes \
          ghcr.io/${{ github.repository }}/${{ matrix.service }}@${{ steps.build-and-push.outputs.digest }}
      env:
        COSIGN_EXPERIMENTAL: "true"

    - name: Generate SBOM
      uses: anchore/sbom-action@v0
      with:
        image: ghcr.io/${{ github.repository }}/${{ matrix.service }}@${{ steps.build-and-push.outputs.digest }}
        format: cyclonedx-json
        output-file: sbom-${{ matrix.service }}.json

    - name: Scan SBOM for vulnerabilities
      uses: anchore/scan-action@v3
      with:
        sbom: sbom-${{ matrix.service }}.json
        fail-build: true
        severity-cutoff: high

    - name: Upload SBOM
      uses: actions/upload-artifact@v3
      with:
        name: sbom-${{ matrix.service }}
        path: sbom-${{ matrix.service }}.json
        retention-days: 90

    - name: Create image attestation
      run: |
        echo '{"image": "${{ steps.build-and-push.outputs.digest }}", "built-by": "GitHub Actions"}' > attestation.json
        cosign attest --yes --predicate attestation.json \
          ghcr.io/${{ github.repository }}/${{ matrix.service }}@${{ steps.build-and-push.outputs.digest }}
```

**Dockerfile Best Practices**:

```dockerfile
# services/bff/Dockerfile

# Build stage
FROM composer:2 AS builder

WORKDIR /app

# Copy composer files
COPY composer.json composer.lock ./

# Install dependencies
RUN composer install \
    --no-dev \
    --no-scripts \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader

# Copy application code
COPY . .

# Run post-install scripts
RUN composer dump-autoload --optimize --classmap-authoritative

# Production stage
FROM php:8.3-fpm-alpine

# Install system dependencies
RUN apk add --no-cache \
    postgresql-dev \
    redis \
    nginx \
    supervisor

# Install PHP extensions
RUN docker-php-ext-install \
    pdo_pgsql \
    opcache \
    pcntl

# Copy application from builder
COPY --from=builder /app /var/www/html

# Copy configuration
COPY docker/php.ini /usr/local/etc/php/conf.d/
COPY docker/opcache.ini /usr/local/etc/php/conf.d/
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/supervisor.conf /etc/supervisor/conf.d/

# Set permissions
RUN chown -R www-data:www-data /var/www/html/var

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD php-fpm-healthcheck || exit 1

# Expose port
EXPOSE 8080

# Run supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisor.conf"]

# Labels
LABEL org.opencontainers.image.source="https://github.com/org/platform"
LABEL org.opencontainers.image.description="BFF Service"
LABEL org.opencontainers.image.licenses="MIT"
```

**Success Criteria**:
- All images build successfully
- Images signed with Cosign
- SBOMs generated
- No high/critical vulnerabilities
- Multi-arch support (amd64, arm64)

### Stage Output

**Artifacts**:
- Docker images pushed to GHCR
- Image signatures
- SBOMs for all services
- Build logs

**Metrics**:
- Build time per service
- Image size
- Number of layers
- Vulnerability count

## Deploy Staging Stage

### Purpose

Deploy built images to staging environment for validation.

### Duration

**Target**: 2-3 minutes
**Timeout**: 10 minutes

### Jobs

```yaml
deploy-staging:
  name: Deploy to Staging
  needs: [build]
  runs-on: ubuntu-latest
  timeout-minutes: 10

  environment:
    name: staging
    url: https://staging.platform.example.com

  steps:
    - uses: actions/checkout@v4
      with:
        token: ${{ secrets.GIT_PAT }}

    - name: Install ArgoCD CLI
      run: |
        curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        chmod +x argocd
        sudo mv argocd /usr/local/bin/

    - name: Install Kustomize
      run: |
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
        sudo mv kustomize /usr/local/bin/

    - name: Update image tags
      run: |
        cd infrastructure/k8s/overlays/staging
        kustomize edit set image \
          bff=ghcr.io/${{ github.repository }}/bff:${{ github.sha }} \
          llm-agent=ghcr.io/${{ github.repository }}/llm-agent:${{ github.sha }} \
          workflow-orchestrator=ghcr.io/${{ github.repository }}/workflow-orchestrator:${{ github.sha }} \
          validation=ghcr.io/${{ github.repository }}/validation:${{ github.sha }} \
          notification=ghcr.io/${{ github.repository }}/notification:${{ github.sha }} \
          audit=ghcr.io/${{ github.repository }}/audit:${{ github.sha }} \
          file-storage=ghcr.io/${{ github.repository }}/file-storage:${{ github.sha }}

    - name: Commit and push changes
      run: |
        git config user.name "GitHub Actions"
        git config user.email "actions@github.com"
        git add infrastructure/k8s/overlays/staging/kustomization.yaml
        git commit -m "deploy: update staging to ${{ github.sha }}"
        git push

    - name: Login to ArgoCD
      run: |
        argocd login ${{ secrets.ARGOCD_SERVER }} \
          --username ${{ secrets.ARGOCD_USERNAME }} \
          --password ${{ secrets.ARGOCD_PASSWORD }} \
          --grpc-web

    - name: Sync ArgoCD Application
      run: |
        argocd app sync platform-staging \
          --prune \
          --force \
          --timeout 600

    - name: Wait for healthy status
      run: |
        argocd app wait platform-staging \
          --health \
          --timeout 600

    - name: Run smoke tests
      run: |
        npm ci
        npm run test:smoke -- --baseUrl=https://staging.platform.example.com
      env:
        API_KEY: ${{ secrets.STAGING_API_KEY }}

    - name: Notify deployment
      if: always()
      uses: slackapi/slack-github-action@v1
      with:
        payload: |
          {
            "text": "${{ job.status == 'success' && '✅' || '❌' }} Staging Deployment",
            "blocks": [
              {
                "type": "section",
                "text": {
                  "type": "mrkdwn",
                  "text": "*Staging Deployment ${{ job.status }}*\n\nCommit: `${{ github.sha }}`\nAuthor: ${{ github.actor }}"
                }
              }
            ]
          }
      env:
        SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

**Success Criteria**:
- ArgoCD sync successful
- All pods healthy
- Smoke tests pass
- No deployment errors

### Stage Output

**Artifacts**:
- Deployment logs
- Smoke test results

**Metrics**:
- Deployment duration
- Pod startup time
- Rollout status

## E2E Tests Stage

### Purpose

Run end-to-end tests against staging environment.

### Duration

**Target**: 10-15 minutes
**Timeout**: 30 minutes

### Jobs

```yaml
e2e-tests:
  name: E2E Tests
  needs: [deploy-staging]
  runs-on: ubuntu-latest
  timeout-minutes: 30

  steps:
    - uses: actions/checkout@v4

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '20'
        cache: 'npm'

    - name: Install dependencies
      run: npm ci

    - name: Install Playwright Browsers
      run: npx playwright install --with-deps

    - name: Run E2E Tests
      run: npx playwright test
      env:
        BASE_URL: https://staging.platform.example.com
        API_KEY: ${{ secrets.STAGING_API_KEY }}
        TEST_USER_EMAIL: ${{ secrets.TEST_USER_EMAIL }}
        TEST_USER_PASSWORD: ${{ secrets.TEST_USER_PASSWORD }}

    - name: Upload Playwright Report
      if: always()
      uses: actions/upload-artifact@v3
      with:
        name: playwright-report
        path: playwright-report/
        retention-days: 30

    - name: Upload test videos
      if: failure()
      uses: actions/upload-artifact@v3
      with:
        name: test-videos
        path: test-results/
```

**Playwright Configuration**:

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 4 : undefined,
  reporter: [
    ['html'],
    ['junit', { outputFile: 'test-results/junit.xml' }],
    ['github'],
  ],
  use: {
    baseURL: process.env.BASE_URL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
  ],
});
```

**Success Criteria**:
- All E2E tests pass
- No flaky tests
- Performance benchmarks met

### Stage Output

**Artifacts**:
- Playwright HTML report
- Test videos (on failure)
- JUnit XML results

**Metrics**:
- Test pass rate
- Test duration
- Flakiness rate

## Deploy Production Stage

### Purpose

Deploy validated changes to production environment.

### Duration

**Target**: 5-10 minutes (including canary rollout)
**Timeout**: 20 minutes

### Jobs

```yaml
deploy-production:
  name: Deploy to Production
  needs: [e2e-tests]
  runs-on: ubuntu-latest
  timeout-minutes: 20

  environment:
    name: production
    url: https://platform.example.com

  steps:
    - uses: actions/checkout@v4
      with:
        token: ${{ secrets.GIT_PAT }}

    - name: Update production images
      run: |
        cd infrastructure/k8s/overlays/production
        kustomize edit set image \
          bff=ghcr.io/${{ github.repository }}/bff:${{ github.sha }} \
          llm-agent=ghcr.io/${{ github.repository }}/llm-agent:${{ github.sha }} \
          # ... other services

    - name: Commit and push
      run: |
        git config user.name "GitHub Actions"
        git config user.email "actions@github.com"
        git add infrastructure/k8s/overlays/production/kustomization.yaml
        git commit -m "deploy: production ${{ github.sha }}"
        git push

    - name: Trigger ArgoCD Sync
      run: |
        argocd login ${{ secrets.ARGOCD_SERVER }} \
          --username ${{ secrets.ARGOCD_USERNAME }} \
          --password ${{ secrets.ARGOCD_PASSWORD }} \
          --grpc-web

        argocd app sync platform-production

    - name: Monitor Canary Rollout
      run: |
        # Argo Rollouts handles progressive delivery
        kubectl argo rollouts get rollout bff -n platform-production --watch

    - name: Wait for healthy status
      run: |
        argocd app wait platform-production \
          --health \
          --timeout 1200

    - name: Create GitHub Release
      uses: actions/create-release@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        tag_name: v${{ github.run_number }}
        release_name: Release v${{ github.run_number }}
        body: |
          Production deployment of ${{ github.sha }}

          Changes: ${{ github.event.head_commit.message }}
        draft: false
        prerelease: false
```

**Success Criteria**:
- Canary rollout successful
- All health checks pass
- Metrics within acceptable ranges
- No increase in error rate

### Stage Output

**Artifacts**:
- Deployment manifest
- Rollout status
- GitHub release

**Metrics**:
- Deployment duration
- Canary phase durations
- Error rate during rollout

## Post-Deployment Stage

### Purpose

Validate production deployment and notify stakeholders.

### Duration

**Target**: 2-3 minutes
**Timeout**: 10 minutes

### Jobs

```yaml
post-deployment:
  name: Post-Deployment Validation
  needs: [deploy-production]
  runs-on: ubuntu-latest
  timeout-minutes: 10

  steps:
    - uses: actions/checkout@v4

    - name: Run Production Smoke Tests
      run: |
        npm ci
        npm run test:smoke -- --baseUrl=https://platform.example.com
      env:
        API_KEY: ${{ secrets.PRODUCTION_API_KEY }}

    - name: Check Metrics
      run: |
        # Query Prometheus for key metrics
        python scripts/check-metrics.py \
          --prometheus-url=${{ secrets.PROMETHEUS_URL }} \
          --duration=5m

    - name: Update Status Page
      run: |
        curl -X POST https://status.example.com/api/incidents \
          -H "Authorization: Bearer ${{ secrets.STATUS_PAGE_TOKEN }}" \
          -d '{"type":"resolved","message":"Deployment completed successfully"}'

    - name: Notify Slack
      uses: slackapi/slack-github-action@v1
      with:
        payload: |
          {
            "text": "✅ Production Deployment Successful",
            "blocks": [
              {
                "type": "section",
                "text": {
                  "type": "mrkdwn",
                  "text": "*🚀 Production Deployment Successful*\n\nCommit: `${{ github.sha }}`\nAuthor: ${{ github.actor }}\nDuration: ${{ job.duration }}"
                }
              },
              {
                "type": "actions",
                "elements": [
                  {
                    "type": "button",
                    "text": {"type": "plain_text", "text": "View Deployment"},
                    "url": "${{ github.event.head_commit.url }}"
                  },
                  {
                    "type": "button",
                    "text": {"type": "plain_text", "text": "View Metrics"},
                    "url": "https://grafana.example.com"
                  }
                ]
              }
            ]
          }
      env:
        SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

    - name: Create Datadog Event
      run: |
        curl -X POST "https://api.datadoghq.com/api/v1/events" \
          -H "Content-Type: application/json" \
          -H "DD-API-KEY: ${{ secrets.DATADOG_API_KEY }}" \
          -d '{
            "title": "Production Deployment",
            "text": "Deployed ${{ github.sha }} to production",
            "tags": ["env:production","service:platform"],
            "alert_type": "info"
          }'
```

**Success Criteria**:
- Smoke tests pass
- Metrics stable
- Notifications sent

### Stage Output

**Artifacts**:
- Smoke test results
- Metrics snapshot

## Stage Dependencies

```yaml
# Complete dependency graph
validate:
  depends_on: []

test:
  depends_on: [validate]

security:
  depends_on: [validate]

build:
  depends_on: [test, security]

deploy-staging:
  depends_on: [build]

e2e-tests:
  depends_on: [deploy-staging]

deploy-production:
  depends_on: [e2e-tests]
  requires_approval: true  # Manual approval gate

post-deployment:
  depends_on: [deploy-production]
```

## Stage Failure Handling

### Failure Actions by Stage

**Validate Stage Failure**:
- Stop pipeline immediately
- Comment on PR with errors
- Assign back to author
- Block merge

**Test Stage Failure**:
- Stop pipeline
- Upload test results
- Generate coverage diff
- Notify via PR comment

**Security Stage Failure**:
- Stop pipeline for high/critical issues
- Create security issue
- Notify security team
- Provide remediation guidance

**Build Stage Failure**:
- Retry once
- Check for transient errors
- Notify build team if persistent

**Deploy Staging Failure**:
- Automatic rollback
- Preserve logs
- Notify team
- Do not proceed to production

**E2E Tests Failure**:
- Retry flaky tests
- Upload screenshots/videos
- Stop production deployment
- Notify QA team

**Deploy Production Failure**:
- Immediate automatic rollback
- Page on-call engineer
- Create incident
- Preserve state for analysis

**Post-Deployment Failure**:
- Alert team
- Monitor for issues
- Prepare for potential rollback

### Retry Strategy

```yaml
retry:
  max_attempts: 3
  backoff:
    duration: 30s
    factor: 2
    max_duration: 5m

  retryable_errors:
    - network_timeout
    - rate_limit
    - transient_failure

  non_retryable_errors:
    - test_failure
    - validation_error
    - security_violation
```

## Summary

This pipeline stages document provides:

1. **Detailed Stage Specifications**: Each stage fully documented
2. **Clear Success Criteria**: Objective measures for each stage
3. **Comprehensive Examples**: Full workflow definitions
4. **Failure Handling**: Strategies for each failure scenario
5. **Metrics**: Key metrics tracked at every stage
6. **Best Practices**: Industry-standard tools and configurations

The pipeline ensures quality, security, and reliability at every step from code commit to production deployment.
