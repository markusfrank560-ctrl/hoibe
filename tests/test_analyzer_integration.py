"""Integration tests for the analyzer pipeline.

Data-driven: auto-discovers all golden fixtures from tests/fixtures/results/.
Each .result.json is a test case with expected ground_truth.
"""

from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import AsyncMock, patch

import cv2
import numpy as np
import pytest

from src.analyzer import analyze_clip, _is_definitive_negative, _parse_fill_level
from src.config import load_config
from src.schemas import AnalysisConfig, AnalysisResult, BeerFillLevel, BeerLikely

from .conftest import GoldenFixture

pytestmark = pytest.mark.integration


@pytest.fixture
def sample_video(tmp_path: Path) -> Path:
    """Create a minimal test video (10s at 10fps)."""
    video_path = tmp_path / "test_clip.mp4"
    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    writer = cv2.VideoWriter(str(video_path), fourcc, 10.0, (320, 240))
    for _ in range(100):
        frame = np.random.randint(0, 255, (240, 320, 3), dtype=np.uint8)
        writer.write(frame)
    writer.release()
    return video_path


# ---------------------------------------------------------------------------
# Data-driven tests: one test per golden fixture, auto-parametrized
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_golden_fixture_detection(sample_video: Path, golden_fixture: GoldenFixture):
    """Validate that the pipeline returns the expected ground truth for each fixture.

    Uses the golden fixture's expected_response as the mocked Ollama output,
    then asserts the parsed result matches ground_truth.
    """
    mock_ollama_output = json.dumps(golden_fixture.mock_response)
    hoibe_cfg = load_config()
    config = AnalysisConfig(
        model_name=hoibe_cfg.windows.model,
        num_frames=hoibe_cfg.windows.num_frames,
        temperature=hoibe_cfg.windows.temperature,
        analysis_version=hoibe_cfg.pipeline.analysis_version,
        ollama_host=hoibe_cfg.defaults.ollama_host,
    )

    with patch("src.ollama_client.ollama.AsyncClient") as MockClient:
        instance = MockClient.return_value
        instance.chat = AsyncMock(
            return_value={"message": {"content": mock_ollama_output}}
        )
        result = await analyze_clip(sample_video, config)

    assert result.first_sip_detected is golden_fixture.ground_truth, (
        f"Expected {golden_fixture.ground_truth} for {golden_fixture.name}, "
        f"got {result.first_sip_detected} (confidence={result.confidence})"
    )
    assert result.model_name == hoibe_cfg.windows.model
    assert result.analysis_version == hoibe_cfg.pipeline.analysis_version
    assert result.analyzed_at is not None
    assert result.source_video == str(sample_video)


@pytest.mark.asyncio
async def test_golden_fixture_confidence_range(sample_video: Path, golden_fixture: GoldenFixture):
    """Confidence must be within [0, 1] and match the golden file."""
    mock_ollama_output = json.dumps(golden_fixture.mock_response)
    config = AnalysisConfig()

    with patch("src.ollama_client.ollama.AsyncClient") as MockClient:
        instance = MockClient.return_value
        instance.chat = AsyncMock(
            return_value={"message": {"content": mock_ollama_output}}
        )
        result = await analyze_clip(sample_video, config)

    assert 0.0 <= result.confidence <= 1.0
    assert result.confidence == golden_fixture.mock_response["confidence"]


@pytest.mark.asyncio
async def test_golden_fixture_diagnostics(sample_video: Path, golden_fixture: GoldenFixture):
    """Diagnostic fields must match the golden fixture exactly."""
    mock_ollama_output = json.dumps(golden_fixture.mock_response)
    config = AnalysisConfig()

    with patch("src.ollama_client.ollama.AsyncClient") as MockClient:
        instance = MockClient.return_value
        instance.chat = AsyncMock(
            return_value={"message": {"content": mock_ollama_output}}
        )
        result = await analyze_clip(sample_video, config)

    expected = golden_fixture.mock_response
    assert result.face_visible == expected["face_visible"]
    assert result.drinking_object_visible == expected["drinking_object_visible"]
    assert result.mouth_contact_likely == expected["mouth_contact_likely"]
    assert result.beer_likely.value == expected["beer_likely"]


# ---------------------------------------------------------------------------
# Unit tests for _is_definitive_negative
# ---------------------------------------------------------------------------

def _make_result(**kwargs) -> AnalysisResult:
    defaults = dict(
        first_sip_detected=False,
        confidence=0.8,
        face_visible=True,
        drinking_object_visible=True,
        mouth_contact_likely=True,
        beer_likely=BeerLikely.true,
        beer_fill_level=BeerFillLevel.unknown,
        reason_short="test",
        model_name="qwen3-vl:4b",
        analysis_version="v2",
    )
    defaults.update(kwargs)
    return AnalysisResult(**defaults)


@pytest.mark.parametrize("fill_level", [BeerFillLevel.mostly_empty, BeerFillLevel.empty, BeerFillLevel.half])
def test_definitive_negative_empty_glass(fill_level):
    result = _make_result(beer_fill_level=fill_level)
    assert _is_definitive_negative(result) is True


def test_definitive_negative_no_beer():
    result = _make_result(beer_likely=BeerLikely.false)
    assert _is_definitive_negative(result) is True


def test_definitive_negative_no_drinking_object():
    result = _make_result(drinking_object_visible=False)
    assert _is_definitive_negative(result) is True


def test_definitive_negative_no_face():
    result = _make_result(face_visible=False)
    assert _is_definitive_negative(result) is True


@pytest.mark.parametrize("fill_level", [BeerFillLevel.full, BeerFillLevel.mostly_full, BeerFillLevel.unknown])
def test_not_definitive_negative_full_glass(fill_level):
    result = _make_result(beer_fill_level=fill_level)
    assert _is_definitive_negative(result) is False


def test_not_definitive_negative_when_positive_detected():
    """A positive detection should never trigger early stop."""
    result = _make_result(first_sip_detected=True, beer_fill_level=BeerFillLevel.mostly_empty)
    assert _is_definitive_negative(result) is False


# ---------------------------------------------------------------------------
# Unit tests for _parse_fill_level
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("raw,expected", [
    ('{"beer_fill_level": "mostly_empty"}', BeerFillLevel.mostly_empty),
    ('{"beer_fill_level": "full"}', BeerFillLevel.full),
    ('{"beer_fill_level": "half"}', BeerFillLevel.half),
    ('{"beer_fill_level": "mostly_full"}', BeerFillLevel.mostly_full),
    ('{"beer_fill_level": "empty"}', BeerFillLevel.empty),
    ('{"beer_fill_level": "unknown"}', BeerFillLevel.unknown),
    # Fallback parsing from raw text
    ('The glass is mostly empty.', BeerFillLevel.mostly_empty),
    ('mostly_full', BeerFillLevel.mostly_full),
    ('It looks half full', BeerFillLevel.half),
    ('full to the brim', BeerFillLevel.full),
    ('completely empty', BeerFillLevel.empty),
    ('I cannot tell', BeerFillLevel.unknown),
    # Edge cases
    ('', BeerFillLevel.unknown),
    ('   ', BeerFillLevel.unknown),
])
def test_parse_fill_level(raw, expected):
    assert _parse_fill_level(raw) == expected
