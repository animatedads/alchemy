/* QueueRexxMigratableNetwork.cls - v0.1-dev12
 *
 * Remote Job-to-Node authority integration for Migratable Job v0.2.4.
 * PLAN is obtained from QueueRexx's central authority.  All authoritative
 * managed-placement actions retain the upstream v0.2.4 implementation with
 * QueueRexxJobNodeNetworkAllocatorProxy adapts the exact upstream
 * JobNodeNetworkAllocatorClient to the allocator-shaped methods consumed by
 * MigratableJobManagedPlacementTool.  No placement authority is local.
 */

::class QueueRexxRemoteManagedPlacementTool public
::attribute application get
::attribute networkClient get
::attribute delegate get

::method init
  expose application networkClient delegate digestProvider auditStore
  use strict arg applicationArg, networkClientArg, startExecutorArg=.nil, auditArg=.nil, digestArg=.nil
  if applicationArg==.nil | networkClientArg==.nil then raise syntax 88.900 array("application and JobNodeNetworkAllocatorClient required")
  application=applicationArg; networkClient=networkClientArg; auditStore=auditArg
  if digestArg==.nil then digestProvider=.JobNodeDigestProvider~new; else digestProvider=digestArg
  /* The upstream tool's mutation/start methods do not consult registry or
   * eligibility; those collaborators are PLAN-only.  PLAN is overridden here
   * and executed by the authority server, so empty local objects cannot become
   * placement evidence. */
  unusedRegistry=.NodeCapabilityRegistry~new
  unusedEligibility=.JobNodeEligibilityPolicy~new
  delegate=.MigratableJobManagedPlacementTool~new(application,networkClient,unusedRegistry,unusedEligibility,.nil,startExecutorArg,auditArg,digestProvider)

::method plan guarded
  expose application networkClient auditStore digestProvider
  use strict arg startRequest, nowEpochMs=0, operationId=""
  binding=self~binding(startRequest)
  if binding[1]<>"OK" then return .MigratableJobPlacementResult~new(.false,binding[1],.MigratableJobPlacementAction~PLAN,operationId,startRequest~jobId,.nil,.nil,.nil,.false,binding[2])
  definition=binding[3]; p=definition~placementRequest
  rr=networkClient~plan(p,nowEpochMs)
  if rr==.nil | \rr~ok then do
    code="NETWORK_PLAN_FAILED"; detail=""
    if rr<>.nil then do; code="NETWORK_"||rr~code; detail=rr~detail; end
    return .MigratableJobPlacementResult~new(.false,code,.MigratableJobPlacementAction~PLAN,operationId,p~jobId,.nil,.nil,.nil,.false,detail)
  end
  response=rr~value
  pd=response["data"]
  entries=.array~new; recommended=""; requestDigest=""; selectedScore=0
  if pd<>.nil then do
    if pd["selectedNodeId"]<>.nil then recommended=pd["selectedNodeId"]~string
    if pd["selectedScore"]<>.nil then selectedScore=pd["selectedScore"]+0
    rows=pd["assessments"]
    if rows<>.nil then do row over rows
      reasons=row["reasons"]; if reasons==.nil then reasons=.array~new
      nodeId=""; if row["nodeId"]<>.nil then nodeId=row["nodeId"]~string
      eligible=.false; if row["eligible"]<>.nil then eligible=row["eligible"]
      score=0; if nodeId=recommended then score=selectedScore
      entries~append(.MigratableJobPlacementPlanEntry~new(nodeId,eligible,reasons,score))
    end
  end
  if response["requestDigest"]<>.nil then requestDigest=response["requestDigest"]~string
  if requestDigest="" then requestDigest=digestProvider~digest(p~canonical)
  ok=response["status"]="OK"
  code="NETWORK_PLAN_INVALID"; if response["code"]<>.nil then code=response["code"]~string
  plan=.MigratableJobPlacementPlan~new(ok,code,p~jobId,requestDigest,entries,recommended,nowEpochMs)
  result=.MigratableJobPlacementResult~new(ok,code,.MigratableJobPlacementAction~PLAN,operationId,p~jobId,.nil,plan,.nil,.false,"plan supplied by QueueRexx Job-to-Node authority; no client-side placement authority")
  ignore=self~auditPlan(result,p,startRequest,nowEpochMs)
  return result

::method check
  expose delegate
  forward to (delegate)
::method allocate
  expose delegate
  forward to (delegate)
::method start
  expose delegate
  forward to (delegate)
::method allocateStart
  expose delegate
  forward to (delegate)
::method release
  expose delegate
  forward to (delegate)

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

::method auditPlan private
  expose auditStore digestProvider
  use strict arg result, placementRequest, startRequest, nowEpochMs
  if auditStore==.nil then return .true
  digest=digestProvider~digest(placementRequest~canonical)
  startId=""; if startRequest<>.nil then startId=startRequest~startId
  receipt=.MigratableJobPlacementAuditReceipt~new(result~operationId,result~action,result~code,result~jobId,digest,"","",0,startId,"",.false,nowEpochMs,result~detail)
  return auditStore~append(receipt)

::requires "QueueRexxAuthority.cls"
::requires "MigratableJobManagedPlacement.cls"
