/* Convert a sealed privacy-minimised BrandJourney into current intervention
   context.  The secret relationshipRef is never read or copied. */
::class BrandInterventionJourneyBridge public
::method fromJourney
  use arg contextId, journey, assessment, sentiment="UNASSESSED", issueSeverity=0
  if journey==.nil | \journey~sealed then return .BrandInterventionResult~failure("JOURNEY_NOT_SEALED")
  if assessment==.nil | \assessment~sealed then return .BrandInterventionResult~failure("JOURNEY_ASSESSMENT_NOT_SEALED")
  tps=journey~touchpoints; if tps~items=0 then return .BrandInterventionResult~failure("JOURNEY_EMPTY")
  last=tps[tps~items]
  c=.BrandInterventionContext~new(contextId,journey~pointId,last~occurredAt~string,last~domain,last~stateAfter,last~unresolvedAfter,sentiment,issueSeverity,last~explicitSalesProposition)
  do x over assessment~findings; c~addFinding(x); end
  do x over last~brandFunctions; c~addBrandFunction(x); end
  do x over last~brandOpportunities; c~addBrandOpportunity(x); end
  c~addObligation("PRESERVE_TRUTHFULNESS")
  c~addObligation("PRESERVE_SAFETY_AND_LEGAL_BOUNDARIES")
  c~addObligation("PRESERVE_CUSTOMER_DATA_BOUNDARIES")
  c~addProhibition("INFER_SALES_AUTHORITY_FROM_BRAND_CONTEXT")
  c~addEvidencePoint(journey~pointId); c~addEvidencePoint(assessment~pointId); c~addEvidencePoint(last~pointId)
  return c~seal
::requires "BrandIntervention.cls"
