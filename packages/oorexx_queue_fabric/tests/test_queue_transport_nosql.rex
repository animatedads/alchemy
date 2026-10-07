assertions = 0
keyHex = "11"~copies(64)
managerA = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
call assertOk managerA~createQueue("XMIT.B", "TEMPORARY", "WIRE", 10, "admin"), "create xmit"
fabricA = .QueueChannelFabric~new("QM.A", managerA, .QueueInProcessTransport~new, "admin")
transport = .QueueSocketClientTransport~new("admin")
endpoint = transport~registerEndpoint("QM.B", "127.0.0.1", 45678, "wire-b", "k1", keyHex)
listener = .QueueSocketListener~new("QM.A", "127.0.0.1", 0, fabricA)
adapter = .QueueTransportNoSQLAdapter~new(transport, fabricA, listener)

q = adapter~query("admin", "SELECT remote_manager,host,port,principal,key_id,attempt_count,success_count,failure_count FROM mq_transport_endpoints")
call assertEqual .Error~SUCCESS, q~status, "endpoint query succeeds"
call assertEqual 1, q~rows~items, "one endpoint projected"
call assertEqual "QM.B", q~rows[1]["remote_manager"], "remote manager projected"
call assertEqual "127.0.0.1", q~rows[1]["host"], "host projected"
call assertEqual 45678, q~rows[1]["port"], "port projected"
call assertEqual "wire-b", q~rows[1]["principal"], "principal projected"
call assertEqual "k1", q~rows[1]["key_id"], "key id projected"
call assertEqual 0, q~rows[1]["attempt_count"], "attempt count projected"
call assertEqual 0, q~rows[1]["success_count"], "success count projected"
call assertEqual 0, q~rows[1]["failure_count"], "failure count projected"

nonAdmin = adapter~query("producer", "SELECT remote_manager,key_id FROM mq_transport_endpoints")
call assertEqual .Error~SUCCESS, nonAdmin~status, "non-admin endpoint query succeeds"
call assertEqual 0, nonAdmin~rows~items, "non-admin sees no endpoint credentials"

listenerQ = adapter~query("admin", "SELECT manager_name,bind_host,port,connection_count,authenticated_count,accepted_count,rejected_count,last_error FROM mq_transport_listeners")
call assertEqual .Error~SUCCESS, listenerQ~status, "listener query succeeds"
call assertEqual 1, listenerQ~rows~items, "one listener projected"
call assertEqual "QM.A", listenerQ~rows[1]["manager_name"], "listener manager projected"
call assertEqual "127.0.0.1", listenerQ~rows[1]["bind_host"], "listener host projected"
call assertEqual 0, listenerQ~rows[1]["port"], "unstarted listener port projected"
call assertEqual 0, listenerQ~rows[1]["connection_count"], "listener connections projected"
call assertEqual 0, listenerQ~rows[1]["authenticated_count"], "listener auth count projected"
call assertEqual 0, listenerQ~rows[1]["accepted_count"], "listener accepted count projected"
call assertEqual 0, listenerQ~rows[1]["rejected_count"], "listener rejected count projected"

managerQ = adapter~query("admin", "SELECT fabric_version FROM mq_manager")
call assertEqual .Error~SUCCESS, managerQ~status, "base manager table federates through transport adapter"
call assertEqual "0.9", managerQ~rows[1]["fabric_version"], "v0.9 manager version projected"
channelQ = adapter~query("admin", "SELECT channel_name FROM mq_sender_channels")
call assertEqual .Error~SUCCESS, channelQ~status, "channel table federates through transport adapter"
call assertEqual 0, channelQ~rows~items, "empty channel table remains queryable"

/* Secret material must not become a SQL column by accidental object reflection. */
secretQuery = adapter~query("admin", "SELECT key_hex FROM mq_transport_endpoints")
call assertTrue secretQuery~status \= .Error~SUCCESS, "HMAC key material is not projected"

say "OBJECT QUEUE FABRIC V0.9 TRANSPORT NOSQL: OK"
say "assertions=" || assertions
exit 0

assertOk: procedure expose assertions
  use arg operationResult, label
  assertions += 1
  if \operationResult~ok then do
    say "ASSERT FAILED:" label "code=" operationResult~code "detail=" operationResult~detail
    exit 1
  end
  return
assertTrue: procedure expose assertions
  use arg condition, label
  assertions += 1
  if \condition then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return
assertEqual: procedure expose assertions
  use arg expected, actual, label
  assertions += 1
  if expected \== actual then do
    say "ASSERT FAILED:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

::requires "ObjectQueueTransportNoSQL.cls"
