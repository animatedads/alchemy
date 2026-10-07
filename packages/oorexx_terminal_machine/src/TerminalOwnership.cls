/*
 * TerminalOwnership.cls - persistent interactive terminal ownership v0.13.
 *
 * This is deliberately terminal-family neutral.  A TerminalSessionOwner takes
 * exclusive lifecycle ownership of one already-constructed live-session
 * object.  Attaching an observer therefore never opens a second network
 * connection or creates another host device session.
 *
 * Authority invariants:
 *   - one live terminal connection belongs to one owner;
 *   - many attached observers may read the same detached terminal evidence;
 *   - attached observers have no mutation methods;
 *   - at most one attached controller exists;
 *   - the exact issued observer/controller object is checked, not its id text;
 *   - controller handoff releases the old lease, proves NO CONTROLLER, then
 *     acquires the new lease at the then-current terminal generation;
 *   - no keystroke/action queue exists in this layer;
 *   - raw live-session, admission reservation and leased-controller objects
 *     are never returned through attached facades;
 *   - terminal-family wire flushing, when required, stays inside the trusted
 *     owner through an optional flushTerminalOutput() live-session hook.
 *
 * The v0.12 boundary is process-resident.  It is the object ownership layer a
 * later IPC/service broker can host; it is not itself an IPC daemon.
 */

::class TerminalOwnershipBuild public
::constant RELEASE "0.13"
::constant API_VERSION "terminal.ownership/0.13"

/* Exact-object capability retained only by TerminalSessionOwner.  It is not
 * public and has no state/getters; possessing the owner facade is deliberately
 * not equivalent to possessing this live-session authority token. */
::class TerminalOwnershipToken

::class TerminalSessionOwner subclass TerminalAlchemyObject public
::attribute sessionId get
::attribute state get
::attribute maxObservers get

::method init
  expose sessionId state maxObservers liveSession observationPort attachments principalIndex observerSequence observerCount activeControllerFacade activeLeasedController activeControllerIdentity activeControllerLeaseId activeControllerAttachmentId ownershipToken alchemySealer alchemyCapabilityAuthority
  use arg liveSessionArg, maxObserversArg = 16, alchemySealerArg = .nil, alchemyCapabilityAuthorityArg = .nil

  if liveSessionArg == .nil then raise syntax 88.900 array("TerminalSessionOwner requires a live session")
  required = .array~of("SESSIONID", "STATE", "OPEN", "OBSERVERPORT", "SNAPSHOT", "PUMPONCE", "ENABLECONTROLGATE", "ACQUIRECONTROL", "REVOKECONTROL", "CONTROLACTIVE", "ACTIVECONTROLLERIDENTITY", "CLOSE", "CLAIMEXCLUSIVEOWNER", "RELEASEEXCLUSIVEOWNER")
  do methodName over required
    if \liveSessionArg~hasMethod(methodName) then raise syntax 88.900 array("TerminalSessionOwner live session missing method " || methodName)
  end
  if \datatype(maxObserversArg, "W") then raise syntax 88.900 array("TerminalSessionOwner maxObservers must be a positive whole number")
  if maxObserversArg < 1 then raise syntax 88.900 array("TerminalSessionOwner maxObservers must be a positive whole number")
  if liveSessionArg~controlActive then raise syntax 88.900 array("TerminalSessionOwner requires an unclaimed live session; active controller already exists")

  liveSession = liveSessionArg
  sessionId = liveSession~sessionId~string
  if sessionId == "" then raise syntax 88.900 array("TerminalSessionOwner live session must have a session id")
  state = liveSession~state~string
  maxObservers = maxObserversArg
  observationPort = .nil
  attachments = .table~new
  principalIndex = .table~new
  observerSequence = 0
  observerCount = 0
  activeControllerFacade = .nil
  activeLeasedController = .nil
  activeControllerIdentity = ""
  activeControllerLeaseId = ""
  activeControllerAttachmentId = ""
  ownershipToken = .TerminalOwnershipToken~new
  alchemySealer = alchemySealerArg
  alchemyCapabilityAuthority = alchemyCapabilityAuthorityArg

  meta = .directory~new
  meta["session_id"] = sessionId
  meta["ownership_api"] = .TerminalOwnershipBuild~API_VERSION
  self~initTerminalAlchemy("Persistent one-connection terminal session ownership", meta, alchemySealer, alchemyCapabilityAuthority)

  self~registerStateVariable("sessionId", "CUSTOMER", "owned terminal session identity")
  self~registerStateVariable("state", "CUSTOMER", "owner-mirrored live session state")
  self~registerStateVariable("maxObservers", "CUSTOMER", "maximum simultaneous attached observers")
  self~registerStateVariable("observerCount", "CUSTOMER", "currently attached read-only observers")
  self~registerStateVariable("activeControllerIdentity", "CUSTOMER", "current attached keyboard owner identity")
  self~registerStateVariable("activeControllerLeaseId", "CUSTOMER", "opaque current control lease id")
  self~registerStateVariable("activeControllerAttachmentId", "CUSTOMER", "observer attachment currently holding keyboard authority")
  /* Alchemy FULL introspection returns registered values by reference.  None of
   * liveSession, observationPort, attachment tables, controller capabilities,
   * sealers/authorities or ownershipToken are registered: emitting any of those
   * exact objects would turn introspection into authority delegation. */

  self~registerMethodContract("OPEN", "open the one owned live terminal connection exactly once", .array~new, "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "NONE")
  self~registerMethodContract("ATTACHOBSERVER", "attach a read-only principal to the existing live session", .array~of("PRINCIPAL"), "TERMINALRESULT", .false, "FALSE", "CUSTOMER", "NORMAL", "MUTATE", "USE")
  self~registerMethodContract("ATTACHKNOWNSTATECATALOG", "attach semantic interpretation to the owned live stream when supported", .array~of("CATALOG", "CAPACITY"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("ENABLECONTROLGATE", "attach external terminal admission authority", .array~of("AUTHORITY", "SCOPE"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("ACQUIRECONTROL", "grant one issued observer exclusive keyboard authority", .array~of("OBSERVER", "RESERVATION", "CAPABILITIES"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("HANDOFFCONTROL", "release old keyboard authority then grant a different/current observer", .array~of("CONTROLLER", "OBSERVER", "RESERVATION", "CAPABILITIES"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("PUMPONCE", "advance the one owned live connection by at most one input chunk", .array~of("TIMEOUT", "MAXIMUM_BYTES"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "NONE")
  self~registerMethodContract("CLOSE", "revoke control, detach observers and close the owned live connection", .array~new, "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "USE")

  if state == "OPEN" then do
    observationPort = liveSession~observerPort
    if observationPort == .nil then raise syntax 88.900 array("TerminalSessionOwner live observer port must not be nil")
    if \observationPort~hasMethod("SNAPSHOT") then raise syntax 88.900 array("TerminalSessionOwner live observer port must expose snapshot")
  end
  claimed = liveSession~claimExclusiveOwner(ownershipToken)
  if \claimed~ok then raise syntax 88.900 array("TerminalSessionOwner exclusive ownership failed: " || claimed~code || ":" || claimed~detail)
  self~alchemyTouch("OWNERSHIP_CLAIM")
  ignore = self~terminalAuthorityEvent("OWNERSHIP_CLAIM", sessionId, "unexported exact-object ownership capability")

::method open
  expose state liveSession observationPort ownershipToken
  if state == "OPEN" then return .TerminalResult~success(.true)
  if state == "CLOSED" then return .TerminalResult~failure("SESSION_OWNER_CLOSED", "closed terminal ownership cannot be reopened")
  if state \== "CREATED" then return .TerminalResult~failure("SESSION_OWNER_NOT_OPENABLE", state)

  opened = liveSession~open(ownershipToken)
  state = liveSession~state~string
  if \opened~ok then return opened
  if state \== "OPEN" then return .TerminalResult~failure("SESSION_OWNER_OPEN_STATE_INVALID", state)

  observationPort = liveSession~observerPort
  if observationPort == .nil then return .TerminalResult~failure("SESSION_OBSERVER_PORT_REQUIRED", "live session returned nil observer port")
  if \observationPort~hasMethod("SNAPSHOT") then return .TerminalResult~failure("SESSION_OBSERVER_PORT_INVALID", "observer port must expose snapshot")
  self~alchemyTouch("OPEN")
  ignore = self~terminalLifecycleEvent(state, "ONE_LIVE_SESSION_OPEN")
  return .TerminalResult~success(.true)

::method attachedObserverCount
  expose observerCount
  return observerCount

::method controlActive
  expose activeControllerFacade
  ignore = self~reconcileControl
  return activeControllerFacade \== .nil

::method activeControllerIdentity
  expose activeControllerIdentity
  ignore = self~reconcileControl
  return activeControllerIdentity

::method activeControlLeaseId
  expose activeControllerLeaseId
  ignore = self~reconcileControl
  return activeControllerLeaseId

::method activeControllerAttachmentId
  expose activeControllerAttachmentId
  ignore = self~reconcileControl
  return activeControllerAttachmentId

::method attachObserver
  expose sessionId state maxObservers attachments principalIndex observerSequence observerCount observationPort liveSession alchemySealer alchemyCapabilityAuthority
  use arg principalArg
  if state \== "OPEN" then return .TerminalResult~failure("SESSION_OWNER_NOT_OPEN", state)
  principal = principalArg~string~strip
  if principal == "" then return .TerminalResult~failure("OBSERVER_IDENTITY_REQUIRED", "observer principal must not be empty")
  if principalIndex~at(principal) \== .nil then return .TerminalResult~failure("OBSERVER_ALREADY_ATTACHED", principal)
  if observerCount >= maxObservers then return .TerminalResult~failure("OBSERVER_CAPACITY_EXHAUSTED", maxObservers)

  if observationPort == .nil then do
    observationPort = liveSession~observerPort
    if observationPort == .nil then return .TerminalResult~failure("SESSION_OBSERVER_PORT_REQUIRED", "live session returned nil observer port")
  end

  observerSequence += 1
  attachmentId = "OBS-" || sessionId || "-" || right(observerSequence, 8, "0")
  observer = .TerminalAttachedObserver~new(self, attachmentId, principal, sessionId, alchemySealer, alchemyCapabilityAuthority)
  attachments~put(observer, attachmentId)
  principalIndex~put(attachmentId, principal)
  observerCount += 1
  self~alchemyTouch("ATTACH_OBSERVER")
  ignore = self~terminalObservationEvent(liveSession~snapshot~generation, "ATTACH:" || principal)
  return .TerminalResult~success(observer)

::method detachObserver
  expose attachments principalIndex observerCount activeControllerAttachmentId liveSession ownershipToken
  use arg observerArg, reasonArg = "DETACHED"
  checked = self~requireObserver(observerArg)
  if \checked~ok then return checked
  observer = checked~value
  attachmentId = observer~attachmentId
  principal = observer~principal

  if activeControllerAttachmentId == attachmentId then do
    if liveSession~controlActive then ignore = liveSession~revokeControl("ATTACHMENT_DETACHED", ownershipToken)
    self~clearController("ATTACHMENT_DETACHED")
  end

  attachments~remove(attachmentId)
  existing = principalIndex~at(principal)
  if existing \== .nil then do
    if existing == attachmentId then principalIndex~remove(principal)
  end
  observerCount -= 1
  if observerCount < 0 then observerCount = 0
  observer~ownerInvalidate(reasonArg)
  self~alchemyTouch("DETACH_OBSERVER")
  return .TerminalResult~success(.true)

::method attachKnownStateCatalog
  expose state liveSession observationPort ownershipToken
  use arg catalogArg, capacityArg = 64
  if state == "CLOSED" then return .TerminalResult~failure("SESSION_OWNER_CLOSED", "closed terminal ownership cannot attach semantic state")
  if \liveSession~hasMethod("ATTACHKNOWNSTATECATALOG") then return .TerminalResult~failure("KNOWN_STATE_TRACKER_UNSUPPORTED", "owned live session has no semantic tracker hook")
  attached = liveSession~attachKnownStateCatalog(catalogArg, capacityArg, ownershipToken)
  if attached~ok then do
    observationPort = liveSession~observerPort
    if observationPort == .nil then return .TerminalResult~failure("SESSION_OBSERVER_PORT_REQUIRED", "semantic tracker attach returned nil observer port")
    if \observationPort~hasMethod("SNAPSHOT") then return .TerminalResult~failure("SESSION_OBSERVER_PORT_INVALID", "semantic tracker observer port must expose snapshot")
    self~alchemyTouch("ATTACH_KNOWN_STATE")
  end
  return attached

::method enableControlGate
  expose state liveSession sessionId ownershipToken
  use arg authorityArg, scopeArg = ""
  if state \== "OPEN" then return .TerminalResult~failure("SESSION_OWNER_NOT_OPEN", state)
  enabled = liveSession~enableControlGate(authorityArg, scopeArg, ownershipToken)
  if enabled~ok then do
    self~alchemyTouch("ENABLE_CONTROL_GATE")
    ignore = self~terminalAuthorityEvent("ENABLE_GATE", sessionId, scopeArg~string)
  end
  return enabled

::method acquireControl
  expose state liveSession activeControllerFacade activeLeasedController activeControllerIdentity activeControllerLeaseId activeControllerAttachmentId ownershipToken alchemySealer alchemyCapabilityAuthority
  use arg observerArg, reservationArg, capabilitiesArg = .nil
  if state \== "OPEN" then return .TerminalResult~failure("SESSION_OWNER_NOT_OPEN", state)
  checked = self~requireObserver(observerArg)
  if \checked~ok then return checked

  reconciled = self~reconcileControl
  if \reconciled~ok then do
    if reconciled~code == "CONTROL_LEASE_INVALIDATED" then nop
    else return reconciled
  end
  if activeControllerFacade \== .nil then return .TerminalResult~failure("CONTROL_BUSY", activeControllerIdentity || " holds " || activeControllerLeaseId)
  if liveSession~controlActive then return .TerminalResult~failure("CONTROL_OWNERSHIP_DESYNC", "live session has control not issued by this owner")

  observer = checked~value
  acquired = liveSession~acquireControl(observer~principal, reservationArg, capabilitiesArg, ownershipToken)
  if \acquired~ok then return acquired
  rawController = acquired~value
  if rawController == .nil then do
    if liveSession~controlActive then ignore = liveSession~revokeControl("OWNER_INVALID_CONTROL_RESULT", ownershipToken)
    return .TerminalResult~failure("CONTROL_CAPABILITY_INVALID", "live session returned nil controller capability")
  end
  needed = .array~of("LEASEID", "CONTROLLERIDENTITY", "SESSIONID", "SCOPE", "ACQUIREDGENERATION", "SNAPSHOT", "CAPABILITYNAMES", "METERFACTS", "RELEASE", "SETFIELD", "TYPEATCURSOR", "MOVECURSOR", "FOCUSFIELD", "NEXTINPUTFIELD", "PREVIOUSINPUTFIELD", "HOME", "ERRORRESET", "PRESS", "SYSTEMREQUEST")
  do methodName over needed
    if \rawController~hasMethod(methodName) then do
      if liveSession~controlActive then ignore = liveSession~revokeControl("OWNER_INVALID_CONTROL_CAPABILITY", ownershipToken)
      return .TerminalResult~failure("CONTROL_CAPABILITY_INVALID", "controller missing " || methodName)
    end
  end

  activeLeasedController = rawController
  activeControllerIdentity = rawController~controllerIdentity~string
  activeControllerLeaseId = rawController~leaseId~string
  activeControllerAttachmentId = observer~attachmentId
  activeControllerFacade = .TerminalAttachedController~new(self, observer, rawController, alchemySealer, alchemyCapabilityAuthority)
  self~alchemyTouch("ACQUIRE_CONTROL")
  ignore = self~terminalAuthorityEvent("ACQUIRE", activeControllerIdentity, activeControllerLeaseId)
  return .TerminalResult~success(activeControllerFacade)

::method handoffControl
  expose liveSession ownershipToken
  use arg controllerArg, targetObserverArg, reservationArg, capabilitiesArg = .nil
  current = self~requireController(controllerArg)
  if \current~ok then return current
  target = self~requireObserver(targetObserverArg)
  if \target~ok then return target

  released = self~controllerRelease(controllerArg, "HANDOFF")
  if \released~ok then return released
  if liveSession~controlActive then do
    ignore = liveSession~revokeControl("HANDOFF_OVERLAP_GUARD", ownershipToken)
    self~clearController("HANDOFF_OVERLAP_GUARD")
    return .TerminalResult~failure("CONTROL_HANDOFF_NOT_CLEAR", "old controller remained active")
  end
  return self~acquireControl(targetObserverArg, reservationArg, capabilitiesArg)

::method revokeControl
  expose liveSession ownershipToken
  use arg reasonArg = "TRUSTED_OWNER_REVOKE"
  if \liveSession~controlActive then do
    self~clearController(reasonArg)
    return .TerminalResult~failure("CONTROL_NOT_HELD", "no active controller")
  end
  revoked = liveSession~revokeControl(reasonArg, ownershipToken)
  self~clearController(reasonArg)
  if revoked~ok then do
    self~alchemyTouch("REVOKE_CONTROL")
    ignore = self~terminalAuthorityEvent("REVOKE", "", reasonArg~string)
  end
  return revoked

::method pumpOnce
  expose state liveSession ownershipToken
  use arg timeoutSeconds = 1, maximumBytes = 16384
  if state \== "OPEN" then return .TerminalResult~failure("SESSION_OWNER_NOT_OPEN", state)
  previousState = state
  pumped = liveSession~pumpOnce(timeoutSeconds, maximumBytes, ownershipToken)
  state = liveSession~state~string
  ignore = self~reconcileControl
  if state \== previousState then do
    self~alchemyTouch("LIVE_STATE")
    ignore = self~terminalLifecycleEvent(state, "OWNED_SESSION_PUMP")
  end
  if pumped~ok then do
    snap = liveSession~snapshot
    ignore = self~terminalObservationEvent(snap~generation, "OWNED_SESSION_PUMP")
  end
  return pumped

::method close
  expose state liveSession sessionId ownershipToken
  if state == "CLOSED" then do
    releasedOwnership = liveSession~releaseExclusiveOwner(ownershipToken)
    if \releasedOwnership~ok then return releasedOwnership
    return .TerminalResult~success(.true)
  end

  if liveSession~controlActive then ignore = liveSession~revokeControl("SESSION_OWNER_CLOSED", ownershipToken)
  self~clearController("SESSION_OWNER_CLOSED")
  self~invalidateAllObservers("SESSION_OWNER_CLOSED")

  closed = liveSession~close(ownershipToken)
  state = liveSession~state~string
  if \closed~ok then do
    ignore = self~terminalLifecycleEvent(state, closed~code || ":" || closed~detail)
    return closed
  end
  releasedOwnership = liveSession~releaseExclusiveOwner(ownershipToken)
  if \releasedOwnership~ok then return releasedOwnership
  self~alchemyTouch("CLOSE")
  ignore = self~terminalLifecycleEvent(state, "ONE_LIVE_SESSION_CLOSED")
  ignore = self~terminalAuthorityEvent("OWNERSHIP_RELEASE", sessionId, "closed live-session claim released")
  ignore = self~alchemyRetire
  return .TerminalResult~success(.true)

/* Observer bridge.  These methods are intentionally public because attached
 * objects are separate objects; every call authenticates exact object identity
 * against the owner's issued-capability table before touching shared state. */
::method observerSnapshot
  expose observationPort
  use arg observerArg
  checked = self~requireObserver(observerArg)
  if \checked~ok then return checked
  return .TerminalResult~success(observationPort~snapshot)

::method observerCurrent
  expose observationPort
  use arg observerArg
  checked = self~requireObserver(observerArg)
  if \checked~ok then return checked
  if \observationPort~hasMethod("CURRENT") then return .TerminalResult~failure("OBSERVATION_METHOD_UNAVAILABLE", "CURRENT")
  return .TerminalResult~success(observationPort~current)

::method observerBack
  expose observationPort
  use arg observerArg, countArg = 1
  checked = self~requireObserver(observerArg)
  if \checked~ok then return checked
  if \observationPort~hasMethod("BACK") then return .TerminalResult~failure("OBSERVATION_METHOD_UNAVAILABLE", "BACK")
  return .TerminalResult~success(observationPort~back(countArg))

::method observerHistory
  expose observationPort
  use arg observerArg
  checked = self~requireObserver(observerArg)
  if \checked~ok then return checked
  if \observationPort~hasMethod("HISTORY") then return .TerminalResult~failure("OBSERVATION_METHOD_UNAVAILABLE", "HISTORY")
  return .TerminalResult~success(observationPort~history)

::method observerKnownStateStatus
  expose observationPort
  use arg observerArg
  checked = self~requireObserver(observerArg)
  if \checked~ok then return checked
  if \observationPort~hasMethod("KNOWNSTATESTATUS") then return .TerminalResult~success("UNTRACKED")
  return .TerminalResult~success(observationPort~knownStateStatus)

::method observerKnownStateId
  expose observationPort
  use arg observerArg
  checked = self~requireObserver(observerArg)
  if \checked~ok then return checked
  if \observationPort~hasMethod("KNOWNSTATEID") then return .TerminalResult~success("")
  return .TerminalResult~success(observationPort~knownStateId)

::method observerKnownStateGeneration
  expose observationPort
  use arg observerArg
  checked = self~requireObserver(observerArg)
  if \checked~ok then return checked
  if \observationPort~hasMethod("KNOWNSTATEGENERATION") then return .TerminalResult~success(0)
  return .TerminalResult~success(observationPort~knownStateGeneration)

::method observerKnownStateHistory
  expose observationPort
  use arg observerArg
  checked = self~requireObserver(observerArg)
  if \checked~ok then return checked
  if \observationPort~hasMethod("KNOWNSTATEHISTORY") then return .TerminalResult~success(.array~new)
  return .TerminalResult~success(observationPort~knownStateHistory)

/* Controller bridge.  The raw TerminalLeasedController never leaves the owner. */
::method controllerSnapshot
  expose activeLeasedController
  use arg controllerArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return .TerminalResult~success(activeLeasedController~snapshot)

::method controllerCapabilityNames
  expose activeLeasedController
  use arg controllerArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return .TerminalResult~success(activeLeasedController~capabilityNames)

::method controllerMeterFacts
  expose activeLeasedController
  use arg controllerArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return activeLeasedController~meterFacts

::method controllerRelease
  expose activeLeasedController activeControllerIdentity activeControllerLeaseId
  use arg controllerArg, reasonArg = "RELEASED"
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  identity = activeControllerIdentity
  leaseId = activeControllerLeaseId
  released = activeLeasedController~release(reasonArg)
  if \released~ok then return released
  self~clearController(reasonArg)
  self~alchemyTouch("RELEASE_CONTROL")
  ignore = self~terminalAuthorityEvent("RELEASE", identity, leaseId || ":" || reasonArg~string)
  return released

::method controllerSetField
  expose activeLeasedController
  use arg controllerArg, generationArg, fieldIdArg, valueArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return activeLeasedController~setField(generationArg, fieldIdArg, valueArg)

::method controllerTypeAtCursor
  expose activeLeasedController
  use arg controllerArg, generationArg, textArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return activeLeasedController~typeAtCursor(generationArg, textArg)

::method controllerMoveCursor
  expose activeLeasedController
  use arg controllerArg, generationArg, rowArg, columnArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return activeLeasedController~moveCursor(generationArg, rowArg, columnArg)

::method controllerFocusField
  expose activeLeasedController
  use arg controllerArg, generationArg, fieldIdArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return activeLeasedController~focusField(generationArg, fieldIdArg)

::method controllerNextInputField
  expose activeLeasedController
  use arg controllerArg, generationArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return activeLeasedController~nextInputField(generationArg)

::method controllerPreviousInputField
  expose activeLeasedController
  use arg controllerArg, generationArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return activeLeasedController~previousInputField(generationArg)

::method controllerHome
  expose activeLeasedController
  use arg controllerArg, generationArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return activeLeasedController~home(generationArg)

::method controllerErrorReset
  expose activeLeasedController
  use arg controllerArg, generationArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return activeLeasedController~errorReset(generationArg)

::method controllerPress
  expose activeLeasedController
  use arg controllerArg, generationArg, aidNameArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  pressed = activeLeasedController~press(generationArg, aidNameArg)
  if \pressed~ok then return pressed
  flushed = self~flushWireOutput
  if \flushed~ok then return flushed
  return pressed

::method controllerSystemRequest
  expose activeLeasedController
  use arg controllerArg, generationArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  requested = activeLeasedController~systemRequest(generationArg)
  if \requested~ok then return requested
  flushed = self~flushWireOutput
  if \flushed~ok then return flushed
  return requested

::method requireObserver private
  expose attachments
  use arg observerArg
  if observerArg == .nil then return .TerminalResult~failure("ATTACHMENT_REQUIRED", "issued observer attachment required")
  if \observerArg~hasMethod("ATTACHMENTID") then return .TerminalResult~failure("ATTACHMENT_INVALID", "observer attachment id missing")
  attachmentId = observerArg~attachmentId~string
  stored = attachments~at(attachmentId)
  if stored == .nil then return .TerminalResult~failure("ATTACHMENT_INACTIVE", attachmentId)
  if stored \== observerArg then return .TerminalResult~failure("ATTACHMENT_INVALID", "attachment object is not the issued capability")
  if \observerArg~active then return .TerminalResult~failure("ATTACHMENT_INACTIVE", attachmentId)
  return .TerminalResult~success(observerArg)

::method requireController private
  expose activeControllerFacade
  use arg controllerArg
  if controllerArg == .nil then return .TerminalResult~failure("CONTROL_CAPABILITY_REQUIRED", "issued attached controller required")
  reconciled = self~reconcileControl
  if \reconciled~ok then return reconciled
  if activeControllerFacade == .nil then return .TerminalResult~failure("CONTROL_NOT_HELD", "no owner-issued controller")
  if controllerArg \== activeControllerFacade then return .TerminalResult~failure("CONTROL_CAPABILITY_INVALID", "controller object is not the active issued capability")
  if \controllerArg~active then return .TerminalResult~failure("CONTROL_CAPABILITY_INVALID", "controller capability is inactive")
  return .TerminalResult~success(controllerArg)

::method reconcileControl private
  expose liveSession activeControllerFacade activeControllerIdentity ownershipToken
  if activeControllerFacade == .nil then do
    if liveSession~controlActive then return .TerminalResult~failure("CONTROL_OWNERSHIP_DESYNC", "live terminal has an unowned active controller")
    return .TerminalResult~success(.true)
  end
  if \liveSession~controlActive then do
    self~clearController("UNDERLYING_CONTROL_ENDED")
    return .TerminalResult~failure("CONTROL_LEASE_INVALIDATED", "underlying live control lease is no longer active")
  end
  liveIdentity = liveSession~activeControllerIdentity~string
  if liveIdentity \== activeControllerIdentity then do
    ignore = liveSession~revokeControl("OWNER_CONTROL_DESYNC", ownershipToken)
    self~clearController("OWNER_CONTROL_DESYNC")
    return .TerminalResult~failure("CONTROL_OWNERSHIP_DESYNC", "underlying controller identity changed outside owner")
  end
  return .TerminalResult~success(.true)

::method clearController private
  expose activeControllerFacade activeLeasedController activeControllerIdentity activeControllerLeaseId activeControllerAttachmentId
  use arg reasonArg = "CONTROL_CLEARED"
  if activeControllerFacade \== .nil then activeControllerFacade~ownerInvalidate(reasonArg)
  activeControllerFacade = .nil
  activeLeasedController = .nil
  activeControllerIdentity = ""
  activeControllerLeaseId = ""
  activeControllerAttachmentId = ""
  return .true

::method invalidateAllObservers private
  expose attachments principalIndex observerCount
  use arg reasonArg = "SESSION_OWNER_CLOSED"
  ids = .array~new
  do key over attachments
    ids~append(key)
  end
  do attachmentId over ids
    observer = attachments~at(attachmentId)
    if observer \== .nil then observer~ownerInvalidate(reasonArg)
    attachments~remove(attachmentId)
  end
  principalIndex = .table~new
  observerCount = 0
  return .true

::method flushWireOutput private
  expose liveSession ownershipToken
  if \liveSession~hasMethod("FLUSHTERMINALOUTPUT") then return .TerminalResult~success(0)
  return liveSession~flushTerminalOutput(ownershipToken)


::class TerminalAttachedObserver subclass TerminalAlchemyObject public
::attribute attachmentId get
::attribute principal get
::attribute sessionId get
::attribute active get
::attribute attachedAt get
::attribute detachedAt get
::attribute detachReason get

::method init
  expose owner attachmentId principal sessionId active attachedAt detachedAt detachReason
  use arg ownerArg, attachmentIdArg, principalArg, sessionIdArg, alchemySealerArg = .nil, alchemyCapabilityAuthorityArg = .nil
  owner = ownerArg
  attachmentId = attachmentIdArg~string
  principal = principalArg~string
  sessionId = sessionIdArg~string
  active = .true
  attachedAt = .DateTime~new~utcIsoDate
  detachedAt = ""
  detachReason = ""
  meta = .directory~new
  meta["session_id"] = sessionId
  meta["attachment_id"] = attachmentId
  meta["principal"] = principal
  self~initTerminalAlchemy("Read-only attachment to one persistent terminal session", meta, alchemySealerArg, alchemyCapabilityAuthorityArg)
  self~registerStateVariable("attachmentId", "CUSTOMER", "opaque observer attachment id")
  self~registerStateVariable("principal", "CUSTOMER", "observer principal identity")
  self~registerStateVariable("sessionId", "CUSTOMER", "shared terminal session identity")
  self~registerStateVariable("active", "CUSTOMER", "whether this observer attachment is active")
  self~registerStateVariable("attachedAt", "CUSTOMER", "attachment timestamp")
  self~registerStateVariable("detachedAt", "CUSTOMER", "detach timestamp")
  self~registerStateVariable("detachReason", "CUSTOMER", "bounded detach reason")
  self~registerMethodContract("SNAPSHOT", "read current detached terminal evidence", .array~new, "TERMINALRESULT", .false, "FALSE", "CUSTOMER", "NORMAL", "READ", "USE")
  self~registerMethodContract("REQUESTCONTROL", "request exclusive keyboard authority through trusted owner", .array~of("RESERVATION", "CAPABILITIES"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("DETACH", "detach this read-only observer", .array~of("REASON"), "TERMINALRESULT", .false, "FALSE", "CUSTOMER", "NORMAL", "MUTATE", "USE")

::method snapshot
  expose owner
  return owner~observerSnapshot(self)

::method current
  expose owner
  return owner~observerCurrent(self)

::method back
  expose owner
  use arg countArg = 1
  return owner~observerBack(self, countArg)

::method history
  expose owner
  return owner~observerHistory(self)

::method knownStateStatus
  expose owner
  return owner~observerKnownStateStatus(self)

::method knownStateId
  expose owner
  return owner~observerKnownStateId(self)

::method knownStateGeneration
  expose owner
  return owner~observerKnownStateGeneration(self)

::method knownStateHistory
  expose owner
  return owner~observerKnownStateHistory(self)

::method requestControl
  expose owner
  use arg reservationArg, capabilitiesArg = .nil
  return owner~acquireControl(self, reservationArg, capabilitiesArg)

::method detach
  expose owner
  use arg reasonArg = "DETACHED"
  return owner~detachObserver(self, reasonArg)

::method ownerInvalidate
  expose active detachedAt detachReason
  use arg reasonArg = "INVALIDATED"
  if \active then return .false
  active = .false
  detachedAt = .DateTime~new~utcIsoDate
  detachReason = reasonArg~string
  self~alchemyTouch("DETACH")
  ignore = self~terminalLifecycleEvent("DETACHED", detachReason)
  ignore = self~alchemyRetire
  return .true


::class TerminalAttachedController subclass TerminalAlchemyObject public
::attribute attachmentId get
::attribute principal get
::attribute sessionId get
::attribute leaseId get
::attribute scope get
::attribute acquiredGeneration get
::attribute active get
::attribute acquiredAt get
::attribute releasedAt get
::attribute releaseReason get

::method init
  expose owner observer attachmentId principal sessionId leaseId scope acquiredGeneration active acquiredAt releasedAt releaseReason
  use arg ownerArg, observerArg, rawControllerArg, alchemySealerArg = .nil, alchemyCapabilityAuthorityArg = .nil
  owner = ownerArg
  observer = observerArg
  attachmentId = observer~attachmentId
  principal = rawControllerArg~controllerIdentity~string
  sessionId = rawControllerArg~sessionId~string
  leaseId = rawControllerArg~leaseId~string
  scope = rawControllerArg~scope~string
  acquiredGeneration = rawControllerArg~acquiredGeneration
  active = .true
  acquiredAt = .DateTime~new~utcIsoDate
  releasedAt = ""
  releaseReason = ""
  meta = .directory~new
  meta["session_id"] = sessionId
  meta["attachment_id"] = attachmentId
  meta["principal"] = principal
  meta["lease_id"] = leaseId
  self~initTerminalAlchemy("Exclusive attached terminal keyboard capability", meta, alchemySealerArg, alchemyCapabilityAuthorityArg)
  self~registerStateVariable("attachmentId", "CUSTOMER", "observer attachment holding control")
  self~registerStateVariable("principal", "CUSTOMER", "controller identity")
  self~registerStateVariable("sessionId", "CUSTOMER", "shared terminal session identity")
  self~registerStateVariable("leaseId", "CUSTOMER", "opaque underlying control lease identity")
  self~registerStateVariable("scope", "CUSTOMER", "external admission scope")
  self~registerStateVariable("acquiredGeneration", "CUSTOMER", "terminal generation at control acquisition")
  self~registerStateVariable("active", "CUSTOMER", "whether this controller capability remains active")
  self~registerStateVariable("acquiredAt", "CUSTOMER", "control acquisition timestamp")
  self~registerStateVariable("releasedAt", "CUSTOMER", "control release/revocation timestamp")
  self~registerStateVariable("releaseReason", "CUSTOMER", "bounded release/revocation reason")
  self~registerMethodContract("SETFIELD", "write one structured field under current generation authority", .array~of("GENERATION", "FIELD_ID", "VALUE"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "USE")
  self~registerMethodContract("PRESS", "send one AID under current generation authority without exposing wire bytes", .array~of("GENERATION", "AID"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "USE")
  self~registerMethodContract("RELEASE", "release this exclusive keyboard capability", .array~of("REASON"), "TERMINALRESULT", .false, "FALSE", "CUSTOMER", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("HANDOFFTO", "release this controller then request control for another issued observer", .array~of("OBSERVER", "RESERVATION", "CAPABILITIES"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")

::method snapshot
  expose owner
  return owner~controllerSnapshot(self)

::method capabilityNames
  expose owner
  return owner~controllerCapabilityNames(self)

::method meterFacts
  expose owner
  return owner~controllerMeterFacts(self)

::method release
  expose owner
  use arg reasonArg = "RELEASED"
  return owner~controllerRelease(self, reasonArg)

::method handoffTo
  expose owner
  use arg targetObserverArg, reservationArg, capabilitiesArg = .nil
  return owner~handoffControl(self, targetObserverArg, reservationArg, capabilitiesArg)

::method setField
  expose owner
  use arg generationArg, fieldIdArg, valueArg
  return owner~controllerSetField(self, generationArg, fieldIdArg, valueArg)

::method typeAtCursor
  expose owner
  use arg generationArg, textArg
  return owner~controllerTypeAtCursor(self, generationArg, textArg)

::method moveCursor
  expose owner
  use arg generationArg, rowArg, columnArg
  return owner~controllerMoveCursor(self, generationArg, rowArg, columnArg)

::method focusField
  expose owner
  use arg generationArg, fieldIdArg
  return owner~controllerFocusField(self, generationArg, fieldIdArg)

::method nextInputField
  expose owner
  use arg generationArg
  return owner~controllerNextInputField(self, generationArg)

::method previousInputField
  expose owner
  use arg generationArg
  return owner~controllerPreviousInputField(self, generationArg)

::method home
  expose owner
  use arg generationArg
  return owner~controllerHome(self, generationArg)

::method errorReset
  expose owner
  use arg generationArg
  return owner~controllerErrorReset(self, generationArg)

::method press
  expose owner
  use arg generationArg, aidNameArg
  return owner~controllerPress(self, generationArg, aidNameArg)

::method systemRequest
  expose owner
  use arg generationArg
  return owner~controllerSystemRequest(self, generationArg)

::method ownerInvalidate
  expose active releasedAt releaseReason
  use arg reasonArg = "INVALIDATED"
  if \active then return .false
  active = .false
  releasedAt = .DateTime~new~utcIsoDate
  releaseReason = reasonArg~string
  self~alchemyTouch("CONTROL_END")
  ignore = self~terminalAuthorityEvent("CONTROL_END", "", releaseReason)
  ignore = self~alchemyRetire
  return .true

::requires "TerminalCore.cls"
