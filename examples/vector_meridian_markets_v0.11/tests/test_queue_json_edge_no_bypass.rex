v=.VectorMeridianMarkets~new
s=.VMMAlgorithmStrategy~new("ALG-Q-3","3.0","QUEUE_NATIVE_MM","SRC-Q3","MODEL-Q3",1000000,2000000,"POL-Q3")
v~registerStrategy(s); v~enableStrategy("ALG-Q-3","VMM-RISK")
i=.VMMTradableInstrument~new("XYZ-N","XYZ","US000000XYZ9","XNYS","ORDINARY","USD","USD","USD","RES-XYZ-XNYS")
d=.VMMAlgorithmDecision~new("DEC-Q-3","ALG-Q-3",i,"BUY",1000,"20260828T132000","MKT-Q3","SIG-Q3","VMM-ALGO")
v~recordAlgorithmDecision(d); o=v~createProprietaryOrder("ORD-Q-3","DEC-Q-3","LIMIT",10.0,"20260828T132001","VMM-ALGO-EXEC")
root="./tmp_queue_json_"||.DateTime~new~microseconds
x=.VMMQueueExecutionService~new(v,root)
call assertTrue v~routeMarketOrder("ORD-Q-3","IDEMP-Q-3","CORR-Q-3","20260828T132002","VMM-EXEC-ROUTER")~ok,"route order"
a=.VMMQueueVenueAdapter~new(x,"SIM-XNYS")
call assertTrue a~processNextCommand("20260828T132003")~ok,"venue ack queued"
call assertTrue x~processNextEvent~ok,"ack applied"
bypass=.false
signal on syntax name bypassBlocked
ignore=v~fillMarketOrder("ILLEGAL-FILL","ORD-Q-3","XNYS-ILLEGAL",1000,9.9,"20260828T132004","EXTERNAL_CLEARER")
signal off syntax
raise syntax 88.900 array("direct fill bypass unexpectedly succeeded")
bypassBlocked:
  signal off syntax
  bypass=.true
call assertTrue bypass,"bound engine rejects direct execution fill"
j=.VMMExecutionJsonAdapter~new(x,"JSON-XNYS")
dj=.directory~new; dj["protocol"]=.VMMExecutionBuild~protocol; dj["type"]="FILL"; dj["event_id"]="JSON-EVT-Q3"; dj["command_id"]=o~executionCommandId; dj["order_id"]=o~orderId; dj["idempotency_key"]="JSON-FILL-Q3"; dj["correlation_id"]=o~executionCorrelationId; dj["fill_id"]="FILL-Q3"; dj["venue_execution_ref"]="XNYS-EXEC-Q3"; dj["notional"]=1000; dj["price"]=9.9; dj["currency"]="USD"; dj["at"]="20260828T132005"; dj["executing_counterparty"]="EXTERNAL_CLEARER"; dj["settlement_ref"]="SETTLE-Q3"
wire=.JSON~toJSON(dj)
call assertTrue j~eventFromJson(wire)~ok,"JSON edge converts event to Queue Fabric"
call assertEq 0,v~inventoryFor(i),"JSON arrival alone cannot mutate VMM inventory"
call assertEq 1,x~eventDepth,"JSON edge produced queued execution event"
call assertTrue x~processNextEvent~ok,"queue consumer applies JSON-originated fill"
call assertEq 1000,v~inventoryFor(i),"only queue-consumed fill mutates inventory"
say "PASS test_queue_json_edge_no_bypass"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)

::requires "VMMQueueExecution.cls"
