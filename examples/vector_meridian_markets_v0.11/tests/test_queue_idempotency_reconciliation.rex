v=.VectorMeridianMarkets~new
s=.VMMAlgorithmStrategy~new("ALG-Q-2","3.0","QUEUE_NATIVE_MM","SRC-Q2","MODEL-Q2",1000000,2000000,"POL-Q2")
v~registerStrategy(s); v~enableStrategy("ALG-Q-2","VMM-RISK")
i=.VMMTradableInstrument~new("ACME-L","ACME","GB000000ACM2","XLON","ORDINARY","GBP","GBP","GBP","RES-ACME-XLON")
d=.VMMAlgorithmDecision~new("DEC-Q-2","ALG-Q-2",i,"SELL",50000,"20260828T131000","MKT-Q2","SIG-Q2","VMM-ALGO")
v~recordAlgorithmDecision(d); o=v~createProprietaryOrder("ORD-Q-2","DEC-Q-2","MARKET",0,"20260828T131001","VMM-ALGO-EXEC")
root="./tmp_queue_idem_"||.DateTime~new~microseconds
x=.VMMQueueExecutionService~new(v,root)
r1=v~routeMarketOrder("ORD-Q-2","IDEMP-Q-2","CORR-Q-2","20260828T131002","VMM-EXEC-ROUTER")
r2=v~routeMarketOrder("ORD-Q-2","IDEMP-Q-2","CORR-Q-2","20260828T131002","VMM-EXEC-ROUTER")
call assertTrue r1~ok & r2~ok,"idempotent route succeeds"
call assertEq r1~value~commandId,r2~value~commandId,"same idempotency key returns same command"
call assertEq 1,x~commandDepth,"idempotent retry does not duplicate queue work"
a=.VMMQueueVenueAdapter~new(x,"SIM-XLON")
call assertTrue a~processNextCommand("20260828T131003")~ok,"venue accepts order"
call assertTrue x~processNextEvent~ok,"initial ack applied"
call assertEq "ACKNOWLEDGED",o~executionState,"initial ack state"
call assertTrue a~publishUnknown("ORD-Q-2","RECON-Q-UNKNOWN","20260828T131004")~ok,"uncertain venue status queued"
call assertTrue x~processNextEvent~ok,"unknown status applied"
call assertEq "UNKNOWN_PENDING_RECONCILIATION",o~executionState,"unknown never becomes invented failure"
call assertTrue a~publishReconciledAcknowledged("ORD-Q-2","RECON-Q-ACK","20260828T131005")~ok,"venue reconciliation queued"
call assertTrue x~processNextEvent~ok,"reconciliation applied"
call assertEq "ACKNOWLEDGED",o~executionState,"reconciliation restores known live state"
say "PASS test_queue_idempotency_reconciliation"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)

::requires "VMMQueueExecution.cls"
