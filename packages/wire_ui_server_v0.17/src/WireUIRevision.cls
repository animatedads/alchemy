/* Monotonic live-view revision. */
::class WireUIRevision subclass AlchemyObject public
::attribute value get
::method init
  expose value
  use arg initial = 0
  self~init:super(.WireUIAlchemy~metadata("Monotonic Wire UI live-view revision"))
  if \datatype(initial, "W") | initial < 0 then raise syntax 93.906 array("revision", initial)
  value = initial
  self~registerStateVariable("value", "CUSTOMER", "current live-view revision")
::method next
  expose value
  old = value
  value += 1
  return .array~of(old, value)
::method matches
  expose value
  use arg candidate
  return candidate = value
::requires "WireUIAlchemy.cls"
