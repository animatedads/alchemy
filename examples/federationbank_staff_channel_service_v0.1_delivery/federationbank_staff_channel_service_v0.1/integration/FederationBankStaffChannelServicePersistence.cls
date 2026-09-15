::class FederationBankStaffChannelCommandFactory public
::method newBlank
  return .FederationBankStaffChannelCommandSnapshot~new("RESTORE","RESTORE","RESTORE","RESTORE","","","",0,"STAFF","RESTORE")
::class FederationBankStaffChannelRelationshipEvidenceFactory public
::method newBlank
  return .FederationBankStaffChannelRelationshipEvidence~new("NO_BANK_ACTION","RESTORE","RESTORE","RESTORE")
::class FederationBankStaffChannelRequestFactory public
::method newBlank
  c=.FederationBankStaffChannelCommandSnapshot~new("RESTORE","RESTORE","RESTORE","RESTORE","","","",0,"STAFF","RESTORE")~seal
  return .FederationBankStaffChannelRequest~new("RESTORE","RESTORE","CUSTOMER_INSTRUCTION","RESTORE","RESTORE","RESTORE","RESTORE",c)
::class FederationBankStaffChannelWorkFactory public
::method newBlank
  c=.FederationBankStaffChannelCommandSnapshot~new("RESTORE","RESTORE","RESTORE","RESTORE","","","",0,"STAFF","RESTORE")~seal
  r=.FederationBankStaffChannelRequest~new("RESTORE","RESTORE","CUSTOMER_INSTRUCTION","RESTORE","RESTORE","RESTORE","RESTORE",c)~seal
  return .FederationBankStaffChannelWorkItem~new(r)
::class FederationBankStaffChannelServiceEnvelopeFactory public
::method newBlank
  return .FederationBankStaffChannelServiceEnvelope~new("RESTORE","RESTORE","RESTORE","RESTORE")
::class FederationBankStaffChannelServiceReplyFactory public
::method newBlank
  return .FederationBankStaffChannelServiceReply~new("RESTORE","RESTORE",.false,"RESTORE")
::class FederationBankStaffChannelServiceReceiptFactory public
::method newBlank
  return .FederationBankStaffChannelServiceReceipt~new("RESTORE","RESTORE")
::class FederationBankStaffChannelServiceEventFactory public
::method newBlank
  return .FederationBankStaffChannelServiceEvent~new("RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE",.DateTime~new,0)
::class FederationBankStaffChannelServiceStateFactory public
::method newBlank
  return .FederationBankStaffChannelServiceState~new

::class FederationBankStaffChannelServicePersistenceSupport public
::method registerTypes class
  use arg codec
  if codec==.nil | \codec~hasMethod("TYPEREGISTRY") then return .false
  ignore=.FederationBankStaffAuthorityServicePersistenceSupport~registerTypes(codec)
  r=codec~typeRegistry
  ignore=r~register("federationbank.staff.channel.command/1",.FederationBankStaffChannelCommandFactory~new)
  ignore=r~register("federationbank.staff.channel.relationship.evidence/1",.FederationBankStaffChannelRelationshipEvidenceFactory~new)
  ignore=r~register("federationbank.staff.channel.request/1",.FederationBankStaffChannelRequestFactory~new)
  ignore=r~register("federationbank.staff.channel.work/1",.FederationBankStaffChannelWorkFactory~new)
  ignore=r~register("federationbank.staff.channel.service.command/1",.FederationBankStaffChannelServiceEnvelopeFactory~new)
  ignore=r~register("federationbank.staff.channel.service.reply/1",.FederationBankStaffChannelServiceReplyFactory~new)
  ignore=r~register("federationbank.staff.channel.service.receipt/1",.FederationBankStaffChannelServiceReceiptFactory~new)
  ignore=r~register("federationbank.staff.channel.service.event/1",.FederationBankStaffChannelServiceEventFactory~new)
  ignore=r~register(.FederationBankStaffChannelServiceBuild~STATE_FORMAT,.FederationBankStaffChannelServiceStateFactory~new)
  return .true
::method newCodec class
  codec=.QueueGraphPayloadCodec~new; ignore=self~registerTypes(codec); return codec

::class FederationBankStaffChannelServiceStore public
::method init
  expose root durableStore codec
  use arg rootArg,codecArg=.nil,recordProtector=.nil,recoveryMode="STRICT"
  root=rootArg~string
  if codecArg==.nil then codec=.FederationBankStaffChannelServicePersistenceSupport~newCodec
  else do; codec=codecArg; ignore=.FederationBankStaffChannelServicePersistenceSupport~registerTypes(codec); end
  durableStore=.QueueDurableStore~new(root,recordProtector,recoveryMode)
::method save
  expose durableStore codec
  use arg state
  signal on syntax name saveFailure
  graph=codec~encode(state); ignore=durableStore~appendJournal("FBSTAFFCHSTATE",.array~of(.FederationBankStaffChannelServiceBuild~STATE_FORMAT,graph)); signal off syntax
  return .FederationBankStaffChannelServiceResult~success(state)
saveFailure:
  signal off syntax
  return .FederationBankStaffChannelServiceResult~failure("STATE_SAVE_FAILED",condition("D"))
::method load
  expose durableStore codec
  signal on syntax name loadFailure
  rows=durableStore~readJournal; graph=""
  do row over rows
    if row~items>=3 then if row[1]="FBSTAFFCHSTATE" & row[2]=.FederationBankStaffChannelServiceBuild~STATE_FORMAT then graph=row[3]
  end
  if graph="" then return .FederationBankStaffChannelServiceResult~success(.FederationBankStaffChannelServiceState~new,"new store")
  state=codec~decode(graph)
  if \state~isA(.FederationBankStaffChannelServiceState) then return .FederationBankStaffChannelServiceResult~failure("STATE_TYPE_INVALID")
  signal off syntax
  return .FederationBankStaffChannelServiceResult~success(state)
loadFailure:
  signal off syntax
  return .FederationBankStaffChannelServiceResult~failure("STATE_LOAD_FAILED",condition("D"))

::requires "FederationBankStaffChannelService.cls"
::requires "FederationBankStaffAuthorityServicePersistence.cls"
::requires "ObjectQueueFabric.cls"
