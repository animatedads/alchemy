/* v0.13 regression: Alchemy introspection is evidence, not object delegation.
 *
 * Alchemy Objects v0.4.3 FULL state emits registered variables by reference.
 * Terminal Machine must therefore never register mutable implementation
 * objects, exact capability objects, live transports/runtimes, reservations,
 * key boundaries or internal mutable collections as state variables.
 */

sealer = .RefEvidenceSealer~new
authority = .RefCapabilityAuthority~new

caps = .TerminalCapabilities~new~add("CHARACTER_GRID")
snap = .TerminalSnapshot~new(1, "FAKE", 2, 8, 1, 1, "UNLOCKED", "OPERATOR_WAIT", .array~of("HELLO   ", "WORLD   "), .nil, caps)

trace = .TerminalTrace~new(sealer, authority)
trace~appendSnapshot(snap)
call assertMissing fullState(trace, authority), "EVENTS", "trace mutable event array is not introspection state"

replay = .TerminalReplay~new(trace, sealer, authority)
call assertMissing fullState(replay, authority), "SNAPSHOTS", "replay snapshot array is not emitted by reference"

watch = .TerminalWatchAlong~new(4, sealer, authority)
watch~observe(snap)
call assertMissing fullState(watch, authority), "HISTORY", "watch history is not emitted by reference"

catalog = .KnownStateCatalog~new(sealer, authority)
call assertMissing fullState(catalog, authority), "STATES", "known-state table is not emitted by reference"

tracker = .TerminalKnownStateTracker~new(catalog, 4, sealer, authority)
tracker~observe(snap)
trackerState = fullState(tracker, authority)
call assertMissing trackerState, "CATALOG", "tracker catalogue object is not emitted"
call assertMissing trackerState, "HISTORY", "tracker mutable history is not emitted"

session = .TerminalSession~new("REF-SESSION", .RefModel~new(snap), trace, sealer, authority)
session~addWatcher(watch)
sessionState = fullState(session, authority)
call assertMissing sessionState, "MODEL", "terminal model is not emitted"
call assertMissing sessionState, "TRACE", "trace capability is not emitted"
call assertMissing sessionState, "WATCHERS", "watcher capability collection is not emitted"

port = .RefMutationPort~new(snap)
admission = .RefAdmissionAuthority~new
gate = .TerminalControlGate~new("REF-CONTROL", "TERMINAL:REF", port, admission, sealer, authority)
reservation = .RefReservation~new("AI_A", "TERMINAL:REF")
acquired = gate~acquire("AI_A", reservation, .array~of("AID"))
call assertTrue acquired~ok, "control gate fixture acquires a real active lease"
gateState = fullState(gate, authority)
call assertMissing gateState, "ACTIVELEASE", "control lease capability is not emitted"
call assertMissing gateState, "ACTIVERESERVATION", "external admission reservation is not emitted"
call assertMissing gateState, "METERFACTS", "mutable meter-fact array is not emitted"

live = .TN5250LiveSession~new("REF-LIVE", "example.invalid", 992, "IBM-3179-2", "", "ADVANCE", .RefTransport~new, sealer, authority)
privateOwnerCapability = .directory~new
claimed = live~claimExclusiveOwner(privateOwnerCapability)
call assertTrue claimed~ok, "live fixture owns an exact capability before introspection"
liveState = fullState(live, authority)
call assertMissing liveState, "OWNERSHIPOWNER", "exact live-session owner capability is not emitted"
call assertMissing liveState, "RUNTIME", "secret-capable TN5250 runtime is not emitted"
call assertMissing liveState, "TRANSPORT", "live transport is not emitted"
call assertMissing liveState, "CONTROLGATE", "control gate is not emitted"
call assertMissing liveState, "KNOWNSTATETRACKER", "semantic tracker object is not emitted"
call assertMissing liveState, "ALCHEMYSEALER", "Alchemy sealer/key boundary is not emitted"
call assertMissing liveState, "ALCHEMYCAPABILITYAUTHORITY", "Alchemy capability authority is not emitted"
call assertTrue liveState["OWNERSHIPCLAIMED"], "safe scalar ownership status remains inspectable"

ownedLive = .TN5250LiveSession~new("REF-OWNER", "example.invalid", 992, "IBM-3179-2", "", "ADVANCE", .RefTransport~new, sealer, authority)
owner = .TerminalSessionOwner~new(ownedLive, 2, sealer, authority)
ownerState = fullState(owner, authority)
call assertMissing ownerState, "LIVESESSION", "owner cannot emit its live-session authority"
call assertMissing ownerState, "OBSERVATIONPORT", "owner cannot emit live observation object"
call assertMissing ownerState, "ATTACHMENTS", "owner cannot emit attachment capability table"
call assertMissing ownerState, "PRINCIPALINDEX", "owner cannot emit principal capability index"
call assertMissing ownerState, "ACTIVECONTROLLERFACADE", "owner cannot emit controller facade capability"
call assertMissing ownerState, "ACTIVELEASEDCONTROLLER", "owner cannot emit raw leased controller"
call assertMissing ownerState, "OWNERSHIPTOKEN", "owner never emits private ownership token"
call assertMissing ownerState, "ALCHEMYSEALER", "owner never emits sealer/key boundary"
call assertMissing ownerState, "ALCHEMYCAPABILITYAUTHORITY", "owner never emits capability authority"

observer = .TerminalAttachedObserver~new(owner, "OBS-1", "AI_A", "REF-OWNER", sealer, authority)
observerState = fullState(observer, authority)
call assertMissing observerState, "OWNER", "observer FULL introspection cannot delegate persistent owner"

rawController = .RefRawController~new("LEASE-1", "AI_A", "REF-OWNER", "TERMINAL:REF", 1)
controller = .TerminalAttachedController~new(owner, observer, rawController, sealer, authority)
controllerState = fullState(controller, authority)
call assertMissing controllerState, "OWNER", "controller FULL introspection cannot delegate persistent owner"
call assertMissing controllerState, "OBSERVER", "controller FULL introspection cannot export observer object"
call assertEq "LEASE-1", controllerState["LEASEID"], "safe opaque lease id remains inspectable"

say "PASS test_alchemy_reference_boundary"
exit 0

fullState: procedure
  use strict arg object, authority
  sealed = object~sealedIntrospection("FULL", .nil)
  return sealed~payload["state"]

assertMissing: procedure
  use strict arg state, key, message
  if state~hasIndex(key) then raise syntax 88.900 array("assertMissing failed: " || message || " key=" || key)
  return

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed: " || message)
  return

assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed: " || message || " expected=" || expected || " actual=" || actual)
  return

::class RefEvidenceEnvelope
::attribute payload get
::method init
  expose payload
  use strict arg payloadArg
  payload = payloadArg

::class RefEvidenceSealer
::method seal
  use strict arg subject, payload
  return .RefEvidenceEnvelope~new(payload)

::class RefCapabilityAuthority
::method verify
  use arg capability, objectId, operation, purpose, requireActive = .true
  return .true

::class RefModel
::method init
  expose snap
  use strict arg snapArg
  snap = snapArg
::method snapshot
  expose snap
  return snap~copyDetached

::class RefMutationPort
::method init
  expose snap
  use strict arg snapArg
  snap = snapArg
::method snapshot
  expose snap
  return snap~copyDetached
::method setField
  use strict arg fieldId, value
  return .TerminalResult~success(.true)
::method typeAtCursor
  use strict arg text
  return .TerminalResult~success(.true)
::method moveCursor
  use strict arg row, column
  return .TerminalResult~success(.true)
::method focusField
  use strict arg fieldId
  return .TerminalResult~success(.true)
::method nextInputField
  return .TerminalResult~success(.true)
::method previousInputField
  return .TerminalResult~success(.true)
::method home
  return .TerminalResult~success(.true)
::method errorReset
  return .TerminalResult~success(.true)
::method press
  use strict arg aid
  return .TerminalResult~success(.true)
::method systemRequest
  return .TerminalResult~success(.true)

::class RefAdmissionAuthority
::method admit
  use strict arg reservation
  return .TerminalResult~success(reservation)

::class RefReservation
::attribute identity get
::attribute scope get
::method init
  expose identity scope
  use strict arg identityArg, scopeArg
  identity = identityArg~string
  scope = scopeArg~string

::class RefTransport
::method open
  return .TerminalResult~success(.true)
::method close
  return .TerminalResult~success(.true)
::method receiveBytesWait
  use arg maximum = 8192, timeout = 1
  return .TerminalResult~failure("TRANSPORT_TIMEOUT", timeout)
::method sendBytes
  use arg bytes
  return .TerminalResult~success(bytes~length)

::class RefRawController
::attribute leaseId get
::attribute controllerIdentity get
::attribute sessionId get
::attribute scope get
::attribute acquiredGeneration get
::method init
  expose leaseId controllerIdentity sessionId scope acquiredGeneration
  use strict arg leaseArg, identityArg, sessionArg, scopeArg, generationArg
  leaseId = leaseArg~string
  controllerIdentity = identityArg~string
  sessionId = sessionArg~string
  scope = scopeArg~string
  acquiredGeneration = generationArg

::requires "TerminalOwnership.cls"
::requires "TN5250LiveSession.cls"
::requires "TerminalControl.cls"
