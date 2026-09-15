v=.VectorMeridianMarkets~new
s=.VMMAlgorithmStrategy~new("ALG-CAP-1","4.0","CAPITAL_AWARE_MM","SRC-CAP","MODEL-CAP",5000,10000,"POL-CAP")
v~registerStrategy(s); v~enableStrategy("ALG-CAP-1","VMM-RISK")
v~setFirmRiskLimits(.VMMFirmRiskLimits~new("RISK-CAP","USD",100000,50000,100000,100000,"POL-RISK-CAP"),"VMM-INDEPENDENT-RISK")
i=.VMMTradableInstrument~new("CAP-US","CAP","US000000CAP1","XNAS","ORDINARY","USD","USD","USD","RES-CAP-XNAS")
d=.VMMAlgorithmDecision~new("DEC-CAP-1","ALG-CAP-1",i,"BUY",2000,"20260828T144000","MKT-CAP","SIG-CAP","VMM-ALGO")
v~recordAlgorithmDecision(d); o=v~createProprietaryOrder("ORD-CAP-1","DEC-CAP-1","LIMIT",10,"20260828T144001","VMM-ALGO-EXEC")
/* Apply independent VMM capital policy after order creation: routing must re-admit against current policy. */
v~setCapitalPolicy(.VMMCapitalPolicy~new("CAP-POL-1","USD",1000,1.5,"VMM-CAPITAL-POLICY"),"VMM-INDEPENDENT-RISK")
root="./tmp_queue_smart_capital_"||.DateTime~new~microseconds
x=.VMMSmartExecutionService~new(v,root)
r=.VMMVenueRoute~new("XNAS_CAP","XNAS","ADAPTER_CAP","VMM_VENUE_CAP","CAP_CLEARER","US",1,0,5000,10,"POL-CAP-ROUTE","ROUTE-CAP")
x~registerRoute(r); x~recordVenueQuote(.VMMVenueQuote~new("VQ-CAP","XNAS_CAP",i~identityKey,9.9,10.0,5000,"20260828T144001","20260828T144100","QUOTE-CAP","MKT-DATA"))
signal on syntax name leverageBlocked
ignore=v~routeMarketOrder("ORD-CAP-1","CAP-IDEMP-1","CAP-CORR-1","20260828T144002","VMM-SMART-ROUTER")
raise syntax 88.900 array("expected leverage gate")
leverageBlocked:
signal off syntax
call assertEq 0,x~commandDepth("XNAS_CAP"),"leverage breach is pre-queue"
call assertEq "CREATED",o~executionState,"capital-rejected order remains unrouted"
v~setCapitalPolicy(.VMMCapitalPolicy~new("CAP-POL-2","USD",2000,2,"VMM-CAPITAL-POLICY-2"),"VMM-INDEPENDENT-RISK")
call assertTrue v~routeMarketOrder("ORD-CAP-1","CAP-IDEMP-2","CAP-CORR-2","20260828T144003","VMM-SMART-ROUTER")~ok,"re-capitalised VMM can route"
a=.VMMSmartVenueAdapter~new(x,r); call assertTrue a~processNextCommand("20260828T144004")~ok,"capital-admitted order acknowledged"; call assertTrue x~processNextEvent~ok,"ack applied"
call assertTrue a~publishFill("ORD-CAP-1","CAP-FILL-1","CAP-EXEC-1",2000,10,"USD","20260828T144005","SETTLE-CAP")~ok,"capital-admitted fill queued"; call assertTrue x~processNextEvent~ok,"fill applied"
snap=v~evaluateCapital("CAP-SNAP-1","USD","20260828T144006","VMM-INDEPENDENT-RISK")
call assertNear 1,snap~leverage,0.000001,"capital snapshot measures gross leverage"
call assertEq "NONE",snap~breachCode,"post-fill leverage within updated policy"
say "PASS test_smart_capital_leverage_gate"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
::routine assertNear
  use strict arg expected,actual,tolerance,label
  if abs(expected-actual)>tolerance then raise syntax 88.900 array("ASSERT_NEAR",label,"expected",expected,"actual",actual)

::requires "VMMSmartExecution.cls"
