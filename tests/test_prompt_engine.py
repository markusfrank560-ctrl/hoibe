"""Tests for prompt_engine module."""

from pathlib import Path

from src.prompt_engine import build_messages, load_prompt_template
from src.schemas import AnalysisConfig, FrameData


def test_load_prompt_template_from_text_files():
    template = load_prompt_template("v2")

    assert template["analysis_version"] == "v2"
    assert "precision drink detection system" in template["system_prompt"]
    assert "{num_frames}" in template["user_prompt_template"]


def test_build_messages_formats_timestamps_and_images():
    frame_data = FrameData(
        frames_base64=["image-1", "image-2"],
        source_path=Path("clip.mp4"),
        total_duration_seconds=4.0,
        frame_timestamps=[1.3, 2.7],
    )
    config = AnalysisConfig(analysis_version="v2")

    messages = build_messages(frame_data, config)

    assert messages[0]["role"] == "system"
    assert "Frame 1 at 1.3s, Frame 2 at 2.7s" in messages[1]["content"]
    assert messages[1]["images"] == ["image-1", "image-2"]