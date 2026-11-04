/* Mail-specific source adapter for a generic Wire projection.
   Owns identity validation and source access, but no renderer/UI mechanics. */
::class WireImapMessageResolver public
::method init
  expose mailbox
  use strict arg mailbox
::method refForIdentity
  expose mailbox
  use strict arg identity
  p1 = identity~pos("|")
  p2 = identity~pos("|", p1 + 1)
  if p1 = 0 | p2 = 0 then raise syntax 88.900 array("WIRE_IDENTITY", identity)
  box = identity~left(p1 - 1)
  validity = identity~substr(p1 + 1, p2 - p1 - 1)
  uid = identity~substr(p2 + 1)
  if box <> mailbox~mailbox | validity <> mailbox~uidValidity then raise syntax 88.900 array("WIRE_STALE_IDENTITY", identity)
  return .WireImapMessageRef~new(box, validity, uid)
::method valueForIdentity
  expose mailbox
  use strict arg identity
  result = mailbox~fetchBody(self~refForIdentity(identity))
  if result == .nil then return ""
  if result~hasMethod("text") then return result~text
  return result~string
::requires "WireImapSource.cls"
