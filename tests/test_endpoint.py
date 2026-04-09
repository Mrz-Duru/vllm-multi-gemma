"""
Test vLLM endpoint — works against local, vast.ai proxy, or any OpenAI-compatible server.
Usage:
    python test_endpoint.py                                    # localhost:8000
    python test_endpoint.py https://INSTANCE-8000.proxy.vast.ai
    python test_endpoint.py http://localhost:8000 sk-xxx       # with API key
"""

import sys
import json
import urllib.request
import urllib.error

def test_endpoint(base_url: str, api_key: str = "not-needed"):
    base_url = base_url.rstrip("/")
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}",
    }

    # ── Test 1: Health ──
    print(f"Testing: {base_url}")
    print("─" * 50)

    try:
        req = urllib.request.Request(f"{base_url}/health")
        urllib.request.urlopen(req, timeout=10)
        print("✓ /health — OK")
    except Exception as e:
        print(f"✗ /health — {e}")
        return False

    # ── Test 2: List models ──
    try:
        req = urllib.request.Request(f"{base_url}/v1/models", headers=headers)
        resp = urllib.request.urlopen(req, timeout=10)
        data = json.loads(resp.read())
        models = [m["id"] for m in data.get("data", [])]
        print(f"✓ /v1/models — Loaded: {models}")
    except Exception as e:
        print(f"✗ /v1/models — {e}")
        return False

    # ── Test 3: Chat completion ──
    try:
        payload = json.dumps({
            "model": models[0],
            "messages": [
                {"role": "user", "content": "Say 'hello' in one word."}
            ],
            "max_tokens": 32,
            "temperature": 0.1,
        }).encode()

        req = urllib.request.Request(
            f"{base_url}/v1/chat/completions",
            data=payload,
            headers=headers,
            method="POST",
        )
        resp = urllib.request.urlopen(req, timeout=60)
        data = json.loads(resp.read())

        reply = data["choices"][0]["message"]["content"]
        usage = data.get("usage", {})
        print(f"✓ /v1/chat/completions")
        print(f"  Reply: {reply.strip()[:100]}")
        print(f"  Tokens: prompt={usage.get('prompt_tokens')}, "
              f"completion={usage.get('completion_tokens')}")
    except Exception as e:
        print(f"✗ /v1/chat/completions — {e}")
        return False

    print("─" * 50)
    print("All tests passed!")
    return True


if __name__ == "__main__":
    url = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000"
    key = sys.argv[2] if len(sys.argv) > 2 else "not-needed"
    success = test_endpoint(url, key)
    sys.exit(0 if success else 1)
