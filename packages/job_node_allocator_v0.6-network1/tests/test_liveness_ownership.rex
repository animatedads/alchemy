uk=.array~of("GB")
req=.JobNodeRequirement~new(uk)
job=.JobPlacementRequest~new("JOB-LIVE",req,"OWNER")
r=.NodeCapabilityRegistry~new

c1=.NodeCapabilityStatement~new("NODE-A",1,"cap-a",uk)
o1=.NodeCapacityObservation~new("NODE-A",1,1,100,20000,4096,10000,4,5000000,1,1,"obs-a")
c2=.NodeCapabilityStatement~new("NODE-B",1,"cap-b",uk)
o2=.NodeCapacityObservation~new("NODE-B",1,1,100,20000,8192,20000,8,9000000,0,0,"obs-b")
r~advertiseCapability(c1); r~observeCapacity(o1)
r~advertiseCapability(c2); r~observeCapacity(o2)

proof=.TestHeartbeatProof~new
live=.JobNodeLivenessRegistry~new(r,proof)
h1=.JobNodeHeartbeat~new("NODE-A",1,1,100,10000,"hb-a")
h1~signature=proof~sign(h1~canonical)
h2=.JobNodeHeartbeat~new("NODE-B",1,1,100,3000,"hb-b")
h2~signature=proof~sign(h2~canonical)
if \live~recordHeartbeat(h1,200) then call fail "node A heartbeat rejected"
if \live~recordHeartbeat(h2,200) then call fail "node B heartbeat rejected"

/* Replay and forged heartbeats fail closed. */
if live~recordHeartbeat(h2,250) then call fail "heartbeat replay accepted"
forged=.JobNodeHeartbeat~new("NODE-A",1,2,300,10000,"hb-a","forged")
if live~recordHeartbeat(forged,300) then call fail "forged heartbeat accepted"

assessors=.array~of(.JobNodeLivenessAssessor~new(live))
elig=.JobNodeEligibilityPolicy~new(assessors)
own=.JobNodeOwnershipRegistry~new
alloc=.JobNodeAllocator~new(r,elig,.nil,.nil,.nil,"4",.nil,own)
life=.JobNodePlacementLifecycle~new(alloc,live,own)

d=alloc~allocate(job,1000,5000)
if \d~placed then call fail "initial placement failed"
if d~lease~nodeId<>"NODE-B" then call fail "best live node not selected"
if d~lease~ownershipEpoch<=0 then call fail "ownership epoch missing"
if \life~destinationAccepts(d~lease,job,1500) then call fail "destination rejected current owner"

/* A second placement for the same job cannot coexist. */
dup=alloc~allocate(job,1500,5000)
if dup~code<>"ACTIVE_PLACEMENT_EXISTS" then call fail "duplicate placement not fenced"

/* Renew while the node remains live: same fence epoch, increasing renewal sequence. */
ren=alloc~renewPlacement(d~lease,job,2000,5000)
if \ren~placed | ren~code<>"RENEWED" then call fail "lease renewal failed"
if ren~lease~ownershipEpoch<>d~lease~ownershipEpoch then call fail "renewal changed ownership epoch"
if ren~lease~renewalSequence<>1 then call fail "renewal sequence not advanced"
if \life~destinationAccepts(ren~lease,job,2500) then call fail "renewed lease rejected"

/* NODE-B heartbeat is now stale although its lease remains time-valid. */
if live~isLive("NODE-B",4000) then call fail "stale heartbeat considered live"
if life~destinationAccepts(ren~lease,job,4000) then call fail "stale node accepted lease"

/* Recovery fences old ownership before choosing another live eligible node. */
rec=life~recover(job,ren~lease,4000,5000)
if \rec~placed then call fail "recovery placement failed"
if rec~lease~nodeId<>"NODE-A" then call fail "recovery did not move to live node"
if rec~lease~ownershipEpoch<=ren~lease~ownershipEpoch then call fail "ownership fence did not advance"
if life~destinationAccepts(ren~lease,job,4100) then call fail "old placement survived fencing"
if \life~destinationAccepts(rec~lease,job,4100) then call fail "replacement placement rejected"

say "PASS authenticated liveness, renewal, ownership fencing and controlled recovery"
exit 0
fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::class TestHeartbeatProof subclass JobNodeHeartbeatProofAuthority
::method sign
  use strict arg text
  return .SHA256~new(text||"|heartbeat-test-key")~digest
::method verify
  use strict arg text, signature
  return signature=.SHA256~new(text||"|heartbeat-test-key")~digest

::requires "../src/JobNodeLiveness.cls"
