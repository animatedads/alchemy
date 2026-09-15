t0 = .DateTime~new
t1 = t0 + .TimeSpan~new(0,0,10,0,0)
t2 = t0 + .TimeSpan~new(0,0,20,0,0)
policy = .ReputationCorroborationPolicy~new(2,70,1,120,.true)

a=.ReputationFeedClaim~new('A','A','F1','SERVICE_FAILURE','Service failed',t0,t0,'GB',90,'ASSERTS','ACTIVE','A','A')
a~addSubject('SERVICE','ETHICAL-INC'); a~addConcept('SERVICE_FAILURE'); a~addAffectedGeography('GB'); a~seal
b=.ReputationFeedClaim~new('B','B','F2','SERVICE_FAILURE','Independent service failure report',t0,t0,'GB',80,'ASSERTS','ACTIVE','B','B')
b~addSubject('SERVICE','ETHICAL-INC'); b~addConcept('SERVICE_FAILURE'); b~addAffectedGeography('GB'); b~seal
ledger=.ReputationHypothesisLedger~new
ledger~addClaim(a); ledger~addClaim(b)

before = ledger~clusterAt(t0,policy)~hypotheses[1]~corroboration(policy)
call assertEqual 'CORROBORATED', before~status, 'historical replay before correction remains corroborated'
call assertEqual 2, before~assertionFamilyCount, 'two families before correction'

correction=.ReputationFeedCorrection~new('R1','B','RETRACTION','',t1,'B',100,'Source retracts B')~seal
ledger~addCorrection(correction)
after = ledger~clusterAt(t2,policy)~hypotheses[1]~corroboration(policy)
call assertEqual 'CORROBORATING', after~status, 'post-retraction current state drops below threshold'
call assertEqual 1, after~assertionFamilyCount, 'retracted family removed from current evidence but history retained'

/* A denial is evidence, not negative corroboration hidden inside confidence. */
d=.ReputationFeedClaim~new('D','D','F3','SERVICE_FAILURE','Organisation denies service failure',t0,t2,'GB',95,'DENIES','ACTIVE','D','D')
d~addSubject('SERVICE','ETHICAL-INC'); d~addConcept('SERVICE_FAILURE'); d~addAffectedGeography('GB'); d~seal
contested=.ReputationEventHypothesis~new('H-CONTEST','SERVICE_FAILURE')
contested~addClaim(a); contested~addClaim(d); contested~seal
contestAssessment=contested~corroboration(policy)
call assertEqual 'CONTESTED', contestAssessment~status, 'assertion plus independent denial is contested'
call assertTrue contestAssessment~contested, 'contested flag retained'
call assertEqual 1, contestAssessment~denialFamilyCount, 'denial family count explicit'

say 'PASS test_event_contested_correction_replay before='before~status 'after='after~status 'contested='contestAssessment~status
exit 0

assertTrue: procedure
  use arg value,label
  if value \== .true then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return

::requires 'ReputationFeed.cls'
