parse arg port keyHex
principal = "AI_A"
keyId = "k1"
clientNonce = copies("aa", 32)
framer = .TerminalBrokerSocketFramer~new(262144)
connection = .StreamSocket~new("127.0.0.1", port)
if connection~open \== "READY:" then exit 41
hello = .directory~new
hello["type"] = "AUTH_HELLO"
hello["protocol"] = .TerminalBrokerSocketBuild~PROTOCOL
hello["principal"] = principal
hello["key_id"] = keyId
hello["client_nonce"] = clientNonce
hello["mac"] = .HMACSHA512~digest(keyHex, .TerminalBrokerSocketProtocol~helloText(principal, keyId, clientNonce))
if \framer~sendRecord(connection, .json~toJson(hello))~ok then exit 42
challengeResult = framer~receiveRecord(connection)
if \challengeResult~ok then exit 43
challenge = .json~fromJson(challengeResult~value)
serverNonce = challenge["server_nonce"]
expected = .HMACSHA512~digest(keyHex, .TerminalBrokerSocketProtocol~challengeText(principal, keyId, clientNonce, serverNonce))
if \.CryptoUtils~secureEquals(expected, challenge["mac"]) then exit 44

payload = '{"protocol":"fixture/1","request_id":"tamper","operation":"STATUS"}'
brokerFrame = .TerminalBrokerFrameCodec~encode(payload)~value
record = .directory~new
record["type"] = "BROKER_REQUEST"
record["protocol"] = .TerminalBrokerSocketBuild~PROTOCOL
record["sequence"] = 1
record["frame"] = brokerFrame
record["mac"] = copies("0", 128) /* intentionally forged */
if \framer~sendRecord(connection, .json~toJson(record))~ok then exit 45
/* The server must close/reject rather than dispatch.  Either EOF or read
 * failure is the expected client-visible result. */
reply = framer~receiveRecord(connection)
ignore = connection~close
if reply~ok then do
  say "UNEXPECTED_TAMPER_RESPONSE"
  exit 46
end
say "TAMPER_REJECTED code=" || reply~code
exit 0

::requires "TerminalBrokerSocket.cls"
::requires "json.cls"
