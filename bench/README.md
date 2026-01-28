# Bench — Measuring Agentic Performance

> **How do you know if your agentic workflow actually works?**

This directory contains a lightweight benchmark suite for evaluating AI agent performance on real development tasks. Think of it as a "mini SWE-bench" tailored to this repository's methodology.

---

## Contents

| Directory | Purpose | Status |
|-----------|---------|--------|
| [tasks/](tasks/) | Benchmark tasks with acceptance criteria | ✅ 10 tasks |
| [scoring/](scoring/) | Scoring schema and metrics | ✅ Active |
| [runner/](runner/) | Execution scripts | ✅ Active |

---

## Tasks (`tasks/`)

10 benchmark tasks ranging from easy to hard:

| Task | Name | Difficulty | Category |
|------|------|------------|----------|
| [T001](tasks/T001/) | Fix Broken Link in README | Easy | Documentation |
| [T002](tasks/T002/) | Add PR Template | Easy | Documentation |
| [T003](tasks/T003/) | Create Glossary Entry | Easy | Documentation |
| [T004](tasks/T004/) | Update Documentation Index | Easy | Documentation |
| [T005](tasks/T005/) | Write ADR for Technology Choice | Medium | Documentation |
| [T006](tasks/T006/) | Create Issue Template | Medium | Configuration |
| [T007](tasks/T007/) | Add Validation Script | Medium | Tooling |
| [T008](tasks/T008/) | Create Workflow Diagram | Medium | Documentation |
| [T009](tasks/T009/) | Implement Handoff Validator | Hard | Tooling |
| [T010](tasks/T010/) | Full Issue-to-PR Demo | Hard | Integration |

Each task includes:
- `task.md` — Description, acceptance criteria, constraints
- `metadata.json` — Difficulty, category, skills tested

---

## Scoring (`scoring/`)

| Document | Description |
|----------|-------------|
| [scoring_schema.json](scoring/scoring_schema.json) | JSON schema for result format |
| [metrics.md](scoring/metrics.md) | What we measure and baseline targets |

### Key Metrics

| Metric | Target |
|--------|--------|
| Success Rate | ≥80% |
| Avg Iterations | ≤3 |
| Avg Quality | ≥7/10 |
| Escalation Rate | ≤20% |

---

## Runner (`runner/`)

| File | Description |
|------|-------------|
| [run_bench.sh](runner/run_bench.sh) | Interactive shell runner |
| [README.md](runner/README.md) | Usage documentation |

### Quick Start

```bash
# List available tasks
./bench/runner/run_bench.sh --list

# Run a specific task
./bench/runner/run_bench.sh T001

# Run all tasks interactively
./bench/runner/run_bench.sh --all
```

---

## Results

Results are stored in `results/` (created on first run):

```
results/
├── T001_result.json
├── T002_result.json
└── ...
```

---

## Running a Benchmark

### Manual Process

1. Select a task from the table above
2. Read `task.md` for requirements
3. Execute with your agent
4. Record results using the runner or manually
5. Compare against baseline targets

### With Runner

```bash
./bench/runner/run_bench.sh T001
```

The runner will:
- Display the task
- Time your execution
- Prompt for results
- Save to JSON

---

## Adding New Tasks

1. Create directory: `tasks/T0XX/`
2. Add `task.md` with:
   - Objective
   - Setup (if needed)
   - Task description
   - Acceptance criteria
   - Constraints
   - Expected duration
   - Difficulty
3. Add `metadata.json` with structured metadata

---

## Philosophy

- **Reproducible** — Same task, same setup, comparable results
- **Practical** — Tasks reflect real development work
- **Progressive** — Difficulty scales from trivial to complex
- **Honest** — We measure what matters, not what flatters

---

*See [../REPO_MAP.md](../REPO_MAP.md) for navigation guidance.*
