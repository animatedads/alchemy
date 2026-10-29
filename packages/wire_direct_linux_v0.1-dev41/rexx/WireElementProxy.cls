/* Capability-bearing ooRexx programming surface for a semantic Wire element.
 * Every operation delegates to the application model.  Native renderer objects
 * and handles are intentionally absent from this contract.
 */
::class WireElementProxy public
::method init
  expose model elementId
  use strict arg model, elementId
::attribute elementId get
::method type
  expose model elementId
  return model~element(elementId)~elementType
::method visible
  expose model elementId
  return model~elementProperty(elementId, "visible")
::method "visible="
  expose model elementId
  use strict arg value
  return model~setElementProperty(elementId, "visible", value)
::method enabled
  expose model elementId
  return model~elementProperty(elementId, "enabled")
::method "enabled="
  expose model elementId
  use strict arg value
  return model~setElementProperty(elementId, "enabled", value)
::method text
  expose model elementId
  return model~elementProperty(elementId, "text")
::method "text="
  expose model elementId
  use strict arg value
  return model~setElementProperty(elementId, "text", value)
::method value
  expose model elementId
  return model~elementProperty(elementId, "value")
::method "value="
  expose model elementId
  use strict arg value
  return model~setElementProperty(elementId, "value", value)
::method selection
  expose model elementId
  return model~elementProperty(elementId, "selection")
::method "selection="
  expose model elementId
  use strict arg value
  return model~setElementProperty(elementId, "selection", value)
::method activate
  expose model elementId
  return model~activateElement(elementId)
