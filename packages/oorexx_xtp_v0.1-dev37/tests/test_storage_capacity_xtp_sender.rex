parse arg peer plannerRoot serviceRoot
backend=plannerRoot'/bin/opctl'
capFile='/tmp/storage-xtp-cap-'||random(100000,999999)||'.tsv'
polFile='/tmp/storage-xtp-pol-'||random(100000,999999)||'.tsv'
svcFile='/tmp/storage-xtp-svc-'||random(100000,999999)||'.tsv'
call value 'OPERATIONAL_CAPACITY_FILE',capFile,'ENVIRONMENT'
call value 'OPERATIONAL_POLICY_FILE',polFile,'ENVIRONMENT'
cap=.OperationalCapacityRegistry~new(backend)
cap~set('mi1-mu2.ingress',1000000,1000000)
classes=.OperationalClassRegistry~new(backend)
classes~register('normal.storage','allow:100:allow:any:30:2:60','allow:100:allow:any:25:2:50','allow:100:allow:any:15:1:15','suspend:0:forbid:protected:10:1:10')
planner=.OperationalPlanner~new(backend)
governor=.OperationalCapacityGovernor~new(cap,planner)
services=.ServiceRegistry~new(svcFile)
services~register(.ServiceDescriptor~new('storage.range.read','normal.storage','storage-fabric'))
control=.StorageOperationalFetchControl~new(services,planner)
offers=.array~new
offers~append(.StorageRangeOffer~new('sfu1-mu5','audio1234.mp4',0,100000000,.true,'xtp-pressure'))
offers~append(.StorageRangeOffer~new('sfu1-mu7','audio1234.mp4',0,100000000,.true,'xtp-pressure'))
plan=control~plan('storage.range.read','audio1234.mp4',0,100000000,'normal',offers)
admission=.StorageCapacityAdmission~new(governor)~admit(plan,'mi1-mu2.ingress')
addr=.PressureAddress~new(peer)
socket=.XtpProviderSocket~new(addr)~service('storage.range.read')~priority('static',100)
sender=admission~sender(1,socket)
payload='Q'~copies(60000)
call time 'R'
n=sender~send(payload)
first=time('E')
if n<>60000 then do; say 'FAIL first send' n; exit 2; end
if socket~lastResult['CAPACITY_RATE_BPS']<>300000 then do; say 'FAIL first rate' socket~lastResult['CAPACITY_RATE_BPS']; exit 3; end
cap~set('mi1-mu2.ingress',1000000,500000)
if \admission~refreshDomain then do; say 'FAIL refresh'; exit 4; end
call time 'R'
n=sender~send(payload)
second=time('E')
if n<>60000 then do; say 'FAIL second send' n; exit 5; end
if socket~lastResult['CAPACITY_RATE_BPS']<>150000 then do; say 'FAIL second rate' socket~lastResult['CAPACITY_RATE_BPS']; exit 6; end
if first<0.18 | second<0.38 then do; say 'FAIL timings' first second; exit 7; end
ignored=admission~release
call SysFileDelete capFile
call SysFileDelete polFile
call SysFileDelete svcFile
say 'PASS Storage ticket -> XTP named service first='first 'second='second
exit 0
::class PressureAddress public
::method init
  expose peer
  use strict arg p
  peer=p
::method xtpAddress
  expose peer
  return peer
::method multicast
  return .false
::requires "OperationalPlanner.cls"
::requires "ServiceDescriptors.cls"
::requires "StorageParallelFetch.cls"
::requires "XtpSocketProvider.cls"
