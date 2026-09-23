/* Semantic event crossing the renderer/application boundary.  UI is a scoped
 * Wire application-element proxy, never a renderer-native object graph.
 */
::class WireApplicationEvent public
::method init
  expose source trigger context timestamp rendererContext ui
  use strict arg source, trigger, context = .nil, timestamp = 0, rendererContext = .nil, ui = .nil
  if source == "" | trigger == "" then raise syntax 88.900 array("WIRE_EVENT_INVALID", source, trigger)
  if context == .nil then context = .collection~new
::attribute source get
::attribute trigger get
::attribute context get
::attribute timestamp get
::attribute rendererContext get
::attribute ui get
