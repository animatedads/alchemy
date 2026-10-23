/* Qualifies both halves of the optional integration:
 * 1. planner activity emits the common instrumentation.mesh/0.1 vocabulary;
 * 2. live collector health influences preference order but never admissibility.
 */
identity = .InstrumentationCodec~identity('alchemy', 'generalized-compute-intentions', 'planner-1', 'node-a', '', 'COMPUTE_INTENTIONS')
telemetry = .GeneralizedComputeIntentionsInstrumentation~new(identity)

healthyResource = .ObservedResource~new('healthy-gpu', 'instrumentation://alchemy/compute/healthy@node-gpu')
degradedResource = .ObservedResource~new('degraded-gpu', 'instrumentation://alchemy/compute/degraded@node-gpu')
resources = .array~of(degradedResource, healthyResource)

collector = .InstrumentationCollector~new(8)
call publishHealth collector, healthyResource~semanticRef, 'healthy', .InstrumentationHealth~HEALTHY, 1
call publishHealth collector, degradedResource~semanticRef, 'degraded', .InstrumentationHealth~DEGRADED, 1

observation = .ComputeInstrumentationAdvisoryAdapter~new(collector)
allow = .AllowAdapter~new('authority')
planner = .GeneralizedComputeIntentionProvider~new(.ComputeAdapter~new(resources), allow, allow, allow, observation)
instrumented = .InstrumentedGeneralizedComputeIntentionProvider~new(planner, telemetry)
workload = .Object~new

route = instrumented~planAdmittance(workload)
call assertEqual 'READY', route~state, 'route state'
call assertTrue route~candidates[1]~isAdmissible, 'degraded observation cannot revoke authoritative admissibility'
call assertTrue route~candidates[2]~isAdmissible, 'healthy candidate admissible'
call assertTrue route~preferredCandidate~resource == healthyResource, 'healthy observation influences preference'
call assertEqual .InstrumentationHealth~DEGRADED, route~candidates[1]~observationAssessment~health, 'degraded health retained'
call assertEqual .InstrumentationHealth~HEALTHY, route~candidates[2]~observationAssessment~health, 'healthy health retained'

snap = telemetry~snapshot('2026-10-08T10:00:00Z')
call assertEqual 'instrumentation.snapshot/1', snap['schema'], 'snapshot schema'
call assertEqual 'instrumentation.mesh/0.1', snap['api'], 'instrumentation API'
call assertEqual 'instrumentation://alchemy/generalized-compute-intentions/planner-1@node-a', snap['semantic_ref'], 'stable semantic ref'
call assertSample snap, .InstrumentationVocabulary~REQUEST_ACCEPTED_TOTAL, 1
call assertSample snap, .InstrumentationVocabulary~REQUEST_COMPLETED_TOTAL, 1
call assertSample snap, 'compute.intentions.plan.ready.total', 1
call assertSample snap, 'compute.intentions.candidates.discovered', 2
call assertSample snap, 'compute.intentions.candidates.admissible', 2

handoff = instrumented~prepareAdmission(workload)
call assertTrue handoff \== .nil, 'handoff prepared'
snap2 = telemetry~snapshot('2026-10-08T10:00:01Z')
call assertSample snap2, 'compute.intentions.handoff.prepared.total', 1

say 'PASS Instrumentation Mesh observation and telemetry integration'
exit 0

publishHealth: procedure
  use arg collector, semanticRef, instanceId, health, sequence
  identity = .InstrumentationCodec~identity('alchemy', 'compute', instanceId, 'node-gpu', '', 'COMPUTE_RESOURCE')
  /* Test identity must match the resource semantic ref exactly. */
  parse var semanticRef 'instrumentation://' estate '/' service '/' instance '@' node
  identity = .InstrumentationCodec~identity(estate, service, instance, node, '', 'COMPUTE_RESOURCE')
  snapshot = .InstrumentationCodec~snapshot(identity, health, .array~new, '2026-10-08T09:59:00Z', .array~new, sequence)
  publication = .InstrumentationCodec~publication('pub-' || instanceId || '-' || sequence, 'publisher-' || instanceId, sequence, .array~of(snapshot), '2026-10-08T09:59:00Z')
  receipt = collector~accept(publication)
  if receipt['status'] \= 'OK' then do
    say 'FAIL unable to seed collector' receipt['code']
    exit 1
  end
  return

assertSample: procedure
  use arg snapshot, name, expected
  do sample over snapshot['samples']
    if sample['name'] = name then do
      if sample['value'] \= expected then do
        say 'FAIL metric' name 'expected='expected 'actual='sample['value']
        exit 1
      end
      return
    end
  end
  say 'FAIL missing metric' name
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
