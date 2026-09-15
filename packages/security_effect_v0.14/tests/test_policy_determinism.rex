now = .DateTime~new
subject = 'CUSTOMER-DETERMINISM'
store = .SecurityEvidenceStore~new
call assertTrue store~recordFinding(.SecurityTestSupport~geoFinding(subject,now))~ok,'finding stored'
snap = store~snapshotFor(subject,now)
policy = .SecurityTestSupport~basePolicy(now)
engine = .SecurityEffectEngine~new
a = .SecurityActionSurface~new('A-DETERMINISTIC',subject,'PURCHASE',now,'HIGH','PAYMENT')
a~putAttribute('PAYMENT_INSTRUMENT','STORED')
a~putAttribute('ASSET_CLASS','HIGH_VALUE_LIQUID_ASSET')
a~putAttribute('AMOUNT',25000)
a~seal
first = ''
disposition = ''
do i = 1 to 5
  evalResult = engine~evaluate(a,snap,policy)
  call assertTrue evalResult~ok,'evaluation succeeds'
  ass = evalResult~value
  if i = 1 then do
    first = ass~trace~traceIdentity
    disposition = ass~disposition
  end
  else do
    call assertEqual first,ass~trace~traceIdentity,'trace identical across repeated submits'
    call assertEqual disposition,ass~disposition,'disposition identical across repeated submits'
  end
end
call assertEqual 'HOLD',disposition,'fixed policy produces fixed hold'

policy2 = .SecurityPolicyFramework~new('SECURITY-POLICY-CORE','1.1',now - .TimeSpan~new(0,0,0,1,0),.nil,'SECURITY_TEAM','RISK_COMMITTEE','1.0')
rule = .SecurityPolicyRule~new('PAY-031',100,'PURCHASE','REVIEW_REQUIRED','changed approved consequence for same evidence')
rule~requireFinding('GEO_CONTINUITY_ANOMALY')
rule~addCriterion('PAYMENT_INSTRUMENT','EQ','STORED')
rule~addCriterion('ASSET_CLASS','EQ','HIGH_VALUE_LIQUID_ASSET')
rule~addCriterion('AMOUNT','GE',20000)
rule~addConstraint('OUT_OF_BAND_CONFIRMATION_REQUIRED','TRANSACTION')
policy2~addRule(rule~seal)
policy2~seal
ass2 = engine~evaluate(a,snap,policy2)~value
call assertEqual 'REVIEW_REQUIRED',ass2~disposition,'changed result requires changed policy version'
call assertTrue policy~semanticIdentity <> policy2~semanticIdentity,'policy semantic identity changes'
say 'PASS test_policy_determinism'
exit 0
assertTrue: procedure
  use arg v,l
  if v = .false then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l; exit 1; end
  return
::requires 'TestSupport.cls'
