v=.VectorMeridianMarkets~new
s=.VMMAlgorithmStrategy~new("ALG-Q-4","3.0","QUEUE_NATIVE_MM","SRC-Q4","MODEL-Q4",1000000,2000000,"POL-Q4")
v~registerStrategy(s); v~enableStrategy("ALG-Q-4","VMM-RISK")
i=.VMMTradableInstrument~new("ABC-US","ABC","US000000ABC4","XNAS","ORDINARY","USD","USD","USD","RES-ABC-XNAS")
d=.VMMAlgorithmDecision~new("DEC-Q-4","ALG-Q-4",i,"BUY",1000,"20260828T133000","MKT-Q4","SIG-Q4","VMM-ALGO")
v~recordAlgorithmDecision(d); o=v~createProprietaryOrder("ORD-Q-4","DEC-Q-4","LIMIT",20,"20260828T133001","VMM-ALGO-EXEC")
root="./tmp_queue_kill_"||.DateTime~new~microseconds
x=.VMMQueueExecutionService~new(v,root); a=.VMMQueueVenueAdapter~new(x,"SIM-XNAS")
call assertTrue v~routeMarketOrder("ORD-Q-4","IDEMP-Q-4","CORR-Q-4","20260828T133002","VMM-EXEC-ROUTER")~ok,"route order"
call assertTrue a~processNextCommand("20260828T133003")~ok,"venue accepts order"
call assertTrue x~processNextEvent~ok,"ack applied"
call assertEq "ACKNOWLEDGED",o~executionState,"live at venue"
v~setKillSwitch(.true,"VMM-INDEPENDENT-RISK","TEST_KILL","20260828T133004")
call assertEq "CANCEL_PENDING",o~executionState,"kill switch requests, not invents, cancellation"
call assertEq "OPEN",o~state,"economic order remains fillable while cancellation races"
call assertEq 1,x~commandDepth,"cancel request sent through Queue Fabric"
/* A real venue fill may race the cancellation command. Book it as fact. */
call assertTrue a~publishFill("ORD-Q-4","FILL-Q4-RACE","XNAS-RACE",400,19.9,"USD","20260828T1330045","EXTERNAL_CLEARER")~ok,"racing fill queued"
call assertTrue x~processNextEvent~ok,"racing fill booked"
call assertEq 400,v~inventoryFor(i),"racing fill is not rejected by kill switch"
call assertEq "PART_FILLED",o~executionState,"partial fill remains explicit"
/* The queued cancellation is then confirmed for the remaining quantity. */
call assertTrue a~processNextCommand("20260828T133005")~ok,"venue processes cancellation"
call assertTrue x~processNextEvent~ok,"cancel confirmation applied"
call assertEq "CANCELLED",o~executionState,"venue-confirmed cancellation is terminal"
call assertEq "CANCELLED",o~state,"remaining order cancelled"
call assertEq 400,o~filledNotional,"executed quantity survives cancellation"
say "PASS test_queue_kill_switch_cancel_race"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)

::requires "VMMQueueExecution.cls"
