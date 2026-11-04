/* Renderer-neutral row target.  Adapter supplied by the application/runtime
   maps this semantic operation onto the renderer ABI. */
::class WireListRowTarget public
::method init
  expose adapter listId
  use strict arg adapter, listId
::method setRowProperty
  expose adapter listId
  use strict arg stableId, name, value
  return adapter~setListRowProperty(listId, stableId, name, value)
