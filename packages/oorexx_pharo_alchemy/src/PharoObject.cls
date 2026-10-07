/* Live ooRexx projection of one resident Pharo object identity. */
::class PharoObject public subclass AlchemyForeignObject

/* Bind this proxy to BRIDGE/HANDLE and compose, rather than replace, any UNKNOWN
 * behaviour inherited from the underlying Alchemy object model.
 */
::method init
  expose bridge handle
  use strict arg bridge, handle
  self~init:super
  if bridge == .nil then raise syntax 93.900 array ('Pharo bridge is required')
  if handle == .nil then raise syntax 93.900 array ('Pharo resident handle is required')
  self~installForeignUnknownComposition('BRIDGEUNKNOWN')

/* Identify the foreign runtime family for Alchemy provenance and inspection. */
::method foreignRuntime
  return 'pharo'

::attribute bridge get
::attribute handle get

/* Resolve an otherwise unknown ooRexx message against the live Pharo receiver.
 * Discovery is passive.  If Pharo understands the selector, send it and allow
 * any Pharo exception to propagate.  Only true absence falls back to the exact
 * previously composed ooRexx UNKNOWN method.
 */
::method bridgeUnknown
  expose bridge handle
  use strict arg messageName, arguments
  selector = self~rexxMessageToSelector(messageName, arguments)
  if bridge~understands(handle, selector) then
    return bridge~send(handle, selector, arguments)
  return self~foreignUnknownFallback(messageName, arguments)

/* Explicitly send a Pharo selector, bypassing ooRexx UNKNOWN selection while
 * preserving live object arguments.  NIL means no arguments, not a NIL argument.
 */
::method sendPharo
  expose bridge handle
  use strict arg selector, arguments = .nil
  if arguments == .nil then arguments = .array~new
  return bridge~send(handle, selector, arguments)

/* Perform a live, side-effect-free selector capability query on this receiver. */
::method understandsPharo
  expose bridge handle
  use strict arg selector
  return bridge~understands(handle, selector)

/* Convert an ooRexx UNKNOWN message name into the selector spelling offered to
 * the resident adapter.  Keyword reconstruction is intentionally not guessed
 * here: the Pharo adapter has authoritative method metadata and argument arity.
 */
::method rexxMessageToSelector
  use strict arg messageName, arguments
  return messageName~string

::requires 'AlchemyForeignObject.cls'
::requires 'PharoBridge.cls'
