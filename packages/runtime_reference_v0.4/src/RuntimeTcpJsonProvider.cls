/* RuntimeTcpJsonProvider.cls -- TCP/JSON transport for runtime.reference/0.4 */

::class RuntimeTcpJsonProvider subclass RuntimeImplementationProvider public
::attribute providerId get
::attribute host get
::attribute port get
::attribute timeoutSeconds get
::attribute maxResponseBytes get

::method init
  expose providerId host port timeoutSeconds maxResponseBytes implementationId
  use strict arg providerId, host = "127.0.0.1", port, timeoutSeconds = 2, maxResponseBytes = 1048576, implementationId = ""
  if port < 1 | port > 65535 then raise syntax 88.900 array("TCP provider port out of range")
  if timeoutSeconds < 0 then raise syntax 88.900 array("TCP provider timeout must be non-negative")
  if maxResponseBytes < 256 then raise syntax 88.900 array("TCP provider response limit too small")

::method invoke unguarded
  expose providerId host port timeoutSeconds maxResponseBytes implementationId
  use strict arg operationId, request, contract
  signal on syntax name tcpSyntaxFailure

  envelope = .Directory~new
  envelope["protocol"] = .RuntimeReferenceBuild~WIRE_PROTOCOL_VERSION
  envelope["operation"] = operationId
  envelope["execution_class"] = contract~executionClass
  envelope["contract_version"] = contract~contractVersion
  if contract~executionClass == "STATE_TRANSFORM" & request~hasIndex("arguments") & request~hasIndex("state") then do
    envelope["arguments"] = request["arguments"]
    envelope["state"] = request["state"]
  end
  else envelope["arguments"] = request
  envelope = self~wireValue(envelope)
  wire = .JSON~toJSON(envelope) || '0a'x

  socket = .Socket~new
  address = .InetAddress~new(host, port)
  connected = socket~connect(address)
  if connected < 0 then do
    err = socket~errno
    socket~close
    return .RuntimeProviderResult~failure("UNAVAILABLE", "connect failed errno=" || err, providerId, implementationId)
  end

  offset = 1
  do while offset <= wire~length
    sent = socket~send(substr(wire, offset))
    if sent == .nil then do
      err = socket~errno
      socket~close
      return .RuntimeProviderResult~failure("UNAVAILABLE", "send failed errno=" || err, providerId, implementationId)
    end
    if sent <= 0 then do
      err = socket~errno
      socket~close
      return .RuntimeProviderResult~failure("UNAVAILABLE", "send failed errno=" || err, providerId, implementationId)
    end
    offset += sent
  end

  responseText = ""
  complete = .false
  do while \complete
    reads = .Array~of(socket)
    writes = .Array~new
    excepts = .Array~new
    selected = socket~select(reads, writes, excepts, timeoutSeconds)
    if selected == .nil then do
      err = socket~errno
      socket~close
      return .RuntimeProviderResult~failure("UNAVAILABLE", "select failed errno=" || err, providerId, implementationId)
    end
    if selected = 0 then do
      socket~close
      return .RuntimeProviderResult~failure("UNAVAILABLE", "response timeout", providerId, implementationId)
    end
    chunk = socket~recv(4096)
    if chunk == .nil then do
      err = socket~errno
      socket~close
      return .RuntimeProviderResult~failure("UNAVAILABLE", "receive failed errno=" || err, providerId, implementationId)
    end
    if chunk == "" then leave
    responseText ||= chunk
    if responseText~length > maxResponseBytes then do
      socket~close
      return .RuntimeProviderResult~failure("MALFORMED_RESPONSE", "response exceeds configured limit", providerId, implementationId)
    end
    nl = pos('0a'x, responseText)
    if nl > 0 then do
      responseText = left(responseText, nl - 1)
      complete = .true
    end
  end
  socket~close

  if responseText == "" then return .RuntimeProviderResult~failure("MALFORMED_RESPONSE", "empty response", providerId, implementationId)
  decoded = .JSON~fromJSON(responseText)
  if \decoded~isa(.Directory) then return .RuntimeProviderResult~failure("MALFORMED_RESPONSE", "response root is not an object", providerId, implementationId)
  if \decoded~hasIndex("protocol") then return .RuntimeProviderResult~failure("MALFORMED_RESPONSE", "missing protocol", providerId, implementationId)
  if decoded["protocol"] \= .RuntimeReferenceBuild~WIRE_PROTOCOL_VERSION then return .RuntimeProviderResult~failure("MALFORMED_RESPONSE", "protocol mismatch", providerId, implementationId)
  if \decoded~hasIndex("status") then return .RuntimeProviderResult~failure("MALFORMED_RESPONSE", "missing status", providerId, implementationId)
  if \decoded~hasIndex("operation") then return .RuntimeProviderResult~failure("MALFORMED_RESPONSE", "missing operation", providerId, implementationId)
  if decoded["operation"]~string \= operationId then return .RuntimeProviderResult~failure("MALFORMED_RESPONSE", "operation mismatch", providerId, implementationId)
  status = decoded["status"]~string~lower
  returnedProvider = providerId
  returnedImplementation = implementationId
  if decoded~hasIndex("provider") then do
    if decoded["provider"]~string \= providerId then return .RuntimeProviderResult~failure("MALFORMED_RESPONSE", "provider identity mismatch", providerId, implementationId)
  end
  if decoded~hasIndex("implementation") then do
    remoteImplementation = decoded["implementation"]~string
    if implementationId \= "" & remoteImplementation \= implementationId then return .RuntimeProviderResult~failure("MALFORMED_RESPONSE", "implementation identity mismatch", providerId, implementationId)
    if implementationId == "" then returnedImplementation = remoteImplementation
  end

  select
    when status == "completed" then do
      if \decoded~hasIndex("value") then return .RuntimeProviderResult~failure("MALFORMED_RESPONSE", "completed response missing value", returnedProvider, returnedImplementation)
      return .RuntimeProviderResult~success(decoded["value"], returnedProvider, returnedImplementation)
    end
    when status == "unsupported" then return .RuntimeProviderResult~failure("UNSUPPORTED", self~responseDetail(decoded), returnedProvider, returnedImplementation)
    when status == "rejected_before_execution" then return .RuntimeProviderResult~failure("REJECTED_BEFORE_EXECUTION", self~responseDetail(decoded), returnedProvider, returnedImplementation)
    when status == "execution_status_unknown" then return .RuntimeProviderResult~failure("EXECUTION_STATUS_UNKNOWN", self~responseDetail(decoded), returnedProvider, returnedImplementation)
    when status == "fault" then return .RuntimeProviderResult~failure("REMOTE_FAULT", self~responseDetail(decoded), returnedProvider, returnedImplementation)
    otherwise return .RuntimeProviderResult~failure("MALFORMED_RESPONSE", "unknown status " || status, returnedProvider, returnedImplementation)
  end

tcpSyntaxFailure:
  if symbol("socket") = "VAR" then do
    if socket \== .nil then socket~close
  end
  condition = condition("O")
  detail = "TCP provider raised a condition"
  if condition \== .nil then do
    if condition~hasIndex("DESCRIPTION") then detail = condition["DESCRIPTION"]
  end
  return .RuntimeProviderResult~failure("MALFORMED_RESPONSE", detail, providerId, implementationId)

::method wireValue private
  use strict arg value
  if value~isa(.RuntimeExactBytes) then return value~hexTagged
  if value~isa(.Directory) then do
    out = .Directory~new
    do key over value
      out[key] = self~wireValue(value[key])
    end
    return out
  end
  if value~isa(.Array) then do
    out = .Array~new
    do item over value
      out~append(self~wireValue(item))
    end
    return out
  end
  return value

::method responseDetail private
  use strict arg decoded
  if decoded~hasIndex("detail") then return decoded["detail"]~string
  return ""

::requires "RuntimeImplementationReference.cls"
::requires "json.cls"
::requires "socket.cls"
