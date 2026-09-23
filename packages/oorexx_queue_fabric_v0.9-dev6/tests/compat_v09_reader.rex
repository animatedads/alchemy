parse arg root
if root = "" then exit 2
manager = .ObjectQueueManager~new(root, .nil, "admin")
depth = manager~depth("COMPAT", "admin")
call must depth, "recover compat queue"
call assert depth~value["ready"] = 1, "one ready package recovered"
browse = manager~browse("COMPAT", "admin")
call must browse, "browse recovered package"
package = browse~value
call assert package~priority = 7, "priority recovered"
call assert package~payload~isA(.Directory), "payload remains Directory"
call assert package~payload["kind"] = "V082", "top-level value recovered"
call assert package~payload["nested"]~isA(.Array), "nested Array recovered"
call assert package~payload["nested"][2]~isA(.Directory), "nested Directory recovered"
call assert package~payload["nested"][2]["value"] = 82, "nested value recovered"
say "OBJECT QUEUE FABRIC V0.8.2 -> V0.9-dev6 REPLAY: OK"
exit 0

must: procedure
  use arg outcome, label
  if outcome == .nil | \outcome~ok then do
    if outcome == .nil then say "ASSERT FAILED:" label "nil outcome"
    else say "ASSERT FAILED:" label outcome~code outcome~detail
    exit 1
  end
  return

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERT FAILED:" label
    exit 1
  end
  return

::requires "ObjectQueueFabric.cls"
