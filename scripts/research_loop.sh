#!/bin/bash
# =============================================================================
# Research Loop - 真正的持续科研循环
# =============================================================================
# 使用方法：
#   ./scripts/research_loop.sh              # 单窗口模式
#   ./scripts/research_loop.sh --worker A   # 多窗口模式，指定窗口 ID
# =============================================================================

set -e

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

# 窗口 ID（多窗口支持）
WORKER_ID="${2:-$(hostname)-$$}"
LOCK_DIR="$PROJECT_DIR/.locks"
STATE_FILE="$PROJECT_DIR/.research_state.json"

mkdir -p "$LOCK_DIR" logs

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} ${GREEN}[$WORKER_ID]${NC} $1"
}

# =============================================================================
# 多窗口锁管理
# =============================================================================

claim_mvp() {
    local mvp="$1"
    local lock_file="$LOCK_DIR/mvp_${mvp}.lock"

    # 检查是否已被占用
    if [ -f "$lock_file" ]; then
        local owner=$(cat "$lock_file")
        # 检查 owner 是否还活着（通过 pid 文件）
        if [ -f "$LOCK_DIR/worker_${owner}.pid" ]; then
            local pid=$(cat "$LOCK_DIR/worker_${owner}.pid")
            if kill -0 "$pid" 2>/dev/null; then
                return 1  # 被占用
            fi
        fi
        # 死锁清理
        rm -f "$lock_file"
    fi

    # 占用
    echo "$WORKER_ID" > "$lock_file"
    return 0
}

release_mvp() {
    local mvp="$1"
    rm -f "$LOCK_DIR/mvp_${mvp}.lock"
}

register_worker() {
    echo "$$" > "$LOCK_DIR/worker_${WORKER_ID}.pid"
    log "Worker registered: $WORKER_ID (PID: $$)"
}

unregister_worker() {
    rm -f "$LOCK_DIR/worker_${WORKER_ID}.pid"
    # 释放所有该 worker 持有的锁
    for lock in "$LOCK_DIR"/mvp_*.lock; do
        [ -f "$lock" ] || continue
        if [ "$(cat "$lock")" = "$WORKER_ID" ]; then
            rm -f "$lock"
        fi
    done
    log "Worker unregistered"
}

trap unregister_worker EXIT

# =============================================================================
# 获取下一个可执行的 MVP
# =============================================================================

get_next_mvp() {
    # 从 Roadmap 中找状态为 ⏳计划 或 🔴就绪 的 MVP
    local roadmap=$(find experiments -name "*_roadmap.md" | head -1)

    if [ -z "$roadmap" ]; then
        echo ""
        return
    fi

    # 解析 MVP 列表，找未完成且未被锁定的
    # 简化版：返回第一个未锁定的待做 MVP
    local mvps=$(grep -E "^\| [0-9]+\.[0-9]+ \|" "$roadmap" | grep -E "⏳|🔴" | awk -F'|' '{print $2}' | tr -d ' ')

    for mvp in $mvps; do
        if claim_mvp "$mvp"; then
            echo "$mvp"
            return
        fi
    done

    echo ""
}

# =============================================================================
# 单次迭代
# =============================================================================

run_one_iteration() {
    local mvp="$1"

    log "Starting iteration for MVP-$mvp"

    # 调用 Claude 执行完整流程
    # 关键：使用 --print 模式，让 Claude 完成后自动返回
    claude --print -p "
你是 Research Project Manager，运行在**自主模式**，窗口 ID: $WORKER_ID

## 当前任务
执行 MVP-$mvp 的完整流程：

1. **读取状态**
   - 读取 Hub 前 30 行了解战略
   - 读取 Roadmap 找到 MVP-$mvp 的配置

2. **生成 Coding Prompt**（如果不存在）
   - 保存到 experiments/*/prompts/prompt_mvp${mvp}.md

3. **执行实验**
   - 后台运行: nohup python ... &
   - 等待完成或超时（最多 30 分钟）

4. **写实验报告**
   - 使用 _backend/template/exp.md
   - 保存到 experiments/*/exp_mvp${mvp}_$(date +%Y%m%d).md

5. **更新文档**
   - 更新 Hub: 共识表、假设状态、权威数字
   - 更新 Roadmap: MVP 状态 → ✅完成

6. **输出决策**

完成后必须输出：
---ITERATION_DONE---
MVP: $mvp
STATUS: [SUCCESS | FAILED | TIMEOUT]
NEXT_MVP: [下一个建议的 MVP，如果有]
GATE_STATUS: [Gate 是否通过]
---END---
"

    # 释放锁
    release_mvp "$mvp"
}

# =============================================================================
# 主循环
# =============================================================================

main_loop() {
    register_worker

    log "=== Research Loop Started ==="
    log "Project: $PROJECT_DIR"
    log "Mode: $([ -n "$2" ] && echo "Multi-worker" || echo "Single-worker")"
    echo ""

    local iteration=0
    local max_iterations=50
    local idle_count=0
    local max_idle=10  # 连续 10 次没有任务则退出

    while [ $iteration -lt $max_iterations ]; do
        iteration=$((iteration + 1))

        # 检查停止信号
        if [ -f "$PROJECT_DIR/.stop_research" ]; then
            log "Stop signal received"
            break
        fi

        # 检查是否完成
        if [ -f "$PROJECT_DIR/.research_complete" ]; then
            log "Research complete!"
            break
        fi

        # 获取下一个 MVP
        local next_mvp=$(get_next_mvp)

        if [ -z "$next_mvp" ]; then
            idle_count=$((idle_count + 1))
            if [ $idle_count -ge $max_idle ]; then
                log "No more MVPs available, exiting"
                break
            fi
            log "No available MVP, waiting... ($idle_count/$max_idle)"
            sleep 60
            continue
        fi

        idle_count=0

        # 执行迭代
        log "=== Iteration $iteration: MVP-$next_mvp ==="
        run_one_iteration "$next_mvp"

        # 短暂休息
        sleep 10
    done

    log "=== Research Loop Ended ==="
}

# =============================================================================
# 入口
# =============================================================================

case "${1:-loop}" in
    loop)
        main_loop "$@"
        ;;
    status)
        echo "=== Worker Status ==="
        echo "Active workers:"
        for pid_file in "$LOCK_DIR"/worker_*.pid; do
            [ -f "$pid_file" ] || continue
            worker=$(basename "$pid_file" .pid | sed 's/worker_//')
            pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                echo "  ✓ $worker (PID: $pid)"
            else
                echo "  ✗ $worker (dead)"
            fi
        done
        echo ""
        echo "MVP locks:"
        for lock in "$LOCK_DIR"/mvp_*.lock; do
            [ -f "$lock" ] || continue
            mvp=$(basename "$lock" .lock | sed 's/mvp_//')
            owner=$(cat "$lock")
            echo "  MVP-$mvp → $owner"
        done
        ;;
    stop)
        touch "$PROJECT_DIR/.stop_research"
        echo "Stop signal sent"
        ;;
    *)
        echo "Usage: $0 [loop|status|stop] [--worker ID]"
        echo ""
        echo "Examples:"
        echo "  $0                    # Start single worker"
        echo "  $0 --worker A         # Start worker A"
        echo "  $0 --worker B         # Start worker B (in another terminal)"
        echo "  $0 status             # Show all workers"
        echo "  $0 stop               # Stop all workers"
        ;;
esac
