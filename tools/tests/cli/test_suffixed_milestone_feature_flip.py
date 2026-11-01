"""R-p (REOPEN #23) regression guard: the close tool's other-open-milestone scan must SEE letter-suffixed
milestone ids (grandfathered M-61a/M-61b from an earlier split). The bug that fired: the scan regex
`^  - id: (M-\\d+)\\r?\\n` was BLIND to `M-61b` (\\d+ matched "61", \\r?\\n failed on the "b"), so at
CLOSE-M-61a the still-pending M-61b was invisible and F-078 flipped done while its sanitization leg was open.

Source-anchored (reads the REAL regex out of mission-close-milestone.ps1, no duplication -> a revert fails
here) + a planted-case: a suffixed PENDING milestone sharing a feature with the closing one must be SEEN
(so the feature is NOT flipped). Non-vacuous: the old `(M-\\d+)` regex is shown to MISS it.
"""
import re
from pathlib import Path

_CLOSE = Path(__file__).resolve().parents[2] / "mission-close-milestone.ps1"

# the exact planted failure spec-shape: M-61a closing (done), M-61b still pending sharing F-078, then M-62.
_SPEC = (
    "  - id: M-61a\n    features: [F-078]\n    status: done\n\n"
    "  - id: M-61b\n    features: [F-078]\n    status: pending\n\n"
    "  - id: M-62\n    features: [F-079]\n    status: pending\n\n"
    "decisions:\n"
)


def _scan_regex_from_source() -> str:
    src = _CLOSE.read_text(encoding="utf-8")
    # the featuresToFlip other-milestone iterator regex
    m = re.search(r"foreach \(\$mm in \[regex\]::Matches\(\$spec,\s*'([^']+)'\)", src)
    assert m, "could not locate the milestone-scan regex in mission-close-milestone.ps1"
    return m.group(1)


def _py(pat: str) -> re.Pattern:
    return re.compile(pat.replace("(?ms)", ""), re.M | re.S)


def test_rp_scan_sees_suffixed_pending_milestone():
    pat = _scan_regex_from_source()
    assert "M-\\d+[a-z]?" in pat, f"the scan regex must match suffixed ids (M-\\d+[a-z]?); got: {pat}"
    seen = [mm.group(1) for mm in _py(pat).finditer(_SPEC)]
    # the fix: the still-pending suffixed M-61b IS seen -> closing M-61a will NOT flip F-078 (M-61b carries it)
    assert "M-61b" in seen, f"the scan must SEE the suffixed pending M-61b (else F-078 flips early); saw {seen}"
    assert {"M-61a", "M-61b", "M-62"} <= set(seen), f"scan must see all milestones; saw {seen}"


def test_rp_nonvacuity_old_regex_missed_suffixed():
    """NON-VACUITY: the pre-R-p `(M-\\d+)` regex MISSES the suffixed M-61b -- the exact bug."""
    old = _py("(?ms)^  - id: (M-\\d+)\\r?\\n.*?(?=^  - id: |^[A-Za-z])")
    old_seen = [mm.group(1) for mm in old.finditer(_SPEC)]
    assert "M-61b" not in old_seen and "M-61a" not in old_seen, (
        f"the old regex must MISS suffixed ids (the bug); saw {old_seen}")
    assert "M-62" in old_seen, "the old regex still saw numeric ids (only suffixed were invisible)"
