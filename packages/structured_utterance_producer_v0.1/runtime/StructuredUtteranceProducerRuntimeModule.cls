/* Runtime Registry entry point for Structured Utterance Producer v0.1. */
::class StructuredUtteranceProducerRuntimeModule public
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
  return .StructuredUtteranceProducerBuild~GENERATION
::method apiVersion
  return .StructuredUtteranceProducerBuild~API_VERSION
::method newProducer
  return .StructuredUtteranceProducer~new
::method newPlan
  forward class (.StructuredUtteranceGenerationPlan) message 'NEW'
::requires 'StructuredUtteranceProducer.cls'
