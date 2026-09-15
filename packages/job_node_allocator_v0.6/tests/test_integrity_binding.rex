/* v0.4 placement-evidence binding and freshness invariants. */
call assertTrue .JobNodeAllocatorBuild~VERSION="0.6", "allocator version"

routeUS=.ApiRouteRequirement~new("US","LEGAL-EU","VPN","CONTROLLED",.array~of("BANK-API"))
routeGB=.ApiRouteRequirement~new("GB","LEGAL-EU","VPN","CONTROLLED",.array~of("BANK-API"))
reqUS=.JobNodeRequirement~new(.nil,.nil,.nil,.nil,.nil,.nil,.nil,"",0,0,0,0,0,0,0,routeUS)
reqGB=.JobNodeRequirement~new(.nil,.nil,.nil,.nil,.nil,.nil,.nil,"",0,0,0,0,0,0,0,routeGB)
call assertTrue reqUS~canonical<>reqGB~canonical, "API route must be bound into requirement canonical evidence"

apiCap=.NodeApiEgressCapability~new(.array~of("US","GB"),.array~of("LEGAL-EU"),.array~of("VPN"),.array~of("CONTROLLED"),.array~of("BANK-API"))
cap=.NodeCapabilityStatement~new("NODE-A",7,"cap-proof",.nil,.nil,.nil,.nil,.nil,.nil,.nil,"X86_64",8192,65536,8,"RUNTIME-1",apiCap)
reg=.NodeCapabilityRegistry~new
call assertTrue reg~advertiseCapability(cap), "initial capability advertise"

/* Same-generation capability/capacity equivocation is rejected. */
apiCapDifferent=.NodeApiEgressCapability~new(.array~of("US"),.array~of("LEGAL-EU"),.array~of("VPN"),.array~of("CONTROLLED"),.array~of("BANK-API"))
capDifferent=.NodeCapabilityStatement~new("NODE-A",7,"cap-proof",.nil,.nil,.nil,.nil,.nil,.nil,.nil,"X86_64",8192,65536,8,"RUNTIME-1",apiCapDifferent)
call assertTrue \reg~advertiseCapability(capDifferent), "same-generation changed capability rejected"
call assertTrue reg~advertiseCapability(cap), "same-generation identical capability idempotent"

obs=.NodeCapacityObservation~new("NODE-A",7,11,100,500,4096,32000,4,2000000,0,0,"obs-proof")
call assertTrue reg~observeCapacity(obs), "initial capacity observation"
obsDifferent=.NodeCapacityObservation~new("NODE-A",7,11,100,500,4096,32000,3,2000000,0,0,"obs-proof")
call assertTrue \reg~observeCapacity(obsDifferent), "same-generation changed capacity rejected"
call assertTrue reg~observeCapacity(obs), "same-generation identical capacity idempotent"

job=.JobPlacementRequest~new("JOB-INTEGRITY",reqUS,"OWNER-UK",1000,1000)
a=.JobNodeAllocator~new(reg,.nil,.nil,.nil,.nil,"POLICY-7")
d=a~allocate(job,100,1000)
call assertTrue d~placed, "placement"
call assertTrue d~lease~expiresEpochMs=500, "lease bounded by capacity observation expiry"
call assertTrue a~verifyLease(d~lease,job,499), "lease verifies while evidence fresh"
call assertTrue \a~verifyLease(d~lease,job,500), "lease fails at capacity/lease freshness boundary"

/* Changing only the API route must invalidate the lease digest. */
jobRouteChanged=.JobPlacementRequest~new("JOB-INTEGRITY",reqGB,"OWNER-UK",1000,1000)
call assertTrue \a~verifyLease(d~lease,jobRouteChanged,200), "API route change invalidates lease"

/* API egress claims are part of capability evidence, including nested mutation. */
apiCap~countries~remove("US")
call assertTrue \a~verifyLease(d~lease,job,200), "API egress capability mutation invalidates lease"
apiCap~countries["US"]=.true
call assertTrue a~verifyLease(d~lease,job,200), "restored capability verifies"

/* A revocation is immediately visible to lease verification. */
reg~revoke("NODE-A")
call assertTrue \a~verifyLease(d~lease,job,200), "revoked node invalidates lease"
cap~setOnline(.true)

/* Policy generation is part of the placement authority contract. */
aOther=.JobNodeAllocator~new(reg,.nil,.nil,.nil,.nil,"POLICY-8")
call assertTrue \aOther~verifyLease(d~lease,job,200), "policy generation mismatch invalidates lease"

say "PASS placement evidence binding, monotonic observations and lease freshness"
exit 0

assertTrue: procedure
  use arg condition,message
  if \condition then do
    say "FAIL" message
    exit 1
  end
return

::requires "../src/JobNodeAllocator.cls"
::requires "ApiClient.cls"
