v=.VectorMeridianMarkets~new
s=.VMMAlgorithmStrategy~new("ALG-HEDGE-1","2.0","ADAPTIVE_SPREAD_HEDGE","SRC-HEDGE","MODEL-HEDGE",1000000,2000000,"POL-HEDGE")
v~registerStrategy(s); v~enableStrategy("ALG-HEDGE-1","VMM-RISK")
limits=.VMMFirmRiskLimits~new("RISK-GBP-1","GBP",5000000,2000000,2000000,500000,"POL-RISK-GBP")
v~setFirmRiskLimits(limits,"VMM-INDEPENDENT-RISK")
i=.VMMTradableInstrument~new("CITI-L","CITI","GB00CITI0001","XLON","ORDINARY","GBP","GBP","GBP","RES-CITI-L")
r=.VMMFlowRequest~new("RFQ-PNL","CITI-L","CFD","LONG","GBP",100000,"REL-PNL","FEDERATIONBANK_MERCHANT_BANK","20260828T121000","",i)
q=v~requestQuote(r,"ALG-HEDGE-1","Q-PNL",100,12,"20260828T121005")
t=v~executeQuote("T-PNL","Q-PNL","20260828T121001","VMM-EXEC")
call assertEq -100000,v~inventoryFor(i),"customer execution creates short inventory"
o=v~createInventoryHedgeOrder("ORD-HEDGE-1","T-PNL","ALG-HEDGE-1",100000,"LIMIT",100.02,"20260828T121002","VMM-ALGO-EXEC")
call assertEq "LONG",o~side,"hedge order opposes customer inventory"
v~fillMarketOrder("FILL-HEDGE-1","ORD-HEDGE-1","XLON-EXEC-9001",100000,100.02,"20260828T121003","EXTERNAL_VENUE_CLEARING","SETTLE-9001")
call assertEq 0,v~inventoryFor(i),"external hedge flattens identified line"
call assertNear 4000,v~tradingCashBalance("GBP"),0.0001,"spread trading pnl in cash after flat hedge"
f=.VMMFundingFacility~new("FAC-PNL","FEDERATIONBANK_CORE_TREASURY","VECTOR_MERIDIAN_MARKETS_LTD","CORE_TREASURY_CAPITAL","GBP",2000000,365,"LEGAL-LOAN-PNL","POL-ARM-PNL","20271231")
v~registerFundingFacility(f); v~drawFunding("DRAW-PNL","FAC-PNL",1000000,"20260828T121010","FEDERATIONBANK_TREASURY_AUTH","LOAN-OBL-PNL")
a=v~accrueFundingCost("ACCR-PNL","FAC-PNL",10,"20260907T121010","VMM-FINANCE")
call assertNear 1000,a~amount,0.0001,"ten days arm-length funding cost"
call assertNear 3000,v~netPnl("GBP"),0.0001,"net pnl after funding cost"
snap=v~evaluateRisk("RISK-SNAP-PNL","GBP","20260907T121011","VMM-INDEPENDENT-RISK")
call assertEq "NONE",snap~breachCode,"flat profitable book within limits"
say "PASS test_algo_external_execution_pnl"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertNear
  use strict arg expected,actual,tolerance,label
  if abs(expected-actual)>tolerance then raise syntax 88.900 array("ASSERT_NEAR",label,"expected",expected,"actual",actual)

::requires "VectorMeridianMarkets.cls"
