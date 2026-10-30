/* Queue Fabric worker semantic smoke with fake exact manager surface.
 * This test does not replace current Queue Fabric integration qualification. */
manager=.FakeQueueManager~new
execution=.FakeRepairExecution~new(.true)
worker=.StorageRepairQueueWorker~new(manager,execution,"STORAGE.REPAIR","worker")
r=worker~processOne
call assert r~ok,"successful repair ACKed"
call assert manager~ackCount=1,"ACK called once"
call assert manager~nackCount=0,"NACK not called"
call assert manager~lastToken="token-1","claimed package token preserved"

manager2=.FakeQueueManager~new
execution2=.FakeRepairExecution~new(.false)
worker2=.StorageRepairQueueWorker~new(manager2,execution2,"STORAGE.REPAIR","worker")
r2=worker2~processOne
call assert \r2~ok,"failed repair returned failure"
call assert manager2~ackCount=0,"ACK not called on failure"
call assert manager2~nackCount=1,"NACK called once"
call assert manager2~lastToken="token-1","NACK uses claimed token"
say "PASS Storage repair Queue Fabric worker semantic smoke"
exit 0

assert: procedure
  use strict arg condition,label
  if \condition then do
    say "FAIL" label
    exit 1
  end
  return

::class FakeQueuePackage public
::attribute packageId get
::attribute claimToken get
::attribute payload get
::method init
  expose packageId claimToken payload
  packageId="pkg-1"; claimToken="token-1"; payload=.directory~new
  payload["schema"]=.StorageRepairQueueBuild~WORK_SCHEMA
  payload["kind"]="STORAGE_REPLICA_REPAIR"

::class FakeQueueManager public
::attribute ackCount get
::attribute nackCount get
::attribute lastToken get
::method init
  expose ackCount nackCount lastToken
  ackCount=0; nackCount=0; lastToken=""
::method claim
  use strict arg queueName,principal
  return .QueueOperationResult~success(.FakeQueuePackage~new)
::method ack
  expose ackCount lastToken
  use strict arg queueName,packageId,claimToken,principal
  ackCount+=1; lastToken=claimToken
  return .QueueOperationResult~success(.true)
::method nack
  expose nackCount lastToken
  use strict arg queueName,packageId,claimToken,principal
  nackCount+=1; lastToken=claimToken
  return .QueueOperationResult~success(.true)

::class FakeRepairExecution public
::method init
  expose ok
  use strict arg okArg
  ok=okArg
::method execute
  expose ok
  use strict arg payload
  if ok then return .StorageRepairResult~success("SATISFIED","done")
  return .StorageRepairResult~failure("COPY_FAILED","fixture")

::requires "../src/StorageRepairQueue.cls"
