journalPath="/tmp/job_node_allocator_v05_restart.journal"
call SysFileDelete journalPath
uk=.array~of("GB")
req=.JobNodeRequirement~new(uk)
job=.JobPlacementRequest~new("JOB-DURABLE",req,"OWNER")
r=.NodeCapabilityRegistry~new
c=.NodeCapabilityStatement~new("NODE-A",1,"cap-a",uk)
o=.NodeCapacityObservation~new("NODE-A",1,1,100,10000,4096,10000,4,5000000,0,0,"obs-a")
r~advertiseCapability(c); r~observeCapacity(o)
proof=.TestProof~new
own1=.JobNodeOwnershipRegistry~new
alloc1=.JobNodeAllocator~new(r,.nil,.nil,.nil,proof,"5",.nil,own1)
j1=.JobNodeDurableJournal~new(journalPath,.nil,proof)
m1=.JobNodeDurablePlacementManager~new(alloc1,own1,j1)
d=m1~allocate(job,1000,5000)
if \d~placed then call fail "initial durable placement failed"
if d~lease~ownershipEpoch<>1 then call fail "initial epoch"
if alloc1~sequenceValue<>1 then call fail "initial sequence"

/* Torn trailing snapshot is ignored; last committed snapshot recovers. */
s=.stream~new(journalPath); s~open("write append"); s~lineout("BEGIN|2|999"); s~lineout("EPOCH|DEAD|999"); s~close
own2=.JobNodeOwnershipRegistry~new
alloc2=.JobNodeAllocator~new(r,.nil,.nil,.nil,proof,"5",.nil,own2)
j2=.JobNodeDurableJournal~new(journalPath,.nil,proof)
m2=.JobNodeDurablePlacementManager~new(alloc2,own2,j2)
rr=m2~restore(1500)
if \rr~ok | rr~restored<>1 then call fail "committed snapshot not restored"
if alloc2~sequenceValue<>1 then call fail "allocator sequence not restored"
if own2~epochFor(job~jobId)<>1 then call fail "ownership epoch not restored"
if \alloc2~verifyLease(d~lease,job,1500) then call fail "restored lease does not verify"
dup=m2~allocate(job,1600,5000)
if dup~code<>"ACTIVE_PLACEMENT_EXISTS" then call fail "restart allowed duplicate owner"
if \m2~releasePlacement(d~lease) then call fail "durable release failed"
job2=.JobPlacementRequest~new("JOB-DURABLE-2",req,"OWNER")
d2=m2~allocate(job2,1700,5000)
if \d2~placed then call fail "post-restart second allocation failed"
if d2~lease~placementId<>"PLACE-2-JOB-DURABLE-2" then call fail "placement sequence reused after restart"

/* A committed integrity failure is fail-closed; it must not fall back and
 * resurrect an earlier apparently valid state. */
badPath="/tmp/job_node_allocator_v05_corrupt.journal"
call SysFileDelete badPath
own3=.JobNodeOwnershipRegistry~new
alloc3=.JobNodeAllocator~new(r,.nil,.nil,.nil,proof,"5",.nil,own3)
j3=.JobNodeDurableJournal~new(badPath,.nil,proof)
m3=.JobNodeDurablePlacementManager~new(alloc3,own3,j3)
d3=m3~allocate(job,2000,5000)
if \d3~placed then call fail "corruption setup placement failed"
s=.stream~new(badPath); s~open("write append"); s~lineout("BEGIN|2|2"); s~lineout("COMMIT|2|BAD|"); s~close
own4=.JobNodeOwnershipRegistry~new
alloc4=.JobNodeAllocator~new(r,.nil,.nil,.nil,proof,"5",.nil,own4)
rr2=.JobNodeDurablePlacementManager~new(alloc4,own4,.JobNodeDurableJournal~new(badPath,.nil,proof))~restore(2100)
if rr2~ok | rr2~code<>"DURABLE_JOURNAL_INTEGRITY_FAILED" then call fail "corrupt committed snapshot did not fail closed"
if own4~current(job~jobId,2100)<>.nil then call fail "corrupt journal restored ownership"

say "PASS durable restart ownership, sequence, torn-write and integrity recovery"
exit 0
fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::class TestProof subclass JobNodeProofAuthority
::method sign
  use strict arg text
  return .SHA256~new(text||"|durable-test-key")~digest
::method verify
  use strict arg text, signature
  return signature=.SHA256~new(text||"|durable-test-key")~digest

::requires "../src/JobNodeDurableState.cls"
