/* Creation/edit actions expose model args but controller supplies package/path/actor. */
desk=.RecordingDesk~new
session=.LlmCodingDeskSession~new(desk,"demo/new.rex","pkg-authority","proj","controller")
controls=session~controls
contracts=controls["action_contracts"]
call assertTrue contracts~items>=10,"action contracts exposed"
args=.directory~new
args["class_name"]="House"; args["ordinal"]="10"
args["package_object_id"]="MODEL-MUST-NOT-WIN"; args["member_path"]="evil.rex"; args["actor"]="model"
ignored=session~execute("CREATE_CLASS",args)
r=desk~lastRequest
call assertEq "pkg-authority",r["package_object_id"],"package identity controller-owned"
call assertEq "demo/new.rex",r["member_path"],"member path controller-owned"
call assertEq "controller",r["actor"],"actor controller-owned"
call assertEq "House",r["class_name"],"model semantic argument retained"
call assertEq "10",r["ordinal"],"model ordinal retained"
say "PASS coding button contracts and controller-owned authority fields"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected\==actual then do; say "FAIL" label; raise syntax 88.900 array("test assertion failed"); end
::routine assertTrue
  use strict arg value,label
  if \value then do; say "FAIL" label; raise syntax 88.900 array("test assertion failed"); end

::class RecordingDesk public
::attribute lastRequest get
::method buttons
  return .array~new
::method classFileModel
  return .directory~new
::method press
  expose lastRequest
  use strict arg action,request
  lastRequest=request
  return .directory~new

::requires "../src/LlmCodingWorkbench.cls"
