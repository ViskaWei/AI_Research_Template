#!/bin/bash
# =============================================================================
# Research Daemon - 事件驱动的自动科研系统
# 核心思路: 训练后台跑，完成后才调用 Claude 做决策
# =============================================================================

set -e

# 配置
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
QUEUE_DIR="$PROJECT_DIR/.research_queue"
LOG_DIR="$PROJECT_DIR/logs/daemon"
STATE_FILE="$PROJECT_DIR/.daemon_state.json"

mkdir -p "$QUEUE_DIR/pending" "$QUEUE_DIR/running" "$QUEUE_DIR/done" "$LOG_DIR"

# =============================================================================
# 核心函数
# =============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/daemon.log"
}

# 检查是否有待处理的实验结果
check_completed_experiments() {
    local count=$(ls -1 "$QUEUE_DIR/done" 2>/dev/null | wc -l)
    echo "$count"
}

# 检查是否有正在运行的实验
check_running_experiments() {
    for job_file in "$QUEUE_DIR/running"/*.json; do
        [ -f "$job_file" ] || continue
        local pid=$(jq -r '.pid' "$job_file")
        if ! kill -0 "$pid" 2>/dev/null; then
            # 进程已结束，移动到 done
            local job_id=$(basename "$job_file" .json)
            log "Experiment $job_id completed"
            mv "$job_file" "$QUEUE_DIR/done/"
        fi
    done
}

# 调用 Claude 做决策（核心省 token 点：只传必要信息）
call_claude_for_decision() {
    local context_file="$1"
    local decision_type="$2"  # analyze_result | plan_next | handle_error

    log "Calling Claude for: $decision_type"

    # 构建最小 prompt
    local prompt=$(cat <<EOF
你是 Research Project Manager。当前任务: $decision_type

**上下文文件**: $context_file
**项目目录**: $PROJECT_DIR

请执行以下步骤:
1. 读取上下文文件了解实验结果
2. 更新 Hub 和 Roadmap
3. 决定下一步:
   - 如果需要新实验: 输出 ACTION:RUN_EXPERIMENT 和配置
   - 如果 Gate 通过: 输出 ACTION:NEXT_PHASE
   - 如果项目完成: 输出 ACTION:COMPLETE
4. 生成下一个实验的 config yaml（如需要）

输出格式:
---ACTION_START---
ACTION: [RUN_EXPERIMENT|NEXT_PHASE|COMPLETE|NEED_HUMAN]
CONFIG_FILE: [yaml路径，如果需要运行实验]
REASON: [一句话原因]
---ACTION_END---
EOF
)

    # 调用 Claude，只用 print 模式，最省 token
    local response=$(claude --print -p "$prompt" 2>&1)

    # 解析 action
    echo "$response" | sed -n '/---ACTION_START---/,/---ACTION_END---/p' > "$QUEUE_DIR/last_decision.txt"

    local action=$(grep "^ACTION:" "$QUEUE_DIR/last_decision.txt" | cut -d: -f2 | tr -d ' ')
    local config=$(grep "^CONFIG_FILE:" "$QUEUE_DIR/last_decision.txt" | cut -d: -f2 | tr -d ' ')

    echo "$action:$config"
}

# 提交实验到后台
submit_experiment() {
    local config_file="$1"
    local job_id="EXP-$(date +%Y%m%d%H%M%S)"

    log "Submitting experiment: $job_id with config: $config_file"

    # 创建 job 文件
    cat > "$QUEUE_DIR/pending/$job_id.json" <<EOF
{
    "job_id": "$job_id",
    "config": "$config_file",
    "submitted": "$(date -Iseconds)",
    "status": "pending"
}
EOF

    # 后台运行实验
    (
        cd "$PROJECT_DIR"
        source init.sh 2>/dev/null || true

        # 更新状态为 running
        mv "$QUEUE_DIR/pending/$job_id.json" "$QUEUE_DIR/running/"

        # 运行训练（捕获输出）
        local log_file="$LOG_DIR/$job_id.log"
        python scripts/train.py --config "$config_file" --exp-id "$job_id" > "$log_file" 2>&1
        local exit_code=$?

        # 保存结果摘要
        cat > "$QUEUE_DIR/done/$job_id.json" <<RESULT
{
    "job_id": "$job_id",
    "config": "$config_file",
    "completed": "$(date -Iseconds)",
    "exit_code": $exit_code,
    "log_file": "$log_file",
    "results_dir": "$PROJECT_DIR/results/$job_id"
}
RESULT

        # 移除 running 状态
        rm -f "$QUEUE_DIR/running/$job_id.json"

    ) &

    local pid=$!

    # 更新 job 文件加入 pid
    jq --arg pid "$pid" '.pid = $pid | .status = "running"' \
        "$QUEUE_DIR/pending/$job_id.json" > "$QUEUE_DIR/running/$job_id.json" 2>/dev/null || true
    rm -f "$QUEUE_DIR/pending/$job_id.json"

    log "Experiment $job_id started with PID $pid"
}

# 处理完成的实验
process_completed() {
    for result_file in "$QUEUE_DIR/done"/*.json; do
        [ -f "$result_file" ] || continue

        local job_id=$(jq -r '.job_id' "$result_file")
        log "Processing completed experiment: $job_id"

        # 调用 Claude 分析结果并决定下一步
        local decision=$(call_claude_for_decision "$result_file" "analyze_result")
        local action=$(echo "$decision" | cut -d: -f1)
        local config=$(echo "$decision" | cut -d: -f2)

        case "$action" in
            "RUN_EXPERIMENT")
                if [ -n "$config" ] && [ -f "$config" ]; then
                    submit_experiment "$config"
                fi
                ;;
            "NEXT_PHASE")
                log "Moving to next phase"
                ;;
            "COMPLETE")
                log "Research project completed!"
                touch "$PROJECT_DIR/.research_complete"
                ;;
            "NEED_HUMAN")
                log "Human intervention needed"
                # 可以发邮件/slack通知
                ;;
        esac

        # 归档处理过的结果
        mkdir -p "$QUEUE_DIR/archived"
        mv "$result_file" "$QUEUE_DIR/archived/"
    done
}

# =============================================================================
# 主循环
# =============================================================================

daemon_loop() {
    log "Research daemon started"

    while true; do
        # 检查是否已完成
        if [ -f "$PROJECT_DIR/.research_complete" ]; then
            log "Research complete. Daemon exiting."
            break
        fi

        # 检查运行中的实验状态
        check_running_experiments

        # 处理已完成的实验
        local completed=$(check_completed_experiments)
        if [ "$completed" -gt 0 ]; then
            process_completed
        fi

        # 如果没有运行中的实验且没有待处理的结果，检查是否需要启动新实验
        local running=$(ls -1 "$QUEUE_DIR/running" 2>/dev/null | wc -l)
        if [ "$running" -eq 0 ] && [ "$completed" -eq 0 ]; then
            # 检查是否有预定义的下一个实验
            if [ -f "$PROJECT_DIR/.next_experiment.yaml" ]; then
                submit_experiment "$PROJECT_DIR/.next_experiment.yaml"
                rm "$PROJECT_DIR/.next_experiment.yaml"
            fi
        fi

        # 休眠（后台实验跑着，这里不耗资源）
        sleep 60
    done
}

# =============================================================================
# 命令接口
# =============================================================================

case "${1:-daemon}" in
    daemon)
        daemon_loop
        ;;
    start)
        # 启动项目，首次调用 Claude 规划
        log "Starting new research project"
        claude --print -p "执行 /research-project-manager，分析当前项目状态，生成第一个 MVP 的 config.yaml 到 configs/mvp_next.yaml"
        if [ -f "$PROJECT_DIR/configs/mvp_next.yaml" ]; then
            submit_experiment "$PROJECT_DIR/configs/mvp_next.yaml"
        fi
        daemon_loop
        ;;
    status)
        echo "=== Research Daemon Status ==="
        echo "Pending: $(ls -1 "$QUEUE_DIR/pending" 2>/dev/null | wc -l)"
        echo "Running: $(ls -1 "$QUEUE_DIR/running" 2>/dev/null | wc -l)"
        echo "Completed: $(ls -1 "$QUEUE_DIR/done" 2>/dev/null | wc -l)"
        echo ""
        echo "Running experiments:"
        for f in "$QUEUE_DIR/running"/*.json; do
            [ -f "$f" ] && jq -r '"\(.job_id) - PID: \(.pid)"' "$f"
        done
        ;;
    submit)
        # 手动提交实验
        submit_experiment "$2"
        ;;
    *)
        echo "Usage: $0 {daemon|start|status|submit <config.yaml>}"
        exit 1
        ;;
esac
