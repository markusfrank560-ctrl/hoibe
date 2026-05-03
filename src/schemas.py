"""Pydantic schemas for analysis results and configuration."""

from __future__ import annotations

from enum import Enum
from pathlib import Path
from typing import Any

from pydantic import BaseModel, Field


class BeerLikely(str, Enum):
    true = "true"
    false = "false"
    unknown = "unknown"


class BeerFillLevel(str, Enum):
    full = "full"
    mostly_full = "mostly_full"
    half = "half"
    mostly_empty = "mostly_empty"
    empty = "empty"
    unknown = "unknown"


class AnalysisResult(BaseModel):
    """Structured output from the first-sip detection model."""

    first_sip_detected: bool
    confidence: float = Field(ge=0.0, le=1.0)
    face_visible: bool
    drinking_object_visible: bool
    mouth_contact_likely: bool
    beer_likely: BeerLikely
    beer_fill_level: BeerFillLevel = BeerFillLevel.unknown
    reason_short: str
    reasoning: str | None = None
    model_name: str
    analysis_version: str
    analyzed_at: str | None = None
    source_video: str | None = None
    run_config: dict[str, Any] = Field(default_factory=dict)


class AnalysisConfig(BaseModel):
    """Configuration for the analysis pipeline."""

    model_name: str = "qwen3-vl:4b"
    num_frames: int = Field(default=2, ge=1, le=16)
    confidence_threshold: float = Field(default=0.7, ge=0.0, le=1.0)
    temperature: float = Field(default=0.3, ge=0.0, le=2.0)
    ollama_host: str = "http://localhost:11434"
    analysis_version: str = "v2"
    sliding_window_min_span: float = Field(default=0.6, gt=0.0, le=1.0)
    sliding_window_count: int = Field(default=3, ge=1)
    fill_level_votes: int = Field(default=1, ge=1, le=5)
    num_ctx: int = Field(default=16384, ge=1024)
    max_width: int = Field(default=512, ge=128, le=4096)
    jpeg_quality: int = Field(default=70, ge=10, le=100)
    think: bool = True


class FrameData(BaseModel):
    """Extracted frame data from a video clip."""

    frames_base64: list[str]
    source_path: Path
    total_duration_seconds: float
    frame_timestamps: list[float]



