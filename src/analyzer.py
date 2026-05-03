"""Main analyzer orchestrating the detection pipeline."""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone
from pathlib import Path

from collections import Counter

from src.config import HoibeConfig, load_config
from src.frame_extractor import extract_frames
from src.ollama_client import ISOLATION_COOLDOWN, call_ollama, call_ollama_light, unload_model
from src.prompt_engine import build_fill_level_messages, build_messages
from src.result_parser import parse_result
from src.schemas import AnalysisConfig, AnalysisResult, BeerFillLevel, BeerLikely

logger = logging.getLogger("hoibe")

SLIDING_WINDOW_MIN_SPAN = 0.6
SLIDING_WINDOW_COUNT = 3


async def _cooldown_cycle(config: AnalysisConfig, hoibe_cfg: HoibeConfig) -> None:
    """Unload model and sleep between inference calls for clean KV cache and thermal recovery."""
    pipeline = hoibe_cfg.pipeline
    if pipeline.unload_between_calls:
        await unload_model(config.ollama_host, config.model_name)
    if pipeline.stage_cooldown > 0:
        logger.debug("Cooldown: %.1fs", pipeline.stage_cooldown)
        await asyncio.sleep(pipeline.stage_cooldown)

_DEFINITIVE_NEGATIVE_FILL_LEVELS = {
    BeerFillLevel.mostly_empty,
    BeerFillLevel.empty,
    BeerFillLevel.half,
}

# Legacy default; now driven by AnalysisConfig.fill_level_votes
_FILL_LEVEL_VOTES_DEFAULT = 1


def _is_definitive_negative(result: AnalysisResult) -> bool:
    """Return True if result contains a feature that makes a first sip physically impossible.

    These are scene-level facts (not temporal), so they apply across any window.
    Only relevant when first_sip_detected is already False.
    """
    if result.first_sip_detected:
        return False
    if result.beer_fill_level in _DEFINITIVE_NEGATIVE_FILL_LEVELS:
        return True
    if result.beer_likely == BeerLikely.false:
        return True
    if not result.drinking_object_visible:
        return True
    if not result.face_visible:
        return True
    return False


def _parse_fill_level(raw: str) -> BeerFillLevel:
    """Parse a fill-level response into a BeerFillLevel enum value."""
    raw = raw.strip()
    # Try JSON parse
    try:
        import json
        data = json.loads(raw)
        level = data.get("beer_fill_level", "unknown")
    except (json.JSONDecodeError, AttributeError):
        # Fallback: look for known keywords in raw text (order matters — check
        # multi-word variants before single-word to avoid partial matches)
        lower = raw.lower()
        if "mostly_empty" in lower or "mostly empty" in lower:
            level = "mostly_empty"
        elif "mostly_full" in lower or "mostly full" in lower:
            level = "mostly_full"
        elif "half" in lower:
            level = "half"
        elif "empty" in lower:
            level = "empty"
        elif "full" in lower:
            level = "full"
        else:
            level = "unknown"

    try:
        return BeerFillLevel(level)
    except ValueError:
        return BeerFillLevel.unknown


async def _check_fill_level(
    video_path: Path, config: AnalysisConfig, hoibe_cfg: HoibeConfig | None = None,
) -> BeerFillLevel:
    """Pre-check fill level using a dedicated prompt on the sharpest rest-frame.

    Extracts 2 frames from the start of the clip, selects the sharpest one
    (highest Laplacian variance), then runs the fill-level prompt on each
    frame separately for majority vote. Each vote sees a different frame.
    """
    import cv2
    import numpy as np
    import base64

    # Resolve gate-specific settings from YAML config (or use defaults)
    if hoibe_cfg is None:
        hoibe_cfg = load_config()
    gate = hoibe_cfg.gate

    gate_config = config.model_copy(update={
        "model_name": gate.model,
        "num_ctx": gate.num_ctx,
        "temperature": gate.temperature,
        "num_frames": gate.votes,
        "max_width": gate.max_width,
        "jpeg_quality": gate.jpeg_quality,
        "fill_level_votes": gate.votes,
        "think": gate.think,
        "call_timeout": gate.call_timeout,
    })

    # Extract candidate frames — more than needed so we can pick the sharpest
    num_candidates = max(gate.votes * 2, 6)
    frame_data = extract_frames(
        video_path,
        num_frames=num_candidates,
        window=tuple(gate.window),
        max_width=gate_config.max_width,
        jpeg_quality=gate_config.jpeg_quality,
    )

    # Rank frames by sharpness (Laplacian variance), pick top N for votes
    scored: list[tuple[float, str]] = []
    for b64 in frame_data.frames_base64:
        raw_bytes = base64.b64decode(b64)
        arr = np.frombuffer(raw_bytes, dtype=np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_GRAYSCALE)
        sharpness = cv2.Laplacian(img, cv2.CV_64F).var()
        scored.append((sharpness, b64))
    scored.sort(key=lambda x: x[0], reverse=True)
    top_frames = scored[:gate.votes]

    votes: list[BeerFillLevel] = []
    for i, (sharpness, frame_b64) in enumerate(top_frames):
        if i > 0:
            await _cooldown_cycle(gate_config, hoibe_cfg)
        messages = build_fill_level_messages(frame_b64, gate_config)
        try:
            raw = await call_ollama_light(messages, gate_config)
            level = _parse_fill_level(raw)
            votes.append(level)
        except (RuntimeError, ConnectionError):
            votes.append(BeerFillLevel.unknown)

    # Majority vote
    if not votes:
        return BeerFillLevel.unknown
    counter = Counter(votes)
    majority_level, _ = counter.most_common(1)[0]
    avg_sharpness = sum(s for s, _ in top_frames) / len(top_frames)
    logger.debug("Fill-level gate: votes=%s → majority=%s (sharpness=%.0f)", 
                 [v.value for v in votes], majority_level.value, avg_sharpness)
    return majority_level


def _annotate_result(
    result: AnalysisResult,
    video_path: Path,
    config: AnalysisConfig,
    *,
    mode: str,
    window: tuple[float, float] | None = None,
    window_index: int | None = None,
) -> AnalysisResult:
    run_config = config.model_dump()
    run_config["mode"] = mode
    if window is not None:
        run_config["window"] = [window[0], window[1]]
    if window_index is not None:
        run_config["window_index"] = window_index

    return result.model_copy(
        update={
            "analyzed_at": datetime.now(timezone.utc)
            .isoformat(timespec="seconds")
            .replace("+00:00", "Z"),
            "source_video": str(video_path),
            "run_config": run_config,
        }
    )


def _build_sliding_windows(
    minimum_span: float = SLIDING_WINDOW_MIN_SPAN,
    window_count: int = SLIDING_WINDOW_COUNT,
) -> list[tuple[float, float]]:
    """Build overlapping windows that cover the full clip.

    Each window spans at least ``minimum_span`` of the clip duration. The
    windows are then shifted evenly from start to end so the first starts at
    0.0 and the last ends at 1.0.
    """
    if window_count <= 0:
        raise ValueError("window_count must be positive")

    span = min(max(minimum_span, 0.0), 1.0)
    if window_count == 1 or span >= 1.0:
        return [(0.0, 1.0)]

    max_start = 1.0 - span
    step = max_start / (window_count - 1)

    windows: list[tuple[float, float]] = []
    for index in range(window_count):
        start = step * index
        end = start + span
        if index == window_count - 1:
            end = 1.0
            start = end - span
        windows.append((round(start, 4), round(end, 4)))

    return windows


async def analyze_clip(
    video_path: Path, config: AnalysisConfig | None = None
) -> AnalysisResult:
    """Analyze a video clip for first-sip detection.

    Pipeline: video → frames → prompt → ollama → parsed result.

    Args:
        video_path: Path to the video clip (MP4/H.264).
        config: Optional analysis configuration. Uses defaults if None.

    Returns:
        AnalysisResult with detection decision and metadata.
    """
    if config is None:
        config = AnalysisConfig()

    # 1. Extract frames
    frame_data = extract_frames(video_path, num_frames=config.num_frames)

    # 2. Build prompt messages
    messages = build_messages(frame_data, config)

    # 3. Call Ollama
    raw_response = await call_ollama(messages, config)

    # 4. Parse and validate result
    result = parse_result(raw_response, config)

    return _annotate_result(result, video_path, config, mode="full_clip")


async def analyze_clip_sliding(
    video_path: Path,
    config: AnalysisConfig | None = None,
    hoibe_cfg: HoibeConfig | None = None,
) -> AnalysisResult:
    """Analyze a video clip using sliding windows for better temporal coverage.

    Runs a small number of overlapping windows across the clip. Each window
    has a minimum span so the model still sees temporal motion, while the
    shifted start positions improve coverage over the full clip.

    Args:
        video_path: Path to the video clip (MP4/H.264).
        config: Optional analysis configuration. Uses defaults if None.
        hoibe_cfg: Optional loaded YAML config. Auto-loaded if None.

    Returns:
        AnalysisResult — the highest-confidence positive hit, or the
        highest-confidence negative if no window detected a sip.
    """
    if config is None:
        config = AnalysisConfig()
    if hoibe_cfg is None:
        hoibe_cfg = load_config()

    # Build window-stage config from YAML
    win_cfg = hoibe_cfg.windows
    window_config = config.model_copy(update={
        "model_name": win_cfg.model,
        "num_ctx": win_cfg.num_ctx,
        "temperature": win_cfg.temperature,
        "num_frames": win_cfg.num_frames,
        "max_width": win_cfg.max_width,
        "jpeg_quality": win_cfg.jpeg_quality,
        "sliding_window_count": win_cfg.count,
        "sliding_window_min_span": win_cfg.min_span,
        "think": win_cfg.think,
        "call_timeout": win_cfg.call_timeout,
        "analysis_version": win_cfg.prompt_version,
    })

    # Build gate reject set from config
    gate_reject_levels = {
        BeerFillLevel(level) for level in hoibe_cfg.gate.reject_levels
    }
    gate_runtime_config = config.model_copy(update={
        "model_name": hoibe_cfg.gate.model,
    })

    # --- Fill-level pre-check gate (Layers 1, 3, 4, 5) ---
    if not hoibe_cfg.gate.enabled:
        logger.debug("Gate SKIPPED (disabled in config)")
        pre_check_level = BeerFillLevel.full
    else:
        pre_check_level = await _check_fill_level(video_path, config, hoibe_cfg)
    if pre_check_level in gate_reject_levels:
        logger.debug("Gate REJECTED: fill_level=%s → early negative", pre_check_level.value)
        result = AnalysisResult(
            first_sip_detected=False,
            confidence=0.0,
            face_visible=True,
            drinking_object_visible=True,
            mouth_contact_likely=False,
            beer_likely=BeerLikely.true,
            beer_fill_level=pre_check_level,
            reason_short=f"Fill-level pre-check: glass is {pre_check_level.value} — cannot be a first sip.",
            model_name=config.model_name,
            analysis_version=config.analysis_version,
        )
        return _annotate_result(result, video_path, config, mode="sliding_precheck")

    windows = _build_sliding_windows(
        window_config.sliding_window_min_span,
        window_config.sliding_window_count,
    )
    logger.debug("Gate PASSED: fill_level=%s → running %d windows", pre_check_level.value, len(windows))

    # Cooldown after gate before first window (clean KV cache for different num_ctx)
    await _cooldown_cycle(gate_runtime_config, hoibe_cfg)

    results: list[AnalysisResult] = []
    for index, window in enumerate(windows, start=1):
        if index > 1:
            await _cooldown_cycle(window_config, hoibe_cfg)
        frame_data = extract_frames(
            video_path,
            num_frames=window_config.num_frames,
            window=window,
            max_width=window_config.max_width,
            jpeg_quality=window_config.jpeg_quality,
        )
        messages = build_messages(frame_data, window_config)
        try:
            raw_response = await call_ollama(messages, window_config)
            result = parse_result(raw_response, window_config)
        except (ValueError, RuntimeError) as error:
            logger.debug(
                "Window %d/%d [%.2f–%.2f] skipped: %s: %s",
                index,
                len(windows),
                window[0],
                window[1],
                type(error).__name__,
                error,
            )
            # Skip windows that produce empty/unparseable responses
            continue
        result = _annotate_result(
            result,
            video_path,
            config,
            mode="sliding",
            window=window,
            window_index=index,
        )
        logger.debug("Window %d/%d [%.2f–%.2f]: detected=%s conf=%.2f fill=%s",
                     index, len(windows), window[0], window[1],
                     result.first_sip_detected, result.confidence,
                     result.beer_fill_level.value)
        results.append(result)
        # Early-exit: first positive hit is enough (OR-logic)
        if result.first_sip_detected:
            # Sanity check: a genuine first sip requires a full glass.
            # If the fill level is below full, the model saw sipping but
            # it's likely a subsequent sip — downgrade to negative.
            if result.beer_fill_level != BeerFillLevel.full:
                logger.debug(
                    "Window %d/%d: downgrading first_sip — fill=%s (not full)",
                    index, len(windows), result.beer_fill_level.value,
                )
                result = result.model_copy(update={
                    "first_sip_detected": False,
                    "reason_short": (
                        f"Sipping detected but fill={result.beer_fill_level.value}"
                        " indicates a subsequent sip, not first."
                    ),
                })
                results[-1] = result
            else:
                return result

        # Early-exit: definitive disqualifier (physically impossible to be first sip)
        if _is_definitive_negative(result):
            return result

    if not results:
        result = AnalysisResult(
            first_sip_detected=False,
            confidence=0.0,
            face_visible=False,
            drinking_object_visible=False,
            mouth_contact_likely=False,
            beer_likely="unknown",
            reason_short="All sliding windows returned empty model responses — uncertain.",
            model_name=config.model_name,
            analysis_version=config.analysis_version,
        )
        return _annotate_result(result, video_path, config, mode="sliding")

    # No positive: return the highest-confidence negative
    return max(results, key=lambda r: r.confidence)



