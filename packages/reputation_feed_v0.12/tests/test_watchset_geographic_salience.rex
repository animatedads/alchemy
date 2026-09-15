now=.DateTime~new
claim=.ReputationFeedClaim~new('A','A','F1','AIRCRAFT_SAFETY_INCIDENT','Cabin incident',now,now,'US-WA',90,'ASSERTS','ACTIVE','A','A')
claim~addSubject('MANUFACTURER','BOEING'); claim~addSubject('EQUIPMENT','737-MAX-9'); claim~addConcept('CABIN_OPENING'); claim~addAffectedGeography('GB'); claim~seal
hyp=.ReputationEventHypothesis~new('H1','AIRCRAFT_SAFETY_INCIDENT'); hyp~addClaim(claim); hyp~seal

watch=.ReputationWatchSet~new('OURLADYAIR-GLA-SKG')
watch~addEventType('AIRCRAFT_SAFETY_INCIDENT'); watch~addSubject('MANUFACTURER','BOEING'); watch~addConcept('CABIN_OPENING'); watch~addGeography('GB'); watch~seal
match=.ReputationWatchEngine~new~match(watch,hyp,now)
call assertTrue match~matched, 'active airline watchset matches relevant event hypothesis'
call assertEqual 100, match~score, 'event, subject, concept and geography all contribute'

unrelated=.ReputationWatchSet~new('FOOTBALL')
unrelated~addEventType('SPORTING_EVENT'); unrelated~addConcept('FOOTBALL'); unrelated~seal
miss=.ReputationWatchEngine~new~match(unrelated,hyp,now)
call assertFalse miss~matched, 'unrelated watchset does not match'
call assertEqual 0, miss~score, 'unrelated event type blocks match'

policy=.ReputationGeographicSaliencePolicy~new(2,5,3,10)
gb=.ReputationGeographicSalienceEvidence~new('H1','GB',now,6,34,4,12,.true,90)
gr=.ReputationGeographicSalienceEvidence~new('H1','GR',now,1,2,0,1,.false,80)
gbA=policy~assess(gb); grA=policy~assess(gr)
call assertEqual 'HIGH',gbA~band,'GB evidence crosses high threshold'
call assertEqual 5,gbA~familyThreshold,'high family threshold explicitly reported'
call assertEqual 'LOW',grA~band,'GR evidence remains low'
call assertEqual 2,grA~familyThreshold,'low assessment reports next medium family threshold'

say 'PASS test_watchset_geographic_salience watch='match~score 'GB='gbA~band 'GR='grA~band
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
