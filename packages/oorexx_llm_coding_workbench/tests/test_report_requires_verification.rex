/* REPORT cannot complete the coding session before structured PASS evidence. */
desk=.ReportDesk~new
session=.LlmCodingDeskSession~new(desk,"demo/x.rex","pkg-x")
gateway=.ReadyGateway~new
workbench=.LlmCodingWorkbench~new(session,gateway)
report=.LlmCodingDecision~new("REPORT",.directory~new,"done")
out=workbench~apply(report)
call assertEq "VERIFY_REQUIRED",out["workbench_status"],"report blocked before PASS"
call assertEq "NOT_SUBMITTED",out["intention_status"],"blocked report not submitted to Intention Service"
pass=.directory~new; pass["kind"]="VERIFICATION"; pass["stage"]="REXXC_TEST"; pass["status"]="PASS"; pass["details"]=.directory~new
workbench~observe(pass)
out=workbench~apply(report)
call assertEq "COMPLETE",out["workbench_status"],"report completes after PASS"
call assertEq "READY",out["intention_status"],"verified report still goes through Intention Service"
call assertEq "done",out["report"],"report retained"
say "PASS REPORT requires structured verification PASS"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected\==actual then do; say "FAIL" label "expected="expected "actual="actual; raise syntax 88.900 array("test assertion failed"); end

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
::class ReportDesk public
::method buttons; return .array~new
::method classFileModel; return .directory~new
::method press; raise syntax 88.900 array("Desk must not be pressed for REPORT")

::requires "../src/LlmCodingWorkbench.cls"
