"""Tests for frame_extractor module."""

from pathlib import Path

import cv2
import numpy as np
import pytest

from src.frame_extractor import extract_frames


@pytest.fixture
def sample_video(tmp_path: Path) -> Path:
    """Create a minimal test video (10 frames, 10fps = 1 second)."""
    video_path = tmp_path / "test_clip.mp4"
    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    writer = cv2.VideoWriter(str(video_path), fourcc, 10.0, (320, 240))

    for i in range(10):
        frame = np.zeros((240, 320, 3), dtype=np.uint8)
        frame[:, :, 0] = i * 25  # varying blue channel
        writer.write(frame)

    writer.release()
    return video_path


def test_extract_frames_default(sample_video: Path):
    result = extract_frames(sample_video, num_frames=4)
    assert len(result.frames_base64) == 4
    assert len(result.frame_timestamps) == 4
    assert result.source_path == sample_video
    assert result.total_duration_seconds == pytest.approx(1.0, abs=0.2)


def test_extract_frames_single(sample_video: Path):
    result = extract_frames(sample_video, num_frames=1)
    assert len(result.frames_base64) == 1


def test_extract_frames_file_not_found():
    with pytest.raises(FileNotFoundError):
        extract_frames(Path("/nonexistent/video.mp4"))


def test_extract_frames_invalid_file(tmp_path: Path):
    bad_file = tmp_path / "bad.mp4"
    bad_file.write_text("not a video")
    with pytest.raises(ValueError):
        extract_frames(bad_file)


def test_frames_are_valid_base64(sample_video: Path):
    import base64

    result = extract_frames(sample_video, num_frames=2)
    for b64 in result.frames_base64:
        decoded = base64.b64decode(b64)
        assert len(decoded) > 0
