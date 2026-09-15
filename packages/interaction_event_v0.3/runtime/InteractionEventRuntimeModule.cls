/* Runtime Registry entry point for Interaction Event v0.3. */
::class InteractionEventRuntimeModule public
::attribute starts get
::attribute quiesces get
::attribute stops get
::method init
  expose starts quiesces stops
  starts = 0; quiesces = 0; stops = 0
::method runtimeStart
  expose starts
  starts += 1
  return .true
::method runtimeQuiesce
  expose quiesces
  quiesces += 1
  return .true
::method runtimeStop
  expose stops
  stops += 1
  return .true
::method generationLabel
  return "INTERACTION-EVENT-V0.3"
::method apiVersion
  return .InteractionEventBuild~API_VERSION
::method newCaptureLibrary
  return .InteractionCaptureLibrary~new
::method newDeidentifiedPolicy
  return .InteractionProjectionPolicy~deidentified
::requires 'InteractionEvent.cls'
