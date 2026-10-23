/* RexxOS Managed Compute MU v0.1-dev2. Transport-neutral, fail-closed supervisor. */
::class MUResult public
::attribute ok get
::attribute code get
::attribute detail get
::method init
  expose ok code detail
  use arg good, name, info=""
  ok=good; code=name~string; detail=info~string

::class MUComputeTarget public
::attribute id get
::attribute kind get
::attribute nodeId get
::attribute generation get
::attribute platform get
::attribute isolation get
::attribute port get
::method init
  expose id kind nodeId generation platform isolation port
  use strict arg idArg,kindArg,nodeArg,genArg,platformArg,isolationArg,portArg
  id=idArg~string;kind=kindArg~string~upper;nodeId=nodeArg~string
  generation=genArg+0;platform=platformArg~string~upper
  isolation=isolationArg~string~upper;port=portArg

/* The authority is the genuine v0.6 allocator, never a local shadow lease store. */
::class MUJobNodeDirectAuthority public
::method init
  expose allocator
  use strict arg allocator
::method verify
  expose allocator
  use strict arg lease, request, now
  return allocator~verifyLease(lease,request,now)

/* Explicit provider bridge; only the existing provider runner executes a job. */
::class MUProviderRunnerPort public
::method init
  expose runner
  use strict arg runner
::method invoke
  expose runner
  use strict arg spec
  result=runner~run(spec)
  if result==.nil then return .MUResult~new(.false,"PROVIDER_NO_RECEIPT")
  if \result~hasMethod('SUCCESS') then return .MUResult~new(.false,"PROVIDER_RECEIPT_UNRECOGNISED")
  if result~success then return .MUResult~new(.true,"COMPLETED",result~code)
  return .MUResult~new(.false,"PROVIDER_FAILED",result~code)

/* Windows is always controlled by a Windows-side agent, not a Linux Docker daemon. */
::class MUWindowsAgentPort public
::method init
  expose agent
  use strict arg agent
::method invoke
  expose agent
  use strict arg spec
  return agent~invoke(spec)

/* Portable local ledger. Close() precedes execution. External durable store must
 * provide fsync/replication guarantees for production deployment. */
::class MULocalRunLedger public
::attribute healthy get
::method init
  expose file rows healthy
  use strict arg fileArg
  file=fileArg~string; rows=.directory~new; healthy=.true
  if stream(file,'C','QUERY EXISTS')='' then return
  input=.stream~new(file)
  rc=input~open('READ')
  if rc~left(5)<>"READY" then do; healthy=.false;return;end
  do while input~lines>0
    line=input~linein
    parse var line id '|' fingerprint '|' state
    if id='' | fingerprint='' | state='' | \self~validToken(id) | \self~validToken(fingerprint) then do
      healthy=.false;leave
    end
    if state<>"CLAIMED" & state<>"COMPLETED" & state<>"FAILED" & state<>"UNCERTAIN" then do
      healthy=.false;leave
    end
    prior=rows[id]
    if prior<>.nil then if prior[1]<>fingerprint then do;healthy=.false;leave;end
    rows[id]=.array~of(fingerprint,state)
  end
  input~close
::method validToken
  use strict arg s
  if s='' then return .false
  allowed='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-:'
  do i=1 to s~length
    if allowed~pos(s~substr(i,1))=0 then return .false
  end
  return .true
::method lookup
  expose rows
  use strict arg id
  return rows[id]
::method write
  expose file rows healthy
  use strict arg id,fingerprint,state
  if \healthy | \self~validToken(id) | \self~validToken(fingerprint) then return .false
  prior=rows[id]
  if prior<>.nil then if prior[1]<>fingerprint then return .false
  if state<>"CLAIMED" & state<>"COMPLETED" & state<>"FAILED" & state<>"UNCERTAIN" then return .false
  out=.stream~new(file)
  rc=out~open('APPEND')
  if rc~left(5)<>"READY" then do;healthy=.false;return .false;end
  count=out~lineout(id||'|'||fingerprint||'|'||state)
  out~close
  if count<>0 then do; healthy=.false;return .false;end
  rows[id]=.array~of(fingerprint,state)
  return .true

::class ManagedComputeMU public
::attribute muId get
::method init
  expose muId authority ledger targets
  use strict arg muIdArg,authorityArg,ledgerArg
  muId=muIdArg~string;authority=authorityArg;ledger=ledgerArg
  targets=.directory~new
::method bindTarget
  expose targets
  use strict arg target
  if target==.nil then return .MUResult~new(.false,'TARGET_REQUIRED')
  if target~nodeId='' | target~id='' | target~generation<1 then return .MUResult~new(.false,'BAD_TARGET')
  select
    when target~kind='COLAB' then do
      if target~platform<>"COLAB" then return .MUResult~new(.false,'PLATFORM_MISMATCH')
    end
    when target~kind='ZEROGPU' then do
      if target~platform<>"HF_SPACE" then return .MUResult~new(.false,'PLATFORM_MISMATCH')
    end
    when target~kind='WINDOWS' then do
      if target~platform<>"WINDOWS" then return .MUResult~new(.false,'WINDOWS_HOST_REQUIRED')
      if target~isolation<>"PROCESS" & target~isolation<>"HYPERV" & target~isolation<>"NATIVE" then return .MUResult~new(.false,'ISOLATION_UNSUPPORTED')
    end
    otherwise return .MUResult~new(.false,'TARGET_KIND_UNKNOWN')
  end
  if target~port==.nil then return .MUResult~new(.false,'TARGET_PORT_REQUIRED')
  targets[target~id]=target
  return .MUResult~new(.true,'BOUND')
::method submit guarded
  expose authority ledger targets
  use strict arg requestId, targetId, lease, placementRequest, workloadDigest, spec, nowEpochMs
  if \ledger~healthy then return .MUResult~new(.false,'LEDGER_UNHEALTHY')
  if lease==.nil | placementRequest==.nil then return .MUResult~new(.false,'LEASE_AND_REQUEST_REQUIRED')
  if spec==.nil then return .MUResult~new(.false,'SPEC_REQUIRED')
  if workloadDigest=='' | \ledger~validToken(workloadDigest) then return .MUResult~new(.false,'WORKLOAD_DIGEST_REQUIRED')
  if \ledger~validToken(requestId) then return .MUResult~new(.false,'REQUEST_ID_INVALID')
  target=targets[targetId]
  if target==.nil then return .MUResult~new(.false,'TARGET_NOT_BOUND')
  if lease~nodeId<>target~nodeId then return .MUResult~new(.false,'PLACEMENT_TARGET_MISMATCH')
  if lease~capabilityGeneration<>target~generation then return .MUResult~new(.false,'TARGET_GENERATION_STALE')
  if lease~jobId<>placementRequest~jobId then return .MUResult~new(.false,'PLACEMENT_JOB_MISMATCH')
  fingerprint=lease~placementId||':'||lease~ownershipEpoch||':'||lease~renewalSequence||':'||targetId||':'||workloadDigest
  if \ledger~validToken(fingerprint) then return .MUResult~new(.false,'FINGERPRINT_INVALID')
  prior=ledger~lookup(requestId)
  if prior<>.nil then do
    if prior[1]<>fingerprint then return .MUResult~new(.false,'REQUEST_ID_CONFLICT')
    return .MUResult~new(.false,'REPLAY_HELD',prior[2])
  end
  if \authority~verify(lease,placementRequest,nowEpochMs) then return .MUResult~new(.false,'PLACEMENT_NOT_AUTHORISED')
  if \ledger~write(requestId,fingerprint,'CLAIMED') then return .MUResult~new(.false,'CLAIM_PERSIST_FAILED')
  /* Once CLAIMED has been durably closed, a lost reply is not a retry grant. */
  signal on syntax name uncertain
  reply=target~port~invoke(spec)
  if reply==.nil then signal uncertain
  if \reply~hasMethod('OK') then signal uncertain
  if \reply~hasMethod('CODE') then signal uncertain
  if reply~ok then do
    if \ledger~write(requestId,fingerprint,'COMPLETED') then return .MUResult~new(.false,'RESULT_PERSIST_UNCERTAIN')
    return .MUResult~new(.true,'COMPLETED',reply~detail)
  end
  if \ledger~write(requestId,fingerprint,'FAILED') then return .MUResult~new(.false,'RESULT_PERSIST_UNCERTAIN')
  return .MUResult~new(.false,'PROVIDER_FAILED',reply~code)
  uncertain:
    ignore=ledger~write(requestId,fingerprint,'UNCERTAIN')
    return .MUResult~new(.false,'EXECUTION_UNCERTAIN')
