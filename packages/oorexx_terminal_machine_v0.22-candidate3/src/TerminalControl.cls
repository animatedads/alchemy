/*
 * Generic terminal control gate v0.1.
 *
 * One terminal may have many observers, but exactly one mutable controller.
 * Control is an in-process capability lease backed by an external admission
 * authority.  The gate deliberately does not implement WLU, cryptography or
 * billing.  A WLUAuthority can be supplied directly because it implements the
 * required admit(reservation) contract and authenticates its own reservation
 * proof.
 *
 * Security / concurrency invariants:
 *   - observation never requires a control lease;
 *   - at most one active control lease exists per gate;
 *   - mutating calls require possession of that exact lease object;
 *   - reservation identity and scope must match the requested controller;
 *   - external admission is revalidated before every mutation;
 *   - screen generation is checked again inside the serialized gate;
 *   - actor identity is taken from the lease, never from caller text;
 *   - terminal metering facts are evidence; the terminal never prices them.
 */

::class TerminalControlBuild public
::constant RELEASE "0.1"
::constant API_VERSION "terminal.control/0.1"

::class TerminalControlCapability public
::constant FIELD_WRITE "FIELD_WRITE"
::constant CURSOR_MOVE "CURSOR_MOVE"
::constant FIELD_NAVIGATION "FIELD_NAVIGATION"
::constant AID "AID"
::constant ERROR_RESET "ERROR_RESET"
::constant SYSTEM_REQUEST "SYSTEM_REQUEST"

::method standard class
  return .array~of(self~FIELD_WRITE, self~CURSOR_MOVE, self~FIELD_NAVIGATION, self~AID, self~ERROR_RESET)

::class TerminalMeterFact public
::attribute factType get
::attribute quantity get
::attribute source get
::attribute dimensions get
::attribute generation get
::attribute controllerIdentity get
::attribute timestamp get

::method init
  expose factType quantity source dimensions generation controllerIdentity timestamp
  use arg factTypeArg, quantityArg = 1, sourceArg = "TERMINAL", dimensionsArg = .nil, generationArg = 0, controllerArg = "", timestampArg = ""
  factType = factTypeArg~string~strip~upper
  if factType == "" then raise syntax 88.900 array("Terminal meter fact type must not be empty")
  if \datatype(quantityArg, "W") | quantityArg < 0 then raise syntax 88.900 array("Terminal meter fact quantity must be a non-negative whole number")
  quantity = quantityArg
  source = sourceArg~string
  dimensions = .TerminalUtil~copyDirectory(dimensionsArg)
  generation = generationArg
  controllerIdentity = controllerArg~string
  if timestampArg == "" then timestamp = .DateTime~new~utcIsoDate
  else timestamp = timestampArg~string

::method copyDetached
  expose factType quantity source dimensions generation controllerIdentity timestamp
  return .TerminalMeterFact~new(factType, quantity, source, dimensions, generation, controllerIdentity, timestamp)

::class TerminalControlLease public
::attribute leaseId get
::attribute controllerIdentity get
::attribute sessionId get
::attribute scope get
::attribute acquiredGeneration get
::attribute acquiredAt get

::method init
  expose leaseId controllerIdentity sessionId scope acquiredGeneration acquiredAt capabilities
  use arg leaseIdArg, controllerArg, sessionIdArg, scopeArg, generationArg, capabilitiesArg
  leaseId = leaseIdArg~string
  controllerIdentity = controllerArg~string
  sessionId = sessionIdArg~string
  scope = scopeArg~string
  acquiredGeneration = generationArg
  acquiredAt = .DateTime~new~utcIsoDate
  capabilities = .TerminalCapabilities~new
  if capabilitiesArg \== .nil then do cap over capabilitiesArg
    capabilities~add(cap)
  end

::method hasCapability
  expose capabilities
  use arg capabilityArg
  return capabilities~has(capabilityArg)

::method capabilityNames
  expose capabilities
  return capabilities~names

/* Lease-bound facade handed to the controller.  The active lease object and
 * gate are private implementation details: an observer cannot discover the
 * current capability object and impersonate its holder. */
::class TerminalLeasedController public
::attribute leaseId get
::attribute controllerIdentity get
::attribute sessionId get
::attribute scope get
::attribute acquiredGeneration get

::method init
  expose gate lease leaseId controllerIdentity sessionId scope acquiredGeneration
  use arg gateArg, leaseArg
  gate = gateArg
  lease = leaseArg
  leaseId = lease~leaseId
  controllerIdentity = lease~controllerIdentity
  sessionId = lease~sessionId
  scope = lease~scope
  acquiredGeneration = lease~acquiredGeneration

::method snapshot
  expose gate
  return gate~snapshot

::method capabilityNames
  expose lease
  return lease~capabilityNames

::method meterFacts
  expose gate lease
  return gate~meterFacts(lease)

::method release
  expose gate lease
  use arg reasonArg = "RELEASED"
  return gate~release(lease, reasonArg)

::method setField
  expose gate lease
  use arg generationArg, fieldIdArg, valueArg
  return gate~setField(lease, generationArg, fieldIdArg, valueArg)

::method typeAtCursor
  expose gate lease
  use arg generationArg, textArg
  return gate~typeAtCursor(lease, generationArg, textArg)

::method moveCursor
  expose gate lease
  use arg generationArg, rowArg, columnArg
  return gate~moveCursor(lease, generationArg, rowArg, columnArg)

::method focusField
  expose gate lease
  use arg generationArg, fieldIdArg
  return gate~focusField(lease, generationArg, fieldIdArg)

::method nextInputField
  expose gate lease
  use arg generationArg
  return gate~nextInputField(lease, generationArg)

::method previousInputField
  expose gate lease
  use arg generationArg
  return gate~previousInputField(lease, generationArg)

::method home
  expose gate lease
  use arg generationArg
  return gate~home(lease, generationArg)

::method errorReset
  expose gate lease
  use arg generationArg
  return gate~errorReset(lease, generationArg)

::method press
  expose gate lease
  use arg generationArg, aidNameArg
  return gate~press(lease, generationArg, aidNameArg)

::method systemRequest
  expose gate lease
  use arg generationArg
  return gate~systemRequest(lease, generationArg)

::class TerminalControlReleaseReceipt public
::attribute leaseId get
::attribute controllerIdentity get
::attribute reason get
::attribute releasedAt get
::attribute mutationCount get

::method init
  expose leaseId controllerIdentity reason releasedAt meterFacts mutationCount
  use arg leaseIdArg, controllerArg, reasonArg, factsArg, mutationCountArg
  leaseId = leaseIdArg~string
  controllerIdentity = controllerArg~string
  reason = reasonArg~string
  releasedAt = .DateTime~new~utcIsoDate
  meterFacts = .array~new
  if factsArg \== .nil then do fact over factsArg
    meterFacts~append(fact~copyDetached)
  end
  mutationCount = mutationCountArg

::method meterFacts
  expose meterFacts
  out = .array~new
  do fact over meterFacts
    out~append(fact~copyDetached)
  end
  return out

::class TerminalControlGate subclass TerminalAlchemyObject public
::attribute sessionId get
::attribute scope get

::method init
  expose sessionId scope port authority activeLease activeReservation leaseSequence meterFacts mutationCount lastRelease awaitingHostRoundTrip
  use arg sessionIdArg, scopeArg, mutationPortArg, admissionAuthorityArg, sealerArg = .nil, alchemyAuthorityArg = .nil
  sessionId = sessionIdArg~string
  scope = scopeArg~string~strip
  meta = .directory~new
  meta["session_id"] = sessionId
  meta["authority_scope"] = scope
  self~initTerminalAlchemy("Exclusive one-writer terminal control gate", meta, sealerArg, alchemyAuthorityArg)
  if sessionId == "" then raise syntax 88.900 array("TerminalControlGate requires session id")
  if scope == "" then raise syntax 88.900 array("TerminalControlGate requires authority scope")
  if mutationPortArg == .nil then raise syntax 88.900 array("TerminalControlGate requires mutation port")
  if admissionAuthorityArg == .nil then raise syntax 88.900 array("TerminalControlGate requires admission authority")
  if \admissionAuthorityArg~hasMethod("ADMIT") then raise syntax 88.900 array("TerminalControlGate authority must implement admit(reservation)")
  port = mutationPortArg
  authority = admissionAuthorityArg
  activeLease = .nil
  activeReservation = .nil
  leaseSequence = 0
  meterFacts = .array~new
  mutationCount = 0
  lastRelease = .nil
  awaitingHostRoundTrip = .false
  self~registerStateVariable("sessionId", "CUSTOMER", "terminal session identity")
  self~registerStateVariable("scope", "CUSTOMER", "external admission authority scope")
  self~registerStateVariable("mutationCount", "CUSTOMER", "successful terminal mutations under active lease")
  /* activeLease, activeReservation and meterFacts are deliberately unregistered.
   * FULL Alchemy state is evidence, not a capability/collection export API. */
  self~registerMethodContract("ACQUIRE", "admit and acquire exclusive terminal control", .array~of("CONTROLLER", "RESERVATION", "CAPABILITIES"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("RELEASE", "release active terminal control lease", .array~of("LEASE", "REASON"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("REVOKE", "trusted owner revokes active terminal control lease", .array~of("REASON"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("SETFIELD", "write a structured input field under active authority", .array~of("LEASE", "GENERATION", "FIELD_ID", "VALUE"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "USE")
  self~registerMethodContract("PRESS", "send an AID under active authority", .array~of("LEASE", "GENERATION", "AID"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "USE")
  self~registerMethodContract("SYSTEMREQUEST", "send privileged system request under explicit capability", .array~of("LEASE", "GENERATION"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "USE")

::method snapshot
  expose port
  return port~snapshot

::method active
  expose activeLease
  guard on
  return activeLease \== .nil

::method activeLeaseId
  expose activeLease
  guard on
  if activeLease == .nil then return ""
  return activeLease~leaseId

::method activeControllerIdentity
  expose activeLease
  guard on
  if activeLease == .nil then return ""
  return activeLease~controllerIdentity

::method lastRelease
  expose lastRelease
  guard on
  return lastRelease

::method acquire
  expose sessionId scope authority activeLease activeReservation leaseSequence meterFacts mutationCount awaitingHostRoundTrip
  use arg controllerIdentityArg, reservationArg, capabilitiesArg = .nil
  guard on
  controllerIdentity = controllerIdentityArg~string~strip
  if controllerIdentity == "" then return .TerminalResult~failure("CONTROL_IDENTITY_REQUIRED", "controller identity must not be empty")
  if activeLease \== .nil then return .TerminalResult~failure("CONTROL_BUSY", activeLease~controllerIdentity || " holds " || activeLease~leaseId)
  if reservationArg == .nil then return .TerminalResult~failure("CONTROL_ADMISSION_REQUIRED", "authenticated admission reservation required")
  if \reservationArg~hasMethod("IDENTITY") | \reservationArg~hasMethod("SCOPE") then return .TerminalResult~failure("CONTROL_ADMISSION_INVALID", "reservation must expose identity and scope")
  if reservationArg~identity \== controllerIdentity then return .TerminalResult~failure("CONTROL_IDENTITY_MISMATCH", "reservation identity=" || reservationArg~identity)
  if reservationArg~scope \== scope then return .TerminalResult~failure("CONTROL_SCOPE_MISMATCH", "reservation scope=" || reservationArg~scope || " gate scope=" || scope)

  admitted = authority~admit(reservationArg)
  if \admitted~ok then return .TerminalResult~failure("CONTROL_ADMISSION_DENIED", admitted~code || ":" || admitted~detail)

  if capabilitiesArg == .nil then capabilitiesArg = .TerminalControlCapability~standard
  leaseSequence += 1
  leaseId = "CTL-" || sessionId || "-" || right(leaseSequence, 8, "0")
  current = self~snapshot
  activeLease = .TerminalControlLease~new(leaseId, controllerIdentity, sessionId, scope, current~generation, capabilitiesArg)
  activeReservation = reservationArg
  meterFacts = .array~new
  mutationCount = 0
  awaitingHostRoundTrip = .false
  self~alchemyTouch("CONTROL_ACQUIRE")
  ignore = self~terminalAuthorityEvent("ACQUIRE", controllerIdentity, leaseId)
  return .TerminalResult~success(.TerminalLeasedController~new(self, activeLease))

::method release
  expose activeLease activeReservation meterFacts mutationCount lastRelease awaitingHostRoundTrip
  use arg leaseArg, reasonArg = "RELEASED"
  guard on
  valid = self~requireLeaseObject(leaseArg)
  if \valid~ok then return valid
  lastRelease = .TerminalControlReleaseReceipt~new(activeLease~leaseId, activeLease~controllerIdentity, reasonArg, meterFacts, mutationCount)
  activeLease = .nil
  activeReservation = .nil
  meterFacts = .array~new
  mutationCount = 0
  awaitingHostRoundTrip = .false
  self~alchemyTouch("CONTROL_RELEASE")
  ignore = self~terminalAuthorityEvent("RELEASE", lastRelease~controllerIdentity, reasonArg)
  return .TerminalResult~success(lastRelease)

::method revoke
  expose activeLease activeReservation meterFacts mutationCount lastRelease awaitingHostRoundTrip
  use arg reasonArg = "REVOKED"
  guard on
  if activeLease == .nil then return .TerminalResult~failure("CONTROL_NOT_HELD", "no active controller")
  lastRelease = .TerminalControlReleaseReceipt~new(activeLease~leaseId, activeLease~controllerIdentity, reasonArg, meterFacts, mutationCount)
  revokedController = activeLease~controllerIdentity
  activeLease = .nil
  activeReservation = .nil
  meterFacts = .array~new
  mutationCount = 0
  awaitingHostRoundTrip = .false
  self~alchemyTouch("CONTROL_REVOKE")
  ignore = self~terminalAuthorityEvent("REVOKE", revokedController, reasonArg)
  return .TerminalResult~success(lastRelease)

::method meterFacts
  expose activeLease meterFacts
  use arg leaseArg
  guard on
  valid = self~requireLeaseObject(leaseArg)
  if \valid~ok then return valid
  return .TerminalResult~success(self~copyFacts(meterFacts))

/* Transport/session owners can append observed work to the currently active
 * controller.  Facts are deliberately not priced here. */
::method recordObservedFact
  expose activeLease meterFacts port
  use arg factTypeArg, quantityArg = 1, sourceArg = "TERMINAL", dimensionsArg = .nil
  guard on
  if activeLease == .nil then return .TerminalResult~success(.false)
  snapshot = port~snapshot
  meterFacts~append(.TerminalMeterFact~new(factTypeArg, quantityArg, sourceArg, dimensionsArg, snapshot~generation, activeLease~controllerIdentity))
  return .TerminalResult~success(.true)

::method recordHostScreenUpdate
  expose activeLease meterFacts port awaitingHostRoundTrip
  use arg quantityArg = 1
  guard on
  if activeLease == .nil then return .TerminalResult~success(.false)
  snapshot = port~snapshot
  meterFacts~append(.TerminalMeterFact~new("SCREEN_UPDATE", quantityArg, "TN5250", .nil, snapshot~generation, activeLease~controllerIdentity))
  if awaitingHostRoundTrip then do
    meterFacts~append(.TerminalMeterFact~new("HOST_ROUND_TRIP", 1, "TN5250", .nil, snapshot~generation, activeLease~controllerIdentity))
    awaitingHostRoundTrip = .false
  end
  return .TerminalResult~success(.true)

::method setField
  expose port activeLease meterFacts mutationCount
  use arg leaseArg, generationArg, fieldIdArg, valueArg
  guard on
  checked = self~validateMutation(leaseArg, generationArg, .TerminalControlCapability~FIELD_WRITE)
  if \checked~ok then return checked
  outcome = port~setField(generationArg, fieldIdArg, valueArg, activeLease~controllerIdentity)
  if outcome~ok then do
    mutationCount += 1
    meterFacts~append(self~newFact("FIELD_WRITE", 1, "TN5250"))
    self~alchemyTouch("FIELD_WRITE")
  end
  return outcome

::method typeAtCursor
  expose port activeLease meterFacts mutationCount
  use arg leaseArg, generationArg, textArg
  guard on
  checked = self~validateMutation(leaseArg, generationArg, .TerminalControlCapability~FIELD_WRITE)
  if \checked~ok then return checked
  outcome = port~typeAtCursor(generationArg, textArg, activeLease~controllerIdentity)
  if outcome~ok then do
    mutationCount += 1
    meterFacts~append(self~newFact("FIELD_WRITE", 1, "TN5250"))
  end
  return outcome

::method moveCursor
  expose port activeLease mutationCount
  use arg leaseArg, generationArg, rowArg, columnArg
  guard on
  checked = self~validateMutation(leaseArg, generationArg, .TerminalControlCapability~CURSOR_MOVE)
  if \checked~ok then return checked
  outcome = port~moveCursor(generationArg, rowArg, columnArg, activeLease~controllerIdentity)
  if outcome~ok then mutationCount += 1
  return outcome

::method focusField
  expose port activeLease mutationCount
  use arg leaseArg, generationArg, fieldIdArg
  guard on
  checked = self~validateMutation(leaseArg, generationArg, .TerminalControlCapability~FIELD_NAVIGATION)
  if \checked~ok then return checked
  outcome = port~focusField(generationArg, fieldIdArg, activeLease~controllerIdentity)
  if outcome~ok then mutationCount += 1
  return outcome

::method nextInputField
  expose port activeLease mutationCount
  use arg leaseArg, generationArg
  guard on
  checked = self~validateMutation(leaseArg, generationArg, .TerminalControlCapability~FIELD_NAVIGATION)
  if \checked~ok then return checked
  outcome = port~nextInputField(generationArg, activeLease~controllerIdentity)
  if outcome~ok then mutationCount += 1
  return outcome

::method previousInputField
  expose port activeLease mutationCount
  use arg leaseArg, generationArg
  guard on
  checked = self~validateMutation(leaseArg, generationArg, .TerminalControlCapability~FIELD_NAVIGATION)
  if \checked~ok then return checked
  outcome = port~previousInputField(generationArg, activeLease~controllerIdentity)
  if outcome~ok then mutationCount += 1
  return outcome

::method home
  expose port activeLease mutationCount
  use arg leaseArg, generationArg
  guard on
  checked = self~validateMutation(leaseArg, generationArg, .TerminalControlCapability~FIELD_NAVIGATION)
  if \checked~ok then return checked
  outcome = port~home(generationArg, activeLease~controllerIdentity)
  if outcome~ok then mutationCount += 1
  return outcome

::method errorReset
  expose port activeLease mutationCount
  use arg leaseArg, generationArg
  guard on
  checked = self~validateMutation(leaseArg, generationArg, .TerminalControlCapability~ERROR_RESET)
  if \checked~ok then return checked
  outcome = port~errorReset(generationArg, activeLease~controllerIdentity)
  if outcome~ok then mutationCount += 1
  return outcome

::method press
  expose port activeLease meterFacts mutationCount awaitingHostRoundTrip
  use arg leaseArg, generationArg, aidNameArg
  guard on
  checked = self~validateMutation(leaseArg, generationArg, .TerminalControlCapability~AID)
  if \checked~ok then return checked
  outcome = port~press(generationArg, aidNameArg, activeLease~controllerIdentity)
  if outcome~ok then do
    mutationCount += 1
    meterFacts~append(self~newFact("AID", 1, "TN5250"))
    awaitingHostRoundTrip = .true
    self~alchemyTouch("AID")
  end
  return outcome

::method systemRequest
  expose port activeLease mutationCount awaitingHostRoundTrip
  use arg leaseArg, generationArg
  guard on
  checked = self~validateMutation(leaseArg, generationArg, .TerminalControlCapability~SYSTEM_REQUEST)
  if \checked~ok then return checked
  outcome = port~systemRequest(generationArg, activeLease~controllerIdentity)
  if outcome~ok then do
    mutationCount += 1
    awaitingHostRoundTrip = .true
    self~alchemyTouch("SYSTEM_REQUEST")
  end
  return outcome

::method validateMutation private
  expose activeLease activeReservation authority port
  use arg leaseArg, generationArg, capabilityArg
  valid = self~requireLeaseObject(leaseArg)
  if \valid~ok then return valid
  if \activeLease~hasCapability(capabilityArg) then return .TerminalResult~failure("CONTROL_CAPABILITY_DENIED", capabilityArg)

  admitted = authority~admit(activeReservation)
  if \admitted~ok then do
    /* An expired/invalid cryptographic admission immediately removes the
     * keyboard capability.  No later caller inherits it. */
    invalidCode = admitted~code
    invalidDetail = admitted~detail
    ignore = self~revoke("ADMISSION_INVALID:" || invalidCode)
    return .TerminalResult~failure("CONTROL_ADMISSION_INVALID", invalidCode || ":" || invalidDetail)
  end

  current = port~snapshot
  if generationArg \== current~generation then return .TerminalResult~failure("STALE_SCREEN", "expected generation " || generationArg || ", actual " || current~generation)
  return .TerminalResult~success

::method requireLeaseObject private
  expose activeLease
  use arg leaseArg
  if activeLease == .nil then return .TerminalResult~failure("CONTROL_NOT_HELD", "no active controller")
  if leaseArg == .nil then return .TerminalResult~failure("CONTROL_LEASE_REQUIRED", "active control lease required")
  if leaseArg \== activeLease then return .TerminalResult~failure("CONTROL_LEASE_INVALID", "lease is not the active terminal capability")
  return .TerminalResult~success(activeLease)

::method newFact private
  expose activeLease port
  use arg factTypeArg, quantityArg, sourceArg
  snap = port~snapshot
  return .TerminalMeterFact~new(factTypeArg, quantityArg, sourceArg, .nil, snap~generation, activeLease~controllerIdentity)

::method copyFacts private
  use arg factsArg
  out = .array~new
  do fact over factsArg
    out~append(fact~copyDetached)
  end
  return out

::requires "TerminalCore.cls"
