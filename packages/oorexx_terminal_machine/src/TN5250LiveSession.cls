/*
 * Trusted long-lived TN5250 connection owner v0.12.
 *
 * The terminal runtime and the network transport belong to one object for the
 * lifetime of a live session.  This is intentionally different from the old
 * one-shot probe pattern: once authenticated, callers should keep this object
 * (and therefore the same TCP/TLS/TN5250 connection and IBM i device session)
 * alive while automation and WatchAlong operate through the safe facade.
 *
 * STRICT DEVNAME collision policy means "this exact device or nothing".  A
 * collision closes the new socket immediately and never substitutes another
 * device name.
 *
 * v0.12 adds an exact-object exclusive-ownership capability.  TerminalSessionOwner
 * retains the actual private token; possession of the public owner facade is
 * deliberately insufficient.  Once claimed, lifecycle, control and wire-mutating
 * methods reject callers that do not present the exact capability.  Unclaimed
 * sessions retain the prior trusted direct API so fixtures and one-shot tools
 * remain compatible.
 */

::class TN5250LiveState public
::constant CREATED "CREATED"
::constant OPEN "OPEN"
::constant REMOTE_CLOSED "REMOTE_CLOSED"
::constant DEVICE_COLLISION "DEVICE_COLLISION"
::constant ERROR "ERROR"
::constant CLOSED "CLOSED"

::class TN5250LivePumpResult public
::attribute activity get
::attribute state get
::attribute snapshot get

::method init
  expose activity state snapshot
  use arg activityArg = .false, stateArg = "", snapshotArg = .nil
  activity = activityArg == .true
  state = stateArg~string
  if snapshotArg == .nil then snapshot = .nil
  else snapshot = snapshotArg~copyDetached

::class TN5250LiveSession subclass TerminalAlchemyObject public
::attribute sessionId get
::attribute host get
::attribute port get
::attribute terminalType get
::attribute requestedDeviceName get
::attribute collisionPolicy get
::attribute state get
::attribute lastError get
::attribute assignedDeviceName get
::attribute effectiveDeviceName get
::attribute deviceIdentitySource get
::attribute deviceIdentityGeneration get
::attribute deviceIdentityEvidenceRow get
::attribute deviceIdentityConsistent get
::attribute currentKnownStateStatus get
::attribute currentKnownStateId get
::attribute currentKnownStateGeneration get
::attribute ownershipClaimed get

::method init
  expose sessionId host port terminalType requestedDeviceName collisionPolicy state lastError runtime transport controlGate alchemySealer alchemyCapabilityAuthority assignedDeviceName effectiveDeviceName deviceIdentitySource deviceIdentityGeneration deviceIdentityEvidenceRow deviceIdentityConsistent knownStateTracker currentKnownStateStatus currentKnownStateId currentKnownStateGeneration ownershipOwner ownershipClaimed
  use arg sessionIdArg, hostArg, portArg = 992, terminalTypeArg = "IBM-3179-2", deviceNameArg = "", collisionPolicyArg = "ADVANCE", transportArg = .nil, alchemySealerArg = .nil, alchemyCapabilityAuthorityArg = .nil
  sessionId = sessionIdArg~string
  host = hostArg~string~strip
  port = portArg
  terminalType = terminalTypeArg~string~strip~upper
  requestedDeviceName = deviceNameArg~string~strip~upper
  meta = .directory~new
  meta["session_id"] = sessionId
  meta["host"] = host
  meta["terminal_type"] = terminalType
  self~initTerminalAlchemy("Long-lived TN5250 TLS terminal session", meta, alchemySealerArg, alchemyCapabilityAuthorityArg)
  alchemySealer = alchemySealerArg
  alchemyCapabilityAuthority = alchemyCapabilityAuthorityArg
  collisionPolicy = .TN5250DeviceCollisionPolicy~normalize(collisionPolicyArg)
  if collisionPolicy == "" then collisionPolicy = .TN5250DeviceCollisionPolicy~ADVANCE
  state = .TN5250LiveState~CREATED
  lastError = ""
  runtime = .TN5250RuntimeSession~new(sessionId, terminalType, requestedDeviceName, 64, .nil, collisionPolicy)
  if transportArg == .nil then transport = .SocatTlsTerminalTransport~new(host, port, .true)
  else transport = transportArg
  controlGate = .nil
  identity = .TN5250DeviceIdentity~fromNegotiation(requestedDeviceName, runtime~negotiatedDeviceName)
  assignedDeviceName = identity~assignedDeviceName
  effectiveDeviceName = identity~effectiveDeviceName
  deviceIdentitySource = identity~source
  deviceIdentityGeneration = identity~generation
  deviceIdentityEvidenceRow = identity~evidenceRow
  deviceIdentityConsistent = identity~consistent
  knownStateTracker = .nil
  currentKnownStateStatus = "UNTRACKED"
  currentKnownStateId = ""
  currentKnownStateGeneration = 0
  ownershipOwner = .nil
  ownershipClaimed = .false
  self~registerStateVariable("sessionId", "CUSTOMER", "terminal session identity")
  self~registerStateVariable("host", "CUSTOMER", "TN5250 host")
  self~registerStateVariable("port", "CUSTOMER", "TN5250 TLS port")
  self~registerStateVariable("terminalType", "CUSTOMER", "negotiated terminal type request")
  self~registerStateVariable("requestedDeviceName", "CUSTOMER", "requested IBM i device name, if any")
  self~registerStateVariable("collisionPolicy", "CUSTOMER", "DEVNAME collision policy")
  self~registerStateVariable("state", "CUSTOMER", "live session lifecycle state")
  self~registerStateVariable("lastError", "CUSTOMER", "last bounded transport/session error")
  self~registerStateVariable("assignedDeviceName", "CUSTOMER", "host-observed active IBM i display name, when learned")
  self~registerStateVariable("effectiveDeviceName", "CUSTOMER", "best current device identity without conflating evidence sources")
  self~registerStateVariable("deviceIdentitySource", "CUSTOMER", "REQUESTED_DEVNAME, TELNET_DEVNAME or HOST_SIGNON_SCREEN")
  self~registerStateVariable("deviceIdentityGeneration", "CUSTOMER", "screen generation supporting host-assigned identity")
  self~registerStateVariable("deviceIdentityEvidenceRow", "CUSTOMER", "row containing host display-name evidence")
  self~registerStateVariable("deviceIdentityConsistent", "CUSTOMER", "whether screen and Telnet device evidence agree when both exist")
  self~registerStateVariable("currentKnownStateStatus", "CUSTOMER", "live semantic state match status")
  self~registerStateVariable("currentKnownStateId", "CUSTOMER", "live unique semantic state id when matched")
  self~registerStateVariable("currentKnownStateGeneration", "CUSTOMER", "generation of latest semantic interpretation")
  self~registerStateVariable("ownershipClaimed", "CUSTOMER", "whether an exclusive lifecycle owner has claimed this live session")
  /* Never register ownershipOwner, runtime, transport, controlGate, semantic
   * tracker or Alchemy key/authority objects. FULL introspection emits exact
   * object references and must not become a route to wire secrets or control. */
  self~registerMethodContract("CLAIMEXCLUSIVEOWNER", "claim exact-object exclusive lifecycle ownership", .array~of("OWNER"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("RELEASEEXCLUSIVEOWNER", "release exact-object exclusive lifecycle ownership after terminal close", .array~of("OWNER"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("OPEN", "open verified TLS TN5250 connection", .array~new, "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "NONE")
  self~registerMethodContract("OBSERVERPORT", "return read-only safe observation facade", .array~new, "ANY", .false, "FALSE", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("ATTACHKNOWNSTATECATALOG", "attach read-only semantic state interpretation to the live stream", .array~of("CATALOG"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("ENABLECONTROLGATE", "attach external admission authority and exclusive control gate", .array~of("AUTHORITY", "SCOPE"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("ACQUIRECONTROL", "acquire exclusive terminal control through gate", .array~of("IDENTITY", "RESERVATION", "CAPABILITIES"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("PUMPONCE", "consume at most one readable network chunk", .array~of("TIMEOUT", "MAXIMUM_BYTES"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "NONE")
  self~registerMethodContract("CLOSE", "close transport, revoke controller, and prove helper teardown", .array~new, "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "USE")

::method claimExclusiveOwner
  expose ownershipOwner ownershipClaimed controlGate sessionId state
  use arg ownerArg
  if ownerArg == .nil then return .TerminalResult~failure("SESSION_OWNERSHIP_OWNER_REQUIRED", "exact ownership capability required")
  if state == .TN5250LiveState~CLOSED then return .TerminalResult~failure("SESSION_OWNERSHIP_CLOSED", "closed live session cannot be claimed")
  if ownershipOwner == .nil then do
    if controlGate \== .nil then if controlGate~active then return .TerminalResult~failure("SESSION_OWNERSHIP_CONTROL_ACTIVE", "cannot claim a live session with an active controller")
    ownershipOwner = ownerArg
    ownershipClaimed = .true
    self~alchemyTouch("OWNERSHIP_CLAIM")
    ignore = self~terminalAuthorityEvent("OWNERSHIP_CLAIM", "PRIVATE_EXACT_OBJECT_CAPABILITY", sessionId)
    return .TerminalResult~success(.true)
  end
  if ownershipOwner == ownerArg then return .TerminalResult~success(.true)
  return .TerminalResult~failure("SESSION_OWNERSHIP_BUSY", "live session already has an exclusive owner")

::method releaseExclusiveOwner
  expose ownershipOwner ownershipClaimed controlGate state sessionId
  use arg ownerArg
  checked = self~validateExclusiveOwner(ownerArg)
  if \checked~ok then return checked
  if ownershipOwner == .nil then return .TerminalResult~success(.true)
  if controlGate \== .nil then if controlGate~active then return .TerminalResult~failure("SESSION_OWNERSHIP_CONTROL_ACTIVE", "release control before ownership")
  if state \== .TN5250LiveState~CLOSED then return .TerminalResult~failure("SESSION_OWNERSHIP_SESSION_NOT_CLOSED", "close the live session before releasing ownership")
  ownershipOwner = .nil
  ownershipClaimed = .false
  self~alchemyTouch("OWNERSHIP_RELEASE")
  ignore = self~terminalAuthorityEvent("OWNERSHIP_RELEASE", "PRIVATE_EXACT_OBJECT_CAPABILITY", sessionId)
  return .TerminalResult~success(.true)

::method validateExclusiveOwner private
  expose ownershipOwner
  use arg ownerArg = .nil
  if ownershipOwner == .nil then return .TerminalResult~success(.true)
  if ownerArg == .nil then return .TerminalResult~failure("SESSION_OWNERSHIP_REQUIRED", "operation belongs to the exclusive session owner")
  if ownerArg \== ownershipOwner then return .TerminalResult~failure("SESSION_OWNERSHIP_INVALID", "caller does not hold the exact ownership capability")
  return .TerminalResult~success(.true)

::method open
  expose state lastError transport
  use arg ownerArg = .nil
  ownerCheck = self~validateExclusiveOwner(ownerArg)
  if \ownerCheck~ok then return ownerCheck
  if state == .TN5250LiveState~OPEN then return .TerminalResult~success
  opened = transport~open
  if \opened~ok then do
    state = .TN5250LiveState~ERROR
    lastError = opened~code || ":" || opened~detail
    return opened
  end
  state = .TN5250LiveState~OPEN
  lastError = ""
  self~alchemyTouch("OPEN")
  ignore = self~terminalLifecycleEvent(state, "TLS_OPEN")
  return .TerminalResult~success

/* Long-lived sessions never expose a raw mutable automation port.  Trusted
 * one-shot fixtures may still use TN5250RuntimeSession directly, but a live
 * shared terminal must place mutation behind TerminalControlGate. */
::method automationPort
  return .TerminalResult~failure("CONTROL_GATE_REQUIRED", "use observerPort() for reads and enableControlGate() for mutation")

::method observerPort
  expose runtime
  return runtime~observationPort

::method attachKnownStateCatalog
  expose runtime knownStateTracker currentKnownStateStatus currentKnownStateId currentKnownStateGeneration alchemySealer alchemyCapabilityAuthority
  use arg catalogArg, capacityArg = 64, ownerArg = .nil
  ownerCheck = self~validateExclusiveOwner(ownerArg)
  if \ownerCheck~ok then return ownerCheck
  if knownStateTracker \== .nil then return .TerminalResult~failure("KNOWN_STATE_TRACKER_EXISTS", "live session already has a semantic state tracker")
  attached = runtime~attachKnownStateCatalog(catalogArg, capacityArg, alchemySealer, alchemyCapabilityAuthority)
  if \attached~ok then return attached
  knownStateTracker = attached~value
  currentKnownStateStatus = knownStateTracker~currentStatus
  currentKnownStateId = knownStateTracker~currentStateId
  currentKnownStateGeneration = knownStateTracker~currentGeneration
  self~alchemyTouch("ATTACH_KNOWN_STATE")
  return .TerminalResult~success(.true)

::method deviceIdentity
  expose requestedDeviceName runtime assignedDeviceName deviceIdentitySource deviceIdentityGeneration deviceIdentityEvidenceRow
  identity = .TN5250DeviceIdentity~new(requestedDeviceName, runtime~negotiatedDeviceName, assignedDeviceName, deviceIdentitySource, deviceIdentityGeneration, deviceIdentityEvidenceRow)
  return identity~copyDetached

::method refreshDeviceIdentity private
  expose requestedDeviceName runtime assignedDeviceName effectiveDeviceName deviceIdentitySource deviceIdentityGeneration deviceIdentityEvidenceRow deviceIdentityConsistent
  negotiated = runtime~negotiatedDeviceName

  /* Keep the negotiation evidence current even before a sign-on screen exists. */
  if assignedDeviceName == "" then do
    base = .TN5250DeviceIdentity~fromNegotiation(requestedDeviceName, negotiated)
    effectiveDeviceName = base~effectiveDeviceName
    deviceIdentitySource = base~source
    deviceIdentityConsistent = base~consistent
  end

  observed = .TN5250DeviceIdentity~observeSignon(runtime~snapshot, requestedDeviceName, negotiated)
  if \observed~ok then return .false
  identity = observed~value
  assignedDeviceName = identity~assignedDeviceName
  effectiveDeviceName = identity~effectiveDeviceName
  deviceIdentitySource = identity~source
  deviceIdentityGeneration = identity~generation
  deviceIdentityEvidenceRow = identity~evidenceRow
  deviceIdentityConsistent = identity~consistent
  self~alchemyTouch("DEVICE_IDENTITY")
  ignore = self~terminalObservationEvent(deviceIdentityGeneration, "DEVICE:" || effectiveDeviceName || ":" || deviceIdentitySource)
  return .true

::method refreshKnownState private
  expose knownStateTracker currentKnownStateStatus currentKnownStateId currentKnownStateGeneration
  if knownStateTracker == .nil then return .false
  currentKnownStateStatus = knownStateTracker~currentStatus
  currentKnownStateId = knownStateTracker~currentStateId
  currentKnownStateGeneration = knownStateTracker~currentGeneration
  return .true

::method enableControlGate
  expose sessionId requestedDeviceName effectiveDeviceName runtime controlGate alchemySealer alchemyCapabilityAuthority
  use arg authorityArg, scopeArg = "", ownerArg = .nil
  ownerCheck = self~validateExclusiveOwner(ownerArg)
  if \ownerCheck~ok then return ownerCheck
  if controlGate \== .nil then return .TerminalResult~success(.true)
  if authorityArg == .nil then return .TerminalResult~failure("CONTROL_ADMISSION_AUTHORITY_REQUIRED", "external admission authority required")
  scope = scopeArg~string~strip
  if scope == "" then do
    device = effectiveDeviceName~strip
    if device == "" then device = runtime~negotiatedDeviceName~strip
    if device == "" then device = requestedDeviceName
    if device \= "" then scope = "TERMINAL:" || device
    else scope = "TERMINAL:SESSION:" || sessionId
  end
  controlGate = .TerminalControlGate~new(sessionId, scope, runtime~automationPort, authorityArg, alchemySealer, alchemyCapabilityAuthority)
  self~alchemyTouch("ENABLE_CONTROL_GATE")
  ignore = self~terminalAuthorityEvent("ENABLE_GATE", scope, "external admission authority attached")
  return .TerminalResult~success(.true)

::method acquireControl
  expose controlGate
  use arg controllerIdentityArg, reservationArg, capabilitiesArg = .nil, ownerArg = .nil
  ownerCheck = self~validateExclusiveOwner(ownerArg)
  if \ownerCheck~ok then return ownerCheck
  if controlGate == .nil then return .TerminalResult~failure("CONTROL_GATE_NOT_ENABLED", "enableControlGate() must be called by the trusted session owner")
  return controlGate~acquire(controllerIdentityArg, reservationArg, capabilitiesArg)

::method revokeControl
  expose controlGate
  use arg reasonArg = "TRUSTED_OWNER_REVOKE", ownerArg = .nil
  ownerCheck = self~validateExclusiveOwner(ownerArg)
  if \ownerCheck~ok then return ownerCheck
  if controlGate == .nil then return .TerminalResult~failure("CONTROL_GATE_NOT_ENABLED", "no control gate")
  return controlGate~revoke(reasonArg)

::method controlActive
  expose controlGate
  if controlGate == .nil then return .false
  return controlGate~active

::method activeControllerIdentity
  expose controlGate
  if controlGate == .nil then return ""
  return controlGate~activeControllerIdentity

::method activeControlLeaseId
  expose controlGate
  if controlGate == .nil then return ""
  return controlGate~activeLeaseId

::method snapshot
  expose runtime
  return runtime~snapshot

::method negotiatedDeviceName
  expose runtime
  return runtime~negotiatedDeviceName

::method deviceNameCollisionCount
  expose runtime
  return runtime~deviceNameCollisionCount

::method strictDeviceCollisionDetected
  expose runtime
  return runtime~strictDeviceCollisionDetected

::method transparentReady
  expose runtime
  return runtime~transparentReady

::method caFile
  expose transport
  if transport~hasMethod("CAFILE") then return transport~caFile
  return ""

::method caPath
  expose transport
  if transport~hasMethod("CAPATH") then return transport~caPath
  return ""

::method trustSource
  expose transport
  if transport~hasMethod("TRUSTSOURCE") then return transport~trustSource
  return ""

/* Process at most one readable network chunk.  A quiet terminal is success
 * with activity=false; callers can therefore keep a live session parked at an
 * operator wait without blocking forever. */
::method pumpOnce
  expose state lastError runtime transport requestedDeviceName controlGate
  use arg timeoutSeconds = 1, maximumBytes = 16384, ownerArg = .nil
  ownerCheck = self~validateExclusiveOwner(ownerArg)
  if \ownerCheck~ok then return ownerCheck
  beforeGeneration = runtime~snapshot~generation
  if state \== .TN5250LiveState~OPEN then return .TerminalResult~failure("TN5250_LIVE_NOT_OPEN", state)

  received = transport~receiveBytesWait(maximumBytes, timeoutSeconds)
  if \received~ok then do
    if received~code == "TRANSPORT_TIMEOUT" then return .TerminalResult~success(.TN5250LivePumpResult~new(.false, state, runtime~snapshot))
    state = .TN5250LiveState~ERROR
    lastError = received~code || ":" || received~detail
    if controlGate \== .nil then if controlGate~active then ignore = controlGate~revoke("SESSION_TRANSPORT_ERROR")
    return received
  end

  bytes = received~value
  if bytes~length > 0 & controlGate \== .nil then ignore = controlGate~recordObservedFact("BYTES_RX", bytes~length, "TN5250")
  if bytes~length = 0 then do
    state = .TN5250LiveState~REMOTE_CLOSED
    lastError = "remote closed connection"
    self~alchemyTouch("REMOTE_CLOSED")
    ignore = self~terminalLifecycleEvent(state, lastError)
    if controlGate \== .nil then if controlGate~active then ignore = controlGate~revoke("SESSION_REMOTE_CLOSED")
    ignore = transport~close
    return .TerminalResult~success(.TN5250LivePumpResult~new(.true, state, runtime~snapshot))
  end

  fed = runtime~feedNetwork(bytes)
  if \fed~ok then do
    state = .TN5250LiveState~ERROR
    lastError = fed~code || ":" || fed~detail
    if controlGate \== .nil then if controlGate~active then ignore = controlGate~revoke("SESSION_PROTOCOL_ERROR")
    ignore = transport~close
    return fed
  end

  /* A strict collision is a meaningful terminal-lifecycle result, not an
   * invitation to create another IBM i device.  TN5250TelnetProfile emits no
   * replacement DEVNAME in this case, so close before any unrelated Telnet
   * output from this feed can prolong the rejected connection. */
  if runtime~strictDeviceCollisionDetected then do
    state = .TN5250LiveState~DEVICE_COLLISION
    lastError = "requested device is already in use: " || requestedDeviceName
    self~alchemyTouch("DEVICE_COLLISION")
    ignore = self~terminalLifecycleEvent(state, lastError)
    if controlGate \== .nil then if controlGate~active then ignore = controlGate~revoke("SESSION_DEVICE_COLLISION")
    ignore = transport~close
    return .TerminalResult~failure("TN5250_DEVICE_COLLISION", lastError)
  end

  outbound = fed~value~outboundBytes
  if outbound~length > 0 then do
    sent = transport~sendBytes(outbound)
    if \sent~ok then do
      state = .TN5250LiveState~ERROR
      lastError = sent~code || ":" || sent~detail
      if controlGate \== .nil then if controlGate~active then ignore = controlGate~revoke("SESSION_TRANSPORT_ERROR")
      ignore = transport~close
      return sent
    end
    if controlGate \== .nil then ignore = controlGate~recordObservedFact("BYTES_TX", outbound~length, "TN5250")
  end

  afterGeneration = fed~value~snapshot~generation
  if controlGate \== .nil & afterGeneration > beforeGeneration then ignore = controlGate~recordHostScreenUpdate(afterGeneration - beforeGeneration)
  if afterGeneration > beforeGeneration then do
    self~alchemyTouch("SCREEN_UPDATE")
    ignore = self~terminalObservationEvent(afterGeneration, "TN5250_HOST_SCREEN")
    ignore = self~refreshKnownState
    ignore = self~refreshDeviceIdentity
  end
  return .TerminalResult~success(.TN5250LivePumpResult~new(.true, state, fed~value~snapshot))

/* Trusted controller hook after a safe automation action.  The bytes drained
 * here may contain NONDISPLAY field contents and are never exposed by the
 * automation facade. */
::method flushTerminalOutput
  expose state lastError runtime transport controlGate
  use arg ownerArg = .nil
  ownerCheck = self~validateExclusiveOwner(ownerArg)
  if \ownerCheck~ok then return ownerCheck
  if state \== .TN5250LiveState~OPEN then return .TerminalResult~failure("TN5250_LIVE_NOT_OPEN", state)
  drained = runtime~drainTerminalOutput
  if \drained~ok then return drained
  bytes = drained~value
  if bytes~length = 0 then return .TerminalResult~success(0)
  sent = transport~sendBytes(bytes)
  if \sent~ok then do
    state = .TN5250LiveState~ERROR
    lastError = sent~code || ":" || sent~detail
    if controlGate \== .nil then if controlGate~active then ignore = controlGate~revoke("SESSION_TRANSPORT_ERROR")
    return sent
  end
  if controlGate \== .nil then ignore = controlGate~recordObservedFact("BYTES_TX", bytes~length, "TN5250")
  return .TerminalResult~success(bytes~length)

::method close
  expose state lastError transport controlGate
  use arg ownerArg = .nil
  ownerCheck = self~validateExclusiveOwner(ownerArg)
  if \ownerCheck~ok then return ownerCheck
  if controlGate \== .nil then if controlGate~active then ignore = controlGate~revoke("SESSION_CLOSED")
  closed = transport~close
  if \closed~ok then do
    state = .TN5250LiveState~ERROR
    lastError = closed~code || ":" || closed~detail
    return closed
  end
  state = .TN5250LiveState~CLOSED
  self~alchemyTouch("CLOSE")
  ignore = self~terminalLifecycleEvent(state, "transport helper terminated")
  ignore = self~alchemyRetire
  return .TerminalResult~success

::requires "TN5250Automation.cls"
::requires "TN5250DeviceIdentity.cls"
::requires "TerminalTransport.cls"
::requires "TerminalControl.cls"
