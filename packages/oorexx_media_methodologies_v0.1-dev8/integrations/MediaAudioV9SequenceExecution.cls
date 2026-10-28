/* MediaAudioV9SequenceExecution.cls
 * Optional bridge from Media Methodologies experiment work into Audio V9
 * Candidate20 sequence-locality contracts.
 *
 * Authority rule: route selection is planning evidence only.  Execution is
 * authorized only by the external Job-to-Node lease referenced by Audio V9.
 * Storage Fabric remains durable source identity and Memory Fabric remains
 * owner of transient fenced resident blocks.
 */
::options numeric inherit

::class MediaSequenceExecutionEvidence public
::method init
  expose methodologyId implementationId policy units moves memoryHits memoryMisses bytesMoved bytesAvoided continuationBytesMoved failovers maxAbsError equivalent authorityEffect sourceAuthorityUnchanged
  use strict arg methodologyArg, implementationArg, policyArg, metricsArg, maxAbsErrorArg=0, toleranceArg=0
  methodologyId=translate(strip(methodologyArg)); implementationId=strip(implementationArg)
  policy=translate(strip(policyArg))
  if methodologyId='' | implementationId='' | policy='' then raise syntax 93.900 array('methodology, implementation and policy are required')
  if metricsArg==.nil then raise syntax 93.900 array('sequence trial metrics are required')
  units=metricsArg~units; moves=metricsArg~moves; memoryHits=metricsArg~memoryHits; memoryMisses=metricsArg~memoryMisses
  bytesMoved=metricsArg~bytesMoved; bytesAvoided=metricsArg~bytesAvoided
  continuationBytesMoved=metricsArg~continuationBytesMoved; failovers=metricsArg~failovers
  maxAbsError=maxAbsErrorArg
  if maxAbsError<=toleranceArg then equivalent=.true; else equivalent=.false
  authorityEffect='EXECUTION_STRATEGY_QUALIFICATION_ONLY'
  sourceAuthorityUnchanged=.true
::attribute methodologyId get
::attribute implementationId get
::attribute policy get
::attribute units get
::attribute moves get
::attribute memoryHits get
::attribute memoryMisses get
::attribute bytesMoved get
::attribute bytesAvoided get
::attribute continuationBytesMoved get
::attribute failovers get
::attribute maxAbsError get
::attribute equivalent get
::attribute authorityEffect get
::attribute sourceAuthorityUnchanged get

::method asDirectory
  expose methodologyId implementationId policy units moves memoryHits memoryMisses bytesMoved bytesAvoided continuationBytesMoved failovers maxAbsError equivalent authorityEffect sourceAuthorityUnchanged
  d=.directory~new
  d['METHODOLOGY_ID']=methodologyId; d['IMPLEMENTATION_ID']=implementationId; d['POLICY']=policy
  d['UNITS']=units; d['MOVES']=moves; d['MEMORY_HITS']=memoryHits; d['MEMORY_MISSES']=memoryMisses
  d['BYTES_MOVED']=bytesMoved; d['BYTES_AVOIDED']=bytesAvoided; d['CONTINUATION_BYTES_MOVED']=continuationBytesMoved
  d['FAILOVERS']=failovers; d['MAX_ABS_ERROR']=maxAbsError; d['EQUIVALENT']=equivalent
  d['AUTHORITY_EFFECT']=authorityEffect; d['SOURCE_AUTHORITY_UNCHANGED']=sourceAuthorityUnchanged
  return d

::class MediaAudioV9SequenceExecutionBridge public
::method policies class
  return .array~of('FIXED_EXECUTION','MOVE_TO_STORAGE','MOVE_TO_MEMORY','LOOKAHEAD_LOCALITY','STATE_AFFINITY','REDUNDANT_CONTINUATION','ECONOMIC','ADAPTIVE')

/* Build the Audio-owned non-mutating planning request.  The caller supplies
 * real AudioV9SequenceUnit / AudioV9MiEvidence objects from Candidate20. */
::method planningRequest class
  use strict arg jobId, policy, currentMi, currentUnit, horizon, candidates, continuationBytes=0, workingSetBytes=0, resilience='CHECKPOINTED'
  if currentUnit==.nil then raise syntax 93.900 array('AudioV9SequenceUnit is required')
  if candidates==.nil then raise syntax 93.900 array('candidate MI evidence is required')
  return .AudioV9SequencePlanningRequest~new(jobId,policy,currentMi,currentUnit,horizon,candidates,continuationBytes,workingSetBytes,resilience)

/* Deliberately returns only the Audio trial planner's proposal.  This bridge
 * cannot create AudioV9AuthorizedSequenceRoute or mint a placement lease. */
::method trialProposal class
  use strict arg planningRequest
  if planningRequest==.nil then raise syntax 93.900 array('planning request is required')
  return .AudioV9SequenceTrialPlanner~propose(planningRequest)

::method qualificationEvidence class
  use strict arg methodologyId, implementationId, policy, metrics, maxAbsError=0, tolerance=0
  return .MediaSequenceExecutionEvidence~new(methodologyId,implementationId,policy,metrics,maxAbsError,tolerance)
::requires 'AudioV9SequenceExecutionExperiment.cls'
