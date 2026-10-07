/* End-to-end local coding turn against the real Semantic Source Store/Desk and
 * real Development Desk Intention adapter.  No model/network is needed: the
 * fixture supplies the one structured model decision. */
parse arg dbRoot, outFile
if strip(dbRoot)=="" then dbRoot="workbench-real-desk-db"
if strip(outFile)=="" then outFile="workbench-real-desk.rex"

store=.SemanticSourceStore~new(dbRoot)
store~bootstrap
authority=.SemanticSourceMcpDirect~new(store~sql)
desk=.SemanticSourceDevelopmentDesk~new(authority)

r=.directory~new; r["member_path"]="demo/door.rex"; r["actor"]="workbench-test"
pkg=desk~press("CREATE_PACKAGE",r)
root=pkg["package_object_id"]
path=pkg["member_path"]

r=.directory~new; r["package_object_id"]=root; r["member_path"]=path; r["class_name"]="Door"; r["ordinal"]=10; r["actor"]="workbench-test"
ignored=desk~press("CREATE_CLASS",r)
r=.directory~new; r["package_object_id"]=root; r["member_path"]=path; r["class_name"]="Door"; r["attribute_name"]="openState"; r["ordinal"]=20; r["actor"]="workbench-test"
ignored=desk~press("ADD_ATTRIBUTE",r)
r=.directory~new; r["package_object_id"]=root; r["member_path"]=path; r["class_name"]="Door"; r["method_name"]="isOpen"; r["ordinal"]=30; r["actor"]="workbench-test"
ignored=desk~press("ADD_METHOD",r)

service=.IntentionService~new
ignored=.SemanticSourceDevelopmentDeskIntention~configure(service,desk,path)
session=.LlmCodingDeskSession~new(desk,path,root,"workbench-test","workbench-test")
gateway=.LlmCodingIntentionGateway~new(service)
workbench=.LlmCodingWorkbench~new(session,gateway)

turn=workbench~prepareMethodTurn("Implement Door.isOpen so it returns openState","Door","isOpen")
wire=.LlmCodingJsonCodec~new~encodeTurn(turn)
turnObject=.json~fromJson(wire)
call assertEq "METHOD",turnObject["semantic_context"]["method"]["object_kind"],"real semantic method retained"
call assertTrue turnObject["semantic_context"]["method"]["source_text"]~pos("::method isOpen")>0,"real current method source included"

args=.directory~new; args["class_name"]="Door"; args["method_name"]="isOpen"; args["method_body"]="return openState"
model=.LlmCodingDecision~new("WRITE_METHOD",args)
outcome=workbench~apply(model)
call assertEq "READY",outcome["intention_status"],"real intention READY"

nextTurn=workbench~prepareMethodTurn("Verify Door.isOpen","Door","isOpen")
nextObject=.json~fromJson(.LlmCodingJsonCodec~new~encodeTurn(nextTurn))
source=nextObject["semantic_context"]["method"]["source_text"]
call assertTrue source~pos("return openState")>0,"real revised method returned to next LLM turn"

empty=.directory~new
build=session~execute("MATERIALISE",empty)
text=build~files[path]
s=.stream~new(outFile); s~open("WRITE REPLACE"); s~charout(text); s~close
call assertTrue text~pos("::class Door")>0,"materialised class"
call assertTrue text~pos("  return openState")>0,"materialised revised body"
say "PASS real Semantic Source Store -> Intention -> Development Desk workbench round trip"
say "OUT="||outFile
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected \== actual then do; say "FAIL" label "expected=" expected "actual=" actual; raise syntax 88.900 array("test assertion failed"); end
::routine assertTrue
  use strict arg value,label
  if \value then do; say "FAIL" label; raise syntax 88.900 array("test assertion failed"); end

::requires "../src/LlmCodingWorkbench.cls"
::requires "../src/LlmCodingIntentionGateway.cls"
::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
::requires "SemanticSourceStore.cls"
::requires "SemanticSourceMcpDirect.cls"
::requires "SemanticSourceDevelopmentDesk.cls"
::requires "SemanticSourceDevelopmentDeskIntention.cls"
