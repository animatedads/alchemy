ring = .WLUFastMacKeyRing~new
ignore = ring~addKey("active", "00112233445566778899aabbccddeeff")
authority = .WLUAuthority~new(ring)
account = .WLUAccount~new("broker-nosql", 0)
ignore = authority~addAccount(account)
ignore = authority~bindAccount("broker-N", "queue/pump/*", "broker-nosql")

manager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
call ok manager~createQueue("XMIT", "TEMPORARY", "OPS", 0, "admin"), "create xmit"
fabric = .QueueChannelFabric~new("A", manager, .QueueInProcessTransport~new, "admin")
call ok fabric~defineSenderChannel("OUT", "XMIT", "B", "IN", "admin", "wire", 0, "TEMPORARY", "admin"), "sender"
call ok fabric~startSenderChannel("OUT", "admin"), "start sender"
policy = .QueueBrokerWLUAdmission~new(authority, "broker-N", "queue", 100, 100, 0, 30, 7, 9, 2)
service = .QueueBrokerService~new("broker-N", fabric, .nil, policy, "admin", 0.1, 0.2, 2, 5)
cycle = service~pumpCycle
call assert cycle~denied = 1, "denial generates retry projection state"
adapter = .QueueBrokerServiceNoSQLAdapter~new(service)
q = adapter~query("admin", "SELECT service_name,state,denial_count,heartbeat_interval_seconds FROM mq_broker_services WHERE service_name='broker-N'")
call assert q~status = .Error~SUCCESS, "service query succeeds"
call assert q~rows~items = 1, "service row present"
call assert q~rows[1]["denial_count"] = 1, "denial count projected"
call assert q~rows[1]["heartbeat_interval_seconds"] = 5, "heartbeat interval projected"
r = adapter~query("admin", "SELECT channel_name,attempts,seconds_until FROM mq_broker_retries")
call assert r~status = .Error~SUCCESS, "retry query succeeds"
call assert r~rows~items = 1, "retry row present"
call assert r~rows[1]["channel_name"] = "OUT", "retry channel projected"
w = adapter~query("admin", "SELECT identity,scope_prefix,expected_micro_wlu,heartbeat_expected_micro_wlu,heartbeat_rate_micro_wlu_per_second FROM mq_broker_wlu")
call assert w~status = .Error~SUCCESS, "WLU query succeeds"
call assert w~rows~items = 1, "WLU row present"
call assert w~rows[1]["identity"] = "broker-N", "WLU identity projected"
call assert w~rows[1]["heartbeat_expected_micro_wlu"] = 7, "heartbeat WLU projected"
call assert w~rows[1]["heartbeat_rate_micro_wlu_per_second"] = 2, "heartbeat rate projected"
private = adapter~query("not-admin", "SELECT service_name FROM mq_broker_services")
call assert private~status = .Error~SUCCESS, "non-admin query remains valid"
call assert private~rows~items = 0, "operational rows hidden from non-admin"
say "OBJECT QUEUE FABRIC V0.9 BROKER NOSQL: OK"
exit 0

ok: procedure
  use arg result, label
  if result == .nil | \result~ok then do
    say "ASSERT FAILED:" label
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

::requires "ObjectQueueServiceNoSQL.cls"
