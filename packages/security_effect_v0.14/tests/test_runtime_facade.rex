now = .DateTime~new
subject = 'CUSTOMER-RUNTIME'
policy = .SecurityTestSupport~basePolicy(now)
module = .SecurityEffectRuntimeModule~new(policy)
call assertTrue module~runtimeStart~ok,'runtime starts with sealed policy'
call assertTrue module~evidenceStore~recordFinding(.SecurityTestSupport~geoFinding(subject,now))~ok,'runtime evidence stored'
a = .SecurityActionSurface~new('A-RUNTIME',subject,'PURCHASE',now,'HIGH','PAYMENT')
a~putAttribute('PAYMENT_INSTRUMENT','STORED')
a~putAttribute('ASSET_CLASS','HIGH_VALUE_LIQUID_ASSET')
a~putAttribute('AMOUNT',22000)
a~seal
ass = module~assess(a)~value
call assertEqual 'HOLD',ass~disposition,'runtime facade uses same deterministic policy'
call assertEqual 'SECURITY_RULES',module~moduleKind,'runtime module kind'
call assertEqual 'security.effect/0.13',module~apiVersion,'runtime api'
call assertTrue module~runtimeQuiesce~ok,'runtime quiesces'
call assertEqual 'RUNTIME_NOT_LIVE',module~assess(a)~code,'quiesced runtime refuses evaluation'
call assertTrue module~runtimeStop~ok,'runtime stops'
say 'PASS test_runtime_facade'
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
