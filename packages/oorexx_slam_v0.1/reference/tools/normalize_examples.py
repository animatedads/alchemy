#!/usr/bin/env python3
"""Three fixes to examples, each from the reference's own text, before they are run:
1. A reference result `.true` / `.false` for a SAY becomes 1 / 0 (what SAY prints for those objects).
2. A SAY whose reference result is a hex string 'hh'x becomes say c2x(...), and the reference the hex digits.
3. An example that uses a variable an earlier example of the same subject set (a line `name = ...` in that
   earlier example) gets those setup lines first, marked /* setup from the example before */.
Result blocks are set back to `not run`: run_examples.rex fills them again.
Usage: python3 tools/normalize_examples.py FILE.md ..."""
import re, sys
ASSIGN = re.compile(r'^\s*([A-Za-z_!?][\w.!?]*)\s*=(?!=)')
SAYX = re.compile(r'^(\s*)[Ss][Aa][Yy]\s+(.*?)(\s*/\*.*\*/)?\s*$')
def blocks_after(L, i):
    """indexes (open, close) of the next fenced block after line i, skipping blanks; None if a text line comes first"""
    j = i + 1
    while j < len(L) and not L[j].strip(): j += 1
    if j >= len(L) or not L[j].strip().startswith('```'): return None
    k = j + 1
    while k < len(L) and not L[k].strip().startswith('```'): k += 1
    return (j, k) if k < len(L) else None
def run(path):
    L = open(path, encoding='utf-8').read().split('\n')
    setup = {}; changed = 0; i = 0; prev_blank = True
    while i < len(L):
        s = L[i].strip()
        if s.startswith('```') and prev_blank:          # a new subject: forget the setup lines
            setup = {}
        if s == 'the code:':
            cb = blocks_after(L, i)
            if cb:
                code = L[cb[0]+1:cb[1]]
                j = cb[1] + 1
                while j < len(L) and not L[j].strip(): j += 1
                rb = blocks_after(L, j) if j < len(L) and L[j].strip() == 'the result:' else None
                ref = None
                if rb:
                    m = rb[1] + 1
                    while m < len(L) and not L[m].strip(): m += 1
                    if m < len(L) and L[m].strip() == 'the reference says:': ref = blocks_after(L, m)
                last = code[-1] if code else ''
                sm = SAYX.match(last)
                new_code = list(code)
                new_ref = L[ref[0]+1:ref[1]] if ref else None
                if sm and new_ref and len(new_ref) == 1:
                    r = new_ref[0].strip()
                    if r in ('.true', '.false'): new_ref = ['1' if r == '.true' else '0']
                    hx = re.fullmatch(r'([\'"])([0-9A-Fa-f ]*)\1[xX]', r)
                    if hx and not sm.group(2).lower().startswith('c2x('):
                        new_code[-1] = sm.group(1) + 'say c2x(' + sm.group(2) + ')' + (sm.group(3) or '')
                        new_ref = [hx.group(2).replace(' ', '').upper()]
                own = {ASSIGN.match(c).group(1).lower() for c in code if ASSIGN.match(c)}
                text = ' '.join(code).lower()
                need = [v for v in setup if v not in own and re.search(r'(?<![\w.])' + re.escape(v) + r'(?![\w])', text)]
                if need and not any('/* setup from the example before */' in c for c in code):
                    lines = []
                    for v in need:
                        for c in setup[v]:
                            if c not in lines: lines.append(c)
                    new_code = [c.rstrip() + '  /* setup from the example before */' for c in lines] + new_code
                for c in code:
                    m2 = ASSIGN.match(c)
                    if m2 and '/* setup from the example before */' not in c:
                        setup[m2.group(1).lower()] = [c.split('/* setup')[0].rstrip()]
                if new_code != code or (ref and new_ref != L[ref[0]+1:ref[1]]):
                    changed += 1
                    if ref: L[ref[0]+1:ref[1]] = new_ref
                    L[rb[0]+1:rb[1]] = ['not run']
                    L[cb[0]+1:cb[1]] = new_code
                i += 1; prev_blank = False; continue
        prev_blank = (s == '' or s.startswith('#'))
        i += 1
    open(path, 'w', encoding='utf-8').write('\n'.join(L))
    print(path, 'examples changed', changed)
for p in sys.argv[1:]: run(p)
