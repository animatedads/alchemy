/* Design-time binding description.
 * Builder stores symbolic behaviour identity, never a live Rexx object or
 * renderer callback.  Runtime resolution is a separate authority.
 */
::class WireBuilderBindingSpec public
::method init
  expose id source trigger behaviour method enabled metadata
  use strict arg id, source, trigger, behaviour, method, enabled = .true, metadata = .nil
  if id == "" | source == "" | trigger == "" | behaviour == "" | method == "" then raise syntax 88.900 array("WIRE_BUILDER_BINDING_INVALID", id)
  if metadata == .nil then metadata = .collection~new
::attribute id get
::attribute source get
::attribute trigger get
::attribute behaviour get
::attribute method get
::attribute enabled get
::attribute enabled set
::attribute metadata get
