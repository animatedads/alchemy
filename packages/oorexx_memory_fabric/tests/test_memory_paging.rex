call addWith "../src"
call addWith "../build"
numeric digits 20

bag=.MemoryBlockBag~new("mu-paging-bag","MU-1","./memory-paging.bin",16777216,2097152,20,.true)
a1=bag~attachMI("MI-A",1)
call assert a1<>.nil, "MI-A epoch 1 attaches"
space=.MemoryFabricPagingSpace~new("RexxOS-space-A","MI-A",1,bag,a1)

g1=space~registerGroup("heap-hot",32,"CHECKPOINTED","checkpoint://rexxos/heap-hot")
call assert g1<>.nil, "page group registered"
call assert g1~pageCount=1, "small logical group occupies one large page"
call assert g1~residency="RESIDENT", "new group resident"
call assert g1~dirty, "new group starts dirty"

call assert space~pin("heap-hot")=1, "pin group"
call assert space~prepareSwapOut("heap-hot")=.nil, "pinned group cannot swap out"
call assert space~unpin("heap-hot"), "unpin group"

stalePlan=space~prepareSwapOut("heap-hot")
call assert stalePlan<>.nil, "dirty swap-out plan created"
call assert stalePlan~kind="SWAP_OUT", "dirty group requires transfer"
call assert stalePlan~transferRequired, "dirty transfer marked required"
call assert space~pin("heap-hot")=1, "state change after planning"
call assert space~commitSwapOut(stalePlan)=.nil, "group generation fences stale plan"
call assert space~unpin("heap-hot"), "unpin after stale plan probe"

payload1="0123456789ABCDEF0123456789ABCDEF"
r1=space~swapOutBytes("heap-hot",payload1)
call assert r1<>.nil, "qualification swap-out commits"
call assert r1~operation="SWAP_OUT", "swap-out receipt operation"
call assert g1~residency="SWAPPED", "group becomes swapped"
call assert \g1~dirty, "swap-out leaves clean backing"
call assert g1~backingHandle<>.nil, "MU backing handle retained"

in1=space~swapInBytes("heap-hot")
call assert in1<>.nil, "qualification swap-in succeeds"
call assert in1["bytes"]=payload1, "swap-in returns exact bytes"
call assert in1["receipt"]~operation="SWAP_IN", "swap-in receipt"
call assert g1~residency="RESIDENT", "group resident after swap-in"
call assert \g1~dirty, "restored group is clean against backing"

cleanPlan=space~prepareSwapOut("heap-hot")
call assert cleanPlan<>.nil, "clean eviction plan created"
call assert cleanPlan~kind="EVICT_CLEAN", "clean backed page evicts without rewrite"
call assert \cleanPlan~transferRequired, "clean eviction requires no payload transfer"
r2=space~commitSwapOut(cleanPlan)
call assert r2<>.nil, "clean eviction commits"
call assert g1~residency="SWAPPED", "clean group reclaimed to backing"

in2=space~swapInBytes("heap-hot")
call assert in2["bytes"]=payload1, "clean backing still contains original bytes"
call assert space~markDirty("heap-hot"), "resident page can become dirty"
payload2="FEDCBA9876543210FEDCBA9876543210"
r3=space~swapOutBytes("heap-hot",payload2)
call assert r3<>.nil, "dirty page rewritten to existing MU backing"
call assert r3~operation="SWAP_OUT", "dirty rewrite receipt"

/* Additional groups prove restart obligation projection. */
g2=space~registerGroup("rebuildable",64,"RECONSTRUCTABLE","storage://objects/42")
g3=space~registerGroup("checkpoint-only",64,"CHECKPOINTED","checkpoint://rexxos/cp-9")
call assert g2<>.nil & g3<>.nil, "restart recovery groups registered"

oldInPlan=space~prepareSwapIn("heap-hot")
call assert oldInPlan<>.nil, "pre-restart swap-in plan exists"
a2=bag~attachMI("MI-A",2)
call assert a2<>.nil, "MI-A epoch 2 attaches"
call assert space~rebindMI(2,a2), "paging space rebinds after MI restart"
call assert \bag~validateAttachment(a1), "old MI attachment detached on restart"
call assert \space~validatePlan(oldInPlan), "space epoch fences in-flight old MI plan"
call assert g1~ownerMiEpoch=2, "logical group ownership rebased to MI epoch 2"

obs=space~restartObligations
call assert obligation(obs,"heap-hot")="RESTORE_FROM_MU_BACKING", "swapped page survives via MU backing"
call assert obligation(obs,"rebuildable")="RECONSTRUCT_FROM_REFERENCE", "dirty resident rebuildable page uses reconstruction"
call assert obligation(obs,"checkpoint-only")="RESTORE_CHECKPOINT", "dirty resident checkpointed page uses checkpoint"

/* MU bag reincarnation fences the old backing, so the checkpointed page no
 * longer claims that stale extent as a recovery source. */
call assert bag~transitionLifecycle("OFFLINE"), "bag offline before reincarnation"
newBagEpoch=bag~advanceOwnerEpoch("ACTIVE","ACCEPTING")
call assert newBagEpoch=21, "MU bag owner epoch advances"
a3=bag~attachMI("MI-A",3)
call assert a3<>.nil, "MI attaches to new bag incarnation"
call assert space~rebindMI(3,a3), "paging space follows new MI/bag attachment"
obs2=space~restartObligations
call assert obligation(obs2,"heap-hot")="RESTORE_CHECKPOINT", "stale MU backing falls back to recovery class"

call assert space~releaseGroup("rebuildable"), "unbacked group releases"
call assert bag~close, "close paging bag"
call SysFileDelete "./memory-paging.bin"
say "PASS memory.fabric.paging/0.1 RexxOS MI large-page backing contract"
exit 0

obligation: procedure
  use strict arg items, groupId
  do d over items
    if d["groupId"]=groupId then return d["action"]
  end
  return ""

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

::requires "MemoryFabricPaging.cls"
