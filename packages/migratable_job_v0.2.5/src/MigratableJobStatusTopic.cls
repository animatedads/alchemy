/* Queue Fabric publish/subscribe live-status adapter for Migratable Job v0.2.2.
 *
 * Status is published to a QueueTopicFabric topic.  Topic subscriptions fan the
 * same observation out to ordinary subscriber queues.  Migration command and
 * acknowledgement queues remain point-to-point and are intentionally separate.
 */
::class MigratableJobStatusTopicAddress public
::method encodeSegment class
  use strict arg value
  return value~string~c2x
::method migrationSubtopic class
  use strict arg jobId, migrationId
  return "job/"||self~encodeSegment(jobId)||"/migration/"||self~encodeSegment(migrationId)
::method jobPattern class
  use strict arg jobId
  return "job/"||self~encodeSegment(jobId)||"/#"
::method allPattern class
  return "job/#"

::class MigratableJobStatusTopicCodec public
::method toDirectory class
  use strict arg migration
  d=.directory~new
  d["schema"]="migratable.job.status/1"
  d["jobId"]=migration~definition~jobId
  d["migrationId"]=migration~migrationId
  d["state"]=migration~state
  d["resumeState"]=migration~resumeState
  d["sequence"]=migration~sequence
  d["startedEpochMs"]=migration~startedEpochMs
  d["updatedEpochMs"]=migration~updatedEpochMs
  d["sourceNodeId"]=migration~sourceLease~nodeId
  d["sourcePlacementId"]=migration~sourceLease~placementId
  d["sourceOwnershipEpoch"]=migration~sourceLease~ownershipEpoch
  d["sourceFenced"]=migration~sourceFenced
  d["sourceAdmissionReleased"]=migration~sourceAdmissionReleased
  d["destinationNodeId"]=""; d["destinationPlacementId"]=""; d["destinationOwnershipEpoch"]=0
  if migration~destinationLease<>.nil then do
    d["destinationNodeId"]=migration~destinationLease~nodeId
    d["destinationPlacementId"]=migration~destinationLease~placementId
    d["destinationOwnershipEpoch"]=migration~destinationLease~ownershipEpoch
  end
  d["checkpointId"]=""
  if migration~checkpointManifest<>.nil then d["checkpointId"]=migration~checkpointManifest~checkpointId
  d["handoffMode"]=migration~handoffMode
  d["handoffId"]=migration~handoffId
  d["destinationResumed"]=migration~destinationResumed
  d["executionRef"]=migration~executionRef
  d["failureCode"]=migration~failureCode
  d["failureDetail"]=migration~failureDetail
  return d

::class MigratableJobTopicStatusPublisher subclass MigratableJobStatusPublisher public
::attribute topicName get
::attribute principal get
::attribute persistent get
::attribute retained get
::method init
  expose topicFabric topicName principal persistent retained expirySeconds
  use strict arg topicFabricArg, topicNameArg, principalArg="", persistentArg=.false, retainedArg=.true, expirySecondsArg=0
  if topicFabricArg==.nil then raise syntax 88.900 array("QueueTopicFabric required")
  topicFabric=topicFabricArg; topicName=topicNameArg~string; principal=principalArg~string
  persistent=(persistentArg==.true); retained=(retainedArg==.true); expirySeconds=expirySecondsArg+0
  if topicName="" then raise syntax 88.900 array("status topic name required")
::method publish
  expose topicFabric topicName principal persistent retained expirySeconds
  use strict arg migration
  payload=.MigratableJobStatusTopicCodec~toDirectory(migration)
  headers=.table~new
  headers["migratable-job-schema"]="migratable.job.status/1"
  headers["migratable-job-id"]=migration~definition~jobId
  headers["migratable-job-migration-id"]=migration~migrationId
  headers["migratable-job-sequence"]=migration~sequence
  options=.table~new
  options["subtopic"]=.MigratableJobStatusTopicAddress~migrationSubtopic(migration~definition~jobId,migration~migrationId)
  options["headers"]=headers
  options["persistent"]=persistent
  options["retain"]=retained
  options["correlationId"]=migration~migrationId||":"||migration~sequence
  if expirySeconds>0 then options["expirySeconds"]=expirySeconds
  r=topicFabric~publish(topicName,payload,options,principal)
  if r==.nil then return .MigratableJobStatusPublishResult~failure("STATUS_TOPIC_NO_RESULT")
  if \r~ok then return .MigratableJobStatusPublishResult~failure(r~code,r~detail)
  return .MigratableJobStatusPublishResult~success("published sequence "||migration~sequence)

::requires "MigratableJob.cls"
::requires "ObjectQueueTopics.cls"
