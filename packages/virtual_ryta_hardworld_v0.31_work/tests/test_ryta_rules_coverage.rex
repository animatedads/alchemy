say 'RYTA RULE COVERAGE START'

rules = .RYTAStateRules~new
states = .array~of('T', 'F', 'U', 'C')
combinations = 0
holes = 0
ambiguous = 0

/* 4 epistemic states for each of three critical facts = 64 combinations. */
do essential over states
  do immediate over states
    do custody over states
      combinations = combinations + 1
      world = .RYTAWorldState~new
      call putState world, 'ESSENTIAL_MEDICATION', essential
      call putState world, 'IMMEDIATE_ACCESS', immediate
      call putState world, 'GUARANTEED_CUSTODY', custody
      stateEval = rules~evaluateState(world)

      if stateEval~winnerRule == .nil then do
        holes = holes + 1
        say 'HOLE:' essential immediate custody
      end
      if stateEval~ambiguous then do
        ambiguous = ambiguous + 1
        say 'AMBIGUOUS WINNER:' essential immediate custody
      end

      call assertExpectedState essential, immediate, custody, stateEval~state
    end
  end
end

call assertEqual 'combination count', 64, combinations
call assertEqual 'coverage holes', 0, holes
call assertEqual 'same-priority conflicting winners', 0, ambiguous
say '  combinations:' combinations
say '  holes:' holes
say '  ambiguous winners:' ambiguous
say 'RYTA RULE COVERAGE: OK'
exit 0

putState: procedure
  use arg world, name, stateCode
  select
    when stateCode == 'T' then world~putKnown(name, .true)
    when stateCode == 'F' then world~putKnown(name, .false)
    when stateCode == 'U' then world~putUnknown(name)
    when stateCode == 'C' then world~putConflict(name)
  end
  return .true

assertExpectedState: procedure
  use arg essential, immediate, custody, actual
  if essential == 'C' | immediate == 'C' | custody == 'C' then expected = .RYTAConstant~STATE_ESCALATE
  else if essential == 'U' | immediate == 'U' | custody == 'U' then expected = .RYTAConstant~STATE_NEEDS_INFORMATION
  else if essential == 'F' | immediate == 'F' then expected = .RYTAConstant~STATE_NORMAL
  else if custody == 'F' then expected = .RYTAConstant~STATE_REMEDIATION_REQUIRED
  else expected = .RYTAConstant~STATE_NORMAL
  if expected == actual then return .true
  say 'ASSERT FAILED state matrix:' essential immediate custody
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

::requires '../VirtualRYTA.cls'
