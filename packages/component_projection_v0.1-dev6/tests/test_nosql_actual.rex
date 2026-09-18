call rxfuncadd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
r=.ComponentProjectionRegistry~new
s=.FakeSource~new
ignore=r~registerReport('Demo','/demo/a',s,'a','text/plain','A value')
ignore=r~registerControl('Demo','/demo/c',s,'c','text/plain','control',.false,1024)
n=.ComponentProjectionNoSQLAdapter~new(r,'cp_')
e=n~buildEngine
et=e~table('cp_endpoints'); vt=e~table('cp_values')
call assertTrue et~isSnapshot,'endpoint table must be a real NoSQL snapshot'
call assertTrue vt~isSnapshot,'value table must be a real NoSQL snapshot'
call assertEq 2,et~rowCount,'endpoint row count'
call assertEq 1,vt~rowCount,'value row count'
rows=vt~readRows
call assertEq '/demo/a',rows[1]['path'],'value path'
call assertEq '42',rows[1]['value_text'],'value text'
s~value=99
rows=vt~readRows
call assertEq '42',rows[1]['value_text'],'snapshot remains frozen'
e2=n~buildEngine
rows2=e2~table('cp_values')~readRows
call assertEq '99',rows2[1]['value_text'],'new snapshot sees current value'
say 'PASS component projection NoSQLServer v0.79 actual snapshot renderer'
exit 0
assertEq: procedure; use arg e,g,m; if e<>g then do; say 'FAIL' m 'expected='e 'got='g; exit 1; end; return
assertTrue: procedure; use arg v,m; if \v then do; say 'FAIL' m; exit 1; end; return
::class FakeSource subclass ComponentProjectionSource
::attribute value
::method init; self~value=42
::method read; use strict arg key; if key='a' then return self~value; return .nil
::method write; use strict arg key,v; return .true
::requires 'ComponentProjectionNoSQL.cls'
