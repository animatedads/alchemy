/* Queue Fabric graph persistence for Branch Day Service v0.1. */
::class FederationBankBranchDayEndpointFactory public
::method newBlank
  return .FederationBankBranchDayEndpointEvidence~new("RESTORE","VAULT","RESTORE","RESTORE-BRANCH","GBP","OPEN",0,0,0,"RESTORE-CUSTODY","RESTORE-SOURCE")
::class FederationBankBranchDayPositionFactory public
::method newBlank
  return .FederationBankBranchDayPositionEvidence~new("RESTORE","RESTORE-BRANCH","GBP",0,0,0,0,0,"RESTORE-SOURCE")
::class FederationBankBranchDayTotalsFactory public
::method newBlank
  return .FederationBankBranchDayControlTotals~new("GBP",0,0,0,0,0,0,"",0,"RESTORE-SOURCE")
::class FederationBankBranchDayApprovalFactory public
::method newBlank
  return .FederationBankBranchDayApproval~new("RESTORE","RESTORE","RESTORE","RESTORE-AUTH")
::class FederationBankBranchDayFactory public
::method newBlank
  return .FederationBankBranchDay~new("RESTORE","RESTORE-BRANCH","1970-01-01")
::class FederationBankBranchDayServiceEnvelopeFactory public
::method newBlank
  return .FederationBankBranchDayServiceEnvelope~new("RESTORE","RESTORE","RESTORE")
::class FederationBankBranchDayServiceReplyFactory public
::method newBlank
  return .FederationBankBranchDayServiceReply~new("RESTORE","RESTORE",.false,"RESTORE")
::class FederationBankBranchDayServiceReceiptFactory public
::method newBlank
  return .FederationBankBranchDayServiceReceipt~new("RESTORE","RESTORE","RESTORE",.false,"RESTORE")
::class FederationBankBranchDayServiceEventFactory public
::method newBlank
  return .FederationBankBranchDayServiceEvent~new("RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE")
::class FederationBankBranchDayServiceStateFactory public
::method newBlank
  return .FederationBankBranchDayServiceState~new

::class FederationBankBranchDayServicePersistenceSupport public
::method registerTypes class
  use arg codec
  if codec==.nil | \codec~hasMethod("TYPEREGISTRY") then return .false
  r=codec~typeRegistry
  ignore=r~register("federationbank.branch.day.endpoint/1",.FederationBankBranchDayEndpointFactory~new)
  ignore=r~register("federationbank.branch.day.position/1",.FederationBankBranchDayPositionFactory~new)
  ignore=r~register("federationbank.branch.day.totals/1",.FederationBankBranchDayTotalsFactory~new)
  ignore=r~register("federationbank.branch.day.approval/1",.FederationBankBranchDayApprovalFactory~new)
  ignore=r~register("federationbank.branch.day/1",.FederationBankBranchDayFactory~new)
  ignore=r~register("federationbank.branch.day.service.command/1",.FederationBankBranchDayServiceEnvelopeFactory~new)
  ignore=r~register("federationbank.branch.day.service.reply/1",.FederationBankBranchDayServiceReplyFactory~new)
  ignore=r~register("federationbank.branch.day.service.receipt/1",.FederationBankBranchDayServiceReceiptFactory~new)
  ignore=r~register("federationbank.branch.day.service.event/1",.FederationBankBranchDayServiceEventFactory~new)
  ignore=r~register(.FederationBankBranchDayServiceBuild~STATE_FORMAT,.FederationBankBranchDayServiceStateFactory~new)
  return .true
::method newCodec class
  codec=.QueueGraphPayloadCodec~new; ignore=self~registerTypes(codec); return codec

::class FederationBankBranchDayServiceStore public
::method init
  expose durableStore codec
  use arg rootArg,codecArg=.nil,recordProtector=.nil,recoveryMode="STRICT"
  if codecArg==.nil then codec=.FederationBankBranchDayServicePersistenceSupport~newCodec
  else do; codec=codecArg; ignore=.FederationBankBranchDayServicePersistenceSupport~registerTypes(codec); end
  durableStore=.QueueDurableStore~new(rootArg~string,recordProtector,recoveryMode)
::method save
  expose durableStore codec
  use arg state
  signal on syntax name saveFailure
  graph=codec~encode(state); ignore=durableStore~appendJournal("FBBRANCHDAYSTATE",.array~of(.FederationBankBranchDayServiceBuild~STATE_FORMAT,graph)); signal off syntax
  return .FederationBankBranchDayServiceResult~success(state)
saveFailure:
  signal off syntax
  return .FederationBankBranchDayServiceResult~failure("STATE_SAVE_FAILED",condition("D"))
::method load
  expose durableStore codec
  signal on syntax name loadFailure
  rows=durableStore~readJournal; graph=""
  do row over rows
    if row~items>=3 then if row[1]="FBBRANCHDAYSTATE" & row[2]=.FederationBankBranchDayServiceBuild~STATE_FORMAT then graph=row[3]
  end
  if graph="" then return .FederationBankBranchDayServiceResult~success(.FederationBankBranchDayServiceState~new,"new store")
  state=codec~decode(graph); if \state~isA(.FederationBankBranchDayServiceState) then return .FederationBankBranchDayServiceResult~failure("STATE_TYPE_INVALID")
  signal off syntax; return .FederationBankBranchDayServiceResult~success(state)
loadFailure:
  signal off syntax
  return .FederationBankBranchDayServiceResult~failure("STATE_LOAD_FAILED",condition("D"))

::requires "FederationBankBranchDayService.cls"
::requires "ObjectQueueFabric.cls"
