parse source . . me
base=filespec('location',me)'..'
plannerRoot=value('OP_PLANNER_ROOT',,'ENVIRONMENT')
serviceRoot=value('SERVICE_DESCRIPTOR_ROOT',,'ENVIRONMENT')
if plannerRoot='' | serviceRoot='' then do
  say 'SKIP requires OP_PLANNER_ROOT and SERVICE_DESCRIPTOR_ROOT'
  exit 77
end
backend=plannerRoot'/bin/opctl'
capFile='/tmp/storage-cap-pressure-'||random(100000,999999)||'.tsv'
polFile='/tmp/storage-pol-pressure-'||random(100000,999999)||'.tsv'
svcFile='/tmp/storage-svc-pressure-'||random(100000,999999)||'.tsv'
call value 'OPERATIONAL_CAPACITY_FILE',capFile,'ENVIRONMENT'
call value 'OPERATIONAL_POLICY_FILE',polFile,'ENVIRONMENT'

caps=.OperationalCapacityRegistry~new(backend)
caps~set('mi1-mu2.ingress',100000000,100000000)
classes=.OperationalClassRegistry~new(backend)
classes~register('normal.storage','allow:100:allow:any:30:2:60','allow:100:allow:any:25:2:50','allow:100:allow:any:15:1:15','suspend:0:forbid:protected:10:1:10')
planner=.OperationalPlanner~new(backend)
governor=.OperationalCapacityGovernor~new(caps,planner)
services=.ServiceRegistry~new(svcFile)
services~register(.ServiceDescriptor~new('storage.range.read','normal.storage','storage-fabric'))
control=.StorageOperationalFetchControl~new(services,planner)

offers=.array~new
offers~append(.StorageRangeOffer~new('sfu1-mu5','audio1234.mp4',0,100000000,.true,'pressure'))
offers~append(.StorageRangeOffer~new('sfu1-mu7','audio1234.mp4',0,100000000,.true,'pressure'))
plan=control~plan('storage.range.read','audio1234.mp4',0,100000000,'normal',offers)
if plan~slices~items<>2 | plan~effectiveInboundPercent<>60 then do; say 'FAIL plan fan-in'; exit 1; end
if plan~slices[1]~startOffset<>0 | plan~slices[1]~endOffset<>50000000 then do; say 'FAIL slice1'; exit 2; end
if plan~slices[2]~startOffset<>50000000 | plan~slices[2]~endOffset<>100000000 then do; say 'FAIL slice2'; exit 3; end
admission=.StorageCapacityAdmission~new(governor)~admit(plan,'mi1-mu2.ingress')
if admission~tickets~items<>2 then do; say 'FAIL ticket count'; exit 4; end
wire1=.FakeCapacitySocket~new; wire2=.FakeCapacitySocket~new
send1=admission~sender(1,wire1); send2=admission~sender(2,wire2)
if send1~send('abc')<>3 | wire1~lastRate<>30000000 then do; say 'FAIL normal transport rate'; exit 20; end
if send2~send('xyz')<>3 | wire2~lastRate<>30000000 then do; say 'FAIL normal transport rate 2'; exit 21; end
do t over admission~tickets
  if t['PERCENT']<>30 | t['BYTES_PER_SEC']<>30000000 then do; say 'FAIL normal rate'; exit 5; end
end
extra=governor~acquire('normal.storage','normal','mi1-mu2.ingress')
if extra<>.nil then do; say 'FAIL third context admitted'; exit 6; end

caps~set('mi1-mu2.ingress',100000000,50000000)
if \admission~refreshDomain then do; say 'FAIL refresh'; exit 7; end
if send1~send('abc')<>3 | wire1~lastRate<>15000000 then do; say 'FAIL live transport contraction'; exit 22; end
do t over admission~tickets
  if t['BYTES_PER_SEC']<>15000000 then do; say 'FAIL contracted rate'; exit 8; end
end
r=admission~reconcile('constrained')
if governor~activeContexts('normal.storage','mi1-mu2.ingress')<>1 then do; say 'FAIL constrained fan-in'; exit 9; end
active=0; suspended=0
do t over r
  if t['ADMITTED']=1 then do; active+=1; if t['BYTES_PER_SEC']<>7500000 then do; say 'FAIL constrained bps'; exit 10; end; end
  else do; suspended+=1; if t['BYTES_PER_SEC']<>0 then do; say 'FAIL suspended bps'; exit 11; end; end
end
if active<>1 | suspended<>1 then do; say 'FAIL constrained ticket state'; exit 12; end
rc1=send1~send('a'); rc2=send2~send('b')
if rc1=-2 then do
  if rc2=-2 then do; say 'FAIL exactly one constrained sender'; exit 23; end
end
else do
  if rc2<>-2 then do; say 'FAIL exactly one constrained sender'; exit 23; end
end
r=admission~reconcile('emergency')
if governor~activeContexts('normal.storage','mi1-mu2.ingress')<>0 then do; say 'FAIL emergency'; exit 13; end
if send1~send('a')<>-2 | send2~send('b')<>-2 then do; say 'FAIL emergency sender gate'; exit 24; end
caps~set('mi1-mu2.ingress',100000000,100000000)
r=admission~reconcile('normal')
if governor~activeContexts('normal.storage','mi1-mu2.ingress')<>2 then do; say 'FAIL restore fan-in'; exit 14; end
do t over r
  if t['ADMITTED']<>1 | t['BYTES_PER_SEC']<>30000000 then do; say 'FAIL restore rate'; exit 15; end
end
if send1~send('abc')<>3 | wire1~lastRate<>30000000 then do; say 'FAIL restored transport rate'; exit 25; end
if \admission~release then do; say 'FAIL release'; exit 16; end
if governor~activeContexts('normal.storage','mi1-mu2.ingress')<>0 then do; say 'FAIL leak'; exit 17; end

/* Planner/admission churn: 1000 complete range plans and two-source admissions. */
do 1000
  plan=control~plan('storage.range.read','audio1234.mp4',0,100000000,'normal',offers)
  a=.StorageCapacityAdmission~new(governor)~admit(plan,'mi1-mu2.ingress')
  if a~tickets~items<>2 then do; say 'FAIL churn tickets'; exit 18; end
  if \a~release then do; say 'FAIL churn release'; exit 19; end
end
call SysFileDelete capFile
call SysFileDelete polFile
call SysFileDelete svcFile
say 'PASS Storage pressure: two-source 100MB plan, live 60->15->0->60 policy, 1000 admission cycles'
exit 0
::class FakeCapacitySocket public
::attribute lastRate get
::method init
  expose lastRate closed
  lastRate=0; closed=.false
::method capacityRate
  expose lastRate
  use strict arg bps
  lastRate=bps
  return self
::method send
  expose closed
  use strict arg bytes
  if closed then return -1
  return length(bytes)
::method close
  expose closed
  closed=.true
  return 0

::requires "../src/StorageParallelFetch.cls"
::requires "OperationalPlanner.cls"
::requires "ServiceDescriptors.cls"
