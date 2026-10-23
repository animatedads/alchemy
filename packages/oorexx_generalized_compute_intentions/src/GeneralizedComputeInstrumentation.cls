/* GeneralizedComputeInstrumentation.cls
 * Optional Instrumentation Mesh adapter for Generalized Compute Intentions.
 *
 * v0.1-dev5 aligns with Instrumentation Mesh v0.1-dev7.  The planner still
 * owns no execution authority.  Mesh health, freshness and events are advisory
 * observations only and cannot make an inadmissible route admissible.
 */

::class ComputeInstrumentationObservation public
::method init
  expose semanticRef health freshness freshnessCode ageSeconds preferencePenalty reason snapshot
  use strict arg semanticRefArg, healthArg, freshnessArg='UNKNOWN', freshnessCodeArg='', ageSecondsArg=.nil, preferencePenaltyArg=0, reasonArg='', snapshotArg=.nil
  semanticRef = semanticRefArg~string
  health = healthArg~string~upper
  freshness = freshnessArg~string~upper
  freshnessCode = freshnessCodeArg~string
  ageSeconds = ageSecondsArg
  preferencePenalty = preferencePenaltyArg
  reason = reasonArg~string
  snapshot = snapshotArg

::attribute semanticRef get
::attribute health get
::attribute freshness get
::attribute freshnessCode get
::attribute ageSeconds get
::attribute preferencePenalty get
::attribute reason get
::attribute snapshot get

::method evidence
  expose semanticRef health freshness freshnessCode ageSeconds reason snapshot
  d = .directory~new
  d['source'] = 'instrumentation.mesh/0.1'
  d['semantic_ref'] = semanticRef
  d['health'] = health
  d['freshness'] = freshness
  d['freshness_code'] = freshnessCode
  if ageSeconds \== .nil then d['age_seconds'] = ageSeconds
  d['reason'] = reason
  d['snapshot'] = snapshot
  return d

::class ComputeResourceInstrumentationReference public
::method semanticRef
  use strict arg resource, workload=.nil, context=.nil
  if resource == .nil then return ''
  if resource~hasMethod('semanticRef') then return resource~semanticRef
  if resource~hasMethod('instrumentationSemanticRef') then return resource~instrumentationSemanticRef
  return ''

/* Current source health and observation freshness are deliberately separate.
 * A HEALTHY but STALE source stays HEALTHY; it merely receives an advisory
 * route-preference penalty. Missing/current-time-less evidence is neutral.
 */
::class ComputeInstrumentationAdvisoryAdapter public
::method init
  expose collector referenceAdapter freshnessAssessor
  use strict arg collectorArg, referenceAdapterArg=.nil
  if collectorArg == .nil then raise syntax 93.900 array('Instrumentation collector is required')
  collector = collectorArg
  if referenceAdapterArg == .nil then referenceAdapter = .ComputeResourceInstrumentationReference~new
  else referenceAdapter = referenceAdapterArg
  freshnessAssessor = .InstrumentationFreshnessAssessor~new(collector)

::method observe
  expose collector referenceAdapter freshnessAssessor
  use strict arg workload, resource, context=.nil
  semanticRef = referenceAdapter~semanticRef(resource, workload, context)
  if semanticRef == '' then return .ComputeInstrumentationObservation~new('', .InstrumentationHealth~UNKNOWN, 'UNKNOWN', 'NO_SEMANTIC_REF', .nil, 0, 'NO_SEMANTIC_REF')

  snapshot = collector~latestBySemanticRef(semanticRef)
  if snapshot == .nil then return .ComputeInstrumentationObservation~new(semanticRef, .InstrumentationHealth~UNKNOWN, 'UNKNOWN', 'NO_CURRENT_OBSERVATION', .nil, 0, 'NO_CURRENT_OBSERVATION')

  health = .InstrumentationCodec~value(snapshot, 'health', .InstrumentationHealth~UNKNOWN)~string~upper
  freshness = 'UNKNOWN'
  freshnessCode = 'NOW_TIME_NOT_SUPPLIED'
  ageSeconds = .nil
  nowPosix = self~contextWhole(context, 'INSTRUMENTATION_NOW_POSIX_SECONDS', .nil)
  freshWithin = self~contextWhole(context, 'INSTRUMENTATION_FRESH_WITHIN_SECONDS', 30)
  staleAfter = self~contextWhole(context, 'INSTRUMENTATION_STALE_AFTER_SECONDS', 120)
  if nowPosix \== .nil then do
    fresh = freshnessAssessor~assess(semanticRef, nowPosix, freshWithin, staleAfter)
    freshness = fresh['status']
    freshnessCode = fresh['code']
    if fresh~hasIndex('age_seconds') then ageSeconds = fresh['age_seconds']
  end

  penalty = self~penaltyForHealth(health) + self~penaltyForFreshness(freshness)
  return .ComputeInstrumentationObservation~new(semanticRef, health, freshness, freshnessCode, ageSeconds, penalty, 'CURRENT_OPERATIONAL_OBSERVATION', snapshot)

::method contextWhole private
  use strict arg context, key, defaultValue=.nil
  if context == .nil then return defaultValue
  if \context~isA(.Directory) then return defaultValue
  value = context[key]
  if value == .nil then return defaultValue
  if \datatype(value, 'W') then return defaultValue
  return value

::method penaltyForHealth private
  use strict arg health
  select
    when health = .InstrumentationHealth~HEALTHY then return 0
    when health = .InstrumentationHealth~STARTING then return 20
    when health = .InstrumentationHealth~UNKNOWN then return 25
    when health = .InstrumentationHealth~DEGRADED then return 50
    when health = .InstrumentationHealth~STOPPING then return 100
    when health = .InstrumentationHealth~STOPPED then return 100
    when health = .InstrumentationHealth~FAILED then return 100
    otherwise return 25
  end

::method penaltyForFreshness private
  use strict arg freshness
  select
    when freshness = .InstrumentationFreshness~FRESH then return 0
    when freshness = .InstrumentationFreshness~LATE then return 15
    when freshness = .InstrumentationFreshness~STALE then return 60
    /* UNKNOWN includes no authoritative publication time. Do not fabricate a
     * failure or silently punish a source simply because timing is absent. */
    otherwise return 0
  end

/* Service-local telemetry source.  Metrics remain the compact operational
 * aggregate; dev5 additionally publishes bounded instrumentation.event/1
 * occurrences for plan/handoff lifecycle.  Events never carry workload text,
 * prompts, credentials, model input/output, or arbitrary resource payloads.
 */
::class GeneralizedComputeIntentionsInstrumentation public
::method init
  expose emitter eventJournal semanticRef planSequence
  use strict arg identity
  emitter = .InstrumentationEmitter~new(identity)
  emitter~setHealth(.InstrumentationHealth~HEALTHY)
  eventJournal = .InstrumentationEventJournal~new(128)
  semanticRef = .InstrumentationCodec~semanticRef(identity)
  planSequence = 0
  self~setLastState('IDLE')
  self~setCandidateCounts(0, 0)

::method snapshot
  expose emitter
  use strict arg observedAt=''
  return emitter~snapshot(observedAt)

::method events
  expose eventJournal
  use strict arg observedAt=''
  return eventJournal~events(observedAt)

::method planningAccepted
  expose emitter eventJournal semanticRef planSequence
  use strict arg observedAt=''
  planSequence += 1
  operationId = 'plan-' || planSequence
  emitter~requestAccepted
  emitter~counterAdd('compute.intentions.plan.accepted.total', 1)
  self~setLastState('PLANNING')
  evidence = .directory~new
  evidence['sequence'] = planSequence
  eventJournal~append(.InstrumentationCodec~event( -
      'compute-intentions:' || operationId || ':STARTED', 'COMPUTE_PLAN_STARTED', -
      semanticRef, 'GENERALIZED_COMPUTE_INTENTIONS', observedAt, -
      .InstrumentationEventSeverity~INFO, '', operationId, 'planned admittance started', -
      .array~new, evidence))
  return operationId

::method planningCompleted
  expose emitter eventJournal semanticRef
  use strict arg route, operationId='', observedAt=''
  emitter~requestCompleted
  emitter~counterAdd('compute.intentions.plan.completed.total', 1)
  if route == .nil then do
    self~setLastState('UNKNOWN')
    return self
  end
  discovered = route~candidates~items
  admissible = route~admissibleCandidates~items
  self~setCandidateCounts(discovered, admissible)
  self~setLastState(route~state)
  if route~state = 'READY' then emitter~counterAdd('compute.intentions.plan.ready.total', 1)
  else if route~state = 'INFEASIBLE' then emitter~counterAdd('compute.intentions.plan.infeasible.total', 1)

  if operationId == '' then operationId = 'plan-unspecified'
  evidence = .directory~new
  evidence['state'] = route~state
  evidence['reason'] = route~reason
  evidence['candidate_count'] = discovered
  evidence['admissible_count'] = admissible
  severity = .InstrumentationEventSeverity~INFO
  if route~state = 'INFEASIBLE' then severity = .InstrumentationEventSeverity~NOTICE
  eventJournal~append(.InstrumentationCodec~event( -
      'compute-intentions:' || operationId || ':COMPLETED', 'COMPUTE_PLAN_COMPLETED', -
      semanticRef, 'GENERALIZED_COMPUTE_INTENTIONS', observedAt, severity, '', operationId, -
      route~reason, .array~new, evidence))
  return self

::method planningFailed
  expose emitter eventJournal semanticRef
  use strict arg reason='', operationId='', observedAt=''
  emitter~requestFailed
  emitter~counterAdd('compute.intentions.plan.failed.total', 1)
  self~setLastState('FAILED')
  if operationId == '' then operationId = 'plan-unspecified'
  evidence = .directory~new
  evidence['reason'] = reason
  eventJournal~append(.InstrumentationCodec~event( -
      'compute-intentions:' || operationId || ':FAILED', 'COMPUTE_PLAN_FAILED', -
      semanticRef, 'GENERALIZED_COMPUTE_INTENTIONS', observedAt, -
      .InstrumentationEventSeverity~ERROR, '', operationId, reason, .array~new, evidence))
  return self

::method handoffPrepared
  expose emitter eventJournal semanticRef
  use strict arg operationId='', observedAt=''
  emitter~counterAdd('compute.intentions.handoff.prepared.total', 1)
  if operationId == '' then operationId = 'handoff-unspecified'
  evidence = .directory~new
  evidence['authoritative_revalidation_required'] = .true
  eventJournal~append(.InstrumentationCodec~event( -
      'compute-intentions:' || operationId || ':HANDOFF_PREPARED', 'COMPUTE_HANDOFF_PREPARED', -
      semanticRef, 'GENERALIZED_COMPUTE_INTENTIONS', observedAt, -
      .InstrumentationEventSeverity~INFO, '', operationId, -
      'planned route prepared; authoritative admission revalidation required', .array~new, evidence))
  return self

::method handoffRefused
  expose emitter eventJournal semanticRef
  use strict arg reason='', operationId='', observedAt=''
  emitter~requestRejected
  emitter~counterAdd('compute.intentions.handoff.refused.total', 1)
  self~setLastState('HANDOFF_REFUSED')
  if operationId == '' then operationId = 'handoff-unspecified'
  evidence = .directory~new
  evidence['reason'] = reason
  eventJournal~append(.InstrumentationCodec~event( -
      'compute-intentions:' || operationId || ':HANDOFF_REFUSED', 'COMPUTE_HANDOFF_REFUSED', -
      semanticRef, 'GENERALIZED_COMPUTE_INTENTIONS', observedAt, -
      .InstrumentationEventSeverity~NOTICE, '', operationId, reason, .array~new, evidence))
  return self

::method setCandidateCounts private
  expose emitter
  use strict arg discovered, admissible
  emitter~gaugeSet('compute.intentions.candidates.discovered', discovered, 'count')
  emitter~gaugeSet('compute.intentions.candidates.admissible', admissible, 'count')
  return self

::method setLastState private
  expose emitter
  use strict arg state
  emitter~gaugeSet('compute.intentions.plan.state', state, 'state', .nil, .InstrumentationMetricKind~STATE)
  return self

::class InstrumentedGeneralizedComputeIntentionProvider public
::method init
  expose planner telemetry
  use strict arg plannerArg, telemetryArg
  if plannerArg == .nil then raise syntax 93.900 array('Generalized compute intention planner is required')
  if telemetryArg == .nil then raise syntax 93.900 array('Generalized compute intention telemetry source is required')
  planner = plannerArg
  telemetry = telemetryArg

::method planAdmittance
  expose planner telemetry
  use arg workload, context=.nil
  operationId = telemetry~planningAccepted
  signal on syntax name planningError
  route = planner~planAdmittance(workload, context)
  signal off syntax
  telemetry~planningCompleted(route, operationId)
  return route
planningError:
  telemetry~planningFailed(condition('D'), operationId)
  signal off syntax
  raise propagate

::method explainAdmittance
  expose planner
  use arg route
  return planner~explainAdmittance(route)

::method preferredRoute
  use arg workload, context=.nil
  return self~planAdmittance(workload, context)~preferredCandidate

::method prepareAdmission
  expose planner telemetry
  use arg workload, context=.nil
  operationId = telemetry~planningAccepted
  signal on syntax name prepareError
  route = planner~planAdmittance(workload, context)
  signal off syntax
  telemetry~planningCompleted(route, operationId)
  handoff = route~handoff
  if handoff \== .nil then telemetry~handoffPrepared(operationId)
  else telemetry~handoffRefused(route~reason, operationId)
  return handoff
prepareError:
  telemetry~planningFailed(condition('D'), operationId)
  signal off syntax
  raise propagate

::method discover
  expose planner
  use arg context=.nil
  return planner~discover(context)

::requires 'GeneralizedComputeIntentions.cls'
::requires 'InstrumentationMesh.cls'
::requires 'InstrumentationAnalysis.cls'
::requires 'InstrumentationServiceAdapters.cls'
