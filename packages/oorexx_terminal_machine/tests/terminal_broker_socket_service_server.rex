parse arg portFile statusFile keyHex
endpoint = .SocketServiceEndpoint~new
host = .TerminalBrokerLocalSocketHost~new(endpoint, 0, 8, 262144, .nil, .nil, .nil, 30000)
if \host~trustPrincipal("AI_A", "k1", keyHex)~ok then exit 21
if \host~trustPrincipal("AI_B", "k1", keyHex)~ok then exit 22
launched = host~launchService(4, 16)
if \launched~ok then do
  call lineout statusFile, "launch_fail=" || launched~code || ":" || launched~detail
  call lineout statusFile
  exit 23
end
call lineout portFile, host~port
call lineout portFile

/* Both connections must be live simultaneously before drain begins. */
do tick = 1 to 2000
  if host~peakConnectionCount >= 2 then leave
  call SysSleep 0.01
end
if host~peakConnectionCount < 2 then do
  call lineout statusFile, "peak_fail=" || host~peakConnectionCount
  call lineout statusFile
  exit 24
end
requested = host~requestDrain("TEST_COMPLETE")
if \requested~ok then do
  call lineout statusFile, "drain_request_fail=" || requested~code || ":" || requested~detail
  call lineout statusFile
  exit 25
end
/* r13196 debug SHA-512 is intentionally slow.  The production socket I/O
 * bound stays 30 seconds; this larger harness wait only bounds test completion. */
drained = host~awaitDrain(60000)
if \drained~ok then do
  call lineout statusFile, "drain_fail=" || drained~code || ":" || drained~detail
  call lineout statusFile
  exit 26
end
s = host~serviceStatus
status = "service=" || s~state || ";listener=" || host~state || ";connections=" || host~connectionCount || ";active=" || host~activeConnectionCount || ";peak=" || host~peakConnectionCount || ";completed=" || host~completedConnectionCount || ";authenticated=" || host~authenticatedCount || ";rejected=" || host~rejectedCount || ";requests=" || host~requestCount || ";endpoint_calls=" || endpoint~callCount || ";last_error=" || s~lastError
call lineout statusFile, status
call lineout statusFile
exit 0

::class SocketServiceEndpoint
::attribute callCount get
::method init
  expose callCount
  callCount = 0
::method handleFrame
  expose callCount
  use strict arg principalArg, frameArg
  callCount += 1
  return .TerminalBrokerFrameCodec~encode('{"ok":true}', 65536)~value

::requires "TerminalBrokerSocket.cls"
