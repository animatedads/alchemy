/* Semantic dispatch only. Committed definitions must be authorized against
 * the exact event-time identity before any application behaviour executes.
 */
::class WireApplicationController public
::method init
  expose model definitionGate
  use strict arg model, definitionGate = .nil
  if model == .nil then raise syntax 88.900 array("WIRE_APPLICATION_MODEL_REQUIRED")
::method dispatch
  expose model definitionGate
  use strict arg event
  if event~definitionId \== .nil then do
    if definitionGate == .nil then raise syntax 88.900 array("WIRE_DEFINITION_GATE_REQUIRED")
    if \definitionGate~authorize(event) then do
      definitionGate~requestResync(event)
      return .array~new
    end
  end
  matches = model~bindingsFor(event~source, event~trigger)
  results = .array~new
  do binding over matches
    results~append(binding~target~sendWith(binding~method, .array~of(event)))
  end
  return results
