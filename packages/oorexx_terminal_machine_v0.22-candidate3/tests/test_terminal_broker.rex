failures = 0

sealer = .BrokerEvidenceSealer~new
alchemyAuthority = .BrokerCapabilityAuthority~new

live = .BrokerFakeLive~new("BROKER-SESSION")
owner = .TerminalSessionOwner~new(live, 4, sealer, alchemyAuthority)
broker = .TerminalSessionBroker~new("SERVICE-A", owner, 3, sealer, alchemyAuthority)

call assertTrue broker~isA(.AlchemyObject), "broker inherits AlchemyObject"
call assertTrue broker~checkSurfaceContract~ok, "broker Alchemy surface contract"
call assertTrue \broker~hasMethod("OWNER"), "broker has no owner getter"
call assertTrue \broker~hasMethod("CLIENTS"), "broker has no client table getter"
call assertTrue broker~open~ok, "broker opens owner session"
call assertEq live~openCount, 1, "one physical live open"
call assertTrue broker~open~ok, "broker open idempotent"
call assertEq live~openCount, 1, "second broker open creates no connection"

/* Service pump uses the one retained owner and does not create new sessions. */
call assertTrue broker~pumpOnce(0)~ok, "broker service pump succeeds"
call assertEq live~pumpCount, 1, "single owner pump path used"

/* Each client becomes one owner-side observer but receives only a broker
 * capability. Attaching clients never opens another live connection. */
aResult = broker~attachClient("AI_A")
bResult = broker~attachClient("AI_B")
call assertTrue aResult~ok, "attach broker client A"
call assertTrue bResult~ok, "attach broker client B"
a = aResult~value
b = bResult~value
call assertEq broker~attachedClientCount, 2, "two broker clients attached"
call assertEq owner~attachedObserverCount, 2, "broker internally owns two observer capabilities"
call assertEq live~openCount, 1, "client attach reuses one connection"
call assertTrue \a~hasMethod("BROKER"), "client has no broker getter"
call assertTrue \a~hasMethod("OWNER"), "client has no owner getter"
call assertTrue \a~hasMethod("PRESS"), "client is read-only"
call assertTrue a~snapshot~ok, "client A reads detached snapshot"
call assertEq a~snapshot~value~generation, live~snapshot~generation, "client sees shared generation"

duplicate = broker~attachClient("AI_A")
call assertTrue \duplicate~ok, "duplicate broker principal blocked"
call assertEq duplicate~code, "BROKER_CLIENT_ALREADY_ATTACHED", "duplicate broker code"

forged = .ForgedBrokerClient~new(a~clientId)
forgedRead = broker~clientSnapshot(forged)
call assertTrue \forgedRead~ok, "forged client object rejected"
call assertEq forgedRead~code, "BROKER_CLIENT_INVALID", "exact broker client capability required"

/* FULL introspection remains evidence, not authority delegation. */
brokerFull = broker~sealedIntrospection("FULL", .nil)~payload["state"]
call assertMissing brokerFull, "OWNER", "broker FULL state cannot export TerminalSessionOwner"
call assertMissing brokerFull, "CLIENTS", "broker FULL state cannot export client table"
call assertMissing brokerFull, "PRINCIPALINDEX", "broker FULL state cannot export principal index"
call assertMissing brokerFull, "ACTIVECONTROLLERFACADE", "broker FULL state cannot export broker controller"
call assertMissing brokerFull, "ACTIVEOWNERCONTROLLER", "broker FULL state cannot export owner controller"
clientFull = a~sealedIntrospection("FULL", .nil)~payload["state"]
call assertMissing clientFull, "BROKER", "client FULL state cannot export broker object"
call assertEq clientFull["CLIENTID"], a~clientId, "safe client id remains inspectable"

status = broker~status
call assertEq status~brokerId, "SERVICE-A", "detached status broker id"
call assertEq status~clientCount, 2, "detached status client count"
call assertTrue \status~controlActive, "status initially has no control"

/* External admission remains below the broker. One writer is still enforced. */
auth = .BrokerAdmission~new
call assertTrue broker~enableControlGate(auth, "TERMINAL:SESSION:BROKER-SESSION")~ok, "broker enables owner control gate"
resA = .BrokerReservation~new("AI_A", "TERMINAL:SESSION:BROKER-SESSION")
resB = .BrokerReservation~new("AI_B", "TERMINAL:SESSION:BROKER-SESSION")
acqA = a~requestControl(resA, .array~of("AID", "SYSTEM_REQUEST"))
call assertTrue acqA~ok, "client A acquires broker keyboard"
ctlA = acqA~value
call assertTrue ctlA~isA(.AlchemyObject), "broker controller inherits AlchemyObject"
call assertTrue \ctlA~hasMethod("BROKER"), "controller has no broker getter"
call assertTrue \ctlA~hasMethod("OWNER"), "controller has no owner getter"
call assertEq broker~activeControllerPrincipal, "AI_A", "broker records A controller"
call assertEq owner~activeControllerIdentity, "AI_A", "owner records same controller"
call assertEq live~peakControllers, 1, "underlying one-writer invariant"

busyB = b~requestControl(resB, .array~of("AID"))
call assertTrue \busyB~ok, "B blocked while A controls"
call assertEq busyB~code, "CONTROL_BUSY", "broker one-writer busy code"

controllerFull = ctlA~sealedIntrospection("FULL", .nil)~payload["state"]
call assertMissing controllerFull, "BROKER", "controller FULL state cannot export broker"
call assertMissing controllerFull, "OWNERCONTROLLER", "controller FULL state cannot export owner controller"
call assertEq controllerFull["LEASEID"], ctlA~leaseId, "opaque lease id remains inspectable"

gen = ctlA~snapshot~value~generation
pressed = ctlA~press(gen, "ENTER")
call assertTrue pressed~ok, "broker controller AID succeeds"
call assertEq live~flushCount, 1, "wire flush remains inside owner below broker"
call assertTrue pressed~value~isA(.TerminalSnapshot), "AID result remains detached terminal evidence"

/* Handoff remains non-overlapping all the way through both capability layers. */
handoff = ctlA~handoffTo(b, resB, .array~of("AID"))
call assertTrue handoff~ok, "broker handoff A to B"
ctlB = handoff~value
call assertTrue \ctlA~active, "old broker controller invalidated"
call assertTrue ctlB~active, "new broker controller active"
call assertEq broker~activeControllerPrincipal, "AI_B", "broker B owns keyboard"
call assertEq owner~activeControllerIdentity, "AI_B", "owner B owns keyboard"
call assertEq live~peakControllers, 1, "handoff never overlaps raw controllers"
call assertEq live~releaseBeforeAcquireViolations, 0, "release happens before acquire"
oldUse = ctlA~press(gen, "ENTER")
call assertTrue \oldUse~ok, "old broker controller cannot mutate"
call assertEq oldUse~code, "BROKER_CONTROL_CAPABILITY_INVALID", "old broker controller exact capability rejected"

/* Detaching a controlling client revokes owner-side control before invalidating
 * the read facade. */
detachB = b~detach("CLIENT_DONE")
call assertTrue detachB~ok, "detach controlling broker client B"
call assertTrue \broker~controlActive, "broker control cleared on detach"
call assertTrue \owner~controlActive, "owner control cleared on detach"
call assertTrue \ctlB~active, "B broker controller invalidated"
call assertEq broker~attachedClientCount, 1, "one broker client remains"
call assertEq owner~attachedObserverCount, 1, "one owner observer remains"

/* Closing the service invalidates remaining capabilities and closes exactly one
 * live session. Generic broker close is still not host-specific signoff. */
closed = broker~close
call assertTrue closed~ok, "broker closes service owner"
call assertEq live~closeCount, 1, "one physical live close"
call assertEq broker~attachedClientCount, 0, "broker closes all clients"
call assertEq owner~attachedObserverCount, 0, "owner closes all observers"
call assertTrue \a~active, "remaining client invalidated"
afterClose = a~snapshot
call assertTrue \afterClose~ok, "closed broker client cannot read"
call assertEq afterClose~code, "BROKER_CLIENT_INACTIVE", "closed client read code"

if failures > 0 then do
  say "FAIL test_terminal_broker" failures
  exit 1
end
say "PASS test_terminal_broker"
exit 0

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


::class BrokerEvidenceEnvelope
::attribute payload get
::method init
  expose payload
  use strict arg payloadArg
  payload = payloadArg

::class BrokerEvidenceSealer
::method seal
  use strict arg subject, payload
  return .BrokerEvidenceEnvelope~new(payload)

::class BrokerCapabilityAuthority
::method verify
  use arg capability, objectId, operation, purpose, requireActive = .true
  return .true

::class ForgedBrokerClient
::attribute clientId get
::attribute active get
::method init
  expose clientId active
  use arg clientIdArg
  clientId = clientIdArg~string
  active = .true

::class BrokerReservation
::attribute identity get
::attribute scope get
::method init
  expose identity scope
  use arg identityArg, scopeArg
  identity = identityArg~string
  scope = scopeArg~string

::class BrokerAdmission
::method admit
  use arg reservation
  return .TerminalResult~success(reservation)

::class BrokerFakeLive
::attribute sessionId get
::attribute state get
::attribute ownershipClaimed get
::attribute openCount get
::attribute closeCount get
::attribute pumpCount get
::attribute flushCount get
::attribute peakControllers get
::attribute releaseBeforeAcquireViolations get

::method init
  expose sessionId state ownershipOwner ownershipClaimed openCount closeCount pumpCount flushCount generation controlActive activeControllerIdentity activeRaw scope leaseSequence observation peakControllers releaseBeforeAcquireViolations
  use arg sessionIdArg
  sessionId = sessionIdArg~string
  state = "CREATED"
  ownershipOwner = .nil
  ownershipClaimed = .false
  openCount = 0
  closeCount = 0
  pumpCount = 0
  flushCount = 0
  generation = 1
  controlActive = .false
  activeControllerIdentity = ""
  activeRaw = .nil
  scope = ""
  leaseSequence = 0
  observation = .BrokerObservationPort~new(self)
  peakControllers = 0
  releaseBeforeAcquireViolations = 0

::method claimExclusiveOwner
  expose ownershipOwner ownershipClaimed
  use arg ownerArg
  if ownerArg == .nil then return .TerminalResult~failure("SESSION_OWNERSHIP_OWNER_REQUIRED")
  if ownershipOwner == .nil then do
    ownershipOwner = ownerArg
    ownershipClaimed = .true
    return .TerminalResult~success(.true)
  end
  if ownershipOwner == ownerArg then return .TerminalResult~success(.true)
  return .TerminalResult~failure("SESSION_OWNERSHIP_BUSY")

::method releaseExclusiveOwner
  expose ownershipOwner ownershipClaimed state controlActive
  use arg ownerArg
  checked = self~checkOwner(ownerArg)
  if \checked~ok then return checked
  if controlActive then return .TerminalResult~failure("SESSION_OWNERSHIP_CONTROL_ACTIVE")
  if state \== "CLOSED" then return .TerminalResult~failure("SESSION_OWNERSHIP_SESSION_NOT_CLOSED")
  ownershipOwner = .nil
  ownershipClaimed = .false
  return .TerminalResult~success(.true)

::method checkOwner private
  expose ownershipOwner
  use arg ownerArg = .nil
  if ownershipOwner == .nil then return .TerminalResult~success(.true)
  if ownerArg == .nil then return .TerminalResult~failure("SESSION_OWNERSHIP_REQUIRED")
  if ownerArg \== ownershipOwner then return .TerminalResult~failure("SESSION_OWNERSHIP_INVALID")
  return .TerminalResult~success(.true)

::method open
  expose state openCount
  use arg ownerArg = .nil
  checked = self~checkOwner(ownerArg)
  if \checked~ok then return checked
  if state == "OPEN" then return .TerminalResult~success(.true)
  if state == "CLOSED" then return .TerminalResult~failure("CLOSED")
  openCount += 1
  state = "OPEN"
  return .TerminalResult~success(.true)

::method observerPort
  expose observation
  return observation

::method snapshot
  expose generation
  return .TerminalSnapshot~new(generation, "FAKE", 24, 80, 1, 1, "UNLOCKED", "OPERATOR_WAIT", .array~of("BROKER"))

::method attachKnownStateCatalog
  use arg catalogArg, capacityArg = 64, ownerArg = .nil
  checked = self~checkOwner(ownerArg)
  if \checked~ok then return checked
  return .TerminalResult~success(.true)

::method pumpOnce
  expose state pumpCount generation
  use arg timeoutArg = 1, maximumArg = 16384, ownerArg = .nil
  checked = self~checkOwner(ownerArg)
  if \checked~ok then return checked
  if state \== "OPEN" then return .TerminalResult~failure("NOT_OPEN")
  pumpCount += 1
  generation += 1
  return .TerminalResult~success(self~snapshot)

::method enableControlGate
  expose state scope
  use arg authorityArg, scopeArg = "", ownerArg = .nil
  checked = self~checkOwner(ownerArg)
  if \checked~ok then return checked
  if state \== "OPEN" then return .TerminalResult~failure("NOT_OPEN")
  scope = scopeArg~string
  return .TerminalResult~success(.true)

::method acquireControl
  expose state sessionId scope controlActive activeControllerIdentity activeRaw leaseSequence peakControllers releaseBeforeAcquireViolations
  use arg identityArg, reservationArg, capabilitiesArg = .nil, ownerArg = .nil
  checked = self~checkOwner(ownerArg)
  if \checked~ok then return checked
  if state \== "OPEN" then return .TerminalResult~failure("NOT_OPEN")
  if controlActive then do
    releaseBeforeAcquireViolations += 1
    return .TerminalResult~failure("CONTROL_BUSY", activeControllerIdentity)
  end
  if reservationArg == .nil then return .TerminalResult~failure("CONTROL_ADMISSION_REQUIRED")
  if reservationArg~identity \== identityArg~string then return .TerminalResult~failure("CONTROL_IDENTITY_MISMATCH")
  if reservationArg~scope \== scope then return .TerminalResult~failure("CONTROL_SCOPE_MISMATCH")
  leaseSequence += 1
  controlActive = .true
  activeControllerIdentity = identityArg~string
  activeRaw = .BrokerRawController~new(self, "LEASE-" || leaseSequence, activeControllerIdentity, sessionId, scope, self~snapshot~generation, capabilitiesArg)
  if peakControllers < 1 then peakControllers = 1
  return .TerminalResult~success(activeRaw)

::method rawRelease
  expose controlActive activeControllerIdentity activeRaw
  use arg rawArg, reasonArg = "RELEASED"
  if \controlActive then return .TerminalResult~failure("CONTROL_NOT_HELD")
  if rawArg \== activeRaw then return .TerminalResult~failure("CONTROL_LEASE_INVALID")
  controlActive = .false
  activeControllerIdentity = ""
  activeRaw = .nil
  return .TerminalResult~success(.true)

::method revokeControl
  expose controlActive activeControllerIdentity activeRaw
  use arg reasonArg = "REVOKED", ownerArg = .nil
  checked = self~checkOwner(ownerArg)
  if \checked~ok then return checked
  if \controlActive then return .TerminalResult~failure("CONTROL_NOT_HELD")
  if activeRaw \== .nil then activeRaw~ownerRevoke(reasonArg)
  controlActive = .false
  activeControllerIdentity = ""
  activeRaw = .nil
  return .TerminalResult~success(.true)

::method controlActive
  expose controlActive
  return controlActive

::method activeControllerIdentity
  expose activeControllerIdentity
  return activeControllerIdentity

::method flushTerminalOutput
  expose flushCount state
  use arg ownerArg = .nil
  checked = self~checkOwner(ownerArg)
  if \checked~ok then return checked
  if state \== "OPEN" then return .TerminalResult~failure("NOT_OPEN")
  flushCount += 1
  return .TerminalResult~success(9)

::method close
  expose state closeCount controlActive activeControllerIdentity activeRaw
  use arg ownerArg = .nil
  checked = self~checkOwner(ownerArg)
  if \checked~ok then return checked
  if controlActive then do
    if activeRaw \== .nil then activeRaw~ownerRevoke("SESSION_CLOSED")
    controlActive = .false
    activeControllerIdentity = ""
    activeRaw = .nil
  end
  if state \== "CLOSED" then closeCount += 1
  state = "CLOSED"
  return .TerminalResult~success(.true)

::class BrokerObservationPort
::method init
  expose live
  use arg liveArg
  live = liveArg
::method snapshot
  expose live
  return live~snapshot
::method current
  expose live
  return live~snapshot
::method back
  expose live
  use arg countArg = 1
  return live~snapshot
::method history
  expose live
  return .array~of(live~snapshot)
::method knownStateStatus
  return "UNTRACKED"
::method knownStateId
  return ""
::method knownStateGeneration
  return 0
::method knownStateHistory
  return .array~new

::class BrokerRawController
::attribute leaseId get
::attribute controllerIdentity get
::attribute sessionId get
::attribute scope get
::attribute acquiredGeneration get
::method init
  expose live leaseId controllerIdentity sessionId scope acquiredGeneration capabilities active
  use arg liveArg, leaseIdArg, identityArg, sessionIdArg, scopeArg, generationArg, capabilitiesArg = .nil
  live = liveArg
  leaseId = leaseIdArg
  controllerIdentity = identityArg
  sessionId = sessionIdArg
  scope = scopeArg
  acquiredGeneration = generationArg
  if capabilitiesArg == .nil then capabilities = .array~new
  else capabilities = capabilitiesArg
  active = .true
::method snapshot
  expose live
  return live~snapshot
::method capabilityNames
  expose capabilities
  return .TerminalUtil~copyArray(capabilities)
::method meterFacts
  return .TerminalResult~success(.array~new)
::method release
  expose live active
  use arg reasonArg = "RELEASED"
  if \active then return .TerminalResult~failure("CONTROL_LEASE_INVALID")
  released = live~rawRelease(self, reasonArg)
  if released~ok then active = .false
  return released
::method ownerRevoke
  expose active
  use arg reasonArg = "REVOKED"
  active = .false
  return .true
::method mutate private
  expose active live
  if \active then return .TerminalResult~failure("CONTROL_LEASE_INVALID")
  return .TerminalResult~success(live~snapshot)
::method setField
  use arg generationArg, fieldIdArg, valueArg
  return self~mutate
::method typeAtCursor
  use arg generationArg, textArg
  return self~mutate
::method moveCursor
  use arg generationArg, rowArg, columnArg
  return self~mutate
::method focusField
  use arg generationArg, fieldIdArg
  return self~mutate
::method nextInputField
  use arg generationArg
  return self~mutate
::method previousInputField
  use arg generationArg
  return self~mutate
::method home
  use arg generationArg
  return self~mutate
::method errorReset
  use arg generationArg
  return self~mutate
::method press
  use arg generationArg, aidArg
  return self~mutate
::method systemRequest
  use arg generationArg
  return self~mutate

::requires "TerminalBroker.cls"
