/* Planner-facing read-only operator: metadata-only bind, materialize then filter/project/limit. */

say 'ALGORITHM READ OPERATOR V0.4 START'

world = .RYTAWorldState~new('WORLD-READ-OP-1')
world~putKnown('HAS_QUERY', .true)
world~putKnown('PRODUCT_RELEVANT', .true)
world~putKnown('PRODUCT_VALUE_HIGH', .true)
world~putKnown('UPSELL_OPPORTUNITY', .true)
world~putKnown('ESSENTIAL_MEDICATION', .true)
world~putKnown('IMMEDIATE_ACCESS', .true)
world~putKnown('GUARANTEED_CUSTODY', .false)

provider = .RYTAAlgorithmProvider~new(.nil, '..')
engine = .AlgorithmRelationEngine~new
call assertTrue 'register provider', engine~addProvider(provider)
operator = .AlgorithmRelationReadOperator~new(engine)

plan = .AlgorithmRelationReadPlan~new('VIRTUAL_RYTA', 'RYTA_ACTION_DECISIONS')
plan~project('ACTION_CODE')
plan~project('SCORE')
plan~project('DISPOSITION')
plan~whereEqual('DISPOSITION', 'PROHIBITED')
plan~limit(1)

described = operator~describe(plan)
call assertTrue 'describe succeeds', described \== .nil
call assertEqual 'describe projection count', 3, described~columns~items
call assertEqual 'describe does not invoke provider', 0, provider~invocationCount

explainLines = operator~explain(plan)
call assertContains 'explain declares no pushdown', explainLines, 'PROVIDER_PUSHDOWN=NONE_V0.4'
call assertEqual 'explain does not invoke provider', 0, provider~invocationCount

context = .AlgorithmExecutionContext~new('READ-INV-1', world~snapshotOid, world~snapshotOid)
readRelation = operator~execute(plan, world, context)
call assertTrue 'read operator returns relation', readRelation \== .nil
call assertEqual 'provider invoked exactly once', 1, provider~invocationCount
call assertEqual 'limit applied to output', 1, readRelation~rows~items
call assertEqual 'filtered row is prohibited', 'PROHIBITED', readRelation~rows[1]~value('DISPOSITION')

/* Inspect cached full provider materialization: LIMIT was not pushed into provider. */
fullResult = engine~execute('VIRTUAL_RYTA', world, context)
call assertEqual 'full result obtained from cache', 1, provider~invocationCount
fullRelation = fullResult~relation('RYTA_ACTION_DECISIONS')
call assertEqual 'provider materialized all seven rows before LIMIT', 7, fullRelation~rows~items

badProjection = .AlgorithmRelationReadPlan~new('VIRTUAL_RYTA', 'RYTA_ACTION_DECISIONS')
badProjection~project('NO_SUCH_COLUMN')
call assertTrue 'bad projection rejected during metadata bind', operator~describe(badProjection) == .nil
call assertEqual 'bad projection still does not invoke provider', 1, provider~invocationCount

say 'ALGORITHM READ OPERATOR V0.4: OK'
exit 0

assertEqual: procedure
  use arg label, expected, actual
  if expected == actual then return .true
  say 'ASSERT FAILED:' label
  say '  expected:' expected
  say '  actual:  ' actual
  exit 1

assertTrue: procedure
  use arg label, actual
  if actual then return .true
  say 'ASSERT FAILED:' label
  say '  actual:' actual
  exit 1

assertContains: procedure
  use arg label, values, expected
  do value over values
    if value == expected then return .true
  end
  say 'ASSERT FAILED:' label
  say '  missing:' expected
  exit 1

::requires '../algorithm/AlgorithmRelation.cls'
::requires '../algorithm/AlgorithmReadOperator.cls'
::requires '../algorithm/RYTAAlgorithmProvider.cls'
::requires '../HardWorld.cls'
