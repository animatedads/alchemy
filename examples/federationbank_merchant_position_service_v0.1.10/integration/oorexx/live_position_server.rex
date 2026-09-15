signal on syntax name failed
parse arg brokerUrl
if brokerUrl="" then brokerUrl="tcp://127.0.0.1:61627"

mb=buildBank()
svc=.MBPositionEnquiryService~new(mb,.LiveLinkageAuthority~new)
gw=.MBPositionJMSGateway~new(svc)
config=.JMSBridgeConfig~new("merchant-position-live","GENERIC",brokerUrl,"ConnectionFactory", -
  "dynamicQueues/FB.BROKERAGE.ATM.REQUESTS","dynamicQueues/FB.BROKERAGE.ATM.REPLIES.ATM-IOM-001", -
  "","","","","","merchant-position",.false,5000,"REJECT", -
  "org.apache.activemq.jndi.ActiveMQInitialContextFactory","CLIENT_ACKNOWLEDGE","ADMINISTERED")
provider=.JMSBSFProvider~new(config,.nil)
r=provider~connect
if \r~ok then do; say "FAIL connect" r~code r~detail; exit 2; end
received=provider~receive(10000)
if \received~ok | received~value==.nil then do; say "FAIL receive" received~code received~detail; ignore=provider~close; exit 3; end
delivery=received~value
result=gw~processBridgeMessage(delivery~message)
if \result~ok then do; say "FAIL gateway" result~code result~detail; ignore=provider~rejectInbound(delivery); ignore=provider~close; exit 4; end
out=result~value
corr=out~headers["JMSCORRELATIONID"]
pkg=.LivePackage~new("MB-LIVE-REPLY-1","FB.BROKERAGE.ATM.REPLIES.ATM-IOM-001",corr,out)
sent=provider~send(pkg)
if \sent~ok then do; say "FAIL send" sent~code sent~detail; ignore=provider~rejectInbound(delivery); ignore=provider~close; exit 5; end
ignore=provider~acceptInbound(delivery)
ignore=provider~close
say "MERCHANT POSITION REAL JMS SERVER PASS"
exit 0

failed:
  say "FAIL syntax:" condition("D")
  if .BSF_ERROR_MESSAGE \== .nil then say .BSF_ERROR_MESSAGE
  exit 1

::routine buildBank
  e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-MB-PRODUCT-1","POLICY-MB-PRODUCT-1")
  mb=.FederationBankMerchantBank~new
  mb~registerRelationship(.MBMerchantRelationship~new("BRK-RET-0002","CLIENT-2","RETAIL-CUST-002","LINK-AUTH-ATM"))
  mb~createPortfolio("PF-ATM-2","CLIENT-2","AUD","BRK-RET-0002")
  mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-XAU-AUD","1","CFD","XAU-AUD","AUD","CASH",e))
  mb~registerProduct(.MBDerivativeProductDefinition~new("OPT-ASX","1","OPTION","ASX200","AUD","CASH",e,"CALL","EUROPEAN",100))
  mb~bookTrade(.MBDerivativeTrade~new("T-XAU","PF-ATM-2","CLIENT-2","CFD","LONG","AUD",2000000,0,0,"",1,"XAU-AUD","CFD-XAU-AUD","XAU-AUD"))
  mb~bookTrade(.MBDerivativeTrade~new("T-ASX","PF-ATM-2","CLIENT-2","OPTION","LONG","AUD",1228000,100000,25000,"20261231",10,"ASX200","OPT-ASX","ASX200"))
  mb~recordMarketEvidence(.MBMarketEvidence~new("ME-XAU","MB-MARKET-DATA","XAU-AUD","2026-08-26T08:21:00.000Z","AUD",1,"CURRENT"))
  mb~recordMarketEvidence(.MBMarketEvidence~new("ME-ASX","MB-MARKET-DATA","ASX200","2026-08-26T08:21:00.000Z","AUD",1,"CURRENT"))
  mb~recordTradeMark(.MBTradeMark~new("TM-XAU","T-XAU","2026-08-26T08:21:00.000Z","AUD",5000000,250000,2000000,"ME-XAU"))
  mb~recordTradeMark(.MBTradeMark~new("TM-ASX","T-ASX","2026-08-26T08:21:00.000Z","AUD",2244000,71500,1228000,"ME-ASX"))
  v=mb~createPortfolioValuation("VAL-ATM","PF-ATM-2","2026-08-26T08:21:00.000Z")
  -- 6x policy; no Core collateral in this fixture, so all collateral remains zero.
  mb~assessMargin("MARG-ATM","PF-ATM-2",v,.MBRiskPolicy~new("MB-RISK-6X",6,0,3600),1000000,"2026-08-26T08:21:00.010Z")
  return mb

::class LiveLinkageAuthority
::method resolve
  use strict arg sessionId,customerId,terminalId,transportContext=.nil
  if sessionId="" | customerId<>"CUST-002" | terminalId<>"ATM-IOM-001" then return .nil
  -- This fixture stands in for the independent Retail/Core trust service. It
  -- creates the trusted assertion; the Merchant service itself still cannot
  -- derive or choose a relationship from the bare customer identifier.
  return .MBTrustedRelationshipLink~new(sessionId,customerId,terminalId,"BRK-RET-0002","CORE-LINKAGE-AUTH-LIVE")

::class LivePackage public
::attribute packageId get
::attribute currentQueue get
::attribute correlationId get
::attribute payload get
::method init
  expose packageId currentQueue correlationId payload
  use strict arg packageId,currentQueue,correlationId,payload

::requires "FederationBankMerchantPositionService.cls"
::requires "JMSQueueBridgeBSF.cls"
