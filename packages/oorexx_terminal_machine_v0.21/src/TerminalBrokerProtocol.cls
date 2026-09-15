/*
 * TerminalBrokerProtocol.cls - serialized broker protocol boundary v0.15.
 *
 * This is deliberately an IPC-neutral codec/endpoint, not a socket daemon.
 * A surrounding trusted transport authenticates a principal and passes that
 * identity separately to handleFrame()/handleJson().  The JSON body can never
 * assert its own principal.
 *
 * Authority model:
 *   authenticated principal + opaque bearer client token
 *   authenticated principal + opaque bearer controller token for mutation
 *
 * The endpoint retains the real TerminalBrokerClient/Controller objects only
 * inside the trusted service process.  Serialized messages contain value data,
 * opaque ids and bounded evidence only.
 *
 * Security invariants:
 *   - no default token generator exists; a host-supplied token source is
 *     mandatory and must produce unpredictable opaque bearer values;
 *   - external WLU/admission reservations cross IPC only as opaque handles;
 *   - NONDISPLAY SET_FIELD / TYPE_AT_CURSOR is rejected before terminal
 *     mutation; trusted credential staging remains a separate local boundary;
 *   - snapshots are allow-listed and NONDISPLAY values are re-masked even if
 *     an upstream fixture accidentally supplies plaintext;
 *   - replay/idempotency storage retains principal + request id + operation +
 *     encoded response only.  It never retains serialized request bodies;
 *   - controller handoff never returns the target controller token to the old
 *     controller.  The target retrieves its own token through CONTROL_STATUS;
 *   - no raw TN5250 READ response bytes are serialized.
 */

::class TerminalBrokerProtocolBuild public
::constant RELEASE "0.17"
::constant PROTOCOL "terminal.broker.ipc/0.1"


::class TerminalBrokerFrameCodec public
::constant HEADER_BYTES 8

::method encode class public
  use strict arg payloadArg, maximumBytesArg = 65536
  numeric digits 20
  payload = payloadArg~string
  if \datatype(maximumBytesArg, "W") then return .TerminalResult~failure("BROKER_FRAME_LIMIT_INVALID", "maximum frame bytes must be a positive whole number")
  if maximumBytesArg < 1 then return .TerminalResult~failure("BROKER_FRAME_LIMIT_INVALID", "maximum frame bytes must be positive")
  if payload~length > maximumBytesArg then return .TerminalResult~failure("BROKER_FRAME_TOO_LARGE", payload~length)
  if payload~length > 4294967295 then return .TerminalResult~failure("BROKER_FRAME_TOO_LARGE", payload~length)
  header = right(d2x(payload~length), 8, "0")~upper
  return .TerminalResult~success(header || payload)

::method decode class public
  use strict arg frameArg, maximumBytesArg = 65536
  numeric digits 20
  frame = frameArg~string
  if \datatype(maximumBytesArg, "W") then return .TerminalResult~failure("BROKER_FRAME_LIMIT_INVALID", "maximum frame bytes must be a positive whole number")
  if maximumBytesArg < 1 then return .TerminalResult~failure("BROKER_FRAME_LIMIT_INVALID", "maximum frame bytes must be positive")
  if frame~length < 8 then return .TerminalResult~failure("BROKER_FRAME_INCOMPLETE", "8-byte length header required")
  header = frame~left(8)
  if verify(header~upper, "0123456789ABCDEF") \= 0 then return .TerminalResult~failure("BROKER_FRAME_HEADER_INVALID", "length header must contain exactly eight hexadecimal digits")
  payloadLength = x2d(header)
  if payloadLength > maximumBytesArg then return .TerminalResult~failure("BROKER_FRAME_TOO_LARGE", payloadLength)
  expected = payloadLength + 8
  if frame~length < expected then return .TerminalResult~failure("BROKER_FRAME_INCOMPLETE", "declared payload is incomplete")
  if frame~length > expected then return .TerminalResult~failure("BROKER_FRAME_TRAILING_DATA", "exactly one frame is accepted")
  return .TerminalResult~success(frame~substr(9, payloadLength))


::class TerminalBrokerProtocolProjection public

::method snapshot class public
  use strict arg snapshot
  if snapshot == .nil then return .nil
  d = .directory~new
  d["generation"] = snapshot~generation
  d["terminal_type"] = snapshot~terminalType~string
  d["rows"] = snapshot~rows
  d["columns"] = snapshot~columns
  d["cursor_row"] = snapshot~cursorRow
  d["cursor_column"] = snapshot~cursorColumn
  d["keyboard_state"] = snapshot~keyboardState~string
  d["session_state"] = snapshot~sessionState~string
  d["content_digest"] = snapshot~contentDigest~string
  d["layout_fingerprint"] = snapshot~layoutFingerprint~string
  d["timestamp"] = snapshot~timestamp~string

  fields = snapshot~fields
  outFields = .array~new
  do field over fields
    f = .directory~new
    f["field_id"] = field~fieldId~string
    f["row"] = field~row
    f["column"] = field~column
    f["length"] = field~length
    if field~nonDisplay then f["value"] = "<SECRET>"
    else f["value"] = field~value~string
    f["input_capable"] = field~inputCapable == .true
    f["protected"] = field~protected == .true
    f["non_display"] = field~nonDisplay == .true
    f["modified"] = field~modified == .true
    f["numeric"] = field~numeric == .true
    outFields~append(f)
  end
  d["fields"] = outFields

  /* The presentation text is already safe in the normal terminal model, but
   * defensively overwrite every host-declared NONDISPLAY cell again.  5250
   * fields can wrap across rows, so masking uses linear presentation offsets. */
  safeRows = snapshot~textRows
  columns = snapshot~columns
  rows = snapshot~rows
  if datatype(columns, "W") then do
    if columns > 0 then do field over fields
      if field~nonDisplay then do
        startPosition = ((field~row - 1) * columns) + field~column
        do offset = 0 to field~length - 1
          position = startPosition + offset
          targetRow = ((position - 1) % columns) + 1
          targetColumn = ((position - 1) // columns) + 1
          if targetRow >= 1 & targetRow <= rows then do
            line = safeRows~at(targetRow)
            if line == .nil then line = ""
            if line~length < targetColumn then line = line~left(targetColumn)
            line = overlay("*", line, targetColumn, 1)
            safeRows[targetRow] = line
          end
        end
      end
    end
  end
  d["text_rows"] = safeRows

  caps = snapshot~capabilities
  if caps \== .nil then do
    if caps~hasMethod("NAMES") then d["capabilities"] = caps~names
  end
  if \d~hasIndex("capabilities") then d["capabilities"] = .array~new

  condition = snapshot~operatorCondition
  if condition \== .nil then do
    c = .directory~new
    c["state"] = condition~state~string
    c["code"] = condition~code~string
    c["kind"] = condition~kind~string
    c["message"] = condition~message~string
    c["origin"] = condition~origin~string
    c["cursor_row"] = condition~cursorRow
    c["cursor_column"] = condition~cursorColumn
    c["recoverable"] = condition~recoverable == .true
    c["recovery_actions"] = condition~recoveryActions
    d["operator_condition"] = c
  end
  return d

::method brokerStatus class public
  use strict arg status
  d = .directory~new
  d["broker_id"] = status~brokerId~string
  d["session_id"] = status~sessionId~string
  d["state"] = status~state~string
  d["client_count"] = status~clientCount
  d["max_clients"] = status~maxClients
  d["control_active"] = status~controlActive == .true
  d["active_controller_principal"] = status~activeControllerPrincipal~string
  d["active_controller_client_id"] = status~activeControllerClientId~string
  d["active_control_lease_id"] = status~activeControlLeaseId~string
  return d

::method knownStateObservation class public
  use strict arg observation
  d = .directory~new
  d["generation"] = observation~generation
  d["status"] = observation~status~string
  d["state_id"] = observation~stateId~string
  d["candidate_state_ids"] = observation~candidateStateIds
  d["timestamp"] = observation~timestamp~string
  return d

::method knownStateHistory class public
  use strict arg history
  out = .array~new
  if history == .nil then return out
  do observation over history
    out~append(self~knownStateObservation(observation))
  end
  return out

::method meterFacts class public
  use strict arg facts
  out = .array~new
  if facts == .nil then return out
  do fact over facts
    d = .directory~new
    d["fact_type"] = fact~factType~string
    d["quantity"] = fact~quantity
    d["source"] = fact~source~string
    d["generation"] = fact~generation
    d["controller_identity"] = fact~controllerIdentity~string
    d["timestamp"] = fact~timestamp~string
    dimensions = fact~dimensions
    safeDimensions = .directory~new
    if dimensions \== .nil then do key over dimensions~allIndexes
      value = dimensions~at(key)
      if value == .nil then safeDimensions[key~string] = ""
      else safeDimensions[key~string] = value~string
    end
    d["dimensions"] = safeDimensions
    out~append(d)
  end
  return out


::class TerminalBrokerProtocolEndpoint subclass TerminalAlchemyObject public
::attribute protocolVersion get
::attribute maxFrameBytes get
::attribute replayCapacity get
::attribute endpointState get

::method init
  expose broker tokenSource protocolVersion maxFrameBytes replayCapacity replayEntries replayOrder replayCount endpointClients clientTokenIndex attachedProtocolClients controllerTokenIndex admissionHandles admissionHandleCount endpointState alchemySealer alchemyCapabilityAuthority
  use strict arg brokerArg, tokenSourceArg, maxFrameBytesArg = 65536, replayCapacityArg = 128, alchemySealerArg = .nil, alchemyCapabilityAuthorityArg = .nil

  if brokerArg == .nil then raise syntax 88.900 array("TerminalBrokerProtocolEndpoint requires TerminalSessionBroker-like service core")
  requiredBroker = .array~of("ATTACHCLIENT", "DETACHCLIENT", "STATUS", "CONTROLACTIVE")
  do methodName over requiredBroker
    if \brokerArg~hasMethod(methodName) then raise syntax 88.900 array("TerminalBrokerProtocolEndpoint broker missing method " || methodName)
  end
  if tokenSourceArg == .nil then raise syntax 88.900 array("TerminalBrokerProtocolEndpoint requires an injected secure opaque token source; no default generator exists")
  if \tokenSourceArg~hasMethod("ISSUETOKEN") then raise syntax 88.900 array("TerminalBrokerProtocolEndpoint token source must implement issueToken(purpose, principal, bindingId)")
  if \datatype(maxFrameBytesArg, "W") then raise syntax 88.900 array("TerminalBrokerProtocolEndpoint max frame bytes must be a positive whole number")
  if maxFrameBytesArg < 256 then raise syntax 88.900 array("TerminalBrokerProtocolEndpoint max frame bytes must be at least 256")
  if maxFrameBytesArg > 16777216 then raise syntax 88.900 array("TerminalBrokerProtocolEndpoint max frame bytes must not exceed 16777216")
  if \datatype(replayCapacityArg, "W") then raise syntax 88.900 array("TerminalBrokerProtocolEndpoint replay capacity must be a positive whole number")
  if replayCapacityArg < 1 then raise syntax 88.900 array("TerminalBrokerProtocolEndpoint replay capacity must be positive")

  broker = brokerArg
  tokenSource = tokenSourceArg
  protocolVersion = .TerminalBrokerProtocolBuild~PROTOCOL
  maxFrameBytes = maxFrameBytesArg
  replayCapacity = replayCapacityArg
  replayEntries = .table~new
  replayOrder = .queue~new
  replayCount = 0
  endpointClients = .table~new
  clientTokenIndex = .table~new
  attachedProtocolClients = 0
  controllerTokenIndex = .table~new
  admissionHandles = .table~new
  admissionHandleCount = 0
  endpointState = "OPEN"
  alchemySealer = alchemySealerArg
  alchemyCapabilityAuthority = alchemyCapabilityAuthorityArg

  meta = .directory~new
  meta["protocol"] = protocolVersion
  meta["transport"] = "IPC_NEUTRAL"
  self~initTerminalAlchemy("Serialized value-only protocol boundary around TerminalSessionBroker", meta, alchemySealer, alchemyCapabilityAuthority)
  self~registerStateVariable("protocolVersion", "CUSTOMER", "serialized broker protocol version")
  self~registerStateVariable("maxFrameBytes", "CUSTOMER", "maximum accepted serialized frame payload bytes")
  self~registerStateVariable("replayCapacity", "CUSTOMER", "bounded idempotency response retention")
  self~registerStateVariable("replayCount", "CUSTOMER", "currently retained idempotency responses")
  self~registerStateVariable("attachedProtocolClients", "CUSTOMER", "protocol clients currently mapped to broker capabilities")
  self~registerStateVariable("admissionHandleCount", "INTERNAL", "opaque host-registered admission handles")
  self~registerStateVariable("endpointState", "CUSTOMER", "serialized broker endpoint lifecycle state")
  /* broker/tokenSource/maps/facades/reservations/tokens are deliberately not registered. */
  self~registerMethodContract("HANDLEFRAME", "decode one bounded frame and return one bounded framed JSON response", .array~of("PRINCIPAL", "FRAME"), "STRING", .false, "FALSE", "CUSTOMER", "SENSITIVE", "EXTERNAL", "USE")
  self~registerMethodContract("HANDLEJSON", "process one JSON request for an already authenticated transport principal", .array~of("PRINCIPAL", "JSON"), "STRING", .false, "FALSE", "CUSTOMER", "SENSITIVE", "EXTERNAL", "USE")
  self~registerMethodContract("REGISTERADMISSIONHANDLE", "bind one opaque external admission handle to a trusted reservation object", .array~of("PRINCIPAL", "CLIENT_ID", "HANDLE", "RESERVATION"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("REVOKEADMISSIONHANDLE", "remove one opaque admission handle from the trusted endpoint", .array~of("HANDLE"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("QUIESCE", "invalidate all remote protocol capabilities without closing the broker/terminal", .array~of("REASON"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("CLOSE", "invalidate protocol capabilities then close the underlying broker service", .array~new, "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "USE")

::method encodeFrame public
  expose maxFrameBytes
  use strict arg payloadArg
  return .TerminalBrokerFrameCodec~encode(payloadArg, maxFrameBytes)

::method decodeFrame public
  expose maxFrameBytes
  use strict arg frameArg
  return .TerminalBrokerFrameCodec~decode(frameArg, maxFrameBytes)

::method handleFrame public
  expose maxFrameBytes
  use strict arg principalArg, frameArg
  decoded = .TerminalBrokerFrameCodec~decode(frameArg, maxFrameBytes)
  if \decoded~ok then do
    response = self~errorJson("", decoded~code, decoded~detail)
    framed = .TerminalBrokerFrameCodec~encode(response, maxFrameBytes)
    if framed~ok then return framed~value
    return ""
  end
  response = self~handleJson(principalArg, decoded~value)
  framed = .TerminalBrokerFrameCodec~encode(response, maxFrameBytes)
  if framed~ok then return framed~value
  fallback = self~errorJson("", "BROKER_RESPONSE_TOO_LARGE", "response exceeded configured frame limit")
  fallbackFrame = .TerminalBrokerFrameCodec~encode(fallback, maxFrameBytes)
  if fallbackFrame~ok then return fallbackFrame~value
  return ""

::method handleJson public
  expose maxFrameBytes replayEntries endpointState
  use strict arg principalArg, jsonTextArg
  principal = principalArg~string~strip
  if principal == "" then return self~errorJson("", "BROKER_PRINCIPAL_REQUIRED", "authenticated transport principal is required")
  if principal~length > 256 then return self~errorJson("", "BROKER_PRINCIPAL_INVALID", "authenticated principal is too long")
  jsonText = jsonTextArg~string
  if jsonText~length > maxFrameBytes then return self~errorJson("", "BROKER_FRAME_TOO_LARGE", "request exceeds configured frame limit")

  signal on syntax name malformedJson
  request = .json~fromJson(jsonText)
  signal off syntax
  if request == .nil then return self~errorJson("", "BROKER_REQUEST_INVALID", "request must be a JSON object")
  if \request~isA(.Directory) then return self~errorJson("", "BROKER_REQUEST_INVALID", "request must be a JSON object")

  requestId = self~requestString(request, "request_id")
  if requestId == "" then return self~errorJson("", "BROKER_REQUEST_ID_REQUIRED", "request_id is required")
  if requestId~length > 128 then return self~errorJson("", "BROKER_REQUEST_ID_INVALID", "request_id is too long")
  operation = self~requestString(request, "operation")~strip~upper
  if operation == "" then return self~errorJson(requestId, "BROKER_OPERATION_REQUIRED", "operation is required")
  if operation~length > 64 then return self~errorJson(requestId, "BROKER_OPERATION_INVALID", "operation is too long")
  if endpointState == "QUIESCED" then return self~errorJson(requestId, "BROKER_ENDPOINT_QUIESCED", "remote protocol capabilities are quiesced")
  if endpointState == "CLOSED" then return self~errorJson(requestId, "BROKER_ENDPOINT_CLOSED", "serialized broker endpoint is closed")
  if endpointState == "QUIESCE_FAILED" then return self~errorJson(requestId, "BROKER_ENDPOINT_QUIESCE_FAILED", "remote protocol capability revocation did not complete cleanly")
  if endpointState \== "OPEN" then return self~errorJson(requestId, "BROKER_ENDPOINT_NOT_OPEN", endpointState)
  protocol = self~requestString(request, "protocol")
  if protocol \== .TerminalBrokerProtocolBuild~PROTOCOL then return self~errorJson(requestId, "BROKER_PROTOCOL_MISMATCH", "unsupported protocol version")

  replay = self~lookupReplay(principal, requestId, operation)
  if replay~ok then return replay~value
  if replay~code == "BROKER_REQUEST_ID_REUSE" then return self~errorJson(requestId, replay~code, replay~detail)

  params = request~at("params")
  if params == .nil then params = .directory~new
  if \params~isA(.Directory) then do
    response = self~errorJson(requestId, "BROKER_PARAMS_INVALID", "params must be a JSON object")
    self~rememberReplay(principal, requestId, operation, response)
    return response
  end

  responseDir = self~dispatch(principal, requestId, operation, request, params)
  response = .json~toJson(responseDir)
  self~rememberReplay(principal, requestId, operation, response)
  return response

malformedJson:
  signal off syntax
  return self~errorJson("", "BROKER_JSON_INVALID", "request JSON could not be parsed")

::method registerAdmissionHandle public
  expose endpointClients admissionHandles admissionHandleCount
  use strict arg principalArg, clientIdArg, handleArg, reservationArg
  principal = principalArg~string~strip
  clientId = clientIdArg~string~strip
  handle = handleArg~string~strip
  if principal == "" then return .TerminalResult~failure("BROKER_PRINCIPAL_REQUIRED", "authenticated principal required")
  if clientId == "" then return .TerminalResult~failure("BROKER_CLIENT_ID_REQUIRED", "client id required")
  if handle == "" then return .TerminalResult~failure("BROKER_ADMISSION_HANDLE_REQUIRED", "opaque admission handle required")
  if handle~length > 512 then return .TerminalResult~failure("BROKER_ADMISSION_HANDLE_INVALID", "admission handle too long")
  if reservationArg == .nil then return .TerminalResult~failure("BROKER_ADMISSION_RESERVATION_REQUIRED", "trusted reservation object required")
  if admissionHandles~at(handle) \== .nil then return .TerminalResult~failure("BROKER_ADMISSION_HANDLE_EXISTS", "admission handle already registered")
  entry = endpointClients~at(clientId)
  if entry == .nil then return .TerminalResult~failure("BROKER_PROTOCOL_CLIENT_INVALID", "client is not attached through this endpoint")
  if entry["PRINCIPAL"] \== principal then return .TerminalResult~failure("BROKER_PRINCIPAL_MISMATCH", "admission handle principal does not own client")
  rec = .directory~new
  rec["PRINCIPAL"] = principal
  rec["CLIENT_ID"] = clientId
  rec["RESERVATION"] = reservationArg
  admissionHandles~put(rec, handle)
  admissionHandleCount += 1
  self~alchemyTouch("REGISTER_ADMISSION_HANDLE")
  return .TerminalResult~success(.true)

::method revokeAdmissionHandle public
  expose admissionHandles admissionHandleCount
  use strict arg handleArg
  handle = handleArg~string~strip
  if handle == "" then return .TerminalResult~failure("BROKER_ADMISSION_HANDLE_REQUIRED")
  rec = admissionHandles~at(handle)
  if rec == .nil then return .TerminalResult~failure("BROKER_ADMISSION_HANDLE_INVALID", "unknown admission handle")
  admissionHandles~remove(handle)
  admissionHandleCount -= 1
  if admissionHandleCount < 0 then admissionHandleCount = 0
  self~alchemyTouch("REVOKE_ADMISSION_HANDLE")
  return .TerminalResult~success(.true)

::method quiesce public
  expose endpointState
  use strict arg reasonArg = "SERVICE_DRAIN"
  if endpointState == "CLOSED" then return .TerminalResult~failure("BROKER_ENDPOINT_CLOSED")
  if endpointState == "QUIESCED" then return .TerminalResult~success(.true)
  endpointState = "QUIESCING"
  cleared = self~clearRemoteCapabilities(reasonArg)
  if \cleared~ok then do
    endpointState = "QUIESCE_FAILED"
    self~alchemyTouch("QUIESCE_FAILED")
    ignore = self~terminalLifecycleEvent("QUIESCE_FAILED", cleared~code || ":" || cleared~detail)
    return cleared
  end
  endpointState = "QUIESCED"
  self~alchemyTouch("QUIESCE")
  ignore = self~terminalLifecycleEvent("QUIESCED", reasonArg~string)
  return .TerminalResult~success(.true)

::method close public
  expose broker endpointState
  use strict arg
  if endpointState == "CLOSED" then return .TerminalResult~success(.true)
  /* Revoke all endpoint-local bearer mappings even if one broker-side detach
   * reports failure.  Authoritative broker close is the final revocation. */
  cleared = self~clearRemoteCapabilities("PROTOCOL_ENDPOINT_CLOSED")
  endpointState = "QUIESCED"
  closed = broker~close
  if closed~ok then do
    endpointState = "CLOSED"
    self~alchemyTouch("CLOSE")
    ignore = self~terminalLifecycleEvent("CLOSED", "BROKER_PROTOCOL_ENDPOINT_CLOSED")
    ignore = self~alchemyRetire
  end
  else endpointState = "QUIESCE_FAILED"
  return closed

::method clearRemoteCapabilities private
  expose endpointClients clientTokenIndex controllerTokenIndex admissionHandles attachedProtocolClients admissionHandleCount replayEntries replayOrder replayCount
  use strict arg reasonArg
  firstFailure = .nil
  ids = endpointClients~allIndexes
  do clientId over ids
    entry = endpointClients~at(clientId)
    if entry \== .nil then do
      client = entry["CLIENT"]
      if client \== .nil then do
        if client~active then do
          detached = client~detach(reasonArg)
          if \detached~ok & firstFailure == .nil then firstFailure = detached
        end
      end
      /* Endpoint-local authority is revoked even when broker detach fails. */
      self~dropClientEntry(entry)
    end
  end
  endpointClients = .table~new
  clientTokenIndex = .table~new
  controllerTokenIndex = .table~new
  admissionHandles = .table~new
  attachedProtocolClients = 0
  admissionHandleCount = 0
  replayEntries = .table~new
  replayOrder = .queue~new
  replayCount = 0
  if firstFailure \== .nil then return .TerminalResult~failure("BROKER_ENDPOINT_QUIESCE_DETACH_FAILED", firstFailure~code || ":" || firstFailure~detail)
  return .TerminalResult~success(.true)

::method dispatch private
  use strict arg principal, requestId, operation, request, params
  select
    when operation == "ATTACH" then return self~opAttach(principal, requestId)
    when operation == "DETACH" then return self~opDetach(principal, requestId, request)
    when operation == "STATUS" then return self~opStatus(principal, requestId, request)
    when operation == "SNAPSHOT" then return self~opSnapshot(principal, requestId, request)
    when operation == "BACK" then return self~opBack(principal, requestId, request, params)
    when operation == "HISTORY" then return self~opHistory(principal, requestId, request)
    when operation == "KNOWN_STATE" then return self~opKnownState(principal, requestId, request)
    when operation == "KNOWN_STATE_HISTORY" then return self~opKnownStateHistory(principal, requestId, request)
    when operation == "CONTROL_REQUEST" then return self~opControlRequest(principal, requestId, request, params)
    when operation == "CONTROL_STATUS" then return self~opControlStatus(principal, requestId, request)
    when operation == "CONTROL_RELEASE" then return self~opControlRelease(principal, requestId, request, params)
    when operation == "CONTROL_HANDOFF" then return self~opControlHandoff(principal, requestId, request, params)
    when operation == "CAPABILITIES" then return self~opCapabilities(principal, requestId, request)
    when operation == "METER_FACTS" then return self~opMeterFacts(principal, requestId, request)
    when operation == "SET_FIELD" then return self~opSetField(principal, requestId, request, params)
    when operation == "TYPE_AT_CURSOR" then return self~opTypeAtCursor(principal, requestId, request, params)
    when operation == "MOVE_CURSOR" then return self~opMoveCursor(principal, requestId, request, params)
    when operation == "FOCUS_FIELD" then return self~opFocusField(principal, requestId, request, params)
    when operation == "NEXT_INPUT_FIELD" then return self~opSimpleGenerationMutation(principal, requestId, request, params, "NEXT_INPUT_FIELD")
    when operation == "PREVIOUS_INPUT_FIELD" then return self~opSimpleGenerationMutation(principal, requestId, request, params, "PREVIOUS_INPUT_FIELD")
    when operation == "HOME" then return self~opSimpleGenerationMutation(principal, requestId, request, params, "HOME")
    when operation == "ERROR_RESET" then return self~opSimpleGenerationMutation(principal, requestId, request, params, "ERROR_RESET")
    when operation == "PRESS" then return self~opPress(principal, requestId, request, params)
    when operation == "SYSTEM_REQUEST" then return self~opSimpleGenerationMutation(principal, requestId, request, params, "SYSTEM_REQUEST")
    otherwise return self~responseDirectory(requestId, .false, "BROKER_OPERATION_UNSUPPORTED", "operation is not supported by this protocol version")
  end

::method opAttach private
  expose broker endpointClients clientTokenIndex attachedProtocolClients
  use strict arg principal, requestId
  attached = broker~attachClient(principal)
  if \attached~ok then return self~fromTerminalResult(requestId, attached)
  client = attached~value
  if client == .nil then return self~responseDirectory(requestId, .false, "BROKER_PROTOCOL_CLIENT_INVALID", "broker returned no client capability")
  tokenResult = self~issueUniqueToken("CLIENT", principal, client~clientId)
  if \tokenResult~ok then do
    ignore = client~detach("TOKEN_ISSUE_FAILED")
    return self~fromTerminalResult(requestId, tokenResult)
  end
  token = tokenResult~value
  entry = .directory~new
  entry["CLIENT"] = client
  entry["CLIENT_ID"] = client~clientId~string
  entry["PRINCIPAL"] = principal
  entry["CLIENT_TOKEN"] = token
  entry["CONTROLLER"] = .nil
  entry["CONTROLLER_TOKEN"] = ""
  endpointClients~put(entry, client~clientId~string)
  clientTokenIndex~put(entry, token)
  attachedProtocolClients += 1
  self~alchemyTouch("PROTOCOL_ATTACH")
  payloadOut = .directory~new
  payloadOut["broker_id"] = client~brokerId~string
  payloadOut["session_id"] = client~sessionId~string
  payloadOut["client_id"] = client~clientId~string
  payloadOut["principal"] = principal
  payloadOut["client_token"] = token
  return self~responseDirectory(requestId, .true, "OK", "", payloadOut)

::method opDetach private
  use strict arg principal, requestId, request
  checked = self~requireClientRequest(principal, request)
  if \checked~ok then return self~fromTerminalResult(requestId, checked)
  entry = checked~value
  client = entry["CLIENT"]
  detached = client~detach("PROTOCOL_DETACH")
  if \detached~ok then return self~fromTerminalResult(requestId, detached)
  self~dropClientEntry(entry)
  self~alchemyTouch("PROTOCOL_DETACH")
  return self~responseDirectory(requestId, .true, "OK", "", .true)

::method opStatus private
  expose broker
  use strict arg principal, requestId, request
  checked = self~requireClientRequest(principal, request)
  if \checked~ok then return self~fromTerminalResult(requestId, checked)
  status = broker~status
  return self~responseDirectory(requestId, .true, "OK", "", .TerminalBrokerProtocolProjection~brokerStatus(status))

::method opSnapshot private
  use strict arg principal, requestId, request
  checked = self~requireClientRequest(principal, request)
  if \checked~ok then return self~fromTerminalResult(requestId, checked)
  observed = checked~value["CLIENT"]~snapshot
  if \observed~ok then return self~fromTerminalResult(requestId, observed)
  return self~responseDirectory(requestId, .true, "OK", "", .TerminalBrokerProtocolProjection~snapshot(observed~value))

::method opBack private
  use strict arg principal, requestId, request, params
  checked = self~requireClientRequest(principal, request)
  if \checked~ok then return self~fromTerminalResult(requestId, checked)
  countArg = self~paramWhole(params, "count", 1)
  if countArg < 1 then return self~responseDirectory(requestId, .false, "BROKER_PARAM_INVALID", "count must be a positive whole number")
  observed = checked~value["CLIENT"]~back(countArg)
  if \observed~ok then return self~fromTerminalResult(requestId, observed)
  return self~responseDirectory(requestId, .true, "OK", "", .TerminalBrokerProtocolProjection~snapshot(observed~value))

::method opHistory private
  use strict arg principal, requestId, request
  checked = self~requireClientRequest(principal, request)
  if \checked~ok then return self~fromTerminalResult(requestId, checked)
  history = checked~value["CLIENT"]~history
  if \history~ok then return self~fromTerminalResult(requestId, history)
  out = .array~new
  if history~value \== .nil then do snapshot over history~value
    out~append(.TerminalBrokerProtocolProjection~snapshot(snapshot))
  end
  return self~responseDirectory(requestId, .true, "OK", "", out)

::method opKnownState private
  use strict arg principal, requestId, request
  checked = self~requireClientRequest(principal, request)
  if \checked~ok then return self~fromTerminalResult(requestId, checked)
  client = checked~value["CLIENT"]
  status = client~knownStateStatus
  if \status~ok then return self~fromTerminalResult(requestId, status)
  stateId = client~knownStateId
  if \stateId~ok then return self~fromTerminalResult(requestId, stateId)
  generation = client~knownStateGeneration
  if \generation~ok then return self~fromTerminalResult(requestId, generation)
  payloadOut = .directory~new
  payloadOut["status"] = status~value~string
  payloadOut["state_id"] = stateId~value~string
  payloadOut["generation"] = generation~value
  return self~responseDirectory(requestId, .true, "OK", "", payloadOut)

::method opKnownStateHistory private
  use strict arg principal, requestId, request
  checked = self~requireClientRequest(principal, request)
  if \checked~ok then return self~fromTerminalResult(requestId, checked)
  history = checked~value["CLIENT"]~knownStateHistory
  if \history~ok then return self~fromTerminalResult(requestId, history)
  return self~responseDirectory(requestId, .true, "OK", "", .TerminalBrokerProtocolProjection~knownStateHistory(history~value))

::method opControlRequest private
  use strict arg principal, requestId, request, params
  checked = self~requireClientRequest(principal, request)
  if \checked~ok then return self~fromTerminalResult(requestId, checked)
  entry = checked~value
  if entry["CONTROLLER"] \== .nil then do
    if entry["CONTROLLER"]~active then return self~responseDirectory(requestId, .false, "CONTROL_BUSY", "client already holds control")
    self~clearControllerEntry(entry)
  end
  handle = self~paramString(params, "admission_handle")
  if handle == "" then return self~responseDirectory(requestId, .false, "BROKER_ADMISSION_HANDLE_REQUIRED", "admission_handle is required")
  admission = self~resolveAdmissionHandle(handle, principal, entry["CLIENT_ID"])
  if \admission~ok then return self~fromTerminalResult(requestId, admission)
  capabilities = self~paramArray(params, "capabilities")
  acquired = entry["CLIENT"]~requestControl(admission~value, capabilities)
  if \acquired~ok then return self~fromTerminalResult(requestId, acquired)
  controller = acquired~value
  tokenResult = self~installController(entry, controller)
  if \tokenResult~ok then do
    if controller \== .nil then do
      if controller~active then ignore = controller~release("PROTOCOL_TOKEN_ISSUE_FAILED")
    end
    return self~fromTerminalResult(requestId, tokenResult)
  end
  ignore = self~consumeAdmissionHandle(handle)
  payloadOut = self~controllerDescriptor(entry, .true)
  return self~responseDirectory(requestId, .true, "OK", "", payloadOut)

::method opControlStatus private
  use strict arg principal, requestId, request
  checked = self~requireClientRequest(principal, request)
  if \checked~ok then return self~fromTerminalResult(requestId, checked)
  entry = checked~value
  self~reconcileControllerEntry(entry)
  payloadOut = self~controllerDescriptor(entry, .true)
  return self~responseDirectory(requestId, .true, "OK", "", payloadOut)

::method opControlRelease private
  use strict arg principal, requestId, request, params
  checked = self~requireControllerRequest(principal, request)
  if \checked~ok then return self~fromTerminalResult(requestId, checked)
  entry = checked~value
  reason = self~paramString(params, "reason")
  if reason == "" then reason = "PROTOCOL_RELEASE"
  released = entry["CONTROLLER"]~release(reason)
  if \released~ok then return self~fromTerminalResult(requestId, released)
  self~clearControllerEntry(entry)
  self~alchemyTouch("PROTOCOL_CONTROL_RELEASE")
  return self~responseDirectory(requestId, .true, "OK", "", .true)

::method opControlHandoff private
  expose endpointClients
  use strict arg principal, requestId, request, params
  checked = self~requireControllerRequest(principal, request)
  if \checked~ok then return self~fromTerminalResult(requestId, checked)
  sourceEntry = checked~value
  targetId = self~paramString(params, "target_client_id")
  if targetId == "" then return self~responseDirectory(requestId, .false, "BROKER_TARGET_CLIENT_REQUIRED", "target_client_id is required")
  targetEntry = endpointClients~at(targetId)
  if targetEntry == .nil then return self~responseDirectory(requestId, .false, "BROKER_TARGET_CLIENT_INVALID", "target client is not attached")
  if targetEntry == sourceEntry then return self~responseDirectory(requestId, .false, "BROKER_TARGET_CLIENT_INVALID", "controller cannot hand off to itself")
  handle = self~paramString(params, "admission_handle")
  if handle == "" then return self~responseDirectory(requestId, .false, "BROKER_ADMISSION_HANDLE_REQUIRED", "admission_handle is required for target control")
  admission = self~resolveAdmissionHandle(handle, targetEntry["PRINCIPAL"], targetEntry["CLIENT_ID"])
  if \admission~ok then return self~fromTerminalResult(requestId, admission)
  capabilities = self~paramArray(params, "capabilities")
  oldController = sourceEntry["CONTROLLER"]
  handed = oldController~handoffTo(targetEntry["CLIENT"], admission~value, capabilities)
  if \handed~ok then do
    self~reconcileControllerEntry(sourceEntry)
    return self~fromTerminalResult(requestId, handed)
  end
  self~clearControllerEntry(sourceEntry)
  tokenResult = self~installController(targetEntry, handed~value)
  if \tokenResult~ok then do
    if handed~value \== .nil then do
      if handed~value~active then ignore = handed~value~release("PROTOCOL_TOKEN_ISSUE_FAILED")
    end
    return self~fromTerminalResult(requestId, tokenResult)
  end
  ignore = self~consumeAdmissionHandle(handle)
  self~alchemyTouch("PROTOCOL_CONTROL_HANDOFF")
  payloadOut = .directory~new
  payloadOut["handoff_complete"] = .true
  payloadOut["target_client_id"] = targetEntry["CLIENT_ID"]
  payloadOut["target_principal"] = targetEntry["PRINCIPAL"]
  payloadOut["controller_token_disclosed"] = .false
  payloadOut["target_must_call"] = "CONTROL_STATUS"
  return self~responseDirectory(requestId, .true, "OK", "", payloadOut)

::method opCapabilities private
  use strict arg principal, requestId, request
  checked = self~requireControllerRequest(principal, request)
  if \checked~ok then return self~fromTerminalResult(requestId, checked)
  value = checked~value["CONTROLLER"]~capabilityNames
  if \value~ok then return self~fromTerminalResult(requestId, value)
  return self~responseDirectory(requestId, .true, "OK", "", value~value)

::method opMeterFacts private
  use strict arg principal, requestId, request
  checked = self~requireControllerRequest(principal, request)
  if \checked~ok then return self~fromTerminalResult(requestId, checked)
  value = checked~value["CONTROLLER"]~meterFacts
  if \value~ok then return self~fromTerminalResult(requestId, value)
  return self~responseDirectory(requestId, .true, "OK", "", .TerminalBrokerProtocolProjection~meterFacts(value~value))

::method opSetField private
  use strict arg principal, requestId, request, params
  checked = self~requireControllerRequest(principal, request)
  if \checked~ok then return self~fromTerminalResult(requestId, checked)
  entry = checked~value
  generation = self~requiredWhole(params, "generation")
  if \generation~ok then return self~fromTerminalResult(requestId, generation)
  fieldId = self~paramString(params, "field_id")
  if fieldId == "" then return self~responseDirectory(requestId, .false, "BROKER_FIELD_ID_REQUIRED", "field_id is required")
  current = entry["CONTROLLER"]~snapshot
  if \current~ok then return self~fromTerminalResult(requestId, current)
  field = current~value~field(fieldId)
  if field \== .nil then do
    if field~nonDisplay then return self~responseDirectory(requestId, .false, "BROKER_REMOTE_SECRET_FIELD_DENIED", "remote protocol cannot write host-declared NONDISPLAY fields")
  end
  if \params~hasIndex("value") then return self~responseDirectory(requestId, .false, "BROKER_VALUE_REQUIRED", "value is required")
  value = params~at("value")
  if value == .nil then value = ""
  else value = value~string
  mutated = entry["CONTROLLER"]~setField(generation~value, fieldId, value)
  return self~projectMutationResult(requestId, mutated)

::method opTypeAtCursor private
  use strict arg principal, requestId, request, params
  checked = self~requireControllerRequest(principal, request)
  if \checked~ok then return self~fromTerminalResult(requestId, checked)
  entry = checked~value
  generation = self~requiredWhole(params, "generation")
  if \generation~ok then return self~fromTerminalResult(requestId, generation)
  current = entry["CONTROLLER"]~snapshot
  if \current~ok then return self~fromTerminalResult(requestId, current)
  snapshot = current~value
  field = snapshot~fieldAt(snapshot~cursorRow, snapshot~cursorColumn)
  if field \== .nil then do
    if field~nonDisplay then return self~responseDirectory(requestId, .false, "BROKER_REMOTE_SECRET_FIELD_DENIED", "remote protocol cannot type into host-declared NONDISPLAY fields")
  end
  if \params~hasIndex("text") then return self~responseDirectory(requestId, .false, "BROKER_TEXT_REQUIRED", "text is required")
  text = params~at("text")
  if text == .nil then text = ""
  else text = text~string
  mutated = entry["CONTROLLER"]~typeAtCursor(generation~value, text)
  return self~projectMutationResult(requestId, mutated)

::method opMoveCursor private
  use strict arg principal, requestId, request, params
  checked = self~requireControllerRequest(principal, request)
  if \checked~ok then return self~fromTerminalResult(requestId, checked)
  generation = self~requiredWhole(params, "generation")
  if \generation~ok then return self~fromTerminalResult(requestId, generation)
  row = self~requiredWhole(params, "row")
  if \row~ok then return self~fromTerminalResult(requestId, row)
  column = self~requiredWhole(params, "column")
  if \column~ok then return self~fromTerminalResult(requestId, column)
  mutated = checked~value["CONTROLLER"]~moveCursor(generation~value, row~value, column~value)
  return self~projectMutationResult(requestId, mutated)

::method opFocusField private
  use strict arg principal, requestId, request, params
  checked = self~requireControllerRequest(principal, request)
  if \checked~ok then return self~fromTerminalResult(requestId, checked)
  generation = self~requiredWhole(params, "generation")
  if \generation~ok then return self~fromTerminalResult(requestId, generation)
  fieldId = self~paramString(params, "field_id")
  if fieldId == "" then return self~responseDirectory(requestId, .false, "BROKER_FIELD_ID_REQUIRED", "field_id is required")
  mutated = checked~value["CONTROLLER"]~focusField(generation~value, fieldId)
  return self~projectMutationResult(requestId, mutated)

::method opSimpleGenerationMutation private
  use strict arg principal, requestId, request, params, kind
  checked = self~requireControllerRequest(principal, request)
  if \checked~ok then return self~fromTerminalResult(requestId, checked)
  generation = self~requiredWhole(params, "generation")
  if \generation~ok then return self~fromTerminalResult(requestId, generation)
  controller = checked~value["CONTROLLER"]
  select
    when kind == "NEXT_INPUT_FIELD" then mutated = controller~nextInputField(generation~value)
    when kind == "PREVIOUS_INPUT_FIELD" then mutated = controller~previousInputField(generation~value)
    when kind == "HOME" then mutated = controller~home(generation~value)
    when kind == "ERROR_RESET" then mutated = controller~errorReset(generation~value)
    when kind == "SYSTEM_REQUEST" then mutated = controller~systemRequest(generation~value)
    otherwise return self~responseDirectory(requestId, .false, "BROKER_OPERATION_UNSUPPORTED", kind)
  end
  return self~projectMutationResult(requestId, mutated)

::method opPress private
  use strict arg principal, requestId, request, params
  checked = self~requireControllerRequest(principal, request)
  if \checked~ok then return self~fromTerminalResult(requestId, checked)
  generation = self~requiredWhole(params, "generation")
  if \generation~ok then return self~fromTerminalResult(requestId, generation)
  aid = self~paramString(params, "aid")~strip~upper
  if aid == "" then return self~responseDirectory(requestId, .false, "BROKER_AID_REQUIRED", "aid is required")
  mutated = checked~value["CONTROLLER"]~press(generation~value, aid)
  return self~projectMutationResult(requestId, mutated)

::method projectMutationResult private
  use strict arg requestId, outcomeArg
  if \outcomeArg~ok then return self~fromTerminalResult(requestId, outcomeArg)
  value = outcomeArg~value
  projected = .nil
  if value \== .nil then do
    if value~hasMethod("GENERATION") & value~hasMethod("TERMINALTYPE") then projected = .TerminalBrokerProtocolProjection~snapshot(value)
    else if value == .true | value == .false then projected = value
    else if value~isA(.String) then projected = value~string
    else projected = .nil
  end
  return self~responseDirectory(requestId, .true, outcomeArg~code, outcomeArg~detail, projected)

::method requireClientRequest private
  expose clientTokenIndex
  use strict arg principal, request
  token = self~requestString(request, "client_token")
  if token == "" then return .TerminalResult~failure("BROKER_CLIENT_TOKEN_REQUIRED", "client_token is required")
  entry = clientTokenIndex~at(token)
  if entry == .nil then return .TerminalResult~failure("BROKER_CLIENT_TOKEN_INVALID", "client bearer token is unknown or inactive")
  if entry["PRINCIPAL"] \== principal then return .TerminalResult~failure("BROKER_PRINCIPAL_MISMATCH", "authenticated principal does not own client token")
  client = entry["CLIENT"]
  if client == .nil then return .TerminalResult~failure("BROKER_PROTOCOL_CLIENT_INVALID", "client capability is unavailable")
  if \client~active then do
    self~dropClientEntry(entry)
    return .TerminalResult~failure("BROKER_CLIENT_INACTIVE", "broker client is inactive")
  end
  return .TerminalResult~success(entry)

::method requireControllerRequest private
  expose controllerTokenIndex
  use strict arg principal, request
  clientCheck = self~requireClientRequest(principal, request)
  if \clientCheck~ok then return clientCheck
  entry = clientCheck~value
  token = self~requestString(request, "controller_token")
  if token == "" then return .TerminalResult~failure("BROKER_CONTROLLER_TOKEN_REQUIRED", "controller_token is required")
  indexed = controllerTokenIndex~at(token)
  if indexed == .nil then return .TerminalResult~failure("BROKER_CONTROLLER_TOKEN_INVALID", "controller bearer token is unknown or inactive")
  if indexed \== entry then return .TerminalResult~failure("BROKER_CONTROLLER_TOKEN_INVALID", "controller token does not belong to client token")
  if entry["PRINCIPAL"] \== principal then return .TerminalResult~failure("BROKER_PRINCIPAL_MISMATCH", "authenticated principal does not own controller token")
  controller = entry["CONTROLLER"]
  if controller == .nil then return .TerminalResult~failure("BROKER_CONTROLLER_TOKEN_INVALID", "controller capability is unavailable")
  if \controller~active then do
    self~clearControllerEntry(entry)
    return .TerminalResult~failure("BROKER_CONTROL_CAPABILITY_INVALID", "controller capability is inactive")
  end
  if entry["CONTROLLER_TOKEN"] \== token then return .TerminalResult~failure("BROKER_CONTROLLER_TOKEN_INVALID", "controller token binding mismatch")
  return .TerminalResult~success(entry)

::method installController private
  expose controllerTokenIndex
  use strict arg entry, controller
  if controller == .nil then return .TerminalResult~failure("BROKER_CONTROL_CAPABILITY_INVALID", "broker returned no controller capability")
  tokenResult = self~issueUniqueToken("CONTROLLER", entry["PRINCIPAL"], controller~leaseId~string)
  if \tokenResult~ok then return tokenResult
  self~clearControllerEntry(entry)
  token = tokenResult~value
  entry["CONTROLLER"] = controller
  entry["CONTROLLER_TOKEN"] = token
  controllerTokenIndex~put(entry, token)
  return .TerminalResult~success(token)

::method reconcileControllerEntry private
  use strict arg entry
  controller = entry["CONTROLLER"]
  if controller == .nil then return .false
  if \controller~active then do
    self~clearControllerEntry(entry)
    return .false
  end
  return .true

::method clearControllerEntry private
  expose controllerTokenIndex
  use strict arg entry
  token = entry["CONTROLLER_TOKEN"]
  if token \== .nil then do
    token = token~string
    if token \= "" then controllerTokenIndex~remove(token)
  end
  entry["CONTROLLER"] = .nil
  entry["CONTROLLER_TOKEN"] = ""
  return .true

::method controllerDescriptor private
  use strict arg entry, discloseToken = .false
  self~reconcileControllerEntry(entry)
  d = .directory~new
  controller = entry["CONTROLLER"]
  if controller == .nil then do
    d["active"] = .false
    d["client_id"] = entry["CLIENT_ID"]
    d["principal"] = entry["PRINCIPAL"]
    return d
  end
  d["active"] = .true
  d["client_id"] = entry["CLIENT_ID"]
  d["principal"] = entry["PRINCIPAL"]
  d["lease_id"] = controller~leaseId~string
  d["scope"] = controller~scope~string
  d["acquired_generation"] = controller~acquiredGeneration
  if discloseToken then d["controller_token"] = entry["CONTROLLER_TOKEN"]
  return d

::method issueUniqueToken private
  expose tokenSource clientTokenIndex controllerTokenIndex
  use strict arg purpose, principal, bindingId
  do attempt = 1 to 16
    token = tokenSource~issueToken(purpose, principal, bindingId)
    if token == .nil then iterate
    token = token~string
    if token~length < 32 then return .TerminalResult~failure("BROKER_TOKEN_SOURCE_WEAK", "token source returned fewer than 32 characters")
    if token~length > 512 then return .TerminalResult~failure("BROKER_TOKEN_SOURCE_INVALID", "token source returned an overlong token")
    if clientTokenIndex~at(token) \== .nil then iterate
    if controllerTokenIndex~at(token) \== .nil then iterate
    return .TerminalResult~success(token)
  end
  return .TerminalResult~failure("BROKER_TOKEN_SOURCE_COLLISION", "token source repeatedly returned active bearer tokens")

::method resolveAdmissionHandle private
  expose admissionHandles
  use strict arg handle, principal, clientId
  rec = admissionHandles~at(handle)
  if rec == .nil then return .TerminalResult~failure("BROKER_ADMISSION_HANDLE_INVALID", "unknown or consumed admission handle")
  if rec["PRINCIPAL"] \== principal then return .TerminalResult~failure("BROKER_ADMISSION_PRINCIPAL_MISMATCH", "admission handle is bound to another principal")
  if rec["CLIENT_ID"] \== clientId then return .TerminalResult~failure("BROKER_ADMISSION_CLIENT_MISMATCH", "admission handle is bound to another client")
  return .TerminalResult~success(rec["RESERVATION"])

::method consumeAdmissionHandle private
  expose admissionHandles admissionHandleCount
  use strict arg handle
  if admissionHandles~at(handle) == .nil then return .false
  admissionHandles~remove(handle)
  admissionHandleCount -= 1
  if admissionHandleCount < 0 then admissionHandleCount = 0
  return .true

::method dropClientEntry private
  expose endpointClients clientTokenIndex admissionHandles attachedProtocolClients admissionHandleCount
  use strict arg entry
  self~clearControllerEntry(entry)
  clientToken = entry["CLIENT_TOKEN"]
  if clientToken \== .nil then clientTokenIndex~remove(clientToken~string)
  clientId = entry["CLIENT_ID"]~string
  endpointClients~remove(clientId)
  handles = admissionHandles~allIndexes
  do handle over handles
    rec = admissionHandles~at(handle)
    if rec \== .nil then do
      if rec["CLIENT_ID"] == clientId then do
        admissionHandles~remove(handle)
        admissionHandleCount -= 1
      end
    end
  end
  if admissionHandleCount < 0 then admissionHandleCount = 0
  attachedProtocolClients -= 1
  if attachedProtocolClients < 0 then attachedProtocolClients = 0
  return .true

::method lookupReplay private
  expose replayEntries
  use strict arg principal, requestId, operation
  key = principal || "0"x || requestId
  rec = replayEntries~at(key)
  if rec == .nil then return .TerminalResult~failure("BROKER_REPLAY_MISS")
  if rec["OPERATION"] \== operation then return .TerminalResult~failure("BROKER_REQUEST_ID_REUSE", "request_id was already used for another operation")
  return .TerminalResult~success(rec["RESPONSE"])

::method rememberReplay private
  expose replayEntries replayOrder replayCount replayCapacity
  use strict arg principal, requestId, operation, response
  key = principal || "0"x || requestId
  existing = replayEntries~at(key)
  if existing \== .nil then return .false
  rec = .directory~new
  rec["OPERATION"] = operation
  rec["RESPONSE"] = response~string
  replayEntries~put(rec, key)
  replayOrder~queue(key)
  replayCount += 1
  do while replayCount > replayCapacity
    if replayOrder~items < 1 then leave
    oldest = replayOrder~pull
    if replayEntries~at(oldest) \== .nil then do
      replayEntries~remove(oldest)
      replayCount -= 1
    end
  end
  self~alchemyTouch("PROTOCOL_REPLAY_STORE")
  return .true

::method requestString private
  use strict arg request, key
  value = request~at(key)
  if value == .nil then return ""
  return value~string

::method paramString private
  use strict arg params, key
  value = params~at(key)
  if value == .nil then return ""
  return value~string

::method paramArray private
  use strict arg params, key
  value = params~at(key)
  if value == .nil then return .nil
  if \value~isA(.Array) then return .nil
  out = .array~new
  do item over value
    if item == .nil then iterate
    out~append(item~string)
  end
  return out

::method paramWhole private
  use strict arg params, key, defaultValue
  value = params~at(key)
  if value == .nil then return defaultValue
  if \datatype(value, "W") then return -1
  return value + 0

::method requiredWhole private
  use strict arg params, key
  value = params~at(key)
  if value == .nil then return .TerminalResult~failure("BROKER_PARAM_REQUIRED", key || " is required")
  if \datatype(value, "W") then return .TerminalResult~failure("BROKER_PARAM_INVALID", key || " must be a whole number")
  return .TerminalResult~success(value + 0)

::method fromTerminalResult private
  use strict arg requestId, terminalResult
  return self~responseDirectory(requestId, terminalResult~ok, terminalResult~code, terminalResult~detail)

::method responseDirectory private
  use strict arg requestId, okArg, codeArg, detailArg = "", resultArg = .nil
  d = .directory~new
  d["protocol"] = .TerminalBrokerProtocolBuild~PROTOCOL
  d["request_id"] = requestId~string
  d["ok"] = okArg == .true
  d["code"] = codeArg~string
  d["detail"] = detailArg~string
  if resultArg \== .nil then d["result"] = resultArg
  return d

::method errorJson private
  use strict arg requestId, code, detail = ""
  return .json~toJson(self~responseDirectory(requestId, .false, code, detail))

::requires "TerminalBroker.cls"
::requires "json.cls"
