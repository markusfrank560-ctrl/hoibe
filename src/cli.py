"""CLI entry point for hoibe first-sip detection."""

from __future__ import annotations

import asyncio
import logging
import sys
from datetime import datetime, timezone
from pathlib import Path

import click

from src.analyzer import analyze_clip, analyze_clip_sliding
from src.config import HoibeConfig, load_config
from src.schemas import AnalysisConfig

logger = logging.getLogger("hoibe")


@click.group()
def main():
    """Hoibe – Local first-sip detection from video clips."""
    pass


def _build_config(
    model: str,
    frames: int,
    threshold: float,
    prompt_version: str,
    sliding_window_min_span: float,
    sliding_window_count: int,
) -> AnalysisConfig:
    return AnalysisConfig(
        model_name=model,
        num_frames=frames,
        confidence_threshold=threshold,
        analysis_version=prompt_version,
        sliding_window_min_span=sliding_window_min_span,
        sliding_window_count=sliding_window_count,
    )


def _build_default_output_path(video_path: Path) -> Path:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return video_path.with_name(f"{video_path.stem}.result.{timestamp}.json")


def _build_latest_output_path(video_path: Path) -> Path:
    return video_path.with_name(f"{video_path.stem}.result.latest.json")


@main.command()
@click.argument("video_path", type=click.Path(exists=True, path_type=Path))
@click.option("--config", "config_path", type=click.Path(exists=True, path_type=Path), default=None, help="Path to hoibe.yaml config file")
@click.option("--model", default="qwen3-vl:4b", help="Ollama model name")
@click.option("--frames", default=2, type=int, help="Number of frames to extract")
@click.option("--threshold", default=0.7, type=float, help="Confidence threshold")
@click.option("--prompt-version", default="v2", help="Prompt template version (v1, v2)")
@click.option("--sliding/--no-sliding", default=False, help="Use sliding window (3×2 frames) for better coverage")
@click.option("--sliding-window-count", default=3, type=click.IntRange(min=1), help="Number of overlapping sliding windows")
@click.option("--sliding-window-min-span", default=0.6, type=click.FloatRange(min=0.0, min_open=True, max=1.0), help="Minimum clip fraction covered by each sliding window")
@click.option("--latest/--no-latest", default=False, help="Also update a stable .result.latest.json alias beside the video")
@click.option("--output", "-o", type=click.Path(path_type=Path), help="Output JSON path (default: beside video)")
@click.option("--verbose", "-v", is_flag=True, default=False, help="Show intermediate analysis steps on stderr")
def analyze(
    video_path: Path,
    config_path: Path | None,
    model: str,
    frames: int,
    threshold: float,
    prompt_version: str,
    sliding: bool,
    sliding_window_count: int,
    sliding_window_min_span: float,
    latest: bool,
    output: Path | None,
    verbose: bool,
):
    """Analyze a video clip for first-sip detection."""
    if verbose:
        logging.basicConfig(level=logging.DEBUG, stream=sys.stderr, format="%(message)s")

    hoibe_cfg = load_config(config_path)
    config = _build_config(
        model,
        frames,
        threshold,
        prompt_version,
        sliding_window_min_span,
        sliding_window_count,
    )

    try:
        if sliding:
            result = asyncio.run(analyze_clip_sliding(video_path, config, hoibe_cfg))
        else:
            result = asyncio.run(analyze_clip(video_path, config))
        output_path = output or _build_default_output_path(video_path)
        payload = result.model_dump_json(indent=2)
        output_path.write_text(payload, encoding="utf-8")
        click.echo(f"Result written to: {output_path}")
        if latest:
            latest_path = _build_latest_output_path(video_path)
            if latest_path != output_path:
                latest_path.write_text(payload, encoding="utf-8")
                click.echo(f"Latest alias written to: {latest_path}")
    except FileNotFoundError as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)
    except ConnectionError as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(2)
    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(3)


@main.command()
@click.argument("video_path", type=click.Path(exists=True, path_type=Path))
@click.option("--config", "config_path", type=click.Path(exists=True, path_type=Path), default=None, help="Path to hoibe.yaml config file")
@click.option("--model", default="qwen3-vl:4b", help="Ollama model name")
@click.option("--frames", default=2, type=int, help="Number of frames to extract")
@click.option("--threshold", default=0.7, type=float, help="Confidence threshold")
@click.option("--prompt-version", default="v2", help="Prompt template version (v1, v2)")
@click.option("--sliding/--no-sliding", default=False, help="Use sliding window (3×2 frames) for better coverage")
@click.option("--sliding-window-count", default=3, type=click.IntRange(min=1), help="Number of overlapping sliding windows")
@click.option("--sliding-window-min-span", default=0.6, type=click.FloatRange(min=0.0, min_open=True, max=1.0), help="Minimum clip fraction covered by each sliding window")
@click.option("--verbose", "-v", is_flag=True, default=False, help="Show intermediate analysis steps on stderr")
def check(
    video_path: Path,
    config_path: Path | None,
    model: str,
    frames: int,
    threshold: float,
    prompt_version: str,
    sliding: bool,
    sliding_window_count: int,
    sliding_window_min_span: float,
    verbose: bool,
):
    """Analyze and print result JSON to stdout."""
    if verbose:
        logging.basicConfig(level=logging.DEBUG, stream=sys.stderr, format="%(message)s")

    hoibe_cfg = load_config(config_path)
    config = _build_config(
        model,
        frames,
        threshold,
        prompt_version,
        sliding_window_min_span,
        sliding_window_count,
    )

    try:
        if sliding:
            result = asyncio.run(analyze_clip_sliding(video_path, config, hoibe_cfg))
        else:
            result = asyncio.run(analyze_clip(video_path, config))
        click.echo(result.model_dump_json(indent=2))
    except FileNotFoundError as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)
    except ConnectionError as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(2)
    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(3)


if __name__ == "__main__":
    main()
