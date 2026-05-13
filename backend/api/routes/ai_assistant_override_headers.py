"""
Pure validation helpers for HF Space routing override headers.

Used by ai_assistant_proxy and tests. No Flask dependency.
"""

from __future__ import annotations

from typing import Dict, Mapping, MutableMapping, Optional, Tuple

ALLOWED_AI_PROVIDERS = frozenset(
    {"local", "hf_inference", "openai", "anthropic", "openrouter"}
)
MAX_AI_MODEL_CHARS = 120
MAX_PROVIDER_API_KEY_CHARS = 256

HDR_PROVIDER = "X-AI-Provider"
HDR_MODEL = "X-AI-Model"
HDR_API_KEY = "X-Provider-Api-Key"


def _truthy_allow_byok(raw: Optional[str]) -> bool:
    v = (raw or "true").strip().lower()
    return v in ("1", "true", "yes", "on")


def merge_headers_optional(base: MutableMapping[str, str], overrides: Mapping[str, str]) -> None:
    """Strip empty override values instead of forwarding."""
    for k, v in overrides.items():
        s = str(v).strip() if v is not None else ""
        if s:
            base[k] = s


def _normalized_header(headers: Mapping[str, str], name: str) -> str:
    """werkzeug Headers.get is case-insensitive."""
    raw = headers.get(name)
    if raw is None:
        return ""
    return str(raw).strip()


def extract_validated_hf_override_headers_from_request_headers(
    request_headers: Mapping[str, str],
    *,
    allow_byok_pass_through: Optional[str] = None,
) -> Tuple[Dict[str, str], Optional[Tuple[int, Dict[str, str]]]]:
    """
    Read X-AI-Provider, X-AI-Model, X-Provider-Api-Key (case-insensitive lookup).

    Returns:
        - (headers_dict, None); dict may be {} if nothing usable was sent.
        - ({}, (status_code, json_dict)) — validation error.
    """
    allow_byok = _truthy_allow_byok(allow_byok_pass_through)

    p = _normalized_header(request_headers, HDR_PROVIDER)
    m = _normalized_header(request_headers, HDR_MODEL)
    k_raw = _normalized_header(request_headers, HDR_API_KEY)

    if p == "" and m == "" and k_raw == "":
        return {}, None

    outbound: Dict[str, str] = {}

    if p != "":
        pl = p.lower()
        if pl not in ALLOWED_AI_PROVIDERS:
            return {}, (
                400,
                {
                    "success": False,
                    "error": (
                        "Unsupported X-AI-Provider. Allowed: "
                        + ", ".join(sorted(ALLOWED_AI_PROVIDERS))
                    ),
                    "code": "INVALID_AI_PROVIDER",
                    "upstream_status": None,
                },
            )
        outbound[HDR_PROVIDER] = pl

    if m != "":
        if len(m) > MAX_AI_MODEL_CHARS:
            return {}, (
                400,
                {
                    "success": False,
                    "error": f"X-AI-Model exceeds max length ({MAX_AI_MODEL_CHARS}).",
                    "code": "AI_MODEL_TOO_LONG",
                    "upstream_status": None,
                },
            )
        outbound[HDR_MODEL] = m

    if k_raw != "":
        if allow_byok:
            if len(k_raw) > MAX_PROVIDER_API_KEY_CHARS:
                return {}, (
                    400,
                    {
                        "success": False,
                        "error": (
                            f"X-Provider-Api-Key exceeds max length "
                            f"({MAX_PROVIDER_API_KEY_CHARS})."
                        ),
                        "code": "AI_PROVIDER_KEY_TOO_LONG",
                        "upstream_status": None,
                    },
                )
            outbound[HDR_API_KEY] = k_raw
        # else: BYOK disabled — drop key silently (do not reject whole request).

    return outbound, None

