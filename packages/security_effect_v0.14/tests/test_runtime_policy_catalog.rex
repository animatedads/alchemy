now = .DateTime~new
subject = 'CUSTOMER-RUNTIME-CATALOG'
catalog = .SecurityPolicyCatalog~new
p1 = .SecurityTestSupport~basePolicy(now)
call assertTrue catalog~publish(p1)~ok,'current policy published'
module = .SecurityEffectRuntimeModule~new(catalog,.nil,'SECURITY-POLICY-CORE')
call assertTrue module~runtimeStart~ok,'runtime starts with policy catalog'
call assertTrue module~evidenceStore~recordFinding(.SecurityTestSupport~geoFinding(subject,now))~ok,'runtime finding stored'
a = .SecurityActionSurface~new('A-RUNTIME-CATALOG',subject,'PURCHASE',now,'HIGH','PAYMENT')
a~putAttribute('PAYMENT_INSTRUMENT','STORED')
a~putAttribute('ASSET_CLASS','HIGH_VALUE_LIQUID_ASSET')
a~putAttribute('AMOUNT',22000)
a~seal
ass = module~assess(a)
call assertTrue ass~ok,'catalog-backed assessment succeeds'
call assertEqual 'HOLD',ass~value~disposition,'runtime resolved operative policy by action time'
call assertTrue module~runtimeStop~ok,'runtime stops'
say 'PASS test_runtime_policy_catalog'
exit 0
assertTrue: procedure
  use arg v,l
  if v = .false then do; say 'FAIL:' l; exit 1; end
  return
assertEqual: procedure
  use arg e,a,l
  if e <> a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end
  return
::requires 'SecurityEffectRuntimeModule.cls'
::requires 'TestSupport.cls'
