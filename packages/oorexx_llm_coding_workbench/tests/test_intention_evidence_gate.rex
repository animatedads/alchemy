parse source . . here
root=filespec("L",here)||"/.."
call directory root
catalogue=value("LLM_CODING_CATALOGUE",,"ENVIRONMENT")
if catalogue=="" then catalogue=root||"/config/coding_intention_dev13_rexx_catalogue.json"

service=.IntentionService~new
gate=.LlmCodingEvidenceGate~new(service)
k=.LlmRexxKnowledgeCatalogue~new(catalogue)
bridge=.LlmSemanticCodingBridge~new("EvidenceDemo","probe",k)

/* Meaning is clear, but keyed access must not be rendered without shape evidence. */
a=.directory~new; a["source"]="x"; a["member"]="rooms"; a["target"]="rooms"
d=gate~assessOperation("GET_NAMED_MEMBER",a,bridge)
call assertEq "CLARIFY",d~status,"missing keyed evidence clarifies inside Intention Service dev9"
call assertTrue pos("KEYED MEMBER ACCESS",translate(d~question))>0,"clarification explains missing keyed evidence"

/* Advisory shape evidence is enough for this non-destructive language feasibility gate. */
ignored=bridge~hintObjectShape("x","DIRECTORY",85,"USER_HINT")
d=gate~assessOperation("GET_NAMED_MEMBER",a,bridge)
call assertEq "READY",d~status,"shape hint satisfies keyed-access evidence requirement"
ignored=bridge~addOperation("GET_NAMED_MEMBER",a)

/* A semantic Directory construction plus dev10 class contract proves Directory.items. */
c=.directory~new; c["target"]="d"; ignored=bridge~addOperation("CREATE_DIRECTORY",c)
m=.directory~new; m["source"]="d"; m["message"]="items"; m["target"]="count"
d=gate~assessOperation("SEND_MESSAGE",m,bridge)
call assertEq "READY",d~status,"language contract satisfies SEND_MESSAGE plan requirement"
methodFact=service~bestEvidence("d","METHOD","ITEMS")
call assertTrue methodFact\==.nil,"method evidence published"
call assertEq "CONTRACT",methodFact~authority,"class catalogue evidence authority"
ignored=bridge~addOperation("SEND_MESSAGE",m)

/* dev10 method-result contract propagates into the semantic object ledger. */
count=bridge~objectEvidence("count")
call assertTrue count\==.nil,"bound method result has evidence"
call assertEq "NUMBER",count["shape"],"Directory.items result shape propagated"
call assertEq 95,count["confidence"],"contract result confidence"
call assertEq "CLASS_METHOD_CONTRACT",count["source"],"contract result provenance"

/* Invented messages remain blocked even when the receiver class is known. */
bad=.directory~new; bad["source"]="d"; bad["message"]="frobnicate"; bad["target"]="nonsense"
d=gate~assessOperation("SEND_MESSAGE",bad,bridge)
call assertEq "CLARIFY",d~status,"unproven method is not rendered"

say "PASS Intention Service dev9 evidence gate + Coding Intention dev13 result propagation"
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

::requires "LlmCodingEvidenceGate.cls"
::requires "LlmSemanticCodingBridge.cls"
::requires "LlmRexxKnowledgeCatalogue.cls"
::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
