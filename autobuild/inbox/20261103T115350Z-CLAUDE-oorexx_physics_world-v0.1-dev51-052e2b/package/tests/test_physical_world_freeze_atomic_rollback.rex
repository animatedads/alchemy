world=.PhysicalWorld~new
p1=.TxParticipant~new('one',1)
p2=.TxParticipant~new('two',2)
world~registerFreezeParticipant(p1)
world~registerFreezeParticipant(p2)
world~simulationTime=5
cp=world~freeze
p1~state=10; p2~state=20; p2~rejectTarget=2
world~simulationTime=99
signal on syntax name restoreRejected
world~restore(cp)
say 'FAIL rejecting participant did not reject'; exit 1
restoreRejected:
signal off syntax
if p1~state<>10 then do; say 'FAIL earlier participant not rolled back' p1~state; exit 1; end
if p2~state<>20 then do; say 'FAIL rejecting participant changed' p2~state; exit 1; end
if world~simulationTime<>99 then do; say 'FAIL simulation time not rolled back' world~simulationTime; exit 1; end
say 'PASS Physics freeze atomic rollback'
exit 0

::class TxParticipant
::method init
 expose _id _state _rejectTarget
 use strict arg id,state
 _id=id; _state=state; _rejectTarget=.nil
::method checkpointIdentity; expose _id; return 'test.tx:'_id
::method checkpointSchema; return 'test.tx/0.1'
::method exportContinuationState; expose _state; return _state
::method restoreContinuationState
 expose _state _rejectTarget
 use strict arg state
 if _rejectTarget<>.nil & state=_rejectTarget then raise syntax 93.900 array('deliberate restore rejection',state)
 _state=state
 return self
::method state; expose _state; return _state
::method 'state='; expose _state; use strict arg value; _state=value
::method 'rejectTarget='; expose _rejectTarget; use strict arg value; _rejectTarget=value
::requires 'PhysicsWorld.cls'
