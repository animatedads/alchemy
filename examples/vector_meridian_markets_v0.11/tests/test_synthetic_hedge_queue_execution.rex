v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
c=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(c)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("SYN-RISK-JPY","JPY",100000000000,50000000000,100,"POL-SYN-JPY"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-TOPIX","AJI","TOPIX-BASKET","JAPAN_EQUITY_BASKET","EQUITY","JPY",10000000000,"ALL_JAPAN_INSURANCE","","AJI-CURRENT","","VAL-TOPIX")
s=.VMMPortfolioSnapshot~new("AJI-SNAP-H","AJI","ALL_JAPAN_INSURANCE","JPY","20260828T132000",.array~of(p),"AJI-POSITIONS","","VMM-PORTFOLIO-CONTROL")
x~registerPortfolioSnapshot(s)
o=x~createOffer("OFF-H","REQ-H","AJI","AJI-SNAP-H","JPY",10000000000,5,25,120000000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-OFFER","MKT-OFFER","RISK-OFFER")
k=x~acceptOffer("CON-H","OFF-H","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
alg=.VMMAlgorithmStrategy~new("ALG-SYN-HEDGE","5.0","SYNTHETIC_HEDGE","SRC-SYN-HEDGE","MODEL-SYN-HEDGE",5000000000,10000000000,"POL-SYN-HEDGE")
v~registerStrategy(alg); v~enableStrategy("ALG-SYN-HEDGE","VMM-RISK")
v~setFirmRiskLimits(.VMMFirmRiskLimits~new("RISK-HEDGE","JPY",20000000000,10000000000,10000000000,5000000000,"POL-RISK-HEDGE"),"VMM-RISK")
i=.VMMTradableInstrument~new("TOPIX-PUT-2027","TOPIX","JP0000PUT001","XOSE","INDEX_OPTION","JPY","JPY","JPY","RES-TOPIX-PUT")
hedge=x~createHedgeOrder("ORD-SYN-H-1","CON-H","ALG-SYN-HEDGE",i,"LONG",1000000000,"LIMIT",20,"20260828T132300","VMM-SYNTHETIC-HEDGE")
call assertEq "SYNTHETIC_HEDGE",hedge~origin,"synthetic hedge is not proprietary flow"
call assertEq "CON-H",hedge~parentExposureRef,"hedge carries only VMM contract reference"
root="./tmp_queue_synthetic_hedge_"||.DateTime~new~microseconds
smart=.VMMSmartExecutionService~new(v,root)
r=.VMMVenueRoute~new("XOSE_OPTIONS","XOSE","ADAPTER-XOSE","VMM_XOSE_ADAPTER","JP_OPTIONS_CLEARER","JP",2,0,5000000000,1,"POL-XOSE","ROUTE-XOSE-EVID")
smart~registerRoute(r)
smart~recordVenueQuote(.VMMVenueQuote~new("VQ-XOSE-H","XOSE_OPTIONS",i~identityKey,19.5,19.8,2000000000,"20260828T132301","20260828T133000","QUOTE-XOSE-H","JP-MKT-DATA"))
call assertTrue v~routeMarketOrder("ORD-SYN-H-1","IDEMP-SYN-H-1","CORR-SYN-H-1","20260828T132302","VMM-SMART-ROUTER")~ok,"synthetic hedge routed through Queue Fabric"
a=.VMMSmartVenueAdapter~new(smart,r)
call assertTrue a~processNextCommand("20260828T132303")~ok,"venue adapter acknowledges hedge"
call assertTrue smart~processNextEvent~ok,"hedge acknowledgement booked"
call assertTrue a~publishFill("ORD-SYN-H-1","FILL-SYN-H-1","XOSE-EXEC-H-1",1000000000,19.8,"JPY","20260828T132304","SETTLE-XOSE-H")~ok,"venue fill queued"
call assertTrue smart~processNextEvent~ok,"venue fill becomes VMM execution truth"
call assertEq "FILLED",hedge~executionState,"synthetic hedge fill terminal"
call assertEq 1000000000,v~inventoryFor(i~identityKey),"hedge inventory held by VMM only"
say "PASS test_synthetic_hedge_queue_execution"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
::requires "VMMSyntheticProducts.cls"
::requires "VMMSmartExecution.cls"
