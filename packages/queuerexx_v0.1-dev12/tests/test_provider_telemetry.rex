facts = .QueuePlatformFacts~new(.QueuePlatformFacts~OS_LINUX, "tester", 1000, .true, .true)
collector = .QueueProviderTelemetryCollector~new(.QueueProviderRegistry~builtins, facts)
snapshot = collector~collect(.QueueProviderCategory~RUNNER)~asDirectory
call must snapshot["schema"] == .QueueSchema~PROVIDER_HEALTH, "schema"
call must snapshot["provider_count"] == 2, "provider count"
call must snapshot["overall_state"] == .QueueProviderHealthState~NAME_HEALTHY, "healthy overall"
seenDirect = .false; seenSystemd = .false
do row over snapshot["providers"]
  if row["provider"] == .DirectRunnerProvider~PROVIDER_ID then do
    seenDirect = .true
    call must row["state"] == .QueueProviderHealthState~NAME_HEALTHY, "direct healthy"
  end
  if row["provider"] == .SystemdRunnerProvider~PROVIDER_ID then do
    seenSystemd = .true
    call must row["state"] == .QueueProviderHealthState~NAME_HEALTHY, "systemd healthy"
  end
end
call must seenDirect & seenSystemd, "both runner providers present"

facts2 = .QueuePlatformFacts~new(.QueuePlatformFacts~OS_LINUX, "tester", 1000, .false, .true)
snapshot2 = .QueueProviderTelemetryCollector~new(.QueueProviderRegistry~builtins, facts2)~collect(.QueueProviderCategory~RUNNER)~asDirectory
call must snapshot2["overall_state"] == .QueueProviderHealthState~NAME_UNAVAILABLE, "unavailable systemd affects overall state"

do row over snapshot2["providers"]
  if row["provider"] == .DirectRunnerProvider~PROVIDER_ID then call must row["state"] == .QueueProviderHealthState~NAME_HEALTHY, "direct remains healthy"
  if row["provider"] == .SystemdRunnerProvider~PROVIDER_ID then call must row["state"] == .QueueProviderHealthState~NAME_UNAVAILABLE, "systemd unavailable"
end
say "PASS standardized provider health telemetry"
exit 0

must: procedure
  parse arg conditionValue, message
  if \conditionValue then do
    say "FAIL" message
    exit 1
  end
  return

::requires "QueueRexxTelemetry.cls"
