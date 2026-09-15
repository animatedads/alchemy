now = .DateTime~new
subject = 'CUSTOMER-ENVELOPE'
store = .SecurityEvidenceStore~new
call assertTrue store~recordFinding(.SecurityTestSupport~geoFinding(subject,now))~ok,'geo finding stored'
snap = store~snapshotFor(subject,now)
policy = .SecurityTestSupport~basePolicy(now)
engine = .SecurityEffectEngine~new

gold = .SecurityActionSurface~new('A-GOLD-ENV',subject,'PURCHASE',now,'HIGH','PAYMENT')
gold~putAttribute('PAYMENT_INSTRUMENT','STORED')
gold~putAttribute('ASSET_CLASS','HIGH_VALUE_LIQUID_ASSET')
gold~putAttribute('AMOUNT',20000)
gold~seal
goldAss = engine~evaluate(gold,snap,policy)~value

envelope = .SecurityCapabilityEnvelope~new(subject,now)
call assertTrue envelope~applyAssessment(goldAss),'gold assessment applied'
call assertEqual 'HOLD',envelope~entry('PAYMENT')~disposition,'payment capability held'
call assertEqual 'ALLOW',envelope~entry('CUSTOMER_SERVICE_CONVERSATION')~disposition,'customer service remains explicitly available'

/* An ALLOW from another domain must not erase a stronger existing restriction. */
external = .SecurityCapabilityEnvelope~new(subject,now)
extPay = .SecurityCapabilityContribution~new('COMMERCE','ORDER-FLOW-1','ALLOW','ordinary commerce path permits payment')~seal
external~addContribution('PAYMENT',extPay)
external~addContribution('CUSTOMER_SERVICE_CONVERSATION',.SecurityCapabilityContribution~new('SHANNON','SESSION-1','ALLOW','conversation available')~seal)
external~seal
call assertTrue envelope~merge(external),'external envelope merged'
call assertEqual 'HOLD',envelope~entry('PAYMENT')~disposition,'ALLOW cannot downgrade HOLD'
call assertTrue envelope~entry('PAYMENT')~constraints~items > 0,'security constraints survive merge'
call assertEqual 2,envelope~entry('PAYMENT')~contributions~items,'both institutional contributions retained'

envelope~seal
call assertTrue envelope~addContribution('PAYMENT',.SecurityCapabilityContribution~new('TEST','X','REJECT')~seal) = .false,'sealed envelope immutable'
call assertTrue envelope~entry('PAYMENT')~addContribution(.SecurityCapabilityContribution~new('TEST','Y','REJECT')~seal) = .false,'returned entry cannot mutate sealed envelope'
call assertTrue extPay~addConstraint(.SecurityConstraint~new('LATE_MUTATION')) = .false,'retained contribution reference cannot mutate after seal'
say 'PASS test_capability_envelope'
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
