::class BrandInterventionRuntimeModule public
::attribute starts get
::attribute quiesces get
::attribute stops get
::method init
  expose starts quiesces stops
  starts=0; quiesces=0; stops=0
::method runtimeStart
  expose starts; starts+=1; return .true
::method runtimeQuiesce
  expose quiesces; quiesces+=1; return .true
::method runtimeStop
  expose stops; stops+=1; return .true
::method generationLabel
  return "BRAND-INTERVENTION-V0.2"
::method apiVersion
  return .BrandInterventionBuild~API_VERSION
::method newEngine
  return .BrandInterventionEngine~new
::method newLibrary
  return .BrandInterventionLibrary~new
::method newJourneyBridge
  return .BrandInterventionJourneyBridge~new
::method newPopulationBridge
  return .BrandInterventionPopulationBridge~new
::requires "BrandIntervention.cls"
::requires "BrandInterventionJourneyBridge.cls"
::requires "BrandInterventionPopulationBridge.cls"
