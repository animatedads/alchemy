/* FlyLo v0.4 Queue Fabric backend services.
 *
 * Split authorities:
 *   Journey/Inventory Engine - route construction and seat commitment
 *   Booking Engine           - passenger booking identity and confirmation
 *   Operations Engine        - flight operational status
 *
 * Channels can request journeys, bookings and status, but cannot put directly
 * to the inventory-commit queue.  Booking -> inventory -> booking completion
 * is an idempotent Queue Fabric saga.
 */

::class FlyLoServiceTopology public
::constant SECURITY_DOMAIN "FLYLO"
::constant ADMIN_PRINCIPAL "flylo-admin"
::constant CHANNEL_PRINCIPAL "flylo-channel"
::constant JOURNEY_WORKER "flylo-journey-worker"
::constant BOOKING_WORKER "flylo-booking-worker"
::constant OPERATIONS_WORKER "flylo-operations-worker"
::constant FINANCE_PRINCIPAL "flylo-finance-channel"
::constant ACCOUNTING_WORKER "flylo-accounting-worker"

::constant JOURNEY_COMMANDS "FLYLO.JOURNEY.COMMANDS"
::constant JOURNEY_RESULTS "FLYLO.JOURNEY.RESULTS"
::constant BOOKING_COMMANDS "FLYLO.BOOKING.COMMANDS"
::constant BOOKING_RESULTS "FLYLO.BOOKING.RESULTS"
::constant OPERATIONS_COMMANDS "FLYLO.OPERATIONS.COMMANDS"
::constant OPERATIONS_RESULTS "FLYLO.OPERATIONS.RESULTS"
::constant INVENTORY_COMMANDS "FLYLO.INVENTORY.COMMIT"
::constant INVENTORY_OUTCOMES "FLYLO.INVENTORY.OUTCOMES"
::constant BACKEND_DLQ "FLYLO.BACKEND.DLQ"

::constant INVENTORY_TOPIC "FLYLO.INVENTORY.STATE"
::constant INVENTORY_TOPIC_ROOT "inventory/state"
::constant BOOKING_TOPIC "FLYLO.BOOKINGS.STATE"
::constant BOOKING_TOPIC_ROOT "bookings/state"
::constant ACCOUNTING_TOPIC "FLYLO.ACCOUNTING.SOURCE.EVENTS"
::constant ACCOUNTING_TOPIC_ROOT "accounting/source-events"

::method init
  expose manager topics persistent
  use arg managerArg
  if managerArg == .nil then raise syntax 88.900 array("FLYLO_QUEUE_MANAGER_REQUIRED")
  manager = managerArg
  persistent = manager~durableStore <> .nil
  if persistent then lifecycle = .QueueLifecycle~PERMANENT
  else lifecycle = .QueueLifecycle~TEMPORARY

  do q over .array~of(self~JOURNEY_COMMANDS, self~JOURNEY_RESULTS, self~BOOKING_COMMANDS, self~BOOKING_RESULTS, self~OPERATIONS_COMMANDS, self~OPERATIONS_RESULTS, self~INVENTORY_COMMANDS, self~INVENTORY_OUTCOMES, self~BACKEND_DLQ)
    if manager~queue(q) == .nil then ignored = self~must(manager~createQueue(q, lifecycle, self~SECURITY_DOMAIN, 10000, self~ADMIN_PRINCIPAL), "create " || q)
  end
  ignored = self~must(manager~setDeadLetterQueue(self~BACKEND_DLQ, self~ADMIN_PRINCIPAL), "set backend DLQ")
  do q over .array~of(self~JOURNEY_COMMANDS, self~BOOKING_COMMANDS, self~OPERATIONS_COMMANDS, self~INVENTORY_COMMANDS, self~INVENTORY_OUTCOMES)
    ignored = self~must(manager~configureBackout(q, 2, self~BACKEND_DLQ, self~ADMIN_PRINCIPAL), "configure backout " || q)
  end

  /* External/channel authority. */
  ignored = self~grant(self~JOURNEY_COMMANDS, self~CHANNEL_PRINCIPAL, .QueueAccess~PUT)
  ignored = self~grant(self~JOURNEY_RESULTS, self~CHANNEL_PRINCIPAL, .QueueAccess~GET)
  ignored = self~grant(self~JOURNEY_RESULTS, self~CHANNEL_PRINCIPAL, .QueueAccess~BROWSE)
  ignored = self~grant(self~BOOKING_COMMANDS, self~CHANNEL_PRINCIPAL, .QueueAccess~PUT)
  ignored = self~grant(self~BOOKING_RESULTS, self~CHANNEL_PRINCIPAL, .QueueAccess~GET)
  ignored = self~grant(self~BOOKING_RESULTS, self~CHANNEL_PRINCIPAL, .QueueAccess~BROWSE)
  ignored = self~grant(self~OPERATIONS_COMMANDS, self~CHANNEL_PRINCIPAL, .QueueAccess~PUT)
  ignored = self~grant(self~OPERATIONS_RESULTS, self~CHANNEL_PRINCIPAL, .QueueAccess~GET)
  ignored = self~grant(self~OPERATIONS_RESULTS, self~CHANNEL_PRINCIPAL, .QueueAccess~BROWSE)

  /* Journey worker owns journey search and the inventory commit boundary. */
  ignored = self~grant(self~JOURNEY_COMMANDS, self~JOURNEY_WORKER, .QueueAccess~GET)
  ignored = self~grant(self~JOURNEY_RESULTS, self~JOURNEY_WORKER, .QueueAccess~PUT)
  ignored = self~grant(self~INVENTORY_COMMANDS, self~JOURNEY_WORKER, .QueueAccess~GET)
  ignored = self~grant(self~INVENTORY_OUTCOMES, self~JOURNEY_WORKER, .QueueAccess~PUT)

  /* Booking worker can request, but cannot directly mutate, inventory. */
  ignored = self~grant(self~BOOKING_COMMANDS, self~BOOKING_WORKER, .QueueAccess~GET)
  ignored = self~grant(self~BOOKING_RESULTS, self~BOOKING_WORKER, .QueueAccess~PUT)
  ignored = self~grant(self~INVENTORY_COMMANDS, self~BOOKING_WORKER, .QueueAccess~PUT)
  ignored = self~grant(self~INVENTORY_OUTCOMES, self~BOOKING_WORKER, .QueueAccess~GET)

  ignored = self~grant(self~OPERATIONS_COMMANDS, self~OPERATIONS_WORKER, .QueueAccess~GET)
  ignored = self~grant(self~OPERATIONS_RESULTS, self~OPERATIONS_WORKER, .QueueAccess~PUT)

  topics = .QueueTopicFabric~new(manager)
  if topics~topic(self~INVENTORY_TOPIC) == .nil then ignored = self~must(topics~defineTopic(self~INVENTORY_TOPIC, self~INVENTORY_TOPIC_ROOT, lifecycle, self~SECURITY_DOMAIN, self~ADMIN_PRINCIPAL), "define inventory topic")
  ignored = self~must(topics~grantTopicAccess(self~INVENTORY_TOPIC, self~JOURNEY_WORKER, .QueueTopicAccess~PUBLISH, self~ADMIN_PRINCIPAL), "grant inventory publish")
  ignored = self~must(topics~grantTopicAccess(self~INVENTORY_TOPIC, self~JOURNEY_WORKER, .QueueTopicAccess~BROWSE, self~ADMIN_PRINCIPAL), "grant inventory browse")

  if topics~topic(self~BOOKING_TOPIC) == .nil then ignored = self~must(topics~defineTopic(self~BOOKING_TOPIC, self~BOOKING_TOPIC_ROOT, lifecycle, self~SECURITY_DOMAIN, self~ADMIN_PRINCIPAL), "define booking topic")
  ignored = self~must(topics~grantTopicAccess(self~BOOKING_TOPIC, self~BOOKING_WORKER, .QueueTopicAccess~PUBLISH, self~ADMIN_PRINCIPAL), "grant booking publish")
  ignored = self~must(topics~grantTopicAccess(self~BOOKING_TOPIC, self~BOOKING_WORKER, .QueueTopicAccess~BROWSE, self~ADMIN_PRINCIPAL), "grant booking browse")

  /* Finance can publish captured-payment evidence; Accounting is the only
     reader/posting authority.  Booking/channel principals do not write GL. */
  if topics~topic(self~ACCOUNTING_TOPIC) == .nil then ignored = self~must(topics~defineTopic(self~ACCOUNTING_TOPIC, self~ACCOUNTING_TOPIC_ROOT, lifecycle, self~SECURITY_DOMAIN, self~ADMIN_PRINCIPAL), "define accounting source-event topic")
  ignored = self~must(topics~grantTopicAccess(self~ACCOUNTING_TOPIC, self~FINANCE_PRINCIPAL, .QueueTopicAccess~PUBLISH, self~ADMIN_PRINCIPAL), "grant accounting event publish")
  ignored = self~must(topics~grantTopicAccess(self~ACCOUNTING_TOPIC, self~ACCOUNTING_WORKER, .QueueTopicAccess~BROWSE, self~ADMIN_PRINCIPAL), "grant accounting event browse")

::method manager
  expose manager
  return manager
::method topics
  expose topics
  return topics
::method persistent
  expose persistent
  return persistent
::method grant private
  expose manager
  use arg queueName, principal, access
  return self~must(manager~grant(queueName, principal, access, self~ADMIN_PRINCIPAL), "grant " || queueName || " " || principal || " " || access)
::method must private
  use arg result, label
  if result == .nil then raise syntax 88.900 array("FLYLO_QUEUE_INIT_FAILED", label, "NIL")
  if result~ok = .false then raise syntax 88.900 array("FLYLO_QUEUE_INIT_FAILED", label, result~code, result~detail)
  return result
::method safeToken private
  use arg value
  t = value~string
  t = t~changestr("/", "_")
  t = t~changestr(" ", "_")
  t = t~changestr(":", "_")
  return t
::method publishInventoryProjection
  expose topics persistent
  use arg projection, correlationId = ""
  if projection == .nil then return .QueueOperationResult~failure("INVENTORY_PROJECTION_REQUIRED")
  o = .table~new
  o["subtopic"] = "commit/" || self~safeToken(projection["idempotencyKey"])
  o["retain"] = .true
  o["persistent"] = persistent
  if correlationId <> "" then o["correlationId"] = correlationId
  return topics~publish(self~INVENTORY_TOPIC, projection, o, self~JOURNEY_WORKER)
::method publishBookingProjection
  expose topics persistent
  use arg projection, correlationId = ""
  if projection == .nil then return .QueueOperationResult~failure("BOOKING_PROJECTION_REQUIRED")
  o = .table~new
  o["subtopic"] = "booking/" || self~safeToken(projection["bookingRef"])
  o["retain"] = .true
  o["persistent"] = persistent
  if correlationId <> "" then o["correlationId"] = correlationId
  return topics~publish(self~BOOKING_TOPIC, projection, o, self~BOOKING_WORKER)

::class FlyLoBackendRuntime public
::attribute topology get
::attribute journey get
::attribute booking get
::attribute operations get
::method init
  expose topology journey booking operations commandCounter
  use arg topologyArg, journeyArg, bookingArg, operationsArg
  if topologyArg == .nil | journeyArg == .nil | bookingArg == .nil | operationsArg == .nil then raise syntax 88.900 array("FLYLO_BACKEND_COMPONENT_REQUIRED")
  topology = topologyArg
  journey = journeyArg
  booking = bookingArg
  operations = operationsArg
  commandCounter = 0
  rebuilt = self~rebuildFromRetained
  if \rebuilt~ok then raise syntax 88.900 array("FLYLO_BACKEND_REBUILD_FAILED", rebuilt~code, rebuilt~detail)
::method nextCommandId
  expose commandCounter
  guard on
  commandCounter += 1
  return "FLYCMD-" || .DateTime~new~microseconds || "-" || commandCounter
::method options private
  expose topology
  use arg correlationId = ""
  o = .table~new
  o["persistent"] = topology~persistent
  if correlationId <> "" then o["correlationId"] = correlationId
  return o
::method resultPayload private
  use arg command, handled
  d = .directory~new
  d["schema"] = "flylo.channel.result/0.4"
  d["commandId"] = command~commandId
  d["operation"] = command~operation
  d["idempotencyKey"] = command~idempotencyKey
  d["ok"] = handled~ok
  d["code"] = handled~code
  d["detail"] = handled~detail
  if handled~value <> .nil then do
    if handled~value~isA(.Directory) then do key over handled~value
      d[key] = handled~value[key]
    end
    else d["value"] = handled~value
  end
  return d
::method rebuildFromRetained
  expose topology journey booking
  inventoryCount = 0
  bookingCount = 0
  do publication over topology~topics~retainedPublications
    if publication~topicName = .FlyLoServiceTopology~INVENTORY_TOPIC then do
      applied = journey~applyInventoryProjection(publication~payload)
      if \applied~ok then return applied
      inventoryCount += 1
    end
    else if publication~topicName = .FlyLoServiceTopology~BOOKING_TOPIC then do
      applied = booking~applyProjection(publication~payload)
      if \applied~ok then return applied
      bookingCount += 1
    end
  end
  d = .directory~new
  d["inventoryCount"] = inventoryCount
  d["bookingCount"] = bookingCount
  return .FlyLoEngineResult~success(d)
::method submitJourney
  expose topology
  use arg command
  return topology~manager~put(.FlyLoServiceTopology~JOURNEY_COMMANDS, command~asPayload, self~options(command~commandId), .FlyLoServiceTopology~CHANNEL_PRINCIPAL)
::method submitBooking
  expose topology
  use arg command
  return topology~manager~put(.FlyLoServiceTopology~BOOKING_COMMANDS, command~asPayload, self~options(command~commandId), .FlyLoServiceTopology~CHANNEL_PRINCIPAL)
::method submitOperations
  expose topology
  use arg command
  return topology~manager~put(.FlyLoServiceTopology~OPERATIONS_COMMANDS, command~asPayload, self~options(command~commandId), .FlyLoServiceTopology~CHANNEL_PRINCIPAL)
::method rollbackFailure private
  expose topology
  use arg uow, code, detail = ""
  rb = topology~manager~rollbackUnitOfWork(uow)
  if rb~ok = .false then detail ||= "; rollback=" || rb~code || ":" || rb~detail
  return .FlyLoEngineResult~failure(code, detail)
::method commandFromPackage private
  use arg package
  if package == .nil then return .nil
  p = package~payload
  if p == .nil | \p~isA(.Directory) then return .nil
  if \p~hasIndex("operation") | \p~hasIndex("commandId") | \p~hasIndex("idempotencyKey") then return .nil
  return .FlyLoEngineCommand~fromPayload(p)
::method processJourneyOne
  expose topology journey
  manager = topology~manager
  begun = manager~beginUnitOfWork(.FlyLoServiceTopology~JOURNEY_WORKER)
  if \begun~ok then return .FlyLoEngineResult~failure("JOURNEY_UOW_BEGIN_FAILED", begun~code)
  uow = begun~value
  got = manager~uowGet(uow, .FlyLoServiceTopology~JOURNEY_COMMANDS)
  if \got~ok then return self~rollbackFailure(uow, "JOURNEY_QUEUE_GET_FAILED", got~code)
  command = self~commandFromPackage(got~value)
  if command == .nil then return self~rollbackFailure(uow, "MALFORMED_JOURNEY_COMMAND")
  select
    when command~operation = "SEARCH" then handled = journey~search(command~detail("origin"), command~detail("destination"), command~detail("travelDate"), command~detail("passengers", 1))
    otherwise handled = .FlyLoEngineResult~failure("JOURNEY_OPERATION_UNKNOWN", command~operation)
  end
  staged = manager~uowPut(uow, .FlyLoServiceTopology~JOURNEY_RESULTS, self~resultPayload(command, handled), self~options(command~commandId))
  if \staged~ok then return self~rollbackFailure(uow, "JOURNEY_RESULT_STAGE_FAILED", staged~code)
  committed = manager~commitUnitOfWork(uow)
  if \committed~ok then return .FlyLoEngineResult~failure("JOURNEY_UOW_COMMIT_FAILED", committed~code)
  return handled
::method processBookingCommandOne
  expose topology booking
  manager = topology~manager
  begun = manager~beginUnitOfWork(.FlyLoServiceTopology~BOOKING_WORKER)
  if \begun~ok then return .FlyLoEngineResult~failure("BOOKING_UOW_BEGIN_FAILED", begun~code)
  uow = begun~value
  got = manager~uowGet(uow, .FlyLoServiceTopology~BOOKING_COMMANDS)
  if \got~ok then return self~rollbackFailure(uow, "BOOKING_QUEUE_GET_FAILED", got~code)
  command = self~commandFromPackage(got~value)
  if command == .nil then return self~rollbackFailure(uow, "MALFORMED_BOOKING_COMMAND")
  if command~operation = "BOOKING_LOOKUP" then do
    handled = booking~lookup(command~detail("bookingRef"), command~detail("familyName"))
    staged = manager~uowPut(uow, .FlyLoServiceTopology~BOOKING_RESULTS, self~resultPayload(command, handled), self~options(command~commandId))
    if \staged~ok then return self~rollbackFailure(uow, "BOOKING_LOOKUP_RESULT_STAGE_FAILED", staged~code)
    committed = manager~commitUnitOfWork(uow)
    if \committed~ok then return .FlyLoEngineResult~failure("BOOKING_LOOKUP_UOW_COMMIT_FAILED", committed~code)
    return handled
  end
  if command~operation = "BOOKING_ADD_CHECKED_BAG" then do
    handled = booking~addCheckedBags(command~detail("bookingRef"), command~detail("passengerIds"), command~detail("quantity",1), command~detail("paymentAuthorizationId"), command~idempotencyKey)
    if handled~ok then do
      published = topology~publishBookingProjection(handled~value, command~commandId)
      if \published~ok then return self~rollbackFailure(uow, "BOOKING_ANCILLARY_PROJECTION_PUBLISH_FAILED", published~code || ":" || published~detail)
    end
    staged = manager~uowPut(uow, .FlyLoServiceTopology~BOOKING_RESULTS, self~resultPayload(command, handled), self~options(command~commandId))
    if \staged~ok then return self~rollbackFailure(uow, "BOOKING_ANCILLARY_RESULT_STAGE_FAILED", staged~code)
    committed = manager~commitUnitOfWork(uow)
    if \committed~ok then return .FlyLoEngineResult~failure("BOOKING_ANCILLARY_UOW_COMMIT_FAILED", committed~code)
    return handled
  end
  if command~operation <> "BOOKING_CREATE" then do
    handled = .FlyLoEngineResult~failure("BOOKING_OPERATION_UNKNOWN", command~operation)
    staged = manager~uowPut(uow, .FlyLoServiceTopology~BOOKING_RESULTS, self~resultPayload(command, handled), self~options(command~commandId))
    if \staged~ok then return self~rollbackFailure(uow, "BOOKING_RESULT_STAGE_FAILED", staged~code)
    committed = manager~commitUnitOfWork(uow)
    if \committed~ok then return .FlyLoEngineResult~failure("BOOKING_UOW_COMMIT_FAILED", committed~code)
    return handled
  end

  prepared = booking~prepare(command)
  if \prepared~ok then do
    staged = manager~uowPut(uow, .FlyLoServiceTopology~BOOKING_RESULTS, self~resultPayload(command, prepared), self~options(command~commandId))
    if \staged~ok then return self~rollbackFailure(uow, "BOOKING_FAILURE_RESULT_STAGE_FAILED", staged~code)
    committed = manager~commitUnitOfWork(uow)
    if \committed~ok then return .FlyLoEngineResult~failure("BOOKING_FAILURE_UOW_COMMIT_FAILED", committed~code)
    return prepared
  end
  if prepared~detail = "booking replay" then do
    staged = manager~uowPut(uow, .FlyLoServiceTopology~BOOKING_RESULTS, self~resultPayload(command, prepared), self~options(command~commandId))
    if \staged~ok then return self~rollbackFailure(uow, "BOOKING_REPLAY_RESULT_STAGE_FAILED", staged~code)
    committed = manager~commitUnitOfWork(uow)
    if \committed~ok then return .FlyLoEngineResult~failure("BOOKING_REPLAY_UOW_COMMIT_FAILED", committed~code)
    return prepared
  end
  instruction = prepared~value
  staged = manager~uowPut(uow, .FlyLoServiceTopology~INVENTORY_COMMANDS, instruction, self~options(command~commandId))
  if \staged~ok then return self~rollbackFailure(uow, "INVENTORY_REQUEST_STAGE_FAILED", staged~code)
  committed = manager~commitUnitOfWork(uow)
  if \committed~ok then return .FlyLoEngineResult~failure("BOOKING_PREPARE_UOW_COMMIT_FAILED", committed~code)
  return prepared
::method processInventoryOne
  expose topology journey
  manager = topology~manager
  begun = manager~beginUnitOfWork(.FlyLoServiceTopology~JOURNEY_WORKER)
  if \begun~ok then return .FlyLoEngineResult~failure("INVENTORY_UOW_BEGIN_FAILED", begun~code)
  uow = begun~value
  got = manager~uowGet(uow, .FlyLoServiceTopology~INVENTORY_COMMANDS)
  if \got~ok then return self~rollbackFailure(uow, "INVENTORY_QUEUE_GET_FAILED", got~code)
  instruction = got~value~payload
  if instruction == .nil | \instruction~isA(.Directory) then return self~rollbackFailure(uow, "MALFORMED_INVENTORY_COMMAND")
  if instruction["schema"] <> "flylo.booking.inventory-request/0.4" then return self~rollbackFailure(uow, "INVENTORY_COMMAND_SCHEMA_INVALID")
  committedInventory = journey~commitOffer(instruction["bookingId"], instruction["inventoryIdempotencyKey"], instruction["offer"], instruction["passengerCount"])
  if committedInventory~ok then do
    published = topology~publishInventoryProjection(committedInventory~value, instruction["commandId"])
    if \published~ok then return self~rollbackFailure(uow, "INVENTORY_PROJECTION_PUBLISH_FAILED", published~code || ":" || published~detail)
  end
  outcome = .directory~new
  outcome["schema"] = "flylo.booking.inventory-outcome/0.4"
  outcome["commandId"] = instruction["commandId"]
  outcome["bookingRequest"] = instruction
  outcome["ok"] = committedInventory~ok
  outcome["code"] = committedInventory~code
  outcome["detail"] = committedInventory~detail
  if committedInventory~value <> .nil then outcome["inventoryProjection"] = committedInventory~value
  staged = manager~uowPut(uow, .FlyLoServiceTopology~INVENTORY_OUTCOMES, outcome, self~options(instruction["commandId"]))
  if \staged~ok then return self~rollbackFailure(uow, "INVENTORY_OUTCOME_STAGE_FAILED", staged~code)
  committed = manager~commitUnitOfWork(uow)
  if \committed~ok then return .FlyLoEngineResult~failure("INVENTORY_UOW_COMMIT_FAILED", committed~code)
  return committedInventory
::method processBookingOutcomeOne
  expose topology booking
  manager = topology~manager
  begun = manager~beginUnitOfWork(.FlyLoServiceTopology~BOOKING_WORKER)
  if \begun~ok then return .FlyLoEngineResult~failure("BOOKING_OUTCOME_UOW_BEGIN_FAILED", begun~code)
  uow = begun~value
  got = manager~uowGet(uow, .FlyLoServiceTopology~INVENTORY_OUTCOMES)
  if \got~ok then return self~rollbackFailure(uow, "BOOKING_OUTCOME_GET_FAILED", got~code)
  outcome = got~value~payload
  if outcome == .nil | \outcome~isA(.Directory) then return self~rollbackFailure(uow, "MALFORMED_BOOKING_OUTCOME")
  handled = booking~finalize(outcome)
  request = outcome["bookingRequest"]
  command = .FlyLoEngineCommand~new(request["commandId"], "BOOKING_CREATE", request["idempotencyKey"], .directory~new, request["requestedAt"])
  if handled~ok then do
    published = topology~publishBookingProjection(handled~value, command~commandId)
    if \published~ok then return self~rollbackFailure(uow, "BOOKING_PROJECTION_PUBLISH_FAILED", published~code || ":" || published~detail)
  end
  staged = manager~uowPut(uow, .FlyLoServiceTopology~BOOKING_RESULTS, self~resultPayload(command, handled), self~options(command~commandId))
  if \staged~ok then return self~rollbackFailure(uow, "BOOKING_FINAL_RESULT_STAGE_FAILED", staged~code)
  committed = manager~commitUnitOfWork(uow)
  if \committed~ok then return .FlyLoEngineResult~failure("BOOKING_OUTCOME_UOW_COMMIT_FAILED", committed~code)
  return handled
::method processOperationsOne
  expose topology operations
  manager = topology~manager
  begun = manager~beginUnitOfWork(.FlyLoServiceTopology~OPERATIONS_WORKER)
  if \begun~ok then return .FlyLoEngineResult~failure("OPERATIONS_UOW_BEGIN_FAILED", begun~code)
  uow = begun~value
  got = manager~uowGet(uow, .FlyLoServiceTopology~OPERATIONS_COMMANDS)
  if \got~ok then return self~rollbackFailure(uow, "OPERATIONS_QUEUE_GET_FAILED", got~code)
  command = self~commandFromPackage(got~value)
  if command == .nil then return self~rollbackFailure(uow, "MALFORMED_OPERATIONS_COMMAND")
  select
    when command~operation = "FLIGHT_STATUS" then handled = operations~flightStatus(command~detail("flightNo"), command~detail("flightDate"))
    otherwise handled = .FlyLoEngineResult~failure("OPERATIONS_OPERATION_UNKNOWN", command~operation)
  end
  staged = manager~uowPut(uow, .FlyLoServiceTopology~OPERATIONS_RESULTS, self~resultPayload(command, handled), self~options(command~commandId))
  if \staged~ok then return self~rollbackFailure(uow, "OPERATIONS_RESULT_STAGE_FAILED", staged~code)
  committed = manager~commitUnitOfWork(uow)
  if \committed~ok then return .FlyLoEngineResult~failure("OPERATIONS_UOW_COMMIT_FAILED", committed~code)
  return handled
::method hasReady private
  expose topology
  use arg queueName
  q = topology~manager~queue(queueName)
  if q == .nil then return .false
  return q~readyDepth > 0
::method drain
  use arg maxIterations = 100
  count = 0
  do while count < maxIterations
    progressed = .false
    if self~hasReady(.FlyLoServiceTopology~JOURNEY_COMMANDS) then do; ignored = self~processJourneyOne; progressed = .true; count += 1; end
    if self~hasReady(.FlyLoServiceTopology~BOOKING_COMMANDS) then do; ignored = self~processBookingCommandOne; progressed = .true; count += 1; end
    if self~hasReady(.FlyLoServiceTopology~INVENTORY_COMMANDS) then do; ignored = self~processInventoryOne; progressed = .true; count += 1; end
    if self~hasReady(.FlyLoServiceTopology~INVENTORY_OUTCOMES) then do; ignored = self~processBookingOutcomeOne; progressed = .true; count += 1; end
    if self~hasReady(.FlyLoServiceTopology~OPERATIONS_COMMANDS) then do; ignored = self~processOperationsOne; progressed = .true; count += 1; end
    if \progressed then leave
  end
  return count
::method requestJourney
  expose topology
  use arg command
  submitted = self~submitJourney(command)
  if \submitted~ok then return submitted
  ignored = self~drain
  return topology~manager~get(.FlyLoServiceTopology~JOURNEY_RESULTS, .FlyLoServiceTopology~CHANNEL_PRINCIPAL)
::method requestBooking
  expose topology
  use arg command
  submitted = self~submitBooking(command)
  if \submitted~ok then return submitted
  ignored = self~drain
  return topology~manager~get(.FlyLoServiceTopology~BOOKING_RESULTS, .FlyLoServiceTopology~CHANNEL_PRINCIPAL)
::method requestOperations
  expose topology
  use arg command
  submitted = self~submitOperations(command)
  if \submitted~ok then return submitted
  ignored = self~drain
  return topology~manager~get(.FlyLoServiceTopology~OPERATIONS_RESULTS, .FlyLoServiceTopology~CHANNEL_PRINCIPAL)


::class FlyLoBackendFactory public
::method fixture class
  use arg durableRoot = ""
  manager = .ObjectQueueManager~new(durableRoot, .QueueGraphPayloadCodec~new, .FlyLoServiceTopology~ADMIN_PRINCIPAL)
  topology = .FlyLoServiceTopology~new(manager)
  schedule = .FlyLoScheduleRegistry~fixture
  journey = .FlyLoJourneyAuthority~new(schedule)
  booking = .FlyLoBookingAuthority~new
  operations = .FlyLoOperationsAuthority~new(schedule)
  return .FlyLoBackendRuntime~new(topology, journey, booking, operations)

::requires "FlyLoEngine.cls"
::requires "ObjectQueueFabric.cls"
::requires "ObjectQueueTopics.cls"
