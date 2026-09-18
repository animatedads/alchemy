call rxfuncadd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
r=.ComponentProjectionRegistry~new
i=.FakeInspector~new
a=.InspectorClouseauComponentProjectionAdapter~new(r,i)
a~install
call assertEq 2,r~readObject('/inspector/rules/count'),'rule count'
call assertEq 'REPORT_QUEUE_ITEMS',r~readObject('/inspector/rules/1/kind'),'rule kind'
call assertEq 1,r~readObject('/inspector/findings/count'),'finding count'
call assertEq 3,r~readObject('/inspector/state/roots'),'root count'
call assertEq 1,r~readObject('/inspector/triggers/count'),'trigger count'
call assertEq 0,i~workCalls,'passive reads did not create work'
i~addRuleFake; a~refresh
call assertEq 3,r~readObject('/inspector/rules/count'),'dynamic rule count'
call assertEq 'NEW_RULE',r~readObject('/inspector/rules/3/kind'),'new rule exposed'
call assertEq 0,i~workCalls,'refresh did not create work'
say 'PASS Inspector Clouseau component projection adapter'
exit 0
assertEq: procedure; use arg e,g,m; if e<>g then do; say 'FAIL' m 'expected='e 'got='g; exit 1; end; return

::class FakeInspector
::attribute workCalls get
::method init
  expose d workCalls
  workCalls=0; d=.directory~new; d['schema']='alchemy.oorexx.inspector-clouseau.snapshot.v1'; d['generated_at']='T0'
  roots=.array~of(.directory~new,.directory~new,.directory~new); d['roots']=roots
  d['packages']=.array~of('P'); d['objects']=.array~of('O1','O2'); d['edges']=.array~new; d['queues']=.array~new; d['classes']=.array~of('C'); d['methods']=.array~of('M')
  rules=.array~new
  r=.directory~new; r['kind']='REPORT_QUEUE_ITEMS'; r['pattern']='*'; r['value']=.true; r['enabled']=.true; rules~append(r)
  r=.directory~new; r['kind']='DONT_FOLLOW_PACKAGE'; r['pattern']='X*'; r['value']=.true; r['enabled']=.true; rules~append(r); d['rules']=rules
  f=.directory~new; f['kind']='identity'; d['findings']=.array~of(f); d['warnings']=.array~of('careful')
  t=.directory~new; t['sequence']=1; t['trigger_key']='K'; t['trigger_kind']='method'; t['generated_at']='T1'; d['trigger_events']=.array~of(t)
  d['security_events']=.array~new; d['trace_reports']=.array~new; d['trace_request_events']=.array~new; d['scheduled_snapshot_events']=.array~new
::method asDirectory; expose d; return d
::method snapshot; expose workCalls; workCalls=workCalls+1; return .nil
::method refreshObservation; expose workCalls; workCalls=workCalls+1; return .true
::method addRuleFake
  expose d
  r=.directory~new; r['kind']='NEW_RULE'; r['pattern']='*'; r['value']=1; r['enabled']=.true; d['rules']~append(r)
::requires 'ComponentProjectionInspectorClouseau.cls'
