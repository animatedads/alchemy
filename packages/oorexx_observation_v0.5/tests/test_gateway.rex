s1=.FixtureSnapshot~new(1,"FIXTURE","alpha","D1")
o=.FixtureSession~new("OBS-G1","FIXTURE","NODE-A",s1)
stream=.ObservationStream~new("STREAM-G1",o,2)
g=.ObservationGateway~new(10)
if \g~registerStream(stream)~ok then call fail "register"
denied=g~subscribe("AI-1","STREAM-G1",0)
if denied~code<>"OBSERVATION_ACCESS_DENIED" then call fail "acl fail closed"
g~grant("AI-1","STREAM-G1")
subres=g~subscribe("AI-1","STREAM-G1",0,10)
if \subres~ok then call fail "subscribe"
lease=subres~value
stream~publish
o~append(.FixtureSnapshot~new(2,"FIXTURE","beta","D2")); stream~publish
o~append(.FixtureSnapshot~new(3,"FIXTURE","gamma","D3")); stream~publish
batch=g~read(lease,1,10)
if \batch~ok | batch~value~items<>2 then call fail "bounded retained read"
if batch~value[1]~sequence<>2 | batch~value[2]~sequence<>3 then call fail "retention sequence"
q=g~query(lease,.ObservationQueryEnvelope~new("Q1","CURRENT"),2)
if \q~ok | \q~value~ok | q~value~value~generation<>3 then call fail "gateway query"
bad=g~query(lease,.ObservationQueryEnvelope~new("Q2","CLICK"),2)
if bad~value~code<>"OBSERVATION_MUTATION_FORBIDDEN" then call fail "mutation escaped"
hb=g~heartbeat(lease,5,10); if \hb~ok then call fail "heartbeat"
if \g~read(lease,14,1)~ok then call fail "lease early expiry"
expired=g~read(lease,16,1); if expired~code<>"OBSERVATION_LEASE_EXPIRED" then call fail "lease expiry"
d=.ObservationDeltaBuilder~between(o~back(1),o~current)
if d~kind<>"CHANGED" | d~fromGeneration<>2 | d~toGeneration<>3 then call fail "delta"
say "PASS observation v0.5 gateway ACL lease heartbeat retention delta read-only"
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
::method init; expose sessionId terminalType deviceName hist; use arg sessionId,terminalType,deviceName,a; hist=.array~of(a)
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
