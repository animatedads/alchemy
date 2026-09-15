/* QueueRexxPeerMeshAdapters.cls - v0.1-dev12
 *
 * Concrete local-authority adapters for the generic QueueRexx peer mesh.
 * These adapters project local authority; they do not transfer ownership of it.
 */

::class QueueRexxPeerJobCheckHandler public
::attribute root get
::method init
  expose root store
  use strict arg rootArg
  root=rootArg~string; store=.QueueStateStore~new(root)
::method evaluate
  expose store
  use strict arg request
  subject=request["subject"]; qid=.QueueRexxPeerMeshCodec~value(subject,"qid","")
  if qid="" then return .QueueRexxPeerLocalDecision~new(.QueueRexxPeerDecisionCode~ERROR,"QID_REQUIRED")
  matches=store~findAll(qid)
  if matches~items=0 then do
    e=.directory~new; e["qid"]=qid; e["record_count"]=0
    return .QueueRexxPeerLocalDecision~new(.QueueRexxPeerDecisionCode~DENY,"JOB_NOT_FOUND","peer has no authoritative queue record for QID",e)
  end
  if matches~items<>1 then do
    e=.directory~new; e["qid"]=qid; e["record_count"]=matches~items; states=.array~new; do r over matches; states~append(r~stateName); end; e["states"]=states
    return .QueueRexxPeerLocalDecision~new(.QueueRexxPeerDecisionCode~ERROR,"JOB_STATE_AMBIGUOUS","peer has multiple authoritative records for QID",e)
  end
  r=matches[1]; e=.directory~new
  e["qid"]=r~qid; e["name"]=r~name; e["state"]=r~stateName; e["job_class"]=r~effectiveJobClass; e["priority"]=r~priority; e["runner_used"]=r~field(.QueueRecord~FIELD_RUNNER_USED,""); e["record_path"]=r~path
  return .QueueRexxPeerLocalDecision~new(.QueueRexxPeerDecisionCode~APPROVE,"JOB_RECORD_CURRENT","peer returned its one authoritative QueueRexx/QueueBash record",e)

::class QueueRexxPeerPolicyCheckHandler public
::method init
  expose inspection
  use strict arg rootArg, providerArg=.nil
  inspection=.QueuePolicyInspectionService~new(rootArg,providerArg)
::method evaluate
  expose inspection
  use strict arg request
  subject=request["subject"]; qid=.QueueRexxPeerMeshCodec~value(subject,"qid","")
  if qid="" then return .QueueRexxPeerLocalDecision~new(.QueueRexxPeerDecisionCode~ERROR,"QID_REQUIRED")
  a=inspection~inspect(qid); evidence=a~asDirectory
  if a~decision=.QueuePolicyAssessment~ALLOW then return .QueueRexxPeerLocalDecision~new(.QueueRexxPeerDecisionCode~APPROVE,a~code,a~detail,evidence)
  if a~decision=.QueuePolicyAssessment~DENY then return .QueueRexxPeerLocalDecision~new(.QueueRexxPeerDecisionCode~DENY,a~code,a~detail,evidence)
  return .QueueRexxPeerLocalDecision~new(.QueueRexxPeerDecisionCode~ERROR,a~code,a~detail,evidence)

::class QueueRexxPeerJobNodeLoadHandler public
::attribute nodeId get
::method init
  expose registry nodeId
  use strict arg registryArg, nodeArg
  registry=registryArg; nodeId=nodeArg~string
::method evaluate
  expose registry nodeId
  use strict arg request
  c=registry~capability(nodeId); o=registry~capacity(nodeId)
  if c==.nil then return .QueueRexxPeerLocalDecision~new(.QueueRexxPeerDecisionCode~DENY,"CAPABILITY_MISSING","Job-to-Node has no capability statement for peer node")
  if \c~online then return .QueueRexxPeerLocalDecision~new(.QueueRexxPeerDecisionCode~DENY,"NODE_OFFLINE","Job-to-Node capability is offline")
  if o==.nil then return .QueueRexxPeerLocalDecision~new(.QueueRexxPeerDecisionCode~DENY,"CAPACITY_MISSING","Job-to-Node has no current capacity observation")
  context=request["context"]; now=.QueueRexxPeerMeshCodec~number(context,"now_epoch_ms",0)
  e=.directory~new
  e["node_id"]=nodeId; e["capability_generation"]=c~generation; e["capacity_observation_generation"]=o~observationGeneration; e["observed_epoch_ms"]=o~observedEpochMs; e["expires_epoch_ms"]=o~expiresEpochMs
  e["free_memory_mib"]=o~freeMemoryMiB; e["free_disk_mib"]=o~freeDiskMiB; e["available_cpu_units"]=o~availableCpuUnits; e["available_micro_wlu_per_second"]=o~availableMicroWluPerSecond; e["queue_depth"]=o~queueDepth; e["active_jobs"]=o~activeJobs; e["proof_ref"]=o~proofRef
  reasons=.array~new
  if now>0 & o~isExpired(now) then reasons~append("CAPACITY_OBSERVATION_EXPIRED")
  minMem=.QueueRexxPeerMeshCodec~number(context,"minimum_free_memory_mib",0); if o~freeMemoryMiB<minMem then reasons~append("INSUFFICIENT_FREE_MEMORY")
  minDisk=.QueueRexxPeerMeshCodec~number(context,"minimum_free_disk_mib",0); if o~freeDiskMiB<minDisk then reasons~append("INSUFFICIENT_FREE_DISK")
  minCpu=.QueueRexxPeerMeshCodec~number(context,"minimum_available_cpu_units",0); if o~availableCpuUnits<minCpu then reasons~append("INSUFFICIENT_AVAILABLE_CPU")
  minWlu=.QueueRexxPeerMeshCodec~number(context,"minimum_available_micro_wlu_per_second",0); if o~availableMicroWluPerSecond<minWlu then reasons~append("INSUFFICIENT_WLU_RATE")
  maxQueue=.QueueRexxPeerMeshCodec~number(context,"maximum_queue_depth",-1); if maxQueue>=0 & o~queueDepth>maxQueue then reasons~append("QUEUE_DEPTH_LIMIT")
  maxActive=.QueueRexxPeerMeshCodec~number(context,"maximum_active_jobs",-1); if maxActive>=0 & o~activeJobs>maxActive then reasons~append("ACTIVE_JOB_LIMIT")
  e["reasons"]=reasons
  if reasons~items=0 then return .QueueRexxPeerLocalDecision~new(.QueueRexxPeerDecisionCode~APPROVE,"LOAD_ACCEPTABLE","Job-to-Node capacity satisfies peer load check",e)
  return .QueueRexxPeerLocalDecision~new(.QueueRexxPeerDecisionCode~DENY,reasons[1],"Job-to-Node capacity does not satisfy peer load check",e)

/* A local QueueRexx authority host can install its standard mesh handlers in
 * one call.  Approval remains site-specific and is deliberately not fabricated
 * here: AUTHORIZE must be bound to a real local approval authority. */
::class QueueRexxPeerStandardHandlers public
::method install class
  use strict arg service, queueRoot, jobNodeRegistry=.nil, nodeId="", policyProvider=.nil
  ignore=service~registerHandler(.QueueRexxPeerOperation~JOB_CHECK,.QueueRexxPeerJobCheckHandler~new(queueRoot))
  ignore=service~registerHandler(.QueueRexxPeerOperation~POLICY_CHECK,.QueueRexxPeerPolicyCheckHandler~new(queueRoot,policyProvider))
  if jobNodeRegistry<>.nil & nodeId<>"" then ignore=service~registerHandler(.QueueRexxPeerOperation~LOAD_CHECK,.QueueRexxPeerJobNodeLoadHandler~new(jobNodeRegistry,nodeId))
  return .true

::requires "QueueRexxPeerMesh.cls"
::requires "QueueRexxPolicy.cls"
::requires "JobNodeAllocator.cls"
