/* Optional WLU v0.6 admission adapter for Queue Fabric v0.9-dev6. */

::class QueueBrokerWLUAdmission subclass QueueBrokerAdmissionPolicy public
::attribute authority get
::attribute identity get
::attribute scopePrefix get
::attribute expectedMicroWlu get
::attribute ceilingMicroWlu get
::attribute requestedRateMicroWluPerSecond get
::attribute ttlSeconds get
::attribute heartbeatExpectedMicroWlu get
::attribute heartbeatCeilingMicroWlu get
::attribute heartbeatRateMicroWluPerSecond get

::method init
  expose authority identity scopePrefix expectedMicroWlu ceilingMicroWlu requestedRateMicroWluPerSecond ttlSeconds heartbeatExpectedMicroWlu heartbeatCeilingMicroWlu heartbeatRateMicroWluPerSecond requestCounter heartbeatRequestCounter
  use strict arg authority, identity, scopePrefix = "queue-broker", expectedMicroWlu = 1000000, ceilingMicroWlu = .nil, requestedRateMicroWluPerSecond = 0, ttlSeconds = 30, heartbeatExpectedMicroWlu = 0, heartbeatCeilingMicroWlu = .nil, heartbeatRateMicroWluPerSecond = 0
  if authority == .nil | \authority~hasMethod("RESERVEDEMAND") | \authority~hasMethod("SETTLE") | \authority~hasMethod("RELEASE") then raise syntax 88.900 array("QueueBrokerWLUAdmission requires WLUAuthority-compatible object")
  if ceilingMicroWlu == .nil then ceilingMicroWlu = expectedMicroWlu
  if heartbeatCeilingMicroWlu == .nil then heartbeatCeilingMicroWlu = heartbeatExpectedMicroWlu
  identity = identity~string~strip
  scopePrefix = scopePrefix~string~strip
  if identity = "" | scopePrefix = "" then raise syntax 88.900 array("WLU broker identity/scope must not be empty")
  if \datatype(heartbeatExpectedMicroWlu, "W") | heartbeatExpectedMicroWlu < 0 then raise syntax 88.900 array("heartbeat expected WLU must be non-negative whole micro-WLU")
  if \datatype(heartbeatCeilingMicroWlu, "W") | heartbeatCeilingMicroWlu < heartbeatExpectedMicroWlu then raise syntax 88.900 array("heartbeat WLU ceiling must cover expected work")
  requestCounter = 0
  heartbeatRequestCounter = 0
  limitations = .array~of("Broker adapter values successful transfer as configured expected WLU", "Heartbeat metering is optional and independent from transfer metering")
  meta = .directory~new
  meta["purpose"] = "Queue Broker optional WLU v0.6 pre-side-effect admission"
  meta["package_version"] = .QueueBrokerServiceBuild~VERSION
  meta["authorship"] = .array~of("Alchemy ooRexx Queue Fabric")
  meta["standards"] = .array~of("ALCHEMY-HOUSE-OBJECT-0.5", "work.load.units/0.6", .QueueBrokerServiceBuild~API)
  meta["design_limitations"] = limitations
  self~initAlchemy(meta)
  self~registerStateVariable("identity", "CUSTOMER", "WLU policy identity")
  self~registerStateVariable("scopePrefix", "CUSTOMER", "WLU scope prefix")
  self~registerStateVariable("expectedMicroWlu", "CUSTOMER", "expected work reserved per message pump")
  self~registerStateVariable("ceilingMicroWlu", "CUSTOMER", "maximum work reserved per message pump")
  self~registerStateVariable("heartbeatExpectedMicroWlu", "CUSTOMER", "expected work reserved per authenticated heartbeat")
  self~registerStateVariable("heartbeatCeilingMicroWlu", "CUSTOMER", "maximum work reserved per authenticated heartbeat")
  self~recordRelationship("WLU_AUTHORITY", authority, "external workload entitlement/capacity authority", "INTERNAL")

::method admitPump public
  expose expectedMicroWlu ceilingMicroWlu requestedRateMicroWluPerSecond
  use strict arg service, channel
  return self~reserveFor(service, channel, "pump", expectedMicroWlu, ceilingMicroWlu, requestedRateMicroWluPerSecond)

::method completePump public
  expose authority expectedMicroWlu
  use strict arg service, channel, decision, pumpResult
  reservation = decision~reservation
  if reservation == .nil then return .true
  sent = self~sentFromPumpDetail(pumpResult~detail)
  if sent > 0 then settlementResult = authority~settle(reservation, expectedMicroWlu)
  else settlementResult = authority~release(reservation)
  self~alchemyTouch("WLU_COMPLETE_PUMP")
  return settlementResult~ok

::method admitHeartbeat public
  expose heartbeatExpectedMicroWlu heartbeatCeilingMicroWlu heartbeatRateMicroWluPerSecond
  use strict arg service, channel
  if heartbeatExpectedMicroWlu = 0 & heartbeatRateMicroWluPerSecond = 0 then return .QueueBrokerAdmissionDecision~allow
  return self~reserveFor(service, channel, "heartbeat", heartbeatExpectedMicroWlu, heartbeatCeilingMicroWlu, heartbeatRateMicroWluPerSecond)

::method completeHeartbeat public
  expose authority heartbeatExpectedMicroWlu
  use strict arg service, channel, decision, probeResult
  reservation = decision~reservation
  if reservation == .nil then return .true
  if probeResult~ok then settlementResult = authority~settle(reservation, heartbeatExpectedMicroWlu)
  else settlementResult = authority~release(reservation)
  self~alchemyTouch("WLU_COMPLETE_HEARTBEAT")
  return settlementResult~ok

::method reserveFor private
  expose authority identity scopePrefix ttlSeconds requestCounter heartbeatRequestCounter
  use strict arg service, channel, kind, expected, ceiling, rate
  if kind = "heartbeat" then do
    heartbeatRequestCounter += 1
    counter = heartbeatRequestCounter
  end
  else do
    requestCounter += 1
    counter = requestCounter
  end
  scope = scopePrefix || "/" || kind || "/" || channel~channelName
  demand = .WLUWorkDemand~new(expected, ceiling, 0, rate)
  requestId = service~serviceName || ":" || kind || ":" || channel~channelName || ":" || counter
  reserveResult = authority~reserveDemand(identity, scope, demand, ttlSeconds, requestId)
  if \reserveResult~ok then return .QueueBrokerAdmissionDecision~deny(reserveResult~code, reserveResult~detail, reserveResult~retryAfterSeconds, reserveResult~value)
  evidence = .directory~new
  evidence["identity"] = identity
  evidence["scope"] = scope
  evidence["reservation_id"] = reserveResult~value~reservationId
  evidence["expected_micro_wlu"] = expected
  evidence["ceiling_micro_wlu"] = ceiling
  evidence["requested_rate_micro_wlu_per_second"] = rate
  self~alchemyTouch("WLU_ADMIT_" || kind~translate)
  return .QueueBrokerAdmissionDecision~allow(reserveResult~value, evidence)

::method sentFromPumpDetail private
  use strict arg detail
  text = detail~string
  p = pos("sent=", text)
  if p = 0 then return 0
  rest = text~substr(p + 5)
  semi = pos(";", rest)
  if semi > 0 then rest = rest~left(semi - 1)
  if datatype(rest, "W") then return rest
  return 0

::requires "ObjectQueueBrokerService.cls"
::requires "WorkLoadUnits.cls"
