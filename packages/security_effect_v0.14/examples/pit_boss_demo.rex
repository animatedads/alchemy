now = .DateTime~new
subject = 'CUSTOMER-1'
store = .SecurityEvidenceStore~new
ignore = store~recordFinding(.SecurityTestSupport~geoFinding(subject,now))
policy = .SecurityTestSupport~basePolicy(now)
engine = .SecurityEffectEngine~new
snap = store~snapshotFor(subject,now)
a = .SecurityActionSurface~new('GOLD',subject,'PURCHASE',now,'HIGH','PAYMENT')
a~putAttribute('PAYMENT_INSTRUMENT','STORED')
a~putAttribute('ASSET_CLASS','HIGH_VALUE_LIQUID_ASSET')
a~putAttribute('AMOUNT',20000)
a~seal
r = engine~evaluate(a,snap,policy)~value
say 'Security Effect' .SecurityEffectBuild~RELEASE
say 'policy='r~policy~policyId 'version='r~policy~version
say 'action='a~actionType 'disposition='r~disposition
do c over r~constraints
  say 'constraint='c~code 'scope='c~scope
end
do ability over r~unaffectedAbilities
  say 'unaffected='ability
end
::requires 'TestSupport.cls'
