/* Standard starter contract for Migratable Job v0.2.5.
 *
 * One starter covers three entry conditions:
 *   NEW      - first execution of a migratable workload;
 *   RECOVER  - restart/reconcile a durable migration transaction;
 *   HANDOFF  - start a committed destination handoff.
 *
 * The starter owns request binding and durable start-id receipts.  Workload
 * code supplies only the stable definition plus the local NEW executor.
 * Destination HANDOFF execution continues through MigratableJobDestinationRunner.
 */

::class MigratableJobStartContract public
::constant API "migratable.job.start/1"
::constant RECEIPT_API "migratable.job.start.receipt/1"

::class MigratableJobStartMode public
::constant NEW "NEW"
::constant RECOVER "RECOVER"
::constant HANDOFF "HANDOFF"

::class MigratableJobStartState public
::constant CLAIMED "CLAIMED"
::constant PENDING "PENDING"
::constant RUNNING "RUNNING"
::constant FAILED "FAILED"

::class MigratableJobStartRequest public
::attribute startId get
::attribute mode get
::attribute jobId get
::attribute definitionRef get
::attribute partitionId get
::attribute migrationId get
::attribute requestedEpochMs get
::attribute handoffInstruction get
::attribute checkpointOverride get
::attribute leaseDurationMs get
::attribute maxTransferChunks get
::attribute metadataRef get
::method init
  expose startId mode jobId definitionRef partitionId migrationId requestedEpochMs handoffInstruction checkpointOverride leaseDurationMs maxTransferChunks metadataRef
  use strict arg startIdArg="", modeArg="NEW", jobIdArg="", definitionRefArg="", partitionArg="", migrationArg="", requestedArg=0, instructionArg=.nil, checkpointOverrideArg="", leaseDurationArg=30000, maxTransferChunksArg=0, metadataRefArg=""
  handoffInstruction=instructionArg
  mode=modeArg~string~upper
  if mode<>.MigratableJobStartMode~NEW & mode<>.MigratableJobStartMode~RECOVER & mode<>.MigratableJobStartMode~HANDOFF then raise syntax 88.900 array("invalid migratable job start mode",mode)
  startId=startIdArg~string; jobId=jobIdArg~string; definitionRef=definitionRefArg~string; partitionId=partitionArg~string; migrationId=migrationArg~string
  if mode=.MigratableJobStartMode~HANDOFF & handoffInstruction<>.nil then do
    if startId="" then startId=handoffInstruction~handoffId
    if jobId="" then jobId=handoffInstruction~jobId
    if definitionRef="" then definitionRef=handoffInstruction~definitionRef
    if partitionId="" then partitionId=handoffInstruction~partitionId
    if migrationId="" then migrationId=handoffInstruction~migrationId
  end
  if startId="" then raise syntax 88.900 array("start id required")
  if jobId="" then raise syntax 88.900 array("job id required")
  if definitionRef="" then definitionRef="job:"||jobId
  if mode=.MigratableJobStartMode~HANDOFF & handoffInstruction==.nil then raise syntax 88.900 array("handoff instruction required")
  requestedEpochMs=.MigratableJobTime~number(requestedArg); checkpointOverride=checkpointOverrideArg~string
  leaseDurationMs=leaseDurationArg+0; maxTransferChunks=maxTransferChunksArg+0; metadataRef=metadataRefArg~string
  if leaseDurationMs<1 then raise syntax 88.900 array("lease duration must be positive")
  if maxTransferChunks<0 then raise syntax 88.900 array("max transfer chunks must not be negative")
::method canonical
  expose startId mode jobId definitionRef partitionId migrationId handoffInstruction checkpointOverride leaseDurationMs maxTransferChunks metadataRef
  handoff=""
  if handoffInstruction<>.nil then handoff=handoffInstruction~canonical
  return "start="||startId||";mode="||mode||";job="||jobId||";definition="||definitionRef||";partition="||partitionId||";migration="||migrationId||";checkpointOverride="||checkpointOverride||";leaseMs="||leaseDurationMs||";maxChunks="||maxTransferChunks||";metadata="||metadataRef||";handoff={"||handoff||"}"

::class MigratableJobStartResult public
::attribute ok get
::attribute code get
::attribute state get
::attribute startId get
::attribute mode get
::attribute jobId get
::attribute migrationId get
::attribute executionRef get
::attribute detail get
::attribute replayed get
::method init
  expose ok code state startId mode jobId migrationId executionRef detail replayed
  use strict arg okArg, codeArg, stateArg, startIdArg, modeArg, jobIdArg, migrationArg="", executionArg="", detailArg="", replayedArg=.false
  ok=(okArg==.true); code=codeArg~string; state=stateArg~string; startId=startIdArg~string; mode=modeArg~string; jobId=jobIdArg~string
  migrationId=migrationArg~string; executionRef=executionArg~string; detail=detailArg~string; replayed=(replayedArg==.true)
::method running class
  use strict arg request, executionRefArg, migrationArg="", replayedArg=.false
  return self~new(.true,"RUNNING",.MigratableJobStartState~RUNNING,request~startId,request~mode,request~jobId,migrationArg,executionRefArg,"",replayedArg)
::method pending class
  use strict arg request, codeArg, migrationArg="", detailArg=""
  return self~new(.true,codeArg,.MigratableJobStartState~PENDING,request~startId,request~mode,request~jobId,migrationArg,"",detailArg,.false)
::method failure class
  use strict arg request, codeArg, detailArg="", migrationArg=""
  return self~new(.false,codeArg,.MigratableJobStartState~FAILED,request~startId,request~mode,request~jobId,migrationArg,"",detailArg,.false)

::class MigratableJobStartReceipt public
::attribute startId get
::attribute fingerprint get
::attribute mode get
::attribute state get
::attribute code get
::attribute jobId get
::attribute definitionRef get
::attribute partitionId get
::attribute migrationId get
::attribute executionRef get
::attribute epochMs get
::method init
  expose startId fingerprint mode state code jobId definitionRef partitionId migrationId executionRef epochMs
  use strict arg startArg, fingerprintArg, modeArg, stateArg, codeArg, jobArg, definitionArg, partitionArg="", migrationArg="", executionArg="", epochArg=0
  startId=startArg~string; fingerprint=fingerprintArg~string; mode=modeArg~string; state=stateArg~string; code=codeArg~string; jobId=jobArg~string; definitionRef=definitionArg~string
  partitionId=partitionArg~string; migrationId=migrationArg~string; executionRef=executionArg~string; epochMs=.MigratableJobTime~number(epochArg)
::method canonical
  expose startId fingerprint mode state code jobId definitionRef partitionId migrationId executionRef epochMs
  return "start="||startId||";fingerprint="||fingerprint||";mode="||mode||";state="||state||";code="||code||";job="||jobId||";definition="||definitionRef||";partition="||partitionId||";migration="||migrationId||";execution="||executionRef||";at="||epochMs

::class MigratableJobStartReceiptLookup public
::attribute valid get
::attribute code get
::attribute receipt get
::method init
  expose valid code receipt
  use strict arg validArg, codeArg, receiptArg=.nil
  valid=(validArg==.true); code=codeArg~string; receipt=receiptArg

/* Append-only digest-protected starter receipts. CLAIMED is written before a
 * runtime side-effect. If the process dies after execution but before RUNNING
 * is recorded, retry uses the same startId; NEW executors MUST be idempotent by
 * startId and HANDOFF executors are already idempotent by handoffId. */
::class MigratableJobStartReceiptStore public
::method init
  expose path digestProvider
  use strict arg pathArg, digestArg=.nil
  path=pathArg~string
  if path="" then raise syntax 88.900 array("start receipt path required")
  if digestArg==.nil then digestProvider=.JobNodeDigestProvider~new; else digestProvider=digestArg
::method fingerprint
  expose digestProvider
  use strict arg request
  return digestProvider~digest(request~canonical)
::method claim guarded
  use strict arg request, nowEpochMs
  fp=self~fingerprint(request)
  lookup=self~load(request~startId)
  if \lookup~valid then return lookup
  if lookup~receipt<>.nil then do
    if lookup~receipt~fingerprint<>fp then return .MigratableJobStartReceiptLookup~new(.false,"START_ID_CONFLICT",lookup~receipt)
    return lookup
  end
  r=.MigratableJobStartReceipt~new(request~startId,fp,request~mode,.MigratableJobStartState~CLAIMED,"START_CLAIMED",request~jobId,request~definitionRef,request~partitionId,request~migrationId,"",nowEpochMs)
  if \self~append(r) then return .MigratableJobStartReceiptLookup~new(.false,"START_RECEIPT_WRITE_FAILED",.nil)
  return .MigratableJobStartReceiptLookup~new(.true,"CLAIMED",r)
::method record guarded
  use strict arg request, result, nowEpochMs
  fp=self~fingerprint(request)
  lookup=self~load(request~startId)
  if \lookup~valid then return .false
  if lookup~receipt<>.nil & lookup~receipt~fingerprint<>fp then return .false
  r=.MigratableJobStartReceipt~new(request~startId,fp,request~mode,result~state,result~code,request~jobId,request~definitionRef,request~partitionId,result~migrationId,result~executionRef,nowEpochMs)
  return self~append(r)
::method load guarded
  expose path digestProvider
  use strict arg startIdArg
  startId=startIdArg~string
  if stream(path,"c","query exists")="" then return .MigratableJobStartReceiptLookup~new(.true,"NO_RECEIPT",.nil)
  s=.stream~new(path); opened=s~open("read")
  if opened<>"READY:" then return .MigratableJobStartReceiptLookup~new(.false,"START_RECEIPT_READ_FAILED",.nil)
  latest=.nil
  do while s~lines>0
    line=s~linein
    parsed=self~parseLine(line)
    if parsed==.nil then do; s~close; return .MigratableJobStartReceiptLookup~new(.false,"START_RECEIPT_INTEGRITY_FAILED",.nil); end
    if parsed~startId=startId then latest=parsed
  end
  s~close
  return .MigratableJobStartReceiptLookup~new(.true,"OK",latest)
::method append private
  expose path digestProvider
  use strict arg receipt
  material=receipt~canonical
  digest=digestProvider~digest(material)
  values=.array~of(receipt~startId,receipt~fingerprint,receipt~mode,receipt~state,receipt~code,receipt~jobId,receipt~definitionRef,receipt~partitionId,receipt~migrationId,receipt~executionRef,receipt~epochMs)
  out="START1"
  do v over values; out=out||"|"||c2x(v~string); end
  out=out||"|"||digest
  s=.stream~new(path); opened=s~open("write append"); if opened<>"READY:" then return .false
  s~lineout(out); s~close; return .true
::method parseLine private
  expose digestProvider
  use strict arg line
  p=self~split(line)
  if p~items<>13 | p[1]<>"START1" then return .nil
  vals=.array~new
  do i=2 to 12
    h=p[i]~string
    if h<>"" then do
      if h~length//2<>0 | verify(h,"0123456789ABCDEFabcdef")<>0 then return .nil
    end
    vals~append(x2c(h))
  end
  if \datatype(vals[11],"N") then return .nil
  r=.MigratableJobStartReceipt~new(vals[1],vals[2],vals[3],vals[4],vals[5],vals[6],vals[7],vals[8],vals[9],vals[10],.MigratableJobTime~number(vals[11]))
  if digestProvider~digest(r~canonical)<>p[13] then return .nil
  return r
::method split private
  use strict arg text
  a=.array~new; rest=text~string
  do forever
    pos=rest~pos("|")
    if pos=0 then do; a~append(rest); leave; end
    a~append(rest~left(pos-1)); rest=rest~substr(pos+1)
  end
  return a

/* Workload-owned seam. definition() returns the stable binding used by every
 * mode. startNew() launches the first execution and MUST treat request~startId
 * as its idempotency key. */
::class MigratableJobStarterApplication public
::method definition abstract
::method startNew abstract
::method afterStart
  return .true

/* Standard durable path layout.  IDs are hex-encoded so arbitrary job and
 * partition identifiers cannot escape the configured state root. */
::class MigratableJobStartLayout public
::attribute root get
::attribute jobRoot get
::attribute migrationJournal get
::attribute provenanceLedger get
::attribute startReceipts get
::attribute handoffRoot get
::method init
  expose root jobRoot migrationJournal provenanceLedger startReceipts handoffRoot
  use strict arg rootArg, jobIdArg, partitionArg=""
  root=rootArg~string
  if root="" then raise syntax 88.900 array("starter state root required")
  jobRoot=root||"/job-"||c2x(jobIdArg~string)
  if partitionArg~string<>"" then jobRoot=jobRoot||"/partition-"||c2x(partitionArg~string)
  self~mkdirs(jobRoot)
  handoffRoot=jobRoot||"/handoff"; self~mkdirs(handoffRoot)
  migrationJournal=jobRoot||"/migration.journal"
  provenanceLedger=jobRoot||"/provenance.events"
  startReceipts=jobRoot||"/start.receipts"
::method mkdirs private
  use strict arg path
  address system "/bin/mkdir -p -- "||self~shellQuote(path)
  if rc<>0 then raise syntax 88.900 array("could not create starter state directory",path)
::method shellQuote private
  use strict arg s
  sq="'"; dq='"'; replacement=sq||dq||sq||dq||sq
  return sq||changestr(sq,s,replacement)||sq

::class MigratableJobStarter public
::method init
  expose application receiptStore coordinator destinationRunner
  use strict arg applicationArg, receiptStoreArg, coordinatorArg=.nil, destinationRunnerArg=.nil
  application=applicationArg; receiptStore=receiptStoreArg; coordinator=coordinatorArg; destinationRunner=destinationRunnerArg
  if application==.nil | receiptStore==.nil then raise syntax 88.900 array("starter application and receipt store required")
::method start guarded
  expose application receiptStore coordinator destinationRunner
  use strict arg request
  if request==.nil then return .nil
  now=request~requestedEpochMs
  if now<=0 then now=.MigratableJobTime~nowEpochMs
  claim=receiptStore~claim(request,now)
  if \claim~valid then return .MigratableJobStartResult~failure(request,claim~code,"start id receipt conflict or integrity failure",request~migrationId)
  if claim~receipt<>.nil & claim~receipt~state=.MigratableJobStartState~RUNNING then do
    return .MigratableJobStartResult~running(request,claim~receipt~executionRef,claim~receipt~migrationId,.true)
  end

  definition=application~definition(request)
  bind=self~validateDefinition(request,definition)
  if bind<>"" then do
    result=.MigratableJobStartResult~failure(request,bind,"starter request does not bind to workload definition",request~migrationId)
    ignore=receiptStore~record(request,result,now); return result
  end

  select
    when request~mode=.MigratableJobStartMode~NEW then result=self~startNew(request,definition)
    when request~mode=.MigratableJobStartMode~RECOVER then result=self~recover(request,definition,now)
    when request~mode=.MigratableJobStartMode~HANDOFF then result=self~handoff(request,definition,now)
    otherwise result=.MigratableJobStartResult~failure(request,"START_MODE_INVALID","",request~migrationId)
  end
  if result==.nil then result=.MigratableJobStartResult~failure(request,"START_RESULT_MISSING","",request~migrationId)
  ignore=receiptStore~record(request,result,now)
  ignore=application~afterStart(request,result)
  return result
::method startNew private
  expose application
  use strict arg request, definition
  rr=application~startNew(request,definition)
  if rr==.nil then return .MigratableJobStartResult~failure(request,"NEW_START_RESULT_MISSING")
  if \rr~ok then return .MigratableJobStartResult~failure(request,rr~code,rr~detail)
  if rr~executionRef="" then return .MigratableJobStartResult~failure(request,"EXECUTION_REF_REQUIRED")
  return .MigratableJobStartResult~running(request,rr~executionRef)
::method recover private
  expose coordinator
  use strict arg request, definition, now
  if coordinator==.nil then return .MigratableJobStartResult~failure(request,"RECOVERY_COORDINATOR_REQUIRED")
  snap=coordinator~restore(definition,now)
  if snap==.nil then return .MigratableJobStartResult~failure(request,"RECOVERY_SNAPSHOT_MISSING")
  if \snap~valid then return .MigratableJobStartResult~failure(request,snap~code)
  m=snap~migration
  if m==.nil then return .MigratableJobStartResult~failure(request,"RECOVERY_MIGRATION_MISSING")
  if request~migrationId<>"" & request~migrationId<>m~migrationId then return .MigratableJobStartResult~failure(request,"MIGRATION_BINDING_MISMATCH","",m~migrationId)
  if m~state=.MigratableJobMigrationState~RUNNING then return .MigratableJobStartResult~running(request,m~executionRef,m~migrationId)
  if m~state=.MigratableJobMigrationState~FAILED then return .MigratableJobStartResult~failure(request,"MIGRATION_FAILED",m~failureCode||":"||m~failureDetail,m~migrationId)
  if m~state=.MigratableJobMigrationState~PAUSED then ok=coordinator~resumePaused(m,now,request~leaseDurationMs,request~maxTransferChunks)
  else ok=coordinator~step(m,now,request~leaseDurationMs,request~maxTransferChunks)
  if m~state=.MigratableJobMigrationState~RUNNING then return .MigratableJobStartResult~running(request,m~executionRef,m~migrationId)
  if m~state=.MigratableJobMigrationState~FAILED then return .MigratableJobStartResult~failure(request,"MIGRATION_FAILED",m~failureCode||":"||m~failureDetail,m~migrationId)
  detail=m~state
  if m~failureCode<>"" then detail=detail||":"||m~failureCode
  return .MigratableJobStartResult~pending(request,"RECOVERY_PENDING",m~migrationId,detail)
::method handoff private
  expose destinationRunner
  use strict arg request, definition, now
  if destinationRunner==.nil then return .MigratableJobStartResult~failure(request,"DESTINATION_RUNNER_REQUIRED","",request~migrationId)
  i=request~handoffInstruction
  if i==.nil then return .MigratableJobStartResult~failure(request,"HANDOFF_INSTRUCTION_REQUIRED","",request~migrationId)
  if i~jobId<>definition~jobId | i~definitionRef<>definition~definitionRef | i~partitionId<>definition~partitionId then return .MigratableJobStartResult~failure(request,"HANDOFF_DEFINITION_MISMATCH","",i~migrationId)
  if request~migrationId<>"" & request~migrationId<>i~migrationId then return .MigratableJobStartResult~failure(request,"MIGRATION_BINDING_MISMATCH","",i~migrationId)
  ack=destinationRunner~start(i,now,request~checkpointOverride)
  if ack==.nil then return .MigratableJobStartResult~failure(request,"DESTINATION_ACK_MISSING","",i~migrationId)
  if \ack~ok then return .MigratableJobStartResult~failure(request,ack~code,ack~detail,i~migrationId)
  if ack~executionRef="" then return .MigratableJobStartResult~failure(request,"EXECUTION_REF_REQUIRED","",i~migrationId)
  return .MigratableJobStartResult~running(request,ack~executionRef,i~migrationId)
::method validateDefinition private
  use strict arg request, definition
  if definition==.nil then return "DEFINITION_MISSING"
  if definition~jobId<>request~jobId then return "JOB_BINDING_MISMATCH"
  if definition~definitionRef<>request~definitionRef then return "DEFINITION_BINDING_MISMATCH"
  if request~partitionId<>"" & definition~partitionId<>request~partitionId then return "PARTITION_BINDING_MISMATCH"
  return ""

/* Adapter used by Queue Fabric destination workers and file/manual starters.
 * Both transports continue to speak the existing acknowledgement contract,
 * but every destination start is first normalised through MigratableJobStarter. */
::class MigratableJobStarterDestinationRunner public
::method init
  expose starter
  use strict arg starterArg
  starter=starterArg
  if starter==.nil then raise syntax 88.900 array("standard starter required")
::method start
  expose starter
  use strict arg instruction, nowEpochMs, checkpointOverride=""
  if instruction==.nil then return .nil
  request=.MigratableJobStartRequest~new(instruction~handoffId,.MigratableJobStartMode~HANDOFF,instruction~jobId,instruction~definitionRef,instruction~partitionId,instruction~migrationId,nowEpochMs,instruction,checkpointOverride)
  result=starter~start(request)
  if result==.nil then return .MigratableJobResumeAcknowledgement~failure(instruction,"START_RESULT_MISSING","standard starter returned nil",nowEpochMs)
  if \result~ok then return .MigratableJobResumeAcknowledgement~failure(instruction,result~code,result~detail,nowEpochMs)
  if result~state<>.MigratableJobStartState~RUNNING then return .MigratableJobResumeAcknowledgement~failure(instruction,"START_NOT_RUNNING",result~code||":"||result~detail,nowEpochMs)
  return .MigratableJobResumeAcknowledgement~success(instruction,result~executionRef,nowEpochMs)

::requires "MigratableJobDurable.cls"
::requires "MigratableJobHandoff.cls"
