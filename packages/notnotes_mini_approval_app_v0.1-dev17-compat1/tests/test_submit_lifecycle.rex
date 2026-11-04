/* Draft -> submit -> approve lifecycle, durable across restart. */
root = value("MININOTES_DB_ROOT",, "ENVIRONMENT")
if root = "" then raise syntax 93.900 array("MININOTES_DB_ROOT required")

app = .MiniNotesApp~new(root)
fields = .Array~new
spec = .Directory~new
spec["NAME"] = "TPSNumber"
spec["LABEL"] = "TPS Number"
spec["TYPE"] = "IDENTIFIER"
fields~append(spec)
ignore = app~installUserFormat("TPS Report", fields)
values = .Directory~new
values["TPSNumber"] = "TPS-SUBMIT-001"
doc = app~createUserDocument("TPS Report", fields, values)
call assertEqual "DRAFT", doc~ApprovalStatus, "new user document starts draft"
app~select(doc~DocKey)
status = app~submitSelected("ready for approval")
call assertEqual "PENDING APPROVAL", status, "submit moves draft to pending"
call assertEqual "PENDING APPROVAL", doc~ApprovalStatus, "submitted document status"
status = app~submitSelected("duplicate submit")
call assertEqual "NOT_DRAFT", status, "duplicate submit rejected"
ignore = app~persistNow
key = doc~DocKey

app2 = .MiniNotesApp~new(root)
reloaded = app2~byKey(key)
call assertTrue reloaded \== .nil, "submitted document reloads"
call assertEqual "PENDING APPROVAL", reloaded~ApprovalStatus, "pending state survives restart"
app2~select(key)
status = app2~decideSelected("APPROVE", "approved after restart")
call assertEqual "APPROVED", status, "submitted document can be approved"
ignore = app2~persistNow

app3 = .MiniNotesApp~new(root)
final = app3~byKey(key)
call assertEqual "APPROVED", final~ApprovalStatus, "approval survives restart"
say "PASS submit lifecycle / restart"
exit 0

::routine assertEqual
  use strict arg expected, actual, label
  if expected \= actual then raise syntax 93.900 array(label || ": expected=" || expected || " actual=" || actual)
  return

::routine assertTrue
  use strict arg condition, label
  if \condition then raise syntax 93.900 array(label)
  return

::requires 'src/MiniNotesApp.cls'
