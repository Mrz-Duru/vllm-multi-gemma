#!/bin/bash
# Check vLLM server health and currently loaded model
PORT="${PORT:-8000}"

echo "Checking vLLM at http://localhost:$PORT ..."

# Health endpoint
if curl -sf "http://localhost:$PORT/health" > /dev/null 2>&1; then
    echo "Status: HEALTHY"
else
    echo "Status: DOWN"
    if [ -f /tmp/vllm.pid ]; then
        PID=$(cat /tmp/vllm.pid)
        if kill -0 "$PID" 2>/dev/null; then
            echo "  Process $PID is running (model may still be loading)"
        else
            echo "  Process $PID is dead"
        fi
    else
        echo "  No PID file found"
    fi
    exit 1
fi

# Models endpoint
echo ""
echo "Loaded model(s):"
curl -sf "http://localhost:$PORT/v1/models" | jq -r '.data[].id' 2>/dev/null || echo "  (could not fetch)"

# Quick stats
echo ""
echo "Process info:"
if [ -f /tmp/vllm.pid ]; then
    PID=$(cat /tmp/vllm.pid)
    ps -p "$PID" -o pid,rss,etime,cmd --no-headers 2>/dev/null || echo "  PID $PID not found"
fi

# GPU usage
echo ""
echo "GPU memory:"
nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv,noheader 2>/dev/null || echo "  nvidia-smi not available"
