/*
 * Queue Fabric v0.9-dev5 broker operational service.
 *
 * This layer intentionally sits above QueueChannelFabric.  It does not move
 * CLAIM/ACK/RELEASE semantics out of the accepted queue/channel layer.  A
 * broker admission policy is consulted before each one-message pump so an
 * optional WLU denial occurs before queue CLAIM or transport side effects.
 *
 * v0.9 also adds an optional authenticated heartbeat cycle.  Heartbeat
 * admission is a distinct policy message so liveness traffic can be metered
 * independently from message transfer without teaching the broker about WLU.
 */

::class QueueBrokerServiceBuild public
::constant VERSION "0.9-dev5"
::constant API "queue.broker.service/0.2"

::class QueueBrokerServiceState public
::constant NEW "NEW"
::constant PREPARED "PREPARED"
::constant RUNNING "RUNNING"
::constant DRAINING "DRAINING"
::constant QUIESCED "QUIESCED"
::constant STOPPED "STOPPED"
::constant FAILED "FAILED"

::class QueueBrokerAdmissionDecision public
::attribute admitted get
::attribute code get
::attribute detail get
::attribute reservation get
::attribute retryAfterSeconds get
::attribute evidence get

::method init
  expose admitted code detail reservation retryAfterSeconds evidence
  use strict arg admitted, code = "OK", detail = "", reservation = .nil, retryAfterSeconds = .nil, evidence = .nil
  admitted = admitted == .true
  code = code~string
  detail = detail~string

::method allow class
  use strict arg reservation = .nil, evidence = .nil
  return self~new(.true, "OK", "", reservation, .nil, evidence)

::method deny class
  use strict arg code, detail = "", retryAfterSeconds = .nil, evidence = .nil
  return self~new(.false, code, detail, .nil, retryAfterSeconds, evidence)


::class QueueBrokerAdmissionPolicy subclass AlchemyObject public
::method init
  meta = self~adoptionMetadata("Queue Broker admission policy", .array~of("No external capacity authority is installed by the default policy"))
  self~initAlchemy(meta)
  self~registerMethodContract("ADMITPUMP", "Admit one sender-channel pump before queue claim", .array~of("SERVICE", "CHANNEL"), "QUEUEBROKERADMISSIONDECISION", .false)
  self~registerMethodContract("COMPLETEPUMP", "Complete an admitted pump after queue/transport result", .array~of("SERVICE", "CHANNEL", "DECISION", "PUMP_RESULT"), "BOOLEAN", .false)
  self~registerMethodContract("ADMITHEARTBEAT", "Admit one authenticated health probe before network activity", .array~of("SERVICE", "CHANNEL"), "QUEUEBROKERADMISSIONDECISION", .false)
  self~registerMethodContract("COMPLETEHEARTBEAT", "Complete an admitted authenticated health probe", .array~of("SERVICE", "CHANNEL", "DECISION", "PROBE_RESULT"), "BOOLEAN", .false)
  self~describeMethodPolicy("ADMITPUMP", "FALSE", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~describeMethodPolicy("COMPLETEPUMP", "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~describeMethodPolicy("ADMITHEARTBEAT", "FALSE", "INTERNAL", "SENSITIVE", "READ", "NONE")
  self~describeMethodPolicy("COMPLETEHEARTBEAT", "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")

::method admitPump public
  use strict arg service, channel
  return .QueueBrokerAdmissionDecision~allow

::method completePump public
  use strict arg service, channel, decision, pumpResult
  return .true

::method admitHeartbeat public
  use strict arg service, channel
  return .QueueBrokerAdmissionDecision~allow

::method completeHeartbeat public
  use strict arg service, channel, decision, probeResult
  return .true

::method adoptionMetadata private
  use strict arg purpose, limitations
  meta = .directory~new
  meta["purpose"] = purpose
  meta["package_version"] = .QueueBrokerServiceBuild~VERSION
  meta["authorship"] = .array~of("Alchemy ooRexx Queue Fabric")
  meta["standards"] = .array~of("ALCHEMY-HOUSE-OBJECT-0.5", .QueueBrokerServiceBuild~API)
  meta["design_limitations"] = limitations
  return meta


::class QueueBrokerCycleResult public
::attribute attempted get
::attribute sent get
::attribute denied get
::attribute deferred get
::attribute failures get
::attribute details get

::method init
  expose attempted sent denied deferred failures details
  use strict arg attempted = 0, sent = 0, denied = 0, deferred = 0, failures = 0, details = .nil
  if details == .nil then details = .array~new


::class QueueBrokerHeartbeatResult public
::attribute attempted get
::attribute healthy get
::attribute denied get
::attribute skipped get
::attribute failures get
::attribute details get

::method init
  expose attempted healthy denied skipped failures details
  use strict arg attempted = 0, healthy = 0, denied = 0, skipped = 0, failures = 0, details = .nil
  if details == .nil then details = .array~new


::class QueueBrokerRetryState public
::attribute channelName get
::attribute attempts get
::attribute deadlineTick get
::attribute secondsUntil get

::method init
  expose channelName attempts deadlineTick secondsUntil
  use strict arg channelName, attempts, deadlineTick, secondsUntil


::class QueueBrokerService subclass AlchemyObject public
::attribute serviceName get
::attribute channelFabric get
::attribute listener get
::attribute admissionPolicy get
::attribute adminPrincipal get
::attribute state get
::attribute pumpIntervalSeconds get
::attribute retryBaseSeconds get
::attribute retryCapSeconds get
::attribute heartbeatIntervalSeconds get
::attribute cycles get
::attribute sentCount get
::attribute denialCount get
::attribute failureCount get
::attribute heartbeatCount get
::attribute heartbeatDenialCount get
::attribute heartbeatFailureCount get
::attribute lastHeartbeatAt get
::attribute lastHeartbeatError get
::attribute lastError get
::attribute runtimeContext get

::method init
  expose serviceName channelFabric listener admissionPolicy adminPrincipal state pumpIntervalSeconds retryBaseSeconds retryCapSeconds heartbeatIntervalSeconds cycles sentCount denialCount failureCount heartbeatCount heartbeatDenialCount heartbeatFailureCount lastHeartbeatAt lastHeartbeatError lastError runtimeContext retryAttempts retryDeadlines pumpMessage listenerMessage stopRequested drainRequested nextHeartbeatTick
  use strict arg serviceName, channelFabric, listener = .nil, admissionPolicy = .nil, adminPrincipal = "", pumpIntervalSeconds = 0.05, retryBaseSeconds = 0.25, retryCapSeconds = 30, heartbeatIntervalSeconds = 0
  if channelFabric == .nil | \channelFabric~isA(.QueueChannelFabric) then raise syntax 88.900 array("QueueBrokerService requires QueueChannelFabric")
  if admissionPolicy == .nil then admissionPolicy = .QueueBrokerAdmissionPolicy~new
  if \admissionPolicy~hasMethod("ADMITPUMP") | \admissionPolicy~hasMethod("COMPLETEPUMP") | \admissionPolicy~hasMethod("ADMITHEARTBEAT") | \admissionPolicy~hasMethod("COMPLETEHEARTBEAT") then raise syntax 88.900 array("QueueBrokerService admission policy contract is incomplete")
  if adminPrincipal = "" then adminPrincipal = channelFabric~adminPrincipal
  if \datatype(pumpIntervalSeconds, "N") | pumpIntervalSeconds < 0 then raise syntax 88.900 array("pump interval must be non-negative")
  if \datatype(retryBaseSeconds, "N") | retryBaseSeconds <= 0 then raise syntax 88.900 array("retry base must be positive")
  if \datatype(retryCapSeconds, "N") | retryCapSeconds < retryBaseSeconds then raise syntax 88.900 array("retry cap must be >= retry base")
  if \datatype(heartbeatIntervalSeconds, "N") | heartbeatIntervalSeconds < 0 then raise syntax 88.900 array("heartbeat interval must be non-negative")
  serviceName = serviceName~string~strip
  if serviceName = "" then raise syntax 88.900 array("QueueBrokerService name must not be empty")
  state = .QueueBrokerServiceState~NEW
  cycles = 0
  sentCount = 0
  denialCount = 0
  failureCount = 0
  heartbeatCount = 0
  heartbeatDenialCount = 0
  heartbeatFailureCount = 0
  lastHeartbeatAt = ""
  lastHeartbeatError = ""
  lastError = ""
  runtimeContext = .nil
  retryAttempts = .table~new
  retryDeadlines = .table~new
  pumpMessage = .nil
  listenerMessage = .nil
  stopRequested = .false
  drainRequested = .false
  nextHeartbeatTick = 0

  limitations = .array~of("No distributed XA; transport remains at-least-once with idempotent receiver insertion", "Heartbeat requires a transport implementing PROBE")
  meta = self~adoptionMetadata("Queue Fabric broker operational lifecycle", limitations)
  meta["service_name"] = serviceName
  self~initAlchemy(meta)
  self~registerStateVariable("serviceName", "PUBLIC", "broker service identity")
  self~registerStateVariable("state", "PUBLIC", "broker lifecycle state")
  self~registerStateVariable("cycles", "CUSTOMER", "completed pump cycles")
  self~registerStateVariable("sentCount", "CUSTOMER", "successfully transferred work packages")
  self~registerStateVariable("denialCount", "CUSTOMER", "pre-claim admission denials")
  self~registerStateVariable("failureCount", "CUSTOMER", "pump failures")
  self~registerStateVariable("heartbeatCount", "CUSTOMER", "successful authenticated health probes")
  self~registerStateVariable("heartbeatDenialCount", "CUSTOMER", "heartbeat admission denials")
  self~registerStateVariable("heartbeatFailureCount", "CUSTOMER", "heartbeat failures")
  self~registerStateVariable("lastHeartbeatAt", "CUSTOMER", "latest successful heartbeat timestamp")
  self~registerStateVariable("lastHeartbeatError", "INTERNAL", "latest heartbeat error")
  self~registerStateVariable("lastError", "INTERNAL", "latest operational error")
  self~registerMethodContract("START", "Start broker listener and sender pump activities", .array~new, "QUEUEOPERATIONRESULT", .false)
  self~registerMethodContract("QUIESCE", "Stop ingress and optionally drain sender work", .array~of("DRAIN"), "QUEUEOPERATIONRESULT", .false)
  self~registerMethodContract("STOP", "Stop broker activities immediately", .array~new, "QUEUEOPERATIONRESULT", .false)
  self~registerMethodContract("PUMPCYCLE", "Run one pre-admitted one-message pump across eligible channels", .array~new, "QUEUEBROKERCYCLERESULT", .false)
  self~registerMethodContract("HEARTBEATCYCLE", "Run one admission-controlled authenticated health-probe cycle", .array~new, "QUEUEBROKERHEARTBEATRESULT", .false)
  self~registerMethodContract("RUNTIMEPREPARE", "Runtime Registry prepare hook", .array~of("CONTEXT"), "BOOLEAN", .false)
  self~registerMethodContract("RUNTIMESELFTEST", "Runtime Registry self-test hook", .array~new, "BOOLEAN", .false)
  self~registerMethodContract("RUNTIMESTART", "Runtime Registry activation hook", .array~new, "BOOLEAN", .false)
  self~registerMethodContract("RUNTIMEQUIESCE", "Runtime Registry quiesce hook", .array~new, "BOOLEAN", .false)
  self~registerMethodContract("RUNTIMESTOP", "Runtime Registry stop hook", .array~new, "BOOLEAN", .false)
  self~describeMethodPolicy("START", "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~describeMethodPolicy("QUIESCE", "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~describeMethodPolicy("STOP", "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "NONE")
  self~describeMethodPolicy("HEARTBEATCYCLE", "FALSE", "CUSTOMER", "SENSITIVE", "READ", "NONE")
  self~recordRelationship("CHANNEL_FABRIC", channelFabric, "broker-owned pump collaborator", "INTERNAL")
  self~recordRelationship("ADMISSION_POLICY", admissionPolicy, "pre-side-effect admission collaborator", "INTERNAL")
  if listener \== .nil then self~recordRelationship("SOCKET_LISTENER", listener, "authenticated ingress collaborator", "INTERNAL")

::method runtimePrepare public
  expose runtimeContext state
  use strict arg context
  runtimeContext = context
  guard on
  if state = .QueueBrokerServiceState~NEW | state = .QueueBrokerServiceState~STOPPED then state = .QueueBrokerServiceState~PREPARED
  prepared = state = .QueueBrokerServiceState~PREPARED | state = .QueueBrokerServiceState~QUIESCED
  guard off
  return prepared

::method runtimeSelfTest public
  expose channelFabric admissionPolicy listener state heartbeatIntervalSeconds
  if channelFabric == .nil | \channelFabric~hasMethod("PUMP") then return .false
  if admissionPolicy == .nil | \admissionPolicy~hasMethod("ADMITPUMP") | \admissionPolicy~hasMethod("COMPLETEPUMP") | \admissionPolicy~hasMethod("ADMITHEARTBEAT") | \admissionPolicy~hasMethod("COMPLETEHEARTBEAT") then return .false
  if listener \== .nil then do
    if \listener~hasMethod("START") | \listener~hasMethod("STOP") | \listener~hasMethod("SERVEONE") then return .false
  end
  if heartbeatIntervalSeconds > 0 then if \channelFabric~transport~hasMethod("PROBE") then return .false
  return state \= .QueueBrokerServiceState~FAILED

::method runtimeStart public
  return self~start~ok

::method runtimeQuiesce public
  return self~quiesce(.true)~ok

::method runtimeStop public
  return self~stop~ok

::method start public
  expose state listener pumpMessage listenerMessage stopRequested drainRequested lastError heartbeatIntervalSeconds nextHeartbeatTick
  guard on
  if state = .QueueBrokerServiceState~RUNNING then do
    guard off
    return .QueueOperationResult~success(self, "already running")
  end
  if state = .QueueBrokerServiceState~DRAINING then do
    guard off
    return .QueueOperationResult~failure("BROKER_DRAINING")
  end
  stopRequested = .false
  drainRequested = .false
  lastError = ""
  if heartbeatIntervalSeconds > 0 then nextHeartbeatTick = self~nowTick + (heartbeatIntervalSeconds * 1000000)
  else nextHeartbeatTick = 0
  guard off

  if listener \== .nil then do
    if \listener~start then do
      guard on
      state = .QueueBrokerServiceState~FAILED
      lastError = "LISTENER_START_FAILED"
      guard off
      return .QueueOperationResult~failure("LISTENER_START_FAILED", listener~lastError)
    end
  end

  guard on
  state = .QueueBrokerServiceState~RUNNING
  guard off
  pumpMessage = .Message~new(self, "RUNPUMPER")
  pumpMessage~start
  if listener \== .nil then do
    listenerMessage = .Message~new(self, "RUNLISTENER")
    listenerMessage~start
  end
  self~alchemyTouch("BROKER_START")
  return .QueueOperationResult~success(self)

::method quiesce public
  expose state listener drainRequested stopRequested
  use strict arg drain = .true
  guard on
  if state = .QueueBrokerServiceState~STOPPED | state = .QueueBrokerServiceState~QUIESCED then do
    guard off
    return .QueueOperationResult~success(self, "already quiesced")
  end
  if drain then do
    state = .QueueBrokerServiceState~DRAINING
    drainRequested = .true
  end
  else do
    state = .QueueBrokerServiceState~QUIESCED
    stopRequested = .true
  end
  guard off
  if listener \== .nil then ignore = listener~stop
  self~alchemyTouch("BROKER_QUIESCE")
  return .QueueOperationResult~success(self)

::method stop public
  expose state listener stopRequested drainRequested
  guard on
  stopRequested = .true
  drainRequested = .false
  state = .QueueBrokerServiceState~STOPPED
  guard off
  if listener \== .nil then ignore = listener~stop
  self~alchemyTouch("BROKER_STOP")
  return .QueueOperationResult~success(self)

::method waitForStop public unguarded
  expose pumpMessage listenerMessage
  use strict arg waitListener = .true
  if pumpMessage \== .nil then pumpMessage~wait
  if waitListener & listenerMessage \== .nil then listenerMessage~wait
  return self

::method pumpCycle public
  expose channelFabric admissionPolicy adminPrincipal cycles sentCount denialCount failureCount lastError retryAttempts retryDeadlines
  details = .array~new
  attempted = 0
  sent = 0
  denied = 0
  deferred = 0
  failures = 0
  nowTick = self~nowTick
  do channel over channelFabric~senderChannels
    if channel~state \= .QueueChannelState~RUNNING & channel~state \= .QueueChannelState~RETRYING then iterate
    channelKey = channel~channelName~translate
    deadline = retryDeadlines~at(channelKey)
    if deadline \== .nil then do
      numeric digits 30
      if nowTick < deadline then do
        deferred += 1
        iterate
      end
    end

    decision = admissionPolicy~admitPump(self, channel)
    if decision == .nil | \decision~hasMethod("ADMITTED") then decision = .QueueBrokerAdmissionDecision~deny("ADMISSION_CONTRACT_INVALID", "policy returned no QueueBrokerAdmissionDecision")
    if \decision~admitted then do
      denied += 1
      denialCount += 1
      details~append(.array~of(channel~channelName, "DENIED", decision~code, decision~detail))
      self~scheduleDeniedRetry(channelKey, decision~retryAfterSeconds)
      iterate
    end

    attempted += 1
    pumpResult = channelFabric~pump(channel~channelName, 1, adminPrincipal)
    completeOk = admissionPolicy~completePump(self, channel, decision, pumpResult)
    if completeOk == .false then do
      failures += 1
      failureCount += 1
      lastError = "ADMISSION_COMPLETE_FAILED:" || channel~channelName
      details~append(.array~of(channel~channelName, "COMPLETE_FAILED", "ADMISSION_COMPLETE_FAILED", ""))
    end

    if pumpResult~ok then do
      sentThis = self~sentFromDetail(pumpResult~detail)
      sent += sentThis
      sentCount += sentThis
      retryAttempts~remove(channelKey)
      retryDeadlines~remove(channelKey)
      details~append(.array~of(channel~channelName, "OK", pumpResult~code, pumpResult~detail))
    end
    else do
      failures += 1
      failureCount += 1
      lastError = pumpResult~code || ":" || pumpResult~detail
      self~scheduleFailureRetry(channelKey)
      details~append(.array~of(channel~channelName, "FAILED", pumpResult~code, pumpResult~detail))
    end
  end
  cycles += 1
  self~alchemyTouch("BROKER_PUMP_CYCLE")
  return .QueueBrokerCycleResult~new(attempted, sent, denied, deferred, failures, details)

::method heartbeatCycle public
  expose channelFabric admissionPolicy heartbeatIntervalSeconds heartbeatCount heartbeatDenialCount heartbeatFailureCount lastHeartbeatAt lastHeartbeatError
  details = .array~new
  attempted = 0
  healthy = 0
  denied = 0
  skipped = 0
  failures = 0
  transport = channelFabric~transport
  if heartbeatIntervalSeconds = 0 then return .QueueBrokerHeartbeatResult~new(0, 0, 0, 0, 0, details)
  if \transport~hasMethod("PROBE") then do
    details~append(.array~of("", "SKIPPED", "TRANSPORT_PROBE_UNAVAILABLE", ""))
    return .QueueBrokerHeartbeatResult~new(0, 0, 0, 1, 0, details)
  end

  do channel over channelFabric~senderChannels
    if channel~state \= .QueueChannelState~RUNNING & channel~state \= .QueueChannelState~RETRYING then do
      skipped += 1
      iterate
    end
    decision = admissionPolicy~admitHeartbeat(self, channel)
    if decision == .nil | \decision~hasMethod("ADMITTED") then decision = .QueueBrokerAdmissionDecision~deny("HEARTBEAT_ADMISSION_CONTRACT_INVALID", "policy returned no QueueBrokerAdmissionDecision")
    if \decision~admitted then do
      denied += 1
      heartbeatDenialCount += 1
      details~append(.array~of(channel~channelName, "DENIED", decision~code, decision~detail))
      iterate
    end

    attempted += 1
    probeResult = transport~probe(channelFabric~managerName, channel~remoteManager, channel~remoteChannel, channel~remotePrincipal)
    completeOk = admissionPolicy~completeHeartbeat(self, channel, decision, probeResult)
    if completeOk == .false then do
      failures += 1
      heartbeatFailureCount += 1
      lastHeartbeatError = "HEARTBEAT_COMPLETE_FAILED:" || channel~channelName
      details~append(.array~of(channel~channelName, "COMPLETE_FAILED", "HEARTBEAT_COMPLETE_FAILED", ""))
    end
    if probeResult~ok then do
      healthy += 1
      heartbeatCount += 1
      lastHeartbeatAt = .QueueClock~timestamp
      lastHeartbeatError = ""
      details~append(.array~of(channel~channelName, "HEALTHY", probeResult~code, probeResult~detail))
    end
    else do
      failures += 1
      heartbeatFailureCount += 1
      lastHeartbeatError = probeResult~code || ":" || probeResult~detail
      details~append(.array~of(channel~channelName, "FAILED", probeResult~code, probeResult~detail))
    end
  end
  self~scheduleNextHeartbeat
  self~alchemyTouch("BROKER_HEARTBEAT_CYCLE")
  return .QueueBrokerHeartbeatResult~new(attempted, healthy, denied, skipped, failures, details)

::method retryStateRows public
  expose channelFabric retryAttempts retryDeadlines
  rows = .array~new
  now = self~nowTick
  do channel over channelFabric~senderChannels
    key = channel~channelName~translate
    attempts = retryAttempts~at(key)
    deadline = retryDeadlines~at(key)
    if attempts == .nil then attempts = 0
    if deadline == .nil then iterate
    numeric digits 30
    remaining = deadline - now
    if remaining < 0 then remaining = 0
    rows~append(.QueueBrokerRetryState~new(channel~channelName, attempts, deadline, remaining / 1000000))
  end
  return rows

::method runPumper public unguarded
  expose state pumpIntervalSeconds stopRequested drainRequested heartbeatIntervalSeconds nextHeartbeatTick
  do forever
    guard on
    stopNow = stopRequested
    stateNow = state
    guard off
    if stopNow | stateNow = .QueueBrokerServiceState~STOPPED | stateNow = .QueueBrokerServiceState~FAILED | stateNow = .QueueBrokerServiceState~QUIESCED then leave
    if stateNow = .QueueBrokerServiceState~RUNNING & heartbeatIntervalSeconds > 0 then do
      numeric digits 30
      if nextHeartbeatTick = 0 | self~nowTick >= nextHeartbeatTick then ignore = self~heartbeatCycle
    end
    cycle = self~pumpCycle
    if stateNow = .QueueBrokerServiceState~DRAINING & drainRequested then do
      /* A quiet pump cycle means every runnable sender queue was empty.
       * attempted may be non-zero because probing an empty RUNNING channel is
       * still a pump attempt.  Denial/defer/failure is not a drained state. */
      if cycle~sent = 0 & cycle~denied = 0 & cycle~deferred = 0 & cycle~failures = 0 then do
        guard on
        state = .QueueBrokerServiceState~QUIESCED
        stopRequested = .true
        guard off
        leave
      end
    end
    if pumpIntervalSeconds > 0 then call SysSleep pumpIntervalSeconds
  end
  return .true

::method runListener public unguarded
  expose listener state stopRequested failureCount lastError
  if listener == .nil then return .true
  do forever
    guard on
    stopNow = stopRequested
    stateNow = state
    guard off
    if stopNow | stateNow \= .QueueBrokerServiceState~RUNNING then leave
    listenerResult = listener~serveOne
    guard on
    stopAfter = stopRequested
    stateAfter = state
    guard off
    if \listenerResult~ok & \stopAfter & stateAfter = .QueueBrokerServiceState~RUNNING then do
      failureCount += 1
      lastError = listenerResult~code || ":" || listenerResult~detail
    end
  end
  return .true

::method scheduleDeniedRetry private
  expose retryDeadlines
  use strict arg channelKey, retryAfterSeconds = .nil
  delay = retryAfterSeconds
  if delay == .nil then delay = 0.25
  else if \datatype(delay, "N") then delay = 0.25
  else if delay <= 0 then delay = 0.25
  numeric digits 30
  retryDeadlines[channelKey] = self~nowTick + (delay * 1000000)
  return delay

::method scheduleFailureRetry private
  expose retryAttempts retryDeadlines retryBaseSeconds retryCapSeconds
  use strict arg channelKey
  attempts = retryAttempts~at(channelKey)
  if attempts == .nil then attempts = 0
  attempts += 1
  retryAttempts[channelKey] = attempts
  delay = retryBaseSeconds
  if attempts > 1 then delay = retryBaseSeconds * (2 ** (attempts - 1))
  if delay > retryCapSeconds then delay = retryCapSeconds
  numeric digits 30
  retryDeadlines[channelKey] = self~nowTick + (delay * 1000000)
  return delay

::method scheduleNextHeartbeat private
  expose heartbeatIntervalSeconds nextHeartbeatTick
  if heartbeatIntervalSeconds <= 0 then nextHeartbeatTick = 0
  else do
    numeric digits 30
    nextHeartbeatTick = self~nowTick + (heartbeatIntervalSeconds * 1000000)
  end
  return nextHeartbeatTick

::method sentFromDetail private
  use strict arg detail
  text = detail~string
  p = pos("sent=", text)
  if p = 0 then return 0
  rest = text~substr(p + 5)
  semi = pos(";", rest)
  if semi > 0 then rest = rest~left(semi - 1)
  if datatype(rest, "W") then return rest
  return 0

::method nowTick private
  numeric digits 30
  return time("F")

::method adoptionMetadata private
  use strict arg purpose, limitations
  meta = .directory~new
  meta["purpose"] = purpose
  meta["package_version"] = .QueueBrokerServiceBuild~VERSION
  meta["authorship"] = .array~of("Alchemy ooRexx Queue Fabric")
  meta["standards"] = .array~of("ALCHEMY-HOUSE-OBJECT-0.5", .QueueBrokerServiceBuild~API)
  meta["design_limitations"] = limitations
  return meta

::requires "ObjectQueueChannels.cls"
::requires "AlchemyObject.cls"
