call rxfuncadd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
r=.ComponentProjectionRegistry~new
s=.FakeSource~new
ignore=r~registerReport('Demo','/demo/a',s,'a','text/plain','A value')
ignore=r~registerControl('Demo','/demo/c',s,'c','text/plain','control',.false,1024)
n=.ComponentProjectionNoSQLAdapter~new(r,'cp_')
e=n~buildEngine
et=e~table('cp_endpoints'); vt=e~table('cp_values')
call assertEq 2,et~rowCount,'endpoint rows'
call assertEq 1,vt~rowCount,'readable value rows'
rows=vt~readRows; row=rows[1]
call assertEq '/demo/a',row~path,'value path'
call assertTrue pos('42',row~valueText)=1,'value text'
f=.FakeFederated~new
call assertTrue n~snapshotInto(f),'snapshot into'
call assertEq 2,f~names~items,'two snapshots'
say 'PASS component projection NoSQL renderer'
exit 0
assertEq: procedure; use arg e,g,m; if e<>g then do; say 'FAIL' m e g; exit 1; end; return
assertTrue: procedure; use arg v,m; if \v then do; say 'FAIL' m; exit 1; end; return
::class FakeSource subclass ComponentProjectionSource
::method read; use strict arg key; if key='a' then return 42; return .nil
::method write; use strict arg key,v; return .true
::class FakeFederated
::attribute names get
::method init; expose names; names=.array~new
::method registerSnapshot; expose names; use strict arg name,c,m; names~append(name); return .true
::requires 'ComponentProjectionNoSQL.cls'
