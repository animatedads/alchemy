/* Converts persistent/symbolic Builder specs into executable WireBindings.
 * Resolution happens once at composition time, not during renderer dispatch.
 */
::class WireBindingCompiler public
::method init
  expose registry
  use strict arg registry
  if registry == .nil then raise syntax 88.900 array("WIRE_BEHAVIOUR_REGISTRY_REQUIRED")
::method compile
  expose registry
  use strict arg spec
  target = registry~resolve(spec~behaviour)
  if target == .nil then raise syntax 88.900 array("WIRE_BEHAVIOUR_NOT_FOUND", spec~behaviour)
  return .WireBinding~new(spec~id, spec~source, spec~trigger, target, spec~method, spec~enabled, spec~metadata)
::requires "WireBinding.cls"
