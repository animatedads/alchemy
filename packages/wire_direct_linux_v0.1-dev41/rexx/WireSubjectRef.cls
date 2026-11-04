/* Renderer/source-neutral semantic subject reference.
   Wire transports identity; observation/interaction authorities define evidence semantics. */
::class WireSubjectRef public
::method init
  expose value
  use strict arg value
  if value == .nil | value = "" then raise syntax 88.900 array("WIRE_SUBJECT_REF", value)
::attribute value get
::method string
  expose value
  return value
