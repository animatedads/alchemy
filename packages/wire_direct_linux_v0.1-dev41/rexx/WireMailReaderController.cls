/* Deprecated dev5 compatibility facade. New applications bind WireSelectionProjection directly. */
::class WireMailReaderController public
::method init
  expose projection
  use strict arg ui, mailbox
  resolver = .WireImapMessageResolver~new(mailbox)
  target = .WireElementTarget~new(ui, "message")
  projection = .WireSelectionProjection~new(resolver, target, "value")
::method selectionChanged
  expose projection
  use strict arg event
  return projection~selectionChanged(event)
::requires "WireSelectionProjection.cls"
::requires "WireImapMessageResolver.cls"
::requires "WireElementTarget.cls"
