now=.DateTime~new
policy=.ReputationCorroborationPolicy~new(2,70,1,120,.true)

a=makeClaim('A','F1',90,'VERIFIED',.false)
b=makeClaim('B','F2',82,'UNVERIFIED',.false)
c=makeClaim('C','F3',99,'FAILED',.false)
d=makeClaim('D','F4',97,'VERIFIED',.true)

h=.ReputationEventHypothesis~new('H-DEMO','SYNTH_EVENT')
h~addClaim(a); h~addClaim(b); h~addClaim(c); h~addClaim(d); h~seal
assessment=h~corroboration(policy)
say 'feed_api=' .ReputationFeedBuild~API_VERSION
say 'claims=' assessment~claimCount
say 'eligible_claims=' assessment~eligibleClaimCount
say 'discovery_only_claims=' assessment~discoveryOnlyClaimCount
say 'eligible_families=' assessment~assertionFamilyCount
say 'family_normalised_confidence=' assessment~weightedConfidence
say 'status=' assessment~status
say 'failed_family=' assessment~evidenceStatusForClaim('C')~disposition assessment~evidenceStatusForClaim('C')~reasonCode
say 'compromised_family=' assessment~evidenceStatusForClaim('D')~disposition assessment~evidenceStatusForClaim('D')~reasonCode
exit 0

makeClaim: procedure
  use arg id,family,confidence,authState,compromised
  c=.ReputationFeedClaim~new(id,'ART-'id,family,'SYNTH_EVENT','Synthetic',.DateTime~new,.DateTime~new,'GB',confidence,'ASSERTS','ACTIVE','SRC-'id,id)
  c~setEventKey('DEMO-EVENT')
  c~addConcept('SYNTH')
  c~setSourceAuthentication(authState,'AUTH-'id,compromised,'HISTORY-'id)
  c~seal
  return c

::requires 'ReputationFeed.cls'
