parse source . . here
root = filespec("L", here)
proposal = .directory~new
proposal["workflow_id"] = "disk-ed209e"
proposal["action"] = "sshnode_fixed"
proposal["args"] = .array~of("ed209e", "/bin/bash", "df")
proposal["interval_seconds"] = 900
proposal["predicate_metric"] = "working_space_free_percent"
proposal["predicate_operator"] = "<"
proposal["predicate_threshold"] = 50
proposal["notify_mode"] = "on_match"
made = .LlmPaWorkflowSpec~fromDirectory(proposal)
call must made, "workflow proposal"
call mustBool made~value~workflowId = "disk-ed209e", "workflow identity"
call mustBool made~value~intervalSeconds = 900, "workflow interval"
call mustBool made~value~actionArgs[3] = "df", "fixed action args"
bad = .directory~new
bad["workflow_id"] = "bad"
bad["action"] = "sshnode_fixed"
bad["args"] = .array~of("ed209e")
bad["interval_seconds"] = 15
bad["predicate_metric"] = "working_space_free_percent"
bad["predicate_operator"] = "<"
bad["predicate_threshold"] = 50
call mustFail .LlmPaWorkflowSpec~fromDirectory(bad), "short interval rejected"
low = .LlmPaWorkflowPredicate~evaluate(42, "<", 50)
call must low, "low predicate"
call mustBool low~value["matched"] = .true, "low space matches"
high = .LlmPaWorkflowPredicate~evaluate(71, "<", 50)
call must high, "high predicate"
call mustBool high~value["matched"] = .false, "healthy space silent"
auditPath = root || "/workflow.audit"
audit = .LlmPaWorkflowAudit~new(auditPath)
event = .directory~new
event["event_type"] = "EXECUTION"
event["workflow_id"] = "disk-ed209e"
event["execution_id"] = "run-1"
event["outcome"] = "SUCCESS"
event["predicate_matched"] = .false
event["notification"] = "SUPPRESSED"
call must audit~append(event), "audit append"
address command "rm -f" auditPath
say "PASS test_workflow"
exit 0

must: procedure
  use arg r, label
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 1; end
return
mustFail: procedure
  use arg r, label
  if r~ok then do; say "FAIL" label "unexpected OK"; exit 1; end
return
mustBool: procedure
  use arg ok, label
  if \ok then do; say "FAIL" label; exit 1; end
return
::requires "LlmPaWorkflow.cls"
