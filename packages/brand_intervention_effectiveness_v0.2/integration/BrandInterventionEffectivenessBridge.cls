/* Build an effectiveness aggregate from sealed BrandInterventionOutcomeObservation
   objects.  Only observations where the intervention was eligible/proposed are
   expected here.  This bridge does not infer eligibility from unrelated journeys. */
::class BrandInterventionEffectivenessBridge public
::method aggregateOutcomes
  use arg aggregateId, outcomes, interventionKind, outcomeKind, desiredDirection, outcomeRole, classification, fromAt, toAt, observationDays, outcomeWindowSeconds=0, assignmentMethod="OBSERVATIONAL", assignmentAuthorityId="UNSPECIFIED", classifierId="UNSPECIFIED", taxonomyVersion="UNSPECIFIED", processVersion="UNSPECIFIED", modelVersion="UNSPECIFIED"
  if outcomes==.nil then return .BrandInterventionEffectivenessResult~failure("OUTCOMES_REQUIRED")
  kind=.BrandInterventionEffectivenessCanonical~token(interventionKind); outkind=.BrandInterventionEffectivenessCanonical~token(outcomeKind)
  eligible=0; applied=0; appliedOutcome=0; notApplied=0; notAppliedOutcome=0
  support=.array~new; counter=.array~new
  do o over outcomes
    if o==.nil | \o~sealed then iterate
    if o~interventionKind<>kind | o~outcomeKind<>outkind then iterate
    if o~observedAt<fromAt~string | o~observedAt>toAt~string then iterate
    if outcomeWindowSeconds>0 & o~outcomeLagSeconds>outcomeWindowSeconds then iterate
    eligible+=1
    direction=.BrandInterventionEffectivenessCanonical~token(desiredDirection)
    if o~interventionApplied then do
      applied+=1
      if o~outcomeOccurred then do
        appliedOutcome+=1
        if direction=.BrandInterventionEffectivenessConstant~DIRECTION_INCREASE then support~append(o~pointId)
        else counter~append(o~pointId)
      end
      else do
        if direction=.BrandInterventionEffectivenessConstant~DIRECTION_DECREASE then support~append(o~pointId)
        else counter~append(o~pointId)
      end
    end
    else do
      notApplied+=1
      if o~outcomeOccurred then do
        notAppliedOutcome+=1
        if direction=.BrandInterventionEffectivenessConstant~DIRECTION_DECREASE then support~append(o~pointId)
        else counter~append(o~pointId)
      end
      else do
        if direction=.BrandInterventionEffectivenessConstant~DIRECTION_INCREASE then support~append(o~pointId)
        else counter~append(o~pointId)
      end
    end
  end
  a=.BrandInterventionEffectivenessAggregate~new(aggregateId,kind,outkind,desiredDirection,outcomeRole,classification,fromAt,toAt,observationDays,eligible,applied,appliedOutcome,notApplied,notAppliedOutcome,outcomeWindowSeconds,assignmentMethod,assignmentAuthorityId,classifierId,taxonomyVersion,processVersion,modelVersion)
  /* Keep only a small evidence sample, not every row. */
  i=0; do p over support; if i>=3 then leave; a~addSupportPoint(p); i+=1; end
  i=0; do p over counter; if i>=3 then leave; a~addCounterPoint(p); i+=1; end
  sr=a~seal; if \sr~ok then return sr
  return .BrandInterventionEffectivenessResult~success(a)
::requires "BrandInterventionEffectiveness.cls"
