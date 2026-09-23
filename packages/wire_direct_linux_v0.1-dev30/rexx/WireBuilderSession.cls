/* Small public editing surface used by a visual Builder or scripts.
 * It edits symbolic application intent; it does not create widgets, callbacks,
 * behaviour objects, protocol sources, or scheduler policy.
 */
::class WireBuilderSession public
::method init
  expose specs selectedSource selectedTrigger
  specs = .array~new
  selectedSource = ""
  selectedTrigger = ""
::method selectElement
  expose selectedSource
  use strict arg source
  if source == "" then raise syntax 88.900 array("WIRE_BUILDER_SOURCE_REQUIRED")
  selectedSource = source
  return self
::method selectEvent
  expose selectedSource selectedTrigger
  use strict arg trigger
  if selectedSource == "" then raise syntax 88.900 array("WIRE_BUILDER_SELECT_ELEMENT_FIRST")
  if trigger == "" then raise syntax 88.900 array("WIRE_BUILDER_TRIGGER_REQUIRED")
  selectedTrigger = trigger
  return self
::method bindBehaviour
  expose specs selectedSource selectedTrigger
  use strict arg id, behaviour, method
  if selectedSource == "" | selectedTrigger == "" then raise syntax 88.900 array("WIRE_BUILDER_SELECT_EVENT_FIRST")
  spec = .WireBuilderBindingSpec~new(id, selectedSource, selectedTrigger, behaviour, method)
  specs~append(spec)
  return spec
::method bindingSpecs
  expose specs
  copy = .array~new
  do spec over specs
    copy~append(spec)
  end
  return copy
::requires "WireBuilderBindingSpec.cls"
