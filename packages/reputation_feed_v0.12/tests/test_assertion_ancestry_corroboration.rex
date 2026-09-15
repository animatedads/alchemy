now=.DateTime~new
policy=.ReputationCorroborationPolicy~new(2,70,1,120,.true)

r=makeClaim('REUTERS','PUB-REUTERS',90,'ASSERTS','BOEING-PR-123','BOEING','DERIVED_FROM','LIB-R')
b=makeClaim('BBC','PUB-BBC',88,'ASSERTS','BOEING-PR-123','BOEING','QUOTED_ASSERTION','LIB-B')
l=makeClaim('LOCAL','PUB-LOCAL',86,'ASSERTS','BOEING-PR-123','BOEING','AI_REWRITE_OF','LIB-L')

h=.ReputationEventHypothesis~new('H-ANCESTRY','AIRCRAFT_SAFETY_INCIDENT')
h~addClaim(r); h~addClaim(b); h~addClaim(l); h~seal
a=h~corroboration(policy)
call assertEqual 3,a~claimCount,'all publisher reports retained'
call assertEqual 3,a~publicationFamilyCount,'three distinct publication families retained'
call assertEqual 1,a~explicitAssertionOriginFamilyCount,'three publications resolve to one underlying assertion root'
call assertEqual 1,a~assertionFamilyCount,'corroboration counts assertion ancestry, not mastheads'
call assertEqual 3,a~ancestryResolvedClaimCount,'all claims have explicit assertion ancestry'
call assertEqual 0,a~ancestryFallbackClaimCount,'no publication-lineage fallback required'
call assertEqual 90,a~weightedConfidence,'best representative chosen once for shared assertion root'
call assertEqual 'CORROBORATING',a~status,'one underlying assertion is not corroborated by rewrites'
call assertFalse a~thresholdSatisfied,'one assertion origin cannot meet two-family threshold'
status=a~evidenceStatusForClaim('BBC')
call assertEqual 'ASSERTION:BOEING-PR-123',status~familyId,'effective corroboration family retained'
call assertEqual 'PUB-BBC',status~publicationFamilyId,'publication family retained separately'
call assertEqual 'BOEING-PR-123',status~assertionOriginFamilyId,'assertion root retained'
call assertTrue status~assertionAncestryResolved,'explicit ancestry state retained'

faa=makeClaim('FAA','PUB-FAA',84,'ASSERTS','FAA-CONFIRM-987','FAA','PRIMARY_CONFIRMATION','LIB-F')
h2=.ReputationEventHypothesis~new('H-ANCESTRY-2','AIRCRAFT_SAFETY_INCIDENT')
h2~addClaim(r); h2~addClaim(b); h2~addClaim(l); h2~addClaim(faa); h2~seal
a2=h2~corroboration(policy)
call assertEqual 4,a2~publicationFamilyCount,'four publication families retained'
call assertEqual 2,a2~explicitAssertionOriginFamilyCount,'FAA confirmation adds a second underlying assertion root'
call assertEqual 2,a2~assertionFamilyCount,'two underlying assertion families corroborate'
call assertEqual 87,a2~weightedConfidence,'confidence averages best representative per assertion origin'
call assertEqual 'CORROBORATED',a2~status,'independent primary confirmation satisfies threshold'
call assertTrue a2~thresholdSatisfied,'independent assertion origins meet threshold'

contestPolicy=.ReputationCorroborationPolicy~new(2,70,2,120,.true)
deny1=makeClaim('DENY1','PUB-DENY-A',91,'DENIES','BOEING-DENIAL-1','BOEING','DERIVED_FROM','LIB-D1')
deny2=makeClaim('DENY2','PUB-DENY-B',89,'DENIES','BOEING-DENIAL-1','BOEING','AI_REWRITE_OF','LIB-D2')
contestH=.ReputationEventHypothesis~new('H-CONTEST-ANCESTRY','AIRCRAFT_SAFETY_INCIDENT')
contestH~addClaim(r); contestH~addClaim(faa); contestH~addClaim(deny1); contestH~addClaim(deny2); contestH~seal
contestA=contestH~corroboration(contestPolicy)
call assertEqual 1,contestA~denialFamilyCount,'two denial publications repeating one denial root count once'
call assertFalse contestA~contested,'one denial assertion root cannot meet two-family contest threshold'
call assertEqual 'CORROBORATED',contestA~status,'duplicate denial ancestry does not manufacture contested state'

deny3=makeClaim('DENY3','PUB-DENY-C',83,'DENIES','REGULATOR-DENIAL-2','REGULATOR','PRIMARY_CONFIRMATION','LIB-D3')
contestH2=.ReputationEventHypothesis~new('H-CONTEST-ANCESTRY-2','AIRCRAFT_SAFETY_INCIDENT')
contestH2~addClaim(r); contestH2~addClaim(faa); contestH2~addClaim(deny1); contestH2~addClaim(deny2); contestH2~addClaim(deny3); contestH2~seal
contestA2=contestH2~corroboration(contestPolicy)
call assertEqual 2,contestA2~denialFamilyCount,'independent denial root adds genuine contest evidence'
call assertTrue contestA2~contested,'two independent denial assertion roots meet contest threshold'
call assertEqual 'CONTESTED',contestA2~status,'independent denial ancestry produces contested state'

legacy1=.ReputationFeedClaim~new('LEGACY1','ART-L1','LEGACY-PUB-1','AIRCRAFT_SAFETY_INCIDENT','Legacy one',now,now,'GB',82,'ASSERTS','ACTIVE','LEGACY-1','L1')
legacy1~setEventKey('INCIDENT-A'); legacy1~addConcept('CABIN_OPENING'); legacy1~seal
legacy2=.ReputationFeedClaim~new('LEGACY2','ART-L2','LEGACY-PUB-2','AIRCRAFT_SAFETY_INCIDENT','Legacy two',now,now,'GB',80,'ASSERTS','ACTIVE','LEGACY-2','L2')
legacy2~setEventKey('INCIDENT-A'); legacy2~addConcept('CABIN_OPENING'); legacy2~seal
legacyH=.ReputationEventHypothesis~new('H-LEGACY','AIRCRAFT_SAFETY_INCIDENT'); legacyH~addClaim(legacy1); legacyH~addClaim(legacy2); legacyH~seal
legacyA=legacyH~corroboration(policy)
call assertEqual 2,legacyA~assertionFamilyCount,'legacy claims preserve publication-lineage fallback behaviour'
call assertEqual 0,legacyA~ancestryResolvedClaimCount,'legacy claims have no invented assertion ancestry'
call assertEqual 2,legacyA~ancestryFallbackClaimCount,'fallback use is explicit evidence'
call assertEqual 'CORROBORATED',legacyA~status,'legacy behaviour remains compatible when ancestry is unknown'
call assertEqual 'PUBLICATION:LEGACY-PUB-1',legacyA~evidenceStatusForClaim('LEGACY1')~familyId,'fallback family is explicitly typed as publication lineage'

say 'PASS test_assertion_ancestry_corroboration publications='a2~publicationFamilyCount 'assertion_roots='a2~assertionFamilyCount
exit 0

makeClaim: procedure
  use arg id,pubFamily,confidence,stance,root,originSource,relationship,evidenceId
  c=.ReputationFeedClaim~new(id,'ART-'id,pubFamily,'AIRCRAFT_SAFETY_INCIDENT','Synthetic ancestry claim',.DateTime~new,.DateTime~new,'GB',confidence,stance,'ACTIVE','SRC-'id,id)
  c~setEventKey('INCIDENT-A')
  c~addConcept('CABIN_OPENING')
  c~addAffectedGeography('GB')
  c~addAssertionOrigin(root,originSource,relationship,evidenceId)
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
