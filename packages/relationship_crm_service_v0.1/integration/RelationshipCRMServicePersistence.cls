::class CRMServiceCommandFactory public
::method newBlank; return .RelationshipCRMServiceEnvelope~new("RESTORE","RESTORE","RESTORE","SYSTEM")
::class CRMServiceReplyFactory public
::method newBlank; return .RelationshipCRMServiceReply~new("RESTORE","RESTORE",.false,"RESTORE")
::class CRMServiceEventFactory public
::method newBlank; return .RelationshipCRMServiceEvent~new("RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","SYSTEM",.DateTime~new)
::class CRMServiceReceiptFactory public
::method newBlank; return .RelationshipCRMServiceReceipt~new("RESTORE","RESTORE","RESTORE")
::class CRMServiceStateFactory public
::method newBlank; return .RelationshipCRMServiceState~new

::class RelationshipCRMServicePersistenceSupport public
::method registerTypes class
  use arg codec
  ignore=.RelationshipCRMQueuePersistenceSupport~registerTypes(codec)
  r=codec~typeRegistry
  ignore=r~register("relationship.crm.service.command/1",.CRMServiceCommandFactory~new)
  ignore=r~register("relationship.crm.service.reply/1",.CRMServiceReplyFactory~new)
  ignore=r~register("relationship.crm.service.event/1",.CRMServiceEventFactory~new)
  ignore=r~register("relationship.crm.service.receipt/1",.CRMServiceReceiptFactory~new)
  ignore=r~register(.RelationshipCRMServiceBuild~STATE_FORMAT,.CRMServiceStateFactory~new)
  return .true
::method newCodec class
  codec=.QueueGraphPayloadCodec~new; ignore=self~registerTypes(codec); return codec

::class RelationshipCRMServiceStore public
::method init
  expose durableStore codec
  use arg rootArg,codecArg=.nil,recordProtector=.nil,recoveryMode="STRICT"
  if codecArg==.nil then codec=.RelationshipCRMServicePersistenceSupport~newCodec; else do; codec=codecArg; ignore=.RelationshipCRMServicePersistenceSupport~registerTypes(codec); end
  durableStore=.QueueDurableStore~new(rootArg~string,recordProtector,recoveryMode)
::method save
  expose durableStore codec
  use arg state
  signal on syntax name saveFailure
  graph=codec~encode(state); ignore=durableStore~appendJournal("CRMSTATE",.array~of(.RelationshipCRMServiceBuild~STATE_FORMAT,graph)); signal off syntax
  return .RelationshipCRMServiceResult~success(state)
saveFailure:
  signal off syntax; return .RelationshipCRMServiceResult~failure("STATE_SAVE_FAILED",condition("D"))
::method load
  expose durableStore codec
  signal on syntax name loadFailure
  rows=durableStore~readJournal; graph=""
  do row over rows
    if row~items>=3 then if row[1]="CRMSTATE" & row[2]=.RelationshipCRMServiceBuild~STATE_FORMAT then graph=row[3]
  end
  if graph="" then return .RelationshipCRMServiceResult~success(.RelationshipCRMServiceState~new,"new store")
  state=codec~decode(graph); if \state~isA(.RelationshipCRMServiceState) then return .RelationshipCRMServiceResult~failure("STATE_TYPE_INVALID")
  signal off syntax; return .RelationshipCRMServiceResult~success(state)
loadFailure:
  signal off syntax; return .RelationshipCRMServiceResult~failure("STATE_LOAD_FAILED",condition("D"))
::requires "RelationshipCRMService.cls"
::requires "RelationshipCRMQueuePersistence.cls"
::requires "ObjectQueueFabric.cls"
