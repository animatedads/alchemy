now = .DateTime~new
threshold = .ReputationCorroborationPolicy~new(2,70,1,120,.true)
defaultEvidence = .ReputationCorroborationEvidencePolicy~new

verified = makeClaim('V','FAM-V',88,'ASSERTS','VERIFIED',.false)
failed = makeClaim('F','FAM-F',94,'ASSERTS','FAILED',.false)
unverified = makeClaim('U','FAM-U',84,'ASSERTS','UNVERIFIED',.false)
compromised = makeClaim('C','FAM-C',96,'ASSERTS','VERIFIED',.true)

h = .ReputationEventHypothesis~new('H-PROV','SYNTH_EVENT')
h~addClaim(verified); h~addClaim(failed); h~addClaim(unverified); h~addClaim(compromised); h~seal
a = h~corroboration(threshold,defaultEvidence)
call assertEqual 4,a~claimCount,'all evidence retained'
call assertEqual 2,a~eligibleAssertionClaimCount,'verified plus unverified eligible by default'
call assertEqual 2,a~discoveryOnlyClaimCount,'failed and compromised remain discovery only'
call assertEqual 2,a~assertionFamilyCount,'only eligible assertion families count toward threshold'
call assertEqual 'CORROBORATED',a~status,'verified plus unverified independent families corroborate'
call assertTrue a~thresholdSatisfied,'eligible families meet threshold'
call assertEqual 'AUTHENTICATION_FAILED',a~evidenceStatusForClaim('F')~reasonCode,'failed proof reason retained'
call assertEqual 'SOURCE_COMPROMISED',a~evidenceStatusForClaim('C')~reasonCode,'compromise reason retained'
call assertEqual 86,a~weightedConfidence,'confidence averages only eligible family representatives'
call assertTrue pos('AUTHENTICATION_FAILED',a~canonicalText) > 0,'canonical assessment retains provenance reason evidence'

mixed=.ReputationEventHypothesis~new('H-MIXED-FAMILY','SYNTH_EVENT')
mixed~addClaim(verified)
failedSame=.ReputationFeedClaim~new('FS','ART-FS','FAM-V','SYNTH_EVENT','Synthetic',now,now,'GB',99,'ASSERTS','ACTIVE','SRC-FS','FS')
failedSame~setEventKey('EVENT-PROV'); failedSame~addConcept('SYNTH'); failedSame~setSourceAuthentication('FAILED','AUTH-FS'); failedSame~seal
mixed~addClaim(failedSame); mixed~seal
mixedAssessment=mixed~corroboration(threshold,defaultEvidence)
call assertEqual 1,mixedAssessment~eligibleIndependentFamilyCount,'eligible family survives mixed provenance within same lineage'
call assertEqual 0,mixedAssessment~discoveryOnlyFamilyCount,'same lineage is not double-counted as discovery-only family when it has eligible evidence'

h2 = .ReputationEventHypothesis~new('H-FAILED','SYNTH_EVENT')
h2~addClaim(verified); h2~addClaim(failed); h2~seal
a2 = h2~corroboration(threshold,defaultEvidence)
call assertEqual 'CORROBORATING',a2~status,'failed second family does not create corroboration'
call assertEqual 1,a2~assertionFamilyCount,'failed family is not a vote'
call assertEqual 2,a2~claimCount,'failed family remains visible evidence'

failedDenial = makeClaim('D','FAM-D',95,'DENIES','FAILED',.false)
h3 = .ReputationEventHypothesis~new('H-DENIAL','SYNTH_EVENT')
h3~addClaim(verified); h3~addClaim(unverified); h3~addClaim(failedDenial); h3~seal
a3 = h3~corroboration(threshold,defaultEvidence)
call assertEqual 'CORROBORATED',a3~status,'failed denial does not manufacture contested state'
call assertFalse a3~contested,'failed denial not contest evidence by default'

permissive = .ReputationCorroborationEvidencePolicy~new(.true,.true,.true,.true)
a4 = h3~corroboration(threshold,permissive)
call assertEqual 'CONTESTED',a4~status,'explicit policy may admit failed denial as contest evidence'
call assertTrue a4~contested,'policy override is explicit'
call assertEqual 'FAILED_AUTH_ALLOWED_BY_POLICY',a4~evidenceStatusForClaim('D')~reasonCode,'override reason retained'

strict = .ReputationCorroborationEvidencePolicy~new(.false,.false,.false,.false)
h4 = .ReputationEventHypothesis~new('H-STRICT','SYNTH_EVENT')
h4~addClaim(unverified); h4~seal
a5 = h4~corroboration(threshold,strict)
call assertEqual 'DISCOVERY_ONLY',a5~status,'strict policy retains unverified claim without using it as corroboration'
call assertEqual 0,a5~eligibleClaimCount,'strict policy admits no eligible evidence'
call assertEqual 1,a5~discoveryOnlyClaimCount,'unverified evidence remains visible'

say 'PASS test_provenance_aware_corroboration eligible=' || a~eligibleClaimCount 'discovery=' || a~discoveryOnlyClaimCount
exit 0

makeClaim: procedure
  use arg id,family,confidence,stance,authState,compromised
  c=.ReputationFeedClaim~new(id,'ART-'id,family,'SYNTH_EVENT','Synthetic',.DateTime~new,.DateTime~new,'GB',confidence,stance,'ACTIVE','SRC-'id,id)
  c~setEventKey('EVENT-PROV')
  c~addConcept('SYNTH')
  c~setSourceAuthentication(authState,'AUTH-'id,compromised,'HISTORY-'id)
  c~seal
  return c

assertTrue: procedure
  use arg value,label
  if value \== .true then do; say 'FAIL:' label; exit 1; end
  return
assertFalse: procedure
  use arg value,label
  if value == .true then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return

::requires 'ReputationFeed.cls'
