---
description: "Operational gotchas and workarounds for running qwen3-vl models via Ollama locally. Use when debugging timeouts, empty responses, infinite thinking loops, or performance issues with qwen3-vl on Ollama."
applyTo: "src/ollama_client.py,src/analyzer.py,src/schemas.py,tests/**"
---

# Ollama qwen3-vl Gotchas

Hard-won lessons from running qwen3-vl:4b locally via Ollama 0.6.x for vision tasks with structured output.

## Optimized Config (qwen3-vl:4b)

These values were validated on 5 fixtures (3 positive, 2 negative) achieving 4/5 correct with the full sliding-window pipeline:

```python
AnalysisConfig(
    model_name="qwen3-vl:4b",
    num_frames=2,                   # 2 frames per window — sweet spot for speed/accuracy
    temperature=0.3,                # MUST be >0; 0.0 causes infinite think loop
    analysis_version="v2",
    sliding_window_count=3,         # 3 overlapping windows across clip
    sliding_window_min_span=0.6,    # each window covers 60% of clip
    fill_level_votes=1,             # single gate vote (fast; gate accuracy is high)
    confidence_threshold=0.7,
)
```

### Pipeline architecture
1. **Gate** — single fill-level check on sharpest frame from first 10% of clip. Uses `call_ollama_light`. If fill ∈ {mostly_empty, empty} → reject immediately.
2. **Sliding windows** — 3 overlapping windows, each with 2 frames, using `call_ollama` (full structured v2 prompt with thinking).
3. **Early exit** — first window with `first_sip_detected=True` AND `fill=full` → return positive.
4. **Downgrade** — if sip detected but fill ≠ full → set `first_sip_detected=False` (subsequent sip, not first).

### Frame extraction
- Max width: 512px (downscaled via `cv2.resize`)
- JPEG quality: 70
- Sharpest-frame selection for gate (Laplacian variance)

### Ollama call params
- `num_ctx=16384` — both gate and window calls
- `temperature=0.3` — both gate and window calls
- No `think` param, no `num_predict` — let model think freely
- `_CALL_TIMEOUT=300s`, `_CALL_LIGHT_TIMEOUT=60s`
- Strip `<think>...</think>` from response via regex before JSON parse

### Accuracy (2026-05-03, 5 fixtures)
| Fixture | Result | Time |
|---------|--------|------|
| positive_first-sip_001 | PASS | ~53s |
| positive_first-sip_002 | PASS | ~53s |
| positive_first-sip_003 | PASS (sometimes timeout) | ~53-90s |
| negative_no-sip_001 | FAIL (false positive) | ~75s |
| negative_sip-not-first_001 | PASS (sometimes timeout) | ~75s |

## Critical Pitfalls

### temperature=0.0 causes infinite thinking loop

qwen3-vl with thinking mode enabled **never stops generating** at temperature 0.
The model loops on `<think>` tokens indefinitely, consuming GPU until the context window or timeout is hit.

**Fix:** Use `temperature ≥ 0.3`.

### num_predict caps thinking + content combined

`num_predict` limits ALL output tokens — both thinking and content.
The model exhausts its budget on thinking and returns empty content.

**Fix:** Do not use `num_predict` to limit thinking. Let the model finish naturally.

### think=False produces empty content on complex prompts

With multi-image prompts and structured output instructions, setting `think=False` causes qwen3-vl to return empty `content`. Works fine for simple single-image prompts.

**Fix:** Avoid `think=False` for complex vision prompts. Instead, let the model think and strip `<think>...</think>` tags from the response via regex.

## Performance

| Scenario | Approximate Time |
|----------|-----------------|
| Cold start (2 images + structured prompt) | >90 s |
| Warm inference (2 images + structured prompt) | ~75 s |
| Gate call (1 image, light prompt) | ~15 s |
| Typical output size | ~16k chars thinking + ~800 chars content |

- **Warmup strategy:** The gate call (single image, simple prompt) warms the model before expensive multi-image window calls. No unload between windows.
- **Frame size:** Downscale to max 512px width, JPEG quality 70. Larger frames add inference time without improving accuracy.
- **Total pipeline time (warm):** Gate (~15s) + 3 windows (~75s each) ≈ 4–5 min worst case. Early exit can cut to ~90s.

## Operational Issues

### Killed terminals leave Ollama stuck

When a terminal is killed mid-inference, Ollama continues processing the request internally.
New requests queue behind the stuck one, appearing to hang.

**Fix:**
```bash
pkill -9 -f "ollama"
sleep 5          # auto-restarts via launchd on macOS
```

### NO_PROXY required for localhost

Ollama runs on `localhost:11434`. Python's `httpx`/`aiohttp` may route through a corporate proxy unless bypassed.

**Fix:** Set at module level AND as environment variable:
```python
import os
os.environ.setdefault("NO_PROXY", "localhost,127.0.0.1")
os.environ.setdefault("no_proxy", "localhost,127.0.0.1")
```

For tests, also export before pytest:
```bash
export NO_PROXY=localhost,127.0.0.1
export no_proxy=localhost,127.0.0.1
```

## Response Handling

- Access response via `response["message"]["content"]` (dict access, not attribute).
- Thinking content lives in `response["message"]["thinking"]` (when available).
- Always strip `<think>...</think>` blocks from content with regex before parsing JSON.
- Use `num_ctx=16384` to give the model enough context for 2 images + structured prompt + thinking.
