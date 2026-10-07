/* Physics World dev47: coherent package-wide in-memory freeze/restore.
   In-memory checkpoints are bound to their originating world and exact body
   inventory. Restore is transactional: participant/body/time changes are
   rolled back if any participant rejects its continuation state. */

::class PhysicalWorldCheckpoint public
::method init
  expose _schema _world _time _bodyStates _participantStates _participantSchemas _participantOrder
  use strict arg schema,ownerWorld,worldTime,bodyStates,participantStates,participantSchemas,participantOrder
  _schema=schema; _world=ownerWorld; _time=worldTime; _bodyStates=bodyStates
  _participantStates=participantStates; _participantSchemas=participantSchemas; _participantOrder=participantOrder
::method schema; expose _schema; return _schema
::method ownerWorld; expose _world; return _world
::method worldTime; expose _time; return _time
::method bodyStates; expose _bodyStates; return _bodyStates~copy
::method participantStates; expose _participantStates; return _participantStates~copy
::method participantSchemas; expose _participantSchemas; return _participantSchemas~copy
::method participantOrder; expose _participantOrder; return _participantOrder~copy

::class PhysicalBodyFreezeState public
::method init
 expose _body _pose
 use strict arg body,pose
 _body=body;_pose=pose
::method body; expose _body; return _body
::method pose; expose _pose; return _pose

::class PhysicsFreezeCoordinator public
::method freeze class
  use strict arg world
  bodyStates=.array~new
  do body over world~bodies
    bodyStates~append(.PhysicalBodyFreezeState~new(body,body~pose))
  end
  states=.directory~new; schemas=.directory~new; order=.array~new
  do participant over world~freezeParticipants
    id=participant~checkpointIdentity
    if id='' | states~hasIndex(id) then raise syntax 93.900 array('unique Physics checkpoint participant identity',id)
    schemas[id]=participant~checkpointSchema
    states[id]=participant~exportContinuationState
    order~append(id)
  end
  return .PhysicalWorldCheckpoint~new('physics.world.checkpoint/0.2',world,world~simulationTime,bodyStates,states,schemas,order)

::method restore class
  use strict arg world,checkpoint
  if checkpoint~schema<>'physics.world.checkpoint/0.2' then raise syntax 93.900 array('supported Physics world checkpoint schema',checkpoint~schema)
  if checkpoint~ownerWorld \== world then raise syntax 93.900 array('checkpoint belongs to target Physics world')

  currentParticipants=.directory~new
  do participant over world~freezeParticipants
    id=participant~checkpointIdentity
    if id='' | currentParticipants~hasIndex(id) then raise syntax 93.900 array('unique Physics restore participant identity',id)
    currentParticipants[id]=participant
  end
  states=checkpoint~participantStates; schemas=checkpoint~participantSchemas; order=checkpoint~participantOrder

  /* Validate the full participant inventory/schema before mutating anything. */
  if order~items<>currentParticipants~items then raise syntax 93.900 array('checkpoint participant inventory count match',order~items currentParticipants~items)
  do id over order
    if \currentParticipants~hasIndex(id) then raise syntax 93.900 array('checkpoint participant present at restore',id)
    p=currentParticipants[id]
    if \states~hasIndex(id) then raise syntax 93.900 array('checkpoint continuation state present',id)
    if p~checkpointSchema<>schemas[id] then raise syntax 93.900 array('checkpoint participant schema match',id schemas[id] p~checkpointSchema)
  end
  do id over currentParticipants
    if \states~hasIndex(id) then raise syntax 93.900 array('runtime participant present in checkpoint',id)
  end

  /* Validate the exact body object inventory before mutation. */
  bodyStates=checkpoint~bodyStates; currentBodies=world~bodies
  if bodyStates~items<>currentBodies~items then raise syntax 93.900 array('checkpoint body inventory count match',bodyStates~items currentBodies~items)
  do i=1 to bodyStates~items
    if bodyStates[i]~body \== currentBodies[i] then raise syntax 93.900 array('checkpoint body identity/order match',i)
  end

  /* Snapshot current target state for rollback. */
  rollbackBody=.array~new
  do body over currentBodies; rollbackBody~append(.PhysicalBodyFreezeState~new(body,body~pose)); end
  rollbackStates=.directory~new
  do id over order; rollbackStates[id]=currentParticipants[id]~exportContinuationState; end
  rollbackTime=world~simulationTime

  signal on syntax name restoreFailed
  do bs over bodyStates; bs~body~pose=bs~pose; end
  do id over order; currentParticipants[id]~restoreContinuationState(states[id]); end
  world~simulationTime=checkpoint~worldTime
  signal off syntax
  return world

restoreFailed:
  signal off syntax
  do bs over rollbackBody; bs~body~pose=bs~pose; end
  do id over order; currentParticipants[id]~restoreContinuationState(rollbackStates[id]); end
  world~simulationTime=rollbackTime
  raise syntax 93.900 array('atomic Physics restore failed; pre-restore state reinstated')

::class RigidBodyFreezeState public
::method init
 expose _v _omega _force _torque
 use strict arg velocity,angularVelocity,force,torque
 _v=velocity;_omega=angularVelocity;_force=force;_torque=torque
::method velocity; expose _v; return _v
::method angularVelocity; expose _omega; return _omega
::method force; expose _force; return _force
::method torque; expose _torque; return _torque

::class RigidBodyFreezeParticipant public
::method init
 expose _id _state
 use strict arg identity,state
 _id=identity;_state=state
::method checkpointIdentity; expose _id; return 'mechanics.rigid-body:'_id
::method checkpointSchema; return 'physics.rigid-body-state/0.1'
::method exportContinuationState
 expose _state
 return .RigidBodyFreezeState~new(_state~velocity,_state~angularVelocity,_state~force,_state~torque)
::method restoreContinuationState
 expose _state
 use strict arg s
 _state~velocity=s~velocity; _state~angularVelocity=s~angularVelocity
 _state~clearAccumulators
 _state~applyForce(s~force); _state~applyTorque(s~torque)
 return _state

::class FreeSurfaceFreezeParticipant public
::method init
 expose _id _solver
 use strict arg identity,solver
 _id=identity;_solver=solver
::method checkpointIdentity; expose _id; return 'fluid.free-surface-2d:'_id
::method checkpointSchema; return 'physics.free-surface-2d/0.1'
::method exportContinuationState; expose _solver; return _solver~exportContinuationState
::method restoreContinuationState; expose _solver; use strict arg s; return _solver~restoreContinuationState(s)
