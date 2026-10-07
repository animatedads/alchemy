/* Semantic objects remain structured; controller-owned identity is injected. */
desk=.FakeDesk~new
gateway=.FakeGateway~new
session=.LlmCodingDeskSession~new(desk,"demo/house.rex","pkg-house")
workbench=.LlmCodingWorkbench~new(session,gateway)
turn=workbench~prepareMethodTurn("Make Door.isOpen return openState","Door","isOpen")
parsed=.json~fromJson(.LlmCodingJsonCodec~new~encodeTurn(turn))
call assertEq "Door",parsed["target"]["class_name"],"target class retained"
call assertEq "isOpen",parsed["semantic_context"]["method"]["source_spelling"],"method retained"
call assertEq "METHOD",parsed["semantic_context"]["method"]["object_kind"],"method kind retained"
call assertTrue parsed["semantic_context"]["class"]["methods"]~items>0,"class methods remain collection"
call assertTrue parsed["controls"]["action_contracts"]~items>=10,"model receives button argument contracts"

args=.directory~new; args["class_name"]="Door"; args["method_name"]="isOpen"; args["method_body"]="return openState"
decision=.LlmCodingDecision~new("WRITE_METHOD",args)
outcome=workbench~apply(decision)
call assertEq "READY",outcome["intention_status"],"intention gate"
call assertEq 1,gateway~commitCount,"one intention commit"
call assertEq 1,desk~writeCount,"one desk write"
call assertEq "return openState",desk~lastRequest["method_body"],"body preserved"
call assertEq "pkg-house",desk~lastRequest["package_object_id"],"package identity from session"
call assertEq "demo/house.rex",desk~lastRequest["member_path"],"path from session"
say "PASS structured semantic coding turn and gated desk action"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected\==actual then do; say "FAIL" label "expected="expected "actual="actual; raise syntax 88.900 array("test assertion failed"); end
::routine assertTrue
  use strict arg value,label
  if \value then do; say "FAIL" label; raise syntax 88.900 array("test assertion failed"); end

::class FakeGateway public
::attribute commitCount get
::method init
  expose commitCount; commitCount=0
::method interpret
  use strict arg modelDecision
  return .FakeDecision~new("READY",modelDecision~action)
::method commit
  expose commitCount
  use strict arg decision
  commitCount+=1
  return decision~intent

::class FakeDecision public
::attribute status get
::attribute question get
::attribute intent get
::method init
  expose status question intent
  use strict arg statusArg,intentArg
  status=statusArg; question=""; intent=intentArg

::class FakeDesk public
::attribute writeCount get
::attribute lastRequest get
::method init
  expose writeCount lastRequest; writeCount=0; lastRequest=.nil
::method buttons
  a=.array~new
  do n over .array~of("VIEW_CLASS","VIEW_METHOD","WRITE_METHOD","MATERIALISE")
    d=.directory~new; d["action"]=n; d["label"]=n; d["purpose"]="fixture"; a~append(d)
  end
  return a
::method classFileModel
  d=.directory~new; d["authority"]="semantic objects"; return d
::method press
  expose writeCount lastRequest
  use strict arg action,request
  action=translate(action)
  if action=="VIEW_CLASS" then do
    d=.directory~new; c=.directory~new; c["source_spelling"]="Door"; c["object_kind"]="CLASS"; d["class"]=c
    attrs=.array~new; a=.directory~new; a["source_spelling"]="openState"; attrs~append(a); d["attributes"]=attrs
    methods=.array~new; m=.directory~new; m["source_spelling"]="isOpen"; m["object_kind"]="METHOD"; methods~append(m); d["methods"]=methods
    return d
  end
  if action=="VIEW_METHOD" then do
    m=.directory~new; m["source_spelling"]="isOpen"; m["object_kind"]="METHOD"; m["source_text"]="::method isOpen"||d2c(10)||"  return .false"; return m
  end
  if action=="WRITE_METHOD" then do
    writeCount+=1; lastRequest=request; r=.directory~new; r["status"]="REVISED"; r["revision_id"]="rev2"; return r
  end
  raise syntax 88.900 array("unexpected fake desk action "||action)

::requires "../src/LlmCodingWorkbench.cls"
