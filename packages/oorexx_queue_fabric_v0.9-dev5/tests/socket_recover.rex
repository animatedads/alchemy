parse arg storeRoot
manager = .ObjectQueueManager~new(storeRoot, .QueueGraphPayloadCodec~new, "admin")
depthResult = manager~depth("INBOX", "admin")
if \depthResult~ok then exit 51
if depthResult~value["ready"] \= 1 then exit 52
package = manager~browse("INBOX", "admin")~value
if package == .nil then exit 53
if package~payload["kind"] \= "render" then exit 54
if package~payload["steps"][2] \= "encode" then exit 55
if package~correlationId \= "socket-42" then exit 56
if manager~transferReceiptCount \= 1 then exit 57
say "depth=1;receipts=1;kind=" || package~payload["kind"] || ";step2=" || package~payload["steps"][2] || ";correlation=" || package~correlationId
exit 0

::requires "ObjectQueueFabric.cls"
