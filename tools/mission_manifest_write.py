"""F-040/M-20 (A-183): the validator-results manifest WRITE helper.

Invoked by Set-ValidatorResultManifestEntry (mission-lib.ps1). The manifest is a python json.dump(indent=2)
artifact (the harnesses + every prior milestone wrote it that way); writing it back through the SAME
serializer is what gives the three properties A-183 was widened to require:
  - BOM-less UTF-8 (encoding='utf-8' never emits a BOM; PS Set-Content -Encoding UTF8 DID -> broke json.load);
  - MINIMAL-DIFF: untouched entries + notes serialize byte-identically (same indent=2, ensure_ascii, LF, no
    trailing newline), so a 3-entry change diffs as ~3 entries, not a full reserialization;
  - DETERMINISTIC: dict order is preserved (load->modify->dump), so same logical manifest -> identical bytes.

LOGIC (unchanged from the PS impl VALIDATE confirmed correct): the verdict is SOURCED from the authoritative
A-NNN.validator-result.json (never a caller literal); absent assertion_id -> append (attempt_number 1);
present -> reconcile the current (max-attempt) entry's verdict IN PLACE, attempt_number UNCHANGED, no
bump/supersedes (ruling a').

Usage: python mission_manifest_write.py <root> <assertion_id> <result_file> <commit_sha-or-empty>
Prints the action line; exit 0 on success, non-zero (with a message) on failure.
"""
import json
import sys


def main():
    if len(sys.argv) < 4:
        sys.stderr.write("mission_manifest_write: need <root> <assertion_id> <result_file> [<commit_sha>]\n")
        return 2
    root, aid, result_file = sys.argv[1], sys.argv[2], sys.argv[3]
    commit_sha = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] else None
    vr_dir = root.rstrip("/\\") + "/.mission/validator-results"
    manifest_path = vr_dir + "/manifest.json"
    json_path = vr_dir + "/" + result_file

    try:
        vr = json.load(open(json_path, encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        sys.stderr.write("authoritative JSON '%s' unreadable: %s -- the verdict is SOURCED from the JSON, never a caller literal (A-183)\n" % (result_file, exc))
        return 3
    verdict = vr["verdict"]                 # <- SOURCED from the authoritative JSON (the root-bug fix)
    ev_count = len(vr.get("evidence", []))

    m = json.load(open(manifest_path, encoding="utf-8"))
    hits = [e for e in m["entries"] if e.get("assertion_id") == aid]
    if not hits:
        m["entries"].append({
            "assertion_id": aid, "verdict": verdict, "commit_sha": commit_sha, "file": result_file,
            "id": vr.get("id"), "validator_id": vr.get("validator_id"), "evidence_count": ev_count,
            "attempt_number": 1,
        })  # APPEND (absent) -- legacy behaviour preserved
        action = "appended (attempt_number=1)"
    else:
        cur = max(hits, key=lambda e: e.get("attempt_number", 1))   # the consumed max-attempt entry
        cur["verdict"] = verdict                                    # RECONCILE IN PLACE -- attempt_number UNCHANGED, no supersedes
        cur["evidence_count"] = ev_count
        if vr.get("id"):
            cur["id"] = vr["id"]
        if commit_sha:
            cur["commit_sha"] = commit_sha
        action = "reconciled in place (verdict=%s, attempt_number=%s unchanged)" % (verdict, cur.get("attempt_number"))

    # BOM-less UTF-8, LF, indent=2, ensure_ascii (the format the manifest already uses), NO trailing newline.
    with open(manifest_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(m, f, indent=2)
    sys.stdout.write(action + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
