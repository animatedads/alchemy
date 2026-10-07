bridge = value("QF_CRYPTO_FOREIGN_BRIDGE", , "ENVIRONMENT")
if bridge \= "" then ignore = .CryptoForeignRuntimeInstaller~install(bridge)

parse arg port keyHex
codec = .QueueGraphPayloadCodec~new
transport = .QueueSocketClientTransport~new("admin", codec)
ignore = transport~registerEndpoint("QM.B", "127.0.0.1", port, "wire-b", "k1", keyHex)
payload = .table~new
payload["kind"] = "replay"
payload["nested"] = .array~of("one", "two")
envelope = .QueueTransmissionEnvelope~new("xfer-fixed-1", "QM.A", "B.INBOX", "source-pkg-1", "QM.B", "INBOX", payload, .table~new, 0, .true, "WIRE", "", "replay-42", "", 0)
firstDelivery = transport~deliver("QM.B", "A.TO.B", envelope, "wire-b")
if \firstDelivery~ok then exit 61
if firstDelivery~value~duplicate then exit 62
secondDelivery = transport~deliver("QM.B", "A.TO.B", envelope, "wire-b")
if \secondDelivery~ok then exit 63
if \secondDelivery~value~duplicate then exit 64
say "first=accepted;second=duplicate"
exit 0

::requires "ObjectQueueSocketTransport.cls"

::requires "CryptoForeignRuntimeProvider.cls"
