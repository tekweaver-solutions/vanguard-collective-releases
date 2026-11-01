"""CONTRACT-M-56 guards for the comment-tolerant field-writer class (F-072).

RED baseline (no fix in place):
  A-264 / A-265 / A-266 FAIL  (comment-bearing field lines are not advanced)
  A-267              PASSES   (comment-free path is the preserved/current behavior)

A-268 (non-vacuity) has no separate guard -- its evidence IS the A-264/265/266 RED baseline.
"""


def test_a264_current_milestone_comment_preserved(ps_lib):
    """A-264 -- current_milestone advances on a comment-bearing line, comment preserved.

    DOT-SOURCED against the F-072 shared helper (close-milestone:187 is gate-heavy end-to-end).
    """
    cp = ps_lib.set_field("current_milestone: M-55   # keep me\n", "current_milestone", "M-56")
    out = cp.stdout
    assert "current_milestone: M-56" in out, (
        f"value not advanced (helper Set-MissionFieldValue missing pre-build?) rc={cp.returncode} "
        f"stdout={out!r} stderr={cp.stderr!r}")
    assert "# keep me" in out, f"trailing comment not preserved; stdout={out!r}"


def test_a265_current_spec_version_comment_preserved_e2e(bump_env):
    """A-265 -- current_spec_version advances on a comment-bearing line, comment preserved.

    END-TO-END through the real mission-spec-bump CLI (writer mission-lib.ps1:115).
    """
    res = bump_env(
        mission_yaml="state: Reworking\ncurrent_spec_version: 10   # SENTINEL-CSV-COMMENT\n",
        spec010_yaml=("version: 10\nprevious_version: 9\n"
                      "created_from_amendment: AM-OLD\ngoal: contract-m56 fixture\n"),
    )
    assert "current_spec_version: 11" in res.mission_text, (
        f"current_spec_version not advanced past the trailing comment; rc={res.proc.returncode} "
        f"mission.yaml={res.mission_text!r} stderr={res.proc.stderr!r}")
    assert "SENTINEL-CSV-COMMENT" in res.mission_text, "trailing comment not preserved"


def test_a266_spec_body_writers_comment_preserved_e2e(bump_env):
    """A-266 -- version / previous_version / created_from_amendment advance on comment-bearing
    lines, comments preserved. END-TO-END (writers mission-lib.ps1:105/106/107)."""
    res = bump_env(
        mission_yaml="state: Reworking\ncurrent_spec_version: 10\n",
        spec010_yaml=("version: 10   # SENTINEL-VER\n"
                      "previous_version: 9   # SENTINEL-PREV\n"
                      "created_from_amendment: AM-OLD   # SENTINEL-CFA\n"
                      "goal: contract-m56 fixture\n"),
    )
    s = res.spec011_text
    assert s, f"v011.yaml not produced; rc={res.proc.returncode} stderr={res.proc.stderr!r}"
    assert "version: 11" in s, f"version not advanced past comment; v011={s!r}"
    assert "previous_version: 10" in s, f"previous_version not advanced past comment; v011={s!r}"
    assert "created_from_amendment: AM-099" in s, f"created_from_amendment not advanced; v011={s!r}"
    assert "SENTINEL-VER" in s and "SENTINEL-PREV" in s and "SENTINEL-CFA" in s, \
        "one or more trailing comments not preserved"


def test_a267_comment_free_no_regression_e2e(bump_env):
    """A-267 -- refactor-safety: the spec-bump writers stay byte-correct on COMMENT-FREE lines.

    GREEN-NOW, STAYS-GREEN (this is the preserved/current behavior). If this fails at the contract
    RED baseline, the refactor-safety baseline is wrong -> STOP.
    """
    res = bump_env(
        mission_yaml="state: Reworking\ncurrent_spec_version: 10\n",
        spec010_yaml=("version: 10\nprevious_version: 9\n"
                      "created_from_amendment: AM-OLD\ngoal: contract-m56 fixture\n"),
    )
    assert res.proc.returncode == 0, f"spec-bump failed; stderr={res.proc.stderr!r}"
    assert "current_spec_version: 11" in res.mission_text
    s = res.spec011_text
    assert "version: 11" in s
    assert "previous_version: 10" in s
    assert "created_from_amendment: AM-099" in s
