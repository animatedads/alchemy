/* LdapCancel.cls - RFC 3909 Cancel and association operation state.
 *
 * Cancel is a conversation-layer facility.  It does not grant authority and
 * it never changes Identity Directory semantics.  The registry is scoped to
 * one LDAP association so a message id can never cancel another association's
 * operation.
 */

::class LdapCancelBuild public
::constant API_VERSION "ldap.cancel/0.1"
::constant CANCEL_OID "1.3.6.1.1.8"
::constant RESULT_CANCELED 118
::constant RESULT_NO_SUCH_OPERATION 119
::constant RESULT_TOO_LATE 120
::constant RESULT_CANNOT_CANCEL 121

::class LdapCancelCodec public
::method encodeRequestValue class
  use strict arg cancelId
  if cancelId <= 0 then raise syntax 88.900 array("LDAP Cancel message id must be positive")
  return .LdapBer~sequence(.LdapBer~integer(cancelId))
::method decodeRequestValue class
  use strict arg bytes
  out = .directory~new
  top = .LdapBer~readElement(bytes, 1)
  if \top["ok"] | top["tag"] <> 48 then do; out["ok"] = .false; out["code"] = "LDAP_CANCEL_VALUE_INVALID"; return out; end
  if top["next"] <> bytes~length + 1 then do; out["ok"] = .false; out["code"] = "LDAP_CANCEL_VALUE_TRAILING_BYTES"; return out; end
  idEl = .LdapBer~readElement(top["value"], 1)
  if \idEl["ok"] | idEl["tag"] <> 2 then do; out["ok"] = .false; out["code"] = "LDAP_CANCEL_ID_INVALID"; return out; end
  if idEl["next"] <> top["value"]~length + 1 then do; out["ok"] = .false; out["code"] = "LDAP_CANCEL_VALUE_TRAILING_FIELDS"; return out; end
  cancelId = .LdapBer~decodeUnsignedInteger(idEl["value"])
  if cancelId <= 0 then do; out["ok"] = .false; out["code"] = "LDAP_CANCEL_ID_INVALID"; return out; end
  out["ok"] = .true; out["cancelId"] = cancelId
  return out

::class LdapOutstandingOperation public
::attribute messageId get
::attribute operationType get
::attribute cancellable get
::attribute cancelReason get
::attribute context
::method init
  expose messageId operationType cancellable state cancelReason context
  use strict arg messageIdArg, operationTypeArg, cancellableArg = .true
  messageId = messageIdArg
  operationType = operationTypeArg~string
  cancellable = cancellableArg
  state = "ACTIVE"
  cancelReason = ""
  context = .nil
::method requestCancel
  expose state cancellable cancelReason
  use strict arg reasonArg = "CLIENT_CANCEL"
  if state = "COMPLETE" then return .LdapCancelBuild~RESULT_TOO_LATE
  if \cancellable then return .LdapCancelBuild~RESULT_CANNOT_CANCEL
  if state = "CANCEL_REQUESTED" then return .LdapCancelBuild~RESULT_CANNOT_CANCEL
  state = "CANCEL_REQUESTED"
  cancelReason = reasonArg~string
  return 0
::method cancelRequested
  expose state
  return state = "CANCEL_REQUESTED"
::method complete
  expose state
  state = "COMPLETE"
  return .true
::method state
  expose state
  return state

::class LdapOperationRegistry public
::method init
  expose active completed
  active = .directory~new
  completed = .directory~new
::method register
  expose active completed
  use strict arg operation
  key = operation~messageId~string
  /* LDAP message IDs need only be unique while an operation is outstanding.
   * Once a prior operation completed, the client may legally reuse that ID;
   * the new operation then replaces the old tooLate tombstone. */
  if active~hasIndex(key) then return .false
  if completed~hasIndex(key) then completed~remove(key)
  active[key] = operation
  return .true
::method lookup
  expose active
  use strict arg messageId
  key = messageId~string
  if active~hasIndex(key) then return active[key]
  return .nil
::method requestCancel
  expose active completed
  use strict arg messageId
  key = messageId~string
  if active~hasIndex(key) then return active[key]~requestCancel("CLIENT_CANCEL")
  if completed~hasIndex(key) then return .LdapCancelBuild~RESULT_TOO_LATE
  return .LdapCancelBuild~RESULT_NO_SUCH_OPERATION
::method complete
  expose active completed
  use strict arg messageId
  key = messageId~string
  if active~hasIndex(key) then do
    active[key]~complete
    active~remove(key)
  end
  completed[key] = .true
  return .true
::method cancelAll
  expose active
  use strict arg reasonArg = "ASSOCIATION_CLOSED"
  do key over active
    operation = active[key]
    if \operation~cancelRequested then ignore = operation~requestCancel(reasonArg)
  end
  return .true
::method activeCount
  expose active
  return active~items
::method activeOperations
  expose active
  out = .array~new
  do key over active
    out~append(active[key])
  end
  return out

/* Serialize complete LDAPMessage writes through the association-owned sender.
 * The current DSA uses one event-loop dispatcher rather than concurrent RxSock
 * reader/writer workers, but retaining this boundary keeps writes atomic if
 * additional outstanding operation classes are added later. */
::class LdapAssociationSender public
::method init
  expose transport closed
  use strict arg transportArg
  transport = transportArg
  closed = .false
::method replaceTransport
  expose transport closed
  use strict arg transportArg
  if closed then return .false
  transport = transportArg
  return .true
::method send
  expose transport closed
  use strict arg bytes
  if closed then return .false
  return .LdapSocketIO~sendAll(transport, bytes)
::method markClosed
  expose closed
  closed = .true
  return .true

::requires "src/LdapBer.cls"
::requires "src/LdapSocketIO.cls"
