"""Build prompts for Ollama VLM calls."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from src.schemas import AnalysisConfig, FrameData

PROMPTS_DIR = Path(__file__).parent.parent / "prompts"
PROMPT_FILENAMES = {
    "system_prompt": "system_prompt.txt",
    "user_prompt_template": "user_prompt_template.txt",
}


def load_prompt_template(version: str = "v1") -> dict[str, str]:
    """Load prompt template from versioned text files.

    Args:
        version: Prompt version directory name.

    Returns:
        Dict with 'system_prompt', 'user_prompt_template', 'analysis_version'.

    Raises:
        FileNotFoundError: If prompt files do not exist.
    """
    version_dir = PROMPTS_DIR / version
    if not version_dir.exists():
        raise FileNotFoundError(f"Prompt template directory not found: {version_dir}")

    data = {"analysis_version": version}
    for key, filename in PROMPT_FILENAMES.items():
        prompt_path = version_dir / filename
        if not prompt_path.exists():
            raise FileNotFoundError(f"Prompt file not found: {prompt_path}")
        data[key] = prompt_path.read_text(encoding="utf-8").rstrip("\n")

    return data


def build_messages(
    frame_data: FrameData, config: AnalysisConfig
) -> list[dict[str, Any]]:
    """Build Ollama chat messages with images.

    Args:
        frame_data: Extracted frames from video.
        config: Analysis configuration.

    Returns:
        List of message dicts for Ollama chat API.
    """
    template = load_prompt_template(config.analysis_version)

    # Format frame timestamps for temporal reasoning
    timestamp_lines = ", ".join(
        f"Frame {i+1} at {t:.1f}s"
        for i, t in enumerate(frame_data.frame_timestamps)
    )

    user_prompt = template["user_prompt_template"].replace(
        "{num_frames}", str(len(frame_data.frames_base64))
    ).replace(
        "{frame_timestamps}", timestamp_lines
    )

    messages = [
        {"role": "system", "content": template["system_prompt"]},
        {
            "role": "user",
            "content": user_prompt,
            "images": frame_data.frames_base64,
        },
    ]

    return messages


def build_fill_level_messages(
    frame_base64: str, config: AnalysisConfig
) -> list[dict[str, Any]]:
    """Build messages for a single-frame fill-level check.

    Uses a dedicated, focused prompt that asks only about fill level.

    Args:
        frame_base64: Single base64-encoded frame.
        config: Analysis configuration (for version directory).

    Returns:
        List of message dicts for Ollama chat API.
    """
    version_dir = PROMPTS_DIR / config.analysis_version
    prompt_path = version_dir / "fill_level_prompt.txt"
    if not prompt_path.exists():
        raise FileNotFoundError(f"Fill level prompt not found: {prompt_path}")

    prompt_text = prompt_path.read_text(encoding="utf-8").rstrip("\n")

    return [
        {
            "role": "user",
            "content": prompt_text,
            "images": [frame_base64],
        },
    ]
