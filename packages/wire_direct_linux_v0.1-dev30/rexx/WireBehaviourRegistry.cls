/* Runtime registry resolving Builder symbolic behaviour names to live Rexx
 * behaviour objects.  It is intentionally independent of renderers.
 */
::class WireBehaviourRegistry public
::method init
  expose behaviours
  behaviours = .directory~new
::method register
  expose behaviours
  use strict arg name, behaviour
  if name == "" | behaviour == .nil then raise syntax 88.900 array("WIRE_BEHAVIOUR_INVALID", name)
  behaviours[name] = behaviour
  return behaviour
::method resolve
  expose behaviours
  use strict arg name
  if \behaviours~hasIndex(name) then return .nil
  return behaviours[name]
