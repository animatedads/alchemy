/* QueueRexxScheduling.cls - WLU/Job-to-Node-aware scheduling surface, v0.1-dev11.
 *
 * Scheduling does not collapse priority, WLU, placement and runner choice into
 * one score.  Priority orders otherwise eligible jobs.  Admission providers
 * decide whether the external authorities required by a job are satisfied.
 */

::class QueueSchedulingStatus public
::constant SELECTED 1
::constant NO_WORK 2
::constant BLOCKED 3
::constant LOST_RACE 4
::constant START_FAILED 5
::constant STARTED 6
::constant NAME_SELECTED "selected"
::constant NAME_NO_WORK "no_work"
::constant NAME_BLOCKED "blocked"
::constant NAME_LOST_RACE "lost_race"
::constant NAME_START_FAILED "start_failed"
::constant NAME_STARTED "started"
::method name class
  use strict arg value
  select
    when value == self~SELECTED then return self~NAME_SELECTED
    when value == self~NO_WORK then return self~NAME_NO_WORK
    when value == self~BLOCKED then return self~NAME_BLOCKED
    when value == self~LOST_RACE then return self~NAME_LOST_RACE
    when value == self~START_FAILED then return self~NAME_START_FAILED
    when value == self~STARTED then return self~NAME_STARTED
    otherwise return "unknown"
  end

::class QueueSchedulingCode public
::constant ELIGIBLE "ELIGIBLE"
::constant WLU_AUTHORITY_REQUIRED "WLU_AUTHORITY_REQUIRED"
::constant WLU_RESERVATION_REQUIRED "WLU_RESERVATION_REQUIRED"
::constant WLU_PLACEMENT_REQUIRED "WLU_PLACEMENT_REQUIRED"
::constant WLU_BINDING_MISMATCH "WLU_BINDING_MISMATCH"
::constant JOB_NODE_AUTHORITY_REQUIRED "JOB_NODE_AUTHORITY_REQUIRED"
::constant JOB_NODE_REQUEST_REQUIRED "JOB_NODE_REQUEST_REQUIRED"
::constant JOB_NODE_LEASE_INVALID "JOB_NODE_LEASE_INVALID"
::constant NO_ELIGIBLE_JOB "NO_ELIGIBLE_JOB"
::constant POLICY_DENIED "POLICY_DENIED"
::constant CLAIM_FAILED "CLAIM_FAILED"
::constant ACTIVATION_FAILED "ACTIVATION_FAILED"
::constant EXECUTION_START_FAILED "EXECUTION_START_FAILED"
::constant STARTED "STARTED"

::class QueueSchedulingAdmissionVerdict public
::attribute eligible get
::attribute code get
::attribute detail get
::attribute data get
::attribute context get
::method init
  expose eligible code detail data context
  use arg eligibleArg, codeArg = "", detailArg = "", dataArg = .nil, contextArg = .nil
  eligible = eligibleArg; code = codeArg~string; detail = detailArg~string
  if dataArg == .nil then data = .Directory~new; else data = dataArg
  context = contextArg
::method yes class
  use arg codeArg = (.QueueSchedulingCode~ELIGIBLE), detailArg = "", dataArg = .nil, contextArg = .nil
  return self~new(.true, codeArg, detailArg, dataArg, contextArg)
::method no class
  use arg codeArg, detailArg = "", dataArg = .nil, contextArg = .nil
  return self~new(.false, codeArg, detailArg, dataArg, contextArg)
::method asDirectory
  expose eligible code detail data
  d = .Directory~new
  d["eligible"] = .QueueRexxUtil~jsonBoolean(eligible)
  d["code"] = code
  d["detail"] = detail
  d["data"] = data
  return d

::class QueueSchedulingAdmissionProvider public
::method assess abstract

/* The dependency-free default admits ordinary pending work only.  A managed
 * WLU job must be evaluated by an explicit WLU-aware admission provider. */
::class QueueDefaultSchedulingAdmission public subclass QueueSchedulingAdmissionProvider
::method assess
  use strict arg record
  if record~wluRequirement~managed then return .QueueSchedulingAdmissionVerdict~no(.QueueSchedulingCode~WLU_AUTHORITY_REQUIRED, "managed WLU job requires an explicit WLU scheduling admission provider")
  if record~state \= .QueueState~PENDING then return .QueueSchedulingAdmissionVerdict~no(.QueueSchedulingCode~NO_ELIGIBLE_JOB, "ordinary work must be pending")
  return .QueueSchedulingAdmissionVerdict~yes

::class QueueSchedulingDecision public
::attribute status get
::attribute record get
::attribute verdict get
::attribute considered get
::method init
  expose status record verdict considered
  use arg statusArg, recordArg = .nil, verdictArg = .nil, consideredArg = .nil
  status = statusArg + 0; record = recordArg; verdict = verdictArg
  if consideredArg == .nil then considered = .Array~new; else considered = consideredArg
::method selected
  expose status record
  return status == .QueueSchedulingStatus~SELECTED & record \= .nil
::method placementLease
  expose verdict
  if verdict == .nil then return .nil
  return verdict~context
::method asDirectory
  expose status record verdict considered
  d = .Directory~new
  d["schema"] = .QueueSchema~SCHEDULING
  d["status"] = .QueueSchedulingStatus~name(status)
  if record == .nil then do
    d["qid"] = ""; d["state"] = .QueueState~name(.QueueState~UNKNOWN); d["priority"] = .nil
  end
  else do
    d["qid"] = record~qid; d["state"] = record~stateName; d["priority"] = record~priority
  end
  if verdict \= .nil then d["admission"] = verdict~asDirectory
  d["considered"] = considered
  return d

::class QueueJobScheduler public
::attribute root get
::attribute store get
::attribute admission get
::method init
  expose root store admission
  use arg rootArg, admissionArg = .nil
  root = rootArg~string; store = .QueueStateStore~new(root)
  if admissionArg == .nil then admission = .QueueDefaultSchedulingAdmission~new; else admission = admissionArg
::method selectNext
  expose store admission
  candidates = .Array~new
  do r over store~records(.QueueState~PENDING); candidates~append(r); end
  do r over store~records(.QueueState~WAITING); candidates~append(r); end
  best = .nil; bestVerdict = .nil; considered = .Array~new
  do r over candidates
    verdict = admission~assess(r)
    c = .Directory~new
    c["qid"] = r~qid; c["state"] = r~stateName; c["priority"] = r~priority; c["admission"] = verdict~asDirectory
    considered~append(c)
    if \verdict~eligible then iterate
    if best == .nil then do; best = r; bestVerdict = verdict; iterate; end
    if r~priority > best~priority then do; best = r; bestVerdict = verdict; iterate; end
    if r~priority == best~priority & r~path < best~path then do; best = r; bestVerdict = verdict; end
  end
  if best == .nil then return .QueueSchedulingDecision~new(.QueueSchedulingStatus~NO_WORK, .nil, .QueueSchedulingAdmissionVerdict~no(.QueueSchedulingCode~NO_ELIGIBLE_JOB), considered)
  return .QueueSchedulingDecision~new(.QueueSchedulingStatus~SELECTED, best, bestVerdict, considered)

::class QueuePlacementLeaseLookup public
::method lookup abstract
/* Lease verification needs the exact placement request that was originally
 * digested by Job-to-Node.  Implementations that do not retain that request
 * fail closed by returning .nil here. */
::method lookupRequest
  use strict arg qid
  return .nil

::class QueueMemoryPlacementLeaseLookup public subclass QueuePlacementLeaseLookup
::attribute leases get
::attribute requests get
::method init
  expose leases requests
  leases = .Directory~new
  requests = .Directory~new
::method put
  expose leases requests
  use arg lease, placementRequest = .nil
  leases[lease~jobId] = lease
  if placementRequest \== .nil then requests[lease~jobId] = placementRequest
  return lease
::method lookup
  expose leases
  use strict arg qid
  if leases~hasIndex(qid~string) then return leases[qid~string]
  return .nil
::method lookupRequest
  expose requests
  use strict arg qid
  if requests~hasIndex(qid~string) then return requests[qid~string]
  return .nil

::class QueueJobNodeVerificationCode public
::constant VERIFIED "JOB_NODE_LEASE_VERIFIED"
::constant AUTHORITY_REQUIRED "JOB_NODE_AUTHORITY_REQUIRED"
::constant TIME_AUTHORITY_REQUIRED "JOB_NODE_TIME_AUTHORITY_REQUIRED"
::constant REQUEST_REQUIRED "JOB_NODE_PLACEMENT_REQUEST_REQUIRED"
::constant QID_MISMATCH "JOB_NODE_QID_MISMATCH"
::constant INVALID "JOB_NODE_LEASE_INVALID_OR_STALE"

::class QueueJobNodeVerification public
::attribute verified get
::attribute code get
::attribute detail get
::attribute data get
::method init
  expose verified code detail data
  use arg verifiedArg, codeArg, detailArg = "", dataArg = .nil
  verified = verifiedArg
  code = codeArg~string
  detail = detailArg~string
  if dataArg == .nil then data = .Directory~new; else data = dataArg
::method yes class
  use arg dataArg = .nil
  return self~new(.true, .QueueJobNodeVerificationCode~VERIFIED, "Job-to-Node v0.6 accepted the current placement lease", dataArg)
::method no class
  use arg codeArg, detailArg = "", dataArg = .nil
  return self~new(.false, codeArg, detailArg, dataArg)
::method asDirectory
  expose verified code detail data
  d = .Directory~new
  d["verified"] = .QueueRexxUtil~jsonBoolean(verified)
  d["code"] = code
  d["detail"] = detail
  d["data"] = data
  return d

/* Job-to-Node itself remains placement/ownership authority.  QueueRexx merely
 * asks the supplied allocator whether the lease is still current against the
 * exact request, registry state, ownership epoch, capacity observation,
 * policy generation and reservation evidence that Job-to-Node owns. */
::class QueueJobNodePlacementAuthority public
::attribute allocator get
::attribute timeSource get
::method init
  expose allocator timeSource
  use arg allocatorArg, timeSourceArg = .nil
  allocator = allocatorArg
  timeSource = timeSourceArg
::method verify
  expose allocator timeSource
  use strict arg record, lease, placementRequest
  if allocator == .nil then return .QueueJobNodeVerification~no(.QueueJobNodeVerificationCode~AUTHORITY_REQUIRED, "Job-to-Node allocator is not configured")
  if timeSource == .nil then return .QueueJobNodeVerification~no(.QueueJobNodeVerificationCode~TIME_AUTHORITY_REQUIRED, "Job-to-Node lease verification requires the allocator time authority")
  if placementRequest == .nil then return .QueueJobNodeVerification~no(.QueueJobNodeVerificationCode~REQUEST_REQUIRED, "exact placement request is not retained")
  if lease == .nil then return .QueueJobNodeVerification~no(.QueueJobNodeVerificationCode~INVALID, "placement lease is missing")
  if lease~jobId \= record~qid | placementRequest~jobId \= record~qid then return .QueueJobNodeVerification~no(.QueueJobNodeVerificationCode~QID_MISMATCH, "queue QID, placement request and lease do not identify the same job")
  nowEpochMs = timeSource~nowEpochMs
  d = .Directory~new
  d["placement_id"] = lease~placementId
  d["node_id"] = lease~nodeId
  d["ownership_epoch"] = lease~ownershipEpoch
  d["reservation_ref"] = lease~reservationRef
  d["allocation_policy_generation"] = lease~allocationPolicyGeneration
  d["capability_generation"] = lease~capabilityGeneration
  d["capacity_observation_generation"] = lease~capacityObservationGeneration
  d["verified_at_epoch_ms"] = nowEpochMs
  signal on syntax name jobNodeVerifyFailure
  accepted = allocator~verifyLease(lease, placementRequest, nowEpochMs)
  signal off syntax
  if \accepted then return .QueueJobNodeVerification~no(.QueueJobNodeVerificationCode~INVALID, "Job-to-Node v0.6 rejected the lease as stale, superseded or evidence-mismatched", d)
  return .QueueJobNodeVerification~yes(d)
jobNodeVerifyFailure:
  signal off syntax
  return .QueueJobNodeVerification~no(.QueueJobNodeVerificationCode~INVALID, "Job-to-Node v0.6 lease verification raised a condition; placement fails closed", d)

::class QueueFixedJobNodeTimeSource public
::attribute value get
::method init
  expose value
  use strict arg valueArg = 0
  value = valueArg + 0
::method nowEpochMs
  expose value
  return value
::method set
  expose value
  use strict arg valueArg
  value = valueArg + 0
  return value

/* A typed worker composes the already-qualified authorities.  It does not
 * bypass QueueWorkerAdmission, WLU activation, or QueueExecutionService. */
::class QueueTypedWorker public
::attribute scheduler get
::attribute workerAdmission get
::attribute executionService get
::attribute wluActivationService get
::attribute policyGate get
::method init
  expose scheduler workerAdmission executionService wluActivationService policyGate
  use arg schedulerArg, workerAdmissionArg, executionServiceArg, wluActivationArg = .nil, policyGateArg = .nil
  scheduler = schedulerArg; workerAdmission = workerAdmissionArg; executionService = executionServiceArg; wluActivationService = wluActivationArg
  if policyGateArg == .nil then policyGate = .QueueDenyAllOperationPolicyGate~new; else policyGate = policyGateArg
::method startNext
  expose scheduler workerAdmission executionService wluActivationService policyGate
  decision = scheduler~selectNext
  if \decision~selected then return .QueueSchedulingRunReceipt~new(.QueueSchedulingStatus~NO_WORK, decision, .nil, .QueueSchedulingCode~NO_ELIGIBLE_JOB)
  record = decision~record
  if record~wluRequirement~managed then do
    verdict = policyGate~assessExecution(record)
    if verdict == .nil | \verdict~isAllowed then do
      detail = ""; if verdict \= .nil then detail = verdict~code || ":" || verdict~detail
      return .QueueSchedulingRunReceipt~new(.QueueSchedulingStatus~BLOCKED, decision, .nil, .QueueSchedulingCode~POLICY_DENIED, detail)
    end
    if wluActivationService == .nil then return .QueueSchedulingRunReceipt~new(.QueueSchedulingStatus~BLOCKED, decision, .nil, .QueueSchedulingCode~WLU_AUTHORITY_REQUIRED, "WLU activation service missing")
    lease = decision~placementLease
    if lease == .nil then return .QueueSchedulingRunReceipt~new(.QueueSchedulingStatus~BLOCKED, decision, .nil, .QueueSchedulingCode~WLU_PLACEMENT_REQUIRED, "eligible WLU decision has no placement lease")
    activated = wluActivationService~activate(record~qid, lease)
    if \activated~ok then return .QueueSchedulingRunReceipt~new(.QueueSchedulingStatus~LOST_RACE, decision, .nil, .QueueSchedulingCode~ACTIVATION_FAILED, activated~detail)
  end
  else do
    claimed = workerAdmission~claim(record~qid)
    if \claimed~ok then return .QueueSchedulingRunReceipt~new(.QueueSchedulingStatus~LOST_RACE, decision, .nil, .QueueSchedulingCode~CLAIM_FAILED, claimed~code || ":" || claimed~detail)
  end
  started = executionService~start(record~qid)
  if \started~ok then return .QueueSchedulingRunReceipt~new(.QueueSchedulingStatus~START_FAILED, decision, started, .QueueSchedulingCode~EXECUTION_START_FAILED, started~code || ":" || started~detail)
  return .QueueSchedulingRunReceipt~new(.QueueSchedulingStatus~STARTED, decision, started, .QueueSchedulingCode~STARTED)

::class QueueSchedulingRunReceipt public
::attribute status get
::attribute decision get
::attribute execution get
::attribute code get
::attribute detail get
::method init
  expose status decision execution code detail
  use arg statusArg, decisionArg, executionArg = .nil, codeArg = "", detailArg = ""
  status = statusArg + 0; decision = decisionArg; execution = executionArg; code = codeArg~string; detail = detailArg~string
::method ok
  expose status
  return status == .QueueSchedulingStatus~STARTED
::method asDirectory
  expose status decision execution code detail
  d = .Directory~new
  d["schema"] = .QueueSchema~SCHEDULING
  d["status"] = .QueueSchedulingStatus~name(status)
  d["code"] = code; d["detail"] = detail
  if decision \= .nil then d["decision"] = decision~asDirectory
  if execution \= .nil then d["execution"] = execution~asDirectory
  return d

::requires "QueueRexxCore.cls"
::requires "QueueRexxOperations.cls"
::requires "QueueRexxExecution.cls"
