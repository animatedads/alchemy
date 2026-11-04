/* Renderer-neutral state of one Builder-designed Wire element.
 * This object is application state, never a GTK/DOM/Swing widget wrapper.
 */
::class WireElementState public
::method init
  expose elementId elementType properties
  use strict arg elementId, elementType = "Element"
  if elementId == "" then raise syntax 88.900 array("WIRE_ELEMENT_ID_REQUIRED")
  properties = .directory~new
  properties["visible"] = .true
  properties["enabled"] = .true
  properties["text"] = ""
  properties["value"] = .nil
  properties["selection"] = .nil
::attribute elementId get
::attribute elementType get
::method property
  expose properties
  use strict arg name
  if properties~hasIndex(name) then return properties[name]
  return .nil
::method setProperty
  expose properties
  use strict arg name, value
  properties[name] = value
  return value
