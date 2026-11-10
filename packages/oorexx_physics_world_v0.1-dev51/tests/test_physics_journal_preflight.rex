/* Physics World journal preflight: foreign world/body inventory must not
   move the journal pointer or mutate physical state. */
world=.ProbeWorld~new
body=.ProbeBody~new("first")
world~addBody(body)
adapter=.PhysicsJournalParticipant~new(.PhysicsWorldCoreParticipant~new(world),"PHYSICS-PREFLIGHT")

original=adapter~journalPoint
body~pose="moved"
world~simulationTime=5
good=adapter~capture("GOOD")
adapter~journalMoveTo(original)
if body~pose<>"first" | world~simulationTime<>0 then exit 1
adapter~journalMoveTo(good)
if body~pose<>"moved" | world~simulationTime<>5 then exit 1

/* Make an invalid node without passing through the Physics adapter. */
other=.ProbeWorld~new
foreignState=.PhysicsWorldCoreContinuationState~new(other,99, -
    .array~of(.PhysicalBodyFreezeState~new(body,"corrupt")))
bad=adapter~journal~put("STATE",foreignState,"BAD")
adapter~journalMoveTo(good)
beforePoint=adapter~journalPoint~nodeId
beforePose=body~pose
beforeTime=world~simulationTime
if \rejects(adapter,bad) then do
 say "FAIL foreign-world journal destination accepted"
 exit 1
end
if adapter~journalPoint~nodeId<>beforePoint then exit 1
if body~pose<>beforePose | world~simulationTime<>beforeTime then exit 1

/* Same origin but a changed live body inventory must also fail. */
world~addBody(.ProbeBody~new("late"))
if \rejects(adapter,original) then do
 say "FAIL changed body inventory journal destination accepted"
 exit 1
end
if adapter~journalPoint~nodeId<>beforePoint then exit 1
say "PHYSICS JOURNAL PREFLIGHT: OK"
exit 0

::routine rejects
 use strict arg adapter,point
 signal on syntax name rejected
 adapter~journalMoveTo(point)
 signal off syntax
 return .false
rejected:
 signal off syntax
 return .true

::class ProbeBody public
::attribute pose
::method init
 expose pose
 use strict arg pose

::class ProbeWorld public
::attribute simulationTime
::method init
 expose _bodies simulationTime
 _bodies=.array~new
 simulationTime=0
::method addBody
 expose _bodies
 use strict arg body
 _bodies~append(body)
 return body
::method bodies
 expose _bodies
 return _bodies~copy

::requires "PhysicsJournalState.cls"
