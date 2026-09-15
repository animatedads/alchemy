/* Runtime Registry entry point for Structured Utterance v0.3. */
::class StructuredUtteranceRuntimeModule public
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
  return "STRUCTURED-UTTERANCE-V0.3"
::method apiVersion
  return .StructuredUtteranceBuild~API_VERSION
::method newLibrary
  return .StructuredUtteranceLibrary~new
::method newAnalyzer
  return .StructuredUtteranceAnalyzer
::method newDeidentifiedPolicy
  return .UtteranceProjectionPolicy~deidentified
::method newFullPolicy
  return .UtteranceProjectionPolicy~full
::method serviceAsSalesContext
  return .BrandExperienceContext~serviceAsSales
::requires 'StructuredUtterance.cls'
