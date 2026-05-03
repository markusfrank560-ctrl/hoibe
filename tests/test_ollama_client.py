"""Tests for ollama_client module."""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest

from src.ollama_client import call_ollama
from src.schemas import AnalysisConfig


@pytest.fixture
def config():
    return AnalysisConfig()


@pytest.fixture
def sample_messages():
    return [
        {"role": "system", "content": "You are a test system."},
        {"role": "user", "content": "Test prompt", "images": ["base64data"]},
    ]


@pytest.mark.asyncio
async def test_call_ollama_success(config, sample_messages):
    mock_response = {"message": {"content": '{"first_sip_detected": true}'}}

    with patch("src.ollama_client.ollama.AsyncClient") as MockClient:
        instance = MockClient.return_value
        instance.chat = AsyncMock(return_value=mock_response)

        result = await call_ollama(sample_messages, config)

    assert result == '{"first_sip_detected": true}'
    instance.chat.assert_called_once_with(
        model="qwen3-vl:4b",
        messages=sample_messages,
        options={"temperature": 0.3, "num_ctx": 16384},
        think=True,
    )


@pytest.mark.asyncio
async def test_call_ollama_connection_error(config, sample_messages):
    with patch("src.ollama_client.ollama.AsyncClient") as MockClient:
        instance = MockClient.return_value
        instance.chat = AsyncMock(side_effect=Exception("connection refused"))

        with pytest.raises(ConnectionError, match="Cannot connect to Ollama"):
            await call_ollama(sample_messages, config)


@pytest.mark.asyncio
async def test_call_ollama_runtime_error(config, sample_messages):
    with patch("src.ollama_client.ollama.AsyncClient") as MockClient:
        instance = MockClient.return_value
        instance.chat = AsyncMock(side_effect=Exception("model not found"))

        with pytest.raises(RuntimeError, match="Ollama call failed"):
            await call_ollama(sample_messages, config)
