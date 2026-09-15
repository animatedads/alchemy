mb=buildBank()
resolver=.FixtureLinkageResolver~new("SESSION-2","CUST-002","ATM-IOM-001","BRK-RET-0002")
svc=.MBPositionEnquiryService~new(mb,resolver)
req=request()
r=svc~handleRequest(req)
call assertTrue r["ok"],"position read accepted"
call assertEq "MERCHANT_POSITION_CURRENT",r["code"],"position response code"
d=r["data"]
call assertEq "BRK-RET-0002",d["relationshipId"],"server-resolved relationship"
call assertEq "AUD",d["currency"],"currency"
call assertEq 600000,d["netMarketValueMinor"],"merchant market value"
call assertEq 20000,d["unrealisedPnlMinor"],"merchant unrealised pnl"
call assertEq 2,d["positionCount"],"position count"
call assertEq "FEDERATION_BROKERAGE_POSITION_AUTHORITY",d["sourceAuthority"],"merchant source authority"
call assertFalse d~hasIndex("availableBalanceMinor"),"never masquerades as retail available balance"

say "PASS test_position_enquiry"
exit 0

::routine buildBank
  e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL","POLICY")
  mb=.FederationBankMerchantBank~new
  mb~registerRelationship(.MBMerchantRelationship~new("BRK-RET-0002","CLIENT-2","RETAIL-CUST-002","LINK-AUTH"))
  mb~createPortfolio("PF-2","CLIENT-2","AUD","BRK-RET-0002")
  mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-X","1","CFD","X","AUD","CASH",e))
  mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-Y","1","CFD","Y","AUD","CASH",e))
  mb~bookTrade(.MBDerivativeTrade~new("TX","PF-2","CLIENT-2","CFD","LONG","AUD",600000,0,0,"",1,"X","CFD-X","X"))
  mb~bookTrade(.MBDerivativeTrade~new("TY","PF-2","CLIENT-2","CFD","SHORT","AUD",400000,0,0,"",1,"Y","CFD-Y","Y"))
  mb~recordMarketEvidence(.MBMarketEvidence~new("MX","MKT","X","2026-08-26T08:21:00.000Z","AUD",1))
  mb~recordMarketEvidence(.MBMarketEvidence~new("MY","MKT","Y","2026-08-26T08:21:00.000Z","AUD",1))
  mb~recordTradeMark(.MBTradeMark~new("MKX","TX","2026-08-26T08:21:00.000Z","AUD",500000,25000,600000,"MX"))
  mb~recordTradeMark(.MBTradeMark~new("MKY","TY","2026-08-26T08:21:00.000Z","AUD",100000,-5000,400000,"MY"))
  v=mb~createPortfolioValuation("V","PF-2","2026-08-26T08:21:00.000Z")
  p=.MBRiskPolicy~new("RISK",2,0,3600)
  mb~assessMargin("A","PF-2",v,p,1000000,"2026-08-26T08:21:00.010Z")
  return mb
::routine request
  d=.directory~new
  d["schema"]=.MBPositionServiceBuild~REQUEST_SCHEMA
  d["commandId"]="BRKPOS-1"
  d["operation"]=.MBPositionServiceBuild~OPERATION
  d["terminalId"]="ATM-IOM-001"
  d["bankSessionId"]="SESSION-2"
  d["customerId"]="CUST-002"
  d["requestedAt"]="2026-08-26T08:21:00.000Z"
  return d
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg actual,label
  if actual<>.true then raise syntax 88.900 array("ASSERT_TRUE",label)
::routine assertFalse
  use strict arg actual,label
  if actual<>.false then raise syntax 88.900 array("ASSERT_FALSE",label)
::class FixtureLinkageResolver
::method init
  expose session customer terminal relationship
  use strict arg session,customer,terminal,relationship
::method resolve
  expose session customer terminal relationship
  use strict arg gotSession,gotCustomer,gotTerminal,transportContext=.nil
  if gotSession<>session | gotCustomer<>customer | gotTerminal<>terminal then return .nil
  return .MBTrustedRelationshipLink~new(session,customer,terminal,relationship,"RETAIL-LINKAGE-AUTH-1")
::requires "FederationBankMerchantPositionService.cls"
