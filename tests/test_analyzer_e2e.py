"""Live end-to-end tests for the analyzer pipeline.

These tests run against a real Ollama instance and the real fixture videos.
They are opt-in via --run-e2e or --e2e-case.
"""

from __future__ import annotations

import asyncio
import json
from datetime import datetime, timezone
from functools import lru_cache
from urllib.error import URLError
from urllib.request import urlopen

import pytest

from src.analyzer import analyze_clip, analyze_clip_sliding
from src.config import load_config
from src.ollama_client import ISOLATION_COOLDOWN, unload_model
from src.schemas import AnalysisConfig

from .conftest import GoldenFixture

pytestmark = pytest.mark.e2e


@pytest.fixture(autouse=True)
async def _isolate_ollama_between_cases(request: pytest.FixtureRequest):
    """Unload model after each e2e case for consistent timing.

    Active when --e2e-isolate is passed or --e2e-full-config is set.
    """
    yield
    isolate = request.config.getoption("--e2e-isolate") or request.config.getoption("--e2e-full-config")
    if not isolate:
        return
    hoibe_cfg = load_config()
    host = hoibe_cfg.defaults.ollama_host
    model = hoibe_cfg.windows.model
    cooldown = request.config.getoption("--e2e-cooldown")
    if cooldown is None:
        cooldown = ISOLATION_COOLDOWN
    await unload_model(host, model)
    await asyncio.sleep(cooldown)


@lru_cache(maxsize=None)
def _available_ollama_models(host: str) -> set[str]:
    tags_url = f"{host.rstrip('/')}/api/tags"
    with urlopen(tags_url, timeout=3) as response:
        payload = json.load(response)
    models = payload.get("models", [])
    names: set[str] = set()
    for model in models:
        for key in ("model", "name"):
            value = model.get(key)
            if value:
                names.add(value)
    return names


def _require_live_ollama(host: str, model_name: str) -> None:
    try:
        available_models = _available_ollama_models(host)
    except URLError as error:
        pytest.skip(f"Live Ollama is unavailable at {host}: {error.reason}")

    if model_name not in available_models:
        available_list = ", ".join(sorted(available_models)) or "<none>"
        pytest.skip(
            f"Required Ollama model '{model_name}' is not installed. Available: {available_list}"
        )


@pytest.mark.asyncio
async def test_golden_fixture_live_detection(
    golden_fixture: GoldenFixture,
    request: pytest.FixtureRequest,
):
    hoibe_cfg = load_config()
    use_full_config = request.config.getoption("--e2e-full-config")

    if use_full_config:
        use_sliding = True
    else:
        use_sliding = False

    # Build AnalysisConfig from YAML (windows stage settings as baseline)
    win = hoibe_cfg.windows
    config = AnalysisConfig(
        model_name=win.model,
        num_frames=win.num_frames if use_full_config else min(win.num_frames, 2),
        confidence_threshold=hoibe_cfg.pipeline.confidence_threshold,
        temperature=win.temperature,
        ollama_host=hoibe_cfg.defaults.ollama_host,
        analysis_version=hoibe_cfg.pipeline.analysis_version,
        sliding_window_min_span=win.min_span,
        sliding_window_count=win.count,
        num_ctx=win.num_ctx,
        max_width=win.max_width,
        jpeg_quality=win.jpeg_quality,
        think=win.think,
    )

    _require_live_ollama(config.ollama_host, config.model_name)

    if use_sliding:
        result = await analyze_clip_sliding(golden_fixture.video_path, config, hoibe_cfg)
    else:
        result = await analyze_clip(golden_fixture.video_path, config)

    assert result.first_sip_detected is golden_fixture.ground_truth, (
        f"Expected {golden_fixture.ground_truth} for {golden_fixture.name}, "
        f"got {result.first_sip_detected} with confidence={result.confidence}"
    )
    assert 0.0 <= result.confidence <= 1.0
    assert result.model_name == config.model_name
    assert result.analysis_version == config.analysis_version
    assert result.analyzed_at is not None
    assert result.source_video == str(golden_fixture.video_path)
    if use_sliding:
        assert result.run_config["mode"] in ("sliding", "sliding_precheck")
    else:
        assert result.run_config["mode"] == "full_clip"

    # Update fixture with e2e pass timestamp and reasoning for traceability
    _update_fixture_on_pass(golden_fixture, result, use_full_config)


def _update_fixture_on_pass(
    fixture: GoldenFixture, result, use_full_config: bool
) -> None:
    """Write last_run data into the fixture file on successful e2e pass."""
    from pathlib import Path

    results_dir = Path(__file__).parent / "fixtures" / "results"
    fixture_path = results_dir / f"{fixture.name}.result.json"
    if not fixture_path.exists():
        return

    data = json.loads(fixture_path.read_text())
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    data["last_run"] = {
        "passed": True,
        "timestamp": now,
        "mode": "full_config" if use_full_config else "smoke",
        "confidence": result.confidence,
        "first_sip_detected": result.first_sip_detected,
        "reasoning": result.reasoning,
        "reason_short": result.reason_short if hasattr(result, "reason_short") else None,
    }
    fixture_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")