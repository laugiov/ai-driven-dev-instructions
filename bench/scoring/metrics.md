# Benchmark Metrics

> What we measure and why.

This document defines the metrics used to evaluate agent performance on benchmark tasks.

---

## Primary Metrics

### Success Rate

**Definition**: Percentage of tasks completed successfully.

**Calculation**: `(tasks_passed / tasks_attempted) * 100`

**Interpretation**:
- 90%+ = Excellent
- 70-89% = Good
- 50-69% = Needs improvement
- <50% = Significant issues

### Iteration Count

**Definition**: Number of attempts before task completion or failure.

**Calculation**: Count of Plan→Act→Observe→Fix cycles

**Interpretation**:
- 1-2 = Efficient
- 3-4 = Acceptable
- 5 = At limit
- >5 = Escalation triggered

### Quality Score

**Definition**: Human assessment of output quality (1-10).

**Factors**:
- Correctness
- Completeness
- Code/doc quality
- Adherence to standards

**Interpretation**:
- 9-10 = Exceptional
- 7-8 = Good
- 5-6 = Acceptable
- <5 = Below standard

---

## Secondary Metrics

### Duration

**Definition**: Wall-clock time from task start to completion.

**Use**: Efficiency comparison between agents/runs.

### Token Cost

**Definition**: Total tokens consumed (input + output).

**Use**: Cost efficiency analysis.

### Files Modified

**Definition**: Count of files changed.

**Use**: Scope assessment, complexity indicator.

### Escalation Rate

**Definition**: Percentage of tasks requiring human input.

**Calculation**: `(tasks_with_escalations / tasks_attempted) * 100`

**Use**: Autonomy measurement.

---

## Composite Scores

### Efficiency Score

**Formula**: `success_rate * (1 / avg_iterations) * quality_score`

**Use**: Overall performance ranking.

### Autonomy Score

**Formula**: `success_rate * (1 - escalation_rate)`

**Use**: Independence measurement.

---

## Aggregation

### Per-Task
Individual task results stored in `results/T00X_result.json`

### Per-Run
Aggregate across all tasks in a single session.

### Per-Agent
Historical comparison across multiple runs.

---

## Reporting

### Summary Report Format

```
Benchmark Run: [date]
Agent: [identifier]

Tasks: X attempted, Y passed, Z failed
Success Rate: XX%
Avg Iterations: X.X
Avg Quality: X.X/10
Avg Duration: Xm Xs

By Difficulty:
- Easy: X/Y passed
- Medium: X/Y passed
- Hard: X/Y passed

Escalations: X total
```

### Detailed Report

Include per-task breakdown with acceptance criteria results.

---

## Baseline Targets

| Metric | Target | Stretch |
|--------|--------|---------|
| Success Rate | 80% | 95% |
| Avg Iterations | ≤3 | ≤2 |
| Avg Quality | 7+ | 9+ |
| Escalation Rate | ≤20% | ≤10% |

---

*Metrics should inform improvement, not punish experimentation.*
