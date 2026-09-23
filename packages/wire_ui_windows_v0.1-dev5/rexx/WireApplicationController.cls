/* Dispatches semantic ApplicationEvents through the executable model.
 * The renderer translates native activity into source/trigger/context before
 * this boundary.  Controller dispatch depends only on semantic model and event contracts.
 */
::class WireApplicationController public
::method init
  expose model
  use strict arg model
  if model == .nil then raise syntax 88.900 array("WIRE_APPLICATION_MODEL_REQUIRED")

::method dispatch
  expose model
  use strict arg event
  matches = model~bindingsFor(event~source, event~trigger)
  results = .array~new
  do binding over matches
    results~append(binding~target~sendWith(binding~method, event))
  end
  return results
