#!/bin/bash
# =============================================================================
# 实验完成回调 - 训练脚本结束时调用此脚本
# 用法: python train.py ... && ./scripts/on_experiment_done.sh $EXP_ID $EXIT_CODE
# =============================================================================

EXP_ID="${1:-unknown}"
EXIT_CODE="${2:-0}"
PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
RESULTS_DIR="$PROJECT_DIR/results/$EXP_ID"

# 生成结果摘要（给 Claude 的最小上下文）
SUMMARY_FILE="$RESULTS_DIR/summary_for_claude.md"

cat > "$SUMMARY_FILE" <<EOF
# Experiment Summary: $EXP_ID

**Status**: $([ "$EXIT_CODE" -eq 0 ] && echo "✅ Success" || echo "❌ Failed (exit=$EXIT_CODE)")
**Time**: $(date)

## Key Metrics
$(if [ -f "$RESULTS_DIR/metrics.json" ]; then
    jq -r 'to_entries | .[] | "- \(.key): \(.value)"' "$RESULTS_DIR/metrics.json"
else
    echo "- (no metrics.json found)"
fi)

## Config Used
$(if [ -f "$RESULTS_DIR/config.yaml" ]; then
    head -30 "$RESULTS_DIR/config.yaml"
else
    echo "(no config found)"
fi)

## Log Tail
\`\`\`
$(tail -50 "$RESULTS_DIR/train.log" 2>/dev/null || echo "no log")
\`\`\`
EOF

echo "Summary generated: $SUMMARY_FILE"

# 如果 daemon 在运行，通知它
QUEUE_DIR="$PROJECT_DIR/.research_queue"
if [ -d "$QUEUE_DIR" ]; then
    cat > "$QUEUE_DIR/done/$EXP_ID.json" <<EOF
{
    "job_id": "$EXP_ID",
    "completed": "$(date -Iseconds)",
    "exit_code": $EXIT_CODE,
    "summary": "$SUMMARY_FILE",
    "results_dir": "$RESULTS_DIR"
}
EOF
    echo "Notified daemon of completion"
fi
