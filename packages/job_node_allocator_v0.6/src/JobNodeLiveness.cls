/* ooRexx Job-to-Node Allocator v0.5 liveness and ownership fencing. */

::class JobNodeHeartbeat public
::attribute nodeId get
::attribute capabilityGeneration get
::attribute sequence get
::attribute issuedEpochMs get
::attribute expiresEpochMs get
::attribute proofRef get
::attribute signature
::method init
  expose nodeId capabilityGeneration sequence issuedEpochMs expiresEpochMs proofRef signature
  use strict arg nodeIdArg, capabilityGenerationArg, sequenceArg, issuedArg, expiresArg, proofRefArg="", signatureArg=""
  nodeId=nodeIdArg~string; capabilityGeneration=capabilityGenerationArg+0; sequence=sequenceArg+0
  issuedEpochMs=issuedArg+0; expiresEpochMs=expiresArg+0; proofRef=proofRefArg~string; signature=signatureArg~string
::method canonical
  expose nodeId capabilityGeneration sequence issuedEpochMs expiresEpochMs proofRef
  return "job.node.heartbeat/1;node="||nodeId||";capGen="||capabilityGeneration||";seq="||sequence||";issued="||issuedEpochMs||";expires="||expiresEpochMs||";proofRef="||proofRef
::method isExpired
  expose expiresEpochMs
  use strict arg nowEpochMs
  return nowEpochMs+0 >= expiresEpochMs

::class JobNodeHeartbeatProofAuthority public
::method sign abstract
::method verify abstract

::class JobNodeLivenessRegistry public
::method init
  expose capabilityRegistry proofAuthority heartbeats rejected
  use strict arg capabilityRegistryArg, proofAuthorityArg
  if capabilityRegistryArg==.nil then raise syntax 88.900 array("capability registry required")
  if proofAuthorityArg==.nil then raise syntax 88.900 array("heartbeat proof authority required")
  capabilityRegistry=capabilityRegistryArg; proofAuthority=proofAuthorityArg
  heartbeats=.directory~new; rejected=.directory~new
::method recordHeartbeat guarded
  expose capabilityRegistry proofAuthority heartbeats rejected
  use strict arg heartbeat, nowEpochMs
  if heartbeat==.nil then return .false
  nodeId=heartbeat~nodeId
  cap=capabilityRegistry~capability(nodeId)
  if cap==.nil then do; rejected[nodeId]="HEARTBEAT_UNKNOWN_NODE"; return .false; end
  if \cap~online then do; rejected[nodeId]="HEARTBEAT_NODE_REVOKED"; return .false; end
  if cap~generation<>heartbeat~capabilityGeneration then do; rejected[nodeId]="HEARTBEAT_CAPABILITY_GENERATION_MISMATCH"; return .false; end
  if heartbeat~expiresEpochMs<=heartbeat~issuedEpochMs then do; rejected[nodeId]="HEARTBEAT_INVALID_WINDOW"; return .false; end
  if heartbeat~isExpired(nowEpochMs) then do; rejected[nodeId]="HEARTBEAT_EXPIRED"; return .false; end
  if \proofAuthority~verify(heartbeat~canonical,heartbeat~signature) then do; rejected[nodeId]="HEARTBEAT_PROOF_INVALID"; return .false; end
  old=heartbeats[nodeId]
  if old<>.nil then if heartbeat~sequence<=old~sequence then do; rejected[nodeId]="HEARTBEAT_SEQUENCE_NOT_ADVANCING"; return .false; end
  heartbeats[nodeId]=heartbeat
  rejected~remove(nodeId)
  return .true
::method heartbeat guarded
  expose heartbeats
  use strict arg nodeId
  return heartbeats[nodeId~string]
::method isLive guarded
  expose capabilityRegistry heartbeats
  use strict arg nodeId, nowEpochMs
  cap=capabilityRegistry~capability(nodeId)
  if cap==.nil | \cap~online then return .false
  hb=heartbeats[nodeId~string]
  if hb==.nil then return .false
  if hb~capabilityGeneration<>cap~generation then return .false
  return \hb~isExpired(nowEpochMs)
::method statusCode guarded
  expose capabilityRegistry heartbeats rejected
  use strict arg nodeId, nowEpochMs
  nodeId=nodeId~string
  cap=capabilityRegistry~capability(nodeId)
  if cap==.nil then return "NODE_UNKNOWN"
  if \cap~online then return "NODE_REVOKED"
  hb=heartbeats[nodeId]
  if hb==.nil then do
    r=rejected[nodeId]
    if r<>.nil then return r
    return "HEARTBEAT_MISSING"
  end
  if hb~capabilityGeneration<>cap~generation then return "HEARTBEAT_CAPABILITY_GENERATION_MISMATCH"
  if hb~isExpired(nowEpochMs) then return "HEARTBEAT_STALE"
  return "LIVE"

::class JobNodeLivenessAssessor subclass JobNodeHardConstraintAssessor public
::method init
  expose liveness
  use strict arg livenessArg
  liveness=livenessArg
::method assess
  expose liveness
  use strict arg placementRequest, capability, capacity, nowEpochMs
  a=.array~new
  if capability==.nil then return a
  if \liveness~isLive(capability~nodeId,nowEpochMs) then a~append(liveness~statusCode(capability~nodeId,nowEpochMs))
  return a

/* Current ownership is a fence, not merely an informational lease table.
 * Each replacement gets a monotonically increasing epoch per job. */
::class JobNodeOwnershipRegistry public
::method init
  expose active epochs
  active=.directory~new; epochs=.directory~new
::method nextEpoch guarded
  expose epochs
  use strict arg jobId
  k=jobId~string
  e=epochs[k]
  if e==.nil then e=0
  e+=1; epochs[k]=e
  return e
::method claim guarded
  expose active epochs
  use strict arg lease, nowEpochMs
  if lease==.nil then return .false
  k=lease~jobId
  cur=active[k]
  if cur<>.nil then if \cur~isExpired(nowEpochMs) & cur~placementId<>lease~placementId then return .false
  known=epochs[k]
  if known==.nil then known=0
  if lease~ownershipEpoch<known then return .false
  if lease~ownershipEpoch>known then epochs[k]=lease~ownershipEpoch
  active[k]=lease
  return .true
::method current guarded
  expose active
  use strict arg jobId, nowEpochMs
  cur=active[jobId~string]
  if cur==.nil then return .nil
  if cur~isExpired(nowEpochMs) then return .nil
  return cur
::method isCurrent guarded
  expose active
  use strict arg lease, nowEpochMs
  if lease==.nil | lease~isExpired(nowEpochMs) then return .false
  cur=active[lease~jobId]
  if cur==.nil then return .false
  return cur~placementId=lease~placementId & cur~ownershipEpoch=lease~ownershipEpoch
::method epochFor guarded
  expose epochs
  use strict arg jobId
  e=epochs[jobId~string]
  if e==.nil then return 0
  return e
::method epochEntries guarded
  expose epochs
  out=.array~new
  do jobId over epochs
    out~append(.array~of(jobId,epochs[jobId]))
  end
  return out
::method activeLeases guarded
  expose active
  out=.array~new
  do jobId over active
    lease=active[jobId]
    if lease<>.nil then out~append(lease)
  end
  return out
::method restoreEpoch guarded
  expose epochs
  use strict arg jobId, epoch
  k=jobId~string; known=epochs[k]; if known==.nil then known=0
  if epoch+0>known then epochs[k]=epoch+0
  return .true
::method restoreCurrent guarded
  expose active epochs
  use strict arg lease
  if lease==.nil then return .false
  k=lease~jobId; known=epochs[k]; if known==.nil then known=0
  if lease~ownershipEpoch<known then return .false
  if lease~ownershipEpoch>known then epochs[k]=lease~ownershipEpoch
  active[k]=lease
  return .true
::method release guarded
  expose active
  use strict arg lease
  if lease==.nil then return .false
  cur=active[lease~jobId]
  if cur==.nil then return .true
  if cur~placementId<>lease~placementId | cur~ownershipEpoch<>lease~ownershipEpoch then return .false
  active~remove(lease~jobId)
  return .true
::method fence guarded
  expose active epochs
  use strict arg lease
  if lease==.nil then return .false
  cur=active[lease~jobId]
  if cur<>.nil then do
    if cur~placementId<>lease~placementId | cur~ownershipEpoch<>lease~ownershipEpoch then return .false
    active~remove(lease~jobId)
  end
  /* Advance immediately so a delayed claim carrying the old epoch cannot win. */
  k=lease~jobId; known=epochs[k]; if known==.nil then known=0
  if known<=lease~ownershipEpoch then epochs[k]=lease~ownershipEpoch+1
  return .true

/* Lifecycle coordinator permits recovery only after liveness loss or expiry.
 * It fences the old placement before asking the allocator for a replacement. */
::class JobNodePlacementLifecycle public
::method init
  expose allocator liveness ownership
  use strict arg allocatorArg, livenessArg, ownershipArg
  allocator=allocatorArg; liveness=livenessArg; ownership=ownershipArg
::method recover
  expose allocator liveness ownership
  use strict arg placementRequest, priorLease, nowEpochMs, leaseDurationMs=30000
  if priorLease==.nil then return .JobNodePlacementDecision~new(.false,"PRIOR_PLACEMENT_REQUIRED")
  if priorLease~jobId<>placementRequest~jobId then return .JobNodePlacementDecision~new(.false,"PRIOR_PLACEMENT_JOB_MISMATCH")
  if ownership~isCurrent(priorLease,nowEpochMs) then do
    if liveness~isLive(priorLease~nodeId,nowEpochMs) & \priorLease~isExpired(nowEpochMs) then return .JobNodePlacementDecision~new(.false,"PRIOR_NODE_STILL_LIVE",priorLease)
  end
  ownership~fence(priorLease)
  allocator~releasePlacement(priorLease)
  return allocator~allocate(placementRequest,nowEpochMs,leaseDurationMs)
::method destinationAccepts
  expose allocator liveness ownership
  use strict arg lease, placementRequest, nowEpochMs
  if \liveness~isLive(lease~nodeId,nowEpochMs) then return .false
  if \ownership~isCurrent(lease,nowEpochMs) then return .false
  return allocator~verifyLease(lease,placementRequest,nowEpochMs)

::requires "JobNodeAllocator.cls"
