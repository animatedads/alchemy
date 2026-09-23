/* Common queued/file handoff records for Migratable Job v0.2. */

::class MigratableJobHandoffCodec public
::method instructionToDirectory class
  use strict arg i
  d=.directory~new
  d["schema"]="migratable.job.handoff/2"
  d["handoffId"]=i~handoffId; d["mode"]=i~mode; d["migrationId"]=i~migrationId; d["jobId"]=i~jobId
  d["definitionRef"]=i~definitionRef; d["partitionId"]=i~partitionId; d["checkpointId"]=i~checkpointId
  d["sourceNodeId"]=i~sourceNodeId; d["sourcePlacementId"]=i~sourcePlacementId; d["sourceOwnershipEpoch"]=i~sourceOwnershipEpoch
  d["destinationNodeId"]=i~destinationNodeId; d["destinationPlacementId"]=i~destinationPlacementId; d["destinationOwnershipEpoch"]=i~destinationOwnershipEpoch
  d["checkpointRef"]=i~checkpointRef; d["checkpointStateDigest"]=i~checkpointStateDigest; d["verificationRef"]=i~verificationRef; d["commitEvidenceRef"]=i~commitEvidenceRef
  d["runtimeId"]=i~runtimeId; d["runtimeGeneration"]=i~runtimeGeneration; d["executableRevision"]=i~executableRevision; d["createdEpochMs"]=i~createdEpochMs; d["replyTo"]=i~replyTo
  return d
::method instructionFromDirectory class
  use strict arg d
  if d==.nil then return .nil
  if d["schema"]==.nil | d["schema"]<>"migratable.job.handoff/2" then return .nil
  required=.array~of("handoffId","mode","migrationId","jobId","checkpointId","destinationNodeId","destinationPlacementId","checkpointRef","verificationRef","commitEvidenceRef")
  do k over required; if d[k]==.nil | d[k]="" then return .nil; end
  return .MigratableJobHandoffInstruction~new(d["handoffId"],d["mode"],d["migrationId"],d["jobId"],self~v(d,"definitionRef"),self~v(d,"partitionId"),d["checkpointId"],self~v(d,"sourceNodeId"),self~v(d,"sourcePlacementId"),self~n(d,"sourceOwnershipEpoch"),d["destinationNodeId"],d["destinationPlacementId"],self~n(d,"destinationOwnershipEpoch"),d["checkpointRef"],self~v(d,"checkpointStateDigest"),d["verificationRef"],d["commitEvidenceRef"],self~v(d,"runtimeId"),self~v(d,"runtimeGeneration"),self~v(d,"executableRevision"),self~n(d,"createdEpochMs"),self~v(d,"replyTo"))
::method acknowledgementToDirectory class
  use strict arg a
  d=.directory~new; d["schema"]="migratable.job.ack/2"
  d["ok"]=a~ok; d["code"]=a~code; d["handoffId"]=a~handoffId; d["migrationId"]=a~migrationId; d["jobId"]=a~jobId; d["checkpointId"]=a~checkpointId
  d["destinationNodeId"]=a~destinationNodeId; d["destinationPlacementId"]=a~destinationPlacementId; d["destinationOwnershipEpoch"]=a~destinationOwnershipEpoch
  d["executionRef"]=a~executionRef; d["detail"]=a~detail; d["epochMs"]=a~epochMs
  return d
::method acknowledgementFromDirectory class
  use strict arg d
  if d==.nil then return .nil
  if d["schema"]==.nil | d["schema"]<>"migratable.job.ack/2" then return .nil
  required=.array~of("code","handoffId","migrationId","jobId","checkpointId","destinationNodeId","destinationPlacementId")
  do k over required; if d[k]==.nil | d[k]="" then return .nil; end
  ok=.false; if d["ok"]<>.nil then ok=(d["ok"]==.true | d["ok"]~string~upper="TRUE" | d["ok"]~string="1")
  return .MigratableJobResumeAcknowledgement~new(ok,d["code"],d["handoffId"],d["migrationId"],d["jobId"],d["checkpointId"],d["destinationNodeId"],d["destinationPlacementId"],self~n(d,"destinationOwnershipEpoch"),self~v(d,"executionRef"),self~v(d,"detail"),self~n(d,"epochMs"))
::method v private class
  use strict arg d,k
  v=d[k]; if v==.nil then return ""; return v~string
::method n private class
  use strict arg d,k
  v=d[k]; if v==.nil | \datatype(v,"N") then return 0; return .MigratableJobTime~number(v)

/* Verifies portable/local checkpoint bytes when the transfer evidence is a
 * sha256 reference.  Other provider verification references remain the
 * responsibility of their Storage Fabric/provider verifier. */
::class MigratableJobCheckpointFileVerifier public
::method verify
  use strict arg pathArg, verificationRefArg
  path=pathArg~string; verification=verificationRefArg~string~lower
  if \verification~startsWith("sha256:") then return .true
  expected=verification~substr(8)
  if stream(path,"c","query exists")="" then return .false
  tmp=SysTempFileName("/tmp/migratable-job-sha256-??????")
  address system "/usr/bin/sha256sum -- "||self~shellQuote(path)||" > "||self~shellQuote(tmp)||" 2>/dev/null"
  result=rc
  if result<>0 then do; call SysFileDelete tmp; return .false; end
  line=linein(tmp); call stream tmp,"c","close"; call SysFileDelete tmp
  return word(line,1)~lower=expected
::method shellQuote private
  use strict arg s
  sq="'"; dq='"'; replacement=sq||dq||sq||dq||sq
  return sq||changestr(sq,s,replacement)||sq

/* Common destination runner.  The destination executor is deliberately local:
 * it must enforce its runtime/authority policy and make repeated start calls
 * with the same handoff idempotent. */
::class MigratableJobDestinationRunner public
::method init
  expose executor fileVerifier
  use strict arg executorArg, fileVerifierArg=.nil
  executor=executorArg
  if executor==.nil then raise syntax 88.900 array("destination executor required")
  if fileVerifierArg==.nil then fileVerifier=.MigratableJobCheckpointFileVerifier~new; else fileVerifier=fileVerifierArg
::method start
  expose executor fileVerifier
  use strict arg instruction, nowEpochMs, checkpointOverride=""
  if instruction==.nil then return .nil
  checkpoint=checkpointOverride~string
  if checkpoint="" then checkpoint=instruction~checkpointRef
  verifyPath=checkpoint
  if verifyPath~startsWith("file:") then verifyPath=verifyPath~substr(6)
  if instruction~verificationRef~lower~startsWith("sha256:") then do
    if \fileVerifier~verify(verifyPath,instruction~verificationRef) then return .MigratableJobResumeAcknowledgement~failure(instruction,"CHECKPOINT_VERIFICATION_FAILED",verifyPath,nowEpochMs)
  end
  rr=executor~start(instruction,checkpoint,nowEpochMs)
  if rr==.nil then return .MigratableJobResumeAcknowledgement~failure(instruction,"DESTINATION_RESULT_MISSING","",nowEpochMs)
  if \rr~ok then return .MigratableJobResumeAcknowledgement~failure(instruction,rr~code,rr~detail,nowEpochMs)
  return .MigratableJobResumeAcknowledgement~success(instruction,rr~executionRef,nowEpochMs)

/* Digest-protected control manifest.  Checkpoint bytes remain the Storage
 * Fabric data plane and may be copied separately for an air-gap/manual move. */
::class MigratableJobFileHandoffTransport subclass MigratableJobHandoffTransport public
::method init
  expose root digestProvider replyTo
  use strict arg rootArg, digestArg=.nil, replyToArg=""
  root=rootArg~string; replyTo=replyToArg~string
  if root="" then raise syntax 88.900 array("file handoff root required")
  if digestArg==.nil then digestProvider=.JobNodeDigestProvider~new; else digestProvider=digestArg
  call SysMkDir root
::method mode
  return .MigratableJobHandoffMode~FILE
::method submit
  expose root digestProvider replyTo
  use strict arg migration, nowEpochMs
  if migration~handoffId="" then return .MigratableJobHandoffSubmission~failure("HANDOFF_ID_REQUIRED")
  i=.MigratableJobHandoffInstruction~fromMigration(migration,self~mode,migration~handoffId,nowEpochMs,replyTo)
  if i==.nil then return .MigratableJobHandoffSubmission~failure("HANDOFF_INSTRUCTION_INCOMPLETE")
  path=root||"/"||migration~handoffId||".mjob"
  if stream(path,"c","query exists")<>"" then do
    existing=self~read(path)
    if existing<>.nil & existing~canonical=i~canonical then return .MigratableJobHandoffSubmission~success(i~handoffId,path)
    return .MigratableJobHandoffSubmission~failure("HANDOFF_FILE_CONFLICT",path)
  end
  if \self~write(path,i) then return .MigratableJobHandoffSubmission~failure("HANDOFF_FILE_WRITE_FAILED",path)
  return .MigratableJobHandoffSubmission~success(i~handoffId,path)
::method write
  expose digestProvider
  use strict arg path, instruction
  d=.MigratableJobHandoffCodec~instructionToDirectory(instruction)
  keys=self~instructionKeys
  s=.stream~new(path); opened=s~open("write replace")
  if opened<>"READY:" then return .false
  s~lineout("MIGRATABLE-JOB-HANDOFF-2")
  do k over keys; s~lineout(k||"|"||c2x(d[k]~string)); end
  s~lineout("DIGEST|"||digestProvider~digest(instruction~canonical)); s~close
  return .true
::method read
  expose digestProvider
  use strict arg path
  s=.stream~new(path); opened=s~open("read")
  if opened<>"READY:" then return .nil
  magic=s~linein; if magic<>"MIGRATABLE-JOB-HANDOFF-2" then do; s~close; return .nil; end
  d=.directory~new; expected=""
  do while s~lines>0
    line=s~linein; p=line~pos("|"); if p=0 then iterate
    k=line~left(p-1); v=line~substr(p+1)
    if k="DIGEST" then expected=v
    else d[k]=x2c(v)
  end
  s~close
  i=.MigratableJobHandoffCodec~instructionFromDirectory(d)
  if i==.nil | expected="" then return .nil
  if digestProvider~digest(i~canonical)<>expected then return .nil
  return i
::method writeAcknowledgement
  expose digestProvider
  use strict arg path, acknowledgement
  d=.MigratableJobHandoffCodec~acknowledgementToDirectory(acknowledgement)
  keys=self~ackKeys; canonical=self~ackCanonical(acknowledgement)
  s=.stream~new(path); opened=s~open("write replace"); if opened<>"READY:" then return .false
  s~lineout("MIGRATABLE-JOB-ACK-2")
  do k over keys; s~lineout(k||"|"||c2x(d[k]~string)); end
  s~lineout("DIGEST|"||digestProvider~digest(canonical)); s~close; return .true
::method readAcknowledgement
  expose digestProvider
  use strict arg path
  s=.stream~new(path); opened=s~open("read"); if opened<>"READY:" then return .nil
  magic=s~linein; if magic<>"MIGRATABLE-JOB-ACK-2" then do; s~close; return .nil; end
  d=.directory~new; expected=""
  do while s~lines>0
    line=s~linein; p=line~pos("|"); if p=0 then iterate
    k=line~left(p-1); v=line~substr(p+1)
    if k="DIGEST" then expected=v
    else d[k]=x2c(v)
  end
  s~close
  a=.MigratableJobHandoffCodec~acknowledgementFromDirectory(d); if a==.nil | expected="" then return .nil
  if digestProvider~digest(self~ackCanonical(a))<>expected then return .nil
  return a
::method instructionKeys private
  return .array~of("schema","handoffId","mode","migrationId","jobId","definitionRef","partitionId","checkpointId","sourceNodeId","sourcePlacementId","sourceOwnershipEpoch","destinationNodeId","destinationPlacementId","destinationOwnershipEpoch","checkpointRef","checkpointStateDigest","verificationRef","commitEvidenceRef","runtimeId","runtimeGeneration","executableRevision","createdEpochMs","replyTo")
::method ackKeys private
  return .array~of("schema","ok","code","handoffId","migrationId","jobId","checkpointId","destinationNodeId","destinationPlacementId","destinationOwnershipEpoch","executionRef","detail","epochMs")
::method ackCanonical private
  use strict arg a
  return "ok="||a~ok||";code="||a~code||";handoff="||a~handoffId||";migration="||a~migrationId||";job="||a~jobId||";checkpoint="||a~checkpointId||";node="||a~destinationNodeId||";placement="||a~destinationPlacementId||";epoch="||a~destinationOwnershipEpoch||";execution="||a~executionRef||";detail="||a~detail||";at="||a~epochMs

::class MigratableJobFileManualStarter public
::method init
  expose fileTransport runner
  use strict arg fileTransportArg, runnerArg
  fileTransport=fileTransportArg; runner=runnerArg
::method start
  expose fileTransport runner
  use strict arg handoffPath, nowEpochMs, checkpointOverride="", acknowledgementPath=""
  i=fileTransport~read(handoffPath)
  if i==.nil then return .nil
  a=runner~start(i,nowEpochMs,checkpointOverride)
  if a<>.nil & acknowledgementPath<>"" then ignore=fileTransport~writeAcknowledgement(acknowledgementPath,a)
  return a

::requires "MigratableJob.cls"
