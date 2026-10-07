parse arg output
if output=="" then do; say "usage: generate_runtime_contract_demo.rex OUTPUT"; exit 2; end
catalogue=value("LLM_CODING_CATALOGUE",,"ENVIRONMENT")
if catalogue=="" then do; say "LLM_CODING_CATALOGUE is required"; exit 3; end
k=.LlmRexxKnowledgeCatalogue~new(catalogue)
b=.LlmSemanticCodingBridge~new("RuntimeContractDemo","count",k)
a=.directory~new; a["target"]="d"; ignored=b~addOperation("CREATE_DIRECTORY",a)
a=.directory~new; a["target"]="d"; a["member"]="x"; a["value"]="ready"; ignored=b~addOperation("SET_NAMED_MEMBER",a)
a=.directory~new; a["source"]="d"; a["message"]="items"; a["target"]="count"; ignored=b~addOperation("SEND_MESSAGE",a)
a=.directory~new; a["value"]="$count"; ignored=b~addOperation("RETURN_VALUE",a)
body=b~renderMethodBody
source="probe=.RuntimeContractDemo~new"||.endOfLine||,
       "if probe~count<>1 then do; say 'FAIL runtime contract generated count'; exit 1; end"||.endOfLine||,
       "say 'PASS runtime contract generated source behaviour'"||.endOfLine||,
       "exit 0"||.endOfLine||.endOfLine||,
       "::class RuntimeContractDemo public"||.endOfLine||,
       "::method count"||.endOfLine
remaining=body||.endOfLine
do while remaining<>""
  parse var remaining line "0a"x remaining
  if line<>"" then source=source||"  "||line||.endOfLine
end
s=.stream~new(output); s~open("WRITE REPLACE"); s~charout(source); s~close
say "GENERATED" output
exit 0
::requires "LlmSemanticCodingBridge.cls"
