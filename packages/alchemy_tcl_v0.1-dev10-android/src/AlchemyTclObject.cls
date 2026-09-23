/* Alchemy Tcl v0.1-dev1
 * ooRexx-side semantic projection skeleton.
 *
 * Native invocation is intentionally not faked in dev1.  The class establishes
 * the shared Foreign Object inheritance and state contract; dev2 will attach
 * the resident native Tcl provider.
 */
::class AlchemyTclObject public subclass AlchemyForeignObject

::method init
  expose tclInterpreterId tclEntityId tclGeneration tclKind
  use strict arg tclInterpreterId, tclEntityId, tclGeneration = 1, tclKind = "COMMAND"
  self~init:super
  self~installForeignUnknownComposition("BRIDGEUNKNOWN")
  return

::method foreignRuntime
  return "TCL"

::method bridgeUnknown
  use strict arg messageName, arguments
  /* dev1 deliberately refuses to simulate native Tcl resolution. */
  raise syntax 93.900 array ("Alchemy Tcl native dispatch is not attached in dev1", messageName)

::method tclProjectionState
  expose tclInterpreterId tclEntityId tclGeneration tclKind
  d = .directory~new
  d["interpreter_id"] = tclInterpreterId
  d["entity_id"] = tclEntityId
  d["generation"] = tclGeneration
  d["kind"] = tclKind
  d["runtime"] = self~foreignRuntime
  return d

::requires 'AlchemyForeignObject.cls'
