# HALT-SAMPLE-02 -- a synthetic legacy HALT: a file the build needs sits where the session cannot copy it

**Raised:** a sample seat, after the other members went GREEN. This is the last member.
**HEAD:** the sample build commit.
**Status:** ANSWERED -- the copy made outside the session and verified by its hash. Raised before halt-ruling gates existed, so no gate binds these bytes.

---

## What was expected

The member reads a vendored copy of a protected file, byte for byte.

## What was observed

Every channel that names the protected path is refused, and the one that does not would transcribe the file by hand.

## Smallest change that resolves it

One copy, outside the session, and one hash compared inside it.

## State while this is open

Every other member is committed and GREEN; this one is RED against a marked placeholder.
