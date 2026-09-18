/*
 * TerminalBrokerService.cls - persistent multi-client service lifecycle v0.18.
 *
 * This layer coordinates the already separated concerns without merging them:
 *   TerminalBrokerLocalSocketHost   local authenticated transport
 *   TerminalBrokerProtocolEndpoint remote serialized authority boundary
 *   TerminalSessionBroker          one-session/many-readers/one-writer core
 *
 * Drain order is deliberate:
 *   1. stop admitting new socket connections;
 *   2. let already authenticated bounded connections finish;
 *   3. quiesce/revoke remote protocol capabilities;
 *   4. only then may a trusted local caller request IBM i orderly signoff.
 *
 * Generic transport drain never closes the terminal.  Generic endpoint quiesce
 * never closes the terminal.  IBM i signoff still requires exact known-state
 * confirmation, external admission/WLU proof, option 90 and one explicit ENTER.
 */

::class TerminalBrokerServiceBuild public
::constant RELEASE "0.18"
::constant API_VERSION "terminal.broker.service/0.2"


::class TerminalBrokerServiceStatus public
::attribute state get
::attribute port get
::attribute activeConnections get
::attribute peakConnections get
::attribute protocolState get
::attribute brokerState get
::attribute drainReason get
::attribute lastError get
::attribute socketLastError get
/* v0.18 detached operational evidence. */
::attribute socketServiceState get
::attribute listenerState get
::attribute socketGeneration get
::attribute workerLimit get
::attribute acceptorActive get
::attribute completedConnections get
::attribute totalConnections get
::attribute authenticatedConnections get
::attribute rejectedConnections get
::attribute requestCount get
::attribute brokerClientCount get
::attribute brokerMaxClients get
::attribute brokerControlActive get
::attribute brokerControllerPrincipal get

::method init
  expose state port activeConnections peakConnections protocolState brokerState drainReason lastError socketLastError socketServiceState listenerState socketGeneration workerLimit acceptorActive completedConnections totalConnections authenticatedConnections rejectedConnections requestCount brokerClientCount brokerMaxClients brokerControlActive brokerControllerPrincipal
  use strict arg stateArg, portArg, activeArg, peakArg, protocolStateArg, brokerStateArg, drainReasonArg, lastErrorArg, socketServiceStateArg = "", socketGenerationArg = 0, workerLimitArg = 0, acceptorActiveArg = .false, completedArg = 0, totalArg = 0, authenticatedArg = 0, rejectedArg = 0, requestArg = 0, brokerClientCountArg = 0, brokerMaxClientsArg = 0, brokerControlActiveArg = .false, brokerControllerPrincipalArg = "", socketLastErrorArg = "", listenerStateArg = "UNKNOWN"
  state = stateArg~string
  port = portArg
  activeConnections = activeArg
  peakConnections = peakArg
  protocolState = protocolStateArg~string
  brokerState = brokerStateArg~string
  drainReason = drainReasonArg~string
  lastError = lastErrorArg~string
  socketLastError = socketLastErrorArg~string
  socketServiceState = socketServiceStateArg~string
  listenerState = listenerStateArg~string
  socketGeneration = socketGenerationArg
  workerLimit = workerLimitArg
  acceptorActive = acceptorActiveArg == .true
  completedConnections = completedArg
  totalConnections = totalArg
  authenticatedConnections = authenticatedArg
  rejectedConnections = rejectedArg
  requestCount = requestArg
  brokerClientCount = brokerClientCountArg
  brokerMaxClients = brokerMaxClientsArg
  brokerControlActive = brokerControlActiveArg == .true
  brokerControllerPrincipal = brokerControllerPrincipalArg~string


::class TerminalBrokerServiceLifecycle subclass TerminalAlchemyObject public
::attribute state get
::attribute drainReason get
::attribute lastError get

::method init
  expose socketHost endpoint broker state drainReason lastError alchemySealer alchemyCapabilityAuthority
  use strict arg socketHostArg, endpointArg, brokerArg, alchemySealerArg = .nil, alchemyCapabilityAuthorityArg = .nil
  if socketHostArg == .nil then raise syntax 88.900 array("TerminalBrokerServiceLifecycle requires a socket host")
  if endpointArg == .nil then raise syntax 88.900 array("TerminalBrokerServiceLifecycle requires a protocol endpoint")
  if brokerArg == .nil then raise syntax 88.900 array("TerminalBrokerServiceLifecycle requires a broker")
  requiredHost = .array~of("LAUNCHSERVICE", "REQUESTDRAIN", "AWAITDRAIN", "SERVICESTATUS")
  do methodName over requiredHost
    if \socketHostArg~hasMethod(methodName) then raise syntax 88.900 array("Terminal broker service socket host missing " || methodName)
  end
  if \endpointArg~hasMethod("QUIESCE") then raise syntax 88.900 array("Terminal broker service endpoint must implement quiesce(reason)")
  requiredBroker = .array~of("STATUS", "ATTACHEDCLIENTCOUNT", "CONTROLACTIVE", "ATTACHCLIENT", "PUMPONCE", "CLOSE")
  do methodName over requiredBroker
    if \brokerArg~hasMethod(methodName) then raise syntax 88.900 array("Terminal broker service broker missing " || methodName)
  end

  socketHost = socketHostArg
  endpoint = endpointArg
  broker = brokerArg
  state = "STOPPED"
  drainReason = ""
  lastError = ""
  alchemySealer = alchemySealerArg
  alchemyCapabilityAuthority = alchemyCapabilityAuthorityArg

  meta = .directory~new
  meta["service_api"] = .TerminalBrokerServiceBuild~API_VERSION
  meta["shutdown_order"] = "DRAIN_SOCKET_THEN_QUIESCE_PROTOCOL_THEN_OPTIONAL_HOST_SIGNOFF"
  self~initTerminalAlchemy("Persistent terminal broker service lifecycle coordinator", meta, alchemySealer, alchemyCapabilityAuthority)
  self~registerStateVariable("state", "CUSTOMER", "service lifecycle state")
  self~registerStateVariable("drainReason", "INTERNAL", "graceful drain reason")
  self~registerStateVariable("lastError", "INTERNAL", "latest lifecycle failure")
  /* socketHost/endpoint/broker are capability-bearing live objects and are never registered. */
  self~registerMethodContract("LAUNCH", "launch persistent authenticated multi-client service", .array~of("MAX_CONNECTIONS", "BACKLOG"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "EXTERNAL", "USE")
  self~registerMethodContract("DRAIN", "gracefully drain connections then quiesce all remote protocol capabilities", .array~of("TIMEOUT_MS", "REASON"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("ORDERLYIBMISIGNOFF", "after quiesce, perform exact-known-state IBM i option-90 signoff using external admission", .array~of("CATALOG", "RESERVATION", "PRINCIPAL", "MAX_PUMPS", "PUMP_TIMEOUT_SECONDS"), "TERMINALRESULT", .true, "FALSE", "INTERNAL", "SECURITY_BOUNDARY", "EXTERNAL", "USE")
  self~registerMethodContract("STATUS", "return detached scalar service lifecycle evidence", .array~new, "TERMINALBROKERSERVICESTATUS", .false, "FALSE", "CUSTOMER", "NORMAL", "READ", "USE")

::method launch public
  expose socketHost state drainReason lastError
  use strict arg maxConnectionsArg = 16, backlogArg = 64
  if state == "RUNNING" then return .TerminalResult~success(self~status)
  if state == "DRAINING" then return .TerminalResult~failure("TERMINAL_SERVICE_DRAINING", drainReason)
  if state == "QUIESCED" | state == "CLOSED" then return .TerminalResult~failure("TERMINAL_SERVICE_NOT_RESTARTABLE", state)
  launched = socketHost~launchService(maxConnectionsArg, backlogArg)
  if \launched~ok then do
    lastError = launched~code || ":" || launched~detail
    state = "ERROR"
    return launched
  end
  state = "RUNNING"
  drainReason = ""
  lastError = ""
  self~alchemyTouch("SERVICE_LAUNCH")
  ignore = self~terminalLifecycleEvent("SERVICE_RUNNING", "port=" || launched~value)
  return .TerminalResult~success(self~status)

::method drain public unguarded
  expose socketHost endpoint state drainReason lastError
  use strict arg timeoutMillisecondsArg = 30000, reasonArg = "SERVICE_SHUTDOWN"
  current = self~status
  if current~state == "QUIESCED" then return .TerminalResult~success(current)
  if current~state \== "RUNNING" & current~state \== "DRAINING" then return .TerminalResult~failure("TERMINAL_SERVICE_NOT_RUNNING", current~state)

  self~markDraining(reasonArg)
  requested = socketHost~requestDrain(reasonArg)
  if \requested~ok then do
    self~markError(requested~code || ":" || requested~detail)
    return requested
  end
  drained = socketHost~awaitDrain(timeoutMillisecondsArg)
  if \drained~ok then do
    self~markError(drained~code || ":" || drained~detail)
    return drained
  end
  quiesced = endpoint~quiesce(reasonArg)
  if \quiesced~ok then do
    self~markError(quiesced~code || ":" || quiesced~detail)
    return quiesced
  end
  self~markQuiesced
  return .TerminalResult~success(self~status)

::method orderlyIBMISignoff public protected unguarded
  expose broker state lastError
  use strict arg catalogArg, reservationArg, principalArg = "TERMINAL_SERVICE_SIGNOFF", maxPumpsArg = 10, pumpTimeoutSecondsArg = 1
  current = self~status
  if current~state \== "QUIESCED" then return .TerminalResult~failure("TERMINAL_SERVICE_SIGNOFF_REQUIRES_QUIESCE", current~state)
  signed = .TN5250BrokerSignoff~perform(broker, catalogArg, reservationArg, principalArg, maxPumpsArg, pumpTimeoutSecondsArg)
  if \signed~ok then do
    brokerState = broker~status~state
    if brokerState == "CLOSED" then self~markClosed(signed~code || ":" || signed~detail)
    else self~markSignoffFailure(signed~code || ":" || signed~detail)
    return signed
  end
  self~markClosed("")
  return signed

::method status public
  expose socketHost endpoint broker state drainReason lastError
  use strict arg
  socketStatus = socketHost~serviceStatus
  protocolState = "UNKNOWN"
  if endpoint~hasMethod("ENDPOINTSTATE") then protocolState = endpoint~endpointState
  brokerStatus = broker~status

  /* v0.18 deliberately copies only detached scalar operational evidence.
   * The socket host, endpoint, broker and their live authority remain private. */
  socketServiceState = "UNKNOWN"
  listenerState = "UNKNOWN"
  if socketHost~hasMethod("STATE") then listenerState = socketHost~state
  socketGeneration = 0
  workerLimit = 0
  acceptorActive = .false
  completedConnections = 0
  totalConnections = 0
  authenticatedConnections = 0
  rejectedConnections = 0
  requestCount = 0
  socketLastError = ""
  if socketStatus~hasMethod("STATE") then socketServiceState = socketStatus~state
  if socketStatus~hasMethod("GENERATION") then socketGeneration = socketStatus~generation
  if socketStatus~hasMethod("WORKERLIMIT") then workerLimit = socketStatus~workerLimit
  if socketStatus~hasMethod("ACCEPTORACTIVE") then acceptorActive = socketStatus~acceptorActive
  if socketStatus~hasMethod("COMPLETEDCONNECTIONS") then completedConnections = socketStatus~completedConnections
  if socketStatus~hasMethod("TOTALCONNECTIONS") then totalConnections = socketStatus~totalConnections
  if socketStatus~hasMethod("AUTHENTICATEDCONNECTIONS") then authenticatedConnections = socketStatus~authenticatedConnections
  if socketStatus~hasMethod("REJECTEDCONNECTIONS") then rejectedConnections = socketStatus~rejectedConnections
  if socketStatus~hasMethod("REQUESTCOUNT") then requestCount = socketStatus~requestCount
  if socketStatus~hasMethod("LASTERROR") then socketLastError = socketStatus~lastError

  brokerClientCount = 0
  brokerMaxClients = 0
  brokerControlActive = .false
  brokerControllerPrincipal = ""
  if brokerStatus~hasMethod("CLIENTCOUNT") then brokerClientCount = brokerStatus~clientCount
  if brokerStatus~hasMethod("MAXCLIENTS") then brokerMaxClients = brokerStatus~maxClients
  if brokerStatus~hasMethod("CONTROLACTIVE") then brokerControlActive = brokerStatus~controlActive
  if brokerStatus~hasMethod("ACTIVECONTROLLERPRINCIPAL") then brokerControllerPrincipal = brokerStatus~activeControllerPrincipal

  return .TerminalBrokerServiceStatus~new(state, socketStatus~port, socketStatus~activeConnections, socketStatus~peakConnections, protocolState, brokerStatus~state, drainReason, lastError, socketServiceState, socketGeneration, workerLimit, acceptorActive, completedConnections, totalConnections, authenticatedConnections, rejectedConnections, requestCount, brokerClientCount, brokerMaxClients, brokerControlActive, brokerControllerPrincipal, socketLastError, listenerState)

::method markDraining private
  expose state drainReason lastError
  use strict arg reasonArg
  state = "DRAINING"
  drainReason = reasonArg~string
  lastError = ""
  self~alchemyTouch("SERVICE_DRAIN")
  ignore = self~terminalLifecycleEvent("SERVICE_DRAINING", drainReason)
  return .true

::method markQuiesced private
  expose state lastError
  state = "QUIESCED"
  lastError = ""
  self~alchemyTouch("SERVICE_QUIESCED")
  ignore = self~terminalLifecycleEvent("SERVICE_QUIESCED", "remote capabilities revoked; terminal retained")
  return .true

::method markClosed private
  expose state lastError
  use strict arg detailArg = ""
  state = "CLOSED"
  lastError = detailArg~string
  self~alchemyTouch("SERVICE_CLOSED")
  ignore = self~terminalLifecycleEvent("SERVICE_CLOSED", lastError)
  ignore = self~alchemyRetire
  return .true

::method markSignoffFailure private
  expose state lastError
  use strict arg detailArg
  state = "QUIESCED"
  lastError = detailArg~string
  self~alchemyTouch("SERVICE_SIGNOFF_REFUSED")
  return .true

::method markError private
  expose state lastError
  use strict arg detailArg
  state = "ERROR"
  lastError = detailArg~string
  self~alchemyTouch("SERVICE_ERROR")
  ignore = self~terminalLifecycleEvent("SERVICE_ERROR", lastError)
  return .true

::requires "TN5250Signoff.cls"
::requires "TerminalBrokerSocket.cls"
