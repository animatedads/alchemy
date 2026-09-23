/* Loopback command access point for a long-lived LLM PA Queue Fabric owner.
 * Protocol deliberately resembles the existing Queue Fabric Web Gateway
 * private bridge, but PA PUTs are persistent by contract.
 */

::class LlmPaCommandBridgeBackend public
::method init
  expose manager inQueue outQueue principal bridgeToken
  use arg managerArg, inQueueArg, outQueueArg, principalArg, bridgeTokenArg
  manager = managerArg
  inQueue = inQueueArg~string
  outQueue = outQueueArg~string
  principal = principalArg~string
  bridgeToken = bridgeTokenArg~string
  if manager == .nil | inQueue = "" | outQueue = "" | principal = "" | bridgeToken = "" then raise syntax 88.900 array("invalid LLM PA bridge configuration")

::method handle
  expose manager inQueue outQueue principal bridgeToken
  use arg request
  if request == .nil then return self~failure("REQUEST_REQUIRED")
  if \request~isa(.Directory) then return self~failure("REQUEST_INVALID")
  if self~field(request, "bridgeToken", "") \= bridgeToken then return self~failure("BRIDGE_AUTH_FAILED")
  op = self~field(request, "op", "")~string~translate
  select
    when op = "PING" then return self~success("OK")
    when op = "PUT" then do
      payload = self~field(request, "payload", .nil)
      if payload == .nil then return self~failure("PAYLOAD_REQUIRED")
      normalized = self~normalizeRequestPayload(payload)
      if \normalized~ok then return self~failure(normalized~code, normalized~detail)
      payload = normalized~value
      options = .table~new
      options["persistent"] = .true
      options["securityDomain"] = "LLMPA"
      options["correlationId"] = self~field(request, "correlationId", "")
      options["replyTo"] = self~field(request, "replyTo", outQueue)
      r = manager~put(inQueue, payload, options, principal)
      if \r~ok then return self~failure(r~code, r~detail)
      d = .directory~new
      d["packageId"] = r~value~packageId
      d["requestId"] = payload["request_id"]
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
      pkg["payload"] = p~payload
      pkg["correlationId"] = p~correlationId
      pkg["createdAt"] = p~createdAt
      d["package"] = pkg
      return self~success(d)
    end
    when op = "ACK" then return self~disposition(manager~ack(outQueue, self~field(request, "packageId", ""), self~field(request, "claimToken", ""), principal))
    when op = "RELEASE" then return self~disposition(manager~release(outQueue, self~field(request, "packageId", ""), self~field(request, "claimToken", ""), principal, "llmpa-client-release"))
    otherwise return self~failure("OP_UNSUPPORTED", op)
  end

::method normalizeRequestPayload private
  use arg payload
  if \payload~isa(.Directory) then return .LlmPaResult~failure("PAYLOAD_INVALID", "request payload must be a JSON object")
  fields = .array~of("schema", "request_id", "command", "arg1", "arg2", "submitted_by", "reply_to", "created_at")
  d = .directory~new
  do name over fields
    if \payload~hasIndex(name) then return .LlmPaResult~failure("PAYLOAD_FIELD_REQUIRED", name)
    d[name] = payload[name]~string
  end
  if d["schema"] \= "llm.pa.request/0.1" then return .LlmPaResult~failure("PAYLOAD_SCHEMA_INVALID", d["schema"])
  return .LlmPaResult~success(d)

::method disposition private
  use arg queueResult
  if \queueResult~ok then return self~failure(queueResult~code, queueResult~detail)
  return self~success("OK")

::method success private
  use arg valueArg = .nil
  d = .directory~new
  d["ok"] = .true
  d["code"] = "OK"
  if valueArg \== .nil then d["value"] = valueArg
  return d

::method failure private
  use arg codeArg, detailArg = ""
  d = .directory~new
  d["ok"] = .false
  d["code"] = codeArg~string
  if detailArg \= "" then d["detail"] = detailArg~string
  return d

::method field private
  use arg source, name, default = .nil
  if source~hasIndex(name) then return source[name]
  return default

::class LlmPaCommandAccessPoint public
::attribute port get
::method init
  expose listener port
  use arg binding, bridgeToken, bindHost = "127.0.0.1", portArg = 0
  backend = .LlmPaCommandBridgeBackend~new(binding~manager, binding~requestQueue, binding~replyQueue, binding~producerPrincipal, bridgeToken)
  listener = .QueueFabricWebGatewayBridgeListener~new(backend, bindHost, portArg)
  port = portArg

::method start
  expose listener port
  ok = listener~start
  if ok then port = listener~port
  return ok

::method serveOne unguarded
  expose listener
  return listener~serveOne

::method serveAsync unguarded
  expose listener port
  started = listener~serveAsync
  port = listener~port
  if started == .false then return .false
  return .true

::method stop unguarded
  expose listener
  return listener~stop

::requires "LlmPaCore.cls"
::requires "QueueFabricWebGatewayBridge.cls"
