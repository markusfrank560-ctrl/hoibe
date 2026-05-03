"""Extract key frames from video clips."""

from __future__ import annotations

import base64
from pathlib import Path

import cv2
import numpy as np

from src.schemas import FrameData


def extract_frames(
    video_path: Path,
    num_frames: int = 4,
    window: tuple[float, float] | None = None,
    max_width: int = 512,
    jpeg_quality: int = 70,
) -> FrameData:
    """Extract equally-spaced frames from a video clip.

    Args:
        video_path: Path to the video file (MP4/H.264).
        num_frames: Number of frames to extract (default: 4).
        window: Optional (start, end) as fractions 0.0–1.0 of clip duration.
                If None, samples from the full clip (excluding very start/end).

    Returns:
        FrameData with base64-encoded JPEG frames.

    Raises:
        FileNotFoundError: If video file does not exist.
        ValueError: If video cannot be opened or has no frames.
    """
    video_path = Path(video_path)
    if not video_path.exists():
        raise FileNotFoundError(f"Video not found: {video_path}")

    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        raise ValueError(f"Cannot open video: {video_path}")

    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS)

    if total_frames <= 0 or fps <= 0:
        cap.release()
        raise ValueError(f"Invalid video (frames={total_frames}, fps={fps}): {video_path}")

    duration = total_frames / fps

    # Calculate equally-spaced frame positions within the window
    if window:
        start_frame = int(total_frames * window[0])
        end_frame = int(total_frames * window[1])
    else:
        start_frame = 0
        end_frame = total_frames

    window_length = end_frame - start_frame
    if num_frames == 1:
        frame_indices = [start_frame + window_length // 2]
    else:
        frame_indices = [
            int(start_frame + i * (window_length - 1) / (num_frames - 1))
            for i in range(num_frames)
        ]

    frames_base64: list[str] = []
    timestamps: list[float] = []

    for idx in frame_indices:
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ret, frame = cap.read()
        if not ret:
            continue

        # Downscale if wider than max_width to reduce token count
        h, w = frame.shape[:2]
        if w > max_width:
            new_h = int(h * max_width / w)
            frame = cv2.resize(frame, (max_width, new_h), interpolation=cv2.INTER_AREA)

        # Encode frame as JPEG then base64
        _, buffer = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, jpeg_quality])
        b64 = base64.b64encode(buffer.tobytes()).decode("utf-8")
        frames_base64.append(b64)
        timestamps.append(idx / fps)

    cap.release()

    if not frames_base64:
        raise ValueError(f"Could not extract any frames from: {video_path}")

    return FrameData(
        frames_base64=frames_base64,
        source_path=video_path,
        total_duration_seconds=duration,
        frame_timestamps=timestamps,
    )
