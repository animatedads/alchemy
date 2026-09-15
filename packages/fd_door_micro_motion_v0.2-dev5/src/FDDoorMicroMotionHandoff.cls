/* FD Door Micro Motion v0.2-dev5 destination handoff bridge.
 *
 * Queue/file handoffs MUST enter through Migratable Job v0.2.4
 * migratable.job.start/1 HANDOFF.  This local executor only converts the
 * committed handoff instruction into the FD execution-adapter seam; it does
 * not allocate/fence ownership or invent commit authority.
 */


::class FDDoorCommittedLeaseView public
::attribute nodeId get
::attribute placementId get
::attribute ownershipEpoch get
::method init
  expose nodeId placementId ownershipEpoch
  use strict arg nodeArg, placementArg, epochArg
  nodeId=nodeArg~string; placementId=placementArg~string; ownershipEpoch=epochArg+0
  if nodeId='' | placementId='' | ownershipEpoch<1 then raise syntax 88.900 array('invalid committed FD destination lease view')

::class FDDoorMicroMotionHandoffExecutor subclass MigratableJobDestinationExecutor public
::method init
  expose application executionAdapter
  use strict arg applicationArg, executionAdapterArg
  application=applicationArg; executionAdapter=executionAdapterArg
  if application==.nil | executionAdapter==.nil then raise syntax 88.900 array('FD handoff application and execution adapter required')

::method start
  expose application executionAdapter
  use strict arg instruction, checkpointRef, nowEpochMs
  if instruction==.nil then return .MigratableJobResumeResult~failure('FD_HANDOFF_INSTRUCTION_MISSING')
  definition=application~definition(.nil)
  if definition==.nil then return .MigratableJobResumeResult~failure('FD_HANDOFF_DEFINITION_MISSING')
  if instruction~jobId<>definition~jobId | instruction~definitionRef<>definition~definitionRef | instruction~partitionId<>definition~partitionId then return .MigratableJobResumeResult~failure('FD_HANDOFF_DEFINITION_MISMATCH')
  if instruction~runtimeId<>'' & definition~runtimeId<>'' & instruction~runtimeId<>definition~runtimeId then return .MigratableJobResumeResult~failure('FD_HANDOFF_RUNTIME_MISMATCH')
  if instruction~runtimeGeneration<>'' & definition~runtimeGeneration<>'' & instruction~runtimeGeneration<>definition~runtimeGeneration then return .MigratableJobResumeResult~failure('FD_HANDOFF_RUNTIME_GENERATION_MISMATCH')
  if instruction~executableRevision<>'' & definition~executableRevision<>'' & instruction~executableRevision<>definition~executableRevision then return .MigratableJobResumeResult~failure('FD_HANDOFF_REVISION_MISMATCH')
  if instruction~commitEvidenceRef='' | instruction~verificationRef='' then return .MigratableJobResumeResult~failure('FD_HANDOFF_COMMIT_OR_VERIFICATION_MISSING')

  inputEvidence=''
  if definition~sourceInputs<>.nil then if definition~sourceInputs~items>0 then inputEvidence=definition~sourceInputs[1]
  outputEvidence=''
  if definition~outputRefs<>.nil then if definition~outputRefs~items>0 then outputEvidence=definition~outputRefs[1]

  /* The FD adapter needs only node/placement/ownership identity. Preserve
   * exactly the committed handoff values instead of fabricating lease expiry,
   * capability or admission fields that remain Job-to-Node authority. */
  destinationLease=.FDDoorCommittedLeaseView~new(instruction~destinationNodeId,instruction~destinationPlacementId,instruction~destinationOwnershipEpoch)
  manifest=.MigratableJobCheckpointManifest~new(instruction~checkpointId,instruction~jobId,instruction~migrationId,instruction~partitionId,instruction~sourceNodeId,instruction~sourcePlacementId,instruction~sourceOwnershipEpoch,instruction~runtimeId,instruction~runtimeGeneration,instruction~executableRevision,checkpointRef,instruction~checkpointStateDigest,inputEvidence,outputEvidence,instruction~createdEpochMs,0,instruction~createdEpochMs,0)
  if executionAdapter~hasMethod('BINDDESTINATIONSTARTID') then ignore=executionAdapter~bindDestinationStartId(instruction~handoffId)
  return executionAdapter~resumeFromCheckpoint(definition,destinationLease,manifest,checkpointRef,nowEpochMs)

::requires 'FDDoorMicroMotionStarter.cls'
::requires 'FDDoorMicroMotionMigratable.cls'
::requires 'MigratableJobStarter.cls'
