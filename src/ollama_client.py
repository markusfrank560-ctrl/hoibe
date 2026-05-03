"""Ollama API client for VLM inference."""

from __future__ import annotations

import asyncio
import os
import re
from typing import Any

import ollama

from src.schemas import AnalysisConfig

# Ensure local Ollama connections bypass any HTTP proxy.
_NO_PROXY = os.environ.get("no_proxy", "")
if "localhost" not in _NO_PROXY and "127.0.0.1" not in _NO_PROXY:
    _updated = f"{_NO_PROXY},localhost,127.0.0.1" if _NO_PROXY else "localhost,127.0.0.1"
    os.environ["no_proxy"] = _updated
    os.environ["NO_PROXY"] = _updated

# Seconds to sleep after unloading to allow GPU thermal recovery.
ISOLATION_COOLDOWN = float(os.environ.get("HOIBE_COOLDOWN", "5"))

# Default timeout for VLM inference calls (seconds).
# Must accommodate cold-start model loads (e.g. num_ctx change triggers reload).
_CALL_TIMEOUT = float(os.environ.get("HOIBE_TIMEOUT", "300"))
_CALL_LIGHT_TIMEOUT = float(os.environ.get("HOIBE_TIMEOUT_LIGHT", "60"))

_THINK_RE = re.compile(r"<think>.*?</think>\s*", re.DOTALL)


def _strip_think_tags(content: str) -> str:
    """Remove <think>...</think> blocks from model output."""
    return _THINK_RE.sub("", content).strip()


async def unload_model(host: str, model_name: str) -> None:
    """Immediately unload a model from Ollama GPU memory (best-effort).

    Uses keep_alive=0 to signal Ollama to release the model. This clears the
    KV cache and frees VRAM, giving the next inference a clean slate.
    """
    client = ollama.AsyncClient(host=host)
    try:
        await client.generate(model=model_name, keep_alive=0, prompt="")
    except Exception:
        pass  # best-effort; never break the pipeline


async def call_ollama(
    messages: list[dict[str, Any]], config: AnalysisConfig
) -> str:
    """Call local Ollama model with chat messages.

    Args:
        messages: Chat messages including images.
        config: Analysis configuration with model name and params.

    Returns:
        Raw response content string from the model.

    Raises:
        ConnectionError: If Ollama is not reachable.
        RuntimeError: If the model call fails.
    """
    client = ollama.AsyncClient(host=config.ollama_host)

    chat_kwargs: dict[str, Any] = {
        "model": config.model_name,
        "messages": messages,
        "options": {"temperature": config.temperature, "num_ctx": config.num_ctx},
    }
    if config.think:
        chat_kwargs["think"] = True

    timeout = config.call_timeout if config.call_timeout else _CALL_TIMEOUT
    try:
        response = await asyncio.wait_for(
            client.chat(**chat_kwargs),
            timeout=timeout,
        )
    except asyncio.TimeoutError:
        raise RuntimeError(
            f"Ollama call timed out after {timeout}s. "
            "Model may be overloaded or stuck."
        )
    except Exception as e:
        error_msg = str(e).lower()
        if "connect" in error_msg or "refused" in error_msg:
            raise ConnectionError(
                f"Cannot connect to Ollama at {config.ollama_host}. "
                "Is Ollama running? Start with: ollama serve"
            ) from e
        raise RuntimeError(f"Ollama call failed: {e}") from e

    return _strip_think_tags(response["message"]["content"])


async def call_ollama_light(
    messages: list[dict[str, Any]], config: AnalysisConfig
) -> str:
    """Lightweight Ollama call without thinking mode.

    Used for cheap, fast queries (e.g. fill-level checks) where
    chain-of-thought reasoning is unnecessary.

    Args:
        messages: Chat messages including images.
        config: Analysis configuration with model name and params.

    Returns:
        Raw response content string from the model.

    Raises:
        ConnectionError: If Ollama is not reachable.
        RuntimeError: If the model call fails.
    """
    client = ollama.AsyncClient(host=config.ollama_host)

    chat_kwargs: dict[str, Any] = {
        "model": config.model_name,
        "messages": messages,
        "options": {"temperature": config.temperature, "num_ctx": config.num_ctx},
    }
    if config.think:
        chat_kwargs["think"] = True

    timeout = config.call_timeout if config.call_timeout else _CALL_LIGHT_TIMEOUT
    try:
        response = await asyncio.wait_for(
            client.chat(**chat_kwargs),
            timeout=timeout,
        )
    except asyncio.TimeoutError:
        raise RuntimeError(
            f"Ollama light call timed out after {timeout}s. "
            "Model may be overloaded or stuck."
        )
    except Exception as e:
        error_msg = str(e).lower()
        if "connect" in error_msg or "refused" in error_msg:
            raise ConnectionError(
                f"Cannot connect to Ollama at {config.ollama_host}. "
                "Is Ollama running? Start with: ollama serve"
            ) from e
        raise RuntimeError(f"Ollama call failed: {e}") from e

    return _strip_think_tags(response["message"]["content"])
