::class FBExtBundleFactory public
::method newBlank; return .FederationBankExternalCashBundle~new("GBP",.directory~new)
::class FBExtShipmentFactory public
::method newBlank; return .FederationBankExternalCashShipment~new("RESTORE","RESTORE-BRANCH","INBOUND","RESTORE-VAULT","RESTORE-CENTRE","RESTORE-CARRIER","RESTORE-MANIFEST","RESTORE-SEAL",.FederationBankExternalCashBundle~new("GBP",.directory~new),"RESTORE-STAFF","RESTORE-AUTH")
::class FBExtApprovalFactory public
::method newBlank; return .FederationBankExternalCashApproval~new("RESTORE","RESTORE-ID","RESTORE-CHECKER","RESTORE-AUTH")
::class FBExtAuthorityFactory public
::method newBlank; return .FederationBankExternalCashAuthorityEnvelope~new("RESTORE","RESTORE-ID","RESTORE-SHIP","RESTORE-BRANCH","INBOUND",0,"GBP","RESTORE-VAULT","RESTORE-MANIFEST","RESTORE-SEAL","RESTORE-MAKER","RESTORE-AUTH","RESTORE-CHECKER","RESTORE-AUTH2","RESTORE-POLICY")
::class FBExtReceiptFactory public
::method newBlank; return .FederationBankExternalCashReceipt~new("RESTORE","RESTORE-ID","BRANCH","RESTORE","RESTORE-SEAL",.FederationBankExternalCashBundle~new("GBP",.directory~new),"RESTORE-CUSTODY")
::class FBExtWorkFactory public
::method newBlank
  s=.FBExtShipmentFactory~new~newBlank; a=.FederationBankExternalCashApproval~new("RESTORE",s~semanticIdentity,"RESTORE-CHECKER","RESTORE-AUTH"); au=.FederationBankExternalCashAuthorityIssuer~new~issue(s,a,.FederationBankExternalCashFixturePolicy~new)~value; return .FederationBankExternalCashServiceWork~new(s,a,au)
::class FBExtCmdFactory public
::method newBlank; return .FederationBankExternalCashServiceEnvelope~new("RESTORE","RESTORE","RESTORE","RESTORE")
::class FBExtReplyFactory public
::method newBlank; return .FederationBankExternalCashServiceReply~new("RESTORE","RESTORE",.false,"RESTORE")
::class FBExtRecRecordFactory public
::method newBlank; return .FederationBankExternalCashServiceReceiptRecord~new("RESTORE","RESTORE","RESTORE","RESTORE")
::class FBExtEventFactory public
::method newBlank; return .FederationBankExternalCashServiceEvent~new("RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE",0)
::class FBExtStateFactory public
::method newBlank; return .FederationBankExternalCashServiceState~new

::class FederationBankExternalCashServicePersistenceSupport public
::method registerTypes class
  use arg codec
  r=codec~typeRegistry
  ignore=r~register("federationbank.external.cash.bundle/1",.FBExtBundleFactory~new)
  ignore=r~register("federationbank.external.cash.shipment/1",.FBExtShipmentFactory~new)
  ignore=r~register("federationbank.external.cash.approval/1",.FBExtApprovalFactory~new)
  ignore=r~register("federationbank.external.cash.authority/1",.FBExtAuthorityFactory~new)
  ignore=r~register("federationbank.external.cash.receipt/1",.FBExtReceiptFactory~new)
  ignore=r~register("federationbank.external.cash.service.work/1",.FBExtWorkFactory~new)
  ignore=r~register("federationbank.external.cash.service.command/1",.FBExtCmdFactory~new)
  ignore=r~register("federationbank.external.cash.service.reply/1",.FBExtReplyFactory~new)
  ignore=r~register("federationbank.external.cash.service.receiptrecord/1",.FBExtRecRecordFactory~new)
  ignore=r~register("federationbank.external.cash.service.event/1",.FBExtEventFactory~new)
  ignore=r~register(.FederationBankExternalCashServiceBuild~STATE_FORMAT,.FBExtStateFactory~new)
  return .true
::method newCodec class
  c=.QueueGraphPayloadCodec~new; ignore=self~registerTypes(c); return c

::class FederationBankExternalCashServiceStore public
::method init
  expose durableStore codec
  use arg rootArg,codecArg=.nil
  if codecArg==.nil then codec=.FederationBankExternalCashServicePersistenceSupport~newCodec; else do; codec=codecArg; ignore=.FederationBankExternalCashServicePersistenceSupport~registerTypes(codec); end
  durableStore=.QueueDurableStore~new(rootArg~string)
::method save
  expose durableStore codec
  signal on syntax name sf
  g=codec~encode(arg(1)); ignore=durableStore~appendJournal("FBEXTCASHSTATE",.array~of(.FederationBankExternalCashServiceBuild~STATE_FORMAT,g)); signal off syntax; return .FederationBankExternalCashServiceResult~success(arg(1))
sf:
  signal off syntax; return .FederationBankExternalCashServiceResult~failure("STATE_SAVE_FAILED",condition("D"))
::method load
  expose durableStore codec
  signal on syntax name lf
  rows=durableStore~readJournal; g=""; do row over rows; if row~items>=3 then if row[1]="FBEXTCASHSTATE" & row[2]=.FederationBankExternalCashServiceBuild~STATE_FORMAT then g=row[3]; end
  if g="" then return .FederationBankExternalCashServiceResult~success(.FederationBankExternalCashServiceState~new)
  s=codec~decode(g); signal off syntax; return .FederationBankExternalCashServiceResult~success(s)
lf:
  signal off syntax; return .FederationBankExternalCashServiceResult~failure("STATE_LOAD_FAILED",condition("D"))
::requires "FederationBankExternalCashService.cls"
::requires "ObjectQueueFabric.cls"
