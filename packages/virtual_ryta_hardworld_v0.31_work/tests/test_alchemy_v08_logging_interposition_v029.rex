say 'RYTA ALCHEMY V0.8 / LOGGING V0.5 INTERPOSITION V0.29 START'

ring = .CryptoMacKeyRing~new
ring~addKey('ryta-v029', '00112233445566778899aabbccddeeff')
sealer = .AlchemyMacSealer~new(ring)
authority = .AlchemyCapabilityAuthority~new(ring)
options = .directory~new
options['SEALER'] = sealer
options['CAPABILITY_AUTHORITY'] = authority

/* Baseline business result used to prove both interposition orders are
   observational infrastructure rather than decision authority. */
baselineWorld = .RYTAWorldState~new('V029-BASELINE')
baseline = .VirtualRYTA~new(options)~evaluate(baselineWorld)

/* ------------------------------------------------------------------
 * Logging first -> Alchemy joins the existing generic coordinator.
 * ------------------------------------------------------------------ */
ryta = .RYTALoggedVirtualRYTA~new(options)
service = .LogService~new('ryta-v029-logging-first')
mem = .LogMemoryTarget~new('memory', .Log~INTERNAL)
service~addTarget(mem)
service~registerMethod(ryta, 'evaluate', .Log~INTERNAL)
rule = .LogRule~new('ryta-evaluate-logging-first', 'virtual_ryta_hardworld', -
  'RYTALoggedVirtualRYTA', 'evaluate', .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, -
  .LogConditionAlways~new, .array~of('memory'), .array~of(.Log~ENTRY, .Log~EXIT))
service~addRule(rule)

status = ryta~methodInterpositionStatus('evaluate')
call AssertEqual 1, status['physical_wrappers'], 'Logging owns one physical wrapper first'
call AssertEqual 1, status['methods'][1]['provider_count'], 'one Logging provider before Alchemy'
call AssertTrue ryta~instanceMethod('EVALUATE')~isGuarded, 'Logging wrapper preserves guarded RYTA serialization'

installed = ryta~instrumentMethod('EVALUATE', .false)
call AssertTrue installed~ok, 'Alchemy joins Logging coordinator'
call AssertEqual 'TELEMETRY_COORDINATED', installed~code, 'coordinated install result'
status = ryta~methodInterpositionStatus('evaluate')
call AssertEqual 1, status['physical_wrappers'], 'still one physical wrapper'
call AssertEqual 2, status['methods'][1]['provider_count'], 'Logging and Alchemy share wrapper'

world = .RYTAWorldState~new('V029-BASELINE')
observed = ryta~evaluate(world)
call AssertDecisionEqual baseline, observed, 'logging-first decision unchanged'
call AssertEqual 2, mem~count, 'Logging receives entry and exit'

base = ryta~alchemyBaseState
call AssertTrue base['cooperative_interposition_available'], 'Alchemy v0.8 sees cooperative coordinator'
call AssertEqual 1, base['coordinated_instrumentation_count'], 'one coordinated Alchemy method'
call AssertEqual '0.8', ryta~alchemyConstructionProvenance['base_version'], 'Alchemy v0.8 construction provenance'

cap = authority~issue('ryta-v029-auditor', ryta~alchemyObjectId, 'SEALEDINTROSPECTION', 'INTROSPECT:CUSTOMER')
sealed = ryta~sealedIntrospection('CUSTOMER', cap)
call AssertTrue sealer~verify(sealed), 'sealed introspection verifies'
exec = sealed~payload['execution_provenance']
record = FindExecution(exec, 'EVALUATE')
call AssertTrue record \== .nil, 'Alchemy execution record retained'
call AssertEqual 'SUCCESS', record['outcome'], 'Alchemy outcome preserved'
call AssertEqual 1, record['argument_count'], 'bounded argument count retained'
call AssertTrue \record~hasIndex('arguments'), 'Alchemy does not copy raw world argument'

removed = ryta~uninstrumentMethod('EVALUATE')
call AssertTrue removed~ok, 'Alchemy provider withdraws independently'
call AssertEqual 'TELEMETRY_COORDINATED_REMOVED', removed~code, 'coordinated provider removal'
status = ryta~methodInterpositionStatus('evaluate')
call AssertEqual 1, status['physical_wrappers'], 'Logging wrapper remains after Alchemy withdrawal'
call AssertEqual 1, status['methods'][1]['provider_count'], 'only Logging provider remains'

before = mem~count
again = ryta~evaluate(.RYTAWorldState~new('V029-BASELINE'))
call AssertDecisionEqual baseline, again, 'Logging-only decision unchanged'
call AssertEqual before + 2, mem~count, 'Logging remains active after Alchemy withdrawal'
service~disableRule('ryta-evaluate-logging-first')
call AssertEqual 0, ryta~methodInterpositionStatus('evaluate')['physical_wrappers'], 'final Logging release restores plain method'

/* ------------------------------------------------------------------
 * Alchemy first -> Logging wraps the retained Alchemy object method.
 * Alchemy must refuse to tear out its direct layer while Logging owns
 * the outer physical wrapper. After Logging releases, Alchemy may release.
 * ------------------------------------------------------------------ */
ryta2 = .RYTALoggedVirtualRYTA~new(options)
installed2 = ryta2~instrumentMethod('EVALUATE', .false)
call AssertTrue installed2~ok, 'Alchemy direct wrapper installs first'
call AssertEqual 'TELEMETRY_INSTALLED', installed2~code, 'direct install result'
call AssertTrue ryta2~instanceMethod('EVALUATE')~isGuarded, 'Alchemy direct wrapper preserves guarded RYTA serialization'

service2 = .LogService~new('ryta-v029-alchemy-first')
mem2 = .LogMemoryTarget~new('memory2', .Log~INTERNAL)
service2~addTarget(mem2)
service2~registerMethod(ryta2, 'evaluate', .Log~INTERNAL)
rule2 = .LogRule~new('ryta-evaluate-alchemy-first', 'virtual_ryta_hardworld', -
  'RYTALoggedVirtualRYTA', 'evaluate', .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, -
  .LogConditionAlways~new, .array~of('memory2'), .array~of(.Log~ENTRY, .Log~EXIT))
service2~addRule(rule2)

run2 = ryta2~evaluate(.RYTAWorldState~new('V029-BASELINE'))
call AssertDecisionEqual baseline, run2, 'alchemy-first decision unchanged'
call AssertEqual 2, mem2~count, 'Logging sees Alchemy-first call'

blocked = ryta2~uninstrumentMethod('EVALUATE')
call AssertTrue \blocked~ok, 'Alchemy refuses destructive removal under outer coordinator'
call AssertEqual 'TELEMETRY_EXTERNAL_INTERPOSITION_ACTIVE', blocked~code, 'fail-safe removal code'

run3 = ryta2~evaluate(.RYTAWorldState~new('V029-BASELINE'))
call AssertDecisionEqual baseline, run3, 'refused removal leaves decision path intact'
call AssertEqual 4, mem2~count, 'Logging remains intact after refused Alchemy removal'

service2~disableRule('ryta-evaluate-alchemy-first')
removed2 = ryta2~uninstrumentMethod('EVALUATE')
call AssertTrue removed2~ok, 'Alchemy direct layer removable after Logging releases'
call AssertEqual 'TELEMETRY_REMOVED', removed2~code, 'direct removal after outer release'
plain = ryta2~evaluate(.RYTAWorldState~new('V029-BASELINE'))
call AssertDecisionEqual baseline, plain, 'plain decision unchanged after all observability removed'

say '  logging_first=PASS physical_wrapper=1 providers=2'
say '  alchemy_first=PASS fail_safe_release=PASS'
say '  authority_semantics=UNCHANGED guarded_serialization=PRESERVED raw_alchemy_arguments=NOT_RETAINED'
say 'RYTA ALCHEMY V0.8 / LOGGING V0.5 INTERPOSITION V0.29: OK'
exit 0

::routine FindExecution
  use strict arg evidence, methodName
  do candidate over evidence['records']
    if candidate['method'] = methodName~translate then return candidate
  end
  return .nil

::routine AssertDecisionEqual
  use strict arg expected, actual, label
  call AssertEqual expected~state, actual~state, label || ' state'
  call AssertEqual expected~winningRule, actual~winningRule, label || ' winning rule'
  call AssertEqual expected~winningTier, actual~winningTier, label || ' winning tier'
  call AssertEqual expected~executionStatus, actual~executionStatus, label || ' execution status'
  call AssertEqual expected~outputs~items, actual~outputs~items, label || ' output count'
  return 0

::routine AssertTrue
  use strict arg value, label
  if \value then raise syntax 88.900 array('ASSERT TRUE FAILED: ' || label)
  return 0

::routine AssertEqual
  use strict arg expected, actual, label
  if expected \== actual then raise syntax 88.900 array('ASSERT EQUAL FAILED: ' || label || ' expected=' || expected || ' actual=' || actual)
  return 0

::requires '../integration/RYTALoggingIntegration.cls'
::requires 'AlchemyEvidence.cls'
::requires 'AlchemySecurity.cls'
