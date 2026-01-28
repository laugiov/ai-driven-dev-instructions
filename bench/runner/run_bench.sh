#!/bin/bash
# Benchmark Runner - Manual Execution Helper
# Usage: ./run_bench.sh [task_id] [--all]

set -e

BENCH_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TASKS_DIR="$BENCH_DIR/tasks"
RESULTS_DIR="$BENCH_DIR/results"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create results directory if needed
mkdir -p "$RESULTS_DIR"

show_help() {
    echo "Benchmark Runner"
    echo ""
    echo "Usage:"
    echo "  ./run_bench.sh T001        Run specific task"
    echo "  ./run_bench.sh --list      List all tasks"
    echo "  ./run_bench.sh --all       Run all tasks (interactive)"
    echo "  ./run_bench.sh --help      Show this help"
    echo ""
}

list_tasks() {
    echo "Available Benchmark Tasks:"
    echo ""
    for task_dir in "$TASKS_DIR"/T0*/; do
        if [ -d "$task_dir" ]; then
            task_id=$(basename "$task_dir")
            if [ -f "$task_dir/metadata.json" ]; then
                name=$(grep -o '"name": *"[^"]*"' "$task_dir/metadata.json" | cut -d'"' -f4)
                difficulty=$(grep -o '"difficulty": *"[^"]*"' "$task_dir/metadata.json" | cut -d'"' -f4)
                echo "  $task_id: $name [$difficulty]"
            fi
        fi
    done
    echo ""
}

run_task() {
    local task_id=$1
    local task_dir="$TASKS_DIR/$task_id"

    if [ ! -d "$task_dir" ]; then
        echo -e "${RED}Error: Task $task_id not found${NC}"
        exit 1
    fi

    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Task: $task_id${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""

    # Display task description
    if [ -f "$task_dir/task.md" ]; then
        cat "$task_dir/task.md"
    fi

    echo ""
    echo -e "${YELLOW}----------------------------------------${NC}"
    echo "Instructions:"
    echo "1. Read the task above"
    echo "2. Execute with your agent"
    echo "3. Record results in $RESULTS_DIR/${task_id}_result.json"
    echo ""
    echo "Press Enter when ready to start timing..."
    read -r

    # Start timer
    start_time=$(date +%s)

    echo ""
    echo -e "${GREEN}Timer started. Execute the task now.${NC}"
    echo "Press Enter when complete..."
    read -r

    # End timer
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    echo ""
    echo -e "${GREEN}Task completed in ${duration} seconds${NC}"
    echo ""

    # Prompt for results
    echo "Record your results:"
    echo "  Status (pass/fail/partial): "
    read -r status
    echo "  Iterations (1-5): "
    read -r iterations
    echo "  Quality score (1-10): "
    read -r quality

    # Create result file
    result_file="$RESULTS_DIR/${task_id}_result.json"
    cat > "$result_file" << EOF
{
  "task_id": "$task_id",
  "status": "$status",
  "metrics": {
    "iterations": $iterations,
    "duration_seconds": $duration
  },
  "quality_score": $quality,
  "timestamp": "$(date -Iseconds)",
  "notes": ""
}
EOF

    echo ""
    echo -e "${GREEN}Results saved to $result_file${NC}"
}

# Main
case "${1:-}" in
    --help|-h)
        show_help
        ;;
    --list|-l)
        list_tasks
        ;;
    --all|-a)
        for task_dir in "$TASKS_DIR"/T0*/; do
            if [ -d "$task_dir" ]; then
                task_id=$(basename "$task_dir")
                run_task "$task_id"
                echo ""
                echo "Continue to next task? (y/n)"
                read -r cont
                if [ "$cont" != "y" ]; then
                    break
                fi
            fi
        done
        ;;
    T0*)
        run_task "$1"
        ;;
    *)
        show_help
        ;;
esac
