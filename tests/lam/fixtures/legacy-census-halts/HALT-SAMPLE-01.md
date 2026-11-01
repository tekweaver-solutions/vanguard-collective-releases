# HALT-SAMPLE-01 -- a synthetic legacy HALT: two readings of one contract clause, and the build cannot take both

**Raised:** a sample seat, before any build, on reading the clause the check names.
**HEAD:** the sample contract commit.
**Status:** ANSWERED -- the first reading accepted; the seat resumed at the next member. Raised before halt-ruling gates existed, so no gate binds these bytes.

---

## Expected

The clause says the check passes "unchanged" against the new hooks, and the next clause says the hooks change what
the check reads.

## Observed

Both cannot hold as written: the first reading keeps the check and drops the change, the second keeps the change and
edits the check.

## Smallest change that resolves it

Take the first reading. The check stays byte for byte; the change is made where the check does not look.

## What I did not do

No file was created or edited while this was open. No check was relaxed.
