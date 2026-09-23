/* Foreign-language code remains a bounded ooRexx behaviour.
 * Wire dispatches only to this Rexx object.  The supplied Alchemy-facing
 * bridge owns Rexx -> language variable projection, execution, and the
 * language -> Rexx return crossing.  Wire never enters a foreign application
 * dispatch graph and never learns engine, renderer, or language object rules.
 */
::class WireLanguageBlock public
::method init
  expose language source bridge
  use strict arg language, source, bridge
  if language == "" then raise syntax 88.900 array("WIRE_LANGUAGE_REQUIRED")
  if source == "" then raise syntax 88.900 array("WIRE_LANGUAGE_SOURCE_REQUIRED")
  if bridge == .nil then raise syntax 88.900 array("WIRE_LANGUAGE_BRIDGE_REQUIRED")

::attribute language get
::attribute source get

/* This is deliberately an ordinary Rexx behaviour method. */
::method dispatch
  expose language source bridge
  use strict arg event
  variables = .collection~new
  variables["event"] = event
  return bridge~executeBlock(language, source, variables)
