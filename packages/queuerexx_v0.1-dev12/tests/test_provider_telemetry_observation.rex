facts = .QueuePlatformFacts~new(.QueuePlatformFacts~OS_LINUX, "tester", 1000, .true, .true)
collector = .QueueProviderTelemetryCollector~new(.QueueProviderRegistry~builtins, facts)
bridge = .QueueProviderTelemetryObservationBridge~new(collector)
checked = .ObservationProtocol~validateObserver(bridge~source)
if \checked~ok then do; say "FAIL telemetry observation protocol" checked~code; exit 1; end
rec = bridge~publish
if rec == .nil then do; say "FAIL telemetry observation publish"; exit 1; end
if rec~kind \= .QueueObservationKind~PROVIDER_HEALTH then do; say "FAIL telemetry observation kind"; exit 1; end
if bridge~source~knownStateStatus \= .QueueProviderHealthState~NAME_HEALTHY then do; say "FAIL telemetry known state"; exit 1; end
say "PASS provider telemetry uses shared Observation v0.5 surface"
exit 0
::requires "QueueRexxTelemetryObservationV05Adapter.cls"
