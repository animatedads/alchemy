bridge = value("QF_CRYPTO_FOREIGN_BRIDGE", , "ENVIRONMENT")
if bridge \= "" then ignore = .CryptoForeignRuntimeInstaller~install(bridge)

parse arg storeRoot port keyHex expectedCode
manager = .ObjectQueueManager~new(storeRoot, .QueueGraphPayloadCodec~new, "admin")
if manager~queue("XMIT.B") == .nil then do
  createResult = manager~createQueue("XMIT.B", "PERMANENT", "WIRE", 10, "admin")
  if \createResult~ok then exit 31
end
transport = .QueueSocketClientTransport~new("admin")
ignore = transport~registerEndpoint("QM.B", "127.0.0.1", port, "wire-b", "k1", keyHex)
fabric = .QueueChannelFabric~new("QM.A", manager, transport, "admin")
if fabric~senderChannel("A.TO.B") == .nil then do
  defineSender = fabric~defineSenderChannel("A.TO.B", "XMIT.B", "QM.B", "A.TO.B", "admin", "wire-b", 5, "TEMPORARY", "admin")
  if \defineSender~ok then exit 32
end
ignore = fabric~startSenderChannel("A.TO.B", "admin")
if fabric~remoteQueue("B.INBOX") == .nil then do
  defineRemote = fabric~defineRemoteQueue("B.INBOX", "INBOX", "QM.B", "XMIT.B", "A.TO.B", "WIRE", "TEMPORARY", "admin", "admin")
  if \defineRemote~ok then exit 33
  grantRemote = fabric~grantRemotePut("B.INBOX", "producer", "admin")
  if \grantRemote~ok then exit 34
end
payload = .table~new
payload["kind"] = "render"
payload["steps"] = .array~of("decode", "encode")
options = .table~new
options["persistent"] = .true
options["securityDomain"] = "WIRE"
options["correlationId"] = "socket-42"
putResult = fabric~put("B.INBOX", payload, options, "producer")
if \putResult~ok then exit 35
pumpResult = fabric~pump("A.TO.B", 1, "admin")
if expectedCode = "" then do
  if \pumpResult~ok then do
    say "pump failed" pumpResult~code pumpResult~detail
    exit 36
  end
  if manager~depth("XMIT.B", "admin")~value["ready"] \= 0 then exit 37
end
else do
  if pumpResult~ok then exit 38
  if pumpResult~code \= "CHANNEL_DELIVERY_FAILED" then exit 39
  package = manager~browse("XMIT.B", "admin")~value
  if package == .nil then exit 40
  if package~deliveryCount \= 1 then exit 41
  if package~backoutCount \= 0 then exit 42
  if expectedCode \= "ANY" then do
    if pumpResult~detail~pos(expectedCode) = 0 then do
      say "unexpected detail" pumpResult~detail
      exit 43
    end
  end
end
exit 0

::requires "ObjectQueueSocketTransport.cls"

::requires "CryptoForeignRuntimeProvider.cls"
