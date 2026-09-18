call rxfuncadd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
r=.ComponentProjectionRegistry~new
i=.InspectorClouseau~new
ignore=i~reportQueueItems(.true)
ignore=i~dontFollowPackage('TEST*')
ignore=i~createInspectionReportOnSignal('CLASS*','METHOD*','SYNTAX','rc',13,'inspector-signal')
a=.InspectorClouseauComponentProjectionAdapter~new(r,i)
a~install
if r~readObject('/inspector/rules/count')<2 then do; say 'FAIL actual inspector rules'; exit 1; end
if r~readObject('/inspector/state/roots')<>0 then do; say 'FAIL adapter must not auto-seed or walk roots'; exit 1; end
if r~readObject('/inspector/rules/1/kind')='' then do; say 'FAIL actual rule kind'; exit 1; end
d=i~asDirectory; signalIndex=0
do j=1 to d['rules']~items
  rec=d['rules'][j]
  if rec~hasIndex('class_pattern') then do
    if rec['class_pattern']=='CLASS*' then do; signalIndex=j; leave; end
  end
end
if signalIndex=0 then do; say 'FAIL could not locate rich signal rule'; exit 1; end
base='/inspector/rules/'||signalIndex
if r~readObject(base||'/class_pattern')<>'CLASS*' then do; say 'FAIL rich rule class pattern'; exit 1; end
if r~readObject(base||'/condition_variable')<>'rc' then do; say 'FAIL rich rule condition variable'; exit 1; end
if r~readObject(base||'/condition_equals')<>13 then do; say 'FAIL rich rule condition equals'; exit 1; end
if r~readObject(base||'/report_prefix')<>'inspector-signal' then do; say 'FAIL rich rule report prefix'; exit 1; end
say 'PASS Inspector Clouseau actual live-state projection adapter'
exit 0
::requires 'InspectorClouseau.cls'
::requires 'ComponentProjectionInspectorClouseau.cls'
