parse arg portFile keyHex mode
mode = mode~strip~upper
if mode == "" then mode = "BAD_RESPONSE"
framer = .TerminalBrokerSocketFramer~new(262144)
listener = .Socket~new("AF_INET", "SOCK_STREAM", 0)
if listener~errno \= 0 then exit 51
ignore = listener~setOption("SO_REUSEADDR", 1)
if listener~bind(.InetAddress~new("127.0.0.1", 0)) = -1 then exit 52
if listener~listen(1) = -1 then exit 53
actual = listener~getSockName
if actual == .nil then exit 54
call lineout portFile, actual~port
call lineout portFile
accepted = listener~accept
if accepted == .nil then exit 55
ignore = accepted~setOption("SO_RCVTIMEO", 30000)
ignore = accepted~setOption("SO_SNDTIMEO", 30000)
connection = .StreamSocket~new(accepted)
helloResult = framer~receiveRecord(connection)
if \helloResult~ok then exit 56
hello = .json~fromJson(helloResult~value)
principal = hello["principal"]~string
keyId = hello["key_id"]~string
clientNonce = hello["client_nonce"]~string~lower
serverNonce = copies("cc", 32)
challenge = .directory~new
challenge["type"] = "AUTH_CHALLENGE"
challenge["protocol"] = .TerminalBrokerSocketBuild~PROTOCOL
challenge["server_nonce"] = serverNonce
if mode == "BAD_CHALLENGE" then challenge["mac"] = copies("0", 128)
else challenge["mac"] = .HMACSHA512~digest(keyHex, .TerminalBrokerSocketProtocol~challengeText(principal, keyId, clientNonce, serverNonce))
if \framer~sendRecord(connection, .json~toJson(challenge))~ok then exit 57
if mode == "BAD_CHALLENGE" then do
  ignore = connection~close
  ignore = listener~close
  exit 0
end
requestResult = framer~receiveRecord(connection)
if \requestResult~ok then exit 58
request = .json~fromJson(requestResult~value)
sequence = request["sequence"]
brokerFrame = .TerminalBrokerFrameCodec~encode('{"ok":true,"fixture":"forged"}')~value
response = .directory~new
response["type"] = "BROKER_RESPONSE"
response["protocol"] = .TerminalBrokerSocketBuild~PROTOCOL
response["sequence"] = sequence
response["frame"] = brokerFrame
response["mac"] = copies("0", 128)
if \framer~sendRecord(connection, .json~toJson(response))~ok then exit 59
ignore = connection~close
ignore = listener~close
exit 0

::requires "TerminalBrokerSocket.cls"
::requires "json.cls"
