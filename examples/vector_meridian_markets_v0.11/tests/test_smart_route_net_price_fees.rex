v=.VectorMeridianMarkets~new
s=.VMMAlgorithmStrategy~new("ALG-SMART-1","4.0","SMART_MM","SRC-SMART1","MODEL-SMART1",5000,10000,"POL-SMART1")
v~registerStrategy(s); v~enableStrategy("ALG-SMART-1","VMM-RISK")
v~setFirmRiskLimits(.VMMFirmRiskLimits~new("RISK-SMART1","USD",100000,50000,100000,100000,"POL-RISK-SMART1"),"VMM-INDEPENDENT-RISK")
i=.VMMTradableInstrument~new("ACME-US","ACME","US000000SMA1","XNAS","ORDINARY","USD","USD","USD","RES-SMART-XNAS")
d=.VMMAlgorithmDecision~new("DEC-SMART-1","ALG-SMART-1",i,"BUY",1000,"20260828T140000","MKT-SMART1","SIG-SMART1","VMM-ALGO")
v~recordAlgorithmDecision(d); o=v~createProprietaryOrder("ORD-SMART-1","DEC-SMART-1","LIMIT",101,"20260828T140001","VMM-ALGO-EXEC")
root="./tmp_queue_smart_route_"||.DateTime~new~microseconds
x=.VMMSmartExecutionService~new(v,root)
rA=.VMMVenueRoute~new("XNAS_DIRECT","XNAS","ADAPTER_DIRECT","VMM_VENUE_DIRECT","DIRECT_XNAS_CLEARER","US",3,2,5000,10,"POL-DIRECT","ROUTE-EVID-DIRECT")
rB=.VMMVenueRoute~new("XNAS_BROKER","XNAS","ADAPTER_BROKER","VMM_VENUE_BROKER","BROKER_XNAS_CLEARER","US",5,0,5000,20,"POL-BROKER","ROUTE-EVID-BROKER")
x~registerRoute(rA); x~registerRoute(rB)
/* Broker has the lower raw ask, but its fee makes the direct route cheaper net. */
x~recordVenueQuote(.VMMVenueQuote~new("VQ-A","XNAS_DIRECT",i~identityKey,99.98,100.00,5000,"20260828T140001","20260828T140100","QUOTE-A","MKT-DATA"))
x~recordVenueQuote(.VMMVenueQuote~new("VQ-B","XNAS_BROKER",i~identityKey,99.97,99.99,5000,"20260828T140001","20260828T140100","QUOTE-B","MKT-DATA"))
r=v~routeMarketOrder("ORD-SMART-1","SMART-IDEMP-1","SMART-CORR-1","20260828T140002","VMM-SMART-ROUTER")
call assertTrue r~ok,"smart order routed"
call assertEq "XNAS_DIRECT",x~routeDecision("ORD-SMART-1")~routeId,"router uses net executable price"
call assertEq 1,x~commandDepth("XNAS_DIRECT"),"selected route has command"
call assertEq 0,x~commandDepth("XNAS_BROKER"),"unselected route has no command"
a=.VMMSmartVenueAdapter~new(x,rA)
call assertTrue a~processNextCommand("20260828T140003")~ok,"selected adapter acknowledges"
call assertTrue x~processNextEvent~ok,"ack applied"
call assertTrue a~publishFill("ORD-SMART-1","SMART-FILL-1","XNAS-D-1",400,100,"USD","20260828T140004","SETTLE-1")~ok,"first partial fill queued"
call assertTrue x~processNextEvent~ok,"first partial fill applied"
call assertEq "PART_FILLED",o~executionState,"partial fill retained"
call assertTrue a~publishFill("ORD-SMART-1","SMART-FILL-2","XNAS-D-2",600,100.1,"USD","20260828T140005","SETTLE-2")~ok,"second fill queued"
call assertTrue x~processNextEvent~ok,"second fill applied"
call assertEq "FILLED",o~executionState,"fills aggregate to terminal order"
call assertNear 100.06,o~averagePrice,0.000001,"weighted average fill price"
call assertNear 30.018,o~executionFeeTotal,0.000001,"venue fees aggregate across partial fills"
call assertNear 20.012,o~executionRebateTotal,0.000001,"venue rebates aggregate separately from fees"
call assertNear -100070.006,v~tradingCashBalance("USD"),0.000001,"execution fees reduce VMM trading cash"
say "PASS test_smart_route_net_price_fees"
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
