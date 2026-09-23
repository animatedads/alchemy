bridge = value("QF_CRYPTO_FOREIGN_BRIDGE", , "ENVIRONMENT")
if bridge \= "" then ignore = .CryptoForeignRuntimeInstaller~install(bridge)

parse arg storeRoot portFile statusFile keyHex maxDepth connectionCount prefill allowIp priorAllowIp
if allowIp = "" then allowIp = "127.0.0.1"
if maxDepth = "" then maxDepth = 10
if connectionCount = "" then connectionCount = 1
manager = .ObjectQueueManager~new(storeRoot, .QueueGraphPayloadCodec~new, "admin")
if manager~queue("INBOX") == .nil then do
  createResult = manager~createQueue("INBOX", "PERMANENT", "WIRE", maxDepth, "admin")
  if \createResult~ok then exit 21
  grantResult = manager~grant("INBOX", "wire-b", .QueueAccess~PUT, "admin")
  if \grantResult~ok then exit 22
end
fabric = .QueueChannelFabric~new("QM.B", manager, .QueueInProcessTransport~new, "admin")
if fabric~receiverChannel("A.TO.B") == .nil then do
  defineResult = fabric~defineReceiverChannel("A.TO.B", "QM.A", "wire-b", "TEMPORARY", "admin")
  if \defineResult~ok then exit 23
end
startResult = fabric~startReceiverChannel("A.TO.B", "admin")
if \startResult~ok then exit 24
if prefill = "1" then do
  prefillOptions = .table~new
  prefillOptions["securityDomain"] = "WIRE"
  prefillResult = manager~put("INBOX", "seed", prefillOptions, "admin")
  if \prefillResult~ok then exit 26
end
listener = .QueueSocketListener~new("QM.B", "127.0.0.1", 0, fabric)
if priorAllowIp \= "" then ignore = listener~trustPeer("QM.A", "wire-b", "k1", keyHex, .array~of(priorAllowIp))
ignore = listener~trustPeer("QM.A", "wire-b", "k1", keyHex, .array~of(allowIp))
if \listener~start then exit 25
call lineout portFile, listener~port
call lineout portFile
handled = 0
do i = 1 to connectionCount
  serveResult = listener~serveOne
  handled += 1
end
ignore = listener~stop
call lineout statusFile, "connections=" || listener~connectionCount || ";authenticated=" || listener~authenticatedCount || ";accepted=" || listener~acceptedCount || ";rejected=" || listener~rejectedCount || ";ipRejected=" || listener~ipRejectedCount || ";probes=" || listener~probeCount || ";handled=" || handled || ";depth=" || manager~depth("INBOX", "admin")~value["ready"] || ";receipts=" || manager~transferReceiptCount
call lineout statusFile
exit 0

::requires "ObjectQueueSocketTransport.cls"

::requires "CryptoForeignRuntimeProvider.cls"
