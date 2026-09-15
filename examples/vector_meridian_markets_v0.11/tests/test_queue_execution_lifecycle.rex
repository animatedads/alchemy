v=.VectorMeridianMarkets~new
s=.VMMAlgorithmStrategy~new("ALG-Q-1","3.0","QUEUE_NATIVE_MM","SRC-Q1","MODEL-Q1",1000000,2000000,"POL-Q1")
v~registerStrategy(s); v~enableStrategy("ALG-Q-1","VMM-RISK")
v~setFirmRiskLimits(.VMMFirmRiskLimits~new("RISK-Q1","USD",5000000,2000000,2000000,500000,"POL-RISK-Q1"),"VMM-INDEPENDENT-RISK")
i=.VMMTradableInstrument~new("ACME-US","ACME","US000000ACM1","XNAS","ORDINARY","USD","USD","USD","RES-ACME-XNAS")
d=.VMMAlgorithmDecision~new("DEC-Q-1","ALG-Q-1",i,"BUY",100000,"20260828T130000","MKT-Q1","SIG-Q1","VMM-ALGO")
v~recordAlgorithmDecision(d)
o=v~createProprietaryOrder("ORD-Q-1","DEC-Q-1","LIMIT",99.5,"20260828T130001","VMM-ALGO-EXEC")
root="./tmp_queue_lifecycle_"||.DateTime~new~microseconds
x=.VMMQueueExecutionService~new(v,root)
call assertEq 1,v~executionServiceBound,"Queue Fabric execution service bound"
r=v~routeMarketOrder("ORD-Q-1","IDEMP-Q-1","CORR-Q-1","20260828T130002","VMM-EXEC-ROUTER")
call assertTrue r~ok,"order routed"
call assertEq "ROUTED",o~executionState,"order is routed, not assumed executed"
call assertEq 1,x~commandDepth,"one durable execution command"
a=.VMMQueueVenueAdapter~new(x,"SIM-XNAS")
vr=a~processNextCommand("20260828T130003")
call assertTrue vr~ok,"venue consumes command"
call assertEq 1,x~eventDepth,"venue acknowledgement is a queued event"
pr=x~processNextEvent
call assertTrue pr~ok,"VMM consumes acknowledgement"
call assertEq "ACKNOWLEDGED",o~executionState,"venue acknowledgement advances lifecycle"
call assertEq "VENUE-ORD-Q-1",o~venueOrderRef,"venue order reference retained"
fr=a~publishFill("ORD-Q-1","FILL-Q-1","XNAS-EXEC-Q1",100000,99.4,"USD","20260828T130004","EXTERNAL_CLEARER","SETTLE-Q1")
call assertTrue fr~ok,"venue fill published"
call assertTrue x~processNextEvent~ok,"VMM consumes fill"
call assertEq "FILLED",o~executionState,"execution lifecycle filled"
call assertEq "FILLED",o~state,"economic order filled"
call assertEq 100000,v~inventoryFor(i),"venue fill changes VMM inventory only after queued event"
say "PASS test_queue_execution_lifecycle"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)

::requires "VMMQueueExecution.cls"
