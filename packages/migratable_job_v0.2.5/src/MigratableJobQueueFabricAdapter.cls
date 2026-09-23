/* Queue Fabric transport adapter for Migratable Job v0.2. */
::class MigratableJobQueueCommand public
::attribute operation get
::attribute migrationId get
::attribute jobId get
::attribute checkpointId get
::attribute checkpointRef get
::attribute verificationRef get
::attribute commitEvidenceRef get
::method init
  expose operation migrationId jobId checkpointId checkpointRef verificationRef commitEvidenceRef
  use strict arg operationArg, migrationArg, jobArg, checkpointArg="", checkpointRefArg="", verificationArg="", commitEvidenceArg=""
  operation=operationArg~string~upper; migrationId=migrationArg~string; jobId=jobArg~string; checkpointId=checkpointArg~string; checkpointRef=checkpointRefArg~string; verificationRef=verificationArg~string; commitEvidenceRef=commitEvidenceArg~string
::method canonical
  expose operation migrationId jobId checkpointId checkpointRef verificationRef commitEvidenceRef
  return "operation="||operation||";migration="||migrationId||";job="||jobId||";checkpoint="||checkpointId||";checkpointRef="||checkpointRef||";verification="||verificationRef||";commit="||commitEvidenceRef

::class MigratableJobQueueFabricDispatcher public
::method init
  expose dispatcher
  use strict arg dispatcherArg
  dispatcher=dispatcherArg
::method dispatchResume
  expose dispatcher
  use strict arg migration, principal="", options=.nil
  if migration~destinationLease==.nil | migration~checkpointManifest==.nil then return .QueueOperationResult~failure("MIGRATION_NOT_READY")
  command=.MigratableJobQueueCommand~new("RESUME",migration~migrationId,migration~definition~jobId,migration~checkpointManifest~checkpointId,migration~destinationCheckpointRef,migration~transferVerificationRef,migration~commitEvidenceRef)
  envelope=.JobNodeDispatchEnvelope~new(migration~destinationLease,command)
  return dispatcher~dispatch(envelope,principal,options)

::requires "MigratableJob.cls"
::requires "JobNodeDispatch.cls"
::requires "JobNodeQueueFabricAdapter.cls"

/* v0.2 inter-node handoff path.  Unlike the legacy in-process
 * JobNodeDispatchEnvelope helper above, the payload is a QueueGraph-persistable
 * Directory so it can cross QueueChannelFabric store-and-forward/socket links. */
::class MigratableJobQueueChannelTransport subclass MigratableJobHandoffTransport public
::method init
  expose fabric queues replyTo persistent principal
  use strict arg fabricArg, replyToArg="", persistentArg=.true, principalArg=""
  fabric=fabricArg; replyTo=replyToArg~string; persistent=(persistentArg==.true); principal=principalArg~string
  if fabric==.nil then raise syntax 88.900 array("QueueChannelFabric required")
  queues=.directory~new
::method bindNodeQueue
  expose queues
  use strict arg nodeId, queueOrAlias
  queues[nodeId~string~upper]=queueOrAlias~string
  return self
::method mode
  return .MigratableJobHandoffMode~QUEUE
::method submit
  expose fabric queues replyTo persistent principal
  use strict arg migration, nowEpochMs
  if migration~handoffId="" then return .MigratableJobHandoffSubmission~failure("HANDOFF_ID_REQUIRED")
  q=queues[migration~destinationLease~nodeId~upper]
  if q==.nil then return .MigratableJobHandoffSubmission~failure("DESTINATION_QUEUE_UNBOUND",migration~destinationLease~nodeId)
  i=.MigratableJobHandoffInstruction~fromMigration(migration,self~mode,migration~handoffId,nowEpochMs,replyTo)
  if i==.nil then return .MigratableJobHandoffSubmission~failure("HANDOFF_INSTRUCTION_INCOMPLETE")
  payload=.MigratableJobHandoffCodec~instructionToDirectory(i)
  headers=.table~new
  headers["migratable-job-schema"]="migratable.job.handoff/2"
  headers["migratable-job-id"]=i~jobId
  headers["migratable-job-handoff-id"]=i~handoffId
  headers["job-node-placement-id"]=i~destinationPlacementId
  headers["job-node-execution-node-id"]=i~destinationNodeId
  headers["job-node-ownership-epoch"]=i~destinationOwnershipEpoch
  options=.table~new; options["headers"]=headers; options["correlationId"]=i~handoffId; options["replyTo"]=replyTo; options["persistent"]=persistent
  r=fabric~put(q,payload,options,principal)
  if r==.nil | \r~ok then do
    code="QUEUE_HANDOFF_FAILED"; detail=""
    if r<>.nil then do; code=r~code; detail=r~detail; end
    return .MigratableJobHandoffSubmission~failure(code,detail)
  end
  ref="queue:"||q
  v=r~value; if v<>.nil then if v~hasMethod("TRANSFERID") then ref=ref||":"||v~transferId
  return .MigratableJobHandoffSubmission~success(i~handoffId,ref)

::class MigratableJobQueueWorker public
::method init
  expose fabric queueName runner ackPrincipal ackPersistent
  use strict arg fabricArg, queueNameArg, runnerArg, ackPrincipalArg="", ackPersistentArg=.true
  fabric=fabricArg; queueName=queueNameArg~string; runner=runnerArg; ackPrincipal=ackPrincipalArg~string; ackPersistent=(ackPersistentArg==.true)
::method runOne
  expose fabric queueName runner ackPrincipal ackPersistent
  use strict arg nowEpochMs, workerPrincipal
  qm=fabric~queueManager
  claim=qm~claim(queueName,workerPrincipal)
  if claim==.nil | \claim~ok then return .nil
  package=claim~value
  instruction=.MigratableJobHandoffCodec~instructionFromDirectory(package~payload)
  if instruction==.nil then do
    ignore=qm~release(queueName,package~packageId,package~claimToken,workerPrincipal,"invalid migratable-job handoff")
    return .nil
  end
  ack=runner~start(instruction,nowEpochMs)
  if ack==.nil then do
    ignore=qm~release(queueName,package~packageId,package~claimToken,workerPrincipal,"destination runner returned no acknowledgement")
    return .nil
  end
  if instruction~replyTo<>"" then do
    options=.table~new; options["correlationId"]=instruction~handoffId; options["persistent"]=ackPersistent
    qr=fabric~put(instruction~replyTo,.MigratableJobHandoffCodec~acknowledgementToDirectory(ack),options,ackPrincipal)
    if qr==.nil | \qr~ok then do
      ignore=qm~release(queueName,package~packageId,package~claimToken,workerPrincipal,"acknowledgement delivery failed")
      return .nil
    end
  end
  ar=qm~ack(queueName,package~packageId,package~claimToken,workerPrincipal)
  if ar==.nil | \ar~ok then return .nil
  return ack

::class MigratableJobQueueAcknowledgementReader public
::method init
  expose queueManager queueName
  use strict arg queueManagerArg, queueNameArg
  queueManager=queueManagerArg; queueName=queueNameArg~string
::method get
  expose queueManager queueName
  use strict arg principal
  r=queueManager~get(queueName,principal)
  if r==.nil | \r~ok then return .nil
  return .MigratableJobHandoffCodec~acknowledgementFromDirectory(r~value~payload)

::requires "MigratableJobHandoff.cls"
::requires "ObjectQueueChannels.cls"
