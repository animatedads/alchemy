e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL","POLICY")
mb=.FederationBankMerchantBank~new
mb~registerRelationship(.MBMerchantRelationship~new("MBR-S","CLIENT-S","RETAIL-S","AUTH-S"))
mb~createPortfolio("PF-S","CLIENT-S","GBP","MBR-S")
mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-S","1","CFD","IDX-S","GBP","CASH",e))
mb~bookTrade(.MBDerivativeTrade~new("T-S","PF-S","CLIENT-S","CFD","LONG","GBP",600000,0,0,"",1,"IDX-S","CFD-S","IDX-S"))
mb~recordMarketEvidence(.MBMarketEvidence~new("M-S","MKT","IDX-S","2026-08-26T08:00:00.000Z","GBP",1,"STALE"))
mb~recordTradeMark(.MBTradeMark~new("MK-S","T-S","2026-08-26T08:00:00.000Z","GBP",100000,1000,600000,"M-S"))
v=mb~createPortfolioValuation("V-S","PF-S","2026-08-26T08:00:00.000Z")
mb~assessMargin("A-S","PF-S",v,.MBRiskPolicy~new("RISK",6,0,3600),1000000,"NOW")
svc=.MBPositionEnquiryService~new(mb,.Resolver~new)
req=.directory~new; req["schema"]=.MBPositionServiceBuild~REQUEST_SCHEMA; req["commandId"]="C-S"; req["operation"]=.MBPositionServiceBuild~OPERATION; req["terminalId"]="ATM-S"; req["bankSessionId"]="SESSION-S"; req["customerId"]="CUST-S"; req["requestedAt"]="NOW"
r=svc~handleRequest(req)
call assertEq "MERCHANT_POSITION_STALE",r["code"],"stale market data is never labelled current"
call assertEq "STALE",r["data"]["valuationStatus"],"status survives projection"
say "PASS test_valuation_status"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::class Resolver
::method resolve
  use strict arg s,c,t,transportContext=.nil
  return .MBTrustedRelationshipLink~new(s,c,t,"MBR-S","AUTH")
::requires "FederationBankMerchantPositionService.cls"
