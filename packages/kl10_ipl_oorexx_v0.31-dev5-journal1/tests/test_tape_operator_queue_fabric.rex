numeric digits 30
parse arg tapePath
if tapePath="" then do
  say "usage: rexx test_tape_operator_queue_fabric.rex tape.tap"
  exit 2
end

manager=.ObjectQueueManager~new("",.QueueGraphPayloadCodec~new,"admin")
call must manager~createQueue("KL10.OPERATOR","TEMPORARY","OPS",100,"admin"),"create queue"
call must manager~grant("KL10.OPERATOR","kl10-panel",.QueueAccess~PUT,"admin"),"grant put"
call must manager~grant("KL10.OPERATOR","auditor",.QueueAccess~GET,"admin"),"grant get"

tape=.KL10MassbusTape~new~~mount(tapePath)
sink=.KL10TapeOperatorQueueFabricSink~new(manager,"KL10.OPERATOR","kl10-panel")
panel=.KL10TapeOperatorPanel~new(tape,sink)

snap=panel~snapshot
r=panel~press("OFFLINE",snap~stateToken,"museum-attendant","panel-0001")
call eq r~ok,1,"button accepted"

getResult=manager~get("KL10.OPERATOR","auditor")
call must getResult,"get event"
event=getResult~value~payload

call eq event~eventType,"KL10_TAPE_OPERATOR_BUTTON","event type"
call eq event~actor,"museum-attendant","actor"
call eq event~correlationId,"panel-0001","correlation"
call eq event~button,"OFFLINE","button"
call eq event~accepted,1,"accepted"
call eq event~before~online,1,"before online"
call eq event~after~online,0,"after offline"

say "PASS test_tape_operator_queue_fabric"
exit 0

must: procedure
  use arg operationResult,label
  if \operationResult~ok then do
    say "FAIL" label operationResult~code operationResult~detail
    exit 1
  end
  return

eq: procedure
  use arg actual,expected,label
  if actual \= expected then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return

::requires "../KL10TapeOperator.cls"
::requires "ObjectQueueFabric.cls"
