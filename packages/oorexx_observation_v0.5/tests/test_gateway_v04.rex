s1=.FixtureSnapshot~new(1,"FIXTURE",.array~of("Inbox","Unread 2"),.array~of(.FixtureField~new("A","2")),"D1")
o=.FixtureSession~new("OBS-4","FIXTURE","NODE-A",s1)
a=.FixtureAuthorizer~new
g=.ObservationGateway~new(10,a)
stream=.ObservationStream~new("S4",o,10)
g~registerStream(stream)
if g~subscribe("AI","S4",0)~code<>"OBSERVATION_ACCESS_DENIED" then call fail "external authority fail closed"
a~allow("AI","S4")
lease=g~subscribe("AI","S4",0,10,.nil,1)~value
stream~publish
o~append(.FixtureSnapshot~new(2,"FIXTURE",.array~of("Inbox","Unread 3","Ticket 44"),.array~of(.FixtureField~new("A","3"),.FixtureField~new("B","Ticket 44")),"D2")); stream~publish
b=g~read(lease,1,10); if b~value~items<>1 then call fail "credit window"
if g~read(lease,1,10)~value~items<>0 then call fail "backpressure not applied"
if g~ack(lease,1,1)~value<>1 then call fail "ack credit"
b2=g~read(lease,1,10); if b2~value~items<>1 | b2~value[1]~sequence<>2 then call fail "resume after ack"
d=.ObservationStructuralDeltaBuilder~between(o~back(1),o~current)
if d~count<3 then call fail "structural delta too weak"
seenRow=.false; seenField=.false
do c over d~changes
  if c~kind="ROW_ADDED" then seenRow=.true
  if c~kind="FIELD_CHANGED" | c~kind="FIELD_ADDED" then seenField=.true
end
if \seenRow | \seenField then call fail "structural changes missing"
qm=.FixtureQueueManager~new
rec=stream~publish
if rec~sequence<>2 then call fail "duplicate generation should not republish"
o~append(.FixtureSnapshot~new(3,"FIXTURE",.array~of("Inbox","Unread 4"),.array~of(.FixtureField~new("A","4")),"D3")); rec=stream~publish
ad=.ObservationQueueFabricAdapter~new(qm,"OBS.Q","OBS-SERVICE")
r=ad~publishRecord(rec)
if \r~ok then call fail "queue adapter"
if qm~lastPayload["schema"]<>"observation.stream/0.5" then call fail "wire schema"
if qm~lastPayload["sequence"]<>3 then call fail "wire sequence"
if qm~lastOptions["correlationId"]<>"S4:3" then call fail "queue correlation"
say "PASS observation v0.5 structural delta backpressure external authority queue-fabric adapter"
exit 0
fail: procedure; parse arg m; say "FAIL" m; exit 1
::class FixtureAuthorizer subclass ObservationAuthorizer
::method init; expose grants; grants=.directory~new
::method allow; expose grants; use arg p,s; grants[p||"|"||s]=1
::method mayObserve; expose grants; use arg p,s; return grants~hasIndex(p||"|"||s)
::class FixtureField
::attribute fieldId get
::attribute value get
::method init; expose fieldId value; use arg fieldId,value
::method displayValue; expose value; return value
::method copyDetached; expose fieldId value; return .FixtureField~new(fieldId,value)
::class FixtureSnapshot
::attribute generation get
::attribute terminalType get
::attribute contentDigest get
::method init; expose generation terminalType rows fields contentDigest; use arg generation,terminalType,rows,fields,contentDigest
::method visibleText; expose rows; out=""; do r over rows; if out<>"" then out=out||"0a"x; out=out||r; end; return out
::method textRows; expose rows; a=.array~new; do r over rows; a~append(r); end; return a
::method fields; expose fields; a=.array~new; do f over fields; a~append(f~copyDetached); end; return a
::method copyDetached; expose generation terminalType rows fields contentDigest; return .FixtureSnapshot~new(generation,terminalType,self~textRows,self~fields,contentDigest)
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
::class FixtureQueueResult
::attribute ok get
::method init; expose ok; ok=.true
::class FixtureQueueManager
::attribute lastPayload get
::attribute lastOptions get
::method put; expose lastPayload lastOptions; use arg q,p,o,principal; lastPayload=p; lastOptions=o; return .FixtureQueueResult~new
::requires "src/Observation.cls"
