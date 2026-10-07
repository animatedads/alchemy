/* Intention Service dev9 hints advise Luna and shape selected action plans. */
service=.IntentionService~new
service~registerBucket("LLM_CODING",.IntentionBucketPolicy~new("FLEXIBLE",60,12,.false,.false))
service~register("write method",.HintEvent~new("WRITE_METHOD"),"LLM_CODING")
gateway=.LlmCodingIntentionGateway~new(service)
hints=.LlmCodingHintBridge~new
session=.LlmCodingDeskSession~new(.HintDesk~new,"demo/house.rex","pkg-1","hint-test","tester")
wb=.LlmCodingWorkbench~new(session,gateway,.nil,hints)

turn=wb~prepareMethodTurn("Make Door.isOpen correct","Door","isOpen")~asDirectory
semantic=turn["semantic_context"]
call assert semantic~hasIndex("hints"),"turn exposes structured hints"
call assert semantic["hints"]~items>=1,"at least semantic-method hint"
first=semantic["hints"]~at(1)
call assert first["state"]=="SEMANTIC_METHOD_TARGET","semantic target hint state"
call assert first["intention"]=="WRITE_METHOD","hint recommends bounded method write path"

wb~recordVerification("REXXC","FAIL",.directory~new)
turn2=wb~prepareMethodTurn("Make Door.isOpen correct","Door","isOpen")~asDirectory
foundFail=.false
 do h over turn2["semantic_context"]["hints"]
   if h["state"]=="VERIFICATION_FAILED" then foundFail=.true
 end
call assert foundFail,"compile failure projects repair hint"

args=.directory~new
args["class_name"]="Door"; args["method_name"]="isOpen"; args["method_body"]="return .true"
model=.LlmCodingDecision~new("WRITE_METHOD",args)
decision=gateway~interpret(model)
call assert decision~status=="READY","hint does not block READY"
call assert decision~proposedPlan\==.nil,"plan-only hint attached to selected action"
call assert decision~proposedPlan~steps~items>=3,"WRITE_METHOD advisory plan has inspect/write/verify"
call assert gateway~commit(decision)=="WRITE_METHOD","hint cannot replace committed dispatch"

say "PASS Intention Service dev9 coding hints -> Luna guidance + advisory plan"
exit 0

::routine assert
  use strict arg ok,label
  if \ok then do; say "FAIL" label; raise syntax 88.900 array("test assertion failed"); end

::class HintDesk public
::method buttons
  return .array~of("VIEW_CLASS","VIEW_METHOD","WRITE_METHOD","MATERIALISE")
::method classFileModel
  d=.directory~new; d["schema"]="hint-test"; return d
::method press
  use strict arg action,request
  action=translate(action)
  if action=="VIEW_CLASS" then do
    d=.directory~new; d["object_type"]="CLASS"; d["source_spelling"]=request["class_name"]; d["methods"]=.array~new; d["attributes"]=.array~new; return d
  end
  if action=="VIEW_METHOD" then do
    d=.directory~new; d["object_type"]="METHOD"; d["class_name"]=request["class_name"]; d["source_spelling"]=request["method_name"]; d["projection"]="return .false"; return d
  end
  return .directory~new

::requires "../src/LlmCodingWorkbench.cls"
::requires "../src/LlmCodingIntentionGateway.cls"
::requires "../src/LlmCodingHintBridge.cls"
::requires "IntentionService.cls"
::requires "IntentionProviders.cls"

::class HintEvent public
::method init
  expose value
  use strict arg valueArg
  value=valueArg
::method invoke
  expose value
  use arg decision
  return value
