/* Native ooRexx qualification for additive Storage command service.
 * Run under ooRexx 5.3.0 r13196 when available. */
root=SysTempFileName('/tmp/storage-command-??????')
call SysFileDelete root
call SysMkDir root
source=root||'/source.webm'
call charout source,"00"x||"01"x||"02"x||"ff"x||'Storage Command'
call stream source,'c','close'
service=.StorageCommandService~new(root,'ed209c')
r=service~registerFile(source,'source.webm')
call ok r['ok'],'register source'
object=r['object']
call eq 1,service~objects~items,'one registered object'
call eq 0,.StorageReplicaPolicy~new~durableReplicaCount(object),'unqualified filesystem must not be durable'
found=service~lookup('source.webm')
call ok found['ok'],'lookup by name'
found=service~lookup(source)
call ok found['ok'],'lookup by physical path'
call eq object~ref~objectId,found['object']~ref~objectId,'lookup identity'

/* Authority and catalogue survive process-local object destruction. */
newService=.StorageCommandService~new(root,'ed209c')
call eq 1,newService~snapshot~revision,'snapshot revision'
call eq 1,newService~objects~items,'reloaded catalogue'
found=newService~lookup(object~ref~objectId)
call ok found['ok'],'lookup by digest identity'

/* Two durable replicas must not be asserted by one unqualified file. */
outcome=newService~ensureAzure(object~ref~objectId)
call eq 'GIT_PROVIDER_NOT_CONFIGURED',outcome['code'],'no Azure credentials/provider'

/* Re-register with explicit storage durability evidence. */
qualified=.StorageCommandService~new(root,'ed209c','SAFE','AZURE','ED209C')
r=qualified~registerFile(source)
call ok r['ok'],'qualified re-registration'
call eq 1,.StorageReplicaPolicy~new~durableReplicaCount(r['object']),'qualified local durable copy'

/* Missing mesh connector must fail, not quietly use another transport. */
outcome=qualified~materialise(object~ref~objectId,root||'/target.webm','ed209b')
call eq 'PEER_TRANSPORT_NOT_CONFIGURED',outcome['code'],'mesh connector required'
call ok stream(root||'/target.webm','c','query exists')='','no target on failed materialisation'

say 'PASS Storage command native register/locate/persistence/fail-closed'
exit 0

::routine ok
  use arg value,label
  if \value then do
    say 'FAIL' label
    raise syntax 88.900 array('assertion failed')
  end
::routine eq
  use arg expected,actual,label
  if expected<>actual then do
    say 'FAIL' label 'expected='expected 'actual='actual
    raise syntax 88.900 array('assertion failed')
  end
::requires 'StorageCommand.cls'
