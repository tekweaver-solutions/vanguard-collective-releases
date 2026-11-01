"""
model_routing.py -- read tools/mission-cli/config/model-routing.yaml and
resolve a ModelClass to a concrete provider+model identifier.

Per ADR-005 + kickoff prompt §5. The runner takes the resolved string and
passes it verbatim to `claude -p --model <value>`.

Default routing config path:
  <repo_root>/tools/mission-cli/config/model-routing.yaml

Overridable via the `routing_path` parameter (used by tests + future
operator-config layering).
"""

from __future__ import annotations

from pathlib import Path
from typing import Optional

import yaml

from schemas import ModelClass

_DEFAULT_ROUTING_PATH = (
    Path(__file__).parent.parent / "mission-cli" / "config" / "model-routing.yaml"
)


class ModelRoutingError(RuntimeError):
    """Raised when the routing config can't be read, parsed, or applied."""


def _load_routing(routing_path: Path) -> dict[str, dict[str, Optional[str]]]:
    if not routing_path.is_file():
        raise ModelRoutingError(f"routing config not found: {routing_path}")
    try:
        with routing_path.open("r", encoding="utf-8") as f:
            doc = yaml.safe_load(f)
    except yaml.YAMLError as e:
        raise ModelRoutingError(f"routing config YAML parse failed: {e}") from e
    if not isinstance(doc, dict):
        raise ModelRoutingError(
            f"routing config root must be a mapping; got {type(doc).__name__}"
        )
    routing = doc.get("routing")
    if not isinstance(routing, dict):
        raise ModelRoutingError(
            "routing config missing required `routing` key (mapping)"
        )
    return routing


def resolve_model_class(
    model_class: ModelClass,
    *,
    routing_path: Optional[Path] = None,
) -> str:
    """Return the primary concrete model identifier for the given ModelClass.

    Raises ModelRoutingError if the class is not declared in the routing
    config, or if the config can't be read.

    The fallback field is informational at v1; the runner uses the primary
    verbatim. Fallback semantics (rate-limit detection + auto-switch) are
    deferred to a future amendment.
    """
    path = routing_path or _DEFAULT_ROUTING_PATH
    routing = _load_routing(path)
    entry = routing.get(model_class.value)
    if entry is None:
        raise ModelRoutingError(
            f"model_class {model_class.value!r} not declared in routing config "
            f"({path}); declared classes: {sorted(routing)}"
        )
    if not isinstance(entry, dict):
        raise ModelRoutingError(
            f"routing entry for {model_class.value!r} must be a mapping; "
            f"got {type(entry).__name__}"
        )
    primary = entry.get("primary")
    if not isinstance(primary, str) or not primary:
        raise ModelRoutingError(
            f"routing entry for {model_class.value!r} missing or empty `primary` field"
        )
    return primary


def get_fallback(
    model_class: ModelClass,
    *,
    routing_path: Optional[Path] = None,
) -> Optional[str]:
    """Return the fallback model identifier (or None). Informational at v1."""
    path = routing_path or _DEFAULT_ROUTING_PATH
    routing = _load_routing(path)
    entry = routing.get(model_class.value)
    if entry is None or not isinstance(entry, dict):
        return None
    fallback = entry.get("fallback")
    if not isinstance(fallback, str) or not fallback:
        return None
    return fallback
