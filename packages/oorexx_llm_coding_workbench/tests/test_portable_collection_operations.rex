parse source . . here
root=filespec("L",here)||"/.."
call directory root
catalogue=value("LLM_CODING_CATALOGUE",,"ENVIRONMENT")
if catalogue=="" then catalogue=root||"/config/coding_intention_dev13_rexx_catalogue.json"
k=.LlmRexxKnowledgeCatalogue~new(catalogue)

call assert k~supportsOperation("GET_COLLECTION_SIZE"),"size semantic is advertised"
call assert k~supportsOperation("GET_KEYS"),"keys semantic is advertised"
call assert k~supportsOperation("APPEND_ITEM"),"append semantic is advertised"
call assert k~supportsOperation("CONTAINS_KEY"),"membership semantic is advertised"

b=.LlmSemanticCodingBridge~new("Portable","probe",k)
a=.directory~new; a["target"]="d"; ignored=b~addOperation("CREATE_DIRECTORY",a)
a=.directory~new; a["target"]="values"; ignored=b~addOperation("CREATE_ARRAY",a)

a=.directory~new; a["source"]="d"; a["target"]="count"; ignored=b~addOperation("GET_COLLECTION_SIZE",a)
a=.directory~new; a["source"]="d"; a["target"]="keys"; ignored=b~addOperation("GET_KEYS",a)
a=.directory~new; a["source"]="values"; a["value"]="$itemValue"; ignored=b~addOperation("APPEND_ITEM",a)
a=.directory~new; a["source"]="d"; a["member"]="x"; a["target"]="hasX"; ignored=b~addOperation("CONTAINS_KEY",a)

body=b~renderMethodBody
call assertContains body,"count = d~items","portable size resolves through Rexx authority"
call assertContains body,"keys = d~allIndexes","portable keys resolves through Rexx authority"
call assertContains body,"values~append(itemValue)","portable append resolves through Rexx authority"
call assertContains body,'hasX = d~hasIndex("x")',"portable membership resolves through Rexx authority"

countEvidence=b~objectEvidence("count")
keysEvidence=b~objectEvidence("keys")
hasEvidence=b~objectEvidence("hasX")
call assert countEvidence["shape"]=="NUMBER","size result shape evidence"
call assert keysEvidence["shape"]=="ARRAY","keys result shape evidence"
call assert hasEvidence["shape"]=="LOGICAL","membership result shape evidence"

/* Directory is collection-like but not an appendable sequence: fail closed. */
signal on syntax name badAppend
bad=.directory~new; bad["source"]="d"; bad["value"]="x"
ignored=b~addOperation("APPEND_ITEM",bad)
signal off syntax
say "FAIL: APPEND_ITEM accepted keyed collection without sequence evidence"
exit 1
badAppend:
signal off syntax

say "PASS portable collection operations avoid raw ooRexx message selection"
exit 0

assert: procedure
  use arg ok,label
  if \ok then do; say "FAIL:" label; exit 1; end
return

assertContains: procedure
  use arg haystack,needle,label
  if pos(needle,haystack)=0 then do; say "FAIL:" label; say haystack; exit 1; end
return

::requires "LlmSemanticCodingBridge.cls"
