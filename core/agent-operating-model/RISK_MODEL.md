# Risk Model

> Taxonomy and mitigation strategies for agentic development risks.

This document classifies risks that arise during autonomous agent execution and provides guidance on identification, assessment, and mitigation.

---

## Risk Taxonomy

### Category 1: Architecture Risk

**Definition**: Changes that affect system structure, component boundaries, or fundamental design patterns.

**Indicators**:
- New dependencies introduced
- Interface contracts modified
- Data flow patterns altered
- Service boundaries changed

**Mitigation**:
- Require ADR for significant changes
- Mandatory escalation before implementation
- Incremental changes with rollback points

### Category 2: Security Risk

**Definition**: Changes that could introduce vulnerabilities, expose data, or weaken access controls.

**Indicators**:
- Authentication/authorization logic modified
- Input validation changed
- Cryptographic code touched
- External API integrations added
- Secrets or credentials involved

**Mitigation**:
- Security review checkpoint mandatory
- Automated SAST/DAST in pipeline
- Escalate any uncertainty immediately

### Category 3: Data Risk

**Definition**: Changes affecting data integrity, privacy, or persistence.

**Indicators**:
- Database schema modifications
- Data migration required
- PII handling changed
- Backup/recovery impacted

**Mitigation**:
- Require migration plan with rollback
- Test on production-like data
- Compliance review for PII changes

### Category 4: Performance Risk

**Definition**: Changes that could degrade system performance or scalability.

**Indicators**:
- Query patterns modified
- Caching logic changed
- New external calls added
- Batch processing affected

**Mitigation**:
- Benchmark before/after
- Load test for critical paths
- Gradual rollout with monitoring

### Category 5: Compatibility Risk

**Definition**: Changes that could break existing functionality or integrations.

**Indicators**:
- Public API contracts modified
- Configuration format changed
- Deprecation of features
- Third-party integration affected

**Mitigation**:
- Backward compatibility analysis
- Deprecation warnings before removal
- Consumer notification required

---

## Risk Levels

| Level | Definition | Response |
|-------|------------|----------|
| **Low** | Localized change, easily reversible | Proceed with standard workflow |
| **Medium** | Multiple components affected, reversible | Additional testing, checkpoint review |
| **High** | System-wide impact, complex rollback | Escalation required, phased rollout |
| **Critical** | Security/data breach potential | Immediate escalation, human approval mandatory |

---

## Risk Assessment Matrix

| Probability / Impact | Low Impact | Medium Impact | High Impact |
|---------------------|------------|---------------|-------------|
| **Likely** | Medium | High | Critical |
| **Possible** | Low | Medium | High |
| **Unlikely** | Low | Low | Medium |

---

## Tagging Convention

Apply risk tags to issues and PRs for visibility:

| Tag | Usage |
|-----|-------|
| `risk:arch` | Architecture changes |
| `risk:security` | Security-related changes |
| `risk:data` | Data/schema changes |
| `risk:perf` | Performance-sensitive changes |
| `risk:compat` | Breaking change potential |
| `risk:low` | Low risk level |
| `risk:medium` | Medium risk level |
| `risk:high` | High risk level |
| `risk:critical` | Critical risk level |

---

## Risk-Triggered Escalations

These risk combinations always require escalation:

1. **Any Critical risk** → Immediate human review
2. **Security + Data** → Compliance team notification
3. **Architecture + High** → ADR required before implementation
4. **Performance + Production** → Load test results required
5. **Compatibility + Public API** → Consumer impact assessment

---

## Documentation Requirements

When risk is identified, document:

```yaml
risk_assessment:
  category: [architecture|security|data|performance|compatibility]
  level: [low|medium|high|critical]
  description: "Brief description of the risk"
  mitigation: "Planned mitigation strategy"
  escalated: [true|false]
  escalation_reason: "Why escalation was/wasn't needed"
```

---

*Risk assessment is mandatory for all changes beyond trivial fixes.*
