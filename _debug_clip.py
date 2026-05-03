import asyncio
import ollama
from pathlib import Path
from src.frame_extractor import extract_frames
from src.prompt_engine import build_messages, load_prompt_template
from src.schemas import AnalysisConfig

async def test():
    config = AnalysisConfig(model_name='qwen3-vl:4b', num_frames=2, temperature=0.0, analysis_version='v2')
    frames = extract_frames(Path('tests/fixtures/videos/positive_first-sip_003_2026-05-02.mp4'), num_frames=2)
    messages = build_messages(frames, config)
    
    client = ollama.AsyncClient()
    response = await client.chat(
        model='qwen3-vl:4b',
        messages=messages,
        options={"temperature": 0.0, "num_ctx": 16384},
        think=True,
    )
    msg = response["message"]
    print("KEYS:", list(msg.keys()))
    print("CONTENT repr:", repr(msg.get("content", "")[:500]))
    print("THINKING repr:", repr(str(msg.get("thinking", ""))[:500]))
    print("ROLE:", msg.get("role"))

asyncio.run(test())
