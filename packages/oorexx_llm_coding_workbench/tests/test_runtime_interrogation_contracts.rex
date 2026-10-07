parse source . . here
root=filespec("L",here)||"/.."
call directory root
catalogue=value("LLM_CODING_CATALOGUE",,"ENVIRONMENT")
if catalogue=="" then catalogue=root||"/config/coding_intention_dev13_rexx_catalogue.json"
k=.LlmRexxKnowledgeCatalogue~new(catalogue)
call assert k~source=="coding_intention_steps_v0.1-dev13","dev9 catalogue source"
call assert k~resolveMethodContract("Directory","items")\==.nil,"Directory.items contract"
call assert k~resolveMethodContract("JSON","load")==.nil,"invented JSON.load has no contract"

/* Runtime witness: confidence 100 and hasMethod() is authoritative. */
b=.LlmSemanticCodingBridge~new("Probe","count",k)
d=.Directory~new; d["x"]="y"
e=b~bindRuntimeObject("d",d)
call assert e~shape=="DIRECTORY","runtime Directory shape"
call assert e~className=="Directory","runtime Directory class"
call assert e~confidence==100,"runtime evidence confidence"
a=.directory~new; a["source"]="d"; a["message"]="items"; a["target"]="count"
s=b~addOperation("SEND_MESSAGE",a)
proof=s~args["message_evidence"]
call assert proof["allowed"],"runtime hasMethod permits items"
call assert proof["evidence_kind"]=="RUNTIME_HASMETHOD","runtime evidence kind"
call assert b~renderMethodBody=="count = d~items","runtime-evidenced send renders"

/* A runtime witness must fail closed for an invented message. */
proofBad=b~messageEvidence("d","frobnicate")
call assert \proofBad["allowed"],"runtime evidence rejects invented method"
call assert pos("does not have method frobnicate",proofBad["reason"])>0,"runtime rejection explains method absence"
signal on syntax name badRuntime
bad=.directory~new; bad["source"]="d"; bad["message"]="frobnicate"
ignored=b~addOperation("SEND_MESSAGE",bad)
signal off syntax
say "FAIL: invented runtime method was accepted"
exit 1
badRuntime:
signal off syntax

/* Known semantic construction gets a dev9 class contract even without a live witness. */
b2=.LlmSemanticCodingBridge~new("Probe","contract",k)
a=.directory~new; a["target"]="d2"; ignored=b2~addOperation("CREATE_DIRECTORY",a)
a=.directory~new; a["source"]="d2"; a["message"]="items"; a["target"]="n"; s2=b2~addOperation("SEND_MESSAGE",a)
proof2=s2~args["message_evidence"]
call assert proof2["allowed"],"class contract permits Directory.items"
call assert proof2["evidence_kind"]=="CLASS_CONTRACT","class-contract evidence kind"
call assert pos("Directory",proof2["class_name"])>0,"class contract names Directory"

say "PASS Coding Intention dev13 runtime interrogation + class/method contract gating"
exit 0

assert: procedure
  use arg ok,label
  if \ok then do; say "FAIL:" label; exit 1; end
  return

::requires "LlmSemanticCodingBridge.cls"
