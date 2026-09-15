/*
 * WLURouteAnalytics v0.1
 *
 * Read-only cross-job statistics over verified durable WLU route evidence.
 * Analytics never grants entitlement, opens jobs, reserves capacity, mutates
 * hierarchy state, or invokes providers.  Every report preserves its time
 * window, matched-job count, raw sample count and caller-declared minimum
 * sample threshold so downstream reasoning can distinguish evidence from a
 * statistically under-sized anecdote.
 */

::options digits 30

::class WLURouteAnalyticsBuild public
::constant VERSION "0.1"
::constant API_VERSION "work.load.units.route-analytics/0.1"
::constant DEFAULT_MINIMUM_SAMPLES 30

::class WLURouteStatisticsMath public

::method basisPoints class
  use strict arg numerator, denominator
  if denominator <= 0 then return 0
  return trunc((numerator * 10000) / denominator)

/* 95% Wilson score interval.  Returned values are integer basis points.
 * This is descriptive evidence only; no claim is made that route observations
 * are independent, identically distributed, or free of selection effects. */
::method wilson95BasisPoints class
  use strict arg positives, samples
  numeric digits 30
  if samples <= 0 then return .array~of(0, 10000)
  if positives < 0 | positives > samples then raise syntax 88.900 array("Wilson positives must be between zero and sample count")
  p = positives / samples
  z = 1.96
  z2 = z * z
  denom = 1 + (z2 / samples)
  centre = (p + (z2 / (2 * samples))) / denom
  radicand = (p * (1 - p) / samples) + (z2 / (4 * samples * samples))
  margin = (z * self~sqrtDecimal(radicand)) / denom
  lower = max(0, centre - margin)
  upper = min(1, centre + margin)
  return .array~of(trunc(lower * 10000), trunc(upper * 10000))

::method sqrtDecimal class private
  use strict arg value
  numeric digits 30
  if value <= 0 then return 0
  guess = value
  if guess < 1 then guess = 1
  do i = 1 to 80
    next = (guess + (value / guess)) / 2
    if abs(next - guess) < 0.00000000000000000001 then return next
    guess = next
  end
  return guess


::class WLURouteAnalyticsSnapshot public
::attribute sourceSequence get
::attribute sourceTag get
::attribute events get

::method init
  expose sourceSequence sourceTag events
  use strict arg sourceSequence, sourceTag, events

::method eventCount
  expose events
  return events~items

::class WLURouteStageStatistics public
::attribute stageId get
::attribute windowStartTick get
::attribute windowEndTick get
::attribute minimumSamples get
::attribute verifiedEventCount get
::attribute matchedJobCount get
::attribute sampleCount get
::attribute settledCount get
::attribute releasedCount get
::attribute declaredSuccessCount get
::attribute overExpectedCount get
::attribute breakdownKnownCount get
::attribute actualMicroWlu get
::attribute knownHandoffMicroWlu get
::attribute outcomeCounts get

::method init
  expose stageId windowStartTick windowEndTick minimumSamples verifiedEventCount matchedJobCount sampleCount settledCount releasedCount declaredSuccessCount overExpectedCount breakdownKnownCount actualMicroWlu knownHandoffMicroWlu outcomeCounts
  use strict arg stageId, windowStartTick, windowEndTick, minimumSamples, verifiedEventCount, matchedJobCount, sampleCount, settledCount, releasedCount, declaredSuccessCount, overExpectedCount, breakdownKnownCount, actualMicroWlu, knownHandoffMicroWlu, outcomeCounts

::method sufficientSample
  expose sampleCount minimumSamples
  return sampleCount >= minimumSamples

::method declaredSuccessBasisPoints
  expose declaredSuccessCount sampleCount
  return .WLURouteStatisticsMath~basisPoints(declaredSuccessCount, sampleCount)

::method declaredSuccessWilson95
  expose declaredSuccessCount sampleCount
  return .WLURouteStatisticsMath~wilson95BasisPoints(declaredSuccessCount, sampleCount)

::method overExpectedBasisPoints
  expose overExpectedCount sampleCount
  return .WLURouteStatisticsMath~basisPoints(overExpectedCount, sampleCount)

::method overExpectedWilson95
  expose overExpectedCount sampleCount
  return .WLURouteStatisticsMath~wilson95BasisPoints(overExpectedCount, sampleCount)

::method averageActualMicroWlu
  expose actualMicroWlu sampleCount
  if sampleCount <= 0 then return 0
  return trunc(actualMicroWlu / sampleCount)

::method averageKnownHandoffMicroWlu
  expose knownHandoffMicroWlu breakdownKnownCount
  if breakdownKnownCount <= 0 then return 0
  return trunc(knownHandoffMicroWlu / breakdownKnownCount)

::method outcomeCount
  expose outcomeCounts
  use strict arg code
  code = code~string~strip~translate
  value = outcomeCounts[code]
  if value == .nil then return 0
  return value

::class WLURouteTransitionStatistics public
::attribute fromStageId get
::attribute toStageId get
::attribute windowStartTick get
::attribute windowEndTick get
::attribute minimumSamples get
::attribute verifiedEventCount get
::attribute matchedJobCount get
::attribute sampleCount get
::attribute reasonCounts get

::method init
  expose fromStageId toStageId windowStartTick windowEndTick minimumSamples verifiedEventCount matchedJobCount sampleCount reasonCounts
  use strict arg fromStageId, toStageId, windowStartTick, windowEndTick, minimumSamples, verifiedEventCount, matchedJobCount, sampleCount, reasonCounts

::method sufficientSample
  expose sampleCount minimumSamples
  return sampleCount >= minimumSamples

::method reasonCount
  expose reasonCounts
  use strict arg code
  code = code~string~strip~translate
  value = reasonCounts[code]
  if value == .nil then return 0
  return value

/* Long-lived read-only analytics surface.  The key ring is used only for the
 * inherited Alchemy introspection/sealing boundary; verified evidence itself
 * is read through the journal's own authentication authority. */
::class WLUJobRouteAnalytics subclass AlchemyObject public
::attribute keyRing get

::method init
  expose keyRing
  use strict arg keyRing
  if keyRing == .nil | \keyRing~isA(.WLUFastMacKeyRing) then raise syntax 88.900 array("WLU route analytics requires WLUFastMacKeyRing")
  alchemyConstruction = .WLUAlchemySupport~construction(keyRing, "WLUJobRouteAnalytics", "Read-only cross-job statistics over verified durable route evidence")
  self~init:super(alchemyConstruction[1], alchemyConstruction[2], alchemyConstruction[3])
  ignore = .WLUAlchemySupport~finishConstruction(self)
  self~registerMethodContract("VERIFIEDSNAPSHOT", "Verify a durable route journal once and pin an immutable analytics evidence cut", .array~of("JOURNAL"), "WLURESULT", .false, "AUTO", "CUSTOMER", "SENSITIVE", "READ", "NONE")
  self~registerMethodContract("STAGESTATISTICS", "Aggregate verified stage-close evidence with explicit time and sample thresholds", .array~of("JOURNAL", "STAGEID", "WINDOWSTARTTICK", "WINDOWENDTICK", "MINIMUMSAMPLES", "JOBIDS"), "WLURESULT", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("TRANSITIONSTATISTICS", "Aggregate verified fallback-transition evidence without inferring application truth", .array~of("JOURNAL", "FROMSTAGEID", "TOSTAGEID", "WINDOWSTARTTICK", "WINDOWENDTICK", "MINIMUMSAMPLES", "JOBIDS"), "WLURESULT", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerInstrumentationPoint("WLU.JOB.ROUTE.ANALYTICS", "read-only verified route-evidence aggregation boundary", .true, "ALL", "INTERNAL")

::method verifiedSnapshot
  use strict arg journal
  guard on
  if journal == .nil | \journal~isA(.WLUJobRouteFileJournal) then return .WLUResult~failure("WLU_ROUTE_ANALYTICS_JOURNAL_REQUIRED", "verified WLUJobRouteFileJournal required")
  verified = journal~readVerified
  if \verified~ok then return verified
  events = verified~value[1]
  return .WLUResult~success(.WLURouteAnalyticsSnapshot~new(events~items, verified~value[2], events))

::method stageStatistics
  use strict arg source, stageId, windowStartTick = 0, windowEndTick = 0, minimumSamples = .nil, jobIds = .nil
  guard on
  if minimumSamples == .nil then minimumSamples = .WLURouteAnalyticsBuild~DEFAULT_MINIMUM_SAMPLES
  valid = self~validateRequest(source, windowStartTick, windowEndTick, minimumSamples, jobIds)
  if \valid~ok then return valid
  stageId = stageId~string~strip~translate
  if stageId = "" then return .WLUResult~failure("WLU_ROUTE_ANALYTICS_STAGE_REQUIRED", "stage id required")
  resolved = self~resolveSnapshot(source)
  if \resolved~ok then return resolved
  events = resolved~value~events
  cohort = self~cohort(jobIds)
  jobs = .table~new
  outcomes = .directory~new
  samples = 0
  settled = 0
  released = 0
  declaredSuccess = 0
  overExpected = 0
  breakdownKnown = 0
  actual = 0
  handoff = 0
  do event over events
    if \self~inWindow(event~observedTick, windowStartTick, windowEndTick) then iterate
    if \self~inCohort(event~jobId, cohort) then iterate
    if event~stageId~translate \= stageId then iterate
    if event~eventType \= .WLUJobRouteEventType~STAGE_SETTLED & event~eventType \= .WLUJobRouteEventType~STAGE_RELEASED then iterate
    samples += 1
    jobs[event~jobId] = 1
    if event~eventType = .WLUJobRouteEventType~STAGE_SETTLED then settled += 1
    else released += 1
    actual += event~actualTotalMicroWlu
    if event~breakdownKnown then do
      breakdownKnown += 1
      handoff += event~actualHandoffMicroWlu
    end
    if event~overExpected then overExpected += 1
    outcome = event~reasonCode~string~strip~translate
    if outcome = "" then outcome = "(UNSPECIFIED)"
    current = outcomes[outcome]
    if current == .nil then current = 0
    outcomes[outcome] = current + 1
    if outcome = "SUCCESS" then declaredSuccess += 1
  end
  report = .WLURouteStageStatistics~new(stageId, windowStartTick, windowEndTick, minimumSamples, events~items, jobs~items, samples, settled, released, declaredSuccess, overExpected, breakdownKnown, actual, handoff, outcomes)
  meta = .directory~new
  meta["stage_id"] = stageId
  meta["sample_count"] = samples
  meta["minimum_samples"] = minimumSamples
  meta["sufficient_sample"] = report~sufficientSample
  self~alchemyInstrument("WLU.JOB.ROUTE.ANALYTICS", meta)
  return .WLUResult~success(report)

::method transitionStatistics
  use strict arg source, fromStageId, toStageId = "", windowStartTick = 0, windowEndTick = 0, minimumSamples = .nil, jobIds = .nil
  guard on
  if minimumSamples == .nil then minimumSamples = .WLURouteAnalyticsBuild~DEFAULT_MINIMUM_SAMPLES
  valid = self~validateRequest(source, windowStartTick, windowEndTick, minimumSamples, jobIds)
  if \valid~ok then return valid
  fromStageId = fromStageId~string~strip~translate
  toStageId = toStageId~string~strip~translate
  if fromStageId = "" then return .WLUResult~failure("WLU_ROUTE_ANALYTICS_FROM_STAGE_REQUIRED", "from stage id required")
  resolved = self~resolveSnapshot(source)
  if \resolved~ok then return resolved
  events = resolved~value~events
  cohort = self~cohort(jobIds)
  jobs = .table~new
  reasons = .directory~new
  samples = 0
  do event over events
    if event~eventType \= .WLUJobRouteEventType~TRANSITION then iterate
    if \self~inWindow(event~observedTick, windowStartTick, windowEndTick) then iterate
    if \self~inCohort(event~jobId, cohort) then iterate
    if event~fromStageId~translate \= fromStageId then iterate
    if toStageId \= "" then if event~stageId~translate \= toStageId then iterate
    samples += 1
    jobs[event~jobId] = 1
    reason = event~reasonCode~string~strip~translate
    if reason = "" then reason = "(UNSPECIFIED)"
    current = reasons[reason]
    if current == .nil then current = 0
    reasons[reason] = current + 1
  end
  report = .WLURouteTransitionStatistics~new(fromStageId, toStageId, windowStartTick, windowEndTick, minimumSamples, events~items, jobs~items, samples, reasons)
  meta = .directory~new
  meta["from_stage_id"] = fromStageId
  meta["to_stage_id"] = toStageId
  meta["sample_count"] = samples
  meta["minimum_samples"] = minimumSamples
  meta["sufficient_sample"] = report~sufficientSample
  self~alchemyInstrument("WLU.JOB.ROUTE.ANALYTICS", meta)
  return .WLUResult~success(report)

::method validateRequest private
  use strict arg source, windowStartTick, windowEndTick, minimumSamples, jobIds
  if source == .nil then return .WLUResult~failure("WLU_ROUTE_ANALYTICS_SOURCE_REQUIRED", "verified journal or analytics snapshot required")
  if \source~isA(.WLUJobRouteFileJournal) & \source~isA(.WLURouteAnalyticsSnapshot) then return .WLUResult~failure("WLU_ROUTE_ANALYTICS_SOURCE_REQUIRED", "verified journal or analytics snapshot required")
  if \datatype(windowStartTick, "W") | windowStartTick < 0 then return .WLUResult~failure("WLU_ROUTE_ANALYTICS_WINDOW_INVALID", "window start must be a non-negative whole tick")
  if \datatype(windowEndTick, "W") | windowEndTick < 0 then return .WLUResult~failure("WLU_ROUTE_ANALYTICS_WINDOW_INVALID", "window end must be a non-negative whole tick")
  if windowStartTick > 0 & windowEndTick > 0 then if windowEndTick < windowStartTick then return .WLUResult~failure("WLU_ROUTE_ANALYTICS_WINDOW_INVALID", "window end precedes start")
  if \datatype(minimumSamples, "W") | minimumSamples < 1 then return .WLUResult~failure("WLU_ROUTE_ANALYTICS_THRESHOLD_INVALID", "minimum sample threshold must be a positive whole number")
  if jobIds \== .nil then do
    if \jobIds~isA(.Collection) then return .WLUResult~failure("WLU_ROUTE_ANALYTICS_COHORT_INVALID", "jobIds must be a collection when supplied")
  end
  return .WLUResult~success

::method resolveSnapshot private
  use strict arg source
  if source~isA(.WLURouteAnalyticsSnapshot) then return .WLUResult~success(source)
  return self~verifiedSnapshot(source)

::method cohort private
  use strict arg jobIds
  if jobIds == .nil then return .nil
  cohort = .table~new
  do jobId over jobIds
    value = jobId~string~strip
    if value \= "" then cohort[value] = 1
  end
  return cohort

::method inCohort private
  use strict arg jobId, cohort
  if cohort == .nil then return .true
  return cohort~hasIndex(jobId)

::method inWindow private
  use strict arg observedTick, windowStartTick, windowEndTick
  if windowStartTick > 0 then if observedTick < windowStartTick then return .false
  if windowEndTick > 0 then if observedTick > windowEndTick then return .false
  return .true

::requires "WLURouteJournal.cls"
