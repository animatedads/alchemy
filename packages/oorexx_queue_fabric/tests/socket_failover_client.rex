bridge = value("QF_CRYPTO_FOREIGN_BRIDGE", , "ENVIRONMENT")
if bridge \= "" then ignore = .CryptoForeignRuntimeInstaller~install(bridge)

parse arg storeRoot livePort deadPort keyHex
manager = .ObjectQueueManager~new(storeRoot, .QueueGraphPayloadCodec~new, "admin")
call ok manager~createQueue("XMIT.B", "TEMPORARY", "WIRE", 10, "admin"), "create xmit"
transport = .QueueSocketClientTransport~new("admin")
primary = transport~registerEndpoint("QM.B", "127.0.0.1", deadPort, "wire-b", "k1", keyHex)
secondary = transport~registerFailoverEndpoint("QM.B", "127.0.0.1", livePort, "wire-b", "k1", keyHex)
call assert primary~endpointOrder = 1, "primary order"
call assert secondary~endpointOrder = 2, "secondary order"
fabric = .QueueChannelFabric~new("QM.A", manager, transport, "admin")
call ok fabric~defineSenderChannel("A.TO.B", "XMIT.B", "QM.B", "A.TO.B", "admin", "wire-b", 5, "TEMPORARY", "admin"), "define sender"
call ok fabric~startSenderChannel("A.TO.B", "admin"), "start sender"
call ok fabric~defineRemoteQueue("B.INBOX", "INBOX", "QM.B", "XMIT.B", "A.TO.B", "WIRE", "TEMPORARY", "admin", "admin"), "define remote"
call ok fabric~grantRemotePut("B.INBOX", "producer", "admin"), "grant producer"

probe = transport~probe("QM.A", "QM.B", "A.TO.B", "wire-b")
call ok probe, "authenticated health probe through alternate endpoint"
call assert primary~healthAttemptCount = 1, "primary probe attempted"
call assert primary~healthFailureCount = 1, "primary probe failure recorded"
call assert secondary~healthSuccessCount = 1, "secondary probe success recorded"

options = .table~new
options["securityDomain"] = "WIRE"
call ok fabric~put("B.INBOX", "failover-payload", options, "producer"), "queue remote work"
pump = fabric~pump("A.TO.B", 1, "admin")
call ok pump, "delivery fails over to second endpoint"
call assert primary~attemptCount = 1, "primary delivery attempted"
call assert primary~failureCount = 1, "primary delivery failure recorded"
call assert secondary~successCount = 1, "secondary delivery success recorded"
call assert manager~depth("XMIT.B", "admin")~value["ready"] = 0, "xmit drained after failover"
say "SOCKET FAILOVER CLIENT: OK"
exit 0

ok: procedure
  use arg result, label
  if result == .nil | \result~ok then do
    if result == .nil then say "ASSERT FAILED:" label "nil"
    else say "ASSERT FAILED:" label result~code result~detail
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

::requires "ObjectQueueSocketTransport.cls"

::requires "CryptoForeignRuntimeProvider.cls"
