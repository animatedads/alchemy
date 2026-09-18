from pathlib import Path
p=Path(__file__).resolve().parents[1]/'rexx'/'AlchemyJavaScriptObject.cls'
s=p.read_text()
need=[
 'projectJavaScriptSelector public',
 'installJavaScriptRexxOverride public',
 'removeJavaScriptRexxOverride public',
 '__javascriptDispatchProjected private unguarded',
 'return self~nativeInvoke(name, arguments)',
 'javascriptProjectionState public',
]
for x in need:
    assert x in s, x
assert s.count('self~setMethod(name, trampoline, "OBJECT")') == 1
dispatch=s.split('::method __javascriptDispatchProjected',1)[1].split('::method javascriptProjectionState',1)[0]
assert '~setMethod(' not in dispatch
ov=s.split('::method installJavaScriptRexxOverride',1)[1].split('::method removeJavaScriptRexxOverride',1)[0]
assert 'self~setMethod(alias, methodObject, "OBJECT")' in ov
assert 'self~setMethod(name, methodObject' not in ov
print('cooperative-interposition-contract=PASS')
