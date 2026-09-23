/* Managed Job-to-Node placement/start boundary for Migratable Job v0.2.5.
 *
 * This class does not replace Job-to-Node authority.  PLAN is observational.
 * ALLOCATE delegates the authoritative admission/ownership transition to
 * JobNodeAllocator. START requires that the resulting lease still verifies.
 */

::class MigratableJobPlacementContract public
::constant API "migratable.job.placement/1"
::constant RECEIPT_API "migratable.job.placement.receipt/1"

::class MigratableJobPlacementAction public
::constant PLAN "PLAN"
::constant CHECK "CHECK"
::constant ALLOCATE "ALLOCATE"
::constant START "START"
::constant ALLOCATE_START "ALLOCATE_START"
::constant RELEASE "RELEASE"

::class MigratableJobPlacementPlanEntry public
::attribute nodeId get
::attribute eligible get
::attribute reasons get
::attribute score get
::method init
  expose nodeId eligible reasons score
  use strict arg nodeArg, eligibleArg, reasonsArg=.nil, scoreArg=0
  nodeId=nodeArg~string; eligible=(eligibleArg==.true); score=scoreArg+0
  if reasonsArg==.nil then reasons=.array~new; else reasons=reasonsArg
::method reasonsText
  expose reasons
  out=""
  do i=1 to reasons~items
    if i>1 then out=out||"," 
    out=out||reasons[i]~string
  end
  return out
::method canonical
  expose nodeId eligible score
  return "node="||nodeId||";eligible="||eligible||";score="||score||";reasons="||self~reasonsText

::class MigratableJobPlacementPlan public
::attribute ok get
::attribute code get
::attribute jobId get
::attribute requestDigest get
::attribute entries get
::attribute recommendedNodeId get
::attribute generatedEpochMs get
::method init
  expose ok code jobId requestDigest entries recommendedNodeId generatedEpochMs
  use strict arg okArg, codeArg, jobArg, digestArg, entriesArg=.nil, recommendedArg="", epochArg=0
  ok=(okArg==.true); code=codeArg~string; jobId=jobArg~string; requestDigest=digestArg~string
  if entriesArg==.nil then entries=.array~new; else entries=entriesArg
  recommendedNodeId=recommendedArg~string; generatedEpochMs=.MigratableJobTime~number(epochArg)
::method entry
  expose entries
  use strict arg nodeIdArg
  do e over entries
    if e~nodeId=nodeIdArg~string then return e
  end
  return .nil

::class MigratableJobPlacementResult public
::attribute ok get
::attribute code get
::attribute action get
::attribute operationId get
::attribute jobId get
::attribute lease get
::attribute plan get
::attribute startResult get
::attribute placementHeld get
::attribute detail get
::method init
  expose ok code action operationId jobId lease plan startResult placementHeld detail
  use strict arg okArg, codeArg, actionArg, operationArg, jobArg, leaseArg=.nil, planArg=.nil, startArg=.nil, heldArg=.false, detailArg=""
  ok=(okArg==.true); code=codeArg~string; action=actionArg~string; operationId=operationArg~string; jobId=jobArg~string
  lease=leaseArg; plan=planArg; startResult=startArg; placementHeld=(heldArg==.true); detail=detailArg~string

::class MigratableJobPlacementAuditReceipt public
::attribute operationId get
::attribute action get
::attribute code get
::attribute jobId get
::attribute requestDigest get
::attribute placementId get
::attribute nodeId get
::attribute ownershipEpoch get
::attribute startId get
::attribute executionRef get
::attribute placementHeld get
::attribute epochMs get
::attribute detail get
::method init
  expose operationId action code jobId requestDigest placementId nodeId ownershipEpoch startId executionRef placementHeld epochMs detail
  use strict arg operationArg, actionArg, codeArg, jobArg, digestArg, placementArg="", nodeArg="", ownershipArg=0, startArg="", executionArg="", heldArg=.false, epochArg=0, detailArg=""
  operationId=operationArg~string; action=actionArg~string; code=codeArg~string; jobId=jobArg~string; requestDigest=digestArg~string
  placementId=placementArg~string; nodeId=nodeArg~string; ownershipEpoch=ownershipArg+0; startId=startArg~string; executionRef=executionArg~string
  placementHeld=(heldArg==.true); epochMs=.MigratableJobTime~number(epochArg); detail=detailArg~string
::method canonical
  expose operationId action code jobId requestDigest placementId nodeId ownershipEpoch startId executionRef placementHeld epochMs detail
  return "operation="||operationId||";action="||action||";code="||code||";job="||jobId||";request="||requestDigest||";placement="||placementId||";node="||nodeId||";ownerEpoch="||ownershipEpoch||";start="||startId||";execution="||executionRef||";held="||placementHeld||";at="||epochMs||";detail="||detail

/* Audit is evidence, never placement authority.  Corrupt evidence fails closed
 * for reads but does not manufacture or revoke Job-to-Node ownership. */
::class MigratableJobPlacementAuditStore public
::method init
  expose path digestProvider
  use strict arg pathArg, digestArg=.nil
  path=pathArg~string
  if path="" then raise syntax 88.900 array("placement audit path required")
  if digestArg==.nil then digestProvider=.JobNodeDigestProvider~new; else digestProvider=digestArg
::method append guarded
  expose path digestProvider
  use strict arg receipt
  if receipt==.nil then return .false
  material=receipt~canonical
  digest=digestProvider~digest(material)
  values=.array~of(receipt~operationId,receipt~action,receipt~code,receipt~jobId,receipt~requestDigest,receipt~placementId,receipt~nodeId,receipt~ownershipEpoch,receipt~startId,receipt~executionRef,receipt~placementHeld,receipt~epochMs,receipt~detail)
  out="MJPLACE1"
  do v over values; out=out||"|"||c2x(v~string); end
  out=out||"|"||digest
  s=.stream~new(path); opened=s~open("write append")
  if opened<>"READY:" then return .false
  s~lineout(out); s~close
  return .true
::method verify guarded
  expose path digestProvider
  if stream(path,"c","query exists")="" then return .true
  s=.stream~new(path); opened=s~open("read")
  if opened<>"READY:" then return .false
  do while s~lines>0
    line=s~linein
    p=self~split(line)
    if p~items<>15 | p[1]<>"MJPLACE1" then do; s~close; return .false; end
    vals=.array~new
    do i=2 to 14
      h=p[i]~string
      if h<>"" then do
        if h~length//2<>0 | verify(h,"0123456789ABCDEFabcdef")<>0 then do; s~close; return .false; end
      end
      vals~append(x2c(h))
    end
    if \datatype(vals[8],"N") | \datatype(vals[12],"N") then do; s~close; return .false; end
    r=.MigratableJobPlacementAuditReceipt~new(vals[1],vals[2],vals[3],vals[4],vals[5],vals[6],vals[7],vals[8]+0,vals[9],vals[10],vals[11]=1,.MigratableJobTime~number(vals[12]),vals[13])
    if digestProvider~digest(r~canonical)<>p[15] then do; s~close; return .false; end
  end
  s~close
  return .true
::method split private
  use strict arg text
  a=.array~new; rest=text~string
  do forever
    pos=rest~pos("|")
    if pos=0 then do; a~append(rest); leave; end
    a~append(rest~left(pos-1)); rest=rest~substr(pos+1)
  end
  return a

/* Start execution only after placement has been verified.  A remote executor
 * can implement this seam using Queue Fabric; the local executor below is the
 * reference implementation. */
::class MigratableJobPlacedStartExecutor public
::method start abstract

::class MigratableJobLocalPlacedStartExecutor subclass MigratableJobPlacedStartExecutor public
::method init
  expose localNodeId starter
  use strict arg localNodeArg, starterArg
  localNodeId=localNodeArg~string; starter=starterArg
  if localNodeId="" | starter==.nil then raise syntax 88.900 array("local node id and starter required")
::method start
  expose localNodeId starter
  use strict arg lease, startRequest, nowEpochMs
  if lease==.nil then return .MigratableJobStartResult~failure(startRequest,"PLACEMENT_LEASE_REQUIRED")
  if lease~nodeId<>localNodeId then return .MigratableJobStartResult~failure(startRequest,"PLACEMENT_NOT_LOCAL","allocated node="||lease~nodeId||" local node="||localNodeId)
  return starter~start(startRequest)

/* Managed surface.  The application supplies the exact placement request via
 * its MigratableJobDefinition; therefore the tool cannot silently place a job
 * under different requirements than the standard starter will execute. */
::class MigratableJobManagedPlacementTool public
::method init
  expose application allocator registry eligibilityPolicy placementPolicy digestProvider startExecutor auditStore
  use strict arg applicationArg, allocatorArg, registryArg, eligibilityArg, placementArg=.nil, startExecutorArg=.nil, auditArg=.nil, digestArg=.nil
  application=applicationArg; allocator=allocatorArg; registry=registryArg; eligibilityPolicy=eligibilityArg
  if placementArg==.nil then placementPolicy=.JobNodePlacementPolicy~new; else placementPolicy=placementArg
  startExecutor=startExecutorArg; auditStore=auditArg
  if digestArg==.nil then digestProvider=.JobNodeDigestProvider~new; else digestProvider=digestArg
  if application==.nil | allocator==.nil | registry==.nil | eligibilityPolicy==.nil then raise syntax 88.900 array("application, allocator, registry and eligibility policy required")
::method plan guarded
  expose application registry eligibilityPolicy placementPolicy digestProvider
  use strict arg startRequest, nowEpochMs=0, operationId=""
  binding=self~binding(startRequest)
  if binding[1]<>"OK" then return .MigratableJobPlacementResult~new(.false,binding[1],.MigratableJobPlacementAction~PLAN,operationId,startRequest~jobId,.nil,.nil,.nil,.false,binding[2])
  definition=binding[3]; placementRequest=definition~placementRequest
  digest=digestProvider~digest(placementRequest~canonical)
  entries=.array~new; bestNode=""; bestScore=0; haveBest=.false
  ids=registry~nodeIds; ids~sort
  do nodeId over ids
    cap=registry~capability(nodeId); capacity=registry~capacity(nodeId)
    a=eligibilityPolicy~assess(placementRequest,cap,capacity,nowEpochMs)
    score=0
    if a~eligible then do
      score=placementPolicy~score(placementRequest,a)
      if \haveBest | score>bestScore | (score=bestScore & nodeId<bestNode) then do
        bestNode=nodeId; bestScore=score; haveBest=.true
      end
    end
    reasons=.array~new; do r over a~reasons; reasons~append(r); end
    entries~append(.MigratableJobPlacementPlanEntry~new(nodeId,a~eligible,reasons,score))
  end
  code="PLAN_READY"; ok=.true
  if \haveBest then do; code="NO_ELIGIBLE_NODE"; ok=.false; end
  plan=.MigratableJobPlacementPlan~new(ok,code,placementRequest~jobId,digest,entries,bestNode,nowEpochMs)
  result=.MigratableJobPlacementResult~new(ok,code,.MigratableJobPlacementAction~PLAN,operationId,placementRequest~jobId,.nil,plan,.nil,.false,"plan is advisory; admission and ownership are not committed")
  ignore=self~audit(result,placementRequest,startRequest,nowEpochMs)
  return result
::method check guarded
  expose application allocator
  use strict arg startRequest, lease, nowEpochMs=0, operationId=""
  binding=self~binding(startRequest)
  if binding[1]<>"OK" then return .MigratableJobPlacementResult~new(.false,binding[1],.MigratableJobPlacementAction~CHECK,operationId,startRequest~jobId,lease,.nil,.nil,.false,binding[2])
  p=binding[3]~placementRequest
  ok=allocator~verifyLease(lease,p,nowEpochMs)
  if ok then code="PLACEMENT_CURRENT"; else code="PLACEMENT_INVALID"
  result=.MigratableJobPlacementResult~new(ok,code,.MigratableJobPlacementAction~CHECK,operationId,p~jobId,lease,.nil,.nil,ok,"verified against Job-to-Node authority")
  ignore=self~audit(result,p,startRequest,nowEpochMs)
  return result
::method allocate guarded
  expose application allocator digestProvider
  use strict arg startRequest, nowEpochMs=0, leaseDurationMs=30000, operationId=""
  binding=self~binding(startRequest)
  if binding[1]<>"OK" then return .MigratableJobPlacementResult~new(.false,binding[1],.MigratableJobPlacementAction~ALLOCATE,operationId,startRequest~jobId,.nil,.nil,.nil,.false,binding[2])
  p=binding[3]~placementRequest
  d=allocator~allocate(p,nowEpochMs,leaseDurationMs)
  if d==.nil then result=.MigratableJobPlacementResult~new(.false,"ALLOCATION_RESULT_MISSING",.MigratableJobPlacementAction~ALLOCATE,operationId,p~jobId)
  else if d~placed then result=.MigratableJobPlacementResult~new(.true,"PLACED",.MigratableJobPlacementAction~ALLOCATE,operationId,p~jobId,d~lease,.nil,.nil,.true,"Job-to-Node committed admission and ownership")
  else do
    /* If a retry sees the same still-current placement, surface it as an
     * idempotent replay only when the exact requirement still verifies. */
    if d~code="ACTIVE_PLACEMENT_EXISTS" & d~lease<>.nil then do
      if allocator~verifyLease(d~lease,p,nowEpochMs) then result=.MigratableJobPlacementResult~new(.true,"PLACED_REPLAY",.MigratableJobPlacementAction~ALLOCATE,operationId,p~jobId,d~lease,.nil,.nil,.true,"existing current placement satisfies the same request")
      else result=.MigratableJobPlacementResult~new(.false,d~code,.MigratableJobPlacementAction~ALLOCATE,operationId,p~jobId,d~lease,.nil,.nil,.true,"active placement exists but does not verify for this request")
    end
    else result=.MigratableJobPlacementResult~new(.false,d~code,.MigratableJobPlacementAction~ALLOCATE,operationId,p~jobId,d~lease,.nil,.nil,d~lease<>.nil,"Job-to-Node allocation denied")
  end
  ignore=self~audit(result,p,startRequest,nowEpochMs)
  return result
::method start guarded
  expose application allocator startExecutor
  use strict arg startRequest, lease, nowEpochMs=0, operationId=""
  binding=self~binding(startRequest)
  if binding[1]<>"OK" then return .MigratableJobPlacementResult~new(.false,binding[1],.MigratableJobPlacementAction~START,operationId,startRequest~jobId,lease,.nil,.nil,.false,binding[2])
  p=binding[3]~placementRequest
  if startRequest~mode<>.MigratableJobStartMode~NEW then do
    result=.MigratableJobPlacementResult~new(.false,"MANAGED_INITIAL_START_REQUIRES_NEW",.MigratableJobPlacementAction~START,operationId,p~jobId,lease,.nil,.nil,lease<>.nil,"RECOVER/HANDOFF use their own authority paths")
    ignore=self~audit(result,p,startRequest,nowEpochMs); return result
  end
  if lease==.nil then do
    result=.MigratableJobPlacementResult~new(.false,"PLACEMENT_LEASE_REQUIRED",.MigratableJobPlacementAction~START,operationId,p~jobId)
    ignore=self~audit(result,p,startRequest,nowEpochMs); return result
  end
  if \allocator~verifyLease(lease,p,nowEpochMs) then do
    result=.MigratableJobPlacementResult~new(.false,"PLACEMENT_INVALID",.MigratableJobPlacementAction~START,operationId,p~jobId,lease,.nil,.nil,.false,"start denied before runtime entry")
    ignore=self~audit(result,p,startRequest,nowEpochMs); return result
  end
  if startExecutor==.nil then do
    result=.MigratableJobPlacementResult~new(.false,"START_EXECUTOR_REQUIRED",.MigratableJobPlacementAction~START,operationId,p~jobId,lease,.nil,.nil,.true,"placement is held; dispatch/start executor not configured")
    ignore=self~audit(result,p,startRequest,nowEpochMs); return result
  end
  sr=startExecutor~start(lease,startRequest,nowEpochMs)
  if sr==.nil then result=.MigratableJobPlacementResult~new(.false,"START_RESULT_MISSING",.MigratableJobPlacementAction~START,operationId,p~jobId,lease,.nil,.nil,.true,"placement held because execution outcome is ambiguous")
  else if sr~ok & sr~state=.MigratableJobStartState~RUNNING then result=.MigratableJobPlacementResult~new(.true,"RUNNING",.MigratableJobPlacementAction~START,operationId,p~jobId,lease,.nil,sr,.true,"standard starter confirmed running")
  else if sr~ok & sr~state=.MigratableJobStartState~PENDING then result=.MigratableJobPlacementResult~new(.true,"START_PENDING_PLACEMENT_HELD",.MigratableJobPlacementAction~START,operationId,p~jobId,lease,.nil,sr,.true,"remote start dispatched; placement retained while execution acknowledgement is pending")
  else do
    code="START_FAILED_PLACEMENT_HELD"
    detail="placement retained; start="||sr~code||":"||sr~detail
    result=.MigratableJobPlacementResult~new(.false,code,.MigratableJobPlacementAction~START,operationId,p~jobId,lease,.nil,sr,.true,detail)
  end
  ignore=self~audit(result,p,startRequest,nowEpochMs)
  return result
::method allocateStart guarded
  use strict arg startRequest, nowEpochMs=0, leaseDurationMs=30000, operationId=""
  allocated=self~allocate(startRequest,nowEpochMs,leaseDurationMs,operationId||":allocate")
  if \allocated~ok then return allocated
  started=self~start(startRequest,allocated~lease,nowEpochMs,operationId||":start")
  if started~ok then do
    if started~startResult<>.nil then if started~startResult~state=.MigratableJobStartState~PENDING then return .MigratableJobPlacementResult~new(.true,"START_PENDING_PLACEMENT_HELD",.MigratableJobPlacementAction~ALLOCATE_START,operationId,startRequest~jobId,allocated~lease,allocated~plan,started~startResult,.true,"placement committed; remote start acknowledgement pending")
    return .MigratableJobPlacementResult~new(.true,"RUNNING",.MigratableJobPlacementAction~ALLOCATE_START,operationId,startRequest~jobId,allocated~lease,allocated~plan,started~startResult,.true,"placement committed and starter confirmed running")
  end
  return .MigratableJobPlacementResult~new(.false,"START_FAILED_PLACEMENT_HELD",.MigratableJobPlacementAction~ALLOCATE_START,operationId,startRequest~jobId,allocated~lease,allocated~plan,started~startResult,.true,started~detail)
::method release guarded
  expose application allocator
  use strict arg startRequest, lease, nowEpochMs=0, operationId="", reason="operator-request"
  binding=self~binding(startRequest)
  if binding[1]<>"OK" then return .MigratableJobPlacementResult~new(.false,binding[1],.MigratableJobPlacementAction~RELEASE,operationId,startRequest~jobId,lease,.nil,.nil,.false,binding[2])
  p=binding[3]~placementRequest
  if lease==.nil then result=.MigratableJobPlacementResult~new(.false,"PLACEMENT_LEASE_REQUIRED",.MigratableJobPlacementAction~RELEASE,operationId,p~jobId)
  else if lease~jobId<>p~jobId then result=.MigratableJobPlacementResult~new(.false,"PLACEMENT_JOB_MISMATCH",.MigratableJobPlacementAction~RELEASE,operationId,p~jobId,lease,.nil,.nil,.true,"release denied")
  else do
    ok=allocator~releasePlacement(lease)
    if ok then result=.MigratableJobPlacementResult~new(.true,"RELEASED",.MigratableJobPlacementAction~RELEASE,operationId,p~jobId,lease,.nil,.nil,.false,reason)
    else result=.MigratableJobPlacementResult~new(.false,"RELEASE_FAILED",.MigratableJobPlacementAction~RELEASE,operationId,p~jobId,lease,.nil,.nil,.true,reason)
  end
  ignore=self~audit(result,p,startRequest,nowEpochMs)
  return result
::method binding private
  expose application
  use strict arg startRequest
  out=.array~new
  if startRequest==.nil then do; out~append("START_REQUEST_REQUIRED"); out~append(""); out~append(.nil); return out; end
  if startRequest~mode<>.MigratableJobStartMode~NEW then do; out~append("MANAGED_INITIAL_PLACEMENT_REQUIRES_NEW"); out~append("RECOVER/HANDOFF retain their existing migration authority paths"); out~append(.nil); return out; end
  definition=application~definition(startRequest)
  if definition==.nil then do; out~append("DEFINITION_MISSING"); out~append(""); out~append(.nil); return out; end
  if definition~jobId<>startRequest~jobId then do; out~append("JOB_BINDING_MISMATCH"); out~append(""); out~append(.nil); return out; end
  if definition~definitionRef<>startRequest~definitionRef then do; out~append("DEFINITION_BINDING_MISMATCH"); out~append(""); out~append(.nil); return out; end
  if startRequest~partitionId<>"" & definition~partitionId<>startRequest~partitionId then do; out~append("PARTITION_BINDING_MISMATCH"); out~append(""); out~append(.nil); return out; end
  if definition~placementRequest==.nil then do; out~append("PLACEMENT_REQUEST_MISSING"); out~append(""); out~append(.nil); return out; end
  if definition~placementRequest~jobId<>definition~jobId then do; out~append("PLACEMENT_REQUEST_JOB_MISMATCH"); out~append(""); out~append(.nil); return out; end
  out~append("OK"); out~append(""); out~append(definition); return out
::method audit private
  expose auditStore digestProvider
  use strict arg result, placementRequest, startRequest, nowEpochMs
  if auditStore==.nil | result==.nil | placementRequest==.nil then return .true
  digest=digestProvider~digest(placementRequest~canonical)
  placementId=""; nodeId=""; ownership=0
  if result~lease<>.nil then do; placementId=result~lease~placementId; nodeId=result~lease~nodeId; ownership=result~lease~ownershipEpoch; end
  startId=""; execution=""
  if startRequest<>.nil then startId=startRequest~startId
  if result~startResult<>.nil then execution=result~startResult~executionRef
  receipt=.MigratableJobPlacementAuditReceipt~new(result~operationId,result~action,result~code,result~jobId,digest,placementId,nodeId,ownership,startId,execution,result~placementHeld,nowEpochMs,result~detail)
  return auditStore~append(receipt)

::requires "MigratableJobStarter.cls"
