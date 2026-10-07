/*
 * QueueFabricWebGatewayBridge.cls
 *
 * Private loopback bridge for a browser WebSocket edge.  This object owns no
 * browser semantics.  It maps a fixed access point onto the real
 * ObjectQueueManager PUT / CLAIM / ACK / NACK / RELEASE surface.
 *
 * Queue Fabric claim tokens remain inside the gateway trust boundary.
 */

::class QueueFabricWebGatewayBackend public
::attribute inQueue get
::attribute outQueue get
::attribute principal get

::method init
  expose manager inQueue outQueue principal bridgeToken
  use strict arg manager, inQueue, outQueue, principal, bridgeToken
  if manager == .nil then raise syntax 93.906 array("queue manager")
  inQueue = inQueue~string~strip
  outQueue = outQueue~string~strip
  principal = principal~string~strip
  bridgeToken = bridgeToken~string
  if inQueue = "" | outQueue = "" | principal = "" | bridgeToken = "" then raise syntax 93.906 array("gateway configuration")

::method handle
  expose manager inQueue outQueue principal bridgeToken
  use strict arg request
  if request == .nil then return self~failure("REQUEST_REQUIRED")
  if self~field(request, "bridgeToken", "") \= bridgeToken then return self~failure("BRIDGE_AUTH_FAILED")
  op = self~field(request, "op", "")~string~translate
  select
    when op = "PING" then return self~success("OK")
    when op = "PUT" then do
      payload = self~field(request, "payload", .nil)
      if payload == .nil then return self~failure("PAYLOAD_REQUIRED")
      options = .table~new
      options["correlationId"] = self~field(request, "correlationId", "")
      r = manager~put(inQueue, payload, options, principal)
      if \r~ok then return self~failure(r~code, r~detail)
      d = .directory~new
      d["packageId"] = r~value~packageId
      return self~success(d)
    end
    when op = "CLAIM" then do
      r = manager~claim(outQueue, principal)
      if \r~ok then return self~failure(r~code, r~detail)
      p = r~value
      d = .directory~new
      d["claimToken"] = p~claimToken
      pkg = .directory~new
      pkg["packageId"] = p~packageId
      pkg["sequence"] = p~sequence
      pkg["payload"] = p~payload
      pkg["correlationId"] = p~correlationId
      pkg["requestedQueue"] = p~requestedQueue
      pkg["currentQueue"] = p~currentQueue
      pkg["createdAt"] = p~createdAt
      d["package"] = pkg
      return self~success(d)
    end
    when op = "ACK" then return self~disposition(manager~ack(outQueue, self~field(request,"packageId",""), self~field(request,"claimToken",""), principal))
    when op = "NACK" then return self~disposition(manager~nack(outQueue, self~field(request,"packageId",""), self~field(request,"claimToken",""), principal))
    when op = "RELEASE" then return self~disposition(manager~release(outQueue, self~field(request,"packageId",""), self~field(request,"claimToken",""), principal, "websocket-disconnect"))
    otherwise return self~failure("OP_UNSUPPORTED", op)
  end

::method disposition private
  use strict arg result
  if \result~ok then return self~failure(result~code, result~detail)
  return self~success("OK")

::method success private
  use strict arg value = .nil
  d = .directory~new
  d["ok"] = .true
  d["code"] = "OK"
  if value \== .nil then d["value"] = value
  return d

::method failure private
  use strict arg code, detail = ""
  d = .directory~new
  d["ok"] = .false
  d["code"] = code~string
  if detail \= "" then d["detail"] = detail~string
  return d

::method field private
  use strict arg source, name, default = .nil
  if source~hasIndex(name) then return source[name]
  return default


::class QueueFabricWebGatewayBridgeListener public
::attribute port get
::attribute running get

::method init
  expose backend bindHost port listenSocket maxRequestBytes running
  use strict arg backendArg, bindHostArg = "127.0.0.1", portArg = 0, maxRequestBytesArg = 1048576
  backend = backendArg
  bindHost = bindHostArg~string
  port = portArg
  listenSocket = .nil
  maxRequestBytes = maxRequestBytesArg
  running = .false

::method start
  expose bindHost port listenSocket running
  if listenSocket \== .nil then return .true
  s = .Socket~new("AF_INET", "SOCK_STREAM", 0)
  if s~errno \= 0 then return .false
  ignore = s~setOption("SO_REUSEADDR", 1)
  if s~bind(.InetAddress~new(bindHost, port)) = -1 then do; ignore=s~close; return .false; end
  if s~listen(32) = -1 then do; ignore=s~close; return .false; end
  actual = s~getSockName
  if actual \== .nil then port = actual~port
  listenSocket = s
  running = .true
  return .true

::method stop unguarded
  expose listenSocket running
  running = .false
  if listenSocket == .nil then return .true
  ignore = listenSocket~close
  listenSocket = .nil
  return .true

::method serveOne unguarded
  expose backend listenSocket maxRequestBytes running
  if \running then return .false
  if listenSocket == .nil then return .false
  reads = .array~of(listenSocket)
  ready = listenSocket~select(reads, .array~new, .array~new, 0.10)
  if ready == .nil then return .false
  if ready = 0 then return .true
  if \running | listenSocket == .nil then return .false
  sock = listenSocket~accept
  if sock == .nil then return .false
  stream = .StreamSocket~new(sock)
  signal on syntax name requestFailure
  line = stream~lineIn
  if line~length > maxRequestBytes then response = self~errorResponse("REQUEST_TOO_LARGE")
  else do
    request = .JSON~fromJSON(line)
    response = backend~handle(request)
  end
  ignore = stream~lineOut(.JSON~toJSON(response))
  ignore = stream~close
  signal off syntax
  return .true
requestFailure:
  signal off syntax
  ignore = stream~lineOut(.JSON~toJSON(self~errorResponse("REQUEST_INVALID")))
  ignore = stream~close
  return .false

::method serveForever unguarded
  expose running
  use strict arg
  if \self~start then return .false
  do while running
    ignore = self~serveOne
  end
  return .true

/* Run the private loopback listener on an ooRexx activity while preserving the
 * caller's actual ObjectQueueManager reference. This is the production seam:
 * do not launch a second process with a second in-memory queue manager. */
::method serveAsync unguarded
  expose running
  use strict arg
  if \self~start then return .false
  reply self
  do while running
    ignore = self~serveOne
  end
  return

::method errorResponse private
  use strict arg code
  d=.directory~new; d["ok"]=.false; d["code"]=code; return d

::requires "ObjectQueueFabric.cls"
::requires "json.cls"
::requires "socket.cls"
::requires "streamsocket.cls"
