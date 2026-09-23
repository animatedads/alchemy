/* Minimal semantic element used by renderer-neutral application-model qualification. */
::class WireSemanticElement public
::method init
  expose elementId elementType properties
  use strict arg elementId, elementType
  properties = .directory~new
  properties["visible"] = .true
  properties["enabled"] = .true
  properties["text"] = ""
  properties["value"] = ""
  properties["selection"] = .nil
::attribute elementId get
::attribute elementType get
::method property
  expose properties
  use strict arg name
  if \properties~hasIndex(name) then return .nil
  return properties[name]
::method setProperty
  expose properties
  use strict arg name, value
  properties[name] = value
  return value
