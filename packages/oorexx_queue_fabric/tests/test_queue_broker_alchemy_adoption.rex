manager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
call ok manager~createQueue("XMIT", "TEMPORARY", "OPS", 0, "admin"), "create xmit"
fabric = .QueueChannelFabric~new("A", manager, .QueueInProcessTransport~new, "admin")
defaultPolicy = .QueueBrokerAdmissionPolicy~new
service = .QueueBrokerService~new("broker-adopt", fabric, .nil, defaultPolicy, "admin")
call adopted defaultPolicy, "default admission policy"
call adopted service, "broker service"

ring = .WLUFastMacKeyRing~new
ignore = ring~addKey("active", "00112233445566778899aabbccddeeff")
authority = .WLUAuthority~new(ring)
account = .WLUAccount~new("adopt-account", 1000)
ignore = authority~addAccount(account)
ignore = authority~bindAccount("broker-adopt", "queue/*", "adopt-account")
wluPolicy = .QueueBrokerWLUAdmission~new(authority, "broker-adopt", "queue")
call adopted wluPolicy, "WLU admission policy"
say "OBJECT QUEUE FABRIC V0.9 ALCHEMY OBJECT v0.5 ADOPTION: OK"
exit 0

adopted: procedure
  use arg object, label
  result = .AlchemyAdoptionVerifier~verify(object, "STANDARD")
  if \result~ok then do
    say "ADOPTION FAILED:" label
    do failure over result~failures
      say failure["code"] failure["message"]
    end
    exit 1
  end
  return
ok: procedure
  use arg result, label
  if result == .nil | \result~ok then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return

::requires "ObjectQueueWLU.cls"
::requires "AlchemyAdoption.cls"
