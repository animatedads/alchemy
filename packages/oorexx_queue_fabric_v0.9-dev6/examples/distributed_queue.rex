/* Object Queue Fabric v0.8 distributed object-queue example. */
transport = .QueueInProcessTransport~new
qa = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
qb = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")

ignore = qa~createQueue("XMIT.B", "TEMPORARY", "WIRE", 20, "admin")
ignore = qb~createQueue("INBOX", "TEMPORARY", "WIRE", 20, "admin")
ignore = qb~grant("INBOX", "wire-b", .QueueAccess~PUT, "admin")

fa = .QueueChannelFabric~new("QM.A", qa, transport, "admin")
fb = .QueueChannelFabric~new("QM.B", qb, transport, "admin")
ignore = transport~registerEndpoint("QM.B", fb)
ignore = fa~defineSenderChannel("A.TO.B", "XMIT.B", "QM.B", "A.TO.B", "admin", "wire-b", 0, "TEMPORARY", "admin")
ignore = fb~defineReceiverChannel("A.TO.B", "QM.A", "wire-b", "TEMPORARY", "admin")
ignore = fa~startSenderChannel("A.TO.B", "admin")
ignore = fb~startReceiverChannel("A.TO.B", "admin")
ignore = fa~defineRemoteQueue("B.INBOX", "INBOX", "QM.B", "XMIT.B", "A.TO.B", "WIRE", "TEMPORARY", "admin", "admin")
ignore = fa~grantRemotePut("B.INBOX", "producer", "admin")

payload = .table~new
payload["kind"] = "render"
steps = .array~new
steps~append("camera")
steps~append("encode")
payload["steps"] = steps

options = .table~new
options["securityDomain"] = "WIRE"
options["correlationId"] = "demo-42"
queued = fa~put("B.INBOX", payload, options, "producer")
say "queued transfer:" queued~value~transferId
say "xmit depth before pump:" qa~depth("XMIT.B", "admin")~value["ready"]

sent = fa~pump("A.TO.B", 0, "admin")
say sent~detail
say "xmit depth after pump:" qa~depth("XMIT.B", "admin")~value["ready"]
say "remote depth:" qb~depth("INBOX", "admin")~value["ready"]
received = qb~browse("INBOX", "admin")~value
say "remote payload kind:" received~payload["kind"]
say "remote payload step 2:" received~payload["steps"][2]
say "remote correlation:" received~correlationId
say "transfer receipts:" qb~transferReceiptCount

::requires "ObjectQueueChannels.cls"
