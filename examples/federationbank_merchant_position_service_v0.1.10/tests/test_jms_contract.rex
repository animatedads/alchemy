mb=buildBank()
svc=.MBPositionEnquiryService~new(mb,.Resolver~new)
gw=.MBPositionJMSGateway~new(svc)
req=.directory~new
req["schema"]=.MBPositionServiceBuild~REQUEST_SCHEMA; req["commandId"]="BRKPOS-JMS-1"; req["operation"]=.MBPositionServiceBuild~OPERATION; req["terminalId"]="ATM-IOM-001"; req["bankSessionId"]="SESSION-2"; req["customerId"]="CUST-002"; req["requestedAt"]="2026-08-26T08:21:00.000Z"
m=.JMSBridgeMessage~new("MID","TEXT",.JSON~toJSON(req),.directory~new,.directory~new,"ATM","")
br=gw~processBridgeMessage(m)
call assertTrue br~ok,"JMS gateway success"
out=br~value
call assertEq "BRKPOS-JMS-1",out~headers["JMSCORRELATIONID"],"JMS correlation"
call assertEq .MBPositionServiceBuild~RESPONSE_SCHEMA,out~properties["FB_BROKERAGE_SCHEMA"],"brokerage response property"
parsed=.JSON~fromJSON(out~body)
call assertTrue parsed["ok"],"JSON response success"
call assertEq "BRK-RET-0002",parsed["data"]["relationshipId"]~string,"relationship in JSON"
call assertFalse parsed["data"]~hasIndex("availableBalanceMinor"),"JMS payload cannot alter retail cash semantics"

say "PASS test_jms_contract"
exit 0
::routine buildBank
  e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL","POLICY")
  mb=.FederationBankMerchantBank~new
  mb~registerRelationship(.MBMerchantRelationship~new("BRK-RET-0002","CLIENT-2","RETAIL-CUST-002","LINK-AUTH"))
  mb~createPortfolio("PF-2","CLIENT-2","AUD","BRK-RET-0002")
  mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-X","1","CFD","X","AUD","CASH",e))
  mb~bookTrade(.MBDerivativeTrade~new("TX","PF-2","CLIENT-2","CFD","LONG","AUD",600000,0,0,"",1,"X","CFD-X","X"))
  mb~recordMarketEvidence(.MBMarketEvidence~new("MX","MKT","X","2026-08-26T08:21:00.000Z","AUD",1))
  mb~recordTradeMark(.MBTradeMark~new("MKX","TX","2026-08-26T08:21:00.000Z","AUD",500000,25000,600000,"MX"))
  v=mb~createPortfolioValuation("V","PF-2","2026-08-26T08:21:00.000Z")
  mb~assessMargin("A","PF-2",v,.MBRiskPolicy~new("RISK",2,0,3600),1000000,"NOW")
  return mb
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg actual,label
  if actual<>.true then raise syntax 88.900 array("ASSERT_TRUE",label)
::routine assertFalse
  use strict arg actual,label
  if actual<>.false then raise syntax 88.900 array("ASSERT_FALSE",label)
::class Resolver
::method resolve
  use strict arg s,c,t,transportContext=.nil
  if s<>"SESSION-2" | c<>"CUST-002" | t<>"ATM-IOM-001" then return .nil
  return .MBTrustedRelationshipLink~new(s,c,t,"BRK-RET-0002","AUTH")
::requires "FederationBankMerchantPositionService.cls"
