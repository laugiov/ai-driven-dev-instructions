# Tools — Validation and Automation

> **Utilities that support agentic development workflows.**

This directory contains scripts and tools for validating conformance, checking documentation hygiene, and automating common tasks.

## Planned Tools

| Tool | Purpose | Status |
|------|---------|--------|
| `aidd_validate.py` | Validate repo conformance + link integrity | Planned |
| `aidd_index_repo.py` | Generate repo index/summary (v0.3) | Future |
| `aidd_make_task.py` | Create benchmark task skeleton | Planned |

## Usage

Once implemented, tools will be runnable from the repository root:

```bash
# Validate conformance
python tools/aidd_validate.py

# Create a new benchmark task
python tools/aidd_make_task.py T011 "Add security review template"
```

## Design Principles

- **Zero external dependencies** where possible (stdlib Python)
- **Clear output** — Pass/fail with actionable messages
- **CI-friendly** — Exit codes suitable for pipeline integration
- **Incremental** — Tools added as needed, not speculatively

---

*See [REPO_MAP.md](../REPO_MAP.md) for navigation guidance.*
