"""Tests for model_routing.resolve_model_class + get_fallback (step 9)."""

from __future__ import annotations

from pathlib import Path

import pytest

from model_routing import (
    ModelRoutingError,
    get_fallback,
    resolve_model_class,
)
from schemas import ModelClass


def test_resolve_coding_strong_returns_primary() -> None:
    """coding-strong → claude-code-subscription per kickoff prompt §5."""
    result = resolve_model_class(ModelClass.CODING_STRONG)
    assert result == "claude-code-subscription"


def test_resolve_coding_fast_returns_ollama_7b() -> None:
    result = resolve_model_class(ModelClass.CODING_FAST)
    assert result == "ollama/qwen2.5-coder:7b"


def test_resolve_narrow_validator_returns_ollama_7b() -> None:
    result = resolve_model_class(ModelClass.NARROW_VALIDATOR)
    assert result == "ollama/qwen2.5-coder:7b"


def test_resolve_qa_validator_returns_claude_code_subscription() -> None:
    """qa-validator uses subscription for vision per ADR-013."""
    result = resolve_model_class(ModelClass.QA_VALIDATOR)
    assert result == "claude-code-subscription"


def test_get_fallback_returns_ollama_for_coding_strong() -> None:
    """Per kickoff prompt §5: coding-strong primary + ollama fallback."""
    result = get_fallback(ModelClass.CODING_STRONG)
    assert result == "ollama/qwen2.5-coder:7b"


def test_get_fallback_returns_none_when_unset() -> None:
    """coding-fast / narrow-validator / qa-validator have no fallback at v1."""
    assert get_fallback(ModelClass.CODING_FAST) is None
    assert get_fallback(ModelClass.NARROW_VALIDATOR) is None
    assert get_fallback(ModelClass.QA_VALIDATOR) is None


def test_resolve_with_custom_routing_path(tmp_path: Path) -> None:
    """routing_path override exercises operator-config layering."""
    custom = tmp_path / "custom-routing.yaml"
    custom.write_text(
        "routing:\n"
        "  coding-strong:\n"
        "    primary: custom-model-x\n"
        "    fallback: custom-fallback-y\n",
        encoding="utf-8",
    )
    result = resolve_model_class(ModelClass.CODING_STRONG, routing_path=custom)
    assert result == "custom-model-x"


def test_missing_routing_config_raises(tmp_path: Path) -> None:
    with pytest.raises(ModelRoutingError, match="not found"):
        resolve_model_class(
            ModelClass.CODING_STRONG, routing_path=tmp_path / "missing.yaml"
        )


def test_malformed_routing_yaml_raises(tmp_path: Path) -> None:
    bad = tmp_path / "bad.yaml"
    bad.write_text("not: valid: yaml: [", encoding="utf-8")
    with pytest.raises(ModelRoutingError, match="YAML parse"):
        resolve_model_class(ModelClass.CODING_STRONG, routing_path=bad)


def test_routing_missing_routing_key_raises(tmp_path: Path) -> None:
    no_routing = tmp_path / "no-routing.yaml"
    no_routing.write_text("other_key: value\n", encoding="utf-8")
    with pytest.raises(ModelRoutingError, match="missing required"):
        resolve_model_class(ModelClass.CODING_STRONG, routing_path=no_routing)
