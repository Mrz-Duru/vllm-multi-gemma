FROM vllm/vllm-openai:latest

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl jq procps && \
    rm -rf /var/lib/apt/lists/* && \
    ln -sf $(which python3) /usr/local/bin/python 2>/dev/null || true

# Copy scripts
COPY scripts/ /opt/vllm-gemma/scripts/
RUN chmod +x /opt/vllm-gemma/scripts/*.sh

# Copy config
COPY config/ /opt/vllm-gemma/config/

# Copy entrypoint
COPY docker/entrypoint.sh /opt/vllm-gemma/entrypoint.sh
RUN chmod +x /opt/vllm-gemma/entrypoint.sh

# Default env vars
ENV MODEL_NAME=""
ENV HF_TOKEN=""
ENV PORT=8000
ENV VLLM_EXTRA_ARGS=""
ENV MAX_MODEL_LEN=4096
ENV GPU_MEMORY_UTILIZATION=0.92
ENV DTYPE="bfloat16"

# HuggingFace cache — mount a volume here on vast.ai to persist across model switches
ENV HF_HOME=/root/.cache/huggingface

EXPOSE 8000

ENTRYPOINT ["/opt/vllm-gemma/entrypoint.sh"]