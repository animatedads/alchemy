/* Workbench dev15: a WRITE_METHOD must be rejected if the semantic method
 * changed after the turn inspected it.  The model never supplies the base. */
desk=.RevisionDesk~new
session=.LlmCodingDeskSession~new(desk,"demo/door.rex","pkg-door")
seen=session~viewMethod("Door","isOpen")
call assertEq "rev-1",seen["revision_id"],"initial revision inspected"
desk~revision="rev-2"

args=.directory~new
args["class_name"]="Door"
args["method_name"]="isOpen"
args["method_body"]="return .true"

signal on syntax name stale
ignored=session~execute("WRITE_METHOD",args)
signal off syntax
raise syntax 88.900 array("FAIL stale semantic base was not rejected")

stale:
signal off syntax
detail=condition("D")
call assertTrue pos("STALE_SEMANTIC_BASE",detail)>0,"stale-base condition"
call assertEq 0,desk~writeCount,"stale write never reached Development Desk"
say "PASS Workbench rejects WRITE_METHOD when inspected semantic revision is stale"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("FAIL "||label||" expected="||expected||" actual="||actual)
  return

::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("FAIL "||label)
  return

::class RevisionDesk public
::attribute revision
::attribute writeCount get

::method init
  expose revision writeCount
  revision="rev-1"
  writeCount=0

::method buttons
  return .array~of("VIEW_METHOD","WRITE_METHOD")

::method classFileModel
  return "semantic"

::method press
  expose revision writeCount
  use strict arg action,request
  if action=="VIEW_METHOD" then do
    d=.directory~new
    d["object_kind"]="METHOD"
    d["class_name"]=request["class_name"]
    d["method_name"]=request["method_name"]
    d["revision_id"]=revision
    d["source_text"]="::method isOpen"||"0a"x||" return .false"
    return d
  end
  if action=="WRITE_METHOD" then do
    writeCount+=1
    return .directory~new
  end
  raise syntax 88.900 array("unexpected action "||action)

::requires "../src/LlmCodingWorkbench.cls"
