#!/usr/bin/env python3
from pathlib import Path
root=Path(__file__).resolve().parent
files=sorted(root.glob('test_librarian*.rex'))+[root/'test_algorithm_relation_librarian.rex']
violations=[]
for p in files:
    text=p.read_text()
    if "say 'ASSERT FAILED:'" in text or 'say "ASSERT FAILED:"' in text:
        violations.append(f'{p.name}: print-only ASSERT FAILED remains')
    # Every test which declares AssertTrue must make false conditions raise.
    if '::routine AssertTrue' in text:
        tail=text.split('::routine AssertTrue',1)[1]
        # Limit to the routine before next routine/requires if possible.
        stop=len(tail)
        for marker in ('\n::routine ', '\n::requires '):
            pos=tail.find(marker)
            if pos>=0: stop=min(stop,pos)
        body=tail[:stop]
        if 'raise syntax' not in body:
            violations.append(f'{p.name}: AssertTrue does not raise')
if violations:
    raise SystemExit('\n'.join(violations))
print(f'LIBRARIAN ASSERTION CONTRACT: OK ({len(files)} tests checked)')
