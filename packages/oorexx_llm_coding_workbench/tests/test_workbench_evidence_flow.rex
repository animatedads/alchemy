parse source . . here
root=filespec("L",here)||"/.."
call directory root
catalogue=value("LLM_CODING_CATALOGUE",,"ENVIRONMENT")
if catalogue=="" then catalogue=root||"/config/coding_intention_dev13_rexx_catalogue.json"

service=.IntentionService~new
gateway=.LlmCodingIntentionGateway~new(service)
wb=.LlmCodingWorkbench~new(.FixtureSession~new,gateway)

args=.directory~new
args["class_name"]="Demo"; args["method_name"]="probe"
args["operation"]="GET_NAMED_MEMBER"; args["source"]="x"; args["member"]="rooms"; args["target"]="rooms"
out=wb~apply(.LlmCodingDecision~new("CODING_OPERATION",args))
call assertEq "EVIDENCE_CLARIFY",out["semantic_step_status"],"workbench exposes evidence clarification"
q=translate(out["question"])
ok = pos("KEYED MEMBER ACCESS",q) > 0
call assertTrue ok, "clarification retained for model"

ignored=wb~hintObjectShape("Demo","probe","x","DIRECTORY",85,"USER_HINT")
out=wb~apply(.LlmCodingDecision~new("CODING_OPERATION",args))
call assertEq "ACCEPTED",out["semantic_step_status"],"same operation accepted after evidence refresh"

create=.directory~new
create["class_name"]="Demo"; create["method_name"]="probe"; create["operation"]="CREATE_DIRECTORY"; create["target"]="d"
out=wb~apply(.LlmCodingDecision~new("CODING_OPERATION",create))
call assertEq "ACCEPTED",out["semantic_step_status"],"semantic construction accepted"

msg=.directory~new
msg["class_name"]="Demo"; msg["method_name"]="probe"; msg["operation"]="SEND_MESSAGE"; msg["source"]="d"; msg["message"]="items"; msg["target"]="count"
out=wb~apply(.LlmCodingDecision~new("CODING_OPERATION",msg))
call assertEq "ACCEPTED",out["semantic_step_status"],"contract-proven message accepted"
count=wb~semanticBridge("Demo","probe")~objectEvidence("count")
call assertEq "NUMBER",count["shape"],"result evidence propagated through workbench"
call assertEq "CLASS_METHOD_CONTRACT",count["source"],"result evidence provenance"

say "PASS workbench evidence clarification -> refresh -> semantic result propagation"
exit 0

assertEq: procedure
  use arg expected,actual,label
  if expected==actual then return
  say "FAIL" label "expected="expected "actual="actual
  exit 1
assertTrue: procedure
  use arg ok,label
  if ok then return
  say "FAIL" label
  exit 1

::class FixtureSession public
::method memberPath; return "demo/evidence.rex"
::method controls; return .directory~new

::requires "../src/LlmCodingWorkbench.cls"
::requires "../src/LlmCodingIntentionGateway.cls"
::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
