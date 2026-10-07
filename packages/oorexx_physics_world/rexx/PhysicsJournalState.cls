/* Physics World adapter to common ooRexx Journal Pointed State v0.1.
   One coupled simulation may supply one shared StateOfNationController. */

::class PhysicsJournalParticipant public
::method init
 expose _participant _journal
 use strict arg participant,requestedJournalId=""
 initial=.directory~new; initial["STATE"]=participant~exportContinuationState
 _participant=participant; _journal=.JournalPointedState~new(initial,requestedJournalId)
::method checkpointIdentity; expose _participant; return _participant~checkpointIdentity
::method checkpointSchema; expose _participant; return _participant~checkpointSchema
::method capture
 expose _participant _journal
 use strict arg tag="PHYSICS",metadata=.nil
 return _journal~put("STATE",_participant~exportContinuationState,tag,metadata)
::method journalPoint; expose _journal; return _journal~journalPoint
::method journalCanMoveTo; expose _journal; use strict arg point; return _journal~journalCanMoveTo(point)
::method journalMoveTo
 expose _journal _participant
 use strict arg point,notify=.true
 p=_journal~journalMoveTo(point,notify)
 _participant~restoreContinuationState(_journal~at("STATE"))
 return p
::method journalAttachController; expose _journal; use strict arg controller,componentId; return _journal~journalAttachController(controller,componentId)
::method journalDetachController; expose _journal; return _journal~journalDetachController
::method journal; expose _journal; return _journal

::class PhysicsWorldCoreContinuationState public
::method init
 expose _time _bodyStates
 use strict arg worldTime,bodyStates
 _time=worldTime;_bodyStates=bodyStates
::method worldTime; expose _time; return _time
::method bodyStates; expose _bodyStates; return _bodyStates~copy

::class PhysicsWorldCoreParticipant public
::method init; expose _world; use strict arg world; _world=world
::method checkpointIdentity; return "physics.world.core"
::method checkpointSchema; return "physics.world.core/0.1"
::method exportContinuationState
 expose _world
 states=.array~new
 do body over _world~bodies; states~append(.PhysicalBodyFreezeState~new(body,body~pose)); end
 return .PhysicsWorldCoreContinuationState~new(_world~simulationTime,states)
::method restoreContinuationState
 expose _world
 use strict arg state
 do bs over state~bodyStates; bs~body~pose=bs~pose; end
 _world~simulationTime=state~worldTime
 return _world

::class PhysicsWorldJournal public
::method init
 expose _world _controller _adapters _core _prefix
 use strict arg world,sharedController=.nil,componentPrefix="physics"
 _world=world;_prefix=componentPrefix
 if sharedController==.nil then _controller=.StateOfNationController~new
 else _controller=sharedController
 _adapters=.directory~new
 _core=.PhysicsJournalParticipant~new(.PhysicsWorldCoreParticipant~new(world),componentPrefix || "-WORLD-CORE")
 _controller~register(componentPrefix || ".world.core",_core)
 do participant over world~freezeParticipants
   id=participant~checkpointIdentity
   adapter=.PhysicsJournalParticipant~new(participant,componentPrefix || "-" || id)
   _adapters[id]=adapter
   _controller~register(componentPrefix || "." || id,adapter)
 end
::method capture
 expose _core _adapters _controller
 use strict arg label="",eventName="PHYSICS",metadata=.nil
 _core~capture(eventName,metadata)
 do id over _adapters~allIndexes; _adapters[id]~capture(eventName,metadata); end
 return _controller~checkpoint(label,eventName,metadata)
::method restore; expose _controller; use strict arg checkpoint; return _controller~restore(checkpoint)
::method controller; expose _controller; return _controller
::method adapter; expose _adapters; use strict arg identity; return _adapters[identity]

::requires 'JournalPointedState.cls'
::requires 'PhysicsFreeze.cls'
