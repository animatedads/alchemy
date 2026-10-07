call addWith "../src"
call addWith "../build"
numeric digits 20

bag=.MemoryBlockBag~new("mu-bag-life","MU-1","./memory-block-life.bin",8388608,2097152,12,.true)
a1=bag~attachMI("MI-A",3)
a2=bag~attachMI("MI-B",9)
call assert bag~validateAttachment(a1), "MI-A attached"
call assert bag~validateAttachment(a2), "MI-B attached"
h=bag~allocate(1,"CHECKPOINTED","checkpoint://bag/1")
call assert h<>.nil, "active bag allocates"
call assert bag~writeBytesFor(a1,h,"MI-A-large-block")=16, "MI-A attachment gates native write"
call assert bag~readBytesFor(a2,h,16)="MI-A-large-block", "MI-B attachment sees same MU block"

call assert bag~transitionLifecycle("DRAINING"), "bag draining"
call assert bag~allocate(1)=.nil, "draining bag refuses new allocations"
call assert bag~validate(h), "draining retains existing block"
call assert bag~validateAttachment(a1), "draining retains MI attachment"

call assert bag~transitionLifecycle("OFFLINE"), "bag offline"
call assert \bag~validateAttachment(a1), "offline attachment cannot access"
call assert bag~readBytesFor(a1,h,16)=.nil, "offline MI access rejected"
call assert bag~allocate(1)=.nil, "offline bag refuses allocation"

newEpoch=bag~advanceOwnerEpoch("ACTIVE","ACCEPTING")
call assert newEpoch=13, "bag incarnation advances owner epoch"
call assert \bag~validate(h), "old block handle fenced by owner epoch"
call assert \bag~validateAttachment(a2), "old MI attachment fenced"
call assert bag~readBytesFor(a2,h,16)=.nil, "stale MI lease cannot use old block"
a3=bag~attachMI("MI-A",4)
call assert bag~validateAttachment(a3), "MI reattaches to new bag epoch"
h2=bag~allocate(1,"RECONSTRUCTABLE","storage://bag/2")
call assert h2<>.nil, "new incarnation allocates"
call assert h2~ownerEpoch=13, "new block carries new bag epoch"

call assert bag~close, "close bag"
call SysFileDelete "./memory-block-life.bin"
say "PASS memory block lifecycle + MI attachment fencing"
exit 0

addWith: procedure
  parse arg p
  current=value("REXX_PATH",,"ENVIRONMENT")
  if current="" then call value "REXX_PATH",p,"ENVIRONMENT"
  else call value "REXX_PATH",p||":"||current,"ENVIRONMENT"
  return

assert: procedure
  parse arg condition, label
  if condition then return
  say "FAIL:" label
  exit 99

::requires "MemoryFabricMemoryBlock.cls"
