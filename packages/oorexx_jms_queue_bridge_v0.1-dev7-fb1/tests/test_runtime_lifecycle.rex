parse source . . here
root = filespec("L", here)
call directory root
qm = .ObjectQueueManager~new
call assert qm~createQueue("IN", "TEMPORARY", "DEFAULT", 0, "bridge")~ok, "queue create"
provider = .FakeJMSProvider~new
config = .JMSBridgeConfig~new("runtime", "GENERIC", "", "", "remote", "", "", "", "", "IN", "", "bridge", .false)
bridge = .JMSQueueBridgeService~new(qm, provider, config)
call assert bridge~runtimePrepare~ok, "prepare"
call assert bridge~runtimeSelfTest~ok, "self test"
call assert bridge~runtimeStart~ok, "start"
call assert bridge~state = .JMSBridgeState~RUNNING, "running"
call assert bridge~runtimeQuiesce~ok, "quiesce"
call assert bridge~state = .JMSBridgeState~QUIESCED, "quiesced"
call assert bridge~runtimeStop~ok, "stop"
call assert bridge~state = .JMSBridgeState~STOPPED, "stopped"
say "JMS BRIDGE RUNTIME LIFECYCLE PASS 9"
exit 0
assert: procedure
  use arg ok, label
  if \ok then do
    say "FAIL:" label
    exit 1
  end
return
::requires "JMSQueueBridge.cls"
::requires "FakeJMSProvider.cls"
