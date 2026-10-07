/*
 * TerminalBroker.cls - terminal session broker/service core v0.14.
 *
 * This layer deliberately sits above TerminalSessionOwner.  The service
 * process retains the one real TerminalSessionOwner; AI/operator clients are
 * issued only broker-side observer/controller capabilities.  No client facade
 * returns the owner, owner-side observer, owner-side controller, live session,
 * transport, runtime, admission reservation or wire bytes.
 *
 * Authority invariants:
 *   - one broker maps to one persistent TerminalSessionOwner / live session;
 *   - attaching a broker client reuses that owned session and never opens one;
 *   - broker clients are read-only until an explicit external admission proof
 *     is accepted by the underlying owner/control gate;
 *   - at most one broker controller exists;
 *   - every bridge call authenticates exact issued object identity, never just
 *     caller-supplied ids or principal text;
 *   - controller handoff remains release old -> prove no controller -> acquire
 *     target at the then-current generation;
 *   - no action/keystroke queue exists;
 *   - Alchemy registered state contains scalar/value evidence only.
 *
 * v0.14 is the service *core*: it can be hosted behind IPC, a local socket or
 * another message transport, but intentionally does not invent an IPC wire
 * protocol or daemon lifecycle in the generic terminal package.
 */

::class TerminalBrokerBuild public
::constant RELEASE "0.14"
::constant API_VERSION "terminal.broker/0.14"

::class TerminalBrokerStatus public
::attribute brokerId get
::attribute sessionId get
::attribute state get
::attribute clientCount get
::attribute maxClients get
::attribute controlActive get
::attribute activeControllerPrincipal get
::attribute activeControllerClientId get
::attribute activeControlLeaseId get

::method init
  expose brokerId sessionId state clientCount maxClients controlActive activeControllerPrincipal activeControllerClientId activeControlLeaseId
  use strict arg brokerIdArg, sessionIdArg, stateArg, clientCountArg, maxClientsArg, controlActiveArg, controllerPrincipalArg, controllerClientIdArg, leaseIdArg
  brokerId = brokerIdArg~string
  sessionId = sessionIdArg~string
  state = stateArg~string
  clientCount = clientCountArg
  maxClients = maxClientsArg
  controlActive = controlActiveArg == .true
  activeControllerPrincipal = controllerPrincipalArg~string
  activeControllerClientId = controllerClientIdArg~string
  activeControlLeaseId = leaseIdArg~string

::method copyDetached
  expose brokerId sessionId state clientCount maxClients controlActive activeControllerPrincipal activeControllerClientId activeControlLeaseId
  return .TerminalBrokerStatus~new(brokerId, sessionId, state, clientCount, maxClients, controlActive, activeControllerPrincipal, activeControllerClientId, activeControlLeaseId)


::class TerminalSessionBroker subclass TerminalAlchemyObject public
::attribute brokerId get
::attribute sessionId get
::attribute state get
::attribute maxClients get

::method init
  expose brokerId sessionId state maxClients owner clients principalIndex clientSequence clientCount activeControllerFacade activeOwnerController activeControllerPrincipal activeControllerClientId activeControlLeaseId alchemySealer alchemyCapabilityAuthority
  use arg brokerIdArg, ownerArg, maxClientsArg = 16, alchemySealerArg = .nil, alchemyCapabilityAuthorityArg = .nil

  brokerId = brokerIdArg~string~strip
  if brokerId == "" then raise syntax 88.900 array("TerminalSessionBroker broker id must not be empty")
  if ownerArg == .nil then raise syntax 88.900 array("TerminalSessionBroker requires a TerminalSessionOwner-like service owner")
  required = .array~of("SESSIONID", "STATE", "OPEN", "ATTACHOBSERVER", "DETACHOBSERVER", "ATTACHKNOWNSTATECATALOG", "ENABLECONTROLGATE", "PUMPONCE", "CONTROLACTIVE", "ACTIVECONTROLLERIDENTITY", "ACTIVECONTROLLEASEID", "CLOSE")
  do methodName over required
    if \ownerArg~hasMethod(methodName) then raise syntax 88.900 array("TerminalSessionBroker owner missing method " || methodName)
  end
  if \datatype(maxClientsArg, "W") then raise syntax 88.900 array("TerminalSessionBroker maxClients must be a positive whole number")
  if maxClientsArg < 1 then raise syntax 88.900 array("TerminalSessionBroker maxClients must be a positive whole number")
  if ownerArg~controlActive then raise syntax 88.900 array("TerminalSessionBroker requires owner with no active controller")

  owner = ownerArg
  sessionId = owner~sessionId~string
  if sessionId == "" then raise syntax 88.900 array("TerminalSessionBroker owner session id must not be empty")
  state = owner~state~string
  maxClients = maxClientsArg
  clients = .table~new
  principalIndex = .table~new
  clientSequence = 0
  clientCount = 0
  activeControllerFacade = .nil
  activeOwnerController = .nil
  activeControllerPrincipal = ""
  activeControllerClientId = ""
  activeControlLeaseId = ""
  alchemySealer = alchemySealerArg
  alchemyCapabilityAuthority = alchemyCapabilityAuthorityArg

  meta = .directory~new
  meta["broker_id"] = brokerId
  meta["session_id"] = sessionId
  meta["broker_api"] = .TerminalBrokerBuild~API_VERSION
  self~initTerminalAlchemy("Bounded service broker for one persistent terminal owner", meta, alchemySealer, alchemyCapabilityAuthority)

  self~registerStateVariable("brokerId", "CUSTOMER", "terminal broker identity")
  self~registerStateVariable("sessionId", "CUSTOMER", "one persistent terminal session identity")
  self~registerStateVariable("state", "CUSTOMER", "broker-mirrored owner lifecycle state")
  self~registerStateVariable("maxClients", "CUSTOMER", "maximum attached broker clients")
  self~registerStateVariable("clientCount", "CUSTOMER", "currently attached broker clients")
  self~registerStateVariable("activeControllerPrincipal", "CUSTOMER", "current broker keyboard owner principal")
  self~registerStateVariable("activeControllerClientId", "CUSTOMER", "current broker client holding keyboard authority")
  self~registerStateVariable("activeControlLeaseId", "CUSTOMER", "opaque underlying control lease id")
  /* owner, owner-side attachments/controllers, client tables, admission objects,
   * sealers and capability authorities are deliberately not registered. */

  self~registerMethodContract("OPEN", "open the one service-owned persistent terminal connection", .array~new, "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "NONE")
  self~registerMethodContract("ATTACHCLIENT", "issue one read-only broker-side client capability", .array~of("PRINCIPAL"), "TERMINALRESULT", .false, "FALSE", "CUSTOMER", "NORMAL", "MUTATE", "USE")
  self~registerMethodContract("ATTACHKNOWNSTATECATALOG", "attach semantic interpretation inside the service owner", .array~of("CATALOG", "CAPACITY"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("ENABLECONTROLGATE", "attach external terminal admission authority inside the service owner", .array~of("AUTHORITY", "SCOPE"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("PUMPONCE", "advance the one service-owned live connection by at most one input chunk", .array~of("TIMEOUT", "MAXIMUM_BYTES"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "NONE")
  self~registerMethodContract("STATUS", "return detached scalar broker status evidence", .array~new, "TERMINALBROKERSTATUS", .false, "FALSE", "CUSTOMER", "NORMAL", "READ", "USE")
  self~registerMethodContract("CLOSE", "invalidate broker capabilities and close the one persistent owner", .array~new, "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "USE")

::method open
  expose owner state
  if state == "OPEN" then return .TerminalResult~success(.true)
  if state == "CLOSED" then return .TerminalResult~failure("TERMINAL_BROKER_CLOSED", "closed terminal broker cannot be reopened")
  opened = owner~open
  state = owner~state~string
  if \opened~ok then return opened
  if state \== "OPEN" then return .TerminalResult~failure("TERMINAL_BROKER_OPEN_STATE_INVALID", state)
  self~alchemyTouch("OPEN")
  ignore = self~terminalLifecycleEvent(state, "BROKER_ONE_SESSION_OPEN")
  return .TerminalResult~success(.true)

::method status
  expose brokerId sessionId state clientCount maxClients owner activeControllerFacade activeControllerPrincipal activeControllerClientId activeControlLeaseId
  state = owner~state~string
  ignore = self~reconcileControl
  return .TerminalBrokerStatus~new(brokerId, sessionId, state, clientCount, maxClients, activeControllerFacade \== .nil, activeControllerPrincipal, activeControllerClientId, activeControlLeaseId)

::method attachedClientCount
  expose clientCount
  return clientCount

::method controlActive
  expose activeControllerFacade
  ignore = self~reconcileControl
  return activeControllerFacade \== .nil

::method activeControllerPrincipal
  expose activeControllerPrincipal
  ignore = self~reconcileControl
  return activeControllerPrincipal

::method activeControllerClientId
  expose activeControllerClientId
  ignore = self~reconcileControl
  return activeControllerClientId

::method activeControlLeaseId
  expose activeControlLeaseId
  ignore = self~reconcileControl
  return activeControlLeaseId

::method attachClient
  expose brokerId sessionId state maxClients owner clients principalIndex clientSequence clientCount alchemySealer alchemyCapabilityAuthority
  use arg principalArg
  if state \== "OPEN" then return .TerminalResult~failure("TERMINAL_BROKER_NOT_OPEN", state)
  principal = principalArg~string~strip
  if principal == "" then return .TerminalResult~failure("BROKER_CLIENT_IDENTITY_REQUIRED", "client principal must not be empty")
  if principalIndex~at(principal) \== .nil then return .TerminalResult~failure("BROKER_CLIENT_ALREADY_ATTACHED", principal)
  if clientCount >= maxClients then return .TerminalResult~failure("BROKER_CLIENT_CAPACITY_EXHAUSTED", maxClients)

  ownerAttach = owner~attachObserver(principal)
  if \ownerAttach~ok then return ownerAttach
  ownerObserver = ownerAttach~value
  if ownerObserver == .nil then return .TerminalResult~failure("BROKER_OWNER_ATTACHMENT_INVALID", "owner returned nil observer capability")

  clientSequence += 1
  clientId = "CLI-" || brokerId || "-" || right(clientSequence, 8, "0")
  facade = .TerminalBrokerClient~new(self, clientId, principal, sessionId, brokerId, alchemySealer, alchemyCapabilityAuthority)
  entry = .directory~new
  entry["FACADE"] = facade
  entry["OWNER_OBSERVER"] = ownerObserver
  clients~put(entry, clientId)
  principalIndex~put(clientId, principal)
  clientCount += 1
  self~alchemyTouch("ATTACH_CLIENT")
  observed = ownerObserver~snapshot
  if observed~ok then do
    if observed~value \== .nil then ignore = self~terminalObservationEvent(observed~value~generation, "BROKER_ATTACH:" || principal)
  end
  return .TerminalResult~success(facade)

::method detachClient
  expose owner clients principalIndex clientCount activeControllerClientId
  use arg clientArg, reasonArg = "DETACHED"
  checked = self~requireClient(clientArg)
  if \checked~ok then return checked
  entry = checked~value
  facade = entry["FACADE"]
  ownerObserver = entry["OWNER_OBSERVER"]
  clientId = facade~clientId
  principal = facade~principal

  detached = owner~detachObserver(ownerObserver, reasonArg)
  if \detached~ok then return detached
  if activeControllerClientId == clientId then self~clearController("CLIENT_DETACHED")

  clients~remove(clientId)
  existing = principalIndex~at(principal)
  if existing \== .nil then do
    if existing == clientId then principalIndex~remove(principal)
  end
  clientCount -= 1
  if clientCount < 0 then clientCount = 0
  facade~brokerInvalidate(reasonArg)
  self~alchemyTouch("DETACH_CLIENT")
  return .TerminalResult~success(.true)

::method attachKnownStateCatalog
  expose owner state
  use arg catalogArg, capacityArg = 64
  if state == "CLOSED" then return .TerminalResult~failure("TERMINAL_BROKER_CLOSED", "closed broker cannot attach semantic state")
  attached = owner~attachKnownStateCatalog(catalogArg, capacityArg)
  state = owner~state~string
  if attached~ok then self~alchemyTouch("ATTACH_KNOWN_STATE")
  return attached

::method enableControlGate
  expose owner state sessionId
  use arg authorityArg, scopeArg = ""
  if state \== "OPEN" then return .TerminalResult~failure("TERMINAL_BROKER_NOT_OPEN", state)
  enabled = owner~enableControlGate(authorityArg, scopeArg)
  if enabled~ok then do
    self~alchemyTouch("ENABLE_CONTROL_GATE")
    ignore = self~terminalAuthorityEvent("BROKER_ENABLE_GATE", sessionId, scopeArg~string)
  end
  return enabled

::method pumpOnce
  expose owner state
  use arg timeoutSeconds = 1, maximumBytes = 16384
  if state \== "OPEN" then return .TerminalResult~failure("TERMINAL_BROKER_NOT_OPEN", state)
  previousState = state
  pumped = owner~pumpOnce(timeoutSeconds, maximumBytes)
  state = owner~state~string
  ignore = self~reconcileControl
  if state \== previousState then do
    self~alchemyTouch("OWNER_STATE")
    ignore = self~terminalLifecycleEvent(state, "BROKER_SERVICE_PUMP")
  end
  return pumped

::method close
  expose owner state
  if state == "CLOSED" then return .TerminalResult~success(.true)
  self~invalidateAllClients("TERMINAL_BROKER_CLOSED")
  self~clearController("TERMINAL_BROKER_CLOSED")
  closed = owner~close
  state = owner~state~string
  if \closed~ok then do
    ignore = self~terminalLifecycleEvent(state, closed~code || ":" || closed~detail)
    return closed
  end
  self~alchemyTouch("CLOSE")
  ignore = self~terminalLifecycleEvent(state, "BROKER_ONE_SESSION_CLOSED")
  ignore = self~alchemyRetire
  return .TerminalResult~success(.true)

/* Read-only client bridge. */
::method clientSnapshot
  use arg clientArg
  checked = self~requireClient(clientArg)
  if \checked~ok then return checked
  return checked~value["OWNER_OBSERVER"]~snapshot

::method clientCurrent
  use arg clientArg
  checked = self~requireClient(clientArg)
  if \checked~ok then return checked
  return checked~value["OWNER_OBSERVER"]~current

::method clientBack
  use arg clientArg, countArg = 1
  checked = self~requireClient(clientArg)
  if \checked~ok then return checked
  return checked~value["OWNER_OBSERVER"]~back(countArg)

::method clientHistory
  use arg clientArg
  checked = self~requireClient(clientArg)
  if \checked~ok then return checked
  return checked~value["OWNER_OBSERVER"]~history

::method clientKnownStateStatus
  use arg clientArg
  checked = self~requireClient(clientArg)
  if \checked~ok then return checked
  return checked~value["OWNER_OBSERVER"]~knownStateStatus

::method clientKnownStateId
  use arg clientArg
  checked = self~requireClient(clientArg)
  if \checked~ok then return checked
  return checked~value["OWNER_OBSERVER"]~knownStateId

::method clientKnownStateGeneration
  use arg clientArg
  checked = self~requireClient(clientArg)
  if \checked~ok then return checked
  return checked~value["OWNER_OBSERVER"]~knownStateGeneration

::method clientKnownStateHistory
  use arg clientArg
  checked = self~requireClient(clientArg)
  if \checked~ok then return checked
  return checked~value["OWNER_OBSERVER"]~knownStateHistory

::method clientRequestControl
  expose owner activeControllerFacade activeOwnerController activeControllerPrincipal activeControllerClientId activeControlLeaseId alchemySealer alchemyCapabilityAuthority
  use arg clientArg, reservationArg, capabilitiesArg = .nil
  checked = self~requireClient(clientArg)
  if \checked~ok then return checked
  reconciled = self~reconcileControl
  if \reconciled~ok then do
    if reconciled~code == "BROKER_CONTROL_LEASE_INVALIDATED" then nop
    else return reconciled
  end
  if activeControllerFacade \== .nil then return .TerminalResult~failure("CONTROL_BUSY", activeControllerPrincipal || " holds " || activeControlLeaseId)
  if owner~controlActive then return .TerminalResult~failure("BROKER_CONTROL_OWNERSHIP_DESYNC", "owner has control not issued by broker")

  entry = checked~value
  facade = entry["FACADE"]
  ownerObserver = entry["OWNER_OBSERVER"]
  acquired = ownerObserver~requestControl(reservationArg, capabilitiesArg)
  if \acquired~ok then return acquired
  ownerController = acquired~value
  if ownerController == .nil then do
    if owner~controlActive then ignore = owner~revokeControl("BROKER_INVALID_CONTROL_RESULT")
    return .TerminalResult~failure("BROKER_CONTROL_CAPABILITY_INVALID", "owner returned nil controller")
  end

  activeOwnerController = ownerController
  activeControllerPrincipal = ownerController~principal~string
  activeControllerClientId = facade~clientId
  activeControlLeaseId = ownerController~leaseId~string
  activeControllerFacade = .TerminalBrokerController~new(self, facade~clientId, activeControllerPrincipal, facade~sessionId, facade~brokerId, ownerController~leaseId, ownerController~scope, ownerController~acquiredGeneration, alchemySealer, alchemyCapabilityAuthority)
  self~alchemyTouch("ACQUIRE_CONTROL")
  ignore = self~terminalAuthorityEvent("BROKER_ACQUIRE", activeControllerPrincipal, activeControlLeaseId)
  return .TerminalResult~success(activeControllerFacade)

::method controllerHandoff
  expose owner activeOwnerController activeControllerFacade activeControllerPrincipal activeControllerClientId activeControlLeaseId alchemySealer alchemyCapabilityAuthority
  use arg controllerArg, targetClientArg, reservationArg, capabilitiesArg = .nil
  current = self~requireController(controllerArg)
  if \current~ok then return current
  target = self~requireClient(targetClientArg)
  if \target~ok then return target

  targetEntry = target~value
  targetFacade = targetEntry["FACADE"]
  targetObserver = targetEntry["OWNER_OBSERVER"]
  handed = activeOwnerController~handoffTo(targetObserver, reservationArg, capabilitiesArg)
  if \handed~ok then do
    if \owner~controlActive then self~clearController("HANDOFF_RELEASED_NO_REPLACEMENT")
    return handed
  end
  newOwnerController = handed~value
  if newOwnerController == .nil then do
    self~clearController("HANDOFF_INVALID_RESULT")
    return .TerminalResult~failure("BROKER_CONTROL_CAPABILITY_INVALID", "owner handoff returned nil controller")
  end

  old = activeControllerFacade
  if old \== .nil then old~brokerInvalidate("HANDOFF")
  activeOwnerController = newOwnerController
  activeControllerPrincipal = newOwnerController~principal~string
  activeControllerClientId = targetFacade~clientId
  activeControlLeaseId = newOwnerController~leaseId~string
  activeControllerFacade = .TerminalBrokerController~new(self, targetFacade~clientId, activeControllerPrincipal, targetFacade~sessionId, targetFacade~brokerId, newOwnerController~leaseId, newOwnerController~scope, newOwnerController~acquiredGeneration, alchemySealer, alchemyCapabilityAuthority)
  self~alchemyTouch("HANDOFF_CONTROL")
  ignore = self~terminalAuthorityEvent("BROKER_HANDOFF", activeControllerPrincipal, activeControlLeaseId)
  return .TerminalResult~success(activeControllerFacade)

::method controllerRelease
  expose activeOwnerController activeControllerPrincipal activeControlLeaseId
  use arg controllerArg, reasonArg = "RELEASED"
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  principal = activeControllerPrincipal
  leaseId = activeControlLeaseId
  released = activeOwnerController~release(reasonArg)
  if \released~ok then return released
  self~clearController(reasonArg)
  self~alchemyTouch("RELEASE_CONTROL")
  ignore = self~terminalAuthorityEvent("BROKER_RELEASE", principal, leaseId || ":" || reasonArg~string)
  return released

::method controllerSnapshot
  expose activeOwnerController
  use arg controllerArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return activeOwnerController~snapshot

::method controllerCapabilityNames
  expose activeOwnerController
  use arg controllerArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return activeOwnerController~capabilityNames

::method controllerMeterFacts
  expose activeOwnerController
  use arg controllerArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return activeOwnerController~meterFacts

::method controllerSetField
  expose activeOwnerController
  use arg controllerArg, generationArg, fieldIdArg, valueArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return activeOwnerController~setField(generationArg, fieldIdArg, valueArg)

::method controllerTypeAtCursor
  expose activeOwnerController
  use arg controllerArg, generationArg, textArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return activeOwnerController~typeAtCursor(generationArg, textArg)

::method controllerMoveCursor
  expose activeOwnerController
  use arg controllerArg, generationArg, rowArg, columnArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return activeOwnerController~moveCursor(generationArg, rowArg, columnArg)

::method controllerFocusField
  expose activeOwnerController
  use arg controllerArg, generationArg, fieldIdArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return activeOwnerController~focusField(generationArg, fieldIdArg)

::method controllerNextInputField
  expose activeOwnerController
  use arg controllerArg, generationArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return activeOwnerController~nextInputField(generationArg)

::method controllerPreviousInputField
  expose activeOwnerController
  use arg controllerArg, generationArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return activeOwnerController~previousInputField(generationArg)

::method controllerHome
  expose activeOwnerController
  use arg controllerArg, generationArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return activeOwnerController~home(generationArg)

::method controllerErrorReset
  expose activeOwnerController
  use arg controllerArg, generationArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return activeOwnerController~errorReset(generationArg)

::method controllerPress
  expose activeOwnerController
  use arg controllerArg, generationArg, aidNameArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  /* owner-side controller already keeps secret-capable wire flushing inside
   * TerminalSessionOwner; broker never sees or returns raw response bytes. */
  return activeOwnerController~press(generationArg, aidNameArg)

::method controllerSystemRequest
  expose activeOwnerController
  use arg controllerArg, generationArg
  checked = self~requireController(controllerArg)
  if \checked~ok then return checked
  return activeOwnerController~systemRequest(generationArg)

::method requireClient private
  expose clients
  use arg clientArg
  if clientArg == .nil then return .TerminalResult~failure("BROKER_CLIENT_REQUIRED", "issued broker client required")
  if \clientArg~hasMethod("CLIENTID") then return .TerminalResult~failure("BROKER_CLIENT_INVALID", "client id missing")
  clientId = clientArg~clientId~string
  entry = clients~at(clientId)
  if entry == .nil then return .TerminalResult~failure("BROKER_CLIENT_INACTIVE", clientId)
  facade = entry["FACADE"]
  if facade \== clientArg then return .TerminalResult~failure("BROKER_CLIENT_INVALID", "client object is not the issued capability")
  if \clientArg~active then return .TerminalResult~failure("BROKER_CLIENT_INACTIVE", clientId)
  return .TerminalResult~success(entry)

::method requireController private
  expose activeControllerFacade
  use arg controllerArg
  if controllerArg == .nil then return .TerminalResult~failure("BROKER_CONTROL_CAPABILITY_REQUIRED", "issued broker controller required")
  reconciled = self~reconcileControl
  if \reconciled~ok then return reconciled
  if activeControllerFacade == .nil then return .TerminalResult~failure("CONTROL_NOT_HELD", "no broker-issued controller")
  if controllerArg \== activeControllerFacade then return .TerminalResult~failure("BROKER_CONTROL_CAPABILITY_INVALID", "controller object is not the active issued capability")
  if \controllerArg~active then return .TerminalResult~failure("BROKER_CONTROL_CAPABILITY_INVALID", "controller capability is inactive")
  return .TerminalResult~success(controllerArg)

::method reconcileControl private
  expose owner activeControllerFacade activeControllerPrincipal activeControlLeaseId
  if activeControllerFacade == .nil then do
    if owner~controlActive then return .TerminalResult~failure("BROKER_CONTROL_OWNERSHIP_DESYNC", "owner has active controller not issued by broker")
    return .TerminalResult~success(.true)
  end
  if \owner~controlActive then do
    self~clearController("UNDERLYING_CONTROL_ENDED")
    return .TerminalResult~failure("BROKER_CONTROL_LEASE_INVALIDATED", "underlying owner control lease is no longer active")
  end
  ownerPrincipal = owner~activeControllerIdentity~string
  ownerLease = owner~activeControlLeaseId~string
  if ownerPrincipal \== activeControllerPrincipal | ownerLease \== activeControlLeaseId then do
    ignore = owner~revokeControl("BROKER_CONTROL_DESYNC")
    self~clearController("BROKER_CONTROL_DESYNC")
    return .TerminalResult~failure("BROKER_CONTROL_OWNERSHIP_DESYNC", "underlying owner controller changed outside broker")
  end
  return .TerminalResult~success(.true)

::method clearController private
  expose activeControllerFacade activeOwnerController activeControllerPrincipal activeControllerClientId activeControlLeaseId
  use arg reasonArg = "CONTROL_CLEARED"
  if activeControllerFacade \== .nil then activeControllerFacade~brokerInvalidate(reasonArg)
  activeControllerFacade = .nil
  activeOwnerController = .nil
  activeControllerPrincipal = ""
  activeControllerClientId = ""
  activeControlLeaseId = ""
  return .true

::method invalidateAllClients private
  expose owner clients principalIndex clientCount
  use arg reasonArg = "TERMINAL_BROKER_CLOSED"
  ids = .array~new
  do key over clients
    ids~append(key)
  end
  do clientId over ids
    entry = clients~at(clientId)
    if entry == .nil then iterate
    observer = entry["OWNER_OBSERVER"]
    facade = entry["FACADE"]
    if observer \== .nil then ignore = owner~detachObserver(observer, reasonArg)
    if facade \== .nil then facade~brokerInvalidate(reasonArg)
    clients~remove(clientId)
  end
  principalIndex = .table~new
  clientCount = 0
  return .true


::class TerminalBrokerClient subclass TerminalAlchemyObject public
::attribute clientId get
::attribute principal get
::attribute sessionId get
::attribute brokerId get
::attribute active get
::attribute attachedAt get
::attribute detachedAt get
::attribute detachReason get

::method init
  expose broker clientId principal sessionId brokerId active attachedAt detachedAt detachReason
  use arg brokerArg, clientIdArg, principalArg, sessionIdArg, brokerIdArg, alchemySealerArg = .nil, alchemyCapabilityAuthorityArg = .nil
  broker = brokerArg
  clientId = clientIdArg~string
  principal = principalArg~string
  sessionId = sessionIdArg~string
  brokerId = brokerIdArg~string
  active = .true
  attachedAt = .DateTime~new~utcIsoDate
  detachedAt = ""
  detachReason = ""
  meta = .directory~new
  meta["broker_id"] = brokerId
  meta["session_id"] = sessionId
  meta["client_id"] = clientId
  meta["principal"] = principal
  self~initTerminalAlchemy("Read-only broker client for one persistent terminal session", meta, alchemySealerArg, alchemyCapabilityAuthorityArg)
  self~registerStateVariable("clientId", "CUSTOMER", "opaque broker client id")
  self~registerStateVariable("principal", "CUSTOMER", "broker client principal")
  self~registerStateVariable("sessionId", "CUSTOMER", "shared terminal session identity")
  self~registerStateVariable("brokerId", "CUSTOMER", "terminal broker identity")
  self~registerStateVariable("active", "CUSTOMER", "whether this broker client remains attached")
  self~registerStateVariable("attachedAt", "CUSTOMER", "client attachment timestamp")
  self~registerStateVariable("detachedAt", "CUSTOMER", "client detach timestamp")
  self~registerStateVariable("detachReason", "CUSTOMER", "bounded client detach reason")
  /* Exact broker back-reference is deliberately unregistered. */
  self~registerMethodContract("SNAPSHOT", "read current detached terminal evidence", .array~new, "TERMINALRESULT", .false, "FALSE", "CUSTOMER", "NORMAL", "READ", "USE")
  self~registerMethodContract("REQUESTCONTROL", "request exclusive keyboard authority through service broker", .array~of("RESERVATION", "CAPABILITIES"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("DETACH", "detach this broker client", .array~of("REASON"), "TERMINALRESULT", .false, "FALSE", "CUSTOMER", "NORMAL", "MUTATE", "USE")

::method snapshot
  expose broker
  return broker~clientSnapshot(self)
::method current
  expose broker
  return broker~clientCurrent(self)
::method back
  expose broker
  use arg countArg = 1
  return broker~clientBack(self, countArg)
::method history
  expose broker
  return broker~clientHistory(self)
::method knownStateStatus
  expose broker
  return broker~clientKnownStateStatus(self)
::method knownStateId
  expose broker
  return broker~clientKnownStateId(self)
::method knownStateGeneration
  expose broker
  return broker~clientKnownStateGeneration(self)
::method knownStateHistory
  expose broker
  return broker~clientKnownStateHistory(self)
::method requestControl
  expose broker
  use arg reservationArg, capabilitiesArg = .nil
  return broker~clientRequestControl(self, reservationArg, capabilitiesArg)
::method detach
  expose broker
  use arg reasonArg = "DETACHED"
  return broker~detachClient(self, reasonArg)
::method brokerInvalidate
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


::class TerminalBrokerController subclass TerminalAlchemyObject public
::attribute clientId get
::attribute principal get
::attribute sessionId get
::attribute brokerId get
::attribute leaseId get
::attribute scope get
::attribute acquiredGeneration get
::attribute active get
::attribute acquiredAt get
::attribute releasedAt get
::attribute releaseReason get

::method init
  expose broker clientId principal sessionId brokerId leaseId scope acquiredGeneration active acquiredAt releasedAt releaseReason
  use arg brokerArg, clientIdArg, principalArg, sessionIdArg, brokerIdArg, leaseIdArg, scopeArg, generationArg, alchemySealerArg = .nil, alchemyCapabilityAuthorityArg = .nil
  broker = brokerArg
  clientId = clientIdArg~string
  principal = principalArg~string
  sessionId = sessionIdArg~string
  brokerId = brokerIdArg~string
  leaseId = leaseIdArg~string
  scope = scopeArg~string
  acquiredGeneration = generationArg
  active = .true
  acquiredAt = .DateTime~new~utcIsoDate
  releasedAt = ""
  releaseReason = ""
  meta = .directory~new
  meta["broker_id"] = brokerId
  meta["session_id"] = sessionId
  meta["client_id"] = clientId
  meta["principal"] = principal
  meta["lease_id"] = leaseId
  self~initTerminalAlchemy("Exclusive broker-side terminal keyboard capability", meta, alchemySealerArg, alchemyCapabilityAuthorityArg)
  self~registerStateVariable("clientId", "CUSTOMER", "broker client holding control")
  self~registerStateVariable("principal", "CUSTOMER", "controller principal")
  self~registerStateVariable("sessionId", "CUSTOMER", "shared terminal session identity")
  self~registerStateVariable("brokerId", "CUSTOMER", "terminal broker identity")
  self~registerStateVariable("leaseId", "CUSTOMER", "opaque underlying control lease id")
  self~registerStateVariable("scope", "CUSTOMER", "external admission scope")
  self~registerStateVariable("acquiredGeneration", "CUSTOMER", "terminal generation at control acquisition")
  self~registerStateVariable("active", "CUSTOMER", "whether this broker controller remains active")
  self~registerStateVariable("acquiredAt", "CUSTOMER", "control acquisition timestamp")
  self~registerStateVariable("releasedAt", "CUSTOMER", "control release/revocation timestamp")
  self~registerStateVariable("releaseReason", "CUSTOMER", "bounded release/revocation reason")
  /* Exact broker and owner-side controller references are deliberately absent. */
  self~registerMethodContract("SETFIELD", "write one structured field under current generation authority", .array~of("GENERATION", "FIELD_ID", "VALUE"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "USE")
  self~registerMethodContract("PRESS", "send one AID under current generation authority without exposing wire bytes", .array~of("GENERATION", "AID"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "USE")
  self~registerMethodContract("RELEASE", "release this broker-side keyboard capability", .array~of("REASON"), "TERMINALRESULT", .false, "FALSE", "CUSTOMER", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("HANDOFFTO", "release this controller then request control for another broker client", .array~of("CLIENT", "RESERVATION", "CAPABILITIES"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")

::method snapshot
  expose broker
  return broker~controllerSnapshot(self)
::method capabilityNames
  expose broker
  return broker~controllerCapabilityNames(self)
::method meterFacts
  expose broker
  return broker~controllerMeterFacts(self)
::method release
  expose broker
  use arg reasonArg = "RELEASED"
  return broker~controllerRelease(self, reasonArg)
::method handoffTo
  expose broker
  use arg targetClientArg, reservationArg, capabilitiesArg = .nil
  return broker~controllerHandoff(self, targetClientArg, reservationArg, capabilitiesArg)
::method setField
  expose broker
  use arg generationArg, fieldIdArg, valueArg
  return broker~controllerSetField(self, generationArg, fieldIdArg, valueArg)
::method typeAtCursor
  expose broker
  use arg generationArg, textArg
  return broker~controllerTypeAtCursor(self, generationArg, textArg)
::method moveCursor
  expose broker
  use arg generationArg, rowArg, columnArg
  return broker~controllerMoveCursor(self, generationArg, rowArg, columnArg)
::method focusField
  expose broker
  use arg generationArg, fieldIdArg
  return broker~controllerFocusField(self, generationArg, fieldIdArg)
::method nextInputField
  expose broker
  use arg generationArg
  return broker~controllerNextInputField(self, generationArg)
::method previousInputField
  expose broker
  use arg generationArg
  return broker~controllerPreviousInputField(self, generationArg)
::method home
  expose broker
  use arg generationArg
  return broker~controllerHome(self, generationArg)
::method errorReset
  expose broker
  use arg generationArg
  return broker~controllerErrorReset(self, generationArg)
::method press
  expose broker
  use arg generationArg, aidNameArg
  return broker~controllerPress(self, generationArg, aidNameArg)
::method systemRequest
  expose broker
  use arg generationArg
  return broker~controllerSystemRequest(self, generationArg)
::method brokerInvalidate
  expose active releasedAt releaseReason
  use arg reasonArg = "INVALIDATED"
  if \active then return .false
  active = .false
  releasedAt = .DateTime~new~utcIsoDate
  releaseReason = reasonArg~string
  self~alchemyTouch("CONTROL_END")
  ignore = self~terminalAuthorityEvent("BROKER_CONTROL_END", "", releaseReason)
  ignore = self~alchemyRetire
  return .true

::requires "TerminalOwnership.cls"
