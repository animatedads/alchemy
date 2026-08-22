call assertEqual '0.2', .ReputationEffectBuild~VERSION, 'v0.2 build version'
call assertEqual 'reputation.effect/0.2', .ReputationEffectBuild~API_VERSION, 'v0.2 API version'

failure = .ReputationCommunicationFailure~new('SMOKE-FAIL', 'SERVICE_RESPONSE_FAILURE', 'SUPPORT', 'OPEN', 70, 'Synthetic unresolved support failure')
call assertTrue failure~isOpen, 'failure is open'

comm = .ReputationCommunicationSurface~new('SMOKE-COMM', 'PROSPECTIVE_CUSTOMER', 'PUBLIC_BODY')
call assertTrue comm~addFailure(failure), 'communication accepts failure'
call assertTrue comm~addAct('DECLARED_INTENT', '', 'STOP_SELLING'), 'communication accepts intent'
call assertTrue comm~addAct('SALES_PROMPT', 'DEAL_QUALIFICATION', 'SEAT_COUNT'), 'communication accepts sales prompt'
comm~seal
call assertTrue comm~sealed, 'communication seals'
call assertTrue comm~hasAct('DECLARED_INTENT', '', 'STOP_SELLING'), 'declared intent retained'
call assertTrue comm~redirectedFailedRouteSeverity = 0, 'no redirect means no circular-route severity'

action = .ReputationActionSurface~new('SMOKE-ACTION', 'TEST-ACTOR', 'CUSTOMER_COMMUNICATION', .DateTime~new, 'NORMAL')
call assertTrue action~addGeography('GB'), 'action accepts geography'
call assertTrue action~setCommunicationSurface(comm), 'action accepts communication surface'
action~seal
call assertTrue action~sealed, 'action seals'
call assertTrue action~communicationSurface \== .nil, 'sealed action retains communication surface'
call assertTrue action~canonicalText~pos('COMMUNICATION') > 0, 'canonical action includes communication evidence'

say 'PASS test_reputation_communication_surface_smoke api=' || .ReputationEffectBuild~API_VERSION
exit 0

assertTrue: procedure
  use arg value, label
  if \value then do; say 'FAIL:' label; exit 1; end
  return

assertEqual: procedure
  use arg expected, actual, label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return

::requires 'ReputationEffect.cls'
