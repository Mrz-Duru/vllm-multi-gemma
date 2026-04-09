#!/bin/bash
# Gracefully stop the running vLLM process

if [ ! -f /tmp/vllm.pid ]; then
    echo "No vLLM PID file found. Nothing to stop."
    exit 0
fi

PID=$(cat /tmp/vllm.pid)

if ! kill -0 "$PID" 2>/dev/null; then
    echo "vLLM process $PID is already dead."
    rm -f /tmp/vllm.pid
    exit 0
fi

echo "Stopping vLLM (PID: $PID)..."
kill "$PID"

for i in $(seq 1 30); do
    if ! kill -0 "$PID" 2>/dev/null; then
        echo "Stopped."
        rm -f /tmp/vllm.pid
        exit 0
    fi
    sleep 1
done

echo "Force killing..."
kill -9 "$PID" 2>/dev/null || true
rm -f /tmp/vllm.pid
echo "Done."
