# Benchmark Runner

> Execute and record benchmark task results.

## Overview

This directory contains tools for running benchmark tasks and recording results.

## Files

| File | Purpose |
|------|---------|
| `run_bench.sh` | Interactive shell runner |
| `README.md` | This documentation |

## Usage

### List Available Tasks

```bash
./run_bench.sh --list
```

### Run a Specific Task

```bash
./run_bench.sh T001
```

The runner will:
1. Display the task description
2. Start a timer when you press Enter
3. Stop the timer when you complete the task
4. Prompt for results (status, iterations, quality)
5. Save results to `results/T00X_result.json`

### Run All Tasks

```bash
./run_bench.sh --all
```

Runs tasks sequentially with prompts between each.

## Results Format

Results are stored in JSON format:

```json
{
  "task_id": "T001",
  "status": "pass",
  "metrics": {
    "iterations": 2,
    "duration_seconds": 342
  },
  "quality_score": 8,
  "timestamp": "2026-01-28T16:30:00+00:00",
  "notes": ""
}
```

See `../scoring/scoring_schema.json` for complete schema.

## Manual Recording

If not using the runner, create result files manually in `../results/` following the schema.

## Future Enhancements

- Automated execution with agent APIs
- Result aggregation and reporting
- Comparison across agents/runs
