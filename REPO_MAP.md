# Repository Map

> **Find your path in 60 seconds.**

This repository serves two purposes: (1) a methodology for secure, auditable AI-assisted development, and (2) a practical framework for agentic workflows where AI agents autonomously handle Issue→PR cycles with human oversight at checkpoints.

---

## Who Is This For?

| Profile | Start Here | Then Read |
|---------|------------|-----------|
| **Developer** | [LLM_USAGE_GUIDE.md](LLM_USAGE_GUIDE.md) | [04-development/](04-development/) |
| **Security Engineer** | [02-security/07-security-checklist.md](02-security/07-security-checklist.md) | [02-security/](02-security/) |
| **Agentic Researcher** | [core/README.md](core/README.md) | [runtime/](runtime/) → [bench/](bench/) |
| **Apply to Your Project** | [BOOTSTRAP_NEW_PROJECT.md](runtime/golden-path/BOOTSTRAP_NEW_PROJECT.md) | [core/](core/) → [runtime/prompts/](runtime/prompts/) |

---

## Repository Structure

```
ai-driven-dev-instructions/
│
├── [Root Documentation]
│   ├── README.md                    # Project overview
│   ├── REPO_MAP.md                  # This file — navigation hub
│   ├── METHODOLOGY.md               # Core methodology
│   ├── LLM_USAGE_GUIDE.md          # Agent entry point
│   ├── DOCUMENTATION_INDEX.md       # Complete file index
│   └── GLOSSARY.md                  # Terminology
│
├── [Reference Documentation]        # The "what" — specs and standards
│   ├── 01-architecture/             # System design, ADRs, patterns
│   ├── 02-security/                 # Security-by-design specs
│   ├── 03-infrastructure/           # Cloud-native infrastructure
│   ├── 04-development/              # Coding standards
│   ├── 05-code-review/              # Review checklists
│   ├── 06-cicd/                     # Pipeline and deployment
│   ├── 07-operations/               # Monitoring, incidents
│   └── 08-services/                 # Microservice specifications
│
├── [Agentic Dev Reference]          # The "how" — agentic workflows
│   ├── core/                        # Normative spec (rules, roles, templates)
│   ├── runtime/                     # Execution (prompts, gates, quickstart)
│   ├── bench/                       # Benchmark (tasks, scoring, runner)
│   └── tools/                       # Validation utilities
│
└── [Supporting]
    ├── CONTRIBUTING.md
    ├── LICENSE
    └── .github/                     # GitHub templates & workflows
```

---

## Quick Start Paths

### Path A: Understand the Methodology
1. [METHODOLOGY.md](METHODOLOGY.md) — How to write AI-friendly documentation
2. [LLM_USAGE_GUIDE.md](LLM_USAGE_GUIDE.md) — Task-based navigation for agents
3. [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md) — 13-week phased plan

### Path B: Evaluate Security Practices
1. [02-security/01-security-principles.md](02-security/01-security-principles.md) — Core principles
2. [02-security/07-security-checklist.md](02-security/07-security-checklist.md) — Pre-deployment gates
3. [05-code-review/02-security-review-checklist.md](05-code-review/02-security-review-checklist.md) — Review checklist

### Path C: Explore Agentic Development
1. [core/README.md](core/README.md) — What "agentic-ready" means
2. [runtime/README.md](runtime/README.md) — How to run agentic cycles
3. [bench/README.md](bench/README.md) — Measure agent performance

### Path D: Apply to Your Own Project
1. [BOOTSTRAP_NEW_PROJECT.md](runtime/golden-path/BOOTSTRAP_NEW_PROJECT.md) — Setup guide (full/minimal/agent-only)
2. [core/spec/CHECKPOINTS.md](core/spec/CHECKPOINTS.md) — Adapt checkpoints to your stack
3. [runtime/prompts/CLAUDE_CODE_SYSTEM.md](runtime/prompts/CLAUDE_CODE_SYSTEM.md) — Customize system prompt

---

## Key Concepts

| Term | Definition |
|------|------------|
| **Agentic-ready** | A repo structured for autonomous AI agent execution with human checkpoints |
| **Golden Path** | The fastest route from zero to first successful Issue→PR |
| **Checkpoint** | A validation gate where human approval may be required |
| **Handoff** | Structured transfer of work between agent roles |
| **Escalation** | When an agent must pause and request human decision |

See [GLOSSARY.md](GLOSSARY.md) for complete terminology.

---

## What's New: Agentic Dev Reference

This repository is evolving to become a reference implementation for **autonomous AI-driven development**. The new structure adds:

- **core/** — The normative specification (MUST/SHOULD/MAY rules)
- **runtime/** — Executable workflows (prompts, quality gates)
- **bench/** — Measurable benchmarks (tasks, scoring)
- **tools/** — Validation and automation utilities

The existing documentation (01-08 directories) remains the reference example. The new structure provides the framework to make any repo "agentic-ready."

---

*Last updated: 2026-01-28*
