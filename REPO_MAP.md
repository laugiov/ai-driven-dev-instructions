# Repository Map

> **Find your path in 60 seconds.**

A **technology-agnostic framework** for autonomous AI-driven software delivery — from Issue to PR with human oversight at defined checkpoints.

---

## Who Is This For?

| Profile | Start Here | Then Read |
|---------|------------|-----------|
| **Apply to Your Project** | [BOOTSTRAP_NEW_PROJECT.md](runtime/golden-path/BOOTSTRAP_NEW_PROJECT.md) | [core/](core/) → [runtime/prompts/](runtime/prompts/) |
| **Agentic Researcher** | [core/README.md](core/README.md) | [runtime/](runtime/) → [bench/](bench/) |
| **Explore the Example** | [examples/php-symfony-k8s/](examples/php-symfony-k8s/) | [LLM_USAGE_GUIDE](examples/php-symfony-k8s/LLM_USAGE_GUIDE.md) |

---

## Repository Structure

```
ai-driven-dev-instructions/
│
├── [Framework]                      # Technology-agnostic core
│   ├── core/                        # Agent operating model, checkpoints, templates
│   │   ├── agent-operating-model/   # Roles, workflow, escalation, handoffs
│   │   ├── spec/                    # Checkpoints, DoD, risk model
│   │   └── templates/               # ADR template
│   │
│   ├── runtime/                     # Execution guides and prompts
│   │   ├── golden-path/             # Quickstarts, bootstrap, first task
│   │   ├── prompts/                 # Agent role prompts, system prompt
│   │   └── quality-gates/           # Definition of Done
│   │
│   ├── bench/                       # Benchmark suite
│   │   ├── tasks/                   # 10 benchmark tasks (T001-T010)
│   │   ├── scoring/                 # Scoring schema and rubric
│   │   └── runner/                  # Execution scripts
│   │
│   └── tools/                       # Validation utilities
│
├── [Examples]                       # Stack-specific implementations
│   └── php-symfony-k8s/             # Complete reference (52 docs)
│       ├── 01-architecture/         # System design, ADRs, DDD
│       ├── 02-security/             # Zero Trust, OAuth2, Vault
│       ├── 03-infrastructure/       # Kubernetes, Istio, observability
│       ├── 04-development/          # Coding standards, testing, APIs
│       ├── 05-code-review/          # Review checklists
│       ├── 06-cicd/                 # Pipeline, GitOps
│       ├── 07-operations/           # Monitoring, incidents, DR
│       └── 08-services/             # 7 microservice specs
│
├── [Methodology]
│   ├── README.md                    # Project overview
│   ├── REPO_MAP.md                  # This file
│   ├── METHODOLOGY.md               # Core methodology
│   ├── GLOSSARY.md                  # Terminology
│   └── DOCUMENTATION_INDEX.md       # Complete file index
│
├── [Case Studies]
│   └── case-studies/                # Real-world applications
│
└── [Supporting]
    ├── CONTRIBUTING.md
    ├── LICENSE
    └── .github/                     # Templates & workflows
```

---

## Quick Start Paths

### Path A: Apply to Your Own Project
1. [BOOTSTRAP_NEW_PROJECT.md](runtime/golden-path/BOOTSTRAP_NEW_PROJECT.md) — Setup guide (full/minimal/agent-only)
2. [core/spec/CHECKPOINTS.md](core/spec/CHECKPOINTS.md) — Adapt checkpoints to your stack
3. [runtime/prompts/CLAUDE_CODE_SYSTEM.md](runtime/prompts/CLAUDE_CODE_SYSTEM.md) — Customize system prompt

### Path B: Understand the Framework
1. [core/README.md](core/README.md) — Agent Operating Model overview
2. [core/agent-operating-model/AGENT_OPERATING_MODEL.md](core/agent-operating-model/AGENT_OPERATING_MODEL.md) — Roles and workflow
3. [runtime/README.md](runtime/README.md) — Execution guides

### Path C: Explore Agentic Development
1. [core/README.md](core/README.md) — What "agentic-ready" means
2. [runtime/README.md](runtime/README.md) — How to run agentic cycles
3. [bench/README.md](bench/README.md) — Measure agent performance

### Path D: Learn from the Example
1. [examples/php-symfony-k8s/README.md](examples/php-symfony-k8s/README.md) — Example overview
2. [examples/php-symfony-k8s/LLM_USAGE_GUIDE.md](examples/php-symfony-k8s/LLM_USAGE_GUIDE.md) — Task-based navigation
3. [METHODOLOGY.md](METHODOLOGY.md) — Documentation methodology

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

## Framework vs Examples

| Component | Purpose | Technology |
|-----------|---------|------------|
| **Framework** (core/, runtime/, bench/) | Universal agentic development patterns | Agnostic |
| **Examples** (examples/) | Reference implementations | Stack-specific |

The framework defines *how* AI agents work autonomously with human oversight. Examples show *what* this looks like for specific technology stacks.

---

*Last updated: 2026-01-28*
