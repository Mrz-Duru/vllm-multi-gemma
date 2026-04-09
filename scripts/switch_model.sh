#!/bin/bash
# Switch running model without restarting container
# Usage: ./switch_model.sh gemma3-12b
#        ./switch_model.sh google/gemma-3-12b-it

set -e

SCRIPTS_DIR="$(dirname "$0")"
LOG_DIR="/var/log/vllm"
mkdir -p "$LOG_DIR"

NEW_MODEL="${1:?Usage: switch_model.sh <model_name_or_shortcut>}"

# Resolve shortcut
source "$SCRIPTS_DIR/resolve_model.sh"
RESOLVED_MODEL=$(resolve_model "$NEW_MODEL")

echo "Switching to: $RESOLVED_MODEL"

# ── Kill current vLLM ──
if [ -f /tmp/vllm.pid ]; then
    OLD_PID=$(cat /tmp/vllm.pid)
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Stopping current vLLM (PID: $OLD_PID)..."
        kill "$OLD_PID"
        # Wait for graceful shutdown
        for i in $(seq 1 30); do
            if ! kill -0 "$OLD_PID" 2>/dev/null; then
                echo "  Stopped."
                break
            fi
            sleep 1
        done
        # Force kill if still alive
        if kill -0 "$OLD_PID" 2>/dev/null; then
            echo "  Force killing..."
            kill -9 "$OLD_PID" 2>/dev/null || true
        fi
    fi
    rm -f /tmp/vllm.pid
fi

# ── Clear GPU memory ──
sleep 3

# ── Read env vars (use defaults if not set) ──
PORT="${PORT:-8000}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-4096}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.92}"
DTYPE="${DTYPE:-bfloat16}"
VLLM_EXTRA_ARGS="${VLLM_EXTRA_ARGS:-}"

# ── Start new vLLM ──
echo "Starting vLLM for: $RESOLVED_MODEL"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/vllm_${TIMESTAMP}.log"

nohup python3 -m vllm.entrypoints.openai.api_server \
    --model "$RESOLVED_MODEL" \
    --host 0.0.0.0 \
    --port "$PORT" \
    --dtype "$DTYPE" \
    --max-model-len "$MAX_MODEL_LEN" \
    --gpu-memory-utilization "$GPU_MEMORY_UTILIZATION" \
    --trust-remote-code \
    --enable-reasoning \
    --reasoning-config '{"type": "deepseek_r1"}' \
    --enable-auto-tool-choice \
    --tool-call-parser hermes \
    $VLLM_EXTRA_ARGS \
    > "$LOG_FILE" 2>&1 &

NEW_PID=$!
echo "$NEW_PID" > /tmp/vllm.pid
echo "vLLM started with PID: $NEW_PID"
echo "Log: $LOG_FILE"

# ── Wait for ready ──
echo "Waiting for model to load..."
MAX_WAIT=600
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    if curl -s "http://localhost:$PORT/v1/models" > /dev/null 2>&1; then
        echo ""
        echo "Ready! Model switched to: $RESOLVED_MODEL (took ${ELAPSED}s)"
        echo "Endpoint: http://localhost:$PORT/v1"
        exit 0
    fi
    if ! kill -0 "$NEW_PID" 2>/dev/null; then
        echo "ERROR: vLLM died during startup:"
        tail -30 "$LOG_FILE"
        exit 1
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    if [ $((ELAPSED % 30)) -eq 0 ]; then
        echo "  Loading... (${ELAPSED}s)"
    fi
done

echo "ERROR: Timeout after ${MAX_WAIT}s"
exit 1