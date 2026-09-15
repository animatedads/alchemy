verifier = .RuntimePinnedSourceVerifier~new
kernel = .RuntimeKernel~new(verifier)

call assert .RuntimeRegistryBuild~RELEASE = "0.14", "Runtime Registry v0.14 active"

artifact1 = makeArtifact("1", "jms-bridge:v01dev4:rr:1")
call must verifier~pin(artifact1~artifactId, artifact1~sourceLines), "pin bridge fixture 1"
stage1 = kernel~stage("test", artifact1)
call must stage1, "stage bridge fixture 1"
gen1 = stage1~value
call assert gen1~state = "READY", "stage runs runtimePrepare/selfTest"
call must kernel~activate("test", "jms.queue.bridge", gen1~generationId), "activate bridge fixture 1"
call assert gen1~state = "ACTIVE", "generation active"
lease1Result = kernel~acquire("test", "jms.queue.bridge")
call must lease1Result, "acquire bridge fixture 1"
lease1 = lease1Result~value
call assert lease1~module~bridgeState = .JMSBridgeState~RUNNING, "Runtime Registry called runtimeStart"

artifact2 = makeArtifact("2", "jms-bridge:v01dev4:rr:2")
call must verifier~pin(artifact2~artifactId, artifact2~sourceLines), "pin bridge fixture 2"
stage2 = kernel~stage("test", artifact2)
call must stage2, "stage bridge fixture 2"
gen2 = stage2~value
call must kernel~activate("test", "jms.queue.bridge", gen2~generationId), "activate bridge fixture 2"
call assert gen1~state = "DRAINING", "replacement begins old generation drain"
call assert gen2~state = "ACTIVE", "replacement generation active"
call assert lease1~module~bridgeState = .JMSBridgeState~QUIESCED, "Runtime Registry called runtimeQuiesce"
call must lease1~release, "release old lease"
call must kernel~collectRetired, "collect retired generation"
call assert gen1~state = "RETIRED", "old generation retired"

lease2Result = kernel~acquire("test", "jms.queue.bridge")
call must lease2Result, "acquire bridge fixture 2"
lease2 = lease2Result~value
call assert lease2~module~bridgeState = .JMSBridgeState~RUNNING, "new bridge running"
call must lease2~release, "release new lease"
call must kernel~releaseGeneration(gen1~generationId), "release old generation objects"
call assert gen1~state = "RELEASED", "old generation runtimeStop/release completed"

terminal = makeTerminalArtifact("jms-bridge:v01dev4:rr:terminal")
call must verifier~pin(terminal~artifactId, terminal~sourceLines), "pin terminal fixture"
terminalStage = kernel~stage("test", terminal)
call must terminalStage, "stage terminal fixture"
terminalGen = terminalStage~value
call must kernel~activate("test", "jms.queue.bridge", terminalGen~generationId), "activate terminal fixture"
call must kernel~collectRetired, "collect second bridge generation"
call assert gen2~state = "RETIRED", "second bridge generation retired"
call must kernel~releaseGeneration(gen2~generationId), "release second bridge generation"
call assert gen2~state = "RELEASED", "second bridge runtimeStop/release completed"

say "JMS BRIDGE RUNTIME REGISTRY V0.14 PASS"
exit 0

makeArtifact: procedure
  use arg label, artifactId
  lines = .array~new
  lines~append("::class RuntimeJMSBridgeFixture public")
  lines~append("::method init")
  lines~append("  expose service")
  lines~append('  manager = .ObjectQueueManager~new')
  lines~append('  ignore = manager~createQueue("IN", "TEMPORARY", "DEFAULT", 0, "bridge")')
  lines~append('  provider = .FakeJMSProvider~new')
  lines~append('  config = .JMSBridgeConfig~new("registry-' || label || '", "GENERIC", "", "", "remote", "", "", "", "", "IN", "", "bridge", .false)')
  lines~append("  service = .JMSQueueBridgeService~new(manager, provider, config)")
  lines~append("::method runtimePrepare")
  lines~append("  expose service")
  lines~append("  use arg context")
  lines~append("  return service~runtimePrepare(context)")
  lines~append("::method runtimeSelfTest")
  lines~append("  expose service")
  lines~append("  return service~runtimeSelfTest")
  lines~append("::method runtimeStart")
  lines~append("  expose service")
  lines~append("  return service~runtimeStart")
  lines~append("::method runtimeQuiesce")
  lines~append("  expose service")
  lines~append("  return service~runtimeQuiesce")
  lines~append("::method runtimeStop")
  lines~append("  expose service")
  lines~append("  return service~runtimeStop")
  lines~append("::method bridgeState")
  lines~append("  expose service")
  lines~append("  return service~state")
  lines~append('::requires "JMSQueueBridge.cls"')
  lines~append('::requires "FakeJMSProvider.cls"')
  return .RuntimeArtifact~new("jms.queue.bridge", "SERVICE", "0.1-dev4+" || label, artifactId, "RuntimeJMSBridgeFixture", lines)

makeTerminalArtifact: procedure
  use arg artifactId
  lines = .array~new
  lines~append("::class RuntimeJMSBridgeTerminal public")
  lines~append("::method runtimePrepare")
  lines~append("  use arg context")
  lines~append("  return .true")
  lines~append("::method runtimeSelfTest")
  lines~append("  return .true")
  lines~append("::method runtimeStart")
  lines~append("  return .true")
  lines~append("::method runtimeQuiesce")
  lines~append("  return .true")
  lines~append("::method runtimeStop")
  lines~append("  return .true")
  return .RuntimeArtifact~new("jms.queue.bridge", "SERVICE", "0.1-dev4+terminal", artifactId, "RuntimeJMSBridgeTerminal", lines)

must: procedure
  use arg outcome, label
  if outcome == .nil then do
    say "ASSERT FAILED:" label "nil outcome"
    exit 1
  end
  if \outcome~ok then do
    say "ASSERT FAILED:" label outcome~code outcome~detail
    exit 1
  end
return

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERT FAILED:" label
    exit 1
  end
return

::requires "RuntimeRegistry.cls"
::requires "JMSQueueBridge.cls"
::requires "FakeJMSProvider.cls"
