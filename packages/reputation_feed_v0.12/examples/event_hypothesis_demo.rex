now=.DateTime~new
policy=.ReputationCorroborationPolicy~new(2,70,1,120,.true)
wire=.ReputationFeedClaim~new('WIRE','A','F-WIRE','AIRCRAFT_SAFETY_INCIDENT','Cabin opening report',now,now,'US-WA',92,'ASSERTS','ACTIVE','WIRE','wire')
wire~setEventKey('INCIDENT-42'); wire~addSubject('MANUFACTURER','BOEING'); wire~addConcept('CABIN_OPENING'); wire~addAffectedGeography('GB'); wire~seal
rewrite=.ReputationFeedClaim~new('REWRITE','B','F-WIRE','AIRCRAFT_SAFETY_INCIDENT','AI rewritten local copy',now,now,'GB',86,'ASSERTS','ACTIVE','LOCAL','local')
rewrite~setEventKey('INCIDENT-42'); rewrite~addSubject('MANUFACTURER','BOEING'); rewrite~addConcept('CABIN_OPENING'); rewrite~addAffectedGeography('GB'); rewrite~seal
independent=.ReputationFeedClaim~new('INDEPENDENT','C','F-INDEPENDENT','AIRCRAFT_SAFETY_INCIDENT','Independent confirmation',now,now,'GB',80,'ASSERTS','ACTIVE','OTHER','other')
independent~setEventKey('INCIDENT-42'); independent~addSubject('MANUFACTURER','BOEING'); independent~addConcept('CABIN_OPENING'); independent~addAffectedGeography('GB'); independent~seal
h=.ReputationEventClusterEngine~new~cluster(.array~of(wire,rewrite,independent),policy)~hypotheses[1]
a=h~corroboration(policy)
say 'claims='a~claimCount
say 'independent_assertion_families='a~assertionFamilyCount
say 'required_families='a~requiredIndependentFamilies
say 'family_normalised_confidence='a~weightedConfidence
say 'required_confidence='a~requiredWeightedConfidence
say 'status='a~status
watch=.ReputationWatchSet~new('OURLADYAIR')
watch~addEventType('AIRCRAFT_SAFETY_INCIDENT'); watch~addSubject('MANUFACTURER','BOEING'); watch~addConcept('CABIN_OPENING'); watch~addGeography('GB'); watch~seal
m=.ReputationWatchEngine~new~match(watch,h,now)
say 'watch_match='m~matched 'score='m~score
exit 0
::requires 'ReputationFeed.cls'
