failures = 0

ring = .CryptoMacKeyRing~new
ring~addKey("terminal-owner-test", "00112233445566778899aabbccddeeff")
sealer = .AlchemyMacSealer~new(ring)
alchemyAuthority = .AlchemyCapabilityAuthority~new(ring)

live = .FakeOwnedLiveSession~new("OWNED")
owner = .TerminalSessionOwner~new(live, 2, sealer, alchemyAuthority)
call assertTrue owner~isA(.AlchemyObject), "owner inherits AlchemyObject"
call assertTrue owner~checkSurfaceContract~ok, "owner Alchemy surface contract"
call assertTrue live~ownershipClaimed, "owner constructor claims exact live session"

/* Once claimed, retained references to the raw live session cannot bypass the
 * owner for lifecycle/control/wire operations. */
directOpen = live~open
call assertTrue \directOpen~ok, "direct live open blocked after owner claim"
call assertEq directOpen~code, "SESSION_OWNERSHIP_REQUIRED", "direct open ownership code"
facadeOpen = live~open(owner)
call assertTrue \facadeOpen~ok, "owner facade is not sufficient to bypass private ownership token"
call assertEq facadeOpen~code, "SESSION_OWNERSHIP_INVALID", "owner facade cannot serve as ownership token"
call assertTrue \owner~hasMethod("OWNERSHIPTOKEN"), "ownership token has no public owner getter"
call assertEq live~openCount, 0, "blocked direct open does not touch transport"

opened = owner~open
call assertTrue opened~ok, "owner opens shared live session"
call assertEq live~openCount, 1, "one physical open"
call assertTrue owner~open~ok, "owner open idempotent"
call assertEq live~openCount, 1, "second owner open does not create a session"

directPump = live~pumpOnce
call assertTrue \directPump~ok, "direct pump blocked after claim"
call assertEq directPump~code, "SESSION_OWNERSHIP_REQUIRED", "direct pump ownership code"
call assertEq live~pumpCount, 0, "blocked direct pump does not consume input"
call assertTrue owner~pumpOnce~ok, "owner pump succeeds"
call assertEq live~pumpCount, 1, "owner is sole pump path"

/* Many readers share the same observation port and never reopen the session. */
aResult = owner~attachObserver("AI_A")
bResult = owner~attachObserver("AI_B")
call assertTrue aResult~ok, "attach observer A"
call assertTrue bResult~ok, "attach observer B"
a = aResult~value
b = bResult~value
call assertEq owner~attachedObserverCount, 2, "two attached observers"
call assertEq live~openCount, 1, "observer attachment creates no new connection"
call assertTrue a~isA(.AlchemyObject), "attached observer inherits AlchemyObject"
call assertTrue \a~hasMethod("PRESS"), "observer has no AID mutation method"
call assertTrue \a~hasMethod("SETFIELD"), "observer has no field mutation method"
call assertTrue \a~hasMethod("OWNER"), "observer has no owner getter"
call assertTrue a~snapshot~ok, "observer reads detached snapshot"
call assertEq a~snapshot~value~generation, live~snapshot~generation, "observer sees shared generation"

duplicate = owner~attachObserver("AI_A")
call assertTrue \duplicate~ok, "duplicate principal blocked"
call assertEq duplicate~code, "OBSERVER_ALREADY_ATTACHED", "duplicate observer code"
overCapacity = owner~attachObserver("AI_C")
call assertTrue \overCapacity~ok, "observer capacity enforced"
call assertEq overCapacity~code, "OBSERVER_CAPACITY_EXHAUSTED", "observer capacity code"

forged = .ForgedObserver~new(a~attachmentId)
forgedDetach = owner~detachObserver(forged)
call assertTrue \forgedDetach~ok, "forged attachment object rejected"
call assertEq forgedDetach~code, "ATTACHMENT_INVALID", "exact observer object capability"

/* Alchemy CUSTOMER evidence carries operational state without crossing the
 * raw-session/capability boundary. */
ownerCap = alchemyAuthority~issue("owner-audit", owner~alchemyObjectId, "SEALEDINTROSPECTION", "INTROSPECT:CUSTOMER")
ownerView = owner~sealedIntrospection("CUSTOMER", ownerCap)
call assertTrue sealer~verify(ownerView), "owner CUSTOMER evidence verifies"
ownerState = ownerView~payload["state"]
call assertEq ownerState["OBSERVERCOUNT"], 2, "customer view reports observer count"
call assertTrue \ownerState~hasIndex("LIVESESSION"), "customer view hides raw live session"
call assertTrue \ownerState~hasIndex("ATTACHMENTS"), "customer view hides attachment capability table"
call assertTrue \ownerState~hasIndex("ACTIVELEASEDCONTROLLER"), "customer view hides raw controller capability"
call assertTrue \ownerState~hasIndex("OWNERSHIPTOKEN"), "customer view hides private ownership token"

observerCap = alchemyAuthority~issue("observer-audit", a~alchemyObjectId, "SEALEDINTROSPECTION", "INTROSPECT:CUSTOMER")
observerView = a~sealedIntrospection("CUSTOMER", observerCap)
call assertTrue sealer~verify(observerView), "observer CUSTOMER evidence verifies"
observerState = observerView~payload["state"]
call assertTrue \observerState~hasIndex("OWNER"), "observer evidence hides trusted owner capability"

/* One writer: control is granted only to an issued observer. */
auth = .FakeAdmissionAuthority~new
call assertTrue owner~enableControlGate(auth, "TERMINAL:SESSION:OWNED")~ok, "owner enables admission gate"
directGate = live~enableControlGate(auth, "TERMINAL:SESSION:OWNED")
call assertTrue \directGate~ok, "retained live reference cannot alter gate"
call assertEq directGate~code, "SESSION_OWNERSHIP_REQUIRED", "direct gate ownership code"

resA = .FakeReservation~new("AI_A", "TERMINAL:SESSION:OWNED")
resB = .FakeReservation~new("AI_B", "TERMINAL:SESSION:OWNED")
acqA = a~requestControl(resA, .array~of("AID", "SYSTEM_REQUEST"))
call assertTrue acqA~ok, "observer A acquires keyboard"
ctlA = acqA~value
call assertTrue ctlA~isA(.AlchemyObject), "attached controller inherits AlchemyObject"
call assertTrue owner~controlActive, "owner reports active controller"
call assertEq owner~activeControllerIdentity, "AI_A", "A owns keyboard"
call assertEq owner~activeControllerAttachmentId, a~attachmentId, "control bound to issued attachment"
call assertEq live~peakControllers, 1, "never more than one raw controller"

busyB = b~requestControl(resB, .array~of("AID"))
call assertTrue \busyB~ok, "B blocked while A controls"
call assertEq busyB~code, "CONTROL_BUSY", "one writer busy code"

/* AID/System Request are owner-mediated: successful local control mutation is
 * followed by trusted wire flushing, but no raw wire bytes are returned. */
gen = ctlA~snapshot~value~generation
pressed = ctlA~press(gen, "ENTER")
call assertTrue pressed~ok, "controller AID succeeds"
call assertEq live~flushCount, 1, "AID flushes terminal output inside owner"
sys = ctlA~systemRequest(gen)
call assertTrue sys~ok, "controller System Request succeeds"
call assertEq live~flushCount, 2, "System Request flushes inside owner"

/* Handoff is release -> provable NO CONTROLLER -> acquire at current state. */
handoff = ctlA~handoffTo(b, resB, .array~of("AID"))
call assertTrue handoff~ok, "control handoff A to B"
ctlB = handoff~value
call assertTrue \ctlA~active, "old controller facade invalidated"
call assertTrue ctlB~active, "new controller facade active"
call assertEq owner~activeControllerIdentity, "AI_B", "B owns keyboard after handoff"
call assertEq live~peakControllers, 1, "handoff never overlaps controllers"
call assertEq live~releaseBeforeAcquireViolations, 0, "handoff observed no overlap"
oldUse = ctlA~press(gen, "ENTER")
call assertTrue \oldUse~ok, "old controller unusable after handoff"
call assertEq oldUse~code, "CONTROL_CAPABILITY_INVALID", "old controller exact capability code"

/* Detaching the controller attachment revokes keyboard authority first. */
detachB = b~detach("OBSERVER_DONE")
call assertTrue detachB~ok, "detach active B observer"
call assertTrue \owner~controlActive, "detach revokes B control"
call assertTrue \ctlB~active, "B controller invalidated on detach"
call assertEq owner~attachedObserverCount, 1, "one observer remains"

/* Owner close invalidates observers, closes exactly one underlying session and
 * releases the exclusive live-session claim. */
directClose = live~close
call assertTrue \directClose~ok, "direct close blocked while owner holds claim"
call assertEq live~closeCount, 0, "blocked direct close does not close transport"
closed = owner~close
call assertTrue closed~ok, "owner closes session"
call assertEq live~closeCount, 1, "one underlying close"
call assertTrue \live~ownershipClaimed, "exclusive claim released after close"
call assertEq owner~attachedObserverCount, 0, "close detaches all observers"
call assertTrue \a~active, "remaining observer invalidated on close"
afterCloseRead = a~snapshot
call assertTrue \afterCloseRead~ok, "detached observer cannot read after owner close"
call assertEq afterCloseRead~code, "ATTACHMENT_INACTIVE", "detached read code"

if failures > 0 then do
  say "FAIL test_terminal_ownership" failures
  exit 1
end
say "PASS test_terminal_ownership"
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

::class ForgedObserver
::attribute attachmentId get
::attribute active get
::method init
  expose attachmentId active
  use arg attachmentIdArg
  attachmentId = attachmentIdArg
  active = .true

::class FakeReservation
::attribute identity get
::attribute scope get
::method init
  expose identity scope
  use arg identityArg, scopeArg
  identity = identityArg~string
  scope = scopeArg~string

::class FakeAdmissionAuthority
::method admit
  use arg reservation
  return .TerminalResult~success(reservation)

::class FakeOwnedLiveSession
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
  expose sessionId state ownershipOwner ownershipClaimed openCount closeCount pumpCount flushCount generation controlActive activeControllerIdentity activeRaw scope leaseSequence observation peakControllers releaseBeforeAcquireViolations catalogCount
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
  observation = .FakeObservationPort~new(self)
  peakControllers = 0
  releaseBeforeAcquireViolations = 0
  catalogCount = 0

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
  return .TerminalSnapshot~new(generation, "FAKE", 24, 80, 1, 1, "UNLOCKED", "OPERATOR_WAIT", .array~of("OWNED"))

::method attachKnownStateCatalog
  expose catalogCount
  use arg catalogArg, capacityArg = 64, ownerArg = .nil
  checked = self~checkOwner(ownerArg)
  if \checked~ok then return checked
  catalogCount += 1
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
  expose state scope controlActive activeControllerIdentity activeRaw leaseSequence peakControllers releaseBeforeAcquireViolations
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
  activeRaw = .FakeRawController~new(self, "LEASE-" || leaseSequence, activeControllerIdentity, sessionId, scope, self~snapshot~generation, capabilitiesArg)
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
  return .TerminalResult~success(7)

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

::class FakeObservationPort
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

::class FakeRawController
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

::requires "TerminalOwnership.cls"
