/* Instrumentation Mesh dev7 alignment:
 * - source health and observation freshness remain independent;
 * - stale observations influence preference only;
 * - planner/handoff lifecycle emits bounded instrumentation.event/1 records.
 */
identity = .InstrumentationCodec~identity('alchemy', 'generalized-compute-intentions', 'planner-dev5', 'node-a', '', 'COMPUTE_INTENTIONS')
telemetry = .GeneralizedComputeIntentionsInstrumentation~new(identity)

freshResource = .ObservedResource~new('fresh', 'instrumentation://alchemy/compute/fresh@node-gpu')
staleResource = .ObservedResource~new('stale', 'instrumentation://alchemy/compute/stale@node-gpu')
collector = .InstrumentationCollector~new(8)
call publishHealth collector, freshResource~semanticRef, 'fresh', .InstrumentationHealth~HEALTHY, 1, 1000
call publishHealth collector, staleResource~semanticRef, 'stale', .InstrumentationHealth~HEALTHY, 1, 800

context = .directory~new
context['INSTRUMENTATION_NOW_POSIX_SECONDS'] = 1010
context['INSTRUMENTATION_FRESH_WITHIN_SECONDS'] = 30
context['INSTRUMENTATION_STALE_AFTER_SECONDS'] = 120

observation = .ComputeInstrumentationAdvisoryAdapter~new(collector)
allow = .AllowAdapter~new('authority')
planner = .GeneralizedComputeIntentionProvider~new(.ComputeAdapter~new(.array~of(staleResource, freshResource)), allow, allow, allow, observation)
instrumented = .InstrumentedGeneralizedComputeIntentionProvider~new(planner, telemetry)

route = instrumented~planAdmittance(.Object~new, context)
call assertEqual 'READY', route~state, 'route ready'
call assertEqual .InstrumentationFreshness~STALE, route~candidates[1]~observationAssessment~freshness, 'stale freshness retained'
call assertEqual .InstrumentationHealth~HEALTHY, route~candidates[1]~observationAssessment~health, 'stale health remains healthy'
call assertEqual .InstrumentationFreshness~FRESH, route~candidates[2]~observationAssessment~freshness, 'fresh freshness retained'
call assertTrue route~preferredCandidate~resource == freshResource, 'fresh healthy resource preferred over stale healthy resource'
call assertTrue route~candidates[1]~isAdmissible, 'stale telemetry cannot revoke admissibility'

handoff = instrumented~prepareAdmission(.Object~new, context)
call assertTrue handoff \== .nil, 'handoff prepared'
call assertTrue handoff~revalidationRequired, 'handoff declares authoritative revalidation'

events = telemetry~events('2026-10-11T20:00:00Z')
call assertTrue events~items >= 5, 'planning and handoff events retained'
call assertHasEvent events, 'COMPUTE_PLAN_STARTED'
call assertHasEvent events, 'COMPUTE_PLAN_COMPLETED'
call assertHasEvent events, 'COMPUTE_HANDOFF_PREPARED'

do e over events
  call assertEqual 'instrumentation.event/1', e['schema'], 'event schema'
  call assertEqual 'GENERALIZED_COMPUTE_INTENTIONS', e['authority'], 'event authority'
end

say 'PASS Instrumentation Mesh dev7 freshness and event timeline'
exit 0

publishHealth: procedure
  use arg collector, semanticRef, instanceId, health, sequence, publishedPosix
  parse var semanticRef 'instrumentation://' estate '/' service '/' instance '@' node
  identity = .InstrumentationCodec~identity(estate, service, instance, node, '', 'COMPUTE_RESOURCE')
  snapshot = .InstrumentationCodec~snapshot(identity, health, .array~new, '2026-10-11T19:59:00Z', .array~new, sequence)
  publication = .InstrumentationCodec~publication('pub-' || instanceId || '-' || sequence, 'publisher-' || instanceId, sequence, .array~of(snapshot), '2026-10-11T19:59:00Z', publishedPosix)
  receipt = collector~accept(publication)
  if receipt['status'] \= 'OK' then do
    say 'FAIL unable to seed collector' receipt['code']
    exit 1
  end
  return

assertHasEvent: procedure
  use arg events, kind
  do e over events
    if e['kind'] = kind then return
  end
  say 'FAIL missing event' kind
  exit 1

assertEqual: procedure
  use arg expected, actual, label
  if expected \= actual then do
    say 'FAIL' label 'expected='expected 'actual='actual
    exit 1
  end
  return

assertTrue: procedure
  use arg condition, label
  if \condition then do
    say 'FAIL' label
    exit 1
  end
  return

::class ObservedResource
::method init
  expose id semanticRef
  use arg id, semanticRef
::attribute id get
::attribute semanticRef get

::class ComputeAdapter subclass ComputeIntentionAdapter
::method init
  expose resources
  use arg resources
::method discoverCandidates
  expose resources
  use arg workload, context=.nil
  return resources
::method assess
  use arg workload, resource, context=.nil
  return .IntentionAssessment~new(.true, 'compute', 'CAPABLE', resource)

::class AllowAdapter
::method init
  expose authority
  use arg authority
::method assess
  expose authority
  use arg workload, resource, context=.nil
  return .IntentionAssessment~new(.true, authority, 'ALLOW', resource)

::requires '../src/GeneralizedComputeInstrumentation.cls'
