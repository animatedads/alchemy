call addpath
mesh=.FakePeerMesh~new
c=.StoragePeerQueueRexxBinding~bindClient(mesh,"B","A")
call ok c~ok,"client route binds"
call ok mesh~lastService="STORAGE.REQUEST.A","client service id"
call ok mesh~lastSecurity="STORAGE","Storage security domain"
s=.StoragePeerQueueRexxBinding~bindServer(mesh,"A","A",.StoragePeerService~new("B"))
call ok s~ok,"server route binds"
call ok mesh~lastService="STORAGE.REPLY.A","server service id"
say "PASS Storage peer QueueRexx service-route adapter contract"
exit 0
ok: procedure
  parse arg truth,label
  if truth then return
  say "FAIL" label
  exit 1
addpath:
  here=directory()
  call value "REXX_PATH",here||"/src"||":"||value("REXX_PATH",,"ENVIRONMENT"),"ENVIRONMENT"
  return
::class FakeResult public
::attribute ok get
::attribute value get
::method init
  expose ok value
  use strict arg v
  ok=.true; value=v
::class FakeQueueManager public
::method grant
  return .FakeResult~new(.true)
::class FakeChannels public
::method queueManager
  return .FakeQueueManager~new
::class FakePeerMesh public
::attribute lastService get
::attribute lastSecurity get
::method init
  expose qm ch
  qm=.FakeQueueManager~new; ch=.FakeChannels~new
::method queueManager
  expose qm
  return qm
::method channels
  expose ch
  return ch
::method listener
  return .nil
::method adminPrincipal
  return "queue-admin"
::method bindServiceRoute
  expose lastService lastSecurity
  use strict arg peer,service,local,remote,security,principal="queue-admin"
  lastService=service; lastSecurity=security
  d=.directory~new; d["remote_alias"]="REMOTE"; d["sender_channel"]="SEND"; d["local_queue"]=local
  return .FakeResult~new(d)
::requires "StoragePeer.cls"