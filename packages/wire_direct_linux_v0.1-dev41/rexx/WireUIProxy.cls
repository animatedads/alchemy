/* Scoped view of Builder-designed application elements for behaviour code.
 * Possession is authority: when allowedIds is supplied, other application
 * elements are deliberately not resolvable through this proxy.
 */
::class WireUIProxy public
::method init
  expose model allowedIds
  use strict arg model, allowedIds = .nil
::method byId
  expose model allowedIds
  use strict arg id
  if allowedIds \== .nil then if \allowedIds~hasIndex(id) then return .nil
  if model~element(id) == .nil then return .nil
  return .WireElementProxy~new(model, id)
::method element
  use strict arg id
  return self~byId(id)
::requires "WireElementProxy.cls"
