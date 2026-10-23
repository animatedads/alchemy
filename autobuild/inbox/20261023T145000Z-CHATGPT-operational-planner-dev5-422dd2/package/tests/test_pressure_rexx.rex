parse source . . me
base=filespec('location',me)'..'
backend=base'/bin/opctl'
capFile='/tmp/opcap-pressure-'||random(100000,999999)||'.tsv'
polFile='/tmp/oppol-pressure-'||random(100000,999999)||'.tsv'
call value 'OPERATIONAL_CAPACITY_FILE',capFile,'ENVIRONMENT'
call value 'OPERATIONAL_POLICY_FILE',polFile,'ENVIRONMENT'
cap=.OperationalCapacityRegistry~new(backend)
cap~set('mi1-mu2.ingress',100000000,100000000)
cls=.OperationalClassRegistry~new(backend)
cls~register('normal.storage','allow:100:allow:any:30:2:60','allow:100:allow:any:25:2:50','allow:100:allow:any:15:1:15','suspend:0:forbid:protected:10:1:10')
planner=.OperationalPlanner~new(backend)
g=.OperationalCapacityGovernor~new(cap,planner)
a=g~acquire('normal.storage','normal','mi1-mu2.ingress')
b=g~acquire('normal.storage','normal','mi1-mu2.ingress')
if a==.nil | b==.nil then do; say 'FAIL initial admission'; exit 1; end
cap~set('mi1-mu2.ingress',100000000,50000000)
if \g~refreshDomain('mi1-mu2.ingress') then do; say 'FAIL refresh'; exit 2; end
if g~ticket(a['ID'])['BYTES_PER_SEC']<>15000000 | g~ticket(b['ID'])['BYTES_PER_SEC']<>15000000 then do; say 'FAIL live capacity contraction'; exit 3; end
r=g~reconcile('normal.storage','constrained','mi1-mu2.ingress')
if g~activeContexts('normal.storage','mi1-mu2.ingress')<>1 | g~activePercent('normal.storage','mi1-mu2.ingress')<>15 then do; say 'FAIL constrained reconcile'; exit 4; end
r=g~reconcile('normal.storage','emergency','mi1-mu2.ingress')
if g~activeContexts('normal.storage','mi1-mu2.ingress')<>0 then do; say 'FAIL emergency suspend'; exit 5; end
cap~set('mi1-mu2.ingress',100000000,100000000)
r=g~reconcile('normal.storage','normal','mi1-mu2.ingress')
if g~activeContexts('normal.storage','mi1-mu2.ingress')<>2 | g~activePercent('normal.storage','mi1-mu2.ingress')<>60 then do; say 'FAIL normal restore'; exit 6; end
do 5000
  ignored=g~release(a['ID']); ignored=g~release(b['ID'])
  a=g~acquire('normal.storage','normal','mi1-mu2.ingress')
  b=g~acquire('normal.storage','normal','mi1-mu2.ingress')
  c=g~acquire('normal.storage','normal','mi1-mu2.ingress')
  if a==.nil | b==.nil | c<>.nil then do; say 'FAIL pressure admission'; exit 7; end
end
ignored=g~release(a['ID']); ignored=g~release(b['ID'])
if g~activeContexts('normal.storage','mi1-mu2.ingress')<>0 then do; say 'FAIL pressure leak'; exit 8; end
call SysFileDelete capFile
call SysFileDelete polFile
say 'PASS ooRexx pressure: live contraction/state reconciliation/5000 fan-in cycles'
exit 0
::requires "../rexx/OperationalPlanner.cls"
