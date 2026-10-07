/* A failed verification result remains structured and drives the next coding turn. */
desk=.RepairDesk~new
session=.LlmCodingDeskSession~new(desk,"demo/door.rex","pkg-door")
gateway=.ReadyGateway~new
transport=.RepairTransport~new
workbench=.LlmCodingWorkbench~new(session,gateway,transport)
verifier=.RepairVerifier~new
loop=.LlmCodingHostLoop~new(workbench,6,verifier)
outcome=loop~runMethodChallenge("Implement Door.isOpen so it returns openState","Door","isOpen")
call assertEq "REPORT",outcome["model_action"],"challenge reports only after repair"
call assertEq "implemented and verified",outcome["report"],"report text"
call assertEq 2,desk~writeCount,"one failing write and one repaired write"
call assertEq 3,transport~turnCount,"three LLM turns"
say "PASS structured verification failure -> repair -> report loop"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected\==actual then do; say "FAIL" label "expected="expected "actual="actual; raise syntax 88.900 array("test assertion failed"); end
::routine assertTrue
  use strict arg value,label
  if \value then do; say "FAIL" label; raise syntax 88.900 array("test assertion failed"); end

::class RepairTransport public
::attribute turnCount get
::method init
  expose turnCount; turnCount=0
::method invoke
  expose turnCount
  use strict arg turn
  turnCount+=1
  if turnCount==1 then return self~decision("WRITE_METHOD","if then")
  observations=turn["observations"]
  last=observations~at(observations~items)
  if turnCount==2 then do
    call assertEq "VERIFICATION",last["kind"],"failure remains structured"
    call assertEq "FAIL",last["status"],"failure status visible"
    call assertEq 93,last["details"]["rc"],"compiler rc visible"
    call assertTrue last["details"]["message"]~pos("syntax")>0,"compiler message visible"
    return self~decision("WRITE_METHOD","return openState")
  end
  call assertEq "VERIFICATION",last["kind"],"pass remains structured"
  call assertEq "PASS",last["status"],"pass status visible"
  d=.directory~new; d["action"]="REPORT"; d["args"]=self~blankArgs; d["report"]="implemented and verified"
  return .json~toJson(d)
::method decision private
  use strict arg action,body
  d=.directory~new; d["action"]=action
  args=self~blankArgs; args["class_name"]="Door"; args["method_name"]="isOpen"; args["method_body"]=body
  d["args"]=args; d["report"]=.nil
  return .json~toJson(d)
::method blankArgs private
  d=.directory~new
  do n over .array~of("class_name","method_name","attribute_name","requires_target","ordinal","method_body")
    d[n]=.nil
  end
  return d

::class RepairVerifier public
::method verify
  use strict arg workbench,choice,outcome,challenge,className,methodName
  if choice~action\=="WRITE_METHOD" then return .nil
  evidence=.directory~new
  evidence["schema"]="oorexx.llm-coding.verification/0.1"
  evidence["kind"]="VERIFICATION"
  evidence["stage"]="REXXC"
  details=.directory~new
  if choice~args["method_body"]=="if then" then do
    evidence["status"]="FAIL"; details["rc"]=93; details["line"]=2; details["message"]="syntax error in generated method body"
  end
  else do
    evidence["status"]="PASS"; details["rc"]=0; details["message"]="compiled and method regression passed"
  end
  evidence["details"]=details
  return evidence

::class ReadyGateway public
::method interpret
  use strict arg modelDecision
  return .ReadyDecision~new(modelDecision~action)
::method commit
  use strict arg decision
  return decision~intent
::class ReadyDecision public
::attribute status get
::attribute question get
::attribute intent get
::method init
  expose status question intent
  use strict arg intentArg
  status="READY"; question=""; intent=intentArg

::class RepairDesk public
::attribute writeCount get
::method init
  expose writeCount body; writeCount=0; body="return .false"
::method buttons
  return .array~new
::method classFileModel
  d=.directory~new; d["authority"]="semantic objects"; return d
::method press
  expose writeCount body
  use strict arg action,request
  action=translate(action)
  if action=="VIEW_CLASS" then do
    d=.directory~new; c=.directory~new; c["object_kind"]="CLASS"; c["source_spelling"]="Door"; d["class"]=c
    d["attributes"]=.array~new; methods=.array~new; m=.directory~new; m["source_spelling"]="isOpen"; methods~append(m); d["methods"]=methods; return d
  end
  if action=="VIEW_METHOD" then do
    m=.directory~new; m["object_kind"]="METHOD"; m["source_spelling"]="isOpen"; m["source_text"]="::method isOpen"||d2c(10)||"  "||body; return m
  end
  if action=="WRITE_METHOD" then do
    writeCount+=1; body=request["method_body"]; r=.directory~new; r["revision_id"]="rev"||writeCount; return r
  end
  raise syntax 88.900 array("unexpected action "||action)

::requires "../src/LlmCodingWorkbench.cls"
::requires "../src/LlmCodingHostLoop.cls"
