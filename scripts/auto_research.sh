#!/bin/bash
# =============================================================================
# Auto Research - 自主科研模式（省 Token 版）
# =============================================================================
# 核心原理：训练后台跑 → 完成后才调 Claude → 省 96%+ token
# =============================================================================

set -e

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

# 配置文件路径
AUTONOMOUS_CONFIG="$PROJECT_DIR/configs/autonomous_mode.yaml"
STATE_FILE="$PROJECT_DIR/.autonomous_state.json"
PAUSE_FILE="$PROJECT_DIR/.pause_research"
COMPLETE_FILE="$PROJECT_DIR/.research_complete"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================================================
# 工具函数
# =============================================================================

print_header() {
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║        🤖 Autonomous Research Mode - Token Efficient       ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log() {
    local level="$1"
    local msg="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        INFO)  echo -e "${BLUE}[$timestamp]${NC} $msg" ;;
        OK)    echo -e "${GREEN}[$timestamp] ✓${NC} $msg" ;;
        WARN)  echo -e "${YELLOW}[$timestamp] ⚠${NC} $msg" ;;
        ERROR) echo -e "${RED}[$timestamp] ✗${NC} $msg" ;;
    esac

    # 同时写入日志文件
    mkdir -p "$PROJECT_DIR/logs"
    echo "[$timestamp] [$level] $msg" >> "$PROJECT_DIR/logs/autonomous.log"
}

# 读取 YAML 配置（简单版，支持基本键值）
get_config() {
    local key="$1"
    local default="$2"

    if [ ! -f "$AUTONOMOUS_CONFIG" ]; then
        echo "$default"
        return
    fi

    # 简单的 YAML 解析
    local value=$(grep "^[[:space:]]*$key:" "$AUTONOMOUS_CONFIG" | head -1 | sed 's/.*:[[:space:]]*//' | sed 's/[[:space:]]*#.*//')

    if [ -z "$value" ]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# 更新状态文件
update_state() {
    local key="$1"
    local value="$2"

    if [ ! -f "$STATE_FILE" ]; then
        echo "{}" > "$STATE_FILE"
    fi

    # 使用 jq 如果可用，否则用简单方法
    if command -v jq &> /dev/null; then
        jq --arg k "$key" --arg v "$value" '.[$k] = $v' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    else
        # 简单追加
        echo "\"$key\": \"$value\"" >> "$STATE_FILE.log"
    fi
}

# 获取状态
get_state() {
    local key="$1"
    local default="$2"

    if [ ! -f "$STATE_FILE" ]; then
        echo "$default"
        return
    fi

    if command -v jq &> /dev/null; then
        local value=$(jq -r --arg k "$key" '.[$k] // empty' "$STATE_FILE")
        if [ -z "$value" ]; then
            echo "$default"
        else
            echo "$value"
        fi
    else
        echo "$default"
    fi
}

# 检查暂停条件
check_pause_conditions() {
    # 手动暂停文件
    if [ -f "$PAUSE_FILE" ]; then
        log WARN "Manual pause file detected"
        return 1
    fi

    # 检查连续失败次数
    local consecutive_failures=$(get_state "consecutive_failures" "0")
    local max_failures=$(get_config "max_consecutive_failures" "3")
    if [ "$consecutive_failures" -ge "$max_failures" ]; then
        log ERROR "Too many consecutive failures: $consecutive_failures >= $max_failures"
        return 1
    fi

    # 检查磁盘空间
    local disk_usage=$(df "$PROJECT_DIR" | tail -1 | awk '{print $5}' | tr -d '%')
    local max_disk=$(get_config "disk_usage_percent" "90")
    if [ "$disk_usage" -ge "$max_disk" ]; then
        log ERROR "Disk usage too high: $disk_usage% >= $max_disk%"
        return 1
    fi

    return 0
}

# 检查完成条件
check_completion() {
    if [ -f "$COMPLETE_FILE" ]; then
        return 0
    fi

    # 检查迭代次数
    local iterations=$(get_state "iterations" "0")
    local max_iterations=$(get_config "max_iterations" "20")
    if [ "$iterations" -ge "$max_iterations" ]; then
        log WARN "Max iterations reached: $iterations"
        # 这不一定意味着完成，取决于配置
        local stop_at_max=$(get_config "max_iterations_reached" "false")
        if [ "$stop_at_max" = "true" ]; then
            return 0
        fi
    fi

    return 1
}

# 生成进度报告
generate_progress_report() {
    local report_dir="$PROJECT_DIR/logs/autonomous_reports"
    mkdir -p "$report_dir"

    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local report_file="$report_dir/progress_$timestamp.md"

    local iterations=$(get_state "iterations" "0")
    local max_iterations=$(get_config "max_iterations" "20")
    local start_time=$(get_state "start_time" "unknown")

    cat > "$report_file" <<EOF
# 🤖 自主科研进度报告

**生成时间**: $(date '+%Y-%m-%d %H:%M:%S')
**项目目录**: $PROJECT_DIR
**运行状态**: $([ -f "$PAUSE_FILE" ] && echo "⏸️ 暂停" || echo "🚀 运行中")

## 📊 迭代统计

| 指标 | 值 |
|------|-----|
| 当前迭代 | $iterations / $max_iterations |
| 开始时间 | $start_time |
| 连续失败 | $(get_state "consecutive_failures" "0") |

## 📁 最近实验

$(ls -lt "$PROJECT_DIR/results/" 2>/dev/null | head -6 || echo "无")

## 📈 最新指标

$(if [ -f "$PROJECT_DIR/results/latest/metrics.json" ]; then
    cat "$PROJECT_DIR/results/latest/metrics.json"
else
    echo "无可用指标"
fi)

## 📋 Hub 状态摘要

$(head -30 "$PROJECT_DIR"/experiments/*_hub.md 2>/dev/null || echo "Hub 文件未找到")

---
*此报告由自主科研模式自动生成*
EOF

    log OK "Progress report generated: $report_file"
    echo "$report_file"
}

# =============================================================================
# 核心功能
# =============================================================================

# 初始化项目
do_init() {
    local autonomous="$1"

    print_header
    log INFO "Initializing research project..."

    # 如果指定 --autonomous，确保配置文件存在
    if [ "$autonomous" = "--autonomous" ] || [ "$autonomous" = "-a" ]; then
        if [ ! -f "$AUTONOMOUS_CONFIG" ]; then
            log INFO "Creating default autonomous config..."
            mkdir -p configs
            cp "$PROJECT_DIR/configs/autonomous_mode.yaml" "$AUTONOMOUS_CONFIG" 2>/dev/null || \
            cat > "$AUTONOMOUS_CONFIG" <<'YAML'
autonomous_mode: true
iteration:
  max_iterations: 20
  max_consecutive_failures: 3
checkpoint:
  interval_hours: 6
pause_conditions:
  gate_failed_twice: true
  error_rate_threshold: 0.3
auto_decisions:
  skip_problem_confirmation: true
  auto_proceed_on_success: true
  gate_decision_policy: "auto"
YAML
        fi
        log OK "Autonomous mode enabled"
    fi

    # 初始化状态
    cat > "$STATE_FILE" <<EOF
{
    "iterations": 0,
    "consecutive_failures": 0,
    "start_time": "$(date -Iseconds)",
    "last_checkpoint": "$(date -Iseconds)",
    "phase": "init"
}
EOF

    # 调用 Claude 创建项目结构
    log INFO "Calling Claude to analyze and create project structure..."

    claude --print -p "
你是 Research Project Manager，运行在**自主模式**。

当前目录: $PROJECT_DIR

请完成初始化：
1. 检查是否有 research question 文件或 README 中的研究问题
2. 创建 Hub 和 Roadmap（使用 _backend/template/）
3. 规划 MVP-0.0 (Baseline)
4. 生成第一个实验配置到 configs/mvp_0_0.yaml

配置格式示例:
\`\`\`yaml
exp_id: \"EXP-$(date +%Y%m%d)-baseline-01\"
mvp: \"0.0\"
data:
  N: 10
  M: 100
model:
  type: \"baseline\"
training:
  epochs: 20
  lr: 0.001
output:
  dir: \"results/\${exp_id}\"
\`\`\`

完成后输出：
ACTION: READY
CONFIG: configs/mvp_0_0.yaml
"

    if [ -f "configs/mvp_0_0.yaml" ]; then
        log OK "Project initialized, first config ready: configs/mvp_0_0.yaml"
        echo ""
        echo "Next step:"
        echo "  ./scripts/auto_research.sh run configs/mvp_0_0.yaml"
        echo ""
        echo "Or start autonomous loop:"
        echo "  ./scripts/auto_research.sh loop"
    else
        log WARN "Config not created, please check Claude's output"
    fi
}

# 后台运行实验
do_run() {
    local config="${1:-configs/mvp_next.yaml}"
    local exp_id="${2:-EXP-$(date +%Y%m%d-%H%M%S)}"

    if [ ! -f "$config" ]; then
        log ERROR "Config not found: $config"
        return 1
    fi

    log INFO "Starting experiment: $exp_id"
    log INFO "Config: $config"

    mkdir -p logs "results/$exp_id"
    cp "$config" "results/$exp_id/config.yaml"

    # 创建运行脚本
    cat > "/tmp/run_$exp_id.sh" <<SCRIPT
#!/bin/bash
cd "$PROJECT_DIR"
source init.sh 2>/dev/null || true

# 运行训练
python scripts/train.py --config "$config" --exp-id "$exp_id" > "logs/$exp_id.log" 2>&1
EXIT_CODE=\$?

# 保存退出码
echo "\$EXIT_CODE" > "results/$exp_id/exit_code"

# 生成 Claude 用的摘要
cat > "results/$exp_id/summary_for_claude.md" <<SUMMARY
# Experiment: $exp_id
**Status**: \$([ "\$EXIT_CODE" -eq 0 ] && echo "✅ Success" || echo "❌ Failed")
**Config**: $config
**Time**: \$(date)

## Metrics
\$(cat "results/$exp_id/metrics.json" 2>/dev/null || echo "No metrics")

## Log Tail
\`\`\`
\$(tail -30 "logs/$exp_id.log")
\`\`\`
SUMMARY

# 更新 latest 链接
rm -f results/latest
ln -sf "$exp_id" results/latest

# 信号完成
touch "results/$exp_id/.done"
SCRIPT

    chmod +x "/tmp/run_$exp_id.sh"

    # 后台运行
    nohup "/tmp/run_$exp_id.sh" > /dev/null 2>&1 &
    local pid=$!
    echo "$pid" > "logs/$exp_id.pid"

    log OK "Experiment running in background (PID: $pid)"
    log INFO "Monitor: tail -f logs/$exp_id.log"

    # 更新状态
    update_state "current_exp" "$exp_id"
    update_state "current_pid" "$pid"
}

# 检查状态
do_status() {
    print_header

    echo "📊 Autonomous Research Status"
    echo ""

    # 模式
    local autonomous=$(get_config "autonomous_mode" "false")
    echo "Mode: $([ "$autonomous" = "true" ] && echo "🤖 Autonomous" || echo "👤 Manual")"
    echo ""

    # 状态
    echo "State:"
    echo "  Iterations: $(get_state "iterations" "0") / $(get_config "max_iterations" "20")"
    echo "  Failures: $(get_state "consecutive_failures" "0") / $(get_config "max_consecutive_failures" "3")"
    echo "  Started: $(get_state "start_time" "N/A")"
    echo ""

    # 运行中的实验
    echo "Running Experiments:"
    local found_running=false
    for pid_file in logs/*.pid; do
        [ -f "$pid_file" ] || continue
        local pid=$(cat "$pid_file")
        local exp=$(basename "$pid_file" .pid)
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "  ${YELLOW}🚀 $exp (PID: $pid)${NC}"
            found_running=true
        fi
    done
    [ "$found_running" = "false" ] && echo "  (none)"
    echo ""

    # 最近完成的实验
    echo "Recent Results:"
    ls -lt results/ 2>/dev/null | head -5 | tail -4
    echo ""

    # 暂停状态
    if [ -f "$PAUSE_FILE" ]; then
        echo -e "${YELLOW}⏸️  PAUSED - Remove $PAUSE_FILE to resume${NC}"
    fi

    if [ -f "$COMPLETE_FILE" ]; then
        echo -e "${GREEN}✅ COMPLETE - Research finished${NC}"
    fi
}

# 分析结果并决定下一步
do_next() {
    print_header
    log INFO "Analyzing results and planning next step..."

    # 找最新完成的实验
    local latest_summary=""
    if [ -L "results/latest" ]; then
        local latest_exp=$(readlink "results/latest")
        latest_summary="results/$latest_exp/summary_for_claude.md"
    fi

    if [ ! -f "$latest_summary" ]; then
        latest_summary=$(ls -t results/*/summary_for_claude.md 2>/dev/null | head -1)
    fi

    # 构建最小上下文
    local hub_summary=$(head -30 experiments/*_hub.md 2>/dev/null | head -40)
    local roadmap_summary=$(head -50 experiments/*_roadmap.md 2>/dev/null | head -60)

    # 调用 Claude（关键：精简上下文）
    local response=$(claude --print -p "
你是 Research Project Manager，运行在**自主模式**。

## 当前上下文（精简版）

### Hub 摘要（前30行）
$hub_summary

### Roadmap 摘要（前50行）
$roadmap_summary

### 最新实验结果
$(cat "$latest_summary" 2>/dev/null || echo "无")

## 任务

1. 分析实验结果
2. 更新 Hub（共识、假设状态、权威数字）
3. 更新 Roadmap（MVP状态、Gate评估）
4. 决定下一步：
   - 需要新实验 → 生成 configs/mvp_next.yaml
   - Gate 通过 → 输出 ACTION: NEXT_PHASE
   - 全部完成 → 输出 ACTION: COMPLETE

## 输出格式

---DECISION---
ACTION: [RUN_EXPERIMENT | NEXT_PHASE | COMPLETE | PAUSE]
REASON: [一句话原因]
CONFIG: [配置文件路径，如果 RUN_EXPERIMENT]
---END---
")

    echo "$response"

    # 解析决策
    local action=$(echo "$response" | sed -n '/---DECISION---/,/---END---/p' | grep "^ACTION:" | cut -d: -f2 | tr -d ' ')
    local config=$(echo "$response" | sed -n '/---DECISION---/,/---END---/p' | grep "^CONFIG:" | cut -d: -f2 | tr -d ' ')

    # 更新迭代计数
    local iterations=$(get_state "iterations" "0")
    iterations=$((iterations + 1))
    update_state "iterations" "$iterations"

    case "$action" in
        "RUN_EXPERIMENT")
            if [ -n "$config" ] && [ -f "$config" ]; then
                log OK "Next experiment: $config"
                update_state "consecutive_failures" "0"
                return 0
            else
                log WARN "Config file not found or not specified"
                return 1
            fi
            ;;
        "NEXT_PHASE")
            log OK "Moving to next phase"
            update_state "consecutive_failures" "0"
            return 0
            ;;
        "COMPLETE")
            log OK "Research complete!"
            touch "$COMPLETE_FILE"
            generate_progress_report
            return 2
            ;;
        "PAUSE")
            log WARN "Claude requested pause"
            touch "$PAUSE_FILE"
            return 1
            ;;
        *)
            log WARN "Unknown action: $action"
            local failures=$(get_state "consecutive_failures" "0")
            update_state "consecutive_failures" "$((failures + 1))"
            return 1
            ;;
    esac
}

# 自动循环
do_loop() {
    local max_iter="${1:-$(get_config "max_iterations" "20")}"
    local check_interval="${2:-300}"  # 默认 5 分钟
    local checkpoint_interval=$(($(get_config "interval_hours" "6") * 3600))

    print_header
    log INFO "Starting autonomous loop"
    log INFO "Max iterations: $max_iter"
    log INFO "Check interval: ${check_interval}s"
    log INFO "Checkpoint interval: ${checkpoint_interval}s"
    echo ""

    update_state "start_time" "$(date -Iseconds)"
    update_state "last_checkpoint" "$(date +%s)"

    local iteration=0

    while true; do
        iteration=$((iteration + 1))
        log INFO "=== Iteration $iteration ==="

        # 检查完成
        if check_completion; then
            log OK "Research completed!"
            generate_progress_report
            break
        fi

        # 检查暂停条件
        if ! check_pause_conditions; then
            log WARN "Pause condition triggered, stopping loop"
            generate_progress_report
            break
        fi

        # 检查是否有运行中的实验
        local running=false
        for pid_file in logs/*.pid; do
            [ -f "$pid_file" ] || continue
            local pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                running=true
                break
            fi
        done

        if [ "$running" = "true" ]; then
            log INFO "Experiment running, waiting..."
        else
            # 检查是否有完成的实验需要分析
            if [ -f "results/latest/.done" ]; then
                rm "results/latest/.done"

                # 调用 Claude 分析
                do_next
                local result=$?

                if [ $result -eq 2 ]; then
                    # 完成
                    break
                elif [ $result -eq 0 ]; then
                    # 继续，启动下一个实验
                    if [ -f "configs/mvp_next.yaml" ]; then
                        do_run "configs/mvp_next.yaml"
                    fi
                fi
            elif [ -f "configs/mvp_next.yaml" ] || [ -f "configs/mvp_0_0.yaml" ]; then
                # 有待运行的配置
                local next_config=""
                if [ -f "configs/mvp_next.yaml" ]; then
                    next_config="configs/mvp_next.yaml"
                else
                    next_config="configs/mvp_0_0.yaml"
                fi
                do_run "$next_config"
            else
                # 没有实验运行，也没有配置，调用 Claude 规划
                log INFO "No pending experiments, calling Claude to plan..."
                do_next
            fi
        fi

        # 检查是否需要生成检查点报告
        local last_checkpoint=$(get_state "last_checkpoint" "0")
        local now=$(date +%s)
        if [ $((now - last_checkpoint)) -ge $checkpoint_interval ]; then
            log INFO "Generating checkpoint report..."
            generate_progress_report
            update_state "last_checkpoint" "$now"
        fi

        # 等待
        sleep "$check_interval"
    done

    log OK "Autonomous loop ended"
}

# =============================================================================
# 主入口
# =============================================================================

case "${1:-help}" in
    init)
        do_init "$2"
        ;;
    run)
        do_run "$2" "$3"
        ;;
    status)
        do_status
        ;;
    next)
        do_next
        ;;
    loop)
        do_loop "$2" "$3"
        ;;
    report)
        generate_progress_report
        ;;
    pause)
        touch "$PAUSE_FILE"
        log OK "Research paused"
        ;;
    resume)
        rm -f "$PAUSE_FILE"
        log OK "Research resumed"
        do_loop
        ;;
    *)
        print_header
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  init [--autonomous]  Initialize project, optionally in autonomous mode"
        echo "  run <config> [id]    Run experiment in background"
        echo "  status               Show current status"
        echo "  next                 Analyze results and plan next step"
        echo "  loop [max] [sec]     Start autonomous loop"
        echo "  report               Generate progress report"
        echo "  pause                Pause autonomous mode"
        echo "  resume               Resume autonomous mode"
        echo ""
        echo "Autonomous Mode:"
        echo "  1. ./scripts/auto_research.sh init --autonomous"
        echo "  2. ./scripts/auto_research.sh loop"
        echo ""
        echo "Token Efficiency:"
        echo "  - Training runs in background (0 tokens)"
        echo "  - Claude called only at decision points (~2k tokens/call)"
        echo "  - 10 experiments ≈ 20k tokens (vs 500k traditional)"
        ;;
esac
