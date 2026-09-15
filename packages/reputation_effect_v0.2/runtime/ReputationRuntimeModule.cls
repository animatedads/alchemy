/* Runtime Registry entry point for Reputation Effect v0.2. */
::class ReputationRuntimeModule public
::attribute starts get
::attribute quiesces get
::attribute stops get

::method init
  expose starts quiesces stops
  starts = 0
  quiesces = 0
  stops = 0

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
  return "REPUTATION-EFFECT-V0.2"

::method apiVersion
  return .ReputationEffectBuild~API_VERSION

::method newEngine
  return .ReputationEngine~new

::method newPolicy
  return .ReputationPolicy~new

::method newConceptGraph
  return .ReputationConceptGraph~new

::requires "ReputationEffect.cls"
