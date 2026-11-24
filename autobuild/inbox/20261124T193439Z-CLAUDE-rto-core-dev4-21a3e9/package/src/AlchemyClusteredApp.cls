/* Alchemy clustered application base
 * API: alchemy.clustered.app/0.1
 * One-time cluster wiring: roles, replay, commit acknowledgement and fencing.
 * dev4 (alchemy_rto_core): rtoLifecycle records its state (see the end).
 */

::class AlchemyClusteredApp public
::attribute clusterId get
::attribute instanceId get
::attribute preferredRole get
::attribute resolvedRole get
::attribute roleSource get
::attribute activationEpoch get
::attribute replaySequence get
::attribute committedSequence get
::attribute rtoState get
::attribute replicaAvailable

::method init
  expose clusterId instanceId preferredRole resolvedRole roleSource activationEpoch -
         replaySequence committedSequence rtoState replicaAvailable transport
  use arg clusterId, instanceId, preferredRole, transport
  if preferredRole == "" then preferredRole = "AUTO"
  resolvedRole = "ROLE_UNRESOLVED"
  roleSource = "NONE"
  activationEpoch = 0
  replaySequence = 0
  committedSequence = 0
  rtoState = "JOINING"
  replicaAvailable = .false
  self~clusterInitialise

::method clusterInitialise
  expose rtoState
  rtoState = "NEGOTIATING"
  self~onClusterStart

/* Preferred role is advisory.  Resolved role requires a newer fencing epoch.
 * Every transition to ACTIVE converges on _transitionToActive so negotiated,
 * directed and failover promotion all perform the same rollback/bind/activate
 * sequence. */
::method resolveRole
  expose resolvedRole roleSource activationEpoch rtoState
  use arg role, epoch, source
  role = role~upper
  if epoch <= activationEpoch then return .false
  if role <> "ACTIVE" & role <> "REPLAY" then return .false
  if role = "ACTIVE" then return self~_transitionToActive(epoch, source)

  /* Transitioning away from ACTIVE is explicit deactivation. */
  if resolvedRole = "ACTIVE" then self~onDeactivate
  activationEpoch = epoch
  resolvedRole = "REPLAY"
  roleSource = source
  rtoState = "REPLAY"
  self~onReplayReady
  return .true

::method applyDirectedRole
  use strict arg assignment
  return self~resolveRole(assignment["role"], assignment["epoch"], "DIRECTED")

::method negotiateRole
  use strict arg role, epoch
  return self~resolveRole(role, epoch, "NEGOTIATED")

/* Single authority path into ACTIVE.  Rollback is mandatory even when the
 * incoming assignment is negotiated/direct rather than a failure promotion. */
::method _transitionToActive private
  expose resolvedRole roleSource activationEpoch rtoState replicaAvailable
  use strict arg newEpoch, source
  if newEpoch <= activationEpoch then return .false
  rtoState = "ACTIVATING"
  self~rtoRollbackToCommitted
  self~rtoBind(.Directory~new)
  self~rtoActivate(newEpoch)
  activationEpoch = newEpoch
  roleSource = source
  resolvedRole = "ACTIVE"
  replicaAvailable = .false
  rtoState = "ACTIVE"
  self~onActivate
  return .true

::method commitState
  expose resolvedRole replaySequence committedSequence
  use arg transactionId
  if resolvedRole <> "ACTIVE" then
    raise syntax 93.900 array("commitState requires ACTIVE role")
  replaySequence = replaySequence + 1
  self~rtoCommitLocalState
  committedSequence = replaySequence
  self~onCommit(transactionId, committedSequence)
  return committedSequence

/* Commit an externally proposed sequence after its mirror ACK.  Sequence
 * ownership stays in this superclass scope; subclasses never mutate fencing
 * or replay counters directly. */
::method commitMirroredState
  expose resolvedRole replaySequence committedSequence
  use strict arg transactionId, sequence
  if resolvedRole <> "ACTIVE" then
    raise syntax 93.900 array("commitMirroredState requires ACTIVE role")
  if sequence <> replaySequence + 1 then return .false
  replaySequence = sequence
  self~rtoCommitLocalState
  committedSequence = sequence
  self~onCommit(transactionId, committedSequence)
  return .true

/* Apply a speculative or already-committed replay image.  Authoritative ACTIVE
 * instances must never ingest replica state. */
::method applyReplay
  expose resolvedRole replaySequence committedSequence rtoState
  use strict arg state, sequence, committed
  if resolvedRole <> "REPLAY" then
    raise syntax 93.900 array("applyReplay requires REPLAY role")
  if sequence <= replaySequence then return .false
  self~rtoImportState(state)
  replaySequence = sequence
  if committed then do
    committedSequence = sequence
    self~rtoCommitReplayState
  end
  rtoState = "REPLAY"
  self~onReplay(sequence, committed)
  return .true

/* Turn the most recently replayed speculative state into committed state. */
::method acceptReplayCommit
  expose resolvedRole replaySequence committedSequence
  use strict arg sequence
  if resolvedRole <> "REPLAY" then
    raise syntax 93.900 array("acceptReplayCommit requires REPLAY role")
  if sequence <> replaySequence then return .false
  if sequence <= committedSequence then return .false
  self~rtoCommitReplayState
  committedSequence = sequence
  self~onReplayCommit(sequence)
  return .true

::method promote
  use strict arg newEpoch
  return self~_transitionToActive(newEpoch, "DIRECTED")

::method demote
  expose resolvedRole rtoState
  resolvedRole = "REPLAY"
  rtoState = "REPLAY"
  self~onDeactivate

/* Hooks */
::method onClusterStart; return
::method onActivate; return
::method onDeactivate; return
::method onReplayReady; return
::method onReplay; return
::method onReplayCommit; return
::method onCommit; return

/* RTO protocol hooks; subclasses provide state semantics. */
::method rtoIdentity; return self~clusterId || ":" || self~instanceId
::method rtoExportState abstract
::method rtoImportState abstract
::method rtoCommitLocalState abstract
::method rtoCommitReplayState abstract
::method rtoRollbackToCommitted abstract
::method rtoBind; return
::method rtoActivate; return
/* dev4 (Claude (Opus 5.5)): the lifecycle was not recorded (an empty method);
   now RECONSTRUCTED, BOUND and ACTIVE are kept, so a caller can tell an inert
   reconstruction from a live object. */
::method rtoLifecycleState
  expose rtoLifecycleState
  if symbol('rtoLifecycleState') \== 'VAR' then return 'NONE'
  return rtoLifecycleState
::method rtoLifecycle
  expose rtoLifecycleState
  use strict arg rtoLifecycleState
