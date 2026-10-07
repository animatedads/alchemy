parse arg outPath
if strip(outPath)=="" then do; say "usage: generate_catalogue_demo.rex OUT"; exit 2; end
bridge=.LlmSemanticCodingBridge~new("CatalogueDemo","build")
a=.directory~new; a["target"]="doc"; bridge~addOperation("CREATE_DIRECTORY",a)
a=.directory~new; a["target"]="doc"; a["member"]="status"; a["value"]="ready"; bridge~addOperation("SET_NAMED_MEMBER",a)
a=.directory~new; a["source"]="doc"; a["target"]="encoded"; bridge~addOperation("ENCODE_JSON_TEXT",a)
a=.directory~new; a["value"]="$encoded"; bridge~addOperation("RETURN_VALUE",a)
s=.stream~new(outPath)~~open("write replace")
s~lineOut("d=.CatalogueDemo~new")
s~lineOut("encoded=d~build")
s~lineOut("parsed=.json~fromJSON(encoded)")
s~lineOut('if parsed["status"]\=="ready" then do; say "FAIL generated catalogue runtime"; exit 1; end')
s~lineOut('say "PASS generated catalogue semantic runtime behaviour"')
s~lineOut("exit 0")
s~lineOut("")
s~lineOut("::class CatalogueDemo public")
s~lineOut("::method build")
body=bridge~renderMethodBody
remaining=body||"0a"x
do while remaining<>""
  parse var remaining line "0a"x remaining
  if remaining=="" & line=="" then leave
  s~lineOut("  "||line)
end
s~lineOut('::requires "json.cls"')
s~close
say "GENERATED" outPath
exit 0
::requires "../src/LlmSemanticCodingBridge.cls"
