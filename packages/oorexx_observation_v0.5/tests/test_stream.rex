s1=.FixtureSnapshot~new(1,"FIXTURE","alpha","D1")
s2=.FixtureSnapshot~new(2,"FIXTURE","beta","D2")
o=.FixtureSession~new("OBS-1","FIXTURE","NODE-A",s1,s2)
stream=.ObservationStream~new("STREAM-1",o)
r=stream~publish
if r~sequence<>1 | r~generation<>2 then call fail "first record"
sub=stream~subscribe
batch=stream~read(sub,10)
if batch~items<>1 then call fail "initial read"
cp=stream~latestCheckpoint
sub2=stream~subscribe(cp)
if stream~read(sub2,10)~items<>0 then call fail "checkpoint replay boundary"
o~append(.FixtureSnapshot~new(3,"FIXTURE","gamma","D3"))
r2=stream~publish
if r2~sequence<>2 | r2~generation<>3 then call fail "second record"
if stream~read(sub,10)~items<>1 then call fail "subscriber continuation"
if stream~read(sub2,10)~items<>1 then call fail "resumed subscriber"
q=.ObservationQueryRouter~new
res=q~execute(o,.ObservationQueryEnvelope~new("Q1","SNAPSHOT"))
if \res~ok | res~value~generation<>3 then call fail "snapshot query"
bad=q~execute(o,.ObservationQueryEnvelope~new("Q2","CLICK"))
if bad~code<>"OBSERVATION_MUTATION_FORBIDDEN" then call fail "mutation accepted"
say "PASS observation v0.5 transportable stream checkpoint replay read-only query"
exit 0
fail: procedure; parse arg m; say "FAIL" m; exit 1
::class FixtureSnapshot
::attribute generation get
::attribute terminalType get
::attribute contentDigest get
::method init; expose generation terminalType visible contentDigest; use arg generation,terminalType,visible,contentDigest
::method visibleText; expose visible; return visible
::method copyDetached; expose generation terminalType visible contentDigest; return .FixtureSnapshot~new(generation,terminalType,visible,contentDigest)
::class FixtureSession
::attribute sessionId get
::attribute terminalType get
::attribute deviceName get
::method init; expose sessionId terminalType deviceName hist; use arg sessionId,terminalType,deviceName,a,b; hist=.array~of(a,b)
::method append; expose hist; use arg s; hist~append(s)
::method snapshot; return self~current
::method current; expose hist; return hist[hist~items]~copyDetached
::method back; expose hist; use arg n=1; i=hist~items-n; if i<1 then return .nil; return hist[i]~copyDetached
::method history; expose hist; a=.array~new; do s over hist; a~append(s~copyDetached); end; return a
::method knownStateStatus; return "UNTRACKED"
::method knownStateId; return ""
::method knownStateGeneration; return 0
::method knownStateHistory; return .array~new
::requires "src/Observation.cls"
