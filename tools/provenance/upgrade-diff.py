# The upgrade prediction, read-only: what install.ps1's plan gives every installer-owned path when a release upgrades a
# target an earlier release installed fresh, its files standing at that release's bytes and its lock rows reading
# installed.
# usage: python -I tools/provenance/upgrade-diff.py <old manifest> <new manifest> --old-version <v> [--new-version <v>]
#            [--repo <checkout> --old-rev <rev> --new-rev <rev>] [--out <file>]
#        python -I tools/provenance/upgrade-diff.py --digest <manifest>
# A MANIFEST IS NAMED BY ITS INSTALLER-OWNED RECORDS, NOT BY ITS FILE. The prediction is a function of the
# installer-owned records alone, and it is committed as a document whose own manifest record carries its sha256: so the
# manifest of the commit that holds the document -- and of every later commit a release seat makes before the tag --
# has a file sha256 no document written before it can name. The 0.1.1 -> 0.2.0 prediction named 8ec7e4e's file, and
# the tag's manifest was another. The records digest is the sha256 of one line per installer-owned record --
# destination, class, sha256, bytes and eol joined by tabs and ended by LF, an absent field written None -- the lines
# sorted by code point, UTF-8: the fields every disposition below depends on (class, sha256 and eol decide it) and the
# bytes install.ps1 holds a source file to. A commit that changes only AUTHORED records or reasons leaves it as it is;
# one that changes any of those fields of an installer-owned record changes it. --digest prints it for any manifest,
# so the tag's can be held to the document.
# A COMMITTED MANIFEST ONLY: a manifest given that is a git work tree's provenance/manifest.jsonl, and the --repo
# checkout's own, must equal HEAD's -- a working tree whose manifest differs from HEAD's is refused, by name, before
# anything is written; so is a path git cannot answer for (anything but "not a git repository"), since a check that
# cannot be made is not passed. Git runs with the variables that would make it answer for another repository cleared.
# Each manifest's installer-owned set is derived as install.ps1 derives its own: source the manifest's host token, class
# MOVE, TEMPLATE or HOST-CONFIG, a destination. The host token is read from the header (the one key ending in _base other
# than lam_smoke_base names it), so a release that renamed it is read by its own vocabulary, and the token is never
# printed. Paths are matched without regard to case, as the lock reads them. The plan, as install.ps1 makes it:
#   new TEMPLATE or HOST-CONFIG, present            -> kept
#   new TEMPLATE root .gitattributes, absent        -> not-written (install.ps1 writes it on a fresh
#                                                      install only; an upgrade adds none where the project has none)
#   new path, absent                                -> installed
#   new MOVE, present, folding alike                -> already-identical
#   new MOVE, present, otherwise                    -> upgraded-from <old version> (its row reads installed)
#   old path not in the new set                     -> retired (left in place, dropped from the lock)
# "Folding alike" is install.ps1's EOL rule: a text file (no 0x00 byte) is judged after every CR LF is made LF, a binary
# one raw. A manifest's sha256 is the raw file's, which is the folded one for a record whose eol is LF or NONE; for any
# other record the two blobs are read from --repo at the two revs (whose manifests must be the two given) and folded, and
# without --repo such a pair is compared raw and the output says so. The prediction is Markdown, UTF-8, LF, the same
# bytes for the same inputs: written to --out, or to stdout.
import hashlib, json, os, subprocess, sys

OWNED_CLASSES = ('MOVE', 'TEMPLATE', 'HOST-CONFIG')
KIND = {'MOVE': 'move', 'TEMPLATE': 'template', 'HOST-CONFIG': 'host-config'}
ROOT_ATTRIBUTES = '.gitattributes'
# git reads these from the environment and would answer for another repository, or with injected configuration; the
# list is tools/lam/commit_ledger.py's.
GIT_REDIRECTS = ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR', 'GIT_OBJECT_DIRECTORY',
                 'GIT_ALTERNATE_OBJECT_DIRECTORIES', 'GIT_NAMESPACE', 'GIT_CONFIG_PARAMETERS', 'GIT_CONFIG_COUNT')

def fail(text):
    sys.stderr.write('upgrade-diff: ' + text + '\n')
    sys.exit(1)

def git(cwd, argv):
    env = dict((k, v) for k, v in os.environ.items() if k.upper() not in GIT_REDIRECTS)
    return subprocess.run(['git', '-C', cwd] + argv, capture_output=True, env=env)

def read(path, label):
    try:
        return open(path, 'rb').read()
    except OSError as e:
        fail('%s cannot be read (%s)' % (label, e))

def owned_set(raw, label):
    lines = raw.decode('utf-8').split('\n')
    if lines[-1] != '':
        fail(label + ' does not end with LF')
    head = json.loads(lines[0])
    if head.get('manifest') != 'provenance':
        fail(label + ' does not begin with the provenance header')
    keys = [k for k in head if k.endswith('_base') and k != 'lam_smoke_base']
    if len(keys) != 1:
        fail(label + "'s header does not name one host token (%d candidate keys)" % len(keys))
    token = keys[0][:-len('_base')]
    out = {}
    for l in lines[1:-1]:
        r = json.loads(l)
        if r.get('source') != token or r.get('class') not in OWNED_CLASSES or r.get('destination') is None:
            continue
        k = r['destination'].lower()
        if k in out:
            fail(label + ' names ' + r['destination'] + ' twice')
        out[k] = r
    return out

def git_blob(repo, spec):
    p = git(repo, ['cat-file', 'blob', spec])
    if p.returncode != 0:
        fail('git cat-file blob %s exited %d' % (spec, p.returncode))
    return p.stdout

def judged(b):
    if b'\0' in b:
        return hashlib.sha256(b).hexdigest()
    return hashlib.sha256(b.replace(b'\r\n', b'\n')).hexdigest()

def records_digest(owned):
    lines = sorted('%s\t%s\t%s\t%s\t%s\n' % (r['destination'], r['class'], r['sha256'], r.get('bytes'), r.get('eol'))
                   for r in owned.values())
    return hashlib.sha256(''.join(lines).encode('utf-8')).hexdigest()

def work_tree_top(where, label, required):
    # The top of the git work tree holding the folder `where`; None where git says it is in no repository (and that is
    # allowed). Any other answer git cannot give -- dubious ownership, a broken repository -- refuses the run.
    p = git(where, ['rev-parse', '--show-toplevel'])
    if p.returncode == 0:
        return p.stdout.decode('utf-8').strip()
    err = p.stderr.decode('utf-8', 'replace').strip()
    if not required and 'not a git repository' in err:
        return None
    fail('%s: git cannot say which work tree holds %s (%s), so its manifest cannot be held to HEAD\'s; nothing was written'
         % (label, where, err))

def held_to_head(path, label, checkout=False):
    # A manifest given that is a work tree's provenance/manifest.jsonl -- or, with checkout, the manifest of the work
    # tree holding the folder `path` -- must be byte for byte HEAD's.
    if checkout:
        top = work_tree_top(path, label, True)
    else:
        if not os.path.isfile(path):
            return
        top = work_tree_top(os.path.dirname(os.path.abspath(path)), label, False)
        if top is None:
            return
    own = os.path.join(top, 'provenance', 'manifest.jsonl')
    if not checkout and os.path.normcase(os.path.realpath(own)) != os.path.normcase(os.path.realpath(path)):
        return
    raw = open(own, 'rb').read() if os.path.isfile(own) else None
    head = git(top, ['cat-file', 'blob', 'HEAD:provenance/manifest.jsonl'])
    if raw is None or head.returncode != 0 or head.stdout != raw:
        fail('%s: the working tree\'s provenance/manifest.jsonl at %s differs from HEAD\'s (working tree sha256 %s, HEAD %s): '
             'a prediction is made from a committed manifest -- commit it first; nothing was written'
             % (label, top, hashlib.sha256(raw).hexdigest() if raw is not None else 'none in the working tree',
                hashlib.sha256(head.stdout).hexdigest() if head.returncode == 0 else 'none at HEAD'))

def main():
    args = sys.argv[1:]
    opts = {}
    pos = []
    while args:
        a = args.pop(0)
        if a in ('--old-version', '--new-version', '--repo', '--old-rev', '--new-rev', '--out', '--digest'):
            if not args:
                fail(a + ' needs a value')
            if a in opts:
                fail(a + ' is given twice')
            opts[a] = args.pop(0)
        else:
            pos.append(a)
    if '--digest' in opts:
        if pos or len(opts) != 1:
            fail('usage: upgrade-diff.py --digest <manifest>')
        owned = owned_set(read(opts['--digest'], opts['--digest']), opts['--digest'])
        sys.stdout.buffer.write(('installer-owned %d  records sha256 %s\n' % (len(owned), records_digest(owned))).encode('ascii'))
        return
    if len(pos) != 2 or '--old-version' not in opts:
        fail('usage: upgrade-diff.py <old manifest> <new manifest> --old-version <v> [--new-version <v>] '
             '[--repo <checkout> --old-rev <rev> --new-rev <rev>] [--out <file>]  |  upgrade-diff.py --digest <manifest>')
    repo = opts.get('--repo')
    held_to_head(pos[0], 'the old manifest')
    held_to_head(pos[1], 'the new manifest')
    if repo:
        held_to_head(repo, 'the --repo checkout', checkout=True)
    raws = [read(pos[0], 'the old manifest'), read(pos[1], 'the new manifest')]
    if repo:
        if '--old-rev' not in opts or '--new-rev' not in opts:
            fail('--repo needs --old-rev and --new-rev')
        for raw, rev, label in ((raws[0], opts['--old-rev'], 'the old manifest'), (raws[1], opts['--new-rev'], 'the new manifest')):
            if git_blob(repo, rev + ':provenance/manifest.jsonl') != raw:
                fail(label + ' is not ' + rev + ':provenance/manifest.jsonl')
    old, new = owned_set(raws[0], 'the old manifest'), owned_set(raws[1], 'the new manifest')
    ver = opts['--old-version']
    rows, raw_only = [], []
    for k in sorted(set(old) | set(new), key=lambda x: (new.get(x) or old.get(x))['destination']):
        o, n = old.get(k), new.get(k)
        path = (n or o)['destination']
        if n is None:
            rows.append((path, o['class'], None, 'retired'))
            continue
        if o is None:
            rows.append((path, None, n['class'],
                         'not-written' if n['class'] == 'TEMPLATE' and n['destination'] == ROOT_ATTRIBUTES else 'installed'))
            continue
        if n['class'] != 'MOVE':
            rows.append((path, o['class'], n['class'], 'kept'))
            continue
        if o.get('eol') in ('LF', 'NONE') and n.get('eol') in ('LF', 'NONE'):
            same = o['sha256'] == n['sha256']
        elif repo:
            same = judged(git_blob(repo, opts['--old-rev'] + ':' + o['destination'])) == judged(git_blob(repo, opts['--new-rev'] + ':' + n['destination']))
        else:
            same = o['sha256'] == n['sha256']
            raw_only.append(path)
        rows.append((path, o['class'], n['class'], 'already-identical' if same else 'upgraded-from ' + ver))
    count = {}
    for r in rows:
        count[r[3]] = count.get(r[3], 0) + 1
    up = count.get('upgraded-from ' + ver, 0)
    written = count.get('installed', 0) + up
    text = []
    w = text.append
    w('# The upgrade prediction: %s over a fresh %s install\n\n' % (opts.get('--new-version', 'the new release'), ver))
    w('Output of `tools/provenance/upgrade-diff.py`. The old manifest: sha256 `%s`, installer-owned %d, records digest `%s`; '
      'the new: installer-owned %d, records digest `%s`. The target: a folder %s installed fresh -- every installer-owned file '
      'of it at its bytes, every lock row `installed`.%s\n\n' % (hashlib.sha256(raws[0]).hexdigest(), len(old), records_digest(old),
      len(new), records_digest(new), ver,
      ' Revisions read for the fold: `%s` and `%s`.' % (opts['--old-rev'], opts['--new-rev']) if repo else ''))
    w('## The manifests, named by their installer-owned records\n\n')
    w('A records digest is the sha256 of one line per installer-owned record -- its destination, class, sha256, bytes and eol '
      'joined by tabs and ended by LF, an absent field written `None` -- the lines sorted by code point, UTF-8: the fields every '
      'disposition here depends on (class, sha256 and eol decide it) and the bytes install.ps1 holds a source file to. The new '
      'manifest is named by it and not by its file\'s sha256, because a commit that changes only AUTHORED records or reasons -- this document\'s own record among them -- '
      'changes the file and leaves the digest as it is: the digest above is the new manifest\'s at every such later commit, the '
      'one the release tag points to among them. A different digest there is a different plan, and the prediction is made '
      'again. `python -I tools/provenance/upgrade-diff.py --digest <manifest>` prints the digest of any manifest.\n\n')
    w('## The counts\n\n')
    nw = count.get('not-written', 0)
    w('```text\nplanned: written=%d already-identical=%d kept=%d%s retired=%d refused=0\n```\n\n' %
      (written, count.get('already-identical', 0), count.get('kept', 0), (' not-written=%d' % nw) if nw else '', count.get('retired', 0)))
    w('written = installed %d + upgraded-from %s %d. framework.lock after the upgrade: %d lines, the header and one row per '
      'installer-owned file of the new release (%d).\n\n' % (count.get('installed', 0), ver, up, len(new) + 1, len(new)))
    if nw:
        w('not-written is the root `.gitattributes`: install.ps1 writes it on a fresh install only, into a folder that holds no '
          'file a git repository tracks, and an upgrade adds none where the project has none -- a framework install does not '
          'change a project\'s line-ending policy for the project\'s own files. Its lock row reads `not-written`, sha256 and eol '
          'null. Where the project has a `.gitattributes` of its own, it is kept, as any template: kept=%d and no not-written= '
          'there.\n\n' % (count.get('kept', 0) + nw))
    kinds = [r for r in rows if r[1] and r[2] and r[1] != r[2]]
    w('## Kind changes (%d)\n\n' % len(kinds))
    if kinds:
        w('| path | %s | new | disposition |\n|---|---|---|---|\n' % ver)
        for r in kinds:
            w('| `%s` | %s | %s | %s |\n' % (r[0], KIND[r[1]], KIND[r[2]], r[3]))
        w('\n')
    diff = [r[0] for r in rows if r[3] == 'installed' or r[3].startswith('upgraded-from ')] + ['framework.lock']
    w('## The paths a `git diff --stat` on the host names (%d)\n\n' % len(diff))
    w('The upgraded files, the installed ones and `framework.lock` -- the installed ones and an untracked lock once added '
      '(`git add -A`, then `git diff --cached --stat`). Kept, not-written and retired files are not written, and an already-identical one '
      'is left as it stands.\n\n')
    for p in diff:
        w('- `%s`\n' % p)
    w('\n## The fold rule on a CRLF host\n\n')
    w('install.ps1 judges a text file after folding every CR LF to LF, against the lock and against the release alike. On a '
      'host whose checkout has CRLF line endings (`core.autocrlf=true`), an unchanged file therefore reads already-identical '
      'and is not rewritten; a changed one is held to its lock row as install.ps1 holds it (Get-HeldSha256: by its folded '
      'sha256 for a lock that names the fold rule, as 0.1.1 and later write it; for the raw rows of a 0.1.0 lock, by its '
      'raw, folded or CRLF form), so it is upgraded, not refused. The counts above are the same there.%s\n\n' % (
      (' Compared raw, without --repo: ' + ', '.join('`%s`' % p for p in raw_only) + '.') if raw_only else ''))
    w('## Every path (%d)\n\n| path | %s | new | disposition |\n|---|---|---|---|\n' % (len(rows), ver))
    for r in rows:
        w('| `%s` | %s | %s | %s |\n' % (r[0], KIND[r[1]] if r[1] else '--', KIND[r[2]] if r[2] else '--', r[3]))
    data = ''.join(text).encode('utf-8')
    if '--out' in opts:
        open(opts['--out'], 'wb').write(data)
    else:
        sys.stdout.buffer.write(data)

main()
