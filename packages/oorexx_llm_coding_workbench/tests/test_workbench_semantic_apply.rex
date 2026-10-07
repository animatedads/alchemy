/* End-to-end workbench semantic step accumulation -> deterministic WRITE_METHOD. */
desk=.FakeDesk~new
session=.LlmCodingDeskSession~new(desk,"demo/house.rex","PKG1","project","worker")
intentions=.PassthroughIntentions~new
wb=.LlmCodingWorkbench~new(session,intentions)

args=.directory~new; args["class_name"]="House"; args["method_name"]="openDoor"; args["attribute_name"]="door"; args["value"]="open"
o=wb~apply(.LlmCodingDecision~new("CODING_SET_ATTRIBUTE",args))
call assertEq "ACCEPTED",o["semantic_step_status"],"set step accepted"
args=.directory~new; args["class_name"]="House"; args["method_name"]="openDoor"; args["attribute_name"]="door"; args["condition"]="open"; args["return_value"]="false"
o=wb~apply(.LlmCodingDecision~new("CODING_RETURN_IF_ALREADY",args))
call assertEq "ACCEPTED",o["semantic_step_status"],"guard step accepted"
args=.directory~new; args["class_name"]="House"; args["method_name"]="openDoor"
o=wb~apply(.LlmCodingDecision~new("CODING_APPLY_METHOD",args))
call assertEq "WRITE_METHOD",o["dispatch"],"semantic apply routes through WRITE_METHOD intention"
call assertEq "WRITE_METHOD",desk~lastAction,"desk receives write method"
expected='expose door'||.endOfLine||'if door == "open" then return .false'||.endOfLine||'door = "open"'||.endOfLine||'return .true'
call assertEq expected,desk~lastRequest["method_body"],"desk receives deterministic generated body"
call assertEq "PKG1",desk~lastRequest["package_object_id"],"package authority remains controller-owned"
call assertEq "demo/house.rex",desk~lastRequest["member_path"],"path authority remains controller-owned"
say "PASS workbench semantic coding steps -> intention gate -> desk WRITE_METHOD"
exit 0

::class FakeDesk public
::attribute lastAction get
::attribute lastRequest get
::method buttons
  return .array~of("VIEW_CLASS","VIEW_METHOD","WRITE_METHOD")
::method classFileModel
  d=.directory~new; d["model"]="semantic"; return d
::method press
  expose lastAction lastRequest
  use arg action,request
  lastAction=action; lastRequest=request
  d=.directory~new; d["action"]=action; d["ok"]=.true; return d

::class PassthroughIntentions public
::method interpret
  use arg decision
  return .FakeIntentionDecision~new(decision~action)
::method commit
  use arg decision
  return decision~action
::class FakeIntentionDecision public
::attribute status get
::attribute question get
::attribute action get
::method init
  expose status question action
  use arg a
  status="READY"; question=""; action=a

::routine assertEq
  use arg expected,actual,label
  if expected\==actual then do; say "FAIL" label "expected="expected "actual="actual; raise syntax 88.900 array("test assertion failed"); end

::requires "../src/LlmCodingWorkbench.cls"
