"""CONTRACT-M-56 guards for the reopen-matched numbering class (F-073).

RED baseline (no fix in place): A-269 / A-270 / A-271 all FAIL -- the shared helper
Resolve-ReopenMatchedNumber does not exist yet, so the dot-source driver terminates non-zero
without emitting the reopen-matched number or the fail-loud sentinel.
"""


def _blocks(kind, lo, hi):
    return "\n".join(f"# --- {kind} #{n} (2026-01-01) -- fixture block ---" for n in range(lo, hi + 1))


# REOPEN cycle clearly at #20; RE-CLOSURE blocks only up to #17 (=> #18/#19 reclosures skipped).
# Buggy maxN+1 over RE-CLOSURE = 18; the reopen-matched number is 20.
RECLOSE_FIX = _blocks("REOPEN", 2, 20) + "\n" + _blocks("RE-CLOSURE", 2, 17) + "\nstate: Complete\n"

# REOPEN blocks up to #18 only (#19 was a re-charter with no block, on disk).
# Buggy maxN+1 over REOPEN = 19; the reopen-matched number is 20.
REOPEN_FIX = _blocks("REOPEN", 2, 18) + "\nstate: Complete\n"


def test_a269_reclose_explicit_not_maxn_plus1(ps_lib):
    """A-269 -- reclose emits the reopen-matched RE-CLOSURE number via explicit param, not maxN+1."""
    cp = ps_lib.resolve_number(RECLOSE_FIX, "RE-CLOSURE", 20)
    assert cp.returncode == 0, (
        f"helper did not resolve (Resolve-ReopenMatchedNumber missing pre-build?); "
        f"rc={cp.returncode} stdout={cp.stdout!r} stderr={cp.stderr!r}")
    assert cp.stdout.strip() == "20", (
        f"expected reopen-matched 20 (not buggy maxN+1=18); got {cp.stdout.strip()!r}")


def test_a270_reopen_explicit_not_maxn_plus1(ps_lib):
    """A-270 -- reopen emits the reopen-matched REOPEN number via explicit param, not maxN+1."""
    cp = ps_lib.resolve_number(REOPEN_FIX, "REOPEN", 20)
    assert cp.returncode == 0, (
        f"helper did not resolve; rc={cp.returncode} stdout={cp.stdout!r} stderr={cp.stderr!r}")
    assert cp.stdout.strip() == "20", (
        f"expected reopen-matched 20 (not buggy maxN+1=19); got {cp.stdout.strip()!r}")


def test_a271_mismatch_halts_loud(ps_lib):
    """A-271 -- a number that collides with sealed history HALTS LOUDLY (non-zero + sentinel),
    rather than silently emitting a number. Explicit 17 collides with the sealed RE-CLOSURE #17."""
    cp = ps_lib.resolve_number(RECLOSE_FIX, "RE-CLOSURE", 17)
    combined = (cp.stdout or "") + (cp.stderr or "")
    assert cp.returncode != 0, f"a colliding number must HALT (non-zero); got rc=0 stdout={cp.stdout!r}"
    assert "REOPEN-NUMBER-MISMATCH" in combined, (
        "halt must carry the loud sentinel 'REOPEN-NUMBER-MISMATCH' (absent pre-build => RED for the "
        f"right reason); output={combined!r}")
