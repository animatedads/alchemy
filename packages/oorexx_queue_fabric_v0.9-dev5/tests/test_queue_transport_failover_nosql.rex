transport = .QueueSocketClientTransport~new("admin")
ignore = transport~registerEndpoint("QM.B", "127.0.0.1", 20001, "wire", "k1", "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff")
ignore = transport~registerFailoverEndpoint("QM.B", "127.0.0.1", 20002, "wire", "k2", "ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100")
manager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
fabric = .QueueChannelFabric~new("QM.A", manager, transport, "admin")
adapter = .QueueTransportNoSQLAdapter~new(transport, fabric)
q = adapter~query("admin", "SELECT endpoint_id,endpoint_order,remote_manager,key_id,health_attempt_count FROM mq_transport_endpoints WHERE remote_manager='QM.B'")
call assert q~status = .Error~SUCCESS, "endpoint projection query"
call assert q~rows~items = 2, "both failover endpoints projected"
call assert q~rows[1]["endpoint_order"] + q~rows[2]["endpoint_order"] = 3, "ordered endpoint positions projected"
call assert q~rows[1]["endpoint_id"] \= q~rows[2]["endpoint_id"], "endpoint identity is unique"
call assert q~rows[1]~values~hasIndex("key_id"), "key id is observable"
call assert \q~rows[1]~values~hasIndex("key_hex"), "HMAC key material is not projected"
say "OBJECT QUEUE FABRIC V0.9 FAILOVER NOSQL: OK"
exit 0
assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return
::requires "ObjectQueueTransportNoSQL.cls"
