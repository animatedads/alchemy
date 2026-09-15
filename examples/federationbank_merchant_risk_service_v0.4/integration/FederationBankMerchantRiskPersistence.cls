::class MBRiskNoticeFactory public
::method newBlank; return .MBRiskMarketStructureNotice~new("RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE")
::class MBRiskCommandFactory public
::method newBlank; return .MBRiskServiceEnvelope~new("RESTORE","RISK.WORK.LIST","RESTORE","MERCHANT_RISK_READ")
::class MBRiskReplyFactory public
::method newBlank; return .MBRiskServiceReply~new("RESTORE","RESTORE",.false,"RESTORE")
::class MBRiskWatchFactory public
::method newBlank; return .MBRiskWatch~new("RESTORE","RESTORE","RESTORE","RESTORE")
::class MBRiskWorkFactory public
::method newBlank; return .MBRiskWorkItem~new("RESTORE","RESTORE","RESTORE","","RESTORE","RESTORE","RESTORE")
::class MBRiskEventFactory public
::method newBlank; return .MBRiskOperationalEvent~new("RESTORE","RESTORE","","","","RESTORE")
::class MBRiskReceiptFactory public
::method newBlank; return .MBRiskCommandReceipt~new("RESTORE","RESTORE","RESTORE")
::class MBRiskStateFactory public
::method newBlank; return .MBRiskServiceState~new

::class FederationBankMerchantRiskPersistence public
::method registerTypes class
  use arg codec
  r=codec~typeRegistry
  ignore=r~register("federationbank.merchant.risk.market-structure-notice/1",.MBRiskNoticeFactory~new)
  ignore=r~register("federationbank.merchant.risk.command/1",.MBRiskCommandFactory~new)
  ignore=r~register("federationbank.merchant.risk.reply/1",.MBRiskReplyFactory~new)
  ignore=r~register("federationbank.merchant.risk.watch/1",.MBRiskWatchFactory~new)
  ignore=r~register("federationbank.merchant.risk.work/1",.MBRiskWorkFactory~new)
  ignore=r~register("federationbank.merchant.risk.work/2",.MBRiskWorkFactory~new)
  ignore=r~register("federationbank.merchant.risk.event/1",.MBRiskEventFactory~new)
  ignore=r~register("federationbank.merchant.risk.receipt/1",.MBRiskReceiptFactory~new)
  ignore=r~register(.MBRiskServiceBuild~LEGACY_STATE_FORMAT,.MBRiskStateFactory~new)
  ignore=r~register(.MBRiskServiceBuild~STATE_FORMAT,.MBRiskStateFactory~new)
  return .true
::method newCodec class
  codec=.QueueGraphPayloadCodec~new; ignore=self~registerTypes(codec); return codec

::class FederationBankMerchantRiskStateStore public
::method init
  expose durableStore codec
  use strict arg rootArg
  codec=.FederationBankMerchantRiskPersistence~newCodec
  durableStore=.QueueDurableStore~new(rootArg~string)
::method save
  expose durableStore codec
  use strict arg state
  graph=codec~encode(state)
  ignore=durableStore~appendJournal("MBRISKSTATE",.array~of(.MBRiskServiceBuild~STATE_FORMAT,graph))
  return state
::method load
  expose durableStore codec
  rows=durableStore~readJournal; graph=""
  do row over rows
    if row~items>=3 then if row[1]="MBRISKSTATE" then do
      if row[2]=.MBRiskServiceBuild~STATE_FORMAT | row[2]=.MBRiskServiceBuild~LEGACY_STATE_FORMAT then graph=row[3]
    end
  end
  if graph="" then return .MBRiskServiceState~new
  state=codec~decode(graph)
  if \state~isA(.MBRiskServiceState) then raise syntax 88.900 array("Merchant Risk state type invalid")
  return state
::requires "FederationBankMerchantRiskService.cls"
::requires "ObjectQueueFabric.cls"
