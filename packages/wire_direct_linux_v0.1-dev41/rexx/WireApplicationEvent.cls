/* Semantic event captured at the renderer/application boundary.
 * Revision and workspace context are captured with the native event, not
 * looked up from mutable renderer state when the queue is later drained.
 * workspaceContext remains opaque to Wire Direct.
 */
::class WireApplicationEvent public
::method init
  expose source trigger context timestamp rendererContext ui renderedRevision workspaceContext definitionId definitionVersion
  use strict arg source, trigger, context = .nil, timestamp = 0, rendererContext = .nil, ui = .nil, renderedRevision = .nil, workspaceContext = .nil, definitionId = .nil, definitionVersion = .nil
  if source == "" | trigger == "" then raise syntax 88.900 array("WIRE_EVENT_INVALID", source, trigger)
  if context == .nil then context = .collection~new
  if (definitionId == .nil) \== (definitionVersion == .nil) then raise syntax 88.900 array("WIRE_DEFINITION_ID_VERSION_PAIR_REQUIRED")
::attribute source get
::attribute trigger get
::attribute context get
::attribute timestamp get
::attribute rendererContext get
::attribute ui get
::attribute renderedRevision get
::attribute workspaceContext get
::attribute definitionId get
::attribute definitionVersion get
