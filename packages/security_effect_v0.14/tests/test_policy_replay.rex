now = .DateTime~new
subject = 'CUSTOMER-REPLAY'
store = .SecurityEvidenceStore~new
call assertTrue store~recordFinding(.SecurityTestSupport~geoFinding(subject,now))~ok,'finding stored'
snap = store~snapshotFor(subject,now)
action = .SecurityActionSurface~new('A-REPLAY',subject,'PURCHASE',now,'HIGH','PAYMENT')
action~putAttribute('PAYMENT_INSTRUMENT','STORED')
action~putAttribute('ASSET_CLASS','HIGH_VALUE_LIQUID_ASSET')
action~putAttribute('AMOUNT',25000)
action~seal

p1 = .SecurityTestSupport~basePolicy(now)
p2 = .SecurityPolicyFramework~new('SECURITY-POLICY-CORE','1.1',now + .TimeSpan~new(0,1,0,0,0),.nil,'SECURITY_TEAM','RISK_COMMITTEE','1.0')
r = .SecurityPolicyRule~new('PAY-031',100,'PURCHASE','REVIEW_REQUIRED','approved policy change under identical historical evidence')
r~requireFinding('GEO_CONTINUITY_ANOMALY')
r~addCriterion('PAYMENT_INSTRUMENT','EQ','STORED')
r~addCriterion('ASSET_CLASS','EQ','HIGH_VALUE_LIQUID_ASSET')
r~addCriterion('AMOUNT','GE',20000)
r~addConstraint('OUT_OF_BAND_CONFIRMATION_REQUIRED','TRANSACTION')
p2~addRule(r~seal)
p2~seal

replay = .SecurityPolicyReplayEngine~new
cmpResult = replay~compare(action,snap,p1,p2)
call assertTrue cmpResult~ok,'comparison succeeds'
cmp = cmpResult~value
call assertTrue cmp~changed,'policy comparison reports changed outcome'
call assertEqual 'HOLD',cmp~fromAssessment~disposition,'old policy replay remains HOLD'
call assertEqual 'REVIEW_REQUIRED',cmp~toAssessment~disposition,'future policy counterfactual is REVIEW_REQUIRED'
call assertEqual 'OPERATIVE',cmp~fromAssessment~trace~evaluationMode,'historical side labelled operative'
call assertEqual 'COUNTERFACTUAL',cmp~toAssessment~trace~evaluationMode,'alternate side labelled counterfactual'
call assertTrue cmp~fromAssessment~snapshot == snap,'exact historical snapshot retained'
call assertTrue cmp~toAssessment~snapshot == snap,'same snapshot replayed under replacement policy'

directFuture = replay~replay(action,snap,p2)
call assertEqual 'POLICY_NOT_EFFECTIVE',directFuture~code,'future policy cannot masquerade as operative historical policy'
cf = replay~counterfactual(action,snap,p2)
call assertTrue cf~ok,'explicit counterfactual path accepts alternate policy'
call assertEqual 'COUNTERFACTUAL',cf~value~trace~evaluationMode,'counterfactual trace labelled'

repeat = replay~replay(action,snap,p1)
call assertEqual cmp~fromAssessment~trace~traceIdentity,repeat~value~trace~traceIdentity,'historical replay deterministic'

p3 = .SecurityPolicyFramework~new('SECURITY-POLICY-CORE','1.2',now + .TimeSpan~new(0,2,0,0,0),.nil,'SECURITY_TEAM','RISK_COMMITTEE','1.1')
r3 = .SecurityPolicyRule~new('PAY-NEW-ID',100,'PURCHASE','HOLD','same business outcome under a different policy trace')
r3~requireFinding('GEO_CONTINUITY_ANOMALY')
r3~addCriterion('PAYMENT_INSTRUMENT','EQ','STORED')
r3~addCriterion('ASSET_CLASS','EQ','HIGH_VALUE_LIQUID_ASSET')
r3~addCriterion('AMOUNT','GE',20000)
r3~addConstraint('OUT_OF_BAND_CONFIRMATION_REQUIRED','TRANSACTION')
r3~addConstraint('FREEZE_RECOVERY_CHANNEL_MUTATION','ACCOUNT')
r3~addUnaffectedAbility('BOOKING_STATUS_READ')
r3~addUnaffectedAbility('CUSTOMER_SERVICE_CONVERSATION')
p3~addRule(r3~seal)
p3~seal
same = replay~compare(action,snap,p1,p3)~value
call assertTrue same~changed = .false,'different policy trace with same result is not falsely reported as outcome change'
call assertTrue same~traceChanged,'different policy identity/rule remains visible as trace change'

say 'PASS test_policy_replay'
exit 0
assertTrue: procedure
  use arg v,l
  if v = .false then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return
::requires 'TestSupport.cls'
