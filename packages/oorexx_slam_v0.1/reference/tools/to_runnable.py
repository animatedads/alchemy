#!/usr/bin/env python3
"""Rewrite every `/* examples */` block of a SLAM fact file into Tom's runnable example form:

the code:
```rexx
<one or more ooRexx lines; for a value example the last line is a SAY>
```
the result:
```
not run
```
the reference says:
```
<what the reference says that code gives>
```

Nothing here was run: ooRexx is not in the container that wrote these files, so every result block is
`not run`. `the reference says` keeps the reference's own stated result so a checker that runs the code can
compare. Rules, per example line `code -> stated`:
  - stated is a quoted string            -> it is unquoted (doubled quotes undone): that is what SAY prints
  - stated is a hex string 'hh'x          -> the code becomes say c2x(<expr>), stated becomes the hex digits
  - a /* comment */ after stated          -> it moves to the end of the code line
  - code starts with SAY                  -> kept as it is
  - in VALUE files (functions, methods, numbers) an expression with a one-token or quoted stated result
    gets `say ` in front; anything else keeps its code and is not a SAY (a checker should not compare it)
  - lines with no -> before an arrow line are part of that example's code; lines after the last arrow
    become one example with no stated result
Usage: python3 tools/to_runnable.py FILE [--value]   (rewrites FILE in place)"""
import re, sys
KEYWORDS = ('say ', 'call ', 'do ', 'loop ', 'parse ', 'if ', 'signal ', 'address ', 'drop ', 'exit', 'return',
            'select', 'use ', 'trace', 'numeric ', 'interpret ', 'push ', 'queue ', 'pull', 'arg ', 'raise ', 'end')
def split_arrow(line):
    q = None
    for i, ch in enumerate(line):
        if q:
            if ch == q: q = None
            continue
        if ch in '"\'': q = ch; continue
        if line.startswith('/*', i):
            j = line.find('*/', i + 2)
            if j < 0: return None
            # skip comment
            return split_arrow_from(line, i, j + 2)
        if line.startswith('->', i): return line[:i], line[i + 2:]
    return None
def split_arrow_from(line, start, after):
    rest = split_arrow(line[after:])
    if rest is None: return None
    return line[:after] + rest[0], rest[1]
def unquote(s):
    if len(s) >= 2 and s[0] == s[-1] and s[0] in '"\'':
        return s[1:-1].replace(s[0] * 2, s[0])
    return None
def convert_item(code_lines, stated, value_file):
    comment = ''
    if stated is not None:
        m = re.match(r'^(.*?)\s*(/\*.*\*/)\s*$', stated)
        if m and m.group(1).strip(): stated, comment = m.group(1), m.group(2)
        stated = stated.strip()
    last = code_lines[-1].rstrip() if code_lines else ''
    is_say = last.strip().lower().startswith('say ')
    expected = None
    if stated is not None:
        hx = re.match(r'^([\'"])([0-9A-Fa-f ]*)\1[xX]$', stated)
        uq = unquote(stated)
        if hx and not is_say and value_file and not last.strip().lower().startswith(KEYWORDS):
            code_lines[-1] = 'say c2x(' + last.strip() + ')'
            expected = hx.group(2).replace(' ', '').upper(); is_say = True
        else:
            expected = uq if uq is not None else stated
            one_token = uq is not None or len(stated.split()) <= 1
            if (not is_say and value_file and one_token and last.strip()
                    and not last.strip().lower().startswith(KEYWORDS) and not re.match(r'^[\w.]+\s*=[^=]', last.strip())):
                code_lines[-1] = 'say ' + last.strip(); is_say = True
    if comment: code_lines[-1] = code_lines[-1].rstrip() + '  ' + comment
    out = ['the code:', '```rexx'] + code_lines + ['```', 'the result:', '```', 'not run', '```']
    if expected is not None:
        out += ['the reference says:', '```', expected, '```']
    return out + ['']
def convert_block(lines, value_file):
    items, cur = [], []
    for l in lines:
        sp = split_arrow(l)
        if sp is None:
            cur.append(l.rstrip()); continue
        code, stated = sp[0].rstrip(), sp[1]
        if code.strip(): cur.append(code)
        while cur and not cur[0].strip(): cur.pop(0)
        if not cur: continue  # an arrow with no code at all
        items.append((cur, stated)); cur = []
    while cur and not cur[-1].strip(): cur.pop()
    if cur and any(x.strip() for x in cur): items.append((cur, None))
    out = []
    for c, s in items: out += convert_item(list(c), s, value_file)
    return out
def main(path, value_file):
    src = open(path, encoding='utf-8').read().split('\n')
    out, i, n = [], 0, 0
    while i < len(src):
        if src[i].strip().startswith('```') and i + 1 < len(src) and src[i + 1].strip().lower().startswith('/* examples */'):
            j = i + 2; body = []
            while j < len(src) and not src[j].strip().startswith('```'): body.append(src[j]); j += 1
            out += convert_block(body, value_file); n += 1; i = j + 1
            if i < len(src) and src[i].strip() == '' and out and out[-1] == '': i += 1
            continue
        out.append(src[i]); i += 1
    open(path, 'w', encoding='utf-8').write('\n'.join(out))
    print(path, 'example blocks', n)
if __name__ == '__main__': main(sys.argv[1], '--value' in sys.argv[2:])
