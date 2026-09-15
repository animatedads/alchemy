say 'RYTA NAMED TIERS START'

world = .RYTAWorldState~new('WORLD-TIERS-1')
world~putConflict('ESSENTIAL_MEDICATION')
world~putUnknown('IMMEDIATE_ACCESS')
world~putKnown('GUARANTEED_CUSTODY', .true)

rules = .RYTAStateRules~new
stateEval = rules~evaluateState(world)
call assertEqual 'highest tier', .RYTAConstant~TIER_SAFETY_CRITICAL, stateEval~highestTier
call assertEqual 'explicit conflict override wins', 'RYTA-CRITICAL-CONFLICT', stateEval~winnerRule~ruleId
call assertEqual 'resolved state', .RYTAConstant~STATE_ESCALATE, stateEval~state
call assertEqual 'not ambiguous with explicit override', .false, stateEval~ambiguous

rules~rule('RYTA-CRITICAL-CONFLICT')~clearOverrides
ambiguousEval = rules~evaluateState(world)
call assertEqual 'same-tier incompatible rules without override are ambiguous', .true, ambiguousEval~ambiguous
call assertEqual 'ambiguous model enters rule-conflict state', .RYTAConstant~STATE_RULE_CONFLICT, ambiguousEval~state
call assertEqual 'ambiguous model has no winning rule', .nil, ambiguousEval~winnerRule

say 'RYTA NAMED TIERS: OK'
exit 0

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

::requires '../VirtualRYTA.cls'
