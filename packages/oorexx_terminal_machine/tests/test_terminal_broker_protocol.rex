failures = 0

broker = .ProtoBroker~new
tokens = .ProtoTokenSource~new
sealer = .ProtoEvidenceSealer~new
authority = .ProtoCapabilityAuthority~new
endpoint = .TerminalBrokerProtocolEndpoint~new(broker, tokens, 65536, 32, sealer, authority)

call assertTrue endpoint~isA(.AlchemyObject), "protocol endpoint inherits AlchemyObject"
call assertTrue endpoint~checkSurfaceContract~ok, "protocol endpoint Alchemy surface contract"
call assertEq endpoint~protocolVersion, "terminal.broker.ipc/0.1", "protocol version"

/* Exact 8-hex framing and single-frame fail-closed behavior. */
encoded = .TerminalBrokerFrameCodec~encode("abc", 16)
call assertTrue encoded~ok, "frame encode"
call assertEq encoded~value, "00000003abc", "frame header"
decoded = .TerminalBrokerFrameCodec~decode(encoded~value, 16)
call assertTrue decoded~ok, "frame decode"
call assertEq decoded~value, "abc", "frame payload"
call assertEq .TerminalBrokerFrameCodec~decode("ZZZZZZZZabc", 16)~code, "BROKER_FRAME_HEADER_INVALID", "bad hex rejected"
call assertEq .TerminalBrokerFrameCodec~decode("00000003ab", 16)~code, "BROKER_FRAME_INCOMPLETE", "short frame rejected"
call assertEq .TerminalBrokerFrameCodec~decode("00000003abcd", 16)~code, "BROKER_FRAME_TRAILING_DATA", "trailing frame data rejected"
call assertEq .TerminalBrokerFrameCodec~decode("00000020", 16)~code, "BROKER_FRAME_TOO_LARGE", "declared oversize rejected before payload"

/* Attach is replay-safe: a lost response can be retried without a second
 * broker attachment or a second session. */
attachReq = request("attach-1", "ATTACH")
attach1 = callFrame(endpoint, "AI_A", attachReq)
call assertTrue attach1["ok"], "attach A"
clientA = attach1["result"]["client_id"]
clientTokenA = attach1["result"]["client_token"]
call assertEq broker~attachCount, 1, "one broker attachment"
attachReplay = callFrame(endpoint, "AI_A", attachReq)
call assertTrue attachReplay["ok"], "attach replay succeeds"
call assertEq attachReplay["result"]["client_token"], clientTokenA, "attach replay returns same bearer"
call assertEq broker~attachCount, 1, "attach replay does not duplicate client"

attachB = callFrame(endpoint, "AI_B", request("attach-b", "ATTACH"))
call assertTrue attachB["ok"], "attach B"
clientB = attachB["result"]["client_id"]
clientTokenB = attachB["result"]["client_token"]

/* The transport-authenticated principal is authoritative; body bearer tokens
 * cannot be moved to another authenticated principal. */
wrong = request("wrong-principal", "SNAPSHOT")
wrong["client_token"] = clientTokenA
wrongResp = callFrame(endpoint, "AI_B", wrong)
call assertTrue \wrongResp["ok"], "cross-principal client token rejected"
call assertEq wrongResp["code"], "BROKER_PRINCIPAL_MISMATCH", "principal mismatch code"

/* Snapshot projection re-masks both field value and presentation cells even
 * though this deliberately hostile fixture supplies raw secret text. */
snapReq = request("snap-1", "SNAPSHOT")
snapReq["client_token"] = clientTokenA
snapResp = callFrame(endpoint, "AI_A", snapReq)
call assertTrue snapResp["ok"], "snapshot response"
fields = snapResp["result"]["fields"]
call assertEq fields[1]["value"], "<SECRET>", "nondisplay field value masked"
call assertEq snapResp["result"]["text_rows"][1]~left(4), "****", "nondisplay screen cells re-masked"
snapJson = .json~toJson(snapResp)
call assertTrue snapJson~pos("p@ss") == 0, "raw secret absent from serialized snapshot"

/* Register real reservation objects only in trusted host memory. */
resA = .ProtoReservation~new("AI_A", "TERMINAL:PROTO")
resB = .ProtoReservation~new("AI_B", "TERMINAL:PROTO")
call assertTrue endpoint~registerAdmissionHandle("AI_A", clientA, "adm-A-001", resA)~ok, "register A admission handle"
call assertTrue endpoint~registerAdmissionHandle("AI_B", clientB, "adm-B-001", resB)~ok, "register B admission handle"

controlReq = request("control-a", "CONTROL_REQUEST")
controlReq["client_token"] = clientTokenA
p = .directory~new
p["admission_handle"] = "adm-A-001"
p["capabilities"] = .array~of("AID", "FIELD_WRITE")
controlReq["params"] = p
controlA = callFrame(endpoint, "AI_A", controlReq)
call assertTrue controlA["ok"], "A acquires control"
controllerTokenA = controlA["result"]["controller_token"]
call assertTrue controllerTokenA~length >= 32, "opaque controller token minimum length"
call assertEq broker~peakControllers, 1, "one writer"
call assertEq broker~mutationCount, 0, "no mutation during admission"

/* Remote secret input is prohibited before the controller can mutate.  The
 * rejected plaintext is not echoed in the response and a replay with another
 * plaintext returns only the cached safe response. */
secretReq = request("secret-write", "SET_FIELD")
secretReq["client_token"] = clientTokenA
secretReq["controller_token"] = controllerTokenA
sp = .directory~new
sp["generation"] = 7
sp["field_id"] = "SECRET"
sp["value"] = "NeverRetainThisPassword"
secretReq["params"] = sp
secretResp = callFrame(endpoint, "AI_A", secretReq)
call assertTrue \secretResp["ok"], "remote nondisplay setField denied"
call assertEq secretResp["code"], "BROKER_REMOTE_SECRET_FIELD_DENIED", "secret setField code"
call assertEq broker~mutationCount, 0, "secret denial occurs before mutation"
call assertTrue .json~toJson(secretResp)~pos("NeverRetainThisPassword") == 0, "secret not echoed in response"
sp["value"] = "DifferentSecretOnReplay"
secretReplay = callFrame(endpoint, "AI_A", secretReq)
call assertEq .json~toJson(secretReplay), .json~toJson(secretResp), "request-id replay returns cached safe response"
call assertEq broker~mutationCount, 0, "replayed secret request cannot mutate"

/* Cursor-relative typing into NONDISPLAY is equally blocked. */
typeSecret = request("secret-type", "TYPE_AT_CURSOR")
typeSecret["client_token"] = clientTokenA
typeSecret["controller_token"] = controllerTokenA
tp = .directory~new
tp["generation"] = 7
tp["text"] = "AlsoSecret"
typeSecret["params"] = tp
typeResp = callFrame(endpoint, "AI_A", typeSecret)
call assertTrue \typeResp["ok"], "remote nondisplay type denied"
call assertEq typeResp["code"], "BROKER_REMOTE_SECRET_FIELD_DENIED", "secret type code"
call assertEq broker~mutationCount, 0, "secret cursor denial before mutation"

/* Ordinary nonsecret mutation still works under current generation authority. */
moveReq = request("move-normal", "MOVE_CURSOR")
moveReq["client_token"] = clientTokenA
moveReq["controller_token"] = controllerTokenA
mp = .directory~new
mp["generation"] = 7
mp["row"] = 1
mp["column"] = 6
moveReq["params"] = mp
moveResp = callFrame(endpoint, "AI_A", moveReq)
call assertTrue moveResp["ok"], "move cursor to ordinary field"
call assertEq broker~mutationCount, 1, "cursor mutation counted"

typeReq = request("type-normal", "TYPE_AT_CURSOR")
typeReq["client_token"] = clientTokenA
typeReq["controller_token"] = controllerTokenA
tp2 = .directory~new
tp2["generation"] = 7
tp2["text"] = "x"
typeReq["params"] = tp2
typeNormal = callFrame(endpoint, "AI_A", typeReq)
call assertTrue typeNormal["ok"], "ordinary cursor typing succeeds"
call assertEq broker~mutationCount, 2, "ordinary typing mutates once"

/* Current controller may select the handoff target, but never receives the
 * target's controller bearer. */
handoffReq = request("handoff-ab", "CONTROL_HANDOFF")
handoffReq["client_token"] = clientTokenA
handoffReq["controller_token"] = controllerTokenA
hp = .directory~new
hp["target_client_id"] = clientB
hp["admission_handle"] = "adm-B-001"
hp["capabilities"] = .array~of("AID")
handoffReq["params"] = hp
handoff = callFrame(endpoint, "AI_A", handoffReq)
call assertTrue handoff["ok"], "handoff A to B"
call assertTrue \handoff["result"]~hasIndex("controller_token"), "old controller receives no target controller token"
call assertTrue \handoff["result"]["controller_token_disclosed"], "handoff disclosure marker false"
call assertEq broker~peakControllers, 1, "handoff never overlaps writers"
call assertEq broker~releaseBeforeAcquireViolations, 0, "old writer released before new writer"

statusBReq = request("control-status-b", "CONTROL_STATUS")
statusBReq["client_token"] = clientTokenB
statusB = callFrame(endpoint, "AI_B", statusBReq)
call assertTrue statusB["ok"], "target queries own control status"
call assertTrue statusB["result"]["active"], "target control active"
controllerTokenB = statusB["result"]["controller_token"]
call assertTrue controllerTokenB~length >= 32, "target gets own opaque controller token"
call assertTrue .json~toJson(handoff)~pos(controllerTokenB) == 0, "target token absent from old principal handoff response"

oldUse = request("old-use", "PRESS")
oldUse["client_token"] = clientTokenA
oldUse["controller_token"] = controllerTokenA
op = .directory~new
op["generation"] = 7
op["aid"] = "ENTER"
oldUse["params"] = op
oldResp = callFrame(endpoint, "AI_A", oldUse)
call assertTrue \oldResp["ok"], "old controller token inactive after handoff"
call assertEq oldResp["code"], "BROKER_CONTROLLER_TOKEN_INVALID", "old token invalid code"

/* request_id cannot silently change operation under the same principal. */
reuse = request("snap-1", "STATUS")
reuse["client_token"] = clientTokenA
reuseResp = callFrame(endpoint, "AI_A", reuse)
call assertTrue \reuseResp["ok"], "request id cross-operation reuse rejected"
call assertEq reuseResp["code"], "BROKER_REQUEST_ID_REUSE", "request id reuse code"

/* FULL Alchemy state remains scalar evidence.  Tokens, broker/client/controller
 * objects, replay payloads, admission reservations and maps are unregistered. */
full = endpoint~sealedIntrospection("FULL", .nil)~payload["state"]
call assertMissing full, "BROKER", "FULL state does not export broker"
call assertMissing full, "TOKENSOURCE", "FULL state does not export token source"
call assertMissing full, "ENDPOINTCLIENTS", "FULL state does not export client map"
call assertMissing full, "CLIENTTOKENINDEX", "FULL state does not export client bearers"
call assertMissing full, "CONTROLLERTOKENINDEX", "FULL state does not export controller bearers"
call assertMissing full, "ADMISSIONHANDLES", "FULL state does not export reservations"
call assertMissing full, "REPLAYENTRIES", "FULL state does not export replay responses"
call assertTrue full["REPLAYCOUNT"] <= 32, "replay state remains bounded"

/* v0.17 service drain quiesces remote capability state without closing the
 * retained terminal broker.  Existing clients/controllers/admission handles
 * disappear before orderly terminal signoff is attempted by the service. */
call assertTrue endpoint~quiesce("TEST_DRAIN")~ok, "protocol endpoint quiesces"
call assertEq endpoint~endpointState, "QUIESCED", "endpoint state quiesced"
call assertEq broker~closeCount, 0, "quiesce does not close broker"
call assertTrue \broker~controlActive, "quiesce releases active remote controller"
call assertEq broker~status~clientCount, 0, "quiesce detaches all protocol clients"
quiescedReq = request("after-quiesce", "STATUS")
quiescedResp = callFrame(endpoint, "AI_A", quiescedReq)
call assertTrue \quiescedResp["ok"], "quiesced endpoint rejects new request"
call assertEq quiescedResp["code"], "BROKER_ENDPOINT_QUIESCED", "quiesced endpoint code"
fullQ = endpoint~sealedIntrospection("FULL", .nil)~payload["state"]
call assertEq fullQ["ENDPOINTSTATE"], "QUIESCED", "Alchemy exposes scalar quiesce state"
call assertEq fullQ["ATTACHEDPROTOCOLCLIENTS"], 0, "Alchemy reports zero remote clients after quiesce"
call assertEq fullQ["ADMISSIONHANDLECOUNT"], 0, "Alchemy reports zero admission handles after quiesce"
call assertEq fullQ["REPLAYCOUNT"], 0, "quiesce clears replay retention"

call assertTrue endpoint~close~ok, "protocol endpoint closes broker"
call assertEq broker~closeCount, 1, "broker closed exactly once"

/* A broker-side detach failure during service quiesce must not be hidden.
 * Endpoint-local bearers are still revoked and the endpoint becomes fail-closed;
 * authoritative endpoint close may then close the broker itself. */
brokerFail = .ProtoBroker~new
tokensFail = .ProtoTokenSource~new
endpointFail = .TerminalBrokerProtocolEndpoint~new(brokerFail, tokensFail, 65536, 8, sealer, authority)
failAttach = callFrame(endpointFail, "AI_FAIL", request("attach-fail", "ATTACH"))
call assertTrue failAttach["ok"], "detach-failure fixture attaches"
brokerFail~failDetach(.true)
qFail = endpointFail~quiesce("FAIL_CLOSED_TEST")
call assertTrue \qFail~ok, "quiesce surfaces broker detach failure"
call assertEq qFail~code, "BROKER_ENDPOINT_QUIESCE_DETACH_FAILED", "quiesce detach-failure code"
call assertEq endpointFail~endpointState, "QUIESCE_FAILED", "endpoint enters fail-closed quiesce state"
call assertEq brokerFail~status~clientCount, 1, "failed broker detach remains visible to signoff precondition"
blockedAfterFailure = callFrame(endpointFail, "AI_FAIL", request("blocked-after-fail", "STATUS"))
call assertTrue \blockedAfterFailure["ok"], "failed quiesce blocks all remote operations"
call assertEq blockedAfterFailure["code"], "BROKER_ENDPOINT_QUIESCE_FAILED", "failed-quiesce request code"
call assertTrue endpointFail~close~ok, "authoritative close recovers from detach failure"
call assertEq brokerFail~closeCount, 1, "authoritative broker close after quiesce failure"
call assertEq endpointFail~endpointState, "CLOSED", "endpoint closes after authoritative broker close"

if failures > 0 then do
  say "FAIL test_terminal_broker_protocol" failures
  exit 1
end
say "PASS test_terminal_broker_protocol"
exit 0

request: procedure
  use strict arg requestId, operation
  d = .directory~new
  d["protocol"] = "terminal.broker.ipc/0.1"
  d["request_id"] = requestId
  d["operation"] = operation
  d["params"] = .directory~new
  return d

callFrame: procedure
  use strict arg endpoint, principal, request
  jsonText = .json~toJson(request)
  framed = endpoint~encodeFrame(jsonText)
  if \framed~ok then raise syntax 88.900 array("test request frame encoding failed")
  responseFrame = endpoint~handleFrame(principal, framed~value)
  decoded = endpoint~decodeFrame(responseFrame)
  if \decoded~ok then raise syntax 88.900 array("test response frame decoding failed: " || decoded~code)
  return .json~fromJson(decoded~value)

assertTrue: procedure expose failures
  use arg condition, label
  if condition then return
  failures += 1
  say "ASSERT_TRUE FAIL:" label
  return

assertEq: procedure expose failures
  use arg actual, expected, label
  if actual == expected then return
  failures += 1
  say "ASSERT_EQ FAIL:" label "expected="expected "actual="actual
  return

assertMissing: procedure expose failures
  use arg state, key, label
  if \state~hasIndex(key) then return
  failures += 1
  say "ASSERT_MISSING FAIL:" label "key="key
  return

::class ProtoEvidenceEnvelope
::attribute payload get
::method init
  expose payload
  use strict arg payloadArg
  payload = payloadArg

::class ProtoEvidenceSealer
::method seal
  use strict arg producer, payload
  return .ProtoEvidenceEnvelope~new(payload)

::class ProtoCapabilityAuthority
::method verify
  use arg capability, objectId, operation, purpose, requireActive = .true
  return .true

::class ProtoTokenSource
::method init
  expose sequence
  sequence = 0
::method issueToken
  expose sequence
  use strict arg purpose, principal, bindingId
  sequence += 1
  return "proto-token-" || right(sequence, 8, "0") || "-0123456789abcdef0123456789abcdef"

::class ProtoReservation
::attribute identity get
::attribute scope get
::method init
  expose identity scope
  use strict arg identityArg, scopeArg
  identity = identityArg~string
  scope = scopeArg~string

::class ProtoBroker
::attribute attachCount get
::attribute mutationCount get
::attribute peakControllers get
::attribute releaseBeforeAcquireViolations get
::attribute closeCount get
::method init
  expose clients principalIndex nextId activeController attachCount mutationCount peakControllers releaseBeforeAcquireViolations closeCount cursorRow cursorColumn failDetachFlag
  clients = .table~new
  principalIndex = .table~new
  nextId = 0
  activeController = .nil
  attachCount = 0
  mutationCount = 0
  peakControllers = 0
  releaseBeforeAcquireViolations = 0
  closeCount = 0
  cursorRow = 1
  cursorColumn = 1
  failDetachFlag = .false
::method failDetach
  expose failDetachFlag
  use strict arg valueArg
  failDetachFlag = valueArg
::method attachClient
  expose clients principalIndex nextId attachCount
  use strict arg principal
  if principalIndex~at(principal) \== .nil then return .TerminalResult~failure("BROKER_CLIENT_ALREADY_ATTACHED", principal)
  nextId += 1
  id = "PCLI-" || right(nextId, 4, "0")
  c = .ProtoClient~new(self, id, principal)
  clients~put(c, id)
  principalIndex~put(id, principal)
  attachCount += 1
  return .TerminalResult~success(c)
::method detachClient
  expose clients principalIndex activeController failDetachFlag
  use strict arg client, reason = "DETACHED"
  if failDetachFlag then return .TerminalResult~failure("FIXTURE_DETACH_FAILED", reason)
  if client == .nil then return .TerminalResult~failure("BROKER_CLIENT_INVALID")
  existing = clients~at(client~clientId)
  if existing \== client then return .TerminalResult~failure("BROKER_CLIENT_INVALID")
  if activeController \== .nil then do
    if activeController~client == client then ignore = self~release(activeController, reason)
  end
  clients~remove(client~clientId)
  principalIndex~remove(client~principal)
  client~invalidate
  return .TerminalResult~success(.true)
::method status
  expose clients activeController
  principal = ""; clientId = ""; leaseId = ""; active = .false
  if activeController \== .nil then do
    if activeController~active then do
      active = .true
      principal = activeController~principal
      clientId = activeController~client~clientId
      leaseId = activeController~leaseId
    end
  end
  return .TerminalBrokerStatus~new("PROTO-BROKER", "PROTO-SESSION", "OPEN", clients~items, 8, active, principal, clientId, leaseId)
::method controlActive
  expose activeController
  if activeController == .nil then return .false
  return activeController~active
::method acquire
  expose activeController peakControllers releaseBeforeAcquireViolations
  use strict arg client, reservation, capabilities = .nil
  if activeController \== .nil then do
    if activeController~active then do
      releaseBeforeAcquireViolations += 1
      return .TerminalResult~failure("CONTROL_BUSY", activeController~principal)
    end
  end
  if reservation == .nil then return .TerminalResult~failure("CONTROL_ADMISSION_REQUIRED")
  if reservation~identity \== client~principal then return .TerminalResult~failure("CONTROL_IDENTITY_MISMATCH")
  activeController = .ProtoController~new(self, client, "P-LEASE-" || client~clientId, capabilities)
  if peakControllers < 1 then peakControllers = 1
  return .TerminalResult~success(activeController)
::method handoff
  expose activeController releaseBeforeAcquireViolations
  use strict arg controller, targetClient, reservation, capabilities = .nil
  if activeController \== controller then return .TerminalResult~failure("BROKER_CONTROL_CAPABILITY_INVALID")
  released = self~release(controller, "HANDOFF")
  if \released~ok then return released
  if activeController \== .nil then do
    if activeController~active then do
      releaseBeforeAcquireViolations += 1
      return .TerminalResult~failure("CONTROL_HANDOFF_NOT_CLEAR")
    end
  end
  return self~acquire(targetClient, reservation, capabilities)
::method release
  expose activeController
  use strict arg controller, reason = "RELEASED"
  if activeController \== controller then return .TerminalResult~failure("BROKER_CONTROL_CAPABILITY_INVALID")
  controller~invalidate
  activeController = .nil
  return .TerminalResult~success(.true)
::method noteMutation
  expose mutationCount
  mutationCount += 1
  return mutationCount
::method cursor
  expose cursorRow cursorColumn
  d = .directory~new
  d["ROW"] = cursorRow
  d["COLUMN"] = cursorColumn
  return d
::method setCursor
  expose cursorRow cursorColumn
  use strict arg row, column
  cursorRow = row
  cursorColumn = column
  self~noteMutation
  return self~snapshot
::method snapshot
  expose cursorRow cursorColumn
  caps = .TerminalCapabilities~new
  caps~add("AID")
  caps~add("FIELD_WRITE")
  attrs = .directory~new
  secret = .TerminalFieldSnapshot~new("SECRET", 1, 1, 4, "p@ss", .true, .false, .true)
  normal = .TerminalFieldSnapshot~new("NORMAL", 1, 6, 5, "hello", .true, .false, .false)
  rows = .array~of("p@ss hello")
  return .TerminalSnapshot~new(7, "PROTO", 1, 20, cursorRow, cursorColumn, "UNLOCKED", "OPEN", rows, .array~of(secret, normal), caps, attrs, "digest", "layout", "2026-08-24T16:00:00Z")
::method close
  expose closeCount activeController clients principalIndex
  if activeController \== .nil then ignore = self~release(activeController, "CLOSED")
  do id over clients~allIndexes
    c = clients~at(id)
    if c \== .nil then c~invalidate
  end
  clients = .table~new
  principalIndex = .table~new
  closeCount += 1
  return .TerminalResult~success(.true)

::class ProtoClient
::attribute clientId get
::attribute principal get
::attribute sessionId get
::attribute brokerId get
::attribute active get
::method init
  expose broker clientId principal sessionId brokerId active
  use strict arg brokerArg, idArg, principalArg
  broker = brokerArg
  clientId = idArg
  principal = principalArg
  sessionId = "PROTO-SESSION"
  brokerId = "PROTO-BROKER"
  active = .true
::method snapshot
  expose broker active
  if \active then return .TerminalResult~failure("BROKER_CLIENT_INACTIVE")
  return .TerminalResult~success(broker~snapshot)
::method current
  return self~snapshot
::method back
  use strict arg count = 1
  return self~snapshot
::method history
  s = self~snapshot
  if \s~ok then return s
  return .TerminalResult~success(.array~of(s~value))
::method knownStateStatus
  return .TerminalResult~success("NO_MATCH")
::method knownStateId
  return .TerminalResult~success("")
::method knownStateGeneration
  return .TerminalResult~success(7)
::method knownStateHistory
  return .TerminalResult~success(.array~new)
::method requestControl
  expose broker active
  use strict arg reservation, capabilities = .nil
  if \active then return .TerminalResult~failure("BROKER_CLIENT_INACTIVE")
  return broker~acquire(self, reservation, capabilities)
::method detach
  expose broker
  use strict arg reason = "DETACHED"
  return broker~detachClient(self, reason)
::method invalidate
  expose active
  active = .false
  return .true

::class ProtoController
::attribute client get
::attribute leaseId get
::attribute principal get
::attribute scope get
::attribute acquiredGeneration get
::attribute active get
::method init
  expose broker client leaseId principal scope acquiredGeneration active capabilities
  use strict arg brokerArg, clientArg, leaseArg, capabilitiesArg = .nil
  broker = brokerArg
  client = clientArg
  leaseId = leaseArg
  principal = client~principal
  scope = "TERMINAL:PROTO"
  acquiredGeneration = 7
  active = .true
  capabilities = .TerminalCapabilities~new
  if capabilitiesArg \== .nil then do c over capabilitiesArg
    capabilities~add(c)
  end
::method snapshot
  expose broker active
  if \active then return .TerminalResult~failure("BROKER_CONTROL_CAPABILITY_INVALID")
  return .TerminalResult~success(broker~snapshot)
::method capabilityNames
  expose capabilities
  return .TerminalResult~success(capabilities~names)
::method meterFacts
  return .TerminalResult~success(.array~of(.TerminalMeterFact~new("AID", 1, "PROTO", .directory~new, 7, self~principal)))
::method release
  expose broker
  use strict arg reason = "RELEASED"
  return broker~release(self, reason)
::method handoffTo
  expose broker
  use strict arg targetClient, reservation, capabilities = .nil
  return broker~handoff(self, targetClient, reservation, capabilities)
::method setField
  expose broker active
  use strict arg generation, fieldId, value
  if \active then return .TerminalResult~failure("BROKER_CONTROL_CAPABILITY_INVALID")
  if generation \== 7 then return .TerminalResult~failure("STALE_SCREEN")
  broker~noteMutation
  return .TerminalResult~success(broker~snapshot)
::method typeAtCursor
  expose broker active
  use strict arg generation, text
  if \active then return .TerminalResult~failure("BROKER_CONTROL_CAPABILITY_INVALID")
  if generation \== 7 then return .TerminalResult~failure("STALE_SCREEN")
  broker~noteMutation
  return .TerminalResult~success(broker~snapshot)
::method moveCursor
  expose broker active
  use strict arg generation, row, column
  if \active then return .TerminalResult~failure("BROKER_CONTROL_CAPABILITY_INVALID")
  if generation \== 7 then return .TerminalResult~failure("STALE_SCREEN")
  return .TerminalResult~success(broker~setCursor(row, column))
::method focusField
  expose broker
  use strict arg generation, fieldId
  if fieldId == "SECRET" then return self~moveCursor(generation, 1, 1)
  return self~moveCursor(generation, 1, 6)
::method nextInputField
  use strict arg generation
  return self~moveCursor(generation, 1, 6)
::method previousInputField
  use strict arg generation
  return self~moveCursor(generation, 1, 1)
::method home
  use strict arg generation
  return self~moveCursor(generation, 1, 1)
::method errorReset
  expose broker
  use strict arg generation
  broker~noteMutation
  return .TerminalResult~success(broker~snapshot)
::method press
  expose broker
  use strict arg generation, aid
  broker~noteMutation
  return .TerminalResult~success(broker~snapshot)
::method systemRequest
  expose broker
  use strict arg generation
  broker~noteMutation
  return .TerminalResult~success(broker~snapshot)
::method invalidate
  expose active
  active = .false
  return .true

::requires "TerminalBrokerProtocol.cls"
::requires "TerminalControl.cls"
::requires "json.cls"
