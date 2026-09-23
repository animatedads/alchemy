bridge = value("QF_CRYPTO_FOREIGN_BRIDGE", , "ENVIRONMENT")
if bridge \= "" then ignore = .CryptoForeignRuntimeInstaller~install(bridge)

parse arg portFile keyHex
framer = .QueueSocketFramer~new
listenerSocket = .Socket~new("AF_INET", "SOCK_STREAM", 0)
ignore = listenerSocket~setOption("SO_REUSEADDR", 1)
if listenerSocket~bind(.InetAddress~new("127.0.0.1", 0)) = -1 then exit 71
if listenerSocket~listen(4) = -1 then exit 72
call lineout portFile, listenerSocket~getSockName~port
call lineout portFile
acceptedSocket = listenerSocket~accept
if acceptedSocket == .nil then exit 73
connection = .StreamSocket~new(acceptedSocket)
helloResult = framer~receiveFrame(connection)
if \helloResult~ok then exit 74
hello = .QueueRecordCodec~decode(helloResult~value)
if hello == .nil then exit 75
sourceManager = hello[3]
destinationManager = hello[4]
receiverChannel = hello[5]
principal = hello[6]
keyId = hello[7]
clientNonce = hello[8]
serverNonce = "33"~copies(32)
challengeText = .QueueSocketProtocol~challengeText(sourceManager, destinationManager, receiverChannel, principal, keyId, clientNonce, serverNonce)
challengeMac = .QueueHmacSha512~digest(keyHex, challengeText)
challengeFrame = .QueueRecordCodec~encode("CHALLENGE", .array~of(.QueueSocketTransportBuild~PROTOCOL, serverNonce, challengeMac))
if \framer~sendFrame(connection, challengeFrame)~ok then exit 76
transcript = .QueueSocketSessionCrypto~transcript(sourceManager, destinationManager, receiverChannel, principal, keyId, clientNonce, serverNonce)
sessionCrypto = .QueueSocketSessionCrypto~new(keyHex, transcript)
deliveryResult = framer~receiveFrame(connection)
if \deliveryResult~ok then exit 77
openedDelivery = sessionCrypto~open("C2S", deliveryResult~value)
if \openedDelivery~ok then exit 78
/* Deliberately forge the authenticated tag on an otherwise valid encrypted RESULT. */
okText = "1"; code = "OK"; detail = "forged"; transferId = "x"; packageId = "p"; queueName = "INBOX"; acceptedAt = "now"; receiptSourceManager = "QM.A"; duplicateText = "0"
plainResult = .QueueRecordCodec~encode("RESULT", .array~of(.QueueSocketTransportBuild~PROTOCOL, okText, code, detail, transferId, packageId, queueName, acceptedAt, receiptSourceManager, duplicateText))
sealedResult = sessionCrypto~seal("S2C", plainResult)
secureRow = .QueueRecordCodec~decode(sealedResult)
resultFrame = .QueueRecordCodec~encode("SECURE", .array~of(secureRow[2], secureRow[3], secureRow[4], "00"~copies(64)))
ignore = framer~sendFrame(connection, resultFrame)
ignore = connection~close
ignore = listenerSocket~close
exit 0

::requires "ObjectQueueSocketTransport.cls"

::requires "CryptoForeignRuntimeProvider.cls"
