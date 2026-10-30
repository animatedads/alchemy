from pathlib import Path
p=Path(__file__).resolve().parents[1]/'docs'/'MODULE_STACK.md'
s=p.read_text()
required=['WireApplicationModel','WireFilterWindow','JavaScript Alchemy dev23','QuickJS-NG 0.17.0','Prolog Alchemy dev13','SWI-Prolog 10.0.2','Renderer ABI 4','WireLanguageBlock','rexx_send/4','UIDVALIDITY']
for x in required:
    assert x in s, x
assert 'predicate receives candidates but no source/pull handle' in s
assert 'explicit relational operation' in s
print('PASS module stack graph: layers, providers and authority boundaries documented')
