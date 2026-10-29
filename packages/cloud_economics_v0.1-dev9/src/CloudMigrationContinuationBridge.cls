/* Cloud Economics v0.1-dev7 -- native Migratable Job v0.2.2 read-only
 * continuation preflight and transfer-record variance.
 * Neither a native record nor a matching digest string is provider authority.
 * No begin/step/pause/fence/transfer/resume/commit method is called here.
 */
::class CloudContinuationAssessment public
::method init
  expose status reason estate definition migration expectedGiB destinationNode evidence
  use strict arg status,reason,estate=.nil,definition=.nil,migration=.nil,expectedGiB=0,destinationNode='',evidence=.nil
::attribute status get
::attribute reason get
::attribute estate get
::attribute definition get
::attribute migration get
::attribute expectedGiB get
::attribute destinationNode get
::attribute evidence get
::method dispatchable
  return .false
::method purchaseAllowed
  return .false
::method migrationAllowed
  return .false

::class CloudMigrationContinuationBridge public
::method assessPreflight
  /* Native job definition and hard destination policy must match the
   * existing allocator/Memory Fabric advisory for this very source lease.
   * This is only a preflight: checkpoint support and route capacity are not
   * attested by this interface. No job is paused, transferred or allocated. */
  use strict arg estate,running,offers,routes,definition,sourceRequest,destinationPolicy
  hold=.CloudContinuationAssessment~new('HOLD','NATIVE_CONTINUATION_EVIDENCE_REQUIRED')
  if estate==.nil | definition==.nil | sourceRequest==.nil | destinationPolicy==.nil then return hold
  if \estate~isA(.CloudMigrationEstateHandoff) | ,
     \definition~isA(.MigratableJobDefinition) | ,
     \sourceRequest~isA(.JobPlacementRequest) | ,
     \destinationPolicy~isA(.MigratableJobDestinationPolicy) then return hold
  if estate~status<>'NATIVE_ELIGIBLE_ADVISORY' then
    return .CloudContinuationAssessment~new('HOLD','DESTINATION_NOT_EXISTING_VERIFIED_CAPACITY')
  if estate~decision==.nil | estate~lease==.nil | estate~destinationEvidence==.nil | estate~context==.nil then return hold
  if estate~decision['status']<>'PAPER_MOVE_FAVORED' then return hold
  if definition~placementRequest\==sourceRequest | sourceRequest~jobId<>running['id'] | ,
     definition~jobId<>running['id'] | estate~lease~jobId<>definition~jobId then
    return .CloudContinuationAssessment~new('HOLD','JOB_OR_REQUEST_NOT_BOUND')
  if definition~runtimeId='' | definition~executableRevision='' | definition~runtimeGeneration='' then
    return .CloudContinuationAssessment~new('HOLD','PORTABLE_RUNTIME_IDENTITY_MISSING')
  if destinationPolicy~sourceNodeId<>estate~lease~nodeId then
    return .CloudContinuationAssessment~new('HOLD','SOURCE_NODE_POLICY_MISMATCH')
  if estate~destinationEvidence~hasIndex('binding')=.false then return hold
  dest=estate~destinationEvidence['binding']['node_id']
  if dest='' | dest=estate~lease~nodeId | \destinationPolicy~allows(dest) then
    return .CloudContinuationAssessment~new('HOLD','DESTINATION_MOBILITY_POLICY_DENIED')
  if definition~requireDifferentNode=.false then nop
  found=.false
  do node over definition~allowedDestinationNodeIds
    if node=dest then found=.true
  end
  if definition~allowedDestinationNodeIds~items>0 & \found then
    return .CloudContinuationAssessment~new('HOLD','DEFINITION_DESTINATION_DENIED')
  offerFound=.false
  do offer over offers
    if offer['id']=running['source_id'] then do
      if offer['runtime']<>definition~runtimeId then
        return .CloudContinuationAssessment~new('HOLD','SOURCE_RUNTIME_MISMATCH')
    end
    if offer['id']=estate~decision['selected'] then do
      offerFound=.true
      if offer['runtime']<>definition~runtimeId then
        return .CloudContinuationAssessment~new('HOLD','DESTINATION_RUNTIME_MISMATCH')
    end
  end
  if \offerFound then return hold
  expected=-1
  do route over routes
    if route['id']=estate~decision['route'] & route['dest_id']=estate~decision['selected'] then do
      expected=(running['state_gib']+0)+(route['staging_gib']+0)
    end
  end
  if expected<=0 then return .CloudContinuationAssessment~new('HOLD','TRANSFER_SIZE_NOT_ESTIMATED')
  return .CloudContinuationAssessment~new('PREFLIGHT_ADVISORY','CHECKPOINT_AND_TRANSFER_NOT_YET_ATTESTED', ,
    estate,definition,.nil,expected,dest)

::method assessTransfer
  /* This reconciles a native Migratable Job record with the preflight.
   * Source is normally FENCED by this stage: never re-check it as RUNNING.
   * An API record can be forged; external Storage Fabric digest checks,
   * current destination lease, committing authority and resume ACK remain
   * the sole responsibility of their respective runtime services. */
  use strict arg preflight,migration,checkpoint,transfer,nowEpochMs
  hold=.CloudContinuationAssessment~new('HOLD','MIGRATION_RECORDS_REQUIRED')
  if preflight==.nil | migration==.nil | checkpoint==.nil | transfer==.nil then return hold
  if \preflight~isA(.CloudContinuationAssessment) | ,
     \migration~isA(.MigratableJobMigration) | ,
     \checkpoint~isA(.MigratableJobCheckpointResult) | ,
     \transfer~isA(.MigratableJobTransferResult) then return hold
  if preflight~status<>'PREFLIGHT_ADVISORY' then return hold
  if migration~definition\==preflight~definition | migration~sourceLease\==preflight~estate~lease then
    return .CloudContinuationAssessment~new('HOLD','MIGRATION_SOURCE_IDENTITY_MISMATCH')
  if \checkpoint~ok | checkpoint~manifest==.nil then
    return .CloudContinuationAssessment~new('HOLD','CHECKPOINT_NOT_READY')
  m=checkpoint~manifest
  if \m~isA(.MigratableJobCheckpointManifest) | migration~checkpointManifest\==m then
    return .CloudContinuationAssessment~new('HOLD','CHECKPOINT_MANIFEST_NOT_BOUND')
  d=preflight~definition; s=migration~sourceLease
  if m~jobId<>d~jobId | m~migrationId<>migration~migrationId | ,
     m~partitionId<>d~partitionId | m~runtimeId<>d~runtimeId | ,
     m~runtimeGeneration<>d~runtimeGeneration | m~executableRevision<>d~executableRevision | ,
     m~sourceNodeId<>s~nodeId | m~sourcePlacementId<>s~placementId | ,
     m~sourceOwnershipEpoch<>s~ownershipEpoch then
    return .CloudContinuationAssessment~new('HOLD','CHECKPOINT_IDENTITY_INCONSISTENT')
  if m~createdEpochMs<=0 | m~createdEpochMs>nowEpochMs | ,
     m~sourceExecutionPausedEpochMs<=0 | ,
     m~sourceExecutionPausedEpochMs>m~createdEpochMs | ,
     m~sourceExecutionStartedEpochMs>m~sourceExecutionPausedEpochMs then
    return .CloudContinuationAssessment~new('HOLD','CHECKPOINT_CLOCK_INCONSISTENT')
  if checkpoint~transferRef='' | checkpoint~transferRef<>migration~checkpointTransferRef then
    return .CloudContinuationAssessment~new('HOLD','CHECKPOINT_TRANSFER_REFERENCE_INCONSISTENT')
  if \migration~sourceFenced | \migration~sourceAdmissionReleased | ,
     migration~destinationLease==.nil then
    return .CloudContinuationAssessment~new('HOLD','SOURCE_FENCE_OR_DESTINATION_LEASE_ABSENT')
  target=migration~destinationLease
  if \target~isA(.JobNodePlacementLease) | target~jobId<>d~jobId | ,
     target~nodeId<>preflight~destinationNode | target~ownershipEpoch<=s~ownershipEpoch then
    return .CloudContinuationAssessment~new('HOLD','DESTINATION_LEASE_RECORD_MISMATCH')
  if migration~state<>.MigratableJobMigrationState~COMMITTING & ,
     migration~state<>.MigratableJobMigrationState~AWAITING_DESTINATION & ,
     migration~state<>.MigratableJobMigrationState~RUNNING then
    return .CloudContinuationAssessment~new('HOLD','MIGRATION_STAGE_NOT_TRANSFERRED')
  if \transfer~completed | transfer~verificationRef='' | ,
     transfer~destinationCheckpointRef='' | transfer~bytesTransferred<=0 then
    return .CloudContinuationAssessment~new('HOLD','TRANSFER_NOT_COMPLETED')
  if transfer~verificationRef<>migration~transferVerificationRef | ,
     transfer~destinationCheckpointRef<>migration~destinationCheckpointRef then
    return .CloudContinuationAssessment~new('HOLD','TRANSFER_RECORD_NOT_BOUND')
  /* Transfer cost variation is retrospective information only. A successful
   * record says nothing about digest authentication or remaining spend. */
  numeric digits 20
  g=transfer~bytesTransferred/1073741824
  estimate=preflight~expectedGiB
  quoted=preflight~estate~decision['breakdown']['transfer']+0
  actual=quoted*g/estimate
  e=.directory~new
  e['projected_transfer_gib']=estimate
  e['observed_transfer_gib']=g
  e['estimated_transfer_usd']=quoted
  e['estimated_charge_at_observed_bytes_usd']=actual
  e['transfer_cost_variance_usd']=actual-quoted
  e['checkpoint_id']=m~checkpointId
  e['migration_id']=migration~migrationId
  e['verification_ref']=transfer~verificationRef
  e['destination_checkpoint_ref']=transfer~destinationCheckpointRef
  e['accounting_status']='NOT_POSTED_PROVIDER_INVOICE_NOT_RECONCILED'
  e['capacity_status']='DESTINATION_LEASE_NOT_REVERIFIED'
  return .CloudContinuationAssessment~new('TRANSFER_RECORD_ADVISORY', ,
    'NATIVE_RECORDS_MATCH_NOT_CRYPTOGRAPHICALLY_VERIFIED', ,
    preflight~estate,d,migration,estimate,preflight~destinationNode,e)

::requires 'CloudMigrationEstateBridge.cls'
::requires 'MigratableJob.cls'
