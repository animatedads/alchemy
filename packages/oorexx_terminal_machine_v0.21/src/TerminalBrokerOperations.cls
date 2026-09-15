/*
 * TerminalBrokerOperations.cls - operational supervision for Terminal Machine v0.18.
 *
 * This layer is intentionally above the v0.17 service lifecycle.  It provides
 * detached health/readiness evidence and controlled start/drain/signoff calls
 * without acquiring TerminalSessionOwner, broker client/controller, socket,
 * protocol bearer, WLU reservation or wire authority.
 *
 * A HEALTHY service means all four service boundaries agree:
 *   lifecycle RUNNING
 *   socket service RUNNING with its acceptor active
 *   protocol endpoint OPEN
 *   retained terminal broker OPEN
 *
 * Anything less while the lifecycle claims RUNNING is DEGRADED and fail-closed
 * for requireReady().  Health observation never starts, closes, signs off or
 * mutates the terminal.
 */

::class TerminalBrokerOperationsBuild public
::constant RELEASE "0.18"
::constant API_VERSION "terminal.broker.operations/0.1"


::class TerminalBrokerOperationalHealth public
::attribute health get
::attribute ready get
::attribute accepting get
::attribute lifecycleState get
::attribute socketServiceState get
::attribute listenerState get
::attribute listenerPort get
::attribute serviceGeneration get
::attribute workerLimit get
::attribute acceptorActive get
::attribute activeConnections get
::attribute peakConnections get
::attribute completedConnections get
::attribute totalConnections get
::attribute authenticatedConnections get
::attribute rejectedConnections get
::attribute requestCount get
::attribute protocolState get
::attribute brokerState get
::attribute brokerClientCount get
::attribute brokerMaxClients get
::attribute brokerControlActive get
::attribute brokerControllerPrincipal get
::attribute drainReason get
::attribute lastError get
::attribute socketLastError get

::method init
  expose health ready accepting lifecycleState socketServiceState listenerState listenerPort serviceGeneration workerLimit acceptorActive activeConnections peakConnections completedConnections totalConnections authenticatedConnections rejectedConnections requestCount protocolState brokerState brokerClientCount brokerMaxClients brokerControlActive brokerControllerPrincipal drainReason lastError socketLastError
  use strict arg healthArg, readyArg, acceptingArg, lifecycleArg, socketStateArg, listenerStateArg, portArg, generationArg, workerLimitArg, acceptorArg, activeArg, peakArg, completedArg, totalArg, authenticatedArg, rejectedArg, requestArg, protocolArg, brokerArg, clientCountArg, maxClientsArg, controlArg, controllerPrincipalArg, drainReasonArg, lastErrorArg, socketLastErrorArg = ""
  health = healthArg~string
  ready = readyArg == .true
  accepting = acceptingArg == .true
  lifecycleState = lifecycleArg~string
  socketServiceState = socketStateArg~string
  listenerState = listenerStateArg~string
  listenerPort = portArg
  serviceGeneration = generationArg
  workerLimit = workerLimitArg
  acceptorActive = acceptorArg == .true
  activeConnections = activeArg
  peakConnections = peakArg
  completedConnections = completedArg
  totalConnections = totalArg
  authenticatedConnections = authenticatedArg
  rejectedConnections = rejectedArg
  requestCount = requestArg
  protocolState = protocolArg~string
  brokerState = brokerArg~string
  brokerClientCount = clientCountArg
  brokerMaxClients = maxClientsArg
  brokerControlActive = controlArg == .true
  brokerControllerPrincipal = controllerPrincipalArg~string
  drainReason = drainReasonArg~string
  lastError = lastErrorArg~string
  socketLastError = socketLastErrorArg~string

::method summary public
  expose health lifecycleState socketServiceState listenerState protocolState brokerState activeConnections lastError
  text = "health=" || health || ";lifecycle=" || lifecycleState || ";socket=" || socketServiceState || ";listener=" || listenerState || ";protocol=" || protocolState || ";broker=" || brokerState || ";active=" || activeConnections
  if lastError \== "" then text ||= ";error=" || lastError
  return text


::class TerminalBrokerServiceSupervisor subclass TerminalAlchemyObject public
::attribute state get
::attribute startCount get
::attribute shutdownCount get
::attribute lastError get
::attribute socketLastError get

::method init
  expose lifecycle state startCount shutdownCount lastError alchemySealer alchemyCapabilityAuthority
  use strict arg lifecycleArg, alchemySealerArg = .nil, alchemyCapabilityAuthorityArg = .nil
  if lifecycleArg == .nil then raise syntax 88.900 array("TerminalBrokerServiceSupervisor requires a service lifecycle")
  required = .array~of("LAUNCH", "DRAIN", "STATUS", "ORDERLYIBMISIGNOFF")
  do methodName over required
    if \lifecycleArg~hasMethod(methodName) then raise syntax 88.900 array("Terminal broker service lifecycle missing " || methodName)
  end

  lifecycle = lifecycleArg
  state = "STOPPED"
  startCount = 0
  shutdownCount = 0
  lastError = ""
  alchemySealer = alchemySealerArg
  alchemyCapabilityAuthority = alchemyCapabilityAuthorityArg

  meta = .directory~new
  meta["operations_api"] = .TerminalBrokerOperationsBuild~API_VERSION
  meta["health_rule"] = "LIFECYCLE_RUNNING_AND_SOCKET_RUNNING_AND_ACCEPTOR_ACTIVE_AND_PROTOCOL_OPEN_AND_BROKER_OPEN"
  self~initTerminalAlchemy("Operational supervisor for one persistent terminal broker service", meta, alchemySealer, alchemyCapabilityAuthority)
  self~registerStateVariable("state", "CUSTOMER", "supervisor-observed lifecycle state")
  self~registerStateVariable("startCount", "CUSTOMER", "successful controlled service starts")
  self~registerStateVariable("shutdownCount", "CUSTOMER", "successful controlled service drains")
  self~registerStateVariable("lastError", "INTERNAL", "latest bounded operational failure")
  /* lifecycle is a live capability-bearing coordinator and is never registered. */
  self~registerMethodContract("START", "start the persistent local service through its lifecycle coordinator", .array~of("MAX_CONNECTIONS", "BACKLOG"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "USE")
  self~registerMethodContract("HEALTH", "return detached scalar health and readiness evidence without mutation", .array~new, "TERMINALBROKEROPERATIONALHEALTH", .false, "FALSE", "CUSTOMER", "NORMAL", "READ", "USE")
  self~registerMethodContract("REQUIREREADY", "fail closed unless all persistent service boundaries are ready", .array~new, "TERMINALRESULT", .false, "FALSE", "CUSTOMER", "NORMAL", "READ", "USE")
  self~registerMethodContract("SHUTDOWN", "drain socket workers then quiesce remote protocol authority while retaining terminal ownership", .array~of("TIMEOUT_MS", "REASON"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("ORDERLYIBMISIGNOFF", "after quiesce, explicitly request exact-known-state IBM i option-90 signoff", .array~of("CATALOG", "RESERVATION", "PRINCIPAL", "MAX_PUMPS", "PUMP_TIMEOUT_SECONDS"), "TERMINALRESULT", .true, "FALSE", "INTERNAL", "SECURITY_BOUNDARY", "EXTERNAL", "USE")
  ignore = self~syncState

::method start public
  expose lifecycle state startCount lastError
  use strict arg maxConnectionsArg = 16, backlogArg = 64
  current = self~health
  if current~ready then return .TerminalResult~success(current)
  if current~lifecycleState \== "STOPPED" then return .TerminalResult~failure("TERMINAL_SUPERVISOR_START_REFUSED", current~summary)

  started = lifecycle~launch(maxConnectionsArg, backlogArg)
  ignore = self~syncState
  if \started~ok then do
    lastError = started~code || ":" || started~detail
    self~alchemyTouch("SUPERVISOR_START_FAILED")
    return started
  end
  startCount += 1
  lastError = ""
  self~alchemyTouch("SUPERVISOR_START")
  ignore = self~terminalLifecycleEvent("SUPERVISOR_RUNNING", "starts=" || startCount)
  ready = self~requireReady
  if \ready~ok then return ready
  return .TerminalResult~success(ready~value)

::method health public
  expose lifecycle state lastError
  use strict arg
  status = lifecycle~status
  state = status~state~string

  socketState = status~socketServiceState~string
  protocolState = status~protocolState~string
  brokerState = status~brokerState~string
  accepting = state == "RUNNING" & socketState == "RUNNING" & status~listenerState == "LISTENING" & status~acceptorActive & status~port > 0 & status~workerLimit > 0
  ready = accepting & protocolState == "OPEN" & brokerState == "OPEN" & status~lastError == ""

  healthCode = state
  select
    when state == "RUNNING" then do
      if ready then healthCode = "HEALTHY"
      else healthCode = "DEGRADED"
    end
    when state == "STOPPED" then healthCode = "STOPPED"
    when state == "DRAINING" then healthCode = "DRAINING"
    when state == "QUIESCED" then healthCode = "QUIESCED"
    when state == "CLOSED" then healthCode = "CLOSED"
    otherwise healthCode = "ERROR"
  end
  if status~workerLimit > 0 & status~activeConnections > status~workerLimit then do
    ready = .false
    healthCode = "DEGRADED"
  end

  effectiveError = status~lastError~string
  if effectiveError == "" then effectiveError = lastError
  return .TerminalBrokerOperationalHealth~new(healthCode, ready, accepting, state, socketState, status~listenerState, status~port, status~socketGeneration, status~workerLimit, status~acceptorActive, status~activeConnections, status~peakConnections, status~completedConnections, status~totalConnections, status~authenticatedConnections, status~rejectedConnections, status~requestCount, protocolState, brokerState, status~brokerClientCount, status~brokerMaxClients, status~brokerControlActive, status~brokerControllerPrincipal, status~drainReason, effectiveError, status~socketLastError)

::method requireReady public
  use strict arg
  current = self~health
  if current~ready then return .TerminalResult~success(current)
  return .TerminalResult~failure("TERMINAL_SERVICE_NOT_READY", current~summary)

::method shutdown public unguarded
  expose lifecycle shutdownCount lastError
  use strict arg timeoutMillisecondsArg = 30000, reasonArg = "CONTROLLED_SHUTDOWN"
  current = self~health
  if current~lifecycleState == "QUIESCED" | current~lifecycleState == "CLOSED" then return .TerminalResult~success(current)
  if current~lifecycleState \== "RUNNING" & current~lifecycleState \== "DRAINING" then return .TerminalResult~failure("TERMINAL_SUPERVISOR_SHUTDOWN_REFUSED", current~summary)

  stopped = lifecycle~drain(timeoutMillisecondsArg, reasonArg)
  ignore = self~syncState
  if \stopped~ok then do
    lastError = stopped~code || ":" || stopped~detail
    self~alchemyTouch("SUPERVISOR_SHUTDOWN_FAILED")
    return stopped
  end
  shutdownCount += 1
  lastError = ""
  self~alchemyTouch("SUPERVISOR_SHUTDOWN")
  ignore = self~terminalLifecycleEvent("SUPERVISOR_QUIESCED", "shutdowns=" || shutdownCount)
  return .TerminalResult~success(self~health)

::method orderlyIBMISignoff public protected unguarded
  expose lifecycle lastError
  use strict arg catalogArg, reservationArg, principalArg = "TERMINAL_SERVICE_SIGNOFF", maxPumpsArg = 10, pumpTimeoutSecondsArg = 1
  current = self~health
  if current~lifecycleState \== "QUIESCED" then return .TerminalResult~failure("TERMINAL_SUPERVISOR_SIGNOFF_REQUIRES_QUIESCE", current~lifecycleState)
  result = lifecycle~orderlyIBMISignoff(catalogArg, reservationArg, principalArg, maxPumpsArg, pumpTimeoutSecondsArg)
  ignore = self~syncState
  if \result~ok then do
    lastError = result~code || ":" || result~detail
    self~alchemyTouch("SUPERVISOR_SIGNOFF_REFUSED")
  end
  else do
    lastError = ""
    self~alchemyTouch("SUPERVISOR_SIGNOFF")
  end
  return result

::method syncState private
  expose lifecycle state
  status = lifecycle~status
  state = status~state~string
  return state

::requires "TerminalBrokerService.cls"
