parse arg root
policyPath = root || '/policy/ourladyair_safety_policy.txt'
policy = .ShannonLegalPolicy~new(policyPath)

call assertEqual .LegalEffectBuild~API_VERSION, policy~legalApiVersion, 'loaded Legal Effect API identity retained'

world = .RYTAWorldState~new('LEGAL-PROMOTION-TEST')
ignored = world~putKnown('TARGETED_OFFER_EVALUATION', .true, 'TEST', 'DETERMINISTIC')
ignored = world~putKnown('OFFER_AGE_RESTRICTED', .true, 'TEST', 'MODEL_PROPOSAL')
ignored = world~putKnown('TARGET_AGE_RESTRICTED_ELIGIBLE', .false, 'BOOKING/P2', 'BOOKING_SYSTEM')
ignored = world~putKnown('TARGET_AGE_RESTRICTED_INELIGIBLE', .true, 'BOOKING/P2', 'BOOKING_SYSTEM')
ignored = world~putKnown('TARGET_ELIGIBILITY_UNKNOWN', .false, 'BOOKING/P2', 'BOOKING_SYSTEM')

evaluation = policy~evaluateAction('SELL_PRODUCT', world)
call assertEqual 'BLOCKED', evaluation~status, 'ineligible age-restricted target blocked'
call assertFalse world~hasFact('LEGAL_SELL_PRODUCT_ACTION_BLOCKED'), 'evaluation alone does not mutate HardWorld'
call assertTrue evaluation~promotionAuthority~pos('LEGAL_EFFECT/0.5/') = 1, 'explicit v0.5 compatibility authority namespace retained'
call assertTrue evaluation~promotionAuthority~pos('LEGAL_EFFECT/' || policy~legalApiVersion~substr(policy~legalApiVersion~lastpos('/') + 1) || '/') = 0, 'does not relabel bridge as loaded engine authority'
call assertTrue evaluation~promotionAuthority~pos('LEGAL_EFFECT/0.6/') = 0, 'not v0.6 compatibility authority'

applied = policy~applyEvaluation(evaluation, world)
call assertEqual 3, applied~applied, 'three status projections applied'
call assertTrue world~isKnownTrue('LEGAL_SELL_PRODUCT_ACTION_BLOCKED'), 'promotion explicitly enters HardWorld'
blockedFact = world~fact('LEGAL_SELL_PRODUCT_ACTION_BLOCKED')
call assertTrue blockedFact~authority~pos('LEGAL_EFFECT/0.5/') = 1, 'HardWorld fact retains explicit compatibility authority'
call assertTrue blockedFact~evidence \== .nil, 'HardWorld fact retains promotion bundle evidence'

say 'PASS test_shannon_legal_identity_and_promotion api=' || policy~legalApiVersion || ' build=' || policy~legalBuildVersion
exit 0

assertTrue: procedure
  use arg value, label
  if \value then do; say 'FAIL:' label; exit 1; end
  return
assertFalse: procedure
  use arg value, label
  if value then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected=' expected 'actual=' actual; exit 1; end
  return

::requires 'ShannonLegalPolicy.cls'
