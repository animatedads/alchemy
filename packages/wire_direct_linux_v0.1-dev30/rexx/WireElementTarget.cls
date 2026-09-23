/* Tiny semantic target facade. UI lookup is isolated from projection/source code. */
::class WireElementTarget public
::method init
  expose ui elementId
  use strict arg ui, elementId
::method setProperty
  expose ui elementId
  use strict arg name, value
  element = ui~byId(elementId)
  element~sendWith(name || "=", .array~of(value))
