::class FederationBankRelationshipDecisionFactory public
::method newBlank
  return .FederationBankRelationshipDecision~new("RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","NONE")
::class FederationBankRelationshipRequestFactory public
::method newBlank
  return .FederationBankRelationshipActionRequest~new("RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","NONE","RESTORE","SYSTEM")
::class FederationBankRelationshipServiceEnvelopeFactory public
::method newBlank
  return .FederationBankRelationshipServiceEnvelope~new("RESTORE","RESTORE","RESTORE","SYSTEM")
::class FederationBankRelationshipServiceReplyFactory public
::method newBlank
  return .FederationBankRelationshipServiceReply~new("RESTORE","RESTORE",.false,"RESTORE")
::class FederationBankRelationshipActionRecordFactory public
::method newBlank
  return .FederationBankRelationshipActionRecord~new("RESTORE","RESTORE","RESTORE","RESTORE","NONE")
::class FederationBankRelationshipServiceEventFactory public
::method newBlank
  return .FederationBankRelationshipServiceEvent~new("RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE",.DateTime~new,"0")
::class FederationBankRelationshipServiceReceiptFactory public
::method newBlank
  return .FederationBankRelationshipServiceReceipt~new("RESTORE","RESTORE","RESTORE")
::class FederationBankRelationshipServiceStateFactory public
::method newBlank
  return .FederationBankRelationshipServiceState~new

::class FederationBankRelationshipServicePersistenceSupport public
::method registerTypes class
  use arg codec
  if codec==.nil | \codec~hasMethod("TYPEREGISTRY") then return .false
  ignore=.RelationshipCaseQueuePersistenceSupport~registerTypes(codec)
  r=codec~typeRegistry
  ignore=r~register("federationbank.relationship.decision/1",.FederationBankRelationshipDecisionFactory~new)
  ignore=r~register("federationbank.relationship.action.request/1",.FederationBankRelationshipRequestFactory~new)
  ignore=r~register("federationbank.relationship.adapter.service.command/1",.FederationBankRelationshipServiceEnvelopeFactory~new)
  ignore=r~register("federationbank.relationship.adapter.service.reply/1",.FederationBankRelationshipServiceReplyFactory~new)
  ignore=r~register("federationbank.relationship.adapter.service.action/1",.FederationBankRelationshipActionRecordFactory~new)
  ignore=r~register("federationbank.relationship.adapter.service.event/1",.FederationBankRelationshipServiceEventFactory~new)
  ignore=r~register("federationbank.relationship.adapter.service.receipt/1",.FederationBankRelationshipServiceReceiptFactory~new)
  ignore=r~register(.FederationBankRelationshipAdapterServiceBuild~STATE_FORMAT,.FederationBankRelationshipServiceStateFactory~new)
  return .true
::method newCodec class
  codec=.QueueGraphPayloadCodec~new; ignore=self~registerTypes(codec); return codec

::class FederationBankRelationshipServiceStore public
::method init
  expose root durableStore codec
  use arg rootArg,codecArg=.nil,recordProtector=.nil,recoveryMode="STRICT"
  root=rootArg~string
  if codecArg==.nil then codec=.FederationBankRelationshipServicePersistenceSupport~newCodec
  else do; codec=codecArg; ignore=.FederationBankRelationshipServicePersistenceSupport~registerTypes(codec); end
  durableStore=.QueueDurableStore~new(root,recordProtector,recoveryMode)
::method save
  expose durableStore codec
  use arg state
  signal on syntax name saveFailure
  graph=codec~encode(state); ignore=durableStore~appendJournal("FBRELSTATE",.array~of(.FederationBankRelationshipAdapterServiceBuild~STATE_FORMAT,graph)); signal off syntax
  return .FederationBankRelationshipServiceResult~success(state)
saveFailure:
  signal off syntax
  return .FederationBankRelationshipServiceResult~failure("STATE_SAVE_FAILED",condition("D"))
::method load
  expose durableStore codec
  signal on syntax name loadFailure
  rows=durableStore~readJournal; graph=""
  do row over rows
    if row~items>=3 then if row[1]="FBRELSTATE" & row[2]=.FederationBankRelationshipAdapterServiceBuild~STATE_FORMAT then graph=row[3]
  end
  if graph="" then return .FederationBankRelationshipServiceResult~success(.FederationBankRelationshipServiceState~new,"new store")
  state=codec~decode(graph)
  if \state~isA(.FederationBankRelationshipServiceState) then return .FederationBankRelationshipServiceResult~failure("STATE_TYPE_INVALID")
  signal off syntax
  return .FederationBankRelationshipServiceResult~success(state)
loadFailure:
  signal off syntax
  return .FederationBankRelationshipServiceResult~failure("STATE_LOAD_FAILED",condition("D"))

::requires "FederationBankRelationshipAdapterService.cls"
::requires "RelationshipCaseQueuePersistence.cls"
::requires "ObjectQueueFabric.cls"
