numeric digits 20
call testMain
exit 0

testMain:
  registry=.MemoryFabricRegistry~new("memory:lifecycle")
  p=.MemoryFabricProvider~new("p1","MU","MU-1","","site","machine","local://p1",4096,0,"ACTIVE","ACCEPTING",4,7,"boot-a")
  call assert registry~registerProvider(p), "register active provider"

  b1=.MemoryFabricBlockRef~new("v",1,"p1",0,512,"VOLATILE","",4)
  b2=.MemoryFabricBlockRef~new("r",1,"p1",512,512,"RECONSTRUCTABLE","storage://source",4)
  b3=.MemoryFabricBlockRef~new("rep",1,"p1",1024,512,"REPLICATED","replica://peer",4)
  b4=.MemoryFabricBlockRef~new("cp",1,"p1",1536,512,"CHECKPOINTED","checkpoint://7",4)
  call assert registry~publishBlock(b1), "publish volatile"
  call assert registry~publishBlock(b2), "publish reconstructable"
  call assert registry~publishBlock(b3), "publish replicated"
  call assert registry~publishBlock(b4), "publish checkpointed"

  draining=registry~transitionProvider("p1",4,"DRAINING","DRAINING")
  call assert draining<>.nil, "transition to draining"
  call assert \draining~acceptsGeneralAllocation, "draining refuses allocation"
  call assert registry~resolveBlock("cp",1)<>.nil, "draining keeps existing block resolvable"

  obligations=registry~lifecycleObligations("p1")
  call assert obligations~items=4, "four lifecycle obligations"
  call assert findAction(obligations,"VOLATILE")="DROP_ON_OFFLINE", "volatile obligation"
  call assert findAction(obligations,"RECONSTRUCTABLE")="RECONSTRUCT_FROM_REFERENCE", "reconstruct obligation"
  call assert findAction(obligations,"REPLICATED")="VERIFY_OR_PROMOTE_REPLICA", "replica obligation"
  call assert findAction(obligations,"CHECKPOINTED")="RESTORE_CHECKPOINT", "checkpoint obligation"

  offline=registry~transitionProvider("p1",4,"OFFLINE","CLOSED")
  call assert offline<>.nil, "transition offline"
  call assert registry~resolveBlock("cp",1)=.nil, "offline provider not resolvable"

  reborn=registry~reincarnateProvider("p1",4,"boot-b","local://p1-new")
  call assert reborn<>.nil, "reincarnate provider"
  call assert reborn~membershipEpoch=5, "reincarnation advances owner epoch"
  call assert registry~resolveBlock("cp",1)=.nil, "old block remains fenced after reincarnation"
  call assert registry~transitionProvider("p1",4,"ACTIVE","ACCEPTING")=.nil, "stale lifecycle authority rejected"

  say "PASS memory fabric provider lifecycle"
  return

findAction: procedure
  use arg obligations, class
  do x over obligations
    if x["recovery_class"]=class then return x["action"]
  end
  return ""

assert: procedure
  use arg ok, label
  if ok then return
  say "FAIL:" label
  exit 99

::requires "../src/MemoryFabric.cls"
