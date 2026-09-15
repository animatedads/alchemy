now = .DateTime~new
policy = .ReputationCorroborationPolicy~new(2, 70, 1, 120, .true)

a = .ReputationFeedClaim~new('A','ART-A','WIRE-1','AIRCRAFT_SAFETY_INCIDENT','Cabin opening incident',now,now,'US-WA',90,'ASSERTS','ACTIVE','PUB-A','A')
a~setEventKey('INCIDENT-A'); a~addSubject('MANUFACTURER','BOEING'); a~addConcept('CABIN_OPENING'); a~addAffectedGeography('GB'); a~seal
b = .ReputationFeedClaim~new('B','ART-B','WIRE-1','AIRCRAFT_SAFETY_INCIDENT','AI rewrite of same source',now,now,'GB',86,'ASSERTS','ACTIVE','PUB-B','B')
b~setEventKey('INCIDENT-A'); b~addSubject('MANUFACTURER','BOEING'); b~addConcept('CABIN_OPENING'); b~addAffectedGeography('GB'); b~seal
c = .ReputationFeedClaim~new('C','ART-C','REPORTER-2','AIRCRAFT_SAFETY_INCIDENT','Independent confirmation',now,now,'GB',82,'ASSERTS','ACTIVE','PUB-C','C')
c~setEventKey('INCIDENT-A'); c~addSubject('MANUFACTURER','BOEING'); c~addConcept('CABIN_OPENING'); c~addAffectedGeography('GB'); c~seal

clusters = .ReputationEventClusterEngine~new~cluster(.array~of(a,b,c), policy)
call assertEqual 1, clusters~hypothesisCount, 'three compatible claims cluster into one hypothesis'
h = clusters~hypotheses[1]
assessment = h~corroboration(policy)
call assertEqual 3, assessment~claimCount, 'all claims retained as evidence'
call assertEqual 2, assessment~assertionFamilyCount, 'AI rewrite family counted once'
call assertEqual 2, assessment~requiredIndependentFamilies, 'threshold is explicit'
call assertEqual 86, assessment~weightedConfidence, 'confidence averages best representative per independent family'
call assertEqual 70, assessment~requiredWeightedConfidence, 'confidence threshold is explicit'
call assertEqual 'CORROBORATED', assessment~status, 'two independent families meet corroboration threshold'
call assertTrue assessment~thresholdSatisfied, 'threshold result retained'

onlyOneFamily = .ReputationEventHypothesis~new('H-ONE','AIRCRAFT_SAFETY_INCIDENT')
onlyOneFamily~addClaim(a); onlyOneFamily~addClaim(b); onlyOneFamily~seal
oneAssessment = onlyOneFamily~corroboration(policy)
call assertEqual 2, oneAssessment~claimCount, 'two rewritten claims retained'
call assertEqual 1, oneAssessment~assertionFamilyCount, 'same lineage does not double corroboration'
call assertEqual 'CORROBORATING', oneAssessment~status, 'one independent source family is insufficient'
call assertFalse oneAssessment~thresholdSatisfied, 'one family does not satisfy threshold'

x = .ReputationFeedClaim~new('X','ART-X','F3','AIRCRAFT_SAFETY_INCIDENT','Separate Boeing incident',now,now,'US-WA',90,'ASSERTS','ACTIVE','PUB-X','X')
x~setEventKey('INCIDENT-X'); x~addSubject('MANUFACTURER','BOEING'); x~addConcept('CABIN_OPENING'); x~seal
separate = .ReputationEventClusterEngine~new~cluster(.array~of(a,x), policy)
call assertEqual 2, separate~hypothesisCount, 'conflicting normalized event keys prevent false merge'

say 'PASS test_event_corroboration_lineage_threshold status=' assessment~status 'families=' assessment~assertionFamilyCount'/'assessment~requiredIndependentFamilies 'confidence='assessment~weightedConfidence'/'assessment~requiredWeightedConfidence
exit 0

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
