codec=.LlmCodingJsonCodec~new
bad='[{"action":"VIEW_METHOD","args":{}},{"action":"WRITE_METHOD","args":{}}]'
call expectSyntax codec,"decodeDecision",bad,.nil,"multiple actions rejected"

desk=.RejectDesk~new
session=.LlmCodingDeskSession~new(desk,"demo/house.rex","pkg")
args=.directory~new; args["class_name"]="Door"; args["method_name"]="isOpen"; args["method_body"]="  ::method isOpen"
call expectSyntax session,"execute","WRITE_METHOD",args,"method directive rejected"
args["method_body"]='say "literal ::method is data"' || d2c(10) || 'return .true'
call expectSyntax desk,"arm",.nil,.nil,"fixture arm"
desk~permitWrite
ignored=session~execute("WRITE_METHOD",args)
call assertEq args["method_body"],desk~lastRequest["method_body"],"non-directive ::method text allowed"
say "PASS one-action and body-only boundaries"
exit 0

::routine expectSyntax
  use arg receiver,message,a1=.nil,a2=.nil,label=""
  signal on syntax name caught
  if a1==.nil then ignored=receiver~sendWith(message,.array~new)
  else if a2==.nil then ignored=receiver~sendWith(message,.array~of(a1))
  else ignored=receiver~sendWith(message,.array~of(a1,a2))
  signal off syntax
  say "FAIL" label "did not raise"
  raise syntax 88.900 array("test assertion failed")
caught:
  signal off syntax
  return
::routine assertEq
  use strict arg expected,actual,label
  if expected\==actual then do; say "FAIL" label; raise syntax 88.900 array("test assertion failed"); end

::class RejectDesk public
::attribute allowWrite
::attribute lastRequest get
::method init
  expose allowWrite lastRequest; allowWrite=.false; lastRequest=.nil
::method permitWrite
  expose allowWrite; allowWrite=.true
::method arm
  raise syntax 88.900 array("fixture")
::method buttons
  return .array~new
::method classFileModel
  return .directory~new
::method press
  expose allowWrite lastRequest
  use strict arg action,request
  if \allowWrite then raise syntax 88.900 array("desk must not be reached")
  lastRequest=request
  return .directory~new

::requires "../src/LlmCodingWorkbench.cls"
