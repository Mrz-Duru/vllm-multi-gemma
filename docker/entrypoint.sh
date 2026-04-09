#!/bin/bash
set -e

SCRIPTS_DIR="/opt/vllm-gemma/scripts"
LOG_DIR="/var/log/vllm"
mkdir -p "$LOG_DIR"

# ── Validate required env ──
if [ -z "$MODEL_NAME" ]; then
    echo "ERROR: MODEL_NAME is required."
    echo "Usage: docker run -e MODEL_NAME=google/gemma-3-12b-it -e HF_TOKEN=hf_xxx ..."
    echo ""
    echo "Available model shortcuts:"
    echo "  gemma2-cosmos   -> ytu-ce-cosmos/turkish-gemma2-9b-it"
    echo "  gemma3-12b      -> google/gemma-3-12b-it"
    echo "  gemma4-12b      -> google/gemma-4-12b-it"
    exit 1
fi

if [ -z "$HF_TOKEN" ]; then
    echo "ERROR: HF_TOKEN is required for gated model access."
    exit 1
fi

# ── Login to HuggingFace ──
echo "Logging into HuggingFace..."
# NEW lines:
export HUGGING_FACE_HUB_TOKEN="$HF_TOKEN"
hf auth login --token "$HF_TOKEN" 2>/dev/null || huggingface-cli login --token "$HF_TOKEN" 2>/dev/null || true

# ── Resolve model shortcuts ──
source "$SCRIPTS_DIR/resolve_model.sh"
RESOLVED_MODEL=$(resolve_model "$MODEL_NAME")
echo "Resolved model: $RESOLVED_MODEL"

# ── Start vLLM ──
echo "Starting vLLM server for: $RESOLVED_MODEL"
echo "  Port: $PORT"
echo "  Max model len: $MAX_MODEL_LEN"
echo "  GPU memory utilization: $GPU_MEMORY_UTILIZATION"
echo "  Dtype: $DTYPE"
echo "  Extra args: $VLLM_EXTRA_ARGS"

nohup python3 -m vllm.entrypoints.openai.api_server \
    --model "$RESOLVED_MODEL" \
    --host 0.0.0.0 \
    --port "$PORT" \
    --dtype "$DTYPE" \
    --max-model-len "$MAX_MODEL_LEN" \
    --gpu-memory-utilization "$GPU_MEMORY_UTILIZATION" \
    --trust-remote-code \
    --reasoning-parser deepseek_r1 \
    --enable-auto-tool-choice \
    --tool-call-parser hermes \
    $VLLM_EXTRA_ARGS \
    > "$LOG_DIR/vllm.log" 2>&1 &

VLLM_PID=$!
echo "$VLLM_PID" > /tmp/vllm.pid
echo "vLLM started with PID: $VLLM_PID"

# ── Wait for server to be ready ──
echo "Waiting for vLLM to load model and become ready..."
MAX_WAIT=600  # 10 minutes for large models
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    if curl -s "http://localhost:$PORT/v1/models" > /dev/null 2>&1; then
        echo "vLLM is ready! (took ${ELAPSED}s)"
        echo ""
        echo "═══════════════════════════════════════════════════"
        echo "  Model:    $RESOLVED_MODEL"
        echo "  Endpoint: http://localhost:$PORT/v1"
        echo "  Health:   http://localhost:$PORT/health"
        echo "═══════════════════════════════════════════════════"
        break
    fi

    # Check if process died
    if ! kill -0 "$VLLM_PID" 2>/dev/null; then
        echo "ERROR: vLLM process died. Last 50 lines of log:"
        tail -50 "$LOG_DIR/vllm.log"
        exit 1
    fi

    sleep 5
    ELAPSED=$((ELAPSED + 5))
    if [ $((ELAPSED % 30)) -eq 0 ]; then
        echo "  Still loading... (${ELAPSED}s elapsed)"
    fi
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "ERROR: vLLM did not become ready within ${MAX_WAIT}s"
    tail -50 "$LOG_DIR/vllm.log"
    exit 1
fi

# ── Keep container alive by tailing logs ──
echo "Tailing vLLM logs (container will stay alive)..."
tail -f "$LOG_DIR/vllm.log"