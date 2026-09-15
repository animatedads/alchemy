v=.VectorMeridianMarkets~new
s=.VMMAlgorithmStrategy~new("ALG-Q-5","3.0","QUEUE_NATIVE_MM","SRC-Q5","MODEL-Q5",1000000,2000000,"POL-Q5")
v~registerStrategy(s); v~enableStrategy("ALG-Q-5","VMM-RISK")
i=.VMMTradableInstrument~new("PERSIST-L","PERSIST","GB000000PST5","XLON","ORDINARY","GBP","GBP","GBP","RES-PERSIST-XLON")
d=.VMMAlgorithmDecision~new("DEC-Q-5","ALG-Q-5",i,"SELL",25000,"20260828T134000","MKT-Q5","SIG-Q5","VMM-ALGO")
v~recordAlgorithmDecision(d); o=v~createProprietaryOrder("ORD-Q-5","DEC-Q-5","MARKET",0,"20260828T134001","VMM-ALGO-EXEC")
root="./tmp_queue_persist_"||.DateTime~new~microseconds
x=.VMMQueueExecutionService~new(v,root)
call assertTrue v~routeMarketOrder("ORD-Q-5","IDEMP-Q-5","CORR-Q-5","20260828T134002","VMM-EXEC-ROUTER")~ok,"persistent command routed"
call assertEq 1,x~commandDepth,"first manager sees command"
/* New manager/service instance over the same durable queue state reconstructs the payload graph. */
v2=.VectorMeridianMarkets~new
x2=.VMMQueueExecutionService~new(v2,root,"VMM_EXECUTION_RECOVERY_BIND")
call assertEq 1,x2~commandDepth,"recovered manager sees durable command"
claim=x2~claimNextCommand
call assertTrue claim~ok,"recovered command claimable"
c=claim~value~payload
call assertTrue c~isA(.VMMExecutionCommand),"recovered payload retains execution-command type"
call assertEq "ORD-Q-5",c~orderId,"order identity survives queue recovery"
call assertEq "GB000000PST5",c~isin,"ISIN survives queue recovery"
call assertEq "XLON",c~venueMic,"venue identity survives queue recovery"
call assertEq "CORR-Q-5",c~correlationId,"correlation survives queue recovery"
say "PASS test_queue_command_persistence"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)

::requires "VMMQueueExecution.cls"
