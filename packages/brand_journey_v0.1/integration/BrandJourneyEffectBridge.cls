/* Optional conversion of journey findings into Brand Interaction Effect findings. */
::class BrandJourneyEffectBridge public
::method findingsFromAssessment class
  use arg assessment
  out=.array~new
  if assessment==.nil | \assessment~sealed then return out
  do code over assessment~findings
    polarity="INFO"; severity=45; confidence=85
    select
      when code=.BrandJourneyConstant~FIND_CONTEXT_LOSS then do; polarity="CONCERN"; severity=72; end
      when code=.BrandJourneyConstant~FIND_REPEAT_BURDEN then do; polarity="CONCERN"; severity=68; end
      when code=.BrandJourneyConstant~FIND_UNRESOLVED_CARRY then do; polarity="CONCERN"; severity=60; end
      when code=.BrandJourneyConstant~FIND_COMMERCIAL_WHILE_UNRESOLVED then do; polarity="CONCERN"; severity=82; end
      when code=.BrandJourneyConstant~FIND_RECOVERY_ACROSS_DOMAIN then do; polarity="SUPPORT"; severity=65; end
      when code=.BrandJourneyConstant~FIND_CROSS_DOMAIN_CONTINUITY then do; polarity="SUPPORT"; severity=55; end
      when code=.BrandJourneyConstant~FIND_RELATIONSHIP_PRESERVED then do; polarity="SUPPORT"; severity=55; end
      when code=.BrandJourneyConstant~FIND_SERVICE_AS_SALES then do; polarity="OPPORTUNITY"; severity=45; end
      otherwise nop
    end
    f=.BrandEffectFinding~new("JOURNEY-"||assessment~assessmentId||"-"||out~items+1,code,polarity,severity,confidence,"JOURNEY_EVIDENCE")
    f~addEvidencePoint(assessment~pointId)
    do ep over assessment~evidencePoints; f~addEvidencePoint(ep); end
    f~seal
    out~append(f)
  end
  return out
::requires "BrandJourney.cls"
::requires "BrandInteractionEffect.cls"
