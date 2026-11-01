# The manifest as the law of the tree, read at a COMMIT (default HEAD) -- read-only.
# usage: python -I tools/provenance/tree-law.py [<repo>] [<rev>]      (<repo> defaults to the checkout this file is in)
# Checks: every blob tracked at <rev> has exactly one manifest line whose destination is its path and whose
# sha256/bytes equal the blob's; the manifest's own line exists, AUTHORED, with sha256 null; every manifest line
# with a destination names a tracked path. Prints the class census, the installer-owned set by kind (the set
# install.ps1 derives: source host, class MOVE, TEMPLATE or HOST-CONFIG, a destination), the AUTHORED lines,
# and TREE-LAW: OK or TREE-LAW: FAIL (exit 1) after the faults.
import hashlib, json, os, subprocess, sys

OWNED_SOURCE = 'host'
OWNED_CLASSES = ('MOVE', 'TEMPLATE', 'HOST-CONFIG')

def main():
    repo = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
    rev = sys.argv[2] if len(sys.argv) > 2 else 'HEAD'
    ls = subprocess.run(['git', '-C', repo, 'ls-tree', '-r', '-z', '--full-tree', rev], capture_output=True, check=True).stdout
    tracked = {}
    for ent in ls.split(b'\0'):
        if not ent:
            continue
        meta, path = ent.split(b'\t', 1)
        mode, typ, sha = meta.split(b' ')
        if typ != b'blob':
            sys.exit('non-blob entry ' + path.decode())
        tracked[path.decode('utf-8')] = sha.decode()
    cat = subprocess.Popen(['git', '-C', repo, 'cat-file', '--batch'], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    def blob(sha):
        cat.stdin.write((sha + '\n').encode()); cat.stdin.flush()
        head = cat.stdout.readline().split()
        size = int(head[2])
        data = cat.stdout.read(size)
        cat.stdout.read(1)
        return data
    mraw = blob(tracked['provenance/manifest.jsonl'])
    lines = mraw.decode('utf-8').split('\n')
    if lines[-1] != '':
        sys.exit('manifest at rev does not end with LF')
    lines = lines[:-1]
    recs = [json.loads(l) for l in lines[1:]]
    bydest = {}
    faults = []
    for r in recs:
        d = r.get('destination')
        if d is None:
            continue
        if d in bydest:
            faults.append('duplicate destination ' + d)
        bydest[d] = r
    for p, sha in sorted(tracked.items()):
        r = bydest.get(p)
        if r is None:
            faults.append('TRACKED WITHOUT A MANIFEST LINE: ' + p)
            continue
        if p == 'provenance/manifest.jsonl':
            if r.get('sha256') is not None or r.get('class') != 'AUTHORED':
                faults.append("the manifest's own line must be AUTHORED with sha256 null")
            continue
        b = blob(sha)
        h = hashlib.sha256(b).hexdigest()
        if r.get('sha256') != h or r.get('bytes') != len(b):
            faults.append('MISMATCH %s manifest=%s/%s blob=%s/%d' % (p, r.get('sha256'), r.get('bytes'), h, len(b)))
    for d in sorted(bydest):
        if d not in tracked:
            faults.append('MANIFEST LINE WITHOUT A TRACKED FILE: ' + d)
    cat.stdin.close(); cat.wait()
    census = {}
    for r in recs:
        k = '%s|%s|%s' % (r.get('source'), r.get('class'), 'dest' if r.get('destination') is not None else 'null')
        census[k] = census.get(k, 0) + 1
    owned = [r for r in recs if r.get('source') == OWNED_SOURCE and r.get('class') in OWNED_CLASSES and r.get('destination') is not None]
    authored = [r for r in recs if r.get('class') == 'AUTHORED']
    print('rev: %s' % subprocess.run(['git', '-C', repo, 'rev-parse', rev], capture_output=True, text=True).stdout.strip())
    print('tracked blobs: %d   manifest records: %d   manifest sha256 at rev: %s' % (len(tracked), len(recs), hashlib.sha256(mraw).hexdigest()))
    for k in sorted(census):
        print('  %4d %s' % (census[k], k))
    print('installer-owned: %d (MOVE %d, TEMPLATE %d, HOST-CONFIG %d)' % (len(owned), sum(1 for r in owned if r['class'] == 'MOVE'), sum(1 for r in owned if r['class'] == 'TEMPLATE'), sum(1 for r in owned if r['class'] == 'HOST-CONFIG')))
    print('AUTHORED: %d' % len(authored))
    for r in authored:
        print('  AUTHORED %s sha256=%s bytes=%s eol=%s' % (r['path'], r.get('sha256'), r.get('bytes'), r.get('eol')))
    if faults:
        print('FAULTS: %d' % len(faults))
        for f in faults:
            print('  ' + f)
        print('TREE-LAW: FAIL (%d fault(s))' % len(faults))
        sys.exit(1)
    print('TREE-LAW: OK (every tracked file has its manifest line; every manifest destination is tracked)')

main()
