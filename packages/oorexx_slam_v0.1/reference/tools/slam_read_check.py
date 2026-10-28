#!/usr/bin/env python3
"""Mirror of SLAM v0.1 `readDoc` (bin/slam.rex) so a document can be checked without ooRexx.
Usage: python3 slam_read_check.py CORPUS.csv DOC1 [DOC2 ...]
Docs are read in order, as `rexx slam.rex read DB DOC` would be run once per doc on one database.
A doc with any unknown word adds nothing (SLAM stores nothing from it), exactly as readDoc does.
Rules copied from readDoc:
  - vocabulary = corpus headwords (+ words added by earlier docs)
  - a line starting ``` toggles code; code lines are skipped
  - 'head: tail' is a definition when tail is not empty, head is ONE word, head is all letters
    (datatype M), and head is not known yet; the head becomes known BEFORE the tail is checked
  - every other line: each word must be known; numerals (datatype N) are values, not words
  - cleaning: lower case; these characters become blanks: . , ; : ( ) " ' ? ! # * ` [ ] { } < >
"""
import csv, re, sys
STRIP = '.,;:()"\'?!#*`[]{}<>'
TBL = str.maketrans({c: ' ' for c in STRIP})
NUM = re.compile(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$')
def clean(t): return t.lower().translate(TBL).split()
def is_num(w): return bool(NUM.match(w.strip()))
def read_doc(vocab, path):
    new, unknown, defs = set(), [], 0
    known = lambda w: w in vocab or w in new
    in_code, n, words = False, 0, 0
    for n, line in enumerate(open(path, encoding='utf-8'), 1):
        s = line.rstrip('\n').rstrip('\r').strip()
        if s.startswith('```'): in_code = not in_code; continue
        if in_code: continue
        head, sep, tail = s.partition(':')
        hw = head.split()
        if sep and tail != '' and len(hw) == 1 and head == hw[0] and hw[0].isalpha() and hw[0].isascii() and not known(hw[0].lower()):
            w = hw[0].lower(); new.add(w); defs += 1
            for x in clean(tail):
                if not known(x): unknown.append(f'{n}: {x} (in the definition of {w})')
            continue
        for x in clean(s):
            if is_num(x): continue
            words += 1
            if not known(x): unknown.append(f'{n}: {x}')
    return n, words, defs, new, unknown
def main(argv):
    vocab = set()
    rows = list(csv.reader(open(argv[1], encoding='utf-8')))
    for r in rows[1:]:
        if r and r[0].strip(): vocab.add(r[0].strip().lower())
    ok = True
    for doc in argv[2:]:
        n, words, defs, new, unknown = read_doc(vocab, doc)
        print(f'{doc}: lines {n}  words read {words}  known words {len(vocab)}  new words {defs}')
        if unknown:
            ok = False
            print('  some words here are not words i know:')
            for u in unknown: print('   ', u)
        else:
            vocab |= new
            print('  i know each word here. i can read all of it.')
    return 0 if ok else 1
if __name__ == '__main__': sys.exit(main(sys.argv))
