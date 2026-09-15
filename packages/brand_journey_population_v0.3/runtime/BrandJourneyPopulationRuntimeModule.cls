::class BrandJourneyPopulationRuntimeModule public
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
  return "BRAND-JOURNEY-POPULATION-V0.3"
::method apiVersion
  return .BrandJourneyPopulationBuild~API_VERSION
::method newPopulation
  use arg populationId
  return .BrandJourneyPopulation~new(populationId)
::method newAnalyzer
  return .BrandJourneyPopulationAnalyzer~new
::method newLibrary
  return .BrandJourneyPopulationLibrary~new
::requires "BrandJourneyPopulation.cls"
