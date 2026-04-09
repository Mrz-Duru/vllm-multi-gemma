#!/bin/bash
# Resolves model shortcuts to full HuggingFace repo IDs

resolve_model() {
    local input="$1"

    case "$input" in
        gemma2-cosmos|gemma2|cosmos)
            echo "ytu-ce-cosmos/turkish-gemma2-9b-it"
            ;;
        gemma3-12b|gemma3)
            echo "google/gemma-3-12b-it"
            ;;
        gemma4-12b|gemma4)
            echo "google/gemma-4-12b-it"
            ;;
        *)
            # Assume it's already a full HF repo ID
            echo "$input"
            ;;
    esac
}
