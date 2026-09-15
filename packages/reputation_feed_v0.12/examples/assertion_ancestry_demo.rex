now=.DateTime~new
policy=.ReputationCorroborationPolicy~new(2,70,1,120,.true)

r=claim('R','PUB-REUTERS',90,'BOEING-PR-123','BOEING','DERIVED_FROM')
b=claim('B','PUB-BBC',88,'BOEING-PR-123','BOEING','QUOTED_ASSERTION')
l=claim('L','PUB-LOCAL',86,'BOEING-PR-123','BOEING','AI_REWRITE_OF')
f=claim('F','PUB-FAA',84,'FAA-CONFIRM-987','FAA','PRIMARY_CONFIRMATION')

h=.ReputationEventHypothesis~new('DEMO-ANCESTRY','AIRCRAFT_SAFETY_INCIDENT')
h~addClaim(r); h~addClaim(b); h~addClaim(l); h~addClaim(f); h~seal
a=h~corroboration(policy)
say 'feed_api=' .ReputationFeedBuild~API_VERSION
say 'publication_families=' a~publicationFamilyCount
say 'explicit_assertion_origins=' a~explicitAssertionOriginFamilyCount
say 'corroborating_assertion_families=' a~assertionFamilyCount
say 'weighted_confidence=' a~weightedConfidence
say 'status=' a~status
say 'R publication=' a~evidenceStatusForClaim('R')~publicationFamilyId 'corroboration='a~evidenceStatusForClaim('R')~familyId
say 'B publication=' a~evidenceStatusForClaim('B')~publicationFamilyId 'corroboration='a~evidenceStatusForClaim('B')~familyId
say 'F publication=' a~evidenceStatusForClaim('F')~publicationFamilyId 'corroboration='a~evidenceStatusForClaim('F')~familyId
exit 0

claim: procedure
  use arg id,pubFamily,confidence,root,originSource,relationship
  c=.ReputationFeedClaim~new(id,'ART-'id,pubFamily,'AIRCRAFT_SAFETY_INCIDENT','Assertion ancestry demo',.DateTime~new,.DateTime~new,'GB',confidence,'ASSERTS','ACTIVE','SRC-'id,id)
  c~setEventKey('INCIDENT-DEMO')
  c~addConcept('CABIN_OPENING')
  c~addAffectedGeography('GB')
  c~addAssertionOrigin(root,originSource,relationship,'LIB-'id)
  c~seal
  return c

::requires 'ReputationFeed.cls'
