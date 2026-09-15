v=.VectorMeridianMarkets~new
s=.VMMAlgorithmStrategy~new("ALG-REST-1","4.0","SMART_MM","SRC-REST","MODEL-REST",5000,10000,"POL-REST")
v~registerStrategy(s); v~enableStrategy("ALG-REST-1","VMM-RISK")
v~setFirmRiskLimits(.VMMFirmRiskLimits~new("RISK-REST","USD",100000,50000,100000,100000,"POL-RISK-REST"),"VMM-INDEPENDENT-RISK")
i=.VMMTradableInstrument~new("REST-US","REST","US000000RST1","XNYS","ORDINARY","USD","USD","USD","RES-REST-XNYS")
d=.VMMAlgorithmDecision~new("DEC-REST-1","ALG-REST-1",i,"BUY",500,"20260828T142000","MKT-REST","SIG-REST","VMM-ALGO")
v~recordAlgorithmDecision(d); o=v~createProprietaryOrder("ORD-REST-1","DEC-REST-1","LIMIT",25,"20260828T142001","VMM-ALGO-EXEC")
root="./tmp_queue_smart_restrict_"||.DateTime~new~microseconds
x=.VMMSmartExecutionService~new(v,root)
r=.VMMVenueRoute~new("XNYS_DIRECT","XNYS","ADAPTER_NY","VMM_VENUE_NY","NY_CLEARER","US",1,0,5000,10,"POL-NY","ROUTE-NY")
x~registerRoute(r); x~recordVenueQuote(.VMMVenueQuote~new("VQ-REST","XNYS_DIRECT",i~identityKey,24.9,25.0,5000,"20260828T142001","20260828T142100","QUOTE-REST","MKT-DATA"))
rest=.VMMMarketRestriction~new("REST-SANCTIONS-1",i~identityKey,"XNYS","SETTLEMENT_IMPAIRED","SANCTIONS_ASSET_FREEZE","20260828T142001","SANCTIONS-EVID-1","VMM-COMPLIANCE","US")
v~recordMarketRestriction(rest)
signal on syntax name blocked
ignore=v~routeMarketOrder("ORD-REST-1","REST-IDEMP-1","REST-CORR-1","20260828T142002","VMM-SMART-ROUTER")
raise syntax 88.900 array("expected sanctions restriction")
blocked:
signal off syntax
call assertEq 0,x~commandDepth("XNYS_DIRECT"),"settlement impairment blocks before queue admission"
call assertEq "CREATED",o~executionState,"blocked order remains unrouted"
v~liftMarketRestriction("REST-SANCTIONS-1","VMM-COMPLIANCE","20260828T142003")
call assertTrue v~routeMarketOrder("ORD-REST-1","REST-IDEMP-2","REST-CORR-2","20260828T142004","VMM-SMART-ROUTER")~ok,"lifted restriction permits routing"
call assertEq 1,x~commandDepth("XNYS_DIRECT"),"permitted order reaches selected route queue"
say "PASS test_smart_market_restriction"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)

::requires "VMMSmartExecution.cls"
