import os

import pytest

from api.routes.ai_assistant_override_headers import (
    ALLOWED_AI_PROVIDERS,
    extract_validated_hf_override_headers_from_request_headers,
)


class _Hdr(dict):
    """Minimal headers mapping (case-sensitive get as most servers send)."""


def test_empty_headers_returns_empty():
    h, err = extract_validated_hf_override_headers_from_request_headers(
        {}, allow_byok_pass_through="true"
    )
    assert h == {}
    assert err is None


def test_invalid_provider_returns_400():
    h, err = extract_validated_hf_override_headers_from_request_headers(
        _Hdr({"X-AI-Provider": "bogus"}), allow_byok_pass_through="true"
    )
    assert h == {}
    assert err is not None
    status, payload = err
    assert status == 400
    assert payload["code"] == "INVALID_AI_PROVIDER"


def test_model_length_limit():
    h, err = extract_validated_hf_override_headers_from_request_headers(
        _Hdr({"X-AI-Model": "x" * 121}), allow_byok_pass_through="true"
    )
    assert err is not None and err[0] == 400
    assert err[1]["code"] == "AI_MODEL_TOO_LONG"


def test_key_length_limit_when_byok_allowed():
    h, err = extract_validated_hf_override_headers_from_request_headers(
        _Hdr({"X-Provider-Api-Key": "k" * 257}), allow_byok_pass_through="true"
    )
    assert err is not None and err[0] == 400
    assert err[1]["code"] == "AI_PROVIDER_KEY_TOO_LONG"


def test_valid_full_set():
    h, err = extract_validated_hf_override_headers_from_request_headers(
        _Hdr(
            {
                "X-AI-Provider": "OpenAI",
                "X-AI-Model": "gpt-4o-mini",
                "X-Provider-Api-Key": "sk-secret",
            }
        ),
        allow_byok_pass_through="true",
    )
    assert err is None
    assert h["X-AI-Provider"] == "openai"
    assert h["X-AI-Model"] == "gpt-4o-mini"
    assert h["X-Provider-Api-Key"] == "sk-secret"


def test_byok_disabled_strips_key_but_keeps_provider_model(monkeypatch):
    h, err = extract_validated_hf_override_headers_from_request_headers(
        _Hdr(
            {
                "X-AI-Provider": "anthropic",
                "X-AI-Model": "claude",
                "X-Provider-Api-Key": "should-drop",
            }
        ),
        allow_byok_pass_through="false",
    )
    assert err is None
    assert "X-Provider-Api-Key" not in h
    assert h.get("X-AI-Provider") == "anthropic"
    assert h.get("X-AI-Model") == "claude"


def test_only_key_with_byok_off_returns_empty():
    h, err = extract_validated_hf_override_headers_from_request_headers(
        _Hdr({"X-Provider-Api-Key": "k"}),
        allow_byok_pass_through="false",
    )
    assert err is None
    assert h == {}


def test_allowlist_contains_expected():
    assert "hf_inference" in ALLOWED_AI_PROVIDERS

