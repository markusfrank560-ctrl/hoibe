"""Tests for result_parser module."""

from __future__ import annotations

import json

import pytest

from src.result_parser import parse_result
from src.schemas import AnalysisConfig


@pytest.fixture
def config():
    return AnalysisConfig()


VALID_RESPONSE = json.dumps(
    {
        "first_sip_detected": True,
        "confidence": 0.85,
        "face_visible": True,
        "drinking_object_visible": True,
        "mouth_contact_likely": True,
        "beer_likely": "true",
        "beer_fill_level": "full",
        "reason_short": "Person clearly drinking from beer glass",
    }
)

LOW_CONFIDENCE_RESPONSE = json.dumps(
    {
        "first_sip_detected": True,
        "confidence": 0.4,
        "face_visible": True,
        "drinking_object_visible": True,
        "mouth_contact_likely": False,
        "beer_likely": "unknown",
        "beer_fill_level": "unknown",
        "reason_short": "Unclear if actual drinking",
    }
)


def test_parse_valid_response(config):
    result = parse_result(VALID_RESPONSE, config)
    assert result.first_sip_detected is True
    assert result.confidence == 0.85
    assert result.face_visible is True
    assert result.model_name == "qwen3-vl:4b"
    assert result.analysis_version == "v2"


def test_confidence_threshold_applied(config):
    """Low confidence should override first_sip_detected to False."""
    result = parse_result(LOW_CONFIDENCE_RESPONSE, config)
    assert result.first_sip_detected is False
    assert result.confidence == 0.4


def test_parse_markdown_wrapped_json(config):
    wrapped = f"```json\n{VALID_RESPONSE}\n```"
    result = parse_result(wrapped, config)
    assert result.first_sip_detected is True


def test_parse_json_with_extra_text(config):
    messy = f"Here is my analysis:\n{VALID_RESPONSE}\nDone."
    result = parse_result(messy, config)
    assert result.first_sip_detected is True


def test_parse_invalid_json(config):
    with pytest.raises(ValueError, match="Cannot extract JSON"):
        parse_result("This is not JSON at all", config)


def test_parse_incomplete_json(config):
    incomplete = json.dumps({"first_sip_detected": True})
    with pytest.raises(ValueError, match="Cannot validate"):
        parse_result(incomplete, config)
