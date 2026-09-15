/* FederationBankMerchantPositionService.cls
 *
 * Read-only arm's-length Merchant Bank position enquiry.
 *
 * This is not a Retail/Core Banking balance service and has no trading,
 * collateral-control, settlement or Ledger mutation API.  A Retail Bank
 * customer/session is merely cross-perimeter identity context; an injected
 * linkage authority must resolve it to a permitted Merchant relationship.
 */

::class MBPositionServiceBuild public
::constant REQUEST_SCHEMA "federationbank.brokerage.atm.request/0.1"
::constant RESPONSE_SCHEMA "federationbank.brokerage.atm.response/0.1"
::constant OPERATION "GET_MERCHANT_POSITION_SUMMARY"
::constant SOURCE_AUTHORITY "FEDERATION_BROKERAGE_POSITION_AUTHORITY"


::class MBTrustedRelationshipLink public
::method init
  expose bankSessionId customerId terminalId relationshipId authorityRef decision
  use strict arg bankSessionId,customerId,terminalId,relationshipId,authorityRef,decision="PERMITTED"
  if relationshipId="" | authorityRef="" then raise syntax 88.900 array("invalid trusted relationship link")
::method bankSessionId; expose bankSessionId; return bankSessionId
::method customerId; expose customerId; return customerId
::method terminalId; expose terminalId; return terminalId
::method relationshipId; expose relationshipId; return relationshipId
::method authorityRef; expose authorityRef; return authorityRef
::method decision; expose decision; return decision
::method permitted; expose decision; return decision="PERMITTED"


::class MBPositionEnquiryService public
::method init
  expose merchantBank linkageAuthority
  use strict arg merchantBank,linkageAuthority
  if \merchantBank~isA(.FederationBankMerchantBank) then raise syntax 88.900 array("FederationBankMerchantBank required")
  if linkageAuthority==.nil then raise syntax 88.900 array("cross-perimeter linkage authority required")

::method handleRequest
  expose merchantBank linkageAuthority
  use strict arg req,transportContext=.nil
  if req==.nil then return self~response("","",.false,"BROKERAGE_REQUEST_INVALID","request required")
  commandId=self~text(req,"commandId")
  operation=self~text(req,"operation")
  terminalId=self~text(req,"terminalId")
  schema=self~text(req,"schema")
  bankSessionId=self~text(req,"bankSessionId")
  customerId=self~text(req,"customerId")
  requestedAt=self~text(req,"requestedAt")
  if schema<>.MBPositionServiceBuild~REQUEST_SCHEMA then return self~response(commandId,terminalId,.false,"BROKERAGE_SCHEMA_UNSUPPORTED",schema)
  if operation<>.MBPositionServiceBuild~OPERATION then return self~response(commandId,terminalId,.false,"BROKERAGE_OPERATION_UNSUPPORTED",operation)
  if commandId="" | terminalId="" | bankSessionId="" | customerId="" | requestedAt="" then return self~response(commandId,terminalId,.false,"BROKERAGE_REQUEST_INVALID","missing identity/time field")

  -- The terminal cannot choose a brokerage relationship, portfolio, trade or
  -- Retail account for this operation.  Those identifiers are server-owned.
  forbidden=.array~of("relationshipId","brokerageAccountId","portfolioId","tradeId","accountId")
  do key over forbidden
    if req~hasIndex(key) then return self~response(commandId,terminalId,.false,"BROKERAGE_CALLER_SCOPE_INVALID","caller supplied "||key)
  end

  signal on syntax name linkageFailure
  link=linkageAuthority~resolve(bankSessionId,customerId,terminalId,transportContext)
  signal off syntax
  if link==.nil then return self~response(commandId,terminalId,.false,"NO_LINKED_BROKERAGE_ACCOUNT","")
  if \link~isA(.MBTrustedRelationshipLink) then return self~response(commandId,terminalId,.false,"BROKERAGE_LINKAGE_INVALID","untrusted linkage result")
  if \link~permitted then return self~response(commandId,terminalId,.false,"BROKERAGE_LINKAGE_NOT_AUTHORISED",link~decision)
  if link~bankSessionId<>bankSessionId | link~customerId<>customerId | link~terminalId<>terminalId then return self~response(commandId,terminalId,.false,"BROKERAGE_LINKAGE_CONTEXT_MISMATCH","")

  signal on syntax name positionUnavailable
  summary=merchantBank~positionSummaryForRelationship(link~relationshipId,.MBPositionServiceBuild~SOURCE_AUTHORITY)
  signal off syntax
  if summary==.nil then return self~response(commandId,terminalId,.false,"NO_LINKED_BROKERAGE_ACCOUNT","")

  d=.directory~new
  d["relationshipId"]=summary~relationshipId
  d["currency"]=summary~currency
  d["valuationTime"]=summary~valuationTime
  d["netMarketValueMinor"]=self~money(summary~netMarketValue)
  d["unrealisedPnlMinor"]=self~money(summary~unrealisedPnL)
  d["realisedPnlMinor"]=self~money(summary~realisedPnL)
  d["collateralMinor"]=self~money(summary~collateral)
  d["marginRequiredMinor"]=self~money(summary~marginRequired)
  d["availableMarginMinor"]=self~money(summary~availableMargin)
  d["positionCount"]=summary~positionCount
  d["valuationStatus"]=summary~valuationStatus
  d["sourceAuthority"]=summary~sourceAuthority
  if summary~valuationStatus="CURRENT" then do
    responseCode="MERCHANT_POSITION_CURRENT"
    responseDetail="Current brokerage derivatives position summary"
  end
  else do
    responseCode="MERCHANT_POSITION_"||summary~valuationStatus
    responseDetail="Brokerage derivatives position summary; valuation status "||summary~valuationStatus
  end
  return self~response(commandId,terminalId,.true,responseCode,responseDetail,d,summary~valuationTime)

linkageFailure:
  signal off syntax
  return self~response(commandId,terminalId,.false,"BROKERAGE_LINKAGE_UNAVAILABLE",condition("D"))
positionUnavailable:
  signal off syntax
  return self~response(commandId,terminalId,.false,"MERCHANT_POSITION_UNAVAILABLE",condition("D"))

::method response private
  use strict arg commandId,terminalId,ok,code,detail,data=.nil,brokerageTime=""
  r=.directory~new
  r["schema"]=.MBPositionServiceBuild~RESPONSE_SCHEMA
  r["commandId"]=commandId
  r["operation"]=.MBPositionServiceBuild~OPERATION
  r["terminalId"]=terminalId
  if ok then r["ok"]=.JSON~true
  else r["ok"]=.JSON~false
  r["code"]=code
  r["detail"]=detail
  if brokerageTime="" then brokerageTime=self~brokerageTime
  r["brokerageTime"]=brokerageTime
  if data<>.nil then r["data"]=data
  return r

::method text private
  use strict arg d,key
  if \d~hasIndex(key) then return ""
  v=d[key]
  if v==.nil then return ""
  return v~string

::method money private
  use strict arg value
  if \datatype(value,"W") then raise syntax 88.900 array("Merchant position money is not integer minor units",value)
  return value+0

::method brokerageTime private
  -- Transport-neutral service does not invent a market timestamp.  This field
  -- is operational response time only; the position carries valuationTime.
  return .DateTime~new~isoDate


::class MBPositionJMSGateway public
::method init
  expose service
  use strict arg service
  if \service~isA(.MBPositionEnquiryService) then raise syntax 88.900 array("MBPositionEnquiryService required")

::method processBridgeMessage
  expose service
  use strict arg message
  if message==.nil | \message~isA(.JMSBridgeMessage) then return .JMSBridgeResult~failure("BROKERAGE_JMS_MESSAGE_REQUIRED")
  if message~bodyType<>"TEXT" then return .JMSBridgeResult~failure("BROKERAGE_JMS_TEXT_REQUIRED")
  signal on syntax name badJson
  req=.JSON~fromJSON(message~body)
  signal off syntax
  transportContext=.directory~new
  transportContext["provider"]=message~provider
  transportContext["source"]=message~source
  transportContext["properties"]=message~properties
  transportContext["headers"]=message~headers
  response=service~handleRequest(req,transportContext)
  commandId=""
  terminalId=""
  if req~hasIndex("commandId") then commandId=req["commandId"]~string
  if req~hasIndex("terminalId") then terminalId=req["terminalId"]~string
  props=.directory~new
  props["FB_BROKERAGE_SCHEMA"]=.MBPositionServiceBuild~RESPONSE_SCHEMA
  props["FB_BROKERAGE_OPERATION"]=.MBPositionServiceBuild~OPERATION
  props["FB_BROKERAGE_TERMINAL_ID"]=terminalId
  headers=.directory~new
  headers["JMSCORRELATIONID"]=commandId
  out=.JMSBridgeMessage~new("","TEXT",.JSON~toJSON(response),headers,props,"FEDERATIONBANK_MERCHANT_BANK","")
  return .JMSBridgeResult~success(out,"BROKERAGE_POSITION_RESPONSE_READY",commandId)
badJson:
  signal off syntax
  return .JMSBridgeResult~failure("BROKERAGE_JSON_INVALID",condition("D"))

::requires "FederationBankMerchantBank.cls"
::requires "JMSQueueBridge.cls"
::requires "json.cls"
