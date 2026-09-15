/* Optional bridge from Brand Interaction Effect v0.3 into Brand Journey v0.1. */
::class BrandJourneyInteractionBridge public
::method touchpointFromEpisode class
  use arg episode, touchpointIdArg, domainArg, surfaceArg="", occurredAtArg=.nil, stateBeforeArg="UNKNOWN", stateAfterArg="UNKNOWN", unresolvedBeforeArg=.false, unresolvedAfterArg=.false
  if episode==.nil | \episode~sealed then return .BrandJourneyResult~failure("EPISODE_NOT_SEALED")
  explicitSale=.false
  do obs over episode~observations
    if obs~hasPurpose("SALESPROP") then explicitSale=.true
  end
  tp=.BrandJourneyTouchpoint~new(touchpointIdArg,domainArg,episode~pointId,surfaceArg,occurredAtArg,stateBeforeArg,stateAfterArg,unresolvedBeforeArg,unresolvedAfterArg,explicitSale)
  /* Episode opportunity is brand significance, not authority to sell. */
  do opp over episode~opportunities; tp~addBrandOpportunity(opp); end
  do obs over episode~observations
    do purpose over obs~purposes; tp~addPurpose(purpose); end
    do tag over obs~tags
      if tag~left(15)="BRAND_FUNCTION/" then tp~addBrandFunction(tag~substr(16))
      else if tag~left(18)="BRAND_OPPORTUNITY/" then tp~addBrandOpportunity(tag~substr(19))
      else tp~addTag(tag)
    end
    tp~addEvidencePoint(obs~pointId)
  end
  tp~seal
  return .BrandJourneyResult~success(tp)
::requires "BrandJourney.cls"
::requires "BrandInteractionEffect.cls"
