verifier = .RuntimePinnedSourceVerifier~new
kernel = .RuntimeKernel~new(verifier)

artifact1 = makeArtifact("1", "queue-broker:v09dev3:rr:1")
call must verifier~pin(artifact1~artifactId, artifact1~sourceLines), "pin broker fixture 1"
stage1 = kernel~stage("test", artifact1)
call must stage1, "stage broker fixture 1"
gen1 = stage1~value
call assert gen1~state = "READY", "stage runs runtimePrepare/selfTest"
call must kernel~activate("test", "queue.broker.service", gen1~generationId), "activate broker fixture 1"
call assert gen1~state = "ACTIVE", "generation active"
lease1Result = kernel~acquire("test", "queue.broker.service")
call must lease1Result, "acquire broker fixture 1"
lease1 = lease1Result~value
call assert lease1~module~brokerState = .QueueBrokerServiceState~RUNNING, "Runtime Registry called runtimeStart"

artifact2 = makeArtifact("2", "queue-broker:v09dev3:rr:2")
call must verifier~pin(artifact2~artifactId, artifact2~sourceLines), "pin broker fixture 2"
stage2 = kernel~stage("test", artifact2)
call must stage2, "stage broker fixture 2"
gen2 = stage2~value
call must kernel~activate("test", "queue.broker.service", gen2~generationId), "activate broker fixture 2"
call assert gen1~state = "DRAINING", "replacement begins old generation drain"
call assert gen2~state = "ACTIVE", "replacement generation active"
call SysSleep 0.03
call assert lease1~module~brokerState = .QueueBrokerServiceState~QUIESCED, "Runtime Registry called runtimeQuiesce"
call must lease1~release, "release old lease"
call must kernel~collectRetired, "collect retired generation"
call assert gen1~state = "RETIRED", "old generation retired"

lease2Result = kernel~acquire("test", "queue.broker.service")
call must lease2Result, "acquire broker fixture 2"
lease2 = lease2Result~value
call assert lease2~module~brokerState = .QueueBrokerServiceState~RUNNING, "new broker service running"
call must lease2~release, "release new lease"
call must kernel~releaseGeneration(gen1~generationId), "release old generation objects"
call assert gen1~state = "RELEASED", "old generation runtimeStop/release completed"

/* Swap to a no-background terminal fixture so Runtime Registry, rather than
 * the test harness, quiesces and stops the last broker generation too. */
terminal = makeTerminalArtifact("queue-broker:v09dev3:rr:terminal")
call must verifier~pin(terminal~artifactId, terminal~sourceLines), "pin terminal fixture"
terminalStage = kernel~stage("test", terminal)
call must terminalStage, "stage terminal fixture"
terminalGen = terminalStage~value
call must kernel~activate("test", "queue.broker.service", terminalGen~generationId), "activate terminal fixture"
call SysSleep 0.03
call must kernel~collectRetired, "collect second broker generation"
call assert gen2~state = "RETIRED", "second broker generation drained and retired"
call must kernel~releaseGeneration(gen2~generationId), "release second broker generation"
call assert gen2~state = "RELEASED", "second broker runtimeStop/release completed"

say "OBJECT QUEUE FABRIC V0.9 RUNTIME REGISTRY SERVICE: OK"
exit 0

makeArtifact: procedure
  use arg label, artifactId
  lines = .array~new
  lines~append("::class RuntimeQueueBrokerFixture public")
  lines~append("::attribute label get")
  lines~append("::method init")
  lines~append("  expose service label")
  lines~append('  label = "' || label || '"')
  lines~append('  manager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")')
  lines~append('  fabric = .QueueChannelFabric~new("RR-' || label || '", manager, .QueueInProcessTransport~new, "admin")')
  lines~append('  service = .QueueBrokerService~new("registry-' || label || '", fabric, .nil, .nil, "admin", 0.005, 0.02, 0.08)')
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
  lines~append("::method brokerState")
  lines~append("  expose service")
  lines~append("  return service~state")
  lines~append('::requires "ObjectQueueBrokerService.cls"')
  return .RuntimeArtifact~new("queue.broker.service", "SERVICE", "0.9-dev3+" || label, artifactId, "RuntimeQueueBrokerFixture", lines)


makeTerminalArtifact: procedure
  use arg artifactId
  lines = .array~new
  lines~append("::class RuntimeQueueBrokerTerminal public")
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
  return .RuntimeArtifact~new("queue.broker.service", "SERVICE", "0.9-dev3+terminal", artifactId, "RuntimeQueueBrokerTerminal", lines)

must: procedure
  use arg outcome, label
  if outcome == .nil | \outcome~ok then do
    if outcome == .nil then say "ASSERT FAILED:" label "nil outcome"
    else say "ASSERT FAILED:" label outcome~code outcome~detail
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
::requires "ObjectQueueBrokerService.cls"
