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
 * current enterprise capacity state.  Runtime route evidence records which
 * declared path was actually selected and how much execution versus handoff
 * work was incurred, without giving that evidence admission authority.
 */

::options digits 30

::class WLUJobBuild public
::constant VERSION "0.5"
::constant API_VERSION "work.load.units.job/0.5"

::class WLUJobCoverage public
::constant FULL "FULL_STRATEGY"
::constant PARTIAL "PARTIAL_STRATEGY"

::class WLUJobForecastStatus public
::constant WITHIN_BUDGET "WITHIN_BUDGET"
::constant AT_RISK "AT_RISK"
::constant EXPECTED_OVER_BUDGET "EXPECTED_OVER_BUDGET"

/* An immutable estimator revision.  Forecasts are evidence, not entitlement:
 * they may legitimately exceed the hard job budget so the scheduler can see
 * trouble before admission itself fails.  confidenceBasisPoints is supplied
 * by the estimator (0..10000); WLU records it but does not pretend to derive
 * statistical confidence from it. */
::class WLUJobForecastRevision public
::attribute jobId get
::attribute forecastRevision get
::attribute observedTick get
::attribute spentMicroWlu get
::attribute committedMicroWlu get
::attribute budgetMicroWlu get
::attribute expectedRemainingMicroWlu get
::attribute upperRemainingMicroWlu get
::attribute confidenceBasisPoints get
::attribute source get
::attribute reason get
::attribute previousProjectedExpectedMicroWlu get
::attribute proof get

::method init
  expose jobId forecastRevision observedTick spentMicroWlu committedMicroWlu budgetMicroWlu expectedRemainingMicroWlu upperRemainingMicroWlu confidenceBasisPoints source reason previousProjectedExpectedMicroWlu proof
  use strict arg jobId, forecastRevision, observedTick, spentMicroWlu, committedMicroWlu, budgetMicroWlu, expectedRemainingMicroWlu, upperRemainingMicroWlu, confidenceBasisPoints, source = "APPLICATION", reason = "", previousProjectedExpectedMicroWlu = .nil, proof = .nil

::method projectedExpectedMicroWlu
  expose spentMicroWlu expectedRemainingMicroWlu
  return spentMicroWlu + expectedRemainingMicroWlu

::method projectedUpperMicroWlu
  expose spentMicroWlu upperRemainingMicroWlu
  return spentMicroWlu + upperRemainingMicroWlu

::method expectedShortfallMicroWlu
  expose budgetMicroWlu
  projected = self~projectedExpectedMicroWlu
  if projected <= budgetMicroWlu then return 0
  return projected - budgetMicroWlu

::method upperShortfallMicroWlu
  expose budgetMicroWlu
  projected = self~projectedUpperMicroWlu
  if projected <= budgetMicroWlu then return 0
  return projected - budgetMicroWlu

::method status
  if self~expectedShortfallMicroWlu > 0 then return .WLUJobForecastStatus~EXPECTED_OVER_BUDGET
  if self~upperShortfallMicroWlu > 0 then return .WLUJobForecastStatus~AT_RISK
  return .WLUJobForecastStatus~WITHIN_BUDGET

::method trend
  expose previousProjectedExpectedMicroWlu
  if previousProjectedExpectedMicroWlu == .nil then return "INITIAL"
  current = self~projectedExpectedMicroWlu
  if current > previousProjectedExpectedMicroWlu then return "HIGHER"
  if current < previousProjectedExpectedMicroWlu then return "LOWER"
  return "UNCHANGED"

::method canonicalText
  expose jobId forecastRevision observedTick spentMicroWlu committedMicroWlu budgetMicroWlu expectedRemainingMicroWlu upperRemainingMicroWlu confidenceBasisPoints source reason previousProjectedExpectedMicroWlu
  text = "wlu-job-forecast-v1" || "0a"x
  text ||= self~field("job-id", jobId)
  text ||= self~field("forecast-revision", forecastRevision)
  text ||= self~field("observed-tick", observedTick)
  text ||= self~field("spent-micro-wlu", spentMicroWlu)
  text ||= self~field("committed-micro-wlu", committedMicroWlu)
  text ||= self~field("budget-micro-wlu", budgetMicroWlu)
  text ||= self~field("expected-remaining-micro-wlu", expectedRemainingMicroWlu)
  text ||= self~field("upper-remaining-micro-wlu", upperRemainingMicroWlu)
  text ||= self~field("confidence-basis-points", confidenceBasisPoints)
  text ||= self~field("source", source)
  text ||= self~field("reason", reason)
  if previousProjectedExpectedMicroWlu == .nil then previous = ""
  else previous = previousProjectedExpectedMicroWlu
  text ||= self~field("previous-projected-expected-micro-wlu", previous)
  return text

::method withProof
  use strict arg newProof
  return .WLUJobForecastRevision~new(self~jobId, self~forecastRevision, self~observedTick, self~spentMicroWlu, self~committedMicroWlu, self~budgetMicroWlu, self~expectedRemainingMicroWlu, self~upperRemainingMicroWlu, self~confidenceBasisPoints, self~source, self~reason, self~previousProjectedExpectedMicroWlu, newProof)

::method verify
  expose proof
  use strict arg keyRing
  if proof == .nil then return .false
  return keyRing~verify(self~canonicalText, proof)

::method field private
  use strict arg name, value
  value = value~string
  return name || ":" || value~length || ":" || value || "0a"x

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
::attribute rateCardId get
::attribute rateCardVersion get

::method init
  expose stageId scope workExpectedMicroWlu workCeilingMicroWlu handoffExpectedMicroWlu handoffCeilingMicroWlu targetSeconds requestedRateMicroWluPerSecond rateCardId rateCardVersion
  use strict arg stageId, scope, workExpectedMicroWlu, workCeilingMicroWlu = .nil, handoffExpectedMicroWlu = 0, handoffCeilingMicroWlu = .nil, targetSeconds = 0, requestedRateMicroWluPerSecond = .nil, rateCardId = "DIRECT", rateCardVersion = "1"
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
  rateCardId = rateCardId~string~strip
  rateCardVersion = rateCardVersion~string~strip
  if rateCardId = "" | rateCardVersion = "" then raise syntax 88.900 array("WLU job stage rate-card id/version must not be empty")

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


::class WLUJobStandbyState public
::constant ACTIVE "ACTIVE"
::constant PROMOTED "PROMOTED"
::constant RELEASED "RELEASED"
::constant EXPIRED "EXPIRED"

/* A standby claim is authenticated scheduling intent, not entitlement.
 * Creating one reserves no WLU, no hierarchy budget and no throughput.
 * It lets an enterprise scheduler see a declared rescue implementation and
 * decide whether to preserve/scale capacity before promotion to a hard
 * reservation.  priority is advisory (0..1000); WLU itself never evicts work
 * merely because another standby has a larger number. */
::class WLUJobStandbyLease public
::attribute standbyId get
::attribute jobId get
::attribute stageId get
::attribute scope get
::attribute ceilingMicroWlu get
::attribute requestedRateMicroWluPerSecond get
::attribute priority get
::attribute createdTick get
::attribute expiresTick get
::attribute state get
::attribute revision get
::attribute promotedReservationId get
::attribute proof get

::method init
  expose standbyId jobId stageId scope ceilingMicroWlu requestedRateMicroWluPerSecond priority createdTick expiresTick state revision promotedReservationId proof
  use strict arg standbyId, jobId, stageId, scope, ceilingMicroWlu, requestedRateMicroWluPerSecond, priority, createdTick, expiresTick, state, revision, promotedReservationId = "", proof = .nil

::method expired
  expose state expiresTick
  use strict arg nowTick
  return state = .WLUJobStandbyState~ACTIVE & nowTick >= expiresTick

::method effectiveState
  expose state
  use strict arg nowTick
  if self~expired(nowTick) then return .WLUJobStandbyState~EXPIRED
  return state

::method canonicalText
  expose standbyId jobId stageId scope ceilingMicroWlu requestedRateMicroWluPerSecond priority createdTick expiresTick state revision promotedReservationId
  text = "wlu-job-standby-v1" || "0a"x
  text ||= self~field("standby-id", standbyId)
  text ||= self~field("job-id", jobId)
  text ||= self~field("stage-id", stageId)
  text ||= self~field("scope", scope)
  text ||= self~field("ceiling-micro-wlu", ceilingMicroWlu)
  text ||= self~field("requested-rate-micro-wlu-per-second", requestedRateMicroWluPerSecond)
  text ||= self~field("priority", priority)
  text ||= self~field("created-tick", createdTick)
  text ||= self~field("expires-tick", expiresTick)
  text ||= self~field("state", state)
  text ||= self~field("revision", revision)
  text ||= self~field("promoted-reservation-id", promotedReservationId)
  return text

::method verify
  expose proof
  use strict arg keyRing
  if proof == .nil then return .false
  return keyRing~verify(self~canonicalText, proof)

::method field private
  use strict arg name, value
  value = value~string
  return name || ":" || value~length || ":" || value || "0a"x

::class WLUJobStandbyRecord public
::attribute standbyId get
::attribute jobId get
::attribute stageId get
::attribute scope get
::attribute ceilingMicroWlu get
::attribute requestedRateMicroWluPerSecond get
::attribute priority get
::attribute createdTick get
::attribute expiresTick get
::attribute state get
::attribute revision get
::attribute promotedReservationId get
::attribute requestId get
::attribute ttlSeconds get

::method init
  expose standbyId jobId stageId scope ceilingMicroWlu requestedRateMicroWluPerSecond priority createdTick expiresTick state revision promotedReservationId requestId ttlSeconds proof
  use strict arg standbyId, jobId, stageId, scope, ceilingMicroWlu, requestedRateMicroWluPerSecond, priority, createdTick, expiresTick, requestId = "", ttlSeconds = 0
  state = .WLUJobStandbyState~ACTIVE
  revision = 1
  promotedReservationId = ""
  proof = ""

::method snapshot
  expose standbyId jobId stageId scope ceilingMicroWlu requestedRateMicroWluPerSecond priority createdTick expiresTick state revision promotedReservationId proof
  return .WLUJobStandbyLease~new(standbyId, jobId, stageId, scope, ceilingMicroWlu, requestedRateMicroWluPerSecond, priority, createdTick, expiresTick, state, revision, promotedReservationId, proof)

::method refreshProof
  expose proof
  use strict arg keyRing
  snap = self~snapshot
  proof = keyRing~sign(snap~canonicalText)
  return self~snapshot

::method promote
  expose state revision promotedReservationId
  use strict arg reservationId
  if state \= .WLUJobStandbyState~ACTIVE then return .false
  state = .WLUJobStandbyState~PROMOTED
  promotedReservationId = reservationId~string
  revision += 1
  return .true

::method release
  expose state revision
  if state \= .WLUJobStandbyState~ACTIVE then return .false
  state = .WLUJobStandbyState~RELEASED
  revision += 1
  return .true

::class WLUJobStandbyAssessment public
::attribute standby get
::attribute effectiveState get
::attribute jobAvailableMicroWlu get
::attribute jobShortfallMicroWlu get
::attribute demandAssessment get

::method init
  expose standby effectiveState jobAvailableMicroWlu jobShortfallMicroWlu demandAssessment
  use strict arg standby, effectiveState, jobAvailableMicroWlu, jobShortfallMicroWlu, demandAssessment = .nil

::method ready
  expose effectiveState jobShortfallMicroWlu demandAssessment
  if effectiveState \= .WLUJobStandbyState~ACTIVE then return .false
  if jobShortfallMicroWlu > 0 then return .false
  if demandAssessment == .nil then return .false
  return demandAssessment~ready


/* Runtime route evidence is deliberately separate from hard entitlement.
 * These records explain which implementation path actually ran and why the
 * application selected a declared fallback.  WLU authenticates the evidence
 * but does not decide whether a quality/provider/application reason is true. */
::class WLUJobRouteEventType public
::constant TRANSITION "TRANSITION"
::constant STAGE_RESERVED "STAGE_RESERVED"
::constant STAGE_SETTLED "STAGE_SETTLED"
::constant STAGE_RELEASED "STAGE_RELEASED"

::class WLUJobRouteEvidence public
::attribute jobId get
::attribute routeRevision get
::attribute observedTick get
::attribute eventType get
::attribute stageId get
::attribute fromStageId get
::attribute reservationId get
::attribute actualWorkMicroWlu get
::attribute actualHandoffMicroWlu get
::attribute breakdownKnown get
::attribute stageExpectedMicroWlu get
::attribute stageCeilingMicroWlu get
::attribute forecastRevision get
::attribute forecastStatus get
::attribute standbyId get
::attribute reasonCode get
::attribute evidenceRef get
::attribute rateCardId get
::attribute rateCardVersion get
::attribute proof get

::method init
  expose jobId routeRevision observedTick eventType stageId fromStageId reservationId actualWorkMicroWlu actualHandoffMicroWlu breakdownKnown stageExpectedMicroWlu stageCeilingMicroWlu forecastRevision forecastStatus standbyId reasonCode evidenceRef rateCardId rateCardVersion proof
  use strict arg jobId, routeRevision, observedTick, eventType, stageId, fromStageId = "", reservationId = "", actualWorkMicroWlu = 0, actualHandoffMicroWlu = 0, breakdownKnown = .false, stageExpectedMicroWlu = 0, stageCeilingMicroWlu = 0, forecastRevision = 0, forecastStatus = "", standbyId = "", reasonCode = "", evidenceRef = "", rateCardId = "", rateCardVersion = "", proof = .nil

::method actualTotalMicroWlu
  expose actualWorkMicroWlu actualHandoffMicroWlu
  return actualWorkMicroWlu + actualHandoffMicroWlu

::method varianceFromExpectedMicroWlu
  expose stageExpectedMicroWlu
  return self~actualTotalMicroWlu - stageExpectedMicroWlu

::method overExpected
  return self~varianceFromExpectedMicroWlu > 0

::method canonicalText
  expose jobId routeRevision observedTick eventType stageId fromStageId reservationId actualWorkMicroWlu actualHandoffMicroWlu breakdownKnown stageExpectedMicroWlu stageCeilingMicroWlu forecastRevision forecastStatus standbyId reasonCode evidenceRef rateCardId rateCardVersion
  text = "wlu-job-route-evidence-v1" || "0a"x
  text ||= self~field("job-id", jobId)
  text ||= self~field("route-revision", routeRevision)
  text ||= self~field("observed-tick", observedTick)
  text ||= self~field("event-type", eventType)
  text ||= self~field("stage-id", stageId)
  text ||= self~field("from-stage-id", fromStageId)
  text ||= self~field("reservation-id", reservationId)
  text ||= self~field("actual-work-micro-wlu", actualWorkMicroWlu)
  text ||= self~field("actual-handoff-micro-wlu", actualHandoffMicroWlu)
  text ||= self~field("breakdown-known", breakdownKnown)
  text ||= self~field("stage-expected-micro-wlu", stageExpectedMicroWlu)
  text ||= self~field("stage-ceiling-micro-wlu", stageCeilingMicroWlu)
  text ||= self~field("forecast-revision", forecastRevision)
  text ||= self~field("forecast-status", forecastStatus)
  text ||= self~field("standby-id", standbyId)
  text ||= self~field("reason-code", reasonCode)
  text ||= self~field("evidence-ref", evidenceRef)
  text ||= self~field("rate-card-id", rateCardId)
  text ||= self~field("rate-card-version", rateCardVersion)
  return text

::method withProof
  use strict arg newProof
  return .WLUJobRouteEvidence~new(self~jobId, self~routeRevision, self~observedTick, self~eventType, self~stageId, self~fromStageId, self~reservationId, self~actualWorkMicroWlu, self~actualHandoffMicroWlu, self~breakdownKnown, self~stageExpectedMicroWlu, self~stageCeilingMicroWlu, self~forecastRevision, self~forecastStatus, self~standbyId, self~reasonCode, self~evidenceRef, self~rateCardId, self~rateCardVersion, newProof)

::method verify
  expose proof
  use strict arg keyRing
  if proof == .nil then return .false
  return keyRing~verify(self~canonicalText, proof)

::method field private
  use strict arg name, value
  value = value~string
  return name || ":" || value~length || ":" || value || "0a"x

::class WLUJobRouteSummary public
::attribute jobId get
::attribute latestRevision get
::attribute eventCount get
::attribute transitionCount get
::attribute stageReservationCount get
::attribute stageCloseCount get
::attribute actualMicroWlu get
::attribute knownHandoffMicroWlu get
::attribute overExpectedCount get

::method init
  expose jobId latestRevision eventCount transitionCount stageReservationCount stageCloseCount actualMicroWlu knownHandoffMicroWlu overExpectedCount
  use strict arg jobId, latestRevision, eventCount, transitionCount, stageReservationCount, stageCloseCount, actualMicroWlu, knownHandoffMicroWlu, overExpectedCount

::method fromEvents class
  use strict arg jobId, events
  total = 0
  transitions = 0
  reservations = 0
  closes = 0
  actual = 0
  handoff = 0
  overExpected = 0
  latestRevision = 0
  do event over events
    if event~jobId \= jobId then iterate
    total += 1
    if event~routeRevision > latestRevision then latestRevision = event~routeRevision
    select
      when event~eventType = .WLUJobRouteEventType~TRANSITION then transitions += 1
      when event~eventType = .WLUJobRouteEventType~STAGE_RESERVED then reservations += 1
      when event~eventType = .WLUJobRouteEventType~STAGE_SETTLED | event~eventType = .WLUJobRouteEventType~STAGE_RELEASED then do
        closes += 1
        actual += event~actualTotalMicroWlu
        if event~breakdownKnown then handoff += event~actualHandoffMicroWlu
        if event~overExpected then overExpected += 1
      end
      otherwise nop
    end
  end
  return self~new(jobId, latestRevision, total, transitions, reservations, closes, actual, handoff, overExpected)


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
::attribute forecastRevision get
::attribute forecastObservedTick get
::attribute forecastProjectedExpectedMicroWlu get
::attribute forecastProjectedUpperMicroWlu get
::attribute forecastConfidenceBasisPoints get
::attribute forecastStatus get
::attribute proof get

::method init
  expose jobId jobKey sessionRef identity businessScope planId planVersion expectedMicroWlu budgetMicroWlu spentMicroWlu committedMicroWlu strategyCeilingMicroWlu coverage revision forecastRevision forecastObservedTick forecastProjectedExpectedMicroWlu forecastProjectedUpperMicroWlu forecastConfidenceBasisPoints forecastStatus proof
  use strict arg jobId, jobKey, sessionRef, identity, businessScope, planId, planVersion, expectedMicroWlu, budgetMicroWlu, spentMicroWlu, committedMicroWlu, strategyCeilingMicroWlu, coverage, revision, forecastRevision = 0, forecastObservedTick = 0, forecastProjectedExpectedMicroWlu = 0, forecastProjectedUpperMicroWlu = 0, forecastConfidenceBasisPoints = 0, forecastStatus = "", proof = .nil

::method remainingMicroWlu
  expose budgetMicroWlu spentMicroWlu committedMicroWlu
  return budgetMicroWlu - spentMicroWlu - committedMicroWlu

::method forecastInferredExpectedRemainingMicroWlu
  expose spentMicroWlu forecastProjectedExpectedMicroWlu
  remaining = forecastProjectedExpectedMicroWlu - spentMicroWlu
  if remaining < 0 then return 0
  return remaining

::method forecastInferredUpperRemainingMicroWlu
  expose spentMicroWlu forecastProjectedUpperMicroWlu
  remaining = forecastProjectedUpperMicroWlu - spentMicroWlu
  if remaining < 0 then return 0
  return remaining

::method canonicalText
  expose jobId jobKey sessionRef identity businessScope planId planVersion expectedMicroWlu budgetMicroWlu spentMicroWlu committedMicroWlu strategyCeilingMicroWlu coverage revision forecastRevision forecastObservedTick forecastProjectedExpectedMicroWlu forecastProjectedUpperMicroWlu forecastConfidenceBasisPoints forecastStatus
  text = "wlu-job-lease-v2" || "0a"x
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
  text ||= self~field("forecast-revision", forecastRevision)
  text ||= self~field("forecast-observed-tick", forecastObservedTick)
  text ||= self~field("forecast-projected-expected-micro-wlu", forecastProjectedExpectedMicroWlu)
  text ||= self~field("forecast-projected-upper-micro-wlu", forecastProjectedUpperMicroWlu)
  text ||= self~field("forecast-confidence-basis-points", forecastConfidenceBasisPoints)
  text ||= self~field("forecast-status", forecastStatus)
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
::attribute forecastRevision get

::method init
  expose jobId jobKey sessionRef identity businessScope plan expectedMicroWlu budgetMicroWlu spentMicroWlu committedMicroWlu revision proof attempts forecastRevision currentForecast forecastHistory routeRevision routeHistory
  use strict arg jobId, jobKey, sessionRef, identity, businessScope, plan, expectedMicroWlu, budgetMicroWlu
  spentMicroWlu = 0
  committedMicroWlu = 0
  revision = 1
  proof = ""
  attempts = .table~new
  forecastRevision = 0
  currentForecast = .nil
  forecastHistory = .array~new
  routeRevision = 0
  routeHistory = .array~new

::method remainingMicroWlu
  expose budgetMicroWlu spentMicroWlu committedMicroWlu
  return budgetMicroWlu - spentMicroWlu - committedMicroWlu

::method snapshot
  expose jobId jobKey sessionRef identity businessScope plan expectedMicroWlu budgetMicroWlu spentMicroWlu committedMicroWlu revision proof currentForecast
  if currentForecast == .nil then do
    forecastRevision = 0
    forecastObservedTick = 0
    forecastProjectedExpected = expectedMicroWlu
    forecastProjectedUpper = expectedMicroWlu
    forecastConfidence = 0
    forecastStatus = .WLUJobForecastStatus~WITHIN_BUDGET
  end
  else do
    forecastRevision = currentForecast~forecastRevision
    forecastObservedTick = currentForecast~observedTick
    forecastProjectedExpected = currentForecast~projectedExpectedMicroWlu
    forecastProjectedUpper = currentForecast~projectedUpperMicroWlu
    forecastConfidence = currentForecast~confidenceBasisPoints
    forecastStatus = currentForecast~status
  end
  return .WLUJobLease~new(jobId, jobKey, sessionRef, identity, businessScope, plan~planId, plan~version, expectedMicroWlu, budgetMicroWlu, spentMicroWlu, committedMicroWlu, plan~strategyCeilingMicroWlu, self~coverage, revision, forecastRevision, forecastObservedTick, forecastProjectedExpected, forecastProjectedUpper, forecastConfidence, forecastStatus, proof)

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

::method initializeForecast
  expose jobId expectedMicroWlu budgetMicroWlu spentMicroWlu committedMicroWlu forecastRevision currentForecast forecastHistory
  use strict arg observedTick, keyRing
  if currentForecast \== .nil then return currentForecast
  forecastRevision = 1
  draft = .WLUJobForecastRevision~new(jobId, forecastRevision, observedTick, spentMicroWlu, committedMicroWlu, budgetMicroWlu, expectedMicroWlu, expectedMicroWlu, 0, "INITIAL_REQUEST", "job opened", .nil)
  currentForecast = draft~withProof(keyRing~sign(draft~canonicalText))
  forecastHistory~append(currentForecast)
  return currentForecast

::method reviseForecast
  expose jobId budgetMicroWlu spentMicroWlu committedMicroWlu revision forecastRevision currentForecast forecastHistory
  use strict arg expectedRemainingMicroWlu, upperRemainingMicroWlu, confidenceBasisPoints, source, reason, observedTick, keyRing
  previousProjected = .nil
  if currentForecast \== .nil then previousProjected = currentForecast~projectedExpectedMicroWlu
  forecastRevision += 1
  draft = .WLUJobForecastRevision~new(jobId, forecastRevision, observedTick, spentMicroWlu, committedMicroWlu, budgetMicroWlu, expectedRemainingMicroWlu, upperRemainingMicroWlu, confidenceBasisPoints, source, reason, previousProjected)
  currentForecast = draft~withProof(keyRing~sign(draft~canonicalText))
  forecastHistory~append(currentForecast)
  revision += 1
  return currentForecast

::method currentForecast
  expose currentForecast
  return currentForecast

::method forecastHistory
  expose forecastHistory
  copy = .array~new
  do forecast over forecastHistory
    copy~append(forecast)
  end
  return copy

::method routeHistory
  expose routeHistory
  copy = .array~new
  do event over routeHistory
    copy~append(event)
  end
  return copy

::method routeSummary
  expose jobId routeHistory
  return .WLUJobRouteSummary~fromEvents(jobId, routeHistory)

::method appendRouteEvent
  expose jobId routeRevision routeHistory
  use strict arg observedTick, eventType, stageId, fromStageId = "", reservationId = "", actualWorkMicroWlu = 0, actualHandoffMicroWlu = 0, breakdownKnown = .false, stageExpectedMicroWlu = 0, stageCeilingMicroWlu = 0, forecastRevision = 0, forecastStatus = "", standbyId = "", reasonCode = "", evidenceRef = "", rateCardId = "", rateCardVersion = "", keyRing
  routeRevision += 1
  draft = .WLUJobRouteEvidence~new(jobId, routeRevision, observedTick, eventType, stageId, fromStageId, reservationId, actualWorkMicroWlu, actualHandoffMicroWlu, breakdownKnown, stageExpectedMicroWlu, stageCeilingMicroWlu, forecastRevision, forecastStatus, standbyId, reasonCode, evidenceRef, rateCardId, rateCardVersion)
  event = draft~withProof(keyRing~sign(draft~canonicalText))
  routeHistory~append(event)
  return event

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
::attribute startedTick get
::attribute stageExpectedMicroWlu get
::attribute stageCeilingMicroWlu get
::attribute forecastRevisionAtStart get
::attribute forecastStatusAtStart get
::attribute standbyId get
::attribute rateCardId get
::attribute rateCardVersion get

::method init
  expose reservationId stageId reservedMicroWlu active actualMicroWlu startedTick stageExpectedMicroWlu stageCeilingMicroWlu forecastRevisionAtStart forecastStatusAtStart standbyId rateCardId rateCardVersion
  use strict arg reservationId, stageId, reservedMicroWlu, startedTick = 0, stageExpectedMicroWlu = 0, stageCeilingMicroWlu = 0, forecastRevisionAtStart = 0, forecastStatusAtStart = "", standbyId = "", rateCardId = "", rateCardVersion = ""
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
::class WLUJobBudgetManager subclass AlchemyObject public
::attribute authority get
::attribute keyRing get

::method init
  expose authority keyRing jobs jobKeys idGenerator standbys standbyKeys standbyIdGenerator transitionKeys
  use strict arg authority
  if authority == .nil | \authority~isA(.WLUAuthority) then raise syntax 88.900 array("WLUJobBudgetManager requires WLUAuthority")
  keyRing = authority~keyRing
  jobs = .table~new
  jobKeys = .table~new
  idGenerator = .WLUIdGenerator~new("wlu-job")
  standbys = .table~new
  standbyKeys = .table~new
  standbyIdGenerator = .WLUIdGenerator~new("wlu-standby")
  transitionKeys = .table~new
  alchemyConstruction = .WLUAlchemySupport~construction(keyRing, "WLUJobBudgetManager", "Logical business-job WLU budget and backend-stage escalation authority")
  self~init:super(alchemyConstruction[1], alchemyConstruction[2], alchemyConstruction[3])
  ignore = .WLUAlchemySupport~finishConstruction(self)
  self~recordRelationship("WLU_AUTHORITY", authority, "child execution admission and settlement authority", "INTERNAL")
  self~registerMethodContract("OPENJOB", "Open an authenticated logical business-job budget", .array~of("REQUEST"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "GRANT")
  self~registerMethodContract("ASSESSSTAGE", "Assess one implementation stage against remaining job budget and live WLU capacity", .array~of("LEASE", "STAGEID"), "WLURESULT", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("FALLBACKOPTIONS", "Assess declared fallback routes without executing them", .array~of("LEASE", "FROMSTAGEID"), "WLURESULT", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("FORECAST", "Read the latest authenticated live workload forecast for the logical job", .array~of("LEASE"), "WLURESULT", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("FORECASTHISTORY", "Read immutable authenticated forecast revisions for the logical job", .array~of("LEASE"), "WLURESULT", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("REVISEFORECAST", "Record a new estimator revision without changing the hard WLU budget", .array~of("LEASE", "EXPECTEDREMAININGMICROWLU", "UPPERREMAININGMICROWLU", "CONFIDENCEBASISPOINTS"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "NONE")
  self~registerMethodContract("STANDBYSTAGE", "Create authenticated non-entitling standby intent for a declared stage", .array~of("LEASE", "STAGEID", "TTLSECONDS", "PRIORITY", "REQUESTID"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "NONE")
  self~registerMethodContract("STANDBYCLAIMS", "List authenticated standby intents for a logical job", .array~of("LEASE"), "WLURESULT", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("ASSESSSTANDBY", "Assess standby intent against current hard job and runtime capacity without reserving it", .array~of("LEASE", "STANDBYLEASE"), "WLURESULT", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("PROMOTESTANDBY", "Promote standby intent to a real WLU stage reservation", .array~of("LEASE", "STANDBYLEASE", "TTLSECONDS", "REQUESTID"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "GRANT")
  self~registerMethodContract("RELEASESTANDBY", "Release non-entitling standby intent", .array~of("LEASE", "STANDBYLEASE"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "REVOKE")
  self~registerMethodContract("RESERVESTAGE", "Make-before-break reservation of a backend stage under the parent job budget", .array~of("LEASE", "STAGEID", "TTLSECONDS", "REQUESTID"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "GRANT")
  self~registerMethodContract("SETTLESTAGE", "Settle a backend stage into the logical job budget", .array~of("LEASE", "RESERVATION", "ACTUALMICROWLU"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "REVOKE")
  self~registerMethodContract("RECORDTRANSITION", "Record authenticated application-declared movement along a declared fallback edge", .array~of("LEASE", "FROMSTAGEID", "TOSTAGEID", "REASONCODE"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "NONE")
  self~registerMethodContract("ROUTEHISTORY", "Read authenticated execution-route evidence for the logical job", .array~of("LEASE"), "WLURESULT", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("ROUTESUMMARY", "Derive route counts and actual WLU from authenticated route evidence", .array~of("LEASE"), "WLURESULT", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("ARCHIVEROUTEHISTORY", "Copy authenticated route history into an external durable archive without changing WLU authority state", .array~of("LEASE", "JOURNAL"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "EXTERNAL", "NONE")
  self~registerMethodContract("SETTLESTAGEBREAKDOWN", "Settle a stage with explicit execution versus handoff WLU evidence", .array~of("LEASE", "RESERVATION", "ACTUALWORKMICROWLU", "ACTUALHANDOFFMICROWLU"), "WLURESULT", .true, "AUTO", "CUSTOMER", "AUTHORITY", "MUTATE", "REVOKE")
  self~registerInstrumentationPoint("WLU.JOB.ROUTE", "authenticated stage-transition and execution-outcome metadata; reason evidence is referenced rather than copied", .true, "ALL", "INTERNAL")

::method openJob public protected
  expose authority jobs jobKeys idGenerator keyRing
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
  ignore = record~initializeForecast(authority~clock~nowTick, keyRing)
  lease = record~refreshProof(keyRing)
  jobs[jobId] = record
  jobKeys[request~jobKey] = jobId
  return .WLUResult~success(lease)

::method forecast
  use strict arg lease
  guard on
  validated = self~validateLease(lease)
  if \validated~ok then return validated
  return .WLUResult~success(validated~value~currentForecast)

::method forecastHistory
  use strict arg lease
  guard on
  validated = self~validateLease(lease)
  if \validated~ok then return validated
  return .WLUResult~success(validated~value~forecastHistory)

::method reviseForecast public protected
  expose authority keyRing
  use strict arg lease, expectedRemainingMicroWlu, upperRemainingMicroWlu = .nil, confidenceBasisPoints = 0, source = "APPLICATION", reason = ""
  guard on
  validated = self~validateLease(lease)
  if \validated~ok then return validated
  if \datatype(expectedRemainingMicroWlu, "W") | expectedRemainingMicroWlu < 0 then return .WLUResult~failure("WLU_FORECAST_INVALID", "expected remaining WLU must be a non-negative whole micro-WLU value")
  if upperRemainingMicroWlu == .nil then upperRemainingMicroWlu = expectedRemainingMicroWlu
  if \datatype(upperRemainingMicroWlu, "W") | upperRemainingMicroWlu < expectedRemainingMicroWlu then return .WLUResult~failure("WLU_FORECAST_INVALID", "upper remaining WLU must be a whole value >= expected remaining WLU")
  if \datatype(confidenceBasisPoints, "W") | confidenceBasisPoints < 0 | confidenceBasisPoints > 10000 then return .WLUResult~failure("WLU_FORECAST_INVALID", "confidence basis points must be an integer from 0 through 10000")
  source = source~string~strip
  reason = reason~string
  if source = "" then source = "APPLICATION"
  record = validated~value
  forecast = record~reviseForecast(expectedRemainingMicroWlu, upperRemainingMicroWlu, confidenceBasisPoints, source, reason, authority~clock~nowTick, keyRing)
  freshLease = record~refreshProof(keyRing)
  detail = "forecast-status=" || forecast~status || " expected-shortfall=" || forecast~expectedShortfallMicroWlu || " upper-shortfall=" || forecast~upperShortfallMicroWlu
  return .WLUResult~success(.array~of(freshLease, forecast), detail)


::method routeHistory
  use strict arg lease
  guard on
  validated = self~validateLease(lease)
  if \validated~ok then return validated
  return .WLUResult~success(validated~value~routeHistory)

::method routeSummary
  use strict arg lease
  guard on
  validated = self~validateLease(lease)
  if \validated~ok then return validated
  return .WLUResult~success(validated~value~routeSummary)

::method archiveRouteHistory public protected
  use strict arg lease, journal
  guard on
  validated = self~validateLease(lease)
  if \validated~ok then return validated
  if journal == .nil then return .WLUResult~failure("WLU_ROUTE_JOURNAL_REQUIRED", "route journal with ARCHIVEEVENTS required")
  if \journal~hasMethod("ARCHIVEEVENTS") then return .WLUResult~failure("WLU_ROUTE_JOURNAL_REQUIRED", "route journal with ARCHIVEEVENTS required")
  history = validated~value~routeHistory
  return journal~archiveEvents(history)

::method recordTransition public protected
  expose authority keyRing transitionKeys
  use strict arg lease, fromStageId, toStageId, reasonCode, evidenceRef = "", standbyLease = .nil, requestId = ""
  guard on
  validated = self~validateLease(lease)
  if \validated~ok then return validated
  record = validated~value
  fromStageId = fromStageId~string~strip
  toStageId = toStageId~string~strip
  reasonCode = reasonCode~string~strip
  evidenceRef = evidenceRef~string~strip
  requestId = requestId~string~strip
  if reasonCode = "" then return .WLUResult~failure("WLU_ROUTE_REASON_REQUIRED", "application route transition requires a reason code")
  requestedStandbyId = ""
  if standbyLease \== .nil then do
    if standbyLease~isA(.WLUJobStandbyLease) then requestedStandbyId = standbyLease~standbyId
  end
  if requestId \= "" then do
    routeKey = record~jobId || ":" || requestId
    existing = transitionKeys[routeKey]
    if existing \== .nil then do
      if existing~fromStageId \= fromStageId | existing~stageId \= toStageId | existing~reasonCode \= reasonCode | existing~evidenceRef \= evidenceRef | existing~standbyId \= requestedStandbyId then return .WLUResult~failure("WLU_ROUTE_IDEMPOTENCY_CONFLICT", "route request id was already used with different transition evidence")
      return .WLUResult~success(existing, "idempotent route-evidence replay")
    end
  end
  sourceResult = record~plan~fallbacksFor(fromStageId)
  if \sourceResult~ok then return sourceResult
  declared = .false
  do candidate over sourceResult~value
    if candidate = toStageId then declared = .true
  end
  if \declared then return .WLUResult~failure("WLU_ROUTE_TRANSITION_UNDECLARED", fromStageId || " -> " || toStageId)
  stageResult = record~plan~stage(toStageId)
  if \stageResult~ok then return stageResult
  standbyId = ""
  if standbyLease \== .nil then do
    standbyResult = self~validateStandby(record, standbyLease)
    if \standbyResult~ok then return standbyResult
    standby = standbyResult~value~snapshot
    if standby~stageId \= toStageId then return .WLUResult~failure("WLU_ROUTE_STANDBY_MISMATCH", "standby belongs to stage " || standby~stageId)
    effective = standby~effectiveState(authority~clock~nowTick)
    if effective = .WLUJobStandbyState~EXPIRED then return .WLUResult~failure("WLU_STANDBY_EXPIRED", standby~standbyId)
    standbyId = standby~standbyId
  end
  forecast = record~currentForecast
  stage = stageResult~value
  event = record~appendRouteEvent(authority~clock~nowTick, .WLUJobRouteEventType~TRANSITION, stage~stageId, fromStageId, "", 0, 0, .false, stage~expectedMicroWlu, stage~ceilingMicroWlu, forecast~forecastRevision, forecast~status, standbyId, reasonCode, evidenceRef, stage~rateCardId, stage~rateCardVersion, keyRing)
  meta = .directory~new
  meta["job_id"] = record~jobId
  meta["from_stage_id"] = fromStageId
  meta["to_stage_id"] = toStageId
  meta["reason_code"] = reasonCode
  meta["forecast_revision"] = forecast~forecastRevision
  meta["standby_id"] = standbyId
  self~alchemyInstrument("WLU.JOB.ROUTE", meta)
  if requestId \= "" then transitionKeys[routeKey] = event
  return .WLUResult~success(event, "route decision recorded; no work or capacity reserved")


::method standbyStage public protected
  expose authority keyRing standbys standbyKeys standbyIdGenerator
  use strict arg lease, stageId, ttlSeconds = 60, priority = 500, requestId = ""
  guard on
  validated = self~validateLease(lease)
  if \validated~ok then return validated
  if \datatype(ttlSeconds, "W") | ttlSeconds <= 0 then return .WLUResult~failure("WLU_STANDBY_INVALID_TTL", "standby TTL must be a positive whole number of seconds")
  if \datatype(priority, "W") | priority < 0 | priority > 1000 then return .WLUResult~failure("WLU_STANDBY_INVALID_PRIORITY", "standby priority must be an integer from 0 through 1000")
  record = validated~value
  stageResult = record~plan~stage(stageId)
  if \stageResult~ok then return stageResult
  stage = stageResult~value
  requestId = requestId~string~strip
  if requestId \= "" then do
    key = record~jobId || ":" || requestId
    existingId = standbyKeys[key]
    if existingId \== .nil then do
      existing = standbys[existingId]
      if existing~stageId \= stage~stageId | existing~ttlSeconds \= ttlSeconds | existing~priority \= priority then return .WLUResult~failure("WLU_STANDBY_IDEMPOTENCY_CONFLICT", "standby request id was already used with different parameters")
      return .WLUResult~success(existing~snapshot, "idempotent standby replay")
    end
  end
  nowTick = authority~clock~nowTick
  expiresTick = nowTick + ttlSeconds * 1000000
  standbyId = standbyIdGenerator~next
  demand = stage~demand
  standby = .WLUJobStandbyRecord~new(standbyId, record~jobId, stage~stageId, stage~scope, stage~ceilingMicroWlu, demand~requestedRateMicroWluPerSecond, priority, nowTick, expiresTick, requestId, ttlSeconds)
  snap = standby~refreshProof(keyRing)
  standbys[standbyId] = standby
  if requestId \= "" then standbyKeys[key] = standbyId
  return .WLUResult~success(snap, "standby intent only; no WLU or throughput reserved")

::method standbyClaims
  expose standbys
  use strict arg lease
  guard on
  validated = self~validateLease(lease)
  if \validated~ok then return validated
  record = validated~value
  out = .array~new
  supplier = standbys~supplier
  do while supplier~available
    standby = supplier~item
    if standby~jobId = record~jobId then out~append(standby~snapshot)
    supplier~next
  end
  return .WLUResult~success(out)

::method assessStandby
  expose authority
  use strict arg lease, standbyLease
  guard on
  validated = self~validateLease(lease)
  if \validated~ok then return validated
  record = validated~value
  standbyResult = self~validateStandby(record, standbyLease)
  if \standbyResult~ok then return standbyResult
  standby = standbyResult~value
  snap = standby~snapshot
  state = snap~effectiveState(authority~clock~nowTick)
  available = record~remainingMicroWlu
  shortfall = 0
  if snap~ceilingMicroWlu > available then shortfall = snap~ceilingMicroWlu - available
  demandAssessment = .nil
  if state = .WLUJobStandbyState~ACTIVE & shortfall = 0 then do
    stageResult = record~plan~stage(snap~stageId)
    if \stageResult~ok then return stageResult
    assessed = authority~assessDemand(record~identity, snap~scope, stageResult~value~demand)
    if assessed~ok then demandAssessment = assessed~value
  end
  return .WLUResult~success(.WLUJobStandbyAssessment~new(snap, state, available, shortfall, demandAssessment))

::method markStandbyPromoted public protected
  expose authority keyRing
  use strict arg lease, standbyLease, reservationId
  guard on
  validated = self~validateLease(lease)
  if \validated~ok then return validated
  record = validated~value
  standbyResult = self~validateStandby(record, standbyLease)
  if \standbyResult~ok then return standbyResult
  standby = standbyResult~value
  snap = standby~snapshot
  if snap~effectiveState(authority~clock~nowTick) = .WLUJobStandbyState~EXPIRED then return .WLUResult~failure("WLU_STANDBY_EXPIRED", snap~standbyId)
  if snap~state \= .WLUJobStandbyState~ACTIVE then return .WLUResult~failure("WLU_STANDBY_NOT_ACTIVE", snap~state)
  attempt = record~attempt(reservationId)
  if attempt == .nil then return .WLUResult~failure("WLU_STANDBY_RESERVATION_MISMATCH", "promotion reservation is not a child attempt of this logical job")
  if \attempt~active | attempt~stageId \= snap~stageId then return .WLUResult~failure("WLU_STANDBY_RESERVATION_MISMATCH", "promotion reservation is not an active attempt for the standby stage")
  if \standby~promote(reservationId) then return .WLUResult~failure("WLU_STANDBY_NOT_ACTIVE", "standby could not be promoted")
  return .WLUResult~success(standby~refreshProof(keyRing))

::method promoteStandby public protected
  expose authority keyRing
  use strict arg lease, standbyLease, ttlSeconds = 30, requestId = ""
  guard on
  validated = self~validateLease(lease)
  if \validated~ok then return validated
  record = validated~value
  standbyResult = self~validateStandby(record, standbyLease)
  if \standbyResult~ok then return standbyResult
  standby = standbyResult~value
  snap = standby~snapshot
  if snap~effectiveState(authority~clock~nowTick) = .WLUJobStandbyState~EXPIRED then return .WLUResult~failure("WLU_STANDBY_EXPIRED", snap~standbyId)
  if snap~state \= .WLUJobStandbyState~ACTIVE then return .WLUResult~failure("WLU_STANDBY_NOT_ACTIVE", snap~state)
  if snap~ceilingMicroWlu > record~remainingMicroWlu then return .WLUResult~failure("WLU_JOB_BUDGET_EXHAUSTED", "standby promotion exceeds remaining logical-job budget by " || (snap~ceilingMicroWlu - record~remainingMicroWlu))
  stageResult = record~plan~stage(snap~stageId)
  if \stageResult~ok then return stageResult
  stage = stageResult~value
  childRequestId = requestId~string~strip
  if childRequestId \= "" then childRequestId = record~jobId || ":" || stage~stageId || ":standby:" || childRequestId
  reserved = authority~reserveDemand(record~identity, stage~scope, stage~demand, ttlSeconds, childRequestId, stage~rateCardId, stage~rateCardVersion)
  if \reserved~ok then return reserved
  child = reserved~value
  forecast = record~currentForecast
  attempt = .WLUJobAttempt~new(child~reservationId, stage~stageId, child~reservedMicroWlu, authority~clock~nowTick, stage~expectedMicroWlu, stage~ceilingMicroWlu, forecast~forecastRevision, forecast~status, snap~standbyId, stage~rateCardId, stage~rateCardVersion)
  ignore = record~addAttempt(attempt)
  ignore = record~appendRouteEvent(authority~clock~nowTick, .WLUJobRouteEventType~STAGE_RESERVED, stage~stageId, "", child~reservationId, 0, 0, .false, stage~expectedMicroWlu, stage~ceilingMicroWlu, forecast~forecastRevision, forecast~status, snap~standbyId, "", "", stage~rateCardId, stage~rateCardVersion, keyRing)
  if \standby~promote(child~reservationId) then do
    rollback = authority~release(child)
    if \rollback~ok then return .WLUResult~failure("WLU_STANDBY_PROMOTION_ROLLBACK_FAILED", "standby state could not be promoted and execution reservation could not be rolled back")
    ignore = record~closeAttempt(child~reservationId, 0)
    ignore = record~appendRouteEvent(authority~clock~nowTick, .WLUJobRouteEventType~STAGE_RELEASED, attempt~stageId, "", child~reservationId, 0, 0, .false, attempt~stageExpectedMicroWlu, attempt~stageCeilingMicroWlu, attempt~forecastRevisionAtStart, attempt~forecastStatusAtStart, attempt~standbyId, "PROMOTION_ROLLBACK", "", attempt~rateCardId, attempt~rateCardVersion, keyRing)
    return .WLUResult~failure("WLU_STANDBY_PROMOTION_ROLLBACK", "execution reservation was rolled back because standby state could not be promoted")
  end
  freshLease = record~refreshProof(keyRing)
  promoted = standby~refreshProof(keyRing)
  return .WLUResult~success(.array~of(freshLease, child, promoted), "standby promoted to hard execution reservation")

::method releaseStandby public protected
  expose keyRing
  use strict arg lease, standbyLease
  guard on
  validated = self~validateLease(lease)
  if \validated~ok then return validated
  record = validated~value
  standbyResult = self~validateStandby(record, standbyLease)
  if \standbyResult~ok then return standbyResult
  standby = standbyResult~value
  snap = standby~snapshot
  if snap~state \= .WLUJobStandbyState~ACTIVE then return .WLUResult~failure("WLU_STANDBY_NOT_ACTIVE", snap~state)
  if \standby~release then return .WLUResult~failure("WLU_STANDBY_NOT_ACTIVE", "standby could not be released")
  return .WLUResult~success(standby~refreshProof(keyRing), "standby released; no hard WLU counters changed")


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

::method reserveStage public protected
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
  reserved = authority~reserveDemand(record~identity, stage~scope, stage~demand, ttlSeconds, childRequestId, stage~rateCardId, stage~rateCardVersion)
  if \reserved~ok then return reserved
  child = reserved~value
  existingAttempt = record~attempt(child~reservationId)
  if existingAttempt \== .nil then do
    if existingAttempt~stageId \= stage~stageId then return .WLUResult~failure("WLU_JOB_IDEMPOTENCY_CONFLICT", "replayed child reservation belongs to a different stage")
    if \existingAttempt~active then return .WLUResult~failure("WLU_JOB_STAGE_NOT_ACTIVE", "idempotent child reservation is already closed")
    return .WLUResult~success(.array~of(record~snapshot, child), "idempotent job-stage replay")
  end
  forecast = record~currentForecast
  attempt = .WLUJobAttempt~new(child~reservationId, stage~stageId, child~reservedMicroWlu, authority~clock~nowTick, stage~expectedMicroWlu, stage~ceilingMicroWlu, forecast~forecastRevision, forecast~status, "", stage~rateCardId, stage~rateCardVersion)
  ignore = record~addAttempt(attempt)
  ignore = record~appendRouteEvent(authority~clock~nowTick, .WLUJobRouteEventType~STAGE_RESERVED, stage~stageId, "", child~reservationId, 0, 0, .false, stage~expectedMicroWlu, stage~ceilingMicroWlu, forecast~forecastRevision, forecast~status, "", "", "", stage~rateCardId, stage~rateCardVersion, keyRing)
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

::method settleStage public protected
  use strict arg lease, reservation, actualMicroWlu = .nil
  result = self~settleStageInternal(lease, reservation, actualMicroWlu, 0, .false, "SETTLED", "")
  if \result~ok then return result
  return .WLUResult~success(result~value[1])

::method settleStageBreakdown public protected
  use strict arg lease, reservation, actualWorkMicroWlu, actualHandoffMicroWlu = 0, outcomeCode = "SETTLED", evidenceRef = ""
  return self~settleStageInternal(lease, reservation, actualWorkMicroWlu, actualHandoffMicroWlu, .true, outcomeCode, evidenceRef)

::method settleStageInternal private
  expose authority keyRing
  use strict arg lease, reservation, actualWorkMicroWlu = .nil, actualHandoffMicroWlu = 0, breakdownKnown = .false, outcomeCode = "SETTLED", evidenceRef = ""
  guard on
  validated = self~validatePair(lease, reservation)
  if \validated~ok then return validated
  record = validated~value[1]
  attempt = validated~value[2]
  if actualWorkMicroWlu == .nil then return .WLUResult~failure("WLU_JOB_ACTUAL_REQUIRED", "job-budget settlement requires actual WLU so the parent budget can be updated deterministically")
  ignore = .WLUUnits~assertMicro(actualWorkMicroWlu)
  ignore = .WLUUnits~assertMicro(actualHandoffMicroWlu)
  actualMicroWlu = actualWorkMicroWlu + actualHandoffMicroWlu
  if actualMicroWlu > attempt~reservedMicroWlu then return .WLUResult~failure("WLU_SETTLEMENT_EXCEEDS_RESERVATION", "top up the stage before settling larger actual work")
  outcomeCode = outcomeCode~string~strip
  if outcomeCode = "" then outcomeCode = "SETTLED"
  evidenceRef = evidenceRef~string~strip
  settled = authority~settle(reservation, actualMicroWlu)
  if \settled~ok then return settled
  ignore = record~closeAttempt(reservation~reservationId, actualMicroWlu)
  event = record~appendRouteEvent(authority~clock~nowTick, .WLUJobRouteEventType~STAGE_SETTLED, attempt~stageId, "", reservation~reservationId, actualWorkMicroWlu, actualHandoffMicroWlu, breakdownKnown, attempt~stageExpectedMicroWlu, attempt~stageCeilingMicroWlu, attempt~forecastRevisionAtStart, attempt~forecastStatusAtStart, attempt~standbyId, outcomeCode, evidenceRef, attempt~rateCardId, attempt~rateCardVersion, keyRing)
  freshLease = record~refreshProof(keyRing)
  return .WLUResult~success(.array~of(freshLease, event))

::method releaseStage
  expose authority keyRing
  use strict arg lease, reservation
  guard on
  validated = self~validatePair(lease, reservation)
  if \validated~ok then return validated
  record = validated~value[1]
  attempt = validated~value[2]
  /* Ask the core authority for authoritative observed consumption before the
   * reservation is closed.  release() refunds only the unused remainder, so
   * the logical parent must retain exactly the same incurred work. */
  usage = authority~reservationConsumed(reservation)
  if \usage~ok then return usage
  actualMicroWlu = usage~value
  released = authority~release(reservation)
  if \released~ok then return released
  ignore = record~closeAttempt(reservation~reservationId, actualMicroWlu)
  ignore = record~appendRouteEvent(authority~clock~nowTick, .WLUJobRouteEventType~STAGE_RELEASED, attempt~stageId, "", reservation~reservationId, actualMicroWlu, 0, .false, attempt~stageExpectedMicroWlu, attempt~stageCeilingMicroWlu, attempt~forecastRevisionAtStart, attempt~forecastStatusAtStart, attempt~standbyId, "RELEASED", "", attempt~rateCardId, attempt~rateCardVersion, keyRing)
  freshLease = record~refreshProof(keyRing)
  return .WLUResult~success(freshLease)


::method validateStandby private
  expose standbys keyRing
  use strict arg jobRecord, standbyLease
  if standbyLease == .nil | \standbyLease~isA(.WLUJobStandbyLease) then return .WLUResult~failure("WLU_STANDBY_LEASE_REQUIRED", "authenticated WLUJobStandbyLease required")
  standby = standbys[standbyLease~standbyId]
  if standby == .nil then return .WLUResult~failure("WLU_STANDBY_NOT_FOUND", standbyLease~standbyId)
  if standby~jobId \= jobRecord~jobId then return .WLUResult~failure("WLU_STANDBY_NOT_OWNED", "standby belongs to a different logical job")
  if \keyRing~verify(standbyLease~canonicalText, standbyLease~proof) then return .WLUResult~failure("WLU_STANDBY_PROOF_INVALID", "standby authentication failed")
  current = standby~snapshot
  if standbyLease~revision \= current~revision | standbyLease~state \= current~state | standbyLease~promotedReservationId \= current~promotedReservationId then return .WLUResult~failure("WLU_STANDBY_STALE", "standby lease is no longer current")
  return .WLUResult~success(standby)


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
