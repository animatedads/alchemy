parse source . . here
base=filespec("LOCATION",here)

/* helper arrays */
uk=.array~of("GB"); eu=.array~of("DE")
legal=.array~of("CUSTOMER-PII-UK")
trust=.array~of("BANK-TRUSTED")
auth=.array~of("CUSTOMER_LEDGER.READ")
abilities=.array~of("DERIVATIVES.POSITION.QUERY")
runtimes=.array~of("OOREXX/5.3")

req=.JobNodeRequirement~new(uk,legal,trust,auth,abilities,runtimes,.nil,"X86_64",4096,0,2,2048,0,1,5000000)
job=.JobPlacementRequest~new("JOB-1",req,"OWNER-A",40000000,5000000)
r=.NodeCapabilityRegistry~new

/* Very idle but wrong jurisdiction: MUST NOT be scoreable/selectable. */
c1=.NodeCapabilityStatement~new("FRANKFURT-IDLE",1,"proof-fr",eu,legal,trust,auth,abilities,runtimes,.nil,"X86_64",65536,1000000,32,"rr-gen-1")
o1=.NodeCapacityObservation~new("FRANKFURT-IDLE",1,1,1000,50000,60000,900000,30,50000000,0,0,"cap-fr")
r~advertiseCapability(c1); if \r~observeCapacity(o1) then call fail "capacity o1"

/* Eligible but busy-ish. */
c2=.NodeCapabilityStatement~new("LONDON-1",4,"proof-l1",uk,legal,trust,auth,abilities,runtimes,.nil,"X86_64",16384,500000,8,"rr-gen-1")
o2=.NodeCapacityObservation~new("LONDON-1",4,7,1000,50000,5000,100000,2,6000000,4,5,"cap-l1")
r~advertiseCapability(c2); if \r~observeCapacity(o2) then call fail "capacity o2"

/* Eligible and more capacity: should win. */
c3=.NodeCapabilityStatement~new("LONDON-2",2,"proof-l2",uk,legal,trust,auth,abilities,runtimes,.nil,"X86_64",32768,500000,16,"rr-gen-1")
o3=.NodeCapacityObservation~new("LONDON-2",2,3,1000,50000,20000,200000,10,12000000,1,1,"cap-l2")
r~advertiseCapability(c3); if \r~observeCapacity(o3) then call fail "capacity o3"

a=.JobNodeAllocator~new(r)
d=a~allocate(job,2000,10000)
if \d~placed then call fail "placement failed"
if d~code<>"PLACED" then call fail "placement code"
if d~lease~nodeId<>"LONDON-2" then call fail "wrong selected node"
if d~exclusionCount("JURISDICTION_NOT_PERMITTED")<>1 then call fail "jurisdiction exclusion evidence"
if \a~verifyLease(d~lease,job,3000) then call fail "valid lease rejected"
if a~verifyLease(d~lease,job,13000) then call fail "expired lease accepted"

/* generation change invalidates an existing lease */
c3new=.NodeCapabilityStatement~new("LONDON-2",3,"proof-l2-new",uk,legal,trust,auth,abilities,runtimes,.nil,"X86_64",32768,500000,16,"rr-gen-2")
r~advertiseCapability(c3new)
if a~verifyLease(d~lease,job,3000) then call fail "stale generation lease accepted"

say "PASS core hard eligibility, optimisation and lease invalidation"
exit 0
fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::requires "../src/JobNodeAllocator.cls"
