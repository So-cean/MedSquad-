"""
Shared OpenAI-compatible client factory.

All API calls go through this module so that every caller uses the same
client configuration (base_url, api_key, headers, timeout, etc.).
"""

from openai import OpenAI

from app.config import settings


def create_client() -> OpenAI:
    """Return an OpenAI-compatible client configured from app settings."""
    return OpenAI(
        base_url=settings.openai_base_url.rstrip("/"),
        api_key=settings.openai_api_key,
        default_headers={"X-Failover-Enabled": "true"},
        timeout=settings.openai_timeout_seconds,
    )


def chat_completion(
    *,
    messages: list,
    model: str | None = None,
    temperature: float = 0.2,
    top_p: float = 0.7,
    max_tokens: int = 4096,
    frequency_penalty: float = 1.0,
    response_format: dict | None = None,
    extra_body: dict | None = None,
    stream: bool = False,
) -> dict:
    """Thin wrapper around client.chat.completions.create.

    Returns the complete response dict when stream=False, or the stream
    iterator when stream=True.
    """
    client = create_client()
    kwargs: dict = {
        "model": model or settings.openai_model,
        "messages": messages,
        "temperature": temperature,
        "top_p": top_p,
        "max_tokens": max_tokens,
        "frequency_penalty": frequency_penalty,
    }
    if response_format is not None:
        kwargs["response_format"] = response_format
    if extra_body is not None:
        kwargs["extra_body"] = extra_body

    if stream:
        kwargs["stream"] = True
        return client.chat.completions.create(**kwargs)

    # Non-streaming: return the full response as a dict
    completion = client.chat.completions.create(**kwargs)
    return completion.model_dump()