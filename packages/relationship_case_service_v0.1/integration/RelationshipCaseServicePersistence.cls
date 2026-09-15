/* Durable service state over Queue Fabric's append-only, torn-tail-aware store. */
::class RelationshipCaseServiceCommandFactory public
::method newBlank
  return .RelationshipCaseServiceEnvelope~new("RESTORE", "RESTORE", "RESTORE", "SYSTEM")
::class RelationshipCaseServiceReplyFactory public
::method newBlank
  return .RelationshipCaseServiceReply~new("RESTORE", "RESTORE", .false, "RESTORE")
::class RelationshipCaseServiceEventFactory public
::method newBlank
  return .RelationshipCaseServiceEvent~new("RESTORE", "RESTORE", "RESTORE", "RESTORE", "RESTORE", "RESTORE", "SYSTEM", .DateTime~new, "0")
::class RelationshipCaseServiceReceiptFactory public
::method newBlank
  return .RelationshipCaseServiceReceipt~new("RESTORE", "RESTORE", "RESTORE")
::class RelationshipCaseServiceStateFactory public
::method newBlank
  return .RelationshipCaseServiceState~new

::class RelationshipCaseServicePersistenceSupport public
::method registerTypes class
  use arg codec
  if codec == .nil | \codec~hasMethod("TYPEREGISTRY") then return .false
  ignore = .RelationshipCaseQueuePersistenceSupport~registerTypes(codec)
  r = codec~typeRegistry
  ignore = r~register("relationship.case.service.command/1", .RelationshipCaseServiceCommandFactory~new)
  ignore = r~register("relationship.case.service.reply/1", .RelationshipCaseServiceReplyFactory~new)
  ignore = r~register("relationship.case.service.event/1", .RelationshipCaseServiceEventFactory~new)
  ignore = r~register("relationship.case.service.receipt/1", .RelationshipCaseServiceReceiptFactory~new)
  ignore = r~register(.RelationshipCaseServiceBuild~STATE_FORMAT, .RelationshipCaseServiceStateFactory~new)
  return .true
::method newCodec class
  codec = .QueueGraphPayloadCodec~new
  ignore = self~registerTypes(codec)
  return codec

::class RelationshipCaseServiceStore public
::attribute root get
::attribute durableStore get
::method init
  expose root durableStore codec
  use arg rootArg, codecArg = .nil, recordProtector = .nil, recoveryMode = "STRICT"
  root = rootArg~string
  if codecArg == .nil then codec = .RelationshipCaseServicePersistenceSupport~newCodec
  else do; codec = codecArg; ignore = .RelationshipCaseServicePersistenceSupport~registerTypes(codec); end
  durableStore = .QueueDurableStore~new(root, recordProtector, recoveryMode)
::method save
  expose durableStore codec
  use arg state
  signal on syntax name saveFailure
  graph = codec~encode(state)
  ignore = durableStore~appendJournal("CASESTATE", .array~of(.RelationshipCaseServiceBuild~STATE_FORMAT, graph))
  signal off syntax
  return .RelationshipCaseServiceResult~success(state)
saveFailure:
  signal off syntax
  return .RelationshipCaseServiceResult~failure("STATE_SAVE_FAILED", condition("D"))
::method load
  expose durableStore codec
  signal on syntax name loadFailure
  rows = durableStore~readJournal
  graph = ""
  do row over rows
    if row~items >= 3 then do
      if row[1] = "CASESTATE" & row[2] = .RelationshipCaseServiceBuild~STATE_FORMAT then graph = row[3]
    end
  end
  if graph = "" then return .RelationshipCaseServiceResult~success(.RelationshipCaseServiceState~new, "new store")
  state = codec~decode(graph)
  if \state~isA(.RelationshipCaseServiceState) then return .RelationshipCaseServiceResult~failure("STATE_TYPE_INVALID")
  signal off syntax
  return .RelationshipCaseServiceResult~success(state)
loadFailure:
  signal off syntax
  return .RelationshipCaseServiceResult~failure("STATE_LOAD_FAILED", condition("D"))

::requires "RelationshipCaseService.cls"
::requires "RelationshipCaseQueuePersistence.cls"
::requires "ObjectQueueFabric.cls"
