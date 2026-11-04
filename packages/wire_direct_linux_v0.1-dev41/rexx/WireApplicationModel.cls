/* Executable renderer-neutral application model.
 * Builder and handwritten applications use the same public model.  Element
 * state is authoritative here; renderers receive projections of changes.
 */
::class WireApplicationModel public
::method init
  expose elements bindings projection actionTarget
  elements = .directory~new
  bindings = .array~new
  projection = .nil
  actionTarget = .nil
::method addElement
  expose elements
  use strict arg id, element
  if id == "" | element == .nil then raise syntax 88.900 array("WIRE_ELEMENT_INVALID", id)
  if elements~hasIndex(id) then raise syntax 88.900 array("WIRE_ELEMENT_DUPLICATE", id)
  elements[id] = element
  return element
::method element
  expose elements
  use strict arg id
  if \elements~hasIndex(id) then return .nil
  return elements[id]
::method elementProperty
  use strict arg id, name
  e = self~element(id)
  if e == .nil then raise syntax 88.900 array("WIRE_ELEMENT_UNKNOWN", id)
  return e~property(name)
::method setElementProperty
  expose projection
  use strict arg id, name, value
  e = self~element(id)
  if e == .nil then raise syntax 88.900 array("WIRE_ELEMENT_UNKNOWN", id)
  e~setProperty(name, value)
  if projection \== .nil then projection~setElementProperty(id, name, value)
  return value
::method "projection="
  expose projection
  use strict arg target
  projection = target
::method "actionTarget="
  expose actionTarget
  use strict arg target
  actionTarget = target
::method activateElement
  expose actionTarget
  use strict arg id
  if self~element(id) == .nil then raise syntax 88.900 array("WIRE_ELEMENT_UNKNOWN", id)
  if actionTarget == .nil then return .false
  return actionTarget~activateElement(id)
::method ui
  return .WireUIProxy~new(self)
::method scopedUI
  use strict arg allowedIds
  return .WireUIProxy~new(self, allowedIds)
::method addBinding
  expose bindings
  use strict arg binding
  if binding == .nil then raise syntax 88.900 array("WIRE_BINDING_REQUIRED")
  bindings~append(binding)
  return binding
::method bindingsFor
  expose bindings
  use strict arg source, trigger
  matches = .array~new
  do binding over bindings
    if binding~enabled & binding~source == source & binding~trigger == trigger then matches~append(binding)
  end
  return matches
::requires "WireUIProxy.cls"
