# System Context Diagram (C4 Level 1)

## Overview

The System Context diagram shows the AI Workflow Platform and how it fits into the wider ecosystem, including external users, systems, and services.

## Diagram

```
                                    ┌─────────────────────────┐
                                    │    End Users            │
                                    │  (Web, Mobile, CLI)     │
                                    └────────────┬────────────┘
                                                 │
                                                 │ HTTPS
                                                 │
                    ┌────────────────────────────▼────────────────────────────┐
                    │                                                          │
                    │          AI Workflow Processing Platform                 │
                    │                                                          │
                    │   Orchestrates AI agents with LLMs to execute           │
                    │   complex multi-step workflows with validation          │
                    │   and quality control                                   │
                    │                                                          │
                    └────┬──────┬──────┬──────┬──────┬──────┬──────┬─────────┘
                         │      │      │      │      │      │      │
                         │      │      │      │      │      │      │
         ┌───────────────┘      │      │      │      │      │      └──────────────┐
         │                      │      │      │      │      │                     │
         │                      │      │      │      │      │                     │
    HTTPS│                      │      │      │      │      │                HTTPS│
         │                      │      │      │      │      │                     │
┌────────▼────────┐   ┌─────────▼──────▼──────▼──────▼──────▼────────┐  ┌───────▼──────┐
│                 │   │                                                │  │              │
│  OpenAI API     │   │         External Services                     │  │  Keycloak    │
│  (GPT-4, etc.)  │   │                                                │  │  (Identity)  │
│                 │   │  - Anthropic (Claude)                          │  │              │
│  Provides LLM   │   │  - SMTP Server (Email)                         │  │  OAuth2/OIDC │
│  capabilities   │   │  - Twilio (SMS)                                │  │  MFA         │
│                 │   │  - S3-compatible storage                       │  │              │
└─────────────────┘   └────────────────────────────────────────────────┘  └──────────────┘
                                         │
                                         │ HTTPS
                                         │
                              ┌──────────▼─────────┐
                              │                    │
                              │  Admin Users       │
                              │  (Operations Team) │
                              │                    │
                              └────────────────────┘
```

## Actors

### End Users (People)

**Who**: Regular users of the platform
- Content creators
- Workflow designers
- Business analysts
- Data scientists

**What they do**:
- Create and manage AI workflows
- Execute workflows with custom parameters
- Review validation results and outputs
- Monitor workflow execution status
- Access audit logs and reports

**How they interact**:
- Web Application (React/Vue.js frontend)
- Mobile Applications (iOS/Android)
- Command-Line Interface (CLI tool)
- All via HTTPS through API Gateway

### Admin Users (People)

**Who**: Platform administrators and operations team
- DevOps engineers
- Security administrators
- Compliance officers
- System administrators

**What they do**:
- Configure system settings
- Manage user access and permissions
- Monitor system health and performance
- Review security alerts
- Generate compliance reports
- Perform system maintenance

**How they interact**:
- Admin Web Console
- kubectl (Kubernetes management)
- Monitoring dashboards (Grafana)
- Log aggregation (Loki)

## External Systems

### OpenAI API (Software System)

**Purpose**: Primary LLM provider for AI agent capabilities

**Capabilities**:
- GPT-4 (advanced reasoning)
- GPT-3.5-turbo (fast responses)
- GPT-4-turbo (cost-effective)
- Embeddings API (vector representations)

**Interaction**:
- HTTPS REST API
- API key authentication
- Token-based billing
- Rate limiting considerations

**Data Flow**:
- Platform → OpenAI: Prompts, parameters, context
- OpenAI → Platform: Generated text, token usage, metadata

**SLA**:
- 99.9% uptime (OpenAI SLA)
- Rate limits: 90k RPM (GPT-4), 10k RPM (GPT-3.5-turbo)
- Response time: 2-10 seconds typical

### Anthropic API (Software System)

**Purpose**: Alternative LLM provider (Claude models)

**Capabilities**:
- Claude 3 Opus (most capable)
- Claude 3 Sonnet (balanced)
- Claude 3 Haiku (fast)
- Large context window (200k tokens)

**Interaction**:
- HTTPS REST API
- API key authentication
- Similar to OpenAI API structure

**Usage**:
- Fallback when OpenAI unavailable
- Specific use cases requiring large context
- A/B testing different models

### SMTP Server (Software System)

**Purpose**: Email delivery for notifications

**Providers** (configurable):
- SendGrid
- AWS SES
- Postmark
- Mailgun

**Interaction**:
- SMTP protocol
- Authentication via API key
- TLS encrypted

**Use Cases**:
- Workflow completion notifications
- Validation failure alerts
- Security alerts
- Compliance reports
- Password reset emails

### Twilio (Software System)

**Purpose**: SMS delivery for critical notifications

**Capabilities**:
- International SMS delivery
- Delivery receipts
- Two-way messaging (future)

**Interaction**:
- REST API over HTTPS
- API key authentication

**Use Cases**:
- Critical system alerts
- MFA codes
- High-priority notifications
- On-call engineer notifications

### S3-Compatible Storage (Software System)

**Purpose**: Object storage for files and backups

**Implementations**:
- AWS S3
- MinIO (self-hosted)
- Google Cloud Storage
- Azure Blob Storage

**Interaction**:
- S3 API over HTTPS
- IAM-based authentication
- Server-side encryption

**Stored Data**:
- Uploaded files
- File versions
- Database backups
- Log archives
- Compliance report exports

### Keycloak (Software System)

**Purpose**: Identity and Access Management

**Capabilities**:
- User authentication (OAuth2/OIDC)
- Multi-factor authentication
- Single Sign-On (SSO)
- User federation (LDAP/AD)
- Role-based access control

**Interaction**:
- OAuth2/OIDC protocols
- REST API for user management
- JWT tokens

**Integration**:
- All platform services authenticate against Keycloak
- Users login once, access all services
- Tokens validated on every request

## System Boundary

### Inside the Platform

The AI Workflow Processing Platform boundary includes:
- ✅ All microservices (7 services)
- ✅ Databases (PostgreSQL per service)
- ✅ Message broker (RabbitMQ)
- ✅ Cache layer (Redis)
- ✅ API Gateway (Kong)
- ✅ Service Mesh (Istio)
- ✅ Observability stack (Prometheus, Grafana, Loki, Tempo)
- ✅ Secrets management (Vault)

### Outside the Platform

External dependencies:
- ❌ LLM providers (OpenAI, Anthropic)
- ❌ Email services (SMTP)
- ❌ SMS services (Twilio)
- ❌ Object storage (S3)
- ❌ Identity provider (Keycloak) *Could be internal depending on deployment*
- ❌ User devices (browsers, mobile apps)

## Data Flows

### User Workflow Execution Flow

```
1. End User → Platform
   - User creates/executes workflow via Web UI
   - HTTPS request to API Gateway
   - JWT token for authentication

2. Platform → OpenAI API
   - Platform executes agent step
   - Sends prompt to OpenAI
   - Receives generated response

3. Platform → Platform
   - Validates response internally
   - Continues workflow execution
   - Updates workflow state

4. Platform → SMTP Server
   - Sends completion notification
   - Email to user

5. Platform → End User
   - Returns workflow result
   - HTTPS response with JSON
```

### Admin Monitoring Flow

```
1. Admin User → Platform
   - Access monitoring dashboard
   - HTTPS to Grafana (via API Gateway)

2. Platform (internal)
   - Prometheus scrapes metrics
   - Loki aggregates logs
   - Tempo traces requests

3. Platform → Admin User
   - Displays dashboards
   - Real-time metrics and logs
```

### Compliance Report Flow

```
1. End User → Platform
   - Requests GDPR data export
   - HTTPS API call

2. Platform (internal)
   - Audit service queries all services
   - Aggregates user data
   - Generates PDF report

3. Platform → S3 Storage
   - Uploads report file
   - Encrypts at rest

4. Platform → End User
   - Sends download link via email
   - Pre-signed S3 URL (time-limited)
```

## Security Boundaries

### Trust Zones

**Zone 1: Internet (Untrusted)**
- End users
- External services
- Potential attackers

**Zone 2: DMZ (Limited Trust)**
- API Gateway
- Load balancers
- WAF

**Zone 3: Application Layer (Trusted)**
- Microservices
- Internal APIs
- Service-to-service communication (mTLS)

**Zone 4: Data Layer (Highly Trusted)**
- Databases
- Secret storage (Vault)
- Backup storage

### Security Controls Between Zones

**Internet → DMZ**:
- TLS 1.3 encryption
- WAF rules
- Rate limiting
- DDoS protection

**DMZ → Application**:
- JWT token validation
- OAuth2 authentication
- API key validation
- Request/response filtering

**Application → Application**:
- mTLS (mutual TLS)
- Service-to-service authorization
- Network policies (Kubernetes)

**Application → Data**:
- Database authentication
- Encrypted connections
- Row-level security
- Audit logging

## Non-Functional Requirements

### Performance
- **API Response Time**: P95 < 200ms (excluding LLM calls)
- **LLM Execution**: P95 < 30s (dependent on provider)
- **Throughput**: 10,000 concurrent workflow executions

### Availability
- **Uptime Target**: 99.9% (43.8 minutes downtime/month)
- **Recovery Time Objective (RTO)**: < 4 hours
- **Recovery Point Objective (RPO)**: < 15 minutes

### Scalability
- **Horizontal Scaling**: All services scale independently
- **Auto-scaling**: Based on CPU, memory, queue depth
- **Database**: Read replicas for query scaling

### Security
- **Encryption**: TLS 1.3 in transit, AES-256 at rest
- **Authentication**: OAuth2/OIDC for users, mTLS for services
- **Authorization**: RBAC + ABAC
- **Compliance**: GDPR, SOC2, ISO27001, NIS2

### Compliance
- **GDPR**: Right to access, right to be forgotten, data portability
- **SOC2**: Security, availability, confidentiality controls
- **ISO27001**: Information security management system
- **NIS2**: Network and information security directive

## Deployment Context

### Cloud-Agnostic Architecture

The platform can be deployed on:
- ✅ AWS (EKS, RDS, S3, etc.)
- ✅ Google Cloud (GKE, Cloud SQL, GCS, etc.)
- ✅ Azure (AKS, Azure Database, Blob Storage, etc.)
- ✅ On-premises (Kubernetes, PostgreSQL, MinIO, etc.)

**Infrastructure as Code**: Terraform modules for each provider

### Multi-Region Considerations (Future)

For global deployment:
- **Active-Active**: Multiple regions serving traffic
- **Data Residency**: Data stored in user's region (GDPR)
- **Latency**: Route users to nearest region
- **Failover**: Automatic failover between regions

## Capacity Planning

### Current Capacity (Initial Deployment)

**Users**: 1,000 concurrent users
**Workflows**: 10,000 executions/day
**LLM Calls**: 100,000 calls/day
**Storage**: 100 TB total (files + databases)

### Growth Projections

**Year 1**: 10x growth
**Year 2**: 5x additional growth
**Year 3**: 3x additional growth

**Scaling Strategy**:
- Horizontal pod autoscaling (Kubernetes)
- Database read replicas
- CDN for static assets
- Message queue partitioning

## Disaster Recovery

### Backup Strategy
- **Databases**: Daily full backups + continuous WAL archiving
- **Files**: Replicated to multiple S3 regions
- **Configuration**: Stored in Git (GitOps)

### Recovery Scenarios

**Scenario 1: Service Failure**
- Kubernetes self-healing restarts failed pods
- Load balancer routes traffic away
- No data loss, < 1 minute downtime

**Scenario 2: Database Failure**
- Promote read replica to primary
- Point-in-time recovery from backups
- < 15 minutes downtime, < 15 minutes data loss

**Scenario 3: Region Failure**
- Failover to secondary region
- DNS-based traffic routing
- < 4 hours downtime (manual intervention)

## Conclusion

The System Context diagram establishes:

✅ **Clear Boundaries**: What's inside/outside the platform
✅ **External Dependencies**: LLM providers, email, SMS, storage
✅ **User Types**: End users, admin users
✅ **Data Flows**: How information moves through the system
✅ **Security Zones**: Trust boundaries and controls
✅ **Non-Functional Requirements**: Performance, availability, security

This context informs all subsequent architectural decisions and detailed designs in the Container, Component, and Deployment diagrams.
