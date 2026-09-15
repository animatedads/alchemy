/* Observation v0.5 service qualification */

snap=.SvcSnapshot~new(1,"hello")
observer=.SvcObserver~new("S-1","VIRTUAL-BROWSER","NODE-Z",snap)
stream=.ObservationStream~new("STREAM-1",observer,16)
producer=.ObservationProducerRegistration~new("PROD-Z","NODE-Z","proof:abc",7)
q=.FakeQueueManager~new
bucket=.FakeBucket~new(2)
admission=.ObservationWLUDeliveryAdmission~new(bucket,1)
auth=.SvcAuthorizer~new
service=.ObservationQueueService~new(q,"obs.queue","observer-service",admission,auth)
call assert service~registerProducer(producer)~ok,"producer registration"
r=service~registerStream("PROD-Z",stream)
call assert r~ok,"stream registration"
call assert r~value~nodeId="NODE-Z","descriptor node"
call assert r~value~capabilityGeneration=7,"descriptor generation"
call assert service~discover("VIRTUAL-BROWSER")~items=1,"discovery"

p1=service~publishLatest("PROD-Z","STREAM-1",10)
call assert p1~ok,"first publish"
call assert q~puts=1,"queue put"
call assert q~lastPayload["schema"]="observation.stream/0.5","schema"
call assert q~lastOptions["correlationId"]="STREAM-1:1","correlation"

observer~replace(.SvcSnapshot~new(2,"world"))
p2=service~publishLatest("PROD-Z","STREAM-1",11)
call assert p2~ok,"second publish"
call assert q~puts=2,"second queue put"
observer~replace(.SvcSnapshot~new(3,"third"))
p3=service~publishLatest("PROD-Z","STREAM-1",12)
call assert \p3~ok & p3~code="OBSERVATION_WLU_THROTTLED","WLU throttle"
call assert q~puts=2,"throttled does not queue"

req=.ObservationReplayRequest~new("R1","AI-1","STREAM-1",0,10)
rr=service~replay(req)
call assert rr~ok,"replay allowed"
call assert rr~value~items=3,"replay includes locally published record even if delivery throttled"

bad=.ObservationReplayRequest~new("R2","DENIED","STREAM-1",0,10)
call assert service~replay(bad)~code="OBSERVATION_ACCESS_DENIED","replay ACL"

c1=service~commitCheckpoint("AI-1","STREAM-1",2,2,20)
call assert c1~ok,"checkpoint commit"
call assert service~checkpoint("AI-1","STREAM-1")~sequence=2,"checkpoint read"
call assert service~commitCheckpoint("AI-1","STREAM-1",1,1,21)~code="CHECKPOINT_REGRESSION","checkpoint regression"

say "PASS observation v0.5 queue service producer discovery replay checkpoint WLU delivery"
exit 0

assert: procedure
  use arg condition,message
  if \condition then do; say "FAIL" message; exit 1; end
  return

::class SvcSnapshot public
::attribute generation get
::attribute visibleText get
::method init
  expose generation visibleText
  use arg g,t; generation=g; visibleText=t
::method terminalType; return "VIRTUAL-BROWSER"
::method contentDigest; expose generation visibleText; return generation||":"||visibleText
::method copyDetached; expose generation visibleText; return .SvcSnapshot~new(generation,visibleText)

::class SvcObserver public
::attribute sessionId get
::attribute terminalType get
::attribute deviceName get
::method init
  expose sessionId terminalType deviceName currentSnap history
  use arg s,t,d,snap; sessionId=s; terminalType=t; deviceName=d; currentSnap=snap; history=.array~of(snap)
::method replace; expose currentSnap history; use arg s; currentSnap=s; history~append(s)
::method snapshot; expose currentSnap; return currentSnap
::method current; expose currentSnap; return currentSnap
::method back; expose history; use arg n=1; i=history~items-n; if i<1 then return .nil; return history[i]
::method history; expose history; return history
::method knownStateStatus; return "UNKNOWN"
::method knownStateId; return ""
::method knownStateGeneration; return 0
::method knownStateHistory; return .array~new

::class SvcAuthorizer public
::method mayObserve; use arg principalId,streamId; return principalId<>"DENIED"

::class FakeBucket public
::method init; expose remaining held; use arg n; remaining=n; held=0
::method hold; expose remaining held; use arg amount,now; if remaining<amount then return .false; remaining-=amount; held=amount; return .true
::method retryAfterSeconds; return 5
::method settleHold; expose held; use arg heldAmount,actual,now; held=0; return .true

::class FakeQueueResult public
::attribute ok get
::method init; expose ok; use arg v; ok=v
::class FakeQueueManager public
::attribute puts get
::attribute lastPayload get
::attribute lastOptions get
::method init; expose puts lastPayload lastOptions; puts=0; lastPayload=.nil; lastOptions=.nil
::method put
  expose puts lastPayload lastOptions
  use arg queue,payload,options,principal
  puts+=1; lastPayload=payload; lastOptions=options
  return .FakeQueueResult~new(.true)

::requires "src/Observation.cls"
