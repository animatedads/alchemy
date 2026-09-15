now = .DateTime~new
subject = 'DEMO-CUSTOMER'
store = .SecurityEvidenceStore~new
store~recordFinding(.SecurityTestSupport~geoFinding(subject,now))
snapshot = store~snapshotFor(subject,now)

action = .SecurityActionSurface~new('DEMO-GOLD',subject,'PURCHASE',now,'HIGH','PAYMENT')
action~putAttribute('PAYMENT_INSTRUMENT','STORED')
action~putAttribute('ASSET_CLASS','HIGH_VALUE_LIQUID_ASSET')
action~putAttribute('AMOUNT',20000)
action~seal

operative = .SecurityTestSupport~basePolicy(now)
proposed = .SecurityPolicyFramework~new('SECURITY-POLICY-CORE','1.1',now + .TimeSpan~new(1,0,0,0,0),.nil,'SECURITY_TEAM','RISK_COMMITTEE','1.0')
r = .SecurityPolicyRule~new('PAY-031',100,'PURCHASE','REVIEW_REQUIRED','proposed replacement consequence')
r~requireFinding('GEO_CONTINUITY_ANOMALY')
r~addCriterion('PAYMENT_INSTRUMENT','EQ','STORED')
r~addCriterion('ASSET_CLASS','EQ','HIGH_VALUE_LIQUID_ASSET')
r~addCriterion('AMOUNT','GE',20000)
r~addConstraint('OUT_OF_BAND_CONFIRMATION_REQUIRED','TRANSACTION')
proposed~addRule(r~seal)
proposed~seal

comparison = .SecurityPolicyReplayEngine~new~compare(action,snapshot,operative,proposed)~value
say 'operative:' comparison~fromAssessment~disposition comparison~fromAssessment~trace~evaluationMode
say 'proposed :' comparison~toAssessment~disposition comparison~toAssessment~trace~evaluationMode
say 'outcome changed:' comparison~changed
say 'trace changed  :' comparison~traceChanged
exit 0
::requires 'TestSupport.cls'
