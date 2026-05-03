"""Quick probe to test call_ollama on the new fixture clip."""
import asyncio
import os
import time
from pathlib import Path

import ollama

from src.frame_extractor import extract_frames
from src.prompt_engine import build_messages
from src.schemas import AnalysisConfig

# Bypass proxy for localhost
os.environ["NO_PROXY"] = "localhost,127.0.0.1"
os.environ["no_proxy"] = "localhost,127.0.0.1"


async def test():
    config = AnalysisConfig(
        model_name="qwen3-vl:4b",
        num_frames=2,
        temperature=0.0,
        analysis_version="v2",
    )
    frames = extract_frames(
        Path("tests/fixtures/videos/positive_first-sip_003_2026-05-02.mp4"),
        num_frames=2,
        window=(0.0, 0.6),
    )
    messages = build_messages(frames, config)
    print(f"Frames: {len(frames.frames_base64)}")
    print(f"Payload sizes (chars): {[len(f) for f in frames.frames_base64]}")

    # Direct call bypassing our wrapper to test raw behavior
    client = ollama.AsyncClient(host="http://localhost:11434")
    start = time.perf_counter()
    try:
        response = await asyncio.wait_for(
            client.chat(
                model="qwen3-vl:4b",
                messages=messages,
                options={"temperature": 0.0, "num_ctx": 16384},
            ),
            timeout=120,
        )
        elapsed = time.perf_counter() - start
        msg = response["message"]
        content = msg.get("content", "")
        thinking = msg.get("thinking", "")
        print(f"Elapsed: {elapsed:.1f}s")
        print(f"Content ({len(content)} chars): {repr(content[:500])}")
        print(f"Thinking ({len(thinking)} chars): {repr(thinking[:2000])}")
        print(f"---END THINKING SNIPPET---")
    except asyncio.TimeoutError:
        elapsed = time.perf_counter() - start
        print(f"TIMEOUT after {elapsed:.1f}s")
    except Exception as e:
        elapsed = time.perf_counter() - start
        print(f"FAILED after {elapsed:.1f}s: {type(e).__name__}: {e}")


asyncio.run(test())
