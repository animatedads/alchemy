/* v0.9 writer used to prove exact accepted v0.8.2 reverse replay. */
parse arg root
if root = "" then exit 2
manager = .ObjectQueueManager~new(root, .nil, "admin")
call must manager~createQueue("COMPAT", "PERMANENT", "OPS", 10, "admin"), "create permanent compat queue"
payload = .directory~new
payload["kind"] = "V09"
payload["nested"] = .array~of("nine", .directory~new)
payload["nested"][2]["value"] = 90
options = .table~new
options["persistent"] = .true
options["priority"] = 8
call must manager~put("COMPAT", payload, options, "admin"), "persist v0.9 payload"
say "V09 WRITER: OK"
exit 0

must: procedure
  use arg outcome, label
  if outcome == .nil | \outcome~ok then do
    if outcome == .nil then say "ASSERT FAILED:" label "nil outcome"
    else say "ASSERT FAILED:" label outcome~code outcome~detail
    exit 1
  end
  return

::requires "ObjectQueueFabric.cls"
