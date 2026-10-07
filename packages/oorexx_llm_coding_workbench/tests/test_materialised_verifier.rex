/* Proves the verifier materialises from Desk authority and returns structured
 * method + project evidence without flattening compiler/test diagnostics. */
desk=.VerifierDesk~new
session=.LlmCodingDeskSession~new(desk,"demo/door.rex","pkg-door")
checker=.VerifierChecker~new
verifier=.LlmCodingMaterialisedVerifier~new(session,checker)
choice=.LlmCodingDecision~new("WRITE_METHOD",.directory~new)
outcome=.directory~new; outcome["dispatch"]="WRITE_METHOD"
evidence=verifier~verify(.nil,choice,outcome,"Implement Door.isOpen","Door","isOpen")
call assertEq "VERIFICATION",evidence["kind"],"verification kind"
call assertEq "PASS",evidence["status"],"verification status"
call assertEq "REXXC_TEST",evidence["stage"],"verification stage"
call assertEq "demo/door.rex",evidence["member_path"],"member path retained"
call assertEq "METHOD",evidence["semantic_method"]["object_kind"],"semantic method retained"
call assertEq 1,checker~count,"checker called once"
call assertTrue checker~lastRequest["source_text"]~pos("::class Door")>0,"materialised source supplied"
call assertEq 0,evidence["details"]["compile_rc"],"structured compile rc"
say "PASS materialised source -> structured verification evidence"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected\==actual then do; say "FAIL" label "expected="expected "actual="actual; raise syntax 88.900 array("test assertion failed"); end
::routine assertTrue
  use strict arg value,label
  if \value then do; say "FAIL" label; raise syntax 88.900 array("test assertion failed"); end

::class VerifierChecker public
::attribute count get
::attribute lastRequest get
::method init
  expose count lastRequest; count=0; lastRequest=.nil
::method verifyMaterialised
  expose count lastRequest
  use strict arg request
  count+=1; lastRequest=request
  d=.directory~new; d["stage"]="REXXC_TEST"; d["status"]="PASS"
  details=.directory~new; details["compile_rc"]=0; details["test_rc"]=0; details["message"]="compiled and tests passed"
  d["details"]=details
  return d

::class VerifierDesk public
::method buttons; return .array~new
::method classFileModel; d=.directory~new; d["authority"]="semantic"; return d
::method press
  use strict arg action,request
  action=translate(action)
  if action=="MATERIALISE" then do
    files=.directory~new; files["demo/door.rex"]="::class Door"||d2c(10)||"::attribute openState"||d2c(10)||"::method isOpen"||d2c(10)||"  return openState"||d2c(10)
    d=.directory~new; d["files"]=files; return d
  end
  if action=="VIEW_METHOD" then do
    d=.directory~new; d["object_kind"]="METHOD"; d["source_spelling"]="isOpen"; d["source_text"]="::method isOpen"||d2c(10)||"  return openState"; return d
  end
  raise syntax 88.900 array("unexpected verifier desk action "||action)

::requires "../src/LlmCodingWorkbench.cls"
::requires "../src/LlmCodingMaterialisedVerifier.cls"
