/* FD Door Micro Motion v0.2-dev5 standard starter application.
 *
 * NEW execution is not allowed to manufacture or accept placement fields in
 * the launch spec.  The native JobPlacementRequest lives in definition(), the
 * Migratable Job v0.2.4 managed placement tool verifies a real Job-to-Node
 * lease, and FDDoorMicroMotionPlacedStartExecutor binds that lease here just
 * before entry through migratable.job.start/1.
 */

::class FDDoorMicroMotionStarterApplication subclass MigratableJobStarterApplication public
::attribute layout get
::attribute definitionRef get
::attribute jobId get
::attribute partitionId get
::attribute sourceNodeId get
::attribute sourceEvidenceRef get
::attribute sourcePlacementId get
::attribute sourceOwnershipEpoch get
::attribute launchSpecPath get

::method init
  expose launchSpecPath launchSpec runnerScript rexxCommand launchTimeoutMs pollMs layout definitionObject definitionRef jobId partitionId sourceNodeId sourceEvidenceRef sourcePlacementId sourceOwnershipEpoch initialLease ownerNodeId stateDir outputPrefix
  use strict arg launchSpecArg, runnerArg, stateRootArg='', rexxArg='rexx', timeoutArg=120000, pollArg=250
  launchSpecPath=launchSpecArg~string; runnerScript=runnerArg~string; rexxCommand=rexxArg~string
  launchTimeoutMs=timeoutArg+0; pollMs=pollArg+0
  if launchSpecPath='' | runnerScript='' then raise syntax 88.900 array('FD starter launch spec and runner are required')
  if launchTimeoutMs<1 | pollMs<1 then raise syntax 88.900 array('FD starter polling values must be positive')
  launchSpec=.FDControlFile~read(launchSpecPath)
  if launchSpec==.nil then raise syntax 88.900 array('FD starter cannot read launch spec',launchSpecPath)
  jobId=launchSpec~require('job_id'); partitionId=launchSpec~get('partition_id',jobId)
  sourceNodeId=launchSpec~require('source_node_id'); ownerNodeId=launchSpec~get('owner_node_id',sourceNodeId)
  stateDir=launchSpec~require('state_dir'); outputPrefix=launchSpec~require('output_prefix'); sourceEvidenceRef=launchSpec~require('source_evidence_ref')
  /* Any historical source placement fields in a HANDOFF destination spec are
   * provenance only.  NEW execution ignores them and still requires a lease
   * injected by the managed placement START executor. */
  sourcePlacementId=''; sourceOwnershipEpoch=0; initialLease=.nil
  stateRoot=stateRootArg~string
  if stateRoot='' then stateRoot=launchSpec~get('migratable_state_root',stateDir||'/migratable')
  layout=.MigratableJobStartLayout~new(stateRoot,jobId,partitionId)

  digest=.JobNodeDigestProvider~new
  definitionRef='fd-door-micro-motion:'||.FDDoorMicroMotionVersion~VERSION||':sha256:'||digest~digest(self~scientificCanonical(launchSpec))
  declared=launchSpec~get('definition_ref','')
  if declared<>'' & declared<>definitionRef then raise syntax 88.900 array('FD definition_ref does not match scientific launch binding',declared,definitionRef)

  abilities=.array~of('FD.DOOR.MICRO.MOTION')
  runtimes=.array~of('OOREXX/5.3')
  sourceTag='FD.SOURCE.'||sourceEvidenceRef~upper~changestr(':','_')
  assignmentTag='FD.ASSIGNED.'||jobId~upper
  tags=.array~of('FD.NIGHT.F11',assignmentTag,sourceTag)
  req=.JobNodeRequirement~new(.nil,.nil,.nil,.nil,abilities,runtimes,tags,'',256,128,1,64,64,1,0)
  placement=.JobPlacementRequest~new(jobId,req,ownerNodeId,0,0,0,.array~of('FD.NIGHT.F11'))
  inputs=.array~of(sourceEvidenceRef)
  outputs=.array~of('logical-output:'||.FDFileUtil~baseName(outputPrefix))
  allowed=self~splitNodes(launchSpec~get('allowed_destination_nodes',''))
  definitionObject=.MigratableJobDefinition~new(jobId,placement,definitionRef,partitionId,ownerNodeId,'OOREXX','5.3-r13196',.FDDoorMicroMotionVersion~VERSION,inputs,outputs,.true,allowed)

::method definition
  expose definitionObject
  use arg request=.nil
  return definitionObject

::method bindInitialLease
  expose initialLease definitionObject jobId sourceNodeId ownerNodeId sourcePlacementId sourceOwnershipEpoch
  use strict arg lease
  if lease==.nil then return .false
  if lease~jobId<>jobId | lease~nodeId<>sourceNodeId | lease~ownerNodeId<>ownerNodeId then return .false
  if lease~placementId='' | lease~ownershipEpoch<1 then return .false
  expected=.JobNodeDigestProvider~new~digest(definitionObject~placementRequest~canonical)
  if lease~requirementDigest<>expected then return .false
  if initialLease<>.nil then do
    if initialLease~placementId<>lease~placementId | initialLease~ownershipEpoch<>lease~ownershipEpoch then return .false
    return .true
  end
  initialLease=lease; sourcePlacementId=lease~placementId; sourceOwnershipEpoch=lease~ownershipEpoch
  return .true

::method startNew
  expose launchSpec runnerScript rexxCommand launchTimeoutMs pollMs layout definitionRef jobId partitionId sourceNodeId sourcePlacementId sourceOwnershipEpoch initialLease stateDir
  use strict arg request, definition
  if initialLease==.nil then return .MigratableJobResumeResult~failure('FD_MANAGED_PLACEMENT_REQUIRED','NEW start must enter through migratable.job.placement/1 START')
  if request~startId<>launchSpec~get('start_id','') then return .MigratableJobResumeResult~failure('FD_START_ID_MISMATCH')
  if definition~definitionRef<>definitionRef then return .MigratableJobResumeResult~failure('FD_DEFINITION_BINDING_MISMATCH')

  execPath=self~executionPath(request~startId)
  existing=.FDControlFile~read(execPath)
  if existing<>.nil then do
    if existing~get('start_id','')<>request~startId | existing~get('job_id','')<>jobId | existing~get('definition_ref','')<>definitionRef then return .MigratableJobResumeResult~failure('FD_EXECUTION_RECORD_BINDING_MISMATCH',execPath)
    if existing~get('source_placement_id','')<>sourcePlacementId | existing~get('source_ownership_epoch','0')+0<>sourceOwnershipEpoch then return .MigratableJobResumeResult~failure('FD_EXECUTION_PLACEMENT_BINDING_MISMATCH',execPath)
    state=existing~get('status','')
    if state='RUNNING' | state='STARTING' then return self~recoverClaimedStart(existing,request,execPath)
    return .MigratableJobResumeResult~failure('FD_START_RETRY_REQUIRES_NEW_WORKSPACE','existing execution record is '||state)
  end

  stale=.FDControlFile~read(stateDir||'/running.tsv')
  if stale<>.nil then return .MigratableJobResumeResult~failure('FD_UNOWNED_EXISTING_RUNTIME','state directory already contains running.tsv')
  stale=.FDControlFile~read(stateDir||'/worker.exit.tsv')
  if stale<>.nil then return .MigratableJobResumeResult~failure('FD_UNOWNED_EXISTING_RUNTIME','state directory already contains worker.exit.tsv')

  workerSpec=self~workerSpec(request,definition)
  workerSpecPath=layout~jobRoot||'/initial-'||c2x(request~startId)||'.worker.tsv'
  .FDControlFile~write(workerSpecPath,workerSpec)
  logPath=layout~jobRoot||'/initial-'||c2x(request~startId)||'.worker.log'
  pidPath=layout~jobRoot||'/initial-'||c2x(request~startId)||'.pid'
  executionRef='fd:start:'||c2x(jobId)||':'||c2x(request~startId)

  record=.FDCheckpointState~new
  record~put('status','STARTING'); record~put('start_id',request~startId); record~put('job_id',jobId); record~put('definition_ref',definitionRef); record~put('partition_id',partitionId); record~put('source_node_id',sourceNodeId); record~put('source_placement_id',sourcePlacementId); record~put('source_ownership_epoch',sourceOwnershipEpoch); record~put('execution_ref',executionRef); record~put('worker_spec',workerSpecPath); record~put('worker_log',logPath); record~put('pid_path',pidPath); record~put('pid','')
  .FDControlFile~write(execPath,record)

  cmd='nohup '||self~shellQuote(rexxCommand)||' '||self~shellQuote(runnerScript)||' '||self~shellQuote(workerSpecPath)||' > '||self~shellQuote(logPath)||' 2>&1 & echo $! > '||self~shellQuote(pidPath)
  address system cmd
  if rc<>0 then do
    record~put('status','FAILED'); record~put('failure_code','FD_INITIAL_LAUNCH_FAILED'); .FDControlFile~write(execPath,record)
    return .MigratableJobResumeResult~failure('FD_INITIAL_LAUNCH_FAILED',logPath)
  end
  pid=self~readFirstLine(pidPath)
  record~put('pid',pid); .FDControlFile~write(execPath,record)
  return self~waitForRunning(record,request,execPath)

::method afterStart
  expose launchSpec layout definitionRef jobId partitionId sourceNodeId sourcePlacementId sourceOwnershipEpoch initialLease stateDir
  use strict arg request, startResult
  st=.FDCheckpointState~new
  st~put('schema','fd.migratable.start.status/1'); st~put('status',startResult~state); st~put('code',startResult~code); st~put('start_contract',.MigratableJobStartContract~API); st~put('migration_api',.MigratableJobBuild~API); st~put('migratable_job_version',.MigratableJobBuild~VERSION); st~put('placement_api',.MigratableJobPlacementContract~API); st~put('placement_receipt_api',.MigratableJobPlacementContract~RECEIPT_API)
  st~put('start_id',request~startId); st~put('start_mode',request~mode); st~put('job_id',jobId); st~put('definition_ref',definitionRef); st~put('partition_id',partitionId); st~put('migration_id',startResult~migrationId); st~put('execution_ref',startResult~executionRef); st~put('replayed',startResult~replayed)
  st~put('start_receipts',layout~startReceipts); st~put('migration_journal',layout~migrationJournal); st~put('provenance_ledger',layout~provenanceLedger); st~put('handoff_root',layout~handoffRoot); st~put('status_topic_contract','migratable.job.status/1')
  if request~mode=.MigratableJobStartMode~NEW then do
    if initialLease<>.nil then do
      st~put('source_node_id',initialLease~nodeId); st~put('source_placement_id',initialLease~placementId); st~put('source_ownership_epoch',initialLease~ownershipEpoch); st~put('source_lease_expires_epoch_ms',initialLease~expiresEpochMs); st~put('source_requirement_digest',initialLease~requirementDigest); st~put('source_capability_digest',initialLease~capabilityDigest); st~put('source_capacity_digest',initialLease~capacityDigest)
      authority=.FDCheckpointState~new; authority~put('schema','fd.migratable.initial.authority/2'); authority~put('authority_owner','JOB_TO_NODE'); authority~put('placement_api',.MigratableJobPlacementContract~API); authority~put('job_id',jobId); authority~put('definition_ref',definitionRef); authority~put('partition_id',partitionId); authority~put('source_node_id',initialLease~nodeId); authority~put('source_placement_id',initialLease~placementId); authority~put('source_ownership_epoch',initialLease~ownershipEpoch); authority~put('issued_epoch_ms',initialLease~issuedEpochMs); authority~put('expires_epoch_ms',initialLease~expiresEpochMs); authority~put('requirement_digest',initialLease~requirementDigest); authority~put('capability_digest',initialLease~capabilityDigest); authority~put('capacity_digest',initialLease~capacityDigest); authority~put('start_id',request~startId); authority~put('execution_ref',startResult~executionRef)
      .FDControlFile~write(stateDir||'/migratable.initial.authority.tsv',authority)
    end
    st~put('status_topic_state','MIGRATION_TRANSACTION_NOT_ACTIVE')
  end
  else if request~mode=.MigratableJobStartMode~HANDOFF then do
    i=request~handoffInstruction
    if i<>.nil then do
      st~put('destination_node_id',i~destinationNodeId); st~put('destination_placement_id',i~destinationPlacementId); st~put('destination_ownership_epoch',i~destinationOwnershipEpoch); st~put('checkpoint_id',i~checkpointId); st~put('commit_evidence_ref',i~commitEvidenceRef); st~put('verification_ref',i~verificationRef)
      authority=.FDCheckpointState~new; authority~put('schema','fd.migratable.handoff.authority/1'); authority~put('authority_owner','JOB_TO_NODE'); authority~put('job_id',jobId); authority~put('definition_ref',definitionRef); authority~put('partition_id',partitionId); authority~put('migration_id',i~migrationId); authority~put('handoff_id',i~handoffId); authority~put('destination_node_id',i~destinationNodeId); authority~put('destination_placement_id',i~destinationPlacementId); authority~put('destination_ownership_epoch',i~destinationOwnershipEpoch); authority~put('commit_evidence_ref',i~commitEvidenceRef); authority~put('execution_ref',startResult~executionRef)
      .FDControlFile~write(stateDir||'/migratable.handoff.authority.tsv',authority)
    end
    st~put('status_topic_state','MIGRATION_TRANSACTION_HANDOFF')
  end
  else st~put('status_topic_state','MIGRATION_TRANSACTION_RECOVERY')
  .FDControlFile~write(stateDir||'/migratable.start.status.tsv',st)
  return .true

::method recoverClaimedStart private
  use strict arg existing,request,execPath
  state=existing~get('status','')
  if state='RUNNING' then return .MigratableJobResumeResult~success(existing~get('execution_ref',''))
  return self~waitForRunning(existing,request,execPath)

::method waitForRunning private
  expose launchTimeoutMs pollMs stateDir
  use strict arg record,request,execPath
  waited=0
  do while waited<=launchTimeoutMs
    running=.FDControlFile~read(stateDir||'/running.tsv')
    if running<>.nil then do
      status=running~get('status','')
      if status='RUNNING' | status='OK' then do
        record~put('status','RUNNING'); .FDControlFile~write(execPath,record)
        return .MigratableJobResumeResult~success(record~get('execution_ref',''))
      end
    end
    exited=.FDControlFile~read(stateDir||'/worker.exit.tsv')
    if exited<>.nil then do
      status=exited~get('status','')
      if status<>'' & status<>'OK' & status<>'PAUSED' then do
        record~put('status','FAILED'); record~put('failure_code',status); .FDControlFile~write(execPath,record)
        return .MigratableJobResumeResult~failure('FD_INITIAL_WORKER_FAILED',status)
      end
    end
    pid=record~get('pid','')
    if pid='' then pid=self~readFirstLine(record~get('pid_path',''))
    if pid<>'' then do
      record~put('pid',pid)
      if \self~pidAlive(pid) then do
        record~put('status','FAILED'); record~put('failure_code','FD_INITIAL_WORKER_EXITED_BEFORE_RUNNING'); .FDControlFile~write(execPath,record)
        return .MigratableJobResumeResult~failure('FD_INITIAL_WORKER_EXITED_BEFORE_RUNNING',record~get('worker_log',''))
      end
    end
    call SysSleep pollMs/1000
    waited+=pollMs
  end
  return .MigratableJobResumeResult~failure('FD_INITIAL_START_TIMEOUT',record~get('worker_log',''))

::method workerSpec private
  expose launchSpec definitionRef jobId partitionId sourceNodeId sourcePlacementId sourceOwnershipEpoch initialLease
  use strict arg request,definition
  s=.FDCheckpointState~new
  do k over launchSpec~values~allIndexes; s~put(k,launchSpec~values[k]); end
  s~put('entry_mode','MIGRATABLE_NEW'); s~put('starter_api',.MigratableJobStartContract~API); s~put('migration_api',.MigratableJobBuild~API); s~put('placement_api',.MigratableJobPlacementContract~API); s~put('starter_start_id',request~startId); s~put('job_id',jobId); s~put('definition_ref',definitionRef); s~put('partition_id',partitionId); s~put('source_node_id',sourceNodeId); s~put('source_placement_id',sourcePlacementId); s~put('source_ownership_epoch',sourceOwnershipEpoch)
  if initialLease<>.nil then do
    s~put('source_authority_ref','job-to-node:placement:'||initialLease~placementId); s~put('source_authority_digest',initialLease~requirementDigest); s~put('source_authority_expires_epoch_ms',initialLease~expiresEpochMs); s~put('source_authority_node_id','JOB_TO_NODE_V0.6')
  end
  return s

::method executionPath private
  expose layout
  use strict arg startId
  return layout~jobRoot||'/execution-'||c2x(startId~string)||'.tsv'

::method scientificCanonical private
  use strict arg spec
  out='version='||.FDDoorMicroMotionVersion~VERSION||';source='||.FDFileUtil~baseName(spec~require('source_path'))||';evidence='||spec~require('source_evidence_ref')||';profile='||spec~get('profile','FD_NIGHT_F11')||';wallOrigin='||spec~get('wall_clock_origin','')||';wallStart='||spec~get('analysis_wall_start','')||';wallEnd='||spec~get('analysis_wall_end','')||';reference='||spec~get('reference_media_ms','')
  n=spec~get('exclusion_count','0')+0
  out=out||';exclusions='||n
  do i=1 to n
    p='exclusion_'||i||'_'
    out=out||';x'||i||'='||spec~get(p||'id','')||','||spec~get(p||'wall_start','')||','||spec~get(p||'wall_end','')||','||spec~get(p||'reason','')
  end
  return out

::method splitNodes private
  use strict arg text
  a=.array~new; rest=text~string~strip
  if rest='' then return a
  rest=changestr(',',rest,' ')
  do while words(rest)>0
    parse var rest node rest
    if node<>'' then a~append(node)
  end
  return a

::method readFirstLine private
  use strict arg path
  if path='' | stream(path,'C','QUERY EXISTS')='' then return ''
  line=linein(path); call stream path,'C','CLOSE'
  return line~strip

::method pidAlive private
  use strict arg pid
  if \datatype(pid,'W') then return .false
  address system '/bin/kill -0 '||pid||' >/dev/null 2>&1'
  return rc=0

::method shellQuote private
  use strict arg text
  return "'"||text~string~changestr("'","'\\''")||"'"

::requires 'FDDoorMicroMotion.cls'
::requires 'MigratableJobManagedPlacement.cls'
