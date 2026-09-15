snap1=.FixtureObservationSnapshot~new(1,"FIXTURE","alpha","D1")
snap2=.FixtureObservationSnapshot~new(2,"FIXTURE","beta","D2")
observer=.FixtureObservationSession~new("OBS-1","FIXTURE","NODE-T",snap1,snap2)
check=.ObservationProtocol~validateObserver(observer)
if \check~ok then call fail "valid observer rejected"
monitor=.SemanticObservationMonitor~new
if monitor~render(observer)~pos("beta")=0 then call fail "render missing semantic text"
if monitor~delta(observer)~pos("1 -> 2 CHANGED")=0 then call fail "delta missing"
env=monitor~capture(observer)
if env==.nil then call fail "capture missing"
if env~sessionId<>"OBS-1" | env~capturedGeneration<>2 then call fail "envelope binding"
bad=.BadObserver~new
badCheck=.ObservationProtocol~validateObserver(bad)
if badCheck~ok then call fail "bad observer accepted"
if badCheck~code<>"OBSERVER_CONTRACT_INVALID" then call fail "bad observer code"
say "PASS observation v0.5 neutral read-only observer contract"
exit 0

fail: procedure
  parse arg m
  say "FAIL" m
  exit 1

::class FixtureObservationSnapshot
::attribute generation get
::attribute terminalType get
::attribute contentDigest get
::method init
  expose generation terminalType visible contentDigest
  use arg generationArg,typeArg,visibleArg,digestArg
  generation=generationArg; terminalType=typeArg; visible=visibleArg; contentDigest=digestArg
::method visibleText
  expose visible
  return visible
::method copyDetached
  expose generation terminalType visible contentDigest
  return .FixtureObservationSnapshot~new(generation,terminalType,visible,contentDigest)

::class FixtureObservationSession
::attribute sessionId get
::attribute terminalType get
::attribute deviceName get
::method init
  expose sessionId terminalType deviceName hist
  use arg idArg,typeArg,deviceArg,s1,s2
  sessionId=idArg; terminalType=typeArg; deviceName=deviceArg; hist=.array~of(s1~copyDetached,s2~copyDetached)
::method snapshot
  return self~current
::method current
  expose hist
  return hist[hist~items]~copyDetached
::method back
  expose hist
  use arg count=1
  i=hist~items-count
  if i<1 then return .nil
  return hist[i]~copyDetached
::method history
  expose hist
  out=.array~new; do s over hist; out~append(s~copyDetached); end; return out
::method knownStateStatus; return "UNTRACKED"
::method knownStateId; return ""
::method knownStateGeneration; return 0
::method knownStateHistory; return .array~new

::class BadObserver
::method snapshot; return .nil

::requires "src/Observation.cls"
