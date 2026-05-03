"""Tests for CLI wiring."""

from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import patch

from click.testing import CliRunner

from src.cli import main
from src.schemas import AnalysisResult


def _fake_result(first_sip_detected: bool = True) -> AnalysisResult:
    return AnalysisResult(
        first_sip_detected=first_sip_detected,
        confidence=0.95,
        face_visible=True,
        drinking_object_visible=True,
        mouth_contact_likely=True,
        beer_likely="true",
        reason_short="stub result",
        model_name="qwen3-vl:4b",
        analysis_version="v2",
    )


def test_check_passes_sliding_window_options(tmp_path: Path):
    video_path = tmp_path / "clip.mp4"
    video_path.write_bytes(b"")
    captured: dict[str, object] = {}

    async def fake_analyze(video: Path, config, hoibe_cfg=None):
        captured["video"] = video
        captured["config"] = config
        return _fake_result()

    runner = CliRunner()
    with patch("src.cli.analyze_clip_sliding", new=fake_analyze):
        result = runner.invoke(
            main,
            [
                "check",
                str(video_path),
                "--sliding",
                "--sliding-window-count",
                "2",
                "--sliding-window-min-span",
                "0.7",
            ],
        )

    assert result.exit_code == 0, result.output
    payload = json.loads(result.output)
    assert payload["first_sip_detected"] is True
    config = captured["config"]
    assert config.sliding_window_count == 2
    assert config.sliding_window_min_span == 0.7
    assert captured["video"] == video_path


def test_analyze_sliding_writes_default_output(tmp_path: Path):
    video_path = tmp_path / "clip.mp4"
    video_path.write_bytes(b"")

    async def fake_analyze(video: Path, config, hoibe_cfg=None):
        return _fake_result(first_sip_detected=False)

    runner = CliRunner()
    with patch("src.cli.analyze_clip_sliding", new=fake_analyze), patch(
        "src.cli.analyze_clip",
        side_effect=AssertionError("non-sliding path should not run"),
    ):
        result = runner.invoke(main, ["analyze", str(video_path), "--sliding"])

    assert result.exit_code == 0, result.output
    result_paths = list(tmp_path.glob("clip.result.*.json"))
    assert len(result_paths) == 1
    payload = json.loads(result_paths[0].read_text())
    assert payload["first_sip_detected"] is False


def test_analyze_writes_latest_alias_when_requested(tmp_path: Path):
    video_path = tmp_path / "clip.mp4"
    video_path.write_bytes(b"")

    async def fake_analyze(video: Path, config):
        return _fake_result(first_sip_detected=True)

    runner = CliRunner()
    with patch("src.cli.analyze_clip", new=fake_analyze):
        result = runner.invoke(main, ["analyze", str(video_path), "--latest"])

    assert result.exit_code == 0, result.output
    timestamped_paths = list(tmp_path.glob("clip.result.*.json"))
    latest_path = tmp_path / "clip.result.latest.json"
    assert len(timestamped_paths) == 2
    assert latest_path.exists()
    payload = json.loads(latest_path.read_text())
    assert payload["first_sip_detected"] is True