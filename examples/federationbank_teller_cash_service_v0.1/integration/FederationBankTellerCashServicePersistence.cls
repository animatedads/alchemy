/* Queue Fabric graph persistence for FederationBank Teller Cash Service v0.1. */

::class FederationBankTellerCashInstructionFactory public
::method newBlank
  d=.directory~new
  bundle=.FederationBankCashBundle~new("GBP",d)
  ctx=.FederationBankTillCustodyContext~new("RESTORE-TILL","RESTORE-BRANCH","RESTORE-STAFF","RESTORE-SESSION","RESTORE-WS","RESTORE-CUSTODY")
  return .FederationBankTellerCashInstruction~new("RESTORE-WORK","RESTORE-COMMAND","WITHDRAWAL","RESTORE-TILL","RESTORE-SETTLEMENT",bundle,ctx)

::class FederationBankTellerCashServiceEnvelopeFactory public
::method newBlank
  return .FederationBankTellerCashServiceEnvelope~new("RESTORE","RESTORE","RESTORE","RESTORE")

::class FederationBankTellerCashServiceReplyFactory public
::method newBlank
  return .FederationBankTellerCashServiceReply~new("RESTORE","RESTORE",.false,"RESTORE")

::class FederationBankTellerCashServiceReceiptFactory public
::method newBlank
  return .FederationBankTellerCashServiceReceipt~new("RESTORE","RESTORE","RESTORE")

::class FederationBankTellerCashServiceEventFactory public
::method newBlank
  return .FederationBankTellerCashServiceEvent~new("RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","",.DateTime~new,0)

::class FederationBankTellerCashServiceWorkFactory public
::method newBlank
  c=.FederationBankStaffChannelCommandSnapshot~new("RESTORE-COMMAND","CASH_WITHDRAWAL","RESTORE-IDEM","RESTORE-CUSTOMER","RESTORE-ACCOUNT","","GBP",0,"STAFF","RESTORE-STAFF")~seal
  r=.FederationBankStaffChannelRequest~new("RESTORE-REQUEST","RESTORE-STAFF-WORK","CUSTOMER_INSTRUCTION","RESTORE-STAFF","RESTORE-SESSION","RESTORE-BRANCH","RESTORE-DESK",c)~seal
  d=.directory~new
  bundle=.FederationBankCashBundle~new("GBP",d)
  ctx=.FederationBankTillCustodyContext~new("RESTORE-TILL","RESTORE-BRANCH","RESTORE-STAFF","RESTORE-SESSION","RESTORE-WS","RESTORE-CUSTODY")
  i=.FederationBankTellerCashInstruction~new("RESTORE-CASH-WORK","RESTORE-COMMAND","WITHDRAWAL","RESTORE-TILL","RESTORE-SETTLEMENT",bundle,ctx)
  return .FederationBankTellerCashServiceWork~new(r,i)

::class FederationBankTellerCashServiceStateFactory public
::method newBlank
  return .FederationBankTellerCashServiceState~new

::class FederationBankTellerCashServicePersistenceSupport public
::method registerTypes class
  use arg codec
  if codec==.nil | \codec~hasMethod("TYPEREGISTRY") then return .false
  ignore=.FederationBankStaffChannelServicePersistenceSupport~registerTypes(codec)
  r=codec~typeRegistry
  ignore=r~register("federationbank.teller.cash.instruction/1",.FederationBankTellerCashInstructionFactory~new)
  ignore=r~register("federationbank.teller.cash.service.command/1",.FederationBankTellerCashServiceEnvelopeFactory~new)
  ignore=r~register("federationbank.teller.cash.service.reply/1",.FederationBankTellerCashServiceReplyFactory~new)
  ignore=r~register("federationbank.teller.cash.service.receipt/1",.FederationBankTellerCashServiceReceiptFactory~new)
  ignore=r~register("federationbank.teller.cash.service.event/1",.FederationBankTellerCashServiceEventFactory~new)
  ignore=r~register("federationbank.teller.cash.service.work/1",.FederationBankTellerCashServiceWorkFactory~new)
  ignore=r~register(.FederationBankTellerCashServiceBuild~STATE_FORMAT,.FederationBankTellerCashServiceStateFactory~new)
  return .true
::method newCodec class
  codec=.QueueGraphPayloadCodec~new; ignore=self~registerTypes(codec); return codec

::class FederationBankTellerCashServiceStore public
::method init
  expose root durableStore codec
  use arg rootArg,codecArg=.nil,recordProtector=.nil,recoveryMode="STRICT"
  root=rootArg~string
  if codecArg==.nil then codec=.FederationBankTellerCashServicePersistenceSupport~newCodec
  else do; codec=codecArg; ignore=.FederationBankTellerCashServicePersistenceSupport~registerTypes(codec); end
  durableStore=.QueueDurableStore~new(root,recordProtector,recoveryMode)
::method save
  expose durableStore codec
  use arg state
  signal on syntax name saveFailure
  graph=codec~encode(state); ignore=durableStore~appendJournal("FBTELCASHSTATE",.array~of(.FederationBankTellerCashServiceBuild~STATE_FORMAT,graph)); signal off syntax
  return .FederationBankTellerCashServiceResult~success(state)
saveFailure:
  signal off syntax
  return .FederationBankTellerCashServiceResult~failure("STATE_SAVE_FAILED",condition("D"))
::method load
  expose durableStore codec
  signal on syntax name loadFailure
  rows=durableStore~readJournal; graph=""
  do row over rows
    if row~items>=3 then if row[1]="FBTELCASHSTATE" & row[2]=.FederationBankTellerCashServiceBuild~STATE_FORMAT then graph=row[3]
  end
  if graph="" then return .FederationBankTellerCashServiceResult~success(.FederationBankTellerCashServiceState~new,"new store")
  state=codec~decode(graph)
  if \state~isA(.FederationBankTellerCashServiceState) then return .FederationBankTellerCashServiceResult~failure("STATE_TYPE_INVALID")
  signal off syntax
  return .FederationBankTellerCashServiceResult~success(state)
loadFailure:
  signal off syntax
  return .FederationBankTellerCashServiceResult~failure("STATE_LOAD_FAILED",condition("D"))

::requires "FederationBankTellerCashService.cls"
::requires "FederationBankStaffChannelServicePersistence.cls"
::requires "ObjectQueueFabric.cls"
