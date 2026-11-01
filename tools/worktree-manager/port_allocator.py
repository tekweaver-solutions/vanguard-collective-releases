"""
port_allocator.py -- per-service static-range port assignment for
worktree-local services (e.g., dev web server, local DB, mock API).

Per the step-7 design (operator-confirmed question (b)): static per-
service range with sequential allocation. MVP-serial dispatcher
assumption documented; no file locks at MVP per ADR-006 GPU gate
(1-3 concurrent workers; <=9 ports total in practice).

**Concurrency assumption (MVP).** The dispatcher (mission-dispatch.ps1,
step 8) invokes the manager + this allocator serially per operator
command. There is no parallel dispatch creator at MVP. Two simultaneous
allocate_ports() calls in the same process from concurrent workers
would race-allocate; the documented assumption prevents this in
practice.

**Algorithm.** For each requested service:
  1. Look up its (start, end) range in _DEFAULT_PORT_RANGES.
  2. Collect ports already assigned across all active worktrees.
  3. Walk start..end; pick the lowest port not in the allocated set.
  4. Add to the running result + the allocated set.
  5. If range exhausted, raise RuntimeError with a clear message.

The result is also persisted to the target worktree's
record.port_assignments.

**Default ranges** can be overridden via the `ranges` parameter; the
defaults below are reasonable for typical MVP services. Operator-config
file for overrides is a documented deferred item.

**Deferred items:**
- Operator-config for port ranges (read from a YAML/JSON config file
  in .mission-runtime/ or .mission/config/).
- File-locked registry for true-parallel dispatcher invocation.
- Service-specific health checks (e.g., test that the allocated port
  is actually bindable, not just "not in our registry").
"""

from __future__ import annotations

from typing import Mapping, Optional

from manager import WorktreeManager


# Default per-service port ranges (inclusive). Operator-config override
# is a deferred item; today these are hardcoded.
_DEFAULT_PORT_RANGES: dict[str, tuple[int, int]] = {
    "web": (4100, 4199),
    "api": (8000, 8099),
    "db": (5500, 5599),
    "cache": (6500, 6599),
    "queue": (9100, 9199),
}


def allocate_ports(
    manager: WorktreeManager,
    worktree_id: str,
    services: list[str],
    *,
    ranges: Optional[Mapping[str, tuple[int, int]]] = None,
) -> dict[str, int]:
    """Allocate one port per requested service from its configured range.

    Avoids ports already assigned to other active worktrees. Updates the
    target worktree's record.port_assignments as a side effect; returns
    the assignment map.

    Raises:
      ValueError: requested service has no configured range.
      RuntimeError: configured range is exhausted (no free port found).
    """
    config = dict(_DEFAULT_PORT_RANGES)
    if ranges is not None:
        config.update(ranges)

    allocated = _collect_allocated_ports(manager, exclude_worktree_id=worktree_id)
    result: dict[str, int] = {}

    for service in services:
        if service not in config:
            raise ValueError(
                f"Unknown service {service!r}; configured services: "
                f"{sorted(config)}"
            )
        start, end = config[service]
        for port in range(start, end + 1):
            if port not in allocated:
                result[service] = port
                allocated.add(port)
                break
        else:
            raise RuntimeError(
                f"Port range exhausted for service {service!r} "
                f"({start}-{end}); all ports already assigned."
            )

    record = manager._load_record(worktree_id)
    record.port_assignments = result
    manager._save_record(record)
    return result


def _collect_allocated_ports(
    manager: WorktreeManager, *, exclude_worktree_id: str
) -> set[int]:
    """Union of ports held by all ACTIVE worktrees, excluding the target."""
    allocated: set[int] = set()
    for record in manager.list_active():
        if record.id == exclude_worktree_id:
            continue
        if record.port_assignments:
            allocated.update(record.port_assignments.values())
    return allocated
