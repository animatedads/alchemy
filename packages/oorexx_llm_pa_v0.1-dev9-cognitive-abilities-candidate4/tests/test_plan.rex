parse source . . here
root = filespec("L", here)
path = root || "/plans.journal"
address command "rm -f" path
manager = .LlmPaPlanManager~new(.LlmPaPlanStore~new(path))
created = manager~create("ED209a Queue recovery", "Find why Queue is failing and restore safe processing")
call must created, "create plan"
planId = created~value["plan_id"]
added = manager~addItem(planId, "Inspect queue daemon state")
call must added, "add plan item"
itemId = added~value["items"][1]["item_id"]
told = manager~tick(planId, itemId, "DONE", "told_done", "Codex said the daemon state was inspected")
call must told, "mark told done"
call mustBool told~value["items"][1]["evidence"] = "told_done", "told done evidence"
verified = manager~tick(planId, itemId, "DONE", "tool_verified", "queue status confirmed by authorised tool")
call must verified, "mark verified"
call mustBool verified~value["items"][1]["evidence"] = "tool_verified", "tool evidence"
similar = manager~similar("deal with ED209e Queue failing")
call must similar, "similar plans"
call mustBool similar~value~items = 1, "similar plan found"
reloaded = .LlmPaPlanManager~new(.LlmPaPlanStore~new(path))
shown = reloaded~show(planId)
call must shown, "reload plan"
call mustBool shown~value["items"][1]["status"] = "DONE", "replayed item status"
address command "rm -f" path
say "PASS test_plan"
exit 0

must: procedure
  use arg answer, label
  if \answer~ok then do; say "FAIL" label answer~code answer~detail; exit 1; end
return
mustBool: procedure
  use arg ok, label
  if \ok then do; say "FAIL" label; exit 1; end
return

::requires "LlmPaPlan.cls"
