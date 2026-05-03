"""Parse and validate Ollama model responses."""

from __future__ import annotations

import json
import re

from src.schemas import AnalysisConfig, AnalysisResult


def parse_result(raw_response: str, config: AnalysisConfig) -> AnalysisResult:
    """Parse raw model response into a validated AnalysisResult.

    Attempts JSON parsing first, then falls back to regex extraction.

    Args:
        raw_response: Raw string response from Ollama.
        config: Analysis config for model_name and analysis_version.

    Returns:
        Validated AnalysisResult.

    Raises:
        ValueError: If response cannot be parsed into valid result.
    """
    data = _extract_json(raw_response)

    # Inject metadata fields
    data["model_name"] = config.model_name
    data["analysis_version"] = config.analysis_version

    # Confidence threshold — only gates positive claims.
    # If the model says detected=true but confidence is below threshold,
    # override to false. A model returning detected=false is never flipped;
    # the confidence value is stored but has no effect on the decision.
    confidence = float(data.get("confidence", 0.0))
    if confidence < config.confidence_threshold:
        data["first_sip_detected"] = False

    # v3 prompts return minimal fields — backfill defaults for gate-proven facts
    if config.analysis_version == "v3":
        data.setdefault("face_visible", True)
        data.setdefault("drinking_object_visible", True)
        data.setdefault("mouth_contact_likely", data.get("first_sip_detected", False))
        data.setdefault("beer_likely", "true")
        data.setdefault("beer_fill_level", "full")

    try:
        return AnalysisResult.model_validate(data)
    except Exception as e:
        raise ValueError(f"Cannot validate model response: {e}") from e


def _extract_json(raw: str) -> dict:
    """Extract JSON object from raw response string.

    Handles cases where the model wraps JSON in markdown code blocks
    or adds extra text.
    """
    raw = raw.strip()

    # Try direct parse
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        pass

    # Try extracting from markdown code block
    match = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", raw, re.DOTALL)
    if match:
        try:
            return json.loads(match.group(1))
        except json.JSONDecodeError:
            pass

    # Try finding first JSON object in text
    match = re.search(r"\{[^{}]*\}", raw, re.DOTALL)
    if match:
        try:
            return json.loads(match.group(0))
        except json.JSONDecodeError:
            pass

    raise ValueError(f"Cannot extract JSON from model response: {raw[:200]}")
