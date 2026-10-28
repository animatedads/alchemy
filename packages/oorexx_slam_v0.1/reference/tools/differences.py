#!/usr/bin/env python3
"""Write DIFFERENCES.md from the FILE.md.results.txt reports that run_examples.rex writes.
Usage (from reference/): python3 tools/differences.py"""
import glob, collections
def blocks(L, i):
    out, cur, j = [], None, i + 1
    while len(out) < 3 and j < len(L):
        s = L[j].strip()
        if s.startswith('```'):
            if cur is None: cur = []
            else: out.append(cur); cur = None
        elif cur is not None: cur.append(L[j])
        elif s and s not in ('the result:', 'the reference says:'): break
        j += 1
    return out
tot, sections = collections.Counter(), []
for f in sorted(glob.glob('[0-9][0-9]_*.md')):
    try: rep = [r for r in open(f + '.results.txt').read().split('\n') if r.strip()]
    except FileNotFoundError: continue
    L = open(f, encoding='utf-8').read().split('\n'); rows = []
    for r in rep:
        verdict = r.split(' | ')[0].split(' ', 1)[1]; tot[verdict] += 1
        if verdict != 'DIFFERENT': continue
        ln = int(r.split(':')[1].split()[0]); b = blocks(L, ln - 1)
        if len(b) < 3: continue
        cell = lambda x, n: ' / '.join(y.strip() for y in x if y.strip())[:n].replace('|', '\\|') or ' '
        rows.append(f'| {f}:{ln} | `{cell(b[0], 110)}` | `{cell(b[1], 60)}` | `{cell(b[2], 60)}` |')
    if rows: sections += [f'## {f} ({len(rows)})', '', '| where | code | ooRexx printed | reference says |', '|---|---|---|---|'] + rows + ['']
head = ['# Examples where ooRexx 5.3.0 r13196 does not print what the reference says', '',
        f'Totals over all files: same {tot["SAME"]}, different {tot["DIFFERENT"]}, no reference {tot["NO REFERENCE"]}.', '',
        'Made by `rexx reference/run_examples.rex` (each example run alone, no input, ten seconds) and `tools/differences.py`.',
        'A difference is a lesson, not yet a verdict: it can be an error in the reference, in the rewrite, a page that sets',
        'a variable in its text and not in its code, an example whose output changes from run to run (DATE, TIME, RANDOM),',
        'or a difference between the reference and this interpreter.', '']
open('DIFFERENCES.md', 'w', encoding='utf-8').write('\n'.join(head + sections))
print(dict(tot))
