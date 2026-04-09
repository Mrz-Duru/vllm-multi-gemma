# vLLM Multi-Gemma

Run Gemma 2 (YTU-Cosmos), Gemma 3 12B, and Gemma 4 12B interchangeably on a single GPU via vLLM, deployed on vast.ai.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  vast.ai Instance (RTX 5090 / A6000 / A100)        │
│                                                     │
│  ┌───────────────────────────────────────────────┐  │
│  │  Docker: ghcr.io/YOU/vllm-multi-gemma         │  │
│  │                                               │  │
│  │  MODEL_NAME=gemma2-cosmos                     │  │
│  │       ↓                                       │  │
│  │  vLLM (nohup) → :8000/v1/chat/completions    │  │
│  │                                               │  │
│  │  switch_model.sh gemma3-12b                   │  │
│  │       ↓ kill old → start new                  │  │
│  │  vLLM (nohup) → :8000/v1/chat/completions    │  │
│  └───────────────────────────────────────────────┘  │
│                    ↓                                │
│  https://INSTANCE-8000.proxy.vast.ai/v1             │
└─────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Push to GitHub & GHCR

```bash
# Clone and push to your GitHub
git clone <this-repo>
cd vllm-multi-gemma
git remote set-url origin https://github.com/YOUR_USER/vllm-multi-gemma.git
git push -u origin main

# GitHub Actions will auto-build and push to ghcr.io
# Or use the Colab notebook for manual build+push
```

### 2. Launch on vast.ai (via Colab)

Open `notebooks/colab_setup.ipynb` in Google Colab and follow the steps.

### 3. Launch on vast.ai (via CLI)

```bash
pip install vastai
vastai set api-key YOUR_KEY

# Find a GPU
vastai search offers 'gpu_ram>=32 num_gpus=1 reliability>0.95' -o 'dph_total'

# Launch
vastai create instance OFFER_ID \
    --image ghcr.io/YOUR_USER/vllm-multi-gemma:latest \
    --disk 100 \
    --env '-e MODEL_NAME=gemma2-cosmos -e HF_TOKEN=hf_xxx -e PORT=8000'
```

### 4. Switch Models

```bash
# SSH into the instance
ssh -p PORT root@HOST

# Switch to Gemma 3
/opt/vllm-gemma/scripts/switch_model.sh gemma3-12b

# Switch to Gemma 4
/opt/vllm-gemma/scripts/switch_model.sh gemma4-12b

# Back to Gemma 2 (YTU-Cosmos)
/opt/vllm-gemma/scripts/switch_model.sh gemma2-cosmos
```

## Model Shortcuts

| Shortcut | HuggingFace Repo | Params | VRAM (BF16) |
|----------|-----------------|--------|-------------|
| `gemma2-cosmos` | `ytu-ce-cosmos/turkish-gemma2-9b-it` | 9B | ~18 GB |
| `gemma3-12b` | `google/gemma-3-12b-it` | 12B | ~24 GB |
| `gemma4-12b` | `google/gemma-4-12b-it` | 12B | ~24 GB |

You can also use any full HuggingFace repo ID directly:
```bash
/opt/vllm-gemma/scripts/switch_model.sh organization/any-model-name
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MODEL_NAME` | *(required)* | Model shortcut or full HF repo ID |
| `HF_TOKEN` | *(required)* | HuggingFace access token |
| `PORT` | `8000` | vLLM server port |
| `MAX_MODEL_LEN` | `4096` | Max sequence length |
| `GPU_MEMORY_UTILIZATION` | `0.92` | Fraction of GPU memory to use |
| `DTYPE` | `bfloat16` | Model dtype (bfloat16 or float16) |
| `VLLM_EXTRA_ARGS` | *(empty)* | Additional vllm flags |

## GPU Requirements

Running full-precision (BF16) — no quantization:

| GPU | VRAM | Gemma 2 9B | Gemma 3/4 12B |
|-----|------|-----------|---------------|
| RTX 5090 | 32 GB | ✅ Comfortable | ✅ Tight (4K ctx) |
| A6000 | 48 GB | ✅ | ✅ Comfortable |
| A100 40GB | 40 GB | ✅ | ✅ |
| A100 80GB | 80 GB | ✅ | ✅ Full context |

## API Usage

The endpoint is OpenAI-compatible:

```python
from openai import OpenAI

client = OpenAI(
    base_url="https://INSTANCE-8000.proxy.vast.ai/v1",
    api_key="not-needed",
)

response = client.chat.completions.create(
    model="ytu-ce-cosmos/turkish-gemma2-9b-it",  # or whatever is loaded
    messages=[{"role": "user", "content": "Merhaba!"}],
    max_tokens=256,
)
print(response.choices[0].message.content)
```

## Project Structure

```
vllm-multi-gemma/
├── docker/
│   ├── Dockerfile          # vllm-openai based image
│   └── entrypoint.sh       # Launches vLLM via nohup
├── scripts/
│   ├── resolve_model.sh    # Shortcut → HF repo ID mapper
│   ├── switch_model.sh     # Hot-swap running model
│   ├── health_check.sh     # Server + GPU status
│   ├── download_models.sh  # Pre-cache all models
│   └── stop_models.sh      # Graceful shutdown
├── config/
│   └── models.json         # Model registry
├── notebooks/
│   └── colab_setup.ipynb   # Build, push, deploy, test
├── tests/
│   └── test_endpoint.py    # Endpoint validation
├── .github/workflows/
│   └── build-push.yml      # CI: auto-build to GHCR
├── .env.example
├── vastai_template.json
└── README.md
```

## License

MIT
