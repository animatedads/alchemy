/* Full offline coding session using real Semantic Source Store/Development Desk,
 * real Intention Service gateway, semantic coding steps, materialisation and
 * structured verification.  The model is scripted so no network is required. */
parse arg dbRoot,outFile
if strip(dbRoot)=="" then dbRoot="workbench-session-db"
if strip(outFile)=="" then outFile="workbench-session-house.rex"

store=.SemanticSourceStore~new(dbRoot); store~bootstrap
authority=.SemanticSourceMcpDirect~new(store~sql)
desk=.SemanticSourceDevelopmentDesk~new(authority)

r=.directory~new; r["member_path"]="demo/house.rex"; r["actor"]="workbench-session"
pkg=desk~press("CREATE_PACKAGE",r); root=pkg["package_object_id"]; path=pkg["member_path"]
r=.directory~new; r["package_object_id"]=root; r["member_path"]=path; r["class_name"]="House"; r["ordinal"]=10; r["actor"]="workbench-session"; ignored=desk~press("CREATE_CLASS",r)
r=.directory~new; r["package_object_id"]=root; r["member_path"]=path; r["class_name"]="House"; r["attribute_name"]="door"; r["ordinal"]=20; r["actor"]="workbench-session"; ignored=desk~press("ADD_ATTRIBUTE",r)
r=.directory~new; r["package_object_id"]=root; r["member_path"]=path; r["class_name"]="House"; r["method_name"]="openDoor"; r["ordinal"]=30; r["actor"]="workbench-session"; ignored=desk~press("ADD_METHOD",r)

service=.IntentionService~new
ignored=.SemanticSourceDevelopmentDeskIntention~configure(service,desk,path)
session=.LlmCodingDeskSession~new(desk,path,root,"workbench-session","workbench-session")
gateway=.LlmCodingIntentionGateway~new(service)
transport=.SemanticSessionTransport~new
workbench=.LlmCodingWorkbench~new(session,gateway,transport)
checker=.SessionChecker~new(outFile)
verifier=.LlmCodingMaterialisedVerifier~new(session,checker)
loop=.LlmCodingHostLoop~new(workbench,8,verifier)
outcome=loop~runMethodChallenge("Make House.openDoor return false when already open, otherwise set door to open and return true","House","openDoor")
call assertEq "REPORT",outcome["model_action"],"session reports"
call assertEq "semantic method implemented and verified",outcome["report"],"verified report"
call assertEq 1,checker~count,"one materialised verification after apply"
call assertTrue checker~lastRequest["source_text"]~pos('if door == "open" then return .false')>0,"guard materialised"
call assertTrue checker~lastRequest["source_text"]~pos('door = "open"')>0,"mutation materialised"
call assertTrue checker~lastRequest["source_text"]~pos('return .true')>0,"success return materialised"
say "PASS real semantic method session -> materialise -> verification -> report"
say "OUT="||outFile
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected\==actual then do; say "FAIL" label "expected="expected "actual="actual; raise syntax 88.900 array("test assertion failed"); end
::routine assertTrue
  use strict arg value,label
  if \value then do; say "FAIL" label; raise syntax 88.900 array("test assertion failed"); end

::class SemanticSessionTransport public
::attribute turn get
::method init
  expose turn; turn=0
::method invoke
  expose turn
  use strict arg payload
  turn+=1
  if turn==1 then return self~guardDecision
  if turn==2 then return self~setDecision
  if turn==3 then return self~applyDecision
  if turn==4 then do
    obs=payload["observations"]
    found=.false
    do o over obs
      if o~isA(.directory) then if o~hasIndex("kind") then if o["kind"]=="VERIFICATION" then if o["status"]=="PASS" then found=.true
    end
    call assertTrue found,"verification PASS visible before REPORT"
    d=.directory~new; d["action"]="REPORT"; d["args"]=.directory~new; d["report"]="semantic method implemented and verified"; return .json~toJson(d)
  end
  raise syntax 88.900 array("unexpected model turn "||turn)
::method baseArgs private
  d=.directory~new; d["class_name"]="House"; d["method_name"]="openDoor"; return d
::method guardDecision private
  d=.directory~new; d["action"]="CODING_RETURN_IF_ALREADY"; a=self~baseArgs
  a["attribute_name"]="door"; a["condition"]="open"; a["return_value"]="false"
  d["args"]=a; d["report"]=.nil; return .json~toJson(d)
::method setDecision private
  d=.directory~new; d["action"]="CODING_SET_ATTRIBUTE"; a=self~baseArgs
  a["attribute_name"]="door"; a["value"]="open"
  d["args"]=a; d["report"]=.nil; return .json~toJson(d)
::method applyDecision private
  d=.directory~new; d["action"]="CODING_APPLY_METHOD"; d["args"]=self~baseArgs; d["report"]=.nil; return .json~toJson(d)

::class SessionChecker public
::attribute count get
::attribute lastRequest get
::method init
  expose count lastRequest outFile; use strict arg outFileArg; count=0; lastRequest=.nil; outFile=outFileArg
::method verifyMaterialised
  expose count lastRequest outFile
  use strict arg request
  count+=1; lastRequest=request
  s=.stream~new(outFile); s~open("WRITE REPLACE"); s~charout(request["source_text"]); s~close
  d=.directory~new; d["stage"]="MATERIALISED_SOURCE"; d["status"]="PASS"
  details=.directory~new; details["output_file"]=outFile; details["message"]="source materialised for external r13196 compile/runtime qualification"; d["details"]=details
  return d

::requires "../src/LlmCodingWorkbench.cls"
::requires "../src/LlmCodingHostLoop.cls"
::requires "../src/LlmCodingIntentionGateway.cls"
::requires "../src/LlmCodingMaterialisedVerifier.cls"
::requires "IntentionService.cls"
::requires "IntentionProviders.cls"
::requires "SemanticSourceStore.cls"
::requires "SemanticSourceMcpDirect.cls"
::requires "SemanticSourceDevelopmentDesk.cls"
::requires "SemanticSourceDevelopmentDeskIntention.cls"
