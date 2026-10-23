root=filespec('location',sourceLine(1))
parse source . . me
base=filespec('location',me)'..'
backend=base'/bin/opctl'
capFile='/tmp/opcap-rexx-'||random(100000,999999)||'.tsv'
polFile='/tmp/oppol-rexx-'||random(100000,999999)||'.tsv'
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
c=g~acquire('normal.storage','normal','mi1-mu2.ingress')
if a==.nil | b==.nil | c<>.nil then do; say 'FAIL admission'; exit 1; end
if a['PERCENT']<>30 | a['BYTES_PER_SEC']<>30000000 then do; say 'FAIL rate'; exit 2; end
if \g~release(a['ID']) then do; say 'FAIL release'; exit 3; end
d=g~acquire('normal.storage','normal','mi1-mu2.ingress')
if d==.nil then do; say 'FAIL reacquire'; exit 4; end
call SysFileDelete capFile
call SysFileDelete polFile
say 'PASS ooRexx operational capacity domain governor'
exit 0
::requires "../rexx/OperationalPlanner.cls"
