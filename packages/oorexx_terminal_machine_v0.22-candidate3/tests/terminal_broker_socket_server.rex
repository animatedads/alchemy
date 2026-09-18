parse arg portFile statusFile keyHex serverNonce
if serverNonce == "" then serverNonce = copies("bb", 32)
endpoint = .SocketFixtureEndpoint~new
nonceSource = .SocketFixtureNonce~new(serverNonce)
host = .TerminalBrokerLocalSocketHost~new(endpoint, 0, 2, 262144, nonceSource)
trusted = host~trustPrincipal("AI_A", "k1", keyHex)
if \trusted~ok then exit 21
started = host~start
if \started~ok then exit 22
call lineout portFile, host~port
call lineout portFile
served = host~serveOne
ignore = host~stop
status = "serve_ok=" || boolText(served~ok) || ";serve_code=" || served~code || ";connections=" || host~connectionCount || ";authenticated=" || host~authenticatedCount || ";rejected=" || host~rejectedCount || ";requests=" || host~requestCount || ";endpoint_calls=" || endpoint~callCount || ";last_principal=" || endpoint~lastPrincipal || ";endpoint_closed=" || endpoint~closeCount || ";state=" || host~state
call lineout statusFile, status
call lineout statusFile
exit 0

boolText: procedure
  use arg value
  if value then return "1"
  return "0"

::class SocketFixtureNonce
::method init
  expose nonce
  use strict arg nonceArg
  nonce = nonceArg~string~lower
::method nextNonceHex
  expose nonce
  return nonce

::class SocketFixtureEndpoint
::attribute callCount get
::attribute lastPrincipal get
::attribute closeCount get
::method init
  expose callCount lastPrincipal closeCount
  callCount = 0
  lastPrincipal = ""
  closeCount = 0
::method handleFrame
  expose callCount lastPrincipal
  use strict arg principalArg, frameArg
  callCount += 1
  lastPrincipal = principalArg~string
  decoded = .TerminalBrokerFrameCodec~decode(frameArg~string, 65536)
  if \decoded~ok then return .TerminalBrokerFrameCodec~encode('{"ok":false,"code":"FIXTURE_BAD_FRAME"}', 65536)~value
  bodyPrincipal = ""
  bodyOperation = ""
  signal on syntax name badJson
  request = .json~fromJson(decoded~value)
  signal off syntax
  if request \== .nil then do
    if request~isA(.Directory) then do
      v = request~at("principal")
      if v \== .nil then bodyPrincipal = v~string
      v = request~at("operation")
      if v \== .nil then bodyOperation = v~string
    end
  end
  response = .directory~new
  response["ok"] = .true
  response["authenticated_principal"] = principalArg~string
  response["body_principal"] = bodyPrincipal
  response["operation"] = bodyOperation
  return .TerminalBrokerFrameCodec~encode(.json~toJson(response), 65536)~value
badJson:
  signal off syntax
  return .TerminalBrokerFrameCodec~encode('{"ok":false,"code":"FIXTURE_BAD_JSON"}', 65536)~value
::method close
  expose closeCount
  closeCount += 1
  return .TerminalResult~success(.true)

::requires "TerminalBrokerSocket.cls"
::requires "json.cls"
