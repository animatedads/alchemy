v=.VectorMeridianMarkets~new
s=.VMMAlgorithmStrategy~new("ALG-LOC-1","4.0","SHORT_MM","SRC-LOC","MODEL-LOC",5000,10000,"POL-LOC")
v~registerStrategy(s); v~enableStrategy("ALG-LOC-1","VMM-RISK")
v~setFirmRiskLimits(.VMMFirmRiskLimits~new("RISK-LOC","USD",100000,50000,100000,100000,"POL-RISK-LOC"),"VMM-INDEPENDENT-RISK")
i=.VMMTradableInstrument~new("SHORT-US","SHORT","US000000LOC1","XNAS","ORDINARY","USD","USD","USD","RES-LOC-XNAS")
d=.VMMAlgorithmDecision~new("DEC-LOC-1","ALG-LOC-1",i,"SELL",1000,"20260828T141000","MKT-LOC","SIG-LOC","VMM-ALGO")
v~recordAlgorithmDecision(d); o=v~createProprietaryOrder("ORD-LOC-1","DEC-LOC-1","LIMIT",50,"20260828T141001","VMM-ALGO-EXEC")
root="./tmp_queue_smart_locate_"||.DateTime~new~microseconds
x=.VMMSmartExecutionService~new(v,root)
r=.VMMVenueRoute~new("XNAS_LOCATE","XNAS","ADAPTER_LOC","VMM_VENUE_LOC","LOCATE_CLEARER","US",1,0,5000,10,"POL-LOC-ROUTE","ROUTE-LOC")
x~registerRoute(r); x~recordVenueQuote(.VMMVenueQuote~new("VQ-LOC","XNAS_LOCATE",i~identityKey,49.95,50.05,5000,"20260828T141001","20260828T141100","QUOTE-LOC","MKT-DATA"))
signal on syntax name noLocate
ignore=v~routeMarketOrder("ORD-LOC-1","LOC-IDEMP-NO","LOC-CORR-NO","20260828T141002","VMM-SMART-ROUTER")
raise syntax 88.900 array("expected missing short locate rejection")
noLocate:
signal off syntax
call assertEq "CREATED",o~executionState,"missing locate rejected before route state mutation"
call assertEq 0,x~commandDepth("XNAS_LOCATE"),"missing locate creates no queue command"
l=.VMMShortLocate~new("LOCATE-1",i~identityKey,"EXTERNAL_PRIME_BROKER",1000,25,"20260828T150000","BORROW-EVID-1","VMM-STOCK-BORROW")
v~registerShortLocate(l)
call assertTrue v~routeMarketOrder("ORD-LOC-1","LOC-IDEMP-YES","LOC-CORR-YES","20260828T141003","VMM-SMART-ROUTER")~ok,"locate-backed short routed"
res=v~shortLocateReservation("ORD-LOC-1")
call assertEq 1000,res~reservedNotional,"full new short exposure reserved"
call assertEq 1000,l~reservedNotional,"locate capacity reserved"
a=.VMMSmartVenueAdapter~new(x,r)
call assertTrue a~processNextCommand("20260828T141004")~ok,"short accepted at venue"
call assertTrue x~processNextEvent~ok,"short ack applied"
call assertTrue a~publishFill("ORD-LOC-1","LOC-FILL-1","LOC-EXEC-1",400,49.9,"USD","20260828T141005","SETTLE-LOC-1")~ok,"partial short fill"
call assertTrue x~processNextEvent~ok,"partial short fill applied"
call assertEq 400,l~consumedNotional,"filled short consumes locate"
call assertEq 600,l~reservedNotional,"unfilled short remains reserved"
call assertEq -400,v~inventoryFor(i),"short inventory booked"
v~setKillSwitch(.true,"VMM-INDEPENDENT-RISK","TEST_LOCATE_CANCEL","20260828T141006")
call assertEq "CANCEL_PENDING",o~executionState,"kill switch requests venue cancellation"
call assertTrue a~processNextCommand("20260828T141007")~ok,"cancel command processed"
call assertTrue x~processNextEvent~ok,"cancel confirmation applied"
call assertEq 0,l~reservedNotional,"unused locate released on cancellation"
call assertEq 400,l~consumedNotional,"used locate remains consumed"
call assertEq "RELEASED",res~state,"order locate reservation closed"
say "PASS test_smart_short_locate_lifecycle"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)

::requires "VMMSmartExecution.cls"
