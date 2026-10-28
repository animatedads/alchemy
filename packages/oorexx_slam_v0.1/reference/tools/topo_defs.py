"""Reorder 'word: definition' lines so each definition uses only words known before it (stable).
Usage: python3 topo_defs.py CORPUS.csv PRIOR_DOCS... -- DOC   (rewrites DOC's definition lines in place order)"""
import sys, csv, re
sys.path.insert(0, __import__('os').path.dirname(__file__))
from slam_read_check import clean, is_num, read_doc
args = sys.argv[1:]; k = args.index('--'); corpus, priors, doc = args[0], args[1:k], args[k+1]
vocab = {r[0].strip().lower() for r in list(csv.reader(open(corpus)))[1:] if r and r[0].strip()}
for p in priors:
    n, w, d, new, unk = read_doc(vocab, p); assert not unk, (p, unk[:5]); vocab |= new
lines = open(doc).read().split('\n')
defre = re.compile(r'^([A-Za-z]+):(.+)$')
defs = [(i, defre.match(l)) for i, l in enumerate(lines) if defre.match(l.strip()) and l.strip().split(':')[0].lower() not in vocab]
heads = {m.group(1).lower() for _, m in defs}
pending = [(m.group(1).lower(), lines[i]) for i, m in defs]
known = set(vocab); out = []
while pending:
    progress = False
    for j, (h, l) in enumerate(pending):
        need = {x for x in clean(l.split(':', 1)[1]) if x != h}
        if need <= known:
            out.append(l); known.add(h); pending.pop(j); progress = True; break
    if not progress:
        for h, l in pending:
            need = {x for x in clean(l.split(':', 1)[1]) if x != h} - known
            print('BLOCKED', h, '->', sorted(need))
        sys.exit(1)
# put sorted defs back into the slots the definitions had, in the new order
slots = [i for i, _ in defs]
for i, l in zip(slots, out): lines[i] = l
open(doc, 'w').write('\n'.join(lines))
print('ok', len(out))
