/* Renderer-neutral application binding.
 * A binding names a semantic source + trigger and an already-existing Rexx
 * behaviour target. It contains no renderer callback, toolkit object, source
 * protocol, scheduling, or application-specific policy.
 */
::class WireBinding public
::method init
  expose id source trigger target method enabled metadata
  use strict arg id, source, trigger, target, method, enabled = .true, metadata = .nil
  if id == "" | source == "" | trigger == "" | method == "" then raise syntax 88.900 array("WIRE_BINDING_INVALID", id)
  if target == .nil then raise syntax 88.900 array("WIRE_BINDING_TARGET_REQUIRED", id)
  if metadata == .nil then metadata = .collection~new
::attribute id get
::attribute source get
::attribute trigger get
::attribute target get
::attribute method get
::attribute enabled get
::attribute enabled set
::attribute metadata get
