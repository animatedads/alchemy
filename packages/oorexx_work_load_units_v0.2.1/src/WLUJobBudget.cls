/*
 * WLUJobBudget.cls
 *
 * Logical-job budgeting and staged execution strategy for WorkLoadUnits.
 *
 * A job is a business obligation (for example one chat session), not one
 * backend invocation.  A job may move through cheap/native, local-model and
 * remote-model stages while retaining one authenticated WLU budget.
 *
 * This layer deliberately does not decide WHY an application escalates.  The
 * application reports that a stage needs a fallback; WLU reports which
 * declared fallback stages remain admissible under the parent budget and the
 * current enterprise capacity state.
 */

::options digits 30

::class WLUJobBuild public
::constant VERSION "0.1"
::constant API_VERSION "work.load.units.job/0.1"

::class WLUJobCoverage public
::constant FULL "FULL_STRATEGY"
::constant PARTIAL "PARTIAL_STRATEGY"

/* A stage is one possible execution implementation in a logical job.
 * handoff* is explicit entry work such as replaying history, warming state,
 * rehydrating context, or converting a representation for a new executor.
 */
::class WLUJobStage public
::attribute stageId get
::attribute scope get
::attribute workExpectedMicroWlu get
::attribute workCeilingMicroWlu get
::attribute handoffExpectedMicroWlu get
::attribute handoffCeilingMicroWlu get
::attribute targetSeconds get
::attribute requestedRateMicroWluPerSecond get

::method init
  expose stageId scope workExpectedMicroWlu workCeilingMicroWlu handoffExpectedMicroWlu handoffCeilingMicroWlu targetSeconds requestedRateMicroWluPerSecond
  use strict arg stageId, scope, workExpectedMicroWlu, workCeilingMicroWlu = .nil, handoffExpectedMicroWlu = 0, handoffCeilingMicroWlu = .nil, targetSeconds = 0, requestedRateMicroWluPerSecond = .nil
  stageId = stageId~string~strip
  scope = scope~string~strip
  if stageId = "" then raise syntax 88.900 array("WLU job stage id must not be empty")
  if scope = "" then raise syntax 88.900 array("WLU job stage scope must not be empty")
  ignore = .WLUUnits~assertMicro(workExpectedMicroWlu)
  if workExpectedMicroWlu <= 0 then raise syntax 88.900 array("WLU job stage expected work must be positive")
  if workCeilingMicroWlu == .nil then workCeilingMicroWlu = workExpectedMicroWlu
  ignore = .WLUUnits~assertMicro(workCeilingMicroWlu)
  if workCeilingMicroWlu < workExpectedMicroWlu then raise syntax 88.900 array("WLU job stage work ceiling must be >= expected work")
  ignore = .WLUUnits~assertMicro(handoffExpectedMicroWlu)
  if handoffCeilingMicroWlu == .nil then handoffCeilingMicroWlu = handoffExpectedMicroWlu
  ignore = .WLUUnits~assertMicro(handoffCeilingMicroWlu)
  if handoffCeilingMicroWlu < handoffExpectedMicroWlu then raise syntax 88.900 array("WLU job stage handoff ceiling must be >= expected handoff work")
  if \datatype(targetSeconds, "W") | targetSeconds < 0 then raise syntax 88.900 array("WLU job stage targetSeconds must be a non-negative whole number")
  if requestedRateMicroWluPerSecond \== .nil then ignore = .WLUUnits~assertMicro(requestedRateMicroWluPerSecond)

::method expectedMicroWlu
  expose workExpectedMicroWlu handoffExpectedMicroWlu
  return workExpectedMicroWlu + handoffExpectedMicroWlu

::method ceilingMicroWlu
  expose workCeilingMicroWlu handoffCeilingMicroWlu
  return workCeilingMicroWlu + handoffCeilingMicroWlu

::method demand
  expose targetSeconds requestedRateMicroWluPerSecond
  return .WLUWorkDemand~new(self~expectedMicroWlu, self~ceilingMicroWlu, targetSeconds, requestedRateMicroWluPerSecond)

/* A sealed fallback graph.  Edges mean "if FROM cannot/should not continue,
 * TO is a declared next implementation".  Branches are alternatives, so
 * strategyCeilingFrom() takes the maximum successor path rather than summing
 * mutually exclusive branches.
 */
::class WLUJobPlan public
::attribute planId get
::attribute version get
::attribute startStageId get
::attribute sealed get

::method init
  expose planId version startStageId sealed stages fallbacks
  use strict arg planId, version = "1"
  planId = planId~string~strip
  version = version~string~strip
  if planId = "" | version = "" then raise syntax 88.900 array("WLU job plan id/version must not be empty")
  startStageId = ""
  sealed = .false
  stages = .table~new
  fallbacks = .table~new

::method addStage
  expose sealed stages startStageId fallbacks
  use strict arg stage, start = .false
  if sealed then raise syntax 88.900 array("WLU job plan is sealed")
  if stage == .nil | \stage~isA(.WLUJobStage) then raise syntax 88.900 array("WLU job plan accepts WLUJobStage objects")
  if stages~hasIndex(stage~stageId) then raise syntax 88.900 array("Duplicate WLU job stage: " || stage~stageId)
  stages[stage~stageId] = stage
  fallbacks[stage~stageId] = .array~new
  if start | startStageId = "" then startStageId = stage~stageId
  return stage

::method setStartStage
  expose sealed stages startStageId
  use strict arg stageId
  if sealed then raise syntax 88.900 array("WLU job plan is sealed")
  stageId = stageId~string~strip
  if \stages~hasIndex(stageId) then raise syntax 88.900 array("Unknown WLU job start stage: " || stageId)
  startStageId = stageId
  return .true

::method addFallback
  expose sealed stages fallbacks
  use strict arg fromStageId, toStageId
  if sealed then raise syntax 88.900 array("WLU job plan is sealed")
  fromStageId = fromStageId~string~strip
  toStageId = toStageId~string~strip
  if \stages~hasIndex(fromStageId) then raise syntax 88.900 array("Unknown WLU fallback source stage: " || fromStageId)
  if \stages~hasIndex(toStageId) then raise syntax 88.900 array("Unknown WLU fallback target stage: " || toStageId)
  if fromStageId = toStageId then raise syntax 88.900 array("WLU job stage cannot fall back to itself")
  targets = fallbacks[fromStageId]
  do existing over targets
    if existing = toStageId then return .true
  end
  targets~append(toStageId)
  return .true

::method stage
  expose stages
  use strict arg stageId
  stage = stages[stageId~string]
  if stage == .nil then return .WLUResult~failure("WLU_JOB_STAGE_NOT_FOUND", stageId~string)
  return .WLUResult~success(stage)

::method fallbacksFor
  expose fallbacks stages
  use strict arg stageId
  stageId = stageId~string
  if \stages~hasIndex(stageId) then return .WLUResult~failure("WLU_JOB_STAGE_NOT_FOUND", stageId)
  copy = .array~new
  do id over fallbacks[stageId]
    copy~append(id)
  end
  return .WLUResult~success(copy)

::method seal
  expose sealed startStageId stages
  if startStageId = "" | stages~items = 0 then return .WLUResult~failure("WLU_JOB_PLAN_EMPTY", "job plan requires a start stage")
  visiting = .table~new
  visited = .table~new
  supplier = stages~supplier
  do while supplier~available
    stageId = supplier~index
    cycle = self~detectCycle(stageId, visiting, visited)
    if cycle \= "" then return .WLUResult~failure("WLU_JOB_PLAN_CYCLE", "fallback graph contains a cycle at " || cycle)
    supplier~next
  end
  sealed = .true
  return .WLUResult~success(self)

::method strategyCeilingMicroWlu
  expose sealed startStageId
  if \sealed then raise syntax 88.900 array("WLU job plan must be sealed before strategy ceiling is requested")
  return self~strategyCeilingFrom(startStageId)

::method strategyCeilingFrom
  expose sealed stages fallbacks
  use strict arg stageId
  if \sealed then raise syntax 88.900 array("WLU job plan must be sealed before strategy ceiling is requested")
  stage = stages[stageId~string]
  if stage == .nil then raise syntax 88.900 array("Unknown WLU job stage: " || stageId~string)
  successorMax = 0
  do nextId over fallbacks[stageId~string]
    candidate = self~strategyCeilingFrom(nextId)
    if candidate > successorMax then successorMax = candidate
  end
  return stage~ceilingMicroWlu + successorMax

::method detectCycle private
  expose stages fallbacks
  use strict arg stageId, visiting, visited
  if visited~hasIndex(stageId) then return ""
  if visiting~hasIndex(stageId) then return stageId
  visiting[stageId] = .true
  do nextId over fallbacks[stageId]
    cycle = self~detectCycle(nextId, visiting, visited)
    if cycle \= "" then return cycle
  end
  visiting~remove(stageId)
  visited[stageId] = .true
  return ""

/* One logical business job/session and its hard WLU envelope. */
::class WLUJobRequest public
::attribute jobKey get
::attribute sessionRef get
::attribute identity get
::attribute businessScope get
::attribute plan get
::attribute expectedMicroWlu get
::attribute budgetMicroWlu get

::method init
  expose jobKey sessionRef identity businessScope plan expectedMicroWlu budgetMicroWlu
  use strict arg jobKey, sessionRef, identity, businessScope, plan, expectedMicroWlu, budgetMicroWlu
  jobKey = jobKey~string~strip
  sessionRef = sessionRef~string~strip
  identity = identity~string~strip
  businessScope = businessScope~string~strip
  if jobKey = "" | identity = "" | businessScope = "" then raise syntax 88.900 array("WLU job key, identity and business scope must not be empty")
  if plan == .nil | \plan~isA(.WLUJobPlan) | \plan~sealed then raise syntax 88.900 array("WLU job request requires a sealed WLUJobPlan")
  ignore = .WLUUnits~assertMicro(expectedMicroWlu)
  ignore = .WLUUnits~assertMicro(budgetMicroWlu)
  if expectedMicroWlu <= 0 then raise syntax 88.900 array("WLU job expected work must be positive")
  if budgetMicroWlu < expectedMicroWlu then raise syntax 88.900 array("WLU job budget must be >= expected work")
  start = plan~stage(plan~startStageId)~value
  if budgetMicroWlu < start~ceilingMicroWlu then raise syntax 88.900 array("WLU job budget cannot admit its start stage ceiling")

::method coverage
  expose plan budgetMicroWlu
  if budgetMicroWlu >= plan~strategyCeilingMicroWlu then return .WLUJobCoverage~FULL
  return .WLUJobCoverage~PARTIAL

/* Authenticated snapshot of a logical job budget. */
::class WLUJobLease public
::attribute jobId get
::attribute jobKey get
::attribute sessionRef get
::attribute identity get
::attribute businessScope get
::attribute planId get
::attribute planVersion get
::attribute expectedMicroWlu get
::attribute budgetMicroWlu get
::attribute spentMicroWlu get
::attribute committedMicroWlu get
::attribute strategyCeilingMicroWlu get
::attribute coverage get
::attribute revision get
::attribute proof get

::method init
  expose jobId jobKey sessionRef identity businessScope planId planVersion expectedMicroWlu budgetMicroWlu spentMicroWlu committedMicroWlu strategyCeilingMicroWlu coverage revision proof
  use strict arg jobId, jobKey, sessionRef, identity, businessScope, planId, planVersion, expectedMicroWlu, budgetMicroWlu, spentMicroWlu, committedMicroWlu, strategyCeilingMicroWlu, coverage, revision, proof

::method remainingMicroWlu
  expose budgetMicroWlu spentMicroWlu committedMicroWlu
  return budgetMicroWlu - spentMicroWlu - committedMicroWlu

::method canonicalText
  expose jobId jobKey sessionRef identity businessScope planId planVersion expectedMicroWlu budgetMicroWlu spentMicroWlu committedMicroWlu strategyCeilingMicroWlu coverage revision
  text = "wlu-job-lease-v1" || "0a"x
  text ||= self~field("job-id", jobId)
  text ||= self~field("job-key", jobKey)
  text ||= self~field("session-ref", sessionRef)
  text ||= self~field("identity", identity)
  text ||= self~field("business-scope", businessScope)
  text ||= self~field("plan-id", planId)
  text ||= self~field("plan-version", planVersion)
  text ||= self~field("expected-micro-wlu", expectedMicroWlu)
  text ||= self~field("budget-micro-wlu", budgetMicroWlu)
  text ||= self~field("spent-micro-wlu", spentMicroWlu)
  text ||= self~field("committed-micro-wlu", committedMicroWlu)
  text ||= self~field("strategy-ceiling-micro-wlu", strategyCeilingMicroWlu)
  text ||= self~field("coverage", coverage)
  text ||= self~field("revision", revision)
  return text

::method field private
  use strict arg name, value
  value = value~string
  return name || ":" || value~length || ":" || value || "0a"x

::class WLUJobRecord public
::attribute jobId get
::attribute jobKey get
::attribute sessionRef get
::attribute identity get
::attribute businessScope get
::attribute plan get
::attribute expectedMicroWlu get
::attribute budgetMicroWlu get
::attribute spentMicroWlu get
::attribute committedMicroWlu get
::attribute revision get

::method init
  expose jobId jobKey sessionRef identity businessScope plan expectedMicroWlu budgetMicroWlu spentMicroWlu committedMicroWlu revision proof attempts
  use strict arg jobId, jobKey, sessionRef, identity, businessScope, plan, expectedMicroWlu, budgetMicroWlu
  spentMicroWlu = 0
  committedMicroWlu = 0
  revision = 1
  proof = ""
  attempts = .table~new

::method remainingMicroWlu
  expose budgetMicroWlu spentMicroWlu committedMicroWlu
  return budgetMicroWlu - spentMicroWlu - committedMicroWlu

::method snapshot
  expose jobId jobKey sessionRef identity businessScope plan expectedMicroWlu budgetMicroWlu spentMicroWlu committedMicroWlu revision proof
  return .WLUJobLease~new(jobId, jobKey, sessionRef, identity, businessScope, plan~planId, plan~version, expectedMicroWlu, budgetMicroWlu, spentMicroWlu, committedMicroWlu, plan~strategyCeilingMicroWlu, self~coverage, revision, proof)

::method refreshProof
  expose proof
  use strict arg keyRing
  snap = self~snapshot
  proof = keyRing~sign(snap~canonicalText)
  return self~snapshot

::method coverage
  expose plan budgetMicroWlu
  if budgetMicroWlu >= plan~strategyCeilingMicroWlu then return .WLUJobCoverage~FULL
  return .WLUJobCoverage~PARTIAL

::method addAttempt
  expose attempts committedMicroWlu revision
  use strict arg attempt
  attempts[attempt~reservationId] = attempt
  committedMicroWlu += attempt~reservedMicroWlu
  revision += 1
  return .true

::method attempt
  expose attempts
  use strict arg reservationId
  return attempts[reservationId~string]

::method topUpAttempt
  expose attempts committedMicroWlu revision
  use strict arg reservationId, extraMicroWlu
  attempt = attempts[reservationId~string]
  if attempt == .nil then return .false
  attempt~increaseReserved(extraMicroWlu)
  committedMicroWlu += extraMicroWlu
  revision += 1
  return .true

::method closeAttempt
  expose attempts committedMicroWlu spentMicroWlu revision
  use strict arg reservationId, actualMicroWlu
  attempt = attempts[reservationId~string]
  if attempt == .nil | \attempt~active then return .false
  committedMicroWlu -= attempt~reservedMicroWlu
  spentMicroWlu += actualMicroWlu
  attempt~close(actualMicroWlu)
  revision += 1
  return .true

::class WLUJobAttempt public
::attribute reservationId get
::attribute stageId get
::attribute reservedMicroWlu get
::attribute active get
::attribute actualMicroWlu get

::method init
  expose reservationId stageId reservedMicroWlu active actualMicroWlu
  use strict arg reservationId, stageId, reservedMicroWlu
  active = .true
  actualMicroWlu = 0

::method increaseReserved
  expose reservedMicroWlu
  use strict arg extraMicroWlu
  reservedMicroWlu += extraMicroWlu
  return reservedMicroWlu

::method close
  expose active actualMicroWlu
  use strict arg actual
  active = .false
  actualMicroWlu = actual
  return .true

::class WLUJobStageAssessment public
::attribute stageId get
::attribute scope get
::attribute budgetAvailableMicroWlu get
::attribute stageCeilingMicroWlu get
::attribute budgetShortfallMicroWlu get
::attribute demandAssessment get

::method init
  expose stageId scope budgetAvailableMicroWlu stageCeilingMicroWlu budgetShortfallMicroWlu demandAssessment
  use strict arg stageId, scope, budgetAvailableMicroWlu, stageCeilingMicroWlu, budgetShortfallMicroWlu, demandAssessment = .nil

::method viable
  expose budgetShortfallMicroWlu demandAssessment
  if budgetShortfallMicroWlu > 0 then return .false
  if demandAssessment == .nil then return .false
  return demandAssessment~ready

/* Parent-budget authority.  Child stage reservations are always made through
 * WLUAuthority, so account/bucket/throughput policy remains authoritative.
 */
::class WLUJobBudgetManager public
::attribute authority get
::attribute keyRing get

::method init
  expose authority keyRing jobs jobKeys idGenerator
  use strict arg authority
  if authority == .nil | \authority~isA(.WLUAuthority) then raise syntax 88.900 array("WLUJobBudgetManager requires WLUAuthority")
  keyRing = authority~keyRing
  jobs = .table~new
  jobKeys = .table~new
  idGenerator = .WLUIdGenerator~new("wlu-job")

::method openJob
  expose jobs jobKeys idGenerator keyRing
  use strict arg request
  guard on
  if request == .nil | \request~isA(.WLUJobRequest) then return .WLUResult~failure("WLU_JOB_REQUEST_REQUIRED", "openJob requires WLUJobRequest")
  if jobKeys~hasIndex(request~jobKey) then do
    existingId = jobKeys[request~jobKey]
    existing = jobs[existingId]
    if existing~identity \= request~identity | existing~sessionRef \= request~sessionRef | existing~budgetMicroWlu \= request~budgetMicroWlu | existing~plan~planId \= request~plan~planId | existing~plan~version \= request~plan~version then return .WLUResult~failure("WLU_JOB_IDEMPOTENCY_CONFLICT", "jobKey was already used with different job parameters")
    return .WLUResult~success(existing~snapshot, "idempotent job replay")
  end
  jobId = idGenerator~next
  record = .WLUJobRecord~new(jobId, request~jobKey, request~sessionRef, request~identity, request~businessScope, request~plan, request~expectedMicroWlu, request~budgetMicroWlu)
  lease = record~refreshProof(keyRing)
  jobs[jobId] = record
  jobKeys[request~jobKey] = jobId
  return .WLUResult~success(lease)

::method assessStage
  expose authority
  use strict arg lease, stageId
  guard on
  validated = self~validateLease(lease)
  if \validated~ok then return validated
  record = validated~value
  stageResult = record~plan~stage(stageId)
  if \stageResult~ok then return stageResult
  stage = stageResult~value
  remaining = record~remainingMicroWlu
  shortfall = 0
  if stage~ceilingMicroWlu > remaining then shortfall = stage~ceilingMicroWlu - remaining
  demandAssessment = .nil
  if shortfall = 0 then do
    assessed = authority~assessDemand(record~identity, stage~scope, stage~demand)
    if \assessed~ok then return assessed
    demandAssessment = assessed~value
  end
  assessment = .WLUJobStageAssessment~new(stage~stageId, stage~scope, remaining, stage~ceilingMicroWlu, shortfall, demandAssessment)
  return .WLUResult~success(assessment)

::method fallbackOptions
  expose authority
  use strict arg lease, fromStageId
  guard on
  validated = self~validateLease(lease)
  if \validated~ok then return validated
  record = validated~value
  fallbacks = record~plan~fallbacksFor(fromStageId)
  if \fallbacks~ok then return fallbacks
  options = .array~new
  do nextId over fallbacks~value
    stageResult = record~plan~stage(nextId)
    stage = stageResult~value
    remaining = record~remainingMicroWlu
    shortfall = 0
    if stage~ceilingMicroWlu > remaining then shortfall = stage~ceilingMicroWlu - remaining
    demandAssessment = .nil
    if shortfall = 0 then do
      assessed = authority~assessDemand(record~identity, stage~scope, stage~demand)
      if assessed~ok then demandAssessment = assessed~value
    end
    options~append(.WLUJobStageAssessment~new(stage~stageId, stage~scope, remaining, stage~ceilingMicroWlu, shortfall, demandAssessment))
  end
  return .WLUResult~success(options)

::method reserveStage
  expose authority keyRing
  use strict arg lease, stageId, ttlSeconds = 30, requestId = ""
  guard on
  validated = self~validateLease(lease)
  if \validated~ok then return validated
  record = validated~value
  stageResult = record~plan~stage(stageId)
  if \stageResult~ok then return stageResult
  stage = stageResult~value
  if stage~ceilingMicroWlu > record~remainingMicroWlu then return .WLUResult~failure("WLU_JOB_BUDGET_EXHAUSTED", "stage ceiling exceeds remaining logical-job budget by " || (stage~ceilingMicroWlu - record~remainingMicroWlu))
  childRequestId = requestId~string~strip
  if childRequestId \= "" then childRequestId = record~jobId || ":" || stage~stageId || ":" || childRequestId
  reserved = authority~reserveDemand(record~identity, stage~scope, stage~demand, ttlSeconds, childRequestId)
  if \reserved~ok then return reserved
  child = reserved~value
  attempt = .WLUJobAttempt~new(child~reservationId, stage~stageId, child~reservedMicroWlu)
  ignore = record~addAttempt(attempt)
  freshLease = record~refreshProof(keyRing)
  return .WLUResult~success(.array~of(freshLease, child), "job lease and child reservation")

::method consumeStage
  expose authority
  use strict arg lease, reservation, microWlu, operationId = ""
  guard on
  validated = self~validatePair(lease, reservation)
  if \validated~ok then return validated
  return authority~consume(reservation, microWlu, operationId)

::method consumeStageFacts
  expose authority
  use strict arg lease, reservation, facts, operationId = ""
  guard on
  validated = self~validatePair(lease, reservation)
  if \validated~ok then return validated
  return authority~consumeFacts(reservation, facts, operationId)

::method topUpStage
  expose authority keyRing
  use strict arg lease, reservation, extraMicroWlu
  guard on
  ignore = .WLUUnits~assertMicro(extraMicroWlu)
  if extraMicroWlu <= 0 then return .WLUResult~failure("WLU_INVALID_AMOUNT", "job stage top-up must be positive")
  validated = self~validatePair(lease, reservation)
  if \validated~ok then return validated
  record = validated~value[1]
  if extraMicroWlu > record~remainingMicroWlu then return .WLUResult~failure("WLU_JOB_BUDGET_EXHAUSTED", "top-up exceeds remaining logical-job budget")
  topped = authority~topUp(reservation, extraMicroWlu)
  if \topped~ok then return topped
  ignore = record~topUpAttempt(reservation~reservationId, extraMicroWlu)
  freshLease = record~refreshProof(keyRing)
  return .WLUResult~success(.array~of(freshLease, topped~value))

::method settleStage
  expose authority keyRing
  use strict arg lease, reservation, actualMicroWlu = .nil
  guard on
  validated = self~validatePair(lease, reservation)
  if \validated~ok then return validated
  record = validated~value[1]
  attempt = validated~value[2]
  if actualMicroWlu == .nil then return .WLUResult~failure("WLU_JOB_ACTUAL_REQUIRED", "job-budget settlement requires actual WLU so the parent budget can be updated deterministically")
  ignore = .WLUUnits~assertMicro(actualMicroWlu)
  if actualMicroWlu > attempt~reservedMicroWlu then return .WLUResult~failure("WLU_SETTLEMENT_EXCEEDS_RESERVATION", "top up the stage before settling larger actual work")
  settled = authority~settle(reservation, actualMicroWlu)
  if \settled~ok then return settled
  ignore = record~closeAttempt(reservation~reservationId, actualMicroWlu)
  freshLease = record~refreshProof(keyRing)
  return .WLUResult~success(freshLease)

::method releaseStage
  expose authority keyRing
  use strict arg lease, reservation
  guard on
  validated = self~validatePair(lease, reservation)
  if \validated~ok then return validated
  record = validated~value[1]
  /* Ask the core authority for authoritative observed consumption before the
   * reservation is closed.  release() refunds only the unused remainder, so
   * the logical parent must retain exactly the same incurred work. */
  usage = authority~reservationConsumed(reservation)
  if \usage~ok then return usage
  actualMicroWlu = usage~value
  released = authority~release(reservation)
  if \released~ok then return released
  ignore = record~closeAttempt(reservation~reservationId, actualMicroWlu)
  freshLease = record~refreshProof(keyRing)
  return .WLUResult~success(freshLease)

::method validatePair private
  use strict arg lease, reservation
  validated = self~validateLease(lease)
  if \validated~ok then return validated
  record = validated~value
  if reservation == .nil | \reservation~isA(.WLUReservation) then return .WLUResult~failure("WLU_RESERVATION_REQUIRED", "child WLUReservation required")
  attempt = record~attempt(reservation~reservationId)
  if attempt == .nil then return .WLUResult~failure("WLU_JOB_RESERVATION_NOT_OWNED", "reservation is not a child of this logical job")
  if \attempt~active then return .WLUResult~failure("WLU_JOB_STAGE_NOT_ACTIVE", "job stage attempt is already closed")
  return .WLUResult~success(.array~of(record, attempt))

::method validateLease private
  expose jobs keyRing
  use strict arg lease
  if lease == .nil | \lease~isA(.WLUJobLease) then return .WLUResult~failure("WLU_JOB_LEASE_REQUIRED", "authenticated WLUJobLease required")
  record = jobs[lease~jobId]
  if record == .nil then return .WLUResult~failure("WLU_JOB_NOT_FOUND", lease~jobId)
  if \keyRing~verify(lease~canonicalText, lease~proof) then return .WLUResult~failure("WLU_JOB_LEASE_PROOF_INVALID", "job budget authentication failed")
  if lease~revision \= record~revision then return .WLUResult~failure("WLU_JOB_LEASE_STALE", "job lease revision is no longer current")
  if lease~spentMicroWlu \= record~spentMicroWlu | lease~committedMicroWlu \= record~committedMicroWlu then return .WLUResult~failure("WLU_JOB_LEASE_STALE", "job budget counters no longer match authority state")
  return .WLUResult~success(record)

::requires "WorkLoadUnits.cls"
