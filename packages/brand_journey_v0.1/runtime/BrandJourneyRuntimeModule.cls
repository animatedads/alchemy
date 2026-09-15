::class BrandJourneyRuntimeModule public
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
  return "BRAND-JOURNEY-V0.1"
::method apiVersion
  return .BrandJourneyBuild~API_VERSION
::method newJourney
  use arg journeyId, relationshipRef="", relationshipClass="CUSTOMER_RELATIONSHIP"
  return .BrandJourney~new(journeyId,relationshipRef,relationshipClass)
::method newEngine
  return .BrandJourneyEngine~new
::method newLibrary
  return .BrandJourneyLibrary~new
::requires "BrandJourney.cls"
