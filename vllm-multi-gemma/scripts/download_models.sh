#!/bin/bash
# Pre-download all 3 models to HF cache
# Run once to avoid download wait during model switches
# Usage: ./download_models.sh

set -e

if [ -z "$HF_TOKEN" ]; then
    echo "ERROR: HF_TOKEN is required"
    exit 1
fi

huggingface-cli login --token "$HF_TOKEN" 2>/dev/null || true

MODELS=(
    "ytu-ce-cosmos/turkish-gemma2-9b-it"
    "google/gemma-3-12b-it"
    "google/gemma-4-12b-it"
)

echo "Pre-downloading ${#MODELS[@]} models..."
echo ""

for model in "${MODELS[@]}"; do
    echo "══════════════════════════════════════"
    echo "Downloading: $model"
    echo "══════════════════════════════════════"
    huggingface-cli download "$model" --quiet || {
        echo "WARNING: Failed to download $model (may be gated or not yet released)"
    }
    echo ""
done

echo "Done. Cache location: ${HF_HOME:-$HOME/.cache/huggingface}"
du -sh "${HF_HOME:-$HOME/.cache/huggingface}/hub/" 2>/dev/null || true
