manager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
fabric = .QueueChannelFabric~new("A", manager, .QueueInProcessTransport~new, "admin")
service = .QueueBrokerService~new("lifecycle", fabric, .nil, .nil, "admin", 0.01)
call assert service~state = .QueueBrokerServiceState~NEW, "initial new"
call assert service~runtimePrepare(.directory~new), "runtimePrepare"
call assert service~state = .QueueBrokerServiceState~PREPARED, "prepared state"
call assert service~runtimeSelfTest, "self-test"
call assert service~runtimeStart, "runtimeStart"
call assert service~state = .QueueBrokerServiceState~RUNNING, "running state"
call SysSleep 0.03
call assert service~runtimeQuiesce, "runtimeQuiesce"
service~waitForStop(.false)
call assert service~state = .QueueBrokerServiceState~QUIESCED, "drained to quiesced"
call assert service~runtimeStop, "runtimeStop"
call assert service~state = .QueueBrokerServiceState~STOPPED, "stopped state"
say "OBJECT QUEUE FABRIC V0.9 BROKER LIFECYCLE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return

::requires "ObjectQueueBrokerService.cls"
