/* Queue Fabric graph persistence for Branch Cash Service v0.2. */
::class FederationBankBranchCashBundleFactory public
::method newBlank
  return .FederationBankBranchCashBundle~new("GBP",.directory~new)
::class FederationBankBranchCashApprovalFactory public
::method newBlank
  return .FederationBankBranchCashApproval~new("RESTORE","RESTORE","RESTORE","RESTORE")
::class FederationBankBranchCashAuthorityFactory public
::method newBlank
  return .FederationBankBranchCashAuthorityEnvelope~new("RESTORE-AUTH","RESTORE-TRANSFER-IDENTITY","RESTORE","RESTORE-BRANCH","VAULT","RESTORE-SOURCE","TILL","RESTORE-DEST",1,"GBP","RESTORE-STAFF","RESTORE-STAFF-AUTH","RESTORE-APPROVAL","RESTORE-CHECKER","RESTORE-POLICY")
::class FederationBankBranchCashTransferFactory public
::method newBlank
  b=.FederationBankBranchCashBundle~new("GBP",.directory~new)
  return .FederationBankBranchCashTransfer~new("RESTORE","RESTORE-BRANCH","VAULT","RESTORE-SOURCE","TILL","RESTORE-DEST",b,"RESTORE","RESTORE-STAFF","RESTORE-AUTH")
::class FederationBankBranchCashVaultFactory public
::method newBlank
  return .FederationBankBranchCashVault~new("RESTORE-VAULT","RESTORE-BRANCH","GBP")
::class FederationBankBranchCashServiceEnvelopeFactory public
::method newBlank
  return .FederationBankBranchCashServiceEnvelope~new("RESTORE","RESTORE","RESTORE","RESTORE")
::class FederationBankBranchCashServiceReplyFactory public
::method newBlank
  return .FederationBankBranchCashServiceReply~new("RESTORE","RESTORE",.false,"RESTORE")
::class FederationBankBranchCashServiceReceiptFactory public
::method newBlank
  return .FederationBankBranchCashServiceReceipt~new("RESTORE","RESTORE","RESTORE")
::class FederationBankBranchCashServiceEventFactory public
::method newBlank
  return .FederationBankBranchCashServiceEvent~new("RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE")
::class FederationBankBranchCashTransferWorkFactory public
::method newBlank
  t=.FederationBankBranchCashTransferFactory~new~newBlank; a=.FederationBankBranchCashApproval~new("RESTORE",t~semanticIdentity,"RESTORE-CHECKER","RESTORE-AUTH"); return .FederationBankBranchCashTransferWork~new("RESTORE","RESTORE",t,a)
::class FederationBankBranchCashServiceStateFactory public
::method newBlank
  return .FederationBankBranchCashServiceState~new

::class FederationBankBranchCashServicePersistenceSupport public
::method registerTypes class
  use arg codec
  if codec==.nil | \codec~hasMethod("TYPEREGISTRY") then return .false
  r=codec~typeRegistry
  ignore=r~register("federationbank.branch.cash.bundle/1",.FederationBankBranchCashBundleFactory~new)
  ignore=r~register("federationbank.branch.cash.approval/1",.FederationBankBranchCashApprovalFactory~new)
  ignore=r~register("federationbank.branch.cash.transfer/1",.FederationBankBranchCashTransferFactory~new)
  ignore=r~register("federationbank.branch.cash.authority/1",.FederationBankBranchCashAuthorityFactory~new)
  ignore=r~register("federationbank.branch.cash.vault/1",.FederationBankBranchCashVaultFactory~new)
  ignore=r~register("federationbank.branch.cash.service.command/1",.FederationBankBranchCashServiceEnvelopeFactory~new)
  ignore=r~register("federationbank.branch.cash.service.reply/1",.FederationBankBranchCashServiceReplyFactory~new)
  ignore=r~register("federationbank.branch.cash.service.receipt/1",.FederationBankBranchCashServiceReceiptFactory~new)
  ignore=r~register("federationbank.branch.cash.service.event/1",.FederationBankBranchCashServiceEventFactory~new)
  ignore=r~register("federationbank.branch.cash.service.work/2",.FederationBankBranchCashTransferWorkFactory~new)
  ignore=r~register(.FederationBankBranchCashServiceBuild~STATE_FORMAT,.FederationBankBranchCashServiceStateFactory~new)
  return .true
::method newCodec class
  codec=.QueueGraphPayloadCodec~new; ignore=self~registerTypes(codec); return codec

::class FederationBankBranchCashServiceStore public
::method init
  expose durableStore codec
  use arg rootArg,codecArg=.nil,recordProtector=.nil,recoveryMode="STRICT"
  if codecArg==.nil then codec=.FederationBankBranchCashServicePersistenceSupport~newCodec
  else do; codec=codecArg; ignore=.FederationBankBranchCashServicePersistenceSupport~registerTypes(codec); end
  durableStore=.QueueDurableStore~new(rootArg~string,recordProtector,recoveryMode)
::method save
  expose durableStore codec
  use arg state
  signal on syntax name saveFailure
  graph=codec~encode(state); ignore=durableStore~appendJournal("FBBRANCHCASHSTATE",.array~of(.FederationBankBranchCashServiceBuild~STATE_FORMAT,graph)); signal off syntax
  return .FederationBankBranchCashServiceResult~success(state)
saveFailure:
  signal off syntax
  return .FederationBankBranchCashServiceResult~failure("STATE_SAVE_FAILED",condition("D"))
::method load
  expose durableStore codec
  signal on syntax name loadFailure
  rows=durableStore~readJournal; graph=""
  do row over rows
    if row~items>=3 then if row[1]="FBBRANCHCASHSTATE" & row[2]=.FederationBankBranchCashServiceBuild~STATE_FORMAT then graph=row[3]
  end
  if graph="" then return .FederationBankBranchCashServiceResult~success(.FederationBankBranchCashServiceState~new,"new store")
  state=codec~decode(graph); if \state~isA(.FederationBankBranchCashServiceState) then return .FederationBankBranchCashServiceResult~failure("STATE_TYPE_INVALID")
  signal off syntax; return .FederationBankBranchCashServiceResult~success(state)
loadFailure:
  signal off syntax
  return .FederationBankBranchCashServiceResult~failure("STATE_LOAD_FAILED",condition("D"))

::requires "FederationBankBranchCashService.cls"
::requires "ObjectQueueFabric.cls"
