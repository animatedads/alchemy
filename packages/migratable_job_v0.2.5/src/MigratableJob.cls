/* ooRexx Migratable Job v0.2
 * Planned, fail-closed migration of a paused/checkpointed job between
 * Job-to-Node placement owners.  Queue Fabric remains transport authority;
 * Storage Fabric remains checkpoint/materialisation authority.
 */

::class MigratableJobBuild public
::constant VERSION "0.2.5"
::constant API "migratable.job/0.2"

/* Epoch values are routinely above 10^12 milliseconds. ooRexx's default
 * NUMERIC DIGITS 9 cannot round-trip those values exactly through +0. Keep all
 * Migratable Job epoch coercion behind this helper. */
::class MigratableJobTime public
::method number class
  use strict arg value
  numeric digits 30
  return value+0
::method nowEpochMs class
  numeric digits 30
  return time('T')*1000

::class MigratableJobMigrationState public
::constant NEW "NEW"
::constant PREPARING "PREPARING"
::constant READY "READY"
::constant TRANSFERRING "TRANSFERRING"
::constant COMMITTING "COMMITTING"
::constant AWAITING_DESTINATION "AWAITING_DESTINATION"
::constant RUNNING "RUNNING"
::constant PAUSED "PAUSED"
::constant FAILED "FAILED"

::class MigratableJobTransferStatus public
::constant COMPLETED "COMPLETED"
::constant PAUSED "PAUSED"
::constant FAILED "FAILED"

::class MigratableJobArray public
::method canonical class
  use arg values=.nil
  if values==.nil then return ""
  a=.array~new
  do v over values; a~append(v~string); end
  if a~items=0 then return ""
  a~sort
  out=""
  do i=1 to a~items
    if i>1 then out=out||"1f"x
    out=out||a[i]
  end
  return out

/* A stable job definition. placementRequest remains the allocator's native
 * authority-bearing request object. Other fields are forensic identity/evidence
 * references and are deliberately value-like. */
::class MigratableJobDefinition public
::attribute jobId get
::attribute definitionRef get
::attribute partitionId get
::attribute ownerNodeId get
::attribute placementRequest get
::attribute runtimeId get
::attribute runtimeGeneration get
::attribute executableRevision get
::attribute sourceInputs get
::attribute outputRefs get
::attribute requireDifferentNode get
::attribute allowedDestinationNodeIds get
::method init
  expose jobId definitionRef partitionId ownerNodeId placementRequest runtimeId runtimeGeneration executableRevision sourceInputs outputRefs requireDifferentNode allowedDestinationNodeIds
  use strict arg jobIdArg, placementRequestArg, definitionRefArg="", partitionArg="", ownerArg="", runtimeArg="", runtimeGenerationArg="", executableRevisionArg="", sourceInputsArg=.nil, outputRefsArg=.nil, requireDifferentArg=.true, allowedDestinationsArg=.nil
  jobId=jobIdArg~string
  if jobId="" then raise syntax 88.900 array("job id required")
  placementRequest=placementRequestArg
  if placementRequest==.nil then raise syntax 88.900 array("placement request required")
  if placementRequest~jobId<>jobId then raise syntax 88.900 array("placement request job mismatch")
  definitionRef=definitionRefArg~string
  if definitionRef="" then definitionRef="job:"||jobId
  partitionId=partitionArg~string; ownerNodeId=ownerArg~string
  if ownerNodeId="" then ownerNodeId=placementRequest~ownerNodeId
  runtimeId=runtimeArg~string; runtimeGeneration=runtimeGenerationArg~string
  executableRevision=executableRevisionArg~string
  if sourceInputsArg==.nil then sourceInputs=.array~new; else sourceInputs=sourceInputsArg
  if outputRefsArg==.nil then outputRefs=.array~new; else outputRefs=outputRefsArg
  requireDifferentNode=(requireDifferentArg==.true)
  if allowedDestinationsArg==.nil then allowedDestinationNodeIds=.array~new; else allowedDestinationNodeIds=allowedDestinationsArg
::method canonical
  expose jobId definitionRef partitionId ownerNodeId placementRequest runtimeId runtimeGeneration executableRevision sourceInputs outputRefs requireDifferentNode allowedDestinationNodeIds
  return "job="||jobId||";definition="||definitionRef||";partition="||partitionId||";owner="||ownerNodeId||";runtime="||runtimeId||";runtimeGen="||runtimeGeneration||";revision="||executableRevision||";inputs="||.MigratableJobArray~canonical(sourceInputs)||";outputs="||.MigratableJobArray~canonical(outputRefs)||";different="||requireDifferentNode||";allowed="||.MigratableJobArray~canonical(allowedDestinationNodeIds)||";placement={"||placementRequest~canonical||"}"

/* Durable checkpoint identity. No process-local handles belong here. */
::class MigratableJobCheckpointManifest public
::attribute checkpointId get
::attribute jobId get
::attribute migrationId get
::attribute partitionId get
::attribute sourceNodeId get
::attribute sourcePlacementId get
::attribute sourceOwnershipEpoch get
::attribute runtimeId get
::attribute runtimeGeneration get
::attribute executableRevision get
::attribute stateRef get
::attribute stateDigest get
::attribute inputEvidenceRef get
::attribute outputEvidenceRef get
::attribute createdEpochMs get
::attribute sourceExecutionStartedEpochMs get
::attribute sourceExecutionPausedEpochMs get
::attribute resumeSequence get
::method init
  expose checkpointId jobId migrationId partitionId sourceNodeId sourcePlacementId sourceOwnershipEpoch runtimeId runtimeGeneration executableRevision stateRef stateDigest inputEvidenceRef outputEvidenceRef createdEpochMs sourceExecutionStartedEpochMs sourceExecutionPausedEpochMs resumeSequence
  use strict arg checkpointArg, jobArg, migrationArg, partitionArg, sourceNodeArg, sourcePlacementArg, sourceEpochArg, runtimeArg="", runtimeGenerationArg="", revisionArg="", stateRefArg="", stateDigestArg="", inputEvidenceArg="", outputEvidenceArg="", createdArg=0, startedArg=0, pausedArg=0, resumeSequenceArg=0
  checkpointId=checkpointArg~string; jobId=jobArg~string; migrationId=migrationArg~string; partitionId=partitionArg~string
  sourceNodeId=sourceNodeArg~string; sourcePlacementId=sourcePlacementArg~string; sourceOwnershipEpoch=sourceEpochArg+0
  runtimeId=runtimeArg~string; runtimeGeneration=runtimeGenerationArg~string; executableRevision=revisionArg~string
  stateRef=stateRefArg~string; stateDigest=stateDigestArg~string; inputEvidenceRef=inputEvidenceArg~string; outputEvidenceRef=outputEvidenceArg~string
  createdEpochMs=.MigratableJobTime~number(createdArg); sourceExecutionStartedEpochMs=.MigratableJobTime~number(startedArg); sourceExecutionPausedEpochMs=.MigratableJobTime~number(pausedArg); resumeSequence=resumeSequenceArg+0
  if checkpointId="" | jobId="" | migrationId="" | sourceNodeId="" | sourcePlacementId="" then raise syntax 88.900 array("invalid migratable checkpoint manifest")
  if stateRef="" | stateDigest="" then raise syntax 88.900 array("checkpoint state reference and digest required")
::method canonical
  expose checkpointId jobId migrationId partitionId sourceNodeId sourcePlacementId sourceOwnershipEpoch runtimeId runtimeGeneration executableRevision stateRef stateDigest inputEvidenceRef outputEvidenceRef createdEpochMs sourceExecutionStartedEpochMs sourceExecutionPausedEpochMs resumeSequence
  return "checkpoint="||checkpointId||";job="||jobId||";migration="||migrationId||";partition="||partitionId||";sourceNode="||sourceNodeId||";sourcePlacement="||sourcePlacementId||";sourceEpoch="||sourceOwnershipEpoch||";runtime="||runtimeId||";runtimeGen="||runtimeGeneration||";revision="||executableRevision||";stateRef="||stateRef||";stateDigest="||stateDigest||";inputs="||inputEvidenceRef||";outputs="||outputEvidenceRef||";created="||createdEpochMs||";started="||sourceExecutionStartedEpochMs||";paused="||sourceExecutionPausedEpochMs||";resume="||resumeSequence

::class MigratableJobCheckpointResult public
::attribute ok get
::attribute code get
::attribute manifest get
::attribute transferRef get
::attribute detail get
::method init
  expose ok code manifest transferRef detail
  use arg okArg, codeArg, manifestArg=.nil, transferRefArg="", detailArg=""
  ok=(okArg==.true); code=codeArg~string; manifest=manifestArg; transferRef=transferRefArg~string; detail=detailArg~string
::method success class
  use strict arg manifestArg, transferRefArg
  return self~new(.true,"CHECKPOINT_READY",manifestArg,transferRefArg,"")
::method failure class
  use arg codeArg, detailArg=""
  return self~new(.false,codeArg,.nil,"",detailArg)

::class MigratableJobTransferResult public
::attribute status get
::attribute verificationRef get
::attribute destinationCheckpointRef get
::attribute bytesTransferred get
::attribute detail get
::method init
  expose status verificationRef destinationCheckpointRef bytesTransferred detail
  use arg statusArg, verificationArg="", destinationRefArg="", bytesArg=0, detailArg=""
  status=statusArg~string~upper; verificationRef=verificationArg~string; destinationCheckpointRef=destinationRefArg~string; bytesTransferred=bytesArg+0; detail=detailArg~string
::method completed
  expose status
  return status=.MigratableJobTransferStatus~COMPLETED

::class MigratableJobCommitDecision public
::attribute allowed get
::attribute code get
::attribute evidenceRef get
::attribute detail get
::method init
  expose allowed code evidenceRef detail
  use arg allowedArg, codeArg, evidenceArg="", detailArg=""
  allowed=(allowedArg==.true); code=codeArg~string; evidenceRef=evidenceArg~string; detail=detailArg~string
::method allow class
  use arg evidenceArg=""
  return self~new(.true,"COMMIT_AUTHORISED",evidenceArg,"")
::method deny class
  use arg codeArg="COMMIT_DENIED", detailArg=""
  return self~new(.false,codeArg,"",detailArg)

::class MigratableJobResumeResult public
::attribute ok get
::attribute code get
::attribute executionRef get
::attribute detail get
::method init
  expose ok code executionRef detail
  use arg okArg, codeArg, executionArg="", detailArg=""
  ok=(okArg==.true); code=codeArg~string; executionRef=executionArg~string; detail=detailArg~string
::method success class
  use arg executionArg=""
  return self~new(.true,"RUNNING",executionArg,"")
::method failure class
  use arg codeArg, detailArg=""
  return self~new(.false,codeArg,"",detailArg)

/* Execution-runtime seam. Implementations must make pauseAndCheckpoint return
 * only after the source can no longer mutate checkpointed job state. */
::class MigratableJobExecutionAdapter public
::method pauseAndCheckpoint abstract
::method resumeFromCheckpoint abstract
::method retireSource
  return .true

::class MigratableJobTransferAdapter public
::method transfer abstract

::class MigratableJobCommitAuthority public
::method authorise abstract

/* Live status is observational fan-out, never migration authority.  Implementations
 * publish the current durable/reconciled snapshot to subscribers and must not turn
 * observer delivery failure into execution authority. */
::class MigratableJobStatusPublishResult public
::attribute ok get
::attribute code get
::attribute detail get
::method init
  expose ok code detail
  use strict arg okArg, codeArg="", detailArg=""
  ok=(okArg==.true); code=codeArg~string; detail=detailArg~string
::method success class
  use arg detailArg=""
  return self~new(.true,"",detailArg)
::method failure class
  use arg codeArg, detailArg=""
  return self~new(.false,codeArg,detailArg)

::class MigratableJobStatusPublisher public
::method publish abstract

/* Resume delivery is a separate authority from checkpoint movement.  A
 * transport may deliver the committed resume instruction through Queue Fabric
 * or export it for a manual/file handoff.  Delivery never grants execution
 * authority by itself: the instruction carries the already-issued commit
 * evidence and the destination must acknowledge a successful resume. */
::class MigratableJobHandoffMode public
::constant DIRECT "DIRECT"
::constant QUEUE "QUEUE"
::constant FILE "FILE"

::class MigratableJobHandoffInstruction public
::attribute handoffId get
::attribute mode get
::attribute migrationId get
::attribute jobId get
::attribute definitionRef get
::attribute partitionId get
::attribute checkpointId get
::attribute sourceNodeId get
::attribute sourcePlacementId get
::attribute sourceOwnershipEpoch get
::attribute destinationNodeId get
::attribute destinationPlacementId get
::attribute destinationOwnershipEpoch get
::attribute checkpointRef get
::attribute checkpointStateDigest get
::attribute verificationRef get
::attribute commitEvidenceRef get
::attribute runtimeId get
::attribute runtimeGeneration get
::attribute executableRevision get
::attribute createdEpochMs get
::attribute replyTo get
::method init
  expose handoffId mode migrationId jobId definitionRef partitionId checkpointId sourceNodeId sourcePlacementId sourceOwnershipEpoch destinationNodeId destinationPlacementId destinationOwnershipEpoch checkpointRef checkpointStateDigest verificationRef commitEvidenceRef runtimeId runtimeGeneration executableRevision createdEpochMs replyTo
  use strict arg handoffArg, modeArg, migrationArg, jobArg, definitionRefArg, partitionArg, checkpointArg, sourceNodeArg, sourcePlacementArg, sourceEpochArg, destinationNodeArg, destinationPlacementArg, destinationEpochArg, checkpointRefArg, checkpointDigestArg, verificationArg, commitEvidenceArg, runtimeArg="", runtimeGenerationArg="", revisionArg="", createdArg=0, replyToArg=""
  handoffId=handoffArg~string; mode=modeArg~string~upper; migrationId=migrationArg~string; jobId=jobArg~string
  definitionRef=definitionRefArg~string; partitionId=partitionArg~string; checkpointId=checkpointArg~string
  sourceNodeId=sourceNodeArg~string; sourcePlacementId=sourcePlacementArg~string; sourceOwnershipEpoch=sourceEpochArg+0
  destinationNodeId=destinationNodeArg~string; destinationPlacementId=destinationPlacementArg~string; destinationOwnershipEpoch=destinationEpochArg+0
  checkpointRef=checkpointRefArg~string; checkpointStateDigest=checkpointDigestArg~string; verificationRef=verificationArg~string; commitEvidenceRef=commitEvidenceArg~string
  runtimeId=runtimeArg~string; runtimeGeneration=runtimeGenerationArg~string; executableRevision=revisionArg~string; createdEpochMs=.MigratableJobTime~number(createdArg); replyTo=replyToArg~string
  if handoffId="" | migrationId="" | jobId="" | checkpointId="" then raise syntax 88.900 array("invalid migration handoff instruction")
  if destinationNodeId="" | destinationPlacementId="" | checkpointRef="" | verificationRef="" | commitEvidenceRef="" then raise syntax 88.900 array("incomplete migration handoff instruction")
::method canonical
  expose handoffId mode migrationId jobId definitionRef partitionId checkpointId sourceNodeId sourcePlacementId sourceOwnershipEpoch destinationNodeId destinationPlacementId destinationOwnershipEpoch checkpointRef checkpointStateDigest verificationRef commitEvidenceRef runtimeId runtimeGeneration executableRevision createdEpochMs replyTo
  return "handoff="||handoffId||";mode="||mode||";migration="||migrationId||";job="||jobId||";definition="||definitionRef||";partition="||partitionId||";checkpoint="||checkpointId||";sourceNode="||sourceNodeId||";sourcePlacement="||sourcePlacementId||";sourceEpoch="||sourceOwnershipEpoch||";destinationNode="||destinationNodeId||";destinationPlacement="||destinationPlacementId||";destinationEpoch="||destinationOwnershipEpoch||";checkpointRef="||checkpointRef||";checkpointDigest="||checkpointStateDigest||";verification="||verificationRef||";commit="||commitEvidenceRef||";runtime="||runtimeId||";runtimeGen="||runtimeGeneration||";revision="||executableRevision||";created="||createdEpochMs||";replyTo="||replyTo
::method fromMigration class
  use strict arg migration, modeArg, handoffIdArg, nowEpochMs, replyToArg=""
  if migration==.nil | migration~destinationLease==.nil | migration~checkpointManifest==.nil then return .nil
  d=migration~definition; s=migration~sourceLease; t=migration~destinationLease; c=migration~checkpointManifest
  if migration~destinationCheckpointRef="" | migration~transferVerificationRef="" | migration~commitEvidenceRef="" then return .nil
  return self~new(handoffIdArg,modeArg,migration~migrationId,d~jobId,d~definitionRef,d~partitionId,c~checkpointId,s~nodeId,s~placementId,s~ownershipEpoch,t~nodeId,t~placementId,t~ownershipEpoch,migration~destinationCheckpointRef,c~stateDigest,migration~transferVerificationRef,migration~commitEvidenceRef,d~runtimeId,d~runtimeGeneration,d~executableRevision,nowEpochMs,replyToArg)

::class MigratableJobHandoffSubmission public
::attribute ok get
::attribute code get
::attribute handoffId get
::attribute handoffRef get
::attribute detail get
::method init
  expose ok code handoffId handoffRef detail
  use arg okArg, codeArg, handoffIdArg="", handoffRefArg="", detailArg=""
  ok=(okArg==.true); code=codeArg~string; handoffId=handoffIdArg~string; handoffRef=handoffRefArg~string; detail=detailArg~string
::method success class
  use arg handoffIdArg, handoffRefArg=""
  return self~new(.true,"HANDOFF_SUBMITTED",handoffIdArg,handoffRefArg,"")
::method failure class
  use arg codeArg, detailArg=""
  return self~new(.false,codeArg,"","",detailArg)

::class MigratableJobResumeAcknowledgement public
::attribute ok get
::attribute code get
::attribute handoffId get
::attribute migrationId get
::attribute jobId get
::attribute checkpointId get
::attribute destinationNodeId get
::attribute destinationPlacementId get
::attribute destinationOwnershipEpoch get
::attribute executionRef get
::attribute detail get
::attribute epochMs get
::method init
  expose ok code handoffId migrationId jobId checkpointId destinationNodeId destinationPlacementId destinationOwnershipEpoch executionRef detail epochMs
  use strict arg okArg, codeArg, handoffArg, migrationArg, jobArg, checkpointArg, nodeArg, placementArg, epochArg, executionArg="", detailArg="", atArg=0
  ok=(okArg==.true); code=codeArg~string; handoffId=handoffArg~string; migrationId=migrationArg~string; jobId=jobArg~string; checkpointId=checkpointArg~string
  destinationNodeId=nodeArg~string; destinationPlacementId=placementArg~string; destinationOwnershipEpoch=epochArg+0; executionRef=executionArg~string; detail=detailArg~string; epochMs=.MigratableJobTime~number(atArg)
::method success class
  use strict arg instruction, executionRefArg, nowEpochMs
  return self~new(.true,"DESTINATION_RUNNING",instruction~handoffId,instruction~migrationId,instruction~jobId,instruction~checkpointId,instruction~destinationNodeId,instruction~destinationPlacementId,instruction~destinationOwnershipEpoch,executionRefArg,"",nowEpochMs)
::method failure class
  use strict arg instruction, codeArg, detailArg="", nowEpochMs=0
  return self~new(.false,codeArg,instruction~handoffId,instruction~migrationId,instruction~jobId,instruction~checkpointId,instruction~destinationNodeId,instruction~destinationPlacementId,instruction~destinationOwnershipEpoch,"",detailArg,nowEpochMs)

::class MigratableJobHandoffTransport public
::method mode abstract
::method submit abstract

/* Destination execution remains a separate local authority.  Queue and file
 * receivers feed the same instruction into this interface. */
::class MigratableJobDestinationExecutor public
::method start abstract

/* Target restrictions are hard constraints, never score adjustments. Add this
 * assessor to JobNodeEligibilityPolicy when target restriction is required. */
::class MigratableJobDestinationPolicy public
::attribute sourceNodeId get
::attribute requireDifferentNode get
::attribute allowedNodes get
::method init
  expose sourceNodeId requireDifferentNode allowedNodes
  use arg sourceArg="", requireDifferentArg=.true, allowedArg=.nil
  sourceNodeId=sourceArg~string
  requireDifferentNode=(requireDifferentArg==.true)
  allowedNodes=.directory~new
  if allowedArg<>.nil then do n over allowedArg; allowedNodes[n~string~upper]=.true; end
::method allows
  expose sourceNodeId requireDifferentNode allowedNodes
  use strict arg nodeIdArg
  n=nodeIdArg~string
  if requireDifferentNode & n~upper=sourceNodeId~upper then return .false
  if allowedNodes~items>0 & allowedNodes~at(n~upper)==.nil then return .false
  return .true

::class MigratableJobDestinationPolicyRegistry public
::method init
  expose policies
  policies=.directory~new
::method set guarded
  expose policies
  use strict arg jobId, policy
  policies[jobId~string]=policy
  return policy
::method get guarded
  expose policies
  use strict arg jobId
  return policies[jobId~string]
::method clear guarded
  expose policies
  use strict arg jobId
  policies~remove(jobId~string)
  return .true

::class MigratableJobDestinationAssessor subclass JobNodeHardConstraintAssessor public
::method init
  expose policies
  use strict arg registryArg
  policies=registryArg
::method assess
  expose policies
  use strict arg placementRequest, capability, capacity, nowEpochMs
  reasons=.array~new
  p=policies~get(placementRequest~jobId)
  if p==.nil | capability==.nil then return reasons
  if \p~allows(capability~nodeId) then do
    if p~requireDifferentNode & capability~nodeId~upper=p~sourceNodeId~upper then reasons~append("MIGRATION_SOURCE_NODE_EXCLUDED")
    else reasons~append("MIGRATION_TARGET_NOT_ALLOWED")
  end
  return reasons

::class MigratableJobProvenanceEvent public
::attribute sequence get
::attribute migrationId get
::attribute jobId get
::attribute kind get
::attribute state get
::attribute nodeId get
::attribute placementId get
::attribute checkpointId get
::attribute epochMs get
::attribute detail get
::attribute previousDigest get
::attribute digest get
::method init
  expose sequence migrationId jobId kind state nodeId placementId checkpointId epochMs detail previousDigest digest
  use strict arg sequenceArg, migrationArg, jobArg, kindArg, stateArg, nodeArg="", placementArg="", checkpointArg="", epochArg=0, detailArg="", previousArg="", digestArg=""
  sequence=sequenceArg+0; migrationId=migrationArg~string; jobId=jobArg~string; kind=kindArg~string; state=stateArg~string
  nodeId=nodeArg~string; placementId=placementArg~string; checkpointId=checkpointArg~string; epochMs=.MigratableJobTime~number(epochArg); detail=detailArg~string
  previousDigest=previousArg~string; digest=digestArg~string
::method canonicalWithoutDigest
  expose sequence migrationId jobId kind state nodeId placementId checkpointId epochMs detail previousDigest
  return "seq="||sequence||";migration="||migrationId||";job="||jobId||";kind="||kind||";state="||state||";node="||nodeId||";placement="||placementId||";checkpoint="||checkpointId||";epoch="||epochMs||";detail="||detail||";previous="||previousDigest

::class MigratableJobProvenanceLedger public
::method init
  expose path digestProvider events lastDigest sequence
  use arg pathArg="", digestArg=.nil
  path=pathArg~string
  if digestArg==.nil then digestProvider=.JobNodeDigestProvider~new; else digestProvider=digestArg
  events=.array~new; lastDigest=""; sequence=0
  if path<>"" then do
    exists=stream(path,"c","query exists")
    if exists<>"" then if \self~loadExisting then raise syntax 88.900 array("migratable provenance ledger integrity failed",path)
  end
::method loadExisting private
  expose path digestProvider events lastDigest sequence
  s=.stream~new(path); opened=s~open("read")
  if opened<>"READY:" then return .false
  expected=1; previous=""
  do while s~lines>0
    line=s~linein
    if line="" then iterate
    f=self~split(line)
    if f~items<>13 | f[1]<>"MJ-EVENT-1" then do; s~close; return .false; end
    if datatype(f[2],"W")=0 | f[10]="" | verify(f[10],"0123456789")<>0 then do; s~close; return .false; end
    if f[2]+0<>expected then do; s~close; return .false; end
    e=.MigratableJobProvenanceEvent~new(f[2]+0,x2c(f[3]),x2c(f[4]),x2c(f[5]),x2c(f[6]),x2c(f[7]),x2c(f[8]),x2c(f[9]),.MigratableJobTime~number(f[10]),x2c(f[11]),f[12],f[13])
    if e~previousDigest<>previous then do; s~close; return .false; end
    actual=digestProvider~digest(e~canonicalWithoutDigest)
    if actual<>e~digest then do; s~close; return .false; end
    events~append(e); previous=e~digest; expected+=1
  end
  s~close
  sequence=expected-1; lastDigest=previous
  return .true
::method split private
  use strict arg text
  a=.array~new; rest=text~string
  do forever
    p=rest~pos("|")
    if p=0 then do; a~append(rest); leave; end
    a~append(rest~left(p-1)); rest=rest~substr(p+1)
  end
  return a
::method append guarded
  expose path digestProvider events lastDigest sequence
  use strict arg migrationId, jobId, kind, state, nodeId="", placementId="", checkpointId="", epochMs=0, detail=""
  sequence+=1
  e=.MigratableJobProvenanceEvent~new(sequence,migrationId,jobId,kind,state,nodeId,placementId,checkpointId,epochMs,detail,lastDigest,"")
  digest=digestProvider~digest(e~canonicalWithoutDigest)
  e=.MigratableJobProvenanceEvent~new(sequence,migrationId,jobId,kind,state,nodeId,placementId,checkpointId,epochMs,detail,lastDigest,digest)
  events~append(e); lastDigest=digest
  if path<>"" then do
    s=.stream~new(path); opened=s~open("write append")
    if opened<>"READY:" then return .false
    s~lineout(self~line(e)); s~close
  end
  return .true
::method line private
  use strict arg e
  return "MJ-EVENT-1|"||e~sequence||"|"||c2x(e~migrationId)||"|"||c2x(e~jobId)||"|"||c2x(e~kind)||"|"||c2x(e~state)||"|"||c2x(e~nodeId)||"|"||c2x(e~placementId)||"|"||c2x(e~checkpointId)||"|"||e~epochMs||"|"||c2x(e~detail)||"|"||e~previousDigest||"|"||e~digest
::method events guarded
  expose events
  return events~copy
::method lastDigest guarded
  expose lastDigest
  return lastDigest

::class MigratableJobMigration public
::attribute migrationId get
::attribute definition get
::attribute sourceLease get
::attribute destinationLease get
::attribute state get
::attribute resumeState get
::attribute checkpointManifest get
::attribute checkpointTransferRef get
::attribute transferVerificationRef get
::attribute destinationCheckpointRef get
::attribute failureCode get
::attribute failureDetail get
::attribute startedEpochMs get
::attribute updatedEpochMs get
::attribute commitEvidenceRef get
::attribute sourceFenced get
::attribute sourceAdmissionReleased get
::attribute destinationResumed get
::attribute executionRef get
::attribute handoffMode get
::attribute handoffId get
::attribute handoffRef get
::attribute sequence get
::method init
  expose migrationId definition sourceLease destinationLease state resumeState checkpointManifest checkpointTransferRef transferVerificationRef destinationCheckpointRef failureCode failureDetail startedEpochMs updatedEpochMs commitEvidenceRef sourceFenced sourceAdmissionReleased destinationResumed executionRef handoffMode handoffId handoffRef sequence
  use strict arg migrationArg, definitionArg, sourceLeaseArg, nowEpochMs=0
  migrationId=migrationArg~string; definition=definitionArg; sourceLease=sourceLeaseArg
  if migrationId="" | definition==.nil | sourceLease==.nil then raise syntax 88.900 array("invalid migration")
  if sourceLease~jobId<>definition~jobId then raise syntax 88.900 array("source lease job mismatch")
  destinationLease=.nil; state=.MigratableJobMigrationState~NEW; resumeState=""
  checkpointManifest=.nil; checkpointTransferRef=""; transferVerificationRef=""; destinationCheckpointRef=""
  failureCode=""; failureDetail=""; startedEpochMs=.MigratableJobTime~number(nowEpochMs); updatedEpochMs=.MigratableJobTime~number(nowEpochMs); commitEvidenceRef=""
  sourceFenced=.false; sourceAdmissionReleased=.false; destinationResumed=.false; executionRef=""; handoffMode=""; handoffId=""; handoffRef=""; sequence=0
::method transition guarded
  expose state updatedEpochMs sequence failureCode failureDetail resumeState
  use strict arg expectedArg, nextArg, nowEpochMs
  if state<>expectedArg~string then return .false
  state=nextArg~string; updatedEpochMs=.MigratableJobTime~number(nowEpochMs); sequence+=1; failureCode=""; failureDetail=""; resumeState=""
  return .true
::method setCheckpoint guarded
  expose checkpointManifest checkpointTransferRef updatedEpochMs sequence
  use strict arg manifestArg, transferRefArg, nowEpochMs
  checkpointManifest=manifestArg; checkpointTransferRef=transferRefArg~string; updatedEpochMs=.MigratableJobTime~number(nowEpochMs); sequence+=1
  return .true
::method setDestinationLease guarded
  expose destinationLease updatedEpochMs sequence
  use strict arg leaseArg, nowEpochMs
  destinationLease=leaseArg; updatedEpochMs=.MigratableJobTime~number(nowEpochMs); sequence+=1
  return .true
::method markSourceFenced guarded
  expose sourceFenced updatedEpochMs sequence
  use strict arg nowEpochMs
  sourceFenced=.true; updatedEpochMs=.MigratableJobTime~number(nowEpochMs); sequence+=1
  return .true
::method markSourceAdmissionReleased guarded
  expose sourceAdmissionReleased updatedEpochMs sequence
  use strict arg nowEpochMs
  sourceAdmissionReleased=.true; updatedEpochMs=.MigratableJobTime~number(nowEpochMs); sequence+=1
  return .true
::method resetDestination guarded
  expose destinationLease transferVerificationRef destinationCheckpointRef commitEvidenceRef updatedEpochMs sequence
  use strict arg nowEpochMs
  destinationLease=.nil; transferVerificationRef=""; destinationCheckpointRef=""; commitEvidenceRef=""
  updatedEpochMs=.MigratableJobTime~number(nowEpochMs); sequence+=1
  return .true
::method setTransferEvidence guarded
  expose transferVerificationRef destinationCheckpointRef updatedEpochMs sequence
  use strict arg verificationArg, destinationRefArg, nowEpochMs
  transferVerificationRef=verificationArg~string; destinationCheckpointRef=destinationRefArg~string; updatedEpochMs=.MigratableJobTime~number(nowEpochMs); sequence+=1
  return .true
::method setCommitEvidence guarded
  expose commitEvidenceRef updatedEpochMs sequence
  use strict arg evidenceArg, nowEpochMs
  commitEvidenceRef=evidenceArg~string; updatedEpochMs=.MigratableJobTime~number(nowEpochMs); sequence+=1
  return .true
::method prepareHandoff guarded
  expose handoffMode handoffId updatedEpochMs sequence
  use strict arg modeArg, handoffIdArg, nowEpochMs
  handoffMode=modeArg~string~upper; handoffId=handoffIdArg~string; updatedEpochMs=.MigratableJobTime~number(nowEpochMs); sequence+=1
  return .true
::method setHandoff guarded
  expose handoffMode handoffId handoffRef state updatedEpochMs sequence failureCode failureDetail resumeState
  use strict arg modeArg, handoffIdArg, handoffRefArg, nowEpochMs
  handoffMode=modeArg~string~upper; handoffId=handoffIdArg~string; handoffRef=handoffRefArg~string
  state=.MigratableJobMigrationState~AWAITING_DESTINATION; updatedEpochMs=.MigratableJobTime~number(nowEpochMs); sequence+=1; failureCode=""; failureDetail=""; resumeState=""
  return .true
::method markRunning guarded
  expose state destinationResumed executionRef updatedEpochMs sequence failureCode failureDetail resumeState
  use strict arg executionArg, nowEpochMs
  state=.MigratableJobMigrationState~RUNNING; destinationResumed=.true; executionRef=executionArg~string; updatedEpochMs=.MigratableJobTime~number(nowEpochMs); sequence+=1; failureCode=""; failureDetail=""; resumeState=""
  return .true
::method pause guarded
  expose state resumeState failureCode failureDetail updatedEpochMs sequence
  use strict arg resumeArg, codeArg, detailArg, nowEpochMs
  resumeState=resumeArg~string; failureCode=codeArg~string; failureDetail=detailArg~string; state=.MigratableJobMigrationState~PAUSED; updatedEpochMs=.MigratableJobTime~number(nowEpochMs); sequence+=1
  return .true
::method resume guarded
  expose state resumeState failureCode failureDetail updatedEpochMs sequence
  use strict arg nowEpochMs
  if state<>.MigratableJobMigrationState~PAUSED | resumeState="" then return .false
  state=resumeState; resumeState=""; failureCode=""; failureDetail=""; updatedEpochMs=.MigratableJobTime~number(nowEpochMs); sequence+=1
  return .true
::method fail guarded
  expose state resumeState failureCode failureDetail updatedEpochMs sequence
  use strict arg codeArg, detailArg, nowEpochMs
  state=.MigratableJobMigrationState~FAILED; resumeState=""; failureCode=codeArg~string; failureDetail=detailArg~string; updatedEpochMs=.MigratableJobTime~number(nowEpochMs); sequence+=1
  return .true
::method restoreDurable guarded
  expose destinationLease state resumeState checkpointManifest checkpointTransferRef transferVerificationRef destinationCheckpointRef failureCode failureDetail startedEpochMs updatedEpochMs commitEvidenceRef sourceFenced sourceAdmissionReleased destinationResumed executionRef handoffMode handoffId handoffRef sequence
  use strict arg destinationLeaseArg, stateArg, resumeStateArg, checkpointArg, checkpointTransferArg, transferVerificationArg, destinationCheckpointArg, failureCodeArg, failureDetailArg, startedArg, updatedArg, commitEvidenceArg, sourceFencedArg, sourceReleasedArg, destinationResumedArg, executionRefArg, sequenceArg, handoffModeArg="", handoffIdArg="", handoffRefArg=""
  state=stateArg~string; resumeState=resumeStateArg~string; destinationLease=destinationLeaseArg; checkpointManifest=checkpointArg
  checkpointTransferRef=checkpointTransferArg~string; transferVerificationRef=transferVerificationArg~string; destinationCheckpointRef=destinationCheckpointArg~string
  failureCode=failureCodeArg~string; failureDetail=failureDetailArg~string; startedEpochMs=.MigratableJobTime~number(startedArg); updatedEpochMs=.MigratableJobTime~number(updatedArg); commitEvidenceRef=commitEvidenceArg~string
  sourceFenced=(sourceFencedArg==.true); sourceAdmissionReleased=(sourceReleasedArg==.true); destinationResumed=(destinationResumedArg==.true); executionRef=executionRefArg~string; sequence=sequenceArg+0
  handoffMode=handoffModeArg~string; handoffId=handoffIdArg~string; handoffRef=handoffRefArg~string
  return self

::class MigratableJobReconcileResult public
::attribute ok get
::attribute code get
::attribute changed get
::attribute detail get
::method init
  expose ok code changed detail
  use arg okArg, codeArg, changedArg=.false, detailArg=""
  ok=(okArg==.true); code=codeArg~string; changed=(changedArg==.true); detail=detailArg~string
::method success class
  use arg changedArg=.false, codeArg="RECONCILED"
  return self~new(.true,codeArg,changedArg,"")
::method failure class
  use arg codeArg, detailArg=""
  return self~new(.false,codeArg,.false,detailArg)

/* Planned handoff: unlike node-loss recovery, it is legal while the source
 * node remains live, but only after the runtime has returned a durable paused
 * checkpoint. The old ownership epoch is fenced before any replacement lease
 * can be created. */
::class MigratableJobPlacementHandoff public
::method init
  expose allocator ownership
  use strict arg allocatorArg, ownershipArg
  allocator=allocatorArg; ownership=ownershipArg
::method reconcile
  expose allocator ownership
  use strict arg migration, nowEpochMs
  if migration==.nil then return .MigratableJobReconcileResult~failure("MIGRATION_REQUIRED")
  source=migration~sourceLease; changed=.false
  cur=ownership~current(source~jobId,nowEpochMs)
  epoch=ownership~epochFor(source~jobId)

  if \migration~sourceFenced then do
    if cur<>.nil then do
      if cur~placementId=source~placementId & cur~ownershipEpoch=source~ownershipEpoch then nop
      else if cur~ownershipEpoch>source~ownershipEpoch then do
        migration~markSourceFenced(nowEpochMs); changed=.true
        if migration~destinationLease==.nil then do
          if allocator~verifyLease(cur,migration~definition~placementRequest,nowEpochMs) then do
            p=.MigratableJobDestinationPolicy~new(source~nodeId,migration~definition~requireDifferentNode,migration~definition~allowedDestinationNodeIds)
            if p~allows(cur~nodeId) then do; migration~setDestinationLease(cur,nowEpochMs); changed=.true; end
          end
        end
      end
      else return .MigratableJobReconcileResult~failure("SOURCE_OWNERSHIP_CONFLICT","current ownership does not dominate source epoch")
    end
    else if epoch>source~ownershipEpoch then do; migration~markSourceFenced(nowEpochMs); changed=.true; end
  end
  else do
    if cur<>.nil then if cur~placementId=source~placementId & cur~ownershipEpoch=source~ownershipEpoch then return .MigratableJobReconcileResult~failure("SOURCE_AUTHORITY_REGRESSION","journal says source fenced but allocator still reports source current")
    if epoch<=source~ownershipEpoch then return .MigratableJobReconcileResult~failure("SOURCE_FENCE_EPOCH_MISSING","allocator epoch does not prove the persisted fence")
  end

  if \migration~sourceAdmissionReleased then do
    released=.false
    if source~reservationRef="" then released=.true
    else if \allocator~hasAdmission(source) then released=.true
    if released then do; migration~markSourceAdmissionReleased(nowEpochMs); changed=.true; end
  end
  return .MigratableJobReconcileResult~success(changed)
::method fenceOwnership
  expose ownership
  use strict arg migration, nowEpochMs
  lease=migration~sourceLease
  if migration~checkpointManifest==.nil then return .JobNodePlacementDecision~new(.false,"CHECKPOINT_REQUIRED_BEFORE_FENCE",lease)
  if migration~sourceFenced then return .JobNodePlacementDecision~new(.true,"SOURCE_ALREADY_FENCED",lease)
  if \ownership~isCurrent(lease,nowEpochMs) then return .JobNodePlacementDecision~new(.false,"SOURCE_NOT_CURRENT_OWNER",lease)
  if \ownership~fence(lease) then return .JobNodePlacementDecision~new(.false,"SOURCE_FENCE_FAILED",lease)
  migration~markSourceFenced(nowEpochMs)
  return .JobNodePlacementDecision~new(.true,"SOURCE_FENCED",lease)
::method releaseSourceAdmission
  expose allocator
  use strict arg migration, nowEpochMs
  lease=migration~sourceLease
  if \migration~sourceFenced then return .JobNodePlacementDecision~new(.false,"SOURCE_FENCE_REQUIRED",lease)
  if migration~sourceAdmissionReleased then return .JobNodePlacementDecision~new(.true,"SOURCE_ADMISSION_ALREADY_RELEASED",lease)
  if \allocator~releasePlacement(lease) then return .JobNodePlacementDecision~new(.false,"SOURCE_ADMISSION_RELEASE_FAILED",lease)
  migration~markSourceAdmissionReleased(nowEpochMs)
  return .JobNodePlacementDecision~new(.true,"SOURCE_ADMISSION_RELEASED",lease)
::method fenceSource
  use strict arg migration, nowEpochMs
  r=self~fenceOwnership(migration,nowEpochMs)
  if \r~placed then return r
  return self~releaseSourceAdmission(migration,nowEpochMs)
::method allocateDestination
  expose allocator
  use strict arg migration, nowEpochMs, leaseDurationMs=30000
  d=allocator~allocate(migration~definition~placementRequest,nowEpochMs,leaseDurationMs)
  if \d~placed then return d
  lease=d~lease
  def=migration~definition
  if def~requireDifferentNode & lease~nodeId~upper=migration~sourceLease~nodeId~upper then do
    allocator~releasePlacement(lease)
    return .JobNodePlacementDecision~new(.false,"DESTINATION_EQUALS_SOURCE",lease,d~assessments,d~selectedScore)
  end
  if def~allowedDestinationNodeIds~items>0 then do
    found=.false
    do n over def~allowedDestinationNodeIds
      if n~string~upper=lease~nodeId~upper then do; found=.true; leave; end
    end
    if \found then do
      allocator~releasePlacement(lease)
      return .JobNodePlacementDecision~new(.false,"DESTINATION_NOT_ALLOWED",lease,d~assessments,d~selectedScore)
    end
  end
  migration~setDestinationLease(lease,nowEpochMs)
  return d
::method verifyDestination
  expose allocator
  use strict arg migration, nowEpochMs
  if migration~destinationLease==.nil then return .false
  return allocator~verifyLease(migration~destinationLease,migration~definition~placementRequest,nowEpochMs)
::method releaseDestination
  expose allocator
  use strict arg migration
  if migration~destinationLease==.nil then return .true
  return allocator~releasePlacement(migration~destinationLease)

::class MigratableJobCoordinator public
::method init
  expose execution transfer commitAuthority handoff provenance destinationPolicies durableJournal resumeTransport statusPublisher
  use strict arg executionArg, transferArg, commitAuthorityArg, handoffArg, provenanceArg=.nil, destinationPoliciesArg=.nil, durableArg=.nil, resumeTransportArg=.nil, statusPublisherArg=.nil
  execution=executionArg; transfer=transferArg; commitAuthority=commitAuthorityArg; handoff=handoffArg
  if execution==.nil | transfer==.nil | commitAuthority==.nil | handoff==.nil then raise syntax 88.900 array("execution, transfer, commit authority and placement handoff are required")
  if provenanceArg==.nil then provenance=.MigratableJobProvenanceLedger~new; else provenance=provenanceArg
  destinationPolicies=destinationPoliciesArg; durableJournal=durableArg; resumeTransport=resumeTransportArg; statusPublisher=statusPublisherArg
::method begin guarded
  expose provenance destinationPolicies
  use strict arg migrationId, definition, sourceLease, nowEpochMs
  if destinationPolicies<>.nil then destinationPolicies~set(definition~jobId,.MigratableJobDestinationPolicy~new(sourceLease~nodeId,definition~requireDifferentNode,definition~allowedDestinationNodeIds))
  m=.MigratableJobMigration~new(migrationId,definition,sourceLease,nowEpochMs)
  provenance~append(migrationId,definition~jobId,"MIGRATION_CREATED",m~state,sourceLease~nodeId,sourceLease~placementId,"",nowEpochMs,definition~definitionRef)
  if \self~persist(m) then m~fail("DURABLE_JOURNAL_WRITE_FAILED","could not persist migration creation",nowEpochMs)
  return m
::method restore guarded
  expose durableJournal handoff provenance destinationPolicies
  use strict arg definition, nowEpochMs
  if durableJournal==.nil then return .nil
  snap=durableJournal~loadLatest(definition)
  if \snap~valid then return snap
  m=snap~migration
  if destinationPolicies<>.nil then destinationPolicies~set(definition~jobId,.MigratableJobDestinationPolicy~new(m~sourceLease~nodeId,definition~requireDifferentNode,definition~allowedDestinationNodeIds))
  if m~checkpointManifest<>.nil & handoff~hasMethod("RECONCILE") then do
    r=handoff~reconcile(m,nowEpochMs)
    if \r~ok then do
      m~fail(r~code,r~detail,nowEpochMs); ignore=self~persist(m)
      provenance~append(m~migrationId,definition~jobId,"RECONCILIATION_FAILED",m~state,m~sourceLease~nodeId,m~sourceLease~placementId,m~checkpointManifest~checkpointId,nowEpochMs,r~code)
    end
    else if r~changed then do
      provenance~append(m~migrationId,definition~jobId,"AUTHORITY_RECONCILED",m~state,m~sourceLease~nodeId,m~sourceLease~placementId,m~checkpointManifest~checkpointId,nowEpochMs,"allocator authority repaired a crash-window snapshot")
      ignore=self~persist(m)
    end
  end
  return snap
::method step guarded
  expose execution transfer commitAuthority handoff provenance destinationPolicies resumeTransport
  use strict arg migration, nowEpochMs, leaseDurationMs=30000, maxTransferChunks=0
  if migration==.nil then return .false
  if migration~state=.MigratableJobMigrationState~PAUSED then return .false
  if migration~state=.MigratableJobMigrationState~FAILED | migration~state=.MigratableJobMigrationState~RUNNING | migration~state=.MigratableJobMigrationState~AWAITING_DESTINATION then return .false

  /* Reconcile against Job-to-Node before taking another authority action.  This
   * repairs the window where the allocator committed a fence or placement but
   * the process died before the migration journal append. */
  if migration~checkpointManifest<>.nil & handoff~hasMethod("RECONCILE") then do
    rc=handoff~reconcile(migration,nowEpochMs)
    if \rc~ok then do
      migration~fail(rc~code,rc~detail,nowEpochMs); ignore=self~persist(migration)
      provenance~append(migration~migrationId,migration~definition~jobId,"RECONCILIATION_FAILED",migration~state,migration~sourceLease~nodeId,migration~sourceLease~placementId,migration~checkpointManifest~checkpointId,nowEpochMs,rc~code)
      return .false
    end
    if rc~changed then do
      provenance~append(migration~migrationId,migration~definition~jobId,"AUTHORITY_RECONCILED",migration~state,migration~sourceLease~nodeId,migration~sourceLease~placementId,migration~checkpointManifest~checkpointId,nowEpochMs,"allocator authority reconciled")
      if \self~persist(migration) then return .false
    end
  end

  if migration~state=.MigratableJobMigrationState~NEW then do
    migration~transition(.MigratableJobMigrationState~NEW,.MigratableJobMigrationState~PREPARING,nowEpochMs)
    provenance~append(migration~migrationId,migration~definition~jobId,"SOURCE_PAUSE_REQUESTED",migration~state,migration~sourceLease~nodeId,migration~sourceLease~placementId,"",nowEpochMs,"")
    if \self~persist(migration) then return .false
  end

  if migration~state=.MigratableJobMigrationState~PREPARING then do
    if migration~checkpointManifest==.nil then do
      cr=execution~pauseAndCheckpoint(migration~definition,migration~sourceLease,migration~migrationId,nowEpochMs)
      checkpointFailed=.false
      if cr==.nil then checkpointFailed=.true
      else if \cr~ok then checkpointFailed=.true
      if checkpointFailed then do
        code="CHECKPOINT_FAILED"; detail=""
        if cr<>.nil then do; if cr~code<>"" then code=cr~code; detail=cr~detail; end
        migration~pause(.MigratableJobMigrationState~PREPARING,code,detail,nowEpochMs)
        provenance~append(migration~migrationId,migration~definition~jobId,"MIGRATION_PAUSED",migration~state,migration~sourceLease~nodeId,migration~sourceLease~placementId,"",nowEpochMs,code)
        ignore=self~persist(migration)
        return .false
      end
      if \self~validCheckpoint(migration,cr~manifest) then do
        migration~fail("CHECKPOINT_BINDING_INVALID","checkpoint does not bind to source lease/job/migration",nowEpochMs)
        provenance~append(migration~migrationId,migration~definition~jobId,"MIGRATION_FAILED",migration~state,migration~sourceLease~nodeId,migration~sourceLease~placementId,"",nowEpochMs,migration~failureCode)
        ignore=self~persist(migration)
        return .false
      end
      migration~setCheckpoint(cr~manifest,cr~transferRef,nowEpochMs)
      provenance~append(migration~migrationId,migration~definition~jobId,"CHECKPOINT_CREATED",migration~state,migration~sourceLease~nodeId,migration~sourceLease~placementId,cr~manifest~checkpointId,nowEpochMs,cr~manifest~stateDigest)
      if \self~persist(migration) then return .false
    end

    if \migration~sourceFenced then do
      if handoff~hasMethod("FENCEOWNERSHIP") then fd=handoff~fenceOwnership(migration,nowEpochMs)
      else fd=handoff~fenceSource(migration,nowEpochMs)
      if \fd~placed then do
        migration~pause(.MigratableJobMigrationState~PREPARING,fd~code,"planned source ownership fence did not complete",nowEpochMs)
        provenance~append(migration~migrationId,migration~definition~jobId,"MIGRATION_PAUSED",migration~state,migration~sourceLease~nodeId,migration~sourceLease~placementId,migration~checkpointManifest~checkpointId,nowEpochMs,fd~code)
        ignore=self~persist(migration)
        return .false
      end
      provenance~append(migration~migrationId,migration~definition~jobId,"SOURCE_FENCED",migration~state,migration~sourceLease~nodeId,migration~sourceLease~placementId,migration~checkpointManifest~checkpointId,nowEpochMs,"ownership epoch fenced")
      if \self~persist(migration) then return .false
    end

    if \migration~sourceAdmissionReleased then do
      if handoff~hasMethod("RELEASESOURCEADMISSION") then rd=handoff~releaseSourceAdmission(migration,nowEpochMs)
      else rd=handoff~fenceSource(migration,nowEpochMs)
      if \rd~placed then do
        migration~pause(.MigratableJobMigrationState~PREPARING,rd~code,"source admission release did not complete",nowEpochMs)
        provenance~append(migration~migrationId,migration~definition~jobId,"MIGRATION_PAUSED",migration~state,migration~sourceLease~nodeId,migration~sourceLease~placementId,migration~checkpointManifest~checkpointId,nowEpochMs,rd~code)
        ignore=self~persist(migration)
        return .false
      end
      provenance~append(migration~migrationId,migration~definition~jobId,"SOURCE_ADMISSION_RELEASED",migration~state,migration~sourceLease~nodeId,migration~sourceLease~placementId,migration~checkpointManifest~checkpointId,nowEpochMs,"")
      if \self~persist(migration) then return .false
    end

    if migration~destinationLease==.nil then do
      pd=handoff~allocateDestination(migration,nowEpochMs,leaseDurationMs)
      if \pd~placed then do
        migration~pause(.MigratableJobMigrationState~PREPARING,pd~code,"destination placement unavailable",nowEpochMs)
        provenance~append(migration~migrationId,migration~definition~jobId,"MIGRATION_PAUSED",migration~state,"","",migration~checkpointManifest~checkpointId,nowEpochMs,pd~code)
        ignore=self~persist(migration)
        return .false
      end
      provenance~append(migration~migrationId,migration~definition~jobId,"DESTINATION_PLACED",migration~state,migration~destinationLease~nodeId,migration~destinationLease~placementId,migration~checkpointManifest~checkpointId,nowEpochMs,"")
      if \self~persist(migration) then return .false
    end
    migration~transition(.MigratableJobMigrationState~PREPARING,.MigratableJobMigrationState~READY,nowEpochMs)
    if \self~persist(migration) then return .false
  end

  if migration~state=.MigratableJobMigrationState~READY then do
    if \handoff~verifyDestination(migration,nowEpochMs) then do
      oldNode=migration~destinationLease~nodeId; oldPlacement=migration~destinationLease~placementId
      handoff~releaseDestination(migration); migration~resetDestination(nowEpochMs)
      migration~pause(.MigratableJobMigrationState~PREPARING,"DESTINATION_LEASE_INVALID","destination placement no longer verifies; destination state reset for re-placement",nowEpochMs)
      provenance~append(migration~migrationId,migration~definition~jobId,"DESTINATION_RESET",migration~state,oldNode,oldPlacement,migration~checkpointManifest~checkpointId,nowEpochMs,migration~failureCode)
      ignore=self~persist(migration)
      return .false
    end
    migration~transition(.MigratableJobMigrationState~READY,.MigratableJobMigrationState~TRANSFERRING,nowEpochMs)
    if \self~persist(migration) then return .false
  end

  if migration~state=.MigratableJobMigrationState~TRANSFERRING then do
    if \handoff~verifyDestination(migration,nowEpochMs) then do
      oldNode=migration~destinationLease~nodeId; oldPlacement=migration~destinationLease~placementId
      handoff~releaseDestination(migration); migration~resetDestination(nowEpochMs)
      migration~pause(.MigratableJobMigrationState~PREPARING,"DESTINATION_LEASE_INVALID","destination placement no longer verifies during transfer; destination state reset for re-placement",nowEpochMs)
      provenance~append(migration~migrationId,migration~definition~jobId,"DESTINATION_RESET",migration~state,oldNode,oldPlacement,migration~checkpointManifest~checkpointId,nowEpochMs,migration~failureCode)
      ignore=self~persist(migration)
      return .false
    end
    tr=transfer~transfer(migration,maxTransferChunks)
    if tr==.nil then do
      migration~fail("TRANSFER_RESULT_MISSING","transfer adapter returned nil",nowEpochMs); ignore=self~persist(migration); return .false
    end
    if tr~status=.MigratableJobTransferStatus~PAUSED then do
      migration~pause(.MigratableJobMigrationState~TRANSFERRING,"TRANSFER_PAUSED",tr~detail,nowEpochMs)
      provenance~append(migration~migrationId,migration~definition~jobId,"TRANSFER_PAUSED",migration~state,migration~destinationLease~nodeId,migration~destinationLease~placementId,migration~checkpointManifest~checkpointId,nowEpochMs,tr~bytesTransferred)
      ignore=self~persist(migration)
      return .false
    end
    if \tr~completed then do
      migration~fail("TRANSFER_FAILED",tr~detail,nowEpochMs); handoff~releaseDestination(migration)
      provenance~append(migration~migrationId,migration~definition~jobId,"MIGRATION_FAILED",migration~state,migration~destinationLease~nodeId,migration~destinationLease~placementId,migration~checkpointManifest~checkpointId,nowEpochMs,tr~detail)
      ignore=self~persist(migration)
      return .false
    end
    if tr~verificationRef="" | tr~destinationCheckpointRef="" then do
      migration~fail("TRANSFER_EVIDENCE_INCOMPLETE","verified transfer and destination checkpoint reference required",nowEpochMs); handoff~releaseDestination(migration); ignore=self~persist(migration); return .false
    end
    migration~setTransferEvidence(tr~verificationRef,tr~destinationCheckpointRef,nowEpochMs)
    provenance~append(migration~migrationId,migration~definition~jobId,"TRANSFER_VERIFIED",migration~state,migration~destinationLease~nodeId,migration~destinationLease~placementId,migration~checkpointManifest~checkpointId,nowEpochMs,tr~verificationRef)
    if \self~persist(migration) then return .false
    migration~transition(.MigratableJobMigrationState~TRANSFERRING,.MigratableJobMigrationState~COMMITTING,nowEpochMs)
    if \self~persist(migration) then return .false
  end

  if migration~state=.MigratableJobMigrationState~COMMITTING then do
    if \handoff~verifyDestination(migration,nowEpochMs) then do
      oldNode=migration~destinationLease~nodeId; oldPlacement=migration~destinationLease~placementId
      handoff~releaseDestination(migration); migration~resetDestination(nowEpochMs)
      migration~pause(.MigratableJobMigrationState~PREPARING,"DESTINATION_LEASE_INVALID","destination lease invalid before commit; verified transfer is discarded and will be repeated",nowEpochMs)
      provenance~append(migration~migrationId,migration~definition~jobId,"DESTINATION_RESET",migration~state,oldNode,oldPlacement,migration~checkpointManifest~checkpointId,nowEpochMs,migration~failureCode)
      ignore=self~persist(migration)
      return .false
    end

    if migration~commitEvidenceRef="" then do
      decision=commitAuthority~authorise(migration,nowEpochMs)
      commitDenied=.false
      if decision==.nil then commitDenied=.true
      else if \decision~allowed then commitDenied=.true
      if commitDenied then do
        code="COMMIT_DENIED"; detail=""
        if decision<>.nil then do; if decision~code<>"" then code=decision~code; detail=decision~detail; end
        migration~pause(.MigratableJobMigrationState~COMMITTING,code,detail,nowEpochMs)
        provenance~append(migration~migrationId,migration~definition~jobId,"COMMIT_DENIED",migration~state,migration~destinationLease~nodeId,migration~destinationLease~placementId,migration~checkpointManifest~checkpointId,nowEpochMs,code)
        ignore=self~persist(migration)
        return .false
      end
      migration~setCommitEvidence(decision~evidenceRef,nowEpochMs)
      provenance~append(migration~migrationId,migration~definition~jobId,"COMMIT_AUTHORISED",migration~state,migration~destinationLease~nodeId,migration~destinationLease~placementId,migration~checkpointManifest~checkpointId,nowEpochMs,decision~evidenceRef)
      if \self~persist(migration) then return .false
    end

    if resumeTransport<>.nil then do
      if migration~handoffId="" then do
        hid="MJH-"||migration~migrationId||"-"||migration~destinationLease~placementId||"-"||migration~checkpointManifest~checkpointId
        migration~prepareHandoff(resumeTransport~mode,hid,nowEpochMs)
        if \self~persist(migration) then return .false
      end
      sub=resumeTransport~submit(migration,nowEpochMs)
      if sub==.nil | \sub~ok then do
        code="HANDOFF_SUBMIT_FAILED"; detail=""
        if sub<>.nil then do; if sub~code<>"" then code=sub~code; detail=sub~detail; end
        migration~pause(.MigratableJobMigrationState~COMMITTING,code,detail,nowEpochMs)
        provenance~append(migration~migrationId,migration~definition~jobId,"HANDOFF_SUBMIT_FAILED",migration~state,migration~destinationLease~nodeId,migration~destinationLease~placementId,migration~checkpointManifest~checkpointId,nowEpochMs,code)
        ignore=self~persist(migration)
        return .false
      end
      migration~setHandoff(resumeTransport~mode,migration~handoffId,sub~handoffRef,nowEpochMs)
      provenance~append(migration~migrationId,migration~definition~jobId,"HANDOFF_SUBMITTED",migration~state,migration~destinationLease~nodeId,migration~destinationLease~placementId,migration~checkpointManifest~checkpointId,nowEpochMs,resumeTransport~mode||":"||sub~handoffRef)
      ignore=self~persist(migration)
      return .false
    end

    rr=execution~resumeFromCheckpoint(migration~definition,migration~destinationLease,migration~checkpointManifest,migration~destinationCheckpointRef,nowEpochMs)
    resumeFailed=.false
    if rr==.nil then resumeFailed=.true
    else if \rr~ok then resumeFailed=.true
    if resumeFailed then do
      code="DESTINATION_RESUME_FAILED"; detail=""
      if rr<>.nil then do; if rr~code<>"" then code=rr~code; detail=rr~detail; end
      migration~pause(.MigratableJobMigrationState~COMMITTING,code,detail,nowEpochMs)
      provenance~append(migration~migrationId,migration~definition~jobId,"MIGRATION_PAUSED",migration~state,migration~destinationLease~nodeId,migration~destinationLease~placementId,migration~checkpointManifest~checkpointId,nowEpochMs,code)
      ignore=self~persist(migration)
      return .false
    end
    return self~finishRunning(migration,rr~executionRef,nowEpochMs)
  end
  return migration~state=.MigratableJobMigrationState~RUNNING
::method acknowledge guarded
  expose provenance handoff
  use strict arg migration, acknowledgement, nowEpochMs
  if migration==.nil | acknowledgement==.nil then return .false
  if migration~state<>.MigratableJobMigrationState~AWAITING_DESTINATION then return .false
  if \acknowledgement~ok then do
    provenance~append(migration~migrationId,migration~definition~jobId,"DESTINATION_RESUME_REJECTED",migration~state,migration~destinationLease~nodeId,migration~destinationLease~placementId,migration~checkpointManifest~checkpointId,nowEpochMs,acknowledgement~code||":"||acknowledgement~detail)
    return .false
  end
  if acknowledgement~handoffId<>migration~handoffId | acknowledgement~migrationId<>migration~migrationId | acknowledgement~jobId<>migration~definition~jobId then return .false
  if acknowledgement~checkpointId<>migration~checkpointManifest~checkpointId then return .false
  if acknowledgement~destinationNodeId<>migration~destinationLease~nodeId | acknowledgement~destinationPlacementId<>migration~destinationLease~placementId | acknowledgement~destinationOwnershipEpoch<>migration~destinationLease~ownershipEpoch then return .false
  if \handoff~verifyDestination(migration,nowEpochMs) then return .false
  return self~finishRunning(migration,acknowledgement~executionRef,nowEpochMs)
::method resumePaused guarded
  expose destinationPolicies
  use strict arg migration, nowEpochMs, leaseDurationMs=30000, maxTransferChunks=0
  if destinationPolicies<>.nil then destinationPolicies~set(migration~definition~jobId,.MigratableJobDestinationPolicy~new(migration~sourceLease~nodeId,migration~definition~requireDifferentNode,migration~definition~allowedDestinationNodeIds))
  if \migration~resume(nowEpochMs) then return .false
  if \self~persist(migration) then return .false
  return self~step(migration,nowEpochMs,leaseDurationMs,maxTransferChunks)
::method finishRunning private
  expose execution provenance destinationPolicies
  use strict arg migration, executionRefArg, nowEpochMs
  migration~markRunning(executionRefArg,nowEpochMs)
  if destinationPolicies<>.nil then destinationPolicies~clear(migration~definition~jobId)
  provenance~append(migration~migrationId,migration~definition~jobId,"MIGRATION_RUNNING",migration~state,migration~destinationLease~nodeId,migration~destinationLease~placementId,migration~checkpointManifest~checkpointId,nowEpochMs,executionRefArg)
  persisted=self~persist(migration)
  if \execution~retireSource(migration~definition,migration~sourceLease,migration~migrationId,nowEpochMs) then provenance~append(migration~migrationId,migration~definition~jobId,"SOURCE_RETIRE_DEFERRED",migration~state,migration~sourceLease~nodeId,migration~sourceLease~placementId,migration~checkpointManifest~checkpointId,nowEpochMs,"source cleanup deferred; execution remains fenced")
  return persisted & migration~state=.MigratableJobMigrationState~RUNNING
::method persist private
  expose durableJournal provenance statusPublisher
  use strict arg migration
  if durableJournal<>.nil then do
    ok=durableJournal~append(migration)
    if \ok then do
      provenance~append(migration~migrationId,migration~definition~jobId,"DURABLE_JOURNAL_WRITE_FAILED",migration~state,"","","",migration~updatedEpochMs,"migration state is only in memory; retry/restart must reconcile allocator authority")
      return .false
    end
  end
  /* Status publication follows authority persistence.  It is deliberately
   * fail-open for migration control: subscribers observe authority; they do
   * not become authority merely by being unavailable or backpressured. */
  if statusPublisher<>.nil then do
    sr=statusPublisher~publish(migration)
    statusFailed=.false
    if sr==.nil then statusFailed=.true
    else if \sr~ok then statusFailed=.true
    if statusFailed then do
      code="STATUS_PUBLICATION_FAILED"; detail="status publisher returned no result"
      if sr<>.nil then do; if sr~code<>"" then code=sr~code; detail=sr~detail; end
      provenance~append(migration~migrationId,migration~definition~jobId,"STATUS_PUBLICATION_FAILED",migration~state,"","","",migration~updatedEpochMs,code||":"||detail)
    end
  end
  return .true
::method validCheckpoint private
  use strict arg migration, manifest
  if manifest==.nil then return .false
  source=migration~sourceLease; def=migration~definition
  if manifest~jobId<>def~jobId then return .false
  if manifest~migrationId<>migration~migrationId then return .false
  if manifest~partitionId<>def~partitionId then return .false
  if manifest~sourceNodeId<>source~nodeId then return .false
  if manifest~sourcePlacementId<>source~placementId then return .false
  if manifest~sourceOwnershipEpoch<>source~ownershipEpoch then return .false
  if def~runtimeId<>"" & manifest~runtimeId<>def~runtimeId then return .false
  if def~runtimeGeneration<>"" & manifest~runtimeGeneration<>def~runtimeGeneration then return .false
  if def~executableRevision<>"" & manifest~executableRevision<>def~executableRevision then return .false
  return .true

::requires "JobNodeAllocator.cls"

::requires "JobNodeLiveness.cls"
