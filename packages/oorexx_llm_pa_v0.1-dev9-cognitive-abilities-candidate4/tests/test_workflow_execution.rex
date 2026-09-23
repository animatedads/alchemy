spec = .LlmPaWorkflowSpec~new("disk-check", "sshnode_fixed", .array~of("ed209e", "/bin/bash", "df"), 900, "working_space_free_percent", "<", 50, "on_match")
executor = .FakeWorkflowExecutor~new
notifier = .FakeWorkflowNotifier~new
service = .LlmPaWorkflowService~new(.FakeWorkflowReminder~new, executor, notifier)
armed = service~activate(spec)
call must armed, "activate workflow"
call mustBool armed~value["status"] = "ARMED", "workflow armed"
ran = service~run("disk-check")
call must ran, "run workflow"
call mustBool executor~calls = 1, "fixed executor called"
call mustBool notifier~calls = 1, "matching notification emitted"
call mustBool ran~value["status"] = "CHECKED", "fired alarm is over"
parsed = .LlmPaDfParser~workingSpaceFreePercent("Filesystem Used Available Capacity Mounted on 0 0 0 62% /work")
call must parsed, "df parser"
call mustBool parsed~value = 38, "free percentage parsed"
say "PASS test_workflow_execution"
exit 0

must: procedure
  use arg answer, label
  if \answer~ok then do; say "FAIL" label answer~code answer~detail; exit 1; end
return
mustBool: procedure
  use arg ok, label
  if \ok then do; say "FAIL" label; exit 1; end
return

::class FakeWorkflowReminder public
::method scheduleDecision
  d = .directory~new
  d["reminder_id"] = "rem-workflow"
  return .LlmPaResult~success(d)

::class FakeWorkflowExecutor public
::attribute calls get
::method init
  expose calls
  calls = 0
::method runFixed
  expose calls
  calls += 1
  return .LlmPaResult~success("Filesystem Used Available Capacity Mounted on 0 0 0 62% /work")

::class FakeWorkflowNotifier public
::attribute calls get
::method init
  expose calls
  calls = 0
::method notify
  expose calls
  calls += 1
  return .LlmPaResult~success(.true)

::requires "LlmPaWorkflow.cls"
