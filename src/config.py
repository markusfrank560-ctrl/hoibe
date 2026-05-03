"""Load and validate pipeline configuration from hoibe.yaml."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml
from pydantic import BaseModel, Field


_DEFAULT_CONFIG_PATHS = [
    Path("hoibe.yaml"),
    Path("hoibe.yml"),
    Path.home() / ".config" / "hoibe" / "hoibe.yaml",
]


class GateConfig(BaseModel):
    """Configuration for the fill-level pre-check gate."""

    enabled: bool = True
    model: str = "qwen3-vl:4b"
    max_width: int = Field(default=1024, ge=128, le=4096)
    jpeg_quality: int = Field(default=70, ge=10, le=100)
    window: tuple[float, float] = (0.0, 0.10)
    num_frames: int = Field(default=2, ge=1, le=8)
    num_ctx: int = Field(default=4096, ge=1024)
    temperature: float = Field(default=0.1, ge=0.0, le=2.0)
    think: bool = False
    votes: int = Field(default=1, ge=1, le=5)
    reject_levels: list[str] = Field(
        default_factory=lambda: ["half", "mostly_empty", "empty"]
    )
    call_timeout: float = Field(default=60.0, ge=10.0, description="Per-vote inference timeout in seconds")


class WindowsConfig(BaseModel):
    """Configuration for the sliding window analysis stage."""

    model: str = "qwen3-vl:4b"
    max_width: int = Field(default=512, ge=128, le=4096)
    jpeg_quality: int = Field(default=70, ge=10, le=100)
    num_frames: int = Field(default=2, ge=1, le=16)
    num_ctx: int = Field(default=16384, ge=1024)
    temperature: float = Field(default=0.3, ge=0.0, le=2.0)
    think: bool = True
    count: int = Field(default=3, ge=1)
    min_span: float = Field(default=0.6, gt=0.0, le=1.0)
    call_timeout: float = Field(default=120.0, ge=10.0, description="Per-window inference timeout in seconds")
    prompt_version: str = Field(default="v2", description="Prompt version directory to use")


class PipelineConfig(BaseModel):
    """Configuration for the analysis pipeline metadata."""

    analysis_version: str = "v2"
    confidence_threshold: float = Field(default=0.7, ge=0.0, le=1.0)
    stage_cooldown: float = Field(default=2.0, ge=0.0, le=30.0)
    unload_between_calls: bool = True


class DefaultsConfig(BaseModel):
    """Shared defaults."""

    ollama_host: str = "http://localhost:11434"


class HoibeConfig(BaseModel):
    """Top-level configuration loaded from hoibe.yaml."""

    pipeline: PipelineConfig = Field(default_factory=PipelineConfig)
    gate: GateConfig = Field(default_factory=GateConfig)
    windows: WindowsConfig = Field(default_factory=WindowsConfig)
    defaults: DefaultsConfig = Field(default_factory=DefaultsConfig)


def load_config(config_path: Path | str | None = None) -> HoibeConfig:
    """Load configuration from a YAML file.

    Search order:
    1. Explicit path (if given)
    2. hoibe.yaml in current directory
    3. hoibe.yml in current directory
    4. ~/.config/hoibe/hoibe.yaml

    Returns HoibeConfig with defaults if no file is found.
    """
    if config_path is not None:
        path = Path(config_path)
        if not path.exists():
            raise FileNotFoundError(f"Config file not found: {path}")
        return _parse_file(path)

    for path in _DEFAULT_CONFIG_PATHS:
        if path.exists():
            return _parse_file(path)

    # No config file found — use defaults
    return HoibeConfig()


def _parse_file(path: Path) -> HoibeConfig:
    """Parse and validate a YAML config file."""
    raw = path.read_text(encoding="utf-8")
    data: dict[str, Any] = yaml.safe_load(raw) or {}
    return HoibeConfig.model_validate(data)
