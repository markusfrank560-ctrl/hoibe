---
description: "Operational gotchas and workarounds for running qwen3-vl models via Ollama locally. Use when debugging timeouts, empty responses, infinite thinking loops, or performance issues with qwen3-vl on Ollama."
applyTo: "src/ollama_client.py,src/analyzer.py,src/schemas.py,tests/**"
---

# Ollama qwen3-vl Gotchas

Hard-won lessons from running qwen3-vl:4b locally via Ollama 0.6.x for vision tasks with structured output.

## Optimized Config (qwen3-vl:4b)

These values were validated on 5 fixtures (3 positive, 2 negative) achieving **5/5 correct**.
Config is now externalized into `hoibe.yaml` — not hardcoded in Python.

```yaml
# hoibe.yaml (as of 2026-05-03)
gate:
  max_width: 1024
  jpeg_quality: 70
  num_frames: 4       # 4 frames → 3-vote majority, tolerates 1 bad frame
  num_ctx: 4096
  temperature: 0.1
  think: false
  votes: 3            # majority of 3 out of 4 frames
  reject_levels: [half, mostly_empty, empty]

windows:
  max_width: 1024     # higher res eliminates false positives (512px was insufficient)
  jpeg_quality: 90    # less compression = better visual detail for edge cases
  num_frames: 2
  num_ctx: 16384
  temperature: 0.1
  think: false
  count: 3
  min_span: 0.6

pipeline:
  stage_cooldown: 15.0       # seconds to sleep between every inference call
  unload_between_calls: true # unload model from GPU between calls
```

### Pipeline architecture
1. **Gate** (`gate.enabled: true`) — fill-level majority vote on first 10% of clip. 4 frames sampled, sharpest 3 used for voting. If majority fill ∈ {half, mostly_empty, empty} → reject immediately. Gate can be disabled via `gate.enabled: false`.
2. **Cooldown** — `unload_model()` + `asyncio.sleep(15s)` between every inference call (gate→window1, window1→window2, etc.) for clean KV cache and thermal recovery.
3. **Sliding windows** — 3 overlapping windows, each with 2 frames at 1024px/quality 90, using `call_ollama` with `think=false`.
4. **Early exit** — first window with `first_sip_detected=True` AND `fill=full` → return positive immediately.
5. **Downgrade** — if sip detected but fill ≠ full → set `first_sip_detected=False` (subsequent sip, not first).

### Frame extraction
- Gate: max width 1024px, JPEG quality 70, 4 frames sampled, sharpest-frame selection (Laplacian variance)
- Windows: max width 1024px, JPEG quality 90 (higher quality critical for edge-case accuracy)
- 512px / quality 70 for windows caused false positives on near-mouth-but-not-drinking clips

### Ollama call params
- Gate: `num_ctx=4096`, `temperature=0.1`, `think=false`, timeout 60s
- Windows: `num_ctx=16384`, `temperature=0.1`, `think=false`, timeout 300s
- `_CALL_TIMEOUT=300s`, `_CALL_LIGHT_TIMEOUT=60s`
- Strip `<think>...</think>` from response via regex before JSON parse
- `think=false` works correctly at 1024px resolution; was unreliable at 512px

### Accuracy (2026-05-03, 5 fixtures, current config)
| Fixture | Result | Time | Notes |
|---------|--------|------|-------|
| positive_first-sip_001 | ✅ PASS | ~1:58 | Gate majority 2/3 full |
| positive_first-sip_002 | ✅ PASS | ~1:41 | Gate unanimous full |
| positive_first-sip_003 | ✅ PASS | ~1:52 | Gate unanimous full |
| negative_no-sip_001 | ✅ PASS | ~1:52 | All 3 windows conf ≤ 0.10 |
| negative_sip-not-first_001 | ✅ PASS | ~1:12 | Gate rejected (majority half) |

## Critical Pitfalls

### temperature=0.0 causes infinite thinking loop

qwen3-vl with thinking mode enabled **never stops generating** at temperature 0.
The model loops on `<think>` tokens indefinitely, consuming GPU until the context window or timeout is hit.

**Fix:** Use `temperature ≥ 0.3`.

### num_predict caps thinking + content combined

`num_predict` limits ALL output tokens — both thinking and content.
The model exhausts its budget on thinking and returns empty content.

**Fix:** Do not use `num_predict` to limit thinking. Let the model finish naturally.

### think=False at low resolution produces empty content

With multi-image prompts and 512px frames, `think=False` causes qwen3-vl to return empty `content`.
At 1024px / JPEG quality 90, `think=False` works correctly for both gate and window calls.

**Fix:** Use `max_width=1024` and `jpeg_quality ≥ 90` when running `think=false` on complex vision prompts.

## Performance

| Scenario | Approximate Time |
|----------|-----------------|
| Gate (4 frames, 3 votes, 15s cooldowns) | ~45–60s |
| Window call (2 frames, 1024px, think=false) | ~25–35s |
| Inter-call cooldown (unload + sleep) | 15s fixed |
| Total pipeline, early exit (1 window) | ~1:40 |
| Total pipeline, all 3 windows | ~1:50–2:00 |
| Typical output size (think=false) | ~800 chars content |

- **Cooldown strategy:** Unload model + 15s sleep between every inference call. Eliminates KV cache pollution and reduces thermal throttling.
- **Frame size:** 1024px width, JPEG quality 90 for windows. Lower resolution (512px) caused false positives on near-mouth clips.
- **Gate early exit:** Clips with half/mostly_empty/empty glass exit after gate (~1:12) without running any windows.

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

**Fix:** Add a `.env` file in the project root and use `pytest-dotenv` (add to dev deps, set `env_files = [".env"]` in `[tool.pytest.ini_options]`):
```
# .env
NO_PROXY=localhost,127.0.0.1
no_proxy=localhost,127.0.0.1
```
Loaded automatically before every pytest run. No need to export manually.

## Response Handling

- Access response via `response["message"]["content"]` (dict access, not attribute).
- Thinking content lives in `response["message"]["thinking"]` (when available).
- Always strip `<think>...</think>` blocks from content with regex before parsing JSON.
- Use `num_ctx=16384` to give the model enough context for 2 images + structured prompt + thinking.
