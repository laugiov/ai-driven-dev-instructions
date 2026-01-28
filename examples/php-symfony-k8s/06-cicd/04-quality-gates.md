# Quality Gates

## Table of Contents

1. [Introduction](#introduction)
2. [Quality Gate Philosophy](#quality-gate-philosophy)
3. [Pre-Commit Gates](#pre-commit-gates)
4. [Pull Request Gates](#pull-request-gates)
5. [Pre-Deployment Gates](#pre-deployment-gates)
6. [Post-Deployment Gates](#post-deployment-gates)
7. [Quality Metrics](#quality-metrics)
8. [Gate Configuration](#gate-configuration)
9. [Bypassing Gates](#bypassing-gates)
10. [Monitoring and Reporting](#monitoring-and-reporting)

## Introduction

Quality gates are automated checkpoints in the CI/CD pipeline that ensure code meets defined quality standards before progressing to the next stage. They act as guardrails to prevent defects from reaching production.

### Purpose of Quality Gates

**Prevent Defects**: Stop problematic code early in the pipeline.

**Enforce Standards**: Ensure consistent code quality across the team.

**Reduce Risk**: Minimize the chance of production incidents.

**Provide Feedback**: Give developers immediate feedback on code quality.

**Maintain Velocity**: Automate quality checks to maintain development speed.

**Build Confidence**: Team and stakeholders trust the deployment process.

### Gate Types

```
┌─────────────────────────────────────────────────────────────┐
│                     QUALITY GATE LEVELS                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Pre-Commit    →    PR Gates    →   Pre-Deploy   →  Post   │
│   (Local)         (CI Pipeline)    (Staging)       Deploy   │
│                                                              │
│  • Linting        • Static        • Integration    • Smoke  │
│  • Unit Tests       Analysis        Tests          Tests    │
│  • Formatting     • Unit Tests    • E2E Tests      • Metrics│
│                   • Security      • Performance    • Health │
│                     Scans           Tests                    │
│                   • Coverage                                 │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Quality Gate Philosophy

### Fail Fast Principle

```
Developer → Pre-Commit (2-3s) → Quick feedback
                ↓ Pass
          Push to Remote
                ↓
         PR Gates (5-10min) → Detailed feedback
                ↓ Pass
         Merge to Main
                ↓
      Pre-Deploy Gates (15-20min) → Comprehensive validation
                ↓ Pass
       Deploy to Production
                ↓
      Post-Deploy Gates (2-5min) → Production validation
```

**Goal**: Detect issues as early as possible when they're cheapest to fix.

### Quality Standards Hierarchy

**Critical (Must Pass)**:
- Zero compilation/syntax errors
- Zero critical security vulnerabilities
- All tests passing
- Code coverage ≥ 80%
- No high-priority bugs

**Important (Should Pass)**:
- PHPStan Level 9
- Psalm Level 1
- No code style violations
- No medium security vulnerabilities
- Mutation score ≥ 70%

**Recommended (Advisory)**:
- Low complexity metrics
- Low code duplication
- Good documentation coverage
- Performance benchmarks met

## Pre-Commit Gates

### Purpose

Catch obvious issues before code is even committed locally.

### Git Hooks Setup

```bash
#!/bin/bash
# .git/hooks/pre-commit

set -e

echo "🔍 Running pre-commit quality gates..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track overall status
GATE_FAILED=0

# Function to print gate status
print_gate() {
    local name=$1
    local status=$2
    if [ $status -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $name"
    else
        echo -e "${RED}✗${NC} $name"
        GATE_FAILED=1
    fi
}

# Gate 1: PHP Syntax Check
echo ""
echo "Gate 1: PHP Syntax Check"
php -l $(git diff --cached --name-only --diff-filter=ACM | grep '\.php$') > /dev/null 2>&1
print_gate "PHP Syntax" $?

# Gate 2: PHP CS Fixer (Dry Run)
echo ""
echo "Gate 2: Code Style Check"
vendor/bin/php-cs-fixer fix --config=.php-cs-fixer.php --dry-run --diff > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}⚠${NC}  Code style issues found. Run: vendor/bin/php-cs-fixer fix"
    print_gate "Code Style" 1
else
    print_gate "Code Style" 0
fi

# Gate 3: PHPStan (Changed Files Only)
echo ""
echo "Gate 3: Static Analysis (PHPStan)"
CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.php$' | tr '\n' ' ')
if [ -n "$CHANGED_FILES" ]; then
    vendor/bin/phpstan analyse --level=9 --no-progress $CHANGED_FILES > /dev/null 2>&1
    print_gate "PHPStan Level 9" $?
else
    echo "No PHP files to analyze"
fi

# Gate 4: Unit Tests (Fast)
echo ""
echo "Gate 4: Unit Tests"
vendor/bin/phpunit --testsuite=Unit --stop-on-failure > /dev/null 2>&1
print_gate "Unit Tests" $?

# Gate 5: Forbidden Patterns
echo ""
echo "Gate 5: Forbidden Patterns Check"
FORBIDDEN_FOUND=0

# Check for var_dump, dd, dump
if git diff --cached --diff-filter=ACM | grep -E '(var_dump|dump\(|dd\()' > /dev/null; then
    echo -e "${RED}✗${NC} Found debugging functions (var_dump, dump, dd)"
    FORBIDDEN_FOUND=1
fi

# Check for TODO without ticket reference
if git diff --cached --diff-filter=ACM | grep -E 'TODO(?!.*#[0-9]+)' > /dev/null; then
    echo -e "${YELLOW}⚠${NC}  Found TODO without ticket reference"
fi

# Check for console.log in JS files
if git diff --cached --diff-filter=ACM --name-only | grep '\.js$' > /dev/null; then
    if git diff --cached --diff-filter=ACM | grep 'console\.log' > /dev/null; then
        echo -e "${YELLOW}⚠${NC}  Found console.log statements"
    fi
fi

# Check for secrets/credentials
if git diff --cached --diff-filter=ACM | grep -iE '(password|secret|api[_-]?key|token|credential).*[=:].*["\047][^"\047]{8,}' > /dev/null; then
    echo -e "${RED}✗${NC} Possible credentials found in code"
    FORBIDDEN_FOUND=1
fi

print_gate "Forbidden Patterns" $FORBIDDEN_FOUND

# Summary
echo ""
echo "================================"
if [ $GATE_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All pre-commit gates passed!${NC}"
    echo "================================"
    exit 0
else
    echo -e "${RED}✗ Some pre-commit gates failed!${NC}"
    echo "================================"
    echo ""
    echo "Fix the issues above and try again."
    echo "To bypass (not recommended): git commit --no-verify"
    exit 1
fi
```

### Installation Script

```bash
#!/bin/bash
# scripts/install-git-hooks.sh

set -e

echo "Installing git hooks..."

HOOKS_DIR=".git/hooks"
SCRIPTS_DIR="scripts/git-hooks"

# Ensure hooks directory exists
mkdir -p "$HOOKS_DIR"

# Copy hooks
cp "$SCRIPTS_DIR/pre-commit" "$HOOKS_DIR/pre-commit"
cp "$SCRIPTS_DIR/commit-msg" "$HOOKS_DIR/commit-msg"
cp "$SCRIPTS_DIR/pre-push" "$HOOKS_DIR/pre-push"

# Make executable
chmod +x "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/commit-msg"
chmod +x "$HOOKS_DIR/pre-push"

echo "✓ Git hooks installed successfully"
echo ""
echo "Hooks installed:"
echo "  - pre-commit: Code quality checks"
echo "  - commit-msg: Commit message format validation"
echo "  - pre-push: Run tests before pushing"
```

### Commit Message Validation

```bash
#!/bin/bash
# .git/hooks/commit-msg

COMMIT_MSG_FILE=$1
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")

# Conventional Commits format
# <type>(<scope>): <subject>
# Example: feat(agent): add temperature parameter

PATTERN="^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z\-]+\))?!?: .{1,100}"

if ! echo "$COMMIT_MSG" | grep -qE "$PATTERN"; then
    echo "❌ Invalid commit message format!"
    echo ""
    echo "Commit message must follow Conventional Commits:"
    echo "  <type>(<scope>): <subject>"
    echo ""
    echo "Types:"
    echo "  feat:     New feature"
    echo "  fix:      Bug fix"
    echo "  docs:     Documentation changes"
    echo "  style:    Code style changes (formatting)"
    echo "  refactor: Code refactoring"
    echo "  perf:     Performance improvements"
    echo "  test:     Adding or updating tests"
    echo "  build:    Build system changes"
    echo "  ci:       CI/CD changes"
    echo "  chore:    Other changes"
    echo ""
    echo "Examples:"
    echo "  feat(agent): add temperature parameter"
    echo "  fix(workflow): correct step execution order"
    echo "  docs: update API documentation"
    echo ""
    exit 1
fi

echo "✓ Commit message format is valid"
exit 0
```

### Performance Target

**Pre-Commit Duration**: < 10 seconds
- Syntax check: < 1s
- Code style: < 2s
- Static analysis (changed files): < 3s
- Unit tests: < 4s

## Pull Request Gates

### Required Checks

```yaml
# .github/workflows/pr-gates.yml
name: Pull Request Quality Gates

on:
  pull_request:
    branches: [main, develop]
    types: [opened, synchronize, reopened]

jobs:
  gate-1-static-analysis:
    name: "Gate 1: Static Analysis"
    runs-on: ubuntu-latest
    timeout-minutes: 10

    steps:
      - uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          coverage: none

      - name: Cache dependencies
        uses: actions/cache@v3
        with:
          path: vendor
          key: ${{ runner.os }}-composer-${{ hashFiles('**/composer.lock') }}

      - name: Install dependencies
        run: composer install --prefer-dist --no-progress

      - name: PHPStan
        run: |
          vendor/bin/phpstan analyse \
            --level=9 \
            --error-format=github \
            --no-progress
        continue-on-error: false

      - name: Psalm
        run: |
          vendor/bin/psalm \
            --output-format=github \
            --no-progress \
            --show-info=false
        continue-on-error: false

      - name: PHP CS Fixer
        run: |
          vendor/bin/php-cs-fixer fix \
            --dry-run \
            --diff \
            --format=github
        continue-on-error: false

  gate-2-tests:
    name: "Gate 2: Tests"
    runs-on: ubuntu-latest
    timeout-minutes: 15

    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_DB: test_db
          POSTGRES_USER: test_user
          POSTGRES_PASSWORD: test_pass
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          coverage: xdebug

      - name: Install dependencies
        run: composer install --prefer-dist --no-progress

      - name: Run Unit Tests
        run: |
          vendor/bin/phpunit \
            --testsuite=Unit \
            --coverage-clover=coverage.xml \
            --log-junit=junit.xml

      - name: Check Coverage Threshold
        run: |
          php tools/coverage-checker.php coverage.xml 80
        continue-on-error: false

      - name: Run Integration Tests
        run: |
          vendor/bin/phpunit \
            --testsuite=Integration
        env:
          DATABASE_URL: postgresql://test_user:test_pass@localhost:5432/test_db

      - name: Upload Coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.xml
          fail_ci_if_error: true

  gate-3-security:
    name: "Gate 3: Security Scan"
    runs-on: ubuntu-latest
    timeout-minutes: 10

    steps:
      - uses: actions/checkout@v4

      - name: Run Snyk Security Check
        uses: snyk/actions/php@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high --fail-on=upgradable

      - name: Run Trivy
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'

  gate-4-complexity:
    name: "Gate 4: Code Complexity"
    runs-on: ubuntu-latest
    timeout-minutes: 5

    steps:
      - uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'

      - name: Install dependencies
        run: composer install --prefer-dist --no-progress

      - name: Check Complexity
        run: |
          vendor/bin/phpmetrics --report-html=metrics src

          # Check if any file exceeds complexity threshold
          COMPLEXITY=$(vendor/bin/phpmetrics --report-json=metrics.json src)

          # Fail if average cyclomatic complexity > 10
          MAX_COMPLEXITY=$(jq '.classes[].ccn' metrics.json | sort -rn | head -1)
          if [ $MAX_COMPLEXITY -gt 15 ]; then
            echo "❌ Maximum cyclomatic complexity ($MAX_COMPLEXITY) exceeds threshold (15)"
            exit 1
          fi

      - name: Upload Complexity Report
        uses: actions/upload-artifact@v3
        with:
          name: complexity-report
          path: metrics/

  gate-5-mutation-testing:
    name: "Gate 5: Mutation Testing"
    runs-on: ubuntu-latest
    timeout-minutes: 20

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

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
            --no-interaction
        env:
          INFECTION_BADGE_API_KEY: ${{ secrets.INFECTION_BADGE_API_KEY }}

  gate-summary:
    name: "Quality Gates Summary"
    needs: [gate-1-static-analysis, gate-2-tests, gate-3-security, gate-4-complexity, gate-5-mutation-testing]
    runs-on: ubuntu-latest
    if: always()

    steps:
      - name: Check all gates passed
        run: |
          if [ "${{ needs.gate-1-static-analysis.result }}" != "success" ] ||
             [ "${{ needs.gate-2-tests.result }}" != "success" ] ||
             [ "${{ needs.gate-3-security.result }}" != "success" ] ||
             [ "${{ needs.gate-4-complexity.result }}" != "success" ] ||
             [ "${{ needs.gate-5-mutation-testing.result }}" != "success" ]; then
            echo "❌ Some quality gates failed"
            exit 1
          fi
          echo "✅ All quality gates passed"

      - name: Comment PR
        uses: actions/github-script@v6
        with:
          script: |
            const gates = {
              'Static Analysis': '${{ needs.gate-1-static-analysis.result }}',
              'Tests': '${{ needs.gate-2-tests.result }}',
              'Security': '${{ needs.gate-3-security.result }}',
              'Complexity': '${{ needs.gate-4-complexity.result }}',
              'Mutation Testing': '${{ needs.gate-5-mutation-testing.result }}'
            };

            const allPassed = Object.values(gates).every(r => r === 'success');
            const emoji = allPassed ? '✅' : '❌';

            let body = `## ${emoji} Quality Gates Report\n\n`;
            body += '| Gate | Status |\n';
            body += '|------|--------|\n';

            for (const [gate, result] of Object.entries(gates)) {
              const status = result === 'success' ? '✅ Pass' : '❌ Fail';
              body += `| ${gate} | ${status} |\n`;
            }

            if (!allPassed) {
              body += '\n⚠️ Some gates failed. Please fix the issues before merging.\n';
            }

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: body
            });
```

### Branch Protection Rules

```yaml
# .github/settings.yml (using probot/settings)
branches:
  - name: main
    protection:
      required_status_checks:
        strict: true
        contexts:
          - "Gate 1: Static Analysis"
          - "Gate 2: Tests"
          - "Gate 3: Security Scan"
          - "Gate 4: Code Complexity"
          - "Gate 5: Mutation Testing"
      required_pull_request_reviews:
        required_approving_review_count: 2
        dismiss_stale_reviews: true
        require_code_owner_reviews: true
      enforce_admins: true
      required_linear_history: true
      restrictions:
        users: []
        teams: ['platform-admins']
```

## Pre-Deployment Gates

### Staging Validation

```yaml
# .github/workflows/pre-deploy-gates.yml
name: Pre-Deployment Quality Gates

on:
  push:
    branches: [main]

jobs:
  gate-integration-tests:
    name: "Gate: Integration Tests"
    runs-on: ubuntu-latest
    timeout-minutes: 20

    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_DB: test_db
          POSTGRES_USER: test_user
          POSTGRES_PASSWORD: test_pass
        ports:
          - 5432:5432

      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379

      rabbitmq:
        image: rabbitmq:3-management-alpine
        env:
          RABBITMQ_DEFAULT_USER: test
          RABBITMQ_DEFAULT_PASS: test
        ports:
          - 5672:5672

    steps:
      - uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          extensions: pdo_pgsql, redis, amqp

      - name: Install dependencies
        run: composer install --prefer-dist --no-progress

      - name: Setup Database
        run: |
          php bin/console doctrine:migrations:migrate --no-interaction --env=test
        env:
          DATABASE_URL: postgresql://test_user:test_pass@localhost:5432/test_db

      - name: Run Integration Tests
        run: |
          vendor/bin/phpunit \
            --testsuite=Integration \
            --stop-on-failure
        env:
          DATABASE_URL: postgresql://test_user:test_pass@localhost:5432/test_db
          REDIS_URL: redis://localhost:6379
          MESSENGER_TRANSPORT_DSN: amqp://test:test@localhost:5672/%2f/messages

  gate-e2e-staging:
    name: "Gate: E2E Tests (Staging)"
    needs: [gate-integration-tests]
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install Playwright
        run: |
          npm ci
          npx playwright install --with-deps

      - name: Wait for Staging Deployment
        run: |
          # Wait for ArgoCD to sync
          timeout 600 bash -c 'until curl -f https://staging.platform.example.com/health; do sleep 5; done'

      - name: Run E2E Tests
        run: |
          npx playwright test --project=chromium
        env:
          BASE_URL: https://staging.platform.example.com
          API_KEY: ${{ secrets.STAGING_API_KEY }}

      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: playwright-report
          path: playwright-report/

  gate-performance:
    name: "Gate: Performance Tests"
    needs: [gate-integration-tests]
    runs-on: ubuntu-latest
    timeout-minutes: 15

    steps:
      - uses: actions/checkout@v4

      - name: Setup K6
        run: |
          sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
          echo "deb https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
          sudo apt-get update
          sudo apt-get install k6

      - name: Run Load Tests
        run: |
          k6 run \
            --vus 10 \
            --duration 5m \
            --thresholds 'http_req_duration{p(95)}<200' \
            tests/load/api-load-test.js
        env:
          BASE_URL: https://staging.platform.example.com
          API_KEY: ${{ secrets.STAGING_API_KEY }}

      - name: Check Performance SLO
        run: |
          # Extract P95 latency from K6 output
          P95_LATENCY=$(jq -r '.metrics.http_req_duration.values.p95' k6-results.json)

          if (( $(echo "$P95_LATENCY > 200" | bc -l) )); then
            echo "❌ P95 latency ($P95_LATENCY ms) exceeds threshold (200ms)"
            exit 1
          fi

          echo "✅ P95 latency: $P95_LATENCY ms"

  gate-security-final:
    name: "Gate: Final Security Check"
    runs-on: ubuntu-latest
    timeout-minutes: 10

    steps:
      - uses: actions/checkout@v4

      - name: OWASP ZAP Scan
        uses: zaproxy/action-baseline@v0.7.0
        with:
          target: 'https://staging.platform.example.com'
          rules_file_name: '.zap/rules.tsv'
          cmd_options: '-a'

  gate-database-migrations:
    name: "Gate: Database Migration Check"
    runs-on: ubuntu-latest
    timeout-minutes: 10

    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_DB: test_db
          POSTGRES_USER: test_user
          POSTGRES_PASSWORD: test_pass
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'

      - name: Install dependencies
        run: composer install --prefer-dist --no-progress

      - name: Check Migration Status
        run: |
          php bin/console doctrine:migrations:status
        env:
          DATABASE_URL: postgresql://test_user:test_pass@localhost:5432/test_db

      - name: Test Migrations (Up)
        run: |
          php bin/console doctrine:migrations:migrate --no-interaction
        env:
          DATABASE_URL: postgresql://test_user:test_pass@localhost:5432/test_db

      - name: Test Migrations (Down)
        run: |
          # Test rollback capability
          php bin/console doctrine:migrations:migrate prev --no-interaction
        env:
          DATABASE_URL: postgresql://test_user:test_pass@localhost:5432/test_db

  pre-deploy-summary:
    name: "Pre-Deployment Gates Summary"
    needs:
      - gate-integration-tests
      - gate-e2e-staging
      - gate-performance
      - gate-security-final
      - gate-database-migrations
    runs-on: ubuntu-latest
    if: always()

    steps:
      - name: Check all gates passed
        run: |
          GATES_PASSED=true

          for gate in \
            "${{ needs.gate-integration-tests.result }}" \
            "${{ needs.gate-e2e-staging.result }}" \
            "${{ needs.gate-performance.result }}" \
            "${{ needs.gate-security-final.result }}" \
            "${{ needs.gate-database-migrations.result }}"
          do
            if [ "$gate" != "success" ]; then
              GATES_PASSED=false
              break
            fi
          done

          if [ "$GATES_PASSED" = false ]; then
            echo "❌ Pre-deployment gates failed - blocking production deployment"
            exit 1
          fi

          echo "✅ All pre-deployment gates passed - ready for production"
```

## Post-Deployment Gates

### Production Validation

```yaml
# .github/workflows/post-deploy-gates.yml
name: Post-Deployment Quality Gates

on:
  workflow_run:
    workflows: ["Deploy to Production"]
    types: [completed]

jobs:
  gate-smoke-tests:
    name: "Gate: Smoke Tests"
    runs-on: ubuntu-latest
    timeout-minutes: 5

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Run Smoke Tests
        run: |
          npm run test:smoke
        env:
          BASE_URL: https://platform.example.com
          API_KEY: ${{ secrets.PRODUCTION_API_KEY }}

      - name: Verify Critical Endpoints
        run: |
          ENDPOINTS=(
            "/health"
            "/api/v1/agents"
            "/api/v1/workflows"
          )

          for endpoint in "${ENDPOINTS[@]}"; do
            STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://platform.example.com${endpoint}")
            if [ "$STATUS" != "200" ]; then
              echo "❌ Endpoint $endpoint returned $STATUS"
              exit 1
            fi
            echo "✅ $endpoint: $STATUS"
          done

  gate-metrics-validation:
    name: "Gate: Metrics Validation"
    runs-on: ubuntu-latest
    timeout-minutes: 10

    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          pip install requests prometheus-api-client

      - name: Check Error Rate
        run: |
          python scripts/check-metrics.py \
            --metric error_rate \
            --threshold 0.01 \
            --duration 5m
        env:
          PROMETHEUS_URL: ${{ secrets.PROMETHEUS_URL }}

      - name: Check Latency
        run: |
          python scripts/check-metrics.py \
            --metric latency_p95 \
            --threshold 200 \
            --duration 5m
        env:
          PROMETHEUS_URL: ${{ secrets.PROMETHEUS_URL }}

      - name: Check Success Rate
        run: |
          python scripts/check-metrics.py \
            --metric success_rate \
            --threshold 0.95 \
            --duration 5m
        env:
          PROMETHEUS_URL: ${{ secrets.PROMETHEUS_URL }}

  gate-synthetic-monitoring:
    name: "Gate: Synthetic Monitoring"
    runs-on: ubuntu-latest
    timeout-minutes: 10

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Run Synthetic Tests
        run: |
          npm run test:synthetic
        env:
          BASE_URL: https://platform.example.com

      - name: Verify User Journeys
        run: |
          # Test critical user journeys
          npm run test:journey:agent-creation
          npm run test:journey:workflow-execution
        env:
          BASE_URL: https://platform.example.com
          API_KEY: ${{ secrets.PRODUCTION_API_KEY }}

  gate-rollback-decision:
    name: "Gate: Rollback Decision"
    needs: [gate-smoke-tests, gate-metrics-validation, gate-synthetic-monitoring]
    runs-on: ubuntu-latest
    if: failure()

    steps:
      - name: Trigger Automatic Rollback
        run: |
          echo "❌ Post-deployment gates failed - initiating rollback"

          # Trigger rollback workflow
          gh workflow run rollback.yml \
            -f environment=production \
            -f reason="Post-deployment gates failed"
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Create Incident
        uses: actions/github-script@v6
        with:
          script: |
            await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: '🚨 Production Deployment Failed Post-Deploy Gates',
              body: `
                ## Incident Report

                **Deployment**: ${{ github.sha }}
                **Time**: ${{ github.event.workflow_run.created_at }}

                **Failed Gates**:
                - Smoke Tests: ${{ needs.gate-smoke-tests.result }}
                - Metrics: ${{ needs.gate-metrics-validation.result }}
                - Synthetic Monitoring: ${{ needs.gate-synthetic-monitoring.result }}

                **Actions Taken**:
                - Automatic rollback initiated
                - On-call engineer paged

                **Investigation Required**:
                - [ ] Review deployment logs
                - [ ] Analyze error metrics
                - [ ] Check for infrastructure issues
              `,
              labels: ['incident', 'production', 'high-priority']
            });

      - name: Page On-Call
        run: |
          curl -X POST ${{ secrets.PAGERDUTY_WEBHOOK }} \
            -H 'Content-Type: application/json' \
            -d '{
              "event_action": "trigger",
              "payload": {
                "summary": "Production deployment failed post-deploy gates",
                "severity": "critical",
                "source": "GitHub Actions"
              }
            }'
```

### Metrics Check Script

```python
# scripts/check-metrics.py
import argparse
import sys
from datetime import datetime, timedelta
from prometheus_api_client import PrometheusConnect

def check_metric(prom, metric_name, threshold, duration, comparison='lt'):
    """
    Check if a metric meets the threshold.

    Args:
        prom: Prometheus client
        metric_name: Name of the metric
        threshold: Threshold value
        duration: Time range to check (e.g., '5m')
        comparison: 'lt' for less than, 'gt' for greater than
    """
    queries = {
        'error_rate': f'sum(rate(http_requests_total{{status=~"5.."}}[{duration}])) / sum(rate(http_requests_total[{duration}]))',
        'latency_p95': f'histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[{duration}])) by (le))',
        'success_rate': f'sum(rate(http_requests_total{{status=~"2.."}}[{duration}])) / sum(rate(http_requests_total[{duration}]))',
    }

    if metric_name not in queries:
        print(f"❌ Unknown metric: {metric_name}")
        sys.exit(1)

    query = queries[metric_name]
    result = prom.custom_query(query)

    if not result:
        print(f"⚠️  No data for metric: {metric_name}")
        sys.exit(1)

    value = float(result[0]['value'][1])

    print(f"Metric: {metric_name}")
    print(f"Value: {value}")
    print(f"Threshold: {threshold}")

    if comparison == 'lt':
        passed = value < threshold
        operator = '<'
    else:
        passed = value > threshold
        operator = '>'

    if passed:
        print(f"✅ {metric_name}: {value} {operator} {threshold}")
        sys.exit(0)
    else:
        print(f"❌ {metric_name}: {value} !{operator} {threshold}")
        sys.exit(1)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Check Prometheus metrics')
    parser.add_argument('--metric', required=True, help='Metric name')
    parser.add_argument('--threshold', type=float, required=True, help='Threshold value')
    parser.add_argument('--duration', default='5m', help='Time range (e.g., 5m, 1h)')
    parser.add_argument('--comparison', default='lt', choices=['lt', 'gt'], help='Comparison operator')

    args = parser.parse_args()

    prom_url = os.environ.get('PROMETHEUS_URL')
    if not prom_url:
        print("❌ PROMETHEUS_URL environment variable not set")
        sys.exit(1)

    prom = PrometheusConnect(url=prom_url, disable_ssl=False)

    check_metric(
        prom,
        args.metric,
        args.threshold,
        args.duration,
        args.comparison
    )
```

## Quality Metrics

### Tracking Quality Over Time

```yaml
# .github/workflows/quality-metrics.yml
name: Quality Metrics Collection

on:
  push:
    branches: [main]
  schedule:
    - cron: '0 0 * * *'  # Daily

jobs:
  collect-metrics:
    name: Collect Quality Metrics
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          coverage: xdebug

      - name: Install dependencies
        run: composer install --prefer-dist --no-progress

      - name: Collect Metrics
        run: |
          # Code coverage
          vendor/bin/phpunit --coverage-clover=coverage.xml
          COVERAGE=$(php tools/coverage-checker.php coverage.xml 0 | grep -oP '\d+\.\d+' | head -1)

          # PHPStan errors
          PHPSTAN_ERRORS=$(vendor/bin/phpstan analyse --level=9 --error-format=json | jq '.totals.file_errors')

          # Code complexity
          vendor/bin/phpmetrics --report-json=metrics.json src
          AVG_COMPLEXITY=$(jq '[.classes[].ccn] | add / length' metrics.json)

          # Duplication
          DUPLICATION=$(vendor/bin/phpcpd --min-lines 5 src | grep -oP '\d+\.\d+%' | head -1)

          # Technical debt
          DEBT_RATIO=$(vendor/bin/phpmetrics --report-json=metrics.json src && jq '.project.maintainabilityIndex' metrics.json)

          # Lines of code
          LOC=$(cloc src --json | jq '.PHP.code')

          # Store metrics
          cat > quality-metrics.json << EOF
          {
            "date": "$(date -I)",
            "commit": "${{ github.sha }}",
            "coverage": $COVERAGE,
            "phpstan_errors": $PHPSTAN_ERRORS,
            "avg_complexity": $AVG_COMPLEXITY,
            "duplication": "$DUPLICATION",
            "debt_ratio": $DEBT_RATIO,
            "lines_of_code": $LOC
          }
          EOF

      - name: Upload to monitoring
        run: |
          # Send to your metrics backend (e.g., InfluxDB, Prometheus)
          curl -X POST https://metrics.example.com/api/quality \
            -H 'Content-Type: application/json' \
            -d @quality-metrics.json
```

### Quality Dashboard

```yaml
# Grafana dashboard configuration for quality metrics
{
  "dashboard": {
    "title": "Code Quality Metrics",
    "panels": [
      {
        "title": "Code Coverage Trend",
        "targets": [
          {
            "query": "SELECT coverage FROM quality_metrics WHERE time > now() - 30d"
          }
        ],
        "thresholds": [
          { "value": 80, "color": "green" },
          { "value": 70, "color": "yellow" },
          { "value": 0, "color": "red" }
        ]
      },
      {
        "title": "PHPStan Errors",
        "targets": [
          {
            "query": "SELECT phpstan_errors FROM quality_metrics WHERE time > now() - 30d"
          }
        ]
      },
      {
        "title": "Average Cyclomatic Complexity",
        "targets": [
          {
            "query": "SELECT avg_complexity FROM quality_metrics WHERE time > now() - 30d"
          }
        ],
        "thresholds": [
          { "value": 10, "color": "red" },
          { "value": 5, "color": "yellow" },
          { "value": 0, "color": "green" }
        ]
      }
    ]
  }
}
```

## Gate Configuration

### Quality Standards Configuration

```yaml
# .quality-gates.yml
gates:
  pre-commit:
    enabled: true
    timeout: 10s
    checks:
      - syntax
      - code-style
      - static-analysis-changed-files
      - unit-tests-fast

  pull-request:
    enabled: true
    timeout: 20m
    required:
      - static-analysis
      - unit-tests
      - security-scan
      - coverage-check
    optional:
      - complexity-check
      - mutation-testing

  pre-deployment:
    enabled: true
    timeout: 30m
    required:
      - integration-tests
      - e2e-tests
      - performance-tests
      - security-scan-full
    blocking: true

  post-deployment:
    enabled: true
    timeout: 10m
    required:
      - smoke-tests
      - metrics-validation
      - synthetic-monitoring
    auto-rollback: true

thresholds:
  coverage:
    minimum: 80
    target: 90

  complexity:
    cyclomatic: 10
    cognitive: 15

  security:
    max_critical: 0
    max_high: 0
    max_medium: 5

  performance:
    latency_p95_ms: 200
    latency_p99_ms: 500
    error_rate_percent: 1

  mutation:
    msi_minimum: 70
    covered_msi_minimum: 80
```

## Bypassing Gates

### Emergency Bypass Procedure

```yaml
# .github/workflows/emergency-deploy.yml
name: Emergency Deployment (Bypass Gates)

on:
  workflow_dispatch:
    inputs:
      reason:
        description: 'Reason for emergency deployment'
        required: true
      approver:
        description: 'Name of approver'
        required: true
      ticket:
        description: 'Incident ticket number'
        required: true

jobs:
  validate-emergency:
    name: Validate Emergency Request
    runs-on: ubuntu-latest

    steps:
      - name: Validate Approver
        run: |
          APPROVED_USERS="platform-lead,cto,vp-engineering"

          if [[ ! "$APPROVED_USERS" =~ "${{ github.event.inputs.approver }}" ]]; then
            echo "❌ Approver not authorized for emergency deployments"
            exit 1
          fi

      - name: Create Audit Log
        run: |
          cat > emergency-deploy-audit.json << EOF
          {
            "timestamp": "$(date -Iseconds)",
            "deployer": "${{ github.actor }}",
            "approver": "${{ github.event.inputs.approver }}",
            "reason": "${{ github.event.inputs.reason }}",
            "ticket": "${{ github.event.inputs.ticket }}",
            "commit": "${{ github.sha }}"
          }
          EOF

      - name: Store Audit Log
        run: |
          # Store in secure audit log system
          curl -X POST https://audit.example.com/api/emergency-deploys \
            -H 'Content-Type: application/json' \
            -H 'Authorization: Bearer ${{ secrets.AUDIT_API_KEY }}' \
            -d @emergency-deploy-audit.json

      - name: Notify Team
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "🚨 EMERGENCY DEPLOYMENT",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*🚨 Emergency Deployment Initiated*\n\n*Reason*: ${{ github.event.inputs.reason }}\n*Approver*: ${{ github.event.inputs.approver }}\n*Ticket*: ${{ github.event.inputs.ticket }}\n*Deployer*: ${{ github.actor }}"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_CRITICAL }}

  emergency-deploy:
    name: Emergency Deploy (Gates Bypassed)
    needs: validate-emergency
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://platform.example.com

    steps:
      - uses: actions/checkout@v4

      - name: Deploy to Production
        run: |
          # Deploy directly without gates
          kubectl set image deployment/bff bff=ghcr.io/platform/bff:${{ github.sha }} -n platform-production

      - name: Monitor Deployment
        run: |
          kubectl rollout status deployment/bff -n platform-production --timeout=5m

      - name: Run Basic Health Check
        run: |
          sleep 30
          curl -f https://platform.example.com/health || exit 1
```

### Bypass Documentation

All gate bypasses must be documented:

```markdown
## Emergency Deployment Checklist

- [ ] Incident ticket created: ___________
- [ ] Approver identified: ___________
- [ ] Reason documented: ___________
- [ ] Post-deployment review scheduled
- [ ] Gates to be re-enabled after deployment
- [ ] Root cause analysis planned
```

## Monitoring and Reporting

### Quality Gates Dashboard

```typescript
// monitoring/dashboards/quality-gates.ts
export const qualityGatesDashboard = {
  title: 'Quality Gates Status',
  panels: [
    {
      title: 'Gate Success Rate',
      query: 'rate(quality_gate_passed_total[1h]) / rate(quality_gate_runs_total[1h])',
      threshold: 0.95
    },
    {
      title: 'Average Gate Duration',
      query: 'avg(quality_gate_duration_seconds) by (gate)',
    },
    {
      title: 'Gate Failures by Type',
      query: 'sum(quality_gate_failed_total) by (gate, reason)',
    },
    {
      title: 'Bypass Events',
      query: 'sum(quality_gate_bypassed_total) by (reason)',
    }
  ]
};
```

### Weekly Quality Report

```bash
#!/bin/bash
# scripts/generate-quality-report.sh

WEEK_START=$(date -d 'last monday' +%Y-%m-%d)
WEEK_END=$(date -d 'next sunday' +%Y-%m-%d)

cat > quality-report-${WEEK_START}.md << EOF
# Quality Report: ${WEEK_START} to ${WEEK_END}

## Gate Statistics

### Success Rates
$(curl -s "https://prometheus.example.com/api/v1/query?query=rate(quality_gate_passed_total[7d])")

### Average Duration
$(curl -s "https://prometheus.example.com/api/v1/query?query=avg(quality_gate_duration_seconds[7d])")

### Top Failure Reasons
$(curl -s "https://prometheus.example.com/api/v1/query?query=topk(5, sum(quality_gate_failed_total[7d]) by (reason))")

## Trends
- Coverage: $(get_trend coverage 7d)
- Complexity: $(get_trend complexity 7d)
- Security Issues: $(get_trend security_issues 7d)

## Actions Required
- [ ] Review repeated gate failures
- [ ] Update thresholds if needed
- [ ] Address technical debt

---
Generated: $(date)
EOF
```

## Summary

This quality gates document provides:

1. **Comprehensive Gate Coverage**: From pre-commit to post-deployment
2. **Automated Enforcement**: All gates automated in CI/CD
3. **Clear Criteria**: Objective pass/fail criteria
4. **Fast Feedback**: Progressive gate strategy
5. **Safety Mechanisms**: Rollback on gate failures
6. **Bypass Procedures**: Documented emergency processes
7. **Monitoring**: Complete visibility into gate performance

Quality gates ensure consistent quality while maintaining development velocity.
